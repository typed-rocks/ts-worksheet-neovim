local M = {}
local separator = package.config:sub(1, 1)  -- Get the OS-specific directory separator
local severity = vim.diagnostic.severity.INFO
function M.setup(opts)
    severity = opts.type or severity
end
local namespace = vim.api.nvim_create_namespace("tsw")
local function on_save()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.diagnostic.reset(namespace, bufnr)

    -- Get the first line of the buffer
    local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
    -- Check if the first line starts with "//ts-worksheet"
    if first_line and first_line:match("^//ts%-worksheet%-with%-variables") then
        M.add_inlay_hints("node", true, false)
    elseif first_line and first_line:match("^//ts%-worksheet") then
        M.add_inlay_hints("node", false, false)
    end
end

vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "*.ts", "*.js" },
    callback = on_save,
})

function M.get_current_file_path()
    return vim.api.nvim_buf_get_name(0)
end

local function read_file_to_string(filepath)
    local file = io.open(filepath, "r")
    if not file then
        vim.notify("Could not open file: " .. filepath, vim.log.levels.ERROR)
        return nil
    end

    local content = file:read("*all")

    file:close()

    return content
end

function M.get_directory_from_path(file_path)
    return vim.fn.fnamemodify(file_path, ":h")
end

function M.mapSingleCalled(obj)
    local res
    if type(obj) == "table" then
        -- Assuming obj is a Lua table equivalent of a JSON array.
        local msg = obj[1]
        local errObj = #obj > 1 and ", " .. obj[2] or ""
        res = msg .. errObj
    else
        res = obj
    end
    -- Replace "\\n" with Lua's line separator and Unicode space.
    res = tostring(res):gsub("\\n", "\n"):gsub('\226\128\131', ' ')
    return res
end

function M.stringedCalledAndValue(obj)
    local valueArray = {}
    for _, str in ipairs(obj["value"]) do
        table.insert(valueArray, str)
    end
    local valueString = table.concat(valueArray, ", ")

    local calledArray = {}
    for _, calledItem in ipairs(obj["called"]) do
        table.insert(calledArray, M.mapSingleCalled(calledItem))
    end
    local calledString = table.concat(calledArray, ", ")
    local stringedValue = valueString:gsub('\226\128\131', ' ')

    return calledString, stringedValue
end

local function is_number_in_table(tbl, num)
    for _, value in ipairs(tbl) do
        if value == tonumber(num) then
            return true
        end
    end
    return false
end

function M.find_lines_with_comment_suffix()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local matching_lines = {}
    for index, line in ipairs(lines) do
        if line:match("//%?$") then
            table.insert(matching_lines, index)
        end
    end

    return matching_lines
end

local function get_plugin_directory()
    local info = debug.getinfo(1, "S")
    local path = info.source:sub(2)  -- Remove the '@' prefix from the file path
    local dir = vim.fn.fnamemodify(path, ":h")  -- Get the directory part of the path
    return dir
end

-- Function to check if a value is in a list (table)
local function value_in_list(value, list)
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

local function is_rt_valid(rt)
    return value_in_list(rt, { "node", "deno", "bun" })
end

local function is_installed(exec)
    return vim.fn.executable(exec) == 1
end

function M.add_inlay_hints(rt, showVariables, showOrder)

    if is_rt_valid(rt) == false then
        vim.notify("Only the runtimes 'node', 'bun' or 'deno' are allowed as 'rt' parameter", vim.log.levels.ERROR)
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()

    local singleLines = M.find_lines_with_comment_suffix()
    local file_path = M.get_current_file_path()
    local file_dir = M.get_directory_from_path(file_path)

    vim.diagnostic.reset(namespace, bufnr)

    local mappedRt = rt

    if mappedRt == "node" then
        mappedRt = "tsx"
    end
    if mappedRt == "tsx" and not is_installed(mappedRt) then
        vim.notify("TSX is being installed")
        os.execute("npm i -g tsx@4.7.0 > /dev/null 2>&1")
        vim.notify("TSX is installed")
    end
    if not is_installed(mappedRt) then
        vim.notify(mappedRt .. " is not available in the systems PATH. Please install it.")
        return
    end
    local plugin_dir = get_plugin_directory()
    local envs = "CLI=" .. mappedRt .. " FILE=" .. file_path
    if showOrder then
        envs = envs .. " SHOW_ORDER=true"
    end
    local command = envs .. " node " .. plugin_dir .. separator .. "ts-worksheet-cli.js > /dev/null 2>&1"
    local json_file_path = file_dir .. separator .. ".ws.data.json"

    local r = os.execute(command)
    if not (r == 0) then
        vim.notify("An error occurred running ts-worksheet. Please file an issue if you think this should have worked properly", vim.log.levels.ERROR)
        return
    end
    local file_content = read_file_to_string(json_file_path)
    os.remove(json_file_path)

    local response = vim.json.decode(file_content)
    local data = response.data
    local error = response.error

    if error then
        if error.message then
            vim.notify("An error occurred. Maybe your TypeScript file is not valid? Otherwise file an issue: " .. error.message, vim.log.levels.ERROR)
        end
        return
    end

    if data == nil then
        vim.notify("There was an error getting the data from the CLI. Please file an issue", vim.log.levels.ERROR)
        return
    end

    local diagnostics = M.createInlays(data, namespace, showVariables, singleLines)

    vim.diagnostic.set(namespace, bufnr, diagnostics, {
        signs = false,
        virtual_text = true,
    })

    vim.notify("Done running with ts-worksheet with " .. rt, vim.log.levels.INFO)
end

function M.createInlays(data, namespace, showVariables, singleLines)
    local diagnostics = {}

    for line, value in pairs(data) do
        local curLine = tonumber(line) - 1

        local obj = value
        local type = obj["type"]

        local isVariable = (type == "variable")
        local showVariable = isVariable and showVariables
        local shouldShowLine = (next(singleLines) == nil or is_number_in_table(singleLines, line))
        if shouldShowLine and (showVariable or not isVariable) then
            local calledArray, stringedValue = M.stringedCalledAndValue(obj)

            table.insert(diagnostics, {
                lnum = curLine, -- Line number (0-indexed)
                col = #line, -- Column number (end of line)
                message = stringedValue,
                severity = severity,
                source = "tsw",
                namespace = namespace,
                type = "ts-worksheet-" .. type
            })
        end

    end
    return diagnostics
end

vim.api.nvim_create_user_command("Tsw", function(opts)
    local args = {}
    for _, arg in pairs(vim.split(opts.args, "%s+")) do
        local key, value = unpack(vim.split(arg, "="))
        args[key] = value
    end

    local rt = "node"
    local show_variables = args["show_variables"] == "true"
    local show_order = args["show_order"] == "true"
    if args["rt"] then
        rt = args["rt"]
    end

    M.add_inlay_hints(rt, show_variables, show_order)
end, { nargs = "*" })

return M

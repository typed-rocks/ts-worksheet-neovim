local M = {}
local utils = require('tsw.utils')
local config = require('tsw.config')

function M.setup()
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

        utils.add_inlay_hints(rt, show_variables, show_order)
    end, { nargs = "*" })

    vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = { "*.ts", "*.js" },
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            vim.diagnostic.reset(config.namespace, bufnr)

            -- Get the first line of the buffer
            local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
            -- Check if the first line starts with "//ts-worksheet"
            if first_line and first_line:match("^//ts%-worksheet%-with%-variables") then
                utils.add_inlay_hints("node", true, false)
            elseif first_line and first_line:match("^//ts%-worksheet") then
                utils.add_inlay_hints("node", false, false)
            end
        end,
    })
end

return M


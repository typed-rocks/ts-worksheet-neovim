local M = {}

M.severity = vim.diagnostic.severity.INFO
M.namespace = vim.api.nvim_create_namespace("tsw")

function M.setup(opts)
    M.severity = opts.severity or M.severity
end

return M


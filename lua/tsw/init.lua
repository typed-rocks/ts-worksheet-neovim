local M = {}

local config = require('tsw.config')
local commands = require('tsw.commands')

function M.setup(opts)
    config.setup(opts)
    commands.setup()
end

return M


if vim.g.loaded_tsw then
  return
end
vim.g.loaded_tsw = true

require('tsw').setup({})


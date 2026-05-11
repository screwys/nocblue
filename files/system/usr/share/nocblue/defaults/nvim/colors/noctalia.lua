local generated = vim.fn.expand "~/.cache/noctalia-nvim.lua"

if vim.uv.fs_stat(generated) then
  dofile(generated)
  return
end

vim.cmd "highlight clear"
if vim.fn.exists "syntax_on" == 1 then
  vim.cmd "syntax reset"
end
vim.g.colors_name = "noctalia"

vim.api.nvim_set_hl(0, "Normal", {})
vim.api.nvim_set_hl(0, "NormalFloat", {})

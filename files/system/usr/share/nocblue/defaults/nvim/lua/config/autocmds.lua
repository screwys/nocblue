local function open_tree()
  vim.schedule(function()
    if vim.bo.buftype ~= "" then
      return
    end
    pcall(vim.cmd, "Neotree show reveal left")
    pcall(vim.cmd, "wincmd p")
  end)
end

-- Keep the project tree visible by default, while keeping focus on the file.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("nvim_auto_open_tree", { clear = true }),
  callback = open_tree,
})

if vim.v.vim_did_enter == 1 then
  open_tree()
end

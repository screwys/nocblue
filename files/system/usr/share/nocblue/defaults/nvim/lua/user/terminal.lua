local M = {}

M.height = 0.18

function M.opts(cwd)
  return {
    cwd = cwd or LazyVim.root(),
    win = {
      position = "bottom",
      height = M.height,
    },
  }
end

function M.toggle(cwd)
  Snacks.terminal(nil, M.opts(cwd))
end

function M.focus(cwd)
  Snacks.terminal.focus(nil, M.opts(cwd))
end

function M.show(cwd, keep_current_window)
  local current = vim.api.nvim_get_current_win()
  Snacks.terminal(nil, M.opts(cwd))

  if keep_current_window and vim.api.nvim_win_is_valid(current) then
    vim.api.nvim_set_current_win(current)
  end
end

return M

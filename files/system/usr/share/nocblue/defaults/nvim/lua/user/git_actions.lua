local M = {}

local function root()
  return LazyVim.root.git() or LazyVim.root() or vim.uv.cwd()
end

local function terminal(command)
  Snacks.terminal(command, require("user.terminal").opts(root()))
end

function M.fetch()
  terminal { "git", "fetch", "--prune" }
end

function M.commit()
  vim.ui.input({ prompt = "Commit message: " }, function(message)
    if not message or message == "" then
      return
    end
    vim.cmd "wall"
    terminal { "git", "commit", "-m", message }
  end)
end

function M.push()
  terminal { "git", "push" }
end

function M.pull()
  terminal { "git", "pull", "--ff-only" }
end

return M

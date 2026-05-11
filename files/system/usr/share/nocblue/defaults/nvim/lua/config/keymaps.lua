-- Extra beginner-friendly aliases. LazyVim already provides the main keymaps.
local map = vim.keymap.set

map("n", "<leader>e", "<cmd>Neotree toggle reveal left<cr>", { desc = "Explorer" })
map("n", "<leader>E", "<cmd>Neotree focus left<cr>", { desc = "Focus Explorer" })
map("n", "<leader>ff", LazyVim.pick "files", { desc = "Find Files" })
map("n", "<leader>fg", LazyVim.pick "live_grep", { desc = "Search Text" })
map("n", "<leader>bb", LazyVim.pick "buffers", { desc = "Buffers" })
map("n", "<leader>o", "<cmd>Outline<cr>", { desc = "Code Outline" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Close Window" })
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<Tab>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
map("n", "<A-h>", "zh", { desc = "Scroll Left" })
map("n", "<A-l>", "zl", { desc = "Scroll Right" })
map("n", "<A-H>", "zH", { desc = "Scroll Left More" })
map("n", "<A-L>", "zL", { desc = "Scroll Right More" })
map("v", "<Tab>", ">gv", { desc = "Indent Selection" })
map("v", "<S-Tab>", "<gv", { desc = "Outdent Selection" })
map("n", "<leader>sr", function()
  require("user.replace").file()
end, { desc = "Replace in File" })
map("v", "<leader>sr", function()
  require("user.replace").selection()
end, { desc = "Replace in Selection" })

vim.schedule(function()
  local git = require "user.git_actions"
  local terminal = require "user.terminal"

  map({ "n", "t" }, "<C-/>", function()
    terminal.focus()
  end, { desc = "Terminal" })
  map({ "n", "t" }, "<C-_>", function()
    terminal.focus()
  end, { desc = "which_key_ignore" })
  map("n", "<leader>tt", function()
    terminal.toggle()
  end, { desc = "Terminal" })
  map("n", "<leader>tT", function()
    terminal.toggle(vim.uv.cwd())
  end, { desc = "Terminal (cwd)" })

  map("n", "<leader>gg", function()
    if vim.fn.executable "lazygit" == 1 then
      Snacks.lazygit { cwd = LazyVim.root.git() }
    else
      vim.notify("lazygit is not installed yet", vim.log.levels.WARN)
    end
  end, { desc = "LazyGit" })

  map("n", "<leader>gf", git.fetch, { desc = "Git Fetch" })
  map("n", "<leader>gc", git.commit, { desc = "Git Commit" })
  map("n", "<leader>gp", git.push, { desc = "Git Push" })
  map("n", "<leader>gP", git.pull, { desc = "Git Pull" })
end)

map("n", "<C-h>", "<C-w>h", { desc = "Go Left Window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go Lower Window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go Upper Window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go Right Window" })

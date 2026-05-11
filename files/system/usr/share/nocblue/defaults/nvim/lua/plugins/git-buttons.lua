local function in_git_repo()
  return vim.fn.executable "git" == 1 and vim.b.gitsigns_head ~= nil
end

local function button(label, action)
  return {
    function()
      return label
    end,
    cond = in_git_repo,
    on_click = function()
      vim.schedule(function()
        require("user.git_actions")[action]()
      end)
    end,
  }
end

return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}

      table.insert(opts.sections.lualine_x, 1, button("fetch", "fetch"))
      table.insert(opts.sections.lualine_x, 2, button("commit", "commit"))
      table.insert(opts.sections.lualine_x, 3, button("push", "push"))
    end,
  },
}

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        local ok = pcall(vim.cmd.colorscheme, "noctalia")
        if not ok then
          vim.cmd.colorscheme "habamax"
          vim.notify(
            "Noctalia Neovim theme has not been generated yet. Change or reapply the Noctalia colorscheme once.",
            vim.log.levels.WARN
          )
        end
      end,
    },
  },
}

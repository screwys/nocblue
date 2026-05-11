return {
  {
    "snacks.nvim",
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          if #vim.api.nvim_list_uis() == 0 then
            return
          end

          vim.defer_fn(function()
            require("user.terminal").show(nil, true)
          end, 80)
        end,
      })
    end,
  },
}

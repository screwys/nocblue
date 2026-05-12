return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        cssls = {},
        emmet_language_server = {
          filetypes = {
            "css",
            "eruby",
            "html",
            "javascript",
            "javascriptreact",
            "less",
            "sass",
            "scss",
            "typescriptreact",
          },
        },
        html = {},
        lua_ls = {
          settings = {
            Lua = {
              workspace = {
                checkThirdParty = false,
              },
            },
          },
        },
        taplo = {
          single_file_support = false,
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, { ".taplo.toml", "taplo.toml", ".git" })
            if root then
              on_dir(root)
            end
          end,
        },
      },
    },
  },
}

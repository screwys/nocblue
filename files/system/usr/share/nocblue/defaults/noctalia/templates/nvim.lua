local colors = {
  bg = "{{colors.surface.default.hex}}",
  bg_dark = "{{colors.surface_container_low.default.hex}}",
  bg_float = "{{colors.surface_container.default.hex}}",
  bg_high = "{{colors.surface_container_high.default.hex}}",
  fg = "{{colors.on_surface.default.hex}}",
  fg_dim = "{{colors.on_surface_variant.default.hex}}",
  border = "{{colors.outline_variant.default.hex}}",
  accent = "{{colors.primary.default.hex}}",
  accent_fg = "{{colors.on_primary.default.hex}}",
  secondary = "{{colors.secondary.default.hex}}",
  tertiary = "{{colors.tertiary.default.hex}}",
  red = "{{colors.error.default.hex}}",
  red_bg = "{{colors.error_container.default.hex}}",
  red_fg = "{{colors.on_error_container.default.hex}}",
  yellow = "{{colors.tertiary_container.default.hex}}",
  yellow_fg = "{{colors.on_tertiary_container.default.hex}}",
  green = "{{colors.secondary_container.default.hex}}",
  green_fg = "{{colors.on_secondary_container.default.hex}}",
  purple = "{{colors.primary_container.default.hex}}",
  purple_fg = "{{colors.on_primary_container.default.hex}}",
  visual = "{{colors.primary_container.default.hex}}",
}

vim.cmd "highlight clear"
if vim.fn.exists "syntax_on" == 1 then
  vim.cmd "syntax reset"
end
vim.g.colors_name = "noctalia"

local function hl(group, spec)
  vim.api.nvim_set_hl(0, group, spec)
end

hl("Normal", { fg = colors.fg, bg = colors.bg })
hl("NormalNC", { fg = colors.fg_dim, bg = colors.bg })
hl("NormalFloat", { fg = colors.fg, bg = colors.bg_float })
hl("FloatBorder", { fg = colors.border, bg = colors.bg_float })
hl("FloatTitle", { fg = colors.accent, bg = colors.bg_float, bold = true })
hl("CursorLine", { bg = colors.bg_high })
hl("CursorLineNr", { fg = colors.accent, bold = true })
hl("LineNr", { fg = colors.border })
hl("SignColumn", { bg = colors.bg })
hl("Visual", { bg = colors.visual })
hl("Search", { fg = colors.accent_fg, bg = colors.accent })
hl("IncSearch", { fg = colors.accent_fg, bg = colors.tertiary })
hl("MatchParen", { fg = colors.accent, bg = colors.bg_high, bold = true })
hl("Pmenu", { fg = colors.fg, bg = colors.bg_float })
hl("PmenuSel", { fg = colors.accent_fg, bg = colors.accent })
hl("PmenuSbar", { bg = colors.bg_high })
hl("PmenuThumb", { bg = colors.accent })
hl("StatusLine", { fg = colors.fg, bg = colors.bg_high })
hl("StatusLineNC", { fg = colors.fg_dim, bg = colors.bg_dark })
hl("WinSeparator", { fg = colors.border })
hl("TabLine", { fg = colors.fg_dim, bg = colors.bg_dark })
hl("TabLineSel", { fg = colors.accent_fg, bg = colors.accent, bold = true })
hl("TabLineFill", { bg = colors.bg_dark })

hl("Comment", { fg = colors.fg_dim, italic = true })
hl("Constant", { fg = colors.tertiary })
hl("String", { fg = colors.secondary })
hl("Character", { fg = colors.secondary })
hl("Number", { fg = colors.tertiary })
hl("Boolean", { fg = colors.tertiary })
hl("Identifier", { fg = colors.fg })
hl("Function", { fg = colors.accent })
hl("Statement", { fg = colors.purple_fg })
hl("Conditional", { fg = colors.purple_fg })
hl("Repeat", { fg = colors.purple_fg })
hl("Label", { fg = colors.purple_fg })
hl("Operator", { fg = colors.fg_dim })
hl("Keyword", { fg = colors.accent })
hl("Exception", { fg = colors.red })
hl("PreProc", { fg = colors.tertiary })
hl("Type", { fg = colors.secondary })
hl("Special", { fg = colors.accent })
hl("Underlined", { fg = colors.accent, underline = true })
hl("Error", { fg = colors.red_fg, bg = colors.red_bg })
hl("Todo", { fg = colors.yellow_fg, bg = colors.yellow, bold = true })

hl("DiagnosticError", { fg = colors.red })
hl("DiagnosticWarn", { fg = colors.yellow_fg })
hl("DiagnosticInfo", { fg = colors.secondary })
hl("DiagnosticHint", { fg = colors.tertiary })
hl("DiagnosticVirtualTextError", { fg = colors.red, bg = colors.bg_dark })
hl("DiagnosticVirtualTextWarn", { fg = colors.yellow_fg, bg = colors.bg_dark })
hl("DiagnosticVirtualTextInfo", { fg = colors.secondary, bg = colors.bg_dark })
hl("DiagnosticVirtualTextHint", { fg = colors.tertiary, bg = colors.bg_dark })

hl("GitSignsAdd", { fg = colors.green_fg })
hl("GitSignsChange", { fg = colors.yellow_fg })
hl("GitSignsDelete", { fg = colors.red })

hl("NeoTreeNormal", { fg = colors.fg, bg = colors.bg_dark })
hl("NeoTreeNormalNC", { fg = colors.fg_dim, bg = colors.bg_dark })
hl("NeoTreeDirectoryIcon", { fg = colors.accent })
hl("NeoTreeDirectoryName", { fg = colors.accent })
hl("NeoTreeFileNameOpened", { fg = colors.fg, bold = true })
hl("NeoTreeGitAdded", { fg = colors.green_fg })
hl("NeoTreeGitModified", { fg = colors.yellow_fg })
hl("NeoTreeGitDeleted", { fg = colors.red })

hl("TelescopeNormal", { fg = colors.fg, bg = colors.bg_float })
hl("TelescopeBorder", { fg = colors.border, bg = colors.bg_float })
hl("TelescopePromptNormal", { fg = colors.fg, bg = colors.bg_high })
hl("TelescopePromptBorder", { fg = colors.accent, bg = colors.bg_high })
hl("TelescopeSelection", { fg = colors.fg, bg = colors.bg_high, bold = true })
hl("TelescopeMatching", { fg = colors.accent, bold = true })

hl("WhichKey", { fg = colors.accent })
hl("WhichKeyGroup", { fg = colors.secondary })
hl("WhichKeyDesc", { fg = colors.fg })
hl("WhichKeyBorder", { fg = colors.border, bg = colors.bg_float })

hl("TroubleNormal", { fg = colors.fg, bg = colors.bg })
hl("TroubleText", { fg = colors.fg })
hl("TroubleCount", { fg = colors.accent, bg = colors.bg_high })

hl("BlinkCmpMenu", { fg = colors.fg, bg = colors.bg_float })
hl("BlinkCmpMenuBorder", { fg = colors.border, bg = colors.bg_float })
hl("BlinkCmpMenuSelection", { fg = colors.accent_fg, bg = colors.accent })
hl("BlinkCmpLabelMatch", { fg = colors.accent, bold = true })

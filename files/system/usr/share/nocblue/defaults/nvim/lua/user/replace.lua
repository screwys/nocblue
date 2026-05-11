local M = {}

local function escape_search(text)
  return vim.fn.escape(text, [[\/]])
end

local function escape_replace(text)
  return vim.fn.escape(text, [[\/&]])
end

local function substitute(range)
  vim.ui.input({ prompt = "Find: " }, function(find)
    if not find or find == "" then
      return
    end

    vim.ui.input({ prompt = "Replace with: " }, function(replace)
      if replace == nil then
        return
      end

      local command = ("%ss/\\V%s/%s/g"):format(range, escape_search(find), escape_replace(replace))
      vim.cmd(command)
    end)
  end)
end

function M.file()
  substitute "%"
end

function M.selection()
  substitute "'<,'>"
end

return M

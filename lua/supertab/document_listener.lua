local ollama = require("supertab.ollama")
local preview = require("supertab.completion_preview")
local config = require("supertab.config")

local M = {
  augroup = nil,
}

--- Get the appropriate handler based on configuration
local function get_handler()
  if config.ollama and config.ollama.enable then
    return ollama
  end
  return nil
end

M.setup = function()
  M.augroup = vim.api.nvim_create_augroup("supertab", { clear = true })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = M.augroup,
    callback = function(event)
      local file_name = event["file"]
      local buffer = event["buf"]
      if not file_name or not buffer then
        return
      end

      local handler = get_handler()
      if handler and handler.on_update then
        handler:on_update(buffer, file_name, "text_changed")
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    callback = function(_)
      local ok, api = pcall(require, "supertab.api")
      if not ok then
        return
      end
      if config.condition() or vim.g.SUPERTAB_DISABLED == 1 then
        if api.is_running() then
          api.stop()
          return
        end
      else
        if api.is_running() then
          return
        end
        api.start()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = M.augroup,
    callback = function(event)
      local file_name = event["file"]
      local buffer = event["buf"]
      if not file_name or not buffer then
        return
      end

      local handler = get_handler()
      if handler and handler.on_update then
        handler:on_update(buffer, file_name, "cursor")
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    group = M.augroup,
    callback = function(event)
      preview:dispose_inlay()
    end,
  })

  if config.color and config.color.suggestion_color and config.color.cterm then
    vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, {
      group = M.augroup,
      pattern = "*",
      callback = function(event)
        vim.api.nvim_set_hl(0, "SupertabSuggestion", {
          fg = config.color.suggestion_color,
          ctermfg = config.color.cterm,
        })
        preview.suggestion_group = "SupertabSuggestion"
      end,
    })
  end
end

M.teardown = function()
  if M.augroup ~= nil then
    vim.api.nvim_del_augroup_by_id(M.augroup)
    M.augroup = nil
  end
end

return M
local ollama = require("supertab.ollama")
local preview = require("supertab.completion_preview")
local config = require("supertab.config")
local api = require("supertab.api")

local M = {}

---@type integer|nil
local augroup = nil

---@return table|nil
local function get_handler()
  if config.ollama and config.ollama.enable then
    return ollama
  end
  return nil
end

---@param event table
local function on_text_changed(event)
  local file_name = event.file
  local buffer = event.buf
  if not file_name or not buffer then
    return
  end

  local handler = get_handler()
  if handler and handler.on_update then
    handler:on_update(buffer, file_name, "text_changed")
  end
end

---@param _event table
local function on_buf_enter(_event)
  if config.condition() or vim.g.SUPERTAB_DISABLED == 1 then
    if api.is_running() then
      api.stop()
    end
    return
  end

  if not api.is_running() then
    api.start()
  end
end

---@param event table
local function on_cursor_moved(event)
  local file_name = event.file
  local buffer = event.buf
  if not file_name or not buffer then
    return
  end

  local handler = get_handler()
  if handler and handler.on_update then
    handler:on_update(buffer, file_name, "cursor")
  end
end

---@param _event table
local function on_insert_leave(_event)
  preview:dispose_inlay()
end

---@param _event table
local function setup_highlight(_event)
  if config.color and config.color.suggestion_color and config.color.cterm then
    vim.api.nvim_set_hl(0, "SupertabSuggestion", {
      fg = config.color.suggestion_color,
      ctermfg = config.color.cterm,
    })
    preview.suggestion_group = "SupertabSuggestion"
  end
end

M.setup = function()
  augroup = vim.api.nvim_create_augroup("supertab", { clear = true })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = augroup,
    callback = on_text_changed,
    desc = "Trigger completion on text change",
  })

  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = augroup,
    callback = on_buf_enter,
    desc = "Auto-start/stop supertab on buffer enter",
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = augroup,
    callback = on_cursor_moved,
    desc = "Update completion on cursor move",
  })

  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    group = augroup,
    callback = on_insert_leave,
    desc = "Clear completion on insert leave",
  })

  vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, {
    group = augroup,
    pattern = "*",
    callback = setup_highlight,
    desc = "Setup supertab highlight colors",
  })
end

M.teardown = function()
  if augroup ~= nil then
    vim.api.nvim_del_augroup_by_id(augroup)
    augroup = nil
  end
end

return M

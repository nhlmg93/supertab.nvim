---Cursor and position helpers using Neovim 0.12+ APIs
---@class SupertabCursor
local M = {}

---Get current cursor position.
--- Neovim's nvim_win_get_cursor returns: row 1-indexed, col 0-indexed.
--- This function returns the position as-is from Neovim (1-indexed row).
---@param winid? integer Window ID (default: 0 for current window)
---@return integer[] # {row, col} row is 1-indexed, col is 0-indexed
function M.get_position(winid)
  winid = winid or 0
  return vim.api.nvim_win_get_cursor(winid)
end

---Get current cursor line (0-indexed for other uses)
---@return integer line 0-indexed
function M.get_line()
  return vim.api.nvim_win_get_cursor(0)[1] - 1
end

---Get current cursor column (0-indexed, byte-position)
---@return integer column 0-indexed byte position
function M.get_col()
  return vim.api.nvim_win_get_cursor(0)[2]
end

---Set cursor position (converts from 0-indexed input to 1-indexed for Neovim)
---@param row integer 0-indexed row
---@param col integer 0-indexed column
---@param winid? integer Window ID
function M.set_position(row, col, winid)
  winid = winid or 0
  vim.api.nvim_win_set_cursor(winid, { row + 1, col })
end

---Get line at given row
---@param bufnr integer Buffer number
---@param row integer 0-indexed row
---@return string
function M.get_line_at(bufnr, row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
  return lines[1] or ""
end

---Get text before cursor on current line
---@param cursor? integer[] 0-indexed cursor position
---@return string # Text before cursor
function M.get_text_before_cursor(cursor)
  cursor = cursor or M.get_position()
  local line = vim.api.nvim_get_current_line()
  return string.sub(line, 1, cursor[2])
end

---Get text after cursor on current line
---@param cursor? integer[] 0-indexed cursor position
---@return string # Text after cursor
function M.get_text_after_cursor(cursor)
  cursor = cursor or M.get_position()
  local line = vim.api.nvim_get_current_line()
  return string.sub(line, cursor[2] + 1)
end

---Get line count in current buffer
---@return integer
function M.get_buf_line_count()
  return vim.api.nvim_buf_line_count(0)
end

---Get current buffer number
---@return integer
function M.get_bufnr()
  return vim.api.nvim_get_current_buf()
end

---Check if position is within valid buffer range
---@param bufnr integer Buffer number
---@param row integer 0-indexed row
---@param col integer 0-indexed column
---@return boolean
function M.is_valid_position(bufnr, row, col)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if row < 0 or row >= line_count then
    return false
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  if col < 0 or col > #line then
    return false
  end
  return true
end

---Get line ending at given position (handles different line ending types)
---@param bufnr integer Buffer number
---@param row integer 0-indexed row
---@return string
function M.get_line_ending(bufnr, row)
  local line = M.get_line_at(bufnr, row)
  -- Check for CRLF
  if line:match(".*\r\n$") then
    return "\r\n"
  end
  -- Check for CR (rare)
  if line:match(".*\r$") then
    return "\r"
  end
  -- Default to LF
  return "\n"
end

return M

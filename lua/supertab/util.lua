local M = {}

---@param a string
---@param b string
---@return boolean
function M.contains(a, b)
  return a:find(b, 1, true) ~= nil
end

---@param text string
---@param suffix string
---@return boolean
function M.is_floating_completion(text, suffix)
  return #suffix > 0 and text:sub(1, #suffix) ~= suffix
end

---@param str string
---@param highlight_group string
---@return {first_line: string, other_lines: table[]}
function M.first_line_split(str, highlight_group)
  local first_line = nil
  local other_lines = {}
  local split = vim.split(str, "\n", { plain = true })
  for _, line in ipairs(split) do
    if first_line == nil then
      first_line = line
    else
      table.insert(other_lines, { { line, highlight_group } })
    end
  end

  return {
    first_line = first_line,
    other_lines = other_lines,
  }
end

---@param bufnr integer
---@param cursor integer[]
---@return string
function M.get_cursor_prefix(bufnr, cursor)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return ""
  end

  local prefix = vim.api.nvim_buf_get_text(bufnr, 0, 0, cursor[1] - 1, cursor[2], {})
  return table.concat(prefix, "\n")
end

---@param bufnr integer
---@param cursor integer[]
---@return string
function M.get_cursor_suffix(bufnr, cursor)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return ""
  end

  local suffix = vim.api.nvim_buf_get_text(bufnr, cursor[1] - 1, cursor[2], -1, -1, {})
  return table.concat(suffix, "\n")
end

---@param cursor integer[]
---@return {text_before_cursor: string, text_after_cursor: string}
function M.get_text_before_after_cursor(cursor)
  local line = vim.api.nvim_get_current_line()
  local text_before_cursor = string.sub(line, 1, cursor[2])
  local text_after_cursor = string.sub(line, cursor[2] + 1)
  return {
    text_before_cursor = text_before_cursor,
    text_after_cursor = text_after_cursor,
  }
end

---@param s string
---@return string
function M.trim_end(s)
  return s:gsub("%s*$", "")
end

---@param s string
---@return string
function M.trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end

---@param s string
---@return string
function M.trim_start(s)
  return s:gsub("^%s*", "")
end

---@param bufnr integer
---@return string
function M.get_text(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, "\n")
end

---@param str string
---@return integer
function M.line_count(str)
  local count = 0
  for _ in str:gmatch("\n") do
    count = count + 1
  end
  return count
end

---@param str string
---@return string
function M.get_last_line(str)
  local last_line = str
  for i = #str, 1, -1 do
    local char = str:sub(i, i)
    if char == "\n" then
      last_line = str:sub(i + 1)
      break
    end
  end
  return last_line
end

---@param str string
---@return string
function M.to_next_word(str)
  local match = str:match("^.-[%a%d_]+")
  if match ~= nil then
    return match
  end
  return str
end

M.uv = vim.uv or vim.loop

return M

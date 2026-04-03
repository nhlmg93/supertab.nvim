local log = require("supertab.logger")

local M = {}

---@param pattern string
---@param lps integer[]
local function compute_lps(pattern, lps)
  local length = 0
  local i = 2
  lps[1] = 0

  while i <= #pattern do
    if pattern:sub(i, i) == pattern:sub(length + 1, length + 1) then
      length = length + 1
      lps[i] = length
      i = i + 1
    else
      if length ~= 0 then
        length = lps[length]
      else
        lps[i] = 0
        i = i + 1
      end
    end
  end
end

---@param a string
---@param b string
---@return boolean
function M.contains(a, b)
  local m, n = #a, #b
  if m < n then
    return false
  end
  local lps = {}

  compute_lps(b, lps)

  local i, j = 1, 1
  while i <= m do
    if a:sub(i, i) == b:sub(j, j) then
      i = i + 1
      j = j + 1
    end
    if j > n then
      return true
    elseif i <= m and a:sub(i, i) ~= b:sub(j, j) then
      if j ~= 1 then
        j = lps[j - 1] + 1
      else
        i = i + 1
      end
    end
  end
  return false
end

---@param str string
---@return string
function M.removeAfterNewline(str)
  local newlinePos = string.find(str, "\n")
  if newlinePos then
    return string.sub(str, 1, newlinePos - 1)
  else
    return str
  end
end

---@param str string
---@param sep string
---@return string[]
function M.split(str, sep)
  return vim.fn.split(str, sep)
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

---@return string|nil
function M.get_home_directory()
  local homeDir = os.getenv("HOME")
  if not homeDir then
    homeDir = os.getenv("USERPROFILE")
  end
  return homeDir
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

---@param char string
---@return boolean
function M.isWhitespace(char)
  return char == " " or char == "\t" or char == "\n" or char == "\r" or char == "\v" or char == "\f"
end

---@param bufnr integer
---@return string
function M.get_text(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, "\n")
end

---@param t table
---@param message? string
function M.print_table(t, message)
  if message == nil then
    log:info(vim.inspect(t))
  else
    log:info(message .. ": " .. vim.inspect(t))
  end
end

---@param str string
---@param prefix string
---@return boolean
function M.starts_with(str, prefix)
  return string.sub(str, 1, #prefix) == prefix
end

---@param str string
---@param suffix string
---@return boolean
function M.ends_with(str, suffix)
  return string.sub(str, -#suffix) == suffix
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

---@param bufnr integer
---@param line_number integer
---@return string|nil
function M.safe_get_line(bufnr, line_number)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_number < 1 or line_number > line_count then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)
  return lines[1]
end

---@param t table
---@param n? integer
---@return table
function M.tbl_flatten(t, n)
  if n ~= nil then
    return vim.iter and vim.iter(t):flatten(n):totable() or vim.tbl_flatten(t)
  end
  return vim.iter and vim.iter(t):flatten():totable() or vim.tbl_flatten(t)
end

---@param name string
---@param opts? vim.api.keyset.option
---@return any
function M.nvim_get_option_value(name, opts)
  if opts ~= nil then
    return vim.api.nvim_get_option_value and vim.api.nvim_get_option_value(name, opts) or vim.api.nvim_get_option(name)
  end
  return vim.api.nvim_get_option_value and vim.api.nvim_get_option_value(name, { scope = "local" })
    or vim.api.nvim_get_option(name)
end

---@param name string
---@param value any
---@param opts vim.api.keyset.option
function M.nvim_set_option_value(name, value, opts)
  if opts == nil then
    log:error("Must specify window or buffer in options, see `:help nvim_set_option_value`")
    return
  end
  if opts.win then
    return vim.api.nvim_set_option_value and vim.api.nvim_set_option_value(name, value, opts)
      or vim.api.nvim_win_set_option(opts.win, name, value)
  elseif opts.buf then
    return vim.api.nvim_set_option_value and vim.api.nvim_set_option_value(name, value, opts)
      or vim.api.nvim_buf_set_option(opts.buf, name, value)
  else
    log:error("Must specify window or buffer in options, see `:help nvim_set_option_value`")
    return
  end
end

M.uv = vim.uv or vim.loop

return M

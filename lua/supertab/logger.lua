local config = require("supertab.config")
local loop = vim.uv

---@class SupertabLogger
---@field private __notify_fmt function
---@field private __log_file file*|nil
local log = {}

---@alias LogLevel "off" | "trace" | "debug" | "info" | "warn" | "error"

---@type table<LogLevel, number>
local level_values = {
  off = 0,
  trace = 1,
  debug = 2,
  info = 3,
  warn = 4,
  error = 5,
}

---@param ... string
---@return string
local function join_path(...)
  local is_windows = loop.os_uname().version:match("Windows")
  local path_sep = is_windows and "\\" or "/"
  return table.concat(vim.iter({ ... }):flatten():totable(), path_sep):gsub(path_sep .. "+", path_sep)
end

---@return string|nil
local function get_log_path()
  local log_path = join_path(vim.fn.stdpath("cache"), "supertab.nvim.log")
  if vim.fn.filereadable(log_path) == 0 then
    return nil
  end
  return log_path
end

--- Creates the log file if it doesn't exist
local function create_log_file()
  local log_path = get_log_path()
  if log_path ~= nil then
    return
  end

  local cache_dir = vim.fn.stdpath("cache")
  if type(cache_dir) == "table" then
    cache_dir = cache_dir[1]
  end
  ---@cast cache_dir string

  if vim.fn.isdirectory(cache_dir) == 0 then
    vim.fn.mkdir(cache_dir, "p")
  end

  log_path = join_path(cache_dir, "supertab.nvim.log")
  local file = io.open(log_path, "w")
  if file == nil then
    vim.notify("Failed to create log file: " .. log_path, vim.log.levels.ERROR, { title = "Supertab" })
    return
  end
  file:close()
end

---@param level LogLevel
---@param msg string
function log:write_log_file(level, msg)
  local log_path = get_log_path()
  if log_path == nil then
    create_log_file()
    return
  end

  local file = io.open(log_path, "a")
  if file == nil then
    vim.notify("Failed to open log file: " .. log_path, vim.log.levels.ERROR, { title = "Supertab" })
    return
  end

  file:write(string.format("[%-6s %s] %s\n", level:upper(), os.date(), msg))
  file:close()
end

---@param level LogLevel
---@param msg string
function log:add_entry(level, msg)
  local conf = config.config

  if not self.__notify_fmt then
    self.__notify_fmt = function(message)
      return string.format("[supertab.nvim] %s", message)
    end
  end

  if conf.log_level == "off" or level_values[conf.log_level] == nil then
    return
  end

  if self.__log_file == nil then
    self.__log_file = create_log_file()
  end

  self:write_log_file(level, msg)

  if level_values[level] >= level_values[conf.log_level] then
    vim.notify(self.__notify_fmt(msg), vim.log.levels[level:upper()] or vim.log.levels.INFO, { title = "Supertab" })
  end
end

---@return string|nil
function log:get_log_path()
  return get_log_path()
end

---@param msg string
function log:warn(msg)
  self:add_entry("warn", msg)
end

---@param msg string
function log:error(msg)
  self:add_entry("error", msg)
end

---@param msg string
function log:info(msg)
  self:add_entry("info", msg)
end

---@param msg string
function log:debug(msg)
  self:add_entry("debug", msg)
end

---@param msg string
function log:trace(msg)
  self:add_entry("trace", msg)
end

return log

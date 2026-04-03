--- HTTP client for Ollama API using vim.uv (streaming only)
-- @module supertab.ollama.client

local log = require("supertab.logger")
local config = require("supertab.config")

local M = {}

M.current_request = nil
M.pending_request = nil

--- Parse host config into ip, port, path components
-- @param endpoint string Full URL like http://127.0.0.1:11434/api/generate
-- @return string ip, number port, string path, string host_port
local function parse_url(endpoint)
  local stripped = endpoint:gsub("^https?://", "")
  local slash = stripped:find("/")
  local host_port, path
  if slash then
    host_port = stripped:sub(1, slash - 1)
    path = stripped:sub(slash)
  else
    host_port = stripped
    path = "/"
  end
  local colon = host_port:find(":")
  local ip, port
  if colon then
    ip = host_port:sub(1, colon - 1)
    port = tonumber(host_port:sub(colon + 1))
  else
    ip = host_port
    port = 11434
  end
  return ip, port or 11434, path, host_port
end

--- Get the Ollama base URL
-- @return string
local function get_base_url()
  local ollama_config = config.ollama or {}
  return ollama_config.host or "http://127.0.0.1:11434"
end

--- Make a streaming HTTP request over TCP using vim.uv
-- Parses newline-delimited JSON as it arrives from Ollama's streaming API.
-- Also handles non-streaming responses (single JSON body) for endpoints like /api/tags.
-- @param method string HTTP method
-- @param url string Full URL
-- @param body string|nil Request body (for POST)
-- @param on_token fun(token: string, accumulated: string)|nil Called for each streaming token (nil for non-streaming)
-- @param on_done fun(err: string|nil, full_text: string) Called when complete
-- @return function Cancel function
local function http_request(method, url, body, on_token, on_done)
  local ip, port, path, host_port = parse_url(url)

  local tcp = vim.uv.new_tcp()
  local cancelled = false
  local accumulated = ""
  local body_buffer = ""
  local headers_parsed = false
  local header_buf = ""
  local is_chunked = false
  local chunk_buffer = ""

  local function finish(err)
    if cancelled then return end
    cancelled = true
    if tcp and not tcp:is_closing() then
      tcp:close()
    end
    vim.schedule(function()
      on_done(err, accumulated)
    end)
  end

  local function process_json_object(trimmed)
    if cancelled then return end

    local ok, data = pcall(vim.json.decode, trimmed)
    if not ok or type(data) ~= "table" then return end

    if data.error then
      finish("Ollama error: " .. data.error)
      return
    end

    local token = data.response or ""

    if #token > 0 then
      accumulated = accumulated .. token
      if on_token then
        vim.schedule(function()
          if not cancelled then
            on_token(token, accumulated)
          end
        end)
      end
    end

    if data.done then
      finish(nil)
    end
  end

  local function process_body_lines()
    while true do
      local nl = body_buffer:find("\n")
      if not nl then break end
      local line = body_buffer:sub(1, nl - 1)
      body_buffer = body_buffer:sub(nl + 1)
      local trimmed = line:match("^%s*(.-)%s*$")
      if trimmed and #trimmed > 0 then
        process_json_object(trimmed)
      end
    end
  end

  local function drain_chunks()
    while true do
      local crlf = chunk_buffer:find("\r\n")
      if not crlf then return end
      local size_str = chunk_buffer:sub(1, crlf - 1)
      local chunk_size = tonumber(size_str, 16)
      if not chunk_size then return end
      if chunk_size == 0 then
        finish(nil)
        return
      end
      local chunk_start = crlf + 2
      local chunk_end = chunk_start + chunk_size - 1
      if #chunk_buffer < chunk_end + 2 then return end
      local chunk_data = chunk_buffer:sub(chunk_start, chunk_end)
      chunk_buffer = chunk_buffer:sub(chunk_end + 3)
      body_buffer = body_buffer .. chunk_data
    end
  end

  local function handle_body_data(raw_data)
    if is_chunked then
      chunk_buffer = chunk_buffer .. raw_data
      drain_chunks()
    else
      body_buffer = body_buffer .. raw_data
    end
    process_body_lines()
  end

  tcp:connect(ip, port, function(conn_err)
    if conn_err then
      finish("connect: " .. tostring(conn_err))
      return
    end

    local lines = {
      method .. " " .. path .. " HTTP/1.1",
      "Host: " .. host_port,
      "Connection: close",
    }
    if body then
      table.insert(lines, "Content-Type: application/json")
      table.insert(lines, "Content-Length: " .. #body)
    end
    table.insert(lines, "")
    table.insert(lines, body or "")

    tcp:write(table.concat(lines, "\r\n"), function(write_err)
      if write_err then
        finish("write: " .. tostring(write_err))
        return
      end

      tcp:read_start(function(read_err, data)
        if read_err then
          finish("read: " .. tostring(read_err))
          return
        end
        if not data then
          tcp:read_stop()
          if not cancelled then
            -- For non-streaming responses, accumulated may be empty — pass body_buffer
            if #accumulated == 0 and #body_buffer > 0 then
              accumulated = body_buffer
            end
            finish(nil)
          end
          return
        end

        if not headers_parsed then
          header_buf = header_buf .. data
          local header_end = header_buf:find("\r\n\r\n")
          if header_end then
            local headers = header_buf:sub(1, header_end - 1)
            local status = tonumber(headers:match("HTTP/%d%.%d%s+(%d+)"))
            if not status or status >= 400 then
              finish("HTTP " .. tostring(status))
              return
            end
            is_chunked = headers:lower():find("transfer%-encoding:%s*chunked") ~= nil
            headers_parsed = true
            local remaining = header_buf:sub(header_end + 4)
            header_buf = ""
            if #remaining > 0 then
              handle_body_data(remaining)
            end
          end
        else
          handle_body_data(data)
        end
      end)
    end)
  end)

  return function()
    if not cancelled then
      cancelled = true
      if tcp and not tcp:is_closing() then
        tcp:close()
      end
    end
  end
end

--- Build the request body for Ollama
-- @param prefix string Text before cursor
-- @param suffix string Text after cursor
-- @return table
function M.build_request_body(prefix, suffix)
  local ollama_config = config.ollama or {}
  return {
    model = ollama_config.model or "codellama",
    stream = true,
    think = false,
    prompt = prefix,
    suffix = suffix,
    options = {
      temperature = ollama_config.temperature or 0.2,
      top_p = ollama_config.top_p or 0.9,
      top_k = ollama_config.top_k or 40,
      num_predict = ollama_config.max_tokens or 64,
    },
  }
end

--- Make streaming completion request to Ollama
-- @param prefix string Text before cursor
-- @param suffix string Text after cursor
-- @param on_token fun(token: string, accumulated: string) Called per token
-- @param on_done fun(completion: string) Called when complete
-- @return function Cancel function
function M.make_request(prefix, suffix, on_token, on_done)
  local url = get_base_url() .. "/api/generate"
  local body = M.build_request_body(prefix, suffix)
  local body_json = vim.json.encode(body)

  log:debug("Ollama streaming request to " .. url)

  return http_request("POST", url, body_json, on_token, function(err, full_text)
    if err then
      log:error("Ollama request failed: " .. err)
      on_done("")
      return
    end
    full_text = full_text:gsub("^%s*```[a-zA-Z]*%s*\n", ""):gsub("\n%s*```%s*$", "")
    on_done(full_text)
  end)
end

--- Queue a streaming request, cancelling any previous one
-- @param prefix string Text before cursor
-- @param suffix string Text after cursor
-- @param on_token fun(token: string, accumulated: string) Called per token
-- @param on_done fun(completion: string) Called when complete
-- @return function Cancel function
function M.queue_request(prefix, suffix, on_token, on_done)
  if M.pending_request and M.pending_request.cancel then
    M.pending_request.cancel()
    M.pending_request = nil
  end

  if M.current_request then
    M.pending_request = {
      prefix = prefix,
      suffix = suffix,
      on_token = on_token,
      on_done = on_done,
      cancel = function() M.pending_request = nil end,
    }
    return function()
      if M.pending_request then M.pending_request = nil end
    end
  end

  M.current_request = { prefix = prefix, suffix = suffix, on_token = on_token, on_done = on_done }

  local cancel_fn = M.make_request(prefix, suffix, on_token, function(completion)
    local has_pending = M.pending_request ~= nil
    M.current_request = nil
    if has_pending then
      local pending = M.pending_request
      M.pending_request = nil
      M.queue_request(pending.prefix, pending.suffix, pending.on_token, pending.on_done)
    else
      on_done(completion)
    end
  end)

  M.current_request.cancel = cancel_fn

  return function()
    if M.current_request and M.current_request.cancel then
      M.current_request.cancel()
      M.current_request = nil
    end
    if M.pending_request then M.pending_request = nil end
  end
end

--- Cancel all pending requests
function M.cancel_all()
  if M.current_request and M.current_request.cancel then
    M.current_request.cancel()
    M.current_request = nil
  end
  if M.pending_request then M.pending_request = nil end
end

--- Check if Ollama is available
-- @param callback fun(available: boolean, version: string|nil)
function M.check_availability(callback)
  local url = get_base_url() .. "/api/tags"
  log:debug("Checking Ollama at " .. url)

  http_request("GET", url, nil, nil, function(err, body)
    if err then
      log:error("Ollama health check failed: " .. err)
      callback(false, nil)
      return
    end
    local ok, data = pcall(vim.json.decode, body or "")
    if ok and data then
      callback(true, data.version)
    else
      callback(true, nil)
    end
  end)
end

return M

---Ollama HTTP transport layer
---@class OllamaHttp
local M = {}

---Resolve hostname to IP address
---@param hostname string
---@return string|nil ip
local function resolve_host(hostname)
  -- Already a numeric IP
  if hostname:match("^%d+%.%d+%.%d+%.%d+$") then
    return hostname
  end
  local res = vim.uv.getaddrinfo(hostname, nil, { family = "inet", socktype = "stream" })
  if res and res[1] and res[1].addr then
    return res[1].addr
  end
  return nil
end

---Parse URL into components
---@param endpoint string
---@return string|nil ip, integer|nil port, string|nil path, string|nil host_port, string|nil err_error
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
  local host, port
  if colon then
    host = host_port:sub(1, colon - 1)
    port = tonumber(host_port:sub(colon + 1)) or 11434
  else
    host = host_port
    port = 11434
  end
  local ip = resolve_host(host)
  if not ip then
    return nil, nil, nil, nil, "Could not resolve hostname: " .. host
  end
  return ip, port, path, host_port, nil
end

---Make an HTTP request to Ollama
---@param method string HTTP method
---@param url string Full URL
---@param body string|nil Request body
---@param on_token fun(token: string, accumulated: string)|nil Token callback for streaming
---@param on_done fun(err: string|nil, full_text: string) Completion callback
---@return function Cancel function
local function http_request(method, url, body, on_token, on_done)
  local ip, port, path, host_port, parse_err = parse_url(url)
  if parse_err then
    vim.schedule(function()
      on_done(parse_err, "")
    end)
    return function() end
  end
  local tcp = vim.uv.new_tcp()
  local cancelled = false
  local accumulated = ""
  local body_buffer = ""
  local headers_parsed = false
  local header_buf = ""
  local is_chunked = false
  local chunk_buffer = ""

  ---@param err string|nil
  local function finish(err)
    if cancelled then
      return
    end
    cancelled = true
    if tcp and not tcp:is_closing() then
      tcp:close()
    end
    vim.schedule(function()
      on_done(err, accumulated)
    end)
  end

  ---@param trimmed string
  local function process_json_object(trimmed)
    if cancelled then
      return
    end

    local ok, data = pcall(vim.json.decode, trimmed)
    if not ok or type(data) ~= "table" then
      return
    end

    if data.error then
      finish("Ollama error: " .. data.error)
      return
    end

    local token = data.response or (data.message and data.message.content) or ""
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
      if not nl then
        break
      end
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
      if not crlf then
        return
      end
      local size_str = chunk_buffer:sub(1, crlf - 1)
      local chunk_size = tonumber(size_str, 16)
      if not chunk_size then
        return
      end
      if chunk_size == 0 then
        finish(nil)
        return
      end
      local chunk_start = crlf + 2
      local chunk_end = chunk_start + chunk_size - 1
      if #chunk_buffer < chunk_end + 2 then
        return
      end
      local chunk_data = chunk_buffer:sub(chunk_start, chunk_end)
      chunk_buffer = chunk_buffer:sub(chunk_end + 3)
      body_buffer = body_buffer .. chunk_data
    end
  end

  ---@param raw_data string
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

---Make a GET request
---@param url string
---@param on_done fun(err: string|nil, body: string)
---@return function Cancel function
function M.get(url, on_done)
  return http_request("GET", url, nil, nil, on_done)
end

---Make a POST request with streaming
---@param url string
---@param body table Request body (will be JSON encoded)
---@param on_token fun(token: string, accumulated: string)|nil
---@param on_done fun(err: string|nil, full_text: string)
---@return function Cancel function
function M.post_stream(url, body, on_token, on_done)
  local body_json = vim.json.encode(body)
  return http_request("POST", url, body_json, on_token, on_done)
end

---Make a POST request without streaming
---@param url string
---@param body table Request body
---@param on_done fun(err: string|nil, full_text: string)
---@return function Cancel function
function M.post(url, body, on_done)
  return http_request("POST", url, vim.json.encode(body), nil, on_done)
end

return M

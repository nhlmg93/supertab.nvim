---Ollama client implementation
---@class OllamaClient
---@field name string
---@field available boolean
---@field version string|nil
local OllamaClient = {
  name = "ollama",
  available = false,
  version = nil,
}

local clients = require("supertab.clients")
local config = require("supertab.config")
local log = require("supertab.logger")
local http = require("supertab.clients.ollama.http")

---@type {prefix: string, suffix: string, on_token: function, on_done: function, cancel: function}|nil
local current_request = nil

---@type table|nil
local pending_request = nil

---Get Ollama config
---@return table|nil
local function get_ollama_config()
  return config.get_client_config("ollama")
end

---Get base URL from config
---@return string
local function get_base_url()
  local ollama_config = get_ollama_config()
  return ollama_config and ollama_config.host or "http://127.0.0.1:11434"
end

---Build request body for completion
---@param prefix string
---@param suffix string
---@return table
function OllamaClient.build_request_body(prefix, suffix)
  local ollama_config = get_ollama_config()
  return {
    model = (ollama_config and ollama_config.model) or "codellama",
    stream = true,
    think = false,
    prompt = prefix,
    suffix = suffix,
    options = {
      temperature = (ollama_config and ollama_config.temperature) or 0.2,
      top_p = (ollama_config and ollama_config.top_p) or 0.9,
      top_k = (ollama_config and ollama_config.top_k) or 40,
      num_predict = (ollama_config and ollama_config.max_tokens) or 64,
    },
  }
end

---Build request body for doc snippet generation
---@param prompt string
---@return table
function OllamaClient.build_doc_request_body(prompt)
  local ollama_config = get_ollama_config()
  local max_tokens = (ollama_config and ollama_config.doc_max_tokens) or 512
  local system = "You write code examples. Rules:\n"
    .. "- Output ONLY code, nothing else\n"
    .. "- First line must be code, not a comment\n"
    .. "- Short inline comments only on non-obvious lines\n"
    .. "- No introductions, no summaries, no markdown\n"
    .. "- Max "
    .. max_tokens
    .. " tokens"
  return {
    model = (ollama_config and ollama_config.model) or "codellama",
    stream = true,
    think = false,
    messages = {
      { role = "system", content = system },
      { role = "user", content = prompt },
    },
    options = {
      temperature = (ollama_config and ollama_config.temperature) or 0.2,
      top_p = (ollama_config and ollama_config.top_p) or 0.9,
      top_k = (ollama_config and ollama_config.top_k) or 40,
      num_predict = max_tokens,
    },
  }
end

---Check if Ollama is available
---@param callback fun(available: boolean, version: string|nil)
function OllamaClient.check_availability(callback)
  local url = get_base_url() .. "/api/tags"
  log:debug("Checking Ollama at " .. url)

  http.get(url, function(err, body)
    if err then
      log:error("Ollama health check failed: " .. err)
      OllamaClient.available = false
      callback(false, nil)
      return
    end
    local ok, data = pcall(vim.json.decode, body or "")
    if ok and data then
      OllamaClient.available = true
      OllamaClient.version = data.version
      callback(true, data.version)
    else
      OllamaClient.available = true
      callback(true, nil)
    end
  end)
end

---Make a completion request
---@param prefix string
---@param suffix string
---@param on_token fun(token: string, accumulated: string)
---@param on_done fun(completion: string)
---@return function Cancel function
function OllamaClient.make_request(prefix, suffix, on_token, on_done)
  local url = get_base_url() .. "/api/generate"
  local body = OllamaClient.build_request_body(prefix, suffix)

  log:debug("Ollama streaming request to " .. url)

  return http.post_stream(url, body, on_token, function(err, full_text)
    if err then
      log:error("Ollama request failed: " .. err)
      on_done("")
      return
    end
    -- Clean up markdown code blocks
    full_text = full_text:gsub("^%s*```[a-zA-Z]*%s*\n", ""):gsub("\n%s*```%s*$", "")
    on_done(full_text)
  end)
end

---Make a doc generation request
---@param prompt string
---@param on_done fun(completion: string)
---@return function Cancel function
function OllamaClient.make_doc_request(prompt, on_done)
  local url = get_base_url() .. "/api/chat"
  local body = OllamaClient.build_doc_request_body(prompt)

  log:debug("Ollama doc request to " .. url .. " (model=" .. tostring(body.model) .. ")")

  return http.post_stream(url, body, nil, function(err, full_text)
    if err then
      log:error("Ollama doc request failed: " .. err)
      on_done("")
      return
    end
    full_text = full_text:gsub("^%s*```[a-zA-Z]*%s*\n", ""):gsub("\n%s*```%s*$", "")
    on_done(full_text)
  end)
end

---Queue a completion request with request deduplication
---@param prefix string
---@param suffix string
---@param on_token fun(token: string, accumulated: string)
---@param on_done fun(completion: string)
---@return function Cancel function
function OllamaClient.queue_request(prefix, suffix, on_token, on_done)
  if pending_request and pending_request.cancel then
    pending_request.cancel()
    pending_request = nil
  end

  if current_request then
    pending_request = {
      prefix = prefix,
      suffix = suffix,
      on_token = on_token,
      on_done = on_done,
      cancel = function()
        pending_request = nil
      end,
    }
    return function()
      if pending_request then
        pending_request = nil
      end
    end
  end

  current_request = {
    prefix = prefix,
    suffix = suffix,
    on_token = on_token,
    on_done = on_done,
  }

  local cancel_fn = OllamaClient.make_request(prefix, suffix, on_token, function(completion)
    local has_pending = pending_request ~= nil
    current_request = nil
    if has_pending then
      local pending = pending_request
      pending_request = nil
      OllamaClient.queue_request(pending.prefix, pending.suffix, pending.on_token, pending.on_done)
    else
      on_done(completion)
    end
  end)

  current_request.cancel = cancel_fn

  return function()
    if current_request and current_request.cancel then
      current_request.cancel()
      current_request = nil
    end
    if pending_request then
      pending_request = nil
    end
  end
end

---Client interface entrypoint for streaming completion.
---@param prefix string
---@param suffix string
---@param _ctx table
---@param on_token fun(token: string, accumulated: string)
---@param on_done fun(completion: string)
---@return function Cancel function
function OllamaClient.complete(prefix, suffix, _ctx, on_token, on_done)
  return OllamaClient.queue_request(prefix, suffix, on_token, on_done)
end

---Cancel all pending requests
function OllamaClient.cancel_all()
  if current_request and current_request.cancel then
    current_request.cancel()
    current_request = nil
  end
  if pending_request then
    pending_request = nil
  end
end

---Get active completion request
---@return table|nil
function OllamaClient.get_current_request()
  return current_request
end

---Get pending request
---@return table|nil
function OllamaClient.get_pending_request()
  return pending_request
end

-- Auto-register with client registry
clients.register(OllamaClient)

return OllamaClient

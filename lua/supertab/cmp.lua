local CompletionPreview = require("supertab.completion_preview")
local util = require("supertab.util")

local loop = util.uv

---@class SupertabCmpSource
---@field client any
---@field timer userdata
---@field executions table
local source = {
  executions = {},
}

---@param text string
---@return string
local function label_text(text)
  local function shorten(str)
    local short_prefix = string.sub(str, 1, 20)
    local short_suffix = string.sub(str, string.len(str) - 15, string.len(str))
    return short_prefix .. " ... " .. short_suffix
  end

  text = text:gsub("^%s*", "")
  return string.len(text) > 40 and shorten(text) or text
end

function source.get_trigger_characters()
  return { "*" }
end

function source.get_keyword_pattern()
  return "."
end

function source.is_available()
  return true
end

---@param completion_item table
---@param callback function
function source:resolve(completion_item, callback)
  for _, fn in ipairs(self.executions) do
    completion_item = fn(completion_item)
  end
  callback(completion_item)
end

---@param completion_item table
---@param callback function
function source:execute(completion_item, callback)
  CompletionPreview:dispose_inlay()
  callback(completion_item)
end

---@param params table
---@param callback function
function source:complete(params, callback)
  local inlay_instance = CompletionPreview:get_inlay_instance()

  if inlay_instance == nil or inlay_instance.is_active == false then
    callback({
      isIncomplete = true,
      items = {},
    })
    return
  end

  local context = params.context
  local cursor = context.cursor

  local completion_text = inlay_instance.line_before_cursor .. inlay_instance.completion_text
  local split = vim.split(completion_text, "\n", { plain = true })
  local label = label_text(split[1])

  local insertTextFormat = 1 -- cmp.lsp.InsertTextFormat.PlainText
  if #split > 1 then
    insertTextFormat = 2 -- cmp.lsp.InsertTextFormat.Snippet
  end

  local range = {
    start = {
      line = cursor.line,
      character = math.max(cursor.col - inlay_instance.prior_delete - #inlay_instance.line_before_cursor - 1, 0),
    },
    ["end"] = {
      line = cursor.line,
      character = vim.fn.col("$") - 1,
    },
  }

  local items = {
    {
      label = label,
      kind = 1,
      score = 100,
      filterText = nil,
      insertTextFormat = insertTextFormat,
      cmp = {
        kind_hl_group = "CmpItemKindSupertab",
        kind_text = "Supertab",
      },
      textEdit = {
        newText = completion_text,
        insert = range,
        replace = range,
      },
      documentation = {
        kind = "markdown",
        value = "```" .. vim.bo.filetype .. "\n" .. completion_text .. "\n```",
      },
      dup = 0,
    },
  }

  callback({
    isIncomplete = false,
    items = items,
  })
end

---@param client? any
---@param opts? table
---@return SupertabCmpSource
function source.new(client, opts)
  local self = setmetatable({
    timer = loop.new_timer(),
    client = client,
    opts = opts,
    executions = {},
  }, { __index = source })

  return self
end

return source

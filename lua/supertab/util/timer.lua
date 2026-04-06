---@class SupertabTimer
---@field timer userdata|nil
---@field callback fun()
---@field delay_ms number
local Timer = {}
Timer.__index = Timer

---Create a new Timer instance
---@param delay_ms number Delay in milliseconds
---@param callback fun() Callback to execute
---@return SupertabTimer
function Timer.new(delay_ms, callback)
  local self = setmetatable({
    timer = vim.uv.new_timer(),
    delay_ms = delay_ms,
    callback = callback,
  }, Timer)
  return self
end

---Start or restart the timer
function Timer:start()
  self:stop()
  self.timer:start(
    self.delay_ms,
    0,
    vim.schedule_wrap(function()
      if self.callback then
        self.callback()
      end
    end)
  )
end

---Stop the timer
function Timer:stop()
  if self.timer and self.timer:is_active() then
    self.timer:stop()
  end
end

---Close and dispose the timer
function Timer:close()
  self:stop()
  if self.timer then
    self.timer:close()
    self.timer = nil
  end
end

---@class SupertabDebouncer
---@field timer userdata|nil
---@field delay_ms number
---@field pending fun():boolean
local Debouncer = {}
Debouncer.__index = Debouncer

---Create a new Debouncer
---@param delay_ms number Delay in milliseconds
---@param callback fun() Callback to execute after delay
---@return SupertabDebouncer
function Debouncer.new(delay_ms, callback)
  local timer = vim.uv.new_timer()
  local wrapped_callback = vim.schedule_wrap(function()
    callback()
  end)

  local self = setmetatable({
    timer = timer,
    delay_ms = delay_ms,
    _callback = wrapped_callback,
  }, Debouncer)

  return self
end

---Debounce: reset timer on each call, execute once after delay
function Debouncer:debounce()
  self:stop()
  self.timer:start(self.delay_ms, 0, function()
    self:_callback()
  end)
end

---Stop the debouncer
function Debouncer:stop()
  if self.timer and self.timer:is_active() then
    self.timer:stop()
  end
end

---Close the debouncer
function Debouncer:close()
  self:stop()
  if self.timer then
    self.timer:close()
    self.timer = nil
  end
end

---@class SupertabThrottler
---@field timer userdata|nil
---@field delay_ms number
---@field last_execution number
---@field pending boolean
local Throttler = {}
Throttler.__index = Throttler

---Create a new Throttler
---@param delay_ms number Minimum delay between executions
---@param callback fun() Callback to execute
---@return SupertabThrottler
function Throttler.new(delay_ms, callback)
  local self = setmetatable({
    timer = vim.uv.new_timer(),
    delay_ms = delay_ms,
    last_execution = 0,
    _callback = callback,
  }, Throttler)
  return self
end

---Throttle: execute callback if enough time has passed, otherwise schedule for later
function Throttler:throttle()
  local now = vim.uv.now()
  local elapsed = now - self.last_execution

  if elapsed >= self.delay_ms then
    self.last_execution = now
    vim.schedule_wrap(self._callback)()
    return
  end

  if self.timer and self.timer:is_active() then
    return
  end

  local remaining = self.delay_ms - elapsed
  self.timer:start(
    remaining,
    0,
    vim.schedule_wrap(function()
      self.last_execution = vim.uv.now()
      self:_callback()
    end)
  )
end

---Stop the throttler
function Throttler:stop()
  if self.timer and self.timer:is_active() then
    self.timer:stop()
  end
end

---Close the throttler
function Throttler:close()
  self:stop()
  if self.timer then
    self.timer:close()
    self.timer = nil
  end
end

---Module exports
local M = {
  Timer = Timer,
  Debouncer = Debouncer,
  Throttler = Throttler,
}

return M

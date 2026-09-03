--- opx77_chat -- the public surface: six client exports. Every call answers a table carrying
--- `ok`; `error` is a code from types.lua.

local Runtime = OpxChat.runtime

---@param ok boolean
---@param values table|nil
---@return table
local function response(ok, values)
  values = values or {}
  values.ok = ok == true
  return values
end

--- The invoking resource, read from the host so a caller cannot claim to be another one.
---@return string|nil
local function caller()
  local owner = GetInvokingResource()
  if type(owner) ~= "string" or owner == "" or #owner > 64 or
    owner:match("^[%w_%-%.]+$") == nil then
    return nil
  end
  return owner
end

--- The refusal every export starts with: there is no invoking resource.
---@return table|nil
local function nobody()
  if caller() == nil then return response(false, { error = "export_call_required" }) end
  return nil
end

--- The second refusal, for the exports that put something on the page.
---@return table|nil
local function noPage()
  local exists, ready = Runtime.surface()
  if not exists then return response(false, { error = "no_surface" }) end
  if not ready then return response(false, { error = "page_not_ready" }) end
  return nil
end

--- Put one line in this player's box. Local only: it renders here and travels nowhere.
---@param message ChatMessage|string  a bare string is taken as `{ text = message }`
---@return ChatResponse
exports("addMessage", function(message)
  local refused = nobody() or noPage()
  if refused then return refused end
  if not Runtime.addMessage(message) then
    return response(false, { error = "invalid_message" })
  end
  return response(true, {})
end)

--- Empty the visible log, leaving the suggestions alone.
---@return ChatResponse
exports("clearMessages", function()
  local refused = nobody() or noPage()
  if refused then return refused end
  Runtime.clearMessages()
  return response(true, {})
end)

--- Add or replace the completion entry for one slash command.
---@param command string  with or without the leading slash; `"heal"` and `"/heal"` are one entry
---@param help string|nil  the one-line description shown beside the name
---@param parameters ChatSuggestionParameter[]|nil
---@return ChatResponse
exports("addSuggestion", function(command, help, parameters)
  local refused = nobody() or noPage()
  if refused then return refused end
  local name = tostring(command or "")
  if name == "" then return response(false, { error = "invalid_command" }) end
  Runtime.addSuggestion(name, help, parameters)
  return response(true, {})
end)

--- Take one completion entry back down. Removing what was never added is `ok`.
---@param command string
---@return ChatResponse
exports("removeSuggestion", function(command)
  local refused = nobody() or noPage()
  if refused then return refused end
  local name = tostring(command or "")
  if name == "" then return response(false, { error = "invalid_command" }) end
  Runtime.removeSuggestion(name)
  return response(true, {})
end)

--- Turn the box off, or back on. Disabling closes it if it is open. No page check: the flag is
--- real state before the surface exists.
---@param value any  anything but `false` enables
---@return ChatEnabledState
exports("setEnabled", function(value)
  return nobody() or response(true, { enabled = Runtime.setEnabled(value) })
end)

--- Whether the box is on.
---@return ChatEnabledState
exports("isEnabled", function()
  return nobody() or response(true, { enabled = Runtime.isEnabled() })
end)

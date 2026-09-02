--- opx77_chat -- the public surface.
---
--- These are the six names the platform documents on its own `open77_chat` package
--- (`resource-exports.md`): `addMessage`, `clear`, `addSuggestion`, `removeSuggestion`,
--- `setEnabled`, `isEnabled`. Same arguments, same message schema, same ownership rule --
--- `enabled` is one flag for the whole box, not one per caller -- so third-party code written
--- against the documented chat surface works against this resource without a change.
---
--- Client-side, because that is the only side exports exist on: the server runtime installs
--- none. A server resource that wants to put a line in one player's box sends `chat:addMessage`
--- to them, which is what the net-event half of client/main.lua is for.
---
--- Every call answers a table carrying `ok` and never raises, which is this framework's
--- convention and opx77_core's. The official package returns bare booleans instead; a caller
--- that only tests truthiness reads `{ ok = true }` as true either way, and one that wants the
--- reason now has it. `error` is a stable snake_case code meant for branching:
---   export_call_required  called from inside this resource, or without the export machinery --
---                         there is no invoking resource to attribute the call to
---   no_surface            WebUI.create failed at start; there is no box and never will be
---   page_not_ready        the surface exists but has not raised `chat:ready` yet; try again
---   invalid_message       not a string and not a table
---   invalid_command       an empty command name, which the page would silently drop

local Runtime = OpxChat.runtime

---@param ok boolean
---@param values table|nil
---@return table
local function response(ok, values)
  values = values or {}
  values.ok = ok == true
  return values
end

--- Who is calling. From the host, never from an argument: a caller cannot claim to be another
--- resource. Nothing inside this VM should be reaching the public surface -- the local
--- functions are right there -- so a call with no invoking resource is a call that went
--- somewhere it did not mean to.
---@return string|nil
local function caller()
  local owner = GetInvokingResource()
  if type(owner) ~= "string" or owner == "" or #owner > 64 or
    owner:match("^[%w_%-%.]+$") == nil then
    return nil
  end
  return owner
end

--- The refusal every export starts with.
---@return table|nil
local function nobody()
  if caller() == nil then return response(false, { error = "export_call_required" }) end
  return nil
end

--- The second refusal, for the four exports that put something on the page. `send` in
--- client/main.lua drops the payload silently when the surface is missing or still starting;
--- answering `ok` for a message that went nowhere would be the one lie this file can tell.
---@return table|nil
local function noPage()
  local exists, ready = Runtime.surface()
  if not exists then return response(false, { error = "no_surface" }) end
  if not ready then return response(false, { error = "page_not_ready" }) end
  return nil
end

--- Put one line in this player's box. Local only: it renders here and travels nowhere, so a
--- resource that wants everyone to see it says so on the server.
---@param message table|string  a bare string is taken as `{ text = message }`
---@return table
exports("addMessage", function(message)
  local refused = nobody() or noPage()
  if refused then return refused end
  if not Runtime.addMessage(message) then
    return response(false, { error = "invalid_message" })
  end
  return response(true, {})
end)

--- Empty the visible log. Suggestions are a separate list and are left alone, which is what
--- the official package does too.
---@return table
exports("clear", function()
  local refused = nobody() or noPage()
  if refused then return refused end
  Runtime.clear()
  return response(true, {})
end)

--- Add or replace the completion entry for one slash command. The page keys them by name and
--- adds the leading slash itself, so `"heal"` and `"/heal"` are the same entry.
---@param command string
---@param help string|nil  the one-line description shown beside the name
---@param parameters table|nil  a list of `{ name = ..., help = ... }`
---@return table
exports("addSuggestion", function(command, help, parameters)
  local refused = nobody() or noPage()
  if refused then return refused end
  if tostring(command or "") == "" then
    return response(false, { error = "invalid_command" })
  end
  Runtime.addSuggestion(command, help, parameters)
  return response(true, {})
end)

--- Take one completion entry back down. Removing what was never added is `ok`: the page keys
--- by name, so there is nothing to be wrong about.
---@param command string
---@return table
exports("removeSuggestion", function(command)
  local refused = nobody() or noPage()
  if refused then return refused end
  if tostring(command or "") == "" then
    return response(false, { error = "invalid_command" })
  end
  Runtime.removeSuggestion(command)
  return response(true, {})
end)

--- Turn the box off, or back on. Disabling closes it if it is open, and the open key then
--- refuses with a logged line rather than silently doing nothing. No page check: the flag is
--- real state whether or not there is a surface to draw it on, and a gamemode that disables
--- the chat during a cutscene has to be able to do it before the page has loaded.
---@param value any  anything but `false` enables
---@return table ok and the state it now holds
exports("setEnabled", function(value)
  return nobody() or response(true, { enabled = Runtime.setEnabled(value) })
end)

---@return table ok and the current state
exports("isEnabled", function()
  return nobody() or response(true, { enabled = Runtime.isEnabled() })
end)

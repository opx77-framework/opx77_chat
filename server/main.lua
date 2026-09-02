--- opx77_chat -- the server half: it relays a message, and nothing else.
---
--- Commands do NOT come through here. The client sends `open77:command:execute` straight to
--- the host's authenticated dispatcher, which resolves `command.<name>` against the caller's
--- ACL before any Lua runs. A relay written here would be a second, weaker gate.

local Config = OPX_CHAT_CONFIG

--- player -> when they last said something, for the floor between two messages.
local lastSaidMs = {}

---@return integer
local function nowMs()
  return math.floor(Open77.time.monotonic() * 1000)
end

--- Truncate and strip control characters. Everything here came off the wire: a newline in a
--- message would forge a line in the box, and 48 KiB of them is every client's memory.
---@param value any
---@return string
local function clean(value)
  local text = tostring(value or ""):gsub("[%c]", " ")
  if #text > Config.MAX_LENGTH then text = text:sub(1, Config.MAX_LENGTH) .. "..." end
  return text
end

--- A player said something. Relayed to everyone, attributed to the connection that sent it --
--- never to a name in the payload.
RegisterNetEvent("chat:submit", function(text)
  -- `source` inside a net event handler is the authenticated connection (platform convention
  -- 2: convert it). A client cannot speak as somebody else.
  local player = tonumber(source) or 0
  if player <= 0 then return end

  local said = clean(text)
  if said:match("^%s*$") then return end

  local at = nowMs()
  local previous = lastSaidMs[player]
  if previous ~= nil and at - previous < Config.RATE_MS then return end
  lastSaidMs[player] = at

  local name = Open77.players.name and Open77.players.name(player) or nil
  TriggerClientEvent("chat:addMessage", -1, {
    type = "chat",
    -- the display name is player-changeable, so it is a LABEL and never an identity
    author = clean(name or ("player " .. player)),
    text = said,
  })
end)

--- Both departure events, because the platform raises two and documents neither.
---@param playerId any
local function forget(playerId)
  lastSaidMs[tonumber(playerId) or tonumber(source) or -1] = nil
end

--- `onPlayerDisconnected` is the only departure event this platform raises. There used to
--- be a `playerDropped` handler beside it: that name occurs in the shipped server binary
--- only inside the platform's own embedded Lua bootstrap, which registers a handler that
--- nothing ever fires. A second handler here was dead code that made the cleanup look
--- doubly covered.
AddEventHandler("onPlayerDisconnected", forget)

--- Warns once if the official package this one replaces is also running. `GetResourceState`
--- is the only way to ask: server resources cannot call each other. Deferred to a thread
--- rather than run at file scope, because at load time a conflicting resource listed after
--- this one in `resources.load` is still `discovered` and the warning would silently not
--- fire -- which would make it depend on load order, the one thing an operator did not
--- choose. The host answers lowercase; `:lower()` costs nothing and survives it changing.
CreateThread(function()
  local official = tostring(GetResourceState("open77_chat") or ""):lower()
  if official ~= "running" and official ~= "starting" then return end
  Open77.log.warn("open77_chat is running and is the package this one replaces")
  Open77.log.warn("  both draw their own chat box, both answer chat:addMessage and both take")
  Open77.log.warn("  focus on the open key, so every message is rendered twice. Drop one from")
  Open77.log.warn("  resources.load in server.jsonc.")
end)

Open77.log.info("ready")

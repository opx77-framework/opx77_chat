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

AddEventHandler("onPlayerDisconnected", forget)
AddEventHandler("playerDropped", forget)

Open77.log.info("ready")

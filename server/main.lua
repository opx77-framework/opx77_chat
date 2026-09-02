--- opx77_chat -- the server half: it relays a message, and nothing else.
---
--- Commands do not come through here: the client sends `open77:command:execute` straight to the
--- host's ACL-checked dispatcher, and a relay written here would be a second, weaker gate.

local Config = OPX_CHAT_CONFIG

--- player -> when they last said something, for the floor between two messages.
local lastSaidMs = {}

---@return integer
local function nowMs()
  return math.floor(Open77.time.monotonic() * 1000)
end

--- Sanitise one line off the wire: control characters out, length capped. A newline would forge
--- a line in every client's box, and an uncapped one is every client's memory.
---@param value any
---@return string
local function clean(value)
  local text = tostring(value or ""):gsub("[%c]", " ")
  if #text > Config.MAX_LENGTH then
    local cut = Config.MAX_LENGTH
    -- MAX_LENGTH counts bytes: back a cut that landed inside a UTF-8 sequence off the sequence
    while cut > 0 and text:byte(cut + 1) >= 0x80 and text:byte(cut + 1) < 0xC0 do
      cut = cut - 1
    end
    text = text:sub(1, cut) .. "..."
  end
  return text
end

--- A player said something. Relayed to everyone, attributed to the connection that sent it.
RegisterNetEvent("chat:submit", function(text)
  -- `source` is the authenticated connection, so a client cannot speak as somebody else.
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
    author = clean(name or locale("chat.author.unknown", { id = player })),
    text = said,
  })
end)

--- Drop a departed player's rate-limit entry.
---@param playerId any
local function forget(playerId)
  lastSaidMs[tonumber(playerId) or tonumber(source) or -1] = nil
end

AddEventHandler("onPlayerDisconnected", forget)

--- Warns once if the official package this one replaces is also running. Deferred to a thread so
--- the check does not depend on load order.
CreateThread(function()
  local official = tostring(GetResourceState("open77_chat") or ""):lower()
  if official ~= "running" and official ~= "starting" then return end
  Open77.log.warn("open77_chat is running and is the package this one replaces")
  Open77.log.warn("  both draw their own chat box, both answer chat:addMessage and both take")
  Open77.log.warn("  focus on the open key, so every message is rendered twice. Drop one from")
  Open77.log.warn("  resources.load in server.jsonc.")
end)

Open77.log.info("ready")

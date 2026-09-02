--- opx77_chat -- the server half: it relays a message, and nothing else.

local Config = OPX_CHAT_CONFIG
local Text = OpxChat.Text

--- player -> when they last said something, for the floor between two messages.
local lastSaidMs = {}

--- The scheduler clock in milliseconds; `monotonic` answers SECONDS. A non-finite reading is
--- dropped rather than propagated: a NaN would expire nothing, an infinity everything.
---@return integer
local lastMs = 0
local function nowMs()
  local read, seconds = pcall(Open77.time.monotonic)
  if read and type(seconds) == "number" and seconds == seconds and
    seconds >= 0 and seconds < math.huge then
    lastMs = math.floor(seconds * 1000)
  end
  return lastMs
end

local function clean(value)
  return Text.clean(value, Config.MAX_LENGTH, "...") or ""
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
---@param playerId number|string|nil
local function forget(playerId)
  lastSaidMs[tonumber(playerId) or tonumber(source) or -1] = nil
end

-- the only departure event this platform raises
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

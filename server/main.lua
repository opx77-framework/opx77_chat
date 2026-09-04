--- opx77_chat -- the server half: it relays a message, and nothing else.

local Config = OPX_CHAT_CONFIG
local Text = OpxChat.Text

--- player -> when they last said something, for the floor between two messages.
local lastSaidMs = {}

--- The scheduler clock in milliseconds; `monotonic` answers SECONDS. A non-finite reading is
--- dropped rather than propagated: a NaN would expire nothing, an infinity everything.
---
--- The fallback matters more here than the guard does. `lastSaidMs` is compared against this
--- clock, so a frozen one makes `at - previous` zero for anybody who has already spoken --
--- which is below any rate, so every message they send from then on is dropped in silence,
--- for the rest of the process. `GetGameTimer` is the same scheduler clock in milliseconds.
---@return integer
local lastMs = 0
local clockWarned = false
local function nowMs()
  local read, seconds = pcall(Open77.time.monotonic)
  if read and type(seconds) == "number" and seconds == seconds and
    seconds >= 0 and seconds < math.huge then
    lastMs = math.floor(seconds * 1000)
    return lastMs
  end
  local ticked, ms = pcall(GetGameTimer)
  if ticked and type(ms) == "number" and ms == ms and ms >= 0 and ms < math.huge then
    if not clockWarned then
      clockWarned = true
      Open77.log.warn("Open77.time.monotonic unreadable; falling back to GetGameTimer")
    end
    lastMs = math.floor(ms)
  end
  return lastMs
end

local function clean(value)
  return Text.clean(value, Config.MAX_LENGTH, "...") or ""
end

--- What the host will vouch for about the connection, or nil when it vouches for nothing.
--- One call answers both the label to print and the account id to fall back on; no
--- permission is needed for either.
---@param player integer
---@return PlayerIdentity|nil
local function identityOf(player)
  local players = Open77.players
  if type(players) ~= "table" or type(players.identity) ~= "function" then return nil end
  local read, identity = pcall(players.identity, player)
  if not read or type(identity) ~= "table" then return nil end
  return identity
end

--- A player said something. Relayed to everyone, attributed to the connection that sent it.
RegisterNetEvent("chat:submit", function(text)
  -- `source` is the authenticated connection, so a client cannot speak as somebody else.
  local player = tonumber(source) or 0
  if player <= 0 then return end

  -- the floor is checked before the text is cleaned: a flood must not buy a scan per packet
  local at = nowMs()
  local previous = lastSaidMs[player]
  if previous ~= nil and at - previous < Config.RATE_MS then return end

  -- the floor moves for a message that was REFUSED as well as one that was relayed.
  -- Recording it only after the blank check meant a flood of whitespace never advanced it,
  -- so it paid a bounded scan on every packet forever -- exactly what the line above says
  -- must not happen.
  lastSaidMs[player] = at

  local said = clean(text)
  if said:match("^%s*$") then return end

  local identity = identityOf(player)
  local name = identity and identity.name
  if type(name) ~= "string" or name == "" then name = nil end
  -- the display name is player-changeable, so it is a LABEL and never an identity. When
  -- there is none, the account id says something an operator can act on; the session id it
  -- used to print means nothing to a player and nothing to anybody once they have left.
  local unknown = identity and identity.userId and identity.userId:sub(1, 8) or tostring(player)
  TriggerClientEvent("chat:addMessage", -1, {
    type = "chat",
    author = clean(name or locale("chat.author.unknown", { id = unknown })),
    text = said,
  })
end)

--- Drop a departed player's rate-limit entry.
---
--- `source` is not populated for a host-fanned event, so the old `tonumber(source)` branch
--- was dead, and the `-1` behind it wrote into a slot no player will ever have. An id that
--- will not convert is worth a line, not a phantom key.
--- The event also carries a `reason` now (`connection_closed`, or the text a disconnect,
--- kick or ban was queued with). A relay has nothing to do with it, so it is not taken.
---@param playerId any  a string, like every host event argument
local function forget(playerId)
  local player = tonumber(playerId)
  if player == nil then
    Open77.log.warn(("onPlayerDisconnected: unusable player id %q"):format(tostring(playerId)))
    return
  end
  lastSaidMs[player] = nil
end

-- the departure of an ADMITTED player. A connection refused at the door never reaches here;
-- that is `onPlayerRejected`, which this resource does not listen for.
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

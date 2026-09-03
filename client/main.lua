--- opx77_chat -- the box, and the only way a typed command reaches the server.

OpxChat = OpxChat or {}

local Config = OPX_CHAT_CONFIG

local page
local pageReady = false
local opened = false
local enabled = true

--- The fragment of the dispatcher's queue acknowledgement, verbatim from the platform:
--- `command '<name>' queued by resource <resource>`. Not a contract -- docs/unknowns.md.
local QUEUE_ACK = "' queued by resource "

--- The dispatcher takes at most this many arguments, the command name included.
local MAX_ARGUMENTS = 32

--- Split a typed command into the tokens the server's dispatcher expects, one per argument,
--- honouring quotes and backslash escapes.
---@param text string  with the leading slash
---@return CommandTokens|nil tokens  nil when the line is unusable
---@return string|nil reason  a player-facing message when tokens is nil
local function commandTokens(text)
  local line = tostring(text or ""):sub(2)
  -- one table per token, joined once: appending to a string per character is quadratic
  local tokens, buffer, quote, escaped, started = {}, {}, nil, false, false
  for index = 1, #line do
    local character = line:sub(index, index)
    if escaped then
      buffer[#buffer + 1], escaped, started = character, false, true
    elseif character == "\\" then
      escaped, started = true, true
    elseif quote ~= nil then
      if character == quote then quote = nil else buffer[#buffer + 1] = character end
      started = true
    elseif character == "\"" or character == "'" then
      quote, started = character, true
    elseif character:match("%s") then
      if started then
        tokens[#tokens + 1] = table.concat(buffer)
        buffer, started = {}, false
        if #tokens > MAX_ARGUMENTS then
          return nil, locale("chat.tooManyArgs", { max = MAX_ARGUMENTS })
        end
      end
    else
      buffer[#buffer + 1], started = character, true
    end
  end
  if escaped then return nil, locale("chat.escapeAtEnd") end
  if quote ~= nil then return nil, locale("chat.unterminatedQuote") end
  if started then
    tokens[#tokens + 1] = table.concat(buffer)
    if #tokens > MAX_ARGUMENTS then
      return nil, locale("chat.tooManyArgs", { max = MAX_ARGUMENTS })
    end
  end
  if #tokens == 0 or tokens[1] == "" then return nil, locale("chat.commandExpected") end
  return tokens
end

--- Send one payload to the page; silently dropped while there is no ready surface.
---@param channel string
---@param payload table|nil
local function send(channel, payload)
  if page ~= nil and pageReady then page:send(channel, payload or {}) end
end

--- Put one line in this player's box.
---@param message ChatMessage|string
---@return boolean
local function addMessage(message)
  if type(message) == "string" then message = { text = message } end
  if type(message) ~= "table" then return false end
  send("chat:addMessage", message)
  return true
end

--- Close the box and hand the keyboard back.
local function closeChat()
  if page == nil or not opened then return end
  opened = false
  page:setFocus(false, false)
  send("chat:close", {})
end

--- Open the box and take keyboard focus. Refusals are logged, never silent.
local function openChat()
  if page == nil then
    Open77.log.warn("open refused: the WebUI surface was never created")
    return
  end
  if not enabled then
    Open77.log.warn("open refused: the chat is disabled by the server")
    return
  end
  -- Focus before ready would capture the keyboard with the entry line still hidden; `opened`
  -- stays false so the next press succeeds once the page raises `chat:ready`.
  if not pageReady then
    Open77.log.warn("open refused: the page has not reported ready")
    return
  end
  if opened then return end
  opened = true

  -- Focus BEFORE `chat:open`: both travel one ordered pipe, so the element focus must land in
  -- a browser that already holds focus.
  if not page:setFocus(true, false) then
    Open77.log.warn("keyboard focus was refused; the box will take no text")
  end
  send("chat:open", {})
  TriggerServerEvent("chat:ready")
end

-- ---------------------------------------------------------------------------
-- What the server and other resources send
-- ---------------------------------------------------------------------------

--- Add or replace one completion entry.
---@param command any  with or without the leading slash; the page adds it
---@param help any
---@param parameters ChatSuggestionParameter[]|nil
local function addSuggestion(command, help, parameters)
  send("chat:addSuggestion", {
    command = tostring(command or ""),
    help = tostring(help or ""),
    parameters = type(parameters) == "table" and parameters or {},
  })
end

--- Take one completion entry back down.
---@param command any
local function removeSuggestion(command)
  send("chat:removeSuggestion", { command = tostring(command or "") })
end

--- Empty the visible log, leaving the suggestions alone.
local function clearMessages()
  send("chat:clear", {})
end

--- Turn the box off or back on. One flag for the whole box, not one per caller.
---@param value any  anything but `false` enables
---@return boolean enabled  the state it now holds
local function setEnabled(value)
  enabled = value ~= false
  if not enabled then closeChat() end
  send("chat:state", { enabled = enabled })
  return enabled
end

RegisterNetEvent("chat:addMessage", addMessage)
RegisterNetEvent("chat:addSuggestion", addSuggestion)

RegisterNetEvent("chat:addSuggestions", function(suggestions)
  send("chat:addSuggestions", {
    suggestions = type(suggestions) == "table" and suggestions or {},
  })
end)

RegisterNetEvent("chat:removeSuggestion", removeSuggestion)

RegisterNetEvent("chat:clearSuggestions", function() send("chat:clearSuggestions", {}) end)
RegisterNetEvent("chat:clear", clearMessages)

RegisterNetEvent("chat:setEnabled", setEnabled)

--- The dispatcher's answer to a command this player typed.
RegisterNetEvent("open77:command:result", function(raw, accepted, message)
  raw, message = tostring(raw or ""), tostring(message or "")
  -- The dispatcher acknowledges queueing before it sends the useful result; only show the
  -- latter. Matched on the platform's own English wording -- see docs/unknowns.md.
  if accepted and message:find(QUEUE_ACK, 1, true) ~= nil then return end
  addMessage({
    type = accepted and "info" or "error",
    author = locale("chat.author.command"),
    text = message ~= "" and message or raw,
    color = accepted and { 120, 220, 232 } or { 255, 76, 92 },
  })
end)

-- The host raises this when the player presses the chat key; there is no binding of our own.
AddEventHandler("open77:chat:open", openChat)
AddEventHandler("chat:open", openChat)
AddEventHandler("chat:close", closeChat)

-- ---------------------------------------------------------------------------
-- What the public surface is allowed to reach
-- ---------------------------------------------------------------------------

--- What client/exports.lua may call. The key, the focus and the command parser stay private.
OpxChat.runtime = {
  addMessage = addMessage,
  clearMessages = clearMessages,
  addSuggestion = addSuggestion,
  removeSuggestion = removeSuggestion,
  setEnabled = setEnabled,
  isEnabled = function() return enabled end,
  --- Whether a call would actually land on the page.
  ---@return boolean surfaceExists
  ---@return boolean ready
  surface = function() return page ~= nil, pageReady end,
}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

AddEventHandler("onClientResourceStart", function(name)
  if name ~= GetCurrentResourceName() then return end

  local reason
  page, reason = WebUI.create({
    entry = "web/index.html",
    -- "hud", not "menu": the box takes focus explicitly and only while it is open
    layer = "hud",
    width = 1920,
    height = 1080,
    fps = 60,
    -- 700 draws below opx77_hud (705), the toasts (720) and opx77_menu (725)
    zIndex = 700,
    transparent = true,
    -- created visible: a surface created hidden never uploads a frame once shown
    visible = true,
  })
  if page == nil then
    Open77.log.error("WebUI surface failed: " .. tostring(reason))
    Open77.log.error("  no command typed in chat will reach the server.")
    return
  end

  page:on("chat:ready", function()
    pageReady = true
    send("chat:config", {
      anchor = Config.ANCHOR,
      width = Config.WIDTH,
      history = Config.HISTORY,
      fadeMs = Config.FADE_MS,
      maxLength = Config.MAX_LENGTH,
      placeholder = locale("chat.placeholder"),
    })
    -- ask every resource for its suggestions now that there is somewhere to put them
    TriggerServerEvent("chat:ready")
  end)

  page:on("chat:submit", function(payload)
    local text = type(payload) == "table" and tostring(payload.text or "") or ""
    if #text > 0 then
      if text:sub(1, 1) == "/" then
        local tokens, failure = commandTokens(text)
        if tokens == nil then
          addMessage({ type = "error", author = locale("chat.author.command"),
                       text = failure, color = { 255, 76, 92 } })
          closeChat()
          return
        end
        TriggerEvent("chat:commandSubmitted", text, tokens)
        local sent, why = TriggerServerEvent("open77:command:execute", table.unpack(tokens))
        if not sent then
          Open77.log.warn("command not sent: " .. tostring(why))
          addMessage({ type = "error", author = locale("chat.author.network"),
                       text = locale("chat.commandNotSent"), color = { 255, 76, 92 } })
        end
      else
        local sent, why = TriggerServerEvent("chat:submit", text)
        if not sent then
          Open77.log.warn("message not sent: " .. tostring(why))
          addMessage({ type = "error", author = locale("chat.author.network"),
                       text = locale("chat.messageNotSent"), color = { 255, 76, 92 } })
        end
      end
    end
    closeChat()
  end)

  page:on("chat:close", closeChat)

  page:on("chat:diag", function(payload)
    if type(payload) ~= "table" then return end
    Open77.log.info("page: " .. tostring(payload.text or ""))
  end)
end)

AddEventHandler("onClientResourceStop", function(name)
  if name ~= GetCurrentResourceName() then return end
  -- Hand the keyboard back before the page handle goes: focus held over a stop leaves the
  -- player unable to move.
  closeChat()
  page, pageReady, opened = nil, false, false
end)

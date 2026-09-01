--- opx77_chat -- the box, and the only way a typed command reaches the server.
---
--- The host owns the open key: it raises `open77:chat:open` when the player presses it, and
--- this file has no binding of its own. Everything else is the platform's published contract
--- -- `chat:addMessage`, `chat:addSuggestion(s)`, `open77:command:execute` and
--- `open77:command:result` -- which every resource on the server already speaks.

OpxChat = OpxChat or {}

local Config = OPX_CHAT_CONFIG

local page
local pageReady = false
local opened = false
local enabled = true

--- The command tokens the server's dispatcher expects: one string per argument, quotes and
--- backslashes honoured. The transport caps a line at 32 tokens, so this refuses at 32 rather
--- than sending a line the host will drop.
---@param text string  with the leading slash
---@return table|nil tokens, string|nil reason
local function commandTokens(text)
  local source = tostring(text or ""):sub(2)
  local tokens, token, quote, escaped, started = {}, "", nil, false, false
  for index = 1, #source do
    local character = source:sub(index, index)
    if escaped then
      token, escaped, started = token .. character, false, true
    elseif character == "\\" then
      escaped, started = true, true
    elseif quote ~= nil then
      if character == quote then quote = nil else token = token .. character end
      started = true
    elseif character == "\"" or character == "'" then
      quote, started = character, true
    elseif character:match("%s") then
      if started then
        tokens[#tokens + 1] = token
        token, started = "", false
        if #tokens > 32 then return nil, "Commands are limited to 32 arguments." end
      end
    else
      token, started = token .. character, true
    end
  end
  if escaped then return nil, "A command cannot end with an escape character." end
  if quote ~= nil then return nil, "The command contains an unterminated quote." end
  if started then
    tokens[#tokens + 1] = token
    if #tokens > 32 then return nil, "Commands are limited to 32 arguments." end
  end
  if #tokens == 0 or tokens[1] == "" then return nil, "Enter a command after '/'." end
  return tokens
end

---@param channel string
---@param payload table|nil
local function send(channel, payload)
  if page ~= nil and pageReady then page:send(channel, payload or {}) end
end

---@param message table|string
---@return boolean
local function addMessage(message)
  if type(message) == "string" then message = { text = message } end
  if type(message) ~= "table" then return false end
  send("chat:addMessage", message)
  return true
end

local function closeChat()
  if page == nil or not opened then return end
  opened = false
  page:setFocus(false, false)
  send("chat:close", {})
end

local function openChat()
  -- Refusals are printed, never silent: "the key does nothing" is the report this file has to
  -- be able to answer, and these are three different faults.
  if page == nil then
    Open77.log.warn("open refused: the WebUI surface was never created")
    return
  end
  if not enabled then
    Open77.log.warn("open refused: the chat is disabled by the server")
    return
  end
  if opened then return end
  opened = true

  -- Focus BEFORE the page is told to open. `setFocus` reaches the WebHost as the browser's own
  -- focus call while `chat:open` reaches the page as script; both travel one ordered pipe, so
  -- asking for browser focus first lands the element focus in a browser that already has it.
  if not page:setFocus(true, false) then
    Open77.log.warn("keyboard focus was refused; the box will take no text")
  end
  send("chat:open", {})
  TriggerServerEvent("chat:ready")
end

-- ---------------------------------------------------------------------------
-- What the server and other resources send
-- ---------------------------------------------------------------------------

RegisterNetEvent("chat:addMessage", addMessage)

RegisterNetEvent("chat:addSuggestion", function(command, help, parameters)
  send("chat:addSuggestion", {
    command = tostring(command or ""),
    help = tostring(help or ""),
    parameters = type(parameters) == "table" and parameters or {},
  })
end)

RegisterNetEvent("chat:addSuggestions", function(suggestions)
  send("chat:addSuggestions", {
    suggestions = type(suggestions) == "table" and suggestions or {},
  })
end)

RegisterNetEvent("chat:removeSuggestion", function(command)
  send("chat:removeSuggestion", { command = tostring(command or "") })
end)

RegisterNetEvent("chat:clearSuggestions", function() send("chat:clearSuggestions", {}) end)
RegisterNetEvent("chat:clear", function() send("chat:clear", {}) end)

RegisterNetEvent("chat:setEnabled", function(value)
  enabled = value ~= false
  if not enabled then closeChat() end
  send("chat:state", { enabled = enabled })
end)

--- The dispatcher's answer to a command this player typed.
RegisterNetEvent("open77:command:result", function(raw, accepted, message)
  raw, message = tostring(raw or ""), tostring(message or "")
  -- The dispatcher acknowledges queueing immediately and then sends the useful result. Showing
  -- both puts a line of noise above every answer.
  if accepted and message:match("^queued by ") then return end
  addMessage({
    type = accepted and "info" or "error",
    author = "COMMAND",
    text = message ~= "" and message or raw,
    color = accepted and { 120, 220, 232 } or { 255, 76, 92 },
  })
end)

-- The host raises this when the player presses the chat key; there is no binding of our own.
AddEventHandler("open77:chat:open", openChat)
AddEventHandler("chat:open", openChat)
AddEventHandler("chat:close", closeChat)

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
    -- above opx77_hud (705) and opx77_menu: a chat that opens under a menu is a chat nobody
    -- can read what they are typing in
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
          addMessage({ type = "error", author = "COMMAND", text = failure,
                       color = { 255, 76, 92 } })
          closeChat()
          return
        end
        TriggerEvent("chat:commandSubmitted", text, tokens)
        local sent, why = TriggerServerEvent("open77:command:execute", table.unpack(tokens))
        if not sent then
          addMessage({ type = "error", author = "NETWORK",
                       text = tostring(why or "The command could not be sent."),
                       color = { 255, 76, 92 } })
        end
      else
        local sent, why = TriggerServerEvent("chat:submit", text)
        if not sent then
          addMessage({ type = "error", author = "NETWORK",
                       text = tostring(why or "The message could not be sent."),
                       color = { 255, 76, 92 } })
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
  page, pageReady, opened = nil, false, false
end)

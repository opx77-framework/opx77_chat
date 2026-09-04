---@meta
--- Type annotations for opx77_chat. Never loaded at runtime.

--- Why an export refused. Codes are a branching surface, never player-facing text: a caller
--- that wants to show one renders it through its own catalogue.
--- What the host vouches for about an admitted player, as returned by
--- `Open77.players.identity`. Reading it needs no permission.
---@class PlayerIdentity
---@field userId string      the Master account id, stable across renames
---@field name string        the display name the client presents: a label, never a key
---@field publicKey string   the identity public key, base64
---@field fingerprint string `sha256:<hex>` of the public key
---@field joinedAt string    when they were admitted, ISO 8601 UTC

---@alias ChatError
---| "export_call_required" no invoking resource, so the call came from inside
---| "no_surface"           the WebUI surface was never created
---| "page_not_ready"       created, but the page has not raised `chat:ready` yet
---| "invalid_message"      `addMessage` was handed neither a table nor a string
---| "invalid_command"      the command name was empty once coerced to a string

--- Every export answers a table carrying `ok` and never raises. All six can answer
--- `export_call_required`; only the four that draw can answer `no_surface`/`page_not_ready`.
---@class ChatResponse
---@field ok boolean
---@field error ChatError|nil

--- What `setEnabled` and `isEnabled` answer. Neither touches the page, so neither has a
--- surface refusal; `enabled` is absent only on `export_call_required`.
---@class ChatEnabledState : ChatResponse
---@field enabled boolean|nil

--- Where the box sits. Anything else the page reads as "bottom-left".
---@alias ChatAnchor "bottom-left"|"top-left"

--- How a line is drawn. Unknown values fall back to "chat".
---@alias ChatLineType "chat"|"info"|"error"|"system"

--- One line in this player's box: the `chat:addMessage` payload, and the `addMessage` export's
--- argument. A bare string is taken as `{ text = message }`.
---@class ChatMessage
---@field text string|nil                    the body; rendered with textContent, never as HTML
---@field author string|nil                  the tag before it; omitted when empty
---@field type ChatLineType|nil              default "chat"
---@field color [integer, integer, integer]|nil  the author tag's colour, 0-255 per channel

--- One argument of a completion entry, shown as `[name]` after the help text.
---@class ChatSuggestionParameter
---@field name string
---@field help string|nil
---@field optional boolean|nil  sent by some callers; this resource does not render it

--- One completion entry. Adding a name that already exists replaces it. The `chat:addSuggestion`
--- net event carries these three as POSITIONAL arguments, not as one table.
---@class ChatSuggestion
---@field command string                          with or without the leading slash
---@field help string|nil                         the one-line description shown beside the name
---@field parameters ChatSuggestionParameter[]|nil

--- What `commandTokens` answers: one string per argument of a typed slash command, the name
--- first and the leading slash stripped. At most 32 entries.
---@alias CommandTokens string[]

--- config.lua. Every field is operator-authored and read on both halves.
---@class ChatConfig
---@field ANCHOR ChatAnchor
---@field WIDTH integer      box width in pixels, at a 1920-wide surface
---@field HISTORY integer    messages kept on screen
---@field FADE_MS integer    how long a line stays visible with the box closed; 0 never fades
---@field MAX_LENGTH integer the longest message a player may send, in CHARACTERS
---@field RATE_MS integer    floor between two messages from the same player
---@field LOCALE string      the catalogue player-facing text is rendered from

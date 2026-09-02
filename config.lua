OPX_CHAT_CONFIG = {
  -- "bottom-left" | "top-left"; web/chat.js reads any other value as "bottom-left"
  ANCHOR = "bottom-left",
  WIDTH = 620, -- box width in pixels, at a 1920-wide surface
  HISTORY = 60, -- messages kept on screen; older ones fall off the top
  FADE_MS = 12000, -- how long a message stays visible when the box is closed; 0 never fades
  MAX_LENGTH = 240, -- the longest message a player may send
  RATE_MS = 800, -- floor between two messages from the same player
  -- player-facing text; a catalogue in locales/ must carry this code
  LOCALE = "en",
}

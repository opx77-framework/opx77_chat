OPX_CHAT_CONFIG = {
  ANCHOR = "bottom-left", -- "bottom-left" | "top-left"
  WIDTH = 620, -- box width in pixels, at a 1920-wide surface
  HISTORY = 60, -- messages kept on screen; older ones fall off the top
  FADE_MS = 12000, -- how long a message stays visible when the box is closed; 0 never fades
  MAX_LENGTH = 240, -- the longest message a player may send
  RATE_MS = 800, -- floor between two messages from the same player
}

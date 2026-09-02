OPX_CHAT_CONFIG = {
  -- Which end of the LEFT edge the box sits at. Two values, and no others: "bottom-left" |
  -- "top-left". web/chat.js recognises "top-left" and treats every other string, right-hand
  -- corners included, as "bottom-left" -- silently, so a typo reads as a working default.
  -- The other resources spell this key `ANCHOR` too and accept wider sets; ours is narrow
  -- because a chat log grows upward from its anchor and the right-hand corners are where
  -- opx77_hud puts its info column.
  ANCHOR = "bottom-left",
  WIDTH = 620, -- box width in pixels, at a 1920-wide surface
  HISTORY = 60, -- messages kept on screen; older ones fall off the top
  FADE_MS = 12000, -- how long a message stays visible when the box is closed; 0 never fades
  MAX_LENGTH = 240, -- the longest message a player may send
  RATE_MS = 800, -- floor between two messages from the same player
}

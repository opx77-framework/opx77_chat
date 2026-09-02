resource "opx77_chat"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true

-- "reconnect", like every resource that owns a CEF surface.
--
-- The rule is the platform's, not ours: a resource that owns a WebUI surface declares
-- "reconnect"; one that owns only rules or state declares "local". Swapping a live CEF
-- surface while gameplay is running has historically caused unstable transitions, so a
-- generation change takes the session through a clean reconnect instead of replacing the
-- page in place. open77_notifications, open77_interactions, open77_admin,
-- open77_vehiclepicker and pursuit_hud each say exactly that in their own manifests, and
-- writing-a-gamemode.md states it in one line: "A WebUI surface needs reload_policy
-- 'reconnect'; a rules resource wants 'local'." A handful of older first-party surfaces --
-- open77_chat, open77_watermark, open77_blips -- still declare "local" and give no reason
-- for it; they are the drift, not the practice to copy.
--
-- The cost is real and is the point: one manifest declares one policy, so a resource that
-- pairs a surface with rules an operator wants to iterate on has to be split in two. That is
-- why pursuit_hud is its own resource rather than part of pursuit.
reload_policy "reconnect"

client_script "config.lua"
client_script "client/main.lua"
client_script "client/exports.lua" -- last: publishing the surface claims it exists

server_script "config.lua"
server_script "server/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
-- `**` on its own is the one glob that is safe here. The fatal pattern is a SCRIPT glob:
-- `client/**/*.lua` needs an intermediate directory and matches nothing against a flat
-- `client/`, and an empty script pattern refuses the whole session's resource set with
-- `script_pattern_empty:...` -- no player can connect. That is why every script above is
-- on its own line. `web_files { "web/**" }` is not that case: it is what fifteen shipped
-- resources use, including open77_chat and open77_notifications, and the server's own
-- package cache shows it matching this resource's flat web/ files one for one.
web_files { "web/**" }

permissions {
  "network.events", -- the only transport there is: submit, dispatch, broadcast
}

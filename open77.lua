resource "opx77_chat"
version "0.2.0"
open77_version ">=0.0.1"
auto_start true

-- "reconnect" is the policy for a resource that owns a CEF surface.
reload_policy "reconnect"

shared_script "config.lua" -- both halves read it: the box, the caps, and LOCALE
shared_script "shared/text.lua"
shared_script "shared/locale.lua" -- after config.lua: LOCALE is read at load
shared_script "locales/en.lua" -- registered right after the catalogue, so no file
shared_script "locales/fr.lua" -- below calls locale() against an empty one

server_script "server/main.lua"

client_script "client/main.lua"
client_script "client/exports.lua" -- last: publishing the surface claims it exists

web_ui_page "web/index.html"
web_ui_auto_create false -- created in client/main.lua, so a failure is one logged line
-- Every script is listed on its own line: a glob that matches no script refuses the whole
-- session's resource set with `script_pattern_empty:...`.
web_files { "web/**" }

permissions {
  "network.events", -- the only transport there is: submit, dispatch, broadcast
}

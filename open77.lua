resource "opx77_chat"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true

-- "reconnect" is the policy for any resource owning a WebUI surface; "local" is for rules only.
reload_policy "reconnect"

-- Configuration first: shared/locale.lua reads LOCALE out of it at load.
client_script "config.lua"
server_script "config.lua"

shared_script "shared/locale.lua"
shared_script "locales/en.lua" -- registered right after the catalogue, so no file below calls
shared_script "locales/fr.lua" -- locale() against an empty one

client_script "client/main.lua"
client_script "client/exports.lua" -- last: publishing the surface claims it exists

server_script "server/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
-- Script patterns must stay one file per line: a glob such as `client/**/*.lua` matches nothing
-- against a flat directory and an empty pattern refuses the whole session's resource set.
web_files { "web/**" }

permissions {
  "network.events", -- the only transport there is: submit, dispatch, broadcast
}

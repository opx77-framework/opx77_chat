resource "opx77_chat"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true

reload_policy "local" -- a CEF surface, rebuilt on start

client_script "config.lua"
client_script "client/main.lua"

server_script "config.lua"
server_script "server/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

permissions {
  "network.events", -- the only transport there is: submit, dispatch, broadcast
}

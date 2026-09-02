# opx77_chat

> [!WARNING]
> **This project is currently in early development and is not considered production-ready.**
>
> The API, architecture, features, and internal systems are subject to change at any time without prior notice. Breaking changes may be introduced as development progresses.
>
> **Do not rely on the current API for production resources yet.**

The chat box for **Opx77**, and the path a typed command takes to the server.

Without it nothing typed in game reaches the server: slash commands travel on the host's authenticated dispatcher, and this is the resource that tokenises a line and hands it over. A typed command is limited to 32 arguments; quotes and backslash escapes are honoured when the line is split.

## Features

- Messages relayed to every player, attributed to the connection that sent them
- Slash commands dispatched to the host's ACL-checked command path, never re-implemented here
- Command completion from the suggestions every resource publishes on `chat:ready`
- Arrow-key history of what you typed, and Tab to complete
- The log fades while the box is closed and comes back when it opens
- Every line it writes itself is rendered from `locales/`, English and French shipped

## Commands

None of its own. It carries everybody else's.

## Exports

Client-side only — the server runtime installs no exports. These are the six names the platform documents on its own `open77_chat` package, with the same arguments. A server resource that wants a line in one player's box sends them `chat:addMessage` instead.

| Export | Does |
|---|---|
| `addMessage(message)` | put one line in this player's box; a bare string is taken as its text |
| `clear()` | empty the visible log, leaving the suggestions alone |
| `addSuggestion(command, help, parameters?)` | add or replace one completion entry |
| `removeSuggestion(command)` | take one completion entry back down |
| `setEnabled(enabled)` | turn the box off or back on, for everyone, not just the caller |
| `isEnabled()` | whether it is on |

Every call answers `{ ok = boolean }`, with an `error` code when `ok` is false: `export_call_required`, `no_surface`, `page_not_ready`, `invalid_message`, `invalid_command`. The caller is read from the host, never from an argument.

Like every export on this platform the call is asynchronous: it answers a promise that has to be awaited inside a `CreateThread`, and only a resolved `{ ok = false }` is a refusal by this resource.

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_chat", "addMessage", {
    type = "info", author = "RIPPERDOC", text = "You are patched up.",
  })
  if not promise then return print("not dispatched: " .. tostring(reason)) end

  local answer, callError = promise:await()
  if callError then return print("call failed: " .. tostring(callError)) end
  if not answer.ok then print("chat refused: " .. tostring(answer.error)) end
end)
```

## Configuration

`config.lua`. Where the box sits, how wide it is, how many lines it keeps, how long they stay visible, the floor between two messages from one player, and `LOCALE` — the language every line this resource writes is rendered in.

`LOCALE` is this resource's own setting, separate from the core's: a satellite's server half cannot ask the core for a translation, so each one carries its catalogue. `locales/en.lua` and `locales/fr.lua` ship; add a language by copying one to `locales/<code>.lua`, translating the right-hand side, adding a `shared_script` line for it in `open77.lua` beside the others, and setting `LOCALE` to that code. Every catalogue carries the same keys — a missing one falls back to `en`, then to the key itself. The page holds no translations of its own: the strings it draws arrive already rendered in the `chat:config` payload.

Chat text arrives from clients and is never trusted: the server strips control characters and truncates to `MAX_LENGTH` before relaying, the author is taken from the authenticated connection rather than from the payload, and the page renders every author and message with `textContent`, never `innerHTML`. Keep all three if you touch that path.

Do not run this alongside the platform's own `open77_chat` package: both draw a box, both answer `chat:addMessage` and both take focus on the open key, so every message renders twice. The server half warns when it sees the other one running.

## Community & Support

Join the Open77 and Opx77 communities to discover the platform, share your projects, and connect with other developers.

<!-- TODO: replace with the final URLs before publication. -->

* [Open77](#)
* [Open77 GitHub](#)
* [OPX Discord](#)

## License

opx77_chat is licensed under the [**MIT License**](LICENSE).

Copyright © 2026 **Luis MOUTA**.

<p align="center">
    <sub>opx77_chat is an independent community project and is not affiliated with or endorsed by CD PROJEKT RED.</sub>
</p>

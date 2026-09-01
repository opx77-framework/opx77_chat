# opx77_chat

> [!WARNING]
> **This project is currently in early development and is not considered production-ready.**
>
> The API, architecture, features, and internal systems are subject to change at any time without prior notice. Breaking changes may be introduced as development progresses.
>
> **Do not rely on the current API for production resources yet.**

The chat box for **Opx77**, and the path a typed command takes to the server.

Without it nothing typed in game reaches the server: slash commands travel on the host's authenticated dispatcher, and this is the resource that tokenises a line and hands it over.

## Features

- Messages relayed to every player, attributed to the connection that sent them
- Slash commands dispatched to the host's ACL-checked command path, never re-implemented here
- Command completion from the suggestions every resource publishes on `chat:ready`
- Arrow-key history of what you typed, and Tab to complete
- The log fades while the box is closed and comes back when it opens

## Commands

None of its own. It carries everybody else's.

## Configuration

`config.lua`. Where the box sits, how wide it is, how many lines it keeps, how long they stay visible, and the floor between two messages from one player.

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

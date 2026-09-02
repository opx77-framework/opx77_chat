# What is not settled

Nothing here may be assumed in the code. Each entry says what this resource does about it in
the meantime, so the next reader does not have to work it out again — or "correct" it in the
wrong direction.

The sibling file is `opx77_core/docs/unknowns.md`, which carries the platform-wide entries.
This file only holds what is specific to the chat box.

## The queue acknowledgement is recognised by matching English text the PLATFORM writes

`open77:command:result(raw, accepted, message)` fires **twice** for one slash command. The
first is the dispatcher acknowledging that it queued the command; the second is the command's
own answer, a tick or two later. Showing both puts a line of noise above every answer, so
`client/main.lua` drops the first.

The payload carries nothing that distinguishes the two — no phase, no flag, no code. `accepted`
is true for both. So the only way to tell them apart is the wording of `message`, and that
wording is the platform's, not ours.

**The literal, read byte for byte out of `Open77.Server.Scripting.dll`** (UTF-16, beside
`permission denied for command '` and `unknown command '`):

```
command '<name>' queued by resource <resource>
```

built from the two fragments `command '` and `' queued by resource `.

**The previous filter was already broken.** It tested `message:match("^queued by ")`, anchored
at the start of the string — and the message starts with `command '`, not with `queued`. It
therefore never matched, and every player was already seeing the acknowledgement line above
every command answer. `QUEUE_ACK` in `client/main.lua` now holds the substring
`' queued by resource ` and the test is a plain `find`, not a pattern.

**What this resource does.** It matches the substring, and only when `accepted` is true. The
failure mode is understood in both directions and neither loses a command:

- the platform rewords the acknowledgement -> the filter stops matching and the queue line
  reappears above every answer. Cosmetic, and the fix is one constant.
- a command's own answer happens to contain `' queued by resource ` -> that answer is
  swallowed. Unlikely, and no more than one line.

**Do not** try to fix this by counting results, by a timer, or by remembering what was typed:
`open77:command:result` is not guaranteed to be ordered against anything else, and a command
that answers nothing at all is normal. If the platform ever grows a structured field on this
event, use it and delete `QUEUE_ACK`.

## The message cap is enforced in two different units

`config.lua`'s `MAX_LENGTH` is one number read on both sides:

- the page sets it as the input's `maxlength` attribute, which HTML counts in **UTF-16 code
  units**;
- `server/main.lua` truncates in **Unicode characters**, counting UTF-8 lead bytes.

The two agree for everything in the Basic Multilingual Plane, which is all of Latin, Greek,
Cyrillic, Hebrew, Arabic and CJK. They diverge on astral characters — emoji, and the rarer CJK
extensions — which the page counts as two and the server as one. A line of emoji can therefore
be stopped by the input at half of `MAX_LENGTH` characters.

**What this resource does.** Nothing, deliberately. The server is the side that must not be
outrun, and it is the more generous of the two, so a client can never push more past it than
the operator configured. The page being stricter than the server is the safe direction.

Never make the server count bytes to "match": that was the original bug, and it cut a
multi-byte character in half.

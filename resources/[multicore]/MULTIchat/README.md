# MULTIchat

MULTIcore's own chat. A black chat box with white letters, roleplay commands, and command suggestions as you type.

It answers every call scripts make to the standard **chat** resource (`chat:addMessage`, `chat:addSuggestion`, `chatMessage`, `exports.chat:...`). Scripts written for the standard chat work without edits.

## Install

```
ensure MULTIcore
ensure MULTItarget
ensure MULTIchat       # instead of "ensure chat"
```

Do **not** start the standard `chat` resource as well. MULTIchat `provide`s the name `chat`, so scripts that depend on it still start.

## Using it

| | |
|---|---|
| **T** | Open the chat box |
| **Enter** | Send |
| **Esc** | Close without sending |
| **Tab** | Finish the highlighted command |
| **Arrow up / down** | Move through suggestions, or through what you sent before |

## Commands

| Command | Looks like | Who sees it |
|---|---|---|
| `/me tips his hat` | *\* Jack Hale tips his hat*: white on black | Players within 20 m |
| `/do the door is locked` | *\* The door is locked (( Jack Hale ))*: blue on black | Players within 20 m |
| `/try to pick the lock` | *\* Jack Hale tries to pick the lock* **and succeeds** / **and fails** | Players within 20 m |
| plain text | **Jack Hale:** hello | Players within 20 m (see `Config.PlainText`) |
| `/clear` | Clears your own chat | You |
| `/togglechat` | Hides or shows the chat lines | You |

MULTIcore's `/ooc` still works as before. Names are the character's first and last name. Players in another routing bucket never see each other's lines.

## Config

| Option | Default | What it does |
|---|---|---|
| `Config.OpenKey` | `0x9720FCEE` | Key that opens the chat (MpTextChatAll, T) |
| `Config.Scale` | `1.0` | Size of the chat |
| `Config.MaxMessages` | `100` | Lines kept before the oldest are dropped |
| `Config.FadeSeconds` | `12` | With the box closed, new lines show this long, then fade |
| `Config.MaxLength` | `256` | Longest message (characters) |
| `Config.CooldownMs` | `750` | Shortest time between two messages from one player |
| `Config.UseCharacterName` | `true` | Character name (true) or account name (false) |
| `Config.LogToConsole` | `true` | Print /me, /do, /try and plain text to the server console |
| `Config.PlainText` | `'local'` | `'local'`, `'global'` or `'off'` |
| `Config.Range` | 20 m each | How far each kind of line is heard |
| `Config.Commands` | see file | Command names; set one to `false` to turn it off |
| `Config.TryChance` | `50` | Chance (%) that /try succeeds |
| `Config.Styles` | see file | Letter and band colours for me, do, try, say and system lines |

Colours and sizes can also be changed in `html/custom.css` (loaded last). Text: `locales/` (10 languages).

## Exports

Server:

```lua
exports.MULTIchat:addMessage(target, { args = { 'Sheriff', 'Road closed' } })   -- target = player id or -1
exports.MULTIchat:SendMe(src, 'opens the satchel')   -- a /me line from that player
exports.MULTIchat:SendDo(src, 'the satchel is empty')
```

Client: `addMessage`, `addSuggestion`, `addSuggestions`, `removeSuggestion`, `addTemplate`, `clear`.

All of these also work on `exports.chat`.

A message can carry `mc = 'me' | 'do' | 'try' | 'say' | 'system'` to use that line style.

## Licence

GPL-3.0-or-later, part of MULTIcore by RINGO (RINGOscripting).

# MULTItelegram

Telegrams for MULTIcore servers: send a telegram to another character at the post office, read your inbox at any office, keep an address book, optionally send a parcel. RSG v2 scripts keep working, because telegrams live in rsg-telegram's own tables (`telegrams`, `address_book`) and MULTItelegram answers rsg-telegram's events.

GPL v3, like MULTIcore. Post office places and table shapes from rsg-telegram (RSG v2, GPL v3), see `CREDITS.md`.

Deliberately basic. No bird post, no job mailboxes, no stamps, no mail carriers: that is what premium mail scripts are for.

## What it does

- **Twelve post offices**: Valentine, Rhodes, Saint Denis, Van Horn, Annesburg, Armadillo, Tumbleweed, Strawberry, and the Wallace, Riggs, Flatneck and Emerald Ranch railway stations (`config/offices.lua`). MULTItarget on the counter and clerk ("Open", hold Left Alt) when it runs, else a hold-key prompt (`Config.Interact = 'auto'`, `PromptDistance` 2.0 m); `/mcinteract` (MULTIcore) prints what was placed to the server console, map blips, optional clerk NPC.
- **Send** at an office counter only, to a character by name ("Ada Hollis", any case), character number (`#12`, `players.id`), citizen id, or a name in your address book. Costs `Config.Price` ($0.10) in cash.
- **Inbox** at any office (or anywhere with `Config.ReadAnywhere = true`): newest first, unread marked, read, reply, throw away.
- **Arrival notice** through MULTIcore Notify with the unread count. Characters that were offline are told on their next login (`Config.LoginNoticeDelayMs`). Rows other scripts write straight into `telegrams` by SQL (rsg-horses does) are announced too (`Config.PollSeconds`).
- **Address book** per character: add by number, citizen id or name, with your own label; write to or remove a contact. Editable anywhere (`Config.ContactsAnywhere`).
- **Parcels** (off by default, `Config.Parcel.Enabled`): one satchel stack sent with a telegram, held by the post office until the recipient collects it at any office. Weapons only with `AllowWeapons`; `Blacklist` for items that may never be posted.
- **Page** (NUI, MULTIcore theme): inbox, write, address book, a telegram blank in the base-game black-and-white look. Every word from `locales/*.lua` (10 languages).

## Safety

- Every action runs on the server: office distance (`Config.MaxUseDistance`, needs OneSync), cash, the sender's identity (the client can't send as someone else), message lengths, a spam guard and a short send cooldown.
- Money only through MULTIcore's `Player.Functions.RemoveMoney`; parcel items only through MULTIinventory exports. If a later step fails, earlier ones are refunded.
- A parcel is claimed in the database before the item is handed over, so it can't be collected twice. A telegram with an uncollected parcel can't be thrown away.

## Setup

1. Put `MULTItelegram` in `resources/[multicore]/`.
2. `server.cfg`, after MULTIcore and MULTIinventory, before RSG / VORP scripts:
   ```
   ensure MULTItelegram
   ```
3. Remove `rsg-telegram` from the server: MULTItelegram stands in for it (`provide 'rsg-telegram'`).
4. Needs `oxmysql`, `ox_lib`, `MULTIcore`; `MULTIinventory` for parcels; `MULTItarget` recommended (used automatically when it runs). Tables are created on first start (MULTIcore's `sql/rsg_core.sql` has `telegrams` and `address_book` already; missing later columns are added).

## Config (`config.lua`, `config/offices.lua`)

Every option has a comment. The main ones: `Price`, `ReadAnywhere`, `ContactsAnywhere`, `AllowSendToSelf`, `MaxUseDistance`, `Interact` (`'auto'`, `'target'`, `'prompt'`), `PromptKey`, `PromptDistance`, `Commands`, the length limits, `LoginNoticeDelayMs`, `PollSeconds`, `RateLimit`, `SendCooldownMs`, `Parcel`, `Npc`, `Blips`.

**Clerk NPCs**: none ship, because there are no checked clerk spots for these counters. To have one, stand behind the counter in game and add `npc = vector4(x, y, z, heading)` to that office in `config/offices.lua`. The model is `s_m_m_trainstationworker_01`.

## Commands

- `/telegram`: open your inbox (at an office, or anywhere with `ReadAnywhere`).
- `/addressbook`: open your address book.

Names in `Config.Commands` (the same names as rsg-telegram's).

## Exports (server)

| Export | Returns |
|---|---|
| `Send(src, to, subject, message, parcel?)` | a player sends from the office they stand at (money, checks): `true, { id, name, price }` or `false, err` |
| `SendTelegram(to, sendername, subject, message, sender?)` | a telegram from a script (free, no office): `id` or `false, err` |
| `GetUnread(src or citizenid)` | unread count |
| `Resolve(to)` | `{ citizenid, name, id }` or `nil, err` |
| `GetInbox(citizenid)`, `GetContacts(citizenid)` | lists |
| `IsReady()` | tables made |

Server event `MULTItelegram:sent (src, telegramId, recipientCitizenid)` after every player telegram; `MULTItelegram:notice (src, 'arrived' | 'login', unread)` when a player is told.

## rsg-telegram compatibility

| Call | MULTItelegram |
|---|---|
| Direct SQL on `telegrams` / `address_book` (rsg-horses inserts, rsg-core deletes on character delete) | same tables and columns; inserted rows show in the inbox and are announced |
| client `rsg-telegram:client:OpenTelegram`, `ReadMessages` (rsg-prison) | opens the inbox |
| client `rsg-telegram:client:WriteMessagePostOffice` (rsg-prison), `WriteMessage` | opens the write page (sending still needs an office) |
| client `rsg-telegram:client:OpenAddressbook` (rsg-radialmenu, RINGOradialmenu) | opens the address book |
| server `rsg-telegram:server:SendMessagePostOffice (sender, sendername, to, subject, message)` | sends; the sender fields are ignored, as in rsg-telegram 2.1.1 |
| server `SavePerson (name, cid)`, `RemovePerson (cid)`, `DeleteMessage (id)`, `MarkAsRead (id)`, `CheckInbox`, `pickupMessages` | same behaviour |
| callbacks `getTelegramsAmount`, `checkWaitingMessages`, `getInbox`, `getAddressbook`, `GetPlayers`, `GetPlayersPostOffice` | same shapes; `getJobInbox`, `getJobRecipients`, `getJobSenders` answer empty lists |
| state bag `telegramUnreadMessages` | kept up to date |

Not answered (premium features): bird post (`birdpost` item), job mailboxes.

## Self-test

`test/telegram_selftest` (tag `teletest`), run by `tools/test_boot.ps1 -All`.

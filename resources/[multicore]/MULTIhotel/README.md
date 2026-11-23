# MULTIhotel

Hotels for MULTIcore. GPL v3 (see `LICENSE`).
MULTIcore was founded and created by RINGO (RINGOscripting).

- **7 hotels:** Valentine, Strawberry, Rhodes, Saint Denis, Blackwater, Tumbleweed and Annesburg, each with a map blip.
- **Renting:** hold **Left Alt** (MULTItarget) at the front desk and pick **Front desk**, then **Rent a room**. You
  pay `Config.StartCredit` ($10 by default) in cash and it becomes the room's first credit. One room per hotel per
  character.
- **Checking in:** at the front desk pick **Check in** to go up to your room. Every room is its own private copy of the
  hotel room, so you only meet the people you invited.
- **The room menu** (black and white MULTIcore page, hold Left Alt in the room): add credit, take credit out, guests,
  throw guests out, the room locker, telegrams and leave the room.
- **Rent:** every `Config.BillingCycle` hours `Config.RentPerCycle` is taken from each room's credit. Low credit sends a
  warning telegram; when the credit runs out the room is given up and everyone in it is walked back to the street.
- **Room locker:** one MULTIinventory stash per room (`stash:hotel_room_<room>`), 48 slots and 4000 kg by default.
- **Guests:** invite players standing close to you (`Config.InviteDistance`), up to `Config.MaxGuests` per room. A
  guest picks **Guest check in** at the front desk. The owner can take an invitation back at any time.
- **Throw guests out:** sends every guest in the room back to the street at once, with a cooldown
  (`Config.EvictionCooldown`). With `Config.RemoveGuestsOnEviction` their invitations are taken back as well.
- **Telegrams:** invitations, low credit, lost rooms and being thrown out arrive as telegrams (MULTItelegram).
- The hotel doors in `Config.HotelDoors` stay locked (`Config.LockDoors`).
- 32 languages, following MULTIcore's language (`MULTIConfig.Language`). Nothing is drawn in the world (no markers,
  no floating text, no dots).

Every action is checked on the server: desk actions only near the desk, room actions only for the room you are standing
in and only for its owner, and every amount is worked out on the server.

## Install

1. Put `MULTIhotel` in your resources (it ships in `resources/[multicore]`).
2. Add `ensure MULTIhotel` to `server.cfg` after MULTIcore, MULTItarget and MULTIinventory.
3. The tables `multi_hotel_rooms` and `multi_hotel_guests` are made on the first start. `sql/multihotel.sql` holds the
   same if you prefer to import it by hand.

## Settings (`config.lua`)

| Setting | Default | What it does |
|---|---|---|
| `Config.Locale` | `''` | Language for this script; empty follows MULTIcore's language |
| `Config.Debug` | `false` | Extra prints in F8 and the server console |
| `Config.Currency` | `'cash'` | Money type players pay with |
| `Config.StartCredit` | `10` | Paid when renting; becomes the first credit |
| `Config.RentPerCycle` | `1` | Credit taken from each room every cycle |
| `Config.BillingCycle` | `1` | Hours between two rent cycles |
| `Config.CreditWarning` | `5` | Warning telegram when credit is below RentPerCycle x this |
| `Config.MaxCredit` | `10000` | Most credit one room may hold |
| `Config.StorageMaxWeight` | `4000000` | Locker weight in grams |
| `Config.StorageMaxSlots` | `48` | Locker slots |
| `Config.PurgeStorage` | `false` | Empty the locker when a room is lost for unpaid rent |
| `Config.MaxGuests` | `5` | Guests per room |
| `Config.InviteDistance` | `15.0` | How close a player must be to be invited |
| `Config.EvictionCooldown` | `300` | Seconds between two times throwing guests out |
| `Config.RemoveGuestsOnEviction` | `false` | Also take back the invitations when throwing guests out |
| `Config.BucketOffset` | `40000` | Room N uses routing bucket BucketOffset + N |
| `Config.LockDoors` | `true` | Keep the hotel doors locked |
| `Config.Interact` | `'auto'` | `'auto'`, `'target'` (MULTItarget) or `'prompt'` (hold-key prompts) |
| `Config.Key` | `'J'` | Prompt key (prompt mode only) |
| `Config.TargetRadius` / `Config.TargetDistance` | `1.5` / `2.5` | MULTItarget point size and reach |
| `Config.PromptDistance` | `2.0` | Prompt reach (prompt mode) |
| `Config.ServerDistance` | `10.0` | The server refuses desk actions farther than this from the desk |
| `Config.Blip` | hotel bed | Blip sprite, scale and style |
| `Config.LogName` | `'hotel'` | MULTIserver log name; `''` turns logs off |
| `Config.Commands.fixNui` | `'hotelfix'` | Closes the hotel page if it ever gets stuck |
| `Config.Hotels` | 7 hotels | Desk, room menu, arrival and exit points per hotel |
| `Config.HotelDoors` | 14 doors | Door hashes kept locked |

Hotel ids (`id` in `Config.Hotels`) are saved with every room: do not change them once rooms are rented.

## Commands

| Command | Who | What it does |
|---|---|---|
| `/hotelfix` | everyone | Closes the hotel page if it gets stuck |

## Needs

MULTIcore, MULTItarget, MULTIinventory, ox_lib, oxmysql. MULTItelegram (telegrams) and MULTIserver (logs) are used
when they run.

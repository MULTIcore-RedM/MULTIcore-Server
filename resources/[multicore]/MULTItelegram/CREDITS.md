# Credits

MULTItelegram is GPL v3, written for MULTIcore.

## RSG v2 framework: rsg-telegram (GPL v3)

From rsg-telegram 2.1.1 (RSG v2 framework, GPL v3, by the RSG / Rexshack team and contributors):

- **Post office places**: the twelve counter coordinates and names in `config/offices.lua` come from rsg-telegram's `Config.PostOfficeLocations`.
- **Table shapes**: `telegrams` and `address_book` keep rsg-telegram's columns and defaults (`server/main.lua`), so scripts that read or write these tables by SQL keep working.
- **Event, callback and state names** answered in `server/compat.lua` and `client/compat.lua` are rsg-telegram's (`rsg-telegram:server:SendMessagePostOffice`, `rsg-telegram:client:OpenAddressbook`, `telegramUnreadMessages` ...), with the same arguments.
- The blip sprite `blip_post_office` is the one rsg-telegram uses.

No rsg-telegram code was copied; the logic, page and texts are MULTItelegram's own.

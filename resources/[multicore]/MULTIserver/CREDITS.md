# Credits

MULTIserver is GPL v3, written for MULTIcore.

## RSG v2 framework: rsg-essentials `server/logs.lua` (GPL v3)

From the RSG v2 framework (GPL v3, by the RSG / Rexshack team and contributors):

- **The log event** `rsg-log:server:CreateLog (name, title, color, message, tagEveryone)`: its name and argument order, and that it is also sent from game clients (rsg-adminmenu, rsg-medic).
- **The colour names** and their colour codes in `Config.Logs.Colors` (`default`, `blue`, `red`, `green`, `white`, `black`, `orange`, `yellow`, `pink`, `lightgreen`).

No rsg-essentials code was copied. Routing by convar, the sending queue with 429 retry, the client checks, the whitelist, the queue, the player list and the info page are MULTIserver's own.

# Credits for MULTIwagons

MULTIwagons is GPL v3, part of MULTIcore by RINGO (RINGOscripting). Parts of it are based on RSG v2's **rsg-wagons**
(GPL v3, original project https://github.com/Rexshack-RedM/rsg-wagons, authors **Phil and mack**,
with the Rexshack-RedM team and contributors), who keep their copyright. MULTIwagons is not
affiliated with or endorsed by the RSG team.

Taken or adapted from rsg-wagons:
- the `rsg_wagons` table shape (installation/rsg-wagons.sql), so existing rows carry over;
- the dealer places (Valentine, Saint Denis, Strawberry, Blackwater, Tumbleweed, Caliga Hall),
  clerk spots and wagon spawn spots (config.lua `Config.Stores`), in `config/dealers.lua`;
- the wagon model names and the clerk model, the dealer blip sprite / style and the own-wagon blip;
- the spawn steps (CreateVehicle, owned-by-player flag, networking) in `client/main.lua`;
- the names, arguments and return shapes of its events and callbacks, answered in
  `server/compat.lua` and `client/compat.lua`;
- the stash name `Wagon_Stash_<id>`, used once to move old stashes into the new storage.

Everything else (engine, storage through MULTIinventory, health and repair, menus, locales) is
MULTIcore's own.

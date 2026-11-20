# Credits for MULTIdoors

MULTIdoors is GPL v3, written for MULTIcore. It uses data and game facts from these projects:

- **femga, rdr3_discoveries** (https://github.com/femga/rdr3_discoveries), `doorHashes/doorhashes.lua`: the list of every door hash, model and position, turned into `data/doors.lua`. Also femga's `natives.json` for the door natives and their states.
- **RSG v2 rsg-doorlock** 1.0.3 (GPL v3, Rexshack-RedM / RSG and contributors; inspired by QR-Doorlock; Sisika doors by mortimersays), https://github.com/Rexshack-RedM/rsg-doorlock:
  - the law-office and Sisika door positions in `config/locks.lua` (matched to door hashes by position), and the Sisika front-gate hashes;
  - the shape of its `Config.DoorList` (read by `config/rsg_doorlist.lua`), its event names and arguments (`server/compat.lua`, `client/main.lua`);
  - the key animation (`script_common@jail_cell@unlock@key` / `action`), the `p_key02x` prop, its bone and offsets, the door-native call pattern.
- **RSG v2 rsg-banking** (GPL v3, Rexshack-RedM / RSG): the bank door hashes and their open / locked defaults (as MULTIbank carries them).
- **RSG v2 rsg-medic** (GPL v3): the Valentine doctor position used to pick the Valentine doctor doors; the alert blip style and sprite values.

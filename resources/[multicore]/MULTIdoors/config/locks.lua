-- ============================================================
-- MULTIdoors :: lock rules (the owner's file)
-- A door is only managed when a rule names it. Every other door in the
-- game behaves as it always does. Find a door's hash in game with /doors
-- (aim at it) or in data/doors.lua. Rules made in game with /doors are
-- saved in the database and win over a rule here with the same id.
--
-- {
--   id           = 'val_sheriff_front', -- unique, never change it once players use the door (needed; letters, digits, _ -)
--   label        = 'Valentine sheriff - front door', -- name in menus and the prompt
--   door         = 1988748538,          -- door hash, or a list for double doors: { 3410720590, 3821185084 }
--   locked       = true,                -- state after a restart
--   jobs         = { vallaw = 0 },      -- job = lowest grade that may lock / unlock
--   gangs        = { redwater = 1 },   -- gang = lowest gang grade
--   citizenids   = { 'ABC12345' },      -- these characters
--   items        = { 'key_valentine_jail' }, -- anyone carrying one of these items (key items are created by themselves)
--   lockpickable = true,                -- may be picked with Config.Lockpick.Item
--   autoLock     = 30,                  -- seconds after unlocking it locks again (nil / 0 = never)
--   distance     = 2.0,                 -- how close a player must stand (metres; default Config.DefaultDistance)
--   coords       = vector3(x, y, z),    -- only for a door that is not in data/doors.lua
--   rsg          = 1,                   -- number(s) of this door in RSG v2 rsg-doorlock's stock list, so its events find it (optional)
-- }
-- A rule with no jobs, gangs, citizenids or items can only be used by admins.
--
-- Default rules below: law offices and jail cells, banks and doctors.
-- Law office door positions come from RSG v2 rsg-doorlock's config
-- (GPL v3, Rexshack-RedM and contributors; Sisika by mortimersays) and
-- were matched to door hashes by position. Bank door hashes come from
-- RSG v2 rsg-banking's config (GPL v3). See CREDITS.md.
-- Every law rule also lets the marshal job in.
-- ============================================================

Config = Config or {}

Config.Locks = {

    -- Valentine sheriff office (positions: RSG v2 rsg-doorlock)
    { id = 'val_sheriff_front', label = 'Valentine sheriff - front door', door = 1988748538, locked = true, jobs = { marshal = 0, vallaw = 0 }, items = { 'key_valentine_jail' }, lockpickable = true, rsg = 1, distance = 2.5 }, -- p_door_val_jail02x
    { id = 'val_sheriff_back', label = 'Valentine sheriff - back door', door = 395506985, locked = true, jobs = { marshal = 0, vallaw = 0 }, items = { 'key_valentine_jail' }, lockpickable = true, rsg = 2, distance = 2.5 }, -- p_door_val_jail01x
    { id = 'val_sheriff_cellsback', label = 'Valentine sheriff - cells back door', door = 1508776842, locked = true, jobs = { marshal = 0, vallaw = 0 }, items = { 'key_valentine_jail' }, lockpickable = true, rsg = 3 }, -- p_door_val_jail_cell02x
    { id = 'val_sheriff_cellarea', label = 'Valentine sheriff - cell area', door = 535323366, locked = true, jobs = { marshal = 0, vallaw = 0 }, items = { 'key_valentine_jail' }, lockpickable = true, rsg = 4 }, -- p_door_val_jail_cell01x
    { id = 'val_sheriff_cell1', label = 'Valentine sheriff - cell 1', door = 295355979, locked = true, jobs = { marshal = 0, vallaw = 0 }, items = { 'key_valentine_jail' }, lockpickable = true, rsg = 5 }, -- p_door_val_jail_cell01x
    { id = 'val_sheriff_cell2', label = 'Valentine sheriff - cell 2', door = 193903155, locked = true, jobs = { marshal = 0, vallaw = 0 }, items = { 'key_valentine_jail' }, lockpickable = true, rsg = 6 }, -- p_door_val_jail_cell01x

    -- Rhodes sheriff office (positions: RSG v2 rsg-doorlock)
    { id = 'rho_sheriff_front', label = 'Rhodes sheriff - front door', door = 349074475, locked = true, jobs = { marshal = 0, rholaw = 0 }, items = { 'key_rhodes_jail' }, lockpickable = true, rsg = 7, distance = 2.5 }, -- p_doorrhosheriff02x
    { id = 'rho_sheriff_back', label = 'Rhodes sheriff - back door', door = 1614494720, locked = true, jobs = { marshal = 0, rholaw = 0 }, items = { 'key_rhodes_jail' }, lockpickable = true, rsg = 8, distance = 2.5 }, -- p_door04x
    { id = 'rho_sheriff_cell', label = 'Rhodes sheriff - cell', door = 1878514758, locked = true, jobs = { marshal = 0, rholaw = 0 }, items = { 'key_rhodes_jail' }, lockpickable = true, rsg = 9 }, -- p_door_val_jail_cell01x

    -- Blackwater sheriff office (positions: RSG v2 rsg-doorlock)
    { id = 'blk_sheriff_front', label = 'Blackwater sheriff - front doors', door = { 3410720590, 3821185084 }, locked = true, jobs = { blklaw = 0, marshal = 0 }, items = { 'key_blackwater_jail' }, lockpickable = true, rsg = 10, distance = 2.5 }, -- p_door_bla_jail_r_01x + p_door_bla_jail_l_01x
    { id = 'blk_sheriff_back', label = 'Blackwater sheriff - back door', door = 2810801921, locked = true, jobs = { blklaw = 0, marshal = 0 }, items = { 'key_blackwater_jail' }, lockpickable = true, rsg = 11, distance = 2.5 }, -- p_door34x
    { id = 'blk_sheriff_cell1', label = 'Blackwater sheriff - cell 1', door = 2167775834, locked = true, jobs = { blklaw = 0, marshal = 0 }, items = { 'key_blackwater_jail' }, lockpickable = true, rsg = 12 }, -- p_door_val_jail_cell01x
    { id = 'blk_sheriff_cell2', label = 'Blackwater sheriff - cell 2', door = 2514996158, locked = true, jobs = { blklaw = 0, marshal = 0 }, items = { 'key_blackwater_jail' }, lockpickable = true, rsg = 13 }, -- p_door_val_jail_cell01x

    -- Strawberry sheriff office (positions: RSG v2 rsg-doorlock)
    { id = 'str_sheriff_front', label = 'Strawberry sheriff - front door', door = 1821044729, locked = true, jobs = { marshal = 0, strlaw = 0 }, items = { 'key_strawberry_jail' }, lockpickable = true, rsg = 14, distance = 2.5 }, -- p_door_val_bank02
    { id = 'str_sheriff_back', label = 'Strawberry sheriff - back door', door = 1514359658, locked = true, jobs = { marshal = 0, strlaw = 0 }, items = { 'key_strawberry_jail' }, lockpickable = true, rsg = 17, distance = 2.5 }, -- p_door37x
    { id = 'str_sheriff_cell1', label = 'Strawberry sheriff - cell 1', door = 902070893, locked = true, jobs = { marshal = 0, strlaw = 0 }, items = { 'key_strawberry_jail' }, lockpickable = true, rsg = 15 }, -- p_door_val_jail_cell01x
    { id = 'str_sheriff_cell2', label = 'Strawberry sheriff - cell 2', door = 1207903970, locked = true, jobs = { marshal = 0, strlaw = 0 }, items = { 'key_strawberry_jail' }, lockpickable = true, rsg = 16 }, -- p_door_val_jail_cell01x

    -- Saint Denis police headquarters (positions: RSG v2 rsg-doorlock)
    { id = 'sd_police_front', label = 'Saint Denis police - front doors', door = { 417663242, 1611175760 }, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 18, distance = 2.5 }, -- p_doornbd39a + p_doornbd39a
    { id = 'sd_police_inner_left', label = 'Saint Denis police - inner doors (left)', door = { 3601535313, 3430284519 }, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 19, distance = 2.5 }, -- p_door_nbx_doc01x_r + p_door_nbx_doc01x_l
    { id = 'sd_police_inner_right', label = 'Saint Denis police - inner doors (right)', door = { 3124713594, 1879655431 }, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 20, distance = 2.5 }, -- p_door_nbx_doc01x_r + p_door_nbx_doc01x_l
    { id = 'sd_police_side1', label = 'Saint Denis police - side doors 1', door = { 1020479727, 603068205 }, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 21, distance = 2.5 }, -- p_door_nbx_doc01x_l + p_door_nbx_doc01x_r
    { id = 'sd_police_side2', label = 'Saint Denis police - side doors 2', door = { 305296302, 2503834054 }, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 22, distance = 2.5 }, -- p_door_nbx_doc01x_l + p_door_nbx_doc01x_r
    { id = 'sd_police_back1', label = 'Saint Denis police - back doors 1', door = { 1992193795, 1694749582 }, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 23, distance = 2.5 }, -- p_door_nbx_doc01x_l + p_door_nbx_doc01x_r
    { id = 'sd_police_back2', label = 'Saint Denis police - back doors 2', door = { 1979938193, 1674105116 }, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 24, distance = 2.5 }, -- p_door_nbx_doc01x_l + p_door_nbx_doc01x_r
    { id = 'sd_police_cell1', label = 'Saint Denis police - cell 1', door = 3365520707, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 25 }, -- p_door_val_jail_cell01x
    { id = 'sd_police_cell2', label = 'Saint Denis police - cell 2', door = 1995743734, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 26 }, -- p_door_val_jail_cell01x
    { id = 'sd_police_cell3', label = 'Saint Denis police - cell 3', door = 1711767580, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 27 }, -- p_door_val_jail_cell01x
    { id = 'sd_police_cell4', label = 'Saint Denis police - cell 4', door = 2515591150, locked = true, jobs = { marshal = 0, stdenlaw = 0 }, items = { 'key_saintdenis_jail' }, lockpickable = true, rsg = 28 }, -- p_door_val_jail_cell01x

    -- Sisika Penitentiary (positions: RSG v2 rsg-doorlock, by mortimersays; front gates: its Config.JailDoors)
    { id = 'sisika_gate_outer', label = 'Sisika - main gate (outer)', door = { 3984556459, 906662604 }, locked = true, jobs = { marshal = 0 }, items = { 'key_sisika' }, lockpickable = false, rsg = { 29, 30 }, distance = 3.0 }, -- p_sis_frontgateb_l + p_sis_frontgateb_r
    { id = 'sisika_gate_inner', label = 'Sisika - main gate (inner)', door = { 2617210026, 1121239638 }, locked = true, jobs = { marshal = 0 }, items = { 'key_sisika' }, lockpickable = false, distance = 3.0 }, -- p_sis_frontgateb_l + p_sis_frontgateb_r
    { id = 'sisika_north_in', label = 'Sisika - north side gate (inside)', door = 2381465602, locked = true, jobs = { marshal = 0 }, items = { 'key_sisika' }, lockpickable = false, rsg = 31 }, -- p_doorlocked48a
    { id = 'sisika_north_out', label = 'Sisika - north side gate (outside)', door = 3158090902, locked = true, jobs = { marshal = 0 }, items = { 'key_sisika' }, lockpickable = false, rsg = 32 }, -- p_doorlocked48a
    { id = 'sisika_tower_ne', label = 'Sisika - north-east tower', door = 4249790129, locked = true, jobs = { marshal = 0 }, items = { 'key_sisika' }, lockpickable = false, rsg = 33 }, -- p_doorlocked48a
    { id = 'sisika_tower_e', label = 'Sisika - east tower', door = 2685529153, locked = true, jobs = { marshal = 0 }, items = { 'key_sisika' }, lockpickable = false, rsg = 36 }, -- p_doorlocked48a

    -- Other law offices: jail cells (hashes from the hash list; no town law job, so marshals)
    { id = 'ann_jail_block', label = 'Annesburg jail - cell block door', door = 2212368673, locked = true, jobs = { marshal = 0 }, items = { 'key_annesburg_jail' }, lockpickable = true }, -- ann_jail_main_door_01
    { id = 'ann_jail_cell1', label = 'Annesburg jail - cell 1', door = 1657401918, locked = true, jobs = { marshal = 0 }, items = { 'key_annesburg_jail' }, lockpickable = true }, -- ann_jail_cell_door_01
    { id = 'ann_jail_cell2', label = 'Annesburg jail - cell 2', door = 1502928852, locked = true, jobs = { marshal = 0 }, items = { 'key_annesburg_jail' }, lockpickable = true }, -- ann_jail_cell_door_01
    { id = 'arm_jail_cell1', label = 'Armadillo jail - cell 1', door = 4016307508, locked = true, jobs = { marshal = 0 }, items = { 'key_armadillo_jail' }, lockpickable = true }, -- p_door_val_jail_cell01x
    { id = 'arm_jail_cell2', label = 'Armadillo jail - cell 2', door = 4235597664, locked = true, jobs = { marshal = 0 }, items = { 'key_armadillo_jail' }, lockpickable = true }, -- p_door_val_jail_cell01x
    { id = 'tum_jail_cell1', label = 'Tumbleweed jail - cell 1', door = 2984805596, locked = true, jobs = { marshal = 0 }, items = { 'key_tumbleweed_jail' }, lockpickable = true }, -- p_door_val_jail_cell01x
    { id = 'tum_jail_cell2', label = 'Tumbleweed jail - cell 2', door = 2677989449, locked = true, jobs = { marshal = 0 }, items = { 'key_tumbleweed_jail' }, lockpickable = true }, -- p_door_val_jail_cell01x
    { id = 'tum_jail_cell3', label = 'Tumbleweed jail - cell 3', door = 831345624, locked = true, jobs = { marshal = 0 }, items = { 'key_tumbleweed_jail' }, lockpickable = true }, -- p_door_val_jail_cell01x
    { id = 'vh_jail_cell', label = 'Van Horn jail - cell', door = 4173092066, locked = true, jobs = { marshal = 0 }, items = { 'key_vanhorn_jail' }, lockpickable = true }, -- p_door_val_jail_cell02x

    -- Banks (door hashes: RSG v2 rsg-banking config, as in MULTIbank; front doors start open)
    { id = 'val_bank_front', label = 'Valentine bank - front doors', door = { 2642457609, 3886827663 }, locked = false, jobs = { banker = 0 }, items = { 'key_valentine_bank' }, lockpickable = true, distance = 2.5 }, -- p_door_val_bank00_lx + p_door_val_bank00_rx
    { id = 'val_bank_counter_r', label = 'Valentine bank - counter gate (right)', door = 1340831050, locked = true, jobs = { banker = 0 }, items = { 'key_valentine_bank' }, lockpickable = true }, -- p_gate_valbankvlt
    { id = 'val_bank_counter_l', label = 'Valentine bank - counter gate (left)', door = 2343746133, locked = true, jobs = { banker = 0 }, items = { 'key_valentine_bank' }, lockpickable = true }, -- p_gate_valbankvlt
    { id = 'val_bank_inner1', label = 'Valentine bank - inner door 1', door = 334467483, locked = true, jobs = { banker = 0 }, items = { 'key_valentine_bank' }, lockpickable = true }, -- p_door_val_bank01
    { id = 'val_bank_inner2', label = 'Valentine bank - inner door 2', door = 3718620420, locked = true, jobs = { banker = 0 }, items = { 'key_valentine_bank' }, lockpickable = true }, -- p_door_val_bank01
    { id = 'val_bank_vault', label = 'Valentine bank - vault', door = 576950805, locked = true, jobs = { banker = 0 }, items = { 'key_valentine_bank' }, lockpickable = false }, -- p_door_val_bankvault
    { id = 'rho_bank_front', label = 'Rhodes bank - front doors', door = { 3317756151, 3088209306 }, locked = false, jobs = { banker = 0 }, items = { 'key_rhodes_bank' }, lockpickable = true, distance = 2.5 }, -- p_doornbdaly01x + p_doornbdaly01x
    { id = 'rho_bank_inner1', label = 'Rhodes bank - inner door 1', door = 2058564250, locked = true, jobs = { banker = 0 }, items = { 'key_rhodes_bank' }, lockpickable = true }, -- p_door13x
    { id = 'rho_bank_inner2', label = 'Rhodes bank - inner door 2', door = 3142122679, locked = true, jobs = { banker = 0 }, items = { 'key_rhodes_bank' }, lockpickable = true }, -- p_doornbdaly01x
    { id = 'rho_bank_inner3', label = 'Rhodes bank - inner gate', door = 1634148892, locked = true, jobs = { banker = 0 }, items = { 'key_rhodes_bank' }, lockpickable = true }, -- p_gateundrtkr01x
    { id = 'rho_bank_vault', label = 'Rhodes bank - vault', door = 3483244267, locked = true, jobs = { banker = 0 }, items = { 'key_rhodes_bank' }, lockpickable = false }, -- p_door_val_bankvault
    { id = 'sd_bank_front1', label = 'Saint Denis bank - front doors 1', door = { 2158285782, 1733501235 }, locked = false, jobs = { banker = 0 }, items = { 'key_saintdenis_bank' }, lockpickable = true, distance = 2.5 }, -- p_door_nbx_bank03x_l + p_door_nbx_bank03x_r
    { id = 'sd_bank_front2', label = 'Saint Denis bank - front doors 2', door = { 2817024187, 2089945615 }, locked = false, jobs = { banker = 0 }, items = { 'key_saintdenis_bank' }, lockpickable = true, distance = 2.5 }, -- p_door_nbx_bank03x_l + p_door_nbx_bank03x_r
    { id = 'sd_bank_private', label = 'Saint Denis bank - private door', door = 1830999060, locked = true, jobs = { banker = 0 }, items = { 'key_saintdenis_bank' }, lockpickable = true }, -- p_door_nbxbank01x
    { id = 'sd_bank_manager', label = 'Saint Denis bank - manager doors', door = { 965922748, 1634115439 }, locked = true, jobs = { banker = 0 }, items = { 'key_saintdenis_bank' }, lockpickable = true }, -- p_door_nbxbank02x_l + p_door_nbxbank02x_r
    { id = 'sd_bank_vault', label = 'Saint Denis bank - vault', door = 1751238140, locked = true, jobs = { banker = 0 }, items = { 'key_saintdenis_bank' }, lockpickable = false }, -- p_door_val_bankvault02x
    { id = 'blk_bank_front', label = 'Blackwater bank - front door', door = 531022111, locked = false, jobs = { banker = 0 }, items = { 'key_blackwater_bank' }, lockpickable = true, distance = 2.5 }, -- p_door13x
    { id = 'blk_bank_inner', label = 'Blackwater bank - inner gate', door = 2117902999, locked = true, jobs = { banker = 0 }, items = { 'key_blackwater_bank' }, lockpickable = true }, -- p_gate_valbankvlt
    { id = 'blk_bank_manager', label = 'Blackwater bank - manager door', door = 2817192481, locked = true, jobs = { banker = 0 }, items = { 'key_blackwater_bank' }, lockpickable = true }, -- p_door_val_bank01
    { id = 'blk_bank_vault', label = 'Blackwater bank - vault', door = 1462330364, locked = true, jobs = { banker = 0 }, items = { 'key_blackwater_bank' }, lockpickable = false }, -- p_door_bla_bankvault
    { id = 'arm_bank_front', label = 'Armadillo bank - front door', door = 3101287960, locked = false, jobs = { banker = 0 }, items = { 'key_armadillo_bank' }, lockpickable = true, distance = 2.5 }, -- p_door_val_bank00_lx
    { id = 'arm_bank_inner1', label = 'Armadillo bank - inner gate', door = 3550475905, locked = true, jobs = { banker = 0 }, items = { 'key_armadillo_bank' }, lockpickable = true }, -- p_gate_valbankvlt
    { id = 'arm_bank_inner2', label = 'Armadillo bank - inner door', door = 1329318347, locked = true, jobs = { banker = 0 }, items = { 'key_armadillo_bank' }, lockpickable = true }, -- p_door_val_bank02
    { id = 'arm_bank_back', label = 'Armadillo bank - back door', door = 1366165179, locked = true, jobs = { banker = 0 }, items = { 'key_armadillo_bank' }, lockpickable = true }, -- p_doornbdaly01x

    -- Doctors (start open; medics lock up. Valentine: next to the rsg-medic point of RSG v2; Saint Denis: hash list)
    { id = 'val_doctor_front', label = 'Valentine doctor - street door', door = 3588026089, locked = false, jobs = { medic = 0 }, items = { 'key_valentine_doctor' }, lockpickable = true }, -- p_door62x
    { id = 'val_doctor_back', label = 'Valentine doctor - back room', door = 4067537969, locked = false, jobs = { medic = 0 }, items = { 'key_valentine_doctor' }, lockpickable = true }, -- p_door62x
    { id = 'sd_doctor_front1', label = 'Saint Denis doctor - doors 1', door = { 79213682, 3723126486 }, locked = false, jobs = { medic = 0 }, items = { 'key_saintdenis_doctor' }, lockpickable = true, distance = 2.5 }, -- p_door_nbx_doc01x_r + p_door_nbx_doc01x_l
    { id = 'sd_doctor_front2', label = 'Saint Denis doctor - doors 2', door = { 994323006, 82263429 }, locked = false, jobs = { medic = 0 }, items = { 'key_saintdenis_doctor' }, lockpickable = true, distance = 2.5 }, -- p_door_nbx_doc01x_l + p_door_nbx_doc01x_r
}

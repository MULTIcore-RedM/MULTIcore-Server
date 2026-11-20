-- ============================================================
-- MULTIstores :: the stores in the towns
-- Coordinates and clerk models come from RSG v2 (GPL v3, credited in CREDITS.md):
--   general stores, gunsmiths, saloons:  rsg-shops config.lua (Config.StoreLocations)
--   butchers:                            rsg-hunting config.lua (Config.ButcherLocations)
--   trappers:                            rsg-hunting config.lua (Config.Vendors)
--   doctor:                              rsg-medic config.lua (Config.MedicLocations)
-- Clerk models were checked against femga peds_list.lua.
--
-- Fields:
--   name     unique id; the general stores, gunsmiths and saloons keep rsg-shops' names so
--            'rsg-shops:server:openstore' finds them
--   type     a key of Config.Types (general, gunsmith, butcher, trapper, doctor, saloon)
--   town     locale key town_<town> (the store's name is built from it: "Valentine General Store")
--   label    optional full name instead (e.g. 'La Bastille'); not translated
--   coords   the counter: prompt / target / blip / server distance check
--   npc      clerk spot and heading (x, y, z, heading), or nil for no clerk
--   model    clerk model (default: the type's model)
--   products optional list name in config/products.lua (default: the type's list)
--   hours    optional { open = 6, close = 22 } or false (always open); default Config.Hours
--   jobs     optional { 'doctor', 'medic' } job names allowed to use the store (default: everyone)
--   jobType  optional job type allowed to use the store ('leo', 'medic')
--   onDuty   optional true = the job must be on duty
--   blip     false = no blip for this store
--   enabled  false = store is off
-- ============================================================

Config.Stores = {
    ---------------------------------
    -- general stores
    ---------------------------------
    { name = 'gen-valentine',  type = 'general', town = 'valentine',  coords = vector3(-324.14, 803.51, 117.88),   npc = vector4(-324.14, 803.51, 117.88, 280.98),   model = 'u_m_m_valgenstoreowner_01' },
    { name = 'gen-rhodes',     type = 'general', town = 'rhodes',     coords = vector3(1329.80, -1294.37, 77.02),  npc = vector4(1329.80, -1294.37, 77.02, 60.72),   model = 'u_m_m_rhdgenstoreowner_01' },
    { name = 'gen-stdenis',    type = 'general', town = 'saintdenis', coords = vector3(2859.36, -1202.19, 49.59),  npc = vector4(2859.36, -1202.19, 49.59, 14.85),   model = 'u_m_m_nbxgeneralstoreowner_01' },
    { name = 'gen-blackwater', type = 'general', town = 'blackwater', coords = vector3(-784.77, -1322.15, 43.88),  npc = vector4(-784.77, -1322.15, 43.88, 194.64),  model = 'u_m_o_blwgeneralstoreowner_01' },
    { name = 'gen-strawberry', type = 'general', town = 'strawberry', coords = vector3(-1789.78, -388.15, 160.33), npc = vector4(-1789.78, -388.15, 160.33, 65.43),  model = 'u_m_m_strgenstoreowner_01' },
    { name = 'gen-armadillo',  type = 'general', town = 'armadillo',  coords = vector3(-3687.35, -2623.34, -13.43), npc = vector4(-3687.35, -2623.34, -13.43, 276.71), model = 'u_m_m_armgeneralstoreowner_01' },
    { name = 'gen-tumbleweed', type = 'general', town = 'tumbleweed', coords = vector3(-5486.04, -2937.99, -0.40), npc = vector4(-5486.04, -2937.99, -0.40, 131.21), model = 's_m_m_unibutchers_01' },
    { name = 'gen-vanhorn',    type = 'general', town = 'vanhorn',    coords = vector3(3025.60, 562.29, 44.72),    npc = vector4(3025.60, 562.29, 44.72, 262.32),    model = 's_m_m_unibutchers_01' },
    { name = 'gen-annesburg',  type = 'general', town = 'annesburg',  coords = vector3(2930.97, 1365.38, 45.20),   npc = vector4(2930.97, 1365.38, 45.20, 252.02),   model = 'u_m_m_rhdgenstoreowner_02' },

    ---------------------------------
    -- gunsmiths
    ---------------------------------
    { name = 'wep-valentine',  type = 'gunsmith', town = 'valentine',  coords = vector3(-281.17, 778.94, 119.50),  npc = vector4(-281.17, 778.94, 119.50, 0.59),    model = 'u_m_m_valgunsmith_01' },
    { name = 'wep-rhodes',     type = 'gunsmith', town = 'rhodes',     coords = vector3(1322.31, -1323.02, 77.89), npc = vector4(1322.31, -1323.02, 77.89, 354.88), model = 'u_m_m_rhdgunsmith_01' },
    { name = 'wep-stdenis',    type = 'gunsmith', town = 'saintdenis', coords = vector3(2717.14, -1286.90, 49.64), npc = vector4(2717.14, -1286.90, 49.64, 29.91),  model = 'u_m_m_nbxgunsmith_01' },
    { name = 'wep-tumbleweed', type = 'gunsmith', town = 'tumbleweed', coords = vector3(-5506.41, -2963.95, -0.64), npc = vector4(-5506.41, -2963.95, -0.64, 110.02), model = 'u_m_m_tumgunsmith_01' },
    { name = 'wep-annesburg',  type = 'gunsmith', town = 'annesburg',  coords = vector3(2948.42, 1319.44, 44.82),  npc = vector4(2948.42, 1319.44, 44.82, 79.11),   model = 'u_m_m_asbgunsmith_01' },

    ---------------------------------
    -- butchers (meat, hearts, small game)
    ---------------------------------
    { name = 'butcher-valentine',  type = 'butcher', town = 'valentine',  coords = vector3(-341.05, 767.33, 116.70),   npc = vector4(-339.26, 767.70, 116.57, 103.16),   model = 'u_m_m_valbutcher_01' },
    { name = 'butcher-stdenis',    type = 'butcher', town = 'saintdenis', coords = vector3(2816.37, -1322.24, 46.61),  npc = vector4(2817.68, -1323.25, 46.61, 54.59) },
    { name = 'butcher-rhodes',     type = 'butcher', town = 'rhodes',     coords = vector3(1296.36, -1279.26, 75.84),  npc = vector4(1297.37, -1277.66, 75.88, 158.42) },
    { name = 'butcher-annesburg',  type = 'butcher', town = 'annesburg',  coords = vector3(2937.32, 1310.64, 44.48),   npc = vector4(2937.32, 1310.64, 44.48, 87.14) },
    { name = 'butcher-tumbleweed', type = 'butcher', town = 'tumbleweed', coords = vector3(-5508.10, -2947.73, -1.87), npc = vector4(-5509.83, -2947.27, -1.89, 256.49) },
    { name = 'butcher-blackwater', type = 'butcher', town = 'blackwater', coords = vector3(-751.10, -1284.90, 43.28),  npc = vector4(-753.01, -1284.84, 43.47, 267.18) },
    { name = 'butcher-strawberry', type = 'butcher', town = 'strawberry', coords = vector3(-1752.91, -394.74, 156.19), npc = vector4(-1753.14, -392.84, 156.24, 189.32) },
    { name = 'butcher-vanhorn',    type = 'butcher', town = 'vanhorn',    coords = vector3(2994.23, 571.79, 44.35),    npc = vector4(2992.47, 572.20, 44.37, 263.94) },

    ---------------------------------
    -- trappers (pelts, skins, hides and animal parts)
    ---------------------------------
    { name = 'trapper-valentine',  type = 'trapper', town = 'valentine',  coords = vector3(-333.97, 773.49, 116.22),   npc = vector4(-333.97, 773.49, 116.22, 111.88) },
    { name = 'trapper-tumbleweed', type = 'trapper', town = 'tumbleweed', coords = vector3(-5511.58, -2951.02, -1.84), npc = vector4(-5511.58, -2951.02, -1.84, 141.71) },
    { name = 'trapper-strawberry', type = 'trapper', town = 'strawberry', coords = vector3(-1745.48, -388.89, 156.64), npc = vector4(-1745.48, -388.89, 156.64, 108.08) },
    { name = 'trapper-rhodes',     type = 'trapper', town = 'rhodes',     coords = vector3(1300.53, -1274.23, 75.97),  npc = vector4(1300.53, -1274.23, 75.97, 172.25) },
    { name = 'trapper-stdenis',    type = 'trapper', town = 'saintdenis', coords = vector3(2832.45, -1223.80, 47.66),  npc = vector4(2832.45, -1223.80, 47.66, 184.55) },

    ---------------------------------
    -- doctors (only Valentine has a counter spot in RSG v2's configs; no clerk spot, so no clerk)
    ---------------------------------
    { name = 'doctor-valentine', type = 'doctor', town = 'valentine', coords = vector3(-287.59, 811.28, 118.59) },

    ---------------------------------
    -- saloons
    ---------------------------------
    { name = 'val-saloon',    type = 'saloon', town = 'valentine',  coords = vector3(-313.44, 806.14, 118.98),   npc = vector4(-313.44, 806.14, 118.98, 283.74),   model = 'u_m_o_valbartender_01' },
    { name = 'rho-saloon',    type = 'saloon', town = 'rhodes',     coords = vector3(1340.25, -1374.71, 80.48),  npc = vector4(1340.25, -1374.71, 80.48, 260.32),  model = 'u_m_m_rhdbartender_01' },
    { name = 'lab-saloon',    type = 'saloon', label = 'La Bastille', coords = vector3(2639.87, -1226.13, 53.38), npc = vector4(2639.87, -1226.13, 53.38, 90.83), model = 'u_m_m_nbxbartender_01' },
    { name = 'blk-saloon',    type = 'saloon', town = 'blackwater', coords = vector3(-817.69, -1319.29, 43.68),  npc = vector4(-817.69, -1319.29, 43.68, 281.47) },
    { name = 'tumble-saloon', type = 'saloon', town = 'tumbleweed', coords = vector3(-5518.50, -2906.52, -1.75), npc = vector4(-5518.50, -2906.52, -1.75, 216.14), model = 'u_m_m_tumbartender_01' },
    { name = 'ann-saloon',    type = 'saloon', town = 'annesburg',  coords = vector3(2964.36, 1358.28, 44.86),   npc = vector4(2964.36, 1358.28, 44.86, 357.19) },
    { name = 'old-saloon',    type = 'saloon', label = 'Old Light Saloon',coords = vector3(2948.17, 528.08, 45.34),    npc = vector4(2948.17, 528.08, 45.34, 182.96) },
}

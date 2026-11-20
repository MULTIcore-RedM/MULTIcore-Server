-- ============================================================
-- MULTItelegram post offices
-- Counter coordinates from rsg-telegram's Config.PostOfficeLocations
-- (RSG v2 framework, GPL v3, credited in CREDITS.md).
--
-- id:     short unique name (keep it stable)
-- label:  locale key of the office name (locales/*.lua)
-- coords: the counter (prompt / target / server distance check)
-- npc:    optional clerk spot (x, y, z, heading). None ship: no verified
--         clerk spots exist for these counters. Stand behind the counter
--         in game, read your position and heading, and add e.g.
--         npc = vector4(-179.5, 628.0, 114.09, 180.0)
-- blip:   show a map blip
-- ============================================================
Config.Offices = {
    { id = 'valentine',    label = 'office_valentine',    coords = vector3(-178.9489, 626.83941, 114.08961),  blip = true },
    { id = 'rhodes',       label = 'office_rhodes',       coords = vector3(1225.57, -1293.87, 76.91),         blip = true },
    { id = 'saintdenis',   label = 'office_saintdenis',   coords = vector3(2731.55, -1402.37, 46.18),         blip = true },
    { id = 'vanhorn',      label = 'office_vanhorn',      coords = vector3(2986.1557, 568.51599, 44.627922),  blip = true },
    { id = 'annesburg',    label = 'office_annesburg',    coords = vector3(2939.5173, 1288.5345, 44.652824),  blip = true },
    { id = 'wallace',      label = 'office_wallace',      coords = vector3(-1299.277, 401.93942, 95.383865),  blip = true },
    { id = 'riggs',        label = 'office_riggs',        coords = vector3(-1094.87, -575.608, 82.410873),    blip = true },
    { id = 'flatneck',     label = 'office_flatneck',     coords = vector3(-875.054, -1328.753, 43.958003),   blip = true },
    { id = 'armadillo',    label = 'office_armadillo',    coords = vector3(-3733.965, -2597.86, -12.92674),   blip = true },
    { id = 'tumbleweed',   label = 'office_tumbleweed',   coords = vector3(-5487.083, -2936.11, -0.402813),   blip = true },
    { id = 'strawberry',   label = 'office_strawberry',   coords = vector3(-1765.084, -384.1582, 157.74119),  blip = true },
    { id = 'emeraldranch', label = 'office_emeraldranch', coords = vector3(1522.04, 439.54, 90.68),           blip = true },
}

-- ============================================================
-- MULTIhorses :: stables
-- Locations, stable hand spots and models are taken from rsg-horses'
-- Config.StableSettings (RSG v2 framework, GPL v3; see CREDITS.md).
-- Stable hand models checked against femga peds_list.lua.
--
-- id:     stable name (saved in player_horses.stable, same names as rsg-horses)
-- label:  locale key of the town name
-- coords: where the stable hand stands (the menu is used here; the server checks the distance)
-- npc:    stable hand spot (x, y, z, heading)
-- model:  stable hand model
-- blip:   false = no map blip for this stable
-- ============================================================

Config.Stables = {
    { id = 'valentine',    label = 'stable_valentine',    coords = vector3(-365.2, 791.94, 116.18),    npc = vector4(-365.2, 791.94, 116.18, 180.9),    model = 'u_m_m_bwmstablehand_01' },
    { id = 'blackwater',   label = 'stable_blackwater',   coords = vector3(-876.85, -1365.55, 43.53),  npc = vector4(-876.85, -1365.55, 43.53, 275.38), model = 'u_m_m_bwmstablehand_01' },
    { id = 'strawberry',   label = 'stable_strawberry',   coords = vector3(-1817.1, -568.64, 155.98),  npc = vector4(-1817.1, -568.64, 155.98, 254.85), model = 'u_m_m_bwmstablehand_01' },
    { id = 'rhodes',       label = 'stable_rhodes',       coords = vector3(1211.55, -190.84, 101.39),  npc = vector4(1211.55, -190.84, 101.39, 100.22), model = 'u_m_m_bwmstablehand_01' },
    { id = 'saintdenis',   label = 'stable_saintdenis',   coords = vector3(2512.28, -1457.33, 46.31),  npc = vector4(2512.28, -1457.33, 46.31, 86.43),  model = 'u_m_m_bwmstablehand_01' },
    { id = 'vanhorn',      label = 'stable_vanhorn',      coords = vector3(2968.86, 792.97, 51.4),     npc = vector4(2968.86, 792.97, 51.4, 357.89),    model = 'u_m_m_bwmstablehand_01' },
    { id = 'emeraldranch', label = 'stable_emeraldranch', coords = vector3(1393.90, 354.29, 87.66),    npc = vector4(1393.90, 354.29, 87.66, 151.53),   model = 'mp_de_u_f_m_doverhill_01' },
    { id = 'colter',       label = 'stable_colter',       coords = vector3(-1334.2, 2397.41, 307.21),  npc = vector4(-1334.2, 2397.41, 307.21, 67.43),  model = 'u_m_m_bwmstablehand_01' },
    { id = 'tumbleweed',   label = 'stable_tumbleweed',   coords = vector3(-5514.81, -3040.25, -2.39), npc = vector4(-5514.81, -3040.25, -2.39, 175.22), model = 'u_m_m_bwmstablehand_01' },
}

-- Where a horse bought by another script (e.g. a starter horse with no stable) is kept.
Config.DefaultStable = 'valentine'

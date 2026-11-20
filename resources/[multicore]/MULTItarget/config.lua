-- ============================================================
-- MULTItarget :: config
-- MULTIcore's own target system (hold Left Alt). Every option has a one-line comment.
-- ============================================================

Config = {}

Config.Debug = false              -- print rsg-target calls, failed canInteract checks and anything unsupported (F8)

-- 'hold'   = hold Left Alt to target (default)
-- 'toggle' = press Left Alt to switch targeting on, press again to switch it off
Config.Mode = 'hold'

Config.DefaultDistance = 2.5      -- interaction distance (metres) when neither the option nor its zone sets one
Config.RayDistance = 8.0          -- how far the look ray reaches (metres)
Config.RayIntervalMs = 60         -- how often (ms) the look ray is cast while targeting
Config.RayFlags = 511             -- what the ray can hit (511 = everything: map, wagons, peds, objects ...)
Config.BoneDistance = 1.2         -- options tied to bones (wagon doors, wheels ...) show within this many metres of the bone
Config.Scale = 1.0                -- size of the brackets and the option list (1 = normal, 1.2 = 20% bigger)

-- Keys (control hashes from the game's control list; see README to change them)
Config.Keys = {
    Target = 0x8AAA0AD4,          -- PcFreeLook (Left Alt): hold to target
    Select = { 0x07CE1E61, 0xCEFD9220, 0xC7B5340A }, -- Attack (left mouse), E, FrontendAccept (Enter)
    Down   = { 0xCC1075A7, 0xD0842EDF, 0x05CA7C52 }, -- mouse wheel (PrevWeapon / SelectNextWeapon), FrontendDown (arrow down)
    Up     = { 0xFD0F0C2C, 0xF78D7337, 0x6319DB71 }, -- mouse wheel (NextWeapon / SelectPrevWeapon), FrontendUp (arrow up)
    Cursor = { 0xF84FA74F },                         -- Aim (right mouse): free the cursor to click an option
    LookLr = 0xA987235F,          -- camera left / right (held still while the cursor is free)
    LookUd = 0xD2047988,          -- camera up / down
    -- turned off while targeting, so picking an option does not shoot, punch or swap weapons
    Block = { 0x07CE1E61, 0xF84FA74F, 0xAC4BD4F1, 0xB2F377E8, 0xADEAF48C, 0x73846677, 0x0AF99998,
              0xCC1075A7, 0xFD0F0C2C, 0xD0842EDF, 0xF78D7337, 0xCEFD9220 },
}

-- Zones made from PolyZone-style boxes / polys that give no minZ / maxZ (rsg-target / qb-target calls)
Config.Zone = {
    DefaultHeight = 4.0,          -- box / poly height (metres) around the given centre when no minZ / maxZ is given
    NoZCentre = 450.0,            -- centre height for a 2D poly (points without z) and no minZ / maxZ
    NoZThickness = 1000.0,        -- thickness for that 2D poly (covers the whole map height)
    Debug = false,                -- kept for rsg-target calls that ask for it; MULTItarget never draws zones
}

-- ============================================================
-- MULTItarget :: config
-- MULTIcore's own target system. Works like rsg-target: hold Left Alt, left mouse, click an option. Every option has a one-line comment.
-- ============================================================

Config = {}

Config.Debug = false              -- print rsg-target calls, failed canInteract checks and anything unsupported (F8)

-- 'hold'   = hold Left Alt to target (default)
-- 'toggle' = press Left Alt to switch targeting on, press again to switch it off
Config.Mode = 'hold'

Config.DefaultDistance = 2.5      -- interaction distance (metres) when neither the option nor its zone sets one
Config.RayDistance = 20.0         -- how far the look ray reaches from the camera (metres; each option's own distance still applies)
Config.RayIntervalMs = 60         -- how often (ms) the look ray is cast while targeting
Config.EntityRayFlags = 30        -- first ray: people, animals, wagons and objects only (2 + 4 + 8 + 16), so grass and bushes never block it
Config.RayFlags = 511             -- second ray, used when the first finds nothing: the world, for zones (511 = everything)
Config.BoneDistance = 1.2         -- options tied to bones (wagon doors, wheels ...) show within this many metres of the bone
Config.Scale = 1.0                -- size of the eye and the option list (1 = normal, 1.2 = 20% bigger)

-- Keys (control hashes from the game's control list; see README to change them)
Config.Keys = {
    Target = 0x8AAA0AD4,          -- PcFreeLook (Left Alt): hold to target
    Click  = { 0x07CE1E61, 0x07B8BEAF },             -- Attack / ContextRt (left mouse): bring the cursor out to click an option
    LookLr = 0xA987235F,          -- camera left / right (held still while the cursor is out)
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

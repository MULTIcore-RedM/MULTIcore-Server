-- ============================================================
-- MULTIlaw :: places
-- Law offices and their bounty boards come from rsg-lawman's
-- Config.LawOfficeLocations (RSG v2, GPL v3). Sisika comes from
-- rsg-prison's config. Town cell spots are the cell door positions of
-- rsg-adminmenu's door list: check them in game and move each spot a
-- step into its cell if needed. `label` values are locale keys.
-- ============================================================

-- Law offices: records, evidence locker, bounty posting. `job` = the job whose evidence locker this is.
Config.OfficesOpenToAllLaw = true   -- true = every lawman may use every office; false = only the office's own job
Config.Offices = {
    { id = 'valentine',  label = 'place_valentine',  job = 'vallaw',   coords = vector3(-278.42, 805.29, 119.38) },
    { id = 'rhodes',     label = 'place_rhodes',     job = 'rholaw',   coords = vector3(1362.04, -1302.10, 77.77) },
    { id = 'blackwater', label = 'place_blackwater', job = 'blklaw',   coords = vector3(-761.76, -1268.18, 44.04) },
    { id = 'strawberry', label = 'place_strawberry', job = 'strlaw',   coords = vector3(-1811.95, -353.94, 164.65) },
    { id = 'saintdenis', label = 'place_saintdenis', job = 'stdenlaw', coords = vector3(2507.72, -1301.89, 48.95) },
}
-- Evidence from a lawman whose job has no office above (marshals, the court) goes to this office's locker.
Config.DefaultEvidenceOffice = 'valentine'

-- Bounty boards anyone can read. Default: at each law office (move them to the boards outside if you like).
Config.Boards = {
    { label = 'place_valentine',  coords = vector3(-278.42, 805.29, 119.38) },
    { label = 'place_rhodes',     coords = vector3(1362.04, -1302.10, 77.77) },
    { label = 'place_blackwater', coords = vector3(-761.76, -1268.18, 44.04) },
    { label = 'place_strawberry', coords = vector3(-1811.95, -353.94, 164.65) },
    { label = 'place_saintdenis', coords = vector3(2507.72, -1301.89, 48.95) },
}

-- Town cells. spot = where the prisoner stands (x, y, z, heading), radius = how far he may move,
-- release = where he is let out. Several cells in one town are filled in turn.
Config.Cells = {
    { id = 'valentine_1',  label = 'place_valentine',  spot = vector4(-272.05, 808.26, 118.37, 0.0),    radius = 3.0, release = vector4(-278.42, 805.29, 119.38, 0.0) },
    { id = 'valentine_2',  label = 'place_valentine',  spot = vector4(-273.46, 809.97, 118.37, 0.0),    radius = 3.0, release = vector4(-278.42, 805.29, 119.38, 0.0) },
    { id = 'valentine_3',  label = 'place_valentine',  spot = vector4(-275.02, 809.27, 118.37, 0.0),    radius = 3.0, release = vector4(-278.42, 805.29, 119.38, 0.0) },
    { id = 'rhodes_1',     label = 'place_rhodes',     spot = vector4(1357.33, -1302.45, 76.76, 0.0),   radius = 3.0, release = vector4(1362.04, -1302.10, 77.77, 0.0) },
    { id = 'strawberry_1', label = 'place_strawberry', spot = vector4(-1814.40, -353.15, 160.44, 0.0),  radius = 3.0, release = vector4(-1811.95, -353.94, 164.65, 0.0) },
    { id = 'strawberry_2', label = 'place_strawberry', spot = vector4(-1812.01, -351.92, 160.47, 0.0),  radius = 3.0, release = vector4(-1811.95, -353.94, 164.65, 0.0) },
    { id = 'saintdenis_1', label = 'place_saintdenis', spot = vector4(2502.43, -1307.86, 47.95, 0.0),   radius = 3.0, release = vector4(2507.72, -1301.89, 48.95, 0.0) },
    { id = 'saintdenis_2', label = 'place_saintdenis', spot = vector4(2499.75, -1309.88, 47.95, 0.0),   radius = 3.0, release = vector4(2507.72, -1301.89, 48.95, 0.0) },
    { id = 'saintdenis_3', label = 'place_saintdenis', spot = vector4(2503.64, -1309.88, 47.95, 0.0),   radius = 3.0, release = vector4(2507.72, -1301.89, 48.95, 0.0) },
    { id = 'saintdenis_4', label = 'place_saintdenis', spot = vector4(2498.50, -1307.86, 47.95, 0.0),   radius = 3.0, release = vector4(2507.72, -1301.89, 48.95, 0.0) },
    { id = 'annesburg_1',  label = 'place_annesburg',  spot = vector4(2904.27, 1314.34, 43.94, 0.0),    radius = 3.0, release = vector4(2911.14, 1309.81, 43.93, 0.0) },
    { id = 'annesburg_2',  label = 'place_annesburg',  spot = vector4(2902.96, 1310.87, 43.94, 0.0),    radius = 3.0, release = vector4(2911.14, 1309.81, 43.93, 0.0) },
}

-- Sisika penitentiary (rsg-prison). The prisoner may walk the grounds within `radius` of `center`.
Config.Prison = {
    label = 'place_sisika',
    center = vector3(3357.41, -679.26, 46.26),
    radius = 55.0,
    spawns = {
        vector4(3330.66, -692.75, 43.95, 292.86),
        vector4(3349.62, -650.41, 45.38, 207.53),
        vector4(3380.62, -672.35, 46.27, 110.95),
        vector4(3366.75, -666.08, 46.34, 297.69),
    },
    release = vector4(3340.71, -629.99, 43.72, 36.36),
    blip = vector3(3352.11, -690.77, 44.25),
}

-- Sisika uniform (rsg-prison's shop items). Categories taken off first, then the pieces put on.
Config.PrisonOutfit = {
    remove = {
        0x9925C067, 0x485EE834, 0x18729F39, 0x3107499B, 0x3C1A74CD, 0x3F1F01E5, 0x3F7F3587, 0x49C89D9B,
        0x4A73515C, 0x514ADCEA, 0x5FC29285, 0x79D7DF96, 0x7A96FACA, 0x877A2CF7, 0x9B2C8B89, 0xA6D134C6,
        0xE06D30CE, 0x662AC34, 0xAF14310B, 0x72E6EF74, 0xEABE0032, 0x2026C46D, 0xB6B6122D, 0xB9E2FA01,
    },
    male = { 0x5BA76CCF, 0x216612F0, 0x1CCEE58D },
    female = { 0x6AB27695, 0x75BC0CF5, 0x14683CDF },
}

-- ============================================================
-- MULTIcamps :: places where no camp may be pitched
-- A camp's tent must stand outside every circle below. Centres are rough
-- middles of each place (map x / y, metres), the same ones MULTIdoors uses
-- (config/towns.lua there). Move, grow, add or remove places freely.
-- ============================================================

Config = Config or {}

-- name: shown in the "too close to <name>" message as it is (place names are not translated)
-- x, y: centre of the place
-- radius: metres from the centre where camps are not allowed
Config.NoCampZones = {
    { name = 'Saint Denis',          x = 2560.0,  y = -1230.0, radius = 650.0 },
    { name = 'Valentine',            x = -290.0,  y = 760.0,   radius = 350.0 },
    { name = 'Rhodes',               x = 1310.0,  y = -1310.0, radius = 320.0 },
    { name = 'Blackwater',           x = -800.0,  y = -1300.0, radius = 350.0 },
    { name = 'Strawberry',           x = -1790.0, y = -400.0,  radius = 300.0 },
    { name = 'Armadillo',            x = -3670.0, y = -2600.0, radius = 300.0 },
    { name = 'Tumbleweed',           x = -5500.0, y = -2940.0, radius = 300.0 },
    { name = 'Annesburg',            x = 2930.0,  y = 1330.0,  radius = 350.0 },
    { name = 'Van Horn',             x = 2970.0,  y = 540.0,   radius = 280.0 },
    { name = 'Emerald Ranch',        x = 1410.0,  y = 320.0,   radius = 260.0 },
    { name = 'Butcher Creek',        x = 2550.0,  y = 780.0,   radius = 220.0 },
    { name = 'Braithwaite Manor',    x = 1000.0,  y = -1800.0, radius = 260.0 },
    { name = 'Caliga Hall',          x = 1880.0,  y = -1360.0, radius = 200.0 },
    { name = 'Sisika Penitentiary',  x = 3330.0,  y = -670.0,  radius = 400.0 },
    { name = 'Thieves Landing',      x = -1400.0, y = -2260.0, radius = 250.0 },
    { name = "MacFarlane's Ranch",   x = -2410.0, y = -2390.0, radius = 260.0 },
    { name = "Beecher's Hope",       x = -1620.0, y = -1400.0, radius = 200.0 },
    { name = 'Manzanita Post',       x = -1920.0, y = -1680.0, radius = 200.0 },
    { name = 'Benedict Point',       x = -5225.0, y = -3470.0, radius = 200.0 },
    { name = 'Colter',               x = -1350.0, y = 2420.0,  radius = 200.0 },
    { name = 'Wapiti',               x = 470.0,   y = 2210.0,  radius = 200.0 },
    { name = 'Flatneck Station',     x = -330.0,  y = -350.0,  radius = 150.0 },
    { name = 'Riggs Station',        x = -1095.0, y = -580.0,  radius = 150.0 },
    { name = 'Wallace Station',      x = -1305.0, y = 395.0,   radius = 150.0 },
    { name = 'Bacchus Station',      x = 580.0,   y = 1690.0,  radius = 150.0 },
}

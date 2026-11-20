Config = Config or {}

--[[
    TAILOR SHOPS IN CONFIG

    UseConfigLocations = true loads the shops below. A job placement tool can add more points live
    through MULTItailor's dynamic-location API (server/10_points.lua); set this to false if every
    shop is placed that way.

    One entry per town job:
        bench    = cutting table (Outfit Designer + sewing)       - required
        counter  = shop counter (shelf, orders)                   - optional
        boss     = till / boss panel                              - optional
        storage  = stockroom stash                                - optional
        designer = { ped = vector4, cam = vector3 }  fitting dummy + camera (Config.Designer.placement = 'fittingroom')
    The benches stand inside the towns' clothing stores, the dummy in their fitting rooms. Counter /
    boss / storage spots are default positions: check them in game and adjust to your map if needed.
]]
Config.UseConfigLocations = true

Config.Locations = {
    valtailor = {
        bench = vector3(-326.10, 774.48, 117.46),
        counter = vector3(-324.20, 772.30, 117.46),               -- default position, check in game
        boss = vector3(-327.60, 771.90, 117.46),                  -- default position, check in game
        storage = vector3(-328.40, 773.60, 117.46),               -- default position, check in game
        designer = { ped = vector4(-329.43, 775.29, 121.63, 278.17), cam = vector3(-327.38, 775.48, 122.00) },
    },
    stdentailor = {
        bench = vector3(2552.40, -1165.22, 53.73),
        counter = vector3(2554.30, -1166.90, 53.73),              -- default position, check in game
        boss = vector3(2550.60, -1163.40, 53.73),                 -- default position, check in game
        storage = vector3(2550.20, -1166.70, 53.73),              -- default position, check in game
        designer = { ped = vector4(2556.66, -1159.76, 53.75, 191.14), cam = vector3(2556.56, -1161.72, 54.10) },
    },
    rhodestailor = {
        bench = vector3(1324.66, -1291.59, 77.08),
        counter = vector3(1322.60, -1293.30, 77.08),              -- default position, check in game
        boss = vector3(1326.40, -1289.90, 77.08),                 -- default position, check in game
        storage = vector3(1326.90, -1293.10, 77.08),              -- default position, check in game
        designer = { ped = vector4(1324.24, -1287.88, 77.07, 164.22), cam = vector3(1323.14, -1290.03, 77.72) },
    },
    blacktailor = {
        bench = vector3(-761.61, -1291.98, 43.85),
        counter = vector3(-759.80, -1293.60, 43.85),              -- default position, check in game
        boss = vector3(-763.40, -1290.30, 43.85),                 -- default position, check in game
        storage = vector3(-763.70, -1293.40, 43.85),              -- default position, check in game
        designer = { ped = vector4(-767.98, -1294.88, 43.83, 263.09), cam = vector3(-765.86, -1295.02, 44.14) },
    },
}

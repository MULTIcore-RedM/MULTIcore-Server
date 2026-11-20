-- ============================================================
-- MULTIwagons dealers and call points
-- Dealer places are from RSG v2's rsg-wagons config (GPL v3, Phil and mack /
-- Rexshack-RedM, see CREDITS.md): coords = where the player stands,
-- npc = the clerk, spawn = where a bought or taken-out wagon appears
-- (rsg-wagons' preview spot).
--   name   unique id (also the locale key 'place_<name>' for its label)
--   coords where the prompt / target is
--   npc    clerk spot vector4 (nil = no clerk)
--   spawn  vector4 where wagons appear here
--   blip   false = no map blip
-- ============================================================

Config.Dealers = {
    { name = 'valentine',  coords = vector3(-355.11, 775.18, 116.22),    npc = vector4(-355.11, 775.18, 116.22, 321.41),    spawn = vector4(-353.43, 788.54, 116.15, 274.7) },
    { name = 'saintdenis', coords = vector3(2506.02, -1459.52, 46.37),   npc = vector4(2506.02, -1459.52, 46.37, 66.78),    spawn = vector4(2502.689, -1441.257, 45.313, 177.895) },
    { name = 'strawberry', coords = vector3(-1811.18, -555.63, 155.98),  npc = vector4(-1811.18, -555.63, 155.98, 265.87),  spawn = vector4(-1821.550, -561.547, 155.060, 253.239) },
    { name = 'blackwater', coords = vector3(-870.62, -1370.70, 43.62),   npc = vector4(-870.62, -1370.70, 43.62, 40.36),    spawn = vector4(-865.77, -1366.23, 43.49, 88.50) },
    { name = 'tumbleweed', coords = vector3(-5515.295, -3039.497, -2.388), npc = vector4(-5515.295, -3039.497, -2.388, 182.161), spawn = vector4(-5522.063, -3044.438, -3.388, 265.561) },
    { name = 'caliga',     coords = vector3(1894.08, -1320.43, 42.66),   npc = vector4(1894.08, -1320.43, 42.66, 329.71),   spawn = vector4(1902.91, -1319.31, 42.57, 246.61) },
}

-- Call points: places with no dealer where an owner can take out and put away his wagons
-- (same fields as a dealer, without npc). Every dealer is a call point too.
-- Example:
--   { name = 'rhodes', coords = vector3(1234.5, -1300.0, 76.9), spawn = vector4(1240.0, -1302.0, 76.9, 90.0) },
-- Give each a 'place_<name>' line in the locales.
Config.CallPoints = {
}

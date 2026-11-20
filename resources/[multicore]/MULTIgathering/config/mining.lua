-- ============================================================
-- MULTIgathering :: mining spots and what they give
-- A spot is a rock face the player works with a pickaxe (prompt within `radius`).
-- Each finished swing uses one charge; an empty spot is "worked out" until it refills.
--   id             unique id (letters, digits, _)
--   mine           locale key mine_<mine> for the blip and notes
--   coords         the rock face (height may be a few metres off: Config.ZTolerance)
--   radius         how close the player must stand (metres, flat distance)
--   charges        swings before the spot is worked out
--   respawnMinutes minutes until a worked-out spot is full again
--   rewards        a key of Config.MiningRewards
--
-- !! The coordinates below are approximate (UNVERIFIED in game): the Annesburg coal mine above
--    Annesburg and Gaptooth Breach west of Tumbleweed. No free RSG v2 resource ships mine
--    coordinates. Stand at the rock face and use  /gatherspot  (admin) to print a ready line.
-- ============================================================

Config.MiningSpots = {
    -- Annesburg coal mine, Roanoke Ridge (coal, iron, lead)
    { id = 'annesburg_1', mine = 'annesburg', coords = vector3(2785.0, 1355.0, 71.5), radius = 6.0, charges = 6, respawnMinutes = 15, rewards = 'coal' },
    { id = 'annesburg_2', mine = 'annesburg', coords = vector3(2770.0, 1370.0, 72.0), radius = 6.0, charges = 6, respawnMinutes = 15, rewards = 'coal' },
    { id = 'annesburg_3', mine = 'annesburg', coords = vector3(2795.0, 1375.0, 74.0), radius = 6.0, charges = 6, respawnMinutes = 15, rewards = 'coal' },
    -- Gaptooth Breach, near Tumbleweed (copper, lead, sulfur, nitrate, a little silver and gold)
    { id = 'gaptooth_1', mine = 'gaptooth', coords = vector3(-5960.0, -3210.0, -21.0), radius = 6.0, charges = 6, respawnMinutes = 15, rewards = 'desert' },
    { id = 'gaptooth_2', mine = 'gaptooth', coords = vector3(-5975.0, -3195.0, -20.0), radius = 6.0, charges = 6, respawnMinutes = 15, rewards = 'desert' },
    { id = 'gaptooth_3', mine = 'gaptooth', coords = vector3(-5945.0, -3225.0, -22.0), radius = 6.0, charges = 6, respawnMinutes = 15, rewards = 'desert' },
}

-- Reward tables. Every line is rolled on its own: `chance` in % (decimals allowed), then
-- min..max of the item. `fallback` is given when no line hits, so a swing is never empty.
-- Items are MULTIcore's existing mining items (shared/items.lua).
Config.MiningRewards = {
    coal = {
        { item = 'resource_coal',     chance = 60, min = 1, max = 2 },
        { item = 'resource_rock',     chance = 40, min = 1, max = 2 },
        { item = 'resource_iron',     chance = 20, min = 1, max = 1 },
        { item = 'resource_lead_ore', chance = 12, min = 1, max = 1 },
        fallback = { item = 'resource_rock', amount = 1 },
    },
    desert = {
        { item = 'resource_rock',        chance = 40, min = 1, max = 2 },
        { item = 'resource_copper_ore',  chance = 25, min = 1, max = 1 },
        { item = 'resource_lead_ore',    chance = 20, min = 1, max = 1 },
        { item = 'resource_sulfur',      chance = 15, min = 1, max = 1 },
        { item = 'resource_nitrate',     chance = 15, min = 1, max = 1 },
        { item = 'resource_silver_ore',  chance = 3,  min = 1, max = 1 },
        { item = 'resource_gold_nugget', chance = 1,  min = 1, max = 1 },
        fallback = { item = 'resource_rock', amount = 1 },
    },
}

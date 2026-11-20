-- ============================================================
-- MULTIvorpchar :: config
-- Every option has a one-line comment and its default.
-- MULTIvorpchar shows no text to players, so it has no locales.
-- ============================================================

Config = {}

Config.Debug = false                  -- print every vorp_character call that is translated or ignored (F8 / server console)

-- vorp_character's "reload my character" chat command. VORP scripts run it after changing clothes
-- (ExecuteCommand('rc')). It puts the saved MULTIcore look back on. '' = do not register a command.
Config.ReloadCommand = 'rc'

-- Longest wait (ms) for a clothes / skin save to reach the server before a reload puts the look on.
Config.SaveWaitMs = 3000

-- vorp_character's clothing keys (what scripts pass to GetPlayerComponent and updateCache) ->
-- MULTIcore clothing category (MULTIcore data/clothes.lua). A piece sent with a hash is placed in the
-- category the game data says it belongs to; this list is used to find, and to take off, a key's piece.
Config.Keys = {
    Hat = 'hats', Mask = 'masks', EyeWear = 'eyewear', NeckWear = 'neckwear', NeckTies = 'neckties',
    Coat = 'coats', CoatClosed = 'coats_closed', Vest = 'vests', Shirt = 'shirts_full',
    Suspender = 'suspenders', Poncho = 'ponchos', Cloak = 'cloaks', Glove = 'gloves',
    Gunbelt = 'gunbelts', Holster = 'holsters_left', Belt = 'belts', Buckle = 'belt_buckles',
    Satchels = 'satchels', Pant = 'pants', Skirt = 'skirts', Chap = 'chaps', Boots = 'boots',
    Spurs = 'boot_accessories', Spats = 'spats', Loadouts = 'loadouts', Armor = 'armor',
    Accessories = 'accessories', RingRh = 'jewelry_rings_right', RingLh = 'jewelry_rings_left',
    Bracelet = 'jewelry_bracelets', Gauntlets = 'gauntlets', GunbeltAccs = 'gunbelt_accs',
    Badge = 'badges', Dress = 'dresses',
}

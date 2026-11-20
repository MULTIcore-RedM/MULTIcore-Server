-- ============================================================
-- MULTIhunting :: settings
-- Basic hunting for MULTIcore: skinning an animal (the game's own skinning) gives
-- MULTIinventory items that MULTIstores' trappers and butchers buy.
-- What each animal gives: config/animals.lua
-- ============================================================

Config = Config or {}

Config.Locale = nil                 -- default nil (use setr multicore_locale, else 'en'); e.g. 'de'
Config.Debug = false                -- default false (true = print every reward and refusal in the server console)

---------------------------------
-- detection (client)
---------------------------------
Config.LootEvent = 1376140891       -- default 1376140891 (the game's loot-complete event, as rsg-hunting reads it)
Config.EventPollMs = 0              -- default 0 (ms between event-queue checks; 0 = every frame, events are lost otherwise)
Config.ClientThrottleMs = 1000      -- default 1000 (ignore a second loot event within this many ms on the client)
Config.RewardDelayMs = 1000         -- default 1000 (wait for the game to finish handing over the pelt before asking the server)

---------------------------------
-- the game's own pelt
---------------------------------
-- After skinning, the game puts a pelt on the player's shoulder (it can be laid on the horse).
-- With MULTIhunting the pelt is an inventory item, so the carried copy is removed:
-- otherwise the same skin exists twice (item + carried pelt that another script could sell).
Config.RemoveCarriedPelt = true     -- default true (delete the pelt / small animal the game puts in the player's hands)
Config.DeleteCarcass = false        -- default false (true = remove the skinned carcass a moment later)
Config.DeleteCarcassDelayMs = 1000  -- default 1000 (wait before removing the carcass)

---------------------------------
-- quality
---------------------------------
-- The grade comes from the game: the animal's quality (_GET_PED_QUALITY: 0 poor, 1 good, 2 perfect)
-- and how cleanly it was killed (_GET_PED_DAMAGE_CLEANLINESS: 0 poor, 1 good, 2 perfect).
Config.Quality = {
    Mode = 'min',                   -- default 'min' ('min' = the lower of the two, 'quality' = animal only, 'cleanliness' = kill only)
    Default = 1,                    -- default 1 (grade used when the game gives none: 0 poor, 1 good, 2 perfect)
    Percent = {                     -- info.quality put on the pelt for each grade (MULTIstores pays price x quality / 100)
        [0] = 40,                   -- default 40 (poor)
        [1] = 70,                   -- default 70 (good)
        [2] = 100,                  -- default 100 (perfect)
    },
}

Config.MeatItem = 'raw_meat'        -- default 'raw_meat' (meat item, bought by MULTIstores' butchers)

---------------------------------
-- rules (server)
---------------------------------
Config.PlayerCooldownMs = 1500      -- default 1500 (one skinning reward per player within this many ms)
Config.CarcassMemorySeconds = 1800  -- default 1800 (how long a skinned carcass is remembered, so it pays once)
Config.RequireNetworkedCarcass = false -- default false (true = refuse skinning of carcasses the server cannot identify)
Config.MaxDistance = 6.0            -- default 6.0 (metres between the player and the carcass, checked when the server sees it)

-- Tools the player must carry to skin (any one of them). Empty = no requirement.
-- e.g. { 'weapon_melee_knife', 'weapon_melee_knife_trader', 'weapon_melee_knife_jawbone' }
Config.RequireItems = {}            -- default {} (no tool needed)
Config.RequireItemsForWhole = false -- default false (true = the tool is also needed for small game kept whole)

-- Hunting resources that give their own skinning rewards. When one of them is started,
-- MULTIhunting gives nothing (so nobody is paid twice). Add any premium hunting script here.
Config.StandDownFor = { 'rsg-hunting', 'RINGOoutdoors' } -- default { 'rsg-hunting', 'RINGOoutdoors' }

---------------------------------
-- notifications
---------------------------------
Config.NotifySummary = true         -- default true (one note listing what the skinning gave)
Config.NotifyDuration = 5000        -- default 5000 (ms)

---------------------------------
-- whole carcass sale (not built)
---------------------------------
-- Carrying a whole carcass to a butcher is left to premium hunting scripts; see README.

-- ============================================================
-- MULTIwagons settings (part of MULTIcore, GPL v3)
-- The dealers and call points are in config/dealers.lua, the wagons for sale
-- (price, storage slots and weight) in config/wagons.lua.
-- Prices are dollars with cents at 1899 level. A dealer never pays back more
-- than half of what a wagon costs (no money loops): SellBackRate is capped at 0.5.
-- ============================================================
Config = {}

Config.Locale = ''                  -- default '' (language for this script; empty = setr multicore_locale, else English)
Config.Debug = false                -- default false (prints buys, sales, take-outs and put-aways to the server console)

---------------------------------
-- money and ownership
---------------------------------
Config.Currency = 'cash'            -- default 'cash' (MULTIcore money type wagons are bought, sold and repaired with)
Config.CurrencySign = '$'           -- default '$' (money sign in the menus)
Config.MaxWagonsPerCharacter = 3    -- default 3 (most wagons one character may own)
Config.SellBackRate = 0.4           -- default 0.4 (share of the price paid back when a wagon is sold to a dealer; never above 0.5)
Config.SellNeedsEmptyStorage = true -- default true (a wagon with items in its storage cannot be sold; false = the items are lost)
Config.NameMinLength = 2            -- default 2 (shortest wagon name)
Config.NameMaxLength = 24           -- default 24 (longest wagon name)
Config.PlateLength = 6              -- default 6 (characters in a wagon's plate / id, e.g. 'K7RW2M')
Config.PlateChars = 'ABCDEFGHJKLMNPRSTUVWXYZ23456789' -- default (characters a plate is made of)

---------------------------------
-- how players use dealers and call points
---------------------------------
Config.Interact = 'auto'            -- default 'auto' ('auto' = MULTItarget when it runs, else hold-key prompts; 'target' = MULTItarget on dealers, clerks and wagons; 'prompt' = hold-key prompts)
Config.PromptKey = 'J'              -- default 'J' (dealer / call point key, name from MULTIcore's shared/keybinds.lua; prompt mode)
Config.PromptDistance = 2.0         -- default 2.0 (metres from a dealer / call point at which its prompt shows; prompt mode)
Config.StorageKey = 'E'             -- default 'E' (key to open a wagon's storage at its back; prompt mode)
Config.TargetIcon = 'fas fa-horse'  -- default 'fas fa-horse' (MULTItarget icon on dealers; target mode)
Config.TargetStorageIcon = 'fas fa-box-open' -- default 'fas fa-box-open' (MULTItarget icon on a wagon's back; target mode)
Config.TargetRadius = 1.2           -- default 1.2 (size of the MULTItarget sphere on a dealer; target mode)
Config.TargetDistance = 2.5         -- default 2.5 (how close the player must stand to use a target; target mode)

-- The server re-checks every action (needs OneSync, which MULTIcore servers run).
Config.ServerDistanceCheck = true   -- default true (false only when OneSync is off)
Config.MaxUseDistance = 6.0         -- default 6.0 (metres from a dealer / call point for buy, sell, take out, repair)
Config.CheckIntervalMs = 1000       -- default 1000 (ms between client checks: dealers near, own wagon still there)

---------------------------------
-- taking out and putting away
---------------------------------
Config.CallAnywhere = false         -- default false (true = the /wagon command calls a wagon to the nearest road anywhere)
Config.CallCommand = 'wagon'        -- default 'wagon' (command that opens "my wagons" at a call point, or anywhere with CallAnywhere)
Config.CallSpawnDistance = 12.0     -- default 12.0 (metres from the player a called wagon appears, on the nearest road)
Config.StoreAnywhere = false        -- default false (true = a wagon can be put away anywhere; false = only near a dealer / call point)
Config.StoreRadius = 30.0           -- default 30.0 (metres the WAGON may be from a dealer / call point to be put away there)
Config.StoreDistance = 12.0         -- default 12.0 (metres the player may be from his wagon to put it away)
Config.DespawnOnLeave = true        -- default true (an owner's wagon is put away when he leaves or switches character)
Config.SpawnTimeoutSeconds = 20     -- default 20 (a take-out the client never confirms is undone after this long)
Config.SpawnClearRadius = 4.0       -- default 4.0 (a spawn point with a vehicle this close is taken; the wagon waits for it to clear)
Config.WatchSeconds = 10            -- default 10 (how often the server checks that wagons that are out still exist)
Config.ModelLoadTimeoutMs = 10000   -- default 10000 (give up loading a wagon model after this long)

---------------------------------
-- wagon storage (a MULTIinventory 'trunk:<plate>' inventory per wagon)
---------------------------------
Config.StorageOpenTo = 'owner'      -- default 'owner' ('owner' = only the owner opens it, 'anyone' = anyone at the wagon's back)
Config.StorageDistance = 2.0        -- default 2.0 (metres from the wagon's back the storage prompt / target shows)
Config.StorageServerDistance = 7.0  -- default 7.0 (metres from the wagon's middle the server allows opening and keeps it open)
Config.StorageBackOffset = 0.6      -- default 0.6 (metres behind the wagon's rear edge where the storage point is)
Config.MigrateRsgStashes = true     -- default true (items in old rsg-wagons stashes 'Wagon_Stash_<id>' move into the wagon's storage once)

---------------------------------
-- damage and repair (health is kept as a percentage 0 - 100)
---------------------------------
Config.Health = {
    MinToTakeOut = 10,              -- default 10 (a wagon below this much health must be repaired before it can be taken out)
    ReportSeconds = 30,             -- default 30 (how often the owner's game reports the wagon's health while it is out)
}
Config.Repair = {
    Item = 'wagon_repair_kit',      -- default 'wagon_repair_kit' (item that repairs the owner's wagon at the wagon; '' = off)
    ItemDistance = 5.0,             -- default 5.0 (metres from the wagon to use the repair kit)
    ProgressMs = 6000,              -- default 6000 (how long fixing with the kit takes)
    DealerFeePerPercent = 0.08,     -- default 0.08 (dealer fee per missing health percent; full repair of a wreck = $8.00)
    DealerMinFee = 0.25,            -- default 0.25 (smallest dealer repair fee)
}

-- Items MULTIwagons adds to the item registry (only when no script has them yet).
Config.NewItems = {
    wagon_repair_kit = {
        name = 'wagon_repair_kit', label = 'Wagon Repair Kit', weight = 1500, type = 'item',
        image = 'wagon_repair_kit.png', unique = false, useable = true, shouldClose = true,
        description = 'Spokes, grease and nails to put a wagon right', category = 'tools',
    },
}

---------------------------------
-- dealer clerks
---------------------------------
Config.Npc = {
    Enabled = true,                 -- default true (a clerk stands at every dealer that has an `npc` spot)
    Model = 's_m_m_cghworker_01',   -- default 's_m_m_cghworker_01' (clerk model, the one RSG's rsg-wagons uses)
    SpawnDistance = 40.0,           -- default 40.0 (clerk is made when the player is this close, removed beyond it)
    ZOffset = -1.0,                 -- default -1.0 (added to the clerk z so he stands on the ground)
    LoadTimeoutMs = 5000,           -- default 5000 (give up loading the clerk model after this long)
}

---------------------------------
-- blips
---------------------------------
Config.Blips = {
    Enabled = true,                 -- default true (map blips on dealers)
    Style = 1664425300,             -- default 1664425300 (BlipAddForCoords style, the value rsg-wagons uses)
    Sprite = -1747775003,           -- default -1747775003 (dealer blip sprite hash, the one rsg-wagons uses)
    Scale = 0.2,                    -- default 0.2
    OwnWagon = true,                -- default true (a blip follows your own wagon while it is out)
    OwnWagonSprite = 'blip_player_coach', -- default 'blip_player_coach' (sprite name of that blip, as rsg-wagons uses)
}

---------------------------------
-- spam guard
---------------------------------
Config.RateLimit = {
    Calls = 6,                      -- default 6 (at most this many wagon actions ...)
    WindowMs = 3000,                -- default 3000 (... in this many ms, per player)
}

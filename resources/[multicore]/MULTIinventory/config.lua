-- ============================================================
-- MULTIinventory :: main configuration
-- More specific settings live in config/*.lua.
-- ============================================================

Config = Config or {}

-- On MULTIcore the inventory always talks to MULTIcore's rsg-core shape (this is ignored).
-- Without MULTIcore: 'auto' | 'vorp' | 'rsg'   (server-wide: setr multi_framework "...")
Config.Framework = 'rsg'

-- Language: '' = MULTIcore's language (MULTIConfig.Language), else 'en'
Config.Locale = ''
Config.Debug  = false

-- Commands (client): open / close the satchel. MULTIradial's satchel button runs /inventory.
Config.OpenCommand = 'inventory'
Config.CloseCommand = 'closeinv'
-- Admin command (server, rsg-core command permission 'admin'): /giveitem [id] [item] [amount]
Config.GiveItemCommand = 'giveitem'

-- Item pop-ups (MULTIinventory:client:itembox, rsg-inventory:client:ItemBox) as MULTIcore notifications
Config.ItemBox = { enabled = true, time = 3000 }

-- RedEM:RP face
Config.Redem = {
    UsableEvents = true,   -- a usable item nothing else handles fires RedEM:RP's 'RegisterUsableItem:<name>'
    StashSlots = 50,       -- slots of a stash opened with redemrp_inventory:OpenStash
}

-- ------------------------------------------------------------
-- Player inventory
-- ------------------------------------------------------------
Config.Player = {
    -- Carry capacity in kg. The character's own capacity (MULTIcore PlayerData.weight,
    -- grams) wins; this is the fallback when the framework gives nothing.
    defaultMaxWeight = 35.0,
    useFrameworkCapacity = true,

    slots = 40,                -- grid slots in the player inventory
    hotbarSlots = 5,           -- keys 1-5

    -- Keys: a number (control hash) or an input name string (hashed with joaat).
    openKey = 0xC1989F95,      -- "I"
    -- On / next to a horse the game marks the open key disabled; within this many metres of your
    -- mount (or last mount) the key still opens the inventory (not while cuffed / hogtied).
    horseOpenRadius = 6.0,
    -- Hotbar: press the slot's number key to USE the item there (weapons: draw, press again to holster).
    -- Primary: RegisterKeyMapping, players can rebind under Settings > Key Bindings > FiveM/RedM
    -- ("Inventory hotbar slot N"). Defaults below are only the first-time binding.
    hotbarBindDefaults = { '1', '2', '3', '4', '5' },
    -- Fallback: the game's number-key controls (quick-select 1..5), read even when disabled, for
    -- clients where key mappings do not fire. Switches itself off once a key mapping has fired.
    hotbarControlFallback = true,
    hotbarKeys = { 0xE6F612E4, 0x1CE6D9EB, 0x4F49CC4C, 0x8F9F9E58, 0xAB62E997 }, -- quick-select 1..5
    -- While a hotbar slot holds something, the game's own quick-select on that number is blocked so
    -- the game does not swap weapons at the same time. Empty hotbar slots keep the game behaviour.
    -- Set false if your players rebind the hotbar away from 1-5 and want the native number keys back.
    hotbarSuppressNative = true,
    -- Optional modifier: an input (hash or 'INPUT_...' name) that must be held with the number key.
    -- nil = number key alone (default). The old default was 'INPUT_SELECT_ITEM_WHEEL'.
    hotbarHoldKey = nil,
    hotbarServerGapMs = 250,   -- server: minimum time between two hotbar uses per player

    -- Worn clothing does not count toward carry weight.
    -- Clothing carried in the grid always counts.
    wornClothingCountsWeight = false,

    -- Cash and gold are framework currencies; the inventory only shows them.
    showCurrency = { cash = true, gold = true },
}

-- ------------------------------------------------------------
-- Money as items
-- Two physical items ARE the character's cash: cash = dollars + cents / 100.
-- The framework cash (vorp_core character money / rsg-core PlayerData.money.cash)
-- stays authoritative for every other script; MULTIinventory keeps the items in sync
-- both ways. Ship default: OFF. Turning it on needs the two item rows
-- (money_dollar / money_cent in your item list) and a full server restart.
-- ------------------------------------------------------------
Config.Money = {
    enabled = false,               -- default false; needs a full restart

    dollarItem = 'money_dollar',   -- one-dollar bills (stack = whole dollars)
    centItem   = 'money_cent',     -- coins (stack = cents, always 0-99 in a player's pockets)

    reconcileSeconds = 5,          -- safety-net re-sync of every online player (framework -> items)
    loadDelayMs = 2000,            -- first sync after a character is selected

    countWeight = true,            -- money counts toward carry weight
    weights = { dollar = 0.001, cent = 0.0025 },   -- kg per bill / per coin (override the items table)

    allowInStashes = true,         -- cash may be stored in stashes / saddlebags / trunks / business storage
    allowOnGround = true,          -- cash may be dropped as a world pile
    allowDestroy = false,          -- Config.Drop.mode = 'delete': destroying cash is refused
    searchCountsAsOne = true,      -- robbery: taking a stack of cash counts as ONE item toward search limits

    -- While enabled = false, money items are frozen: nothing (except admins) can add them anywhere,
    -- so stale wallet items from a previous enabled period cannot be stored and later re-cashed.
    freezeWhenDisabled = true,
}

-- ------------------------------------------------------------
-- Dropping
-- ------------------------------------------------------------
Config.Drop = {
    -- 'world'  = the item becomes a ground pick-up anyone can collect (metadata kept)
    -- 'delete' = dropping destroys the item (old DELETE_ON_DROP behaviour)
    mode = 'world',
    confirmDelete = true,          -- UI asks before destroying (mode = 'delete')

    lifetimeSeconds = 1800,        -- despawn timer of a ground pick-up
    persistAcrossRestarts = true,  -- false = all ground pick-ups are wiped on resource start
    sweepSeconds = 15,             -- how often expired drops are removed

    slots = 20,                    -- max different stacks in one ground pile
    mergeRadius = 1.25,            -- a drop this close to an existing pile joins it
    pickupDistance = 2.5,          -- server check (metres) for pick-up
    renderDistance = 40.0,         -- client spawns the local prop within this range

    prop = 'p_cs_bag01x',          -- local (non-networked) prop for a pile; verify model on test server
    propByItem = {},               -- { item_name = 'p_model' } single-item piles
    maxDropsPerMinute = 20,        -- per player, anti-spam
}

-- ------------------------------------------------------------
-- Death
-- ------------------------------------------------------------
Config.Death = {
    -- vorp_core fires vorp:PlayerForceRespawn on a forced respawn. Clear items then?
    clearOnForceRespawn = false,
    clearEquipped = false,         -- also strip worn clothing (only when the above is true)
    keepItems = {},                -- names never cleared, e.g. { id_card = true }
}

-- ------------------------------------------------------------
-- Give
-- ------------------------------------------------------------
Config.Give = {
    maxDistance = 3.0,
    requireTargetConfirm = false,
}

-- ------------------------------------------------------------
-- Stacking
-- ------------------------------------------------------------
Config.Stacking = {
    -- Items stack only when their metadata is equal (canonical compare).
    -- These metadata keys are ignored when comparing (volatile UI hints).
    ignoreKeys = { tooltip = true, context = true },
    -- Respect items.limit as the max count per stack (true) or as max per inventory (false).
    -- items.limit <= 0 means no limit.
    limitIsPerStack = false,
}

-- ------------------------------------------------------------
-- Degradation / expiry
-- ------------------------------------------------------------
Config.Degradation = {
    enabled = true,
    -- items.degradation = minutes until fully decayed (0 = never)
    tickSeconds = 60,
    onlyInPlayerInventory = false, -- decay everywhere unless a container sets flags.freeze = true
    removeWhenExpired = false,     -- false: keep as "spoiled" (items.useExpired decides use)
    -- Two stacks of a decaying item only merge when their expiry times are this close;
    -- the merged stack keeps the EARLIER expiry.
    mergeWindowSeconds = 3600,
}

-- ------------------------------------------------------------
-- Persistence
-- ------------------------------------------------------------
Config.Persistence = {
    saveIntervalSeconds = 30,   -- write-behind flush of dirty containers
    tablePrefix = 'multiinv_',
    idBlock = 1000,             -- stack ids reserved per block (AUTO_INCREMENT is moved past the block)
    unloadOfflineAfter = 600,   -- seconds an offline container stays cached after its last use
}

-- Moving from the old MULTIinventory (server/multi/migrate.lua). On start, once per database,
-- satchels in players.inventory and stashes in the `inventories` table are copied into this
-- inventory (weapons keep their serials). The old data is never changed or deleted. The run is
-- recorded in multiinv_migration (step 'old_multiinventory'); delete that row to run it again -
-- inventories that already hold items here are skipped. false = never import.
Config.MigrateOld = true

-- ------------------------------------------------------------
-- Actions (server authority)
-- ------------------------------------------------------------
Config.Actions = {
    ratePerSecond = 15,         -- NUI actions per player per second
    useCooldownMs = 300,
}

-- ------------------------------------------------------------
-- Images: item pictures come from MULTIimages (put your .png files in MULTIimages/images,
-- named as each item's image field, e.g. bread.png). No pictures are shipped with MULTIinventory.
-- ------------------------------------------------------------
Config.Images = {
    -- NUI path of item pictures (%s = picture name without .png)
    itemPath = 'nui://MULTIimages/images/%s.png',
    -- placeholder for items without a picture
    fallback = 'nui://MULTIinventory/html/img/ui/missing.png',
    -- more picture folders handed to other scripts by exports.MULTIinventory:GetImagePaths()
    -- (MULTIstores, MULTIcrafting), e.g. { 'nui://my_pictures/images/' }
    extraPaths = {},
    shipThirdPartyImages = false,
}

-- ------------------------------------------------------------
-- Item groups -> UI filter tabs (data-driven from the `item_group` table).
-- Key = item_group.description. Groups without a label get a title-cased name.
-- `parents`: the parent tab ALSO lists the child group's items (Provisions shows food/drink).
-- ------------------------------------------------------------
Config.Groups = {
    labels = {
        default   = 'Other',
        medical   = 'Remedies',
        foods     = 'Provisions',
        tools     = 'Materials',
        weapons   = 'Weapons',
        ammo      = 'Ammo',
        documents = 'Documents',
        animals   = 'Animals',
        valuables = 'Valuables',
        horse     = 'Horse',
        herbs     = 'Herbs',
        drinks    = 'Drinks',
        food      = 'Food',
        canned    = 'Canned Food',
        packet    = 'Packet Food',
        meals     = 'Meals',
        alcohol   = 'Alcohol',
        drugs     = 'Drugs & Tobacco',
    },
    parents = { drinks = 'foods', food = 'foods', canned = 'foods', packet = 'foods', meals = 'foods' },
    hidden = { default = true },   -- no own tab (still shown under "All")
}

-- ------------------------------------------------------------
-- Audit log
-- ------------------------------------------------------------
Config.Log = {
    enabled = true,
    -- actions written to multiinv_log (admin_* are always written)
    actions = { give = true, drop = true, pickup = true, destroy = true, drop_expired = true,
                expired = true, death_clear = true,
                money_in = true, money_out = true, cash = true },   -- Config.Money (items <-> framework cash)
    flushSeconds = 10,
}

-- ------------------------------------------------------------
-- Compatibility
-- ------------------------------------------------------------
Config.Compat = {
    -- Fire the vorp_inventory-named events other resources listen to
    -- (vorp_inventory:Server:OnItemUse, vorp_inventory:onWeaponEquipped, ...).
    -- The core emits MULTIinventory:* events; the vorp_inventory face forwards them.
    emitVorpEvents = true,
    -- Show the saddlebag button and send vorp_inventory:Server:SaddleOpen (stable scripts).
    saddleButton = true,
}

-- ------------------------------------------------------------
-- Admin
-- ------------------------------------------------------------
Config.Admin = {
    ace = 'multi_admin',          -- ace permission for admin tools
    commands = {
        inspect = 'invinspect',   -- view / edit another player's inventory
        give    = 'invgive',
        remove  = 'invremove',
        clear   = 'invclear',
        stash   = 'invstash',     -- open any registered secondary inventory
        log     = 'invlog',
        restore = 'invrestore',
        reload  = 'invreload',
        flush   = 'invflush',
    },
}

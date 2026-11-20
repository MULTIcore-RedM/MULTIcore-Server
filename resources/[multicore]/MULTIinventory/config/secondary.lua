-- ============================================================
-- MULTIinventory :: secondary inventories (stashes, saddlebags, trunks, ...)
-- Read by server/secondary/*.lua and client/secondary.lua.
-- ============================================================

Config.Secondary = {
    -- Defaults for inventories registered through the compat API
    -- (registerInventory) when the caller leaves a field out.
    defaults = {
        slots = 50,
        maxWeight = nil,         -- nil = slot limited only (vorp_inventory behaviour)
        acceptWeapons = true,
        shared = false,          -- vorp meaning: false = every character has its own contents
    },

    -- What registerInventory's `limit` means.
    --   'slots' = number of grid slots (public vorp_inventory documentation; default)
    --   'count' = total number of items the inventory may hold; the grid then gets
    --             `countModeSlots` slots
    limitMode = 'slots',
    countModeSlots = 100,
    -- Sanity clamp for registrations (some scripts pass kg values or 1000 as `limit`).
    -- Lowering slots never deletes items: occupied slots above the limit stay until moved.
    minSlots = 1,
    maxSlots = 1000,

    -- `useWeight = true, weight = <kg>` (RINGOstables, RINGOitemplacer, RINGOwagons) gives the
    -- inventory a weight limit in kg on top of its slots.
    honourUseWeight = true,

    -- deleteCustomInventory removes the registration AND everything stored in it
    -- (public documentation; RINGOwagons relies on it for sold/expired wagons).
    deletePurges = true,

    -- Viewers. Inventories registered with shared = true can be open for several players at
    -- once (every move is checked and applied atomically on the server, so two viewers can
    -- never duplicate an item). Per-character inventories always have one viewer (the owner).
    allowMultipleViewers = true,
    maxViewers = 4,
    -- Lua patterns of inventory ids that stay single-viewer even when shared
    -- (e.g. '^placer_' if you want RINGOitemplacer boxes to have one viewer at a time).
    singleViewerPatterns = {},
    -- A single-viewer lock held by someone who has not changed anything for this long
    -- is released when another player tries to open the inventory.
    lockTimeoutSeconds = 120,

    -- Permissions (registerInventory UsePermissions = true).
    permissions = {
        -- UsePermissions on, but no job/charid has been added: false = nobody may move/take
        -- (safe), true = everyone may.
        emptyMeansOpen = false,
        -- AddCharIdPermission* only matter when UsePermissions is on (the calling resource
        -- already decides who may open). true = always enforce them once any is added.
        enforceCharIdWithoutUsePermissions = false,
        -- Admin sessions (/invstash) ignore permissions; black/whitelists still apply.
        adminBypass = true,
    },

    -- Discord webhook (registerInventory `webhook`): one embed per batch of moves.
    webhook = {
        enabled = true,
        username = 'MULTIinventory',
        color = 9807270,
        batchSeconds = 5,
        maxLinesPerMessage = 15,
    },

    -- Horse saddlebags: container id = the bag id handed out by RINGOstables
    -- (ringo_stables_owned.bag_id). Opened through RINGOstables (openInventory) or the
    -- saddlebag button, which sends vorp_inventory:Server:SaddleOpen with the mount's netId.
    saddlebags = {
        enabled = true,
        slots = 40,                -- OpenSaddlebag() defaults when the bag is not registered yet
        maxWeight = nil,
        acceptWeapons = true,
        useLastMount = true,       -- not mounted: use the last mount if it is this close
        lastMountRadius = 4.0,
    },

    -- Wagon trunks (RINGOwagons) and business storages (RINGOjobsandcrafting)
    -- are ordinary registered inventories; the owning resource registers them.

    -- Player search / robbery (openPlayerInventory-style)
    search = {
        enabled = true,
        -- Player-started searches (command / SearchPlayer with checkConditions) need the
        -- target to be in one of these states. Script calls (openPlayerInventory) decide
        -- themselves unless they pass checkConditions = true.
        requireHandsUpOrCuffed = true,
        conditions = { handsUp = true, cuffed = true, hogtied = true, dead = true },
        -- the search closes when the target is no longer in any allowed state
        requireConditionWhileOpen = true,
        maxDistance = 2.0,
        closeDistance = 4.0,       -- auto-close beyond this distance
        checkIntervalMs = 1000,
        robberMustBeFree = true,   -- a dead/cuffed/hogtied player cannot search others
        blacklist = {},            -- item/weapon names that cannot be taken, e.g. { id_card = true }
        itemsLimit = nil,          -- e.g. { items = 5, weapons = 1 } (units per search session)
        cooldownSeconds = 300,     -- same searcher -> same target, after something was taken
        allowGive = false,         -- may the searcher put items INTO the target's inventory?
        allowClothing = false,     -- may worn clothing be taken in a robbery?
        notifyTarget = true,
        command = 'search',        -- client command: search the closest player ('' = none)
        -- hands-up detection on the target's client (anim dict + name). Other scripts may
        -- also set one of the state bags below.
        handsUpAnims = {
            { dict = 'mech_loco_f@generic@reaction@handsup@unarmed@normal', anim = 'loop' },
            { dict = 'mech_busted@unapproved', anim = 'idle_b' },
        },
        -- player state bags written by other resources that also count
        stateBags = {
            cuffed = { 'isCuffed' },   -- RINGOlawmansystem
            dead = { 'isDead' },       -- RINGOdoctorsystem / pma-voice convention
            handsUp = { 'handsUp' },
            hogtied = { 'isHogtied' },
        },
    },

    -- Player-facing texts of this part.
    messages = {
        locked = 'Someone else is using this.',
        no_permission = 'You are not allowed to do that here.',
        not_allowed = 'That does not belong in here.',
        blacklisted = 'That cannot be stored here.',
        limit = 'There is no more room for that here.',
        no_weapons = 'Weapons cannot be stored here.',
        search_not_allowed = 'They have to raise their hands, be restrained or be down.',
        search_too_far = 'Get closer.',
        search_cooldown = 'You searched them a moment ago.',
        search_limit = 'You cannot take any more.',
        search_target = 'You are being searched.',
        search_taken = '%s took %s x%d from you.',
        search_busy = 'Someone is already searching them.',
        search_none = 'Nobody close enough.',
        search_self = 'You cannot do that right now.',
        no_mount = 'You need to be on or next to your horse.',
    },
}

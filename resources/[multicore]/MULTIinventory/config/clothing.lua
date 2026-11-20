-- ============================================================
-- MULTIinventory :: clothing as items + equipment slots
--,
-- ============================================================

Config.Clothing = {
    enabled = true,

    -- Resources whose CreateClothingItem calls are TRUSTED: their pieces need not be in the multiplayer
    -- catalogue and may use any palette (NPC / story clothing: RINGOnpcclothing delivers NPC pieces as items
    -- with their drawable set, MULTItailor its tailored garments). Everyone else is checked as before.
    trustedResources = { 'RINGOnpcclothing', 'MULTItailor' },

    -- Who owns the worn outfit:
    -- 'inventory' = MULTIinventory's equipment container is the source of truth
    --               and the framework appearance record is rewritten from it
    --               (mirror) after every change.
    sourceOfTruth = 'inventory',

    -- VORP: mirror the equipped pieces into characters.compPlayer / compTints so
    -- vorp_character re-applies the same look on spawn / after death ( 4:
    -- mirror mode, vorp_character itself is not changed).
    mirrorToFramework = true,
    -- Online characters are written through vorp_core's character API
    -- (updateComps / updateCompTints). Offline characters (API changes while the player
    -- is away) are written with one UPDATE of characters.compPlayer/compTints.
    mirrorOffline = true,
    -- Wait this long after the last change before writing (rapid drag on/off = one write).
    mirrorDebounceMs = 1000,

    -- RSG: the mirror into playerskins.clothes lives in server/clothing/appearance_rsg.lua
    --. It uses mirrorToFramework above too.

    -- First time a character loads with an EMPTY equipment container while the framework
    -- record still lists worn pieces (inventory installed before the migration, or a
    -- character the migration skipped): create the items from compPlayer/compTints
    -- (same mapping as instead of stripping the character. Until a character is
    -- "seeded" the inventory never strips the ped nor writes the mirror.
    importOnFirstLoad = true,

    -- Re-apply our equipped pieces this many ms after the framework finished
    -- its own spawn/appearance load, after a respawn and after a model change.
    reapplyDelayMs = 1500,
    -- Client watcher interval (ped handle / model / death changes).
    watchIntervalMs = 1000,
    -- Wait for the ped to be ready to render after applying (ms, max).
    readyTimeoutMs = 3000,

    -- Weight of one clothing item (kg) when carried in the grid (the items table decides;
    -- this is the value install/pending_items.lua uses).
    itemWeight = 0.5,

    -- Allow wearing items whose metadata.gender does not match the ped.
    allowCrossGender = false,

    -- Pieces without the clothing contract (no metadata.cv) may be worn. Keep true until the
    -- core test fixtures use cv=1 pieces (change request), then set false.
    allowLegacyPieces = true,

    -- BuildClothingMetadata: a route-A comp must exist in the catalogue for that category.
    requireCatalogue = true,

    -- Allowed tint palettes (hashed with joaat at runtime). extraPaletteHashes adds raw hashes.
    palettes = {
        'metaped_tint_generic', 'metaped_tint_generic_clean', 'metaped_tint_generic_weathered',
        'metaped_tint_generic_worn', 'metaped_tint_hat', 'metaped_tint_hat_clean',
        'metaped_tint_hat_weathered', 'metaped_tint_hat_worn', 'metaped_tint_combined',
        'metaped_tint_combined_leather', 'metaped_tint_leather', 'metaped_tint_swatches',
        'metaped_tint_skirt', 'metaped_tint_skirt_clean', 'metaped_tint_skirt_weathered',
        'metaped_tint_skirt_worn', 'metaped_tint_mpadv',
    },
    extraPaletteHashes = {},

    -- Mutual exclusions: wearing one piece of a pair refuses (or swaps out) the other.
    exclusions = {
        { 'Coat', 'CoatClosed' },
        { 'Dress', 'Shirt' },
        { 'Dress', 'Pant' },
        { 'Dress', 'Skirt' },
        { 'Poncho', 'Cloak' },
    },
    -- 'swap'   = the equip action takes the conflicting piece off first (back to the grid)
    -- 'refuse' = the player must take it off themselves
    -- (a plain drag onto the slot always refuses with a message - only the equip action swaps)
    exclusionMode = 'swap',

    -- Pieces that need another piece worn (holster / gunbelt accessories hang on the gunbelt).
    requires = {
        Holster = 'Gunbelt',
        GunbeltAccs = 'Gunbelt',
    },
    -- Taking the required piece off with the unequip action also takes the dependants off.
    -- A plain drag of the gunbelt out while a holster is worn is refused.
    cascadeUnequip = true,

    -- Apply order on the ped (layering): unlisted categories follow in slot order.
    applyOrder = { 'Pant', 'Skirt', 'Dress', 'Shirt', 'Boots', 'Spats', 'Chap', 'Vest', 'Suspender',
                   'Coat', 'CoatClosed', 'Poncho', 'Cloak', 'Gunbelt', 'Holster', 'GunbeltAccs',
                   'Belt', 'Buckle', 'Satchels', 'Loadouts' },

    -- Durability: worn pieces lose this much per in-game day worn (0 = off). Not used yet.
    wearPerDay = 0,

    -- Wardrobe outfits: max saved outfits per character
    maxOutfits = 20,
    -- Container id prefix of house wardrobe stashes (clothing-only): wardrobe:<charid>:<houseId>
    wardrobePrefix = 'wardrobe:',

    -- NPC general outfitter (optional, basics only; NOT built in Phase 2).
    -- Shops use exports.MULTIinventory:CreateClothingItem(target, spec, count).
    outfitter = {
        enabled = false,
        stock = {},   -- { { category = 'Shirt', comp = <hash>, gender = 'male', price = 4.0 }, ... }
    },
}

-- Audit log: clothing actions.
if Config.Log and Config.Log.actions then
    Config.Log.actions.clothing_equip = true
    Config.Log.actions.clothing_unequip = true
    Config.Log.actions.clothing_import = true
    Config.Log.actions.clothing_unpack = true
    Config.Log.actions.clothing_pack = true
end

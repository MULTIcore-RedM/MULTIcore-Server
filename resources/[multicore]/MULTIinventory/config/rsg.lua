-- ============================================================
-- MULTIinventory :: RSG-Core settings
-- Only used when the framework is RSG (Config.Framework / multi_framework).
-- Everything here has a built-in default in server/rsg/rsg_api.lua, so this
-- file may be missing.
-- ============================================================

Config.Rsg = {
    -- rsg-core item weights are grams; MULTIinventory works in kg.
    -- kg = rsg weight / weightUnit  (RSGCore.Shared.Items, players.weight)
    weightUnit = 1000,

    -- Item definitions come from RSGCore.Shared.Items (rsg-core shared/items.lua
    -- + anything added at runtime with exports['rsg-core']:AddItem).
    -- rsg `category` -> RINGO group key (filter tab). Unlisted = the category itself.
    categoryGroups = {},

    -- rsg-inventory behaviour: AddItem on a full player drops the item on the
    -- ground and returns true, 'dropped' (unless the caller passes noForceDrop).
    forceDropWhenFull = true,

    -- Keep Player.PlayerData.items (rsg-core) a read-only mirror of the
    -- MULTIinventory player grid, so scripts that read PlayerData.items and
    -- rsg-core's client HasItem keep working.
    mirrorPlayerItems = true,

    -- Add AddItem / RemoveItem / GetItemByName / ... to Player.Functions when
    -- rsg-core does not already have them (older qb-style scripts call these).
    playerMethods = true,

    -- Items registered with RSGCore.Functions.CreateUseableItem are usable from
    -- the MULTIinventory UI / hotbar (rsg usable items).
    bridgeUsables = true,
    -- refuse use while dead / cuffed (rsg-core player metadata)
    blockUseWhenDown = true,

    -- Listen to the net event 'rsg-inventory:server:useItem' (only when the real
    -- rsg-inventory is not running).
    netUseEvent = true,

    -- Server-local 'rsg-inventory:server:itemRemovedFromPlayerInventory'
    -- (src, item, { amount, slot, info }, reason, isMove) for third-party hooks.
    emitRemovedEvent = true,
    -- Client 'rsg-inventory:client:ItemBox' (itemDef, 'add'|'remove'|'use', amount)
    -- for HUD scripts that listen to it. Off by default (RINGO UI notifies itself).
    emitItemBox = false,

    -- Also write PlayerData.slots = RINGO grid size (scripts size checks with it).
    mirrorSlots = true,

    -- RINGO UI uses -> net event 'rsg-inventory:server:useItem' (RINGOplayercore,
    -- RINGOjobsandcrafting listen to it). Sent by the player's client through the
    -- client (client/multi/faces.lua) with a one-time token.
    echoUseEvent = true,
    -- An item no script registered as usable: no "cannot be used" message, only the
    -- echo (labor tools / passive consumables are handled by listeners).
    silentNotUsable = true,
    -- Closing a stash -> net event 'rsg-inventory:server:closeInventory' (id)
    -- (RINGOitemplacer box sweep), same client round trip.
    echoCloseEvent = true,
    -- ('rsg-inventory:client:ItemBox' popups fired by ~20 RINGO scripts are shown by the
    --  client as MULTIcore notifications - switch: Config.ItemBox.enabled.)

    -- Stashes opened/created through the rsg-inventory API without sizes
    -- (rsg units: grams).
    stashDefaults = { slots = 100, maxweight = 2000000 },

    -- Clothing mirror into the RSG appearance resource (clothing part contract,
    --. Uses Config.Clothing.mirrorToFramework as master switch.
    appearance = {
        resource = 'auto',        -- 'auto' | 'rsg-character' | 'rsg-appearance' | 'RINGOmulticharacterV2'
        writeDb = true,           -- write the managed categories into playerskins.clothes
        clientEvent = 'MULTIinventory:rsg:applyClothes', -- (clothes, removedCategories, resource)
        debounceMs = 500,
        -- on character load only mirror when the equipment container holds
        -- something (protects existing RSG outfits before clothes are migrated)
        reconcileOnlyWhenWearing = true,
    },
}

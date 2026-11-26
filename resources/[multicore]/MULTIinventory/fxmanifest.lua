fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'MULTIinventory'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'Slot and weight inventory for MULTIcore: satchel, stashes, clothing slots, weapons with a gunbelt, ground drops and crafting, answering RSG, VORP and RedEM:RP scripts alike. GPL v3.'
version '1.0.0'
license 'GPL-3.0'

-- Answers to every inventory name (rsg-inventory, vorp_inventory, redemrp_inventory, RINGOinventory):
-- the exports and events under those names are registered by this resource itself. The names are
-- held by the small stand-in resources of the same name next to this one (ensure them right after
-- MULTIinventory). They also serve the item pictures at each framework's own nui:// path, which
-- `provide` cannot do. No `provide` here: with it, `ensure vorp_inventory` would start this
-- resource instead of the stand-in. Do not run the real inventories next to MULTIinventory.

shared_scripts {
    '@ox_lib/init.lua',
    'shared/ringo_names.lua',      -- answers as RINGOinventory too (must load before any export)
    'config.lua',
    'config_handcraft.lua',       -- hand crafting (Craft tab)
    'config_workshop.lua',        -- crafting journal + work stations
    'config_handcraft_jobs.lua',  -- job field recipes (after config_workshop.lua: adds job chapters)
    'config/*.lua',
    'bridge/shared.lua',          -- framework shape (always rsg on MULTIcore)
    'shared/locale.lua',
    'shared/util.lua',
    'shared/metadata.lua',        -- canonical metadata + stack keys
    'shared/clothing_categories.lua',
    'shared/clothing_catalog.lua',
    'shared/weapons.lua',
}

client_scripts {
    'client/multiui.lua',         -- ox_lib menus (drawn by RINGOui instead when that resource runs)
    'bridge/client.lua',
    'client/nui.lua',
    'client/main.lua',
    'client/hotbar.lua',
    'client/native_inventory.lua', -- game native inventory helper (dual wield: off-hand holster, weapon GUIDs)
    'client/weapons.lua',
    'client/clothing.lua',
    'client/secondary.lua',
    'client/drops.lua',
    'client/handcraft.lua',       -- Craft tab: progress bar + animation
    'client/workshop.lua',        -- crafting journal, placed stations, grinding wheel
    'client/exports.lua',
    'client/multi/faces.lua',     -- MULTIinventory / rsg-inventory / vorp_inventory / redemrp_inventory client exports, /inventory
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/core/db.lua',          -- schema (multiinv_*) auto-migration + oxmysql wrappers
    'server/core/hooks.lua',       -- InvHooks: in-resource extension points
    'server/core/registry.lua',    -- item definitions
    'server/core/containers.lua',  -- container model: player, equipment, drop, stashes
    'server/core/persistence.lua', -- write-behind save queue + stack id allocator
    'server/core/weight.lua',
    'server/core/stacking.lua',
    'server/core/sync.lua',        -- serialisation + NUI deltas
    'server/core/state.lua',       -- character load/unload, open/close sessions
    'server/core/inventory.lua',   -- Inv.*: the rule layer
    'server/core/usables.lua',     -- usable-item registry + use flow
    'server/core/log.lua',         -- audit log (multiinv_log)
    'server/core/hotbar.lua',
    'server/core/drops.lua',       -- world drops
    'server/core/degradation.lua',
    'server/core/actions.lua',     -- move/split/merge/sort/use/give/drop/pickup/hotbar
    'server/core/money.lua',       -- money as items (Config.Money, off by default)
    'server/weapons/weapons.lua',
    'server/weapons/ammo.lua',     -- gunbelt
    'server/secondary/inventories.lua',
    'server/secondary/permissions.lua',
    'server/secondary/search.lua',
    'server/clothing/equipment.lua',
    'server/clothing/appearance_vorp.lua',
    'server/clothing/appearance_rsg.lua',
    'server/clothing/outfits.lua',
    'server/admin/admin.lua',
    'server/handcraft/core.lua',
    'server/handcraft/handcraft.lua',
    'server/workshop/logic.lua',
    'server/workshop/stations.lua',
    'server/workshop/book.lua',
    'server/workshop/sharpen.lua',
    'server/compat/vorp_api.lua',  -- vorp_inventory-shaped API
    'server/compat/vorp_loadout.lua', -- keeps VORP's `loadout` table filled for scripts that read it with SQL
    'server/rsg/items_reader.lua', -- rsg-core item list reader
    'server/rsg/rsg_api.lua',      -- rsg-inventory-shaped API (MULTIcore's player data)
    'server/exports.lua',
    -- server/multi (name order): api.lua = the MULTIinventory export API the MULTI scripts use,
    -- commands.lua = /giveitem, faces.lua = rsg-inventory / vorp_inventory / redemrp_inventory names,
    -- migrate.lua = optional data import from older inventories (when present)
    'server/multi/*.lua',
    'server/core/boot.lua',        -- start-up + background loops (must stay last)
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/fonts.css',
    'html/custom.css',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/ui/*.png',
    'html/img/ui/*.svg',
    'locales/*.json',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'MULTIcore',
    'MULTItarget',
}

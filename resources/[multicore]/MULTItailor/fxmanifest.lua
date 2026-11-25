fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTItailor'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore clothing: clothes as inventory items, clothes stores, wardrobes, saved outfits, quick toggles and the tailor job (Outfit Designer, sewing, counter, till). Answers as rsg-wardrobe. GPL v3.'
version '1.3.0'
license 'GPL-3.0'

-- RSG v2 scripts call exports['rsg-wardrobe']:X(); MULTItailor answers them (do not run rsg-wardrobe too)
provide 'rsg-wardrobe'
provide 'RINGOtailor'         -- scripts written for RINGOtailor use MULTItailor (do not run both)

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/ringo_names.lua',          -- answers as RINGOtailor too (must load before any export)
    '@MULTIcore/data/clothes.lua',     -- every multiplayer clothing piece (catalogue, hash <-> look index)
    '@MULTIcore/data/appearance.lua',  -- palettes (palette hash <-> look index)
    'config.lua',
    'config/*.lua',
    'bridge/shared.lua',
    'shared/locale.lua',
    'shared/util.lua',
    'shared/catalogue.lua',
    'shared/logic.lua',
    'shared/look.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',          -- ox_lib menus, dialogs and notifications in the MULTI look
    'bridge/client.lua',
    'client/00_main.lua',
    'client/10_target.lua',
    'client/20_points.lua',
    'client/30_designer.lua',
    'client/40_sewing.lua',
    'client/50_business.lua',
    'client/60_wear.lua',
    'client/70_stores.lua',
    'client/80_admin.lua',
    'client/90_look.lua',             -- worn items back on after MULTIcore applies the look
    'client/95_wardrobe.lua',         -- toggles, outfits, wardrobe points, rsg-wardrobe client API
    'client/96_extras.lua',           -- give a copy of an outfit, tobacco page, how clothes sit
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/00_adapter.lua',
    'server/05_db.lua',
    'server/10_points.lua',
    'server/20_designer.lua',
    'server/25_npc.lua',
    'server/30_sewing.lua',
    'server/40_counter.lua',
    'server/50_boss.lua',
    'server/60_wear.lua',
    'server/70_stores.lua',
    'server/80_api.lua',
    'server/90_look.lua',             -- worn items <-> MULTIcore look, first-load import
    'server/95_wardrobe.lua',         -- saved outfits, rsg-wardrobe server API
    'server/96_extras.lua',           -- outfit copies, tobacco, how clothes sit (kept per character)
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/fonts.css',
    'locales/*.json',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
    'MULTItarget',     -- MULTIcore's target system (every MULTI script needs it)
}

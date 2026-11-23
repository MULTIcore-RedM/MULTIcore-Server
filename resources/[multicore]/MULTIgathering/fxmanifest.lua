fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIgathering'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore basic gathering: fishing, mining, gold panning, lumber and herb picking give items the stores buy. GPL v3.'
version '0.2.0'

-- No `provide` for rsg-fishing / rsg-goldclaim / rsg-lumberjack / rsg-herbalist: no RSG v2 or
-- RINGO script calls their events or exports (see README "Compatibility"). If one of them (or
-- another listed gathering script) runs, MULTIgathering stands down for that activity by itself.

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
    'shared/util.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',   -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Interaction settings)
    'client/fishing.js',
    'client/herbs.js',
    'client/main.lua',
    'client/work.lua',
    'client/fishing.lua',
    'client/herbs.lua',
}

server_scripts {
    'server/main.lua',
    'server/work.lua',
    'server/minespots.lua',     -- rock faces admins add in game (/minespot), kept in data/mining_spots.json
    'server/fishing.lua',
    'server/herbs.lua',
    'server/exports.lua',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
}

fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIhorses'
author 'Phil (original horse script); MULTIcore by RINGO (RINGOscripting)'
description 'Horses and stables for MULTIcore: buy, ride, customize, breed, trade, move, saddlebags, horse shop, wild horses. Answers as rsg-horses. GPL v3.'
version '2.0.0'
license 'GPL-3.0-or-later'

-- MULTIhorses stands in for rsg-horses (server/compat.lua, client/compat.lua).
-- Do not run rsg-horses on the same server.
provide 'rsg-horses'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
    'shared/functions.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',        -- ox_lib dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/dataview.lua',
    'client/coat.lua',
    'client/client.lua',
    'client/npcs.lua',
    'client/horses.lua',
    'client/showroom.lua',
    'client/action.lua',
    'client/horseinfo.lua',
    'client/wildhorse.lua',
    'client/compat.lua',            -- rsg-horses client events and exports
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/webhooks.lua',
    'server/database.lua',          -- player_horses: made, missing columns added, earlier horses carried over
    'server/server.lua',
    'server/wildhorse.lua',
    'server/compat.lua',            -- rsg-horses server events, callbacks and exports
}

ui_page 'html/index.html'

files {
    'shared/horse_settings.lua',
    'shared/horse_comp.lua',
    'html/index.html',
    'html/horses.css',
    'html/custom.css',
    'html/script.js',
    'html/icons/*.png',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'oxmysql',
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
}

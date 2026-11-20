fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTImedic'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore death and medic system: death screen, hospital respawn, medic revive, optional injuries. GPL v3.'
version '0.1.0'

-- MULTImedic stands in for rsg-medic (see README "rsg-medic compatibility").
-- Do not run rsg-medic on the same server.
provide 'rsg-medic'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',   -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget helper (player options, /mcinteract)
    'client/death.lua',
    'client/medic.lua',
    'client/injuries.lua',
    'client/compat.lua',
    'client/items.lua',
}

server_scripts {
    'server/main.lua',
    'server/compat.lua',
    'server/items.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
    'html/custom.css',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'MULTIcore',
}

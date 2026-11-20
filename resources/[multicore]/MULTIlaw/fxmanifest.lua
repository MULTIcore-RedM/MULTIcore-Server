fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIlaw'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore basic law: handcuffs, escort, search, evidence, jail and Sisika, fines, bounties, records, law alerts. GPL v3.'
version '0.1.0'

-- MULTIlaw stands in for these two RSG v2 resources (see README "RSG compatibility").
-- Do not run rsg-lawman or rsg-prison on the same server.
provide 'rsg-lawman'
provide 'rsg-prison'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',   -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/main.lua',
    'client/actions.lua',
    'client/jail.lua',
    'client/places.lua',
    'client/nui.lua',
    'client/compat.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/restraint.lua',
    'server/jail.lua',
    'server/fines.lua',
    'server/bounty.lua',
    'server/records.lua',
    'server/compat.lua',
    'server/api.lua',
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
    'oxmysql',
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
}

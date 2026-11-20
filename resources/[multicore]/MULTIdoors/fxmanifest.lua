fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIdoors'
author 'MULTIcore'
description 'MULTIcore door locks: every game door known, lock rules per job / gang / character / key item, lockpicking, admin door tool. GPL v3.'
version '0.1.0'
license 'GPL-3.0'

-- MULTIdoors stands in for RSG v2 rsg-doorlock (see README "RSG compatibility").
-- Do not run rsg-doorlock on the same server.
provide 'rsg-doorlock'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
    'data/doors.lua',
    'shared/doors.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',   -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/main.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/compat.lua',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'oxmysql',
    'ox_lib',
    'MULTIcore',
}

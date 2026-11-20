fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIhorses'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'Basic horses and stables for MULTIcore: buy, name, call, care, saddlebags, simple tack. Answers as rsg-horses. GPL v3.'
version '0.1.0'
license 'GPL-3.0'

-- MULTIhorses stands in for rsg-horses (see README "rsg-horses compatibility").
-- Do not run rsg-horses on the same server.
provide 'rsg-horses'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
    'shared/util.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',      -- tables, buy / sell / active / transfer / tack, care, saddlebags, exports
    'server/compat.lua',    -- rsg-horses events, callbacks and items
}

client_scripts {
    '@MULTIcore/lib/ui.lua',   -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/stable.lua',    -- stable hands, blips, prompts / targets, stable menus
    'client/horse.lua',     -- calling, following, sending away, care animations, death, saving state
    'client/compat.lua',    -- rsg-horses client events and exports
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'oxmysql',
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
}

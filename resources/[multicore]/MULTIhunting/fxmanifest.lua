fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIhunting'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore basic hunting: skinning gives pelts, meat and animal parts that the stores buy. GPL v3.'
version '0.1.0'

-- No `provide 'rsg-hunting'`: no RSG or RINGO script calls rsg-hunting's events or exports
-- (see README "Compatibility"). If rsg-hunting runs, MULTIhunting stands down by itself.

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/animals.lua',
    'locales/*.lua',
    'shared/animals.lua',
}

client_scripts {
    'client/events.js',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
}

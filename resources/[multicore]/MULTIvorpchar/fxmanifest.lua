fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIvorpchar'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'Optional MULTIcore stand-in for vorp_character: VORP scripts that read or change clothes keep working on the MULTIcore look'
version '0.1.0'
license 'GPL-3.0-or-later'

-- VORP scripts call exports.vorp_character:X() and fire vorpcharacter:* events; MULTIvorpchar answers them.
-- Only for servers that use MULTIcreator / MULTIclothing. Do not run it together with the real vorp_character.
provide 'vorp_character'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/data/clothes.lua',     -- every multiplayer piece (index <-> hash)
    '@MULTIcore/data/appearance.lua',  -- palettes (index <-> hash)
    'config.lua',
    'shared/convert.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'MULTIcore',
}

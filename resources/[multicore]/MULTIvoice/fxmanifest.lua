fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIvoice'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore proximity voice: whisper, talk and shout ranges, radio and call channels. Answers pma-voice calls, so no other voice script is needed.'
version '1.0.0'
license 'GPL-3.0-or-later'

-- Scripts written for pma-voice work unchanged. Do not run pma-voice on the same server.
provide 'pma-voice'

shared_scripts {
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

dependencies {
    'MULTIcore',
}

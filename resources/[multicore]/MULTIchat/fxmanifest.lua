fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIchat'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore chat: black chat box, /me, /do and /try. Answers every chat call, so no other chat resource is needed.'
version '1.0.0'
license 'GPL-3.0-or-later'

-- Scripts written for the standard chat resource work unchanged.
-- Do not run the standard chat resource on the same server.
provide 'chat'

shared_scripts {
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/chat.css',
    'html/chat.js',
    'html/custom.css',
}

dependencies {
    'MULTIcore',
    'MULTItarget',
}

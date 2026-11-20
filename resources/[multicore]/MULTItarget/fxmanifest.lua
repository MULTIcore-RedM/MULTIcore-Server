fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTItarget'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore target system (hold Left Alt). Answers ox_target, rsg-target and qb-target calls, so no other target script is needed.'
version '1.0.0'
license 'GPL-3.0-or-later'

-- Scripts written for ox_target, rsg-target or qb-target work unchanged.
-- Do not run ox_target, rsg-target or qb-target on the same server.
provide 'ox_target'
provide 'rsg-target'
provide 'qb-target'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/engine.lua',
    'client/main.lua',
    'client/compat.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/target.css',
    'html/target.js',
    'html/custom.css',
}

dependencies {
    'ox_lib',
    'MULTIcore',
}

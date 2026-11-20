fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIjobs'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore jobs and gangs: job centre, multi-job, boss menu, gang menu, duty. GPL v3.'
version '0.1.0'

-- MULTIjobs stands in for these three RSG v2 resources (see README "RSG compatibility").
-- Do not run rsg-bossmenu, rsg-gangmenu or rsg-multijob on the same server.
provide 'rsg-bossmenu'
provide 'rsg-gangmenu'
provide 'rsg-multijob'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/compat.lua',
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
}

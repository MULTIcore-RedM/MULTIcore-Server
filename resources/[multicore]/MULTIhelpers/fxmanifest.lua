fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIhelpers'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore stand-ins for vorp_menu, vorp_inputs and vorp_progressbar (own code, GPL v3).'
version '0.1.0'

-- VORP scripts that list these as dependencies, or call exports.vorp_menu / vorp_inputs /
-- vorp_progressbar, find this resource instead. Do not also start the real ones.
provide 'vorp_menu'
provide 'vorp_inputs'
provide 'vorp_progressbar'

shared_scripts {
    '@MULTIcore/shared/i18n.lua',   -- _L / _LT / _LCode (MULTIcore's shared language helper)
    'config.lua',
    'locales/*.lua',
    'shared/export.lua',            -- registers an export under this name and the VORP names
}

client_scripts {
    'client/nui.lua',        -- one NUI page, focus shared by the three parts
    'client/menu.lua',       -- vorp_menu
    'client/inputs.lua',     -- vorp_inputs
    'client/progress.lua',   -- vorp_progressbar
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/custom.css',       -- owners restyle here (loaded last)
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'MULTIcore',             -- shared UI theme (html/theme/multi.css)
}

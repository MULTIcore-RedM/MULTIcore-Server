fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIwagons'
author 'Phil (original wagon script), Mack (wagon extras, liveries, cargo and lanterns); MULTIcore by RINGO (RINGOscripting)'
description 'Owned wagons for MULTIcore: dealers with a showroom, buy / name / change / sell, call your wagon, storage, carcass storage and a chop shop.'
version '2.0.0'
license 'GPL-3.0-or-later'

-- answers to the old wagon script's name (its table, events and callbacks, see server/compat.lua).
-- Do not run rsg-wagons on the same server.
provide 'rsg-wagons'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',        -- ox_lib menus, dialogs and notifications in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget or hold-key prompts (Config.Interact)
    'client/list.lua',              -- what each model can be fitted with
    'client/wagon_extras.lua',      -- Mack's extras, liveries, cargo sets and lanterns (after list.lua)
    'client/main.lua',              -- your wagon: call, make, send away, storage, carcasses
    'client/showroom.lua',          -- dealer showroom wagon and camera
    'client/menu.lua',              -- dealer page callbacks
    'client/dealers.lua',           -- dealer blips, clerks, counter
    'client/chop.lua',              -- chop shop
    'client/compat.lua',            -- old client event names
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',     -- database, buy / sell / change, wagons out, storage, carcasses, exports
    'server/chop.lua',     -- chop shop rewards
    'server/compat.lua',   -- old event and callback names
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/wagons.css',
    'html/wagons.js',
    'html/custom.css',
    'images/*.png',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'MULTIcore',
    'MULTItarget',
    'MULTIinventory',
}

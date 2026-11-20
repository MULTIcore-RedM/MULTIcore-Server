-- ============================================================
-- MULTIcore :: black-and-white menus for ox_lib calls (client)
-- Every MULTI script that opens ox_lib menus loads it after ox_lib:
--
--   shared_scripts { '@ox_lib/init.lua', ... }
--   client_scripts { '@MULTIcore/lib/ui.lua', 'client/main.lua' }
--
-- The script keeps calling lib.registerContext, lib.showContext,
-- lib.inputDialog, lib.alertDialog, lib.progressBar, lib.showTextUI ...
-- exactly as ox_lib documents them; they are drawn by MULTIcore in the
-- base-game look (client/multi/ui.lua). lib.notify goes to MULTIcore's
-- notifications. lib.skillCheck stays ox_lib's.
-- When MULTIcore is not running, ox_lib draws as before.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================
if IsDuplicityVersion() or type(lib) ~= 'table' then return end

local function core() return GetResourceState('MULTIcore') == 'started' end

-- the ox_lib function, fetched the normal way, for when MULTIcore is not running
local function oxFn(name)
    return function(...) return exports.ox_lib[name](exports.ox_lib, ...) end
end

local function route(name, coreName)
    local fallback = oxFn(name)
    lib[name] = function(...)
        if core() then return exports.MULTIcore[coreName or name](exports.MULTIcore, ...) end
        return fallback(...)
    end
end

for _, name in ipairs({
    'registerContext', 'showContext', 'hideContext', 'getOpenContextMenu',
    'inputDialog', 'closeInputDialog', 'alertDialog', 'closeAlertDialog',
    'progressBar', 'progressCircle', 'progressActive', 'cancelProgress',
    'showTextUI', 'hideTextUI', 'isTextUIOpen',
}) do route(name) end

-- ox_lib notify shape { title, description, type, duration, icon, id } -> MULTIcore notify
lib.notify = function(data)
    if not core() then return exports.ox_lib:notify(data) end
    if type(data) ~= 'table' then return exports.MULTIcore:Notify(tostring(data)) end
    return exports.MULTIcore:Notify({
        title = data.description and data.title or nil,
        text = data.description or data.title,
        type = data.type, duration = data.duration, icon = data.icon, id = data.id,
    })
end

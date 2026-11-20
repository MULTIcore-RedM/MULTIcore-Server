-- ============================================================
-- MULTIinventory :: answers as RINGOinventory too
-- MULTIinventory started life as RINGOinventory. Scripts written for RINGOinventory call
-- exports.RINGOinventory:X(...): every export this resource makes is also answered under that
-- name. Where MULTIinventory's own export of the same name has the older MULTI shape (AddItem,
-- RemoveItem, Count, GetItemDef, RegisterUsable, UnregisterUsable, IsUsable), the RINGOinventory
-- name gets the original engine version (<Name>Native).
-- Do not run a separate RINGOinventory resource next to MULTIinventory.
-- Part of MULTIcore by RINGO (RINGOscripting). GPL v3.
-- ============================================================
local OLD = 'RINGOinventory'
local CLASH = { AddItem = true, RemoveItem = true, Count = true, GetItemDef = true,
                RegisterUsable = true, UnregisterUsable = true, IsUsable = true }

local mt = getmetatable(exports)
local register = mt and mt.__call
if register then
    mt.__call = function(t, name, fn)
        register(t, name, fn)
        if type(name) ~= 'string' or name:sub(1, 1) == '_' then return end
        local old = name
        local native = name:match('^(.+)Native$')
        if native and CLASH[native] then old = native
        elseif CLASH[name] then return end
        AddEventHandler(('__cfx_export_%s_%s'):format(OLD, old), function(setCB) setCB(fn) end)
    end
end

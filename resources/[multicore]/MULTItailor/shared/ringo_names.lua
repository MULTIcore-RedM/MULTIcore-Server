-- ============================================================
-- MULTItailor :: answers as RINGOtailor too
-- MULTItailor started life as RINGOtailor. Scripts written for it call exports.RINGOtailor:X(...):
-- every export this resource makes is also answered under that name.
-- Do not run a separate RINGOtailor resource next to MULTItailor.
-- Part of MULTIcore by RINGO (RINGOscripting). GPL v3.
-- ============================================================
local OLD = 'RINGOtailor'
local mt = getmetatable(exports)
local register = mt and mt.__call
if register then
    mt.__call = function(t, name, fn)
        register(t, name, fn)
        if type(name) == 'string' and name:sub(1, 1) ~= '_' then
            AddEventHandler(('__cfx_export_%s_%s'):format(OLD, name), function(setCB) setCB(fn) end)
        end
    end
end

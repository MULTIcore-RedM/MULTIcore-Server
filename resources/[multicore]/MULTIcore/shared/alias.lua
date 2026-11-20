-- ============================================================
-- MULTIcore :: export aliases
-- Every export this resource registers is also registered under the
-- name 'rsg-core', so RSG scripts calling exports['rsg-core']:X() reach
-- MULTIcore. The runtime looks exports up through an event named
-- __cfx_export_<resource>_<export>, so a handler for that name is all
-- it takes. VORP exports are registered under 'vorp_core' by hand
-- (server/vorp/core.lua), because they have a different shape.
-- ============================================================

MULTI = MULTI or {}

function MULTI.ExportAs(resourceName, exportName, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resourceName, exportName), function(setCB)
        setCB(fn)
    end)
end

local rawExports = exports
exports = setmetatable({}, {
    __call = function(_, exportName, fn)
        rawExports(exportName, fn)
        MULTI.ExportAs('rsg-core', exportName, fn)
    end,
    __index = function(_, resourceName) return rawExports[resourceName] end,
})

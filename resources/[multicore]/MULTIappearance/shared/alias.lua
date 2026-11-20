-- ============================================================
-- MULTIappearance :: export aliases
-- RSG v2 scripts call exports['rsg-appearance']:X(). The runtime looks an
-- export up through an event named __cfx_export_<resource>_<export>, so
-- answering that event is enough (same technique as MULTIcore's
-- shared/alias.lua). The fxmanifest also says provide 'rsg-appearance'.
-- ============================================================

MA = MA or {}

function MA.ExportAs(resourceName, exportName, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resourceName, exportName), function(setCB)
        setCB(fn)
    end)
end

-- registers fn as exports.MULTIappearance:name and exports['rsg-appearance']:name
function MA.Export(exportName, fn)
    exports(exportName, fn)
    MA.ExportAs('rsg-appearance', exportName, fn)
end

function MA.Debug(...)
    if Config.Debug then print('[MULTIappearance]', ...) end
end

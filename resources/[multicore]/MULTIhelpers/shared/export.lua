-- ============================================================
-- MULTIhelpers :: export registration
-- The runtime finds exports.<resource>:<name> through an event named
-- __cfx_export_<resource>_<name>; whoever answers that event with a
-- function provides the export. So one function can answer under
-- MULTIhelpers and under the VORP resource name it stands in for.
-- ============================================================

Helpers = Helpers or {}

local registered = {}   -- [resource] = { handler, ... } so they can be dropped again

local function answerAs(resourceName, exportName, fn)
    local h = AddEventHandler(('__cfx_export_%s_%s'):format(resourceName, exportName), function(setCB)
        setCB(fn)
    end)
    registered[resourceName] = registered[resourceName] or {}
    registered[resourceName][#registered[resourceName] + 1] = h
end

local function isRunning(res)
    local state = GetResourceState(res)
    return state == 'started' or state == 'starting'
end
Helpers.IsRunning = isRunning

--- Register `fn` as exports.MULTIhelpers:<exportName> and as exports.<res>:<exportName>
--- for every name in `standsInFor`. Skips a VORP name whose real resource is running.
function Helpers.Export(exportName, fn, standsInFor)
    exports(exportName, fn)
    for _, res in ipairs(standsInFor or {}) do
        if isRunning(res) and res ~= GetCurrentResourceName() then
            print('^1[MULTIhelpers] ' .. _L('warn_running', res, res) .. '^7')
        else
            answerAs(res, exportName, fn)
        end
    end
end

-- The real resource started after us: step aside so the two do not fight over the export.
AddEventHandler(IsDuplicityVersion() and 'onServerResourceStart' or 'onClientResourceStart', function(res)
    local list = registered[res]
    if not list or res == GetCurrentResourceName() then return end
    for _, h in ipairs(list) do RemoveEventHandler(h) end
    registered[res] = nil
    print('^1[MULTIhelpers] ' .. _L('warn_started', res, res) .. '^7')
end)

function Helpers.Debug(...)
    if Config and Config.Debug then
        print('[MULTIhelpers]', ...)
    end
end

--- Call a function that came from another resource without letting its error kill our thread.
function Helpers.SafeCall(fn, ...)
    if fn == nil then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        print('^1[MULTIhelpers] ' .. _L('callback_error', tostring(err)) .. '^7')
    end
end

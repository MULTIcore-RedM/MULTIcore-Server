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

-- GetResourceState follows `provide`, so 'vorp_inputs' reports MULTIhelpers' own state while
-- it starts. Only a resource that really has that name counts as the real one.
local function realRunning(res)
    if res == GetCurrentResourceName() then return false end
    for i = 0, GetNumResources() - 1 do
        if GetResourceByFindIndex(i) == res then return isRunning(res) end
    end
    return false
end
Helpers.RealRunning = realRunning

--- Register `fn` as exports.MULTIhelpers:<exportName> and as exports.<res>:<exportName>
--- for every name in `standsInFor`. Skips a VORP name whose real resource is running.
function Helpers.Export(exportName, fn, standsInFor)
    exports(exportName, fn)
    for _, res in ipairs(standsInFor or {}) do
        if realRunning(res) then
            print('^1[MULTIhelpers] ' .. _L('warn_running', res, res) .. '^7')
        else
            answerAs(res, exportName, fn)
        end
    end
end

--- Like Helpers.Export, but only under the other names, not as exports.MULTIhelpers:<exportName>.
--- For export names that several stand-ins share (initiate, send, tip ...).
function Helpers.ExportAs(exportName, fn, standsInFor)
    for _, res in ipairs(standsInFor or {}) do
        if realRunning(res) then
            print('^1[MULTIhelpers] ' .. _L('warn_running', res, res) .. '^7')
        else
            answerAs(res, exportName, fn)
        end
    end
end

--- An event of a stand-in name: answered only while the real resource is not running.
--- net = true also takes it from the server (TriggerClientEvent) or from clients.
function Helpers.On(res, eventName, fn, net)
    local handler = function(...)
        if realRunning(res) then return end
        return fn(...)
    end
    if net then RegisterNetEvent(eventName, handler) else AddEventHandler(eventName, handler) end
end

--- Functions handed over by another resource arrive as callable tables (function references).
function Helpers.Callable(f)
    if type(f) == 'function' then return true end
    local mt = type(f) == 'table' and getmetatable(f) or nil
    return mt ~= nil and mt.__call ~= nil
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

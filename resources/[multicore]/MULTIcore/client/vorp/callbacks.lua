-- ============================================================
-- MULTIcore :: VORP face - callbacks (client side)
-- Core.Callback.TriggerAsync / TriggerAwait / Register, as documented by
-- VORP (https://docs.vorp-core.com/api-reference/core). Written fresh;
-- no VORP code is used. The wire events match server/vorp/callbacks.lua:
--   client -> server : MULTIcore:vorp:cb:request (name, id, ...)
--   server -> client : MULTIcore:vorp:cb:response (id, ...)
--   server -> client : MULTIcore:vorp:cb:clientRequest (name, id, ...)
--   client -> server : MULTIcore:vorp:cb:clientResponse (id, ...)
-- ============================================================

MULTI = MULTI or {}
MULTI.VorpClient = MULTI.VorpClient or {}
local VC = MULTI.VorpClient

local TIMEOUT_MS = 30000     -- same as the server side's wait for a client answer

local handlers = {}          -- name -> function(cb, ...) for server -> client requests
local pending = {}           -- request id -> function(...) waiting for the server's answer
local nextId = 0

-- A function passed in from another resource arrives as a callable table.
local function callable(v)
    if type(v) == 'function' then return true end
    if type(v) == 'table' then
        local mt = getmetatable(v)
        return mt ~= nil and mt.__call ~= nil
    end
    return false
end

local function send(name, onAnswer, ...)
    nextId = nextId + 1
    local id = nextId
    pending[id] = onAnswer
    SetTimeout(TIMEOUT_MS, function()
        local fn = pending[id]
        if fn then
            pending[id] = nil
            print(('^3[MULTIcore] VORP callback "%s" got no answer in %d ms^7'):format(tostring(name), TIMEOUT_MS))
            fn()
        end
    end)
    TriggerServerEvent('MULTIcore:vorp:cb:request', name, id, ...)
end

RegisterNetEvent('MULTIcore:vorp:cb:response', function(id, ...)
    local fn = pending[id]
    if not fn then return end
    pending[id] = nil
    fn(...)
end)

local Callback = {}

--- Registers a callback the server can call: fn(cb, ...).
function Callback.Register(name, fn)
    if type(name) ~= 'string' or not callable(fn) then return false end
    handlers[name] = fn
    return true
end

--- Calls a server callback; the answer goes to cb.
--- VORP's docs show (name, source, cb, ...); scripts also call (name, cb, ...).
--- Both are accepted: the first callable argument is the callback.
function Callback.TriggerAsync(name, a, b, ...)
    if callable(a) then
        if b == nil and select('#', ...) == 0 then
            return send(name, function(...) a(...) end)
        end
        return send(name, function(...) a(...) end, b, ...)
    end
    if callable(b) then
        return send(name, function(...) b(...) end, ...)
    end
    -- no callback given: still send, ignore the answer
    return send(name, function() end, a, b, ...)
end

--- Calls a server callback and waits for the answer (must run in a thread).
--- Scripts call it as (name, ...); every argument after the name goes to the server.
function Callback.TriggerAwait(name, ...)
    local p = promise.new()
    send(name, function(...) p:resolve(table.pack(...)) end, ...)
    local res = Citizen.Await(p)
    return table.unpack(res, 1, res.n)
end

RegisterNetEvent('MULTIcore:vorp:cb:clientRequest', function(name, id, ...)
    local fn = handlers[name]
    if not fn then
        print(('^3[MULTIcore] server called unknown VORP client callback "%s"^7'):format(tostring(name)))
        TriggerServerEvent('MULTIcore:vorp:cb:clientResponse', id)
        return
    end
    local answered = false
    local ok, err = pcall(fn, function(...)
        if answered then return end
        answered = true
        TriggerServerEvent('MULTIcore:vorp:cb:clientResponse', id, ...)
    end, ...)
    if not ok then
        print(('^1[MULTIcore] VORP client callback "%s" failed: %s^7'):format(tostring(name), tostring(err)))
        if not answered then
            answered = true
            TriggerServerEvent('MULTIcore:vorp:cb:clientResponse', id)
        end
    end
end)

VC.Callback = Callback

-- exports.vorp_core:ClientRpcCall() gives the callback table on its own (VORP docs)
MULTI.ExportAs('vorp_core', 'ClientRpcCall', function() return Callback end)

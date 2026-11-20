-- ============================================================
-- MULTIcore :: VORP face - callbacks (server side)
-- Core.Callback.Register / TriggerAwait / TriggerAsync, as documented by
-- VORP. Both ends (this file and the client face) belong to MULTIcore,
-- so the wire events are MULTIcore's own.
-- ============================================================

MULTI.Vorp = MULTI.Vorp or {}
local V = MULTI.Vorp

local handlers = {}      -- name -> function(source, cb, ...)
local pending = {}       -- request id -> callback, for server -> client calls
local nextId = 0

local Callback = {}

--- Registers a callback that clients can call.
function Callback.Register(name, fn)
    if type(name) ~= 'string' or type(fn) ~= 'function' and type(fn) ~= 'table' then return false end
    handlers[name] = fn
    return true
end

RegisterNetEvent('MULTIcore:vorp:cb:request', function(name, reqId, ...)
    local src = source
    local fn = handlers[name]
    if not fn then
        print(('^3[MULTIcore] client %s called unknown VORP callback "%s"^7'):format(src, tostring(name)))
        TriggerClientEvent('MULTIcore:vorp:cb:response', src, reqId)
        return
    end
    local answered = false
    local ok, err = pcall(fn, src, function(...)
        if answered then return end
        answered = true
        TriggerClientEvent('MULTIcore:vorp:cb:response', src, reqId, ...)
    end, ...)
    if not ok then
        print(('^1[MULTIcore] VORP callback "%s" failed: %s^7'):format(name, tostring(err)))
        if not answered then TriggerClientEvent('MULTIcore:vorp:cb:response', src, reqId) end
    end
end)

--- Calls a callback registered on a client and passes the answer to cb.
function Callback.TriggerAsync(name, src, cb, ...)
    nextId = nextId + 1
    local id = nextId
    pending[id] = { cb = cb, src = src }
    TriggerClientEvent('MULTIcore:vorp:cb:clientRequest', src, name, id, ...)
    SetTimeout(30000, function()
        local p = pending[id]
        if p then pending[id] = nil; if p.cb then p.cb(nil) end end
    end)
end

--- Calls a callback registered on a client and waits for the answer.
function Callback.TriggerAwait(name, src, ...)
    local p = promise.new()
    Callback.TriggerAsync(name, src, function(...) p:resolve(table.pack(...)) end, ...)
    local res = Citizen.Await(p)
    return table.unpack(res, 1, res.n)
end

RegisterNetEvent('MULTIcore:vorp:cb:clientResponse', function(id, ...)
    local p = pending[id]
    if not p or p.src ~= source then return end
    pending[id] = nil
    if p.cb then p.cb(...) end
end)

V.Callback = Callback

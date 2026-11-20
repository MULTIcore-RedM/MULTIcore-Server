-- ============================================================
-- MULTIinventory :: client state and helpers  (UI builder)
-- GPL v3, part of MULTIcore.
--
-- Shared table MIC for every client file of this resource:
--   MIC.Cfg(path, default)   read config.lua defensively
--   MIC.Def(name)            item definition (engine payload, then RSG shared items)
--   MIC.Inv                  the player's own satchel as last sent by the server
--   MIC.Other                the second pane (stash / drop / custom / player)
--   MIC.Notify(text, kind)   MULTIcore notify
-- The server is always right: the client only shows what it was sent and
-- asks the server to change things.
-- ============================================================

MIC = MIC or {}
MIC.Defs = MIC.Defs or {}     -- [name] = def (from the engine's payloads)
MIC.Inv = MIC.Inv or nil      -- { id, label, slots, maxWeight, items = { [slot] = item } }
MIC.Other = MIC.Other or nil
MIC.IsOpen = false

--- Read a config value by dotted path ('Weapons.Enabled'); default when missing.
function MIC.Cfg(path, default)
    local t = rawget(_G, 'Config')
    for part in tostring(path):gmatch('[^%.]+') do
        if type(t) ~= 'table' then return default end
        t = t[part]
    end
    if t == nil then return default end
    return t
end

local RSG
local function core()
    if RSG == nil then
        local ok, obj = pcall(function() return exports['rsg-core']:GetCoreObject() end)
        RSG = ok and obj or false
    end
    return RSG or nil
end
MIC.Core = core

--- Item definition by name: the engine's own (sent with inventories), else RSG shared items.
function MIC.Def(name)
    if type(name) ~= 'string' then return nil end
    local d = MIC.Defs[name]
    if d then return d end
    local c = core()
    local items = c and c.Shared and c.Shared.Items
    d = items and (items[name] or items[name:lower()])
    return d
end

function MIC.MergeDefs(defs)
    if type(defs) ~= 'table' then return end
    for k, v in pairs(defs) do
        if type(v) == 'table' then MIC.Defs[v.name or k] = v end
    end
end

-- every notification goes through MULTIcore
function MIC.Notify(text, kind, duration)
    pcall(function()
        exports.MULTIcore:Notify({ text = text, title = _L('title_satchel'), type = kind or 'info', duration = duration })
    end)
end

-- engine error codes ('no_space', 'too_heavy', 'limit', 'too_far', ...) are locale keys err_<code>
function MIC.Error(code)
    local key = 'err_' .. tostring(code or 'failed')
    local text = _L(key)
    if text == key then text = _L('err_failed') end
    MIC.Notify(text, 'error')
end

function MIC.LoggedIn()
    return LocalPlayer.state.isLoggedIn == true
end

local function playerMeta()
    local c = core()
    local ok, data = pcall(function() return c and c.Functions.GetPlayerData() end)
    return ok and type(data) == 'table' and data.metadata or {}
end

--- May the player open / use the satchel now? (alive, not cuffed, not busy)
function MIC.CanUse(ignoreBusy)
    if not MIC.LoggedIn() then return false end
    -- RSG scripts lock the satchel with inv_busy (rsg-inventory also sets it while its page is open)
    if LocalPlayer.state.inv_busy and not ignoreBusy then return false end
    -- vorp_inventory:blockInventory (client/vorp) sets this
    if MIC.Blocked then return false end
    local m = playerMeta()
    if m.isdead or m.ishandcuffed then return false end
    if IsEntityDead(PlayerPedId()) then return false end
    return true
end

--- Normalise an inventory's items to { [slot(number)] = item }.
function MIC.NormItems(items)
    local out = {}
    if type(items) ~= 'table' then return out end
    for k, it in pairs(items) do
        if type(it) == 'table' and it.name then
            local slot = tonumber(it.slot) or tonumber(k)
            if slot then
                it.slot = slot
                it.amount = tonumber(it.amount or it.count) or 1
                it.info = type(it.info) == 'table' and it.info or (type(it.metadata) == 'table' and it.metadata or {})
                out[slot] = it
            end
        end
    end
    return out
end

--- Store an inventory the server sent; returns the stored copy.
function MIC.SetInv(inv, isPlayer)
    if type(inv) ~= 'table' then return nil end
    inv.items = MIC.NormItems(inv.items or inv.inventory)
    inv.id = inv.id or inv.name
    inv.maxWeight = tonumber(inv.maxWeight or inv.maxweight) or 0
    inv.slots = tonumber(inv.slots) or 0
    if isPlayer then MIC.Inv = inv else MIC.Other = inv end
    return inv
end

--- Count of an item in the player's satchel (from the last server push; falls back to PlayerData.items).
function MIC.PlayerItems()
    if MIC.Inv and MIC.Inv.items then return MIC.Inv.items end
    local c = core()
    local ok, data = pcall(function() return c and c.Functions.GetPlayerData() end)
    if ok and type(data) == 'table' and type(data.items) == 'table' then return MIC.NormItems(data.items) end
    return {}
end

function MIC.CountItem(name)
    local n = 0
    for _, it in pairs(MIC.PlayerItems()) do
        if it.name == name then n = n + (tonumber(it.amount) or 0) end
    end
    return n
end

-- callbacks other client files hook into (weapons, hotbar) when the satchel changes
MIC.OnInvChange = MIC.OnInvChange or {}
function MIC.FireInvChange()
    for _, fn in ipairs(MIC.OnInvChange) do
        local ok, err = pcall(fn, MIC.Inv)
        if not ok then print(('[MULTIinventory] inventory change hook failed: %s'):format(err)) end
    end
end

-- the VORP face also announces blocking as an event
AddEventHandler('MULTIinventory:client:block', function(state) MIC.Blocked = state == true end)

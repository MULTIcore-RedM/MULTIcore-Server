-- ============================================================
-- MULTIinventory :: engine state and helpers (server)
-- GPL v3. Parts of the engine follow RSG v2's rsg-inventory (GPL v3,
-- Copyright the RSG / Rexshack-RedM team); those places are marked
-- "from rsg-inventory" and listed in CREDITS.md.
-- ============================================================

MULTIInv = MULTIInv or {}
local Inv = MULTIInv

Inv.Items = {}          -- item registry: name -> definition
Inv.List = {}           -- loaded inventories: id -> inventory
Inv.BySrc = {}          -- player source -> 'player:<citizenid>'
Inv.Opened = {}         -- player source -> id of the second inventory the player has open
Inv.Usables = {}        -- item name -> list of { fn, resource, builtin }
Inv.ready = false       -- true once tables exist and stashes are loaded

Inv.WeaponData = MULTIInvData.Weapons
Inv.AmmoData = MULTIInvData.Ammo

local RSGCore = exports['rsg-core']:GetCoreObject()
Inv._core = RSGCore

--- Fresh copy of the core object (RSGCore.Shared.Items changes at runtime).
function Inv.Core(refresh)
    if refresh then RSGCore = exports['rsg-core']:GetCoreObject(); Inv._core = RSGCore end
    return RSGCore
end

--- RSG player object (a copy) for a source, or nil.
function Inv.GetPlayer(src)
    src = tonumber(src)
    if not src then return nil end
    local ok, P = pcall(RSGCore.Functions.GetPlayer, src)
    if ok then return P end
end

function Inv.Debug(...)
    if Config.Debug then print('^5[MULTIinventory]^7', ...) end
end

function Inv.Notify(src, key, ntype, ...)
    if not src or src <= 0 then return end
    local text = _L(key, ...)
    pcall(function() exports.MULTIcore:Notify(src, text, ntype or 'info') end)
end

-- ------------------------------------------------------------
-- small helpers
-- ------------------------------------------------------------

function Inv.DeepCopy(v, seen)
    if type(v) ~= 'table' then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}
    seen[v] = out
    for k, x in pairs(v) do out[Inv.DeepCopy(k, seen)] = Inv.DeepCopy(x, seen) end
    return out
end

local IGNORED_INFO = { lastUpdate = true }

local function deepEqual(a, b, top)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then
        -- 1 and 1.0 are the same amount
        if type(a) == 'number' and type(b) == 'number' then return a == b end
        return false
    end
    for k, v in pairs(a) do
        if not (top and IGNORED_INFO[k]) and not deepEqual(v, b[k]) then return false end
    end
    for k, v in pairs(b) do
        if not (top and IGNORED_INFO[k]) and a[k] == nil and v ~= nil then return false end
    end
    return true
end

--- Two item infos are the same for stacking (lastUpdate, the decay clock, is ignored).
function Inv.InfoEqual(a, b)
    a = type(a) == 'table' and a or {}
    b = type(b) == 'table' and b or {}
    return deepEqual(a, b, true)
end

--- Does `info` contain every key/value of `match` (nil match = anything)?
function Inv.InfoMatches(info, match)
    if match == nil then return true end
    if type(match) ~= 'table' then return false end
    info = type(info) == 'table' and info or {}
    for k, v in pairs(match) do
        if not deepEqual(info[k], v) then return false end
    end
    return true
end

function Inv.IsPositiveInt(n, max)
    return type(n) == 'number' and n >= 1 and n == math.floor(n) and n < 2 ^ 31 and (not max or n <= max)
end

--- Whole positive amount or nil.
function Inv.Amount(n, default)
    n = tonumber(n) or default
    if Inv.IsPositiveInt(n) then return n end
    return nil
end

--- Re-keys an items table by numeric slot (JSON turns sparse slot keys into strings,
--- and saved lists are arrays). From rsg-inventory's NormalizeItems.
function Inv.NormalizeItems(items)
    local out = {}
    if type(items) ~= 'table' then return out end
    for key, item in pairs(items) do
        if type(item) == 'table' and type(item.name) == 'string' then
            local slot = tonumber(item.slot) or tonumber(key)
            if slot then
                item.slot = slot
                item.info = type(item.info) == 'table' and item.info or {}
                out[slot] = item
            end
        end
    end
    return out
end

--- Player position (vector3) or nil when the ped is not there (e.g. a test player).
function Inv.PlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

function Inv.IsAdmin(src)
    return src and src > 0 and IsPlayerAceAllowed(src, Config.AdminAce) or false
end

-- per-player rate limit
local last = {}
function Inv.RateLimited(src, what)
    local key = src .. ':' .. (what or '')
    local now = GetGameTimer()
    if last[key] and now - last[key] < Config.RateLimitMs then return true end
    last[key] = now
    return false
end
AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for k in pairs(last) do
        if k:sub(1, #src + 1) == src .. ':' then last[k] = nil end
    end
end)

-- per-player lock: one move / give / use at a time, even across yields
local locks = {}
function Inv.Lock(src)
    if locks[src] then return false end
    locks[src] = true
    return true
end
function Inv.Unlock(src) locks[src] = nil end

--- Runs fn with the player's lock held; returns fn's results or false, 'busy'.
function Inv.WithLock(src, fn, ...)
    if not Inv.Lock(src) then return false, 'busy' end
    local res = table.pack(pcall(fn, ...))
    Inv.Unlock(src)
    if not res[1] then
        print('^1[MULTIinventory] error: ' .. tostring(res[2]) .. '^7')
        return false, 'error'
    end
    return table.unpack(res, 2, res.n)
end

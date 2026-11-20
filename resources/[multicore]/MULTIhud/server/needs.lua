-- MULTIhud server: needs decay and the one place needs are written.
-- Needs live in the RSGCore player metadata (0-100) and are mirrored to the player's
-- state bag (Player(src).state.hunger ...), which is what RSG scripts read on the client.
-- MULTIcore's Save() copies the state bag back into the metadata, so both are always written together.

local RSGCore = exports['rsg-core']:GetCoreObject()

Needs = {}

-- keys this resource manages and their ranges
Needs.Range = {
    hunger = { 0, 100 },
    thirst = { 0, 100 },
    cleanliness = { 0, 100 },
    stress = { 0, 100 },
    metabolism = { -10000, 10000 },   -- VORP "Metabolism" (no RSG equivalent), stored as-is
}
-- keys mirrored to the state bag (MULTIcore mirrors the first four; metabolism is ours, for the client getter)
local STATE_KEYS = { hunger = true, thirst = true, cleanliness = true, stress = true, metabolism = true }

local lastWritten = {}   -- [src][key] = value this resource last wrote
local activity = {}      -- [src] = { mode = 'idle'|'run'|'sprint'|'swim', temp = 'mild'|'cold'|'hot', at = ms }
local lastShot = {}      -- [src] = ms of the last accepted shot report
local TIMER_SLACK = 0.8   -- client reports may arrive up to 20% early (timer and network jitter)

local function dbg(...)
    if Config.Debug then print('[MULTIhud]', ...) end
end

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

---Current value of a need, taking into account writes made by others since our last write:
---a script that called SetMetaData wins, then a client that set the state bag, then our own value.
function Needs.Get(P, key)
    local src = P.PlayerData.source
    local md = tonumber(P.PlayerData.metadata[key])
    local sv = STATE_KEYS[key] and tonumber(Player(src).state[key]) or nil
    local l = lastWritten[src] and lastWritten[src][key]
    if l == nil then
        return md or sv or Config.Defaults[key] or 0
    end
    if md and md ~= l then return md end
    if sv and sv ~= l then return sv end
    return l
end

---Write several needs at once (absolute values). Clamps, stores in metadata and the state bag.
function Needs.Write(P, changes)
    local src = P.PlayerData.source
    local clean = {}
    for key, value in pairs(changes) do
        local range = Needs.Range[key]
        value = tonumber(value)
        if range and value and value == value and value ~= math.huge and value ~= -math.huge then
            clean[key] = round2(math.min(range[2], math.max(range[1], value)))
        end
    end
    if not next(clean) then return end
    P.Functions.SetMetaData(clean)
    lastWritten[src] = lastWritten[src] or {}
    local state = Player(src).state
    -- P is a copy (it crossed from MULTIcore), so it does not see the write: use our own clamped value,
    -- which is the same clamp MULTIcore applies.
    for key, stored in pairs(clean) do
        P.PlayerData.metadata[key] = stored
        lastWritten[src][key] = stored
        if STATE_KEYS[key] then state:set(key, stored, true) end
    end
    dbg(('src %s write %s'):format(src, json.encode(clean)))
end

---Add to several needs at once (deltas).
function Needs.Add(P, deltas)
    local abs = {}
    for key, delta in pairs(deltas) do
        delta = tonumber(delta)
        if Needs.Range[key] and delta then abs[key] = Needs.Get(P, key) + delta end
    end
    Needs.Write(P, abs)
end

function Needs.Player(src)
    return RSGCore.Functions.GetPlayer(tonumber(src))
end

---------------------------------------------------------------------------
-- Decay loop
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.TickSeconds * 1000)
        local frac = Config.TickSeconds / 60
        local now = GetGameTimer()
        for src, P in pairs(RSGCore.Functions.GetRSGPlayers()) do
            if P and not P.Offline and not (Config.SkipDead and P.PlayerData.metadata.isdead) then
                local a = activity[src] or {}
                local mult = Config.ActivityMultiplier[a.mode or 'idle'] or 1.0
                local changes = {}
                for key, rate in pairs(Config.Decay) do
                    if rate and rate ~= 0 and Needs.Range[key] then
                        local m = Config.ActivityAffects[key] and mult or 1.0
                        if Config.Temperature.Enabled then
                            if key == 'hunger' and a.temp == 'cold' then m = m * Config.Temperature.ColdHungerMultiplier end
                            if key == 'thirst' and a.temp == 'hot' then m = m * Config.Temperature.HotThirstMultiplier end
                        end
                        changes[key] = Needs.Get(P, key) - rate * m * frac
                    end
                end
                local rec = Config.Stress.RecoveryPerMinute or 0
                if rec > 0 and now - (lastShot[src] or -math.huge) >= Config.Stress.RecoveryDelaySeconds * 1000 then
                    local s = Needs.Get(P, 'stress')
                    if s > 0 then changes.stress = s - rec * frac end
                end
                Needs.Write(P, changes)
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Client reports
---------------------------------------------------------------------------
local MODES = { idle = true, run = true, sprint = true, swim = true }
local TEMPS = { mild = true, cold = true, hot = true }

RegisterNetEvent('MULTIhud:server:activity', function(mode, temp)
    local src = source
    local now = GetGameTimer()
    local a = activity[src]
    -- throttle: a little slack under the client's own limit
    if a and now - a.at < Config.ReportMinSeconds * 1000 * TIMER_SLACK then return end
    activity[src] = {
        mode = MODES[mode] and mode or 'idle',
        temp = TEMPS[temp] and temp or 'mild',
        at = now,
    }
end)

RegisterNetEvent('MULTIhud:server:shot', function()
    local src = source
    if not Config.Stress.FromShooting then return end
    local now = GetGameTimer()
    if lastShot[src] and now - lastShot[src] < Config.Stress.ShotCooldownMs * TIMER_SLACK then return end
    local P = Needs.Player(src)
    if not P then return end
    lastShot[src] = now
    local job = P.PlayerData.job and P.PlayerData.job.name
    if job and Config.Stress.ExemptJobs[job] then return end
    Needs.Add(P, { stress = Config.Stress.PerShot })
end)

---------------------------------------------------------------------------
-- Client writes (forwarded from rsg-hud / vorp_metabolism style events on the client).
-- RSG already lets clients write these keys (RSGConfig.ClientWritableMetadata), so this is
-- no new trust; it is rate limited and clamped.
---------------------------------------------------------------------------
local writes = {}   -- [src] = { at = ms window start, n = count }
local CLIENT_KEYS = { hunger = true, thirst = true, cleanliness = true, stress = true, metabolism = true }

local function allowWrite(src)
    local now = GetGameTimer()
    local w = writes[src]
    if not w or now - w.at > 1000 then
        writes[src] = { at = now, n = 1 }
        return true
    end
    w.n = w.n + 1
    return w.n <= Config.ClientWrites.PerSecond
end

local function filter(tbl)
    if type(tbl) ~= 'table' then return nil end
    local out = {}
    for key, value in pairs(tbl) do
        if CLIENT_KEYS[key] and type(value) == 'number' then out[key] = value end
    end
    return next(out) and out or nil
end

RegisterNetEvent('MULTIhud:server:setNeeds', function(tbl)
    local src = source
    if not allowWrite(src) then return end
    local P = Needs.Player(src)
    local t = filter(tbl)
    if P and t then Needs.Write(P, t) end
end)

RegisterNetEvent('MULTIhud:server:addNeeds', function(tbl)
    local src = source
    if not allowWrite(src) then return end
    local P = Needs.Player(src)
    local t = filter(tbl)
    if P and t then Needs.Add(P, t) end
end)

---------------------------------------------------------------------------
-- Keep the state bag in step when a script writes the metadata directly.
-- (rsg-canteen calls RSGCore:Server:SetMetaData; without this, the next Save() would copy the
-- old state bag value back over it.)
---------------------------------------------------------------------------
RegisterNetEvent('RSGCore:Server:SetMetaData', function(meta)
    local src = source
    if not STATE_KEYS[meta] then return end
    SetTimeout(0, function()
        local P = Needs.Player(src)
        if not P then return end
        local v = tonumber(P.PlayerData.metadata[meta])
        if v then
            Player(src).state:set(meta, v, true)
            lastWritten[src] = lastWritten[src] or {}
            lastWritten[src][meta] = v
        end
    end)
end)

---------------------------------------------------------------------------
-- Load / unload
---------------------------------------------------------------------------
AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
    local src = P.PlayerData.source
    lastWritten[src] = nil
    activity[src] = nil
    lastShot[src] = nil
    -- fill in any need the character has no value for yet
    local missing = {}
    for key, def in pairs(Config.Defaults) do
        if tonumber(P.PlayerData.metadata[key]) == nil then missing[key] = def end
    end
    if next(missing) then Needs.Write(P, missing) end
    -- MULTIcore only mirrors its own keys to the state bag on load
    local m = tonumber(P.PlayerData.metadata.metabolism)
    if m then Player(src).state:set('metabolism', m, true) end
end)

local function forget(src)
    lastWritten[src] = nil
    activity[src] = nil
    lastShot[src] = nil
    writes[src] = nil
end

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) forget(src) end)
AddEventHandler('playerDropped', function() forget(source) end)

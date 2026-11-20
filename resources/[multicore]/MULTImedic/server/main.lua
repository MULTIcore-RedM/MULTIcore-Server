-- ============================================================
-- MULTImedic :: server
-- Owns the death state (metadata isdead, state bag isDead), checks every
-- respawn, revive, treatment and doctor call. Revives and heals go through
-- MULTIcore's Core.Player (VORP face) so VORP's and MULTIcore's own events
-- fire once, from one place.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

Medic = {}

local deathAt = {}       -- [src] = os.time() of the death
local deathDone = {}     -- [src] = true once the death actions (fee, losses) ran for this death
local deathInjured = {}  -- [src] = true once death injuries were given for this death
local lastCall = {}      -- [src] = os.time() of the last doctor call
local pending = {}       -- [src] = { target, kind, t } a medic action in progress
local lastHit = {}       -- [src] = os.time() of the last counted body hit
local respawning = {}    -- [src] = true while a respawn is being handled
local extraTime = {}     -- [src] = seconds added to this death's respawn timer (vorp_core:Client:AddTimeToRespawn)

local function dbg(...)
    if Config.Debug then print('[MULTImedic]', ...) end
end
Medic.dbg = dbg

local function notify(src, text, kind)
    exports.MULTIcore:Notify(src, { text = text, type = kind or 'medic' })
end
Medic.notify = notify

local function getP(src)
    return src and RSGCore.Functions.GetPlayer(tonumber(src) or -1) or nil
end
Medic.getP = getP

local function fullName(P)
    local c = P and P.PlayerData.charinfo or {}
    return ('%s %s'):format(c.firstname or '?', c.lastname or '')
end
Medic.fullName = fullName

function Medic.IsAdmin(src)
    if not src or src == 0 then return true end -- server console
    return RSGCore.Functions.HasPermission(src, Config.AdminPermissions)
end

function Medic.IsMedic(P)
    if not P then return false end
    local job = P.PlayerData.job or {}
    if not Config.MedicJobs[job.name] then return false end
    return (not Config.RequireOnDuty) or job.onduty == true
end

function Medic.IsDead(src)
    local P = getP(src)
    return P ~= nil and P.PlayerData.metadata.isdead == true
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if c.x == 0.0 and c.y == 0.0 and c.z == 0.0 then return nil end
    return c
end
Medic.pedCoords = pedCoords

-- true when a and b stand within max metres (always true with the check off)
local function near(a, b, max)
    if not Config.ServerDistanceCheck then return true end
    local ca, cb = pedCoords(a), pedCoords(b)
    if not ca or not cb then return false end
    return #(ca - cb) <= max
end

local function core()
    local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
    return ok and c or nil
end

-- ------------------------------------------------------------
-- death state
-- ------------------------------------------------------------
local function setDead(src, P, dead)
    P.Functions.SetMetaData({ isdead = dead, inlaststand = false })
    Player(src).state:set('isDead', dead, true)
end

local function clearDeath(src)
    local P = getP(src)
    deathAt[src], deathDone[src], deathInjured[src], lastCall[src], respawning[src] = nil, nil, nil, nil, nil
    extraTime[src] = nil
    if not P then return end
    local wasDead = P.PlayerData.metadata.isdead == true
    setDead(src, P, false)
    TriggerClientEvent('MULTImedic:client:closeDeath', src)
    if wasDead then
        Medic.ResetInjuries(src)
        TriggerEvent('MULTImedic:server:onRevive', src)
        dbg('alive again', src)
    end
end
Medic.ClearDeath = clearDeath

-- the client reports its own death (from MULTIcore's vorp_core:Client:OnPlayerDeath or its own check)
RegisterNetEvent('MULTImedic:server:died', function(killerId, cause)
    local src = source
    local P = getP(src)
    if not P then return end
    if deathAt[src] then return end -- already down
    setDead(src, P, true)
    deathAt[src] = os.time()
    extraTime[src] = nil
    deathDone[src] = nil

    if Config.Injuries.Enabled and Config.Injuries.DeathInjuries then Medic.ApplyDeathInjuries(src) end

    killerId = tonumber(killerId) or 0
    if Config.Compat.DeathLog then
        local killer = (killerId > 0 and getP(killerId)) and ('%s (%d)'):format(GetPlayerName(killerId) or '?', killerId) or _L('log_unknown')
        TriggerEvent('rsg-log:server:CreateLog', 'death',
            _L('log_title', GetPlayerName(src) or '?', src),
            'red', _L('log_text', fullName(P), killer, tostring(cause or '?')))
    end
    TriggerEvent('MULTImedic:server:onDeath', src, killerId, cause)
    dbg('died', src, 'killer', killerId, 'cause', cause)
end)

-- MULTIcore's Core.Player.Revive / Respawn fire these (also when MULTIadmin revives)
AddEventHandler('vorp_core:Server:OnPlayerRevive', function(src) clearDeath(tonumber(src)) end)
AddEventHandler('vorp_core:Server:OnPlayerRespawn', function(src) clearDeath(tonumber(src)) end)

--- Brings a player back where they lie. healthPct: health after the revive (percent of max).
function Medic.Revive(src, healthPct)
    src = tonumber(src)
    if not getP(src) then return false end
    local c = core()
    if c and c.Player and c.Player.Revive then
        c.Player.Revive(src)       -- core resurrects, fires VORP's OnPlayerRevive (we clear the state there)
    else
        clearDeath(src)
        TriggerClientEvent('MULTIcore:vorp:revive', src)
    end
    clearDeath(src)                -- in case the core event did not reach us
    TriggerClientEvent('MULTImedic:client:afterRevive', src, tonumber(healthPct) or 100)
    return true
end

function Medic.Heal(src)
    src = tonumber(src)
    if not getP(src) then return false end
    local c = core()
    if c and c.Player and c.Player.Heal then c.Player.Heal(src) else TriggerClientEvent('MULTIcore:vorp:heal', src) end
    Medic.ResetInjuries(src)
    return true
end

-- ------------------------------------------------------------
-- death actions: fee and losses (once per death)
-- ------------------------------------------------------------
function Medic.DeathActions(src)
    local P = getP(src)
    if not P or deathDone[src] then return 0 end
    deathDone[src] = true
    local R = Config.Respawn
    local charged = 0

    if (R.Fee or 0) > 0 then
        local cash = P.Functions.GetMoney('cash') or 0
        local fromCash = math.min(cash, R.Fee)
        if fromCash > 0 and P.Functions.RemoveMoney('cash', fromCash, 'doctor-fee') then charged = charged + fromCash end
        local rest = R.Fee - charged
        if rest > 0 and R.FeeFromBank then
            local bank = P.Functions.GetMoney('bank') or 0
            local fromBank = math.min(bank, rest)
            if fromBank > 0 and P.Functions.RemoveMoney('bank', fromBank, 'doctor-fee') then charged = charged + fromBank end
        end
    end

    if R.LoseCash and (P.Functions.GetMoney('cash') or 0) > 0 then
        P.Functions.SetMoney('cash', 0, 'death')
        notify(src, _L('lost_cash'), 'warning')
    end
    if R.LoseBloodmoney and P.PlayerData.money.bloodmoney ~= nil and P.PlayerData.money.bloodmoney > 0 then
        P.Functions.SetMoney('bloodmoney', 0, 'death')
        notify(src, _L('lost_bloodmoney'), 'warning')
    end
    if R.LoseItems then
        if GetResourceState('rsg-inventory') == 'started' then
            local ok = pcall(function() exports['rsg-inventory']:ClearInventory(src, R.KeepItems or {}) end)
            if ok then notify(src, _L('lost_items'), 'warning') end
        end
    end
    return charged
end

local function nearestLocation(pos)
    local best, bestDist = Config.Respawn.Locations[1], math.huge
    if not pos then return best end
    for _, loc in ipairs(Config.Respawn.Locations) do
        local d = #(pos - vector3(loc.coords.x, loc.coords.y, loc.coords.z))
        if d < bestDist then best, bestDist = loc, d end
    end
    return best
end

-- a script added time to this death's respawn timer (vorp_core:Client:AddTimeToRespawn, client/compat.lua).
-- It can only make the wait longer, so the client is trusted with it; capped like on the client.
RegisterNetEvent('MULTImedic:server:addRespawnTime', function(seconds)
    local src = source
    seconds = math.floor(tonumber(seconds) or 0)
    if not deathAt[src] or seconds <= 0 then return end
    local max = tonumber(Config.Compat.MaxAddRespawnSeconds) or 0
    local now = extraTime[src] or 0
    if max > 0 then seconds = math.min(seconds, math.max(0, max - now)) end
    extraTime[src] = now + seconds
end)

-- the player held E after the timer
RegisterNetEvent('MULTImedic:server:respawn', function(clientPos)
    local src = source
    local P = getP(src)
    if not P or respawning[src] then return end
    if P.PlayerData.metadata.isdead ~= true or not deathAt[src] then return end
    if os.time() - deathAt[src] < Config.RespawnTimer + (extraTime[src] or 0) - 2 then
        notify(src, _L('too_early'), 'error')
        return
    end
    respawning[src] = true

    local pos = pedCoords(src)
    if not pos and not Config.ServerDistanceCheck and type(clientPos) == 'vector3' then pos = clientPos end
    local loc = nearestLocation(pos)

    local charged = Medic.DeathActions(src)

    if Config.Respawn.ResetNeeds and GetResourceState('MULTIhud') == 'started' then
        pcall(function() exports.MULTIhud:SetNeeds(src, Config.Respawn.Needs) end)
    end

    local c = core()
    if Config.Respawn.UseCoreRespawn and c and c.Player and c.Player.Respawn then
        c.Player.Respawn(src, loc.coords)  -- the core fires OnPlayerRespawn (clears our state)
        clearDeath(src)
        TriggerClientEvent('MULTImedic:client:afterRevive', src, Config.Respawn.HealthPercent)
    else
        clearDeath(src)
        TriggerClientEvent('MULTImedic:client:respawnAt', src, loc.coords, Config.Respawn.HealthPercent)
        -- the core's Respawn would fire this; MULTImedic moved the player itself, so it fires it once here
        TriggerEvent('vorp_core:Server:OnPlayerRespawn', src)
    end

    if charged > 0 then
        notify(src, _L('respawned_fee', _L(loc.label), charged), 'money')
    else
        notify(src, _L('respawned', _L(loc.label)), 'medic')
    end
    dbg('respawn', src, loc.label, 'fee', charged)
end)

-- ------------------------------------------------------------
-- doctor calls
-- ------------------------------------------------------------
function Medic.MedicCount()
    local n = 0
    for _, P in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if Medic.IsMedic(P) then n = n + 1 end
    end
    return n
end

--- Sends a call to every medic. Returns how many got it.
function Medic.Alert(coords, text, fromSrc)
    if type(coords) ~= 'vector3' then return 0 end
    local n = 0
    for medicSrc, P in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if medicSrc ~= fromSrc and Medic.IsMedic(P) then
            TriggerClientEvent('MULTImedic:client:alert', medicSrc, coords, text)
            n = n + 1
        end
    end
    return n
end

local function callAllowed(src)
    local now = os.time()
    if lastCall[src] and now - lastCall[src] < Config.Call.Cooldown then return false end
    lastCall[src] = now
    return true
end
Medic.CallAllowed = callAllowed

RegisterNetEvent('MULTImedic:server:callDoctor', function()
    local src = source
    local P = getP(src)
    if not P or not Config.Call.Enabled then return end
    if P.PlayerData.metadata.isdead ~= true then return end
    if not callAllowed(src) then
        TriggerClientEvent('MULTImedic:client:callResult', src, false, 'cooldown')
        return
    end
    local pos = pedCoords(src)
    if not pos then
        TriggerClientEvent('MULTImedic:client:callResult', src, false, 'no_pos')
        return
    end
    local n = Medic.Alert(pos, _L('alert_text', fullName(P)), src)
    TriggerClientEvent('MULTImedic:client:callResult', src, n > 0, n > 0 and 'sent' or 'none')
    notify(src, n > 0 and _L('doctor_called') or _L('no_medics'), n > 0 and 'medic' or 'warning')
    dbg('doctor call from', src, 'reached', n)
end)

lib.callback.register('MULTImedic:medicCount', function() return Medic.MedicCount() end)

-- ------------------------------------------------------------
-- medic revive / treat (two steps: start, then finish after the animation)
-- ------------------------------------------------------------
--- Checks a medic action. kind = 'revive' (target must be down) or 'treat' (target must be up).
function Medic.CheckAction(src, target, kind)
    target = tonumber(target)
    local P, T = getP(src), getP(target)
    if not P then return false end
    if not T or target == src then return false, 'no_player' end
    if not Medic.IsMedic(P) then return false, 'not_medic' end
    if Medic.IsDead(src) then return false, 'no_player' end
    local dead = T.PlayerData.metadata.isdead == true
    if kind == 'revive' and not dead then return false, 'not_down' end
    if kind == 'treat' and dead then return false, 'is_down' end
    if not near(src, target, Config.Revive.MaxDistance) then return false, 'too_far' end
    local need = kind == 'revive' and Config.Revive or Config.Treat
    if need.RequireItem and Medic.ItemCount(src, need.Item) < 1 then return false, 'need_item' end
    return true, nil, P, T
end

lib.callback.register('MULTImedic:startAction', function(src, target, kind)
    if kind ~= 'revive' and kind ~= 'treat' then return false end
    local ok, err = Medic.CheckAction(src, target, kind)
    if not ok then
        if err then notify(src, Medic.ErrText(err, kind), 'error') end
        return false
    end
    pending[src] = { target = tonumber(target), kind = kind, t = GetGameTimer() }
    return true
end)

--- Revive (medic) after the checks. Used by the finish event and by rsg-medic:server:RevivePlayer.
function Medic.MedicRevive(src, target)
    local ok, err, P, T = Medic.CheckAction(src, target, 'revive')
    if not ok then
        if err then notify(src, Medic.ErrText(err, 'revive'), 'error') end
        return false
    end
    if Config.Revive.RequireItem and not Medic.TakeItem(src, Config.Revive.Item) then
        notify(src, _L('need_item', Medic.ItemLabel(Config.Revive.Item)), 'error')
        return false
    end
    Medic.Revive(tonumber(target), Config.Revive.HealthPercent)
    notify(src, _L('you_revived', fullName(T)), 'success')
    notify(tonumber(target), _L('revived_by', fullName(P)), 'medic')
    TriggerEvent('MULTImedic:server:onMedicRevive', src, tonumber(target))
    dbg('medic', src, 'revived', target)
    return true
end

function Medic.MedicTreat(src, target)
    local ok, err, P, T = Medic.CheckAction(src, target, 'treat')
    if not ok then
        if err then notify(src, Medic.ErrText(err, 'treat'), 'error') end
        return false
    end
    if Config.Treat.RequireItem and not Medic.TakeItem(src, Config.Treat.Item) then
        notify(src, _L('need_item', Medic.ItemLabel(Config.Treat.Item)), 'error')
        return false
    end
    target = tonumber(target)
    TriggerClientEvent('MULTImedic:client:treated', target, Config.Treat.HealthPercent)
    Medic.ImproveWorst(target)
    notify(src, _L('you_treated', fullName(T)), 'success')
    notify(target, _L('treated_by', fullName(P)), 'medic')
    dbg('medic', src, 'treated', target)
    return true
end

RegisterNetEvent('MULTImedic:server:finishAction', function(target)
    local src = source
    local p = pending[src]
    pending[src] = nil
    if not p or p.target ~= tonumber(target) then return end
    local need = (p.kind == 'revive' and Config.Revive.Time or Config.Treat.Time) * Config.Revive.MinTimeFactor
    if GetGameTimer() - p.t < need then
        dbg('action finished too fast, refused', src, p.kind)
        return
    end
    if p.kind == 'revive' then Medic.MedicRevive(src, target) else Medic.MedicTreat(src, target) end
end)

RegisterNetEvent('MULTImedic:server:cancelAction', function() pending[source] = nil end)

-- ------------------------------------------------------------
-- simple injuries (metadata 'injuries', same shape as rsg-medic)
-- ------------------------------------------------------------
local ORDER = { healthy = 0, injured = 1, broken = 2, bleeding = 3 }
local NEXT_WORSE = { healthy = 'injured', injured = 'broken', broken = 'bleeding' }
local NEXT_BETTER = { bleeding = 'broken', broken = 'injured', injured = 'healthy' }
local VALID_PART = {}
for _, part in ipairs(Config.Injuries.Parts) do VALID_PART[part] = true end

local function healthyTable()
    local t = {}
    for _, part in ipairs(Config.Injuries.Parts) do t[part] = 'healthy' end
    return t
end

function Medic.GetInjuries(src)
    local P = getP(src)
    if not P then return nil end
    local inj = P.PlayerData.metadata.injuries
    if type(inj) ~= 'table' then inj = healthyTable() end
    return inj, P
end

function Medic.SetInjuries(src, inj)
    local P = getP(src)
    if not P then return end
    P.Functions.SetMetaData('injuries', inj)
    -- same client event rsg-medic sends (the patient's own client and rsg scripts listen to it)
    TriggerClientEvent('rsg-medic:client:updateInjuries', src, src, inj, fullName(P))
end

function Medic.ResetInjuries(src)
    local P = getP(src)
    if not P then return end
    local inj = P.PlayerData.metadata.injuries
    if type(inj) ~= 'table' then return end -- nothing stored, nothing to reset
    Medic.SetInjuries(src, healthyTable())
end

function Medic.RecordHit(src, part)
    if not Config.Injuries.Enabled or not VALID_PART[part] then return end
    local now = os.time()
    if lastHit[src] and now - lastHit[src] < Config.Injuries.HitCooldown then return end
    lastHit[src] = now
    local inj = Medic.GetInjuries(src)
    if not inj then return end
    local cur = inj[part] or 'healthy'
    local nxt = NEXT_WORSE[cur]
    if not nxt or math.random() >= (Config.Injuries.Chance[nxt] or 0) then return end
    inj[part] = nxt
    Medic.SetInjuries(src, inj)
    notify(src, _L('injury_worse', _L('part_' .. part), _L('state_' .. nxt)), 'warning')
end

function Medic.ApplyDeathInjuries(src)
    if not Config.Injuries.Enabled or deathInjured[src] then return end
    deathInjured[src] = true
    local inj = healthyTable()
    for _, part in ipairs(Config.Injuries.Parts) do
        local r = math.random()
        if r < 0.1 then inj[part] = 'bleeding'
        elseif r < 0.3 then inj[part] = 'broken'
        elseif r < 0.6 then inj[part] = 'injured' end
    end
    Medic.SetInjuries(src, inj)
end

--- Makes the worst injured part one step better. Returns true if something changed.
function Medic.ImproveWorst(src)
    local inj = Medic.GetInjuries(src)
    if not inj then return false end
    local worst, worstLvl = nil, 0
    for _, part in ipairs(Config.Injuries.Parts) do
        local lvl = ORDER[inj[part] or 'healthy'] or 0
        if lvl > worstLvl then worst, worstLvl = part, lvl end
    end
    if not worst then return false end
    inj[worst] = NEXT_BETTER[inj[worst]] or 'healthy'
    Medic.SetInjuries(src, inj)
    return true
end

RegisterNetEvent('MULTImedic:server:bodyHit', function(part)
    Medic.RecordHit(source, part)
end)

-- ------------------------------------------------------------
-- admin commands (rsg-medic registered these)
-- ------------------------------------------------------------
local function cmdTarget(src, arg)
    local t = tonumber(arg) or src
    if not t or t == 0 or not getP(t) then
        if src ~= 0 then notify(src, _L('no_player'), 'error') else print('[MULTImedic] ' .. _L('no_player')) end
        return nil
    end
    return t
end

CreateThread(function()
    local C = Config.Commands
    if C.Revive and C.Revive ~= '' then
        RSGCore.Commands.Add(C.Revive, _L('cmd_revive'), { { name = 'id', help = _L('cmd_id') } }, false, function(src, args)
            local t = cmdTarget(src, args[1])
            if t then Medic.Revive(t, 100) end
        end, C.Permission)
    end
    if C.Heal and C.Heal ~= '' then
        RSGCore.Commands.Add(C.Heal, _L('cmd_heal'), { { name = 'id', help = _L('cmd_id') } }, false, function(src, args)
            local t = cmdTarget(src, args[1])
            if t then Medic.Heal(t) end
        end, C.Permission)
    end
    if C.Kill and C.Kill ~= '' then
        RSGCore.Commands.Add(C.Kill, _L('cmd_kill'), { { name = 'id', help = _L('cmd_id') } }, true, function(src, args)
            local t = cmdTarget(src, args[1])
            if t then TriggerClientEvent('MULTImedic:client:kill', t) end
        end, C.Permission)
    end
end)

-- ------------------------------------------------------------
-- exports
-- ------------------------------------------------------------
exports('IsDead', function(src) return Medic.IsDead(src) end)
exports('Revive', function(src, healthPct) return Medic.Revive(src, healthPct) end)
exports('Heal', function(src) return Medic.Heal(src) end)
exports('Kill', function(src) if getP(src) then TriggerClientEvent('MULTImedic:client:kill', tonumber(src)) return true end return false end)
exports('IsMedic', function(src) return Medic.IsMedic(getP(src)) end)
exports('GetMedicCount', function() return Medic.MedicCount() end)
exports('AlertMedics', function(coords, text) return Medic.Alert(coords, tostring(text or '')) end)
exports('GetInjuries', function(src) return (Medic.GetInjuries(src)) end)
exports('ResetInjuries', function(src) Medic.ResetInjuries(src) end)

AddEventHandler('playerDropped', function()
    local src = source
    deathAt[src], deathDone[src], deathInjured[src], lastCall[src], pending[src], lastHit[src], respawning[src] = nil, nil, nil, nil, nil, nil, nil
    extraTime[src] = nil
end)

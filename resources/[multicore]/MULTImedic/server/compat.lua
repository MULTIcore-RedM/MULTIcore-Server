-- ============================================================
-- MULTImedic :: rsg-medic server compatibility
-- Event names and argument shapes follow how the RSG v2 framework
-- (GPL v3) and its scripts call rsg-medic; no code was copied.
-- Every event runs the same server checks as MULTImedic's own.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local dbg, notify, getP = Medic.dbg, Medic.notify, Medic.getP

local function ignored(name, ...)
    dbg(('ignored rsg-medic event %s from %s'):format(name, tostring(source)), ...)
end

-- revive a downed player (medic job, distance, target must be down). Arg: target server id
RegisterNetEvent('rsg-medic:server:RevivePlayer', function(playerId)
    Medic.MedicRevive(source, playerId)
end)

-- treat wounds of a standing player (medic job, distance). Arg: target server id
RegisterNetEvent('rsg-medic:server:TreatWounds', function(playerId)
    Medic.MedicTreat(source, playerId)
end)

-- bandage on oneself: improve the worst injury one step. No args.
RegisterNetEvent('rsg-medic:server:healSelfInjury', function()
    local src = source
    if not Config.Injuries.Enabled or Medic.IsDead(src) then return end
    if Medic.ImproveWorst(src) then
        notify(src, _L('injury_better'), 'success')
    else
        notify(src, _L('no_injuries'), 'info')
    end
end)

-- rsg-medic's client sends this after a revive / respawn. Only a living player may clear their own injuries.
RegisterNetEvent('rsg-medic:server:resetPlayerInjuries', function()
    local src = source
    if Medic.IsDead(src) then return end
    Medic.ResetInjuries(src)
end)

-- alert all medics with a text at the sender's position (rsg-radialmenu emergency button). Arg: text
RegisterNetEvent('rsg-medic:server:medicAlert', function(text)
    local src = source
    if not getP(src) then return end
    if not Medic.CallAllowed(src) then
        notify(src, _L('call_cooldown'), 'error')
        return
    end
    local pos = Medic.pedCoords(src)
    if not pos then return end
    text = tostring(text or ''):gsub('[<>]', ''):sub(1, Config.Call.MaxTextLength)
    if text == '' then text = _L('alert_text', Medic.fullName(getP(src))) end
    Medic.Alert(pos, text, src)
end)

-- the respawn wipe (fee / lose cash). Runs at most once per death; MULTImedic's own respawn already runs it.
RegisterNetEvent('rsg-medic:server:deathactions', function()
    local src = source
    if not Medic.IsDead(src) then return ignored('deathactions (not dead)') end
    Medic.DeathActions(src)
end)

-- random injuries on death (once per death, only while down)
RegisterNetEvent('rsg-medic:server:applyDeathInjuries', function()
    local src = source
    if not Medic.IsDead(src) then return end
    Medic.ApplyDeathInjuries(src)
end)

-- a body part was hit. Arg: part name ('head', 'left_leg' ...)
RegisterNetEvent('rsg-medic:server:recordBodyHit', function(bodyPart)
    Medic.RecordHit(source, bodyPart)
end)

-- accepted and ignored: no skeleton screen, no shop, no stash, no item removal yet
RegisterNetEvent('rsg-medic:server:watchSkeleton', function(targetSrc) ignored('watchSkeleton', targetSrc) end)
RegisterNetEvent('rsg-medic:server:unwatchSkeleton', function() ignored('unwatchSkeleton') end)
RegisterNetEvent('rsg-medic:server:openSkeletonAdmin', function(targetSrc) ignored('openSkeletonAdmin', targetSrc) end)
-- medic supplies are sold by MULTIstores (doctor stores); storage is a job stash
RegisterNetEvent('rsg-medic:server:buyMedicItem', function(itemName) ignored('buyMedicItem', itemName) end)
RegisterNetEvent('rsg-medic:server:openstash', function(location) ignored('openstash', location) end)
-- rsg-medic's own bandage flow removed items with this; never trusted from a client here (MULTImedic takes items itself)
RegisterNetEvent('rsg-medic:server:removeitem', function(item, amount) ignored('removeitem', item, amount) end)

-- a client (rsg-adminmenu self revive, other scripts' TriggerClientEvent) asked to be revived / healed.
-- kind: 'adminRevive' | 'playerRevive' | 'adminHeal'
RegisterNetEvent('MULTImedic:server:compatRevive', function(kind)
    local src = source
    if not getP(src) then return end
    if not Config.Compat.TrustClientRevive and not Medic.IsAdmin(src) then
        return dbg('refused client revive event', kind, 'from', src)
    end
    if kind == 'adminHeal' then
        Medic.Heal(src)
    elseif kind == 'playerRevive' then
        Medic.Revive(src, Config.Revive.HealthPercent)
    elseif kind == 'adminRevive' then
        Medic.Revive(src, 100)
    end
    dbg('client revive event', kind, 'for', src)
end)

-- exports['rsg-medic']:IsDead(src) for scripts that look for it under the old name
AddEventHandler('__cfx_export_rsg-medic_IsDead', function(setCB) setCB(function(src) return Medic.IsDead(src) end) end)

-- callbacks rsg-medic offered
RSGCore.Functions.CreateCallback('rsg-medic:server:getmedics', function(_, cb)
    cb(Medic.MedicCount())
end)

RSGCore.Functions.CreateCallback('rsg-medic:server:getPlayerInjuries', function(src, cb, targetSrc)
    local P = getP(src)
    targetSrc = tonumber(targetSrc) or src
    -- own injuries, or a medic's patient
    if not P or (targetSrc ~= src and not Medic.IsMedic(P)) then return cb(nil) end
    local inj, T = Medic.GetInjuries(targetSrc)
    if not inj then return cb(nil) end
    cb(inj, Medic.fullName(T))
end)

-- ------------------------------------------------------------
-- redemrp_respawn (RedEM:RP) - written from its public API, no RedEM:RP code
-- ------------------------------------------------------------

-- TriggerEvent('redemrp_respawn:IsPlayerDead', src, function(isDead) end)
AddEventHandler('redemrp_respawn:IsPlayerDead', function(src, cb)
    if cb then cb(Medic.IsDead(tonumber(src)) == true) end
end)

-- server only: TriggerEvent('redemrp_respawn:server:RequestRevivePlayer', id)
AddEventHandler('redemrp_respawn:server:RequestRevivePlayer', function(id)
    id = tonumber(id)
    if id and getP(id) then Medic.Revive(id, Config.Revive.HealthPercent) end
end)

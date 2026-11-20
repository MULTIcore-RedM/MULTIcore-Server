-- ============================================================
-- MULTIcore :: VORP face - events and state
-- Whatever logs a character in (an RSG or a VORP creator), RSG's
-- PlayerLoaded fires inside the core. This file turns that and the other
-- core events into the VORP events and state bags VORP scripts expect.
-- ============================================================

MULTI.Vorp = MULTI.Vorp or {}
local V = MULTI.Vorp

local lastJob = {}   -- source -> { name, grade } as last seen, to tell what changed

local function setState(src, P)
    local d = P.PlayerData
    local state = Player(src).state
    local job = d.job or {}
    local ci = d.charinfo or {}
    state:set('IsInSession', true, true)
    state:set('Character', {
        CharId = d.id,
        FirstName = ci.firstname,
        LastName = ci.lastname,
        Job = job.name,
        JobLabel = job.label,
        Grade = job.grade and job.grade.level or 0,
        Group = d.metadata.vorp and d.metadata.vorp.group or 'user',
        Money = d.money.cash,
        Gold = d.money.gold,
        Rol = d.money.rol,
        Age = d.metadata.vorp and d.metadata.vorp.age,
        Gender = (ci.gender == 1 or ci.gender == '1') and 'female' or 'male',
        NickName = d.metadata.vorp and d.metadata.vorp.nickname,
        CharDescription = d.metadata.vorp and d.metadata.vorp.description,
    }, true)
end
V.SetState = setState

AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
    local src = P.PlayerData.source
    if not src then return end
    lastJob[src] = { name = P.PlayerData.job.name, grade = P.PlayerData.job.grade.level }
    pcall(setState, src, P)
    TriggerEvent('vorp:SelectedCharacter', src, V.CharacterFields(P))
    TriggerClientEvent('vorp:SelectedCharacter', src, P.PlayerData.id)
end)

AddEventHandler('RSGCore:Server:OnJobUpdate', function(src, job)
    local before = lastJob[src] or {}
    local now = { name = job.name, grade = job.grade and job.grade.level or 0 }
    lastJob[src] = now
    local P = RSGCore.Players[src]
    if P then pcall(setState, src, P) end
    if MULTI.Jobs.silent[src] then return end
    if before.name ~= now.name then
        TriggerEvent('vorp:playerJobChange', src, now.name, before.name)
    end
    if before.grade ~= now.grade then
        TriggerEvent('vorp:playerJobGradeChange', src, now.grade, before.grade)
    end
end)

AddEventHandler('RSGCore:Server:OnMoneyChange', function(src)
    local P = RSGCore.Players[src]
    if P then pcall(setState, src, P) end
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    lastJob[src] = nil
    pcall(function()
        local state = Player(src).state
        state:set('IsInSession', false, true)
        state:set('Character', nil, true)
    end)
end)

AddEventHandler('playerDropped', function()
    lastJob[source] = nil
end)

-- A client reports its own death (client/vorp/core.lua); VORP server scripts listen for
-- vorp_core:Server:OnPlayerDeath (source, killerServerId, causeOfDeath). Once per 5 s per player.
local lastDeath = {}
RegisterNetEvent('MULTIcore:vorp:died', function(killerId, cause)
    local src = source
    if not RSGCore.Players[src] then return end
    local now = GetGameTimer()
    if lastDeath[src] and now - lastDeath[src] < 5000 then return end
    lastDeath[src] = now
    TriggerEvent('vorp_core:Server:OnPlayerDeath', src, tonumber(killerId) or 0, tonumber(cause) or 0)
end)
AddEventHandler('playerDropped', function() lastDeath[source] = nil end)

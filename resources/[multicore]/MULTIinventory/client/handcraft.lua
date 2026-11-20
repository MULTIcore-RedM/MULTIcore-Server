-- ============================================================
-- MULTIinventory :: client/handcraft.lua
--
-- Craft tab (Config.HandCraft). The NUI lists recipes (server action handcraftList)
-- and asks for a craft (local callback handcraftStart). The server answers the start
-- with a token + duration; this file closes the inventory, plays the animation,
-- shows the progress bar and then asks the server to finish (or cancel).
--
-- Cancels on: moving away (cancelDistance), ragdoll, death, mounting / a vehicle,
-- swimming. Animations are checked first (DoesAnimDictExist + RequestAnimDict
-- with a timeout); a missing one means the craft simply runs without animation.
--
-- NUI messages: { action = 'craftProgress', data = { label, duration, qty } | { state = 'done'|'cancel' } }
-- ============================================================

local crafting = false

local function call(name, ...)
    local f = _G[name]
    if type(f) ~= 'function' then return nil end
    local ok, r = pcall(f, ...)
    if ok then return r end
    return nil
end

local function loadDict(dict, timeoutMs)
    if call('DoesAnimDictExist', dict) == false then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeoutMs or 1500)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(20)
    end
    return true
end

local function startAnim(ped, anim, timeoutMs)
    if type(anim) ~= 'table' then return nil end
    if anim.scenario then
        local ok = pcall(TaskStartScenarioInPlace, ped, joaat(anim.scenario), -1, true, false, false, false)
        if not ok then return nil end
        Wait(600)
        if call('IsPedUsingAnyScenario', ped) == false then return nil end
        return { scenario = true }
    end
    if type(anim.dict) ~= 'string' or type(anim.clip) ~= 'string' then return nil end
    if not loadDict(anim.dict, timeoutMs) then return nil end
    local ok = pcall(TaskPlayAnim, ped, anim.dict, anim.clip, 4.0, -4.0, -1, tonumber(anim.flag) or 31, 0.0, false, false, false)
    if not ok then RemoveAnimDict(anim.dict) return nil end
    return { dict = anim.dict, clip = anim.clip }
end

local function stopAnim(ped, h)
    if not h then return end
    if h.scenario then
        ClearPedTasks(ped)
    else
        pcall(StopAnimTask, ped, h.dict, h.clip, 1.0)
        RemoveAnimDict(h.dict)
    end
end

local function cancelReason(ped, start, maxDist)
    if IsEntityDead(ped) or call('IsPedDeadOrDying', ped, true) then return 'dead' end
    if call('IsPedRagdoll', ped) then return 'ragdoll' end
    if call('IsPedOnMount', ped) or call('IsPedInAnyVehicle', ped, false) then return 'mounted' end
    if call('IsPedSwimming', ped) then return 'swimming' end
    local p = GetEntityCoords(ped)
    if #(p - start) > maxDist then return 'moved' end
    return nil
end

-- attack / aim / melee off while the hands are busy
local BLOCK = { 'INPUT_ATTACK', 'INPUT_AIM', 'INPUT_MELEE_ATTACK', 'INPUT_OPEN_WHEEL_MENU' }
local BLOCK_HASH = {}
for i, n in ipairs(BLOCK) do BLOCK_HASH[i] = joaat(n) end

-- actions = { finish = 'sharpenFinish', cancel = 'sharpenCancel' } (default: the hand-craft ones)
local function run(job, actions)
    crafting = true
    local ped = PlayerPedId()
    local start = GetEntityCoords(ped)
    local handle = startAnim(ped, job.anim, job.animLoadTimeoutMs)
    SendNUIMessage({ action = 'craftProgress', data = { label = job.label, duration = job.duration, qty = job.qty } })
    local endAt = GetGameTimer() + job.duration
    local reason
    while GetGameTimer() < endAt do
        Wait(0)
        ped = PlayerPedId()
        for _, h in ipairs(BLOCK_HASH) do DisableControlAction(0, h, true) end
        reason = cancelReason(ped, start, job.cancelDistance or 0.8)
        if reason then break end
        -- keep the looped animation going if something interrupted it
        if handle and handle.dict and not IsEntityPlayingAnim(ped, handle.dict, handle.clip, 3) then
            pcall(TaskPlayAnim, ped, handle.dict, handle.clip, 4.0, -4.0, -1, tonumber(job.anim.flag) or 31, 0.0, false, false, false)
        end
    end
    stopAnim(PlayerPedId(), handle)
    local ok, res = false, reason
    if reason then
        SendNUIMessage({ action = 'craftProgress', data = { state = 'cancel' } })
        InvClient.request(actions and actions.cancel or 'handcraftCancel', { token = job.token })
        if reason ~= 'dead' then
            SendNUIMessage({ action = 'notify', data = { text = 'You stopped working.', type = 'error' } })
        end
    else
        SendNUIMessage({ action = 'craftProgress', data = { state = 'done' } })
        ok, res = InvClient.request(actions and actions.finish or 'handcraftFinish', { token = job.token })   -- the server notifies the result
    end
    crafting = false
    return ok, res
end

-- shared with client/workshop.lua (grinding wheel uses the same progress + animation handling)
-- never leave the player stuck "busy" if something inside the progress errors
local function safeRun(job, actions)
    local ok, a, b = pcall(run, job, actions)
    if not ok then
        crafting = false
        SendNUIMessage({ action = 'craftProgress', data = { state = 'cancel' } })
        print('^1[MULTIinventory] craft progress error: ' .. tostring(a) .. '^7')
        return false, 'error'
    end
    return a, b
end

HandCraftClient = {
    run = safeRun,
    isBusy = function() return crafting end,
}

RegisterNUICallback('handcraftList', function(d, cb)
    if not InvClient or not InvClient.nuiAction then cb({ ok = false, err = 'not_ready' }) return end
    InvClient.nuiAction('handcraftList', {}, cb)
end)

RegisterNUICallback('handcraftStart', function(d, cb)
    if type(d) ~= 'table' then d = {} end
    if crafting then cb({ ok = false, err = 'busy' }) return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or call('IsPedOnMount', ped) or call('IsPedInAnyVehicle', ped, false) or call('IsPedSwimming', ped) then
        cb({ ok = false, err = 'cannot_now' })
        return
    end
    local qty = tonumber(d.qty)
    if not qty or qty ~= qty or qty == math.huge or qty == -math.huge then qty = 1 end
    CreateThread(function()
        local fromBook = d.book == true
        local ok, res = InvClient.request('handcraftBegin', { id = tostring(d.id or ''), qty = math.floor(qty), book = fromBook })
        if not ok or type(res) ~= 'table' then cb({ ok = false, err = res }) return end
        cb({ ok = true, data = { duration = res.duration } })
        if InvClient.isOpen() then InvClient.close() end
        if fromBook and WorkshopClient then WorkshopClient.closeBook() end
        safeRun(res)
        -- back to the same chapter of the journal
        if fromBook and WorkshopClient and Config.CraftBook and Config.CraftBook.reopenAfterCraft ~= false then
            WorkshopClient.openBook(res.chapter)
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and crafting then ClearPedTasks(PlayerPedId()) end
end)

exports('IsHandCrafting', function() return crafting end)

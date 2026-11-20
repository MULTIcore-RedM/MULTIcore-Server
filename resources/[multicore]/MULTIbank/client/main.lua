-- ============================================================
-- MULTIbank :: client
-- Prompt or MULTItarget at each counter, blips, clerk, doors and
-- the passbook NUI. The client never changes money: it only asks
-- the server (lib.callback) and shows the answer.
-- GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local isOpen = false
local openIdx = nil   -- bank index of the open passbook
local blips = {}
local clerks = {}
local zones = {}
local interactMode = nil  -- 'target' or 'prompt' once MCI.Run has decided

local function notify(msg, kind)
    exports.MULTIcore:Notify({ text = msg, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end

local function bankIsOpen()
    if not Config.Hours.Enabled then return true end
    local h = GetClockHours()
    local o, c = Config.Hours.Open, Config.Hours.Close
    if o < c then return h >= o and h < c end
    return h >= o or h < c -- hours that run past midnight
end

local function nearestBank()
    local pos = GetEntityCoords(cache.ped)
    local best, bestDist
    for i, b in ipairs(Config.Banks) do
        local d = #(pos - b.coords)
        if d <= Config.MaxUseDistance and (not bestDist or d < bestDist) then best, bestDist = i, d end
    end
    return best
end

---------------------------------
-- passbook
---------------------------------
local function closeBank()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    lib.callback('MULTIbank:close', false, function() end)
end

local function openBank(idx)
    if isOpen or not idx or not Config.Banks[idx] then return end
    if not bankIsOpen() then
        notify(_L('closed', Config.Hours.Open, Config.Hours.Close), 'error')
        return
    end
    local ok, state = lib.callback.await('MULTIbank:open', false, idx)
    if not ok then
        if state then notify(state, 'error') end
        return
    end
    isOpen = true
    openIdx = idx
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state, L = _LT(), lang = _LCode(), quick = Config.QuickAmounts })
end

---------------------------------
-- safe-deposit box menu (ox_lib); the server decides everything
---------------------------------
local function money(n) return ('$%.2f'):format(tonumber(n) or 0) end
local function kg(g) return ('%.1f'):format((tonumber(g) or 0) / 1000) end

local function sdCall(action, idx, arg)
    local res = lib.callback.await('MULTIbank:sd', false, action, idx, arg)
    if type(res) ~= 'table' then res = { ok = false, msg = _L('failed') } end
    if res.msg then notify(res.msg, res.ok and 'success' or 'error') end
    return res
end

local function confirm(text)
    return lib.alertDialog({ header = _L('sd_title'), content = text, centered = true, cancel = true,
        labels = { confirm = _L('sd_yes'), cancel = _L('sd_no') } }) == 'confirm'
end

local function safeDepositMenu(idx)
    local info = lib.callback.await('MULTIbank:sd', false, 'info', idx)
    if type(info) ~= 'table' or not info.ok then
        notify(type(info) == 'table' and info.msg or _L('failed'), 'error')
        return
    end
    local options = {}
    local payFrom = _L(info.payWith == 'cash' and 'ui_pay_cash' or 'ui_pay_bank')
    if info.box then
        local b = info.box
        options[#options + 1] = {
            title = _L('sd_open'),
            description = _L('sd_box_desc', b.label, b.slots, kg(b.weight)),
            icon = 'box-open',
            disabled = b.overdue,
            onSelect = function() sdCall('open', idx) end,
        }
        if info.billing == 'monthly' then
            local desc = b.overdue and _L('sd_owed', money(b.owed)) or _L('sd_days_left', math.max(0, b.daysLeft or 0))
            options[#options + 1] = {
                title = b.overdue and _L('sd_pay_owed', money(b.owed)) or _L('sd_pay_ahead', money(b.fee)),
                description = desc .. ' ' .. _L('sd_paid_from', payFrom),
                icon = 'money-bill',
                disabled = not b.overdue and not b.canPrepay,
                onSelect = function() sdCall('pay', idx) safeDepositMenu(idx) end,
            }
        end
        options[#options + 1] = {
            title = _L('sd_giveup'),
            description = _L('sd_giveup_desc'),
            icon = 'xmark',
            onSelect = function()
                if confirm(_L('sd_giveup_ask')) then sdCall('giveup', idx) end
            end,
        }
    else
        for _, t in ipairs(info.tiers) do
            local price = info.billing == 'monthly' and _L('sd_price_monthly', money(t.fee), info.periodDays) or _L('sd_price_once', money(t.price))
            options[#options + 1] = {
                title = _L('sd_rent', t.label),
                description = _L('sd_tier_desc', t.slots, kg(t.weight), price),
                icon = 'box',
                onSelect = function()
                    if not confirm(_L('sd_rent_ask', t.label, price, payFrom)) then return end
                    local res = sdCall('rent', idx, t.id)
                    if res.ok then sdCall('open', idx) end
                end,
            }
        end
    end
    lib.registerContext({ id = 'multibank_safedeposit', title = _L('sd_title_at', info.bank), options = options })
    lib.showContext('multibank_safedeposit')
end

-- rsg-banking's safe-deposit event sends the player here when there is no box yet or rent is due
RegisterNetEvent('MULTIbank:client:safedeposit', function(idx)
    idx = tonumber(idx)
    if idx and Config.Banks[idx] then safeDepositMenu(idx) end
end)

RegisterNUICallback('safedeposit', function(_, cb)
    cb({})
    local idx = openIdx
    closeBank()
    if idx then safeDepositMenu(idx) end
end)

RegisterNetEvent('MULTIbank:client:open', function(idx)
    openBank(tonumber(idx))
end)

-- rsg-banking's open event (args: moneytype). Opens the bank the player stands at.
AddEventHandler('rsg-banking:client:OpenBanking', function()
    openBank(nearestBank())
end)

RegisterNUICallback('close', function(_, cb)
    closeBank()
    cb({})
end)

RegisterNUICallback('action', function(data, cb)
    if not isOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    local res = lib.callback.await('MULTIbank:action', false, data.action, data.data or {})
    if type(res) ~= 'table' then res = { ok = false, msg = _L('failed') } end
    cb(res)
    if res.close then
        if res.msg then notify(res.msg, 'error') end
        closeBank()
    end
end)

-- walking away closes the passbook
CreateThread(function()
    while true do
        Wait(Config.CheckIntervalMs)
        if isOpen and not nearestBank() then closeBank() end
    end
end)

---------------------------------
-- prompt / target, blips, doors
---------------------------------
local function setupDoors()
    if not Config.Doors.Enabled then return end
    -- MULTIdoors locks every door in the game (bank doors among them, with keys and law
    -- access), so when it runs the bank leaves its doors to it instead of forcing a state.
    local doors = GetResourceState(Config.Doors.DoorScript or 'MULTIdoors')
    if doors == 'started' or doors == 'starting' then return end
    for _, d in ipairs(Config.Doors.List) do
        if not IsDoorRegisteredWithSystem(d.door) then
            AddDoorToSystemNew(d.door, 1, 1, 0, 0, 0, 0)
        end
        DoorSystemSetDoorState(d.door, d.state)
    end
end

-- the "Open bank" option for one bank (counter zone and clerk use the same one)
local function bankOption(i, b)
    return {
        name = 'multibank_' .. b.id,
        label = _L('prompt_open'),
        icon = Config.TargetIcon,
        distance = Config.TargetDistance,
        onSelect = function() openBank(i) end,
    }
end

-- MULTItarget (Config.Interact 'auto' / 'target') or hold-key prompts, see @MULTIcore/lib/interact.lua
MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    for i, b in ipairs(Config.Banks) do
        if mode == 'target' then
            zones[#zones + 1] = MCI.AddZone({ coords = b.coords, radius = Config.TargetRadius, options = { bankOption(i, b) } })
            if clerks[i] then MCI.AddEntity(clerks[i], { bankOption(i, b) }) end
        else
            MCI.AddPrompt('multibank_' .. b.id, b.coords, Config.PromptKey, _L('prompt_open'),
                { type = 'client', event = 'MULTIbank:client:open', args = { i } }, Config.PromptDistance)
        end
    end
end, function(mode)
    for _, id in ipairs(zones) do MCI.RemoveZone(id) end
    zones = {}
    for _, ped in pairs(clerks) do MCI.RemoveEntity(ped) end
    for _, b in ipairs(Config.Banks) do MCI.RemovePrompt('multibank_' .. b.id) end
    interactMode = nil
end)

CreateThread(function()
    for _, b in ipairs(Config.Banks) do
        if Config.Blips.Enabled and b.blip then
            local blip = BlipAddForCoords(Config.Blips.Style, b.coords.x, b.coords.y, b.coords.z)
            SetBlipSprite(blip, joaat(Config.Blips.Sprite), true)
            SetBlipScale(blip, Config.Blips.Scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, _L(b.label)) -- _SET_BLIP_NAME
            blips[#blips + 1] = blip
        end
    end
    setupDoors()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', setupDoors)

---------------------------------
-- clerks
---------------------------------
local function spawnClerk(b)
    local model = joaat(Config.Npc.Model)
    RequestModel(model, false)
    local deadline = GetGameTimer() + Config.Npc.LoadTimeoutMs
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(0)
    end
    if not HasModelLoaded(model) then return nil end
    local ped = CreatePed(model, b.npc.x, b.npc.y, b.npc.z + Config.Npc.ZOffset, b.npc.w, false, false, false, false)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)
    return ped
end

CreateThread(function()
    if not Config.Npc.Enabled then return end
    while true do
        Wait(Config.CheckIntervalMs)
        local pos = GetEntityCoords(cache.ped)
        for i, b in ipairs(Config.Banks) do
            local near = #(pos - b.npc.xyz) < Config.Npc.SpawnDistance
            if near and not clerks[i] then
                clerks[i] = spawnClerk(b)
                if clerks[i] and interactMode == 'target' then MCI.AddEntity(clerks[i], { bankOption(i, b) }) end
            elseif not near and clerks[i] then
                MCI.RemoveEntity(clerks[i])
                if DoesEntityExist(clerks[i]) then DeletePed(clerks[i]) end
                clerks[i] = nil
            end
        end
    end
end)

-- for /mcinteract
MCI.Counter('npcs', function()
    local n = 0
    for _ in pairs(clerks) do n = n + 1 end
    return n
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    for _, ped in pairs(clerks) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
    for _, b in ipairs(Config.Banks) do MCI.RemovePrompt('multibank_' .. b.id) end
    -- MULTItarget drops this script's zones and entity options by itself when it stops
end)

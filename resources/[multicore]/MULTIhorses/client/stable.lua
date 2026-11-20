-- ============================================================
-- MULTIhorses :: stables (client)
-- Stable hands, blips, the prompt or MULTItarget at each stable, and the
-- stable menus (ox_lib). The client never changes money or horses: it
-- asks the server (lib.callback 'MULTIhorses:action') and shows the menus.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local blips, hands, zones = {}, {}, {}

-- natives (femga natives.json)
local SET_BLIP_NAME = 0x9CB1A1623062F402                -- _SET_BLIP_NAME
local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE  -- _SET_RANDOM_OUTFIT_VARIATION
local TASK_START_SCENARIO_IN_PLACE_HASH = 0x524B54361229154F

local function notify(text, kind)
    exports.MULTIcore:Notify({ text = text, title = _L('title'), type = kind or 'info' })
end

--- Sends one stable action to the server. → ok, result
local function act(action, args)
    return lib.callback.await('MULTIhorses:action', false, action, args)
end
MHClient = MHClient or {}
MHClient.act = act

-- ---------------------------------------------------------------
-- menus
-- ---------------------------------------------------------------
local openStable -- forward

local function horseWhere(h, stableId)
    if h.out then return _L('status_out') end
    if h.active then return _L('status_active') end
    if h.stable == stableId then return _L('status_here') end
    return _L('status_at', MH.StableLabel(h.stable))
end

local function buyMenu(stableId, data)
    local options = {}
    for _, def in ipairs(Config.Horses) do
        if MH.SoldAt(def, stableId) then
            options[#options + 1] = {
                title = MH.HorseLabel(def.model),
                description = MH.Money(def.price),
                icon = 'horse',
                onSelect = function()
                    local fields = {
                        { type = 'input', label = _L('input_name'), required = true, min = Config.NameMinLength, max = Config.NameMaxLength },
                    }
                    if Config.Genders then
                        fields[2] = { type = 'select', label = _L('input_gender'), required = true, default = 'male',
                            options = { { value = 'male', label = _L('stallion') }, { value = 'female', label = _L('mare') } } }
                    end
                    local input = lib.inputDialog(_L('buy_title', MH.HorseLabel(def.model), MH.Money(def.price)), fields)
                    if not input or not input[1] then return lib.showContext('multihorses_buy') end
                    act('buy', { stable = stableId, model = def.model, name = input[1], gender = input[2] })
                    openStable(stableId)
                end,
            }
        end
    end
    lib.registerContext({ id = 'multihorses_buy', title = _L('menu_buy'), menu = 'multihorses_main', options = options })
    lib.showContext('multihorses_buy')
end

local function tackMenu(stableId, h)
    local options = {}
    for _, cat in ipairs(Config.Tack.Categories) do
        local items = {}
        local current = h.tack and h.tack[cat.key]
        for i, it in ipairs(cat.items) do
            items[#items + 1] = {
                title = _L(it.label),
                description = current == it.hash and _L('tack_current') or MH.Money(it.price),
                icon = current == it.hash and 'check' or nil,
                disabled = current == it.hash,
                onSelect = function()
                    act('tack', { stable = stableId, id = h.id, category = cat.key, index = i })
                    openStable(stableId)
                end,
            }
        end
        items[#items + 1] = {
            title = _L('tack_take_off'), icon = 'xmark', disabled = current == nil,
            onSelect = function()
                act('tack', { stable = stableId, id = h.id, category = cat.key, index = 0 })
                openStable(stableId)
            end,
        }
        lib.registerContext({ id = 'multihorses_tack_' .. cat.key, title = _L(cat.label), menu = 'multihorses_tack', options = items })
        options[#options + 1] = { title = _L(cat.label), icon = 'chevron-right', menu = 'multihorses_tack_' .. cat.key }
    end
    lib.registerContext({ id = 'multihorses_tack', title = _L('menu_tack', h.name), menu = 'multihorses_horse', options = options })
    lib.showContext('multihorses_tack')
end

local function horseMenu(stableId, h)
    local options = {}
    local here = h.stable == stableId or not Config.Transfer.Enabled
    if not h.active then
        options[#options + 1] = {
            title = _L('menu_set_active'), icon = 'star',
            description = (not here) and _L('status_at', MH.StableLabel(h.stable)) or (h.injured and _L('status_injured') or nil),
            disabled = not here or h.injured,
            onSelect = function() act('active', { stable = stableId, id = h.id }) openStable(stableId) end,
        }
    end
    if Config.Transfer.Enabled and h.stable ~= stableId and not h.active then
        local fee = MH.TransferFee(h.stable, stableId)
        options[#options + 1] = {
            title = _L('menu_transfer'), icon = 'route', description = _L('fee', MH.Money(fee)),
            onSelect = function() act('transfer', { stable = stableId, id = h.id }) openStable(stableId) end,
        }
    end
    if h.injured then
        options[#options + 1] = {
            title = _L('menu_vet'), icon = 'kit-medical', description = _L('fee', MH.Money(Config.Revive.StableFee)),
            disabled = h.out,
            onSelect = function() act('vet', { stable = stableId, id = h.id }) openStable(stableId) end,
        }
    end
    if Config.Tack.Enabled then
        options[#options + 1] = { title = _L('menu_tack_open'), icon = 'chevron-right', onSelect = function() tackMenu(stableId, h) end }
    end
    options[#options + 1] = {
        title = _L('menu_rename'), icon = 'pen',
        onSelect = function()
            local input = lib.inputDialog(_L('menu_rename'), {
                { type = 'input', label = _L('input_name'), required = true, default = h.name, min = Config.NameMinLength, max = Config.NameMaxLength },
            })
            if input and input[1] then act('rename', { stable = stableId, id = h.id, name = input[1] }) end
            openStable(stableId)
        end,
    }
    local pay = MH.SellPrice(h.model)
    options[#options + 1] = {
        title = _L('menu_sell'), icon = 'coins', description = MH.Money(pay),
        onSelect = function()
            local answer = lib.alertDialog({ header = _L('menu_sell'), content = _L('sell_confirm', h.name, MH.Money(pay)), centered = true, cancel = true })
            if answer == 'confirm' then act('sell', { stable = stableId, id = h.id }) end
            openStable(stableId)
        end,
    }
    lib.registerContext({ id = 'multihorses_horse', title = h.name, menu = 'multihorses_mine', options = options })
    lib.showContext('multihorses_horse')
end

local function mineMenu(stableId, data)
    local options = {}
    for _, h in ipairs(data.horses) do
        local status = horseWhere(h, stableId)
        if h.injured then status = status .. ' - ' .. _L('status_injured') end
        options[#options + 1] = {
            title = h.name,
            description = MH.HorseLabel(h.model) .. ' - ' .. status,
            icon = h.active and 'star' or 'horse',
            onSelect = function() horseMenu(stableId, h) end,
        }
    end
    if #options == 0 then options[1] = { title = _L('no_horses'), disabled = true } end
    lib.registerContext({ id = 'multihorses_mine', title = _L('menu_mine'), menu = 'multihorses_main', options = options })
    lib.showContext('multihorses_mine')
end

openStable = function(stableId)
    local data = lib.callback.await('MULTIhorses:stableData', false, stableId)
    if not data then return end
    local active
    for _, h in ipairs(data.horses) do if h.active then active = h end end
    local options = {
        {
            title = _L('menu_buy'), icon = 'cart-shopping',
            description = _L('owned_of', #data.horses, data.max),
            disabled = #data.horses >= data.max,
            onSelect = function() buyMenu(stableId, data) end,
        },
        { title = _L('menu_mine'), icon = 'horse', onSelect = function() mineMenu(stableId, data) end },
    }
    if active then
        options[#options + 1] = {
            title = _L('menu_store', active.name), icon = 'warehouse',
            onSelect = function() act('store', { stable = stableId }) openStable(stableId) end,
        }
    end
    lib.registerContext({ id = 'multihorses_main', title = _L('stable_title', MH.StableLabel(stableId)), options = options })
    lib.showContext('multihorses_main')
end

-- local event the stable prompt fires (MULTIcore createPrompt, type 'client', args = { stableId })
AddEventHandler('MULTIhorses:client:openStable', function(stableId)
    if MH.Stables[stableId] then openStable(stableId) end
end)

-- ---------------------------------------------------------------
-- prompts / targets (MCI.Run, @MULTIcore/lib/interact.lua) and blips
-- ---------------------------------------------------------------
local interactMode = nil  -- 'target' or 'prompt' once MCI.Run has decided

-- the "open stable" option, on the stable zone and on the stable hand
local function stableOption(s)
    return {
        name = 'multihorses_' .. s.id,
        label = _L('prompt_open', MH.StableLabel(s.id)),
        icon = Config.TargetIcon,
        distance = Config.TargetDistance,
        onSelect = function() openStable(s.id) end,
    }
end

MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    for _, s in ipairs(Config.Stables) do
        if mode == 'target' then
            zones[#zones + 1] = MCI.AddZone({ coords = s.coords, radius = Config.TargetRadius, options = { stableOption(s) } })
            if hands[s.id] then MCI.AddEntity(hands[s.id], { stableOption(s) }) end
        else
            MCI.AddPrompt('multihorses_' .. s.id, s.coords, Config.PromptKey, _L('prompt_open', MH.StableLabel(s.id)),
                { type = 'client', event = 'MULTIhorses:client:openStable', args = { s.id } }, Config.PromptDistance)
        end
    end
end, function()
    for _, id in ipairs(zones) do MCI.RemoveZone(id) end
    zones = {}
    for _, ped in pairs(hands) do MCI.RemoveEntity(ped) end
    for _, s in ipairs(Config.Stables) do MCI.RemovePrompt('multihorses_' .. s.id) end
    interactMode = nil
end)

CreateThread(function()
    for _, s in ipairs(Config.Stables) do
        local label = MH.StableLabel(s.id)
        if Config.Blips.Enabled and s.blip ~= false then
            local blip = BlipAddForCoords(Config.Blips.Style, s.coords.x, s.coords.y, s.coords.z)
            SetBlipSprite(blip, joaat(Config.Blips.Sprite), true)
            SetBlipScale(blip, Config.Blips.Scale)
            Citizen.InvokeNative(SET_BLIP_NAME, blip, label)
            blips[#blips + 1] = blip
        end
    end
end)

-- ---------------------------------------------------------------
-- stable hands
-- ---------------------------------------------------------------
local function spawnHand(s)
    local model = joaat(s.model)
    RequestModel(model, false)
    local deadline = GetGameTimer() + Config.Npc.LoadTimeoutMs
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(model) then return nil end
    local ped = CreatePed(model, s.npc.x, s.npc.y, s.npc.z + Config.Npc.ZOffset, s.npc.w, false, false, false, false)
    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)
    if Config.Npc.Scenario ~= '' then
        Citizen.InvokeNative(TASK_START_SCENARIO_IN_PLACE_HASH, ped, joaat(Config.Npc.Scenario), -1, true, 0, -1.0, false)
    end
    return ped
end

CreateThread(function()
    if not Config.Npc.Enabled then return end
    while true do
        Wait(Config.CheckIntervalMs)
        local pos = GetEntityCoords(cache.ped)
        for _, s in ipairs(Config.Stables) do
            local near = #(pos - s.npc.xyz) < Config.Npc.SpawnDistance
            if near and not hands[s.id] then
                hands[s.id] = spawnHand(s)
                if hands[s.id] and interactMode == 'target' then MCI.AddEntity(hands[s.id], { stableOption(s) }) end
            elseif not near and hands[s.id] then
                MCI.RemoveEntity(hands[s.id])
                if DoesEntityExist(hands[s.id]) then DeletePed(hands[s.id]) end
                hands[s.id] = nil
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    for _, ped in pairs(hands) do if DoesEntityExist(ped) then DeletePed(ped) end end
    for _, s in ipairs(Config.Stables) do MCI.RemovePrompt('multihorses_' .. s.id) end
    -- MULTItarget drops this script's zones and entity options by itself when it stops
end)

-- for /mcinteract
MCI.Counter('npcs', function()
    local n = 0
    for _ in pairs(hands) do n = n + 1 end
    return n
end)

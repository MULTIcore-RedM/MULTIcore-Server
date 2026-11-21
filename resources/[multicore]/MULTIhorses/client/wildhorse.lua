-- ============================================================
-- MULTIhorses :: wild horses (client)
-- Ride a horse you tamed to a horse seller: sell it or have it stabled.
-- Sellers are used through MULTItarget (or a hold-key prompt,
-- Config.Interact). Settings: config/wildhorse.lua.
-- ============================================================
local selling = false
local cooldown = false
local cooldowntimer = 0
local wildhorseBlips = {}
local sellerZones = {}

local function hasOwnHorseOut()
    local myhorse = GetActiveHorsePed and GetActiveHorsePed() or 0
    return myhorse and myhorse ~= 0
end

-- Delete Entity
local DeleteThis = function(horse)
    NetworkRequestControlOfEntity(horse)
    SetEntityAsMissionEntity(horse, true, true)

    Wait(100)

    DeleteEntity(horse)

    Wait(500)

    local ped = PlayerPedId()
    local entitycheck = Citizen.InvokeNative(0xD806CD2A4F2C2996, ped)
    local ridingcheck = GetPedType(entitycheck)

    if ridingcheck == 0 then return true end

    return false
end

-------------------------------------------------------------------------------------------
-- sellers: MULTItarget zones or prompts, and blips
-------------------------------------------------------------------------------------------
if Config.WildHorse.Enabled ~= false then
    CreateThread(function()
        for _, v in pairs(Config.WildHorse.SellWildHorseLocations) do
            if v.showblip == true then
                local SellWildHorseBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v.coords)
                SetBlipSprite(SellWildHorseBlip, joaat(Config.WildHorse.Blip.blipSprite), true)
                SetBlipScale(SellWildHorseBlip, Config.WildHorse.Blip.blipScale)
                Citizen.InvokeNative(0x9CB1A1623062F402, SellWildHorseBlip, _L('wh_blip_name'))
                wildhorseBlips[#wildhorseBlips + 1] = SellWildHorseBlip
            end
        end
    end)

    MCI.Run(Config.Interact, function(mode)
        for _, v in pairs(Config.WildHorse.SellWildHorseLocations) do
            local label = _L(v.label)
            if mode == 'target' then
                sellerZones[#sellerZones + 1] = MCI.AddZone({
                    coords = v.coords,
                    radius = Config.WildHorse.TargetRadius or 1.5,
                    options = {
                        {
                            name = 'multihorses_wildhorse',
                            icon = 'fas fa-horse-head',
                            label = _L('wh_menu_open', label),
                            distance = 3.0,
                            onSelect = function() TriggerEvent('MULTIhorses:wild:client:menu', label) end,
                        },
                    },
                })
            else
                MCI.AddPrompt('multihorses_wild_' .. v.location, v.coords, Config.WildHorse.Keybind, _L('wh_menu_open', label), {
                    type = 'client',
                    event = 'MULTIhorses:wild:client:menu',
                    args = { label },
                })
            end
        end
    end, function()
        for _, id in ipairs(sellerZones) do MCI.RemoveZone(id) end
        sellerZones = {}
        for _, v in pairs(Config.WildHorse.SellWildHorseLocations) do MCI.RemovePrompt('multihorses_wild_' .. v.location) end
    end)
end

-- Sell Wild Horse Menu
AddEventHandler('MULTIhorses:wild:client:menu', function(name)
    if selling then return end

    if Config.WildHorse.EnableCooldown and cooldowntimer > 0 then
        local timer = cooldowntimer
        local unit = _L('wh_cooldown_seconds')

        if cooldowntimer > 60 then
            timer = math.floor(cooldowntimer / 60)
            unit = _L('wh_cooldown_minutes')
        end

        lib.notify({
            title = _L('wh_title'),
            description = _L('wh_error_cooldown', timer, unit),
            type = 'error',
            duration = 3000
        })

        return
    end

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'setLocale', locale = _LT(), lang = _LCode() })
    SendNUIMessage({ action = 'wh-open', title = name })
end)

-- Sell Horse Event
AddEventHandler('MULTIhorses:wild:client:sellhorse', function()
    local ped = PlayerPedId()
    local horse = Citizen.InvokeNative(0xE7E11B8DCBED1058, ped)
    if not horse or horse == 0 then
        lib.notify({
            title = _L('wh_title'),
            description = _L('wh_error_no_horse_sell'),
            type = 'error',
            duration = 3000
        })
        return
    end
    local model = GetEntityModel(horse)
    local owner = Citizen.InvokeNative(0xF103823FFE72BB49, horse)
    selling = true

    if Config.WildHorse.Debug then
        print('[MULTIhorses] wild horse sale: rider ' .. tostring(ped) .. ', horse ' .. tostring(horse) .. ', model ' .. tostring(model) .. ', owner ' .. tostring(owner))
    end

    if not owner or owner ~= ped then
        lib.notify({
            title = _L('wh_title'),
            description = _L('wh_error_not_tamed'),
            type = 'error',
            duration = 3000
        })

        Wait(3000)

        selling = false

        return
    end

    if hasOwnHorseOut() then
        lib.notify({
            title = _L('wh_title'),
            description = _L('wh_error_owned_horse'),
            type = 'error',
            duration = 3000
        })

        Wait(3000)

        selling = false

        return
    end

    for i = 1, #Config.WildHorse.Horse do
        local entry = Config.WildHorse.Horse[i]

        if model == entry.model then
            -- appraisal progress (the stable NUI page)
            SendNUIMessage({
                action = 'wh-progressStart',
                duration = Config.WildHorse.SellTime,
            })

            local sellStart = GetGameTimer()
            local sellDuration = tonumber(Config.WildHorse.SellTime) or 5000
            local cancelled = false

            while (GetGameTimer() - sellStart) < sellDuration do
                Wait(0)

                -- keep the player in place while the appraisal runs
                DisableControlAction(0, 0x07CE1E61, true) -- sprint
                DisableControlAction(0, 0x8FFC75D6, true) -- jump
                DisableControlAction(0, 0xD9D0E1C0, true) -- attack
                DisableControlAction(0, 0xF84FA74F, true) -- aim
                DisableControlAction(0, 0xB238FE0B, true) -- melee attack
                DisableControlAction(0, 0xC1989F95, true) -- melee alternate
                DisableControlAction(0, 0xAC4BD4FE, true) -- weapon wheel
                FreezeEntityPosition(ped, true)

                -- ESC cancels the appraisal
                if IsControlJustPressed(0, 322) then
                    cancelled = true
                    break
                end
            end

            FreezeEntityPosition(ped, false)
            SendNUIMessage({ action = 'wh-progressStop' })

            if cancelled then
                selling = false
                lib.notify({
                    title = _L('wh_title'),
                    description = _L('wh_appraisal_cancelled'),
                    type = 'error',
                    duration = 2500
                })
                return
            end

            local deleted = DeleteThis(horse)

            if deleted then
                -- the server works out the reward from the model
                TriggerServerEvent('MULTIhorses:wild:server:reward', model)

                Wait(3000)

                selling = false

                if Config.WildHorse.EnableCooldown then
                    TriggerEvent('MULTIhorses:wild:client:Cooldown')
                end

                return
            end

            selling = false
        end
    end

    selling = false
end)

AddEventHandler('MULTIhorses:wild:client:Cooldown', function()
    if cooldown then return end

    CreateThread(function()
        cooldowntimer = Config.WildHorse.Cooldown
        cooldown = true

        while true do
            Wait(1000)

            cooldowntimer = cooldowntimer - 1

            if cooldowntimer <= 0 then
                cooldowntimer = 0
                cooldown = false

                return
            end
        end
    end)
end)

if Config.WildHorse.Debug then
    RegisterNetEvent('MULTIhorses:wild:client:SetHorseAsWild', function()
        local ped = PlayerPedId()
        local mount = GetMount(ped)

        if mount then
            Citizen.InvokeNative(0xAEB97D84CDF3C00B, mount, true)
        end
    end)
end

-- Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    FreezeEntityPosition(PlayerPedId(), false)
    SendNUIMessage({ action = 'wh-progressStop' })

    for i = 1, #wildhorseBlips do
        if wildhorseBlips[i] then
            RemoveBlip(wildhorseBlips[i])
        end
    end
    wildhorseBlips = {}
end)

-- Save Wild Horse Event (client)
AddEventHandler('MULTIhorses:wild:client:wildhorsestable', function()
    local ped = PlayerPedId()
    local horse = Citizen.InvokeNative(0xE7E11B8DCBED1058, ped)
    -- validate the horse exists before touching it with other natives
    if not horse or horse == 0 then
        lib.notify({
            title = _L('wh_title'),
            description = _L('wh_error_no_horse_save'),
            type = 'error',
            duration = 3000
        })
        return
    end
    local model = GetEntityModel(horse)
    local owner = Citizen.InvokeNative(0xF103823FFE72BB49, horse)

    if Config.WildHorse.Debug then
        print('[MULTIhorses] wild horse save: rider ' .. tostring(ped) .. ', horse ' .. tostring(horse) .. ', model ' .. tostring(model) .. ', owner ' .. tostring(owner))
    end

    -- the horse must be tamed (owner = the player ped)
    if not owner or owner ~= ped then
        lib.notify({
            title = _L('wh_title'),
            description = _L('wh_error_not_tamed'),
            type = 'error',
            duration = 3000
        })
        return
    end

    -- the player must not be on their own horse
    if hasOwnHorseOut() then
        lib.notify({
            title = _L('wh_title'),
            description = _L('wh_error_owned_horse'),
            type = 'error',
            duration = 3000
        })
        return
    end

    local input = lib.inputDialog(_L('wh_dialog_title'), {
        {
            type = 'input',
            label = _L('wh_dialog_name'),
            description = _L('wh_dialog_name_desc'),
            required = true,
            min = 1,
            max = 30,
        },
        {
            type = 'select',
            label = _L('wh_dialog_gender'),
            description = _L('wh_dialog_gender_desc'),
            required = true,
            options = {
                { value = 'male',   label = _L('wh_gender_male')   },
                { value = 'female', label = _L('wh_gender_female') },
            }
        },
    })

    -- the player closed the dialog
    if not input then
        lib.notify({
            title = _L('wh_title'),
            description = _L('wh_save_cancelled'),
            type = 'error',
            duration = 3000
        })
        return
    end

    local horseName = input[1]
    local gender    = input[2]

    if not horseName or horseName == '' or not gender then
        lib.notify({
            title = _L('wh_title'),
            description = _L('wh_error_invalid_name'),
            type = 'error',
            duration = 3000
        })
        return
    end

    lib.notify({
        title = _L('wh_title'),
        description = _L('wh_saving'),
        type = 'inform',
        duration = 3000
    })

    TriggerServerEvent('MULTIhorses:wild:server:WildHorseStable', model, horseName, gender)
end)

-- the server saved the horse: the wild horse entity goes
RegisterNetEvent('MULTIhorses:wild:client:DeleteWildHorse', function()
    local ped = PlayerPedId()
    local horse = Citizen.InvokeNative(0xE7E11B8DCBED1058, ped)

    if horse and horse ~= 0 then
        NetworkRequestControlOfEntity(horse)
        SetEntityAsMissionEntity(horse, true, true)
        Wait(100)
        DeleteEntity(horse)

        if Config.WildHorse.Debug then
            print('[MULTIhorses] wild horse removed after saving it to the stables.')
        end
    end
end)

-- NUI callbacks of the wild horse panel (wh-prefixed so they never clash with the stable ones)
RegisterNUICallback('whClose', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'wh-close' })
    cb('ok')
end)

RegisterNUICallback('whSell', function(_, cb)
    SetNuiFocus(false, false)
    TriggerEvent('MULTIhorses:wild:client:sellhorse')
    cb('ok')
end)

RegisterNUICallback('whSave', function(_, cb)
    SetNuiFocus(false, false)
    TriggerEvent('MULTIhorses:wild:client:wildhorsestable')
    cb('ok')
end)

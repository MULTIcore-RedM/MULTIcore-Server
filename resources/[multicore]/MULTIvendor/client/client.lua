local Core = exports.MULTIcore:GetCoreObject()
local VendorPeds = {}

local CurrentVendorIndex = nil

-- ============================================================================
-- Notifications (MULTIcore Notify)
-- ============================================================================
local function Notify(msg, nType, duration)
    exports.MULTIcore:Notify({
        title = _L('notify_title'),
        text = msg,
        type = nType == 'error' and 'error' or 'success',
        duration = duration or Config.Notification.DefaultDuration,
    })
end

-- Item picture folders handed out by the inventory (falls back to MULTIimages)
local function ImagePaths()
    if GetResourceState('MULTIinventory') == 'started' then
        local ok, list = pcall(function() return exports.MULTIinventory:GetImagePaths() end)
        if ok and type(list) == 'table' and #list > 0 then return list end
    end
    return { 'nui://MULTIimages/images/' }
end

-- ============================================================================
-- Spawn NPC ped at a vendor location
-- ============================================================================
local function SpawnVendorPed(vendor)
    local pedCfg = vendor.ped or Config.DefaultPed
    local model = GetHashKey(pedCfg.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(50) end

    local ped = CreatePed(model, vendor.coords.x, vendor.coords.y, vendor.coords.z - 1.0, vendor.heading or 0.0, false, false, true, true)
    SetEntityHeading(ped, vendor.heading or 0.0)
    PlaceEntityOnGroundProperly(ped)
    SetEntityAlpha(ped, 0, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedCanRagdoll(ped, false)

    if pedCfg.scenario then
        TaskStartScenarioInPlace(ped, GetHashKey(pedCfg.scenario), 0, true)
    end

    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    SetModelAsNoLongerNeeded(model)

    if Config.FadeIn then
        for i = 0, 255, 51 do
            Wait(50)
            SetEntityAlpha(ped, i, false)
        end
    else
        SetEntityAlpha(ped, 255, false)
    end

    return ped
end

-- ============================================================================
-- Create blips and prompts (one-time setup)
-- ============================================================================
Citizen.CreateThread(function()
    for i, vendor in ipairs(Config.Vendors) do
        -- Prompt at promptCoords (in front of counter where player stands)
        local promptPos = vendor.promptCoords or vendor.coords
        exports.MULTIcore:createPrompt(
            'MULTIvendor-' .. i,
            promptPos,
            Core.Shared.Keybinds[Config.Keybind],
            _L('open_vendor', vendor.name),
            {
                type = 'client',
                event = 'MULTIvendor:client:openMenu',
                args = { i },
            }
        )

        -- Blip
        if Config.Blip.enabled then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, vendor.coords)
            SetBlipSprite(blip, Config.Blip.sprite, 1)
            SetBlipScale(blip, Config.Blip.scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, vendor.blipName or vendor.name)
        end
    end
end)

-- ============================================================================
-- Proximity spawn/despawn loop
-- ============================================================================
Citizen.CreateThread(function()
    while true do
        Wait(500)
        local playerCoords = GetEntityCoords(PlayerPedId())
        for i, vendor in ipairs(Config.Vendors) do
            local distance = #(playerCoords - vendor.coords)

            if distance < Config.DistanceSpawn and not VendorPeds[i] then
                local ped = SpawnVendorPed(vendor)
                VendorPeds[i] = ped
            end

            if distance >= Config.DistanceSpawn and VendorPeds[i] then
                if Config.FadeIn then
                    for a = 255, 0, -51 do
                        Wait(50)
                        SetEntityAlpha(VendorPeds[i], a, false)
                    end
                end
                DeleteEntity(VendorPeds[i])
                VendorPeds[i] = nil
            end
        end
    end
end)

-- ============================================================================
-- Cleanup peds and prompts on resource stop
-- ============================================================================
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for i, ped in pairs(VendorPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
        VendorPeds[i] = nil
    end
    for i = 1, #Config.Vendors do
        pcall(function() exports.MULTIcore:deletePrompt('MULTIvendor-' .. i) end)
    end
    SetNuiFocus(false, false)
end)

-- ============================================================================
-- Build the NUI language table from the active locale
-- ============================================================================
local function UiLang()
    local keys = {
        'close', 'sell', 'sell_all', 'sell_everything', 'custom_amount',
        'amount', 'price_each', 'total', 'confirm', 'cancel',
        'confirm_sell_everything', 'select_item', 'owned', 'no_items', 'not_enough',
        'all',
    }
    local lang = {}
    for _, k in ipairs(keys) do
        lang[k] = _L(k)
    end
    return lang
end

-- ============================================================================
-- Open vendor menu - scans inventory for matching items
-- ============================================================================
RegisterNetEvent('MULTIvendor:client:openMenu', function(vendorIndex)
    local vendor = Config.Vendors[vendorIndex]
    if not vendor then return end

    local player = Core.Functions.GetPlayerData()
    local inventory = {}
    for _, item in pairs(player.items or {}) do
        if item and item.name then
            inventory[item.name] = (inventory[item.name] or 0) + (item.amount or 0)
        end
    end

    local items = {}
    local totalValue = 0

    for itemName, price in pairs(vendor.ItemPrices) do
        local count = inventory[itemName] or 0
        if count > 0 then
            totalValue = totalValue + (count * price)
            local itemInfo = Core.Shared.Items[itemName]
            local label = itemInfo and itemInfo.label or itemName
            local image = itemInfo and itemInfo.image or nil
            local category = Config.SellMenu.Categories[itemName] or ''

            table.insert(items, {
                item     = itemName,
                label    = label,
                price    = price,
                count    = count,
                value    = count * price,
                image    = image,
                category = category,
            })
        end
    end

    table.sort(items, function(a, b)
        return a.label < b.label
    end)

    if #items == 0 then
        Notify(_L('nothing_to_sell'), 'error')
        return
    end

    CurrentVendorIndex = vendorIndex

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openSell',
        vendorName = vendor.name,
        items = items,
        totalValue = totalValue,
        currency = Config.SellMenu.Currency,
        quickAmounts = Config.SellMenu.QuickSellAmounts,
        showSellEverything = Config.SellMenu.ShowSellEverything,
        lang = UiLang(),
        images = ImagePaths(),
        cyrillic = Config.Locale == 'ru',
    })
end)

-- ============================================================================
-- NUI callbacks
-- ============================================================================
RegisterNUICallback('sellItem', function(data, cb)
    SetNuiFocus(false, false)
    local vendorIndex = CurrentVendorIndex
    CurrentVendorIndex = nil
    SendNUIMessage({ action = 'forceCloseSell' })

    if vendorIndex and data and data.item and tonumber(data.amount) then
        local amount = math.floor(tonumber(data.amount))
        if amount > 0 then
            TriggerServerEvent('MULTIvendor:server:sellItem', vendorIndex, data.item, amount)
        end
    end
    cb('ok')
end)

RegisterNUICallback('sellAll', function(data, cb)
    SetNuiFocus(false, false)
    local vendorIndex = CurrentVendorIndex
    CurrentVendorIndex = nil
    SendNUIMessage({ action = 'forceCloseSell' })

    if vendorIndex then
        TriggerServerEvent('MULTIvendor:server:sellAll', vendorIndex)
    end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    CurrentVendorIndex = nil
    cb('ok')
end)

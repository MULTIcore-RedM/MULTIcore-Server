local Core = exports.MULTIcore:GetCoreObject()
local Inv = exports.MULTIinventory

-- ============================================================================
-- Notifications (MULTIcore Notify, server -> client)
-- ============================================================================
local function NotifyServer(src, msg, nType, duration)
    exports.MULTIcore:Notify(src, {
        title = _L('notify_title'),
        text = msg,
        type = nType == 'error' and 'error' or 'success',
        duration = duration or Config.Notification.DefaultDuration,
    })
end

local function ItemLabel(itemName)
    local def = Core.Shared.Items[itemName]
    return def and def.label or itemName
end

-- The player must stand at the vendor (prompt spot or ped) to sell.
local function IsNearVendor(src, vendor)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local maxDist = Config.SellDistance or 10.0
    if vendor.promptCoords and #(pos - vendor.promptCoords) <= maxDist then return true end
    return #(pos - vendor.coords) <= maxDist
end

-- ============================================================================
-- Sell a specific item to a vendor
-- ============================================================================
RegisterNetEvent('MULTIvendor:server:sellItem', function(vendorIndex, itemName, amount)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    local vendor = Config.Vendors[tonumber(vendorIndex) or -1]
    if not vendor then return end
    if not IsNearVendor(src, vendor) then return end

    if type(itemName) ~= 'string' then return end
    local price = vendor.ItemPrices[itemName]
    if not price then
        NotifyServer(src, _L('invalid_item'), 'error')
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount ~= amount or amount <= 0 then return end

    -- Verify player actually has enough
    local have = Inv:Count(src, itemName) or 0
    if have < amount then
        NotifyServer(src, _L('not_enough'), 'error')
        return
    end

    -- Pay only for what was really taken
    local ok = Inv:RemoveItem(src, itemName, amount, nil, nil, 'vendor-sell')
    if not ok then
        NotifyServer(src, _L('not_enough'), 'error')
        return
    end
    Inv:ItemBox(src, itemName, amount, 'remove')

    local totalPayout = amount * price
    Player.Functions.AddMoney('cash', totalPayout, 'vendor-sell')

    NotifyServer(src, _L('sold_item', amount, ItemLabel(itemName), string.format('%.2f', totalPayout)))
end)

-- ============================================================================
-- Sell ALL matching items to a vendor
-- ============================================================================
RegisterNetEvent('MULTIvendor:server:sellAll', function(vendorIndex)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    local vendor = Config.Vendors[tonumber(vendorIndex) or -1]
    if not vendor then return end
    if not IsNearVendor(src, vendor) then return end

    local totalPayout = 0
    local totalItems = 0

    for itemName, price in pairs(vendor.ItemPrices) do
        local count = Inv:Count(src, itemName) or 0
        if count > 0 then
            local ok = Inv:RemoveItem(src, itemName, count, nil, nil, 'vendor-sell-all')
            if ok then
                Inv:ItemBox(src, itemName, count, 'remove')
                totalPayout = totalPayout + count * price
                totalItems = totalItems + count
            end
        end
    end

    if totalPayout > 0 then
        Player.Functions.AddMoney('cash', totalPayout, 'vendor-sell-all')
        NotifyServer(src, _L('sold_all', totalItems, string.format('%.2f', totalPayout)))
    else
        NotifyServer(src, _L('nothing_to_sell_error'), 'error')
    end
end)

-- ============================================================
-- MULTIwagons :: dealer page (client side of html/)
-- Opens the page, answers its callbacks (wagons for sale, your wagons,
-- change options, preview) and sends buys, sales and changes to the server.
-- Based on Phil's wagon script (menu.lua).
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

MWC = MWC or {}
local Core = exports['rsg-core']:GetCoreObject()
local currentWagonCustom = {}
local currentStore, currentWagonModel

local function GetPlayerMoney()
    local player = Core.Functions.GetPlayerData()
    if not player or not player.money then return { cash = 0, gold = 0 } end
    return { cash = player.money[Config.MoneyType.money] or player.money.cash or 0, gold = player.money[Config.MoneyType.gold] or player.money.gold or 0 }
end

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

--- Opens the dealer page of store storeId.
function MWC.OpenStore(storeId)
    if not Config.Stores[storeId] then return end
    currentStore = storeId
    local categories = {}
    for cat in pairs(Config.Wagons) do
        categories[#categories + 1] = { type = cat, label = _L("cat_" .. cat), image = cat .. ".png" }
    end
    table.sort(categories, function(a, b) return a.label:lower() < b.label:lower() end)

    SendNUIMessage({
        action = 'openStore',
        store = storeId,
        categories = categories,
        playerMoney = GetPlayerMoney(),
        prices = Config.CustomPrice,
        currency = Config.CurrencySign,
        nameMax = Config.NameMaxLength,
        text = _LT(),
        lang = _LCode(),
    })
    SetNuiFocus(true, true)
end

RegisterNUICallback('getWagonsByType', function(data, cb)
    local wagonsData = {}
    local set = Config.Wagons[data.type]
    if set then
        for model, v in pairs(set) do
            wagonsData[#wagonsData + 1] = {
                name = v.name, price = v.price, maxAnimals = v.maxAnimals,
                slots = v.slots, maxWeight = v.maxWeight, model = model,
            }
        end
    end
    table.sort(wagonsData, function(a, b) return (a.price or math.huge) < (b.price or math.huge) end)
    SendNUIMessage({ action = 'showWagons', wagons = wagonsData })
    cb('ok')
end)

RegisterNUICallback('previewWagon', function(data, cb)
    cb('ok')
    SpawnShowroomWagon(data.model, currentStore)
end)

RegisterNUICallback('previewMyWagon', function(data, cb)
    cb('ok')
    currentWagonModel = data.model
    currentWagonCustom = copy(data.custom)
    SpawnShowroomMyWagon(data.model, currentStore, data.custom or {})
end)

RegisterNUICallback('buyWagon', function(data, cb)
    cb('ok')
    CloseShowroom()
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    TriggerServerEvent('MULTIwagons:server:buyWagon', data.model, data.name, 'cash')
end)

RegisterNUICallback('getMyWagons', function(_, cb)
    cb('ok')
    lib.callback('MULTIwagons:server:myWagons', false, function(list)
        SendNUIMessage({ action = 'showMyWagons', wagons = list or {} })
    end)
end)

RegisterNUICallback('activateWagon', function(data, cb)
    cb('ok')
    CloseShowroom()
    SetNuiFocus(false, false)
    TriggerServerEvent('MULTIwagons:server:activateWagon', data.id)
end)

RegisterNUICallback('sellWagon', function(data, cb)
    cb('ok')
    CloseShowroom()
    SetNuiFocus(false, false)
    TriggerServerEvent('MULTIwagons:server:sellWagon', data.id)
end)

local function extraLabel(label, id)
    local n = type(label) == 'string' and label:match('^Extra (%d+)$')
    if n or not label then return _L('opt_extra', n or tostring(id)) end
    return label
end

RegisterNUICallback('getCustomOptions', function(data, cb)
    local customType = data.type
    local model = string.lower(data.model or '')
    local custom = data.custom or {}
    currentWagonCustom = copy(custom)

    local options = {}
    local multi = false
    local categories = nil
    local remove = { label = _L('opt_remove'), value = -1 }

    if customType == 'livery' then
        options[#options + 1] = remove
        for _, v in ipairs(Custom.livery and Custom.livery[model] or {}) do
            options[#options + 1] = { label = v[2], value = v[1] }
        end
    elseif customType == 'extra' then
        -- several at once: entries are { id, label } (see wagon_extras.lua); bare numbers still work
        multi = true
        local enabled = {}
        if type(custom.extras) == 'table' then
            for _, id in ipairs(custom.extras) do
                local nid = tonumber(id)
                if nid then enabled[nid] = true end
            end
        elseif custom.extra and tonumber(custom.extra) and tonumber(custom.extra) ~= -1 then
            enabled[tonumber(custom.extra)] = true
        end
        for _, e in ipairs(Custom.extra and Custom.extra[model] or {}) do
            local id, label = nil, nil
            if type(e) == 'table' then
                id, label = tonumber(e.id), e.label
            elseif tonumber(e) then
                id = tonumber(e)
            end
            if id then
                options[#options + 1] = { label = extraLabel(label, id), value = id, enabled = enabled[id] == true }
            end
        end
    elseif customType == 'tint' then
        options[#options + 1] = remove
        for i = 1, (Custom.tint and Custom.tint[model]) or 0 do
            options[#options + 1] = { label = _L('opt_paint', i), value = i }
        end
    elseif customType == 'props' then
        -- cargo sets by category (general / cargo / trade / supplies); a flat list counts as 'general'
        options[#options + 1] = remove
        local sets = Custom.props and Custom.props[model]
        if sets then
            local cats = type(sets.general) == 'table' and sets or { general = sets }
            categories = {}
            local seenCats = {}
            local function addCategory(catName)
                local list = cats[catName]
                if type(list) == 'table' and #list > 0 and not seenCats[catName] then
                    seenCats[catName] = true
                    local catOpts = {}
                    for _, propset in ipairs(list) do
                        if type(propset) == 'string' then catOpts[#catOpts + 1] = { label = propset, value = propset } end
                    end
                    if #catOpts > 0 then
                        local key = 'props_' .. catName
                        local label = _L(key)
                        if label == key then label = catName:gsub('^%l', string.upper) end
                        categories[#categories + 1] = { name = catName, label = label, options = catOpts }
                    end
                end
            end
            for _, catName in ipairs({ 'general', 'cargo', 'trade', 'supplies' }) do addCategory(catName) end
            for catName in pairs(cats) do addCategory(catName) end
        end
    elseif customType == 'lantern' then
        options[#options + 1] = remove
        for _, l in pairs(Custom.lantern and Custom.lantern[model] or {}) do
            local hash, label = nil, nil
            if type(l) == 'table' then
                hash = l.value
                label = l.labelKey and _L(l.labelKey) or l.label
            elseif type(l) == 'string' then
                hash, label = l, l
            end
            if hash then options[#options + 1] = { label = label or hash, value = hash } end
        end
    end

    SendNUIMessage({
        action = 'showCustomOptions',
        type = customType,
        options = options,
        price = Config.CustomPrice[customType] or 0,
        multi = multi,
        categories = categories,
    })
    cb('ok')
end)

RegisterNUICallback('previewCustom', function(data, cb)
    cb('ok')
    local customType, value = data.type, data.value
    local currentShow = copy(currentWagonCustom)
    if customType == 'extra' and type(value) == 'table' then
        currentShow.extras = value
        currentShow.extra = nil
    else
        -- "Remove": false skips the cargo / lantern natives (GetHashKey(-1) would be wrong)
        if (customType == 'props' or customType == 'lantern') and value == -1 then value = false end
        currentShow[customType] = value
    end
    SpawnShowroomMyWagon(currentWagonModel, currentStore, currentShow)
end)

RegisterNUICallback('resetPreview', function(data, cb)
    cb('ok')
    SpawnShowroomMyWagon(data.model, currentStore, data.custom or {})
end)

RegisterNUICallback('saveCustomization', function(data, cb)
    cb('ok')
    local customType, value = data.type, data.value
    if customType == 'extra' and type(value) == 'table' then
        currentWagonCustom.extras = value
        currentWagonCustom.extra = nil
    else
        if (customType == 'props' or customType == 'lantern') and value == -1 then value = false end
        currentWagonCustom[customType] = value
    end
    SpawnShowroomMyWagon(data.model, currentStore, currentWagonCustom)
    TriggerServerEvent('MULTIwagons:server:saveCustomization', data.id, customType, value)
end)

RegisterNUICallback('rotateWagon', function(data, cb)
    cb('ok')
    RotatePreviewWagon(data.direction)
end)

RegisterNUICallback('closeShop', function(_, cb)
    cb('ok')
    CloseShowroom()
    SetNuiFocus(false, false)
end)

exports('OpenStore', MWC.OpenStore)

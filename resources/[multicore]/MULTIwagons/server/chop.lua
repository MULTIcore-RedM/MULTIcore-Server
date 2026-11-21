-- ============================================================
-- MULTIwagons :: chop shop (server): rewards, cooldown, owner-aware delete.
-- Based on Phil's wagon script (chop shop), fitted to MULTIcore.
-- Reaches the wagon list through MW (server/main.lua).
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================
if not (Config.Chop and Config.Chop.Enabled ~= false) then return end

local Core = exports['rsg-core']:GetCoreObject()

local ChopCooldowns = {}
local PendingChops = {}
local LastChop = {}      -- [src] = { netId, at } the last unowned wagon src scrapped (for the server delete)

local function ChopDebug(...)
    if Config.Chop.Debug then print('[MULTIwagons:chop]', ...) end
end

local function chopNotify(src, ntype, titleKey, text)
    TriggerClientEvent('MULTIwagons:client:chopNotify', src, ntype, _L(titleKey), text)
end

local function GetWagonDisplayName(modelName)
    if not modelName then return _L('unknown_item') end
    local cfg = MW.ModelCfg(modelName)
    if cfg and cfg.name then return cfg.name end
    local name = modelName:gsub('^p_', ''):gsub('(%d+x?)$', ''):gsub('(%d+)$', ''):gsub('_', ' ')
    name = name:gsub('(%a)([%w]*)', function(first, rest) return first:upper() .. rest end)
    if name == '' then name = modelName end
    return name
end

-- Multiplier from the wagon's shop price, so no second model list is needed.
local function GetChopMultiplier(modelName)
    local cfg = MW.ModelCfg(modelName)
    if cfg and cfg.price then
        local m = cfg.price / 100.0
        return math.max(Config.Chop.MinMultiplier or 0.5, math.min(Config.Chop.MaxMultiplier or 2.5, m))
    end
    return Config.Chop.DefaultMultiplier or 1.0
end

local function CalculateChopRewards(multiplier)
    local rewards = {}
    for item, range in pairs(Config.Chop.RewardItems or {}) do
        rewards[item] = math.floor(math.random(range.min, range.max) * multiplier + 0.5)
    end
    if Config.Chop.CashPayout then
        rewards.cash = math.floor(math.random(Config.Chop.CashPayout.min, Config.Chop.CashPayout.max) * multiplier + 0.5)
    end
    return rewards
end

local function IsChopOnCooldown(src)
    local now, cd = os.time(), Config.Chop.ChopCooldown or 300
    if ChopCooldowns[src] and (now - ChopCooldowns[src]) < cd then
        return true, cd - (now - ChopCooldowns[src])
    end
    return false, 0
end

local function nearChopPlace(src)
    if not Config.ServerDistanceCheck then return true end
    local pos = MW.PlayerPos(src)
    if not pos then return false end
    for _, loc in ipairs(Config.Chop.Locations or {}) do
        if #(pos - loc.coords) <= (Config.Chop.InteractDistance or 10.0) + 5.0 then return true end
    end
    return false
end

local function wagonNear(src, netId)
    if not Config.ServerDistanceCheck or netId == 0 then return true end
    local _, wpos = MW.Entity(netId)
    local ppos = MW.PlayerPos(src)
    return wpos ~= nil and ppos ~= nil and #(ppos - wpos) <= (Config.Chop.WagonSearchDistance or 30.0) + 5.0
end

--- What src would get for the wagon netId (or an error message).
local function chopInfo(src, netId, modelName)
    if not Core.Functions.GetPlayer(src) then return nil end

    local onCooldown, remaining = IsChopOnCooldown(src)
    if onCooldown then return { error = true, message = _L('chop_cooldown', remaining) } end
    if not nearChopPlace(src) then return { error = true, message = _L('too_far') } end

    netId = tonumber(netId) or 0
    if not wagonNear(src, netId) then return { error = true, message = _L('chop_no_wagon') } end
    local reg = netId ~= 0 and MW.GetRegistered(netId) or nil
    if reg then
        -- owned wagons can only be scrapped by their owner (no scrapping others' wagons for parts)
        if src ~= reg.owner then return { error = true, message = _L('no_permission') } end
        modelName = reg.wagonModel
        if Config.SellNeedsEmptyStorage and MW.StorageHasItems(reg.wagonID) then
            return { error = true, message = _L('not_empty') }
        end
    elseif type(modelName) ~= 'string' or (not MW.ModelCfg(modelName) and not Config.Chop.AllowUnknownWagons) then
        return { error = true, message = _L('chop_no_wagon') }
    end

    local rewards = CalculateChopRewards(GetChopMultiplier(modelName))

    -- labelled list for the page (the map stays for the payout)
    local rewardList = {}
    if rewards.cash and rewards.cash > 0 then
        rewardList[#rewardList + 1] = { item = 'cash', label = _L('chop_cash'), amount = Config.CurrencySign .. rewards.cash }
    end
    for item, amount in pairs(rewards) do
        if item ~= 'cash' and amount > 0 then
            local itemData = Core.Shared.Items[item]
            rewardList[#rewardList + 1] = { item = item, label = (itemData and itemData.label) or item, amount = 'x' .. amount }
        end
    end

    PendingChops[src] = PendingChops[src] or {}
    PendingChops[src][netId] = { modelName = modelName, rewards = rewards, createdAt = os.time() }

    return {
        error = false, netId = netId, modelName = modelName, displayName = GetWagonDisplayName(modelName),
        rewardList = rewardList, isRegistered = reg ~= nil,
    }
end

lib.callback.register('MULTIwagons:server:getChopInfo', function(src, netId, modelName)
    return chopInfo(src, netId, modelName)
end)

RegisterNetEvent('MULTIwagons:server:processChop', function(netId)
    local src = source
    netId = tonumber(netId) or 0
    ChopDebug(('processChop src=%s netId=%s'):format(tostring(src), tostring(netId)))

    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    local onCooldown, remaining = IsChopOnCooldown(src)
    if onCooldown then return chopNotify(src, 'error', 'chop_title', _L('chop_cooldown', remaining)) end

    local pending = PendingChops[src] and PendingChops[src][netId]
    if not pending or (os.time() - pending.createdAt) > (Config.Chop.RequestTimeout or 120) then
        if PendingChops[src] then PendingChops[src][netId] = nil end
        return chopNotify(src, 'error', 'chop_title', _L('chop_expired'))
    end
    PendingChops[src][netId] = nil
    if not nearChopPlace(src) or not wagonNear(src, netId) then
        return chopNotify(src, 'error', 'chop_title', _L('too_far'))
    end

    local reg = netId ~= 0 and MW.GetRegistered(netId) or nil
    if reg and src ~= reg.owner then
        return chopNotify(src, 'error', 'chop_title', _L('no_permission'))
    end
    if reg and Config.SellNeedsEmptyStorage and MW.StorageHasItems(reg.wagonID) then
        return chopNotify(src, 'error', 'chop_title', _L('not_empty'))
    end

    local rewards = pending.rewards
    local modelName = pending.modelName
    local rewardMsg = {}

    if rewards.cash and rewards.cash > 0 then
        Player.Functions.AddMoney(Config.MoneyType.money or 'cash', rewards.cash)
        rewardMsg[#rewardMsg + 1] = Config.CurrencySign .. rewards.cash
    end
    for item, amount in pairs(rewards) do
        if item ~= 'cash' and amount > 0 then
            Player.Functions.AddItem(item, amount)
            TriggerClientEvent('inventory:client:ItemBox', src, Core.Shared.Items[item], 'add', amount)
            local itemData = Core.Shared.Items[item]
            rewardMsg[#rewardMsg + 1] = amount .. 'x ' .. ((itemData and itemData.label) or item)
        end
    end

    ChopCooldowns[src] = os.time()

    if reg then
        -- owned wagon, the chopper is the owner: the row, storage and entity go
        MW.ScrapWagon(reg.wagonID)
        TriggerClientEvent('MULTIwagons:client:chopDeleteOwnedWagon', src, netId)
    else
        -- a wagon nobody owns here: the chopper deletes it, the server makes sure below
        LastChop[src] = { netId = netId, at = os.time() }
        TriggerClientEvent('MULTIwagons:client:chopForceDelete', src, netId)
    end

    chopNotify(src, 'success', 'chop_done_title', _L('chop_done', GetWagonDisplayName(modelName), table.concat(rewardMsg, ', ')))

    local ci = Player.PlayerData.charinfo or {}
    print(('[MULTIwagons:chop] %s %s (ID %s) scrapped %s for %s'):format(
        ci.firstname or '?', ci.lastname or '?', tostring(src), tostring(modelName), table.concat(rewardMsg, ', ')))
end)

-- Server-side delete for wagons nobody owns here (the chopper's own delete may not have control).
RegisterNetEvent('MULTIwagons:server:chopDeleteFallback', function(netId)
    local src = source
    local id = tonumber(netId)
    if not id or id == 0 then return end
    if MW.GetRegistered(id) then return end   -- owned wagons only go through processChop
    local last = LastChop[src]
    if not last or last.netId ~= id or os.time() - last.at > 30 then return end
    LastChop[src] = nil
    local playerPed = GetPlayerPed(src)
    if playerPed == 0 then return end

    local wagon = NetworkGetEntityFromNetworkId(id)
    if wagon == 0 or not DoesEntityExist(wagon) then return end
    if GetEntityType(wagon) ~= 2 then return end
    if #(GetEntityCoords(playerPed) - GetEntityCoords(wagon)) > 60.0 then return end

    DeleteEntity(wagon)
    Wait(200)
    if DoesEntityExist(wagon) then DeleteEntity(wagon) end
    ChopDebug('fallback delete netId=' .. tostring(id) .. ' exists=' .. tostring(DoesEntityExist(wagon)))
end)

AddEventHandler('playerDropped', function()
    local src = source
    ChopCooldowns[src] = nil
    PendingChops[src] = nil
    LastChop[src] = nil
end)

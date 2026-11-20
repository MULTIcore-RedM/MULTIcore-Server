-- ============================================================
-- MULTIstores :: drop-in answers for RSG v2 scripts (server)
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
--
-- 1. rsg-inventory's shop exports, in rsg-inventory's shapes. MULTIinventory's
--    rsg-inventory face passes exports['rsg-inventory']:CreateShop / OpenShop /
--    DoesShopExist / RestockShop on to these (exports.MULTIstores:CreateShop ...).
-- 2. rsg-shops (MULTIstores `provide`s it): the server event
--    'rsg-shops:server:openstore' (products, name, label) that rsg-shops' own
--    client, rsg-lawman and rsg-prison send.
-- Shapes and rules follow RSG v2's rsg-inventory server/shops and rsg-shops
-- server/server.lua (GPL v3, by the RSG / Rexshack-RedM team, see CREDITS.md).
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

-- ------------------------------------------------------------
-- rsg-inventory shop exports
-- ------------------------------------------------------------

--- rsg-inventory CreateShop: one shop { name, label, items, slots?, coords?, persistentStock? }
--- or a table of them (keyed by name or a list). → true | false
local function createShop(shopData)
    if type(shopData) ~= 'table' then return false end
    if shopData.name then
        return (MS.CreateStore({
            name = shopData.name, label = shopData.label, items = shopData.items or {}, coords = shopData.coords,
            persistentStock = shopData.persistentStock, kind = 'script',
        }))
    end
    local any = false
    for key, data in pairs(shopData) do
        if type(data) == 'table' and data.items then
            local d = {}
            for k, v in pairs(data) do d[k] = v end
            d.name = type(key) == 'number' and data.name or key
            any = createShop(d) or any
        end
    end
    return any
end

--- rsg-inventory OpenShop(source, name). → true | false
local function openShop(source, name)
    local ok, err = MS.OpenStore(tonumber(source), name)
    if not ok and Config.Debug then
        print(('[MULTIstores] OpenShop %s for %s refused: %s'):format(tostring(name), tostring(source), tostring(err)))
    end
    return ok == true
end

exports('CreateShop', createShop)
exports('OpenShop', openShop)
exports('DoesShopExist', function(name) return MS.DoesStoreExist(name) end)
exports('RestockShop', function(name, percentage) return MS.Restock(name, percentage or 100) end)

-- ------------------------------------------------------------
-- rsg-shops
-- ------------------------------------------------------------
local cooldown = {}

RegisterNetEvent('rsg-shops:server:openstore', function(products, name, label)
    local src = source
    if not Config.RsgShops.Enabled then return end
    if cooldown[src] and os.time() - cooldown[src] < 1 then return end
    cooldown[src] = os.time()
    if type(name) ~= 'string' or #name > 100 then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- a store with a counter (the town stores keep rsg-shops' names): the usual checks
    local store = MS.Stores[name]
    if store and store.kind == 'config' then
        local ok, err = MS.OpenStore(src, name)
        if not ok then MS.Notify(src, 'err_' .. tostring(err), 'error') end
        return
    end

    -- a product list only scripts open (rsg-lawman 'armoury', rsg-prison 'prison'), like rsg-shops
    if type(products) ~= 'string' then return end
    local list = Config.RsgShops.Products[products]
    if not list then
        print(('^3[MULTIstores] rsg-shops:server:openstore: unknown products "%s" (store "%s")^7'):format(products, name))
        return
    end
    local jobType = Config.RsgShops.JobTypes[products]
    local job = Player.PlayerData.job or {}
    if jobType and job.type ~= jobType then return end
    local storeName = 'rsg-' .. products
    if not MS.Stores[storeName] then
        MS.CreateStore({
            name = storeName, label = type(label) == 'string' and label:sub(1, 60) or products,
            items = list, jobType = jobType, kind = 'script',
        })
    end
    if not MS.ready then return end
    local ok, err = MS.OpenStore(src, storeName)
    if not ok then MS.Notify(src, 'err_' .. tostring(err), 'error') end
end)

AddEventHandler('playerDropped', function() cooldown[source] = nil end)

-- ============================================================
-- MULTIwagons :: answers under the old wagon script's names (server)
-- MULTIwagons `provide`s 'rsg-wagons'. That script has no exports; other
-- scripts and radial menus reach it through these event / callback names,
-- with the same arguments and return shapes:
--
--   callback rsg-wagons:checkMyWagons             -> models[], customs[]
--   callback rsg-wagons:isWagonRegistered(netId)  -> registered, isOwner, wagonId, model, netId
--   callback rsg-wagons:getAnimalStorage(id)      -> { { label, infos }, ... }
--   event    rsg-wagons:getWagonDataByCitizenID([serverSource]) -> calls the selected wagon
--   event    rsg-wagons:openWagonStash(stash, model, wagonId, netId) -> that wagon's storage
--   event    rsg-wagons:saveWagonToDatabase(model, custom, moneyType) -> buys at a dealer (custom.name)
--   event    rsg-wagons:sellWagon(model, custom)   -> sells at a dealer (custom.name)
--   event    rsg-wagons:toggleWagonActive(model, custom) -> selects and calls that wagon
--   event    rsg-wagons:removeWagon(netId)         -> sends the sender's wagon away
--   event    rsg-wagons:registerWagon / updateWagonAuth / storeAnimalInWagon / removeAnimalFromWagon
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local OLD = 'rsg-wagons'

local function byCustom(src, model, custom)
    if type(custom) ~= 'table' then return nil end
    local w = MW.ByName(MW.CitizenId(src), custom.name)
    if not w or (model and w.model ~= model) then return nil end
    return w
end

lib.callback.register(OLD .. ':checkMyWagons', function(src)
    local models, customs = {}, {}
    for _, w in ipairs(MW.ListOf(MW.CitizenId(src))) do
        models[#models + 1] = w.model
        customs[#customs + 1] = w.custom
    end
    return models, customs
end)
lib.callback.register(OLD .. ':isWagonRegistered', function(src, netId) return MW.IsRegistered(src, netId) end)
lib.callback.register(OLD .. ':getAnimalStorage', function(_, id) return MW.AnimalMenu(id) end)

-- also fired server-side with the player's id
RegisterNetEvent(OLD .. ':getWagonDataByCitizenID', function(serverSource)
    local src = source
    if (src == nil or src == '' or tonumber(src) == nil) and serverSource then src = serverSource end
    MW.CallWagon(tonumber(src))
end)

RegisterNetEvent(OLD .. ':openWagonStash', function(stash, model, wagonId, netId)
    local src = source
    if not tonumber(netId) or not MW.GetRegistered(netId) then
        local r, n = MW.OutById(wagonId)
        if not r and type(stash) == 'string' then r, n = MW.OutById(stash:match('(%d+)$')) end
        netId = n
    end
    if netId then MW.OpenStash(src, netId) else MW.Notify(src, 'no_wagon_found', 'error') end
end)

RegisterNetEvent(OLD .. ':saveWagonToDatabase', function(model, custom, moneyType)
    local src = source
    if type(custom) ~= 'table' then return end
    if not MW.NearDealer(src) then return MW.Notify(src, 'too_far_dealer', 'error') end
    MW.Buy(src, model, custom.name, moneyType or custom.buyMoneyType)
end)

RegisterNetEvent(OLD .. ':sellWagon', function(model, custom)
    local src = source
    local w = byCustom(src, model, custom)
    if not w then return MW.Notify(src, 'no_wagon_found', 'error') end
    MW.Sell(src, w.id)
end)

RegisterNetEvent(OLD .. ':toggleWagonActive', function(model, custom)
    local src = source
    local w = byCustom(src, model, custom)
    if not w then return MW.Notify(src, 'no_custom_wagon', 'error') end
    MW.Activate(src, w.id)
end)

RegisterNetEvent(OLD .. ':removeWagon', function(netId) MW.Remove(source, netId) end)
RegisterNetEvent(OLD .. ':registerWagon', function(netId, wagonID, model) MW.Register(source, netId, wagonID, model) end)
RegisterNetEvent(OLD .. ':updateWagonAuth', function(netId, citizenID, action) MW.UpdateAuth(source, netId, citizenID, action) end)
RegisterNetEvent(OLD .. ':storeAnimalInWagon', function(wagonId, animal)
    local _, netId = MW.OutById(wagonId)
    if netId then MW.StoreAnimal(source, netId, animal) end
end)
RegisterNetEvent(OLD .. ':removeAnimalFromWagon', function(wagonId, infos) MW.TakeAnimal(source, wagonId, infos) end)

-- ============================================================
-- MULTIhorses :: server
-- Stables, buying and selling, saddlebags, customization, trading,
-- moving, breeding, horse xp, the horse shop and old age.
-- Based on rsg-horses by Phil (GPL v3), fitted to MULTIcore.
-- ============================================================
local Core = exports['rsg-core']:GetCoreObject()
local HorseSettings = lib.load('shared.horse_settings')
local MI = exports.MULTIinventory

----------------------------------
-- handlers (server/compat.lua answers the older event and callback names with the same functions)
----------------------------------
Horses = { events = {}, callbacks = {}, coreCallbacks = {} }

--- a net event MULTIhorses:server:<name>
function On(name, fn)
    Horses.events[name] = fn
    RegisterNetEvent('MULTIhorses:server:' .. name, fn)
end

--- an ox_lib callback MULTIhorses:server:<name> (fn(source, ...) returns the answer)
function Callback(name, fn)
    Horses.callbacks[name] = fn
    lib.callback.register('MULTIhorses:server:' .. name, fn)
end

--- a core callback MULTIhorses:server:<name> (fn(source, cb, ...))
function CoreCallback(name, fn)
    Horses.coreCallbacks[name] = fn
    Core.Functions.CreateCallback('MULTIhorses:server:' .. name, fn)
end

----------------------------------
-- helpers
----------------------------------
--- the item box in the corner of the screen (MULTIinventory)
function ItemBox(src, name, amount, action)
    pcall(function() MI:ItemBox(src, name, amount, action) end)
end

--- MULTIserver's Discord / console log, when it runs
function ServerLog(name, title, color, message)
    if GetResourceState('MULTIserver') ~= 'started' then return end
    pcall(function() exports.MULTIserver:Log(name, title, color, message) end)
end

--- the saddlebags of a horse: one MULTIinventory inventory per horse id (the same id the earlier MULTIhorses used)
function SaddlebagId(horseid)
    return 'custom:horse_' .. tostring(horseid)
end

local function DeleteSaddlebag(horseid)
    pcall(function() MI:Delete(SaddlebagId(horseid)) end)
end

local function SaddlebagEmpty(horseid)
    local ok, inv = pcall(function() return MI:Exists(SaddlebagId(horseid)) end)
    if not ok or not inv or type(inv.items) ~= 'table' then return true end
    return next(inv.items) == nil
end

local function StableById(stableid)
    for _, s in pairs(Config.StableSettings) do
        if s.stableid == stableid then return s end
    end
end

--- Is the player near this stable (or any stable when stableid is nil)? Config.StableDistance 0 = no check.
function NearStable(src, stableid)
    if not Config.StableDistance or Config.StableDistance <= 0 then return true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, s in pairs(Config.StableSettings) do
        if (stableid == nil or s.stableid == stableid) and #(pos - s.coords) <= Config.StableDistance then
            return true
        end
    end
    return false
end

local function TooFar(src)
    TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_too_far'), type = 'error', duration = 5000 })
end

--- what a stable pays for a horse of this model (nil = not on the list)
function SellPrice(model)
    model = string.lower(tostring(model or ''))
    for _, v in pairs(HorseSettings) do
        if string.lower(tostring(v.horsemodel)) == model then
            return math.floor(v.horseprice * (tonumber(Config.SellBack) or 0.5) * 100 + 0.5) / 100
        end
    end
    return nil
end

----------------------------------
-- security helpers
----------------------------------
local tradeRequests = {} -- Store pending trade requests
local horseWeaponLocks = {} -- per-player lock for weapon store/retrieve
local AcceptHorseTrade -- forwarddeclared; defined below, used by /accepttrade

--- Atomically claim (read + clear) the active horse's stored weapon.
--- The conditional clear means only one concurrent retrieve can win,
--- which closes the double-trigger duplication hole.
local function ClaimStoredWeapon(citizenid)
    local rows = MySQL.query.await('SELECT stored_weapon, stored_weapon_name, stored_weapon_data FROM player_horses WHERE citizenid = ? AND active = 1', { citizenid })
    if not rows or not rows[1] or not rows[1].stored_weapon_name then return nil end
    local cleared = MySQL.update.await('UPDATE player_horses SET stored_weapon = NULL, stored_weapon_name = NULL, stored_weapon_data = NULL WHERE citizenid = ? AND active = 1 AND stored_weapon_name = ?', { citizenid, rows[1].stored_weapon_name })
    if cleared == 0 or cleared == false then return nil end
    return rows[1]
end

--- Give a claimed weapon back; on explicit AddItem failure the row is
--- restored so a full inventory can't permanently eat the weapon.
local function GiveClaimedWeapon(src, Player, claimed)
    local weaponName = claimed.stored_weapon_name
    local weaponData = {}
    if claimed.stored_weapon_data then
        local ok, decoded = pcall(json.decode, claimed.stored_weapon_data)
        if ok and type(decoded) == 'table' then weaponData = decoded end
    end
    local info = weaponData.info or {}
    if weaponData.serial then info.serial = weaponData.serial end

    if Player.Functions.AddItem(weaponName, 1, nil, info) == false then
        MySQL.update('UPDATE player_horses SET stored_weapon = ?, stored_weapon_name = ?, stored_weapon_data = ? WHERE citizenid = ? AND active = 1 AND stored_weapon_name IS NULL',
            { claimed.stored_weapon, weaponName, claimed.stored_weapon_data, Player.PlayerData.citizenid })
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_inventory_full'), type = 'error', duration = 5000 })
        return false
    end
    if Core.Shared.Items[weaponName] then
        ItemBox(src, weaponName, 1, 'add')
    end
    TriggerClientEvent('MULTIhorses:client:equipRetrievedWeapon', src, claimed.stored_weapon)
    SendDiscordLog('economy', 'Weapon Retrieved from Horse', weaponName .. ' retrieved from active horse.', WebhookColors.success, {
        { name = 'Weapon', value = weaponName, inline = true },
    }, src)
    return true
end

local function VerifyHorseOwnership(citizenid, horseid)
    local result = MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE citizenid = ? AND horseid = ?', {citizenid, horseid})
    return result and result > 0
end

local function ValidateComponents(components)
    local HorseComp = lib.load('shared.horse_comp')
    
    if type(components) ~= "table" then
        return false, ''
    end
    
    for category, value in pairs(components) do
        if not HorseComp[category] then
            return false, tostring(category)
        end
        
        if type(value) ~= "number" or value < 0 or value > #HorseComp[category] then
            return false, tostring(category)
        end
    end
    
    return true
end

-- coat colour / markings validation (tint0 0-254, tint1/tint2 0-255, mane/tail 0-254)
local function ValidateCoat(coat)
    if coat == nil then
        return true
    end
    if type(coat) ~= 'table' then
        return false, _L('sv_error_invalid_coat_type')
    end
    local t0 = tonumber(coat.tint0) or 0
    local t1 = tonumber(coat.tint1)
    local t2 = tonumber(coat.tint2)
    if t1 == nil then t1 = 255 end
    if t2 == nil then t2 = 255 end
    local mane = tonumber(coat.mane)
    local tail = tonumber(coat.tail)
    if mane == nil then mane = t0 end
    if tail == nil then tail = t0 end
    if t0 < 0 or t0 > 254 then
        return false, _L('sv_error_invalid_coat_type')
    end
    if t1 < 0 or t1 > 255 then
        return false, _L('sv_error_invalid_coat_type')
    end
    if t2 < 0 or t2 > 255 then
        return false, _L('sv_error_invalid_coat_type')
    end
    if mane < 0 or mane > 254 then
        return false, _L('sv_error_invalid_coat_type')
    end
    if tail < 0 or tail > 254 then
        return false, _L('sv_error_invalid_coat_type')
    end
    return true
end

----------------------------------
-- commands (/findhorse, /fleehorse and /sethorsename are client commands)
----------------------------------
if Config.Commands.AcceptTrade and Config.Commands.AcceptTrade ~= '' then
    lib.addCommand(Config.Commands.AcceptTrade, { help = _L('sv_command_accept_trade') }, function(source)
        local src = source
        if not tradeRequests[src] then
            TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_no_trade_request'), type = 'error', duration = 5000 })
            return
        end
        AcceptHorseTrade(src, nil)
    end)
end

----------------------------------
-- get all horses
----------------------------------
CoreCallback('GetAllHorses', function(source, cb)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then cb(nil) return end
    local horses = MySQL.query.await('SELECT * FROM player_horses WHERE citizenid = ?', { Player.PlayerData.citizenid })
    if horses and horses[1] ~= nil then
        cb(horses)
    else
        cb(nil)
    end
end)

----------------------------------
-- usable items (registered through MULTIinventory at start; see registerItems below)
----------------------------------
local function feedItem(source, item)
    local Player = Core.Functions.GetPlayer(source)
    if not Player then return end
    if Player.Functions.RemoveItem(item.name, 1, item.slot) then
        ItemBox(source, item.name, 1, 'remove')
        GrantFeedXpCredit(source, item.name)
        TriggerClientEvent('MULTIhorses:client:playerfeedhorse', source, item.name)
        SendDiscordLog('horses', 'Horse Fed', 'Player fed their active horse with ' .. item.name .. '.', WebhookColors.info, nil, source)
    end
end

local function reviveItem(source, item)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM player_horses WHERE citizenid = ? AND active = 1', { cid })

    if not result or not result[1] then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_no_active_horse'), type = 'error', duration = 5000 })
        return
    end

    if Player.Functions.RemoveItem(item.name, 1, item.slot) then
        ItemBox(src, item.name, 1, 'remove')
        TriggerClientEvent('MULTIhorses:client:revivehorse', src, item, result[1])
        SendDiscordLog('horses', 'Horse Revived', 'Player revived their active horse (' .. tostring(result[1].name) .. ') using ' .. item.name .. '.', WebhookColors.info, {
            { name = 'Horse', value = tostring(result[1].name), inline = true },
        }, src)
    end
end

local Usables = {
    horse_brush = function(source, item)
        TriggerClientEvent('MULTIhorses:client:playerbrushhorse', source, item.name)
        SendDiscordLog('horses', 'Horse Brushed', 'Player used ' .. item.name .. ' to brush their active horse.', WebhookColors.info, nil, source)
    end,
    horse_lantern = function(source, item)
        TriggerClientEvent('MULTIhorses:client:equipHorseLantern', source, item.name)
    end,
    horse_holster = function(source, item)
        TriggerClientEvent('MULTIhorses:client:equipHorseHolster', source, item.name)
    end,
    horse_reviver = reviveItem,
}
for name in pairs(Config.HorseFeed) do Usables[name] = feedItem end

--- adds the missing items (Config.NewItems) and makes the horse items usable.
--- Registered as built-in: a script that already handles one of these items keeps it.
local function registerItems()
    local added, usable = 0, 0
    for name, def in pairs(Config.NewItems or {}) do
        local ok, exists = pcall(function() return MI:GetItemDef(name) end)
        if ok and not exists then
            local okAdd, res = pcall(function() return MI:RegisterItem(def) end)
            if okAdd and res then added = added + 1 end
        end
    end
    for name, fn in pairs(Usables) do
        local ok = pcall(function()
            if MI:GetItemDef(name) then
                MI:RegisterUsable(name, function(src, stack)
                    fn(src, { name = stack and stack.name or name, slot = stack and stack.slot, info = stack and stack.info })
                end, { builtin = true })
                usable = usable + 1
            end
        end)
        if not ok and Config.Debug then print('[MULTIhorses] could not make ' .. name .. ' usable') end
    end
    print(('[MULTIhorses] %d items added to the registry, %d items usable'):format(added, usable))
end

CreateThread(function()
    local t = 0
    while (GetResourceState('MULTIinventory') ~= 'started' or not MI:IsReady()) and t < 1200 do Wait(250) t = t + 1 end
    if GetResourceState('MULTIinventory') == 'started' then
        registerItems()
    else
        print('^1[MULTIhorses] MULTIinventory is not running: no horse items, no saddlebags^7')
    end
end)

-- MULTIinventory restarted: its list of usable items is empty again
AddEventHandler('onResourceStart', function(res)
    if res ~= 'MULTIinventory' then return end
    CreateThread(function()
        local t = 0
        while not MI:IsReady() and t < 400 do Wait(250) t = t + 1 end
        registerItems()
    end)
end)

----------------------------------
-- buy & active
----------------------------------
On('BuyHorse', function(model, stable, horsename, gender)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

   
    if not horsename or type(horsename) ~= "string" then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_invalid_horse_name'), type = 'error', duration = 5000 })
        return
    end
    horsename = string.gsub(horsename, "[^%w%s%-_]", "")
    if #horsename < 1 or #horsename > 50 then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_horse_name_length'), type = 'error', duration = 5000 })
        return
    end

    local horseInfo = nil
    for k,v in pairs(HorseSettings) do
        if v.horsemodel == model then
            horseInfo = v
            break
        end
    end

    if not horseInfo then
        warn(('MULTIhorses: Buy Horse. Unexpected horse model %s'):format(model))
        return
    end

    local price = horseInfo.horseprice

    -- the stable must exist, sell horses, and the player must stand at it;
    -- gender must be 'male' or 'female' (breeding checks rely on it)
    if type(stable) ~= 'string' or not StableById(stable) then return end
    if not (Config.BuyStables or {})[stable] then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('cl_error_buy_not_here'), type = 'error', duration = 5000 })
        return
    end
    if not NearStable(src, stable) then return TooFar(src) end
    if gender ~= 'male' and gender ~= 'female' then gender = 'male' end

    if not Player.Functions.RemoveMoney(Config.Currency, price) then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_no_cash'), type = 'error', duration = 5000 })
        return
    end

    local horseid = GenerateHorseid()
    local adultAge = (Config.Growth.growthMinutesToAdult or 120) * 60
    local inserted = MySQL.insert.await('INSERT INTO player_horses(stable, citizenid, horseid, name, horse, gender, active, born, age_seconds) VALUES(@stable, @citizenid, @horseid, @name, @horse, @gender, @active, @born, @age_seconds)', {
        ['@stable'] = stable,
        ['@citizenid'] = Player.PlayerData.citizenid,
        ['@horseid'] = horseid,
        ['@name'] = horsename,
        ['@horse'] = model,
        ['@gender'] = gender,
        ['@active'] = false,
        ['@born'] = os.time(),
        ['@age_seconds'] = adultAge
    })
    if not inserted then
        Player.Functions.AddMoney(Config.Currency, price)
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_horse_buy_failed'), type = 'error', duration = 5000 })
        return
    end
    
    TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_success_horse_owned'), type = 'success', duration = 5000 })

    SendDiscordLog('economy', 'Horse Purchased', horsename .. ' (' .. model .. ') bought for the ' .. tostring(stable) .. ' stable.', WebhookColors.success, {
        { name = 'Horse Name', value = horsename, inline = true },
        { name = 'Model', value = model, inline = true },
        { name = 'Price', value = '$' .. tostring(price), inline = true },
        { name = 'Stable', value = tostring(stable), inline = true },
    }, src)
end)

On('storeHorseWeapon', function(weaponHash, weaponName, weaponData)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- SECURITY: weaponName/weaponData are client-supplied. Never trust them
    -- for storage until the item has actually been verified to exist in the
    -- claimed slot and successfully removed from the player's inventory,
    -- otherwise a client could conjure an arbitrary weapon (with arbitrary
    -- serial/info) out of thin air via retrieveHorseWeapon.
    if type(weaponName) ~= 'string' or type(weaponData) ~= 'table' or type(weaponData.slot) ~= 'number' then
        SendDiscordLog('security', 'Invalid storeHorseWeapon Payload', 'Player sent a malformed weapon store payload.', WebhookColors.warning, {
            { name = 'weaponName type', value = type(weaponName), inline = true },
            { name = 'weaponData type', value = type(weaponData), inline = true },
        }, src)
        return
    end

    local slotItem = Player.Functions.GetItemBySlot(weaponData.slot)
    if not slotItem or slotItem.name ~= weaponName then
        SendDiscordLog('security', 'Weapon Slot Mismatch Rejected', 'Claimed weapon did not match the item actually in the given slot.', WebhookColors.warning, {
            { name = 'Claimed Weapon', value = tostring(weaponName), inline = true },
            { name = 'Slot', value = tostring(weaponData.slot), inline = true },
            { name = 'Actual Slot Item', value = slotItem and slotItem.name or 'empty', inline = true },
        }, src)
        return
    end

    if not Player.Functions.RemoveItem(weaponName, 1, weaponData.slot) then
        return
    end

    ItemBox(src, weaponName, 1, 'remove')

    local weaponDataJson = json.encode({
        name = weaponData.name,
        info = weaponData.info,
        serial = weaponData.serial
    })

    MySQL.update('UPDATE player_horses SET stored_weapon = ?, stored_weapon_name = ?, stored_weapon_data = ? WHERE citizenid = ? AND active = 1', {
        weaponHash,
        weaponName,
        weaponDataJson,
        citizenid
    })

    SendDiscordLog('economy', 'Weapon Stored on Horse', weaponName .. ' stored on active horse.', WebhookColors.success, {
        { name = 'Weapon', value = weaponName, inline = true },
        { name = 'Slot', value = tostring(weaponData.slot), inline = true },
    }, src)
end)


On('retrieveHorseWeapon', function()
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end
    if horseWeaponLocks[src] then return end
    horseWeaponLocks[src] = true

    local claimed = ClaimStoredWeapon(Player.PlayerData.citizenid)
    if claimed then
        GiveClaimedWeapon(src, Player, claimed)
    end

    horseWeaponLocks[src] = nil
end)


CoreCallback('getHorseWeapon', function(source, cb)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then cb(nil) return end

    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT stored_weapon, stored_weapon_name, stored_weapon_data FROM player_horses WHERE citizenid = ? AND active = 1', { citizenid })

    if result and result[1] and result[1].stored_weapon then
        local weaponData = {}
        if result[1].stored_weapon_data then
            weaponData = json.decode(result[1].stored_weapon_data) or {}
        end

        cb({
            weaponHash = result[1].stored_weapon,
            weaponName = result[1].stored_weapon_name,
            weaponData = weaponData
        })
    else
        cb(nil)
    end
end)

CoreCallback('getWeaponData', function(source, cb, weaponName)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then cb(nil) return end

    local items = Player.PlayerData.items

    for slot, item in pairs(items) do
        if item and item.name == weaponName then
            cb({
                name = item.name,
                info = item.info or {},
                slot = slot,
                serial = item.info and item.info.serial or nil
            })
            return
        end
    end

    cb(nil)
end)

On('clearHorseWeapon', function()
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end
    if horseWeaponLocks[src] then return end
    horseWeaponLocks[src] = true

    -- only touches the DB when a weapon is actually stored
    local claimed = ClaimStoredWeapon(Player.PlayerData.citizenid)
    if claimed then
        GiveClaimedWeapon(src, Player, claimed)
    end

    horseWeaponLocks[src] = nil
end)
-----------------------------------
-- set horse active (from the stable the horse stands in)
-----------------------------------
On('SetHoresActive', function(id)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end
    id = tonumber(id)
    if not id then return end

    local horse = MySQL.single.await('SELECT id, stable FROM player_horses WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
    if not horse then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_not_own_horse'), type = 'error', duration = 5000 })
        return
    end
    if not NearStable(src, horse.stable) then return TooFar(src) end

    MySQL.update.await('UPDATE player_horses SET active = 0 WHERE citizenid = ? AND active = 1', { Player.PlayerData.citizenid })
    MySQL.update.await('UPDATE player_horses SET active = 1 WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
end)

-----------------------------------
-- set horse unactive (stable it here)
-----------------------------------
On('SetHoresUnActive', function(id, stableid)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end
    id = tonumber(id)
    if not id or type(stableid) ~= 'string' then return end

    -- only real stables, so horses can't be stranded on made-up stable ids
    if not StableById(stableid) then return end
    if not NearStable(src, stableid) then return TooFar(src) end

    local owned = MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE id = ? AND citizenid = ?', {id, Player.PlayerData.citizenid})
    if not owned or owned == 0 then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_not_own_horse'), type = 'error', duration = 5000 })
        return
    end

    MySQL.update('UPDATE player_horses SET active = 0, stable = ? WHERE id = ? AND citizenid = ?', { stableid, id, Player.PlayerData.citizenid })
end)

-----------------------------------
-- store horse when flee is used (Config.StoreFleedHorse)
-----------------------------------
On('fleeStoreHorse', function(stableid)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end
    if type(stableid) ~= 'string' or not StableById(stableid) then return end
    MySQL.update('UPDATE player_horses SET active = 0, stable = ? WHERE citizenid = ? AND active = 1', { stableid, Player.PlayerData.citizenid })
end)

-----------------------------------
-- rename horse (the active horse)
-----------------------------------
On('renameHorse', function(name)
    local src = source
    local Player = Core.Functions.GetPlayer(src)

    if not Player then return end

    if not name or type(name) ~= "string" then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_invalid_horse_name'), type = 'error', duration = 5000 })
        return
    end

    -- letters, digits, spaces, - and _ only
    name = string.gsub(name, "[^%w%s%-_]", "")

    if #name < 1 or #name > 50 then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_horse_name_length'), type = 'error', duration = 5000 })
        return
    end

    local newName = MySQL.update.await('UPDATE player_horses SET name = ? WHERE citizenid = ? AND active = 1', { name, Player.PlayerData.citizenid })

    if not newName or newName == 0 then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_name_change_failed'), type = 'error', duration = 5000 })
        return
    end

    TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_success_name_change', name), type = 'success', duration = 5000 })
end)

----------------------------------
-- horse death (the grace period ran out without a reviver)
----------------------------------
On('HorseDied', function(horseid, horsename)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    -- the horse must be the active one to die
    local horse = MySQL.query.await('SELECT * FROM player_horses WHERE citizenid = ? AND horseid = ? AND active = 1', { cid, horseid })

    if horse and horse[1] then
        horsename = horse[1].name
        if Config.DeleteDeadHorse then
            DeleteSaddlebag(horseid)
            MySQL.update('DELETE FROM player_horses WHERE citizenid = ? AND horseid = ?', {cid, horseid})
            ServerLog('MULTIhorses', _L('sv_log_horse_trainer'), 'red', _L('sv_log_horse_died_line', horsename, cid))
            TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_horse_died'), type = 'error', duration = 7000})
        else
            -- back to its stable; it can be called again
            MySQL.update('UPDATE player_horses SET active = 0 WHERE citizenid = ? AND horseid = ?', {cid, horseid})
            TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_horse_back_to_stable', horsename, StableLabel(horse[1].stable)), type = 'error', duration = 7000})
        end

        SendDiscordLog('horses', 'Horse Died', tostring(horsename) .. ' has died.', WebhookColors.danger, {
            { name = 'Horse Name', value = tostring(horsename), inline = true },
            { name = 'Horse ID', value = tostring(horseid), inline = true },
            { name = 'Deleted', value = tostring(Config.DeleteDeadHorse == true), inline = true },
        }, src)
    end
end)

----------------------------------
-- sell horse ({ horseid = <player_horses.id> } or the id itself)
----------------------------------
On('deletehorse', function(data)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    local horseid = type(data) == 'table' and tonumber(data.horseid) or tonumber(data)
    if not horseid then return end

    local player_horses = MySQL.query.await('SELECT * FROM player_horses WHERE id = ? AND citizenid = ?', { horseid, Player.PlayerData.citizenid })

    if not player_horses or #player_horses == 0 then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_not_own_horse'), type = 'error', duration = 5000 })
        return
    end
    local row = player_horses[1]
    if not NearStable(src, row.stable) then return TooFar(src) end

    -- price first: never delete a horse that pays nothing
    local modelHorse = string.lower(tostring(row.horse or ''))
    local sellprice = SellPrice(modelHorse)
    if not sellprice then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_sell_price_unknown'), type = 'error', duration = 5000 })
        return
    end

    if Config.SellNeedsEmptySaddlebags and not SaddlebagEmpty(row.horseid) then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_saddlebags_not_empty'), type = 'error', duration = 5000 })
        return
    end

    -- delete first, and pay only when this request removed the row
    local affected = MySQL.update.await('DELETE FROM player_horses WHERE id = ? AND citizenid = ?', { horseid, Player.PlayerData.citizenid })
    if affected ~= 1 then return end
    DeleteSaddlebag(row.horseid)

    Player.Functions.AddMoney(Config.Currency, sellprice)
    TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_success_horse_sold_for', sellprice), type = 'success', duration = 5000 })

    SendDiscordLog('economy', 'Horse Sold', 'Horse (model ' .. tostring(modelHorse) .. ') sold back to the stable.', WebhookColors.success, {
        { name = 'Model', value = tostring(modelHorse), inline = true },
        { name = 'Sell Price', value = '$' .. tostring(sellprice), inline = true },
    }, src)
end)


-----------------------------------
-- get horses
-----------------------------------
Callback('GetHorse', function(source, stable)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return {} end
    if type(stable) ~= 'string' then return {} end
    local horses = {}
    local Result = MySQL.query.await('SELECT * FROM player_horses WHERE citizenid=@citizenid AND stable=@stable', { ['@citizenid'] = Player.PlayerData.citizenid, ['@stable'] = stable })
    if not Result then return horses end
    for i = 1, #Result do
        horses[#horses + 1] = Result[i]
    end
    return horses
end)

-----------------------------------
-- get active horse
-----------------------------------
CoreCallback('GetActiveHorse', function(source, cb)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then cb(nil) return end
    local cid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM player_horses WHERE citizenid=@citizenid AND active=@active', { ['@citizenid'] = cid, ['@active'] = 1 })
    if (result[1] ~= nil) then
        cb(result[1])
    else
        cb(nil)
    end
end)

-----------------------------------
-- horse customization
----------------------------------
-- get active horse components callback
CoreCallback('CheckComponents', function(source, cb)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then cb(nil) return end
    local Playercid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM player_horses WHERE citizenid=@citizenid AND active=@active', {
        ['@citizenid'] = Playercid,
        ['@active'] = 1
    })
    if (result[1] ~= nil) then
        cb(result[1])
    else
        cb(nil)
    end
end)

-----------------------------------
-- save saddle
-----------------------------------
On('SaveComponents', function(newComponents, horseid, newCoat)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    -- customization happens at a stable that offers it
    local atCustomStable = false
    for stableid in pairs(Config.CustomizeStables or {}) do
        if NearStable(src, stableid) then atCustomStable = true break end
    end
    if not atCustomStable then return TooFar(src) end

    local valid, error = ValidateComponents(newComponents)
    if not valid then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_invalid_components', error), type = 'error', duration = 5000 })
        return
    end

    local coatValid, coatError = ValidateCoat(newCoat)
    if not coatValid then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_invalid_components', coatError), type = 'error', duration = 5000 })
        return
    end

    local citizenid = Player.PlayerData.citizenid
    
   
    local result = MySQL.query.await('SELECT * FROM player_horses WHERE citizenid=@citizenid AND horseid=@horseid', { ['@citizenid'] = citizenid, ['@horseid'] = horseid })
    local horseData = result[1]
    
    if not horseData then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_not_own_horse'), type = 'error', duration = 5000 })
        return
    end
    
    local newComponents = newComponents or {}
    local currentComponents = {}
    if horseData.components and horseData.components ~= '' then
        local ok, decoded = pcall(json.decode, horseData.components)
        if ok and type(decoded) == 'table' then currentComponents = decoded end
    end
    local price = CalculatePrice(newComponents, currentComponents)

    -- coat price
    local currentCoat = nil
    if horseData.coat ~= nil and horseData.coat ~= '' then
        local ok, decoded = pcall(json.decode, horseData.coat)
        if ok and type(decoded) == 'table' then currentCoat = decoded end
    end
    price = price + CalculateCoatPrice(newCoat, currentCoat)

    if price <= 0 or Player.Functions.RemoveMoney(Config.Currency, price) then
        MySQL.update('UPDATE player_horses SET components = @components WHERE id = @id', {['@components'] = json.encode(newComponents), ['@id'] = horseData.id})
        if newCoat ~= nil then
            local baseTint0 = math.floor(tonumber(newCoat.tint0) or 0)
            local saveCoat = {
                tint0 = baseTint0,
                tint1 = math.floor(tonumber(newCoat.tint1) == nil and 255 or tonumber(newCoat.tint1)),
                tint2 = math.floor(tonumber(newCoat.tint2) == nil and 255 or tonumber(newCoat.tint2)),
                mane = math.floor(tonumber(newCoat.mane) == nil and baseTint0 or tonumber(newCoat.mane)),
                tail = math.floor(tonumber(newCoat.tail) == nil and baseTint0 or tonumber(newCoat.tail)),
                palette = newCoat.palette or 'metaped_tint_horse',
                rainbow = newCoat.rainbow or false,
            }
            MySQL.update('UPDATE player_horses SET coat = @coat WHERE id = @id', {['@coat'] = json.encode(saveCoat), ['@id'] = horseData.id})
        end
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_success_component_saved', price), type = 'success', duration = 5000 })

        SendDiscordLog('horses', 'Horse Customization Saved', 'Saddle/coat customization updated on horse ' .. tostring(horseData.name) .. '.', WebhookColors.info, {
            { name = 'Horse', value = tostring(horseData.name), inline = true },
            { name = 'Price Paid', value = '$' .. tostring(price), inline = true },
        }, src)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_no_cash'), type = 'error', duration = 5000 })
    end
end)

-----------------------------------
-- trade horse (request)
-----------------------------------
On('TradeHorse', function(playerId, horseId)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    local Target = Core.Functions.GetPlayer(playerId)
    
    if not Player or not Target then return end
    
    
    local horse = MySQL.query.await('SELECT * FROM player_horses WHERE horseid = ? AND citizenid = ? AND active = ?', 
        {horseId, Player.PlayerData.citizenid, 1})
    
    if not horse or not horse[1] then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_not_own_or_active'), type = 'error', duration = 5000 })
        return
    end
    
   
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    if not playerPed or not targetPed then return end
    
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 5.0 then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_player_too_far'), type = 'error', duration = 5000 })
        return
    end
    
   
    tradeRequests[playerId] = {
        from = src,
        horseId = horseId,
        horseName = horse[1].name,
        horseModel = horse[1].horse,
        expires = os.time() + 30
    }
    
    TriggerClientEvent('ox_lib:notify', playerId, {
        title = _L('sv_trade_request_title'), 
        description = _L('sv_trade_request_desc', GetPlayerName(src), horse[1].name, Config.Commands.AcceptTrade),
        type = 'info', 
        duration = 30000 
    })
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = _L('sv_trade_request_sent', GetPlayerName(playerId)), 
        type = 'success', 
        duration = 5000 
    })
end)

-----------------------------------
-- trade horse (accept)
-----------------------------------
AcceptHorseTrade = function(acceptorSrc, fromId)
    local src = acceptorSrc
    local trade = tradeRequests[src]

    if not trade then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_no_trade_request'), type = 'error', duration = 5000 })
        return
    end

    if fromId and trade.from ~= fromId then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_invalid_trade_request'), type = 'error', duration = 5000 })
        return
    end

    if os.time() > trade.expires then
        tradeRequests[src] = nil
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_trade_expired'), type = 'error', duration = 5000 })
        return
    end

    local Target = Core.Functions.GetPlayer(src)
    local Sender = Core.Functions.GetPlayer(trade.from)

    if not Target or not Sender then
        tradeRequests[src] = nil
        return
    end

    -- re-validate: sender must still own the horse and it must be active
    local horse = MySQL.query.await('SELECT * FROM player_horses WHERE horseid = ? AND citizenid = ? AND active = ?',
        {trade.horseId, Sender.PlayerData.citizenid, 1})

    if not horse or not horse[1] then
        tradeRequests[src] = nil
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_horse_unavailable'), type = 'error', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', trade.from, {title = _L('sv_error_trade_failed'), type = 'error', duration = 5000 })
        return
    end

    -- proximity re-check at accept time
    local acceptorPed = GetPlayerPed(src)
    local senderPed = GetPlayerPed(trade.from)
    if acceptorPed and senderPed and #(GetEntityCoords(acceptorPed) - GetEntityCoords(senderPed)) > 5.0 then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_player_too_far'), type = 'error', duration = 5000 })
        return
    end

    MySQL.update('UPDATE player_horses SET citizenid = ?, active = ? WHERE horseid = ?', {Target.PlayerData.citizenid, 0, trade.horseId})


    MySQL.update('UPDATE player_horses SET active = ? WHERE citizenid = ? AND active = ?', {0, Target.PlayerData.citizenid, 1})

    TriggerClientEvent('ox_lib:notify', src, {
        title = _L('sv_trade_received', trade.horseName),
        type = 'success',
        duration = 7000
    })

    TriggerClientEvent('ox_lib:notify', trade.from, {
        title = _L('sv_trade_success', GetPlayerName(src)),
        type = 'success',
        duration = 7000
    })

    tradeRequests[src] = nil
end

On('AcceptTrade', function(fromId)
    AcceptHorseTrade(source, fromId)
end)

-----------------------------------
-- move horse between stables
-----------------------------------
On('MoveHorse', function(horseId, newStableId)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    
    local horse = MySQL.query.await('SELECT * FROM player_horses WHERE id = ? AND citizenid = ?', {horseId, citizenid})
    
    if not horse or not horse[1] then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_not_own_horse'), type = 'error', duration = 5000 })
        return
    end

    
    local currentStable = nil
    local newStable = nil
    
    for _, stableConfig in pairs(Config.StableSettings) do
        if stableConfig.stableid == horse[1].stable then
            currentStable = stableConfig
        end
        if stableConfig.stableid == newStableId then
            newStable = stableConfig
        end
    end

    if not newStable then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_invalid_stable'), type = 'error', duration = 5000 })
        return
    end

   
    if horse[1].stable == newStableId then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_horse_already_there'), type = 'error', duration = 5000 })
        return
    end

  
    if not currentStable then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_invalid_stable'), type = 'error', duration = 5000 })
        return
    end
    if not NearStable(src, currentStable.stableid) then return TooFar(src) end

    
    local baseFee = Config.MoveHorseBasePrice
    local feePerMeter = Config.MoveFeePerMeter
    local distance = #(currentStable.coords - newStable.coords)
    local moveFee = math.ceil(baseFee + (distance * feePerMeter))

    
    if not Player.Functions.RemoveMoney(Config.Currency, moveFee) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = _L('sv_error_insufficient_funds'),
            description = _L('cl_move_horse_cost', moveFee),
            type = 'error',
            duration = 5000
        })
        return
    end

    
    MySQL.update('UPDATE player_horses SET stable = ? WHERE id = ? AND citizenid = ?', {newStableId, horseId, citizenid})

    TriggerClientEvent('ox_lib:notify', src, {
        title = _L('sv_success_horse_moved'),
        description = _L('sv_success_horse_moved_desc', horse[1].name, StableLabel(newStableId), moveFee),
        type = 'success',
        duration = 5000
    })

    SendDiscordLog('horses', 'Horse Moved Between Stables', horse[1].name .. ' moved to stable ' .. tostring(newStableId) .. '.', WebhookColors.info, {
        { name = 'Horse', value = horse[1].name, inline = true },
        { name = 'From Stable', value = tostring(horse[1].stable), inline = true },
        { name = 'To Stable', value = tostring(newStableId), inline = true },
        { name = 'Fee Paid', value = '$' .. tostring(moveFee), inline = true },
    }, src)
end)

-----------------------------------
-- generate horseid
-----------------------------------
function GenerateHorseid()
    local UniqueFound = false
    local horseid = nil
    while not UniqueFound do
        horseid = tostring(Core.Shared.RandomStr(3) .. Core.Shared.RandomInt(3)):upper()
        local result = MySQL.prepare.await('SELECT COUNT(*) as count FROM player_horses WHERE horseid = ?', { horseid })
        if result == 0 then
            UniqueFound = true
        end
    end
    return horseid
end

----------------------------------
-- others
----------------------------------
-- Check if Player has horsebrush before brush the horse
On('brushhorse', function(item)
    local src = source
    local Player = Core.Functions.GetPlayer(source)
    if not Player then return end
    if Player.Functions.GetItemByName(item) then
        TriggerClientEvent('MULTIhorses:client:playerbrushhorse', source, item)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_brush', tostring(item)), type = 'error', duration = 5000 })
    end
end)

-----------------------------------
-- horse xp for feeding / brushing (server-authoritative)
-- client sends only the action ('brush' or feed item name),
-- amount is looked up from Config.HorseXp so it can't be spoofed
-----------------------------------
local horseXpCooldowns = {}
local feedXpCredits = {} -- [src] = { item, at }: set when a feed item is consumed

function GrantFeedXpCredit(src, itemName)
    feedXpCredits[src] = { item = itemName, at = os.time() }
end

On('AddHorseXp', function(action)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    if type(action) ~= 'string' then return end

    local xpConfig = Config.HorseXp
    if not xpConfig then return end

    local amount = nil
    local isBrush = (action == 'brush')
    if isBrush then
        amount = tonumber(xpConfig.Brush) or 0
    elseif action == 'drink' then
        amount = tonumber(xpConfig.Drink) or 0
    elseif action == 'graze' then
        amount = tonumber(xpConfig.Graze) or 0
    elseif type(xpConfig.Feed) == 'table' then
        amount = tonumber(xpConfig.Feed[action]) or 0
    end

    if not amount or amount <= 0 then
        SendDiscordLog('security', 'Rejected Horse XP - Unknown Action', 'Player sent an unknown feed/brush action for XP.', WebhookColors.warning, {
            { name = 'Action Sent', value = tostring(action), inline = true },
        }, src)
        return
    end

    -- XP requires a spent item, except brush/drink/graze: brush requires
    -- owning a brush right now; drink/graze consume nothing and are gated
    -- by the per-horse cooldown below.
    if isBrush then
        if not Player.Functions.GetItemByName('horse_brush') then
            SendDiscordLog('security', 'Rejected Horse XP - No Brush', 'Player requested brush XP without owning a brush.', WebhookColors.warning, nil, src)
            return
        end
    elseif action ~= 'drink' and action ~= 'graze' then
        local credit = feedXpCredits[src]
        if not credit or credit.item ~= action or (os.time() - (credit.at or 0)) > 120 then
            SendDiscordLog('security', 'Rejected Horse XP - No Feed Credit', 'Player requested feed XP without consuming the item.', WebhookColors.warning, {
                { name = 'Action Sent', value = tostring(action), inline = true },
            }, src)
            return
        end
        feedXpCredits[src] = nil
    end

    local horse = MySQL.query.await('SELECT id, horseid, name, horsexp FROM player_horses WHERE citizenid = ? AND active = ?', { Player.PlayerData.citizenid, 1 })
    if not horse or not horse[1] then
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_no_active_horse'), type = 'error', duration = 5000 })
        return
    end

    local horseRow = horse[1]
    local maxXp = tonumber(xpConfig.MaxXp) or 2000
    local currentXp = tonumber(horseRow.horsexp) or 0

    if currentXp >= maxXp then
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_horse_xp_maxed'), type = 'info', duration = 5000 })
        return
    end

    local cooldown = tonumber(xpConfig.CooldownSeconds) or 0
    if cooldown > 0 then
        local last = horseXpCooldowns[horseRow.horseid] or 0
        local remaining = cooldown - (os.time() - last)
        if remaining > 0 then
            TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_horse_xp_cooldown', remaining), type = 'error', duration = 5000 })
            SendDiscordLog('security', 'Horse XP Cooldown Hit', 'Player tried to gain horse XP during cooldown.', WebhookColors.warning, {
                { name = 'Horse', value = tostring(horseRow.name), inline = true },
                { name = 'Remaining', value = tostring(remaining) .. 's', inline = true },
            }, src)
            return
        end
    end

    local newXp = math.min(currentXp + amount, maxXp)
    MySQL.update('UPDATE player_horses SET horsexp = ? WHERE id = ? AND citizenid = ?', { newXp, horseRow.id, Player.PlayerData.citizenid })

    if cooldown > 0 then
        horseXpCooldowns[horseRow.horseid] = os.time()
        -- opportunistic prune so the table can't grow unbounded
        local count = 0
        for id, at in pairs(horseXpCooldowns) do
            count = count + 1
            if count > 500 and (os.time() - at) > cooldown then
                horseXpCooldowns[id] = nil
            end
        end
    end

    TriggerClientEvent('MULTIhorses:client:horseXpUpdated', src, newXp, amount)
    TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_horse_xp_gain', amount, horseRow.name), type = 'success', duration = 5000 })

    SendDiscordLog('horses', 'Horse Gained XP', tostring(horseRow.name) .. ' gained +' .. tostring(amount) .. ' XP (' .. (isBrush and 'brush' or tostring(action)) .. ').', WebhookColors.success, {
        { name = 'Horse', value = tostring(horseRow.name), inline = true },
        { name = 'Action', value = isBrush and 'brush' or tostring(action), inline = true },
        { name = 'XP', value = tostring(currentXp) .. ' -> ' .. tostring(newXp), inline = true },
    }, src)
end)

-----------------------------------
-- horse attributes to database
-----------------------------------
On('sethorseAttributes', function(dirt)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    dirt = tonumber(dirt)
    if not dirt or dirt < 0 or dirt > 100 then return end

    local activehorse = MySQL.scalar.await('SELECT id FROM player_horses WHERE citizenid = ? AND active = ?', {Player.PlayerData.citizenid, true})
    if not activehorse then return end
    MySQL.update('UPDATE player_horses SET dirt = ? WHERE id = ? AND citizenid = ?', { dirt, activehorse, Player.PlayerData.citizenid })
end)

-- SECURITY: the second arg is ignored on purpose. Client-sent entity/player
-- handles are meaningless server-side, and passing them straight into
-- SetPlayerRoutingBucket let a modified client bucket arbitrary players.
On('SetPlayerBucket', function(random, _ped)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end
    if random then
        local BucketID = Core.Shared.RandomInt(1000, 9999)
        SetRoutingBucketPopulationEnabled(BucketID, false)
        SetPlayerRoutingBucket(src, BucketID)
    else
        SetPlayerRoutingBucket(src, 0)
    end
end)

---------------------------------
-- horse inventory (saddlebags)
---------------------------------
local function SaddlebagSize(horsexp)
    local lvl
    if horsexp <= 99 then lvl = 1
    elseif horsexp <= 199 then lvl = 2
    elseif horsexp <= 299 then lvl = 3
    elseif horsexp <= 399 then lvl = 4
    elseif horsexp <= 499 then lvl = 5
    elseif horsexp <= 999 then lvl = 6
    elseif horsexp <= 1399 then lvl = 7
    elseif horsexp <= 1699 then lvl = 8
    elseif horsexp <= 1899 then lvl = 9
    else lvl = 10 end
    return Config['Level' .. lvl .. 'InvWeight'], Config['Level' .. lvl .. 'InvSlots']
end

On('openhorseinventory', function(horseid)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    -- the horse must be the player's own
    local horse = MySQL.query.await('SELECT * FROM player_horses WHERE horseid = ? AND citizenid = ?', {horseid, Player.PlayerData.citizenid})
    if not horse or not horse[1] then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_not_own_horse'), type = 'error', duration = 5000 })
        return
    end

    -- a saddle and saddlebags must be on the horse (Config.SaddlebagsNeedTack)
    if Config.SaddlebagsNeedTack then
        local components = {}
        if horse[1].components and horse[1].components ~= '' then
            local ok, decoded = pcall(json.decode, horse[1].components)
            if ok and type(decoded) == 'table' then components = decoded end
        end
        if (tonumber(components.Saddles) or 0) <= 0 or (tonumber(components.Saddlebags) or 0) <= 0 then
            TriggerClientEvent('ox_lib:notify', src, {title = _L('cl_error_no_saddlebags'), type = 'error', duration = 5000 })
            return
        end
    end

    -- size by horse level (worked out here, not by the client)
    local invWeight, invSlots = SaddlebagSize(tonumber(horse[1].horsexp) or 0)
    local data = { label = _L('sv_horse_inventory', horse[1].name), maxWeight = invWeight, slots = invSlots }
    local ok, opened = pcall(function() return MI:Open(src, SaddlebagId(horse[1].horseid), data) end)
    if not ok or not opened then
        if Config.Debug then print('[MULTIhorses] saddlebags of ' .. tostring(horseid) .. ' did not open: ' .. tostring(opened)) end
    end
end)

--------------------------------------
-- horse shop (the stable page shows it; the server checks every purchase)
--------------------------------------
local function ShopPrices()
    local prices, amounts = {}, {}
    for _, shopItem in ipairs(Config.ShopItems) do
        prices[shopItem.name] = shopItem.price
        amounts[shopItem.name] = shopItem.amount
    end
    return prices, amounts
end

On('buyShopItems', function(items, total)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    if type(items) ~= 'table' or #items == 0 then return end
    if not NearStable(src) then return TooFar(src) end

    -- quantities must be whole numbers above 0 (a negative quantity would pay the player)
    for _, item in ipairs(items) do
        if type(item) ~= 'table' or type(item.quantity) ~= 'number' or item.quantity <= 0 or item.quantity ~= math.floor(item.quantity) or item.quantity > 100 then
            TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_invalid_quantity'), type = 'error', duration = 5000})
            SendDiscordLog('security', 'Rejected Shop Purchase - Invalid Quantity', 'Player attempted to buy a shop item with an invalid quantity.', WebhookColors.warning, {
                { name = 'Item', value = tostring(type(item) == 'table' and item.name), inline = true },
                { name = 'Quantity Sent', value = tostring(type(item) == 'table' and item.quantity), inline = true },
            }, src)
            return
        end
    end

    -- only items the shop sells; the total is worked out here
    local shopPrices, shopAmounts = ShopPrices()
    local calcTotal = 0
    for _, item in ipairs(items) do
        local unitPrice = shopPrices[item.name]
        if not unitPrice then
            TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_invalid_item'), type = 'error', duration = 5000})
            SendDiscordLog('security', 'Rejected Shop Purchase - Unknown Item', 'Player attempted to buy an item not sold in the horse shop.', WebhookColors.warning, {
                { name = 'Item', value = tostring(item.name), inline = true },
            }, src)
            return
        end
        if shopAmounts[item.name] and item.quantity > shopAmounts[item.name] then
            TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_invalid_quantity'), type = 'error', duration = 5000})
            return
        end
        calcTotal = calcTotal + (unitPrice * item.quantity)
    end

    if calcTotal <= 0 or calcTotal ~= total then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_price_mismatch'), type = 'error', duration = 5000})
        SendDiscordLog('security', 'Rejected Shop Purchase - Price Mismatch', 'Client-sent total did not match the server-calculated price.', WebhookColors.warning, {
            { name = 'Server Calculated Total', value = '$' .. tostring(calcTotal), inline = true },
            { name = 'Client Sent Total', value = '$' .. tostring(total), inline = true },
        }, src)
        return
    end

    if not Player.Functions.RemoveMoney(Config.Currency, calcTotal) then
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_no_cash'), type = 'error', duration = 5000})
        return
    end

    local refund = 0
    for _, item in ipairs(items) do
        if Player.Functions.AddItem(item.name, item.quantity) then
            ItemBox(src, item.name, item.quantity, 'add')
        else
            refund = refund + shopPrices[item.name] * item.quantity
        end
    end
    if refund > 0 then
        Player.Functions.AddMoney(Config.Currency, refund)
        TriggerClientEvent('ox_lib:notify', src, {title = _L('sv_error_shop_no_room', refund), type = 'error', duration = 5000})
    end
    TriggerClientEvent('MULTIhorses:client:shopPurchaseSuccess', src)

    local itemSummary = {}
    for _, item in ipairs(items) do
        itemSummary[#itemSummary + 1] = tostring(item.quantity) .. 'x ' .. tostring(item.name)
    end
    SendDiscordLog('economy', 'Horse Shop Purchase', table.concat(itemSummary, ', '), WebhookColors.success, {
        { name = 'Total Paid', value = '$' .. tostring(calcTotal - refund), inline = true },
    }, src)
end)

-- the shop list with labels and pictures, for the stable page
On('openShop', function()
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end
    if not NearStable(src) then return TooFar(src) end

    local list = {}
    for _, shopItem in ipairs(Config.ShopItems) do
        local ok, def = pcall(function() return MI:GetItemDef(shopItem.name) end)
        def = ok and def or nil
        list[#list + 1] = {
            name = shopItem.name,
            label = def and def.label or shopItem.name,
            description = def and def.description or '',
            image = def and def.image or (shopItem.name .. '.png'),
            price = shopItem.price,
            amount = shopItem.amount,
        }
    end
    TriggerClientEvent('MULTIhorses:client:openShop', src, list)
end)

----------------------------------
-- old age (Config.StarterHorseDieAge, Config.HorseDieAge)
----------------------------------
local function OldAgeTelegram(ownercid, horsename)
    if not Config.OldAgeTelegram then return end
    MySQL.insert('INSERT INTO telegrams (citizenid, recipient, sender, sendername, subject, sentDate, message) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        ownercid,
        _L('sv_telegram_owner'),
        '22222222',
        _L('sv_telegram_stables'),
        _L('sv_telegram_away', horsename),
        os.date('%x'),
        _L('sv_telegram_inform', horsename),
    })
end

local function HorseOldAge(row, daysPassed, starter)
    local horsename = row.name
    local ownercid = row.citizenid

    DeleteSaddlebag(row.horseid)
    MySQL.update('DELETE FROM player_horses WHERE id = ?', { row.id })
    ServerLog('MULTIhorses', _L('sv_log_horse_trainer'), 'red', _L('sv_log_horse_old_age_line', horsename, ownercid))

    SendDiscordLog('horses', starter and 'Starter Horse Expired (Upkeep)' or 'Horse Expired (Upkeep)', horsename .. ' aged out and was removed from stables.', WebhookColors.warning, {
        { name = 'Horse', value = horsename, inline = true },
        { name = 'Owner CitizenID', value = tostring(ownercid), inline = true },
        { name = 'Days Passed', value = tostring(daysPassed), inline = true },
    })

    OldAgeTelegram(ownercid, horsename)
end

local upkeepRunning = false
UpkeepInterval = function()
    -- one sweep at a time (re-armed at the end)
    if upkeepRunning then return end
    upkeepRunning = true

    local ok, err = pcall(function()
        local result = MySQL.query.await('SELECT id, horseid, horse, name, citizenid, born FROM player_horses') or {}
        local now = os.time()
        for i = 1, #result do
            local row = result[i]
            -- rows without a birth time are skipped
            local born = tonumber(row.born) or 0
            if born > 0 then
                local daysPassed = math.floor((now - born) / (24 * 60 * 60))
                if row.horse == Config.StarterHorseModel then
                    if (Config.StarterHorseDieAge or 0) > 0 and daysPassed >= Config.StarterHorseDieAge then
                        HorseOldAge(row, daysPassed, true)
                    end
                elseif (Config.HorseDieAge or 0) > 0 and daysPassed >= Config.HorseDieAge then
                    HorseOldAge(row, daysPassed, false)
                end
            end
        end
    end)
    if not ok then print('^1[MULTIhorses] old-age check failed: ' .. tostring(err) .. '^7') end

    upkeepRunning = false
    if Config.EnableServerNotify then
        print(_L('sv_print'))
    end

    SetTimeout(Config.CheckCycle * (60 * 1000), UpkeepInterval)
end

-----------------------------------
-- BREEDING SYSTEM
-----------------------------------

local function GetRandomHorseModel()
    local models = Config.HorseModels
    if not models or #models == 0 then return 'a_c_horse_morgan_bay' end
    return models[math.random(#models)]
end

local function GetRandomFoalName()
    local prefixes = { 'Little', 'Tiny', 'Baby', 'Sweet', 'Lucky', 'Happy', 'Sunny', 'Storm', 'Shadow', 'Star', 'Dusty', 'Buddy' }
    local suffixes = { 'Star', 'Storm', 'Wind', 'Heart', 'Spirit', 'Dream', 'Bolt', 'Flash', 'Cloud', 'Moon', 'Fire', 'Rose' }
    return prefixes[math.random(#prefixes)] .. ' ' .. suffixes[math.random(#suffixes)]
end

-- Get all horses for a player (for stallion selection)
Callback('GetPlayerHorses', function(source)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return {} end
    local cid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT id, name, horse, gender, age_seconds, pregnant_until FROM player_horses WHERE citizenid = ?', { cid })
    return result or {}
end)

-- Breed horse event
On('breedHorse', function(mareId, stallionId)
    local src = source
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end
    if not Config.Breeding or not Config.Breeding.enabled then
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_breeding_disabled'), type = 'error', duration = 5000 })
        return
    end

    if Config.Breeding.requiredJob and Config.Breeding.requiredJob ~= '' and Player.PlayerData.job.name ~= Config.Breeding.requiredJob then
        TriggerClientEvent('ox_lib:notify', src, { title = _L('err_breeder_required'), type = 'error', duration = 5000 })
        return
    end

    local cid = Player.PlayerData.citizenid

    -- Fetch mare
    local mare = MySQL.query.await('SELECT * FROM player_horses WHERE id = ? AND citizenid = ?', { mareId, cid })
    if not mare or not mare[1] then
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_not_own_horse'), type = 'error', duration = 5000 })
        return
    end
    mare = mare[1]

    -- Validate mare gender
    if Config.Breeding.requireOppositeSex and mare.gender ~= 'female' then
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_breed_select_mare'), type = 'error', duration = 5000 })
        return
    end

    -- Check mare maturity
    local maturitySecs = (Config.Breeding.maturityMinutes or 60) * 60
    local mareAge = mare.age_seconds or 0
    if mareAge < maturitySecs then
        local minsLeft = math.ceil((maturitySecs - mareAge) / 60)
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_mare_not_mature', minsLeft), type = 'error', duration = 5000 })
        return
    end

    -- Check mare not already pregnant
    if mare.pregnant_until and mare.pregnant_until > os.time() then
        local remaining = math.ceil((mare.pregnant_until - os.time()) / 60)
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_already_pregnant', remaining), type = 'error', duration = 5000 })
        return
    end

    -- Check cooldown
    local cooldownSecs = (Config.Breeding.breedCooldownMinutes or 60) * 60
    if mare.last_bred and (os.time() - mare.last_bred) < cooldownSecs then
        local remaining = math.ceil((cooldownSecs - (os.time() - mare.last_bred)) / 60)
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_breeding_cooldown', remaining), type = 'error', duration = 5000 })
        return
    end

    -- Fetch stallion
    local stallion = MySQL.query.await('SELECT * FROM player_horses WHERE id = ? AND citizenid = ?', { stallionId, cid })
    if not stallion or not stallion[1] then
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_not_own_stallion'), type = 'error', duration = 5000 })
        return
    end
    stallion = stallion[1]

    -- Validate stallion gender
    if Config.Breeding.requireOppositeSex and stallion.gender ~= 'male' then
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_breed_must_be_male'), type = 'error', duration = 5000 })
        return
    end

    -- Check stallion maturity
    local stallionAge = stallion.age_seconds or 0
    if stallionAge < maturitySecs then
        TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_stallion_not_mature'), type = 'error', duration = 5000 })
        return
    end

    -- Remove hay cost
    local hayCost = Config.Breeding.hayCost or 0
    if hayCost > 0 then
        local hasItem = Player.Functions.GetItemByName('hay')
        if not hasItem or hasItem.amount < hayCost then
            TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_need_hay', hayCost), type = 'error', duration = 5000 })
            return
        end
        if not Player.Functions.RemoveItem('hay', hayCost) then
            TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_error_need_hay', hayCost), type = 'error', duration = 5000 })
            return
        end
        ItemBox(src, 'hay', hayCost, 'remove')
    end

    -- Set pregnancy
    local gestationSecs = (Config.Breeding.gestationMinutes or 30) * 60
    local now = os.time()
    local pregnantUntil = now + gestationSecs

    MySQL.update.await('UPDATE player_horses SET pregnant_until = ?, last_bred = ? WHERE id = ?', { pregnantUntil, now, mareId })

    local gestMins = Config.Breeding.gestationMinutes or 30
    TriggerClientEvent('ox_lib:notify', src, { title = _L('sv_success_breeding_started', gestMins), type = 'success', duration = 7000 })
end)

-- Birth processing loop
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()

        local readyMothers = MySQL.query.await('SELECT * FROM player_horses WHERE pregnant_until IS NOT NULL AND pregnant_until <= ?', { now })

        if readyMothers and #readyMothers > 0 then
            for _, mother in ipairs(readyMothers) do
                local cid = mother.citizenid
                local foalModel = GetRandomHorseModel()
                local foalGender = math.random(0, 1) == 0 and 'male' or 'female'
                local foalName = GetRandomFoalName()
                local horseid = tostring(Core.Shared.RandomStr(3) .. Core.Shared.RandomInt(3)):upper()
                local foalStable = mother.stable or Config.DefaultStable or 'valentine'

                -- Ensure unique horseid
                local attempts = 0
                while attempts < 10 do
                    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE horseid = ?', { horseid })
                    if exists == 0 then break end
                    horseid = tostring(Core.Shared.RandomStr(3) .. Core.Shared.RandomInt(3)):upper()
                    attempts = attempts + 1
                end

                MySQL.insert.await('INSERT INTO player_horses(stable, citizenid, horseid, name, horse, gender, active, born, age_seconds) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)', {
                    foalStable, cid, horseid, foalName, foalModel, foalGender, false, now, 0
                })

                -- Clear mother pregnancy
                MySQL.update.await('UPDATE player_horses SET pregnant_until = NULL WHERE id = ?', { mother.id })

                -- Find the owner online and notify
                for _, playerId in ipairs(GetPlayers()) do
                    local pid = tonumber(playerId)
                    if pid then
                        local p = Core.Functions.GetPlayer(pid)
                        if p and p.PlayerData.citizenid == cid then
                            TriggerClientEvent('ox_lib:notify', pid, {
                                title = _L('sv_success_foal_born_title'),
                                description = _L('sv_success_foal_born_desc', foalGender == 'female' and _L('wh_gender_female') or _L('wh_gender_male'), foalModel, foalName, StableLabel(foalStable)),
                                type = 'success',
                                duration = 10000
                            })
                            break
                        end
                    end
                end

                print(('[MULTIhorses] Foal born: %s (%s) for player %s at %s'):format(foalName, foalModel, cid, foalStable))
            end
        end
    end
end)

-- Age tick loop (increments age_seconds for all horses)
CreateThread(function()
    while true do
        Wait(30000)
        MySQL.update('UPDATE player_horses SET age_seconds = age_seconds + 30 WHERE age_seconds IS NOT NULL')
    end
end)

-----------------------------------
-- end of breeding system
-----------------------------------

SetTimeout(Config.CheckCycle * (60 * 1000), UpkeepInterval)

-- ============================================================
-- MULTIinventory :: the player's satchel, start-up and saving (server)
-- The satchel 'player:<citizenid>' is kept in players.inventory in RSG's
-- shape, and mirrored into RSG's Player.PlayerData.items after every change.
-- ============================================================

local Inv = MULTIInv

-- ------------------------------------------------------------
-- PlayerData.items mirror
-- ------------------------------------------------------------

local syncing = {}       -- src -> true while we are writing PlayerData.items
local batchDepth = 0
local batched = {}       -- inventories whose sync waits for the end of a batch

function Inv.SyncPlayer(inv)
    if not inv.ownerSrc then return end
    if batchDepth > 0 then batched[inv.id] = inv return end
    local P = Inv.GetPlayer(inv.ownerSrc)
    if not P or P.PlayerData.citizenid ~= inv.citizenid then return end
    syncing[inv.ownerSrc] = true
    pcall(P.Functions.SetPlayerData, 'items', inv.items)
    syncing[inv.ownerSrc] = nil
end

--- Runs fn with player syncs held back until it ends (one PlayerData update per player).
function Inv.Batch(fn, ...)
    batchDepth = batchDepth + 1
    local res = table.pack(pcall(fn, ...))
    batchDepth = batchDepth - 1
    if batchDepth == 0 then
        local list = batched
        batched = {}
        for _, inv in pairs(list) do Inv.SyncPlayer(inv) end
    end
    if not res[1] then error(res[2], 0) end
    return table.unpack(res, 2, res.n)
end

local function sameItems(a, b)
    a, b = a or {}, b or {}
    for slot, s in pairs(a) do
        local o = b[slot]
        if not o or o.name ~= s.name or o.amount ~= s.amount or not Inv.InfoEqual(o.info, s.info) then return false end
    end
    for slot in pairs(b) do if not a[slot] then return false end end
    return true
end

-- A script wrote Player.PlayerData.items itself (Player.Functions.SetPlayerData('items', ...)).
-- rsg-inventory reads PlayerData.items every time, so such writes count there; adopt them here.
AddEventHandler('RSGCore:Player:SetPlayerData', function(PlayerData)
    if type(PlayerData) ~= 'table' then return end
    local src = tonumber(PlayerData.source)
    if not src or syncing[src] then return end
    local id = Inv.BySrc[src]
    local inv = id and Inv.List[id]
    if not inv or inv.citizenid ~= PlayerData.citizenid then return end
    if tonumber(PlayerData.slots) and tonumber(PlayerData.slots) > 0 then inv.slots = tonumber(PlayerData.slots) end
    if tonumber(PlayerData.weight) and tonumber(PlayerData.weight) > 0 then inv.maxWeight = tonumber(PlayerData.weight) end
    local vm = type(PlayerData.metadata) == 'table' and type(PlayerData.metadata.vorp) == 'table' and PlayerData.metadata.vorp
    if vm then inv.invCapacity = tonumber(vm.invCapacity) end
    local incoming = Inv.NormalizeItems(PlayerData.items)
    if not sameItems(incoming, inv.items) then
        Inv.Debug(('adopting a direct PlayerData.items write for %s'):format(inv.id))
        Inv.SetItems(inv, incoming, 'PlayerData.items write')
    end
end)

-- ------------------------------------------------------------
-- load / bind / unload
-- ------------------------------------------------------------

local function waitReady()
    local t = 0
    while not Inv.ready and t < 300 do Wait(100) t = t + 1 end
end

--- Loads a character's satchel. With a source it becomes the live satchel; without one
--- (offline player) the items are only read and returned. → items (slot-keyed)
function Inv.LoadPlayer(src, citizenid)
    if type(citizenid) ~= 'string' then return {} end
    waitReady()
    local id = 'player:' .. citizenid
    local inv = Inv.List[id]
    if inv then
        if src then Inv.BindPlayer(src, inv) end
        return inv.items
    end
    local raw = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    local items, missing = Inv.LoadItems_(raw or '[]', Config.Decay.WhileOffline and 1 or 0)
    if #missing > 0 then
        print(('^3[MULTIinventory] items removed from %s (no longer exist): %s^7'):format(citizenid, table.concat(missing, ', ')))
    end
    if not src then return items end
    inv = Inv.Create(id, { label = citizenid })
    inv.citizenid = citizenid
    inv.items = items
    Inv.BindPlayer(src, inv)
    return inv.items
end

function Inv.BindPlayer(src, inv)
    src = tonumber(src)
    if inv.ownerSrc and inv.ownerSrc ~= src then Inv.BySrc[inv.ownerSrc] = nil end
    inv.ownerSrc = src
    Inv.BySrc[src] = inv.id
end

--- Saves and forgets a satchel (logout, leave).
function Inv.UnloadPlayer(src, await)
    local id = Inv.BySrc[src]
    if not id then return end
    Inv.Close(src)
    local inv = Inv.List[id]
    Inv.BySrc[src] = nil
    if inv and inv.ownerSrc == src then
        Inv.Save(inv, await)
        Inv.List[id] = nil
    end
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local pd = Player and Player.PlayerData
    if not pd then return end
    local src = pd.source
    local inv = Inv.List['player:' .. pd.citizenid]
    if not inv then
        Inv.LoadPlayer(src, pd.citizenid)
        inv = Inv.List['player:' .. pd.citizenid]
    end
    Inv.BindPlayer(src, inv)
    inv.slots = tonumber(pd.slots) and tonumber(pd.slots) > 0 and tonumber(pd.slots) or Config.Player.Slots
    inv.maxWeight = tonumber(pd.weight) and tonumber(pd.weight) > 0 and tonumber(pd.weight) or Config.Player.MaxWeight
    inv.maxCount = Config.Player.MaxCount
    local vm = type(pd.metadata) == 'table' and type(pd.metadata.vorp) == 'table' and pd.metadata.vorp
    inv.invCapacity = vm and tonumber(vm.invCapacity) or nil
    inv.label = pd.charinfo and pd.charinfo.firstname and (pd.charinfo.firstname .. ' ' .. (pd.charinfo.lastname or '')) or pd.citizenid
    Inv.SendUpdate(src, inv)
    TriggerEvent('MULTIinventory:playerLoaded', src, inv.id)
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    Inv.UnloadPlayer(tonumber(src), false)
end)

AddEventHandler('playerDropped', function()
    local src = source
    Inv.Close(src)
    -- the core saves on drop (SaveInventory); forget the satchel afterwards
    SetTimeout(3000, function() Inv.UnloadPlayer(src, false) end)
end)

-- ------------------------------------------------------------
-- start-up
-- ------------------------------------------------------------

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `inventories` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `identifier` VARCHAR(255) NOT NULL,
      `items` LONGTEXT DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `identifier` (`identifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `multiinventory_kv` (
      `k` VARCHAR(64) NOT NULL,
      `v` VARCHAR(255) NOT NULL,
      PRIMARY KEY (`k`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function tableExists(name)
    local ok, r = pcall(MySQL.query.await, 'SHOW TABLES LIKE ?', { name })
    return ok and type(r) == 'table' and #r > 0
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    for _, q in ipairs(SCHEMA) do MySQL.query.await(q) end
    Inv.hasPlayerWeapons = tableExists('player_weapons')

    local wid = MySQL.scalar.await("SELECT v FROM multiinventory_kv WHERE k = 'weapon_id'")
    Inv.Weapon._SetCounter(tonumber(wid) or 0)

    Inv.LoadItems(true)

    local rows = MySQL.query.await('SELECT identifier, items FROM inventories') or {}
    for _, row in ipairs(rows) do
        local id = Inv.FromDbKey(row.identifier)
        local inv = Inv.List[id] or Inv.Create(id)
        inv.items = Inv.LoadItems_(row.items or '[]', 1)
    end
    Inv.Debug(('%d stashes loaded'):format(#rows))

    -- resource restart: the core still has everyone's items, take them back
    local core = Inv.Core()
    local ok, players = pcall(core.Functions.GetRSGPlayers)
    if ok and type(players) == 'table' then
        for src, P in pairs(players) do
            local pd = P.PlayerData
            if pd and pd.citizenid then
                local slots = tonumber(pd.slots) or 0
                local weight = tonumber(pd.weight) or 0
                local inv = Inv.Create('player:' .. pd.citizenid, {
                    label = pd.citizenid,
                    slots = slots > 0 and slots or nil,
                    maxWeight = weight > 0 and weight or nil,
                })
                inv.citizenid = pd.citizenid
                inv.items = Inv.LoadItems_(Inv.Compact(Inv.NormalizeItems(pd.items)), 0)
                Inv.BindPlayer(tonumber(src), inv)
                pcall(function() Player(tonumber(src)).state.inv_busy = false end)
            end
        end
    end

    Inv.ready = true
    TriggerEvent('MULTIinventory:ready')
    print('^2[MULTIinventory] ready^7')
end)

-- autosave
CreateThread(function()
    while true do
        Wait(math.max(10, Config.AutoSaveSeconds) * 1000)
        if Inv.ready then Inv.SaveAll(false) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, inv in pairs(Inv.List) do
        if inv.type == 'player' or inv.dirty then Inv.Save(inv, false) end
    end
end)
AddEventHandler('txAdmin:events:serverShuttingDown', function() Inv.SaveAll(false) end)

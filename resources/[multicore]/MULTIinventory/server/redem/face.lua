-- ============================================================
-- MULTIinventory :: redemrp_inventory face (server)
-- Written from RedEM:RP's public API (redemrp_inventory 2023); no
-- RedEM:RP code is used. GPL v3, part of MULTIcore by RINGO (RINGOscripting).
--
-- RedEM:RP scripts get the API with
--   TriggerEvent('redemrp_inventory:getData', function(Inv) ... end)
-- and work with Inv.getItem(src, name, meta).AddItem / RemoveItem / ItemAmount.
-- Differences from stock redemrp_inventory, all on the safe side:
--   * ItemAmount counts every stack of the item, not only the first one
--   * AddItem never drops what does not fit on the ground unless makepickup is true
--   * an unknown item gives ItemAmount 0 and AddItem false (stock returns -1)
-- Item names are matched without case: 'WEAPON_REVOLVER_CATTLEMAN' is
-- MULTIcore's weapon_revolver_cattleman.
-- ============================================================

local Inv = MULTIInv

--- A MULTIcore item as RedEM:RP describes it (weight in kg).
local function itemInfo(def)
    if not def then return nil end
    local weapon = def.type == 'weapon'
    return {
        label = def.label,
        description = def.description or '',
        weight = (tonumber(def.weight) or 0) / 1000,
        canBeDropped = def.delete ~= false,
        canBeUsed = def.useable == true or weapon,
        limit = tonumber(def.limit) or (def.unique and 1 or 1000),
        imgsrc = def.image and ('items/' .. def.image) or nil,
        type = weapon and 'item_weapon' or 'item_standard',
        weaponHash = weapon and joaat(def.name:upper()) or nil,
    }
end

local function playerInv(src)
    local id = Inv.PlayerInv(tonumber(src))
    return id and Inv.List[id], id
end

local function emptyMeta(meta) return type(meta) ~= 'table' or next(meta) == nil end

--- Every stack of an item that matches meta (any stack when meta is empty).
local function stacksOf(inv, name, meta)
    local out = {}
    for _, st in pairs(inv and inv.items or {}) do
        if st.name == name and (emptyMeta(meta) or Inv.InfoEqual(st.info or {}, meta)) then out[#out + 1] = st end
    end
    return out
end

local API = {}

--- ItemData for one item of one player (never nil).
function API.getItem(src, name, meta)
    src = tonumber(src)
    name = type(name) == 'string' and name:lower() or ''
    local def = Inv.Items[name]
    local inv, invId = playerInv(src)
    local stacks = stacksOf(inv, name, meta)
    local total = 0
    for _, st in ipairs(stacks) do total = total + (tonumber(st.amount) or 0) end

    local data = {
        ItemAmount = total,
        ItemInfo = itemInfo(def),
        ItemMeta = stacks[1] and stacks[1].info or (type(meta) == 'table' and meta or {}),
    }

    --- Adds amount (for a weapon: the weapon, with amount rounds loaded). makepickup = true drops what does not fit.
    function data.AddItem(amount, makepickup)
        amount = math.floor(tonumber(amount) or 1)
        if not def or not invId or amount < 1 then return false end
        local count, info = amount, (not emptyMeta(meta)) and Inv.DeepCopy(meta) or nil
        if def.type == 'weapon' then
            info = info or {}
            info.ammo = amount
            count = 1
        end
        local ok, err = Inv.AddItem(invId, name, count, info, nil, 'redem')
        if ok then
            Inv.ItemBox(src, name, count, 'add')
            return true
        end
        if makepickup == true and (err == 'too_heavy' or err == 'no_space' or err == 'limit') then
            return Inv.ForceDrop(src, name, count, info, 'redem') and true or false
        end
        return false
    end

    function data.RemoveItem(amount)
        amount = math.floor(tonumber(amount) or 1)
        if not def or not invId or amount < 1 or total < amount then return false end
        local match = (not emptyMeta(meta)) and meta or nil
        local ok = Inv.RemoveItem(invId, name, amount, nil, match, 'redem')
        if ok then
            Inv.ItemBox(src, name, amount, 'remove')
            if def.type == 'weapon' then TriggerClientEvent('MULTIinventory:client:weaponRemoved', src, name, nil) end
        end
        return ok and true or false
    end

    if stacks[1] then
        function data.ChangeMeta(newMeta)
            if type(newMeta) ~= 'table' then return false end
            return Inv.ReplaceInfo(invId, stacks[1].slot, newMeta) and true or false
        end
        function data.getAllItemOfName(n)
            local list = {}
            for _, st in ipairs(stacksOf(inv, (n or name):lower())) do
                list[#list + 1] = { name = st.name, amount = st.amount, meta = st.info or {} }
            end
            return list
        end
    end
    return data
end

function API.getItemData(name)
    return itemInfo(type(name) == 'string' and Inv.Items[name:lower()] or nil)
end

--- The player's whole satchel as RedEM:RP lists it.
function API.getPlayerInventory(src)
    local inv = playerInv(src)
    local out = {}
    for _, st in pairs(inv and inv.items or {}) do
        local info = itemInfo(Inv.Items[st.name]) or {}
        out[#out + 1] = {
            name = st.name, amount = st.amount, meta = st.info or {},
            label = info.label, type = info.type, weaponHash = info.weaponHash,
            weight = info.weight, description = info.description, imgsrc = info.imgsrc,
        }
    end
    return out
end

function API.removePlayerInventory(src)
    local inv = playerInv(src)
    if inv then Inv.Clear(inv, nil, 'redem') end
end

MULTIRedemInv = API

AddEventHandler('redemrp_inventory:getData', function(cb) if cb then cb(API) end end)

-- ------------------------------------------------------------
-- exports['redemrp_inventory']:GetItemsList() and friends
-- ------------------------------------------------------------

local function export(name, fn)
    AddEventHandler(('__cfx_export_redemrp_inventory_%s'):format(name), function(setCB) setCB(fn) end)
end

export('GetItemsList', function()
    local out = {}
    for name, def in pairs(Inv.Items) do
        local info = itemInfo(def)
        out[name] = info
        if info.type == 'item_weapon' then out[name:upper()] = info end
    end
    return out
end)

export('GetStashWeight', function(id)
    local inv = type(id) == 'string' and Inv.Exists('stash:redem_' .. id)
    return inv and Inv.Weight(inv) / 1000 or 0
end)

-- ------------------------------------------------------------
-- stashes: RedEM:RP opens them with the client event
-- redemrp_inventory:OpenStash(id, kg); the client face asks here
-- ------------------------------------------------------------

local CID = '%u%u%u%d%d%d%d%d'

RegisterNetEvent('MULTIinventory:redem:openStash', function(id, kg)
    local src = source
    if Inv.RateLimited(src, 'open') then return end
    if type(id) ~= 'string' or #id > 64 or not id:match('^[%w_%-%.]+$') then return end
    local P = Inv.GetPlayer(src)
    if not P then return end
    -- a stash named after a character belongs to that character only
    local cid = id:match(CID)
    if cid and cid ~= P.PlayerData.citizenid then return end
    -- a job stash belongs to that job
    local job = id:match('^bossstash_(.+)$')
    if job and job ~= P.PlayerData.job.name then return end

    local kgN = tonumber(kg) or 60.0
    kgN = math.max(1, math.min(kgN, 10000))
    local spec = { label = id, slots = Config.Redem and Config.Redem.StashSlots or 50, maxWeight = math.floor(kgN * 1000) }
    local stashId = 'stash:redem_' .. id
    if Inv.Exists(stashId) then Inv.Configure(stashId, spec) else Inv.Create(stashId, spec) end
    Inv.Open(src, stashId, spec)
end)

-- RedEM:RP's client check RedEM.TriggerCallback('redemrp_inventory:server:HasItem', cb, name)
CreateThread(function()
    while GetResourceState('MULTIcore') ~= 'started' do Wait(250) end
    local ok, RedEM = pcall(function() return exports['redem_roleplay']:RedEM() end)
    if not ok or not RedEM then return end
    RedEM.RegisterCallback('redemrp_inventory:server:HasItem', function(src, cb, name)
        local n = API.getItem(src, name).ItemAmount
        cb(n > 0, n)
    end)
end)

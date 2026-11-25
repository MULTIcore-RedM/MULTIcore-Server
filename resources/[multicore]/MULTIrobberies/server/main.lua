-- ============================================================
-- MULTIrobberies :: server
-- Every decision is made here: who may rob, how close they are, how long each
-- step took, what a till or a safe pays and when a bank is fixed again.
--
-- Tills:  multirobberies:till:start (coords) -> token | pick (token, ok) | finish (token)
-- Banks:  a bank gate picked with MULTIdoors opens the bank (MULTIdoors:server:changed);
--         multirobberies:bank:plantStart (id) -> token | plantEnd (token, done)
--         the fuse burns, the vault door is unlocked through MULTIdoors and swung open;
--         multirobberies:bank:lootStart (id, index, coords) -> token | lootEnd (token, ok)
-- State for every client: GlobalState.multirobberies = { [bank id] = { stage, looted = { [i] = true } } }
--   stage: 'closed' | 'open' (gate picked) | 'armed' (fuse burning) | 'blown'
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local Core = exports.MULTIcore:GetCoreObject()
local MI = exports.MULTIinventory
local RES = GetCurrentResourceName()

local Banks = {}          -- [id] = { cfg, vault = { coords, doors }, gates = { [ruleId] = coords }, stage, looted, picked, resetAt }
local BankOrder = {}      -- ids in config order
local Spots = {}          -- [bank id] = { {x,y,z}, ... } from data/safes.json
local tills = {}          -- [till key] = os.time() it was emptied
local lastTill = {}       -- [src] = os.time() of the last till
local attempts = {}       -- [src] = { kind, token, t0, ... } one running step per player
local claims = {}         -- ["bank:index"] = src cracking that safe right now

---------------------------------
-- helpers
---------------------------------
local function debug(msg, ...)
    if Config.Debug then print(('[MULTIrobberies] ' .. msg):format(...)) end
end

local function notify(src, text, kind)
    exports.MULTIcore:Notify(src, { text = text, type = kind or 'info', duration = Config.NotifyDuration })
end

local function player(src) return Core.Functions.GetPlayer(tonumber(src) or -1) end

local function vec(c) return vector3((c.x or c[1]) + 0.0, (c.y or c[2]) + 0.0, (c.z or c[3]) + 0.0) end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if c.x == 0.0 and c.y == 0.0 and c.z == 0.0 then return nil end
    return c
end

local function near(src, coords, dist)
    local p = coordsOf(src)
    return p ~= nil and coords ~= nil and #(p - vec(coords)) <= dist
end

local function alive(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    if GetEntityMaxHealth(ped) > 0 and GetEntityHealth(ped) <= 0 then return false end
    return true
end

local function newToken() return ('%d-%d'):format(GetGameTimer(), math.random(100000, 999999)) end

local function money(v) return math.floor(v * 100 + 0.5) / 100 end

local function rand(a, b)
    if math.type(a) == 'integer' and math.type(b) == 'integer' then return math.random(a, math.max(a, b)) end
    return a + math.random() * (b - a)
end

local function fmt(v) return ('%.2f'):format(v) end

local function isAdmin(src)
    if src == 0 then return true end
    if Config.Admin.Ace and IsPlayerAceAllowed(src, Config.Admin.Ace) then return true end
    for _, g in ipairs(Config.Admin.Groups or {}) do
        local ok, yes = pcall(function() return Core.Functions.HasPermission(src, g) end)
        if ok and yes then return true end
    end
    return false
end

---------------------------------
-- the law
---------------------------------
local function lawJob(p)
    local job = p and p.PlayerData and p.PlayerData.job
    if not job then return false end
    local def = Core.Shared and Core.Shared.Jobs and Core.Shared.Jobs[job.name]
    if not Config.Law.JobTypes[(def and def.type) or job.type or ''] then return false end
    return (not Config.Law.OnDutyOnly) or job.onduty == true
end

local function lawCount()
    if GetResourceState('MULTIlaw') == 'started' then
        local ok, n = pcall(function() return exports.MULTIlaw:GetLawCount() end)
        if ok and tonumber(n) then return tonumber(n) end
    end
    local n = 0
    for _, s in ipairs(Core.Functions.GetPlayers() or {}) do
        if lawJob(player(s)) then n = n + 1 end
    end
    return n
end

local function isLaw(src)
    if GetResourceState('MULTIlaw') == 'started' then
        local ok, yes = pcall(function() return exports.MULTIlaw:IsLaw(src) end)
        if ok then return yes == true end
    end
    return lawJob(player(src))
end

local function alertLaw(coords, text)
    coords = vec(coords)
    if GetResourceState('MULTIlaw') == 'started' then
        local ok = pcall(function() exports.MULTIlaw:Alert(coords, text) end)
        if ok then return end
    end
    for _, s in ipairs(Core.Functions.GetPlayers() or {}) do
        if lawJob(player(s)) then TriggerClientEvent('MULTIrobberies:client:alert', s, coords, text) end
    end
end

--- Common checks before any robbery step. Returns nil or an error key.
local function canRob(src, minLaw)
    if not player(src) then return 'err_generic' end
    if not alive(src) then return 'err_generic' end
    if attempts[src] then return 'err_busy' end
    if not Config.Law.LawCanRob and isLaw(src) then return 'err_law' end
    if (minLaw or 0) > 0 and lawCount() < minLaw then return 'err_need_law' end
    return nil
end

---------------------------------
-- items
---------------------------------
local function invUp() return GetResourceState('MULTIinventory') == 'started' end

local function count(src, item)
    if not invUp() then return 0 end
    local ok, n = pcall(function() return MI:Count(MI:PlayerInv(src), item) end)
    return ok and tonumber(n) or 0
end

local function take(src, item, n, reason)
    local ok, done = pcall(function() return MI:RemoveItem(MI:PlayerInv(src), item, n or 1, nil, nil, reason) end)
    return ok and done == true
end

local function label(item)
    local ok, d = pcall(function() return MI:GetItemDef(item) end)
    return ok and d and d.label or item
end

--- Gives the item when it fits. Returns true when given.
local function give(src, item, n, reason)
    if not invUp() then return false end
    local pid = MI:PlayerInv(src)
    local ok, can = pcall(function() return MI:CanAdd(pid, item, n) end)
    if not ok or not can then return false end
    local added = MI:AddItem(pid, item, n, nil, nil, reason)
    if added then pcall(function() MI:ItemBox(src, item, n, 'add') end) end
    return added and true or false
end

local function addCash(src, amount, reason)
    local p = player(src)
    if not p or amount <= 0 then return false end
    return p.Functions.AddMoney('cash', money(amount), reason) == true
end

local function registerItems()
    if not invUp() then return end
    local t = 0
    while not MI:IsReady() and t < 300 do Wait(100) t = t + 1 end
    local added = 0
    for name, d in pairs(Config.NewItems or {}) do
        if not MI:GetItemDef(name) then
            if MI:RegisterItem({
                name = name, label = d.label, weight = d.weight or 100, type = 'item', unique = false,
                useable = (name == 'jewelry_box' and Config.JewelryBox.Enabled) or false,
                image = d.image or (name .. '.png'), description = d.description,
            }) then added = added + 1 end
        end
    end
    if added > 0 then print(('[MULTIrobberies] %d items added to the item list'):format(added)) end
end

---------------------------------
-- state for clients
---------------------------------
local function publish()
    local out = {}
    for id, b in pairs(Banks) do
        local looted = {}
        for i in pairs(b.looted) do looted[#looted + 1] = i end
        out[id] = { stage = b.stage, looted = looted }
    end
    GlobalState.multirobberies = out
end

local function bankInfo()
    local out = {}
    for _, id in ipairs(BankOrder) do
        local b = Banks[id]
        out[#out + 1] = {
            id = id, label = b.cfg.label, safes = b.cfg.safes,
            vault = b.vault and { coords = b.vault.coords, doors = b.vault.doors } or nil,
            gates = b.gateCentre, spots = Spots[id] or {},
        }
    end
    return out
end

---------------------------------
-- banks: build from MULTIdoors
---------------------------------
local function rule(id)
    if GetResourceState('MULTIdoors') ~= 'started' then return nil end
    local ok, r = pcall(function() return exports.MULTIdoors:GetRule(id) end)
    return ok and r or nil
end

local function loadSpots()
    local raw = LoadResourceFile(RES, 'data/safes.json')
    local ok, t = pcall(json.decode, raw or '{}')
    Spots = (ok and type(t) == 'table') and t or {}
end

local function saveSpots()
    SaveResourceFile(RES, 'data/safes.json', json.encode(Spots, { indent = true }), -1)
end

local function buildBanks()
    local t = 0
    while GetResourceState('MULTIdoors') == 'started' and not exports.MULTIdoors:IsReady() and t < 300 do Wait(100) t = t + 1 end
    Banks, BankOrder = {}, {}
    for _, cfg in ipairs(Config.Banks or {}) do
        local v = rule(cfg.vault)
        if not v then
            print(('^3[MULTIrobberies] %s: vault rule %s not found in MULTIdoors - bank left out^7'):format(cfg.id, tostring(cfg.vault)))
        else
            local gates, sx, sy, sz, n = {}, 0, 0, 0, 0
            for _, gid in ipairs(cfg.gates or {}) do
                local g = rule(gid)
                if g then
                    gates[gid] = vec(g.coords)
                    sx, sy, sz, n = sx + g.coords.x, sy + g.coords.y, sz + g.coords.z, n + 1
                else
                    print(('^3[MULTIrobberies] %s: gate rule %s not found in MULTIdoors^7'):format(cfg.id, tostring(gid)))
                end
            end
            Banks[cfg.id] = {
                cfg = cfg, vault = { coords = vec(v.coords), doors = v.door },
                gates = gates, gateCentre = n > 0 and vector3(sx / n, sy / n, sz / n) or nil,
                stage = 'closed', looted = {}, picked = false, resetAt = nil,
            }
            BankOrder[#BankOrder + 1] = cfg.id
            pcall(function() exports.MULTIdoors:SetLocked(cfg.vault, true) end)
        end
    end
    publish()
    print(('[MULTIrobberies] %d banks ready'):format(#BankOrder))
end

local function bankOfGate(ruleId)
    for id, b in pairs(Banks) do
        if b.gates[ruleId] then return id, b end
    end
end

local function anyGateOpen(b)
    for gid in pairs(b.gates) do
        local ok, locked = pcall(function() return exports.MULTIdoors:IsLocked(gid) end)
        if ok and locked == false then return true end
    end
    return false
end

-- a gate changed: picked open -> the bank is open to robbery; locked again -> closed (unless already blown)
AddEventHandler('MULTIdoors:server:changed', function(ruleId, locked, by)
    local id, b = bankOfGate(ruleId)
    if not b then return end
    if not locked then
        local picker = type(by) == 'string' and tonumber(by:match('^lockpick:(%d+)$'))
        if picker or not Config.Bank.GateMustBePicked then
            b.picked = true
            if b.stage == 'closed' then b.stage = 'open' end
            debug('%s: gate %s opened by %s', id, ruleId, tostring(by))
            if picker and Config.Bank.AlertOnGate then alertLaw(b.gates[ruleId], _L('alert_gate', b.cfg.label)) end
            publish()
        end
    elseif b.stage == 'open' and not anyGateOpen(b) then
        b.stage, b.picked = 'closed', false
        publish()
    end
end)

local function setVaultOpen(b, open)
    pcall(function() exports.MULTIdoors:SetLocked(b.cfg.vault, not open) end)
    TriggerClientEvent('MULTIrobberies:client:vault', -1, b.cfg.id, open)
end

local function resetBank(id)
    local b = Banks[id]
    if not b then return false end
    b.stage, b.looted, b.picked, b.resetAt = 'closed', {}, false, nil
    for k in pairs(claims) do if k:find('^' .. id .. ':') then claims[k] = nil end end
    setVaultOpen(b, false)
    for gid in pairs(b.gates) do pcall(function() exports.MULTIdoors:SetLocked(gid, true) end) end
    publish()
    debug('%s: fixed and locked', id)
    return true
end

local function blow(id, by)
    local b = Banks[id]
    if not b or b.stage ~= 'armed' then return end
    b.stage = 'blown'
    b.resetAt = os.time() + (Config.Bank.ResetMinutes or 90) * 60
    setVaultOpen(b, true)
    if Config.Bank.AlertOnCharge then alertLaw(b.vault.coords, _L('alert_vault', b.cfg.label)) end
    publish()
    debug('%s: vault blown by %s', id, tostring(by))
end

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for id, b in pairs(Banks) do
            if b.resetAt and now >= b.resetAt then resetBank(id) end
        end
    end
end)

lib.callback.register('multirobberies:banks', function() return bankInfo() end)

---------------------------------
-- banks: the charge
---------------------------------
lib.callback.register('multirobberies:bank:plantStart', function(src, id)
    local b = Banks[id]
    if not b then return false, 'err_generic' end
    local err = canRob(src, b.cfg.minLaw)
    if err then return false, err end
    if b.stage == 'armed' then return false, 'bank_armed' end
    if b.stage == 'blown' then return false, 'bank_blown' end
    local gateOk = anyGateOpen(b)
    if Config.Bank.GateMustBePicked and not b.picked then gateOk = false end
    if not gateOk then return false, 'bank_gate_locked' end
    if not near(src, b.vault.coords, Config.Bank.PlantDistance + 1.0) then return false, 'err_too_far' end
    if count(src, Config.Charge) < 1 then return false, 'bank_no_charge' end
    local token = newToken()
    attempts[src] = { kind = 'plant', token = token, t0 = GetGameTimer(), bank = id }
    return true, token
end)

lib.callback.register('multirobberies:bank:plantEnd', function(src, token, done)
    local a = attempts[src]
    attempts[src] = nil
    if not a or a.kind ~= 'plant' or a.token ~= token then return false, 'err_generic' end
    if done ~= true then return false end
    local b = Banks[a.bank]
    if not b or (b.stage ~= 'open' and b.stage ~= 'closed') then return false, 'bank_armed' end
    if GetGameTimer() - a.t0 < Config.Bank.PlantMs * 0.8 then return false, 'err_generic' end
    if not near(src, b.vault.coords, Config.Bank.PlantDistance + 1.0) then return false, 'err_too_far' end
    if not take(src, Config.Charge, 1, 'vault charge') then return false, 'bank_no_charge' end
    b.stage = 'armed'
    publish()
    local fuse = math.max(3, tonumber(Config.Bank.FuseSeconds) or 12)
    TriggerClientEvent('MULTIrobberies:client:fuse', -1, a.bank, fuse, src)
    SetTimeout(fuse * 1000 + 300, function() blow(a.bank, src) end)
    debug('%s: charge set by %d, %ds fuse', a.bank, src, fuse)
    return true, fuse
end)

---------------------------------
-- banks: the safes
---------------------------------
--- Where safe `index` of bank `b` is, as the server trusts it.
local function safeSpot(b, index, clientCoords)
    local list = Spots[b.cfg.id]
    if type(list) == 'table' and #list > 0 then
        local s = list[index]
        return s and vec(s) or nil
    end
    -- no spots set: the client found the safe (a game prop by the vault, or the vault itself)
    if type(clientCoords) ~= 'table' and type(clientCoords) ~= 'vector3' then return nil end
    local c = vec(clientCoords)
    if #(c - b.vault.coords) > (Config.Bank.SafeScanRadius or 9.0) + 2.0 then return nil end
    return c
end

local function safeCount(b)
    local list = Spots[b.cfg.id]
    if type(list) == 'table' and #list > 0 then return #list end
    return b.cfg.safes or 4
end

lib.callback.register('multirobberies:bank:lootStart', function(src, id, index, coords)
    local b = Banks[id]
    if not b then return false, 'err_generic' end
    if b.stage ~= 'blown' then return false, 'bank_not_open' end
    index = math.tointeger(tonumber(index))
    if not index or index < 1 or index > safeCount(b) then return false, 'err_generic' end
    if b.looted[index] then return false, 'safe_empty' end
    local key = id .. ':' .. index
    if claims[key] and claims[key] ~= src and GetPlayerName(claims[key]) then return false, 'safe_busy' end
    if attempts[src] then return false, 'err_busy' end
    if not player(src) or not alive(src) then return false, 'err_generic' end
    local spot = safeSpot(b, index, coords)
    if not spot or not near(src, spot, Config.Bank.SafeDistance) then return false, 'err_too_far' end
    claims[key] = src
    local token = newToken()
    attempts[src] = { kind = 'loot', token = token, t0 = GetGameTimer(), bank = id, index = index, spot = spot }
    return true, token
end)

--- Rolls one safe of bank `b`. Returns cash, { { item, n } }.
local function rollSafe(b)
    local pay = tonumber(b.cfg.pay) or 1.0
    local cash, items = 0, {}
    for _, l in ipairs(Config.SafeLoot or {}) do
        if math.random() <= (l.chance or 1) then
            if l.cash then
                cash = cash + rand(l.min + 0.0, l.max + 0.0) * pay
            elseif l.item then
                local n = math.max(l.min or 1, math.floor(rand(l.min or 1, l.max or 1) * pay))
                items[#items + 1] = { l.item, n }
            end
        end
    end
    return money(cash), items
end

local function giveLoot(src, cash, items, reason)
    local got, lost = {}, {}
    if cash > 0 and addCash(src, cash, reason) then got[#got + 1] = '$' .. fmt(cash) end
    for _, it in ipairs(items) do
        if give(src, it[1], it[2], reason) then
            got[#got + 1] = ('%s x%d'):format(label(it[1]), it[2])
        else
            lost[#lost + 1] = label(it[1])
        end
    end
    return got, lost
end

lib.callback.register('multirobberies:bank:lootEnd', function(src, token, ok)
    local a = attempts[src]
    attempts[src] = nil
    if not a or a.kind ~= 'loot' or a.token ~= token then return false end
    local key = a.bank .. ':' .. a.index
    if claims[key] == src then claims[key] = nil end
    local b = Banks[a.bank]
    if not b or b.stage ~= 'blown' or b.looted[a.index] then return false, 'safe_empty' end
    if ok ~= true then return false, 'safe_failed' end
    if GetGameTimer() - a.t0 < Config.Bank.LootMs * 0.7 then return false, 'err_generic' end
    if not near(src, a.spot, Config.Bank.SafeDistance + 1.0) then return false, 'err_too_far' end
    b.looted[a.index] = true
    publish()
    local cash, items = rollSafe(b)
    local got, lost = giveLoot(src, cash, items, 'bank robbery ' .. a.bank)
    if #got > 0 then notify(src, _L('safe_loot', table.concat(got, ', ')), 'success') else notify(src, _L('safe_nothing'), 'inform') end
    if #lost > 0 then notify(src, _L('no_room', table.concat(lost, ', ')), 'error') end
    debug('%s: safe %d emptied by %d ($%s, %d items)', a.bank, a.index, src, fmt(cash), #items)
    return true
end)

---------------------------------
-- tills
---------------------------------
local function tillKey(c) return ('%d:%d:%d'):format(math.floor(c.x + 0.5), math.floor(c.y + 0.5), math.floor(c.z + 0.5)) end

local function townOf(c)
    for _, t in ipairs(Config.Towns or {}) do
        local dx, dy = c.x - t.x, c.y - t.y
        if dx * dx + dy * dy <= t.radius * t.radius then return t end
    end
    return nil
end

lib.callback.register('multirobberies:till:start', function(src, coords)
    local R = Config.Registers
    if not R.Enabled then return false, 'err_generic' end
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return false, 'err_generic' end
    coords = vec(coords)
    local err = canRob(src, R.MinLaw)
    if err then return false, err end
    if not near(src, coords, R.ServerDistance) then return false, 'err_too_far' end
    local key = tillKey(coords)
    if tills[key] and os.time() - tills[key] < R.CooldownMinutes * 60 then return false, 'till_empty' end
    if lastTill[src] and os.time() - lastTill[src] < R.PlayerCooldownSeconds then return false, 'till_wait' end
    if count(src, Config.Lockpick) < 1 then return false, 'err_no_lockpick' end
    local token = newToken()
    attempts[src] = { kind = 'till', token = token, t0 = GetGameTimer(), coords = coords, key = key, stage = 'pick' }
    return true, token
end)

lib.callback.register('multirobberies:till:pick', function(src, token, ok)
    local a = attempts[src]
    if not a or a.kind ~= 'till' or a.token ~= token or a.stage ~= 'pick' then return false end
    if ok ~= true or GetGameTimer() - a.t0 < 1200 then
        attempts[src] = nil
        local broke = math.random() < (Config.Registers.BreakChance or 0) and take(src, Config.Lockpick, 1, 'lockpick broke')
        return false, broke and 'pick_broke' or 'pick_failed'
    end
    if tills[a.key] and os.time() - tills[a.key] < Config.Registers.CooldownMinutes * 60 then
        attempts[src] = nil
        return false, 'till_empty'
    end
    tills[a.key] = os.time()            -- the till is open: nobody else can empty it now
    lastTill[src] = os.time()
    a.stage, a.t1 = 'empty', GetGameTimer()
    local t = townOf(a.coords)
    if math.random() <= (Config.Registers.AlertChance or 0) then
        alertLaw(a.coords, _L('alert_till', t and t.name or _L('town_none')))
    end
    return true
end)

lib.callback.register('multirobberies:till:finish', function(src, token)
    local a = attempts[src]
    attempts[src] = nil
    if not a or a.kind ~= 'till' or a.token ~= token or a.stage ~= 'empty' then return false end
    if GetGameTimer() - a.t1 < Config.Registers.EmptyMs * 0.8 then return false end
    if not near(src, a.coords, Config.Registers.ServerDistance) then return false, 'err_too_far' end
    local R = Config.Registers
    local t = townOf(a.coords)
    local cash = money(rand(R.Min + 0.0, R.Max + 0.0) * (t and t.pay or R.OtherTowns or 1.0))
    if addCash(src, cash, 'till robbery') then
        notify(src, _L('till_loot', fmt(cash)), 'success')
        debug('till %s (%s) emptied by %d: $%s', a.key, t and t.name or '-', src, fmt(cash))
        return true
    end
    return false
end)

RegisterNetEvent('MULTIrobberies:server:cancel', function()
    local src = source
    local a = attempts[src]
    if not a then return end
    attempts[src] = nil
    if a.kind == 'loot' then
        local key = a.bank .. ':' .. a.index
        if claims[key] == src then claims[key] = nil end
    end
end)

---------------------------------
-- jewellery box
---------------------------------
local function weighted(list)
    local total = 0
    for _, l in ipairs(list) do total = total + (l.weight or 1) end
    local r = math.random() * total
    for _, l in ipairs(list) do
        r = r - (l.weight or 1)
        if r <= 0 then return l end
    end
    return list[#list]
end

local function openBox(src)
    local J = Config.JewelryBox
    if not J.Enabled or attempts[src] then return end
    if not take(src, 'jewelry_box', 1, 'jewellery box opened') then return end
    local cash, items = 0, {}
    for _ = 1, math.max(1, J.Rolls or 1) do
        local l = weighted(J.Loot or {})
        if l and l.cash then cash = cash + rand(l.min + 0.0, l.max + 0.0)
        elseif l and l.item then items[#items + 1] = { l.item, rand(l.min or 1, l.max or 1) } end
    end
    local got, lost = giveLoot(src, money(cash), items, 'jewellery box')
    notify(src, #got > 0 and _L('box_loot', table.concat(got, ', ')) or _L('safe_nothing'), 'success')
    if #lost > 0 then notify(src, _L('no_room', table.concat(lost, ', ')), 'error') end
end

---------------------------------
-- admin
---------------------------------
local function nearestBank(src)
    local p = coordsOf(src)
    if not p then return nil end
    local best, bd
    for id, b in pairs(Banks) do
        local d = #(p - b.vault.coords)
        if d < 30.0 and (not bd or d < bd) then best, bd = id, d end
    end
    return best
end

RegisterCommand(Config.Admin.SafeCommand, function(src, args)
    if src == 0 or not isAdmin(src) then return end
    local id = nearestBank(src)
    if not id then return notify(src, _L('admin_no_bank'), 'error') end
    if args[1] == 'clear' then
        Spots[id] = nil
        saveSpots()
        notify(src, _L('admin_cleared', Banks[id].cfg.label), 'success')
    else
        -- the spot sits on the safe the admin faces: 0.6 m ahead at chest height
        local p = coordsOf(src)
        local h = math.rad(GetEntityHeading(GetPlayerPed(src)))
        p = vector3(p.x - math.sin(h) * 0.6, p.y + math.cos(h) * 0.6, p.z + 0.3)
        Spots[id] = Spots[id] or {}
        Spots[id][#Spots[id] + 1] = { x = money(p.x), y = money(p.y), z = money(p.z) }
        saveSpots()
        notify(src, _L('admin_added', #Spots[id], Banks[id].cfg.label), 'success')
    end
    TriggerClientEvent('MULTIrobberies:client:banks', -1, bankInfo())
end, false)

RegisterCommand(Config.Admin.ResetCommand, function(src, args)
    if not isAdmin(src) then return end
    local n = 0
    for _, id in ipairs(BankOrder) do
        if not args[1] or args[1] == id then
            if resetBank(id) then n = n + 1 end
        end
    end
    if src ~= 0 then notify(src, _L('admin_reset', n), 'success') else print(('[MULTIrobberies] %d banks reset'):format(n)) end
end, false)

---------------------------------
-- players leaving, start
---------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    attempts[src], lastTill[src] = nil, nil
    for k, s in pairs(claims) do if s == src then claims[k] = nil end end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for id, b in pairs(Banks) do if b.stage == 'blown' or b.stage == 'armed' then resetBank(id) end end
end)

CreateThread(function()
    loadSpots()
    registerItems()
    if Config.JewelryBox.Enabled and invUp() then
        MI:RegisterUsable('jewelry_box', function(src) openBox(src) end)
    end
    buildBanks()
    TriggerClientEvent('MULTIrobberies:client:banks', -1, bankInfo())
end)

-- self-test hooks (tools/test_boot.ps1)
exports('GetBankState', function(id) local b = Banks[id] return b and { stage = b.stage, picked = b.picked } or nil end)
exports('ResetBank', function(id) return resetBank(id) end)

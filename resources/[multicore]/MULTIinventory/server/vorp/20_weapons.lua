-- ============================================================
-- MULTIinventory :: vorp_inventory face - weapons and ammo (server)
-- A VORP weapon is a MULTIinventory weapon item:
--   VORP weapon id   = info.id     (unique number from MULTIInv.Weapon.New)
--   serial_number    = info.serie
--   loaded rounds    = info.ammo   (number)
--   components       = info.components (list of names, VORP's older form)
--   comps            = info.comps  ({ [category] = component }, VORP's newer form)
--   custom_label / custom_desc = info.custom_label / info.custom_desc
-- VORP weapon names are upper case (WEAPON_REVOLVER_CATTLEMAN); items are lower case.
-- ============================================================

local V = MULTIVorp
local W = {}
V.Weapons = W

local function reason() return 'vorp:' .. tostring(V.Invoker()) end

local function wname(name)
    if type(name) == 'number' then
        -- a weapon hash
        local wd = V.WeaponDataTable()
        if type(wd) == 'table' then
            for n, d in pairs(wd) do
                if type(d) == 'table' and tonumber(d.hash) == name then return tostring(n):lower() end
            end
        end
        if joaat then
            local h = math.tointeger(name)
            for _, n in ipairs(V.AllWeaponNames and V.AllWeaponNames() or {}) do
                local nh = math.tointeger(joaat(n))
                if h and nh and (nh & 0xFFFFFFFF) == (h & 0xFFFFFFFF) then return n end
            end
        end
        return nil
    end
    if type(name) ~= 'string' or name == '' then return nil end
    return name:lower()
end

--- every weapon item name in the registry
function V.AllWeaponNames()
    local out = {}
    local items = MULTIInv and MULTIInv.Items
    if type(items) == 'table' then
        for n, d in pairs(items) do
            if type(d) == 'table' and d.type == 'weapon' then out[#out + 1] = n end
        end
    end
    return out
end

local function isWeaponStack(st)
    if type(st) ~= 'table' then return false end
    return V.IsWeaponDef(V.Def(st.name), st.name)
end

local function wid(st)
    local info = type(st.info) == 'table' and st.info or {}
    return tonumber(info.id)
end

--- Finds a weapon by VORP id: invId, slot, stack. Looks in `firstInv`
--- (and the player's satchel when `src` is given) before asking the engine.
function W.Find(id, src, firstInv)
    id = tonumber(id)
    if not id then return nil end
    local tried = {}
    local function scan(invId)
        if not invId or tried[invId] then return nil end
        tried[invId] = true
        local inv = V.Get(invId)
        if not inv then return nil end
        for _, e in ipairs(V.Stacks(inv)) do
            if isWeaponStack(e.stack) and wid(e.stack) == id then return invId, e.slot, e.stack end
        end
        return nil
    end
    local a, b, c = scan(firstInv)
    if a then return a, b, c end
    if src then
        a, b, c = scan(V.InvOf(src))
        if a then return a, b, c end
    end
    local E = MULTIInv
    if E and E.Weapon and type(E.Weapon.FindById) == 'function' then
        local ok, r1, r2, r3 = pcall(E.Weapon.FindById, id)
        if ok and r1 then
            if type(r1) == 'string' then
                local inv = V.Get(r1)
                local st = r3 or (inv and inv.items and inv.items[r2])
                if st then return r1, r2, st end
                return scan(r1)
            elseif type(r1) == 'table' then
                local invId = r1.invId or r1.inventory or r1.inv
                local slot = r1.slot
                local st = r1.item or r1.stack
                if invId and slot and st then return invId, slot, st end
                if invId then return scan(invId) end
            end
        end
    end
    -- every online player's satchel
    for _, p in ipairs(GetPlayers and GetPlayers() or {}) do
        a, b, c = scan(V.InvOf(tonumber(p)))
        if a then return a, b, c end
    end
    return nil
end

local function ownerOf(invId)
    for _, p in ipairs(GetPlayers and GetPlayers() or {}) do
        local s = tonumber(p)
        if V.InvOf(s) == invId then return s end
    end
    return nil
end

--- weapon item -> VORP weapon table
function W.ToWeapon(invId, slot, st, src)
    local def = V.Def(st.name) or {}
    local info = type(st.info) == 'table' and st.info or {}
    local types = V.WeaponAmmoTypes(st.name)
    local ammo = {}
    if type(info.ammo) == 'table' then
        ammo = V.Copy(info.ammo)
    elseif types[1] then
        ammo[types[1]] = tonumber(info.ammo) or 0
    end
    local comps = type(info.comps) == 'table' and V.Copy(info.comps) or {}
    local components = type(info.components) == 'table' and V.Copy(info.components) or {}
    local custom = V.Customs and V.Customs.NameOf(invId)
    src = src or (invId and invId:find('^player:') and ownerOf(invId)) or nil
    return {
        id = tonumber(info.id),
        name = st.name:upper(),
        label = info.custom_label or def.label or st.name,
        custom_label = info.custom_label,
        custom_desc = info.custom_desc,
        desc = info.custom_desc or def.description or '',
        serial_number = info.serie or info.serial,
        ammo = ammo,
        components = components,
        comps = comps,
        used = (info.used or info.equipped) and true or false,
        used2 = info.used2 and true or false,
        group = 5,
        source = src,
        charId = src and V.CharId(src) or nil,
        propietary = src and V.CharId(src) or nil,
        dropped = 0,
        currInv = custom or 'default',
        slot = slot,
        quality = tonumber(info.quality),
        weight = (tonumber(def.weight) or 0) / 1000,
        isThrown = V.IsThrownWeapon(st.name),
    }
end

--- builds a weapon's info through the engine (fresh serial and id)
function W.NewInfo(name, extra)
    local info
    local E = MULTIInv
    if E and E.Weapon and type(E.Weapon.New) == 'function' then
        local ok, res = pcall(E.Weapon.New, name, extra)
        if ok and type(res) == 'table' then info = res end
    end
    if not info then
        -- engine helper missing: same fields, made here
        info = V.Copy(extra or {})
        info.id = info.id or (os.time() % 100000000) * 1000 + math.random(0, 999)
        info.serie = info.serie or ('%s%06d'):format(string.char(math.random(65, 90), math.random(65, 90)), math.random(0, 999999))
    end
    if type(extra) == 'table' then
        for k, v in pairs(extra) do if info[k] == nil then info[k] = V.Copy(v) end end
    end
    return info
end

--- n new weapons of one kind into a player's satchel (all or nothing)
function W.giveNew(src, name, n, extra)
    local invId = V.InvOf(src)
    if not invId then return false end
    n = V.Amount(n, 1)
    if not n then return false end
    if V.IsThrownWeapon(name) then
        -- thrown weapons stack: no serial, no id, the count is the ammo
        return MULTIInv.AddItem(invId, name, n, nil, nil, reason()) == true, {}
    end
    if MULTIInv.CanAdd(invId, name, n, extra) ~= true then return false end
    local added = {}
    for _ = 1, n do
        local info = W.NewInfo(name, V.Copy(extra or {}))
        local ok = MULTIInv.AddItem(invId, name, 1, info, nil, reason())
        if ok ~= true then
            for _, id in ipairs(added) do
                local fi, fs, fst = W.Find(id, nil, invId)
                if fi then MULTIInv.RemoveItem(fi, fst.name, 1, fs, nil, reason()) end
            end
            return false
        end
        added[#added + 1] = info.id
    end
    return true, added
end

-- ------------------------------------------------------------
-- Weapons
-- ------------------------------------------------------------

--- createWeapon(source, weaponName, ammo?, components?, comps?, callback?, wepId (internal), serial?, label?, desc?)
function W.createWeapon(src, name, ammo, components, comps, cb, _wepId, serial, label, desc)
    local invId = V.InvOf(src)
    name = wname(name)
    if not invId or not name then return V.Done(cb, false) end
    local extra = {
        ammo = V.AmmoNumber(ammo),
        components = type(components) == 'table' and V.Copy(components) or {},
        comps = type(comps) == 'table' and V.Copy(comps) or {},
        custom_label = type(label) == 'string' and label ~= '' and label or nil,
        custom_desc = type(desc) == 'string' and desc ~= '' and desc or nil,
        serie = (type(serial) == 'string' and serial ~= '') and serial or nil,
    }
    local ok, ids = W.giveNew(src, name, 1, extra)
    if ok then TriggerEvent('vorp_inventory:Server:OnWeaponCreated', V.Src(src), ids[1], name:upper()) end
    return V.Done(cb, ok and true or false)
end

--- giveWeapon(source, weaponId, target?, callback?)
--- Moves the weapon to `source`. If `source` already holds it and a
--- target is given, it goes to the target instead.
function W.giveWeapon(src, id, target, cb)
    if V.IsCallable(target) and cb == nil then cb, target = target, nil end
    src, target = V.Src(src), V.Src(target)
    local toInv = V.InvOf(src)
    local fromInv, slot, st = W.Find(id, target, target and V.InvOf(target) or nil)
    if not fromInv then return V.Done(cb, false) end
    if fromInv == toInv then
        if not target or target == src then return V.Done(cb, true) end
        toInv = V.InvOf(target)
    end
    if not toInv then return V.Done(cb, false) end
    local info = V.Copy(st.info)
    info.used, info.used2, info.equipped = nil, nil, nil
    if MULTIInv.CanAdd(toInv, st.name, 1, info) ~= true then return V.Done(cb, false) end
    local name = st.name
    if MULTIInv.RemoveItem(fromInv, name, 1, slot, nil, reason()) ~= true then return V.Done(cb, false) end
    if MULTIInv.AddItem(toInv, name, 1, info, nil, reason()) ~= true then
        MULTIInv.AddItem(fromInv, name, 1, V.Copy(st.info), slot, reason())
        return V.Done(cb, false)
    end
    local holder = ownerOf(fromInv)
    if holder then TriggerClientEvent('MULTIinventory:client:weaponRemoved', holder, name, st.info and st.info.serie) end
    return V.Done(cb, true)
end

--- subWeapon(source, weaponId, callback?) - takes the weapon from the player
function W.subWeapon(src, id, cb)
    local invId = V.InvOf(src)
    local fi, slot, st = W.Find(id, nil, invId)
    if not fi or fi ~= invId then return V.Done(cb, false) end
    local ok = MULTIInv.RemoveItem(fi, st.name, 1, slot, nil, reason()) == true
    if ok then TriggerClientEvent('MULTIinventory:client:weaponRemoved', V.Src(src), st.name, st.info and st.info.serie) end
    return V.Done(cb, ok)
end

--- deleteWeapon(source, weaponId, callback?) - removes the weapon for good
function W.deleteWeapon(src, id, cb)
    local invId = V.InvOf(src)
    local fi, slot, st = W.Find(id, src, invId)
    if not fi then return V.Done(cb, false) end
    local ok = MULTIInv.RemoveItem(fi, st.name, 1, slot, nil, reason()) == true
    local holder = ownerOf(fi)
    if ok and holder then TriggerClientEvent('MULTIinventory:client:weaponRemoved', holder, st.name, st.info and st.info.serie) end
    return V.Done(cb, ok)
end

--- getUserWeapon(source, callback?, weaponId) / getWeapon
function W.getUserWeapon(src, cb, id)
    if not V.IsCallable(cb) and id == nil then cb, id = nil, cb end
    local invId = V.InvOf(src)
    local fi, slot, st = W.Find(id, nil, invId)
    if not fi or fi ~= invId then return V.Done(cb, nil) end
    return V.Done(cb, W.ToWeapon(fi, slot, st, V.Src(src)))
end

--- getUserInventoryWeapons(source, callback?) / getUserWeapons
function W.getUserInventoryWeapons(src, cb)
    local invId = V.InvOf(src)
    local out = {}
    local inv = invId and V.Get(invId)
    if inv then
        for _, e in ipairs(V.Stacks(inv)) do
            if isWeaponStack(e.stack) then out[#out + 1] = W.ToWeapon(invId, e.slot, e.stack, V.Src(src)) end
        end
    end
    return V.Done(cb, out)
end

--- canCarryWeapons(source, amount, callback?, weaponName?)
function W.canCarryWeapons(src, amount, cb, name)
    if type(cb) == 'string' and name == nil then cb, name = nil, cb end
    local invId = V.InvOf(src)
    amount = V.Amount(amount, 1)
    if not invId or not amount then return V.Done(cb, false) end
    name = wname(name) or V.Cfg('WeaponCheckDefault', 'weapon_revolver_cattleman')
    local max = tonumber(V.Cfg('MaxWeapons', 0)) or 0
    if max > 0 then
        local have = 0
        for _, e in ipairs(V.Stacks(V.Get(invId))) do
            if isWeaponStack(e.stack) and not V.IsThrownWeapon(e.stack.name) then have = have + 1 end
        end
        if have + amount > max then return V.Done(cb, false) end
    end
    return V.Done(cb, MULTIInv.CanAdd(invId, name, amount) == true)
end

-- ------------------------------------------------------------
-- Labels, serials, descriptions
-- Docs list (source, weaponId, value, cb); their examples use
-- (weaponId, value, cb). Both work: a string in the second place
-- means the short form.
-- ------------------------------------------------------------
local function editArgs(a, b, c, d)
    if type(b) == 'string' or (b == nil and type(a) == 'number' and type(c) ~= 'string') then
        return nil, a, b, c      -- (weaponId, value, cb)
    end
    return a, b, c, d            -- (source, weaponId, value, cb)
end

local function editWeapon(src, id, fn)
    local fi, slot, st = W.Find(id, src and V.Src(src) or nil, src and V.InvOf(src) or nil)
    if not fi then return false end
    local info = V.Copy(st.info) or {}
    fn(info)
    local ok = MULTIInv.ReplaceInfo(fi, slot, info)
    return ok ~= false, fi
end

function W.setWeaponCustomLabel(a, b, c, d)
    local src, id, label, cb = editArgs(a, b, c, d)
    return V.Done(cb, (editWeapon(src, id, function(info)
        info.custom_label = (type(label) == 'string' and label ~= '') and label or nil
    end)))
end

function W.setWeaponCustomDesc(a, b, c, d)
    local src, id, desc, cb = editArgs(a, b, c, d)
    return V.Done(cb, (editWeapon(src, id, function(info)
        info.custom_desc = (type(desc) == 'string' and desc ~= '') and desc or nil
    end)))
end

function W.setWeaponSerialNumber(a, b, c, d)
    local src, id, serial, cb = editArgs(a, b, c, d)
    if type(serial) ~= 'string' or serial == '' then return V.Done(cb, false) end
    return V.Done(cb, (editWeapon(src, id, function(info) info.serie = serial end)))
end

-- ------------------------------------------------------------
-- Components
-- ------------------------------------------------------------
local function hasValue(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

local function removeValue(list, v)
    for i = #list, 1, -1 do if list[i] == v then table.remove(list, i) end end
end

--- getWeaponComponents(source, weaponId, callback?) -> { [category] = component } (or the list form when only that exists)
function W.getWeaponComponents(src, id, cb)
    local fi, _, st = W.Find(id, V.Src(src), V.InvOf(src))
    if not fi then return V.Done(cb, {}) end
    local info = st.info or {}
    if type(info.comps) == 'table' and next(info.comps) then return V.Done(cb, V.Copy(info.comps)) end
    return V.Done(cb, V.Copy(info.components or {}))
end

local function notifyComp(src, eventName, id, comp, cat)
    src = V.Src(src)
    -- the client face re-fires it locally as the VORP event (client/vorp/main.lua)
    if src then TriggerClientEvent('MULTIinventory:vorp:component', src, eventName, tonumber(id), comp, cat) end
end

--- addWeaponComponent(source, weaponId, component, category, callback?)
function W.addWeaponComponent(src, id, comp, cat, cb)
    if comp == nil then return V.Done(cb, false) end
    local ok = editWeapon(src, id, function(info)
        info.comps = type(info.comps) == 'table' and info.comps or {}
        info.components = type(info.components) == 'table' and info.components or {}
        if cat ~= nil then info.comps[tostring(cat)] = comp end
        if not hasValue(info.components, comp) then info.components[#info.components + 1] = comp end
    end)
    if ok then notifyComp(src, 'vorp_inventory:componentAdded', id, comp, cat) end
    return V.Done(cb, ok and true or false)
end

--- addWeaponComponents(source, weaponId, { [component] = category }, callback?)
function W.addWeaponComponents(src, id, comps, cb)
    if type(comps) ~= 'table' then return V.Done(cb, false) end
    local list = {}
    for k, v in pairs(comps) do
        if type(k) == 'number' and math.type(k) == 'integer' and k <= #comps then list[#list + 1] = { v, nil } -- a plain list
        else list[#list + 1] = { k, v } end
    end
    local ok = editWeapon(src, id, function(info)
        info.comps = type(info.comps) == 'table' and info.comps or {}
        info.components = type(info.components) == 'table' and info.components or {}
        for _, p in ipairs(list) do
            if p[2] ~= nil then info.comps[tostring(p[2])] = p[1] end
            if not hasValue(info.components, p[1]) then info.components[#info.components + 1] = p[1] end
        end
    end)
    if ok then
        for _, p in ipairs(list) do notifyComp(src, 'vorp_inventory:componentAdded', id, p[1], p[2]) end
    end
    return V.Done(cb, ok and true or false)
end

--- subWeaponComponent(source, weaponId, component, category, callback?)
function W.subWeaponComponent(src, id, comp, cat, cb)
    local ok = editWeapon(src, id, function(info)
        info.comps = type(info.comps) == 'table' and info.comps or {}
        info.components = type(info.components) == 'table' and info.components or {}
        if cat ~= nil and info.comps[tostring(cat)] == comp then info.comps[tostring(cat)] = nil end
        for k, v in pairs(info.comps) do if v == comp then info.comps[k] = nil end end
        removeValue(info.components, comp)
    end)
    if ok then notifyComp(src, 'vorp_inventory:componentRemoved', id, comp, cat) end
    return V.Done(cb, ok and true or false)
end

--- subWeaponComponents(source, weaponId, { [component] = category } or a list, callback?)
function W.subWeaponComponents(src, id, comps, cb)
    if type(comps) ~= 'table' then return V.Done(cb, false) end
    local list = {}
    for k, v in pairs(comps) do
        if type(k) == 'number' and math.type(k) == 'integer' and k <= #comps then list[#list + 1] = { v, nil }
        else list[#list + 1] = { k, v } end
    end
    local ok = editWeapon(src, id, function(info)
        info.comps = type(info.comps) == 'table' and info.comps or {}
        info.components = type(info.components) == 'table' and info.components or {}
        for _, p in ipairs(list) do
            for k, v in pairs(info.comps) do if v == p[1] then info.comps[k] = nil end end
            removeValue(info.components, p[1])
        end
    end)
    if ok then
        for _, p in ipairs(list) do notifyComp(src, 'vorp_inventory:componentRemoved', id, p[1], p[2]) end
    end
    return V.Done(cb, ok and true or false)
end

-- ------------------------------------------------------------
-- Ammo
-- ------------------------------------------------------------

--- getUserAmmo(source, callback?) -> { AMMO_REVOLVER = 24, AMMO_TOMAHAWK = 2, ... }
function W.getUserAmmo(src, cb)
    local invId = V.InvOf(src)
    if not invId then return V.Done(cb, {}) end
    return V.Done(cb, V.UserAmmo(invId))
end

--- addBullets(source, bulletType, amount, callback?) - bulletType 'AMMO_X' or its item name
function W.addBullets(src, bulletType, amount, cb)
    local invId = V.InvOf(src)
    amount = V.Amount(amount)
    local item, _, t = V.AmmoItem(bulletType)
    if not invId or not amount or not item then
        if not item then V.Debug('addBullets: unknown ammo type %s', tostring(bulletType)) end
        return V.Done(cb, false)
    end
    local max = V.Cfg('AmmoMax', nil)
    max = type(max) == 'table' and tonumber(max[t]) or nil
    if max and V.CountOf(invId, item) + amount > max then return V.Done(cb, false) end
    -- rounds items and thrown weapons both stack: a plain add
    local ok = MULTIInv.AddItem(invId, item, amount, nil, nil, reason()) == true
    if ok then TriggerClientEvent('MULTIinventory:client:ammoChanged', V.Src(src), t, V.CountOf(invId, item)) end
    return V.Done(cb, ok and true or false)
end

--- takes `amount` of an ammo type out of the satchel (rounds items or thrown weapons)
local function takeAmmo(src, invId, ammoType, amount)
    local item, _, t = V.AmmoItem(ammoType)
    if not item then return false end
    local ok = V.RemoveFrom(invId, item, amount, V.Find(invId, item), reason())
    if ok then TriggerClientEvent('MULTIinventory:client:ammoChanged', V.Src(src), t, V.CountOf(invId, item)) end
    return ok
end

--- subBullets(weaponId, bulletType, amount, callback?) - as documented
--- subBullets(source, weaponId, bulletType, amount, callback?) - older form
--- Takes rounds loaded in the weapon first, then rounds from the satchel.
function W.subBullets(a, b, c, d, e)
    local src, id, bulletType, amount, cb
    if type(b) == 'string' then
        id, bulletType, amount, cb = a, b, c, d
    else
        src, id, bulletType, amount, cb = a, b, c, d, e
    end
    amount = V.Amount(amount)
    local t = V.AmmoType(bulletType)
    if not amount or not t then return V.Done(cb, false) end
    local fi, slot, st = W.Find(id, src and V.Src(src) or nil, src and V.InvOf(src) or nil)
    if not fi then return V.Done(cb, false) end
    src = src and V.Src(src) or ownerOf(fi)
    local info = V.Copy(st.info) or {}
    local loaded = tonumber(info.ammo) or 0
    local types = V.WeaponAmmoTypes(st.name)
    local fits = false
    for _, x in ipairs(types) do if x == t then fits = true break end end
    if not fits then loaded = 0 end
    local fromWeapon = math.min(loaded, amount)
    local rest = amount - fromWeapon
    local invId = src and V.InvOf(src)
    if rest > 0 then
        local item = V.AmmoItem(t)
        if not invId or not item or V.CountOf(invId, item) < rest then return V.Done(cb, false) end
    end
    if fromWeapon > 0 then
        info.ammo = loaded - fromWeapon
        if MULTIInv.ReplaceInfo(fi, slot, info) == false then return V.Done(cb, false) end
    end
    if rest > 0 and not takeAmmo(src, invId, t, rest) then return V.Done(cb, false) end
    return V.Done(cb, true)
end

--- getWeaponBullets(source, weaponId, callback?) -> rounds loaded (thrown: how many the player has)
function W.getWeaponBullets(src, id, cb)
    if V.IsCallable(id) and cb ~= nil then id, cb = cb, id end
    local invId = V.InvOf(src)
    local fi, _, st = W.Find(id, V.Src(src), invId)
    if not fi then return V.Done(cb, 0) end
    if V.IsThrownWeapon(st.name) then return V.Done(cb, V.CountOf(fi, st.name)) end
    local info = st.info or {}
    if type(info.ammo) == 'table' then return V.Done(cb, V.AmmoNumber(info.ammo)) end
    return V.Done(cb, math.max(0, math.floor(tonumber(info.ammo) or 0)))
end

--- removeAllUserAmmo(source) - every round in the satchel and in the
--- player's weapons (thrown weapons stay: they are weapons too)
function W.removeAllUserAmmo(src, cb)
    local invId = V.InvOf(src)
    if not invId then return V.Done(cb, false) end
    for _, e in ipairs(V.Stacks(V.Get(invId))) do
        local t, thrown = V.AmmoTypeOfItem(e.stack.name)
        if t and not thrown then
            MULTIInv.RemoveItem(invId, e.stack.name, V.StackAmount(e.stack), e.slot, nil, reason())
        elseif isWeaponStack(e.stack) and not V.IsThrownWeapon(e.stack.name) then
            local info = e.stack.info or {}
            if (tonumber(info.ammo) or 0) > 0 or type(info.ammo) == 'table' then
                local copy = V.Copy(info)
                copy.ammo = 0
                MULTIInv.ReplaceInfo(invId, e.slot, copy)
            end
        end
    end
    TriggerClientEvent('MULTIinventory:client:removeAllAmmo', V.Src(src))
    return V.Done(cb, true)
end

-- ------------------------------------------------------------
-- Exports
-- ------------------------------------------------------------
V.Export('createWeapon', W.createWeapon)
V.Export('giveWeapon', W.giveWeapon)
V.Export('subWeapon', W.subWeapon)
V.Export('deleteWeapon', W.deleteWeapon)
V.Export('getUserWeapon', W.getUserWeapon)
V.Export('getWeapon', W.getUserWeapon)
V.Export('getUserInventoryWeapons', W.getUserInventoryWeapons)
V.Export('getUserWeapons', W.getUserInventoryWeapons)
V.Export('canCarryWeapons', W.canCarryWeapons)
V.Export('setWeaponCustomLabel', W.setWeaponCustomLabel)
V.Export('setWeaponCustomDesc', W.setWeaponCustomDesc)
V.Export('setWeaponSerialNumber', W.setWeaponSerialNumber)
V.Export('setWeaponSerial', W.setWeaponSerialNumber)
V.Export('getWeaponComponents', W.getWeaponComponents)
V.Export('addWeaponComponent', W.addWeaponComponent)
V.Export('addWeaponComponents', W.addWeaponComponents)
V.Export('subWeaponComponent', W.subWeaponComponent)
V.Export('subWeaponComponents', W.subWeaponComponents)
V.Export('getUserAmmo', W.getUserAmmo)
V.Export('addBullets', W.addBullets)
V.Export('subBullets', W.subBullets)
V.Export('getWeaponBullets', W.getWeaponBullets)
V.Export('removeAllUserAmmo', W.removeAllUserAmmo)

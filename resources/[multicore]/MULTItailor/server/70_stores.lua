--[[
    Public clothes stores (ready-made basics, NPC clerk).

    lib.callback:
      multitailor:store:open   (storeId)                          -> payload | nil, err
      multitailor:store:buy    ({ storeId, lineId, colour })      -> { ok, error?, cash?, left? }
      multitailor:admin:stores ()                                 -> { stores } | nil       admin
      multitailor:admin:store  ({ action, id, ... })              -> { ok, error?, stores } admin
          action = 'create' { label, town } (at the admin's feet) | 'move' { id } | 'rename' { id, label }
                   'toggle' { id } | 'blip' { id } | 'price' { id, mult } | 'model' { id, model }
                   'delete' { id } | 'reset' { id } (back to config/stores.lua)
    Client sync: 'MULTItailor:stores' (list of enabled stores).
    Prices, colours and stock are decided here; the client only sends ids.
]]
TStores = TStores or {}

local stores = {}          -- [id] = store (config merged with multitailor_stores)
local overrides = {}       -- [id] = data from the database
local lines, lineById = {}, {}
local stock = {}           -- ['store|line|colour'] = { left, at }
local busy = {}

local function vec4(c)
    if type(c) ~= 'table' and type(c) ~= 'vector4' and type(c) ~= 'vector3' then return nil end
    local x, y, z = TU.finite(c.x), TU.finite(c.y), TU.finite(c.z)
    if not x or not y or not z or math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 5000 then return nil end
    return { x = x, y = y, z = z, w = (TU.finite(c.w) or 0.0) % 360.0 }
end

local function rebuild()
    stores = {}
    for _, s in ipairs(Config.Stores.list or {}) do
        local clerk = vec4(s.clerk)
        if type(s.id) == 'string' and clerk then
            stores[s.id] = { id = s.id, label = s.label or s.id, town = s.town, clerk = clerk, model = s.model or Config.Stores.defaultModel,
                             enabled = s.enabled ~= false, blip = s.blip ~= false, priceMultiplier = TU.finite(s.priceMultiplier) or 1.0, config = true }
        end
    end
    for id, d in pairs(overrides) do
        if d.deleted then
            stores[id] = nil
        else
            local base = stores[id] or { id = id, config = false, enabled = true, blip = true, priceMultiplier = 1.0, model = Config.Stores.defaultModel }
            base.label = TU.text(d.label, 48) or base.label or id
            base.town = TU.text(d.town, 32) or base.town
            base.clerk = vec4(d.clerk) or base.clerk
            base.model = TU.text(d.model, 48) or base.model
            if d.enabled ~= nil then base.enabled = d.enabled == true end
            if d.blip ~= nil then base.blip = d.blip == true end
            base.priceMultiplier = TU.clamp(d.priceMultiplier, 0.1, 10.0) or base.priceMultiplier
            base.overridden = true
            if base.clerk then stores[id] = base end
        end
    end
end

local function publicList()
    local out = {}
    for _, s in pairs(stores) do
        if s.enabled then
            out[#out + 1] = { id = s.id, label = s.label, town = s.town, clerk = s.clerk, model = s.model, blip = s.blip }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function adminList()
    local out = {}
    for _, s in pairs(stores) do out[#out + 1] = TU.copy(s) end
    for _, s in ipairs(Config.Stores.list or {}) do
        if not stores[s.id] and overrides[s.id] and overrides[s.id].deleted then
            out[#out + 1] = { id = s.id, label = s.label or s.id, town = s.town, deleted = true, config = true }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function broadcast() TriggerClientEvent('MULTItailor:stores', -1, publicList()) end

function TStores.get(id) return stores[id] end
function TStores.all() return adminList() end
function TStores.lines() return lines end

-- ---------------------------------------------------------------- start
CreateThread(function()
    if Config.Stores.enabled == false then return end
    TDB.ready()
    for _, r in ipairs(MySQL.query.await('SELECT id, data FROM `multitailor_stores`') or {}) do
        local ok, d = pcall(json.decode, r.data or '{}')
        if ok and type(d) == 'table' then overrides[r.id] = d end
    end
    rebuild()
    local cat, err = TS.catalogue()
    if not cat then
        print(('^1[MULTItailor] clothes stores: clothing catalogue not readable (%s) - nothing to sell^0'):format(tostring(err)))
    else
        local skipped
        lines, skipped = TL.resolveStoreCatalogue()
        lineById = {}
        for _, l in ipairs(lines) do lineById[l.id] = l end
        for _, s in ipairs(skipped) do print(('^3[MULTItailor] clothes stores: line %s skipped (%s)^0'):format(s.id, s.why)) end
        local n = 0
        for _ in pairs(stores) do n = n + 1 end
        print(('[MULTItailor] clothes stores: %d store(s), %d ready-made line(s)'):format(n, #lines))
    end
    broadcast()
end)

local asked = {}
RegisterNetEvent('MULTItailor:requestStores', function()
    local src = source
    local now = GetGameTimer()
    if asked[src] and now - asked[src] < 5000 then return end
    asked[src] = now
    TriggerClientEvent('MULTItailor:stores', src, publicList())
end)

-- ---------------------------------------------------------------- shopping
local function near(src, s)
    return TA.dist(src, s.clerk) <= (Config.Stores.serverDistance or 6.0)
end

local function stockKey(s, l, n) return ('%s|%s|%d'):format(s.id, l.id, n) end

local function linesFor(s)
    local out = {}
    local now = os.time()
    for _, l in ipairs(lines) do
        local price = TL.storePrice(l, s)
        if price then
            local colours = {}
            for _, c in ipairs(l.colours) do
                colours[#colours + 1] = { n = c.n, hash = c.hash, left = TL.stockLeft(stock, stockKey(s, l, c.n), now) }
            end
            out[#out + 1] = { id = l.id, sex = l.sex, cat = l.cat, catLabel = l.catLabel, group = l.group, vorp = l.vorp,
                              label = l.label, price = price, colours = colours }
        end
    end
    return out
end

-- Full catalogue: every Designer category that has a store price, with that price at this store.
local function catalogueCategories(s)
    local out = {}
    for _, c in ipairs(Config.Designer.categories or {}) do
        local price = TL.storePrice({ cat = c.id }, s)
        if price then out[#out + 1] = { id = c.id, label = c.label, group = c.group, price = price } end
    end
    return out
end

-- "Hat, style 12" (or the piece's own title when the clothing data has one)
local function pieceLabel(c, sex, m)
    local cat = TS.catalogue()
    local model = cat and cat[sex] and cat[sex][c.id] and cat[sex][c.id][m]
    if model and type(model.title) == 'string' and model.title ~= '' then return model.title end
    return L('store_piece_label', c.label, m)
end

lib.callback.register('multitailor:store:open', function(src, storeId)
    if not TA.rate(src, 'default') then return nil, L('err_slow') end
    local s = type(storeId) == 'string' and stores[storeId]
    if not s or not s.enabled then return nil, L('err_store_closed') end
    if not near(src, s) then return nil, L('err_too_far') end
    local payload = { storeId = s.id, label = s.label, town = s.town, cash = TA.money(src),
                      sex = TA.sex(src) or 'male', format = TA.clothingFormat(), sexLabels = Config.Designer.sexLabels }
    if Config.Stores.fullCatalogue ~= false and TS.catalogue() then
        payload.categories = catalogueCategories(s)   -- the client adds the style / colour counts itself
    else
        payload.lines = linesFor(s)
    end
    return payload
end)

-- Full catalogue: { storeId, sex, cat, m (style), v (colour) }. The hash and the price are worked out here.
lib.callback.register('multitailor:store:buyPiece', function(src, data)
    data = type(data) == 'table' and data or {}
    if Config.Stores.fullCatalogue == false then return { ok = false, error = L('err_bad_line') } end
    if not TA.rate(src, 'buy') then return { ok = false, error = L('err_slow') } end
    if busy[src] then return { ok = false, error = L('err_busy') } end
    local s = type(data.storeId) == 'string' and stores[data.storeId]
    if not s or not s.enabled then return { ok = false, error = L('err_store_closed') } end
    if not near(src, s) then return { ok = false, error = L('err_too_far') } end
    local sex = (data.sex == 'female' or data.sex == 'male') and data.sex or nil
    local c = type(data.cat) == 'string' and TS.category(data.cat)
    local m, v = TU.int(data.m, 1, 100000), TU.int(data.v, 1, 1000)
    local hash = sex and c and m and v and TS.resolve(sex, c.id, m, v)
    local price = hash and TL.storePrice({ cat = c.id }, s)
    if not hash or not price then return { ok = false, error = L('err_bad_line') } end
    if TA.clothingFormat() == 'unavailable' then return { ok = false, error = L('err_inventory_missing') } end
    busy[src] = true
    local res
    local ok, e = pcall(function()
        if TA.money(src) + 1e-9 < price then res = { ok = false, error = L('err_no_money', price) } return end
        if not TA.takeMoney(src, price) then res = { ok = false, error = L('err_no_money', price) } return end
        local label = pieceLabel(c, sex, m)
        local okG, gerr = TA.givePiece(src, {
            cat = c.id, hash = hash, sex = sex, m = m, v = v,
            label = label, description = L('store_item_desc', label, s.label),
        })
        if not okG then
            TA.giveMoney(src, price)
            TU.debug('store give failed: %s', tostring(gerr))
            res = { ok = false, error = (gerr == 'inventory_missing') and L('err_inventory_missing') or L('err_no_room') }
            return
        end
        TriggerEvent('MULTItailor:storePurchase', src, { storeId = s.id, cat = c.id, m = m, colour = v, price = price })
        TA.notify(src, L('store_bought', label, price), 'success')
        res = { ok = true, cash = TA.money(src), label = label, price = price }
    end)
    busy[src] = nil
    if not ok then print(('^1[MULTItailor] store purchase failed: %s^0'):format(tostring(e))) return { ok = false, error = L('err_generic') } end
    return res
end)

lib.callback.register('multitailor:store:buy', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'buy') then return { ok = false, error = L('err_slow') } end
    if busy[src] then return { ok = false, error = L('err_busy') } end
    local s = type(data.storeId) == 'string' and stores[data.storeId]
    if not s or not s.enabled then return { ok = false, error = L('err_store_closed') } end
    if not near(src, s) then return { ok = false, error = L('err_too_far') } end
    local l = type(data.lineId) == 'string' and lineById[data.lineId]
    local n = TU.int(data.colour, 1, 1000)
    local colour
    if l and n then for _, c in ipairs(l.colours) do if c.n == n then colour = c break end end end
    if not l or not colour then return { ok = false, error = L('err_bad_line') } end
    local price = TL.storePrice(l, s)
    if not price then return { ok = false, error = L('err_bad_line') } end
    if TA.clothingFormat() == 'unavailable' then return { ok = false, error = L('err_inventory_missing') } end
    busy[src] = true
    local res
    local ok, e = pcall(function()
        if TA.money(src) + 1e-9 < price then res = { ok = false, error = L('err_no_money', price) } return end
        local key = stockKey(s, l, colour.n)
        local okStock, left = TL.stockTake(stock, key, 1, os.time())
        if not okStock then res = { ok = false, error = L('err_sold_out') } return end
        local function putBack() if stock[key] then stock[key].left = stock[key].left + 1 end end
        if not TA.takeMoney(src, price) then putBack() res = { ok = false, error = L('err_no_money', price) } return end
        local okG, gerr = TA.givePiece(src, {
            cat = l.cat, hash = colour.hash, sex = l.sex, m = l.m, v = colour.v,
            label = l.label, description = L('store_item_desc', l.label, s.label),
        })
        if not okG then
            TA.giveMoney(src, price)
            putBack()
            TU.debug('store give failed: %s', tostring(gerr))
            res = { ok = false, error = (gerr == 'inventory_missing') and L('err_inventory_missing') or L('err_no_room') }
            return
        end
        TriggerEvent('MULTItailor:storePurchase', src, { storeId = s.id, line = l.id, colour = colour.n, price = price })
        TA.notify(src, L('store_bought', l.label, price), 'success')
        res = { ok = true, cash = TA.money(src), left = left }
    end)
    busy[src] = nil
    if not ok then print(('^1[MULTItailor] store purchase failed: %s^0'):format(tostring(e))) return { ok = false, error = L('err_generic') } end
    return res
end)

-- ---------------------------------------------------------------- admin (/tailorstores)
local function save(id, d, by)
    overrides[id] = d
    MySQL.insert.await('INSERT INTO `multitailor_stores` (id, data, updated_by, updated_at) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by), updated_at = VALUES(updated_at)',
        { id, json.encode(d), tostring(by or 'admin'), os.time() })
end

local function feet(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z - 1.0, w = GetEntityHeading(ped) }
end

lib.callback.register('multitailor:admin:stores', function(src)
    if not TA.isAdmin(src) then return nil end
    return { stores = adminList() }
end)

lib.callback.register('multitailor:admin:store', function(src, data)
    if not TA.isAdmin(src) then return { ok = false, error = L('err_no_access') } end
    if not TA.rate(src, 'admin') then return { ok = false, error = L('err_slow') } end
    data = type(data) == 'table' and data or {}
    local action = data.action
    local by = TA.name(src)
    local id = type(data.id) == 'string' and data.id:match('^[%w_%-]+$') and data.id or nil
    local d = id and TU.copy(overrides[id] or {}) or {}
    if action == 'create' then
        local label = TU.text(data.label, 48)
        if not label then return { ok = false, error = L('err_bad_name') } end
        local base = label:lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', ''):sub(1, 32)
        if base == '' then base = 'store' end
        id = base
        local i = 2
        while stores[id] or overrides[id] do id = ('%s_%d'):format(base, i) i = i + 1 end
        local pos = feet(src)
        if not pos then return { ok = false, error = L('err_generic') } end
        d = { label = label, town = TU.text(data.town, 32), clerk = pos, enabled = true, blip = true, priceMultiplier = 1.0 }
    elseif not id or (not stores[id] and not overrides[id]) then
        return { ok = false, error = L('err_not_found') }
    elseif action == 'move' then
        d.clerk = feet(src)
        if not d.clerk then return { ok = false, error = L('err_generic') } end
    elseif action == 'rename' then
        d.label = TU.text(data.label, 48)
        if not d.label then return { ok = false, error = L('err_bad_name') } end
    elseif action == 'toggle' then
        d.enabled = not (stores[id] and stores[id].enabled)
    elseif action == 'blip' then
        d.blip = not (stores[id] and stores[id].blip)
    elseif action == 'price' then
        d.priceMultiplier = TU.clamp(data.mult, 0.1, 10.0)
        if not d.priceMultiplier then return { ok = false, error = L('err_bad_amount') } end
    elseif action == 'model' then
        d.model = type(data.model) == 'string' and data.model:match('^[%w_]+$') and data.model:sub(1, 48) or nil
        if not d.model then return { ok = false, error = L('err_bad_name') } end
    elseif action == 'delete' then
        local isConfig = stores[id] and stores[id].config
        if isConfig then
            d = { deleted = true }
        else
            overrides[id] = nil
            MySQL.update.await('DELETE FROM `multitailor_stores` WHERE id = ?', { id })
            rebuild() broadcast()
            return { ok = true, stores = adminList() }
        end
    elseif action == 'reset' then
        overrides[id] = nil
        MySQL.update.await('DELETE FROM `multitailor_stores` WHERE id = ?', { id })
        rebuild() broadcast()
        return { ok = true, stores = adminList() }
    else
        return { ok = false, error = L('err_generic') }
    end
    save(id, d, by)
    rebuild()
    broadcast()
    print(('[MULTItailor] %s: clothes store %s %s'):format(by, tostring(id), tostring(action)))
    return { ok = true, id = id, stores = adminList() }
end)

AddEventHandler('playerDropped', function() busy[source] = nil asked[source] = nil end)

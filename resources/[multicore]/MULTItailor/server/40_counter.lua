--[[
    The tailor's counter: a shelf staff stock from their pockets (outfits, clothing, cloth), anyone
    buys from it (money -> the shop's till), and customers leave written orders.

    lib.callback:
      multitailor:counter:open    (pointId)                                  -> payload | nil, err
      multitailor:counter:buy     ({ pointId, lineId, qty })                 -> { ok, error?, payload? }
      multitailor:counter:stock   ({ pointId, itemId, name, qty, price })    -> { ok, error?, payload? }   staff
      multitailor:counter:reprice ({ pointId, lineId, price })               -> { ok, error?, payload? }   staff
      multitailor:counter:unstock ({ pointId, lineId })                      -> { ok, error?, payload? }   staff
      multitailor:orders:place    ({ pointId, sex, request })                -> { ok, error?, payload? }
      multitailor:orders:cancel   ({ pointId, id })                          -> { ok, error?, payload? }
      multitailor:orders:set      ({ pointId, id, status })                  -> { ok, error?, payload? }   staff
    Server events: 'MULTItailor:sale' (src, { businessId, item, qty, total }), 'MULTItailor:order' (src, { businessId, id, status }).
]]
TCounter = TCounter or {}

local busy = {}
local STATUS = { open = true, accepted = true, done = true, declined = true }

local function decode(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, v = pcall(json.decode, raw)
    return ok and type(v) == 'table' and v or nil
end

local function counterPoint(src, pointId)
    local p, err = TP.access(src, pointId, 'public')
    if not p then return nil, err end
    if p.kind ~= 'store' or not p.businessId then return nil, L('err_no_access') end
    local job = TA.job(src)
    local role = job and TL.roleAt(p, job) or nil
    return p, role, job
end

local function lineView(r)
    local meta = decode(r.metadata) or {}
    local label = r.label or meta.label or meta.outfit or TA.label(r.item)
    return {
        id = tonumber(r.id), item = r.item, label = label, qty = tonumber(r.qty) or 0, price = TU.money(r.price) or 0,
        description = type(meta.description) == 'string' and meta.description:sub(1, 200) or nil,
        quality = meta.quality_label, maker = meta.maker or meta.tailor,
        sex = TS.sexOf(meta.sex or meta.gender), unique = r.metadata ~= nil,
    }
end

function TCounter.lines(bid)
    local rows = MySQL.query.await('SELECT id, item, label, metadata, qty, price FROM `multitailor_shelf` WHERE business_id = ? AND qty > 0 ORDER BY item, price', { bid }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = lineView(r) end
    return out
end

local function orderRows(where, args)
    local rows = MySQL.query.await('SELECT id, business_id, customer_name, customer_cid, sex, request, status, handled_by, created_at, updated_at FROM `multitailor_orders` WHERE '
        .. where .. ' ORDER BY id DESC LIMIT 60', args) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { id = tonumber(r.id), customer = r.customer_name, sex = r.sex, request = r.request, status = r.status,
                          handledBy = r.handled_by, at = tonumber(r.created_at) or 0, updated = tonumber(r.updated_at) or 0 }
    end
    return out
end

local function stockable(src)
    local out = {}
    for _, it in ipairs(TA.items(src)) do
        if TL.allowedOnCounter(it.name) and it.count > 0 then
            local plain = next(it.metadata) == nil
            local suggest = plain and (Config.Counter.defaultPrices or {})[it.name] or TL.suggestPrice(it.metadata)
            out[#out + 1] = {
                id = it.id, name = it.name, count = it.count, plain = plain,
                label = (not plain and (it.metadata.label or it.metadata.outfit)) or it.label or TA.label(it.name),
                quality = it.metadata.quality_label, suggest = suggest,
            }
        end
    end
    return out
end

local function payload(src, p, role)
    local b = TP.business(p)
    local cid = TA.cid(src)
    local data = {
        pointId = p.id, businessLabel = b.label, town = b.town, staff = role ~= nil, boss = role == 'boss',
        lines = TCounter.lines(b.id), cash = TA.money(src), orders = {}, mine = {},
        sex = TA.sex(src) or 'male', ordersEnabled = Config.Orders.enabled ~= false, textMax = Config.Orders.textMax or 300,
        minPrice = Config.Counter.minPrice, maxPrice = Config.Counter.maxPrice,
    }
    if Config.Orders.enabled ~= false then
        if role then data.orders = orderRows("business_id = ? AND status IN ('open','accepted')", { b.id }) end
        if cid then data.mine = orderRows('business_id = ? AND customer_cid = ?', { b.id, cid }) end
    end
    if role then data.pockets = stockable(src) end
    return data
end

lib.callback.register('multitailor:counter:open', function(src, pointId)
    if not TA.rate(src, 'default') then return nil, L('err_slow') end
    local p, role = counterPoint(src, pointId)
    if not p then return nil, role end
    TDB.ready()
    return payload(src, p, role)
end)

-- ---------------------------------------------------------------- buy
lib.callback.register('multitailor:counter:buy', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'buy') then return { ok = false, error = L('err_slow') } end
    if busy[src] then return { ok = false, error = L('err_busy') } end
    local p, role = counterPoint(src, data.pointId)
    if not p then return { ok = false, error = role } end
    local lineId, qty = TU.int(data.lineId, 1, 2147483647), TU.int(data.qty, 1, 100)
    if not lineId or not qty then return { ok = false, error = L('err_bad_line') } end
    busy[src] = true
    local res
    local ok, e = pcall(function()
        local r = MySQL.single.await('SELECT id, item, label, metadata, qty, price FROM `multitailor_shelf` WHERE id = ? AND business_id = ?', { lineId, p.businessId })
        local meta = r and decode(r.metadata)
        if meta then qty = 1 end   -- one-of-a-kind garments are always sold singly
        if not r or (tonumber(r.qty) or 0) < qty then res = { ok = false, error = L('err_sold_out') } return end
        local total = TL.lineTotal(r.price, qty)
        if not total or total <= 0 then res = { ok = false, error = L('err_bad_line') } return end
        if TA.money(src) + 1e-9 < total then res = { ok = false, error = L('err_no_money', total) } return end
        if not meta and not TA.canCarry(src, r.item, qty) then res = { ok = false, error = L('err_no_room') } return end
        local took = MySQL.update.await('UPDATE `multitailor_shelf` SET qty = qty - ?, updated_at = ? WHERE id = ? AND business_id = ? AND qty >= ?',
            { qty, os.time(), lineId, p.businessId, qty })
        if (tonumber(took) or 0) < 1 then res = { ok = false, error = L('err_sold_out') } return end
        local function restock() MySQL.update.await('UPDATE `multitailor_shelf` SET qty = qty + ? WHERE id = ?', { qty, lineId }) end
        if not TA.takeMoney(src, total) then restock() res = { ok = false, error = L('err_no_money', total) } return end
        if not TA.give(src, r.item, qty, meta) then
            TA.giveMoney(src, total)
            restock()
            res = { ok = false, error = L('err_no_room') }
            return
        end
        MySQL.update.await('DELETE FROM `multitailor_shelf` WHERE id = ? AND qty <= 0', { lineId })
        TDB.till.credit(p.businessId, total, 'sale', TA.name(src), ('%dx %s'):format(qty, r.label or (meta and meta.label) or TA.label(r.item)))
        TriggerEvent('MULTItailor:sale', src, { businessId = p.businessId, item = r.item, qty = qty, total = total })
        TA.notify(src, L('bought', qty, (meta and meta.label) or r.label or TA.label(r.item), total), 'success')
        res = { ok = true, payload = payload(src, p, role) }
    end)
    busy[src] = nil
    if not ok then print(('^1[MULTItailor] counter buy failed: %s^0'):format(tostring(e))) return { ok = false, error = L('err_generic') } end
    return res
end)

-- ---------------------------------------------------------------- stock / price / unstock (staff)
local function staffPoint(src, pointId)
    local p, role, job = counterPoint(src, pointId)
    if not p then return nil, role end
    if not role then return nil, L('err_no_access') end
    return p, role, job
end

local function price(v)
    local n = TU.money(v)
    if not n or n < (Config.Counter.minPrice or 0.05) or n > (Config.Counter.maxPrice or 2500) then return nil end
    return n
end

lib.callback.register('multitailor:counter:stock', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    if busy[src] then return { ok = false, error = L('err_busy') } end
    local p, role, job = staffPoint(src, data.pointId)
    if not p then return { ok = false, error = role } end
    local okL, why = TA.licence(src, 'counterSales', job and job.name)
    if not okL then return { ok = false, error = why } end
    local ask = price(data.price)
    if not ask then return { ok = false, error = L('err_bad_price', Config.Counter.minPrice, Config.Counter.maxPrice) } end
    local qty = TU.int(data.qty, 1, 1000)
    if not qty then return { ok = false, error = L('err_bad_line') } end
    local it
    for _, x in ipairs(TA.items(src)) do
        if tostring(x.id) == tostring(data.itemId) and x.name == data.name then it = x break end
    end
    if not it or not TL.allowedOnCounter(it.name) then return { ok = false, error = L('err_not_stockable') } end
    busy[src] = true
    local res
    local ok, e = pcall(function()
        local n = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `multitailor_shelf` WHERE business_id = ?', { p.businessId })) or 0
        local plain = next(it.metadata) == nil
        if plain then
            qty = math.min(qty, it.count)
            local existing = MySQL.single.await('SELECT id FROM `multitailor_shelf` WHERE business_id = ? AND item = ? AND metadata IS NULL LIMIT 1', { p.businessId, it.name })
            if not existing and n >= (Config.Counter.maxLines or 80) then res = { ok = false, error = L('err_shelf_full') } return end
            if not TA.remove(src, it.name, qty) then res = { ok = false, error = L('err_not_stockable') } return end
            if existing then
                MySQL.update.await('UPDATE `multitailor_shelf` SET qty = qty + ?, price = ?, stocked_by = ?, updated_at = ? WHERE id = ?',
                    { qty, ask, TA.name(src), os.time(), existing.id })
            else
                MySQL.insert.await('INSERT INTO `multitailor_shelf` (business_id, item, label, metadata, qty, price, stocked_by, updated_at) VALUES (?, ?, ?, NULL, ?, ?, ?, ?)',
                    { p.businessId, it.name, TU.text(it.label, 80) or it.name, qty, ask, TA.name(src), os.time() })
            end
        else
            if n >= (Config.Counter.maxLines or 80) then res = { ok = false, error = L('err_shelf_full') } return end
            qty = 1
            if not TA.removeById(src, it.id, 1) then res = { ok = false, error = L('err_not_stockable') } return end
            local label = TU.text(it.metadata.label or it.metadata.outfit or it.label, 80) or it.name
            MySQL.insert.await('INSERT INTO `multitailor_shelf` (business_id, item, label, metadata, qty, price, stocked_by, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?, ?)',
                { p.businessId, it.name, label, json.encode(it.metadata), ask, TA.name(src), os.time() })
        end
        TA.notify(src, L('stocked', qty, it.label or it.name, ask), 'success')
        res = { ok = true, payload = payload(src, p, role) }
    end)
    busy[src] = nil
    if not ok then print(('^1[MULTItailor] stocking failed: %s^0'):format(tostring(e))) return { ok = false, error = L('err_generic') } end
    return res
end)

lib.callback.register('multitailor:counter:reprice', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, role = staffPoint(src, data.pointId)
    if not p then return { ok = false, error = role } end
    local ask, lineId = price(data.price), TU.int(data.lineId, 1, 2147483647)
    if not ask then return { ok = false, error = L('err_bad_price', Config.Counter.minPrice, Config.Counter.maxPrice) } end
    if not lineId then return { ok = false, error = L('err_bad_line') } end
    MySQL.update.await('UPDATE `multitailor_shelf` SET price = ?, updated_at = ? WHERE id = ? AND business_id = ?', { ask, os.time(), lineId, p.businessId })
    return { ok = true, payload = payload(src, p, role) }
end)

lib.callback.register('multitailor:counter:unstock', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    if busy[src] then return { ok = false, error = L('err_busy') } end
    local p, role = staffPoint(src, data.pointId)
    if not p then return { ok = false, error = role } end
    local lineId = TU.int(data.lineId, 1, 2147483647)
    if not lineId then return { ok = false, error = L('err_bad_line') } end
    busy[src] = true
    local res
    local ok, e = pcall(function()
        local r = MySQL.single.await('SELECT id, item, metadata, qty FROM `multitailor_shelf` WHERE id = ? AND business_id = ?', { lineId, p.businessId })
        local qty = r and TU.int(r.qty, 0, 100000) or 0
        if not r or qty < 1 then res = { ok = false, error = L('err_sold_out') } return end
        local meta = decode(r.metadata)
        if not meta and not TA.canCarry(src, r.item, qty) then res = { ok = false, error = L('err_no_room') } return end
        local took = MySQL.update.await('DELETE FROM `multitailor_shelf` WHERE id = ? AND business_id = ? AND qty = ?', { lineId, p.businessId, qty })
        if (tonumber(took) or 0) < 1 then res = { ok = false, error = L('err_sold_out') } return end
        if not TA.give(src, r.item, qty, meta) then
            if meta then
                MySQL.insert.await('INSERT INTO `multitailor_shelf` (business_id, item, label, metadata, qty, price, stocked_by, updated_at) VALUES (?, ?, NULL, ?, ?, ?, ?, ?)',
                    { p.businessId, r.item, r.metadata, qty, Config.Counter.minPrice or 0.05, 'returned', os.time() })
            else
                MySQL.insert.await('INSERT INTO `multitailor_shelf` (business_id, item, label, metadata, qty, price, stocked_by, updated_at) VALUES (?, ?, NULL, NULL, ?, ?, ?, ?)',
                    { p.businessId, r.item, qty, Config.Counter.minPrice or 0.05, 'returned', os.time() })
            end
            res = { ok = false, error = L('err_no_room') }
            return
        end
        res = { ok = true, payload = payload(src, p, role) }
    end)
    busy[src] = nil
    if not ok then print(('^1[MULTItailor] unstock failed: %s^0'):format(tostring(e))) return { ok = false, error = L('err_generic') } end
    return res
end)

-- ---------------------------------------------------------------- orders
local function notifyCustomer(cid, text)
    for _, id in ipairs(TA.players()) do
        if TA.cid(id) == cid then TA.notify(id, text, 'inform') return end
    end
end

lib.callback.register('multitailor:orders:place', function(src, data)
    data = type(data) == 'table' and data or {}
    if Config.Orders.enabled == false then return { ok = false, error = L('err_no_access') } end
    if not TA.rate(src, 'buy') then return { ok = false, error = L('err_slow') } end
    local p, role = counterPoint(src, data.pointId)
    if not p then return { ok = false, error = role } end
    local cid = TA.cid(src)
    local text = TU.text(data.request, Config.Orders.textMax or 300)
    local sex = TS.sexOf(data.sex) or TA.sex(src) or 'male'
    if not cid then return { ok = false, error = L('err_generic') } end
    if not text or #text < 5 then return { ok = false, error = L('err_order_text') } end
    local mine = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM `multitailor_orders` WHERE customer_cid = ? AND business_id = ? AND status IN ('open','accepted')", { cid, p.businessId })) or 0
    if mine >= (Config.Orders.maxOpenPerCustomer or 2) then return { ok = false, error = L('err_order_limit') } end
    local shop = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM `multitailor_orders` WHERE business_id = ? AND status IN ('open','accepted')", { p.businessId })) or 0
    if shop >= (Config.Orders.perShop or 40) then return { ok = false, error = L('err_order_book_full') } end
    local id = MySQL.insert.await('INSERT INTO `multitailor_orders` (business_id, customer_name, customer_cid, sex, request, status, handled_by, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?)',
        { p.businessId, TA.name(src), cid, sex, text, 'open', os.time(), os.time() })
    TriggerEvent('MULTItailor:order', src, { businessId = p.businessId, id = id, status = 'open' })
    -- tell staff of this shop who are on shift nearby / online
    for _, other in ipairs(TA.players()) do
        local job = TA.job(other)
        if other ~= src and job and TL.roleAt(p, job) then TA.notify(other, L('order_new_staff', TA.name(src)), 'inform') end
    end
    TA.notify(src, L('order_placed'), 'success')
    return { ok = true, payload = payload(src, p, role) }
end)

lib.callback.register('multitailor:orders:cancel', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, role = counterPoint(src, data.pointId)
    if not p then return { ok = false, error = role } end
    local id, cid = TU.int(data.id, 1, 2147483647), TA.cid(src)
    if not id or not cid then return { ok = false, error = L('err_bad_line') } end
    MySQL.update.await("UPDATE `multitailor_orders` SET status = 'cancelled', updated_at = ? WHERE id = ? AND customer_cid = ? AND business_id = ? AND status IN ('open','accepted')",
        { os.time(), id, cid, p.businessId })
    return { ok = true, payload = payload(src, p, role) }
end)

lib.callback.register('multitailor:orders:set', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, role = staffPoint(src, data.pointId)
    if not p then return { ok = false, error = role } end
    local id = TU.int(data.id, 1, 2147483647)
    local status = type(data.status) == 'string' and STATUS[data.status] and data.status or nil
    if not id or not status then return { ok = false, error = L('err_bad_line') } end
    local row = MySQL.single.await('SELECT customer_cid FROM `multitailor_orders` WHERE id = ? AND business_id = ?', { id, p.businessId })
    if not row then return { ok = false, error = L('err_bad_line') } end
    MySQL.update.await('UPDATE `multitailor_orders` SET status = ?, handled_by = ?, updated_at = ? WHERE id = ? AND business_id = ?',
        { status, TA.name(src), os.time(), id, p.businessId })
    TriggerEvent('MULTItailor:order', src, { businessId = p.businessId, id = id, status = status })
    notifyCustomer(row.customer_cid, L('order_status_' .. status, TP.business(p).label))
    return { ok = true, payload = payload(src, p, role) }
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)

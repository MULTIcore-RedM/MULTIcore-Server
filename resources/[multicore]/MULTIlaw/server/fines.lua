-- ============================================================
-- MULTIlaw :: fines
-- A lawman writes a fine; the money goes to a MULTIbank account (the
-- officer's job account or a fixed county account) when it is paid,
-- at once or later with /fines.
-- ============================================================

local getP, fail, okRes = Law.getP, Law.fail, Law.okRes

local function row(r)
    return { id = tonumber(r.id), amount = tonumber(r.amount) or 0, reason = r.reason, officer = r.officer,
        created = tonumber(r.created_at) or 0, paid = r.paid_at ~= nil, account = r.account }
end

--- officer fines target → answer table (res.id = the fine's number)
function Law.Fine(officer, target, amount, reason)
    officer, target = tonumber(officer), tonumber(target)
    local P, T = getP(officer), getP(target)
    if not P or not T or officer == target then return fail('no_player') end
    local ok, err = Law.Can(P, 'fine')
    if not ok then return fail(err) end
    if not Law.playersNear(officer, target, Config.Fines.Distance) then return fail('too_far') end
    amount = Law.money(amount)
    if not amount or amount < Config.Fines.Min or amount > Config.Fines.Max then
        return fail('fine_limits', Law.fmt(Config.Fines.Min), Law.fmt(Config.Fines.Max))
    end
    reason = Law.text(reason, Config.Fines.ReasonLength)
    if reason == '' then return fail('need_reason') end
    local account = Law.AccountFor(P, Config.Fines.Account)
    if not account then return fail('failed') end
    local cid = Law.cidOf(T)
    local open = MySQL.scalar.await('SELECT COUNT(*) FROM `multilaw_fines` WHERE `citizenid` = ? AND `paid_at` IS NULL', { cid }) or 0
    if tonumber(open) >= Config.Fines.MaxUnpaid then return fail('too_many_fines') end
    local id = MySQL.insert.await([[INSERT INTO `multilaw_fines` (`citizenid`, `name`, `amount`, `reason`, `account`, `officer_cid`, `officer`, `created_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)]], { cid, Law.nameOf(T), amount, reason, account, Law.cidOf(P), Law.nameOf(P), os.time() })
    if not id then return fail('failed') end
    Law.AddRecord(cid, Law.nameOf(T), 'fine', { detail = reason, amount = amount, officer = Law.nameOf(P) })
    TriggerClientEvent('MULTIlaw:client:fined', target, { id = id, amount = amount, reason = reason, officer = Law.nameOf(P) })
    TriggerEvent('MULTIlaw:server:fined', target, id, amount, account)
    local res = okRes('fine_written', Law.fmt(amount), Law.nameOf(T))
    res.id = id
    return res
end

--- the player's own fines (unpaidOnly = true for the pay list)
function Law.GetFines(cid, unpaidOnly)
    local q = 'SELECT * FROM `multilaw_fines` WHERE `citizenid` = ?' .. (unpaidOnly and ' AND `paid_at` IS NULL' or '') .. ' ORDER BY `id` DESC LIMIT 50'
    local out = {}
    for _, r in ipairs(MySQL.query.await(q, { cid }) or {}) do out[#out + 1] = row(r) end
    return out
end

local paying = {}

--- the player pays one of his own fines → answer table
function Law.PayFine(src, id)
    src, id = tonumber(src), Law.int(id)
    local P = getP(src)
    if not P or not id then return fail('failed') end
    if paying[src] then return fail('busy') end
    paying[src] = true
    local res = (function()
        local r = MySQL.single.await('SELECT * FROM `multilaw_fines` WHERE `id` = ? AND `citizenid` = ? AND `paid_at` IS NULL', { id, Law.cidOf(P) })
        if not r then return fail('no_fine') end
        local amount = Law.money(r.amount)
        if GetResourceState('MULTIbank') ~= 'started' then return fail('no_bank') end
        local paidWith
        for _, kind in ipairs(Config.Fines.PayFrom) do
            if (P.Functions.GetMoney(kind) or 0) >= amount and P.Functions.RemoveMoney(kind, amount, 'multilaw-fine') then
                paidWith = kind
                break
            end
        end
        if not paidWith then return fail('cant_afford', Law.fmt(amount)) end
        -- mark paid first (only one payment can win), then credit the county
        local changed = MySQL.update.await('UPDATE `multilaw_fines` SET `paid_at` = ? WHERE `id` = ? AND `paid_at` IS NULL', { os.time(), id })
        if not changed or changed < 1 then
            P.Functions.AddMoney(paidWith, amount, 'multilaw-fine-refund')
            return fail('no_fine')
        end
        if Law.Bank('AddAccountMoney', r.account, amount, ('fine #%d'):format(id)) ~= true then
            P.Functions.AddMoney(paidWith, amount, 'multilaw-fine-refund')
            MySQL.update.await('UPDATE `multilaw_fines` SET `paid_at` = NULL WHERE `id` = ?', { id })
            return fail('no_bank')
        end
        TriggerEvent('MULTIlaw:server:finePaid', src, id, amount, r.account)
        return okRes('fine_paid', Law.fmt(amount))
    end)()
    paying[src] = nil
    return res
end

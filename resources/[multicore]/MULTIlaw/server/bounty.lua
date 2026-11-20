-- ============================================================
-- MULTIlaw :: wanted posters and bounties
-- A lawman posts a bounty on a character; it shows on every bounty
-- board. When a lawman jails that character, the reward is paid from
-- the poster's account (MULTIbank) to the jailing lawman. Posters come
-- down after Config.Bounty.ExpireHours.
-- ============================================================

local getP, fail, okRes, dbg = Law.getP, Law.fail, Law.okRes, Law.dbg

--- online server id, or a citizenid of any character → cid, name
local function resolveTarget(t)
    local n = tonumber(t)
    if n then
        local T = getP(n)
        if T then return Law.cidOf(T), Law.nameOf(T) end
    end
    if type(t) == 'string' and t:match('^[%w]+$') and #t <= 50 then
        local T = Law.byCid(t)
        if T then return t, Law.nameOf(T) end
        local r = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { t })
        if r then return t, Law.nameFromCharinfo(r.charinfo) or t end
    end
    return nil
end

--- money already promised by open posters on an account
local function pledged(account)
    return tonumber(MySQL.scalar.await("SELECT COALESCE(SUM(`reward`), 0) FROM `multilaw_bounties` WHERE `account` = ? AND `status` = 'open' AND `expires_at` > ?",
        { account, os.time() })) or 0
end

--- officer posts a bounty. data = { target = server id or citizenid, reward, reason } → answer table (res.id)
function Law.PostBounty(officer, data)
    officer = tonumber(officer)
    local P = getP(officer)
    if not P or type(data) ~= 'table' then return fail('failed') end
    local ok, err = Law.Can(P, 'bounty')
    if not ok then return fail(err) end
    if not Config.Bounty.PostAnywhere and not Law.OfficeAt(officer, P) then return fail('not_at_office') end
    local cid, name = resolveTarget(data.target)
    if not cid then return fail('no_person') end
    if cid == Law.cidOf(P) then return fail('not_self') end
    local reward = Law.money(data.reward)
    if not reward or reward < Config.Bounty.Min or reward > Config.Bounty.Max then
        return fail('bounty_limits', Law.fmt(Config.Bounty.Min), Law.fmt(Config.Bounty.Max))
    end
    local reason = Law.text(data.reason, Config.Bounty.ReasonLength)
    if reason == '' then return fail('need_reason') end
    local now = os.time()
    local onTarget = MySQL.scalar.await("SELECT COUNT(*) FROM `multilaw_bounties` WHERE `citizenid` = ? AND `status` = 'open' AND `expires_at` > ?", { cid, now }) or 0
    if tonumber(onTarget) >= Config.Bounty.PerTarget then return fail('too_many_bounties') end
    local account = Law.AccountFor(P, Config.Bounty.Account)
    if not account then return fail('failed') end
    if GetResourceState('MULTIbank') ~= 'started' then return fail('no_bank') end
    local balance = tonumber(Law.Bank('GetAccountBalance', account)) or 0
    if balance < pledged(account) + reward then return fail('bounty_no_funds', Law.fmt(balance - pledged(account))) end
    local id = MySQL.insert.await([[INSERT INTO `multilaw_bounties` (`citizenid`, `name`, `reward`, `reason`, `account`, `poster_cid`, `poster`, `created_at`, `expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { cid, name, reward, reason, account, Law.cidOf(P), Law.nameOf(P), now, now + Config.Bounty.ExpireHours * 3600 })
    if not id then return fail('failed') end
    Law.AddRecord(cid, name, 'bounty', { detail = reason, amount = reward, officer = Law.nameOf(P) })
    TriggerEvent('MULTIlaw:server:bountyPosted', id, cid, reward)
    local res = okRes('bounty_posted', name, Law.fmt(reward))
    res.id = id
    return res
end

--- open posters for the boards
function Law.GetBounties()
    local now = os.time()
    local out = {}
    for _, r in ipairs(MySQL.query.await("SELECT * FROM `multilaw_bounties` WHERE `status` = 'open' AND `expires_at` > ? ORDER BY `reward` DESC, `id` DESC LIMIT 60", { now }) or {}) do
        out[#out + 1] = { id = tonumber(r.id), name = r.name, reward = tonumber(r.reward) or 0, reason = r.reason, poster = r.poster,
            created = tonumber(r.created_at) or 0, expires = tonumber(r.expires_at) or 0, left = (tonumber(r.expires_at) or 0) - now,
            mine = false, cid = r.citizenid, posterCid = r.poster_cid, account = r.account }
    end
    return out
end

--- takes a poster down (the poster himself, a boss of the paying job, or an admin)
function Law.CancelBounty(officer, id)
    officer, id = tonumber(officer), Law.int(id)
    local P = getP(officer)
    if not P or not id then return fail('failed') end
    local r = MySQL.single.await("SELECT * FROM `multilaw_bounties` WHERE `id` = ? AND `status` = 'open'", { id })
    if not r then return fail('no_bounty') end
    if not Law.IsAdmin(officer) then
        local ok, err = Law.Can(P, 'bounty')
        if not ok then return fail(err) end
        local job = Law.LawJob(P)
        local boss = job and job.isboss and job.name == r.account
        if r.poster_cid ~= Law.cidOf(P) and not boss then return fail('not_your_bounty') end
    end
    MySQL.update.await("UPDATE `multilaw_bounties` SET `status` = 'cancelled', `closed_at` = ? WHERE `id` = ?", { os.time(), id })
    return okRes('bounty_cancelled', r.name)
end

--- pays every open bounty on `cid` to the jailing lawman. → total paid
function Law.ClaimBounties(cid, officer)
    local P = getP(officer)
    if not P or not cid then return 0 end
    local now, total = os.time(), 0
    local rows = MySQL.query.await("SELECT * FROM `multilaw_bounties` WHERE `citizenid` = ? AND `status` = 'open' AND `expires_at` > ?", { cid, now }) or {}
    for _, r in ipairs(rows) do
        local reward = Law.money(r.reward)
        local own = r.poster_cid == Law.cidOf(P)
        if cid ~= Law.cidOf(P) and (Config.Bounty.ClaimOwn or not own) then
            -- close the poster first so it can be paid only once
            local changed = MySQL.update.await("UPDATE `multilaw_bounties` SET `status` = 'claimed', `claimed_by` = ?, `closed_at` = ? WHERE `id` = ? AND `status` = 'open'",
                { Law.nameOf(P), now, r.id })
            if changed and changed > 0 then
                if Law.Bank('RemoveAccountMoney', r.account, reward, ('bounty #%d'):format(r.id)) == true then
                    P.Functions.AddMoney(Config.Bounty.PayTo, reward, 'multilaw-bounty')
                    total = total + reward
                    Law.AddRecord(cid, r.name, 'bounty_claimed', { detail = r.reason, amount = reward, officer = Law.nameOf(P) })
                    Law.notify(officer, _L('bounty_claimed', Law.fmt(reward), r.name), 'money')
                    TriggerEvent('MULTIlaw:server:bountyClaimed', r.id, cid, officer, reward)
                else
                    MySQL.update.await("UPDATE `multilaw_bounties` SET `status` = 'open', `claimed_by` = NULL, `closed_at` = NULL WHERE `id` = ?", { r.id })
                    Law.notify(officer, _L('bounty_unpaid', r.name), 'error')
                    dbg('bounty not paid, account short', r.id, r.account)
                end
            end
        end
    end
    return total
end

--- posters past their time come down
function Law.ExpireBounties()
    return MySQL.update.await("UPDATE `multilaw_bounties` SET `status` = 'expired', `closed_at` = ? WHERE `status` = 'open' AND `expires_at` <= ?", { os.time(), os.time() }) or 0
end

CreateThread(function()
    Law.WaitReady(60000)
    while true do
        pcall(Law.ExpireBounties)
        Wait(60000)
    end
end)

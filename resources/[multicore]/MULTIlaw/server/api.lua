-- ============================================================
-- MULTIlaw :: alerts, the client's requests, commands and exports
-- ============================================================

local getP, fail, okRes, dbg = Law.getP, Law.fail, Law.okRes, Law.dbg

---------------------------------
-- law alerts
---------------------------------
local function toVec(c)
    if type(c) == 'vector3' or type(c) == 'vector4' then return vector3(c.x, c.y, c.z) end
    if type(c) == 'table' and tonumber(c.x) and tonumber(c.y) and tonumber(c.z) then return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0) end
    if type(c) == 'table' and tonumber(c[1]) and tonumber(c[2]) and tonumber(c[3]) then return vector3(c[1] + 0.0, c[2] + 0.0, c[3] + 0.0) end
end

--- sends a map alert to every lawman on duty who takes alerts → how many got it
function Law.Alert(coords, text)
    coords = toVec(coords)
    if not coords then return 0 end
    text = Law.text(text, Config.Alerts.TextLength)
    if text == '' then text = _L('alert_default') end
    local types = {}
    for t in pairs(Config.Permissions.alerts or {}) do types[t] = true end
    local list = Law.OnDuty(types)
    for _, s in ipairs(list) do TriggerClientEvent('MULTIlaw:client:alert', s, coords, text) end
    TriggerEvent('MULTIlaw:server:alert', coords, text, #list)
    return #list
end

local lastAlert = {}
--- an alert a player's client sends (emergency button, scripts' client exports). → count or false
function Law.ClientAlert(src, text, coords)
    src = tonumber(src)
    if not getP(src) then return false end
    local now = GetGameTimer()
    if lastAlert[src] and now - lastAlert[src] < Config.Alerts.Cooldown then return false end
    lastAlert[src] = now
    local pos = Law.coordsOf(src)
    local c = toVec(coords)
    -- a sent position is only used when it is near the sender
    if pos and (not c or #(c - pos) > Config.Alerts.MaxCoordsOffset) then c = pos end
    if not c then return false end
    return Law.Alert(c, text)
end
AddEventHandler('playerDropped', function() lastAlert[source] = nil end)

RegisterNetEvent('MULTIlaw:server:alert', function(coords, text)
    Law.ClientAlert(source, text, coords)
end)

---------------------------------
-- jail with an automatic place
---------------------------------
--- place = 'cell' | 'prison' | 'auto' (a cell when the time fits and one is near, else Sisika)
function Law.JailAt(officer, target, minutes, place, opts)
    if place == 'auto' or place == nil then
        local m = Law.int(minutes) or 0
        if m >= 1 and m <= Config.Jail.CellMaxMinutes then
            local res = Law.Jail(officer, target, m, 'cell', opts)
            if res.ok or res.err ~= 'no_cell' then return res end
        end
        return Law.Jail(officer, target, minutes, 'prison', opts)
    end
    return Law.Jail(officer, target, minutes, place, opts)
end

---------------------------------
-- requests from MULTIlaw's own client
---------------------------------
local actions = {
    cuff = function(src, t) return Law.ToggleCuff(src, t) end,
    escort = function(src, t) return Law.ToggleEscort(src, t) end,
    putin = function(src, t, d) return Law.PutIn(src, t, d.netId, d.kind) end,
    takeout = function(src, t) return Law.TakeOut(src, t) end,
    search = function(src, t) return Law.Search(src, t) end,
    confiscateList = function(src, t) return Law.ConfiscateList(src, t) end,
    confiscate = function(src, t, d) return Law.Confiscate(src, t, d.slot, d.amount) end,
    jail = function(src, t, d) return Law.JailAt(src, t, d.minutes, d.place, { reason = d.reason }) end,
    release = function(src, t)
        local T = getP(t)
        if not T then return fail('no_player') end
        return Law.Release(Law.cidOf(T), src)
    end,
    fine = function(src, t, d) return Law.Fine(src, t, d.amount, d.reason) end,
}

lib.callback.register('MULTIlaw:action', function(src, action, target, data)
    if not Law.rateOk(src) then return fail('busy') end
    local fn = actions[action]
    if not fn then return fail('failed') end
    local ok, res = pcall(fn, src, tonumber(target), type(data) == 'table' and data or {})
    if not ok then
        print(('^1[MULTIlaw] action %s failed: %s^7'):format(tostring(action), tostring(res)))
        return fail('failed')
    end
    return res
end)

-- what the client may show on a player (MULTItarget canInteract): cuffed, escorted, in a wagon
lib.callback.register('MULTIlaw:targetState', function(src, target)
    target = tonumber(target)
    if not target then return {} end
    return { cuffed = Law.IsCuffed(target), escorted = Law.escorts[target] == src, inVehicle = Law.inVehicle[target] == true }
end)

-- office: evidence locker
lib.callback.register('MULTIlaw:office:evidence', function(src)
    if not Law.rateOk(src) then return fail('busy') end
    return Law.OpenEvidence(src)
end)

-- office: post a bounty
lib.callback.register('MULTIlaw:bounty:post', function(src, data)
    if not Law.rateOk(src) then return fail('busy') end
    return Law.PostBounty(src, data)
end)

lib.callback.register('MULTIlaw:bounty:cancel', function(src, id)
    if not Law.rateOk(src) then return fail('busy') end
    return Law.CancelBounty(src, id)
end)

-- a bounty board: anyone standing at one (or at an office)
local function atBoard(src)
    for _, b in ipairs(Config.Boards) do if Law.near(src, b.coords, Config.CloseDistance) then return true end end
    return Law.OfficeAt(src, getP(src)) ~= nil
end

lib.callback.register('MULTIlaw:board:list', function(src)
    if not Law.rateOk(src) then return fail('busy') end
    local P = getP(src)
    if not P then return fail('failed') end
    if not atBoard(src) then return fail('not_at_board') end
    local cid = Law.cidOf(P)
    local job = Law.LawJob(P)
    local law = Law.Can(P, 'bounty')
    local list = {}
    for _, b in ipairs(Law.GetBounties()) do
        list[#list + 1] = {
            id = b.id, name = b.name, reward = b.reward, reason = b.reason, poster = b.poster, left = b.left,
            canCancel = law and (b.posterCid == cid or (job and job.isboss and job.name == b.account)) or Law.IsAdmin(src),
        }
    end
    local res = okRes()
    res.list = list
    res.law = law == true
    return res
end)

-- the player's own fines
lib.callback.register('MULTIlaw:fines:mine', function(src)
    local P = getP(src)
    if not P then return fail('failed') end
    local res = okRes()
    res.list = Law.GetFines(Law.cidOf(P), true)
    return res
end)

lib.callback.register('MULTIlaw:fines:pay', function(src, id)
    if not Law.rateOk(src) then return fail('busy') end
    return Law.PayFine(src, id)
end)

-- the client reports what it saw when the player is put back in a cell by another script
Law.Net['MULTIlaw:server:metaJail'] = function(src)
    if not Law.rateOk(src) then return end
    return Law.JailFromMeta(src)
end
RegisterNetEvent('MULTIlaw:server:metaJail', function() Law.Net['MULTIlaw:server:metaJail'](source) end)

-- the client asks whether this player may use the law tools (menus only; every action is checked again)
lib.callback.register('MULTIlaw:isLaw', function(src)
    local P = getP(src)
    local out = {}
    for action in pairs(Config.Permissions) do out[action] = Law.Can(P, action) == true end
    return out
end)

---------------------------------
-- commands that need no target
---------------------------------
if Config.Commands.Unjail ~= '' then
    RegisterCommand(Config.Commands.Unjail, function(src, args)
        if src == 0 then
            local T = getP(tonumber(args[1]))
            if T then print(Law.Release(Law.cidOf(T)).msg or '') end
            return
        end
        local T = getP(tonumber(args[1]))
        if not T then return Law.notify(src, _L('no_player'), 'error') end
        Law.say(src, Law.Release(Law.cidOf(T), src))
    end, false)
end

---------------------------------
-- exports
---------------------------------
exports('Alert', function(coords, text) return Law.Alert(coords, text) end)
exports('IsLaw', function(src) return Law.Can(getP(src), 'cuff') == true or Law.Can(getP(src), 'jail') == true end)
exports('IsLawJob', function(src) return Law.LawJob(getP(src)) ~= nil end)
exports('GetLawCount', function() return #Law.OnDuty() end)
exports('IsCuffed', function(src) return Law.IsCuffed(src) end)
exports('SetCuffed', function(src, on) return Law.SetCuffed(src, on == true, 0) end)
exports('Cuff', function(officer, target) return Law.Cuff(officer, target) end)
exports('Uncuff', function(officer, target) return Law.Uncuff(officer, target) end)
exports('Jail', function(target, minutes, place, reason, officer)
    return Law.JailAt(officer, target, minutes, place or 'auto', { reason = reason, skipChecks = officer == nil })
end)
exports('Release', function(who, by)
    if type(who) ~= 'string' then who = Law.cidOf(getP(who)) end
    if not who then return fail('no_player') end
    return Law.Release(who, by)
end)
exports('IsJailed', function(who)
    if type(who) ~= 'string' then who = Law.cidOf(getP(who)) end
    return Law.IsJailed(who), Law.JailLeft(who)
end)
exports('Fine', function(officer, target, amount, reason) return Law.Fine(officer, target, amount, reason) end)
exports('PayFine', function(src, id) return Law.PayFine(src, id) end)
exports('GetFines', function(cid, unpaidOnly) return Law.GetFines(cid, unpaidOnly) end)
exports('PostBounty', function(officer, data) return Law.PostBounty(officer, data) end)
exports('CancelBounty', function(officer, id) return Law.CancelBounty(officer, id) end)
exports('GetBounties', function() return Law.GetBounties() end)
exports('AddRecord', function(cid, name, kind, data) return Law.AddRecord(cid, name, kind, data) end)
exports('GetRecord', function(cid) return Law.GetRecord(cid) end)
exports('SearchRecords', function(q) return Law.SearchRecords(q) end)
exports('Search', function(officer, target) return Law.Search(officer, target) end)
exports('Confiscate', function(officer, target, slot, amount) return Law.Confiscate(officer, target, slot, amount) end)
exports('IsReady', function() return Law.ready end)

---------------------------------
-- self-test hooks (only with setr multicore_selftest true)
---------------------------------
if Law.SELFTEST then
    exports('_TestNet', function(name, src, ...)
        local fn = Law.Net[name]
        if not fn then return 'no_handler' end
        return fn(tonumber(src), ...)
    end)
    exports('_TestTick', function()
        Law.JailTick()
        Law.ExpireBounties()
        return true
    end)
    exports('_TestCheckLogin', function(src) Law.CheckLogin(src) return true end)
    -- reads the jail table again, as after a server restart
    exports('_TestReload', function() return Law.LoadJail() end)
end

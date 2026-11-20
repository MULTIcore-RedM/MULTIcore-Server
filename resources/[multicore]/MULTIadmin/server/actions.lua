-- ============================================================
-- MULTIadmin :: server actions
-- One callback, 'MULTIadmin:action', takes (action, data). Each handler
-- checks the action permission, validates every value, acts, logs.
-- Handlers return ok, message, extraData. Text comes from locales/.
-- ============================================================

local Bans = Admin.Bans
local H = {}            -- action handlers: H[name](src, data) -> ok, message, data
local spectating = {}   -- admin src -> { target, bucket }
local LIM = Config.TextLimits

-- ---------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------

local function online(id)
    id = tonumber(id)
    if not id or id < 1 or not GetPlayerName(id) then return nil end
    return math.floor(id)
end

local function cleanText(s, max)
    s = tostring(s or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return s:sub(1, max)
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
end

local function inList(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

--- Target actions share these checks: valid online target, rank protection.
local function target(src, data, action)
    local t = online(data and data.target)
    if not t then return nil, _L('err_offline') end
    if not Admin.CanTarget(src, t) then
        Admin.Log(src, action .. ' (refused: higher rank)', nil, t)
        return nil, _L('err_rank')
    end
    return t
end

local function player(t)
    local P = RSGCore.Functions.GetPlayer(t)
    if not P then return nil, _L('err_nochar') end
    return P
end

local function sameBucket(mover, anchor)
    local bucket = GetPlayerRoutingBucket(anchor)
    if GetPlayerRoutingBucket(mover) ~= bucket then SetPlayerRoutingBucket(mover, bucket) end
end

-- ---------------------------------------------------------------
-- players tab
-- ---------------------------------------------------------------

H['goto'] = function(src, data)
    local t, err = target(src, data, 'goto')
    if not t then return false, err end
    local c = pedCoords(t)
    if not c then return false, _L('err_notfound') end
    sameBucket(src, t)
    TriggerClientEvent('MULTIadmin:client:teleport', src, c, true)
    Admin.Log(src, 'goto', nil, t)
    return true
end

H.bring = function(src, data)
    local t, err = target(src, data, 'bring')
    if not t then return false, err end
    local c = pedCoords(src)
    if not c then return false, _L('err_selfpos') end
    sameBucket(t, src)
    TriggerClientEvent('MULTIadmin:client:teleport', t, c, true)
    Admin.Log(src, 'bring', nil, t)
    return true
end

H.freeze = function(src, data)
    local t, err = target(src, data, 'freeze')
    if not t then return false, err end
    local state = not Admin.Frozen[t]
    Admin.Frozen[t] = state or nil
    TriggerClientEvent('MULTIadmin:client:freeze', t, state)
    Admin.Notify(t, _L(state and 'frozen_msg' or 'unfrozen_msg'), { type = state and 'warning' or 'info' })
    Admin.Log(src, state and 'freeze' or 'unfreeze', nil, t)
    return true, _L(state and 'ok_frozen' or 'ok_unfrozen')
end

H.spectate = function(src, data)
    if data.stop then
        local s = spectating[src]
        spectating[src] = nil
        if s and s.bucket and GetPlayerRoutingBucket(src) ~= s.bucket then SetPlayerRoutingBucket(src, s.bucket) end
        TriggerClientEvent('MULTIadmin:client:spectate', src, false)
        Admin.Log(src, 'spectate stop', nil, s and online(s.target) or nil)
        return true
    end
    local t, err = target(src, data, 'spectate')
    if not t then return false, err end
    if t == src then return false, _L('err_spectate_self') end
    local c = pedCoords(t)
    if not c then return false, _L('err_notfound') end
    spectating[src] = spectating[src] or { bucket = GetPlayerRoutingBucket(src) }
    spectating[src].target = t
    sameBucket(src, t)
    TriggerClientEvent('MULTIadmin:client:spectate', src, true, t, c)
    Admin.Log(src, 'spectate', nil, t)
    return true
end

local function heal(t)
    exports.vorp_core:GetCore().Player.Heal(t)
    if Config.LocalHealthFallback then TriggerClientEvent('MULTIadmin:client:heal', t) end
end

local function revive(t)
    exports.vorp_core:GetCore().Player.Revive(t)
    if Config.LocalHealthFallback then TriggerClientEvent('MULTIadmin:client:revive', t) end
end

H.heal = function(src, data)
    local t, err = target(src, data, 'heal')
    if not t then return false, err end
    heal(t)
    Admin.Log(src, 'heal', nil, t)
    return true
end

H.revive = function(src, data)
    local t, err = target(src, data, 'revive')
    if not t then return false, err end
    revive(t)
    Admin.Log(src, 'revive', nil, t)
    return true
end

H.kill = function(src, data)
    local t, err = target(src, data, 'kill')
    if not t then return false, err end
    TriggerClientEvent('MULTIadmin:client:kill', t)
    Admin.Log(src, 'kill', nil, t)
    return true
end

H.kick = function(src, data)
    local t, err = target(src, data, 'kick')
    if not t then return false, err end
    local reason = cleanText(data.reason, LIM.Reason)
    if reason == '' then reason = _L('kick_default') end
    Admin.Log(src, 'kick', reason, t)
    DropPlayer(t, reason)
    return true
end

H.ban = function(src, data)
    local t, err = target(src, data, 'ban')
    if not t then return false, err end
    if t == src then return false, _L('err_ban_self') end
    local hours = tonumber(data.hours)
    if not hours or not inList(Config.BanDurations, hours) then return false, _L('err_ban_length') end
    local reason = cleanText(data.reason, LIM.Reason)
    if reason == '' then return false, _L('err_ban_reason') end
    local by = src == 0 and _L('console') or (GetPlayerName(src) or '?')
    local id, expire = Bans.Add(t, hours, reason, by)
    if not id then return false, _L('err_ban_save') end
    Admin.Log(src, 'ban', ('#%d %s, until %s'):format(id, reason, Bans.UntilText(expire)), t)
    DropPlayer(t, Bans.Message({ id = id, reason = reason, expire = expire }))
    return true, _L('ok_banned', id)
end

H.warn = function(src, data)
    local t, err = target(src, data, 'warn')
    if not t then return false, err end
    local reason = cleanText(data.reason, LIM.Reason)
    if reason == '' then return false, _L('err_warn_reason') end
    local user = Admin.VorpUser(t)
    if not user then return false, _L('err_noaccount') end
    local n = (tonumber(user.getPlayerwarnings()) or 0) + 1
    user.setPlayerWarnings(n)
    Admin.Notify(t, reason, { title = _L('warn_title', n), type = 'error', duration = Config.WarnDuration })
    Admin.Log(src, 'warn', ('#%d %s'):format(n, reason), t)
    if Config.WarnKickAt > 0 and n >= Config.WarnKickAt then
        Admin.Log(src, 'kick (warning limit)', nil, t)
        DropPlayer(t, _L('warn_kick'))
    end
    return true, _L('ok_warned', n)
end

H.money = function(src, data)
    local t, err = target(src, data, 'money')
    if not t then return false, err end
    local P, perr = player(t)
    if not P then return false, perr end
    local mtype = tostring(data.moneyType or '')
    if not inList(Config.MoneyTypes, mtype) then return false, _L('err_currency') end
    local amount = tonumber(data.amount)
    if not amount or amount ~= amount or amount <= 0 or amount > Config.MaxMoneyPerAction then
        return false, _L('err_amount', Config.MaxMoneyPerAction)
    end
    amount = math.floor(amount * 100 + 0.5) / 100   -- cents
    local give = data.mode == 'give'
    local ok
    if give then
        ok = P.Functions.AddMoney(mtype, amount, 'admin-give')
    else
        ok = P.Functions.RemoveMoney(mtype, amount, 'admin-take')
    end
    if not ok then return false, _L(give and 'err_give' or 'err_take') end
    Admin.Log(src, give and 'give money' or 'take money', ('%s %.2f'):format(mtype, amount), t)
    return true
end

H.job = function(src, data)
    local t, err = target(src, data, 'job')
    if not t then return false, err end
    local P, perr = player(t)
    if not P then return false, perr end
    local job = tostring(data.job or ''):lower()
    local def = RSGCore.Shared.Jobs[job]
    if not def then return false, _L('err_job') end
    local grade = math.floor(tonumber(data.grade) or 0)
    if not (def.grades or {})[tostring(grade)] then return false, _L('err_grade') end
    if not P.Functions.SetJob(job, tostring(grade)) then return false, _L('err_setjob') end
    Admin.Log(src, 'set job', ('%s grade %d'):format(job, grade), t)
    return true
end

H.group = function(src, data)
    local t, err = target(src, data, 'group')
    if not t then return false, err end
    local group = tostring(data.group or '')
    if not inList(Config.Groups, group) then return false, _L('err_group') end
    if Config.GroupsNeedGod[group] and src ~= 0 and not RSGCore.Functions.HasPermission(src, 'god') then
        Admin.Log(src, 'set group (refused: needs god)', group, t)
        return false, _L('err_group_god')
    end
    local user = Admin.VorpUser(t)
    if not user then return false, _L('err_noaccount') end
    if not user.setGroup(group) then return false, _L('err_setgroup') end
    Admin.Log(src, 'set group', group, t)
    return true
end

H.charmenu = function(src, data)
    local t, err = target(src, data, 'charmenu')
    if not t then return false, err end
    if not RSGCore.Functions.GetPlayer(t) then return false, _L('err_nochar') end
    if not exports.MULTIcore:LogoutCharacter(t) then return false, _L('err_logout') end
    Admin.Log(src, 'character menu', nil, t)
    return true
end

-- Send a notification (MULTIcore notify) to one player or everyone (target = 'all')
H.notify = function(src, data)
    local text = cleanText(data.text, LIM.Message)
    if text == '' then return false, _L('err_text') end
    local ntype = tostring(data.type or 'info')
    if not inList(Config.NotifyTypes, ntype) then return false, _L('err_notify_type') end
    local style = inList(Config.NotifyStyles, data.style) and data.style or nil
    local opts = { title = _L('staff_title'), type = ntype, style = style }
    if data.target == 'all' then
        Admin.NotifyAll(text, opts)
        Admin.Log(src, 'notify everyone', text)
    else
        local t = online(data.target)
        if not t then return false, _L('err_offline') end
        Admin.Notify(t, text, opts)
        Admin.Log(src, 'notify', text, t)
    end
    return true, _L('ok_notified')
end

-- ---------------------------------------------------------------
-- self tab (the client applies these; the server only allows and logs)
-- ---------------------------------------------------------------

local function selfToggle(name)
    return function(src, data)
        Admin.Log(src, ('%s %s'):format(name, data.on == true and 'on' or 'off'))
        return true
    end
end

H.noclip = selfToggle('noclip')
H.god = selfToggle('godmode')
H.invisible = selfToggle('invisible')

H.waypoint = function(src)
    Admin.Log(src, 'tp to waypoint')
    return true
end

H.selfheal = function(src, data)
    if data.revive then
        revive(src)
        Admin.Log(src, 'revive self')
    else
        heal(src)
        Admin.Log(src, 'heal self')
    end
    return true
end

H.spawn = function(src, data)
    local model = tostring(data.model or '')
    if not model:match('^[%w_]+$') or #model > LIM.Model then return false, _L('err_model_name') end
    Admin.Log(src, 'spawn ' .. (data.kind == 'wagon' and 'wagon' or 'horse'), model)
    return true
end

H.weather = function(src, data)
    if not Config.WorldSync then return false, _L('err_sync_off') end
    local w = tostring(data.weather or '')
    local world = GlobalState.multiadminWorld or {}
    if w == 'reset' then
        world.weather = nil
    elseif inList(Config.WeatherTypes, w) then
        world.weather = w
    else
        return false, _L('err_weather')
    end
    GlobalState.multiadminWorld = world
    Admin.Log(src, 'weather', w)
    return true
end

H.time = function(src, data)
    if not Config.WorldSync then return false, _L('err_sync_off') end
    local world = GlobalState.multiadminWorld or {}
    if data.reset then
        world.hour, world.minute, world.freeze = nil, nil, nil
        Admin.Log(src, 'time', 'reset')
    else
        local h, m = tonumber(data.hour), tonumber(data.minute)
        if not h or not m or h % 1 ~= 0 or m % 1 ~= 0 or h < 0 or h > 23 or m < 0 or m > 59 then
            return false, _L('err_time')
        end
        world.hour, world.minute, world.freeze = h, m, data.freeze == true
        Admin.Log(src, 'time', ('%02d:%02d%s'):format(h, m, world.freeze and ' (frozen)' or ''))
    end
    GlobalState.multiadminWorld = world
    return true
end

-- ---------------------------------------------------------------
-- server tab
-- ---------------------------------------------------------------

H.announce = function(src, data)
    local text = cleanText(data.text, LIM.Message)
    if text == '' then return false, _L('err_text') end
    Admin.NotifyAll(text, {
        title = _L('announce_title'), type = 'info',
        duration = Config.AnnounceDuration, style = Config.AnnounceStyle,
    })
    Admin.Log(src, 'announce', text)
    return true
end

H.bans = function()
    return true, nil, Bans.ListActive()
end

H.unban = function(src, data)
    local id = math.floor(tonumber(data.id) or 0)
    if id < 1 then return false, _L('err_ban_id') end
    if not Bans.Remove(id) then return false, _L('err_no_ban') end
    Admin.Log(src, 'unban', ('ban #%d'):format(id))
    return true, nil, Bans.ListActive()
end

-- ---------------------------------------------------------------
-- entry point
-- ---------------------------------------------------------------

lib.callback.register('MULTIadmin:action', function(src, action, data)
    if type(action) ~= 'string' or not H[action] then return { ok = false, msg = _L('err_unknown') } end
    if not Admin.Allowed(src, action) then
        Admin.Log(src, action .. ' (refused: no permission)')
        return { ok = false, msg = _L('err_perm') }
    end
    if type(data) ~= 'table' then data = {} end
    local ok, res, msg, extra = pcall(H[action], src, data)
    if not ok then
        print(('^1[MULTIadmin]^7 %s failed: %s'):format(action, tostring(res)))
        return { ok = false, msg = _L('err_failed') }
    end
    return { ok = res == true, msg = msg, data = extra }
end)

AddEventHandler('playerDropped', function()
    local src = source
    spectating[src] = nil
    for admin, s in pairs(spectating) do
        if s.target == src then
            spectating[admin] = nil
            if s.bucket and GetPlayerRoutingBucket(admin) ~= s.bucket then SetPlayerRoutingBucket(admin, s.bucket) end
            TriggerClientEvent('MULTIadmin:client:spectate', admin, false)
        end
    end
end)

-- Console / ACE: unban by id ("multiadmin_unban 12")
RegisterCommand('multiadmin_unban', function(src, args)
    if src ~= 0 and not Admin.Allowed(src, 'unban') then return end
    local id = math.floor(tonumber(args[1]) or 0)
    local ok = id > 0 and Bans.Remove(id)
    Admin.Log(src, 'unban', ('ban #%d %s'):format(id, ok and 'removed' or 'not found'))
end, true)

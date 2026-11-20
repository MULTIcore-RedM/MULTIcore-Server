-- ============================================================
-- MULTIlaw :: rsg-lawman and rsg-prison (server side)
-- Event, callback and command names and their argument shapes follow
-- rsg-lawman 2.0.6 and rsg-prison 2.0.3 (RSG v2 framework, GPL v3) and
-- the scripts that call them (rsg-adminmenu, rsg-mdt, rsg-medic,
-- rsg-radialmenu, RINGOradialmenu). Every call runs MULTIlaw's own
-- server checks; nothing a client sends is trusted as it was on RSG.
-- ============================================================

local getP, fail, dbg = Law.getP, Law.fail, Law.dbg
local RSGCore = Law.Core()

Law.Net = {}   -- event name -> function(src, ...) (also used by the self-test)

local function net(name, fn)
    Law.Net[name] = fn
    RegisterNetEvent(name, function(...) fn(source, ...) end)
end

local function ignored(name, src, ...)
    dbg(('ignored %s from %s'):format(name, tostring(src)), ...)
end

--- nearest other player within dist of src (server positions), or nil
local function nearestPlayer(src, dist)
    local pos = Law.coordsOf(src)
    if not pos then return nil end
    local best, bestD
    for _, s in ipairs(GetPlayers()) do
        s = tonumber(s)
        if s ~= src then
            local p = Law.coordsOf(s)
            if p then
                local d = #(p - pos)
                if d <= dist and (not bestD or d < bestD) then best, bestD = s, d end
            end
        end
    end
    return best
end

---------------------------------
-- rsg-lawman: server events
---------------------------------
-- search the nearest player (no args; rsg-lawman's /searchplayer)
net('rsg-lawman:server:SearchPlayer', function(src)
    if not Law.rateOk(src) then return end
    local target = nearestPlayer(src, Config.Search.Distance)
    if not target then return Law.notify(src, _L('no_player'), 'error') end
    Law.say(src, Law.Search(src, target))
end)

-- law alert from any player (emergency button). Args: text, coords?
net('rsg-lawman:server:lawmanAlert', function(src, text, coords)
    return Law.ClientAlert(src, text, coords)
end)

-- jail a player. Args: target server id, minutes
net('rsg-lawman:server:jailplayer', function(src, playerId, minutes)
    if not Law.rateOk(src) then return end
    return Law.say(src, Law.JailAt(src, tonumber(playerId), minutes, 'auto'))
end)

-- cuff / uncuff (toggle). Args: target server id, isSoftcuff
net('rsg-lawman:server:cuffplayer', function(src, playerId)
    if not Law.rateOk(src) then return end
    return Law.say(src, Law.ToggleCuff(src, tonumber(playerId)))
end)

-- the cuffed player's own client reporting its state: only "cuffed" is ever taken from a client
net('rsg-lawman:server:sethandcuffstatus', function(src, isHandcuffed)
    if isHandcuffed == true and not Law.IsCuffed(src) then
        Law.SetCuffed(src, true, 0, true)
    elseif isHandcuffed ~= true and Law.IsCuffed(src) then
        ignored('sethandcuffstatus(false) while cuffed', src)
    end
end)

-- escort status from a client: the server keeps its own
net('rsg-lawman:server:setescortstatus', function(src, v) ignored('setescortstatus', src, v) end)

-- lead / let go. Args: target server id
net('rsg-lawman:server:escortplayer', function(src, playerId)
    if not Law.rateOk(src) then return end
    return Law.say(src, Law.ToggleEscort(src, tonumber(playerId)))
end)

-- rsg-lawman's law storage ("trash"): a stash per law job, opened at an office. Arg: job name
net('rsg-lawman:server:storage', function(src, jobname)
    if not Law.rateOk(src) then return end
    local P = getP(src)
    local ok, err = Law.Can(P, 'evidence')
    if not ok then return Law.notify(src, _L(err), 'error') end
    local job = Law.LawJob(P)
    if jobname ~= job.name then return ignored('storage of another job', src, jobname) end
    if not Law.OfficeAt(src, P) then return Law.notify(src, _L('not_at_office'), 'error') end
    exports.MULTIinventory:Open(src, 'stash:' .. Config.Compat.StoragePrefix .. job.name, {
        label = _L('storage_label'), slots = Config.Compat.StorageSlots, maxWeight = Config.Compat.StorageMaxWeight,
    })
end)

-- add to the sender's own outlaw status (crime scripts). Args: amount, reason
net('rsg-lawman:server:updateoutlawstatus', function(src, amount)
    local P = getP(src)
    amount = Law.int(amount)
    if not P or not amount or amount <= 0 or amount > Config.Compat.MaxOutlawStep then return ignored('updateoutlawstatus', src, amount) end
    MySQL.update.await('UPDATE `players` SET `outlawstatus` = `outlawstatus` + ? WHERE `citizenid` = ?', { amount, Law.cidOf(P) })
end)

-- MULTIlaw's client heard rsg-adminmenu's 'rsg-lawman:client:getcuffed' (by = the admin's server id)
net('MULTIlaw:server:adminCuff', function(src, by)
    by = tonumber(by)
    if not Config.Compat.TrustAdminCuff or not by or not Law.IsAdmin(by) then return ignored('getcuffed', src, by) end
    -- rsg-adminmenu toggles
    Law.SetCuffed(src, not Law.IsCuffed(src), by)
end)

---------------------------------
-- rsg-lawman: callback and commands
---------------------------------
-- how many law are on duty (job type 'leo', as rsg-lawman counts)
RSGCore.Functions.CreateCallback('rsg-lawman:server:getlaw', function(_, cb)
    cb(#Law.OnDuty({ leo = true }))
end)

if Config.Commands.Jail ~= '' then
    RegisterCommand(Config.Commands.Jail, function(src, args)
        if src == 0 then return end
        if args[1] then
            Law.say(src, Law.JailAt(src, tonumber(args[1]), tonumber(args[2]), args[3] == 'cell' and 'cell' or args[3] == 'prison' and 'prison' or 'auto'))
        else
            TriggerClientEvent('MULTIlaw:client:jailNearest', src)
        end
    end, false)
end

---------------------------------
-- rsg-prison: server events
---------------------------------
-- the client's own minute counter: the server keeps the time
net('rsg-prison:server:updateSentance', function(src, t) ignored('updateSentance', src, t) end)
-- job loss is MULTIlaw's Config.Jail.RemoveJob, done when the sentence starts
net('rsg-prison:server:RemovePlayerJob', function(src) ignored('RemovePlayerJob', src) end)
-- "free me": only once the time is served
net('rsg-prison:server:FreePlayer', function(src)
    local cid = Law.cidOf(getP(src))
    if cid and Law.jail[cid] and Law.JailLeft(cid) <= 0 then Law.Release(cid) else ignored('FreePlayer (time left)', src) end
end)
-- items are taken and given back by the server itself (Config.Jail.TakeItems)
net('rsg-prison:server:SaveJailItems', function(src) ignored('SaveJailItems', src) end)
net('rsg-prison:server:GiveJailItems', function(src) ignored('GiveJailItems', src) end)
net('rsg-prison:server:CheckRecordStatus', function(src) ignored('CheckRecordStatus', src) end)
-- rsg-medic sends this on respawn (Config.ResetOutlawStatus): the sender's outlawstatus back to 0
net('rsg-prison:server:resetoutlawstatus', function(src)
    if not Config.Compat.AllowOutlawReset then return ignored('resetoutlawstatus', src) end
    local P = getP(src)
    if not P then return end
    MySQL.update.await('UPDATE `players` SET `outlawstatus` = 0 WHERE `citizenid` = ?', { Law.cidOf(P) })
end)

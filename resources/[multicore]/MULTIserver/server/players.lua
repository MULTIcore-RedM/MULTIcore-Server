-- ============================================================
-- MULTIserver :: player list and server info (server side)
-- The server builds the list; hidden fields are never sent to
-- players who may not see them.
-- ============================================================

local PLc = Config.PlayerList
PlayerList = {}

local lastAsk = {}

local function charName(P)
    local ci = P and P.PlayerData.charinfo
    if not ci then return nil end
    local s = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

--- Every online server id: real players plus logged-in characters (sorted by id).
local function onlineIds()
    local seen, ids = {}, {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id and not seen[id] then seen[id] = true ids[#ids + 1] = id end
    end
    for _, id in ipairs(RSGCore.Functions.GetPlayers() or {}) do
        id = tonumber(id)
        if id and not seen[id] then seen[id] = true ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

local function slots()
    if Config.Queue.MaxPlayers and Config.Queue.MaxPlayers > 0 then return Config.Queue.MaxPlayers end
    return GetConvarInt('sv_maxclients', 32)
end

--- The list as `viewer` may see it:
--- { admin, me, count, max, columns = { name = true, ... }, players = { { id, name, char?, job?, ping?, citizenid?, license? } } }
function PlayerList.Build(viewer)
    local admin = MS.IsAdmin(viewer)
    local cols = {
        id = true, name = true,
        char = admin or PLc.ShowCharacterName,
        job = admin or PLc.ShowJob,
        ping = PLc.ShowPing,
        citizenid = admin, license = admin,
    }
    local list = {}
    for _, id in ipairs(onlineIds()) do
        local P = RSGCore.Functions.GetPlayer(id)
        local row = { id = id, name = GetPlayerName(id) or charName(P) or '?' }
        if cols.char then row.char = charName(P) or '' end
        if cols.job then row.job = P and P.PlayerData.job and (P.PlayerData.job.label or P.PlayerData.job.name) or '' end
        if cols.ping then row.ping = GetPlayerPing(id) or 0 end
        if admin then
            row.citizenid = P and P.PlayerData.citizenid or ''
            row.license = (P and P.PlayerData.license) or GetPlayerIdentifierByType(id, 'license') or ''
        end
        list[#list + 1] = row
    end
    return { admin = admin, me = tonumber(viewer) or 0, count = #list, max = slots(), columns = cols, players = list }
end

function PlayerList.Info()
    local I = Config.Info
    return {
        name = I.ServerName ~= '' and I.ServerName or GetConvar('sv_hostname', ''),
        desc = I.Description ~= '' and I.Description or _L('info_default_desc'),
        rules = I.Rules, discord = I.Discord, website = I.Website,
        count = I.ShowPlayerCount and #onlineIds() or nil,
        max = I.ShowPlayerCount and slots() or nil,
    }
end

lib.callback.register('MULTIserver:players', function(src)
    if not PLc.Enabled then return nil end
    local now = GetGameTimer()
    if lastAsk[src] and now - lastAsk[src] < PLc.CooldownMs then return false end
    lastAsk[src] = now
    return PlayerList.Build(src)
end)

lib.callback.register('MULTIserver:info', function()
    if not Config.Info.Enabled then return nil end
    return PlayerList.Info()
end)

AddEventHandler('playerDropped', function() lastAsk[source] = nil end)

exports('GetPlayerList', function(viewer) return PlayerList.Build(viewer) end)
exports('GetServerInfo', function() return PlayerList.Info() end)

if MS.testMode then
    exports('_TestAdmin', function(src, on) MS._ForceAdmin(src, on) return true end)
    exports('_TestPlayerListConfig', function(key, value) PLc[key] = value return true end)
end

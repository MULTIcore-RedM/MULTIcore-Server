-- ============================================================
-- MULTIcore :: VORP face - the core object
-- exports.vorp_core:GetCore() returns this. Written from VORP's public
-- API documentation; no VORP code is used.
-- ============================================================

MULTI.Vorp = MULTI.Vorp or {}
local V = MULTI.Vorp

local Core = {}

function Core.getUser(src)
    return V.BuildUser(src)
end

--- The user whose current character has this id (players.id), if online.
function Core.getUserByCharId(charId)
    charId = tonumber(charId)
    if not charId then return nil end
    for src, P in pairs(RSGCore.Players) do
        if P.PlayerData.id == charId then return V.BuildUser(src) end
    end
    return nil
end

--- Every online player that has a character, keyed by source.
function Core.getUsers()
    local out = {}
    for src in pairs(RSGCore.Players) do out[src] = V.BuildUser(src) end
    return out
end

-- Notifications
for name, fn in pairs(V.Notify) do Core[name] = fn end

-- Callbacks
Core.Callback = V.Callback

--- Registers jobs and grades. Accepts { jobName = { label = ..., grades = { [0] = { name = ... } } } }
--- and simple lists of names.
function Core.RegisterJobs(jobs, _resource)
    if type(jobs) ~= 'table' then return false end
    for k, j in pairs(jobs) do
        local name = type(k) == 'string' and k or (type(j) == 'table' and (j.name or j.job)) or j
        if type(name) == 'string' then
            local label = type(j) == 'table' and j.label or nil
            MULTI.Jobs.Ensure(name, 0, label)
            if type(j) == 'table' and type(j.grades) == 'table' then
                for g, gd in pairs(j.grades) do
                    local level = tonumber(g) or tonumber(type(gd) == 'table' and gd.grade) or 0
                    MULTI.Jobs.Ensure(name, level, label)
                    local job = RSGCore.Shared.Jobs[name:lower()]
                    if type(gd) == 'table' and gd.label or type(gd) == 'table' and gd.name then
                        job.grades[tostring(level)].name = gd.label or gd.name
                    end
                end
            end
        end
    end
    return true
end

--- Puts a player in a routing bucket (0 = the shared world).
function Core.instancePlayers(src, bucket)
    return RSGCore.Functions.SetPlayerBucket(src, tonumber(bucket) or 0)
end

-- Client Core.instancePlayers(n) asks for its own bucket. 0 = shared world; others are kept within a sane range.
RegisterNetEvent('MULTIcore:vorp:instance', function(n)
    n = math.floor(tonumber(n) or 0)
    if n < 0 or n > 2000000 then return end
    Core.instancePlayers(source, n)
end)

--- Sends a message to a Discord webhook.
function Core.AddWebhook(title, webhook, description, color, name, logo, footerlogo, avatar)
    if type(webhook) ~= 'string' or not webhook:find('^https://') then return end
    local embed = {
        {
            color = tonumber(color) or 4777493,
            title = title,
            description = description,
            thumbnail = logo and { url = logo } or nil,
            footer = footerlogo and { text = name or 'MULTIcore', icon_url = footerlogo } or nil,
        }
    }
    PerformHttpRequest(webhook, function() end, 'POST',
        json.encode({ username = name or 'MULTIcore', avatar_url = avatar, embeds = embed }),
        { ['Content-Type'] = 'application/json' })
end

-- Health: the client face carries these out (phase 4); the events fire here for server scripts
Core.Player = {
    Heal = function(src)
        TriggerClientEvent('MULTIcore:vorp:heal', src)
        TriggerEvent('vorp_core:Server:OnPlayerHeal', src)
    end,
    Revive = function(src)
        TriggerClientEvent('MULTIcore:vorp:revive', src)
        TriggerEvent('vorp_core:Server:OnPlayerRevive', src)
    end,
    -- coords (vector4) is optional; without it the player goes to the nearest MULTIConfig.Vorp.RespawnPoints
    Respawn = function(src, coords)
        TriggerClientEvent('MULTIcore:vorp:respawn', src, coords)
        TriggerEvent('vorp_core:Server:OnPlayerRespawn', src)
    end,
}

-- Whitelist: not part of MULTIcore yet. The functions exist so scripts that call them don't fail.
Core.Whitelist = {
    getEntry = function() return nil end,
    whitelistUser = function() return false end,
    unWhitelistUser = function() return false end,
}

V.Core = Core

-- exports.vorp_core:GetCore() / ServerRpcCall(), and the old event form
MULTI.ExportAs('vorp_core', 'GetCore', function() return Core end)
MULTI.ExportAs('vorp_core', 'ServerRpcCall', function() return V.Callback end)
AddEventHandler('getCore', function(cb) if cb then cb(Core) end end)

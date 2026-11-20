-- ============================================================
-- MULTIcore :: notifications (server)
-- Sends notifications to MULTIcore's client notify system
-- (client/multi/notify.lua). Written fresh for MULTIcore (GPL v3).
--
--   exports.MULTIcore:Notify(src, { text, title, type, style, duration, icon, color, sound, id })
--   exports.MULTIcore:Notify(src, text, type, duration)
--   exports.MULTIcore:NotifyAll(...)               same arguments without src
--   exports.MULTIcore:ClearNotify(src, id)         id = the one you passed in the data
--   exports.MULTIcore:ClearAll(src)
--
-- Must load after server/functions.lua and server/vorp/notify.lua, and
-- before server/vorp/core.lua (which copies the VORP Notify functions).
-- ============================================================

MULTI = MULTI or {}

local Cfg = NotifyConfig

local function notify(src, a, b, c)
    src = tonumber(src)
    if not src then return false end
    if a == nil then return false end
    TriggerClientEvent('MULTIcore:notify', src, a, b, c)
    return true
end

local function notifyAll(a, b, c)
    if a == nil then return false end
    TriggerClientEvent('MULTIcore:notify', -1, a, b, c)
    return true
end

local function clear(src, id)
    src = tonumber(src)
    if not src or id == nil then return end
    TriggerClientEvent('MULTIcore:notify:clear', src, id)
end

local function clearAll(src)
    src = tonumber(src)
    if not src then return end
    TriggerClientEvent('MULTIcore:notify:clear', src, nil)
end

MULTI.Notify = notify
MULTI.NotifyAll = notifyAll

exports('Notify', notify)
exports('NotifyAll', notifyAll)
exports('ClearNotify', clear)
exports('ClearAll', clearAll)

-- ------------------------------------------------------------
-- RSG: rsg-core 2.x has no server RSGCore.Functions.Notify (its scripts
-- send 'ox_lib:notify', which stays ox_lib's). Older RSG / QB scripts
-- call RSGCore.Functions.Notify(src, text, type, length), so it is
-- added here when missing (or replaced, when RouteRSG is on).
-- ------------------------------------------------------------
if Cfg.RouteRSG and RSGCore and RSGCore.Functions then
    RSGCore.Functions.Notify = function(src, text, ntype, length)
        if type(text) == 'table' then
            local d = {}
            for k, v in pairs(text) do d[k] = v end
            d.text = d.text or d.description
            d.title = d.title or d.caption
            d.type = Cfg.RSGTypes[tostring(d.type or ''):lower()] or d.type
            d.style = d.style or Cfg.RSGStyle
            return notify(src, d)
        end
        local t = type(ntype) == 'string' and (Cfg.RSGTypes[ntype:lower()] or ntype) or nil
        return notify(src, { text = text, type = t, duration = length, style = Cfg.RSGStyle })
    end
end

-- ------------------------------------------------------------
-- VORP: server Core.Notify(src, text, type, ms) (server/vorp/notify.lua)
-- draws with this system instead of ox_lib. The other Core.NotifyX go
-- to the VORP client face, which already sends them here.
-- ------------------------------------------------------------
if Cfg.RouteVorpServer and MULTI.Vorp and MULTI.Vorp.Notify then
    MULTI.Vorp.Notify.Notify = function(src, text, ntype, duration)
        return notify(src, { text = text, type = ntype, duration = duration, style = 'toast' })
    end
end

-- ============================================================
-- MULTIcore :: VORP face - notifications (client side)
-- Core.Notify* with the argument orders from VORP's public docs
-- (https://docs.vorp-core.com/api-reference/core). Written fresh; no VORP
-- code is used. Every kind is drawn by MULTIcore's own notification
-- system (exports.MULTIcore:Notify, client/multi/notify.lua), so VORP
-- scripts look the same as RSG and MULTI ones.
--
-- Extra fields passed on when a VORP call gives them (the notify system
-- may use or ignore them): iconDict (texture dictionary of icon), color
-- (VORP colour name such as 'COLOR_RED'), sound = { ref, name }.
-- ============================================================

MULTI = MULTI or {}
MULTI.VorpClient = MULTI.VorpClient or {}
local VC = MULTI.VorpClient

local DEFAULT_MS = 4000

local function ms(v)
    return math.tointeger(tonumber(v)) or DEFAULT_MS   -- -1 = stay until cleared (NotifyLeftInteractive)
end

local function text(v)
    if v == nil or v == '' then return nil end
    return tostring(v)
end

-- Sends one notification to MULTIcore's notify system.
local function send(data)
    if not data.text and not data.title then return end
    local ok, err = pcall(function() exports.MULTIcore:Notify(data) end)
    if not ok then
        print(('^3[MULTIcore] VORP notify could not reach exports.MULTIcore:Notify (%s): %s %s^7')
            :format(tostring(err), data.title or '', data.text or ''))
    end
end

local function sound(ref, name)
    if text(ref) and text(name) then return { ref = tostring(ref), name = tostring(name) } end
    return nil
end

-- ------------------------------------------------------------
-- The Notify* functions (VORP argument orders)
-- ------------------------------------------------------------
local Notify = {}

function Notify.NotifyTip(msg, duration)
    send({ text = text(msg), type = 'info', style = 'tip', duration = ms(duration) })
end

function Notify.NotifyRightTip(msg, duration)
    send({ text = text(msg), type = 'info', style = 'toast', duration = ms(duration) })
end

function Notify.NotifyObjective(msg, duration)
    send({ text = text(msg), type = 'info', style = 'objective', duration = ms(duration) })
end

function Notify.NotifyTop(msg, location, duration)
    send({ title = text(location), text = text(msg), type = 'info', style = 'banner', duration = ms(duration) })
end

function Notify.NotifySimpleTop(title, subtitle, duration)
    send({ title = text(title), text = text(subtitle), type = 'info', style = 'banner', duration = ms(duration) })
end

function Notify.NotifyOneSimpleTop(title, duration)
    send({ text = text(title), type = 'info', style = 'banner', duration = ms(duration) })
end

function Notify.NotifyThreeSimpleTop(title, description, secondDescription, duration)
    local body = text(description)
    if text(secondDescription) then body = (body and body .. '\n' or '') .. tostring(secondDescription) end
    send({ title = text(title), text = body, type = 'info', style = 'banner', duration = ms(duration) })
end

function Notify.NotifyCenter(msg, duration)
    send({ text = text(msg), type = 'info', style = 'banner', duration = ms(duration) })
end

function Notify.NotifyBottomRight(msg, duration)
    send({ text = text(msg), type = 'info', style = 'toast', duration = ms(duration) })
end

local function leftToast(title, subtitle, dict, icon, duration, color)
    send({
        title = text(title), text = text(subtitle), type = 'info', style = 'toast', duration = ms(duration),
        icon = text(icon), iconDict = text(dict), color = text(color),
    })
end

function Notify.NotifyLeft(title, subtitle, dict, icon, duration, color)
    leftToast(title, subtitle, dict, icon, duration, color)
end

function Notify.NotifyLeftRank(title, subtitle, dict, icon, duration, color)
    leftToast(title, subtitle, dict, icon, duration, color)
end

function Notify.NotifyLeftInteractive(title, subtitle, dict, icon, duration, color)
    leftToast(title, subtitle, dict, icon, duration, color)
end

function Notify.NotifyAvanced(msg, dict, icon, color, duration, _quality, _showQuality)
    send({
        text = text(msg), type = 'info', style = 'toast', duration = ms(duration),
        icon = text(icon), iconDict = text(dict), color = text(color),
    })
end

function Notify.NotifyUpdate(title, subtitle, duration)
    send({ title = text(title), text = text(subtitle), type = 'success', style = 'banner', duration = ms(duration) })
end

function Notify.NotifyFail(title, subtitle, duration)
    send({ title = text(title), text = text(subtitle), type = 'error', style = 'banner', duration = ms(duration) })
end

function Notify.NotifyWarning(title, subtitle, audioRef, audioName, duration)
    send({
        title = text(title), text = text(subtitle), type = 'warning', style = 'banner', duration = ms(duration),
        sound = sound(audioRef, audioName),
    })
end

function Notify.NotifyDead(title, audioRef, audioName, duration)
    send({
        text = text(title), type = 'error', style = 'banner', duration = ms(duration),
        sound = sound(audioRef, audioName),
    })
end

VC.Notify = Notify

-- ------------------------------------------------------------
-- Server face: server/vorp/notify.lua sends (kind, ...) for every Core.Notify*(src, ...)
-- ------------------------------------------------------------
RegisterNetEvent('MULTIcore:vorp:notify', function(kind, ...)
    local fn = Notify[kind]
    if fn then fn(...) end
end)

-- ------------------------------------------------------------
-- Old-style events scripts trigger (TriggerEvent on the client or
-- TriggerClientEvent from the server). Arguments follow the matching Notify*.
-- ------------------------------------------------------------
local OLD_EVENTS = {
    ['vorp:TipRight']                      = 'NotifyRightTip',     -- RINGO bridges, RINGOanimations
    ['vorp:NotifyLeft']                    = 'NotifyLeft',         -- spooni_riding_center_script
    ['vorp:ShowBottomRight']               = 'NotifyBottomRight',  -- vorp_admin
    ['vorp:updatemissioNotify']            = 'NotifyUpdate',       -- vorp_admin (server -> client)
    ['vorp:Tip']                           = 'NotifyTip',
    ['vorp:TipBottom']                     = 'NotifyObjective',
    ['vorp:NotifyTop']                     = 'NotifyTop',
    ['vorp:ShowTopNotification']           = 'NotifySimpleTop',
    ['vorp:ShowAdvancedRightNotification'] = 'NotifyAvanced',
    ['vorp:ShowSimpleCenterText']          = 'NotifyCenter',
    ['vorp:failmissioNotifY']              = 'NotifyFail',
    ['vorp:deadplayerNotifY']              = 'NotifyDead',
    ['vorp:warningNotify']                 = 'NotifyWarning',
    ['vorp:LeftRank']                      = 'NotifyLeftRank',
    ['vorp:ThreeSimpleTop']                = 'NotifyThreeSimpleTop',
    ['vorp:OneSimpleTop']                  = 'NotifyOneSimpleTop',
    ['vorp:LeftInteractive']               = 'NotifyLeftInteractive',
}
for eventName, kind in pairs(OLD_EVENTS) do
    RegisterNetEvent(eventName, function(...) Notify[kind](...) end)
end

-- exports.vorp_core:DisplayTipRight(text, ms): used by the RINGO bridges
MULTI.ExportAs('vorp_core', 'DisplayTipRight', function(msg, duration) Notify.NotifyRightTip(msg, duration) end)

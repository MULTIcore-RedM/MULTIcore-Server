-- ============================================================
-- MULTIhelpers :: notification stand-ins (client)
-- Every call is drawn by MULTIcore's own notifications
-- (exports.MULTIcore:Notify), so they all look the same.
--
--   redemrp_notification  TriggerEvent('redemrp_notification:start', text, seconds, type)
--   gum_notify            exports.gum_notify:DisplayLeftNotification(title, text, icon, ms)
--                         TriggerEvent('gum_notify:notify', title, text, icon, ms)
--   rsg_notify            exports.rsg_notify:DisplayNotification(text, ms)
--                         TriggerEvent('rsg_notify:client:notifiy', text)
--                         TriggerEvent('rsg_notify:client:bottom_notifiy', text)
--   pNotify               exports.pNotify:SendNotification({ text, type, timeout, ... })
--                         exports.pNotify:SetQueueMax(queue, max)      (accepted, nothing to do)
--   bln_notify            exports.bln_notify:send(options, template)
--                         exports.bln_notify:tip(text, ms, placement, sound, soundSet)
--                         TriggerEvent('bln_notify:send', options, template)
-- All events also come from the server (TriggerClientEvent).
-- Own code, written from the public API descriptions. GPL v3, part of MULTIcore.
-- ============================================================

local Cfg = Config.Notify

-- turn the bits of HTML these libraries allow into plain lines for MULTIcore
local function plain(v)
    if v == nil then return nil end
    v = tostring(v)
    v = v:gsub('<%s*/?%s*[bB][rR]%s*/?%s*>', '\n')    -- <br>, </br>, <br/>
    v = v:gsub('~img:[^~]*~', '')                       -- bln_notify inline icons
    v = v:gsub('<[^>]->', '')                           -- any other tag
    v = v:gsub('&nbsp;', ' '):gsub('&lt;', '<'):gsub('&gt;', '>'):gsub('&quot;', '"'):gsub('&#39;', "'"):gsub('&amp;', '&')
    if v == '' then return nil end
    return v
end

local function ms(v, fallback)
    v = tonumber(v)
    if not v or v <= 0 then return fallback or Cfg.DefaultDuration end
    return math.floor(v)
end

local function show(d)
    if d.text == nil and d.title == nil then return end
    return exports.MULTIcore:Notify(d)
end
Helpers.Notify = show

-- ------------------------------------------------------------ redemrp_notification
-- seconds, not ms; type 'success' | 'error' | 'warning', anything else = plain
local REDEM_TYPES = { success = 'success', error = 'error', warning = 'warning' }

Helpers.On('redemrp_notification', 'redemrp_notification:start', function(text, seconds, ntype)
    local s = tonumber(seconds)
    show({
        text = plain(text),
        type = REDEM_TYPES[type(ntype) == 'string' and ntype:lower() or ''] or 'info',
        duration = s and s > 0 and math.floor(s * 1000) or Cfg.DefaultDuration,
    })
end, true)

-- ------------------------------------------------------------ gum_notify
-- iconName is an inventory picture name; MULTIcore shows signs only, so it is left out
local function gumNotify(title, text, _iconName, duration)
    show({ title = plain(title), text = plain(text), duration = ms(duration), style = Cfg.GumStyle })
end

Helpers.Export('DisplayLeftNotification', gumNotify, { 'gum_notify' })
Helpers.On('gum_notify', 'gum_notify:notify', gumNotify, true)

-- ------------------------------------------------------------ rsg_notify
local function rsgNotify(text, duration)
    show({ text = plain(text), duration = ms(duration) })
end

Helpers.Export('DisplayNotification', rsgNotify, { 'rsg_notify' })
-- the spelling 'notifiy' is the original's; scripts send it like that
Helpers.On('rsg_notify', 'rsg_notify:client:notifiy', function(text)
    show({ text = plain(text), duration = 5000 })
end, true)
Helpers.On('rsg_notify', 'rsg_notify:client:bottom_notifiy', function(text)
    show({ text = plain(text), style = Cfg.RsgBottomStyle })
end, true)

-- ------------------------------------------------------------ pNotify
local PNOTIFY_TYPES = { success = 'success', error = 'error', warning = 'warning', info = 'info', alert = 'info' }

local function pNotify(options)
    if type(options) ~= 'table' then options = { text = options } end
    local t = type(options.type) == 'string' and options.type:lower() or 'success'
    show({
        text = plain(options.text),
        type = PNOTIFY_TYPES[t] or 'info',
        duration = ms(options.timeout),
    })
end

Helpers.Export('SendNotification', pNotify, { 'pNotify' })
Helpers.Export('SetQueueMax', function() end, { 'pNotify' })   -- MULTIcore keeps its own limits (config_notify.lua)
Helpers.On('pNotify', 'pNotify:SendNotification', pNotify, true)
Helpers.On('pNotify', 'pNotify:SetQueueMax', function() end, true)

-- ------------------------------------------------------------ bln_notify (a subset: title, text, duration, templates)
-- template -> MULTIcore type and whether it is a tip
local BLN_TEMPLATES = {
    INFO = { type = 'info' },
    SUCCESS = { type = 'success' },
    ERROR = { type = 'error' },
    REWARD_MONEY = { type = 'money' },
    TIP = { type = 'info', tip = true },
    TIP_CASH = { type = 'money', tip = true },
    TIP_XP = { type = 'info', tip = true },
    TIP_GOLD = { type = 'gold', tip = true },
}

local function blnSend(options, template)
    if type(options) ~= 'table' then options = { description = options } end
    local tpl = BLN_TEMPLATES[type(template) == 'string' and template:upper() or ''] or {}
    local tip = tpl.tip or options.useBackground == false
    local d = {
        title = plain(options.title),
        text = plain(options.description or options.text),
        type = tpl.type or 'info',
        duration = math.max(1000, ms(options.duration)),
        style = tip and Cfg.BlnTipStyle or nil,
    }
    local cs = options.customSound
    if type(cs) == 'table' and cs.sound and cs.soundSet then d.sound = { cs.sound, cs.soundSet } end
    show(d)
end

local function blnTip(text, duration, _placement, sound, soundSet)
    local d = { text = plain(text), duration = ms(duration), style = Cfg.BlnTipStyle }
    if sound and soundSet then d.sound = { sound, soundSet } end
    show(d)
end

-- 'send' and 'tip' are common words: answer only under bln_notify
Helpers.ExportAs('send', blnSend, { 'bln_notify' })
Helpers.ExportAs('tip', blnTip, { 'bln_notify' })
Helpers.On('bln_notify', 'bln_notify:send', blnSend, true)
-- the server half (server/notify.lua) sends its tips here
RegisterNetEvent('MULTIhelpers:blnTip', function(text, duration, placement, sound, soundSet)
    if Helpers.RealRunning('bln_notify') then return end
    blnTip(text, duration, placement, sound, soundSet)
end)

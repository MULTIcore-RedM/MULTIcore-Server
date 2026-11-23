-- ============================================================
-- MULTIhelpers :: bln_notify stand-in (server half)
--
--   exports.bln_notify:send(target, options, template)        target -1 = everyone
--   exports.bln_notify:tip(target, text, ms, placement, sound, soundSet)
--   TriggerClientEvent('bln_notify:send', target, options, template) works as before
--
-- The client half (client/notify.lua) draws them with MULTIcore's notifications.
-- Own code, written from the public API description. GPL v3, part of MULTIcore.
-- ============================================================

local function target(t)
    t = tonumber(t)
    if not t then return nil end
    return math.floor(t)
end

Helpers.ExportAs('send', function(to, options, template)
    to = target(to)
    if not to then return end
    TriggerClientEvent('bln_notify:send', to, options, template)
end, { 'bln_notify' })

Helpers.ExportAs('tip', function(to, text, duration, placement, sound, soundSet)
    to = target(to)
    if not to then return end
    TriggerClientEvent('MULTIhelpers:blnTip', to, text, duration, placement, sound, soundSet)
end, { 'bln_notify' })

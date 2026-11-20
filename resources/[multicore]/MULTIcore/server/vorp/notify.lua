-- ============================================================
-- MULTIcore :: VORP face - notifications (server side)
-- Each VORP Notify* call is sent to the client face, which draws it
-- (client/vorp, phase 4). The names and argument orders follow VORP's
-- public documentation.
-- ============================================================

MULTI.Vorp = MULTI.Vorp or {}
local V = MULTI.Vorp

local KINDS = {
    'NotifyTip', 'NotifyLeft', 'NotifyRightTip', 'NotifyObjective', 'NotifyTop', 'NotifySimpleTop',
    'NotifyAvanced', 'NotifyCenter', 'NotifyBottomRight', 'NotifyFail', 'NotifyDead', 'NotifyUpdate',
    'NotifyWarning', 'NotifyLeftRank', 'NotifyOneSimpleTop', 'NotifyThreeSimpleTop', 'NotifyLeftInteractive',
}

V.Notify = {}
for _, kind in ipairs(KINDS) do
    V.Notify[kind] = function(src, ...)
        if not src then return end
        TriggerClientEvent('MULTIcore:vorp:notify', src, kind, ...)
    end
end
-- Plain text notice in the style the rest of the core uses
V.Notify.Notify = function(src, text, ntype, duration)
    TriggerClientEvent('ox_lib:notify', src, { description = tostring(text), type = ntype or 'inform', duration = duration or 5000 })
end

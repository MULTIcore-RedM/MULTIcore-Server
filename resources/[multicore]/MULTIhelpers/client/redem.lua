-- ============================================================
-- MULTIhelpers :: RedEM:RP stand-ins (client)
-- redemrp_menu_base is the same menu API as vorp_menu, so it gets the
-- same MenuData. redemrp_progressbars:DisplayProgressBar(ms, text, cb)
-- shows MULTIhelpers' bar and waits for it, like the original.
-- Written from RedEM:RP's public API; no RedEM:RP code is used.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local function answerAs(res, name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(res, name), function(setCB) setCB(fn) end)
end

-- TriggerEvent('redemrp_menu_base:getData', function(MenuData) ... end)
AddEventHandler('redemrp_menu_base:getData', function(cb)
    if cb then cb(Helpers.MenuData) end
end)
answerAs('redemrp_menu_base', 'GetMenuData', function() return Helpers.MenuData end)

--- exports.redemrp_progressbars:DisplayProgressBar(ms, text, cb): blocks until the bar is full, then calls cb.
local function displayProgressBar(ms, text, cb)
    local done = false
    Helpers.ProgressStart(text, ms, function() done = true end)
    local deadline = GetGameTimer() + (tonumber(ms) or 0) + 5000
    while not done and GetGameTimer() < deadline do Wait(0) end
    if cb then cb() end
end
answerAs('redemrp_progressbars', 'DisplayProgressBar', displayProgressBar)

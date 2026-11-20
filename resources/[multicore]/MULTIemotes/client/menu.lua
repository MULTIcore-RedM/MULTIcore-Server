-- ============================================================
-- MULTIemotes :: the emote menu (NUI)
-- Opened by /emotes, /e, the key in the game's key settings, and
-- rsg-animations' open event. Labels come from locales (_LT()).
-- GPL v3.
-- ============================================================

local isOpen = false

local function payload(tab)
    local items = {}
    for _, e in ipairs(Config.Emotes) do
        if e.kind then items[#items + 1] = { id = e.id, cat = e.cat, kind = e.kind } end
    end
    local walks = {}
    for _, w in ipairs(Config.Walkstyles) do walks[#walks + 1] = { id = w.id } end
    return {
        action = 'open',
        tab = tab,
        cats = Config.Categories,
        items = items,
        walks = walks,
        favs = MEM.GetFavourites(),
        walk = MEM.CurrentWalk(),
        cancelKey = Config.CancelKey ~= '' and Config.CancelKey or nil,
        L = _LT(),
        lang = _LCode(),
    }
end

--- Opens the menu, optionally on a tab ('favourites', a category, or 'walk').
function MEM.OpenMenu(tab)
    if isOpen then return end
    if LocalPlayer.state.isLoggedIn == false then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage(payload(tab))
end

function MEM.CloseMenu()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    MEM.CloseMenu()
    cb({})
end)

RegisterNUICallback('play', function(data, cb)
    local e = type(data) == 'table' and MEM.EmoteById[data.id]
    if not e then return cb({ ok = false, msg = _L('err_unknown', tostring(data and data.id)) }) end
    local ok, why = MEM.Play(e)
    cb({ ok = ok, msg = not ok and _L(why) or nil })
    if ok and Config.CloseOnPlay then MEM.CloseMenu() end
end)

RegisterNUICallback('stop', function(_, cb)
    MEM.Stop()
    cb({ ok = true })
end)

RegisterNUICallback('fav', function(data, cb)
    if type(data) ~= 'table' or type(data.id) ~= 'string' then return cb({ ok = false }) end
    local list = MEM.SetFavourite(data.id, data.on == true)
    local isFav = false
    for _, v in ipairs(list) do if v == data.id then isFav = true break end end
    local full = data.on == true and not isFav
    cb({ ok = not full, favs = list, msg = full and _L('err_favs_full', Config.MaxFavourites) or nil })
end)

RegisterNUICallback('walk', function(data, cb)
    local id = type(data) == 'table' and data.id or nil
    if id == false or id == '' then id = nil end
    local ok, err = MEM.SetWalk(id)
    local now = MEM.CurrentWalk()
    if ok then now = id end -- the state bag arrives a moment later
    cb({ ok = ok == true, walk = now or false, msg = not ok and _L(err or 'err_failed') or nil })
end)

---------------------------------
-- commands and key
---------------------------------
local function mapKey(command)
    local key = Config.OpenKey
    if key == false or key == nil then return end
    local k = tostring(key):upper()
    if k == 'PAGEDOWN' or k == 'NEXT' or k == 'PGDN' then
        print('^1[MULTIemotes]^7 ' .. _L('pagedown_refused'))
        key = ''
    end
    RegisterKeyMapping(command, _L('key_open'), 'keyboard', key)
end

if Config.Commands.Menu ~= '' then
    RegisterCommand(Config.Commands.Menu, function() MEM.OpenMenu() end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Menu, _L('help_menu'))
    mapKey(Config.Commands.Menu)
end
if Config.Commands.RsgMenu ~= '' and Config.Commands.RsgMenu ~= Config.Commands.Menu then
    RegisterCommand(Config.Commands.RsgMenu, function() MEM.OpenMenu() end, false)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)

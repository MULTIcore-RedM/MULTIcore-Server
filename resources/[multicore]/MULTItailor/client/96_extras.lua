--[[
    Sharing outfits, tobacco from the clothes menu, and how clothes sit (client).
    The server checks everything (server/96_extras.lua); this file draws the menus and sets the game's
    wearable state of a worn piece.

    How clothes sit: the game lists the ways each shop item can be worn (its wearable states). For a worn
    piece the page reads that list from the game itself and steps through it:
      _GET_SHOP_ITEM_NUM_WEARABLE_STATES     0xFFCC2DB2D9953401 (componentHash, isMpFemale, true) -> int
      _GET_SHOP_ITEM_WEARABLE_STATE_BY_INDEX 0x6243635AF2F1B826 (componentHash, index, isMpFemale, true) -> Hash
      _UPDATE_SHOP_ITEM_WEARABLE_STATE       0x66B957AAC2EAAEAB (ped, componentHash, state, 0, true, 1)
      components updated                     0xAAB86462966168CE (ped, true)
      update ped variation                   0xCC8CA3E88256E58F (ped, false, true, true, true, false)
    Only pieces MULTIinventory put on as shop items (their worn data has `comp`) can change how they sit.
    Hooks used by client/95_wardrobe.lua: TExtras.clothesOptions(reopen) and TExtras.outfitOptions(outfit, reopen).
    GPL v3, part of MULTIcore by RINGO (RINGOscripting).
]]
TExtras = TExtras or {}
local X = TExtras
local INV = 'MULTIinventory'

local N = {
    numStates = 0xFFCC2DB2D9953401,
    stateAt   = 0x6243635AF2F1B826,
    setState  = 0x66B957AAC2EAAEAB,
    updated   = 0xAAB86462966168CE,
    refresh   = 0xCC8CA3E88256E58F,
}

local function invUp() return GetResourceState(INV) == 'started' end

local function worn()
    if not invUp() then return {} end
    local ok, w = pcall(function() return exports[INV]:GetWornLocal() end)
    return (ok and type(w) == 'table') and w or {}
end

local ERR = {
    slow = 'err_slow', no_outfit = 'outfit_gone', inventory_missing = 'err_inventory_missing',
    share_off = 'share_off', share_no_player = 'share_no_player', share_too_far = 'share_too_far', share_busy = 'share_busy',
    tobacco_off = 'tobacco_off', tobacco_none = 'tobacco_none',
}
local function errText(code) return L(ERR[tostring(code)] or 'err_generic') end

-- ---------------------------------------------------------------- sharing
local SH = Config.Share or {}

local function giveCopy(o, reopen)
    local people = lib.callback.await('multitailor:share:nearby', false) or {}
    if #people == 0 then
        TC.notify(L('share_nobody'), 'error')
        return reopen and reopen()
    end
    local options = {}
    for _, p in ipairs(people) do
        options[#options + 1] = {
            title = p.name, icon = 'user',
            onSelect = function()
                local ok, err = lib.callback.await('multitailor:share:offer', false, o.id, p.id)
                if ok then TC.notify(L('share_sent'), 'success') else TC.notify(errText(err), 'error') end
            end,
        }
    end
    lib.registerContext({ id = 'multitailor_share_pick', title = L('share_pick'), options = options })
    lib.showContext('multitailor_share_pick')
end

function X.outfitOptions(o, reopen)
    if SH.enabled == false then return {} end
    return { { title = L('share_give'), description = L('share_give_desc'), icon = 'share-from-square',
               onSelect = function() giveCopy(o, reopen) end } }
end

RegisterNetEvent('MULTItailor:client:shareOffer', function(offerId, fromName, outfitName, pieces, seconds)
    CreateThread(function()
        local answered = false
        SetTimeout((tonumber(seconds) or 30) * 1000, function()
            if not answered then pcall(function() lib.closeAlertDialog() end) end
        end)
        local answer = lib.alertDialog({
            header = L('share_offer_title'),
            content = L('share_offer_text', tostring(fromName or ''), tostring(outfitName or ''), tonumber(pieces) or 0),
            centered = true, cancel = true,
        })
        answered = true
        TriggerServerEvent('MULTItailor:server:shareAnswer', offerId, answer == 'confirm')
    end)
end)

-- ---------------------------------------------------------------- tobacco
local TB = Config.Tobacco or {}

local function tobaccoMenu(reopen)
    local list = lib.callback.await('multitailor:tobacco:list', false) or {}
    local options = {}
    for _, t in ipairs(list) do
        options[#options + 1] = {
            title = t.label, description = L('tobacco_count', t.count or 0), icon = 'smoking',
            disabled = (t.count or 0) < 1,
            onSelect = function()
                local ok, err = lib.callback.await('multitailor:tobacco:use', false, t.item)
                if not ok and err then TC.notify(errText(err), 'error') end
            end,
        }
    end
    if #options == 0 then options[1] = { title = L('tobacco_none'), disabled = true } end
    lib.registerContext({ id = 'multitailor_tobacco', title = L('tobacco_title'), menu = 'multitailor_toggles', options = options })
    lib.showContext('multitailor_tobacco')
end

-- ---------------------------------------------------------------- how clothes sit
local ST = Config.Styles or {}
local chosen = {}          -- [slot key] = state hash
local loaded = false
local saveAt = nil

local function female(ped) return not IsPedMale(ped) end

local function statesOf(comp, ped)
    comp = math.tointeger(tonumber(comp))
    if not comp then return {} end
    local fem = female(ped)
    local n = Citizen.InvokeNative(N.numStates, comp, fem, true, Citizen.ResultAsInteger()) or 0
    local out = {}
    for i = 0, math.min(n, 16) - 1 do
        local h = Citizen.InvokeNative(N.stateAt, comp, i, fem, true, Citizen.ResultAsInteger())
        if h and h ~= 0 then out[#out + 1] = h end
    end
    return out
end

local function indexOf(list, v)
    for i, x in ipairs(list) do if x == v then return i end end
    return nil
end

local function setState(ped, comp, state)
    Citizen.InvokeNative(N.setState, ped, math.tointeger(tonumber(comp)), state, 0, true, 1)
    Citizen.InvokeNative(N.updated, ped, true)
    Citizen.InvokeNative(N.refresh, ped, false, true, true, true, false)
end

local function saveSoon()
    saveAt = GetGameTimer() + 1000
end

CreateThread(function()
    while true do
        Wait(500)
        if saveAt and GetGameTimer() >= saveAt then
            saveAt = nil
            TriggerServerEvent('MULTItailor:server:styles', chosen)
        end
    end
end)

--- put every chosen way back on (after the clothes were put on again)
local function applyChosen()
    if ST.enabled == false or not next(chosen) then return end
    local ped = PlayerPedId()
    local w = worn()
    for key, state in pairs(chosen) do
        local piece = w[key]
        if piece and piece.comp and indexOf(statesOf(piece.comp, ped), state) then
            setState(ped, piece.comp, state)
        end
    end
end

local function loadChosen()
    if ST.enabled == false then return end
    local s = lib.callback.await('multitailor:styles:get', false)
    chosen = type(s) == 'table' and s or {}
    loaded = true
    applyChosen()
end

AddEventHandler('MULTIinventory:client:clothingApplied', function(reason)
    if reason == 'preview' then return end
    SetTimeout(tonumber(ST.reapplyDelayMs) or 250, function()
        if not loaded then CreateThread(loadChosen) else applyChosen() end
    end)
end)
RegisterNetEvent('MULTIcore:client:characterSelected', function() chosen, loaded = {}, false end)

--- the piece in slot `key` steps to its next way of sitting (wraps round to the first)
local function stepStyle(key)
    local ped = PlayerPedId()
    local piece = worn()[key]
    if not piece or not piece.comp then return false end
    local states = statesOf(piece.comp, ped)
    if #states < 2 then return false end
    local i = indexOf(states, chosen[key]) or 1
    local nextState = states[(i % #states) + 1]
    setState(ped, piece.comp, nextState)
    if nextState == states[1] then chosen[key] = nil else chosen[key] = nextState end
    saveSoon()
    return true, (indexOf(states, nextState) or 1), #states
end

local function resetStyles()
    local ped = PlayerPedId()
    local w = worn()
    for key in pairs(chosen) do
        local piece = w[key]
        if piece and piece.comp then
            local states = statesOf(piece.comp, ped)
            if states[1] then setState(ped, piece.comp, states[1]) end
        end
    end
    chosen = {}
    saveSoon()
end

local function stylesMenu()
    local ped = PlayerPedId()
    local w = worn()
    local options = {}
    for _, key in ipairs(ST.keys or {}) do
        local piece = w[key]
        local states = piece and piece.comp and statesOf(piece.comp, ped) or {}
        if #states > 1 then
            local i = indexOf(states, chosen[key]) or 1
            options[#options + 1] = {
                title = tostring(piece.label or key), icon = 'shirt',
                description = L('style_way', i, #states),
                onSelect = function() stepStyle(key) Wait(150) stylesMenu() end,
            }
        end
    end
    if #options == 0 then
        options[1] = { title = L('style_none'), disabled = true }
    else
        options[#options + 1] = { title = L('style_reset'), icon = 'rotate-left', disabled = not next(chosen),
                                  onSelect = function() resetStyles() Wait(150) stylesMenu() end }
    end
    lib.registerContext({ id = 'multitailor_styles', title = L('style_title'), menu = 'multitailor_toggles', options = options })
    lib.showContext('multitailor_styles')
end

if ST.enabled ~= false and type(ST.command) == 'string' and ST.command ~= '' then
    RegisterCommand(ST.command, function()
        if not stepStyle('NeckWear') then TC.notify(L('style_no_bandana'), 'error') end
    end, false)
end

-- ---------------------------------------------------------------- pages in /clothes
function X.clothesOptions(reopen)
    local out = {}
    if ST.enabled ~= false then
        out[#out + 1] = { title = L('style_title'), description = L('style_desc'), icon = 'shirt', arrow = true,
                          onSelect = function() stylesMenu() end }
    end
    if TB.enabled ~= false then
        out[#out + 1] = { title = L('tobacco_title'), description = L('tobacco_desc'), icon = 'smoking', arrow = true,
                          onSelect = function() tobaccoMenu(reopen) end }
    end
    return out
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then
        SetTimeout(2000, function() CreateThread(loadChosen) end)
    end
end)

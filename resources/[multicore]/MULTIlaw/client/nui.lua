-- ============================================================
-- MULTIlaw :: the NUI pages (bounty board, records) and the jail timer
-- The pages show what the server sends; every button asks the server.
-- ============================================================

local page = nil      -- 'board' | 'records'
local openAt = nil    -- where the page was opened (it closes when you walk away)

local function closePage()
    if not page then return end
    page, openAt = nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function LawC.OpenPage(which)
    CreateThread(function()
        if page then closePage() end
        local res
        if which == 'board' then
            res = lib.callback.await('MULTIlaw:board:list', false)
        elseif which == 'records' then
            res = lib.callback.await('MULTIlaw:records:search', false, '')
        end
        if type(res) ~= 'table' or not res.ok then return LawC.say(res or { ok = false, msg = _L('failed') }) end
        page, openAt = which, GetEntityCoords(PlayerPedId())
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', page = which, list = res.list, law = res.law, L = _LT(), lang = _LCode(), now = 0 })
    end)
end

RegisterNUICallback('close', function(_, cb)
    closePage()
    cb({})
end)

RegisterNUICallback('records_search', function(data, cb)
    if page ~= 'records' then return cb({ ok = false }) end
    cb(lib.callback.await('MULTIlaw:records:search', false, type(data) == 'table' and data.q or '') or { ok = false })
end)

RegisterNUICallback('records_get', function(data, cb)
    if page ~= 'records' or type(data) ~= 'table' then return cb({ ok = false }) end
    cb(lib.callback.await('MULTIlaw:records:get', false, data.cid) or { ok = false })
end)

RegisterNUICallback('board_cancel', function(data, cb)
    if page ~= 'board' or type(data) ~= 'table' then return cb({ ok = false }) end
    local res = lib.callback.await('MULTIlaw:bounty:cancel', false, data.id) or { ok = false }
    if res.ok then
        local list = lib.callback.await('MULTIlaw:board:list', false)
        res.list = list and list.list
    end
    cb(res)
end)

RegisterNUICallback('board_post', function(_, cb)
    cb({})
    closePage()
    CreateThread(LawC.PostBountyDialog)
end)

-- walking away closes the page
CreateThread(function()
    while true do
        Wait(1000)
        if page and openAt and #(GetEntityCoords(PlayerPedId()) - openAt) > Config.CloseDistance then closePage() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and page then SetNuiFocus(false, false) end
end)

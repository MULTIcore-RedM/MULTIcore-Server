--[[
    Needlework minigame + the bench's sewing window (view 'sew').
      TSewC.minigame(pointId, kind) -> token, hits | nil, error
         ox_lib skill checks, one per Config.Sewing.rounds entry. The open window loses focus while
         the checks run and gets it back after.
      TSewC.open(point)              the sewing window: recipes, pockets, batch size.
]]
TSewC = TSewC or {}

local sewing = false
local sewPoint

local function playSewAnim(on)
    local ped = PlayerPedId()
    if on then
        TaskStartScenarioInPlace(ped, joaat('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    else
        ClearPedTasks(ped)
    end
end

function TSewC.minigame(pointId, kind)
    if sewing then return nil, L('err_busy') end
    local start = lib.callback.await('multitailor:sew:start', false, { pointId = pointId, kind = kind })
    if not start or not start.ok then return nil, start and start.error or L('err_generic') end
    sewing = true
    local hadFocus = TC.view ~= nil
    SendNUIMessage({ action = 'busy', on = true, text = L('sew_minigame') })
    TC.focus(false)
    Wait(150)
    local hits = {}
    for i, diff in ipairs(start.rounds or {}) do
        local ok, res = pcall(function() return lib.skillCheck({ diff }, start.keys) end)
        hits[i] = ok and res == true
        Wait(200)
    end
    sewing = false
    if hadFocus and TC.view then TC.focus(true) end
    SendNUIMessage({ action = 'busy', on = false })
    return start.token, hits
end

function TSewC.open(point)
    if TC.view then return end
    local payload, err = lib.callback.await('multitailor:sew:open', false, point.id)
    if not payload then return TC.notify(err or L('err_no_access'), 'error') end
    sewPoint = point
    TC.open('sew', payload)
end

TC.on('sew', 'craft', function(data)
    if not sewPoint then return { ok = false } end
    local amount = TU.int(data.amount, 1, Config.Sewing.maxBatch or 10) or 1
    local token, hits = TSewC.minigame(sewPoint.id, 'recipe')
    if not token then return { ok = false, error = hits } end
    TC.focus(false)
    SendNUIMessage({ action = 'busy', on = true, text = L('sew_working') })
    playSewAnim(true)
    local ms = math.min(20000, (Config.Sewing.craftMsPerUnit or 2500) * amount)
    pcall(function() lib.progressBar({ duration = ms, label = L('sew_working'), useWhileDead = false, canCancel = false,
        disable = { move = true, car = true, combat = true } }) end)
    playSewAnim(false)
    local res = lib.callback.await('multitailor:sew:craft', false, { pointId = sewPoint.id, token = token, hits = hits,
        recipe = data.recipe, amount = amount }) or { ok = false }
    SendNUIMessage({ action = 'busy', on = false })
    if TC.view == 'sew' then TC.focus(true) end
    return res
end)

TC.onClose('sew', function() sewPoint = nil end)

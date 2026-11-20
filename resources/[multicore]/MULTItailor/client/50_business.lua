--[[
    Tailor's counter (view 'counter') and office (view 'boss'). Thin relays: every action is a
    server callback that re-checks the point, the job and the money, and returns a fresh payload.
]]
TBiz = TBiz or {}

local counterPoint, bossPoint

function TBiz.counter(point)
    if TC.view then return end
    local payload, err = lib.callback.await('multitailor:counter:open', false, point.id)
    if not payload then return TC.notify(err or L('err_no_access'), 'error') end
    counterPoint = point
    TC.open('counter', payload)
end

function TBiz.boss(point)
    if TC.view then return end
    local payload, err = lib.callback.await('multitailor:boss:open', false, point.id)
    if not payload then return TC.notify(err or L('err_no_access'), 'error') end
    bossPoint = point
    TC.open('boss', payload)
end

local function relay(view, name, getPoint)
    return function(data)
        local p = getPoint()
        if not p then return { ok = false } end
        data.pointId = p.id
        data.view, data.act = nil, nil
        return lib.callback.await(name, false, data) or { ok = false }
    end
end

local function cp() return counterPoint end
local function bp() return bossPoint end

TC.on('counter', 'buy', relay('counter', 'multitailor:counter:buy', cp))
TC.on('counter', 'stock', relay('counter', 'multitailor:counter:stock', cp))
TC.on('counter', 'reprice', relay('counter', 'multitailor:counter:reprice', cp))
TC.on('counter', 'unstock', relay('counter', 'multitailor:counter:unstock', cp))
TC.on('counter', 'orderPlace', relay('counter', 'multitailor:orders:place', cp))
TC.on('counter', 'orderCancel', relay('counter', 'multitailor:orders:cancel', cp))
TC.on('counter', 'orderSet', relay('counter', 'multitailor:orders:set', cp))
TC.onClose('counter', function() counterPoint = nil end)

TC.on('boss', 'withdraw', relay('boss', 'multitailor:boss:withdraw', bp))
TC.on('boss', 'deposit', relay('boss', 'multitailor:boss:deposit', bp))
TC.on('boss', 'hire', relay('boss', 'multitailor:boss:hire', bp))
TC.on('boss', 'fire', relay('boss', 'multitailor:boss:fire', bp))
TC.on('boss', 'grade', relay('boss', 'multitailor:boss:grade', bp))
TC.on('boss', 'refresh', function()
    if not bossPoint then return { ok = false } end
    local payload, err = lib.callback.await('multitailor:boss:open', false, bossPoint.id)
    if not payload then return { ok = false, error = err } end
    return { ok = true, payload = payload }
end)
TC.onClose('boss', function() bossPoint = nil end)

-- walk away -> close
CreateThread(function()
    while true do
        local p = (TC.view == 'counter' and counterPoint) or (TC.view == 'boss' and bossPoint) or nil
        if p then
            local c = vector3(p.coords.x, p.coords.y, p.coords.z)
            if #(GetEntityCoords(PlayerPedId()) - c) > (Config.Tailor.stationDistance or 4.0) + 2.0 or IsEntityDead(PlayerPedId()) then
                TC.close(true)
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

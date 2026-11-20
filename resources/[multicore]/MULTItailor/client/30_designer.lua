--[[
    Outfit Designer (client). A docked Iron Brand plate (html, view 'designer') beside a fitting
    dummy: a local, non-networked mp_male / mp_female ped watched by a scripted camera.

    NUI actions (view 'designer'; the server re-validates everything):
      set { c, m, v } (m = 0 removes) · tint { c, p, t0, t1, t2 } · sex { sex } · rotate { dir } · view { view }
      clear · cut { name } (needlework minigame first) · patternSave { name } · patternLoad { id } · patternDelete { id }
]]
TDes = TDes or {}

local D = {
    open = false, point = nil, payload = nil, sex = 'male',
    dummy = nil, cam = nil, heading = 0.0, root = nil, view = 'full', pieces = {}, npc = {},
}

local function cfg() return Config.Designer end

-- ---------------------------------------------------------------- dummy
local function dressCategory(catId)
    local ped = D.dummy
    if not ped or not DoesEntityExist(ped) then return end
    local c = TS.category(catId)
    if not c then return end
    TCN.removeTag(ped, c.tag)
    local p = D.pieces[catId]
    if p then
        local hash = TS.resolve(D.sex, catId, p.m, p.v)
        if hash then
            TCN.applyHash(ped, hash, c.id == 'boots')
            TCN.updateVariation(ped)
            TCN.readyToRender(ped)
            if (p.p or 0) ~= 0 then TCN.setTint(ped, c.tag, p.p, p.t0 or 0, p.t1 or 0, p.t2 or 0) end
        end
    end
    TCN.updateVariation(ped)
end

local function dressAll()
    local ped = D.dummy
    if not ped or not DoesEntityExist(ped) then return end
    TCN.readyToRender(ped)
    for _, c in ipairs(cfg().categories) do TCN.removeTag(ped, c.tag) end
    TCN.updateVariation(ped)
    for _, c in ipairs(cfg().categories) do
        if D.pieces[c.id] then dressCategory(c.id) end
    end
    for _, id in ipairs({ 'shirt', 'vest', 'boots' }) do if D.pieces[id] then dressCategory(id) end end
    TDes.dressNpc()
end

local function deleteDummy()
    if D.dummy and DoesEntityExist(D.dummy) then
        SetEntityAsMissionEntity(D.dummy, true, true)
        DeleteEntity(D.dummy)
    end
    D.dummy = nil
end

local function clearDistance(from, dir, maxDist)
    local to = from + dir * maxDist
    local probe = Citizen.InvokeNative(0x377906D8A31E5586, from.x, from.y, from.z, to.x, to.y, to.z, 1 | 16, PlayerPedId(), 7, Citizen.ResultAsInteger())
    local t = GetGameTimer() + 500
    while GetGameTimer() < t do
        local state, hit, endCoords = GetShapeTestResult(probe)
        if state ~= 1 then
            if state == 2 and hit == 1 and endCoords then return #(endCoords - from) end
            return maxDist
        end
        Wait(0)
    end
    return maxDist
end

local function spotForDummy()
    local d = D.payload and D.payload.designer
    if cfg().placement == 'fittingroom' and d and d.ped then
        return vector3(d.ped.x, d.ped.y, d.ped.z), (d.ped.w or 0.0), d.cam and vector3(d.cam.x, d.cam.y, d.cam.z) or nil
    end
    local me = PlayerPedId()
    local pos = D.anchor or GetEntityCoords(me)
    local bench = D.point and D.point.coords and vector3(D.point.coords.x, D.point.coords.y, D.point.coords.z)
    local away = bench and (pos - bench) or -GetEntityForwardVector(me)
    away = vector3(away.x, away.y, 0.0)
    local len = #away
    if len < 0.01 then local f = GetEntityForwardVector(me) away = vector3(-f.x, -f.y, 0.0) len = #away end
    away = away / len
    local best, bestDist = away, 0.0
    for _, dir in ipairs({ away, vector3(away.y, -away.x, 0.0), vector3(-away.y, away.x, 0.0) }) do
        local free = clearDistance(pos + vector3(0.0, 0.0, 0.3), dir, (cfg().dummyDistance or 2.0) + 0.6)
        if free > bestDist + 0.25 then best, bestDist = dir, free end
    end
    local dist = math.max(cfg().minDistance or 1.3, math.min(cfg().dummyDistance or 2.0, bestDist - 0.6))
    local spot = pos + best * dist
    local heading = GetHeadingFromVector_2d(-best.x, -best.y)
    return vector3(spot.x, spot.y, pos.z), heading, vector3(pos.x, pos.y, pos.z + 0.15)
end

local function spawnDummy(sex)
    deleteDummy()
    local pos, heading, camPos = spotForDummy()
    D.camPos = camPos
    local model = joaat(sex == 'male' and 'mp_male' or 'mp_female')
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    local ped = CreatePed(model, pos.x, pos.y, pos.z, heading, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    local t2 = GetGameTimer() + 2000
    while not DoesEntityExist(ped) and GetGameTimer() < t2 do Wait(0) end
    if not DoesEntityExist(ped) then TC.notify(L('err_no_dummy'), 'error') return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, sex == 'male' and 4 or 7, true)
    SetEntityVisible(ped, true)
    PlaceEntityOnGroundProperly(ped)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    TaskStandStill(ped, -1)
    D.dummy, D.heading, D.sex = ped, heading, sex
    D.root = GetEntityCoords(ped)
    dressAll()
end

-- ---------------------------------------------------------------- camera
local function aimCamera()
    if not D.cam or not D.dummy then return end
    local v = (cfg().views or {})[D.view] or { z = 0.0, fov = 46.0 }
    local root = D.root or GetEntityCoords(D.dummy)
    local camPos = GetCamCoord(D.cam)
    local f = vector3(root.x - camPos.x, root.y - camPos.y, 0.0)
    local dist = #f
    local aim = vector3(root.x, root.y, root.z + (v.z or 0.0))
    if dist > 0.01 then
        f = f / dist
        local right = vector3(f.y, -f.x, 0.0)
        aim = aim + right * ((cfg().panelShift or 0.45) * dist / 2.2)
    end
    PointCamAtCoord(D.cam, aim.x, aim.y, aim.z)
    local scale = math.max(1.0, math.min(1.7, 2.2 / math.max(dist, 0.5)))
    SetCamFov(D.cam, math.min(80.0, (v.fov or 46.0) * scale))
end

local function makeCamera()
    local camPos = D.camPos
    local root = D.root or (D.dummy and GetEntityCoords(D.dummy))
    if not root then return end
    if not camPos then
        local h = math.rad(D.heading)
        local dist = cfg().camDistance or 2.6
        camPos = vector3(root.x - math.sin(h) * dist, root.y + math.cos(h) * dist, root.z + 0.35)
    end
    D.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, cfg().fov or 42.0, false, 0)
    SetCamActive(D.cam, true)
    RenderScriptCams(true, true, 500, true, true, 0)
    aimCamera()
end

local function destroyCamera()
    if D.cam then
        RenderScriptCams(false, true, 500, true, true, 0)
        SetCamActive(D.cam, false)
        DestroyCam(D.cam, true)
    end
    D.cam = nil
end

-- ---------------------------------------------------------------- open / close
local function countsFor(sex)
    local cat = TCN.catalogue()
    local out = {}
    for _, c in ipairs(cfg().categories) do
        local models = cat and cat[sex] and cat[sex][c.id]
        if models then
            local v, titles = {}, {}
            for i, m in ipairs(models) do v[i] = #m.hashes titles[i] = m.title or false end
            out[c.id] = { variants = v, titles = titles }
        end
    end
    return out
end

local function cleanup()
    D.open = false
    destroyCamera()
    deleteDummy()
    FreezeEntityPosition(PlayerPedId(), false)
    ResetEntityAlpha(PlayerPedId())
    D.pieces, D.payload, D.point, D.anchor, D.camPos = {}, nil, nil, nil, nil
    D.npc = {}
end

TC.onClose('designer', function() if D.open then cleanup() end end)

function TDes.open(point)
    if D.open or TC.view then return end
    local payload, err = lib.callback.await('multitailor:designer:open', false, point.id)
    if not payload then return TC.notify(err or L('err_no_access'), 'error') end
    local cat, cerr = TCN.catalogue()
    if not cat then return TC.notify(L('err_no_catalogue', tostring(cerr)), 'error') end
    D.open, D.point, D.payload, D.view, D.pieces = true, point, payload, 'full', {}
    FreezeEntityPosition(PlayerPedId(), true)
    D.anchor = GetEntityCoords(PlayerPedId())
    DoScreenFadeOut(250)
    Wait(260)
    spawnDummy(payload.sex == 'female' and 'female' or 'male')
    if cfg().hidePlayer ~= false then SetEntityAlpha(PlayerPedId(), 0, false) end
    makeCamera()
    DoScreenFadeIn(400)
    payload.catalogue = { male = countsFor('male'), female = countsFor('female') }
    TC.open('designer', payload)

    if cfg().hideOthers ~= false then
        CreateThread(function()
            local radius = cfg().hideRadius or 15.0
            local list, nextScan = {}, 0
            while D.open do
                local now = GetGameTimer()
                if now >= nextScan then
                    nextScan = now + 500
                    list = {}
                    local me, centre = PlayerPedId(), D.root or D.anchor
                    if centre then
                        for _, pool in ipairs({ 'CPed', 'CVehicle' }) do
                            local ok, entsList = pcall(GetGamePool, pool)
                            for _, e in ipairs(ok and entsList or {}) do
                                if e ~= me and e ~= D.dummy and #(GetEntityCoords(e) - centre) < radius then list[#list + 1] = e end
                            end
                        end
                    end
                end
                for _, e in ipairs(list) do
                    if DoesEntityExist(e) then Citizen.InvokeNative(0xE135A9FF3F5D05D8, e) end -- SET_ENTITY_LOCALLY_INVISIBLE
                end
                Wait(0)
            end
        end)
    end

    CreateThread(function()
        local bench = vector3(point.coords.x, point.coords.y, point.coords.z)
        while D.open do
            Wait(500)
            local me = PlayerPedId()
            if IsEntityDead(me) or #(GetEntityCoords(me) - bench) > ((Config.Tailor.stationDistance or 4.0) + 3.0) then
                TC.close(true)
            end
        end
    end)
end

-- ---------------------------------------------------------------- NUI
local function piecesArray()
    local out = {}
    for _, c in ipairs(cfg().categories) do
        local p = D.pieces[c.id]
        if p then out[#out + 1] = { c = c.id, m = p.m, v = p.v, p = p.p or 0, t = { p.t0 or 0, p.t1 or 0, p.t2 or 0 } } end
    end
    return out
end

TC.on('designer', 'set', function(data)
    local c = TS.category(data.c)
    if not c then return { ok = false } end
    local m, v = TU.int(data.m, 0, 100000) or 0, TU.int(data.v, 1, 100000) or 1
    if m <= 0 then
        D.pieces[c.id] = nil
    elseif TS.resolve(D.sex, c.id, m, v) then
        local old = D.pieces[c.id] or {}
        D.pieces[c.id] = { m = m, v = v, p = old.p or 0, t0 = old.t0 or 0, t1 = old.t1 or 0, t2 = old.t2 or 0 }
    else
        return { ok = false }
    end
    dressCategory(c.id)
    if (c.id == 'coat' or c.id == 'coat_closed' or c.id == 'suspenders') and (D.pieces.shirt or D.pieces.vest) then
        if D.pieces.shirt then dressCategory('shirt') end
        if D.pieces.vest then dressCategory('vest') end
    end
    return { ok = true }
end)

TC.on('designer', 'tint', function(data)
    local c = TS.category(data.c)
    local p = c and D.pieces[c.id]
    if not p then return { ok = false } end
    p.p = TU.int(data.p, -2147483648, 4294967295) or 0
    p.t0, p.t1, p.t2 = TU.int(data.t0, 0, 254) or 0, TU.int(data.t1, 0, 254) or 0, TU.int(data.t2, 0, 254) or 0
    if p.p ~= 0 then
        TCN.setTint(D.dummy, c.tag, p.p, p.t0, p.t1, p.t2)
        TCN.updateVariation(D.dummy)
    else
        dressCategory(c.id)
    end
    return { ok = true }
end)

TC.on('designer', 'sex', function(data)
    local sex = TS.sexOf(data.sex) or 'male'
    D.pieces = {}
    D.npc = {}
    DoScreenFadeOut(200)
    Wait(210)
    spawnDummy(sex)
    aimCamera()
    DoScreenFadeIn(300)
    return { ok = true, sex = sex }
end)

TC.on('designer', 'rotate', function(data)
    local step = cfg().rotateStep or 30.0
    D.heading = (D.heading + step * ((tonumber(data.dir) or 1) >= 0 and 1 or -1)) % 360.0
    if D.dummy then SetEntityHeading(D.dummy, D.heading) end
    return { ok = true }
end)

TC.on('designer', 'view', function(data)
    if (cfg().views or {})[data.view] then D.view = data.view end
    aimCamera()
    return { ok = true, view = D.view }
end)

TC.on('designer', 'clear', function()
    D.pieces = {}
    dressAll()
    return { ok = true }
end)

TC.on('designer', 'cut', function(data)
    local token, hits = TSewC.minigame(D.point.id, 'outfit')
    if not token then return { ok = false, error = hits } end
    local res = lib.callback.await('multitailor:designer:cut', false, {
        pointId = D.point.id, name = data.name, sex = D.sex, pieces = piecesArray(), session = token, hits = hits,
    }) or { ok = false }
    if res.ok and res.pockets and D.payload then D.payload.pockets = res.pockets end
    return res
end)

TC.on('designer', 'patternSave', function(data)
    return lib.callback.await('multitailor:designer:patternSave', false, {
        pointId = D.point.id, name = data.name, sex = D.sex, pieces = piecesArray(),
    }) or { ok = false }
end)

TC.on('designer', 'patternDelete', function(data)
    return lib.callback.await('multitailor:designer:patternDelete', false, { pointId = D.point.id, id = data.id }) or { ok = false }
end)

TC.on('designer', 'patternLoad', function(data)
    local res = lib.callback.await('multitailor:designer:patternLoad', false, { pointId = D.point.id, id = data.id }) or { ok = false }
    if not res.ok or type(res.pattern) ~= 'table' then return res end
    local pat = res.pattern
    local sex = TS.sexOf(pat.sex) or D.sex
    if sex ~= D.sex then spawnDummy(sex) aimCamera() end
    D.pieces = {}
    for _, p in ipairs(pat.pieces or {}) do
        local c = type(p) == 'table' and TS.category(p.c)
        if c and TS.resolve(sex, c.id, p.m, p.v) then
            local t = type(p.t) == 'table' and p.t or {}
            D.pieces[c.id] = { m = tonumber(p.m), v = tonumber(p.v), p = tonumber(p.p) or 0,
                t0 = tonumber(t[1]) or 0, t1 = tonumber(t[2]) or 0, t2 = tonumber(t[3]) or 0 }
        end
    end
    dressAll()
    return { ok = true, sex = sex, name = pat.name, pieces = piecesArray() }
end)

-- ---------------------------------------------------------------- NPC clothing (RINGOnpcclothing, Config.NpcClothing)
-- D.npc[id] = piece (from the server; RINGOnpcclothing approved it). Shown on the dummy on top of the designer pieces.
local function npcRes() return (Config.NpcClothing or {}).resource or 'RINGOnpcclothing' end

local function npcApply(piece)
    if not D.dummy or not DoesEntityExist(D.dummy) or GetResourceState(npcRes()) ~= 'started' then return false end
    local ok, res = pcall(function() return exports[npcRes()]:ApplyPieceToPed(D.dummy, piece) end)
    return ok and res
end

function TDes.dressNpc()
    for _, piece in pairs(D.npc or {}) do npcApply(piece) end
end

TC.on('designer', 'npcList', function(data)
    return lib.callback.await('multitailor:npc:list', false, {
        pointId = D.point.id, sex = D.sex, q = data.q, cat = data.cat, page = data.page,
    }) or { ok = false }
end)

TC.on('designer', 'npcShow', function(data)
    if type(data.id) ~= 'string' then return { ok = false } end
    local res = lib.callback.await('multitailor:npc:piece', false, { pointId = D.point.id, sex = D.sex, id = data.id, v = data.v }) or { ok = false }
    if not res.ok or type(res.piece) ~= 'table' then return res end
    local old = D.npc[data.id]
    if old and old.cat ~= res.piece.cat then pcall(function() exports[npcRes()]:RemoveCategoryFromPed(D.dummy, old.cat) end) end
    D.npc[data.id] = res.piece
    npcApply(res.piece)
    if data.focus ~= false and res.view and (cfg().views or {})[res.view] then D.view = res.view aimCamera() end
    return { ok = true, view = D.view, gcat = res.gcat }
end)

TC.on('designer', 'npcRemove', function(data)
    local p = type(data.id) == 'string' and D.npc[data.id]
    if not p then return { ok = true } end
    D.npc[data.id] = nil
    pcall(function() exports[npcRes()]:RemoveCategoryFromPed(D.dummy, p.cat) end)
    dressAll()
    return { ok = true }
end)

TC.on('designer', 'npcCut', function(data)
    local token, hits = TSewC.minigame(D.point.id, 'outfit')
    if not token then return { ok = false, error = hits } end
    local res = lib.callback.await('multitailor:npc:cut', false, {
        pointId = D.point.id, sex = D.sex, mode = data.mode, name = data.name, pieces = data.pieces,
        session = token, hits = hits,
    }) or { ok = false }
    if res.ok and res.pockets and D.payload then D.payload.pockets = res.pockets end
    return res
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not D.open then return end
    destroyCamera()
    deleteDummy()
    FreezeEntityPosition(PlayerPedId(), false)
    ResetEntityAlpha(PlayerPedId())
    DoScreenFadeIn(0)
end)

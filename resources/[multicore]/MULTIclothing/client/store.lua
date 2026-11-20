-- ============================================================
-- MULTIclothing :: client store
-- Try-on with live preview (MULTIcore look library), camera framing,
-- rotate, basket and checkout. Edits comps only.
-- ============================================================

local S = nil -- the open store session

local TINT_MAX = 254 -- highest tint the MULTIcore look format accepts (format limit, BASE_SET)

local LISTED = {}
for _, c in ipairs(Config.Categories) do LISTED[c.key] = true end

-- game item name, made readable: CLOTHING_ITEM_M_HAT_011_TINT_002 -> Hat 011 Tint 002
-- (nil for pieces with no known name; the page then shows its locale "Style n")
local function pieceName(list, index)
    local e = list and list[index]
    if not e or not e.n then return nil end
    local s = e.n:gsub('^CLOTHING_ITEM_', ''):gsub('^CLOTHING_', ''):gsub('^[MF]_', ''):gsub('_', ' '):lower()
    return (s:gsub('(%a)(%w*)', function(a, b) return a:upper() .. b end))
end

local function buildCategories(clothes)
    local out = {}
    for _, c in ipairs(Config.Categories) do
        if clothes[c.key] and not Config.NotSold[c.key] then
            out[#out + 1] = { key = c.key, group = c.group, cam = c.cam, price = c.price, count = #clothes[c.key] }
        end
    end
    local extra = {}
    for key, list in pairs(clothes) do
        if not LISTED[key] and not Config.NotSold[key] then
            extra[#extra + 1] = { key = key, group = Config.OtherGroup, cam = Config.OtherCam, price = Config.DefaultPrice, count = #list }
        end
    end
    table.sort(extra, function(a, b) return a.key < b.key end)
    for _, e in ipairs(extra) do out[#out + 1] = e end
    return out
end

-- ---------------------------------------------------------------
-- Camera
-- ---------------------------------------------------------------

local function frame(region)
    if not S then return end
    local c = Config.Camera[region] or Config.Camera.full
    local pos = GetEntityCoords(S.ped)
    local h = math.rad(S.camHeading)
    local fx, fy = -math.sin(h), math.cos(h) -- forward of the heading the player faced when the store opened
    local cx, cy, cz = pos.x + fx * c.dist, pos.y + fy * c.dist, pos.z + c.z
    if not S.cam or not DoesCamExist(S.cam) then
        S.cam = CreateCamWithParams(Config.Camera.Name, cx, cy, cz, 0.0, 0.0, 0.0, c.fov, false, 0)
        SetCamActive(S.cam, true)
        RenderScriptCams(true, true, Config.Timing.CamEase, true, true, 0)
    else
        SetCamCoord(S.cam, cx, cy, cz)
        SetCamFov(S.cam, c.fov)
    end
    PointCamAtCoord(S.cam, pos.x, pos.y, pos.z + c.z)
    S.region = region
end

local function dropCam()
    if S and S.cam then
        RenderScriptCams(false, true, Config.Timing.CamEase, true, true, 0)
        DestroyCam(S.cam, false)
        S.cam = nil
    end
end

local function fade(out)
    if out then
        DoScreenFadeOut(Config.Timing.Fade)
        local t = GetGameTimer() + Config.Timing.FadeWaitMax
        while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end
    else
        DoScreenFadeIn(Config.Timing.Fade)
    end
end

-- ---------------------------------------------------------------
-- Open / close
-- ---------------------------------------------------------------

local function close(restore)
    if not S then return end
    local s = S
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    fade(true)
    dropCam()
    FreezeEntityPosition(s.ped, false)
    local exit = Config.Stores[s.id] and Config.Stores[s.id].exit
    if exit then
        SetEntityCoords(s.ped, exit.x, exit.y, exit.z, false, false, false, false)
        SetEntityHeading(s.ped, exit.w)
    end
    S = nil
    MC.storeOpen = false
    if restore then exports.MULTIcore:ReloadLook() end
    fade(false)
end

function MC.OpenStore(storeId)
    if S or not MC.LoggedIn() or MC.Busy() then return end
    local store = Config.Stores[storeId]
    if not store then return end
    local look = MC.SavedLook()
    if not look then return MC.Error('failed') end
    MC.ResetToggles() -- start from the saved look, pieces back on

    local data = exports.MULTIcore:GetData()
    local sex = look.skin.sex == 'female' and 'female' or 'male'
    local clothes = data and data.Clothes and data.Clothes[sex]
    if not clothes then return MC.Error('failed') end

    local ped = PlayerPedId()
    MC.storeOpen = true
    S = {
        id = storeId, ped = ped, sex = sex, clothes = clothes,
        saved = MC.Copy(look.comps), work = {},
        palettes = (data.Palettes and #data.Palettes) or 0,
    }
    local cats = buildCategories(clothes)
    for _, c in ipairs(cats) do S.work[c.key] = MC.Copy(look.comps[c.key]) end

    fade(true)
    ClearPedTasksImmediately(ped, false, true)
    if store.fitting then
        SetEntityCoords(ped, store.fitting.x, store.fitting.y, store.fitting.z, false, false, false, false)
        SetEntityHeading(ped, store.fitting.w)
    end
    FreezeEntityPosition(ped, true)
    Wait(Config.Timing.Settle)
    S.camHeading = GetEntityHeading(ped)
    S.heading = S.camHeading
    frame(Config.Camera.Start)
    fade(false)

    -- send the current pieces with their names
    local list = {}
    for _, c in ipairs(cats) do
        local cur = S.work[c.key]
        c.current = cur
        c.name = cur and pieceName(clothes[c.key], cur.index) or nil
        list[#list + 1] = c
    end
    local pd = MC.RSGCore.Functions.GetPlayerData()
    SendNUIMessage({
        action = 'open',
        store = _L(store.name),
        locale = _LT(),
        lang = _LCode(),
        currency = Config.Currency,
        previewDelay = Config.Timing.PreviewDelay,
        categories = list,
        saved = S.saved,
        cash = pd and pd.money and pd.money.cash or 0,
        recolour = Config.RecolourFactor,
        colours = Config.AllowColours and S.palettes > 0,
        palettes = S.palettes,
    })
    SetNuiFocus(true, true)

    CreateThread(function()
        while S do
            if IsEntityDead(S.ped) then close(true) break end
            Wait(Config.Timing.DeadCheck)
        end
    end)
end

-- ---------------------------------------------------------------
-- NUI callbacks
-- ---------------------------------------------------------------

local function cleanPiece(cat, p)
    local list = S.clothes[cat]
    if type(p) ~= 'table' or not list then return nil end
    local index = math.floor(tonumber(p.index) or 0)
    if index < 1 or index > #list then return nil end
    local out = { index = index }
    local pal = math.floor(tonumber(p.palette) or 0)
    if Config.AllowColours and pal >= 1 and pal <= S.palettes then
        out.palette = pal
        out.tint0 = math.max(0, math.min(TINT_MAX, math.floor(tonumber(p.tint0) or 0)))
        out.tint1 = math.max(0, math.min(TINT_MAX, math.floor(tonumber(p.tint1) or 0)))
        out.tint2 = math.max(0, math.min(TINT_MAX, math.floor(tonumber(p.tint2) or 0)))
    end
    return out
end

RegisterNUICallback('preview', function(d, cb)
    if not S or type(d) ~= 'table' or not S.clothes[d.cat] or Config.NotSold[d.cat] then return cb({}) end
    local piece = cleanPiece(d.cat, d.piece)
    S.work[d.cat] = piece
    if piece then
        exports.MULTIcore:ApplyComp(S.ped, d.cat, piece)
    else
        exports.MULTIcore:RemoveComp(S.ped, d.cat)
    end
    cb({ name = piece and pieceName(S.clothes[d.cat], piece.index) or nil })
end)

RegisterNUICallback('camera', function(d, cb)
    if S and type(d) == 'table' and type(Config.Camera[d.region]) == "table" then frame(d.region) end
    cb({})
end)

RegisterNUICallback('rotate', function(d, cb)
    if S and type(d) == 'table' then
        local dir = tonumber(d.dir) or 0
        if dir > 1 then dir = 1 elseif dir < -1 then dir = -1 end
        S.heading = (S.heading + dir * Config.Camera.RotateStep) % 360.0
        SetEntityHeading(S.ped, S.heading)
    end
    cb({})
end)

RegisterNUICallback('buy', function(_, cb)
    if not S then return cb({ ok = false }) end
    local ok, res = lib.callback.await('MULTIclothing:buy', false, S.id, S.work)
    if not ok then
        cb({ ok = false, msg = (res and _L(res)) or _L('failed') })
        return
    end
    cb({ ok = true })
    local total = tonumber(res) or 0
    if total > 0 then
        MC.Notify(_L("bought", Config.Currency .. ("%.2f"):format(total)), 'success')
    else
        MC.Notify(_L("nothing_bought"), "info")
    end
    close(false)
end)

RegisterNUICallback('cancel', function(_, cb)
    cb({})
    close(true)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not S then return end
    SetNuiFocus(false, false)
    dropCam()
    FreezeEntityPosition(S.ped, false)
    DoScreenFadeIn(0)
    exports.MULTIcore:ReloadLook()
end)

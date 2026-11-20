-- ============================================================
-- MULTIlaw :: the lawman's actions on other players
-- Nearest-player commands, the law menu, MULTItarget options on players,
-- the jail / fine / confiscate dialogs, and paying your own fines.
-- Every action is a request; the server checks job, duty, distance
-- and the target's state.
-- ============================================================

local function act(action, target, data)
    local res = lib.callback.await('MULTIlaw:action', false, action, target, data or {})
    if type(res) ~= 'table' then res = { ok = false, msg = _L('failed') } end
    return res
end

--- nearest other player within dist → server id, ped
function LawC.NearestPlayer(dist)
    local me = PlayerPedId()
    local pos = GetEntityCoords(me)
    local best, bestPed, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            local d = #(GetEntityCoords(ped) - pos)
            if d <= dist and (not bestD or d < bestD) then best, bestPed, bestD = GetPlayerServerId(pid), ped, d end
        end
    end
    return best, bestPed
end

local function serverIdOf(ped)
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerPed(pid) == ped then return GetPlayerServerId(pid) end
    end
end

--- nearest wagon or horse within the configured reach → netId, kind
local function nearestCarrier()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestKind, bestD
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(veh) - pos)
        if d <= Config.Vehicle.Distance and (not bestD or d < bestD) then best, bestKind, bestD = veh, 'vehicle', d end
    end
    for _, ped in ipairs(GetGamePool('CPed')) do
        if not IsPedAPlayer(ped) and Citizen.InvokeNative(0x772A1969F649E902, GetEntityModel(ped)) then -- _IS_THIS_MODEL_A_HORSE
            local d = #(GetEntityCoords(ped) - pos)
            if d <= Config.Vehicle.Distance and (not bestD or d < bestD) then best, bestKind, bestD = ped, 'mount', d end
        end
    end
    if not best or not NetworkGetEntityIsNetworked(best) then return nil end
    return NetworkGetNetworkIdFromEntity(best), bestKind
end

---------------------------------
-- single actions (target = server id)
---------------------------------
function LawC.Cuff(target) return LawC.say(act('cuff', target)) end
function LawC.Escort(target) return LawC.say(act('escort', target)) end
function LawC.Search(target) return LawC.say(act('search', target)) end
function LawC.TakeOut(target) return LawC.say(act('takeout', target)) end
function LawC.Release(target) return LawC.say(act('release', target)) end

function LawC.PutIn(target)
    local netId, kind = nearestCarrier()
    if not netId then return LawC.notify(_L('no_vehicle'), 'error') end
    return LawC.say(act('putin', target, { netId = netId, kind = kind }))
end

function LawC.JailDialog(target)
    local input = lib.inputDialog(_L('jail_title'), {
        { type = 'number', label = _L('jail_minutes'), required = true, min = 1, max = Config.Jail.PrisonMaxMinutes, default = 5 },
        { type = 'select', label = _L('jail_place'), required = true, default = 'auto', options = {
            { value = 'auto', label = _L('jail_auto', Config.Jail.CellMaxMinutes) },
            { value = 'cell', label = _L('jail_cell') },
            { value = 'prison', label = _L('jail_prison') },
        } },
        { type = 'input', label = _L('reason'), required = false, max = 200 },
    })
    if not input then return end
    return LawC.say(act('jail', target, { minutes = input[1], place = input[2], reason = input[3] }))
end

function LawC.FineDialog(target)
    local input = lib.inputDialog(_L('fine_title'), {
        { type = 'number', label = _L('fine_amount', ('%.2f'):format(Config.Fines.Max)), required = true, min = Config.Fines.Min, max = Config.Fines.Max, precision = 2, step = 0.25 },
        { type = 'input', label = _L('reason'), required = true, max = Config.Fines.ReasonLength },
    })
    if not input then return end
    return LawC.say(act('fine', target, { amount = input[1], reason = input[2] }))
end

function LawC.ConfiscateMenu(target)
    local res = act('confiscateList', target)
    if not res.ok then return LawC.say(res) end
    local options = {}
    for _, it in ipairs(res.list or {}) do
        options[#options + 1] = {
            title = it.label,
            description = _L('confiscate_amount_have', it.amount),
            onSelect = function()
                local amount = it.amount
                if it.amount > 1 then
                    local input = lib.inputDialog(_L('confiscate_title'), {
                        { type = 'number', label = _L('confiscate_amount'), required = true, min = 1, max = it.amount, default = it.amount },
                    })
                    if not input then return end
                    amount = input[1]
                end
                LawC.say(act('confiscate', target, { slot = it.slot, amount = amount }))
            end,
        }
    end
    if #options == 0 then options[1] = { title = _L('satchel_empty'), disabled = true } end
    lib.registerContext({ id = 'multilaw_confiscate', title = _L('confiscate_from', res.name or ''), options = options })
    lib.showContext('multilaw_confiscate')
end

---------------------------------
-- the law menu on the nearest player
---------------------------------
function LawC.LawMenu(target)
    if not LawC.IsLaw() then return LawC.notify(_L('not_law'), 'error') end
    target = target or LawC.NearestPlayer(Config.Jail.Distance)
    if not target then return LawC.notify(_L('no_player'), 'error') end
    local st = lib.callback.await('MULTIlaw:targetState', false, target) or {}
    local function opt(key, action, fn, show)
        if show == false or not LawC.Can(action) then return nil end
        return { title = _L(key), onSelect = function() fn(target) end }
    end
    local options = {}
    for _, o in ipairs({
        opt(st.cuffed and 'menu_uncuff' or 'menu_cuff', 'cuff', LawC.Cuff),
        opt(st.escorted and 'menu_escort_stop' or 'menu_escort', 'escort', LawC.Escort),
        opt('menu_putin', 'vehicle', LawC.PutIn, st.cuffed == true and not st.inVehicle),
        opt('menu_takeout', 'vehicle', LawC.TakeOut, st.inVehicle == true),
        opt('menu_search', 'search', LawC.Search),
        opt('menu_confiscate', 'confiscate', LawC.ConfiscateMenu),
        opt('menu_jail', 'jail', LawC.JailDialog),
        opt('menu_fine', 'fine', LawC.FineDialog),
    }) do if o then options[#options + 1] = o end end
    if #options == 0 then return LawC.notify(_L('off_duty'), 'error') end
    lib.registerContext({ id = 'multilaw_menu', title = _L('menu_title'), options = options })
    lib.showContext('multilaw_menu')
end

---------------------------------
-- commands on the nearest player
---------------------------------
local function onNearest(dist, fn)
    return function()
        local target = LawC.NearestPlayer(dist)
        if not target then return LawC.notify(_L('no_player'), 'error') end
        CreateThread(function() fn(target) end)
    end
end

local C = Config.Commands
if C.Cuff ~= '' then RegisterCommand(C.Cuff, onNearest(Config.Cuff.Distance, LawC.Cuff), false) end
if C.Escort ~= '' then RegisterCommand(C.Escort, onNearest(Config.Escort.Distance, LawC.Escort), false) end
if C.PutIn ~= '' then RegisterCommand(C.PutIn, onNearest(Config.Vehicle.TargetDistance, LawC.PutIn), false) end
if C.TakeOut ~= '' then RegisterCommand(C.TakeOut, onNearest(Config.Vehicle.Distance, LawC.TakeOut), false) end
if C.Search ~= '' then RegisterCommand(C.Search, onNearest(Config.Search.Distance, LawC.Search), false) end
if C.Confiscate ~= '' then RegisterCommand(C.Confiscate, onNearest(Config.Search.Distance, LawC.ConfiscateMenu), false) end
if C.Fine ~= '' then RegisterCommand(C.Fine, onNearest(Config.Fines.Distance, LawC.FineDialog), false) end
if C.LawMenu ~= '' then RegisterCommand(C.LawMenu, function() CreateThread(function() LawC.LawMenu() end) end, false) end

-- /jail with no id (server command) asks here
RegisterNetEvent('MULTIlaw:client:jailNearest', onNearest(Config.Jail.Distance, LawC.JailDialog))

-- using the handcuff item: cuff / uncuff the nearest player
RegisterNetEvent('MULTIlaw:client:useCuffs', onNearest(Config.Cuff.Distance, LawC.Cuff))

---------------------------------
-- MULTItarget on every player (shown to law only). Waits for MULTItarget and
-- adds the option again when MULTItarget restarts (@MULTIcore/lib/interact.lua).
---------------------------------
local playerTargetOn = false
if Config.PlayerTarget then
    MCI.Run('auto', function(mode)
        if mode ~= 'target' then return end
        exports.MULTItarget:addGlobalPlayer({
            {
                name = 'multilaw_menu', label = _L('target_law'), icon = Config.TargetIcons.player, distance = Config.PlayerTargetDistance,
                canInteract = function() return LawC.IsLaw() end,
                onSelect = function(data)
                    local sid = serverIdOf(data.entity)
                    if sid then CreateThread(function() LawC.LawMenu(sid) end) end
                end,
            },
        })
        playerTargetOn = true
        MCI.Count('targets', 1)
    end, function(mode)
        if not playerTargetOn then return end
        playerTargetOn = false
        MCI.Count('targets', -1)
        if MCI.HasTarget() then pcall(function() exports.MULTItarget:removeGlobalPlayer({ 'multilaw_menu' }) end) end
    end)
end

---------------------------------
-- fines: the fined player
---------------------------------
local function payFine(id)
    local res = lib.callback.await('MULTIlaw:fines:pay', false, id)
    LawC.say(type(res) == 'table' and res or { ok = false, msg = _L('failed') })
end

RegisterNetEvent('MULTIlaw:client:fined', function(f)
    if type(f) ~= 'table' then return end
    CreateThread(function()
        local choice = lib.alertDialog({
            header = _L('fine_got_title'),
            content = _L('fine_got_text', ('%.2f'):format(f.amount or 0), tostring(f.reason or ''), tostring(f.officer or '')),
            centered = true, cancel = true,
            labels = { confirm = _L('fine_pay_now'), cancel = _L('fine_pay_later') },
        })
        if choice == 'confirm' then payFine(f.id) else LawC.notify(_L('fine_later_hint', '/' .. Config.Commands.MyFines), 'info') end
    end)
end)

function LawC.MyFines()
    local res = lib.callback.await('MULTIlaw:fines:mine', false)
    if type(res) ~= 'table' or not res.ok then return LawC.say(res) end
    local options = {}
    for _, f in ipairs(res.list or {}) do
        options[#options + 1] = {
            title = _L('fine_row', ('%.2f'):format(f.amount), f.reason),
            description = _L('fine_by', tostring(f.officer or '')),
            onSelect = function() CreateThread(function() payFine(f.id) end) end,
        }
    end
    if #options == 0 then options[1] = { title = _L('no_fines'), disabled = true } end
    lib.registerContext({ id = 'multilaw_myfines', title = _L('my_fines'), options = options })
    lib.showContext('multilaw_myfines')
end
if C.MyFines ~= '' then RegisterCommand(C.MyFines, function() CreateThread(LawC.MyFines) end, false) end

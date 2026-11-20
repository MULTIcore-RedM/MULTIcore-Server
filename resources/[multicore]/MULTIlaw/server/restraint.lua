-- ============================================================
-- MULTIlaw :: handcuffs, escort, wagons and horses, search, evidence
-- The cuffed state is the server's: metadata 'ishandcuffed' (what RSG
-- scripts read) plus Law.cuffed. A client may never uncuff itself.
-- Handcuff behaviour follows rsg-lawman (RSG v2, GPL v3); see CREDITS.md.
-- ============================================================

local getP, fail, okRes, dbg = Law.getP, Law.fail, Law.okRes, Law.dbg

Law.cuffed = {}     -- src -> { by = officer src or 0, hard = bool }
Law.escorts = {}    -- target src -> officer src
Law.inVehicle = {}  -- target src -> true while put in a wagon / on a horse

local function meta(P, key) return P and P.PlayerData.metadata and P.PlayerData.metadata[key] end

function Law.IsCuffed(src)
    local P = getP(src)
    return Law.cuffed[tonumber(src)] ~= nil or meta(P, 'ishandcuffed') == true
end

--- puts the server-side state and tells the player's client. Silent = no notification.
function Law.SetCuffed(target, on, by, silent)
    target = tonumber(target)
    local T = getP(target)
    if not T then return false end
    if on then
        Law.cuffed[target] = { by = by or 0, hard = Config.Cuff.Hard }
    else
        Law.cuffed[target] = nil
        Law.StopEscort(target)
        Law.inVehicle[target] = nil
    end
    T.Functions.SetMetaData('ishandcuffed', on == true)
    pcall(function() Player(target).state:set('multilaw_cuffed', on == true, true) end)
    TriggerClientEvent('MULTIlaw:client:cuffed', target, on == true, Config.Cuff.Hard)
    TriggerEvent('MULTIlaw:server:cuffed', target, on == true, by)
    if not silent then Law.notify(target, _L(on and 'you_cuffed' or 'you_uncuffed'), 'police') end
    return true
end

local function hasCuffItem(src)
    if not Config.Cuff.RequireItem or Config.Cuff.Item == '' then return true end
    if GetResourceState('MULTIinventory') ~= 'started' then return true end
    local inv = exports.MULTIinventory:PlayerInv(src)
    return inv ~= nil and (exports.MULTIinventory:Count(inv, Config.Cuff.Item) or 0) > 0
end

--- officer cuffs target → answer table
function Law.Cuff(officer, target)
    officer, target = tonumber(officer), tonumber(target)
    local P, T = getP(officer), getP(target)
    if not P or not T or officer == target then return fail('no_player') end
    local ok, err = Law.Can(P, 'cuff')
    if not ok then return fail(err) end
    if not Law.playersNear(officer, target, Config.Cuff.Distance) then return fail('too_far') end
    if Law.IsCuffed(target) then return fail('already_cuffed') end
    if Law.IsJailed(Law.cidOf(T)) then return fail('is_jailed') end
    if not hasCuffItem(officer) then return fail('need_cuffs') end
    Law.SetCuffed(target, true, officer)
    dbg(('%s cuffed %s'):format(officer, target))
    return okRes('cuffed', Law.nameOf(T))
end

--- officer (law or admin) takes the cuffs off → answer table
function Law.Uncuff(officer, target)
    officer, target = tonumber(officer), tonumber(target)
    local P, T = getP(officer), getP(target)
    if not P or not T or officer == target then return fail('no_player') end
    local admin = Law.IsAdmin(officer)
    if not admin then
        local ok, err = Law.Can(P, 'cuff')
        if not ok then return fail(err) end
        if not Law.playersNear(officer, target, Config.Cuff.Distance) then return fail('too_far') end
    end
    if not Law.IsCuffed(target) then return fail('not_cuffed') end
    Law.SetCuffed(target, false, officer)
    return okRes('uncuffed', Law.nameOf(T))
end

function Law.ToggleCuff(officer, target)
    if Law.IsCuffed(target) then return Law.Uncuff(officer, target) end
    return Law.Cuff(officer, target)
end

---------------------------------
-- escort
---------------------------------
function Law.StopEscort(target)
    target = tonumber(target)
    if not Law.escorts[target] then return end
    Law.escorts[target] = nil
    TriggerClientEvent('MULTIlaw:client:escort', target, false)
end

--- start or stop leading a cuffed or downed player
function Law.ToggleEscort(officer, target)
    officer, target = tonumber(officer), tonumber(target)
    local P, T = getP(officer), getP(target)
    if not P or not T or officer == target then return fail('no_player') end
    local ok, err = Law.Can(P, 'escort')
    if not ok then return fail(err) end
    if Law.escorts[target] then
        if Law.escorts[target] ~= officer and not Law.IsAdmin(officer) then return fail('escorted_by_other') end
        Law.StopEscort(target)
        return okRes('escort_stopped', Law.nameOf(T))
    end
    if not Law.playersNear(officer, target, Config.Escort.Distance) then return fail('too_far') end
    if not (Law.IsCuffed(target) or meta(T, 'isdead')) then return fail('need_cuffed_or_down') end
    for t, o in pairs(Law.escorts) do if o == officer then Law.StopEscort(t) end end
    Law.escorts[target] = officer
    Law.inVehicle[target] = nil
    TriggerClientEvent('MULTIlaw:client:escort', target, officer)
    return okRes('escort_started', Law.nameOf(T))
end

---------------------------------
-- wagons and horses
---------------------------------
local function entityNear(officer, netId)
    netId = tonumber(netId)
    if not netId then return Law.SELFTEST end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return Law.SELFTEST end
    if not Config.ServerDistanceCheck then return true end
    local p = Law.coordsOf(officer)
    if not p then return Law.SELFTEST end
    return #(p - GetEntityCoords(ent)) <= Config.Vehicle.Distance
end

--- kind = 'vehicle' | 'mount'
function Law.PutIn(officer, target, netId, kind)
    officer, target = tonumber(officer), tonumber(target)
    local P, T = getP(officer), getP(target)
    if not P or not T or officer == target then return fail('no_player') end
    local ok, err = Law.Can(P, 'vehicle')
    if not ok then return fail(err) end
    if kind ~= 'vehicle' and kind ~= 'mount' then return fail('no_vehicle') end
    if not Law.IsCuffed(target) then return fail('need_cuffed') end
    if not Law.playersNear(officer, target, Config.Vehicle.TargetDistance) then return fail('too_far') end
    if not entityNear(officer, netId) then return fail('no_vehicle') end
    Law.StopEscort(target)
    Law.inVehicle[target] = true
    TriggerClientEvent('MULTIlaw:client:putIn', target, tonumber(netId), kind)
    return okRes(kind == 'mount' and 'put_on_horse' or 'put_in_wagon', Law.nameOf(T))
end

function Law.TakeOut(officer, target)
    officer, target = tonumber(officer), tonumber(target)
    local P, T = getP(officer), getP(target)
    if not P or not T or officer == target then return fail('no_player') end
    local ok, err = Law.Can(P, 'vehicle')
    if not ok then return fail(err) end
    if not Law.playersNear(officer, target, Config.Vehicle.Distance) then return fail('too_far') end
    if not Law.IsCuffed(target) then return fail('need_cuffed') end
    Law.inVehicle[target] = nil
    TriggerClientEvent('MULTIlaw:client:takeOut', target, officer)
    return okRes('taken_out', Law.nameOf(T))
end

---------------------------------
-- search and evidence
---------------------------------
--- may the officer go through the target's satchel? → true | false, errKey
function Law.Searchable(officer, target, action)
    local P, T = getP(officer), getP(target)
    if not P or not T or officer == target then return false, 'no_player' end
    local ok, err = Law.Can(P, action or 'search')
    if not ok then return false, err end
    if not Law.playersNear(officer, target, Config.Search.Distance) then return false, 'too_far' end
    local st = Player(target).state
    if Config.Search.AllowCuffed and Law.IsCuffed(target) then return true end
    if Config.Search.AllowDead and meta(T, 'isdead') then return true end
    if Config.Search.AllowHandsUp and st and st.multilaw_handsup == true then return true end
    if Config.Search.AllowRestrained and st and st.multilaw_restrained == true then return true end
    return false, 'not_searchable'
end

function Law.Search(officer, target)
    officer, target = tonumber(officer), tonumber(target)
    local ok, err = Law.Searchable(officer, target, 'search')
    if not ok then return fail(err) end
    if GetResourceState('MULTIinventory') ~= 'started' then return fail('no_inventory') end
    local opened = exports.MULTIinventory:OpenPlayer(officer, target)
    if not opened then return fail('failed') end
    Law.notify(target, _L('being_searched'), 'police')
    return okRes()
end

--- the target's satchel as a short list for the confiscate menu
function Law.ConfiscateList(officer, target)
    officer, target = tonumber(officer), tonumber(target)
    local ok, err = Law.Searchable(officer, target, 'confiscate')
    if not ok then return fail(err) end
    local inv = exports.MULTIinventory:Get(exports.MULTIinventory:PlayerInv(target))
    local list = {}
    for slot, s in pairs(inv and inv.items or {}) do
        local def = exports.MULTIinventory:GetItemDef(s.name) or {}
        list[#list + 1] = { slot = tonumber(slot), name = s.name, label = def.label or s.name, amount = s.amount }
    end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    local res = okRes()
    res.list = list
    res.name = Law.nameOf(getP(target))
    return res
end

--- moves `amount` of the stack in `slot` from the target's satchel into the evidence locker
function Law.Confiscate(officer, target, slot, amount)
    officer, target = tonumber(officer), tonumber(target)
    local ok, err = Law.Searchable(officer, target, 'confiscate')
    if not ok then return fail(err) end
    local P, T = getP(officer), getP(target)
    slot, amount = Law.int(slot), Law.int(amount)
    if not slot or not amount or amount < 1 or amount > Config.Evidence.ConfiscateMax then return fail('bad_amount') end
    local MI = exports.MULTIinventory
    local from = MI:PlayerInv(target)
    local stack = from and MI:GetSlot(from, slot)
    if not stack then return fail('no_item') end
    amount = math.min(amount, tonumber(stack.amount) or 0)
    if amount < 1 then return fail('no_item') end
    local office = Law.EvidenceOffice(P)
    local locker = Law.EvidenceId(office)
    local can, why = MI:CanAdd(locker, stack.name, amount, stack.info)
    if not can then return fail('locker_full', tostring(why)) end
    local removed, rerr, info = MI:RemoveItem(from, stack.name, amount, slot, nil, 'multilaw-confiscate')
    if not removed then return fail('failed', tostring(rerr)) end
    local added, aerr = MI:AddItem(locker, stack.name, amount, info or stack.info, nil, 'multilaw-evidence')
    if not added then
        MI:AddItem(from, stack.name, amount, info or stack.info, nil, 'multilaw-confiscate-undo')
        return fail('locker_full', tostring(aerr))
    end
    local def = MI:GetItemDef(stack.name) or {}
    Law.AddRecord(Law.cidOf(T), Law.nameOf(T), 'confiscate', { detail = ('%dx %s'):format(amount, def.label or stack.name), officer = Law.nameOf(P) })
    Law.notify(target, _L('item_confiscated', amount, def.label or stack.name), 'police')
    return okRes('confiscated', amount, def.label or stack.name, _L(office.label))
end

--- opens an office's evidence locker for a lawman standing there
function Law.OpenEvidence(src)
    src = tonumber(src)
    local P = getP(src)
    local ok, err = Law.Can(P, 'evidence')
    if not ok then return fail(err) end
    local office = Law.OfficeAt(src, P)
    if not office then return fail('not_at_office') end
    if GetResourceState('MULTIinventory') ~= 'started' then return fail('no_inventory') end
    local opened = exports.MULTIinventory:Open(src, Law.EvidenceId(office), {
        label = _L('evidence_label', _L(office.label)), slots = Config.Evidence.Slots, maxWeight = Config.Evidence.MaxWeight, coords = office.coords,
    })
    if not opened then return fail('failed') end
    return okRes()
end

---------------------------------
-- login, logout
---------------------------------
AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
    local src = Law.srcOf(P)
    if not src then return end
    Law.cuffed[src], Law.escorts[src], Law.inVehicle[src] = nil, nil, nil
    if meta(P, 'ishandcuffed') then
        if Config.Cuff.KeepOnRelog then
            SetTimeout(3000, function() if getP(src) then Law.SetCuffed(src, true, 0, true) end end)
        else
            P.Functions.SetMetaData('ishandcuffed', false)
        end
    end
end)

local function forget(src)
    src = tonumber(src)
    Law.cuffed[src], Law.inVehicle[src] = nil, nil
    Law.escorts[src] = nil
    for t, o in pairs(Law.escorts) do
        if o == src then Law.StopEscort(t) end
    end
end
AddEventHandler('RSGCore:Server:OnPlayerUnload', forget)
AddEventHandler('playerDropped', function() forget(source) end)

---------------------------------
-- handcuff item
---------------------------------
Law.OnReady(function()
    if not Config.Cuff.UseItem or Config.Cuff.Item == '' or GetResourceState('MULTIinventory') ~= 'started' then return end
    exports.MULTIinventory:RegisterUsable(Config.Cuff.Item, function(src)
        TriggerClientEvent('MULTIlaw:client:useCuffs', src)
    end)
end)

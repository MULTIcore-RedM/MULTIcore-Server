-- ============================================================
-- MULTIdoors :: rsg-doorlock (RSG v2) compatibility, server
-- fxmanifest says provide 'rsg-doorlock'. rsg-doorlock has no exports;
-- it is driven by two server events that name a door by its number in
-- rsg-doorlock's Config.DoorList. Rules carry those numbers in `rsg`
-- (the default law-office rules use the numbers of rsg-doorlock's stock
-- list; config/rsg_doorlist.lua entries become 'rsg_<number>').
--   rsg-doorlock:updatedoorsv (doorID, state)  -> checks the key, sends
--       rsg-doorlock:changedoor (doorID, state) to that player, whose
--       client plays the key animation and fires updateState
--   rsg-doorlock:updateState (doorID, state)   -> checks again, sets the
--       state; every client gets rsg-doorlock:setState (doorID, state)
-- Event names and argument shapes follow rsg-doorlock 1.0.3 (GPL v3).
-- ============================================================

local SELFTEST = GetConvar('multicore_selftest', 'false') == 'true'

local function ruleFor(doorID)
    doorID = tonumber(doorID)
    return doorID and MD.ByRsg[doorID] or nil
end

local function updatedoorsv(src, doorID, state)
    local id = ruleFor(doorID)
    if not id then return false, 'no_rule' end
    local ok, err = MD.Check(src, id)
    if not ok then
        MD.Notify(src, _L('no_key'), 'error')
        return false, err
    end
    TriggerClientEvent('rsg-doorlock:changedoor', src, doorID, state and true or false)
    return true
end

local function updateState(src, doorID, state)
    if type(doorID) ~= 'number' then return false, 'no_rule' end
    local id = ruleFor(doorID)
    if not id then return false, 'no_rule' end
    local res = MD.Use(src, id, state and true or false)
    return res.ok, res.err
end

RegisterNetEvent('rsg-doorlock:updatedoorsv', function(doorID, state)
    updatedoorsv(source, doorID, state)
end)

RegisterNetEvent('rsg-doorlock:updateState', function(doorID, state)
    updateState(source, doorID, state)
end)

-- self-test only: runs the two handlers with a pretend player as source
if SELFTEST then
    exports('_TestRsgEvent', function(name, src, doorID, state)
        if name == 'rsg-doorlock:updatedoorsv' then return updatedoorsv(src, doorID, state) end
        if name == 'rsg-doorlock:updateState' then return updateState(src, doorID, state) end
        return false, 'unknown_event'
    end)
end

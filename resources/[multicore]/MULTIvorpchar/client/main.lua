-- ============================================================
-- MULTIvorpchar :: client
-- vorp_character's client exports and events, answered from the MULTIcore
-- look library (exports.MULTIcore:GetLook / ReloadLook, callback
-- MULTIcore:look:save). Names and argument shapes are learnt from how VORP
-- scripts call vorp_character and from VORP's public docs; no VORP code is used.
--
--   exports.vorp_character:GetPlayerComponent(key)   -> { comp, palette?, tint0..2 } or nil
--   exports.vorp_character:GetAllPlayerComponents() -> { [key] = { comp, ... } }
--   TriggerEvent('vorpcharacter:updateCache', nil, { [key] = { comp = hash | -1, palette, tint0.. } })
--       merges clothes into the saved look (seen after a reload, as on VORP)
--   TriggerEvent('vorpcharacter:savenew', nil, { Hair = hash | -1, Beard = hash | -1 })
--       changes hair / beard of the saved look; other skin keys are ignored
--   Fired: server event vorpcharacter:reloadedskinlistener after every look load,
--          local event vorpcharacter:reloadafterdeath after the look is back on after a respawn / revive
-- ============================================================

local dbg = VC.Debug

local function ExportAs(name, fn)
    exports(name, fn)
    AddEventHandler(('__cfx_export_vorp_character_%s'):format(name), function(setCB) setCB(fn) end)
end

local function look()
    local l = exports.MULTIcore:GetLook()
    if type(l) ~= 'table' then return { skin = {}, comps = {} } end
    return { skin = type(l.skin) == 'table' and l.skin or {}, comps = type(l.comps) == 'table' and l.comps or {} }
end

local function sexNow()
    local s = look().skin.sex
    if s == 'male' or s == 'female' then return s end
    return IsPedMale(PlayerPedId()) and 'male' or 'female'
end

-- ---------------------------------------------------------------
-- reading what is worn
-- ---------------------------------------------------------------

ExportAs('GetAllPlayerComponents', function()
    return VC.ToVorp(look().comps, sexNow())
end)

ExportAs('GetPlayerComponent', function(key)
    local cat = VC.CategoryOf(key)
    if not cat then return nil end
    return VC.ToVorpEntry(look().comps[cat], sexNow(), cat)
end)

-- ---------------------------------------------------------------
-- saving changes (one at a time, in order)
-- ---------------------------------------------------------------

local saving = 0
local pending = {}  -- last comps / skin sent while a save is still on its way (the cached look is older)

local function save(part, value)
    saving = saving + 1
    local ok, res = pcall(function() return lib.callback.await('MULTIcore:look:save', false, part, value) end)
    saving = saving - 1
    if not ok or not res then dbg('save failed', part, ok and 'refused' or res) end
    return ok and res
end

local function waitSaves()
    local untilTime = GetGameTimer() + (Config.SaveWaitMs or 3000)
    while saving > 0 and GetGameTimer() < untilTime do Wait(20) end
end

AddEventHandler('vorpcharacter:updateCache', function(_, comps)
    if type(comps) ~= 'table' then return end
    local base = (saving > 0 and pending.comps) or look().comps
    local merged, skipped = VC.MergeVorp(base, comps, sexNow())
    if #skipped > 0 then dbg('updateCache: no MULTIcore piece for', table.concat(skipped, ', ')) end
    pending.comps = merged
    save('comps', merged)
end)

AddEventHandler('vorpcharacter:savenew', function(_, data)
    if type(data) ~= 'table' then return end
    local base = (saving > 0 and pending.skin) or look().skin
    if not base.sex then return end
    local skin, skipped = VC.MergeSkin(base, data, sexNow())
    if #skipped > 0 then dbg('savenew: ignored', table.concat(skipped, ', ')) end
    if #skipped < VC.CountKeys(data) then
        pending.skin = skin
        save('skin', skin)
    end
end)

function VC.CountKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------
-- reloading and the events vorp_character fires
-- ---------------------------------------------------------------

if type(Config.ReloadCommand) == 'string' and Config.ReloadCommand ~= '' then
    RegisterCommand(Config.ReloadCommand, function()
        if not LocalPlayer.state.isLoggedIn then return end
        waitSaves()
        exports.MULTIcore:ReloadLook()
    end, false)
end

-- MULTIcore put the saved look back on (reload, first spawn, respawn, revive)
AddEventHandler('MULTIcore:client:lookApplied', function(reason)
    TriggerServerEvent('vorpcharacter:reloadedskinlistener')
    if reason == 'respawn' or reason == 'revive' then TriggerEvent('vorpcharacter:reloadafterdeath') end
    dbg('look applied', reason)
end)

-- server export OpenOutfitsMenu(source) -> MULTIclothing's outfit list
RegisterNetEvent('MULTIvorpchar:client:openOutfits', function()
    if GetResourceState('MULTIclothing') ~= 'started' then return end
    TriggerEvent('MULTIclothing:client:wardrobePoint')
end)

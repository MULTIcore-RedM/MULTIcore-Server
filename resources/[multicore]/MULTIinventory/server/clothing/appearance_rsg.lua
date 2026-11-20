-- ============================================================
-- MULTIinventory :: server/clothing/appearance_rsg.lua
--
-- RSG half of
-- source of truth; after every change the worn pieces are written into the RSG appearance
-- record so the appearance resource (rsg-character / rsg-appearance / RINGOmulticharacterV2)
-- re-applies the same look on spawn and /loadskin.
--
--   AppearanceRsg.resource() -> 'rsg-character' | 'rsg-appearance' | ...
--   AppearanceRsg.build(equipContainer) -> clothes, removed
--       clothes = { [game category] = { hash, palette?, tint0?, tint1?, tint2?,
--                   drawable?, albedo?, normal?, material? } }  (rsg clothes cache shape)
--       removed = { game category, ... }  categories RINGO manages that are now empty
--   AppearanceRsg.mirror(charId) -> ok, wroteDb
--   AppearanceRsg.schedule(charId)            debounced mirror (Config.Rsg.appearance.debounceMs)
--
-- Storage: only the 35 categories in shared/clothing_categories.lua are touched in
-- playerskins.clothes (hair, beards, body etc. stay with the appearance resource).
-- Live ped: TriggerClientEvent(Config.Rsg.appearance.clientEvent, src, clothes, removed, res).
-- The client handler
-- applies the pieces and forwards to '<res>:client:ApplyClothes' like RINGOwardrobe does.
-- Server-local event after each mirror: MULTIinventory:rsg:clothesMirrored (charId, clothes, removed)
-- ============================================================

AppearanceRsg = AppearanceRsg or {}

local DEF = { resource = 'auto', writeDb = true, clientEvent = 'MULTIinventory:rsg:applyClothes',
              debounceMs = 500, reconcileOnlyWhenWearing = true }

local function A(k)
    local a = Config and Config.Rsg and Config.Rsg.appearance
    if a and a[k] ~= nil then return a[k] end
    return DEF[k]
end

local function enabled()
    return MBridge ~= nil and MBridge.IsRsg == true
        and Config.Clothing ~= nil and Config.Clothing.enabled ~= false
        and Config.Clothing.mirrorToFramework ~= false
end
AppearanceRsg.enabled = enabled

function AppearanceRsg.resource()
    local want = A('resource')
    if want and want ~= 'auto' then return want end
    for _, r in ipairs({ 'rsg-character', 'rsg-appearance', 'RINGOmulticharacterV2' }) do
        if GetResourceState(r) == 'started' then return r end
    end
    return 'rsg-appearance'
end

local TINTS = { 'tint0', 'tint1', 'tint2' }
local ROUTE_B = { 'drawable', 'albedo', 'normal', 'material' }

function AppearanceRsg.build(c)
    local clothes, removed = {}, {}
    for _, cat in ipairs(ClothingCategories or {}) do
        local e = c and c.stacks[cat.order]
        local m = e and e.kind ~= 'weapon' and e.item == cat.item and e.metadata or nil
        local comp = m and tonumber(m.comp)
        if m and (comp or tonumber(m.drawable)) then
            local v = { hash = comp or 0 }
            if tonumber(m.palette) then v.palette = tonumber(m.palette) end
            for _, k in ipairs(TINTS) do if tonumber(m[k]) then v[k] = tonumber(m[k]) end end
            if not comp then for _, k in ipairs(ROUTE_B) do v[k] = tonumber(m[k]) end end
            clothes[cat.game] = v
        else
            removed[#removed + 1] = cat.game
        end
    end
    return clothes, removed
end

local function writeDb(citizenid, clothes, removed)
    local rows = InvDB.query('SELECT `clothes` FROM `playerskins` WHERE `citizenid` = ? LIMIT 1', { citizenid })
    if not rows[1] then return false end   -- no appearance yet (creator not finished): nothing to mirror into
    local saved = Util.jsonDecode(rows[1].clothes, {})
    if type(saved) ~= 'table' then saved = {} end
    for _, game in ipairs(removed) do saved[game] = nil end
    for game, v in pairs(clothes) do saved[game] = v end
    local n = InvDB.update('UPDATE `playerskins` SET `clothes` = ? WHERE `citizenid` = ?', { json.encode(saved), citizenid })
    return (tonumber(n) or 0) > 0
end

function AppearanceRsg.mirror(charId)
    if not enabled() then return false, 'disabled' end
    charId = tonumber(charId)
    local c = charId and Containers.peek('equip:' .. charId)
    if not c then return false, 'not_loaded' end
    local clothes, removed = AppearanceRsg.build(c)
    local res = AppearanceRsg.resource()
    local wrote = false
    if A('writeDb') and MBridge.CitizenOf then
        local ok, citizenid = pcall(MBridge.CitizenOf, charId)
        if ok and citizenid then wrote = writeDb(citizenid, clothes, removed) end
    end
    local src = State.srcOfChar(charId)
    local ev = A('clientEvent')
    if src and ev and ev ~= '' then TriggerClientEvent(ev, src, clothes, removed, res) end
    TriggerEvent('MULTIinventory:rsg:clothesMirrored', charId, clothes, removed)
    return true, wrote
end

local pending = {}
function AppearanceRsg.schedule(charId)
    charId = tonumber(charId)
    if not charId or pending[charId] then return end
    pending[charId] = true
    SetTimeout(math.max(0, tonumber(A('debounceMs')) or 0), function()
        pending[charId] = nil
        local ok, err = pcall(AppearanceRsg.mirror, charId)
        if not ok then print(('^1[MULTIinventory] rsg clothes mirror %s: %s^7'):format(charId, tostring(err))) end
    end)
end

InvHooks.register('containerChanged', function(c)
    if c.kind == 'equip' and c.ownerCharId and enabled() then AppearanceRsg.schedule(c.ownerCharId) end
end)

-- reconcile on load: the equipment container wins - but never strip an existing RSG outfit
-- of a character whose worn clothes were not migrated into items yet.
InvHooks.register('characterLoaded', function(_, charId)
    if not enabled() then return end
    local c = Containers.peek('equip:' .. tostring(charId))
    if A('reconcileOnlyWhenWearing') and (not c or next(c.stacks) == nil) then return end
    SetTimeout(tonumber(Config.Clothing.reapplyDelayMs) or 1500, function() AppearanceRsg.schedule(charId) end)
end)

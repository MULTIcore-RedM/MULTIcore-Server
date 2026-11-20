-- ============================================================
-- MULTIcore :: appearance storage
-- VORP and RSG creators save looks in different formats. MULTIcore keeps
-- whatever the creator wrote, tagged with its format ('vorp' or 'rsg'),
-- and hands it back unchanged.
-- ============================================================

MULTI.Appearance = { cache = {} }
local A = MULTI.Appearance

local COLS = { skin = 'skin', comps = 'comps', tints = 'comp_tints' }

local function key(citizenid, format) return citizenid .. '|' .. format end

--- Returns { skin, comps, tints } (JSON strings) for a character and format.
function A.Get(citizenid, format)
    if not citizenid then return {} end
    local k = key(citizenid, format)
    if A.cache[k] then return A.cache[k] end
    local row = MySQL.single.await('SELECT skin, comps, comp_tints FROM multicore_appearance WHERE citizenid = ? AND format = ?',
        { citizenid, format }) or {}
    local entry = { skin = row.skin, comps = row.comps, tints = row.comp_tints }
    A.cache[k] = entry
    return entry
end

--- Reads every format of a character's appearance into the cache in one query.
--- Called while the character logs in, before RSGCore:Server:PlayerLoaded fires, so the
--- VORP face can build vorp:SelectedCharacter's character table without waiting on the
--- database (the event then fires at once, inside PlayerLoaded, as VORP scripts expect).
function A.Preload(citizenid)
    if not citizenid then return end
    local rows = MySQL.query.await('SELECT format, skin, comps, comp_tints FROM multicore_appearance WHERE citizenid = ?',
        { citizenid }) or {}
    local found = {}
    for _, row in ipairs(rows) do
        found[row.format] = { skin = row.skin, comps = row.comps, tints = row.comp_tints }
    end
    for _, f in ipairs({ 'multi', 'vorp', 'rsg' }) do
        local k = key(citizenid, f)
        if not A.cache[k] then A.cache[k] = found[f] or {} end
    end
end

--- Stores one part ('skin' | 'comps' | 'tints') of a character's appearance.
function A.Set(citizenid, format, part, value)
    local col = COLS[part]
    if not citizenid or not col then return false end
    if type(value) == 'table' then value = json.encode(value) end
    local entry = A.Get(citizenid, format)
    entry[part] = value
    MySQL.insert.await(('INSERT INTO multicore_appearance (citizenid, format, %s) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE %s = VALUES(%s)')
        :format(col, col, col), { citizenid, format, value })
    return true
end

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    local P = RSGCore.Players[src]
    if not P then return end
    for _, f in ipairs({ 'multi', 'vorp', 'rsg' }) do A.cache[key(P.PlayerData.citizenid, f)] = nil end
end)

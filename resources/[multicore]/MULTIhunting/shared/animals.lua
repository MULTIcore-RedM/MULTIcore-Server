-- ============================================================
-- MULTIhunting :: animal lookup (client and server)
-- Config.Animals is keyed by model name; this builds the hash index once.
-- Hashes are kept unsigned (0 .. 2^32-1) so a signed model hash from the game
-- and an unsigned one from joaat() find the same animal.
-- ============================================================

MH = MH or {}

function MH.Hash(model)
    if type(model) == 'string' then model = joaat(model) end
    model = math.tointeger(tonumber(model))
    if not model then return nil end
    return model & 0xFFFFFFFF
end

MH.ByHash = {}
for name, def in pairs(Config.Animals or {}) do
    def.model = name
    MH.ByHash[MH.Hash(name)] = def
end

--- The animal definition for a model name or hash, or nil.
function MH.Animal(model)
    local h = MH.Hash(model)
    return h and MH.ByHash[h] or nil
end

-- ============================================================
-- MULTItarget :: server
-- Item counts for options that need items (asked once when the player starts targeting).
-- The script that owns an option still checks again on its own server.
-- ============================================================

lib.callback.register('MULTItarget:counts', function(src, names)
    local out = {}
    if type(names) ~= 'table' or GetResourceState('MULTIinventory') ~= 'started' then return out end
    local MI = exports.MULTIinventory
    local ok, inv = pcall(function() return MI:PlayerInv(src) end)
    if not ok or not inv then return out end
    for i, name in ipairs(names) do
        if i > 300 then break end
        if type(name) == 'string' and #name < 64 then
            local good, n = pcall(function() return MI:Count(inv, name) end)
            if good and tonumber(n) and tonumber(n) > 0 then out[name] = tonumber(n) end
        end
    end
    return out
end)

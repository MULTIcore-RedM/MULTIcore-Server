-- ============================================================
-- MULTIfarming :: admin command
--   /farmclear [radius] [dead|all]
-- Clears withered crops (default) or every crop within the radius around the admin
-- (default Config.Admin.ClearRadius). From the server console it works on the whole map.
-- Allowed: MULTIcore permission levels Config.Admin.Groups, or the ace Config.Admin.Ace.
-- ============================================================

local function reply(src, text, kind)
    if src == 0 then print(('[MULTIfarming] %s'):format(text)) else FM.Notify(src, text, kind) end
end

RegisterCommand('farmclear', function(source, args)
    local src = tonumber(source) or 0
    if not FM.IsAdmin(src) then return reply(src, _L('no_permission'), 'error') end
    if not FM.ready then return end
    local radius = tonumber(args[1]) or Config.Admin.ClearRadius
    local all = tostring(args[2] or args[1] or ''):lower() == 'all'
    local pos = src ~= 0 and FM.PlayerCoords(src) or nil
    if src ~= 0 and not pos then return reply(src, _L('too_far'), 'error') end

    local gone, now = {}, FM.Time()
    for id, p in pairs(FM.Plants) do
        FM.Advance(p, now)
        local inRange = not pos or (FM.Dist2(pos, p) <= radius * radius)
        if inRange and (all or p.deadAt) then
            FM.Plants[id] = nil
            gone[#gone + 1] = id
        end
    end
    if #gone > 0 then
        MySQL.query(('DELETE FROM `multi_farming_plants` WHERE `id` IN (%s)'):format(('?,'):rep(#gone):sub(1, -2)), gone)
        TriggerClientEvent('MULTIfarming:client:remove', -1, gone)
    end
    print(('[MULTIfarming] /farmclear by %s: %d crops cleared (%s)'):format(src, #gone, all and 'all' or 'dead'))
    if src ~= 0 then reply(src, _L('farmclear_done', #gone), 'success') end
end, false)

-- ============================================================
-- MULTIemotes :: client exports and the rsg-animations face
-- rsg-animations 2.0.2 (RSG v2, GPL v3) has one client export,
-- PlayAnimation(name, body), and the client event
-- rsg-animations:client:Open. Exports don't follow `provide`, so
-- they are registered under 'rsg-animations' by hand.
-- GPL v3.
-- ============================================================

local function exportAs(resourceName, exportName, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resourceName, exportName), function(setCB) setCB(fn) end)
end

--- rsg-animations: PlayAnimation(name, body) -> true | false, message.
--- `name` is an emote id or label (any shipped language); `body` 'full' (default) | 'upper' | { body = ... }.
local function playAnimation(name, body)
    if type(body) == 'table' then body = body.body end
    body = (type(body) == 'string' and body:lower() == 'upper') and 'upper' or 'full'
    local e = MEM.FindEmote(name)
    if not e then return false, ('Animation "%s" was not found'):format(tostring(name)) end
    local ok, why = MEM.Play(e, body)
    if not ok then return false, _L(why) end
    return true
end
exportAs('rsg-animations', 'PlayAnimation', playAnimation)

-- rsg-animations opens its menu with this event (from its server after loading favourites)
RegisterNetEvent('rsg-animations:client:Open', function() MEM.OpenMenu() end)

-- rsg-animations:server:Favorite, passed on by our server: label -> favourite on / off
RegisterNetEvent('MULTIemotes:client:favourite', function(label, on)
    local e = MEM.FindEmote(label)
    if e then MEM.SetFavourite(e.id, on == true) end
end)

-- MULTIemotes' own client exports
exports('PlayAnimation', playAnimation)
exports('PlayEmote', function(id, body) -- id or label; returns true | false, locale key
    local e = MEM.FindEmote(id)
    if not e then return false, 'err_unknown' end
    return MEM.Play(e, body)
end)
exports('StopEmote', function() MEM.Stop() return true end)
exports('IsPlaying', function() return MEM.IsPlaying() end)
exports('OpenMenu', function(tab) MEM.OpenMenu(tab) end)
exports('CloseMenu', function() MEM.CloseMenu() end)
exports('GetWalkstyle', function() return MEM.CurrentWalk() end)
exports('SetWalkstyle', function(id) return MEM.SetWalk(id) end) -- nil / false = reset
exports('GetFavourites', function() return MEM.GetFavourites() end)

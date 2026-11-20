-- ============================================================
-- MULTIemotes :: rsg-animations face (server)
-- rsg-animations 2.0.2 opens its menu through the server event
-- rsg-animations:server:Open (it loads favourites from SQL first) and
-- saves favourites with rsg-animations:server:Favorite. MULTIemotes
-- keeps favourites on the player's PC (KVP), so Open just opens the
-- menu and Favorite is passed to that player's client.
-- GPL v3.
-- ============================================================

RegisterNetEvent('rsg-animations:server:Open', function()
    TriggerClientEvent('rsg-animations:client:Open', source, {})
end)

RegisterNetEvent('rsg-animations:server:Favorite', function(animation, favorite)
    local label = type(animation) == 'table' and animation.Label or animation
    if type(label) ~= 'string' or #label > 64 then return end
    TriggerClientEvent('MULTIemotes:client:favourite', source, label, favorite == true)
end)

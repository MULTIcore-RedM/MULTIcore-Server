-- ============================================================
-- MULTIinventory :: vorp_inventory face - state bags and block (server)
-- VORP scripts read Player(src).state.IsInvActive and
-- Player(src).state['GetEquippedWeaponData_<weaponHash>'] on the server.
-- The client face reports both (client/vorp/main.lua); the server
-- checks the reports against the satchel before it sets them.
-- ============================================================

local V = MULTIVorp

local lastState = {}

RegisterNetEvent('MULTIinventory:vorp:invState', function(open)
    local src = source
    open = open == true
    if lastState[src] == open then return end
    lastState[src] = open
    Player(src).state:set('IsInvActive', open, true)
end)

-- the weapon a player has in hand: only a weapon the player owns is accepted
RegisterNetEvent('MULTIinventory:vorp:equipped', function(weaponId, hash)
    local src = source
    weaponId, hash = tonumber(weaponId), math.tointeger(tonumber(hash))
    if not weaponId or not hash then return end
    local invId = V.InvOf(src)
    local fi, _, st = V.Weapons.Find(weaponId, nil, invId)
    if not fi or fi ~= invId then return end
    if joaat then
        local h = math.tointeger(joaat(st.name))
        if h and (h & 0xFFFFFFFF) ~= (hash & 0xFFFFFFFF) then return end
    end
    local info = st.info or {}
    Player(src).state:set(('GetEquippedWeaponData_%d'):format(hash), {
        weaponId = weaponId,
        serialNumber = info.serie,
    }, true)
end)

AddEventHandler('playerDropped', function()
    lastState[source] = nil
end)

-- vorp_inventory:blockInventory from a server script (TriggerEvent with a player id)
AddEventHandler('vorp_inventory:blockInventory', function(src, state)
    if type(src) == 'boolean' then return end -- client form, not for the server
    src = V.Src(src)
    if src then TriggerClientEvent('vorp_inventory:blockInventory', src, state and true or false) end
end)

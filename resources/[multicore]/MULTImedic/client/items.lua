-- ============================================================
-- MULTImedic :: bandaging yourself (client)
-- The server asked for it after a satchel use; it takes the item and adds
-- health only once the bandaging finished. Animation as rsg-medic (RSG v2, GPL v3).
-- ============================================================

local busy = false

RegisterNetEvent('MULTImedic:client:selfCare', function(name, time)
    if GetInvokingResource() then return end   -- only the server starts this
    if busy then return TriggerServerEvent('MULTImedic:server:selfCareDone', false) end
    local ped = PlayerPedId()
    if MedicC.IsDead() or (not Config.SelfCare.AllowOnMount and (IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false))) then
        exports.MULTIcore:Notify({ text = _L('cannot_now'), type = 'error' })
        return TriggerServerEvent('MULTImedic:server:selfCareDone', false)
    end
    busy = true
    LocalPlayer.state:set('inv_busy', true, true)
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
    local a = Config.SelfCare.Anim
    local done = lib.progressBar({
        duration = tonumber(time) or 6000,
        label = _L('bandaging'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = a and a.dict and { dict = a.dict, clip = a.clip, flag = a.flag } or nil,
    })
    ClearPedTasks(PlayerPedId())
    LocalPlayer.state:set('inv_busy', false, true)
    busy = false
    TriggerServerEvent('MULTImedic:server:selfCareDone', done == true)
end)

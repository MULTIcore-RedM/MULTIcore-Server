-- ============================================================
-- MULTIhunting :: client
-- Watches the game's loot-complete event (the same way rsg-hunting does, RSG v2,
-- GPL v3, see CREDITS.md): when the local player finishes skinning or picking up
-- a configured animal, the model, the game's quality and kill cleanliness and the
-- carcass network id go to the server, which decides the reward.
-- ============================================================

local NATIVE_GET_PED_QUALITY = 0x7BCC6087D130312A            -- _GET_PED_QUALITY (femga natives.json)
local NATIVE_GET_PED_DAMAGE_CLEANLINESS = 0x88EFFED5FE8B0B4A -- _GET_PED_DAMAGE_CLEANLINESS
local NATIVE_GET_FIRST_ENTITY_CARRIED = 0xD806CD2A4F2C2996   -- _GET_FIRST_ENTITY_PED_IS_CARRYING
local NATIVE_GET_IS_CARRIABLE_PELT = 0x255B6DB4E3AD3C3E      -- _GET_IS_CARRIABLE_PELT
local NATIVE_GET_CARCASS_FROM_PELT = 0x2A77EF9BEC8518F4      -- _GET_CARCASS_FROM_PELT

-- the event data comes back as a 1-based list of 32-bit numbers (8 bytes per field):
-- [1] the ped who looted, [3] the looted entity, [5] 1 when the loot action finished
local IDX_PED, IDX_TARGET, IDX_DONE = 1, 3, 5
local EVENT_STRUCT_SIZE = 3

local lastAt = 0

local function standingDown()
    for _, name in ipairs(Config.StandDownFor or {}) do
        if GetResourceState(name) == 'started' then return true end
    end
    return false
end

local function removeEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    SetEntityAsMissionEntity(ent, true, true)
    if IsEntityAPed(ent) then DeletePed(ent) else DeleteEntity(ent) end
end

-- removes what the game put in the player's hands for this carcass: the pelt, or the small animal itself
local function removeCarried(carcass)
    local ped = PlayerPedId()
    local held = Citizen.InvokeNative(NATIVE_GET_FIRST_ENTITY_CARRIED, ped, Citizen.ResultAsInteger())
    if not held or held == 0 or not DoesEntityExist(held) then return end
    local mine = held == carcass
    if not mine and Citizen.InvokeNative(NATIVE_GET_IS_CARRIABLE_PELT, held) then
        local src = Citizen.InvokeNative(NATIVE_GET_CARCASS_FROM_PELT, held, Citizen.ResultAsInteger())
        mine = (src == carcass) or (src == 0) -- the pelt from this skinning (0 = the game no longer knows)
    end
    if mine then removeEntity(held) end
end

local function onSkinned(carcass)
    local model = GetEntityModel(carcass)
    local def = MH.Animal(model)
    if not def then return end
    local quality = Citizen.InvokeNative(NATIVE_GET_PED_QUALITY, carcass, Citizen.ResultAsInteger())
    local cleanliness = Citizen.InvokeNative(NATIVE_GET_PED_DAMAGE_CLEANLINESS, carcass, Citizen.ResultAsInteger())
    local netId = 0
    if NetworkGetEntityIsNetworked(carcass) then netId = NetworkGetNetworkIdFromEntity(carcass) end

    CreateThread(function()
        Wait(Config.RewardDelayMs)
        local ok = lib.callback.await('MULTIhunting:skinned', false, model, quality, cleanliness, netId)
        if not ok then return end
        if Config.RemoveCarriedPelt then removeCarried(carcass) end
        if Config.DeleteCarcass and not def.whole then
            Wait(Config.DeleteCarcassDelayMs)
            removeEntity(carcass)
        end
    end)
end

CreateThread(function()
    while true do
        Wait(Config.EventPollMs)
        local n = GetNumberOfEvents(0)
        for i = 0, n - 1 do
            if GetEventAtIndex(0, i) == Config.LootEvent and LocalPlayer.state.isLoggedIn and not standingDown() then
                local view = exports.MULTIhunting:GetEventData(0, i, EVENT_STRUCT_SIZE)
                if type(view) == 'table' and view[IDX_PED] == PlayerPedId() and view[IDX_DONE] == 1 then
                    local now = GetGameTimer()
                    if now - lastAt >= Config.ClientThrottleMs then
                        local carcass = view[IDX_TARGET]
                        if carcass and carcass ~= 0 and DoesEntityExist(carcass) then
                            lastAt = now
                            onSkinned(carcass)
                        end
                    end
                end
            end
        end
    end
end)

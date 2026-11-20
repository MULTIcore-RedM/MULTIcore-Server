-- ============================================================
-- MULTIhorses :: rsg-horses client compatibility
-- Names follow rsg-horses 2.3.3 (RSG v2 framework, GPL v3). Callers found:
--   rsg-appearance           TriggerEvent('rsg-horses:client:FleeHorse')
--   rsg-radialmenu           'rsg-horses:client:equipHorseLantern'
--   RINGOitemplacer          exports['rsg-horses']:CheckActiveHorse()
-- ============================================================

-- the horse is taken away at once (rsg-horses: DespawnHorse)
RegisterNetEvent('rsg-horses:client:FleeHorse', function()
    MHClient.despawn(true)
end)

-- hang / take off the saddle lantern (needs the lantern item; checked by the server)
RegisterNetEvent('rsg-horses:client:equipHorseLantern', function()
    MHClient.act('lantern')
end)

-- open the saddlebags of the horse beside the player
RegisterNetEvent('rsg-horses:client:inventoryHorse', function()
    MHClient.act('saddlebag')
end)

-- call the active horse
RegisterNetEvent('rsg-horses:client:SpawnHorse', function()
    MHClient.Whistle()
end)

-- /findhorse
RegisterNetEvent('rsg-horses:client:gethorselocation', function()
    ExecuteCommand(Config.Commands.FindHorse ~= '' and Config.Commands.FindHorse or 'findhorse')
end)

-- bonding level 1-4 from the horse's bonding attribute (7), as rsg-horses works it out
local function bonding()
    local ped = MHClient.GetHorse()
    if ped == 0 then return 0 end
    local max = GetMaxAttributePoints(ped, 7)
    local cur = GetAttributePoints(ped, 7)
    if not max or max <= 0 then return 1 end
    if cur >= max then return 4 elseif cur >= max * 2 / 3 then return 3 elseif cur >= max / 3 then return 2 end
    return 1
end

local function level() return MHClient.GetHorse() ~= 0 and 1 or 0 end -- no horse levels in the basic stable

-- exports['rsg-horses']:CheckActiveHorse() / CheckHorseLevel() / CheckHorseBondingLevel()
local function exportAs(name, fn)
    AddEventHandler(('__cfx_export_rsg-horses_%s'):format(name), function(setCB) setCB(fn) end)
end
exportAs('CheckActiveHorse', function() return MHClient.GetHorse() end)
exportAs('CheckHorseLevel', level)
exportAs('CheckHorseBondingLevel', bonding)
exports('CheckActiveHorse', function() return MHClient.GetHorse() end)
exports('CheckHorseLevel', level)
exports('CheckHorseBondingLevel', bonding)

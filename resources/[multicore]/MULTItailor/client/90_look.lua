--[[
    Worn clothing items on top of MULTIcore's look (client).

    * MULTIcore:client:lookApplied (MULTIcore put the saved look back on: reload, respawn, revive)
      -> after Config.Look.reapplyDelayMs MULTIinventory puts the worn items on again (tints, pieces the
         look could not hold), and the toggled-off pieces stay off (client/95_wardrobe.lua).
    * A piece taken off its equipment slot is taken off with MULTIcore's RemoveComp, which puts the
      body underneath back (no missing torso or legs).
]]
local INV = 'MULTIinventory'
local prevWorn, removed = {}, {}

local function invUp() return GetResourceState(INV) == 'started' end

TLookC = TLookC or {}

function TLookC.reapply(delay)
    if not invUp() then return end
    SetTimeout(math.max(0, delay or tonumber((Config.Look or {}).reapplyDelayMs) or 600), function()
        pcall(function() exports[INV]:ReapplyClothing() end)
    end)
end

AddEventHandler('MULTIcore:client:lookApplied', function() TLookC.reapply() end)

-- MULTIinventory: the worn set changed (server truth). Remember which slots were emptied.
AddEventHandler('MULTIinventory:client:clothingChanged', function(pieces)
    pieces = type(pieces) == 'table' and pieces or {}
    for key in pairs(prevWorn) do
        if pieces[key] == nil then removed[key] = true end
    end
    for key in pairs(pieces) do removed[key] = nil end
    prevWorn = {}
    for key in pairs(pieces) do prevWorn[key] = true end
end)

-- MULTIinventory has drawn the worn set: give the body back under every emptied slot
AddEventHandler('MULTIinventory:client:clothingApplied', function(reason)
    if reason == 'preview' or not next(removed) or GetResourceState('MULTIcore') ~= 'started' then return end
    local ped = PlayerPedId()
    local list = removed
    removed = {}
    for key in pairs(list) do
        local slot = TLook.byKey[key]
        if slot then pcall(function() exports.MULTIcore:RemoveComp(ped, slot.game) end) end
    end
end)

RegisterNetEvent('MULTIcore:client:characterSelected', function() prevWorn, removed = {}, {} end)

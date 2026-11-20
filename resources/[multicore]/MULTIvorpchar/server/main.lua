-- ============================================================
-- MULTIvorpchar :: server
--   exports.vorp_character:OpenOutfitsMenu(source) -> true when MULTItailor's
--   outfit list was opened for that player (MULTItailor running, character loaded).
-- Names follow VORP's public docs and how VORP scripts call vorp_character.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local dbg = VC.Debug

local function ExportAs(name, fn)
    exports(name, fn)
    AddEventHandler(('__cfx_export_vorp_character_%s'):format(name), function(setCB) setCB(fn) end)
end

ExportAs('OpenOutfitsMenu', function(source)
    local src = tonumber(source)
    if not src or not RSGCore.Functions.GetPlayer(src) then return false end
    if GetResourceState('MULTItailor') ~= 'started' then
        dbg('OpenOutfitsMenu: MULTItailor is not running')
        return false
    end
    TriggerClientEvent('MULTIvorpchar:client:openOutfits', src)
    return true
end)

-- The client sends this after every look load (as vorp_character does). VORP scripts register their own
-- handlers; declaring it here keeps it a known net event when no script listens.
RegisterNetEvent('vorpcharacter:reloadedskinlistener')

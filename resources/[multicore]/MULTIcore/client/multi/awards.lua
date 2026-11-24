-- ============================================================
-- MULTIcore :: hide the game's own award popups
-- Part of MULTIcore by RINGO (RINGOscripting). GPL v3.
--
-- The base game shows award and challenge cards on the left of the screen
-- ("Survivalist Award - Hold F1 for details"). They mean nothing on a
-- roleplay server, so they are cleared the moment they appear.
-- Switch: MULTIConfig.HideGameAwards = false in config_multi.lua keeps them.
--
-- Natives (femga natives.json):
--   UI_FEED_GET_CURRENT_MESSAGE 0xC17F69E1418CD11F (feedChannel) -> feedMessage
--   UI_FEED_CLEAR_CHANNEL       0xDD1232B332CBB9E7 (feedChannel, p1, p2)
--   feed channel 6 = kFeedChannel_Toast (the left-hand cards)
-- ============================================================

if MULTIConfig and MULTIConfig.HideGameAwards == false then return end

local TOAST_CHANNEL = 6

CreateThread(function()
    while true do
        if Citizen.InvokeNative(0xC17F69E1418CD11F, TOAST_CHANNEL, Citizen.ResultAsInteger()) ~= 0 then
            Citizen.InvokeNative(0xDD1232B332CBB9E7, TOAST_CHANNEL, true, true)
        end
        Wait(0)
    end
end)

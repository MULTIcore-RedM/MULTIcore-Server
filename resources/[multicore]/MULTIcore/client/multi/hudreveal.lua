-- ============================================================
-- MULTIcore :: stop Left Alt flashing the base game HUD
-- Part of MULTIcore by RINGO (RINGOscripting). GPL v3.
--
-- Left Alt is the target key (MULTItarget) and, in the base game, also
-- "reveal HUD": every press flashed the game's cores, money and honour on
-- screen. The game's reveal is switched off here; scripts that read the
-- key with IsDisabledControlPressed still see it.
-- Switch: MULTIConfig.BlockHudReveal = false in config_multi.lua keeps the reveal.
--
-- Control (redm-info Controls.cs): RevealHud = 0xCF8A4ECA
-- ============================================================

if MULTIConfig and MULTIConfig.BlockHudReveal == false then return end

local REVEAL_HUD = 0xCF8A4ECA

-- runs in MULTIcore's one frame thread (client/prompts.lua)
MULTIFrame.add(function()
    DisableControlAction(0, REVEAL_HUD, true)
end)

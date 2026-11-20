-- ============================================================
-- MULTIinventory :: hotbar
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
--
-- Satchel slots 1..Config.Hotbar.Size are the hotbar. Keys 1-5 use them
-- (the game's quick-select keys, Controls.cs; never PageDown). The bar shows
-- for a moment when a key is used, or stays up with the toggle key.
-- ============================================================

local shown = false

local function hotbarItems()
    local out = {}
    local items = MIC.PlayerItems()
    for i = 1, MIC.Cfg('Hotbar.Size', 5) do
        if items[i] then out[#out + 1] = MIC.ItemForNui(items[i]) end
    end
    return out
end

--- Show / refresh the hotbar. pinned = stay until toggled off; otherwise hides after Hotbar.ShowTime.
function MIC.ShowHotbar(pinned, active)
    MIC.SendStatic()
    SendNUIMessage({
        action = 'hotbar',
        show = true,
        pinned = pinned == true,
        items = hotbarItems(),
        active = active,
        time = MIC.Cfg('Hotbar.ShowTime', 2500),
    })
end

function MIC.HideHotbar()
    SendNUIMessage({ action = 'hotbar', show = false })
end

function MIC.ToggleHotbar()
    shown = not shown
    if shown then MIC.ShowHotbar(true) else MIC.HideHotbar() end
end

function MIC.UseHotbar(i)
    if MIC.IsOpen or not MIC.CanUse() then return end
    MIC.ShowHotbar(shown, i)
    MIC.UseSlot(i)
end

-- keep the pinned bar current when the satchel changes
MIC.OnInvChange[#MIC.OnInvChange + 1] = function()
    if shown then MIC.ShowHotbar(true) end
end

RegisterCommand(MIC.Cfg('Hotbar.Command', 'hotbar'), function()
    if MIC.LoggedIn() then MIC.ToggleHotbar() end
end, false)

CreateThread(function()
    if not MIC.Cfg('Hotbar.Enabled', true) then return end
    -- default keys 1-5: INPUT_SELECT_QUICKSELECT_* (Controls.cs)
    local keys = MIC.Cfg('Hotbar.Keys', { 0xE6F612E4, 0x1CE6D9EB, 0x4F49CC4C, 0x8F9F9E58, 0xAB62E997 })
    local toggle = MIC.Cfg('Hotbar.ToggleKey', 0x26E9DC00) -- RSG's hotbar key (Z), Controls.cs GameMenuTabLeftSecondary
    while true do
        local sleep = 250
        if MIC.LoggedIn() and not MIC.IsOpen and not IsPauseMenuActive() then
            sleep = 0
            for i, key in ipairs(keys) do
                DisableControlAction(0, key, true)
                if IsDisabledControlJustPressed(0, key) then MIC.UseHotbar(i) end
            end
            if toggle and toggle ~= 0 and IsControlJustReleased(0, toggle) then MIC.ToggleHotbar() end
        end
        Wait(sleep)
    end
end)

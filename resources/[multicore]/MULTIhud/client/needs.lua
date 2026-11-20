-- MULTIhud client: tells the server what the player is doing (for faster decay),
-- reports shooting (stress), and applies the effects of hunger / thirst at 0.

---------------------------------------------------------------------------
-- activity + temperature band, reported only when it changes (at most every Config.ReportMinSeconds)
---------------------------------------------------------------------------
CreateThread(function()
    local sentMode, sentTemp, sentAt = nil, nil, 0
    while true do
        Wait(Config.Hud.ActivityCheckMs)
        if Hud.loggedIn then
            local ped = PlayerPedId()
            local mode = 'idle'
            if IsPedSwimming(ped) then
                mode = 'swim'
            elseif IsPedSprinting(ped) then
                mode = 'sprint'
            elseif IsPedRunning(ped) then
                mode = 'run'
            end
            -- riding: the horse does the running
            if IsPedOnMount(ped) then mode = 'idle' end

            local temp = 'mild'
            local c = Hud.temp
            if Config.Temperature.Enabled and c then
                if c <= Config.Temperature.Cold then temp = 'cold' elseif c >= Config.Temperature.Hot then temp = 'hot' end
            end

            local now = GetGameTimer()
            if (mode ~= sentMode or temp ~= sentTemp) and now - sentAt >= Config.ReportMinSeconds * 1000 then
                sentMode, sentTemp, sentAt = mode, temp, now
                TriggerServerEvent('MULTIhud:server:activity', mode, temp)
            end
        end
    end
end)

---------------------------------------------------------------------------
-- shooting -> stress
---------------------------------------------------------------------------
if Config.Stress.FromShooting then
    CreateThread(function()
        local lastSent = 0
        while true do
            if Hud.loggedIn then
                Wait(0)
                if IsPedShooting(PlayerPedId()) then
                    local now = GetGameTimer()
                    if now - lastSent >= Config.Stress.ShotCooldownMs then
                        lastSent = now
                        TriggerServerEvent('MULTIhud:server:shot')
                    end
                end
            else
                Wait(Config.Hud.ActivityCheckMs)
            end
        end
    end)
end

---------------------------------------------------------------------------
-- hunger / thirst at 0: lose health
---------------------------------------------------------------------------
if Config.Starving.Enabled then
    CreateThread(function()
        local wasStarving, wasThirsty = false, false
        while true do
            Wait(Config.Starving.IntervalSeconds * 1000)
            local st = LocalPlayer.state
            if Hud.loggedIn and not st.isdead then
                local ped = PlayerPedId()
                if not IsEntityDead(ped) then
                    local dmg = 0
                    local hunger, thirst = tonumber(st.hunger), tonumber(st.thirst)
                    local starving = hunger ~= nil and hunger <= 0
                    local thirsty = thirst ~= nil and thirst <= 0
                    if starving then dmg = dmg + Config.Starving.HungerDamage end
                    if thirsty then dmg = dmg + Config.Starving.ThirstDamage end
                    -- tell the player once each time they reach 0
                    if Config.Starving.Notify then
                        if starving and not wasStarving then exports.MULTIcore:Notify(_L('starving'), 'warning') end
                        if thirsty and not wasThirsty then exports.MULTIcore:Notify(_L('dehydrated'), 'warning') end
                    end
                    wasStarving, wasThirsty = starving, thirsty
                    if dmg > 0 then
                        local hp = GetEntityHealth(ped) - dmg
                        if not Config.Starving.CanKill and hp < Config.Starving.MinHealth then hp = Config.Starving.MinHealth end
                        if hp < 0 then hp = 0 end
                        SetEntityHealth(ped, hp, 0)
                        if Config.Starving.InnerCoreDrain > 0 then
                            local core = Hud.Core(ped, HudCore.HEALTH) - Config.Starving.InnerCoreDrain
                            Citizen.InvokeNative(HudN.SET_ATTRIBUTE_CORE_VALUE, ped, HudCore.HEALTH, math.max(0, core))
                        end
                    end
                end
            end
        end
    end)
end

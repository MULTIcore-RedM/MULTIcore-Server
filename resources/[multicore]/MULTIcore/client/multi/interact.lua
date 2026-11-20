-- ============================================================
-- MULTIcore :: /mcinteract (client)
-- Asks every running MULTI script for exports.<script>:GetInteractStats()
-- (see lib/interact.lua) and sends the answers to the server, which
-- prints one line per script in the server console. Anyone may use it:
-- it only reads counts.
-- GPL v3, part of MULTIcore.
-- ============================================================

local COMMAND = 'mcinteract'
local PREFIX = 'MULTI'

local function collect()
    local out = {}
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res and res:sub(1, #PREFIX) == PREFIX and GetResourceState(res) == 'started' then
            local ok, s = pcall(function() return exports[res]:GetInteractStats() end)
            if ok and type(s) == 'table' then
                out[#out + 1] = {
                    resource = res,
                    mode = tostring(s.mode or '?'),
                    targets = tonumber(s.targets) or 0,
                    prompts = tonumber(s.prompts) or 0,
                    npcs = tonumber(s.npcs) or 0,
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.resource < b.resource end)
    return out
end

RegisterCommand(COMMAND, function()
    local list = collect()
    TriggerServerEvent('MULTIcore:server:interactReport', {
        oxTarget = GetResourceState('MULTItarget'),
        loggedIn = LocalPlayer.state.isLoggedIn == true,
        list = list,
    })
    exports.MULTIcore:Notify(_L('interact_sent', #list), 'info')
end, false)

TriggerEvent('chat:addSuggestion', '/' .. COMMAND, _L('interact_help'))

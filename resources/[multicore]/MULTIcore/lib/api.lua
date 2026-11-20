-- ============================================================
-- MULTIcore :: API shortcut
-- Put  '@MULTIcore/lib/api.lua'  in shared_scripts and call  MC.GetCharacter(src)
-- instead of  exports.MULTIcore:GetCharacter(src).  Works on the server and the client.
-- Also gives MC.OnCharacterLoaded(fn) and MC.OnCharacterUnloaded(fn).
-- Full list and examples: docs/API.md in the MULTIcore download.
-- ============================================================

MC = setmetatable({}, {
    __index = function(t, name)
        local fn = function(...) return exports.MULTIcore[name](exports.MULTIcore, ...) end
        rawset(t, name, fn)
        return fn
    end,
})

if IsDuplicityVersion() then
    --- fn(src, citizenid, isNew) when a player picks or makes a character
    function MC.OnCharacterLoaded(fn)
        AddEventHandler('MULTIcore:characterSelected', function(src, citizenid, isNew) fn(src, citizenid, isNew) end)
    end
    --- fn(src) when a player logs out of a character or leaves
    function MC.OnCharacterUnloaded(fn)
        AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) fn(src) end)
        AddEventHandler('RSGCore:Server:PlayerDropped', function(P) if P and P.PlayerData then fn(P.PlayerData.source) end end)
    end
    --- fn(src, job) when a player's job changes (job in GetJob's shape)
    function MC.OnJobChanged(fn)
        AddEventHandler('RSGCore:Server:OnJobUpdate', function(src) fn(src, MC.GetJob(src)) end)
    end
else
    --- fn(isNew) when the local player picks or makes a character
    function MC.OnCharacterLoaded(fn)
        RegisterNetEvent('MULTIcore:client:characterSelected', function(isNew) fn(isNew) end)
    end
    --- fn() when the local player logs out of a character
    function MC.OnCharacterUnloaded(fn)
        RegisterNetEvent('MULTIcore:client:loggedOut', function() fn() end)
    end
    --- fn(job) when the local player's job changes
    function MC.OnJobChanged(fn)
        RegisterNetEvent('RSGCore:Client:OnJobUpdate', function() fn(MC.GetJob()) end)
    end
end

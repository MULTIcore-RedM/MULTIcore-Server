-- ============================================================
-- MULTIinventory :: framework bridge (shared, client + server)
--
-- Decides which framework shape the inventory talks to and nothing else.
-- On MULTIcore the answer is always 'rsg': MULTIcore answers as rsg-core,
-- vorp_core and redem_roleplay at the same time, and its player data
-- (PlayerData.items, Player.Functions, RSGCore.Shared.Items) has the
-- rsg-core shape. VORP and RedEM:RP scripts are served by this resource's
-- vorp_inventory and redemrp_inventory faces (server/multi/faces.lua).
--
--   Config.Framework = 'auto' | 'vorp' | 'rsg'      (per resource)
--   setr multi_framework  auto | vorp | rsg        (whole server)
-- Both are only read when MULTIcore is not installed.
-- ============================================================

MBridge = MBridge or {}

local function present(name)
    local s = GetResourceState(name)
    return s ~= 'missing' and s ~= 'unknown'
end

local function running(name)
    local s = GetResourceState(name)
    return s == 'started' or s == 'starting'
end

local function normalise(v)
    v = tostring(v or 'auto'):lower()
    if v == 'rsg' or v == 'rsg-core' or v == 'rsgcore' or v == 'rsg_core' then return 'rsg' end
    if v == 'vorp' or v == 'vorp_core' or v == 'vorpcore' then return 'vorp' end
    return 'auto'
end

local function choose()
    -- MULTIcore makes rsg-core and vorp_core both report started; its data is rsg-shaped
    if present('MULTIcore') then return 'rsg' end
    local want = 'auto'
    if type(Config) == 'table' and Config.Framework ~= nil then
        want = normalise(Config.Framework)
    end
    if want == 'auto' then
        want = normalise(GetConvar('multi_framework', 'auto'))
    end
    if want ~= 'auto' then return want end

    -- Whichever framework is installed is used. With both installed rsg-core wins
    -- unless only vorp_core is actually running.
    local hasVorp, hasRsg = present('vorp_core'), present('rsg-core')
    if hasVorp and not hasRsg then return 'vorp' end
    if hasRsg and not hasVorp then return 'rsg' end
    if hasVorp and hasRsg then
        if running('vorp_core') and not running('rsg-core') then return 'vorp' end
        return 'rsg'
    end
    return 'rsg'
end

MBridge.Framework         = choose()
MBridge.IsVorp            = MBridge.Framework == 'vorp'
MBridge.IsRsg             = MBridge.Framework == 'rsg'
MBridge.FrameworkResource = MBridge.IsRsg and 'rsg-core' or 'vorp_core'
MBridge.Resource          = GetCurrentResourceName()

function MBridge.Log(fmt, ...)
    local msg = select('#', ...) > 0 and fmt:format(...) or fmt
    print(('[%s] [framework:%s] %s'):format(MBridge.Resource, MBridge.Framework, msg))
end

---Block (inside a thread) until the chosen framework resource is running.
function MBridge.WaitForFramework(timeoutMs)
    local waited = 0
    while not running(MBridge.FrameworkResource) do
        Wait(100)
        waited = waited + 100
        if timeoutMs and waited >= timeoutMs then return false end
    end
    return true
end

if IsDuplicityVersion() then
    CreateThread(function()
        Wait(0)
        if present(MBridge.FrameworkResource) then return end
        local other = MBridge.IsRsg and 'vorp_core' or 'rsg-core'
        if present(other) then
            local pick = MBridge.IsRsg and 'vorp' or 'rsg'
            MBridge.Log("^1%s was selected but not found, and %s is installed - to use it set Config.Framework = '%s' (or  setr multi_framework \"%s\"  in server.cfg)^7",
                MBridge.FrameworkResource, other, pick, pick)
        else
            MBridge.Log('^1%s was selected but the resource was not found - check Config.Framework / multi_framework^7',
                MBridge.FrameworkResource)
        end
    end)
end

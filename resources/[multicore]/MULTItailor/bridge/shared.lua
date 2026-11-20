-- ============================================================
-- MULTItailor framework bridge :: shared (client + server)
--
-- Decides which framework and inventory this resource talks to.
-- On MULTIcore, config.lua sets Config.Framework = 'rsg' and
-- Config.Inventory = 'multi' (MULTIcore answers as both cores).
--
--   Config.Framework = 'auto' | 'vorp' | 'rsg'      (per resource)
--   setr multi_framework  auto | vorp | rsg        (whole server)
--
-- Order of precedence: Config.Framework (unless 'auto'), then the
-- convar, then auto-detection. Auto-detection:
--   * only one of vorp_core / rsg-core is started -> that one
--   * BOTH are started -> VORP (name the one you want with
--     Config.Framework or  setr multi_framework "rsg"  to override)
--   * neither is started yet -> whichever one is installed
--     (both installed -> VORP), with a console warning
--   * neither is installed -> a clear console ERROR; the bridge
--     falls back to VORP only so the resource can still load.
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

local chooseProblem -- set when auto-detection had to guess; logged on the server

---Pure decision used by the bridge (exposed for the offline tests).
---want: normalised Config.Framework / convar ('auto'|'vorp'|'rsg').
function MBridge.DecideFramework(want, vorpRunning, rsgRunning, vorpInstalled, rsgInstalled)
    if want == 'vorp' or want == 'rsg' then return want end
    if vorpRunning and not rsgRunning then return 'vorp' end
    if rsgRunning and not vorpRunning then return 'rsg' end
    if vorpRunning and rsgRunning then return 'vorp' end
    -- neither started yet (start order): use what is installed
    if vorpInstalled and not rsgInstalled then return 'vorp', 'notstarted' end
    if rsgInstalled and not vorpInstalled then return 'rsg', 'notstarted' end
    if vorpInstalled and rsgInstalled then return 'vorp', 'notstarted' end
    return 'vorp', 'none'
end

local function choose()
    local want = 'auto'
    if type(Config) == 'table' and Config.Framework ~= nil then
        want = normalise(Config.Framework)
    end
    if want == 'auto' then
        want = normalise(GetConvar('multi_framework', 'auto'))
    end
    local fw, problem = MBridge.DecideFramework(want,
        running('vorp_core'), running('rsg-core'), present('vorp_core'), present('rsg-core'))
    chooseProblem = problem
    return fw
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
        if chooseProblem == 'none' then
            MBridge.Log('^1ERROR: neither vorp_core nor rsg-core is installed - this resource needs one of them. Install a framework or set Config.Framework / multi_framework.^7')
            return
        elseif chooseProblem == 'notstarted' then
            MBridge.Log('^3neither vorp_core nor rsg-core was started when this resource loaded - picked %s because it is installed. Ensure the framework starts first, or set Config.Framework / multi_framework.^7',
                MBridge.FrameworkResource)
        end
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

-- ============================================================
-- Inventory selection (independent of the framework)
--
--   Config.Inventory = 'auto' | 'vorp' | 'rsg' | 'multi'   (per resource)
--   setr multi_inventory  auto | vorp | rsg | multi        (whole server)
--
-- Order of precedence: Config.Inventory (unless 'auto'), then the convar,
-- then auto-detection:
--   * MULTIinventory installed, and the framework's own inventory resource is
--     missing or is MULTIinventory's compatibility shim (author 'RINGO')
--       -> 'multi'
--   * otherwise the framework default: VORP -> vorp_inventory, RSG -> rsg-inventory.
-- While the real vorp_inventory / rsg-inventory still runs next to MULTIinventory
-- (parallel test phase) auto keeps the framework inventory, so nothing moves by
-- accident. Switch on purpose with  setr multi_inventory "multi"  in server.cfg.
-- 'vorp' needs the VORP framework and 'rsg' needs RSG-Core; any other pairing falls
-- back to the framework default with a console warning. 'multi' works on both.
--
-- With 'multi', MBridge.INV is a proxy: INV:addItem(...) / INV.addItem(INV, ...)
-- call exports.MULTIinventory:Compat_addItem(...). The export is looked up on every
-- call (start-order safe) and the first argument is dropped exactly like
-- exports.vorp_inventory does, so callers do not change.
-- Framework selection (money, jobs, characters) is not affected by any of this.
-- ============================================================
do
    local MULTI_INV = 'MULTIinventory'
    local INV_RESOURCE = { vorp = 'vorp_inventory', rsg = 'rsg-inventory', multi = MULTI_INV }
    local IMAGE_BASE = {
        vorp  = 'nui://vorp_inventory/html/img/items/',
        rsg   = 'nui://rsg-inventory/html/images/',
        multi = 'nui://MULTIinventory/html/img/items/',
    }

    local function invPresent(name)
        local s = GetResourceState(name)
        return s ~= 'missing' and s ~= 'unknown'
    end

    local function invRunning(name)
        local s = GetResourceState(name)
        return s == 'started' or s == 'starting'
    end

    local function invNormalise(v)
        v = tostring(v or 'auto'):lower()
        if v == 'multi' or v == 'multiinventory' or v == 'multi_inventory' or v == 'multi-inventory' then return 'multi' end
        if v == 'vorp' or v == 'vorp_inventory' or v == 'vorpinventory' or v == 'vorp-inventory' then return 'vorp' end
        if v == 'rsg' or v == 'rsg-inventory' or v == 'rsg_inventory' or v == 'rsginventory' then return 'rsg' end
        return 'auto'
    end

    -- MULTIinventory's compat shims (compat/*_shim) carry author 'RINGO'; the real ones do not.
    local function isMultiShim(name)
        if not invPresent(name) then return false end
        local ok, author = pcall(GetResourceMetadata, name, 'author', 0)
        return ok and author == 'RINGO'
    end

    local function invLog(msg)
        print(('[%s] [inventory] %s'):format(GetCurrentResourceName(), msg))
    end

    local function chooseInventory()
        local fwDefault = (MBridge.IsRsg or MBridge.Framework == 'rsg') and 'rsg' or 'vorp'
        local want = 'auto'
        if type(Config) == 'table' then
            local v = Config.Inventory
            -- a resource may keep other settings in a Config.Inventory TABLE,
            -- so a non-string value is ignored and Config.InventorySystem is read instead.
            if type(v) ~= 'string' then v = Config.InventorySystem end
            if v ~= nil then want = invNormalise(v) end
        end
        if want == 'auto' then
            want = invNormalise(GetConvar('multi_inventory', 'auto'))
        end
        if want == 'auto' then
            local fwInv = INV_RESOURCE[fwDefault]
            if invPresent(MULTI_INV) and (not invPresent(fwInv) or isMultiShim(fwInv)) then
                want = 'multi'
            else
                want = fwDefault
            end
        end
        if want ~= 'multi' and want ~= fwDefault then
            invLog(("^3inventory '%s' needs the %s framework - using %s^7")
                :format(want, want == 'rsg' and 'RSG' or 'VORP', INV_RESOURCE[fwDefault]))
            want = fwDefault
        end
        return want
    end

    MBridge.Inventory         = chooseInventory()
    MBridge.IsMultiInv        = MBridge.Inventory == 'multi'
    MBridge.IsVorpInv         = MBridge.Inventory == 'vorp'
    MBridge.IsRsgInv          = MBridge.Inventory == 'rsg'
    MBridge.InventoryResource = INV_RESOURCE[MBridge.Inventory]

    ---Is the selected inventory resource running?
    function MBridge.InventoryStarted()
        return invRunning(MBridge.InventoryResource)
    end

    ---NUI picture of an item in the selected inventory: InventoryImage('bread') ->
    ---'nui://<inventory>/<image folder>/bread.png'. No name = the folder itself.
    function MBridge.InventoryImage(name)
        local base = IMAGE_BASE[MBridge.Inventory] or IMAGE_BASE.vorp
        if name == nil then return base end
        name = tostring(name)
        if not name:find('%.%w+$') then name = name .. '.png' end
        return base .. name
    end

    -- vorp_inventory-shaped object over MULTIinventory's Compat_<name> exports.
    -- INV.name gives a function(self, ...) that drops self (like an export does) and
    -- looks the export up on every call, so MULTIinventory may start (or restart)
    -- after this resource without breaking anything.
    MBridge.MultiINV = MBridge.MultiINV or setmetatable({}, {
        __index = function(t, name)
            if type(name) ~= 'string' then return nil end
            local export = 'Compat_' .. name
            local fn = function(_, ...)
                local ex = exports[MULTI_INV]
                return ex[export](ex, ...)
            end
            rawset(t, name, fn)
            return fn
        end,
    })

    ---Server bridges: the INV object to expose. `native` is the framework inventory
    ---object (exports.vorp_inventory, or the rsg-inventory emulation).
    function MBridge.SelectINV(native)
        if MBridge.IsMultiInv then return MBridge.MultiINV end
        return native
    end

    -- Client side: the client bridges make no INV object, so give client code the same handle.
    if not IsDuplicityVersion() and MBridge.INV == nil then
        if MBridge.IsMultiInv then
            MBridge.INV = MBridge.MultiINV
        elseif MBridge.IsVorpInv then
            MBridge.INV = exports.vorp_inventory
        end
    end

    if IsDuplicityVersion() then
        CreateThread(function()
            Wait(0)
            if MBridge.IsMultiInv then
                if invPresent(MULTI_INV) then
                    invLog('using MULTIinventory (vorp_inventory-compatible Compat_* API)')
                else
                    invLog('^1MULTIinventory was selected but the resource was not found - check Config.Inventory / multi_inventory^7')
                end
            end
        end)
    end
end

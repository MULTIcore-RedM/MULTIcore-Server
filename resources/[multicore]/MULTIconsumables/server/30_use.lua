-- ============================================================
-- MULTIconsumables :: using items (server)
-- The item is taken on the server before anything else happens (no duplicates). The client
-- only plays the animation. With Config.Use.ApplyOnStart = false the effects wait for the
-- client's "finished"; stopping early then gives nothing, and the item stays used.
--
-- Usables are registered with MULTIinventory as *built-in* handlers (RegisterUsable opts
-- builtin = true). MULTIinventory runs a built-in handler only when no other script handles
-- the item (an RSG CreateUseableItem, a VORP registerUsableItem or a normal RegisterUsable),
-- whichever starts first. So rsg-consume, rsg-herbalist or a VORP food script keep their
-- items, and nothing here runs twice.
-- ============================================================

local MI = exports.MULTIinventory

local function hud(fn, ...)
    local args = { ... }
    local ok, res = pcall(function() return exports.MULTIhud[fn](exports.MULTIhud, table.unpack(args)) end)
    return ok and res or nil
end

--- Applies an item's effects to a player (needs, cores, drunk, addiction, cures).
function MC.Apply(src, name, def)
    local s = MC.Get(src)
    if not s then return false end
    def = def or Config.Consumables[name]
    if not def then return false end

    -- tolerance: good effects of an addictive item get weaker with the habit
    local mult = def.substance and MC.Addiction.ToleranceMult(s, def.substance) or 1.0
    local function good(v) v = tonumber(v) or 0; return v > 0 and v * mult or v end

    if def.hunger and def.hunger ~= 0 then hud('AddNeed', src, 'hunger', def.hunger) end
    if def.thirst and def.thirst ~= 0 then hud('AddNeed', src, 'thirst', def.thirst) end
    if def.stress and def.stress ~= 0 then
        local stress = def.stress < 0 and def.stress * mult or def.stress
        hud('AddNeed', src, 'stress', stress)
    end

    local cores = {}
    for _, key in ipairs({ 'health', 'healthCore', 'stamina', 'staminaCore' }) do
        if def[key] and def[key] ~= 0 then cores[key] = good(def[key]) end
    end
    if next(cores) then TriggerClientEvent('MULTIconsumables:client:effects', src, cores) end

    if def.alcohol and def.alcohol > 0 then
        local amount = def.alcohol
        if Config.Drunk.ToleranceReduces then amount = amount * MC.Addiction.ToleranceMult(s, 'alcohol') end
        MC.Drunk.Add(src, amount)
    end
    if def.sober and def.sober > 0 then MC.Drunk.Add(src, -def.sober) end
    if def.substance then MC.Addiction.Use(src, def.substance, def.addiction) end
    if def.cures then MC.Addiction.Cure(src, def.cures, def.relief) end

    MC.Save(src)
    MC.Debug('applied %s to %s (tolerance x%.2f)', name, src, mult)
    return true
end

--- Can this player use this item now? → true | false, err
function MC.CanUse(src, name)
    local def = Config.Consumables[name]
    if not def then return false, 'not_consumable' end
    local s, P = MC.Get(src)
    if not s then return false, 'no_player' end
    if (MC.Busy[src] or 0) > GetGameTimer() then return false, 'busy' end
    if MC.Blackout[src] then return false, 'blackout' end
    local meta = P.PlayerData.metadata or {}
    if Config.Use.BlockWhenDead and (meta.isdead or meta.inlaststand) then return false, 'dead' end
    if def.requires then
        local n = MI:Count(MI:PlayerInv(src), def.requires)
        if (tonumber(n) or 0) < 1 then return false, 'requires' end
    end
    return true
end

local tokens = 0

--- Uses one `name` from the player's satchel (slot optional). opts.free = true takes no item.
--- → true | false, err
function MC.Use(src, name, slot, opts)
    src = tonumber(src)
    opts = type(opts) == 'table' and opts or {}
    if type(name) ~= 'string' then return false, 'not_consumable' end
    name = name:lower()
    local ok, err = MC.CanUse(src, name)
    if not ok then
        if err == 'busy' then MC.Notify(src, 'busy', 'error')
        elseif err == 'requires' then
            local need = Config.Consumables[name].requires
            local d = MI:GetItemDef(need)
            MC.Notify(src, 'need_item', 'error', d and d.label or need)
        elseif err == 'dead' or err == 'blackout' then MC.Notify(src, 'cannot_now', 'error') end
        return false, err
    end
    local def = Config.Consumables[name]

    -- refillable (canteens): ask the player's game whether they stand in water, then use again
    -- (in its own thread, so the satchel is not held while the answer comes back)
    if def.refill and opts.inWater == nil and not opts.free then
        CreateThread(function()
            local inWater = lib.callback.await('MULTIconsumables:inWater', src) == true
            MC.Use(src, name, slot, { inWater = inWater })
        end)
        return true
    end
    local refilling = def.refill and opts.inWater and def.refill ~= name
    if def.refillOnly and not refilling then
        MC.Notify(src, 'need_water', 'error')
        return false, 'need_water'
    end

    local invId = MI:PlayerInv(src)
    if not opts.free then
        local removed, rerr = MI:RemoveItem(invId, name, 1, slot, nil, 'MULTIconsumables')
        if not removed then return false, rerr or 'no_item' end
    end
    -- what the player gets back: the refilled item, or the item one step emptier
    local back = refilling and def.refill or def.returns
    if back and not opts.free then
        local added = MI:AddItem(invId, back, 1, nil, slot, 'MULTIconsumables')
        if not added then MI:AddItem(invId, back, 1, nil, nil, 'MULTIconsumables') end
    end
    if refilling then
        MC.Notify(src, 'refilled', 'success')
        local ra = Config.Anims.refill
        MC.Busy[src] = GetGameTimer() + (ra and ra.ms or 0) + Config.Use.CooldownMs
        tokens = tokens + 1
        TriggerClientEvent('MULTIconsumables:client:use', src, name, tokens, 'refill')
        return true
    end

    local anim = Config.Anims[def.anim]
    local animMs = anim and anim.ms or 0
    MC.Busy[src] = GetGameTimer() + animMs + Config.Use.CooldownMs
    tokens = tokens + 1
    local token = tokens

    if Config.Use.ApplyOnStart or opts.instant then
        MC.Apply(src, name, def)
    else
        MC.Pending[src] = {
            name = name, token = token, from = GetGameTimer(),
            minMs = math.floor(animMs * 0.5),
            expires = GetGameTimer() + math.min(animMs, Config.Use.MaxAnimMs) + Config.Use.FinishTimeoutMs,
        }
    end
    if not opts.noAnim then TriggerClientEvent('MULTIconsumables:client:use', src, name, token) end
    TriggerEvent('MULTIconsumables:consumed', src, name)
    MC.Debug('%s used %s (token %d)', src, name, token)
    return true
end

-- the client's animation ended (completed = false when the player stopped early)
RegisterNetEvent('MULTIconsumables:server:finished', function(token, completed)
    local src = source
    MC.Busy[src] = math.min(MC.Busy[src] or 0, GetGameTimer() + Config.Use.CooldownMs)
    local p = MC.Pending[src]
    if not p or p.token ~= token then return end
    MC.Pending[src] = nil
    if completed and GetGameTimer() >= p.from + p.minMs then MC.Apply(src, p.name) end
end)

---------------------------------
-- registration with MULTIinventory
---------------------------------
local function onUse(src, stack)
    if type(stack) ~= 'table' or not stack.name then return end
    local ok, err = MC.Use(src, stack.name, stack.slot)
    -- server.cfg: set multi_debug_use true  prints why a use was refused
    if not ok and GetConvar('multi_debug_use', 'false') == 'true' then print(('[MULTIconsumables use] %s: %s refused (%s)'):format(src, stack.name, tostring(err))) end
end

function MC.Register()
    local added, usable = 0, 0
    for name, def in pairs(Config.NewItems or {}) do
        if not MI:GetItemDef(name) then
            if MI:RegisterItem(def) then added = added + 1 end
        end
    end
    for name in pairs(Config.Consumables) do
        if MI:GetItemDef(name) then
            MI:RegisterUsable(name, onUse, { builtin = true, face = 'multi' })
            usable = usable + 1
        else
            print(('^3[MULTIconsumables] item "%s" is not in the item registry; skipped^7'):format(name))
        end
    end
    print(('[MULTIconsumables] %d items added to the registry, %d items usable (scripts that already handle an item keep it)'):format(added, usable))
end

CreateThread(function()
    local t = 0
    while (GetResourceState('MULTIinventory') ~= 'started' or not MI:IsReady()) and t < 1200 do Wait(250) t = t + 1 end
    if GetResourceState('MULTIinventory') ~= 'started' then
        print('^1[MULTIconsumables] MULTIinventory is not running; no items are usable^7')
        return
    end
    MC.Register()
    MC.Ready = true
end)

-- MULTIinventory restarted: its usable list is empty again
AddEventHandler('onResourceStart', function(res)
    if res ~= 'MULTIinventory' then return end
    CreateThread(function()
        local t = 0
        while not MI:IsReady() and t < 1200 do Wait(250) t = t + 1 end
        MC.Register()
    end)
end)

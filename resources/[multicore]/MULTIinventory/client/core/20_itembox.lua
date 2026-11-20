-- ============================================================
-- MULTIinventory :: item box pop-ups  (UI builder)
-- GPL v3, part of MULTIcore.
--
-- Small black tiles near the bottom of the screen when items come or go.
-- Engine event (contract): MULTIinventory:client:itembox (itemDef, amount, 'add' | 'remove' | 'use')
-- RSG's own names are routed here from client/rsg/.
-- ============================================================

local KINDS = { add = true, remove = true, use = true, info = true }

--- Show one pop-up. def = item definition table or an item name.
function MIC.ItemBox(def, amount, kind)
    if not MIC.Cfg('ItemBox.Enabled', true) then return end
    if type(def) == 'string' then def = MIC.Def(def) or { name = def } end
    if type(def) ~= 'table' or not def.name then return end
    -- RSG callers sometimes pass (def, amount, kind) and sometimes (def, kind, amount)
    if type(amount) == 'string' and KINDS[amount] then amount, kind = kind, amount end
    kind = KINDS[kind] and kind or 'add'
    local full = MIC.Def(def.name) or {}
    MIC.SendStatic()
    SendNUIMessage({
        action = 'itembox',
        kind = kind,
        amount = math.floor(tonumber(amount) or 1),
        item = {
            name = def.name,
            label = def.label or full.label or def.name,
            image = def.image or full.image or (def.name .. '.png'),
        },
        time = MIC.Cfg('ItemBox.Time', 3500),
        max = MIC.Cfg('ItemBox.Max', 5),
    })
end

RegisterNetEvent('MULTIinventory:client:itembox', function(def, amount, kind)
    MIC.ItemBox(def, amount, kind)
end)

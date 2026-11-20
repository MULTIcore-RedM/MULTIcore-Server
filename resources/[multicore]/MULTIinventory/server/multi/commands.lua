-- ============================================================
-- MULTIinventory :: server/multi/commands.lua
--   /giveitem [id] [item] [amount]   give a player any item or weapon (admin)
-- Same name and arguments as rsg-inventory's /giveitem.
-- ============================================================

local API = MultiInv.API

CreateThread(function()
    InvDB.awaitReady()
    local name = Config.GiveItemCommand or 'giveitem'
    if name == '' or name == false then return end
    local core = RsgInv.core()
    if not (core and core.Commands and core.Commands.Add) then return end
    core.Commands.Add(name, L('cmd_giveitem'), {
        { name = 'id', help = L('cmd_giveitem_id') },
        { name = 'item', help = L('cmd_giveitem_item') },
        { name = 'amount', help = L('cmd_giveitem_amount') },
    }, true, function(source, args)
        local target = tonumber(args[1])
        local item = tostring(args[2] or ''):lower()
        local amount = math.max(1, math.floor(tonumber(args[3]) or 1))
        local function tell(text, kind)
            if source == 0 then return print(text) end
            pcall(function() exports.MULTIcore:Notify(source, { text = text, type = kind }) end)
        end
        if not target or not GetPlayerName(target) or not State.get(target) then
            return tell(L('cmd_giveitem_no_player'), 'error')
        end
        local def = MultiInv.def(item)
        if not def then return tell(L('cmd_giveitem_unknown', item), 'error') end
        local ok, err = API.AddItem(target, item, amount, nil, nil, 'admin giveitem')
        if ok then
            API.ItemBox(target, item, amount, 'add')
            tell(L('cmd_giveitem_done', amount, def.label or item, GetPlayerName(target)), 'success')
        else
            tell(L('cmd_giveitem_failed', tostring(err)), 'error')
        end
    end, 'admin')
end)

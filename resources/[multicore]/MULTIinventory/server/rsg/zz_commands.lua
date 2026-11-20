-- ============================================================
-- MULTIinventory :: admin commands
--   /giveitem [id] [item] [amount]   give a player any item or weapon (admin)
-- Same name and arguments as rsg-inventory's /giveitem. GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local Inv = MULTIInv

CreateThread(function()
    local core = Inv.Core()
    if not (core and core.Commands and core.Commands.Add) then return end
    core.Commands.Add(Config.GiveItemCommand or 'giveitem', _L('cmd_giveitem'), {
        { name = 'id', help = _L('cmd_giveitem_id') },
        { name = 'item', help = _L('cmd_giveitem_item') },
        { name = 'amount', help = _L('cmd_giveitem_amount') },
    }, true, function(source, args)
        local target = tonumber(args[1])
        local name = tostring(args[2] or ''):lower()
        local amount = math.floor(tonumber(args[3]) or 1)
        local function tell(text, kind)
            if source == 0 then return print(text) end
            exports.MULTIcore:Notify(source, { text = text, type = kind })
        end
        if not target or not GetPlayerName(target) or not Inv.GetPlayer(target) then
            return tell(_L('cmd_giveitem_no_player'), 'error')
        end
        local def = Inv.Items[name] or Inv.Core(true).Shared.Items[name]
        if not def then return tell(_L('cmd_giveitem_unknown', name), 'error') end
        if amount < 1 then amount = 1 end
        if exports.MULTIinventory:AddItem(target, name, amount, nil, nil, 'admin giveitem') then
            tell(_L('cmd_giveitem_done', amount, def.label or name, GetPlayerName(target)), 'success')
        else
            tell(_L('cmd_giveitem_failed'), 'error')
        end
    end, 'admin')
end)

-- MULTItailor - items (RSG Shared.Items shape). MULTIcore ships the tailoring items in its shared/items.lua;
-- this file is the fallback: at start MULTItailor registers any of these the core does not know yet
-- (MBridge.RegisterItems, runtime only). The clothing items themselves (clothing_hat ... clothing_outfit)
-- belong to MULTIinventory.
return {
    tailored_outfit = { name = 'tailored_outfit', label = 'Tailored Outfit', weight = 1500, type = 'item', image = 'tailored_outfit.png',
        unique = true, useable = true, shouldClose = true, description = 'An outfit from before clothing became separate pieces. Use it to unpack it into an outfit bundle.' },
    tailor_licence = { name = 'tailor_licence', label = 'Tailor Licence', weight = 80, type = 'item', image = 'tailor_licence.png',
        unique = true, useable = true, shouldClose = true, description = 'Licence to cut, sew and sell made-to-measure clothing.' },
    npc_garment = { name = 'npc_garment', label = 'Tailored Garment', weight = 600, type = 'item', image = 'npc_garment.png',
        unique = true, useable = true, shouldClose = true, description = 'A single garment cut by a tailor. Use it to put it on.' },
    npc_outfit = { name = 'npc_outfit', label = 'Tailored Outfit Bundle', weight = 2000, type = 'item', image = 'npc_outfit.png',
        unique = true, useable = true, shouldClose = true, description = 'A bundle of garments cut by a tailor. Use it to unpack the garments.' },
    fabric = { name = 'fabric', label = 'Fabric', weight = 200, type = 'item', image = 'fabric.png', description = 'A bolt of plain cotton fabric.' },
    cloth = { name = 'cloth', label = 'Cloth', weight = 150, type = 'item', image = 'cloth.png', description = 'Woollen cloth.' },
    brass_button = { name = 'brass_button', label = 'Brass Button', weight = 5, type = 'item', image = 'brass_button.png', description = 'A brass button.' },
    wool = { name = 'wool', label = 'Wool', weight = 100, type = 'item', image = 'wool.png', description = 'Raw wool, washed and carded.' },
    cotton = { name = 'cotton', label = 'Cotton', weight = 50, type = 'item', image = 'cotton.png', description = 'Raw cotton.' },
    twine = { name = 'twine', label = 'Twine', weight = 50, type = 'item', image = 'twine.png', description = 'A hank of strong twine.' },
    leather = { name = 'leather', label = 'Leather', weight = 300, type = 'item', image = 'leather.png', description = 'A piece of tanned leather.' },
    copper = { name = 'copper', label = 'Copper', weight = 200, type = 'item', image = 'copper.png', description = 'A small copper ingot.' },
    tanned_fur = { name = 'tanned_fur', label = 'Tanned Fur', weight = 400, type = 'item', image = 'tanned_fur.png', description = 'A tanned fur, ready to sew.' },
}

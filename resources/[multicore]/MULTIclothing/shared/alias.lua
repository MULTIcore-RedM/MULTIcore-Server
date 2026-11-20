-- ============================================================
-- MULTIclothing :: export aliases
-- RSG v2 scripts call exports['rsg-wardrobe']:X(). The runtime looks an
-- export up through an event named __cfx_export_<resource>_<export>, so
-- answering that event is enough (same technique as MULTIcore's
-- shared/alias.lua). The fxmanifest also says provide 'rsg-wardrobe'.
-- ============================================================

MCAlias = MCAlias or {}

function MCAlias.ExportAs(resourceName, exportName, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resourceName, exportName), function(setCB)
        setCB(fn)
    end)
end

-- registers fn as exports.MULTIclothing:name and exports['rsg-wardrobe']:name
function MCAlias.Wardrobe(exportName, fn)
    exports(exportName, fn)
    MCAlias.ExportAs('rsg-wardrobe', exportName, fn)
end

-- rsg-wardrobe clothing names (its Config.ClothingComponents 'name' field) -> MULTIcore look categories.
-- Names with no matching look category (sleeve / collar variants) map to nothing and are ignored.
-- MULTIcore category names (hats, gloves ...) are accepted as they are.
MCAlias.WardrobeNames = {
    accessories = { 'accessories' },
    armor = { 'armor' },
    belts = { 'belts' },
    boots = { 'boots' },
    buckles = { 'belt_buckles' },
    chaps = { 'chaps' },
    cloaks = { 'cloaks' },
    closedcoats = { 'coats_closed' },
    coats = { 'coats' },
    eyewear = { 'eyewear' },
    gauntlets = { 'gauntlets' },
    glove = { 'gloves' },
    gunbelts = { 'gunbelts' },
    hair_accessories = { 'hair_accessories' },
    hat = { 'hats' },
    holster_left = { 'holsters_left' },
    holster_right = { 'holsters_right' },
    loadouts = { 'loadouts' },
    masks = { 'masks' },
    neckties = { 'neckties' },
    neckwear = { 'neckwear' },
    pants = { 'pants' },
    ponchos = { 'ponchos' },
    satchels = { 'satchels' },
    shirt = { 'shirts_full' },
    skirts = { 'skirts' },
    suspenders = { 'suspenders' },
    vest = { 'vests' },
    jewelry_rings_left = { 'jewelry_rings_left' },
    jewelry_rings_right = { 'jewelry_rings_right' },
    sleeve = {}, collar1 = {}, collar2 = {},
}

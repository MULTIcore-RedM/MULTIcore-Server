-- ============================================================
-- MULTIemotes: walk styles
-- A walk style is a locomotion archetype (_SET_PED_DESIRED_LOCO_FOR_MODEL,
-- 0x923583741DC87BCE) plus a motion type (_SET_PED_DESIRED_LOCO_MOTION_TYPE,
-- 0x89F5E7ADECCCB49C), both in femga natives.json.
--   rsg  = used exactly so by RSG v2 rsg-radialmenu (same ids, so a character's saved
--          walk style means the same thing in both scripts).
--   game = archetype listed in natives.json as used by the game's own scripts; motion 'normal'
--          as rsg-radialmenu uses it.
-- id     what /walk <id> takes, the saved value, and the locale key 'walk_<id>' for the label.
--        Never rename one in use (characters keep the id in their metadata).
-- Order here is the order in the menu. Remove a line to take a style out.
-- ============================================================

Config.Walkstyles = {
    { id = 'normal',          loco = 'default',              motion = 'normal' }, -- rsg
    { id = 'angry',           loco = 'default',              motion = 'angry' },  -- rsg
    { id = 'war_veteran',     loco = 'war_veteran',          motion = 'normal' }, -- rsg
    { id = 'gold_panner',     loco = 'gold_panner',          motion = 'normal' }, -- rsg
    { id = 'lost_man',        loco = 'lost_Man',             motion = 'normal' }, -- rsg
    { id = 'murfree',         loco = 'murfree',              motion = 'normal' }, -- rsg
    { id = 'primate',         loco = 'primate',              motion = 'normal' }, -- rsg
    { id = 'cowboy',          loco = 'cowboy',               motion = 'normal' }, -- game
    { id = 'cowboy_f',        loco = 'cowboy_f',             motion = 'normal' }, -- game
    { id = 'default_female',  loco = 'default_female',       motion = 'normal' }, -- game
    { id = 'angry_female',    loco = 'angry_female',         motion = 'normal' }, -- game
    { id = 'old_female',      loco = 'old_female',           motion = 'normal' }, -- game
    { id = 'arthur_healthy',  loco = 'arthur_healthy',       motion = 'normal' }, -- game
    { id = 'john_marston',    loco = 'john_marston',         motion = 'normal' }, -- game
    { id = 'mp_ova_hunter',   loco = 'mp_ova_hunter',        motion = 'normal' }, -- game
    { id = 'mp_ova_hunter_f', loco = 'mp_ova_hunter_female', motion = 'normal' }, -- game
    { id = 'guard_lantern',   loco = 'guard_lantern',        motion = 'normal' }, -- game
    { id = 'waiter',          loco = 'waiter',               motion = 'normal' }, -- game
    { id = 'lone_prisoner',   loco = 'lone_prisoner',        motion = 'normal' }, -- game
    { id = 'injured',         loco = 'injured_general',      motion = 'normal' }, -- game
}

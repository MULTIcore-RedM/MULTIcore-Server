-- ============================================================
-- MULTIcore :: gangs (RSG shape)
-- 'none' = not in a gang; keep it. The other gangs are made-up examples
-- (no names from the game): rename, remove or add your own.
--   grades ['0'] .. ['n'] = { name, isboss }; a boss runs the gang menu (MULTIjobs).
-- Gang money lives in the MULTIbank account 'gang_<name>' (MULTIjobs config).
-- Keep the gang names (keys) stable once players are in them.
-- ============================================================
RSGShared = RSGShared or {}

local function ranks()
    return {
        ['0'] = { name = 'Recruit' },
        ['1'] = { name = 'Member' },
        ['2'] = { name = 'Enforcer' },
        ['3'] = { name = 'Lieutenant' },
        ['4'] = { name = 'Boss', isboss = true },
    }
end

RSGShared.Gangs = {
    none = {
        label = 'No Gang',
        grades = {
            ['0'] = { name = 'Unaffiliated' },
        },
    },
    redwater = { label = 'Red Water Riders', grades = ranks() },
    ashford = { label = 'Ashford Boys', grades = ranks() },
    hollowcreek = { label = 'Hollow Creek Gang', grades = ranks() },
    ironbit = { label = 'Iron Bit Outfit', grades = ranks() },
    blackthorn = { label = 'Blackthorn Company', grades = ranks() },
    dustdevils = { label = 'Dust Devils', grades = ranks() },
}

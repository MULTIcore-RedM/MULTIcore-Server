-- ============================================================
-- MULTIdoors :: doors in RSG v2 rsg-doorlock's shape (optional)
-- Moving over from rsg-doorlock? Paste its Config.DoorList here as it is.
-- Entry number k becomes the rule 'rsg_<k>', so rsg-doorlock's events
-- (which name doors by their number in this list) keep working.
-- Each entry's objCoords are matched to a door in data/doors.lua (within
-- Config.RsgDoorMatchDistance); its doorid is used when it is a known door hash.
--   authorizedJobs = { 'vallaw' }   -> jobs = { vallaw = 0 }
--   locked, distance                -> the same
--   doors = { {...}, {...} }        -> a double door
-- Leave the list empty when config/locks.lua has your doors (the default
-- rules there already hold rsg-doorlock's law offices).
-- ============================================================

Config = Config or {}

Config.DoorList = {
    -- {
    --     authorizedJobs = { 'vallaw' },
    --     doorid = 1988748538,
    --     objCoords = vector3(-276.0126, 802.5911, 118.4117),
    --     textCoords = vector3(-276.0126, 802.5911, 119.4117),
    --     objYaw = 10.0,
    --     locked = true,
    --     distance = 3.0,
    -- },
}

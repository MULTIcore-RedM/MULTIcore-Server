-- ============================================================
-- MULTIcoroner settings
-- Based on phils-coroner by Phil (renamed and fitted to MULTIcore with his permission).
-- ============================================================
Config = {}

Config.Locale = ''                  -- language for this script ('de', 'fr' ...); empty = MULTIcore's language (MULTIConfig.Language), else English
Config.Debug = false                -- prints target, access and SQL checks to the console; /coronerdebug (admins) prints a summary

---------------------------------
-- who may perform inquests and read the ledger
---------------------------------
Config.Jobs = {                     -- job names (MULTIcore shared/jobs.lua)
    coroner = true,
    medic = true,
}
Config.JobTypes = {                 -- every job of these types counts too ('leo' = all law jobs)
    leo = true,
}
Config.RequireOnDuty = true         -- true = only players on duty (admins always may)
Config.AdminAce = 'multicoroner.admin' -- this ace (or the 'admin' ace) may always use it: add_ace group.admin multicoroner.admin allow

---------------------------------
-- targeting (MULTItarget, hold Left Alt)
---------------------------------
Config.TargetDistance = 2.5         -- how close you must be to the body
Config.CorpseZoneRadius = 1.8       -- dead NPCs and animals get a small zone so they can be picked even when the ray misses them
Config.CorpseScanDistance = 30.0    -- how far around you dead NPCs and animals are looked for
Config.CorpseLifetime = 300         -- seconds after you first see a body that it can still be examined (0 = no limit)

---------------------------------
-- the report
---------------------------------
Config.Manners = { 'HOMICIDE', 'SUICIDE', 'ACCIDENTAL', 'NATURAL', 'UNDETERMINED' } -- manner of death choices (labels in locales: manner_<CODE>)
Config.MaxReports = 100             -- reports kept; the oldest are dropped (0 = keep all)
Config.ReportsCommand = 'inquests'  -- opens the inquest ledger

-- Copy of a filed report as an item. Anyone holding it can read it and hand it on.
Config.ReportItem = 'coroner_report'
Config.GiveReportItemOnFile = true  -- the coroner gets a copy when the report is filed

---------------------------------
-- location of the remains (found by itself from where the body lies)
---------------------------------
Config.LocationTowns = {            -- add your own settlements; radius = metres overrides Config.LocationTownRadius
    { label = 'Valentine',   coords = vector3(-170.64, 628.58, 113.0) },
    { label = 'Saint Denis', coords = vector3(2688.77, -1459.11, 46.0) },
    { label = 'Blackwater',  coords = vector3(-830.92, -1343.15, 43.67) },
    { label = 'Rhodes',      coords = vector3(1218.83, -1298.03, 76.0) },
    { label = 'Strawberry',  coords = vector3(-1827.5, -437.65, 159.78) },
    { label = 'Annesburg',   coords = vector3(2945.21, 1272.35, 44.0) },
    { label = 'Armadillo',   coords = vector3(-3729.09, -2603.55, -12.94) },
    { label = 'Tumbleweed',  coords = vector3(-5501.2, -2954.32, -1.73) },
    { label = 'Van Horn',    coords = vector3(2891.52, 619.09, 57.72) },
}
Config.LocationTownRadius = 300.0   -- metres from a town centre; further out counts as wilderness
Config.IncludeCoordsInLocation = false -- true = add X / Y after the town name

Config.DatabaseTable = 'multicoroner_reports' -- created by itself on start

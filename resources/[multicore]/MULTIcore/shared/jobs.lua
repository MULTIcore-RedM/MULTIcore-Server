-- ============================================================
-- MULTIcore :: jobs (RSG shape)
-- Every job a script may set. VORP scripts may also set jobs that are not
-- listed here: MULTIcore adds them on the spot (server/multi/jobs.lua).
--
--   label       name players see
--   type        'leo' (law), 'medic' or nil
--   defaultDuty on duty right after login / taking the job
--   offDutyPay  true = paid even when off duty (leave false: no idle pay)
--   grades      ['0'] .. ['n'] = { name, payment, isboss }
--               payment = dollars per paycheck (config.lua RSGConfig.Money.PayCheckTimeOut, 10 min).
--               Wage jobs are paid at 1899 levels per 10-minute paycheck (Ben, 2026-11-18): business jobs $0.20 - $0.40
--               ($1.20 - $2.40 an hour), law, medical and justice $0.30 - $0.50 ($1.80 - $3.00 an hour); no pay for idling.
--               Trade jobs (farmer, miner, hunter ...) pay 0: they earn by selling what they make.
-- Which jobs the job centre offers is set in MULTIjobs' config.lua (Config.PublicJobs).
-- Keep the job names (keys) stable once players hold them.
-- ============================================================
RSGShared = RSGShared or {}
RSGShared.ForceJobDefaultDutyAtLogin = true -- true: Force duty state to jobdefaultDuty | false: set duty state from database last saved
RSGShared.Jobs = {

    unemployed = {
        name = 'unemployed',
        label = 'Civilian',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Unemployed', payment = 0 }, -- RSG paid 3 here; 0 = no money for idling
        },
    },

    ---------------------------------------------------------------- law
    vallaw = {
        name = 'vallaw',
        label = 'Valentine Law Enforcement',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Recruit', payment = 0.30 },
            ['1'] = { name = 'Deputy', payment = 0.40 },
            ['2'] = { name = 'Sheriff', isboss = true, payment = 0.50 },
        },
    },
    rholaw = {
        name = 'rholaw',
        label = 'Rhodes Law Enforcement',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Recruit', payment = 0.30 },
            ['1'] = { name = 'Deputy', payment = 0.40 },
            ['2'] = { name = 'Sheriff', isboss = true, payment = 0.50 },
        },
    },
    blklaw = {
        name = 'blklaw',
        label = 'Blackwater Law Enforcement',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Recruit', payment = 0.30 },
            ['1'] = { name = 'Deputy', payment = 0.40 },
            ['2'] = { name = 'Sheriff', isboss = true, payment = 0.50 },
        },
    },
    strlaw = {
        name = 'strlaw',
        label = 'Strawberry Law Enforcement',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Recruit', payment = 0.30 },
            ['1'] = { name = 'Deputy', payment = 0.40 },
            ['2'] = { name = 'Sheriff', isboss = true, payment = 0.50 },
        },
    },
    stdenlaw = {
        name = 'stdenlaw',
        label = 'Saint Denis Law Enforcement',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Recruit', payment = 0.30 },
            ['1'] = { name = 'Deputy', payment = 0.40 },
            ['2'] = { name = 'Sheriff', isboss = true, payment = 0.50 },
        },
    },
    marshal = {
        name = 'marshal',
        label = 'U.S. Marshals',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Deputy Marshal', payment = 0.30 },
            ['1'] = { name = 'Marshal', payment = 0.40 },
            ['2'] = { name = 'Chief Marshal', isboss = true, payment = 0.50 },
        },
    },
    judge = {
        name = 'judge',
        label = 'County Court',
        type = 'doj',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Court Clerk', payment = 0.30 },
            ['1'] = { name = 'Justice of the Peace', payment = 0.40 },
            ['2'] = { name = 'Judge', isboss = true, payment = 0.50 },
        },
    },

    ---------------------------------------------------------------- medicine and burial
    medic = {
        name = 'medic',
        label = 'Medic',
        type = 'medic',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Recruit', payment = 0.30 },
            ['1'] = { name = 'Trainee', payment = 0.35 },
            ['2'] = { name = 'Doctor',  payment = 0.40 },
            ['3'] = { name = 'Surgeon', payment = 0.45 },
            ['4'] = { name = 'Manager', isboss = true, payment = 0.50 },
        },
    },
    herbalist = {
        name = 'herbalist',
        label = 'Herbalist',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Apprentice', payment = 0 },
            ['1'] = { name = 'Master', payment = 0, isboss = true },
        },
    },
    undertaker = {
        name = 'undertaker',
        label = 'Undertaker',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Gravedigger', payment = 0.20 },
            ['1'] = { name = 'Undertaker', payment = 0.30 },
            ['2'] = { name = 'Mortician', isboss = true, payment = 0.40 },
        },
    },

    ---------------------------------------------------------------- trades and shops
    blacksmith = {
        name = 'blacksmith',
        label = 'Blacksmith',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Apprentice', payment = 0.20 },
            ['1'] = { name = 'Smith', payment = 0.30 },
            ['2'] = { name = 'Master Smith', isboss = true, payment = 0.40 },
        },
    },
    gunsmith = {
        name = 'gunsmith',
        label = 'Gunsmith',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Apprentice', payment = 0.20 },
            ['1'] = { name = 'Gunsmith', payment = 0.30 },
            ['2'] = { name = 'Master Gunsmith', isboss = true, payment = 0.40 },
        },
    },
    butcher = {
        name = 'butcher',
        label = 'Butcher',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Cutter', payment = 0.20 },
            ['1'] = { name = 'Butcher', payment = 0.30 },
            ['2'] = { name = 'Head Butcher', isboss = true, payment = 0.40 },
        },
    },
    generalstore = {
        name = 'generalstore',
        label = 'General Store',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Clerk', payment = 0.20 },
            ['1'] = { name = 'Senior Clerk', payment = 0.30 },
            ['2'] = { name = 'Storekeeper', isboss = true, payment = 0.40 },
        },
    },
    saloon = {
        name = 'saloon',
        label = 'Saloon',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Barback', payment = 0.20 },
            ['1'] = { name = 'Bartender', payment = 0.27 },
            ['2'] = { name = 'Head Bartender', payment = 0.33 },
            ['3'] = { name = 'Saloon Owner', isboss = true, payment = 0.40 },
        },
    },
    stable = {
        name = 'stable',
        label = 'Stables',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Stable Hand', payment = 0.20 },
            ['1'] = { name = 'Groom', payment = 0.30 },
            ['2'] = { name = 'Stable Master', isboss = true, payment = 0.40 },
        },
    },
    banker = {
        name = 'banker',
        label = 'Bank',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Teller', payment = 0.20 },
            ['1'] = { name = 'Head Teller', payment = 0.30 },
            ['2'] = { name = 'Bank Manager', isboss = true, payment = 0.40 },
        },
    },

    ---------------------------------------------------------------- transport and news
    railroad = {
        name = 'railroad',
        label = 'Railroad',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Track Layer', payment = 0.20 },
            ['1'] = { name = 'Brakeman', payment = 0.25 },
            ['2'] = { name = 'Conductor', payment = 0.30 },
            ['3'] = { name = 'Engineer', payment = 0.35 },
            ['4'] = { name = 'Station Master', isboss = true, payment = 0.40 },
        },
    },
    telegraph = {
        name = 'telegraph',
        label = 'Telegraph and Post Office',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Messenger', payment = 0.20 },
            ['1'] = { name = 'Operator', payment = 0.30 },
            ['2'] = { name = 'Postmaster', isboss = true, payment = 0.40 },
        },
    },
    newspaper = {
        name = 'newspaper',
        label = 'Newspaper',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Paperboy', payment = 0.20 },
            ['1'] = { name = 'Reporter', payment = 0.30 },
            ['2'] = { name = 'Editor', isboss = true, payment = 0.40 },
        },
    },

    ---------------------------------------------------------------- land work (earn by selling, no wage)
    rancher = {
        name = 'rancher',
        label = 'Ranch',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Ranch Hand', payment = 0 },
            ['1'] = { name = 'Wrangler', payment = 0 },
            ['2'] = { name = 'Foreman', payment = 0 },
            ['3'] = { name = 'Rancher', isboss = true, payment = 0 },
        },
    },
    farmer = {
        name = 'farmer',
        label = 'Farm',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Farmhand', payment = 0 },
            ['1'] = { name = 'Farmer', payment = 0 },
            ['2'] = { name = 'Landowner', isboss = true, payment = 0 },
        },
    },
    miner = {
        name = 'miner',
        label = 'Mining',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Mucker', payment = 0 },
            ['1'] = { name = 'Miner', payment = 0 },
            ['2'] = { name = 'Mine Foreman', isboss = true, payment = 0 },
        },
    },
    lumberjack = {
        name = 'lumberjack',
        label = 'Lumber Camp',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Logger', payment = 0 },
            ['1'] = { name = 'Feller', payment = 0 },
            ['2'] = { name = 'Camp Boss', isboss = true, payment = 0 },
        },
    },
    fisherman = {
        name = 'fisherman',
        label = 'Fishery',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Deckhand', payment = 0 },
            ['1'] = { name = 'Fisherman', payment = 0 },
            ['2'] = { name = 'Captain', isboss = true, payment = 0 },
        },
    },
    hunter = {
        name = 'hunter',
        label = 'Hunter and Trapper',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Trapper', payment = 0 },
            ['1'] = { name = 'Hunter', payment = 0 },
            ['2'] = { name = 'Master Hunter', isboss = true, payment = 0 },
        },
    },

}

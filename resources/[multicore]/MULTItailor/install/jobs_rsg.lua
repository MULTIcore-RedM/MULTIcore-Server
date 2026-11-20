-- MULTItailor - tailor jobs (RSG shape: grade keys are STRINGS).
-- MULTIcore ships these in its shared/jobs.lua. This file is the fallback: at start MULTItailor adds any
-- of them the core does not know yet (exports['rsg-core']:AddJob, runtime only). A job the core already
-- has is never changed.
-- Grade 4 (Config.Tailor.bossGrade) and every grade flagged isboss run the till / boss office.
-- Pay: MULTIcore business wages, dollars per 10-minute paycheck.
local grades = {
    ['0'] = { name = 'Apprentice', payment = 0.20 },
    ['1'] = { name = 'Journeyman', payment = 0.25 },
    ['2'] = { name = 'Senior Journeyman', payment = 0.30 },
    ['3'] = { name = 'Cutter', payment = 0.35 },
    ['4'] = { name = 'Master Tailor', isboss = true, payment = 0.40 },
}

local function job(label)
    local own = {}
    for k, g in pairs(grades) do own[k] = { name = g.name, payment = g.payment, isboss = g.isboss } end
    return { label = label, type = 'tailor', defaultDuty = true, offDutyPay = false, grades = own }
end

return {
    tailor       = job('Tailor'),
    valtailor    = job('Valentine Tailor'),
    blacktailor  = job('Blackwater Tailor'),
    strawtailor  = job('Strawberry Tailor'),
    rhodestailor = job('Rhodes Tailor'),
    stdentailor  = job('Saint Denis Tailor'),
    tumbletailor = job('Tumbleweed Tailor'),
    armadtailor  = job('Armadillo Tailor'),
    vantailor    = job('Van Horn Tailor'),
    annetailor   = job('Annesburg Tailor'),
}

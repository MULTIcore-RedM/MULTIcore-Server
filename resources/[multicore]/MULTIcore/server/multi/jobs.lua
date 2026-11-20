-- ============================================================
-- MULTIcore :: jobs
-- RSG only accepts jobs listed in shared/jobs.lua; VORP scripts set any
-- job name they like. MULTIcore adds a job (or a missing grade) the
-- moment a script sets it, so both kinds of script work.
-- ============================================================

MULTI.Jobs = {}

--- Makes sure a job and grade exist. Returns the job name in lower case.
function MULTI.Jobs.Ensure(name, grade, label)
    if type(name) ~= 'string' or name == '' then return nil end
    name = name:lower()
    grade = math.floor(tonumber(grade) or 0)
    local job = RSGCore.Shared.Jobs[name]
    if not job then
        job = {
            label = label or (name:sub(1, 1):upper() .. name:sub(2)),
            defaultDuty = true,
            offDutyPay = false,
            grades = {},
        }
        job.grades[tostring(grade)] = { name = 'Grade ' .. grade, payment = 0 }
        RSGCore.Functions.AddJob(name, job)
    elseif not job.grades[tostring(grade)] then
        job.grades[tostring(grade)] = { name = 'Grade ' .. grade, payment = 0 }
        RSGCore.Functions.UpdateJob(name, job)
    end
    return name
end

-- Players whose next job change should not fire the VORP job events (VORP's "flag")
MULTI.Jobs.silent = {}

--- Sets a player's job (and grade / label), creating them if needed.
--- The VORP job events are fired by server/vorp/events.lua, for job
--- changes from either kind of script.
---@param silent boolean? true = don't fire the VORP job-change events
function MULTI.Jobs.Set(Player, name, grade, label, silent)
    grade = math.floor(tonumber(grade) or 0)
    name = MULTI.Jobs.Ensure(name, grade, label)
    if not name then return false end
    local src = Player.PlayerData.source
    if silent and src then MULTI.Jobs.silent[src] = true end
    local ok = Player.Functions.SetJob(name, grade)
    if src then MULTI.Jobs.silent[src] = nil end
    if not ok then return false end
    if label then
        Player.PlayerData.job.label = label
        Player.Functions.UpdatePlayerData()
    end
    return true
end

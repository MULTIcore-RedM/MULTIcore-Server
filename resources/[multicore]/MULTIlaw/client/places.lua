-- ============================================================
-- MULTIlaw :: offices, bounty boards, blips
-- Law office (law only): records, evidence locker, post a bounty,
-- the bounty board. Bounty board (everyone): the wanted posters.
-- ============================================================

local RSGCore = LawC.Core()
local blips, zones, prompts = {}, {}, {}

local function addBlip(coords, sprite, name)
    local blip = BlipAddForCoords(Config.Blips.Style, coords.x, coords.y, coords.z)
    SetBlipSprite(blip, joaat(sprite), true)
    SetBlipScale(blip, Config.Blips.Scale)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, name) -- _SET_BLIP_NAME
    blips[#blips + 1] = blip
end

---------------------------------
-- office menu
---------------------------------
function LawC.PostBountyDialog()
    local input = lib.inputDialog(_L('bounty_title'), {
        { type = 'input', label = _L('bounty_target'), description = _L('bounty_target_help'), required = true, max = 50 },
        { type = 'number', label = _L('bounty_reward', ('%.2f'):format(Config.Bounty.Max)), required = true, min = Config.Bounty.Min, max = Config.Bounty.Max, precision = 2, step = 1 },
        { type = 'input', label = _L('reason'), required = true, max = Config.Bounty.ReasonLength },
    })
    if not input then return end
    local res = lib.callback.await('MULTIlaw:bounty:post', false, { target = input[1], reward = input[2], reason = input[3] })
    LawC.say(type(res) == 'table' and res or { ok = false, msg = _L('failed') })
end

function LawC.OfficeMenu()
    if not LawC.IsLaw() then return LawC.notify(_L('not_law'), 'error') end
    local options = {}
    if LawC.Can('records') then options[#options + 1] = { title = _L('office_records'), onSelect = function() LawC.OpenPage('records') end } end
    if LawC.Can('evidence') then
        options[#options + 1] = { title = _L('office_evidence'), onSelect = function()
            CreateThread(function() LawC.say(lib.callback.await('MULTIlaw:office:evidence', false)) end)
        end }
    end
    if LawC.Can('bounty') then options[#options + 1] = { title = _L('office_post_bounty'), onSelect = function() CreateThread(LawC.PostBountyDialog) end } end
    options[#options + 1] = { title = _L('office_board'), onSelect = function() LawC.OpenPage('board') end }
    if not LawC.Can('records') and not LawC.Can('bounty') then
        options[#options + 1] = { title = _L('off_duty'), disabled = true }
    end
    lib.registerContext({ id = 'multilaw_office', title = _L('office_title'), options = options })
    lib.showContext('multilaw_office')
end

RegisterNetEvent('MULTIlaw:client:office', function() CreateThread(LawC.OfficeMenu) end)
RegisterNetEvent('MULTIlaw:client:board', function() LawC.OpenPage('board') end)

---------------------------------
-- points
---------------------------------
-- Config.Interact 'auto' / 'target' / 'prompt' (see @MULTIcore/lib/interact.lua)
local interactMode = nil    -- 'target' or 'prompt' once MCI.Run has decided

local function addPoint(id, coords, label, event, icon, canUse)
    if interactMode == 'target' then
        zones[#zones + 1] = MCI.AddZone({
            coords = coords, radius = Config.TargetRadius,
            options = { { name = id, label = label, icon = icon, distance = Config.TargetDistance, canInteract = canUse,
                onSelect = function() TriggerEvent(event) end } },
        })
        return
    end
    MCI.AddPrompt(id, coords, Config.PromptKey, label, { type = 'client', event = event }, Config.PromptDistance)
    prompts[#prompts + 1] = id
end

-- office prompts only for the law (prompt mode); boards for everyone
local function refreshOffices()
    if interactMode ~= 'prompt' then return end
    for _, id in ipairs(prompts) do MCI.RemovePrompt(id) end
    prompts = {}
    local job = LawC.pdata().job or {}
    local law = LawC.IsLaw()
    -- boards: a lawman reaches the board through the office menu, so a board at an office is not doubled for him
    for i, b in ipairs(Config.Boards) do
        local atOffice = false
        for _, o in ipairs(Config.Offices) do
            if #(o.coords - b.coords) < 1.5 and (Config.OfficesOpenToAllLaw or o.job == job.name) then atOffice = true end
        end
        if not (law and atOffice) then
            addPoint('multilaw_board_' .. i, b.coords, _L('prompt_board'), 'MULTIlaw:client:board')
        end
    end
    if not law then return end
    for _, o in ipairs(Config.Offices) do
        if Config.OfficesOpenToAllLaw or o.job == job.name then
            addPoint('multilaw_office_' .. o.id, o.coords, _L('prompt_office'), 'MULTIlaw:client:office')
        end
    end
end

MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    if mode ~= 'target' then
        -- the resource may start (or restart) while the player is already in the world
        refreshOffices()
        return
    end
    -- target mode: one sphere per board (everyone) and per office (canInteract: the office's law job)
    for i, b in ipairs(Config.Boards) do
        addPoint('multilaw_board_' .. i, b.coords, _L('prompt_board'), 'MULTIlaw:client:board', Config.TargetIcons.board)
    end
    for _, o in ipairs(Config.Offices) do
        addPoint('multilaw_office_' .. o.id, o.coords, _L('prompt_office'), 'MULTIlaw:client:office', Config.TargetIcons.office, function()
            local job = LawC.pdata().job or {}
            return LawC.IsLaw() and (Config.OfficesOpenToAllLaw or job.name == o.job)
        end)
    end
end, function(mode)
    interactMode = nil
    for _, z in ipairs(zones) do MCI.RemoveZone(z) end
    zones = {}
    for _, id in ipairs(prompts) do MCI.RemovePrompt(id) end
    prompts = {}
end)

-- blips (do not depend on the interaction mode)
CreateThread(function()
    for _, b in ipairs(Config.Boards) do
        if Config.Blips.Boards then addBlip(b.coords, Config.Blips.BoardSprite, _L('blip_board')) end
    end
    for _, o in ipairs(Config.Offices) do
        if Config.Blips.Offices then addBlip(o.coords, Config.Blips.OfficeSprite, _L('blip_office')) end
    end
    if Config.Blips.Prison then addBlip(Config.Prison.blip, Config.Blips.PrisonSprite, _L(Config.Prison.label)) end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() SetTimeout(1000, refreshOffices) end)
RegisterNetEvent('RSGCore:Client:OnJobUpdate', function() SetTimeout(250, refreshOffices) end)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() SetTimeout(250, refreshOffices) end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    for _, id in ipairs(prompts) do MCI.RemovePrompt(id) end
    -- MULTItarget drops this script's zones by itself when it stops
end)

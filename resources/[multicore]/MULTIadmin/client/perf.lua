-- ============================================================
-- MULTIadmin :: client - performance sample (Performance page)
-- Only the server asks (an admin picked this player). For a few seconds the
-- game's own frame time is read every frame; the result goes back to the server.
-- Scripts cannot read per-resource times on a PC (resmon is a console tool),
-- so this is the whole PC: frames per second, average and slowest frames,
-- and the names of the resources running here.
-- Natives: GET_FRAME_TIME 0x5E72022914CE3C38 (femga natives.json, float seconds);
-- GET_NUM_RESOURCES, GET_RESOURCE_BY_FIND_INDEX, GET_RESOURCE_STATE (CFX shared natives).
-- ============================================================

local GET_FRAME_TIME = 0x5E72022914CE3C38
local sampling = false

lib.callback.register('MULTIadmin:perfSample', function(seconds, slowMs)
    if sampling then return nil end
    sampling = true
    seconds = math.max(1, math.min(30, tonumber(seconds) or 5))
    slowMs = tonumber(slowMs) or 33.4
    local times = {}
    local sum, maxMs, slow = 0, 0, 0
    local stopAt = GetGameTimer() + seconds * 1000
    local startedAt = GetGameTimer()
    while GetGameTimer() < stopAt do
        Wait(0)
        local ms = (Citizen.InvokeNative(GET_FRAME_TIME, Citizen.ResultAsFloat()) or 0) * 1000.0
        if ms > 0 then
            times[#times + 1] = ms
            sum = sum + ms
            if ms > maxMs then maxMs = ms end
            if ms >= slowMs then slow = slow + 1 end
        end
    end
    local n = #times
    table.sort(times, function(a, b) return a > b end)
    local worstN = math.max(1, math.floor(n / 100))
    local worst = 0
    for i = 1, math.min(worstN, n) do worst = worst + times[i] end
    local elapsed = (GetGameTimer() - startedAt) / 1000
    local list = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then list[#list + 1] = name end
    end
    sampling = false
    return {
        frames = n, seconds = elapsed,
        fps = elapsed > 0 and n / elapsed or 0,
        avgMs = n > 0 and sum / n or 0,
        worstMs = n > 0 and worst / math.min(worstN, n) or 0,
        maxMs = maxMs, slowFrames = slow,
        resources = list,
    }
end)

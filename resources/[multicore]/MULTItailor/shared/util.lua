--[[
    TU - small shared helpers (client + server, also loaded by tests/harness.lua).
      TU.finite(n)               -> number | nil   (nil for NaN / inf / non-numbers)  -- nan guard
      TU.int(n, lo, hi)          -> integer | nil  (clamped)
      TU.clamp(n, lo, hi)        -> number | nil
      TU.money(n)                -> number rounded to cents | nil
      TU.text(s, max)            -> cleaned single-line text | nil
      TU.copy(t)                 -> deep copy
      TU.debug(fmt, ...)
]]
TU = TU or {}

function TU.finite(n)
    n = tonumber(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

function TU.clamp(n, lo, hi)
    n = TU.finite(n)
    if not n then return nil end
    if lo and n < lo then n = lo end
    if hi and n > hi then n = hi end
    return n
end

function TU.int(n, lo, hi)
    n = TU.clamp(n, lo, hi)
    if not n then return nil end
    return math.floor(n)
end

function TU.money(n)
    n = TU.finite(n)
    if not n then return nil end
    return math.floor(n * 100 + 0.5) / 100
end

function TU.text(s, max)
    if type(s) ~= 'string' and type(s) ~= 'number' then return nil end
    s = tostring(s):gsub('[%c<>"\\]', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if s == '' then return nil end
    max = max or 64
    if #s > max then s = s:sub(1, max) end
    return s
end

function TU.copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = TU.copy(v) end
    return o
end

function TU.debug(fmt, ...)
    if not (Config and Config.Debug) then return end
    local ok, msg = pcall(string.format, fmt, ...)
    print(('[MULTItailor] %s'):format(ok and msg or tostring(fmt)))
end

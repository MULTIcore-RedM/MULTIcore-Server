-- MULTIimages: picture copy for the stand-ins (vorp_inventory, rsg-inventory, redemrp_inventory,
-- RINGOinventory). Not run by MULTIimages itself: each stand-in loads this file with
--     server_script '@MULTIimages/server/standin.lua'
-- and names its picture folder in its fxmanifest:
--     multicore_pictures 'html/img/items'
--
-- Scripts written for other frameworks load item pictures from their own inventory's folder, for
-- example nui://vorp_inventory/html/img/items/bread.png. A nui:// address only reaches a resource
-- with exactly that name, so each stand-in carries the name and keeps a copy of the pictures.
-- When the stand-in starts, this copies MULTIimages/images into its picture folder: new and changed
-- pictures are written, pictures no longer in MULTIimages are removed. The copy is finished before
-- the stand-in's files are packed for players, so they get the current pictures on joining.
-- (A server script may only write inside its own resource, which is why the copy runs here and
-- not in MULTIimages.) Owners only ever change MULTIimages/images.

local RES = GetCurrentResourceName()
local EXT = { png = true, webp = true }

local function windows(path)
    return path:match('^%a:') ~= nil
end

local function quoteWin(path) return '"' .. path:gsub('/', '\\') .. '"' end
local function quoteSh(path) return "'" .. path:gsub("'", "'\\''") .. "'" end

---The picture files (.png / .webp) in a folder, as a set { [name] = true }; nil when it cannot be read.
local function listPictures(dir)
    local cmd = windows(dir) and ('dir /b /a-d ' .. quoteWin(dir) .. ' 2>nul')
        or ('ls -1A ' .. quoteSh(dir) .. ' 2>/dev/null')
    local ok, h = pcall(io.popen, cmd)
    if not ok or not h or not h.lines then return nil end
    local set = {}
    for line in h:lines() do
        line = line:gsub('[\r\n]+$', '')
        local ext = line:match('%.(%w+)$')
        if ext and EXT[ext:lower()] then set[line] = true end
    end
    h:close()
    return set
end

local function readFile(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local data = f:read('a')
    f:close()
    return data
end

local function writeFile(path, data)
    local f, err = io.open(path, 'wb')
    if not f then return false, err end
    f:write(data)
    f:close()
    return true
end

local function makeDir(dir)
    if windows(dir) then
        os.execute('if not exist ' .. quoteWin(dir) .. ' mkdir ' .. quoteWin(dir))
    else
        os.execute('mkdir -p ' .. quoteSh(dir))
    end
end

local function copy()
    local folder = GetResourceMetadata(RES, 'multicore_pictures', 0)
    local srcRoot = GetResourcePath('MULTIimages')
    local ownRoot = GetResourcePath(RES)
    if not folder or folder:find('%.%.') or not ownRoot or ownRoot == '' then return end
    if not srcRoot or srcRoot == '' then
        print(('[%s] MULTIimages is missing - no item pictures for scripts that look in %s'):format(RES, folder))
        return
    end
    folder = folder:gsub('^/+', ''):gsub('/+$', '')
    local srcDir, dstDir = srcRoot .. '/images', ownRoot .. '/' .. folder

    local pictures = listPictures(srcDir)
    if not pictures then
        print(('[%s] could not list MULTIimages/images - pictures not refreshed'):format(RES))
        return
    end
    makeDir(dstDir)
    local have = listPictures(dstDir) or {}

    local added, updated, removed, failed, firstError = 0, 0, 0, 0, nil
    for name in pairs(pictures) do
        local data = readFile(srcDir .. '/' .. name)
        if data and (not have[name] or readFile(dstDir .. '/' .. name) ~= data) then
            local ok, err = writeFile(dstDir .. '/' .. name, data)
            if ok then
                if have[name] then updated = updated + 1 else added = added + 1 end
            else
                failed = failed + 1
                firstError = firstError or err
            end
        end
    end
    for name in pairs(have) do
        if not pictures[name] and os.remove(dstDir .. '/' .. name) then removed = removed + 1 end
    end

    if added + updated + removed + failed > 0 then
        print(('[%s] item pictures from MULTIimages: %d added, %d updated, %d removed%s'):format(RES, added, updated, removed,
            failed > 0 and (', ' .. failed .. ' could not be written (' .. tostring(firstError) .. ')') or ''))
    end
end

local ok, err = pcall(copy)
if not ok then print(('[%s] item picture copy failed: %s'):format(RES, tostring(err))) end

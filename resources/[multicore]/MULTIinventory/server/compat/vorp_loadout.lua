--[[
    VORP `loadout` table mirror.

    VORP scripts that read a player's guns straight from the database
    (SELECT ... FROM loadout WHERE charidentifier = ?) found nothing on MULTIcore: the table is
    there (MULTIcore creates it) but weapons live in multiinv_weapons. Gunsmith scripts then showed
    an empty weapon list.

    This file keeps `loadout` in step for every character that is online:
      - each weapon in the character's own inventory gets a `loadout` row with the same id
        (name, ammo, comps, label, serial, custom label / description, used);
      - a weapon that leaves the character loses its row;
      - a script that writes `comps`, `custom_label` or `custom_desc` into a row
        (UPDATE loadout SET comps = ? WHERE id = ?) has that change applied to the weapon.

    multiinv_loadout_mirror remembers which `loadout` rows this file wrote and what it wrote, so it
    never removes rows it did not make and can tell a script's change from its own.
    Config.Compat.vorpLoadout = false turns it off; Config.Compat.vorpLoadoutSeconds sets the check interval.
]]

local active = false
local hasCharacters = false   -- VORP-shaped `characters` table (MULTIcore creates it)
local running, again = false, false
local MIRROR_SQL = [[
CREATE TABLE IF NOT EXISTS `multiinv_loadout_mirror` (
  `id`           INT          NOT NULL PRIMARY KEY,
  `charid`       INT          NOT NULL,
  `sig`          LONGTEXT     NOT NULL,
  `comps`        LONGTEXT     NOT NULL,
  `custom_label` VARCHAR(50)  NULL,
  `custom_desc`  VARCHAR(50)  NULL,
  KEY `idx_charid` (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local function compatCfg() return Config.Compat or {} end

local function cut(s, n)
    if s == nil then return nil end
    s = tostring(s)
    if s == '' then return nil end
    return #s > n and s:sub(1, n) or s
end

-- same map -> same text, whatever order pairs() gives
local function canonMap(t)
    if type(t) ~= 'table' then return '{}' end
    local keys = {}
    for k, v in pairs(t) do
        if (type(k) == 'string' or type(k) == 'number') and (type(v) == 'string' or type(v) == 'number') then
            keys[#keys + 1] = tostring(k)
        end
    end
    if #keys == 0 then return '{}' end
    table.sort(keys)
    local parts = {}
    for i, k in ipairs(keys) do
        local v = t[k]
        if v == nil then v = t[tonumber(k)] end
        parts[i] = json.encode(k) .. ':' .. json.encode(v)
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

local function arrayJson(t, max)
    if type(t) ~= 'table' or t[1] == nil then return '[]' end
    local ok, s = pcall(json.encode, t)
    if not ok or #s > max then return '[]' end
    return s
end

local function isArray(t)
    if type(t) ~= 'table' then return false end
    return t[1] ~= nil
end

local function rowOf(r, charId, identifier)
    local def = WeaponDefs.get(r.name) or {}
    local ammo = canonMap(r.ammo)
    if #ammo > 255 then ammo = '{}' end
    return {
        id = r.id, identifier = identifier or '', charid = charId, name = r.name,
        ammo = ammo, components = arrayJson(r.components, 255), comps = canonMap(r.comps),
        dirt = r.dirt or 0, mud = r.soot or 0, cond = r.degradation or 0, rust = r.damage or 0,
        used = r.equipped and 1 or 0, used2 = r.equipped == 'left' and 1 or 0,
        label = cut(r.label or def.label or r.name, 50), serial = cut(r.serial, 50),
        clabel = cut(r.customLabel, 50), cdesc = cut(r.customDesc, 50),
    }
end

local function sigOf(row)
    return table.concat({ row.charid, row.identifier, row.name, row.ammo, row.components, row.comps,
        ('%.3f/%.3f/%.3f/%.3f'):format(row.dirt, row.mud, row.cond, row.rust), row.used, row.used2,
        row.label or '', row.serial or '', row.clabel or '', row.cdesc or '' }, '|')
end

local UPSERT = [[INSERT INTO `loadout` (`id`, `identifier`, `charidentifier`, `name`, `ammo`, `components`, `comps`,
  `dirtlevel`, `mudlevel`, `conditionlevel`, `rustlevel`, `used`, `used2`, `dropped`, `label`, `curr_inv`,
  `serial_number`, `custom_label`, `custom_desc`)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, %s, 'default', %s, %s, %s)
ON DUPLICATE KEY UPDATE `identifier` = VALUES(`identifier`), `charidentifier` = VALUES(`charidentifier`),
  `name` = VALUES(`name`), `ammo` = VALUES(`ammo`), `components` = VALUES(`components`), `comps` = VALUES(`comps`),
  `dirtlevel` = VALUES(`dirtlevel`), `mudlevel` = VALUES(`mudlevel`), `conditionlevel` = VALUES(`conditionlevel`),
  `rustlevel` = VALUES(`rustlevel`), `used` = VALUES(`used`), `used2` = VALUES(`used2`), `dropped` = 0,
  `label` = VALUES(`label`), `curr_inv` = 'default', `serial_number` = VALUES(`serial_number`),
  `custom_label` = VALUES(`custom_label`), `custom_desc` = VALUES(`custom_desc`)]]

local MIRROR_UPSERT = [[INSERT INTO `multiinv_loadout_mirror` (`id`, `charid`, `sig`, `comps`, `custom_label`, `custom_desc`)
VALUES (?, ?, ?, ?, %s, %s)
ON DUPLICATE KEY UPDATE `charid` = VALUES(`charid`), `sig` = VALUES(`sig`), `comps` = VALUES(`comps`),
  `custom_label` = VALUES(`custom_label`), `custom_desc` = VALUES(`custom_desc`)]]

-- a nullable value as '?' (param appended) or NULL: oxmysql parameter lists must not have holes
local function opt(v, params)
    if v == nil then return 'NULL' end
    params[#params + 1] = v
    return '?'
end

local function writeRow(row, sig)
    local p = { row.id, row.identifier, row.charid, row.name, row.ammo, row.components, row.comps,
                row.dirt, row.mud, row.cond, row.rust, row.used, row.used2 }
    local sql = UPSERT:format(opt(row.label, p), opt(row.serial, p), opt(row.clabel, p), opt(row.cdesc, p))
    local m = { row.id, row.charid, sig, row.comps }
    local msql = MIRROR_UPSERT:format(opt(row.clabel, m), opt(row.cdesc, m))
    return { { query = sql, values = p }, { query = msql, values = m } }
end

-- a script changed the row: bring the weapon in step and remember the row as it now is
local function pickUp(r, m)
    local changed = false
    if m.lc ~= nil and m.lc ~= m.mc then
        local t = Util.jsonDecode(m.lc, nil)
        if type(t) == 'table' and not isArray(t) then
            Weapons.setComps(r.id, t)
            changed = true
        end
    end
    if m.lid ~= nil and (m.ll or '') ~= (m.ml or '') then
        Weapons.setCustomLabel(r.id, m.ll)
        changed = true
    end
    if m.lid ~= nil and (m.ld or '') ~= (m.md or '') then
        Weapons.setCustomDesc(r.id, m.ld)
        changed = true
    end
    return changed
end

local function sync()
    if not active then return end
    local online = {}
    local ids = {}
    for src, st in pairs(State.all()) do
        if st.charId then online[st.charId] = st; ids[#ids + 1] = st.charId end
    end
    if #ids == 0 then return end
    if not Weapons.ensureLoaded() then return end

    local marks = {}
    for i = 1, #ids do marks[i] = '?' end
    local rows = InvDB.query(([[SELECT m.id, m.charid, m.sig, m.comps AS mc, m.custom_label AS ml, m.custom_desc AS md,
        l.id AS lid, l.comps AS lc, l.custom_label AS ll, l.custom_desc AS ld
        FROM `multiinv_loadout_mirror` m LEFT JOIN `loadout` l ON l.id = m.id
        WHERE m.charid IN (%s)]]):format(table.concat(marks, ',')), ids)

    local mirror = {}
    for _, m in ipairs(rows) do mirror[tonumber(m.id)] = m end

    -- the identifier VORP scripts get from Character.identifier (MULTIcore keeps `characters` in step;
    -- it is the steam id when the player has one, not the licence the inventory knows)
    local ident = {}
    for _, c in ipairs(not hasCharacters and {} or InvDB.query(('SELECT `charidentifier`, `identifier` FROM `characters` WHERE `charidentifier` IN (%s)')
            :format(table.concat(marks, ',')), ids)) do
        if c.identifier and c.identifier ~= '' then ident[tonumber(c.charidentifier)] = c.identifier end
    end

    -- 1. changes scripts wrote into `loadout`
    for id, m in pairs(mirror) do
        local r = Weapons.get(id)
        if r and m.lid ~= nil and r.owner == tonumber(m.charid) and r.container == 'player:' .. tostring(m.charid) then
            if pickUp(r, m) then m.sig = '' end   -- write the row again below
        end
    end

    -- 2. the weapons each character holds now
    local list, keep = {}, {}
    for charId, st in pairs(online) do
        for _, r in ipairs(Weapons.recordsIn('player:' .. charId)) do
            keep[r.id] = true
            local row = rowOf(r, charId, ident[charId] or st.identifier)
            local sig = sigOf(row)
            local m = mirror[r.id]
            if not m or m.sig ~= sig or m.lid == nil then
                for _, q in ipairs(writeRow(row, sig)) do list[#list + 1] = q end
            end
        end
    end

    -- 3. rows of weapons that left the character
    for id in pairs(mirror) do
        if not keep[id] then
            list[#list + 1] = { query = 'DELETE FROM `loadout` WHERE `id` = ?', values = { id } }
            list[#list + 1] = { query = 'DELETE FROM `multiinv_loadout_mirror` WHERE `id` = ?', values = { id } }
        end
    end

    if #list > 0 then InvDB.transaction(list) end
end

local function runSync()
    if not active then return end
    if running then again = true return end
    running = true
    repeat
        again = false
        local ok, err = pcall(sync)
        if not ok then print(('^1[MULTIinventory] loadout mirror: %s^7'):format(tostring(err))) end
    until not again
    running = false
end

-- right after a change, so a script that reads `loadout` straight away sees it
local queued = false
local function soon()
    if not active or queued then return end
    queued = true
    SetTimeout(150, function()
        queued = false
        runSync()
    end)
end

CreateThread(function()
    if compatCfg().vorpLoadout == false then return end
    InvDB.awaitReady()
    local has = InvDB.scalar([[SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = 'loadout']])
    if (tonumber(has) or 0) == 0 then return end   -- no VORP-shaped tables (MULTIcore creates them)
    hasCharacters = (tonumber(InvDB.scalar([[SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = 'characters']])) or 0) > 0
    InvDB.update(MIRROR_SQL)
    active = true
    local wait = math.max(1, tonumber(compatCfg().vorpLoadoutSeconds) or 2) * 1000
    while true do
        runSync()
        Wait(wait)
    end
end)

InvHooks.register('characterLoaded', function() soon() end)
InvHooks.register('weaponCreated', function() soon() end)
InvHooks.register('weaponDeleted', function() soon() end)
AddEventHandler('MULTIinventory:weaponComponentsChanged', function() soon() end)
AddEventHandler('MULTIinventory:weaponEquipped', function() soon() end)
AddEventHandler('MULTIinventory:weaponHolstered', function() soon() end)

---Sync now (blocks until the rows are written). Returns false when the mirror is off.
VorpLoadout = { sync = function() if not active then return false end runSync() return true end }

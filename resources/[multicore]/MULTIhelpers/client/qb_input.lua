-- ============================================================
-- MULTIhelpers :: QB-style input dialog
-- (stands in for rsg-input, qb-input, qbr-input and fx-input: one API)
--
--   local result = exports['rsg-input']:ShowInput({
--       header = 'Give money', submitText = 'Give',
--       inputs = {
--           { text = 'Player id', name = 'id', type = 'number', isRequired = true },
--           { text = 'Note', name = 'note', type = 'text' },
--           { text = 'Pay with', name = 'kind', type = 'radio', options = {
--               { value = 'cash', text = 'Cash', checked = true }, { value = 'gold', text = 'Gold' } } },
--       },
--   })
--   -- result = { id = '3', note = '', kind = 'cash' }, or nil when the player closes it
--
-- Types: text, password, number, radio, select, checkbox (result = list of ticked
-- values), color. Drawn with MULTIcore's input dialog (exports.MULTIcore:inputDialog),
-- so it follows the UI presets. Own code, written from the public API description.
-- GPL v3, part of MULTIcore.
-- ============================================================

local NAMES = { 'rsg-input', 'qb-input', 'qbr-input', 'fx-input' }

local function str(v)
    if v == nil then return nil end
    -- 3.0 from the page reads as '3', as the original's form gives it
    if math.type(v) == 'float' and v == math.floor(v) and math.abs(v) < 2^53 then
        return ('%d'):format(v)
    end
    return tostring(v)
end

--- one QB input row -> one MULTIcore dialog row
local function toRow(i)
    local t = type(i.type) == 'string' and i.type:lower() or 'text'
    local row = {
        label = str(i.text or i.label) or '',
        required = i.isRequired and true or false,
        icon = type(i.icon) == 'string' and i.icon or nil,   -- fx-input
        default = i.default,
    }
    if t == 'number' then
        row.type = 'number'
        row.default = tonumber(i.default)
        row.min, row.max, row.step = tonumber(i.min), tonumber(i.max), tonumber(i.step)
    elseif t == 'password' then
        row.type, row.password = 'input', true
    elseif t == 'color' then
        row.type = 'color'
    elseif t == 'radio' or t == 'select' or t == 'checkbox' then
        row.type = t == 'checkbox' and 'multi-select' or 'select'
        row.options = {}
        local ticked = {}
        for _, o in ipairs(type(i.options) == 'table' and i.options or {}) do
            if type(o) == 'table' then
                row.options[#row.options + 1] = { value = o.value, label = str(o.text or o.label or o.value) }
                if o.checked then ticked[#ticked + 1] = o.value end
            end
        end
        if t == 'checkbox' then
            row.default = ticked
        elseif row.default == nil then
            row.default = ticked[1]
        end
        -- a radio always has one picked, like the original
        if t == 'radio' then
            row.required = true
            if row.default == nil and row.options[1] then row.default = row.options[1].value end
        end
    else
        row.type = 'input'
        row.placeholder = str(i.text)
    end
    return row, t
end

local function showInput(dialog)
    if type(dialog) ~= 'table' then return nil end
    local rows, kinds, names = {}, {}, {}
    for _, i in ipairs(type(dialog.inputs) == 'table' and dialog.inputs or {}) do
        if type(i) == 'table' then
            local row, t = toRow(i)
            rows[#rows + 1] = row
            kinds[#rows] = t
            names[#rows] = i.name ~= nil and tostring(i.name) or tostring(#rows)
        end
    end
    if #rows == 0 then return nil end

    local values = exports.MULTIcore:inputDialog(str(dialog.header) or '', rows)
    if type(values) ~= 'table' then return nil end

    -- QB scripts get strings keyed by name; checkboxes give the list of ticked values
    local out = {}
    for n = 1, #rows do
        local v = values[n]
        if kinds[n] == 'checkbox' then
            local list = {}
            if type(v) == 'table' then
                for _, x in ipairs(v) do list[#list + 1] = str(x) end
            end
            out[names[n]] = list
        elseif v == nil then
            out[names[n]] = ''
        else
            out[names[n]] = str(v)
        end
    end
    return out
end

Helpers.Export('ShowInput', showInput, NAMES)

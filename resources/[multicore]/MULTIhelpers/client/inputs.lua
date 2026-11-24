-- ============================================================
-- MULTIhelpers :: input box (stands in for vorp_inputs)
--
--   local text = exports.vorp_inputs:advancedInput(myInput)     -- waits, returns text or nil
--   local text = exports.vorp_inputs:getInput(button, placeholder) -- waits, returns text or nil
--   TriggerEvent('vorpinputs:advancedInput', json.encode(myInput), function(text) end)
--   TriggerEvent('vorpinputs:getInput', button, placeholder, function(text) end)
--
-- myInput = {
--   type = 'enableinput', style = 'block',         -- fixed values, ignored
--   inputType = 'input' | 'textarea',
--   button = 'Confirm', placeholder = 'NAME QUANTITY',
--   attributes = {
--     inputHeader = 'GIVE ITEM',
--     type = 'text' | 'number' | 'date' | 'password' | 'textarea',
--     pattern = '[0-9]', title = 'numbers only',  -- HTML pattern + message when it fails
--     min, max, step, minlength, maxlength, value, -- plain HTML input attributes
--     style = 'css',                              -- used only with Config AllowCustomStyle
--   },
-- }
-- Cancelling (Esc / close) gives Config.Inputs.CancelResult ('' by default, like VORP).
--
-- Written from VORP's public docs (docs.vorp-core.com/api-reference/inputs and the
-- vorp_inputs README) and from how scripts call it. No VORP code is used.
-- ============================================================

local Cfg = Config.Inputs

local function cancelValue(result)
    if result == nil then return Cfg.CancelResult end
    return result
end

--- Turn a vorp_inputs table (or its JSON string) into a dialog spec.
local function toSpec(input)
    if type(input) == 'string' then
        local ok, decoded = pcall(json.decode, input)
        input = ok and decoded or nil
    end
    input = type(input) == 'table' and input or {}
    local a = type(input.attributes) == 'table' and input.attributes or {}
    local itype = a.type
    if input.inputType == 'textarea' then itype = 'textarea' end
    return {
        kind = 'input',
        header = a.inputHeader or input.header,
        placeholder = input.placeholder,
        button = input.button,             -- nil = the locale's Confirm
        inputType = itype or 'text',
        pattern = a.pattern,
        title = a.title,
        min = a.min, max = a.max, step = a.step,
        minLength = a.minlength or a.minLength,
        maxLength = a.maxlength or a.maxLength,
        value = a.value,
        style = Cfg.AllowCustomStyle and a.style or nil,
    }
end

local function ask(spec, owner)
    local p = promise.new()
    Helpers.OpenDialog(spec, function(result) p:resolve(result) end, owner)
    return cancelValue(Citizen.Await(p))
end

local function askAsync(spec, owner, cb)
    Helpers.OpenDialog(spec, function(result)
        if cb then Helpers.SafeCall(cb, cancelValue(result)) end
    end, owner)
end

local function simpleSpec(button, placeholder, inputType)
    return {
        kind = 'input',
        placeholder = placeholder,
        button = button,
        inputType = inputType or 'text',
    }
end

-- ------------------------------------------------------------ exports
Helpers.Export('advancedInput', function(input)
    return ask(toSpec(input), GetInvokingResource())
end, { 'vorp_inputs' })

Helpers.Export('getInput', function(button, placeholder, inputType)
    return ask(simpleSpec(button, placeholder, inputType), GetInvokingResource())
end, { 'vorp_inputs' })

-- ------------------------------------------------------------ events (callback style)
AddEventHandler('vorpinputs:advancedInput', function(input, cb)
    askAsync(toSpec(input), GetInvokingResource(), cb)
end)

AddEventHandler('vorpinputs:getInput', function(button, placeholder, cb)
    askAsync(simpleSpec(button, placeholder), GetInvokingResource(), cb)
end)

-- TriggerEvent('vorpinputs:getInputsWithInputType', button, placeholder, 'number', function(text) end)
AddEventHandler('vorpinputs:getInputsWithInputType', function(button, placeholder, inputType, cb)
    askAsync(simpleSpec(button, placeholder, inputType), GetInvokingResource(), cb)
end)

-- ------------------------------------------------------------ gum_inputs
--   TriggerEvent('guminputs:getInput', buttonText, placeholder, function(value) end)
--     value = the typed text, or the string 'close' when the player cancels
--   TriggerEvent('guminputs:getAnswer', question, yesText, noText, function(answer) end)
--     answer = true (first button) or false
-- Own code, written from gum_inputs' public API description.
Helpers.On('gum_inputs', 'guminputs:getInput', function(button, placeholder, cb)
    Helpers.OpenDialog(simpleSpec(button, placeholder), function(result)
        if Helpers.Callable(cb) then Helpers.SafeCall(cb, result == nil and 'close' or result) end
    end, GetInvokingResource())
end)

-- ------------------------------------------------------------ syn_inputs
--   TriggerEvent('syn_inputs:sendinputs', buttonText, placeholder, function(text) end)
-- The callback gets the typed text. It is not called when the player cancels: scripts feed the text
-- straight into tonumber / math (amounts) and would throw on an empty answer.
Helpers.On('syn_inputs', 'syn_inputs:sendinputs', function(button, placeholder, cb)
    Helpers.OpenDialog(simpleSpec(button, placeholder), function(result)
        if result ~= nil and Helpers.Callable(cb) then Helpers.SafeCall(cb, result) end
    end, GetInvokingResource())
end)

Helpers.On('gum_inputs', 'guminputs:getAnswer', function(question, yesText, noText, cb)
    Helpers.OpenDialog({
        kind = 'yesno', header = question, button = yesText, cancelButton = noText,
    }, function(result)
        if Helpers.Callable(cb) then Helpers.SafeCall(cb, result ~= nil) end
    end, GetInvokingResource())
end)

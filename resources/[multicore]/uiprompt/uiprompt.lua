-- ============================================================================
-- uiprompt.lua :: MULTIcore stand-in for the uiprompt library
-- Scripts include it with  client_scripts { '@uiprompt/uiprompt.lua', ... }
-- and use the global classes it creates:
--   Uiprompt          one key prompt (the game's own prompt at the bottom right)
--   UipromptGroup     a titled group of prompts, shown while it is active
--   UipromptManager   one thread that runs every prompt and group of the resource
-- Own code, written from the public description of the API. GPL v3.
-- Copyright (C) 2026 RINGO (RINGOscripting)
-- ============================================================================

-- This file runs inside the resource that includes it, so a second include
-- (two client files listing it) must not reset what the first one built.
if Uiprompt and UipromptGroup and UipromptManager and Uiprompt.__multicore then return end

-- ------------------------------------------------------------ natives
-- Prefer the named natives (UiPrompt..., then the older Prompt... names);
-- fall back to calling the hash when neither exists in this build.
local Invoke = Citizen.InvokeNative

local function truthy(r)
    return r == true or (type(r) == 'number' and r ~= 0)
end

local function native(names, hash, returnsBool)
    for _, n in ipairs(names) do
        local f = _G[n]
        if type(f) == 'function' then
            if returnsBool then
                return function(...) return truthy(f(...)) end
            end
            return f
        end
    end
    if returnsBool then
        return function(...)
            local args = table.pack(...)
            args[args.n + 1] = Citizen.ResultAsInteger()
            return truthy(Invoke(hash, table.unpack(args, 1, args.n + 1)))
        end
    end
    return function(...) return Invoke(hash, ...) end
end

local N = {
    RegisterBegin        = native({ 'UiPromptRegisterBegin', 'PromptRegisterBegin' }, 0x04F97DE45A519419),
    RegisterEnd          = native({ 'UiPromptRegisterEnd', 'PromptRegisterEnd' }, 0xF7AA2696A22AD8B9),
    SetControlAction     = native({ 'UiPromptSetControlAction', 'PromptSetControlAction' }, 0xB5352B7494A08258),
    SetText              = native({ 'UiPromptSetText', 'PromptSetText' }, 0x5DD02A8318420DD7),
    SetEnabled           = native({ 'UiPromptSetEnabled', 'PromptSetEnabled' }, 0x8A0FB4D03A630D21),
    SetVisible           = native({ 'UiPromptSetVisible', 'PromptSetVisible' }, 0x71215ACCFDE075EE),
    SetGroup             = native({ 'UiPromptSetGroup', 'PromptSetGroup' }, 0x2F11D3A254169EA4),
    RemoveGroup          = native({ 'UiPromptRemoveGroup', 'PromptRemoveGroup' }, 0x4E52C800A28F7BE8),
    SetStandardMode      = native({ 'UiPromptSetStandardMode', 'PromptSetStandardMode' }, 0xCC6656799977741B),
    SetHoldMode          = native({ 'UiPromptSetHoldMode', 'PromptSetHoldMode' }, 0x94073D5CA3F16B7B),
    SetStandardizedHold  = native({ 'UiPromptSetStandardizedHoldMode', 'PromptSetStandardizedHoldMode' }, 0x74C7D7B72ED0D3CF),
    SetMashMode          = native({ 'UiPromptSetMashMode', 'PromptSetMashMode' }, 0xDF6423BF071C7F71),
    SetMashIndefinitely  = native({ 'UiPromptSetMashIndefinitelyMode', 'PromptSetMashIndefinitelyMode' }, 0x7B66E89312727274),
    RestartModes         = native({ 'UiPromptRestartModes', 'PromptRestartModes' }, 0xDC6C55DFA2C24EE5),
    Delete               = native({ 'UiPromptDelete', 'PromptDelete' }, 0x00EDE88D4D13CF59),
    SetActiveGroup       = native({ 'UiPromptSetActiveGroupThisFrame', 'PromptSetActiveGroupThisFrame' }, 0xC65A45D4453C2627),

    IsValid              = native({ 'UiPromptIsValid', 'PromptIsValid' }, 0x347469FBDD1589A9, true),
    IsActive             = native({ 'UiPromptIsActive', 'PromptIsActive' }, 0x546E342E01DE71CF, true),
    IsEnabled            = native({ 'UiPromptIsEnabled', 'PromptIsEnabled' }, 0x0D00EDDFB58B7F28, true),
    IsControlActionActive = native({ 'UiPromptIsControlActionActive', 'PromptIsControlActionActive' }, 0x1BE19185B8AFE299, true),
    IsPressed            = native({ 'UiPromptIsPressed', 'PromptIsPressed' }, 0x21E60E230086697F, true),
    IsJustPressed        = native({ 'UiPromptIsJustPressed', 'PromptIsJustPressed' }, 0x2787CC611D3FACC5, true),
    IsReleased           = native({ 'UiPromptIsReleased', 'PromptIsReleased' }, 0xAFC887BA7A7756D6, true),
    IsJustReleased       = native({ 'UiPromptIsJustReleased', 'PromptIsJustReleased' }, 0x635CC82FA297A827, true),
    HasHoldMode          = native({ 'UiPromptHasHoldMode', 'PromptHasHoldMode' }, 0xB60C9F9ED47ABB76, true),
    IsHoldModeRunning    = native({ 'UiPromptIsHoldModeRunning', 'PromptIsHoldModeRunning' }, 0xC7D70EAEF92EFF48, true),
    HasHoldCompleted     = native({ 'UiPromptHasHoldModeCompleted', 'PromptHasHoldModeCompleted' }, 0xE0F65F0640EF0617, true),
    HasMashMode          = native({ 'UiPromptHasMashMode', 'PromptHasMashMode' }, 0xCD072523791DDC1B, true),
    HasMashCompleted     = native({ 'UiPromptHasMashModeCompleted', 'PromptHasMashModeCompleted' }, 0x845CE958416DC473, true),
    HasStandardCompleted = native({ 'UiPromptHasStandardModeCompleted', 'PromptHasStandardModeCompleted' }, 0xC92AC953F0A982AE, true),

    IsControlPressed      = native({ 'IsControlPressed' }, 0xF3A21BCD95725A4A, true),
    IsControlReleased     = native({ 'IsControlReleased' }, 0x648EE3E7F38877DD, true),
    IsControlJustPressed  = native({ 'IsControlJustPressed' }, 0x580417101DDB492F, true),
    IsControlJustReleased = native({ 'IsControlJustReleased' }, 0x50F940259D3841E6, true),
    EnableControlAction   = native({ 'EnableControlAction' }, 0x351220255D64C155),
    DisableControlAction  = native({ 'DisableControlAction' }, 0xFE99B66D079CF6BC),
}

local function varString(text)
    local f = _G.VarString or _G.CreateVarString
    if f then return f(10, 'LITERAL_STRING', tostring(text or '')) end
    return Invoke(0xFA925AC00EB830B9, 10, 'LITERAL_STRING', tostring(text or ''), Citizen.ResultAsLong())
end

-- control given as a hash (number), a '0x...' string or a name such as 'INPUT_JUMP'
local function toHash(control)
    if type(control) == 'number' then return control end
    if type(control) == 'string' then
        local n = control:match('^0[xX]%x+$') and tonumber(control) or nil
        if n then return n end
        return GetHashKey(control)
    end
    return 0
end

local function frame()
    return GetFrameCount and GetFrameCount() or GetGameTimer()
end

-- a handler from the script must not kill the event thread
local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        print(('^1[uiprompt] handler error: %s^7'):format(tostring(err)))
    end
end

-- ------------------------------------------------------------ events
-- one table drives both the setOn... setters and handleEvents
-- check = method that tells whether the event happens this frame
local EVENTS = {
    { name = 'JustPressed',               check = 'isJustPressed' },
    { name = 'JustReleased',              check = 'isJustReleased' },
    { name = 'Pressed',                   check = 'isPressed' },
    { name = 'Released',                  check = 'isReleased' },
    { name = 'ControlPressed',            check = 'isControlPressed' },
    { name = 'ControlReleased',           check = 'isControlReleased' },
    { name = 'ControlJustPressed',        check = 'isControlJustPressed' },
    { name = 'ControlJustReleased',       check = 'isControlJustReleased' },
    { name = 'StandardModeCompleted',     check = 'hasStandardModeCompleted' },
    { name = 'StandardModeJustCompleted', check = 'hasStandardModeJustCompleted' },
    { name = 'HoldModeRunning',           check = 'isHoldModeRunning' },
    { name = 'HoldModeCompleted',         check = 'hasHoldModeCompleted' },
    { name = 'HoldModeJustCompleted',     check = 'hasHoldModeJustCompleted' },
    { name = 'MashModeCompleted',         check = 'hasMashModeCompleted' },
    { name = 'MashModeJustCompleted',     check = 'hasMashModeJustCompleted' },
}

local function addHandlerSetters(class)
    for _, ev in ipairs(EVENTS) do
        local key = ev.name
        class['setOn' .. key] = function(self, handler)
            self.handlers[key] = handler
            return self
        end
    end
end

-- ============================================================================
-- UipromptManager
-- ============================================================================
UipromptManager = { __multicore = true }
UipromptManager.__index = UipromptManager

function UipromptManager:new()
    local m = setmetatable({}, UipromptManager)
    m.prompts = {}
    m.groups = {}
    m.running = false
    return m
end

function UipromptManager:addPrompt(prompt)
    self.prompts[prompt] = true
    return self
end

function UipromptManager:removePrompt(prompt)
    self.prompts[prompt] = nil
    return self
end

function UipromptManager:addGroup(group)
    self.groups[group] = true
    return self
end

function UipromptManager:removeGroup(group)
    self.groups[group] = nil
    return self
end

--- One frame of work: every group (with its prompts) and every prompt outside a group.
function UipromptManager:handleEvents(...)
    for group in pairs(self.groups) do
        group:handleEvents(...)
    end
    for prompt in pairs(self.prompts) do
        if not prompt.group then prompt:handleEvents(...) end
    end
end

function UipromptManager:startEventThread()
    if self.running then return self end
    self.running = true
    CreateThread(function()
        while self.running do
            if next(self.groups) or next(self.prompts) then
                self:handleEvents()
                Wait(0)
            else
                Wait(250)
            end
        end
    end)
    return self
end

function UipromptManager:stopEventThread()
    self.running = false
    return self
end

function UipromptManager:delete()
    self.running = false
    local groups, prompts = {}, {}
    for g in pairs(self.groups) do groups[#groups + 1] = g end
    for p in pairs(self.prompts) do prompts[#prompts + 1] = p end
    for _, g in ipairs(groups) do g:delete() end
    for _, p in ipairs(prompts) do p:delete() end
    self.groups, self.prompts = {}, {}
end

-- The class table is also the default manager every new prompt and group joins, so
-- UipromptManager:startEventThread() works without creating one.
UipromptManager.prompts = {}
UipromptManager.groups = {}
UipromptManager.running = false

-- ============================================================================
-- Uiprompt
-- ============================================================================
Uiprompt = { __multicore = true }
Uiprompt.__index = Uiprompt
addHandlerSetters(Uiprompt)

--- Uiprompt:new(controls, text, group?, enabled?)
function Uiprompt:new(controls, text, group, enabled)
    local p = setmetatable({}, Uiprompt)
    p.handlers = {}
    p.edges = {}
    if type(controls) ~= 'table' then controls = { controls } end
    p.controls = {}
    for i, c in ipairs(controls) do p.controls[i] = toHash(c) end
    p.text = tostring(text or '')
    if enabled == nil then enabled = true end

    p.handle = N.RegisterBegin()
    for _, c in ipairs(p.controls) do N.SetControlAction(p.handle, c) end
    N.SetText(p.handle, varString(p.text))
    N.SetEnabled(p.handle, enabled and true or false)
    N.SetVisible(p.handle, true)
    N.SetStandardMode(p.handle, true)
    -- the group goes on before the prompt is finished, as the game expects
    local gid = (type(group) == 'table' and group.groupId) or (type(group) == 'number' and group) or nil
    if gid then N.SetGroup(p.handle, gid, 0) end
    N.RegisterEnd(p.handle)

    if group ~= nil then p:setGroup(group) end
    UipromptManager:addPrompt(p)
    return p
end

-- ---------------------------------------------------- getters / state
function Uiprompt:getHandle() return self.handle end
function Uiprompt:getText() return self.text end
function Uiprompt:getGroup() return self.group end
function Uiprompt:getControls() return self.controls end
function Uiprompt:isValid() return self.handle ~= nil and N.IsValid(self.handle) end
function Uiprompt:isActive() return N.IsActive(self.handle) end
function Uiprompt:isEnabled() return N.IsEnabled(self.handle) end
function Uiprompt:hasHoldMode() return N.HasHoldMode(self.handle) end
function Uiprompt:hasMashMode() return N.HasMashMode(self.handle) end
function Uiprompt:isJustPressed() return N.IsJustPressed(self.handle) end
function Uiprompt:isJustReleased() return N.IsJustReleased(self.handle) end
function Uiprompt:isPressed() return N.IsPressed(self.handle) end
function Uiprompt:isReleased() return N.IsReleased(self.handle) end
function Uiprompt:isHoldModeRunning() return N.IsHoldModeRunning(self.handle) end
function Uiprompt:hasStandardModeCompleted() return N.HasStandardCompleted(self.handle, 0) end
function Uiprompt:hasHoldModeCompleted() return N.HasHoldCompleted(self.handle) end
function Uiprompt:hasMashModeCompleted() return N.HasMashCompleted(self.handle) end

function Uiprompt:isControlActionActive()
    for _, c in ipairs(self.controls) do
        if N.IsControlActionActive(c) then return true end
    end
    return false
end

-- "just completed": true only on the first frame the state turns true.
-- Remembered per frame, so asking twice in one frame gives the same answer.
function Uiprompt:_edge(key, now)
    local e = self.edges[key]
    local f = frame()
    if e and e.frame == f then return e.result end
    local was = e and e.value or false
    local result = now and not was
    self.edges[key] = { frame = f, value = now, result = result }
    return result
end

function Uiprompt:hasStandardModeJustCompleted() return self:_edge('standard', self:hasStandardModeCompleted()) end
function Uiprompt:hasHoldModeJustCompleted() return self:_edge('hold', self:hasHoldModeCompleted()) end
function Uiprompt:hasMashModeJustCompleted() return self:_edge('mash', self:hasMashModeCompleted()) end

-- ---------------------------------------------------- setters
function Uiprompt:setEnabled(enabled)
    N.SetEnabled(self.handle, enabled and true or false)
    return self
end

function Uiprompt:setVisible(visible)
    N.SetVisible(self.handle, visible and true or false)
    return self
end

function Uiprompt:setEnabledAndVisible(b)
    self:setEnabled(b)
    self:setVisible(b)
    return self
end

function Uiprompt:setText(text)
    self.text = tostring(text or '')
    N.SetText(self.handle, varString(self.text))
    return self
end

--- group = UipromptGroup object or a raw group id; nil takes the prompt out of its group
function Uiprompt:setGroup(group)
    if self.group and self.group ~= group then self.group:_forget(self) end
    if type(group) == 'table' then
        group:addPrompt(self)
    elseif type(group) == 'number' then
        self.group = nil
        self.groupId = group
        N.SetGroup(self.handle, group, 0)
    else
        if self.groupId then N.RemoveGroup(self.handle, self.groupId) end
        self.group, self.groupId = nil, nil
    end
    return self
end

function Uiprompt:setStandardMode(releaseMode)
    N.SetStandardMode(self.handle, releaseMode and true or false)
    return self
end

--- true = the game's standard hold time, a number = hold time in ms, false = back to a plain press
function Uiprompt:setHoldMode(holdMode)
    if type(holdMode) == 'number' then
        N.SetHoldMode(self.handle, math.floor(holdMode))
    elseif holdMode then
        N.SetStandardizedHold(self.handle, GetHashKey('MEDIUM_TIMED_EVENT'))
    else
        N.SetStandardMode(self.handle, true)
    end
    return self
end

function Uiprompt:setMashMode(count)
    N.SetMashMode(self.handle, math.floor(tonumber(count) or 1))
    return self
end

function Uiprompt:setMashIndefinitelyMode()
    N.SetMashIndefinitely(self.handle)
    return self
end

function Uiprompt:restartModes()
    N.RestartModes(self.handle)
    return self
end

-- ---------------------------------------------------- controls
--- func(padIndex, control) for every control; true when any call returned true
function Uiprompt:doForEachControl(func, padIndex, ...)
    local any = false
    for _, c in ipairs(self.controls) do
        if func(padIndex or 0, c, ...) then any = true end
    end
    return any
end

function Uiprompt:isControlPressed(padIndex) return self:doForEachControl(N.IsControlPressed, padIndex) end
function Uiprompt:isControlReleased(padIndex) return self:doForEachControl(N.IsControlReleased, padIndex) end
function Uiprompt:isControlJustPressed(padIndex) return self:doForEachControl(N.IsControlJustPressed, padIndex) end
function Uiprompt:isControlJustReleased(padIndex) return self:doForEachControl(N.IsControlJustReleased, padIndex) end

function Uiprompt:enableControlAction(padIndex)
    self:doForEachControl(function(pad, c) N.EnableControlAction(pad, c, true) end, padIndex)
    return self
end

function Uiprompt:disableControlAction(padIndex)
    self:doForEachControl(function(pad, c) N.DisableControlAction(pad, c, true) end, padIndex)
    return self
end

-- ---------------------------------------------------- events
--- Call every frame when not using UipromptManager:startEventThread().
--- Each handler gets the prompt first, then the arguments given here.
function Uiprompt:handleEvents(...)
    if not self.handle then return end
    if not next(self.handlers) then return end
    for _, ev in ipairs(EVENTS) do
        local h = self.handlers[ev.name]
        if h and self[ev.check](self) then
            safeCall(h, self, ...)
        end
    end
end

function Uiprompt:delete()
    if self.group then self.group:_forget(self) end
    if self.handle then N.Delete(self.handle) end
    self.handle = nil
    UipromptManager:removePrompt(self)
end

-- ============================================================================
-- UipromptGroup
-- ============================================================================
UipromptGroup = { __multicore = true }
UipromptGroup.__index = UipromptGroup
addHandlerSetters(UipromptGroup)

--- UipromptGroup:new(text, active?)
function UipromptGroup:new(text, active)
    local g = setmetatable({}, UipromptGroup)
    g.groupId = GetRandomIntInRange(0, 0xffffff)
    g.text = tostring(text or '')
    g.prompts = {}
    g.handlers = {}
    if active == nil then active = true end
    g.active = active and true or false
    UipromptManager:addGroup(g)
    return g
end

function UipromptGroup:getGroupId() return self.groupId end
function UipromptGroup:getText() return self.text end
function UipromptGroup:getPrompts() return self.prompts end
function UipromptGroup:isActive() return self.active end

function UipromptGroup:setText(text)
    self.text = tostring(text or '')
    return self
end

function UipromptGroup:setActive(active)
    self.active = active and true or false
    return self
end

--- shows the group (with its title) this frame
function UipromptGroup:setActiveThisFrame()
    N.SetActiveGroup(self.groupId, varString(self.text), 0, 0, 0, 0)
    return self
end

function UipromptGroup:addPrompt(prompt)
    if prompt.group == self then return self end
    if prompt.group then prompt.group:_forget(prompt) end
    prompt.group = self
    prompt.groupId = self.groupId
    N.SetGroup(prompt.handle, self.groupId, 0)
    self.prompts[#self.prompts + 1] = prompt
    return self
end

function UipromptGroup:_forget(prompt)
    for i = #self.prompts, 1, -1 do
        if self.prompts[i] == prompt then table.remove(self.prompts, i) end
    end
    if prompt.group == self then prompt.group = nil end
end

--- Calls prompt[methodName](prompt, ...) for every prompt; callback(prompt) for each one that
--- answered true. Returns true when any prompt answered true.
function UipromptGroup:doForEachPrompt(methodName, callback, ...)
    local any = false
    for _, p in ipairs(self.prompts) do
        local fn = p[methodName]
        if fn and fn(p, ...) then
            any = true
            if callback then callback(p) end
        end
    end
    return any
end

function UipromptGroup:isJustPressed(cb) return self:doForEachPrompt('isJustPressed', cb) end
function UipromptGroup:isJustReleased(cb) return self:doForEachPrompt('isJustReleased', cb) end
function UipromptGroup:isPressed(cb) return self:doForEachPrompt('isPressed', cb) end
function UipromptGroup:isReleased(cb) return self:doForEachPrompt('isReleased', cb) end
function UipromptGroup:isControlPressed(pad, cb) return self:doForEachPrompt('isControlPressed', cb, pad) end
function UipromptGroup:isControlReleased(pad, cb) return self:doForEachPrompt('isControlReleased', cb, pad) end
function UipromptGroup:isControlJustPressed(pad, cb) return self:doForEachPrompt('isControlJustPressed', cb, pad) end
function UipromptGroup:isControlJustReleased(pad, cb) return self:doForEachPrompt('isControlJustReleased', cb, pad) end
function UipromptGroup:hasStandardModeCompleted(cb) return self:doForEachPrompt('hasStandardModeCompleted', cb) end
function UipromptGroup:hasStandardModeJustCompleted(cb) return self:doForEachPrompt('hasStandardModeJustCompleted', cb) end
function UipromptGroup:isHoldModeRunning(cb) return self:doForEachPrompt('isHoldModeRunning', cb) end
function UipromptGroup:hasHoldModeCompleted(cb) return self:doForEachPrompt('hasHoldModeCompleted', cb) end
function UipromptGroup:hasHoldModeJustCompleted(cb) return self:doForEachPrompt('hasHoldModeJustCompleted', cb) end
function UipromptGroup:hasMashModeCompleted(cb) return self:doForEachPrompt('hasMashModeCompleted', cb) end
function UipromptGroup:hasMashModeJustCompleted(cb) return self:doForEachPrompt('hasMashModeJustCompleted', cb) end

function UipromptGroup:setEnabled(enabled)
    for _, p in ipairs(self.prompts) do p:setEnabled(enabled) end
    return self
end

function UipromptGroup:setVisible(visible)
    for _, p in ipairs(self.prompts) do p:setVisible(visible) end
    return self
end

function UipromptGroup:enableControlAction(pad)
    for _, p in ipairs(self.prompts) do p:enableControlAction(pad) end
    return self
end

function UipromptGroup:disableControlAction(pad)
    for _, p in ipairs(self.prompts) do p:disableControlAction(pad) end
    return self
end

--- Shows the group this frame (when active), runs each prompt's own handlers, then the
--- group's handlers, which get (group, prompt, ...) for every prompt the event happened to.
function UipromptGroup:handleEvents(...)
    if not self.active then return end
    self:setActiveThisFrame()
    for _, p in ipairs(self.prompts) do
        p:handleEvents(...)
    end
    if not next(self.handlers) then return end
    for _, ev in ipairs(EVENTS) do
        local h = self.handlers[ev.name]
        if h then
            for _, p in ipairs(self.prompts) do
                if p.handle and p[ev.check](p) then
                    safeCall(h, self, p, ...)
                end
            end
        end
    end
end

function UipromptGroup:delete()
    local list = {}
    for i, p in ipairs(self.prompts) do list[i] = p end
    for _, p in ipairs(list) do p:delete() end
    self.prompts = {}
    UipromptManager:removeGroup(self)
end

-- ------------------------------------------------------------ cleanup
-- Prompts belong to the game, not the resource: remove them when the script stops.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    UipromptManager:delete()
end)

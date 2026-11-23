# uiprompt (MULTIcore stand-in)

MULTIcore's own version of the `uiprompt` library. Scripts that list `@uiprompt/uiprompt.lua`
in their `client_scripts` work with it unchanged. Own code, written from the public description
of the library's API. GPL v3.

## Install

Put the folder in your resources and start it before the scripts that use it:

```cfg
ensure uiprompt
```

Nothing runs inside this resource; it only serves the file `uiprompt.lua`, which each script
loads into itself.

## What a script gets

```lua
-- fxmanifest.lua of the script
client_scripts {
    '@uiprompt/uiprompt.lua',
    'client.lua',
}
```

```lua
-- client.lua
local group = UipromptGroup:new('Saloon')
local drink = Uiprompt:new('INPUT_CONTEXT_Y', 'Buy a drink', group)
drink:setHoldMode(1000)
drink:setOnHoldModeJustCompleted(function(prompt)
    print('bought a drink')
end)

UipromptManager:startEventThread()
```

### Uiprompt

| | |
|---|---|
| Create | `Uiprompt:new(controls, text, group?, enabled?)` - one control (hash, `'0x...'` or a name like `'INPUT_JUMP'`) or a table of them; `group` is a `UipromptGroup` or a raw group id |
| State | `getHandle`, `getText`, `isValid`, `isActive`, `isEnabled`, `isControlActionActive`, `hasHoldMode`, `hasMashMode`, `isJustPressed`, `isJustReleased`, `isPressed`, `isReleased`, `isHoldModeRunning`, `hasStandardModeCompleted`, `hasStandardModeJustCompleted`, `hasHoldModeCompleted`, `hasHoldModeJustCompleted`, `hasMashModeCompleted`, `hasMashModeJustCompleted` |
| Change | `setEnabled`, `setVisible`, `setEnabledAndVisible`, `setText`, `setGroup`, `setStandardMode`, `setHoldMode(true or ms)`, `setMashMode(count)`, `setMashIndefinitelyMode` |
| Controls | `isControlPressed(pad?)`, `isControlReleased`, `isControlJustPressed`, `isControlJustReleased`, `enableControlAction`, `disableControlAction`, `doForEachControl(func, pad?)` |
| Handlers | `setOnJustPressed`, `setOnJustReleased`, `setOnPressed`, `setOnReleased`, `setOnControlPressed`, `setOnControlReleased`, `setOnControlJustPressed`, `setOnControlJustReleased`, `setOnStandardModeCompleted`, `setOnStandardModeJustCompleted`, `setOnHoldModeRunning`, `setOnHoldModeCompleted`, `setOnHoldModeJustCompleted`, `setOnMashModeCompleted`, `setOnMashModeJustCompleted` - the handler gets the prompt, then whatever was passed to `handleEvents` |
| Run | `handleEvents(...)` every frame (or let the manager do it), `delete()` |

### UipromptGroup

`UipromptGroup:new(text, active?)`, `getGroupId`, `getText`, `setText`, `getPrompts`, `addPrompt`,
`isActive`, `setActive`, `setActiveThisFrame`, `setEnabled`, `setVisible`,
`doForEachPrompt(methodName, callback, ...)`, the same state checks as a prompt (each takes an
optional callback that gets every prompt it is true for), `enableControlAction(pad)`,
`disableControlAction(pad)`, the same `setOn...` handlers (they get `group, prompt, ...`),
`handleEvents(...)` and `delete()`.

### UipromptManager

`addPrompt`, `removePrompt`, `addGroup`, `removeGroup`, `startEventThread()`, `delete()`.
Every new prompt and group joins it on its own. When the script stops, its prompts are removed
from the screen.

## Licence

GPL v3, see `LICENSE`. Copyright (C) 2026 RINGO (RINGOscripting).

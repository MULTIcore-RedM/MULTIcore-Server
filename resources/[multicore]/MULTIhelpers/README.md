# MULTIhelpers

Part of MULTIcore (GPL v3). One resource that stands in for the small menu, input, progress bar, notification and minigame resources that RedM scripts depend on.

## Stands in for

| Resource name | What it is | Answered by |
|---|---|---|
| `vorp_menu` | the `MenuData` list menus VORP scripts open | `client/menu.lua` |
| `menuapi` | the old name of vorp_menu | `client/menu.lua` |
| `gum_menu` | Gum's MenuData menu | `client/menu.lua` |
| `tpz_menu_base` | TPZ's MenuData menu | `client/menu.lua` |
| `redemrp_menu_base` | RedEM:RP's MenuData menu | `client/redem.lua` |
| `vorp_inputs` | the text / number input box | `client/inputs.lua` |
| `gum_inputs` | Gum's input box and yes/no question | `client/inputs.lua` |
| `rsg-input`, `qb-input`, `qbr-input`, `fx-input` | the QB-style input dialog | `client/qb_input.lua` |
| `rsg-menu`, `qb-menu`, `qbr-menu` | the QB-style menu | `client/qb_menu.lua` |
| `vorp_progressbar` | the timed progress bar | `client/progress.lua` |
| `redemrp_progressbars` | RedEM:RP's progress bar | `client/redem.lua` |
| `progressbar` | the QB-style progress bar RSG v1 and QBR scripts call | `client/qb_progress.lua` |
| `feather-progressbar` | Feather's progress bar | `client/feather_progress.lua` |
| `redemrp_notification` | RedEM:RP notifications | `client/notify.lua` |
| `gum_notify` | Gum notifications | `client/notify.lua` |
| `rsg_notify` | the old RSG notifications | `client/notify.lua` |
| `pNotify` | pNotify notifications | `client/notify.lua` |
| `bln_notify` | BLN notifications (a subset), client and server | `client/notify.lua`, `server/notify.lua` |
| `syn_minigame`, `fx-minigame` | the skill bar (`taskBar`) | `client/minigame.lua` |
| `syn_inputs` | the text box (`syn_inputs:sendinputs`) | `client/inputs.lua` |
| `feather-menu` | Feather's page menu (v1) that BCC scripts open | `client/feather_menu.lua` |
| `bcc-minigames` | skill check, lockpick, rock-paper-scissors, hammertime, cow milker, dice | `client/bcc_minigames.lua` |
| `uiprompt` | the prompt library (`@uiprompt/uiprompt.lua`) | its own resource `uiprompt` in `[multicore]` |

The fxmanifest `provide`s every name above, so scripts that list them as dependencies start fine. Every export is registered under the name it stands in for (most also under `MULTIhelpers`). Menus, boxes and bars draw in the MULTIcore theme (`MULTIcore/html/theme/multi.css`) and follow its three UI presets. Notifications are drawn by MULTIcore's own notifications; QB menus and QB input dialogs by MULTIcore's context menu and input dialog.

This is our own code, written from each resource's public docs and API description (for VORP: docs.vorp-core.com, *API reference: menu, inputs, progressbar*) and from how scripts call them. No code of the original resources is used.

## Setup

```
ensure oxmysql
ensure ox_lib
ensure MULTIcore
ensure MULTIhelpers
```

Remove the `ensure` lines of every resource in the table above. If one of them starts anyway, MULTIhelpers steps aside for that name (its exports and events) and prints a warning in F8.

RINGOui also stands in for `vorp_progressbar`. Run only one of the two stand-ins for it.

## Config (`config.lua`)

Every option has a comment. The main ones:

- `Config.Locale`: the language (`en`, `de`, `fr`, `es`, `pt-br`, `it`, `pl`, `ru`, `nl`, `tr`). If it is not set, the server's `setr multicore_locale` is used, then `en`.
- `Config.Menu`: default position (`Align`, `OffsetTop`, `OffsetSide`), `Width`, `MaxVisibleItems`, `GridColumns`, key hints, `CursorByDefault`, `KeepGameInput`, the navigation `Keys` and the frontend `Sounds`.
- `Config.Inputs`: `CancelResult` (what a cancelled box returns, `''` by default, like VORP), `AllowCustomStyle`, `Width`.
- `Config.Progress`: `TakeFocus`, `DefaultTheme`, `Color`, `TrackColor`, `Width`, `CircleSize`, `Bottom`, `ShowPercent`, `ProgressBarsStartUI`.
- `Config.Notify`: `DefaultDuration` and which MULTIcore style gum_notify, rsg_notify's bottom text and bln_notify tips use.
- `Config.Minigame`: the skill bar `Key` (E), the narrowest / widest target zone, where the zone may sit, and the fastest sweep.
- `Config.QBProgress`: `CancelKeys` (X and Backspace) and `BusyMessage`.

To restyle, use `html/custom.css`. It loads last.

## Menu: `vorp_menu`

The older way works too (syn_* and many older scripts use it). MULTIhelpers must start before those scripts:
`TriggerEvent('menuapi:getData', function(call) MenuData = call end)` (also `vorp_menu:getData`). The events
`menuapi:closemenu`, `vorp_menu:closemenu` and `vorp_menu:openmenu` fire as in the original: `vorp_menu:closemenu` on every close,
`menuapi:closemenu` only when the player closes the menu (a script closing it with `menu.close()` or `CloseAll()` does not send it).

```lua
local MenuData = exports.vorp_menu:GetMenuData()

MenuData.Open('default', GetCurrentResourceName(), 'shop', {
    title = 'General Store', subtext = 'Valentine', align = 'top-left',
    elements = {
        { label = 'Beans', value = 'beans', desc = 'A tin of beans', descPrice = { amount = 1.25, icon = 'money', text = 'each' } },
        { label = 'Amount', value = 1, type = 'slider', min = 1, max = 10, hop = 1, desc = 'How many' },
    },
    lastmenu = 'OpenMainMenu',
}, function(data, menu)               -- submit
    if data.current == 'backup' then return _G[data.trigger]() end
    print(data.current.value)
end, function(data, menu)             -- cancel
    menu.close()
end, function(data, menu) end,        -- change (moving and sliders)
function(data, menu) end)             -- close
```

### `MenuData` functions
| Call | Notes |
|---|---|
| `Open(type, namespace, name, data, submit, cancel, change, close)` | Returns the menu object. Opening the same `type/namespace/name` again replaces it. A reopened menu starts on the row it was left on. |
| `Close(type, namespace, name)` | |
| `CloseAll(showRadar, soundClose, fireEventClose)` | Every argument is optional. `false` skips that part. |
| `GetOpened(type, namespace, name)` | Returns the menu object, or nil. |
| `GetOpenedMenus()` | Returns a list of menu objects. |
| `IsOpen(type, namespace, name)` | |
| `ReOpen(type, namespace, name)` or `ReOpen(menu)` | Brings a covered menu back to the front. |
| `RegisterControls(controls, onPress)` / `UnregisterControls()` | `controls` takes KeyboardEvent key names plus `'scrollup'`, `'scrolldown'` and `'mousepress'`. `onPress(name)` gets the name; a mouse press arrives as `mousepress_left` or `mousepress_right`. |

`exports.vorp_menu:CloseAll(...)`, `RegisterControls(...)` and `UnregisterControls()` also work directly on the export.

### Menu object (`menu` in callbacks)
`menu.close(showRadar, soundClose, fireEventClose)`, `menu.refresh()`, `menu.addNewElement(el)`, `menu.getElementByValue(v)`, `menu.getElementByIndex(i)`, `menu.setElement(i, field, value)`, `menu.removeElementByValue(v, all)`, `menu.removeElementByIndex(i, all)`, `menu.setTitle(t)`, `menu.setSubtext(t)`, `menu.displayInput(options, onSubmit, onCancel)`.
Changes made through these calls are drawn on the next tick. `refresh()` draws them at once.

`displayInput` options: `inputType` (`text`, `number`, `password`, `date` or `yesno`), `header`, `placeholder`, `description`, `buttons = { confirm, cancel }`, `maxLength`, `pattern` and `patternMessage`. `pattern` can be a preset (`letters`, `numbers`, `alphanumeric`, `no-symbols`, `username`, `phone`, `email`, `money`, `no-special`) or a regex. Pass callbacks and the call returns at once. Leave them out and the call waits, then returns the value (nil when cancelled). A yes/no box submits `true`.

### Menu data fields
`title`, `subtext`, `align` (`top-left`, `top-center` or `top-right`), `elements`, `lastmenu`, `itemHeight`, `labelPos` (`left` or `center`), `divider`, `fixedHeight`, `enableCursor`, `maxVisibleItems`, `hideRadar`, `soundOpen`, `confirmButton` and `cancelButton` (`{ label, value }`), `isGrid`, `skipOpenEvent`.

### Element fields
`label`, `value`, `desc` (all three may hold simple HTML; scripts are removed), `itemHeight`, `labelPos`, `footerText`, `isNotSelectable` (a header row that is skipped), `isDisabled` (shown, can't be submitted), `image` (grid tiles), `descPrice = { amount, icon = 'gold'|'money', text }`, `tickBox = true` with `value = 'ticked'|'unticked'`.
Element types:
- `slider`: `min`, `max`, `hop`, `value`.
- `label-slider`: the same fields plus `attributes = { trackColor, fillColor, thumbColor }`. `thumbColor` is ignored because the bar has no thumb.
- `text-slider`: `textList = { { label, value } }`. Read `data.current.textIndex`.
- `desc-slider`: `sliders = { { label, value, min, max, hop, attributes } }`. The sub-sliders are shown in the description box: Tab picks one, Left/Right changes it, or click the bar. Read `data.current.sliderIndex`.
- `tick-box`: `tickBoxes = { { label, value = 'ticked'|'unticked' } }`. Left/Right picks a box and Enter toggles it. Read `data.current.tickBoxIndex`.

### Callbacks
Each callback gets `(data, menu)`, where `data = { current = element (with .index), elements }`.
- `change` fires when the selected row moves and when a slider or box changes.
- Enter on a tick box toggles it, fires `change`, then fires `submit`.
- Backspace on a menu with `lastmenu` calls `submit` with `{ current = 'backup', trigger = lastmenu }`. Without `lastmenu`, Backspace counts as cancel.
- Esc calls `cancel`. If the menu has no cancel callback, Esc closes it.
- The confirm button calls `submit` with `data.current = confirmButton` and `data.button = 'confirm'`. The cancel button calls `cancel`.

Client events: `vorp:menu:openmenu` and `vorp:menu:closemenu`, each with `{ type, namespace, name, title }`.

Keys: arrows, Enter, Backspace, Esc and Tab, all set in `Config.Menu.Keys`. The mouse wheel scrolls. With a cursor, hovering a row selects it, a click submits it, and a click on ‹ › moves a slider.

## Input box: `vorp_inputs`

```lua
local text = exports.vorp_inputs:advancedInput({
    type = 'enableinput', inputType = 'input', button = 'Confirm', placeholder = 'NAME QUANTITY', style = 'block',
    attributes = { inputHeader = 'GIVE ITEM', type = 'text', pattern = '[0-9]+', title = 'numbers only' },
})
local text = exports.vorp_inputs:getInput('Confirm', 'Amount')
TriggerEvent('vorpinputs:advancedInput', json.encode(myInput), function(text) end)
TriggerEvent('vorpinputs:getInput', 'Confirm', 'Amount', function(text) end)
```
- The calls return the typed text as a string, or `Config.Inputs.CancelResult` (`''` by default) when the player cancels.
- `advancedInput` takes the table or its JSON string.
- `inputType = 'textarea'` (or `attributes.type = 'textarea'`) gives a multi-line box. Ctrl+Enter submits it.
- `attributes`:
  - `inputHeader`
  - `type`: `text`, `number`, `date` or `password`
  - `pattern`: an HTML pattern, which must match the whole text
  - `title`: the message shown when the text fails the check
  - `min`, `max`, `step`, `minlength`, `maxlength`, `value`
  - `style`: used only with `Config.Inputs.AllowCustomStyle`
- Only one box is open at a time. A new one cancels the old one.

## Progress bar: `vorp_progressbar`

```lua
local progressbar = exports.vorp_progressbar:initiate()
progressbar.start('Crafting', 5000, function() print('done') end, 'linear', '#b8322a', '20vw')
```
`start(message, ms, callback, theme, color, width, focus)`:
- `theme`: `linear`, `circle` or `innercircle`.
- `color`: any CSS colour.
- `width`: any CSS width, or a number in pixels. For the circle themes it sets the circle size.
- `focus`: pass `false` and the bar does not take the keyboard.

The callback runs with no arguments when the bar ends. Bars can overlap; the newest one is drawn.
- `exports.vorp_progressbar:CancelNext(cb)` cancels the oldest bar. `cb(info)` gets `info = { message, duration, theme, focus }`.
- `exports.vorp_progressbar:CancelAll(cb)` cancels every bar. `cb(list)` gets a list of the same info tables.
- A cancelled bar never calls back.
- `exports.progressBars:startUI(ms, text)` (the older resource) is answered too, unless `progressBars` is running.

## Not supported / differences
- **Menu `RegisterControls`** only works while a menu (or another MULTIhelpers window) has focus. The NUI page cannot hear keys when nothing is open.
- **`label-slider` `thumbColor`** is ignored because the bar has no thumb.
- **Where the old functions came from:**
  - The VORP docs don't list `GetOpened`, `GetOpenedMenus`, `IsOpen`, `ReOpen` or `Close(type, namespace, name)`. They follow the usual MenuData shape.
  - The `vorp_inputs` docs don't list `getInput` (export and event) either. It follows how older scripts call it.
- **Cancel value:** a cancelled box returns `''` by default, which is what VORP scripts check for. Set `Config.Inputs.CancelResult = nil` if your scripts expect nil.
- **Not taken from the docs, our own choice:**
  - Which callback the menu `confirmButton` / `cancelButton` fire.
  - What a yes/no `displayInput` submits (`true`).
  - The `data` sent with the open and close events.
- **Live menu tables:** a menu object is a copy once it reaches another resource. Change rows through `setElement` / `addNewElement` / `remove*` / `refresh`, not by editing `menu.data.elements` directly.
- **Notifications:** the vorp_* stand-ins send none. The QB progress bar sends one when a bar is refused (already busy, or dead).

## Languages
Words of our own (default buttons, key hints, input check messages and console warnings) come from `locales/*.lua`. Text from the calling script is shown as it is. `ru` switches the page to the theme's Cyrillic font preset.

## RedEM:RP (redemrp_menu_base, redemrp_progressbars)

`TriggerEvent('redemrp_menu_base:getData', cb)` gives the same menu as vorp_menu. `exports.redemrp_progressbars:DisplayProgressBar(ms, text, cb)` shows the MULTIhelpers bar, waits for it and then calls `cb`.

## Menu aliases: `menuapi`, `gum_menu`, `tpz_menu_base`

The same MenuData as vorp_menu, handed out under the other names:

```lua
TriggerEvent('menuapi:getData', function(call) MenuData = call end)
TriggerEvent('gum_menu:getData', function(call) MenuData = call end)
TriggerEvent('tpz_menu_base:getData', function(call) MenuData = call end)
local MenuData = exports.tpz_menu_base:GetMenuData()   -- also exports.menuapi / exports.gum_menu
```

tpz_menu_base extras:
- `exports.tpz_menu_base:UpdateCurrentSubtextDescription(text)` puts new text in the description box of the selected row.
- `tpz_menu_base:onForcedClosed` fires when `MenuData.CloseAll()` shuts open menus.
- Element fields `image` (a small picture before the label) and `descriptionimages = { { src, text, count } }` (pictures in the description box). Sliders (`type = 'slider'`, `min`, `max`, `hop`) work as in vorp_menu.

## Input box: `gum_inputs`

```lua
TriggerEvent('guminputs:getInput', 'Confirm', 'Name', function(value)
    if value == 'close' then return end      -- cancelled
end)
TriggerEvent('guminputs:getAnswer', 'Sell the horse?', 'Yes', 'No', function(answer) end)   -- true / false
```

## QB-style input: `rsg-input`, `qb-input`, `qbr-input`, `fx-input`

```lua
local r = exports['rsg-input']:ShowInput({
    header = 'Give money', submitText = 'Give',
    inputs = {
        { text = 'Player id', name = 'id', type = 'number', isRequired = true },
        { text = 'Pay with', name = 'kind', type = 'radio', options = {
            { value = 'cash', text = 'Cash', checked = true }, { value = 'gold', text = 'Gold' } } },
        { text = 'Extras', name = 'extras', type = 'checkbox', options = {
            { value = 'receipt', text = 'Receipt' }, { value = 'wrap', text = 'Gift wrap' } } },
    },
})
if r then print(r.id, r.kind, json.encode(r.extras)) end   -- strings; checkbox = list of ticked values
```

Types: `text`, `password`, `number`, `radio`, `select`, `checkbox`, `color`. `isRequired`, `default` and fx-input's `icon` work. Drawn by MULTIcore's input dialog; `nil` when the player closes it. Empty fields come back as `''`.

## QB-style menu: `rsg-menu`, `qb-menu`, `qbr-menu`

```lua
exports['rsg-menu']:openMenu({
    { header = 'Stable', isMenuHeader = true },
    { header = 'Buy a horse', txt = 'See the horses for sale', icon = 'fas fa-horse',
      params = { event = 'stable:client:buy', args = { id = 1 } } },
    { header = 'Sell', txt = 'Not today', disabled = true },
    { header = 'Close', params = { event = 'rsg-menu:client:closeMenu' } },
})
exports['rsg-menu']:closeMenu()
TriggerClientEvent('rsg-menu:client:openMenu', src, menu)   -- from the server
```

Row fields: `header`, `txt` (or `text`), `icon`, `isMenuHeader`, `disabled`, `hidden`, `params = { event, args, isServer, isCommand, isQBCommand, isAction }`. The first `isMenuHeader` row becomes the menu title. qbr-menu's `openMenu(menu, onClose)` runs `onClose` when the player closes the menu. Drawn by MULTIcore's context menu.

## QB-style progress bar: `progressbar`

```lua
exports['progressbar']:Progress({
    name = 'pick_herbs', duration = 5000, label = 'Picking herbs...',
    useWhileDead = false, canCancel = true,
    controlDisables = { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
    animation = { task = 'WORLD_HUMAN_CROUCH_INSPECT' },          -- or { animDict = '...', anim = '...', flags = 1 }
    prop = { model = 'p_bottle01x', bone = 'SKEL_R_Hand', coords = { x = 0.0, y = 0.0, z = 0.0 }, rotation = { x = 0.0, y = 0.0, z = 0.0 } },
}, function(cancelled) end)
```

Also `ProgressWithStartEvent(action, start, finish)`, `ProgressWithTickEvent(action, tick, finish)`, `ProgressWithStartAndTick(action, start, tick, finish)`, and the client events `progressbar:client:progress` (and the three other names), `progressbar:client:cancel`, `progressbar:client:ToggleBusyness`. `canCancel` bars stop on X or Backspace (`Config.QBProgress.CancelKeys`). One bar at a time: a second one gets `finish(true)` straight away.

## Progress bar: `feather-progressbar`

```lua
local progressbar = exports['feather-progressbar']:initiate()
progressbar.onCancel(function() print('cancelled') end)
progressbar.start('Crafting', 4000, function() print('done') end, 'circle')
exports['feather-progressbar']:cancelCurrentProgressBar()
```

Calls are queued: a second `start` waits for the first bar. `startUI(ms, text)` is answered too.

## Notifications: `redemrp_notification`, `gum_notify`, `rsg_notify`, `pNotify`, `bln_notify`

All drawn by MULTIcore's notifications (looks and positions in `MULTIcore/config_notify.lua`).

```lua
TriggerEvent('redemrp_notification:start', 'Saved', 3, 'success')                -- seconds, success/error/warning
exports.gum_notify:DisplayLeftNotification('Bank', 'Deposit done', 'money', 4000) -- also event gum_notify:notify
exports.rsg_notify:DisplayNotification('Hello', 4000)                           -- events rsg_notify:client:notifiy / :bottom_notifiy
exports.pNotify:SendNotification({ text = 'Hi', type = 'error', timeout = 3000 }) -- also event pNotify:SendNotification
exports.bln_notify:send({ title = 'Shop', description = 'Bought', duration = 4000 }, 'SUCCESS')
exports.bln_notify:tip('Press G to open', 3000)
exports.bln_notify:send(src, { title = 'Shop', description = 'Bought' }, 'SUCCESS') -- server; -1 = everyone
```

Types map to MULTIcore types (`alert` = info; bln templates `REWARD_MONEY` / `TIP_CASH` = money, `TIP_GOLD` = gold, `TIP*` and `useBackground = false` = tip style). Small HTML (`<br>`) becomes line breaks; other tags are removed.

## Skill bar: `syn_minigame`, `fx-minigame`

```lua
local result = exports['syn_minigame']:taskBar(4000, 7)   -- sweep ms, zone width %
if result == 100 then print('hit') end
```

A marker sweeps once across a bar in the MULTI look; press E inside the marked zone. Returns `100` on a hit, `0` on a miss (wrong timing, Esc, or no press).

## Not supported (the newer stand-ins)
- **QB menu:** `showHeader` opens the menu with focus, like `openMenu`. qbr-menu's `onMouseOver` / `onMouseOut` do nothing. rsg-menu's item-name icons are not turned into item pictures.
- **QB input:** `submitText` is not used; the dialog's own Confirm button is shown.
- **QB progress bar:** QB bone numbers in `prop.bone` are passed to the game as they are; use RedM bone names (`SKEL_R_Hand`).
- **pNotify:** `layout`, `theme`, `queue`, `buttons`, `sounds` and the other Noty options are ignored; `SetQueueMax` does nothing.
- **bln_notify:** `placement`, `progress`, `keyActions` (and so the `bln_notify:keyPressed` event), `contentAlignment`, `isRTL` and icons are ignored.
- **gum_notify:** the item icon is not shown.

## Feather menu: `feather-menu` (v1) and minigames: `bcc-minigames`
`FeatherMenu = exports['feather-menu'].initiate()`: RegisterMenu, RegisterPage, RegisterElement (header, subheader, line,
bottomline, textdisplay, html, button, input, textarea, slider, arrows, toggle, checkbox, dropdown, gridslider, imagebox,
imageboxcontainer, pagearrows), RouteTo, Open, Close, Notify, plus the FeatherMenu:opened / closed / Page:RoutedTo events.
Menus use the MULTI look and follow the UI presets: a script's size and layout styles are kept, its colours, borders and
fonts are not.

`MiniGame = exports['bcc-minigames'].initiate()`: Start / Stop / Trigger with skillcheck, lockpick, rps, hammertime,
cowmilker and diceroller, as simple MULTI-styled skill checks with the same results. Escape cancels a game (failed result).

## Prompts: `uiprompt`
Scripts that include `@uiprompt/uiprompt.lua` get MULTIcore's own `uiprompt` resource (in `[multicore]`): Uiprompt,
UipromptGroup and UipromptManager with the same constructors, setters and `setOn...` handlers. Put `ensure uiprompt`
before the scripts that use it.

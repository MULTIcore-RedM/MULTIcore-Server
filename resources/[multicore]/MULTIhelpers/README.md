# MULTIhelpers

Part of MULTIcore (GPL v3). One resource that stands in for three VORP helper resources:

| Stands in for | What it is |
|---|---|
| `vorp_menu` | the `MenuData` list menus VORP scripts open |
| `vorp_inputs` | the text / number input box |
| `vorp_progressbar` | the timed progress bar |

The fxmanifest `provide`s all three names, so scripts that list them as dependencies start fine. Every export is registered under `MULTIhelpers` **and** under the VORP name it replaces. All three draw in the MULTIcore theme (`MULTIcore/html/theme/multi.css`).

This is our own code, written from VORP's public docs (docs.vorp-core.com, *API reference: menu, inputs, progressbar*) and from how scripts call these resources. No VORP code is used.

## Setup

```
ensure oxmysql
ensure ox_lib
ensure MULTIcore
ensure MULTIhelpers
```

Remove `ensure vorp_menu`, `ensure vorp_inputs` and `ensure vorp_progressbar`. If one of them starts anyway, MULTIhelpers steps aside for that name and prints a warning in F8.

RINGOui also stands in for `vorp_progressbar`. Run only one of the two stand-ins for it.

## Config (`config.lua`)

Every option has a comment. The main ones:

- `Config.Locale`: the language (`en`, `de`, `fr`, `es`, `pt-br`, `it`, `pl`, `ru`, `nl`, `tr`). If it is not set, the server's `setr multicore_locale` is used, then `en`.
- `Config.Menu`: default position (`Align`, `OffsetTop`, `OffsetSide`), `Width`, `MaxVisibleItems`, `GridColumns`, key hints, `CursorByDefault`, `KeepGameInput`, the navigation `Keys` and the frontend `Sounds`.
- `Config.Inputs`: `CancelResult` (what a cancelled box returns, `''` by default, like VORP), `AllowCustomStyle`, `Width`.
- `Config.Progress`: `TakeFocus`, `DefaultTheme`, `Color`, `TrackColor`, `Width`, `CircleSize`, `Bottom`, `ShowPercent`, `ProgressBarsStartUI`.

To restyle, use `html/custom.css`. It loads last.

## Menu: `vorp_menu`

The older way works too (syn_* and many older scripts use it). MULTIhelpers must start before those scripts:
`TriggerEvent('menuapi:getData', function(call) MenuData = call end)` (also `vorp_menu:getData`). The events
`menuapi:closemenu`, `vorp_menu:closemenu` and `vorp_menu:openmenu` fire as in the original.

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
- **Notifications:** MULTIhelpers sends none.

## Languages
Words of our own (default buttons, key hints, input check messages and console warnings) come from `locales/*.lua`. Text from the calling script is shown as it is. `ru` switches the page to the theme's Cyrillic font preset.

## RedEM:RP (redemrp_menu_base, redemrp_progressbars)

`TriggerEvent('redemrp_menu_base:getData', cb)` gives the same menu as vorp_menu. `exports.redemrp_progressbars:DisplayProgressBar(ms, text, cb)` shows the MULTIhelpers bar, waits for it and then calls `cb`.


# MULTIcore UI guide

How to make a MULTI script's screens look like every other MULTI script. Follow it to the letter and the result will match without any design work.

**Hand this file and `MULTIcore-UI-Kit.zip` to whoever writes your script, or to your coding tools, together with `MULTIcore-Script-Rules.md`.** The kit holds the theme, a complete working example menu and three real MULTI pages to copy from.

## What's in the kit

| Folder | What it is |
|---|---|
| `theme/multi.css` | The shared theme. In game it is at `nui://MULTIcore/html/theme/multi.css`; never copy it into your script, link it |
| `theme/img/mc-mark.png` | The small MC mark shown above menu titles |
| `theme/fonts/README.md` | Which game fonts the theme uses when they are installed |
| `example/html/` | **Start here.** A complete store-style menu that shows every part: mark, title, tabs, rows, money, a text field, a slider, buttons and key prompts. Open `index.html` in a browser to see it with test data |
| `reference/MULTIstores/` | The real store menu |
| `reference/MULTItarget/` | The target list (a small card beside the middle of the screen) |
| `reference/MULTIchat/` | The chat (black lines, black text box) |

## The look in one paragraph

Red Dead Redemption 2's own menus: **black see-through panels, white lettering, a white frame round the selected row, thin white rules that fade at the ends, key prompts in small white boxes.** No brown, no cream, no paper, no parchment, no wood, no textures, no gradients other than the panel's soft edge, no rounded corners, no drop shadows, no glow, no endless animations. Colour is used only for meaning: red for danger or "can't afford", green for good, gold for gold bars.

## Rules

1. **Link the theme first, then your own CSS, then `custom.css` last:**
   ```html
   <link rel="stylesheet" href="nui://MULTIcore/html/theme/multi.css">
   <link rel="stylesheet" href="style.css">
   <link rel="stylesheet" href="custom.css">
   ```
2. **Put `class="mc-root"` on your page's root element.** Everything inside inherits the fonts, colours and size.
3. **Use the theme's classes** (table below) for panels, titles, rows, buttons and fields. Your own `style.css` holds **layout only** (position, width, grid, gaps).
4. **Never write a colour or font in your CSS.** Use the variables: `var(--mc-ink)`, `var(--mc-ink-dim)`, `var(--mc-paper)`, `var(--mc-line)`, `var(--mc-font-ui)`, and so on.
5. **Sizes go through `--mc-scale`:** `calc(440px * var(--mc-scale))`, so a server owner can make every MULTI screen bigger at once.
6. **Prefix your own classes** with two letters for your script (`mx-col`, `mx-row`), so they never clash with `mc-` theme classes.
7. **Ship an empty, commented `html/custom.css`** and list it in `files {}`.
8. **No words in the HTML or JS.** Every visible word comes from the locale table Lua sends (`_LT()`); mark elements with `data-l="key"` and fill them in JS. Add `mc-cyrillic` to the root when the language is `ru`.
9. **Player text goes in with `textContent`, never `innerHTML`.**
10. **Hide with `mc-hidden`.** Fade in once with `mc-fade`. Nothing animates forever.
11. **Placement:**
    - menus: a black column on the left (like the stores);
    - small cards: beside the middle of the screen;
    - key prompts: bottom centre;
    - the HUD: centre bottom;
    - notifications: use `exports.MULTIcore:Notify`, never your own.
12. **No marker dots, markers, sprites or floating 3D text in the world, ever.** World interaction is MULTItarget (hold Left Alt).
13. **Small menus and dialogs:** use ox_lib (`lib.registerContext`, `lib.inputDialog`, `lib.alertDialog`, `lib.progressBar`) instead of building a page. Set `setr ox:primaryColor gray` in server.cfg so their highlights are grey, not blue.
14. **Font Awesome icons** are fine (cdnjs link, as in `reference/MULTItarget/index.html`). Keep icons white.

## Theme classes

| Class | Use |
|---|---|
| `mc-root` | Page root (fonts, colours, size) |
| `mc-hidden` | Hide anything |
| `mc-panel` | Black see-through panel with soft top and bottom edges |
| `mc-title` | Big title (game title font, upper case) |
| `mc-subtitle` | Small line above the title (town, shop type) |
| `mc-heading` | Section heading |
| `mc-rule` (on `<hr>`) | Thin white line fading at both ends |
| `mc-note` | Dim small text |
| `mc-hand` | Italic description text |
| `mc-tabs` + `mc-tab` (`.active`) | Tab row; the active tab is underlined |
| `mc-list` + `mc-row` (`.active`, `.disabled`) | List rows; the active row gets the white frame. `mc-sub` inside a row is a dim second line |
| `mc-btn` (`.primary`, `.danger`, `.small`) | Buttons: white words in a thin frame; primary is white with black text |
| `mc-btn-row` | A row of buttons |
| `mc-field` + `label` | A labelled field |
| `mc-input`, `mc-select`, `mc-textarea` | Black inputs with a thin white frame |
| `mc-slider` (`mc-slider-label`, `mc-slider-value`, `input[type=range]`) | Slider with its label and value |
| `mc-stepper` (`button`, `mc-stepper-text`) | ‹ value › picker |
| `mc-swatches` + `mc-swatch` (`.active`) | Colour picker squares |
| `mc-money` + `mc-cents` | Money, with small raised cents: `$12<span class="mc-cents">50</span>` |
| `mc-gold`, `mc-red`, `mc-cant` | Gold amounts, danger / can't afford |
| `mc-key` inside `mc-prompts` | Game-style key prompt: `<span class="mc-key">E</span>Open` |
| `mc-scroll` | Scroll area with a thin white scroll bar |
| `mc-brand mc-brand-above` (on the mark `<img>`) | The MC mark above a centred title. Also `mc-brand-left`, `mc-brand-corner`, `mc-brand-sm` |
| `mc-fade` | Fade in once |
| `mc-cyrillic` | Russian font preset |

## Variables

| Variable | Meaning |
|---|---|
| `--mc-scale` | Text and size scale (1 = normal) |
| `--mc-zoom` | Zoom whole panels |
| `--mc-panel` | Panel darkness (0 to 1) |
| `--mc-ink`, `--mc-ink-dim`, `--mc-ink-faint` | White, dim white, faint white |
| `--mc-paper`, `--mc-paper-2`, `--mc-paper-3` | Panel black, row black, hover white |
| `--mc-line`, `--mc-line-strong` | Thin and strong white lines |
| `--mc-red`, `--mc-good`, `--mc-bad`, `--mc-gold` | Meaning colours only |
| `--mc-font-title`, `--mc-font-ui`, `--mc-font-body`, `--mc-font-hand` | Fonts |
| `--mc-size-title`, `--mc-size-heading`, `--mc-size-ui`, `--mc-size-body`, `--mc-size-small` | Text sizes (already scaled) |

## The Lua side of a page

```lua
-- fxmanifest.lua
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js', 'html/custom.css' }

-- client/main.lua
local open = false

local function openMenu(items, cash)
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', text = _LT(), lang = _LCode(), cash = cash, tabs = Config.Tabs, items = items })
end

local function closeMenu()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb) cb('ok'); closeMenu() end)

RegisterNUICallback('buy', function(data, cb)
    cb('ok')
    -- the server decides: it checks the item, the amount, the price and the player's money
    TriggerServerEvent('MULTIexample:buy', data.name, tonumber(data.amount) or 1)
end)
```

The page talks back with `fetch('https://' + GetParentResourceName() + '/buy', { method: 'POST', body: JSON.stringify(...) })` (see `example/html/app.js`).

## Before you call a screen done

- Open your `index.html` in a browser with test data (the example shows how) and look at it at 1366 x 768 and 1920 x 1080.
- Check it against the reference pages: black, white, white frame on the selected row, no brown, no dots.
- Try `ru` once to see the Cyrillic preset.

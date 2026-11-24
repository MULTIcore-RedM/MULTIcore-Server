-- ============================================================
-- MULTIhelpers :: config
-- Every option has a one-line comment and its default.
-- Text lives in locales/<lang>.lua, looks in html/custom.css.
-- ============================================================

Config = {}

Config.Locale = nil                 -- language for this script ('de', 'fr', ...); nil = MULTIcore's language (MULTIConfig.Language), else 'en'
Config.Debug = false                -- print debug lines (menu opens, inputs, bars) to the F8 console

-- ------------------------------------------------------------ menu (vorp_menu)
Config.Menu = {
    MaxVisibleItems = 8,            -- rows shown at once when a menu does not set maxVisibleItems
    Align = 'top-left',             -- default position when a menu does not set align ('top-left', 'top-center', 'top-right')
    OffsetTop = '8vh',              -- distance from the top of the screen (any CSS length)
    OffsetSide = '3vw',             -- distance from the left / right edge (any CSS length)
    Width = '25vw',                 -- menu width (any CSS length; min 340px, max 460px in style.css)
    GridColumns = 4,                -- tiles per row in grid menus (isGrid = true)
    ShowKeyHints = true,            -- show the key hints (Move / Select / Back) under the menu
    CursorByDefault = false,        -- show the mouse cursor on every menu, not only menus with enableCursor = true
    KeepGameInput = true,           -- the game keeps keyboard input while a menu is open, as with vorp_menu: scripts'
                                    -- own key loops (rotate / zoom a preview) keep working; false = the menu takes the keyboard

    -- Navigation keys (browser KeyboardEvent.key names). The VORP docs reserve these while a menu is open.
    Keys = {
        Up = 'ArrowUp',             -- previous row
        Down = 'ArrowDown',         -- next row
        Left = 'ArrowLeft',         -- slider down / previous option
        Right = 'ArrowRight',       -- slider up / next option
        Select = 'Enter',           -- submit the row
        Back = 'Backspace',         -- back to lastmenu (or cancel when the menu has none)
        Close = 'Escape',           -- cancel
        NextSlider = 'Tab',         -- next sub-slider on a desc-slider row
    },

    -- Frontend sounds { name, soundset } from the game's frontend sound list; false mutes one.
    Sounds = {
        open   = { 'INFO_SHOW', 'Ledger_Sounds' },     -- a menu opens
        close  = { 'INFO_HIDE', 'Ledger_Sounds' },     -- a menu closes
        up     = { 'NAV_UP', 'Ledger_Sounds' },        -- move up
        down   = { 'NAV_DOWN', 'Ledger_Sounds' },      -- move down
        left   = { 'NAV_LEFT', 'Ledger_Sounds' },      -- slider / option left
        right  = { 'NAV_RIGHT', 'Ledger_Sounds' },     -- slider / option right
        select = { 'SELECT', 'HUD_SHOP_SOUNDSET' },    -- submit
        back   = { 'BACK', 'HUD_SHOP_SOUNDSET' },      -- back / cancel
    },
}

-- ------------------------------------------------------------ input box (vorp_inputs)
Config.Inputs = {
    CancelResult = '',              -- what a cancelled input returns; '' is what VORP scripts expect (nil = Lua nil)
    AllowCustomStyle = false,       -- apply the caller's attributes.style CSS to the input; false = keep the theme look
    Width = '26vw',                 -- input box width (any CSS length)
}

-- ------------------------------------------------------------ progress bar (vorp_progressbar)
Config.Progress = {
    TakeFocus = true,               -- a running bar takes the keyboard so the player stands still (caller can pass focus = false)
    DefaultTheme = 'linear',        -- theme when the caller gives none or an unknown one ('linear', 'circle', 'innercircle')
    Color = nil,                    -- default fill colour (any CSS colour); nil = theme red
    TrackColor = nil,               -- background of the bar / ring (any CSS colour); nil = theme dark
    Width = '24vw',                 -- default linear bar width (any CSS length); a caller's width wins
    CircleSize = '84px',            -- default circle size (any CSS length); a caller's width wins
    Bottom = '9vh',                 -- distance from the bottom of the screen (any CSS length)
    ShowPercent = true,             -- show the percentage inside the circle themes
    ProgressBarsStartUI = true,     -- also answer the old exports.progressBars:startUI(time, text) when progressBars is not running
}

-- ------------------------------------------------------------ notifications (redemrp_notification, gum_notify, rsg_notify, pNotify, bln_notify)
-- All of them are drawn by MULTIcore's notifications (MULTIcore/config_notify.lua sets the look).
Config.Notify = {
    DefaultDuration = 5000,         -- ms on screen when a call gives no time
    GumStyle = 'toast',             -- MULTIcore style for gum_notify ('toast', 'tip', 'objective', 'banner')
    RsgBottomStyle = 'tip',         -- MULTIcore style for rsg_notify's bottom-centre text
    BlnTipStyle = 'tip',            -- MULTIcore style for bln_notify tips and TIP_* templates
}

-- ------------------------------------------------------------ skill bar (syn_minigame, fx-minigame)
Config.Minigame = {
    Key = 'E',                      -- key the player presses (browser KeyboardEvent.key, not case sensitive)
    MinZone = 4,                    -- narrowest target zone, in % of the bar (a skillGap below this is widened)
    MaxZone = 50,                   -- widest target zone, in % of the bar
    ZoneFrom = 30,                  -- the zone never starts before this % of the bar
    ZoneTo = 95,                    -- ... and never ends after this %
    MinSweep = 600,                 -- fastest sweep in ms (a lower difficulty is slowed to this)
}

-- ------------------------------------------------------------ QB-style progress bar (progressbar, RSG v1 / QBR scripts)
Config.QBProgress = {
    CancelKeys = { 0x8CC9CD42, 0x156F7119 },   -- controls that cancel a bar with canCancel = true (X, Backspace)
    BusyMessage = true,             -- tell the player when a second bar is refused (already busy)
}

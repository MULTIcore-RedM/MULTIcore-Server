-- ============================================================
-- MULTIcore :: notification settings
-- Every MULTI script notifies through MULTIcore, and RSG / VORP
-- notifications are routed here too, so they all look the same.
-- Change anything below; colours and fonts also follow the shared
-- theme (html/theme/multi.css) and html/notify/custom.css.
--
-- Use from any script:
--   client: exports.MULTIcore:Notify({ text = 'Hello', type = 'success' })
--           exports.MULTIcore:Notify('Hello', 'success', 5000)
--   server: exports.MULTIcore:Notify(src, { text = 'Hello', type = 'money', style = 'tip' })
--           exports.MULTIcore:NotifyAll('Storm coming', 'warning')
-- ============================================================

NotifyConfig = {}

-- ------------------------------------------------------------
-- General
-- ------------------------------------------------------------
NotifyConfig.DefaultType = 'info'        -- type used when none (or an unknown one) is given
NotifyConfig.DefaultStyle = 'toast'      -- style used when none is given: toast, tip, objective, banner
NotifyConfig.MinDuration = 1500          -- shortest time a notification stays (ms)
NotifyConfig.MaxDuration = 60000         -- longest time (ms). duration = -1 stays until ClearNotify(id) / ClearAll()
NotifyConfig.Dedupe = true               -- the same message again while it is still shown counts up (x2, x3) instead of stacking
NotifyConfig.Sounds = true               -- false = never play notification sounds
NotifyConfig.SoundGap = 250              -- ms between two sounds, so a burst of messages plays one sound
NotifyConfig.StripGameCodes = true       -- remove game colour codes such as ~e~ or ~COLOR_RED~ from text

-- ------------------------------------------------------------
-- Styles: where and how each kind of notification is drawn
--   toast     = stacked boxes in a screen corner (most messages)
--   tip       = one small line at the bottom centre (hints)
--   objective = one line at the top centre (what to do next)
--   banner    = big title and text in the middle, like the game's mission text
-- ------------------------------------------------------------
NotifyConfig.Styles = {
    toast = {
        position = 'top-left',    -- top-right, top-left, bottom-right, bottom-left, middle-right, middle-left
        offsetX = 28,            -- px from the side of the screen
        offsetY = 90,            -- px from the top / bottom of the screen
        width = 340,             -- px
        duration = 5000,         -- default ms
        max = 5,                 -- most toasts on screen; the oldest goes first
    },
    tip = {
        offsetY = 110,           -- px from the bottom of the screen
        duration = 4000,
        max = 1,                 -- a new tip replaces the old one
    },
    objective = {
        offsetY = 60,            -- px from the top of the screen
        duration = 6000,
        max = 1,
    },
    banner = {
        top = 30,                -- % from the top of the screen
        duration = 5000,
        max = 1,
        sound = { 'REWARD_MORALE', 'HUD_REWARD_SOUNDSET' },  -- played for every banner instead of the type's sound (false = use the type's)
    },
}

-- ------------------------------------------------------------
-- Types: accent colour, icon (any text or unicode sign, no images),
-- sound { soundName, soundSet } or false, and whether the type puts a
-- default title on top (words from locales/notify_<lang>.lua).
-- Sound names are game frontend sounds; keep to known pairs.
-- ------------------------------------------------------------
NotifyConfig.Types = {
    info    = { color = '#ffffff', icon = 'i',      sound = false,                                    title = false },
    success = { color = '#8fbf6a', icon = '\u{2714}', sound = { 'YES', 'HUD_DOMINOS_SOUNDSET' },        title = false },
    error   = { color = '#c0281e', icon = '\u{2716}', sound = { 'UNAFFORDABLE', 'Ledger_Sounds' },      title = false },
    warning = { color = '#d9a441', icon = '!',      sound = { 'INFO', 'HUD_SHOP_SOUNDSET' },          title = false },
    money   = { color = '#8fbf6a', icon = '$',      sound = { 'PURCHASE', 'HUD_SHOP_SOUNDSET' },      title = false },
    gold    = { color = '#d6b25e', icon = '\u{25C6}', sound = { 'SELL', 'HUD_SHOP_SOUNDSET' },          title = false },
    job     = { color = '#cfcfcf', icon = '\u{2692}', sound = { 'READ', 'HUD_SHOP_SOUNDSET' },          title = false },
    police  = { color = '#7f9fcc', icon = '\u{2605}', sound = { 'Whistle', 'Flex_Fight_Sounds' },       title = true  },
    medic   = { color = '#c0281e', icon = '\u{271A}', sound = { 'Core_Fill_Up', 'Consumption_Sounds' }, title = true  },
}
-- Other sounds you can use (all known game pairs):
--   { 'INFO_SHOW', 'Ledger_Sounds' }  { 'SELECT', 'HUD_SHOP_SOUNDSET' }  { 'MONEY', 'HUD_DOMINOS_SOUNDSET' }
--   { 'NO', 'HUD_DOMINOS_SOUNDSET' }  { 'MAIL', 'HUD_MAIL_SOUNDSET' }    { 'ITEM_TICKER_GENERIC', 'HUD_REWARD_SOUNDSET' }
--   { 'Horn', 'Flex_Fight_Sounds' }   { 'BET_PROMPT', 'HUD_POKER' }      { 'Tithe_Donation_Small', 'Tithe_Donation_Sounds' }

-- Other names scripts use for a type, mapped to one of the types above
NotifyConfig.TypeAliases = {
    primary = 'info', inform = 'info', information = 'info', default = 'info',
    ok = 'success', good = 'success',
    fail = 'error', failed = 'error', danger = 'error', bad = 'error',
    warn = 'warning',
    cash = 'money', dollar = 'money', dollars = 'money',
    sheriff = 'police', law = 'police', lawman = 'police',
    ambulance = 'medic', doctor = 'medic', medical = 'medic', ems = 'medic',
}

-- ------------------------------------------------------------
-- RSG scripts (RSGCore.Functions.Notify on the client, and the
-- older client event 'RSGCore:Notify')
-- ------------------------------------------------------------
NotifyConfig.RouteRSG = true             -- false = RSGCore.Functions.Notify keeps using ox_lib
NotifyConfig.RSGStyle = 'toast'          -- style for RSG notifications
NotifyConfig.RSGTypes = {                -- RSG type -> MULTI type
    primary = 'info', inform = 'info', info = 'info',
    success = 'success', error = 'error', warning = 'warning',
    police = 'police', ambulance = 'medic',
}


-- ------------------------------------------------------------
-- VORP scripts: the VORP face (client/vorp/notify.lua) sends every
-- Core.NotifyX and old vorp:* event here with its own style and type.
-- They may pass a game colour name and a game icon; these settings
-- decide what happens with them.
-- ------------------------------------------------------------
NotifyConfig.RouteVorpServer = true      -- server Core.Notify(src, text, type, ms) uses this system instead of ox_lib

-- Game colour names (as VORP scripts pass them) -> CSS colour for the accent.
-- Unknown names are ignored (the type's own colour is kept). A CSS colour
-- such as '#a0c060' may also be passed directly.
NotifyConfig.Colors = {
    COLOR_WHITE = '#e6e6e6', COLOR_PURE_WHITE = '#ffffff', COLOR_BLACK = '#3a3a3a',
    COLOR_GREY = '#9b9b9b', COLOR_GREYMID = '#7a7a7a', COLOR_GREYDARK = '#555555',
    COLOR_RED = '#c0281e', COLOR_REDDARK = '#7f1a14', COLOR_REDLIGHT = '#e05a4e',
    COLOR_GREEN = '#8fbf6a', COLOR_GREENDARK = '#4f7a35', COLOR_GREENLIGHT = '#b4d998',
    COLOR_BLUE = '#7f9fcc', COLOR_BLUEDARK = '#4a6a99', COLOR_BLUELIGHT = '#a9c4e6',
    COLOR_YELLOW = '#e5cf5a', COLOR_YELLOWDARK = '#b09a2e', COLOR_ORANGE = '#d9862e',
    COLOR_GOLD = '#d6b25e', COLOR_SILVER = '#c0c4c8', COLOR_BRONZE = '#b07a44',
    COLOR_PURPLE = '#9a78c0', COLOR_PINK = '#e08ab0', COLOR_BROWN = '#8a6440',
}

-- Game icons (icon + iconDict, a texture in a game texture dictionary).
-- A web page cannot read game textures in a way that is known to work in
-- RedM, so by default the type's own sign is shown instead. true = try
-- the https://nui-img/<dict>/<texture> address (works in FiveM; not
-- tested in RedM) and fall back to the type's sign if it does not load.
NotifyConfig.GameIcons = false

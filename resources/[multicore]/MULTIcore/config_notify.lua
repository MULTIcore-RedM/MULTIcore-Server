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
--
-- Every style can be put anywhere and sized:
--   position = where on the screen it sits:
--              'top-left'    'top-center'    'top-right'
--              'middle-left' 'center'        'middle-right'
--              'bottom-left' 'bottom-center' 'bottom-right'
--   offsetX  = px in from the left / right edge (for a -center position: px right of the middle, negative = left)
--   offsetY  = px in from the top / bottom edge (for a middle- position or 'center': px below the middle, negative = above)
--   width    = px wide (0 = as wide as its text needs)
--   scale    = size of the whole notification: text, box and icon (1 = normal, 0.8 = smaller, 1.3 = bigger)
--   align    = text alignment: 'auto' (follows the side of the screen), 'left', 'center', 'right'
--   duration = default ms on screen      max = most of this style on screen at once (the oldest goes first)
-- Players can also move and resize them in game with /notifylayout (NotifyConfig.Editor below).
NotifyConfig.Styles = {
    toast = {
        position = 'top-left',
        offsetX = 28,
        offsetY = 90,
        width = 340,
        scale = 1.0,
        align = 'auto',
        duration = 5000,
        max = 5,
    },
    tip = {
        position = 'bottom-center',
        offsetX = 0,
        offsetY = 110,
        width = 0,
        scale = 1.0,
        align = 'center',
        duration = 4000,
        max = 1,                 -- a new tip replaces the old one
    },
    objective = {
        position = 'top-center',
        offsetX = 0,
        offsetY = 60,
        width = 0,
        scale = 1.0,
        align = 'center',
        duration = 6000,
        max = 1,
    },
    banner = {
        position = 'center',
        offsetX = 0,
        offsetY = -170,          -- above the middle of the screen
        width = 1100,
        scale = 1.0,
        align = 'center',
        duration = 5000,
        max = 1,
        sound = { 'REWARD_MORALE', 'HUD_REWARD_SOUNDSET' },  -- played for every banner instead of the type's sound (false = use the type's)
    },
}

-- ------------------------------------------------------------
-- Look: how the notifications are drawn (all styles). The default is the
-- game's own look: black boxes fading out at the edges, white words.
-- Pick a ready-made Preset, then change any single value below it.
--   'game'    = the game's look (default)
--   'box'     = solid black boxes with a thin white border
--   'card'    = solid boxes with rounded corners and the type's colour along the top
--   'minimal' = no box at all, only words with a shadow
-- Colours: any CSS colour, e.g. '#000000', 'rgba(0, 0, 0, 0.8)', 'white'.
-- Anything left as nil follows the Preset. For more, html/notify/custom.css.
-- ------------------------------------------------------------
NotifyConfig.Look = {
    Preset = 'game',

    Background = nil,        -- box colour, e.g. 'rgba(0, 0, 0, 0.82)'
    FadeEdges = nil,         -- true = the box fades out at its edges (game look); false = a solid box
    Border = nil,            -- e.g. '1px solid rgba(255, 255, 255, 0.35)', or 'none'
    Radius = nil,            -- corner rounding in px (0 = square)
    Padding = nil,           -- space inside the box, e.g. '11px 14px'
    AccentEdge = nil,        -- px of the type's colour along one edge of the box (0 = none)
    AccentSide = nil,        -- that edge: 'screen' (towards the screen edge), 'left', 'right', 'top', 'bottom'
    TextColor = nil,         -- main words
    TitleColor = nil,        -- titles
    DimColor = nil,          -- words under a title
    TextShadow = nil,        -- e.g. '0 1px 2px #000', or 'none'
    TitleUppercase = nil,    -- true = titles in capitals
    TitleFont = nil,         -- font for titles, e.g. 'Oswald'; nil = MULTIcore's game font
    BodyFont = nil,          -- font for the words; nil = MULTIcore's game font
    TextSize = nil,          -- px before scale (theme default 16)
    TitleSize = nil,         -- px before scale (theme default 17)
    ShowIcons = nil,         -- false = no sign in front of toasts and tips
    IconSize = nil,          -- px before scale
    Gap = nil,               -- px between stacked notifications
    Animation = nil,         -- 'slide' (fade and slide in), 'fade', 'none'
    FadeMs = nil,            -- ms the fade in / out takes
}

-- ------------------------------------------------------------
-- In-game layout editor. /notifylayout shows one of each style: drag them
-- where you want them, mouse wheel = bigger / smaller, Shift + wheel = wider /
-- narrower, then Save. It is kept on that player's own PC, so only their screen
-- changes. Saving also prints the positions to the F8 console in the form
-- NotifyConfig.Styles uses, so a server owner can set everyone's default the
-- same way: lay it out, save, copy the lines into this file.
-- ------------------------------------------------------------
NotifyConfig.Editor = {
    Command = 'notifylayout',     -- false = no editor
    Players = true,               -- true = every player can set their own layout; false = only admins (ace 'command')
    ResetCommand = 'notifyreset', -- puts the player's layout back to the server's
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

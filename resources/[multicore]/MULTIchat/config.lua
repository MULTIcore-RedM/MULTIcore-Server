-- ============================================================
-- MULTIchat :: config
-- MULTIcore's own chat. Every option has a one-line comment.
-- ============================================================

Config = {}

-- Config.Locale = 'en'           -- language for this script only (else MULTIcore's language (MULTIConfig.Language), else English)

Config.OpenKey = 0x9720FCEE       -- MpTextChatAll (T): opens the chat box
Config.Scale = 1.0                -- size of the chat (1 = normal, 1.2 = 20% bigger)
Config.MaxMessages = 100          -- lines kept in the chat before the oldest are dropped
Config.FadeSeconds = 12           -- with the box closed, new lines show this long, then fade
Config.MaxLength = 256            -- longest message a player can send (characters)
Config.CooldownMs = 750           -- shortest time between two messages from one player (ms)
Config.UseCharacterName = true    -- true = the character's first and last name, false = the player's account name
Config.LogToConsole = true        -- print /me, /do, /try and plain text to the server console

-- What plain text (no / in front) does:
--   'local'  = shows "Name: text" to players within Config.Range.say
--   'global' = shows it to everyone on the server
--   'off'    = plain text is not sent; players must use a command
Config.PlainText = 'local'

-- How far (metres) each kind of message is heard. Players in another routing bucket never see it.
Config.Range = {
    me  = 20.0,
    ['do'] = 20.0,
    try = 20.0,
    say = 20.0,
}

-- Command names (without the /). Set one to false to turn that command off.
Config.Commands = {
    Me    = 'me',                 -- /me tips his hat      -> * Jack Hale tips his hat
    Do    = 'do',                 -- /do the door is locked -> * The door is locked (( Jack Hale ))
    Try   = 'try',                -- /try to pick the lock  -> * Jack Hale tries to pick the lock and succeeds / fails
    Clear = 'clear',              -- clears your own chat
    Hide  = 'togglechat',         -- hides or shows the chat
}

Config.TryChance = 50             -- chance (%) that /try succeeds

-- Colours of each kind of line. text = letters, bg = the band behind the line.
-- Change them here, or in html/custom.css.
Config.Styles = {
    me     = { text = '#ffffff', bg = 'rgba(0, 0, 0, 0.88)' },   -- white on black
    ['do'] = { text = '#5fa8ff', bg = 'rgba(0, 0, 0, 0.88)' },   -- blue on black
    try    = { text = '#ffffff', bg = 'rgba(0, 0, 0, 0.88)', good = '#8fbf6a', bad = '#d04a3c' },
    say    = { text = '#ffffff', bg = 'rgba(0, 0, 0, 0.55)' },   -- plain text
    system = { text = '#ffffff', bg = 'rgba(0, 0, 0, 0.55)' },   -- messages from other scripts
}

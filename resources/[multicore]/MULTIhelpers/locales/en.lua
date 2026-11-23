-- MULTIhelpers :: en (master: every key lives here first)
Locales = Locales or {}
Locales['en'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Confirm",
    ['cancel'] = "Cancel",
    ['yes'] = "Yes",
    ['no'] = "No",
    -- key hints under a menu
    ['key_move'] = "Move",
    ['key_change'] = "Change",
    ['key_next'] = "Next",
    ['key_select'] = "Select",
    ['key_back'] = "Back",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Not allowed",
    ['err_letters'] = "Letters only",
    ['err_numbers'] = "Numbers only",
    ['err_alphanumeric'] = "Letters and numbers only",
    ['err_no_symbols'] = "No symbols",
    ['err_username'] = "At least 3 letters, numbers, _ . or -",
    ['err_phone'] = "Numbers, spaces and + - ( ) only",
    ['err_email'] = "Not an e-mail address",
    ['err_money'] = "An amount, like 12.50",
    ['err_no_special'] = "No special characters",
    -- console lines for the server owner
    ['warn_running'] = "%s is running - remove \"ensure %s\" from server.cfg, MULTIhelpers stands in for it.",
    ['warn_started'] = "%s started next to MULTIhelpers - remove \"ensure %s\" from server.cfg.",
    ['callback_error'] = "callback error: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Press %s in the marked zone",
    ['progress_busy'] = "You are already doing something",
    ['progress_dead'] = "You can't do that while dead",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Rock",
    ["mg_paper"] = "Paper",
    ["mg_scissors"] = "Scissors",
    ["mg_win"] = "You win",
    ["mg_lose"] = "You lose",
    ["mg_tie"] = "Tie",
}

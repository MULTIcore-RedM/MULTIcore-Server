-- MULTIhelpers :: da
Locales = Locales or {}
Locales['da'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Bekræft",
    ['cancel'] = "Annuller",
    ['yes'] = "Ja",
    ['no'] = "Nej",
    -- key hints under a menu
    ['key_move'] = "Flyt",
    ['key_change'] = "Skift",
    ['key_next'] = "Næste",
    ['key_select'] = "Vælg",
    ['key_back'] = "Tilbage",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Ikke tilladt",
    ['err_letters'] = "Kun bogstaver",
    ['err_numbers'] = "Kun tal",
    ['err_alphanumeric'] = "Kun bogstaver og tal",
    ['err_no_symbols'] = "Ingen symboler",
    ['err_username'] = "Mindst 3 bogstaver, tal, _ . eller -",
    ['err_phone'] = "Kun tal, mellemrum og + - ( )",
    ['err_email'] = "Ikke en e-mailadresse",
    ['err_money'] = "Et beløb, f.eks. 12.50",
    ['err_no_special'] = "Ingen specialtegn",
    -- console lines for the server owner
    ['warn_running'] = "%s kører - fjern \"ensure %s\" fra server.cfg, MULTIhelpers erstatter det.",
    ['warn_started'] = "%s startede ved siden af MULTIhelpers - fjern \"ensure %s\" fra server.cfg.",
    ['callback_error'] = "callback-fejl: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Tryk %s i det markerede felt",
    ['progress_busy'] = "Du er allerede i gang med noget",
    ['progress_dead'] = "Det kan du ikke, mens du er død",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Sten",
    ["mg_paper"] = "Papir",
    ["mg_scissors"] = "Saks",
    ["mg_win"] = "Du vinder",
    ["mg_lose"] = "Du taber",
    ["mg_tie"] = "Uafgjort",
}

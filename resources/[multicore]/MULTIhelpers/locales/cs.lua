-- MULTIhelpers :: cs
Locales = Locales or {}
Locales['cs'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Potvrdit",
    ['cancel'] = "Zrušit",
    ['yes'] = "Ano",
    ['no'] = "Ne",
    -- key hints under a menu
    ['key_move'] = "Pohyb",
    ['key_change'] = "Změnit",
    ['key_next'] = "Další",
    ['key_select'] = "Vybrat",
    ['key_back'] = "Zpět",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Nepovoleno",
    ['err_letters'] = "Jen písmena",
    ['err_numbers'] = "Jen čísla",
    ['err_alphanumeric'] = "Jen písmena a čísla",
    ['err_no_symbols'] = "Bez symbolů",
    ['err_username'] = "Aspoň 3 písmena, čísla, _ . nebo -",
    ['err_phone'] = "Jen čísla, mezery a + - ( )",
    ['err_email'] = "Není to e-mailová adresa",
    ['err_money'] = "Částka, např. 12.50",
    ['err_no_special'] = "Bez zvláštních znaků",
    -- console lines for the server owner
    ['warn_running'] = "%s běží - odeber \"ensure %s\" ze server.cfg, MULTIhelpers ho nahrazuje.",
    ['warn_started'] = "%s se spustil vedle MULTIhelpers - odeber \"ensure %s\" ze server.cfg.",
    ['callback_error'] = "chyba callbacku: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Stiskni %s v označené zóně",
    ['progress_busy'] = "Už něco děláš",
    ['progress_dead'] = "To nejde, když jsi mrtvý",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Kámen",
    ["mg_paper"] = "Papír",
    ["mg_scissors"] = "Nůžky",
    ["mg_win"] = "Vyhráváš",
    ["mg_lose"] = "Prohráváš",
    ["mg_tie"] = "Remíza",
}

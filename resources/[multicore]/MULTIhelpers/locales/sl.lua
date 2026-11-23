-- MULTIhelpers :: sl (Slovenian)
Locales = Locales or {}
Locales['sl'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Potrdi",
    ['cancel'] = "Prekliči",
    ['yes'] = "Da",
    ['no'] = "Ne",
    -- key hints under a menu
    ['key_move'] = "Premik",
    ['key_change'] = "Spremeni",
    ['key_next'] = "Naprej",
    ['key_select'] = "Izberi",
    ['key_back'] = "Nazaj",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Ni dovoljeno",
    ['err_letters'] = "Samo črke",
    ['err_numbers'] = "Samo številke",
    ['err_alphanumeric'] = "Samo črke in številke",
    ['err_no_symbols'] = "Brez simbolov",
    ['err_username'] = "Vsaj 3 črke, številke, _ . ali -",
    ['err_phone'] = "Samo številke, presledki in + - ( )",
    ['err_email'] = "To ni e-poštni naslov",
    ['err_money'] = "Znesek, npr. 12.50",
    ['err_no_special'] = "Brez posebnih znakov",
    -- console lines for the server owner
    ['warn_running'] = "%s teče - odstrani \"ensure %s\" iz server.cfg, MULTIhelpers ga nadomešča.",
    ['warn_started'] = "%s se je zagnal poleg MULTIhelpers - odstrani \"ensure %s\" iz server.cfg.",
    ['callback_error'] = "napaka povratnega klica: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Pritisni %s v označenem območju",
    ['progress_busy'] = "Nekaj že počneš",
    ['progress_dead'] = "Tega ne moreš, ko si mrtev",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Kamen",
    ["mg_paper"] = "Papir",
    ["mg_scissors"] = "Škarje",
    ["mg_win"] = "Zmagaš",
    ["mg_lose"] = "Izgubiš",
    ["mg_tie"] = "Neodločeno",
}

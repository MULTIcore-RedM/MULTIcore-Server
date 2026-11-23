-- MULTIhelpers :: fi (Suomi)
Locales = Locales or {}
Locales['fi'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Vahvista",
    ['cancel'] = "Peruuta",
    ['yes'] = "Kyllä",
    ['no'] = "Ei",
    -- key hints under a menu
    ['key_move'] = "Liiku",
    ['key_change'] = "Vaihda",
    ['key_next'] = "Seuraava",
    ['key_select'] = "Valitse",
    ['key_back'] = "Takaisin",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Ei sallittu",
    ['err_letters'] = "Vain kirjaimia",
    ['err_numbers'] = "Vain numeroita",
    ['err_alphanumeric'] = "Vain kirjaimia ja numeroita",
    ['err_no_symbols'] = "Ei symboleita",
    ['err_username'] = "Vähintään 3 kirjainta, numeroa, _ . tai -",
    ['err_phone'] = "Vain numeroita, välilyöntejä ja + - ( )",
    ['err_email'] = "Ei sähköpostiosoite",
    ['err_money'] = "Summa, esim. 12.50",
    ['err_no_special'] = "Ei erikoismerkkejä",
    -- console lines for the server owner
    ['warn_running'] = "%s on käynnissä - poista \"ensure %s\" server.cfg-tiedostosta, MULTIhelpers korvaa sen.",
    ['warn_started'] = "%s käynnistyi MULTIhelpersin rinnalla - poista \"ensure %s\" server.cfg-tiedostosta.",
    ['callback_error'] = "callback-virhe: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Paina %s merkityllä alueella",
    ['progress_busy'] = "Teet jo jotain",
    ['progress_dead'] = "Et voi tehdä sitä kuolleena",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Kivi",
    ["mg_paper"] = "Paperi",
    ["mg_scissors"] = "Sakset",
    ["mg_win"] = "Voitit",
    ["mg_lose"] = "Hävisit",
    ["mg_tie"] = "Tasapeli",
}

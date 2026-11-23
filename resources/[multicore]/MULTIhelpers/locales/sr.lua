-- MULTIhelpers :: sr
Locales = Locales or {}
Locales['sr'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Potvrdi",
    ['cancel'] = "Otkaži",
    ['yes'] = "Da",
    ['no'] = "Ne",
    -- key hints under a menu
    ['key_move'] = "Pomeri",
    ['key_change'] = "Promeni",
    ['key_next'] = "Dalje",
    ['key_select'] = "Izaberi",
    ['key_back'] = "Nazad",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Nije dozvoljeno",
    ['err_letters'] = "Samo slova",
    ['err_numbers'] = "Samo brojevi",
    ['err_alphanumeric'] = "Samo slova i brojevi",
    ['err_no_symbols'] = "Bez simbola",
    ['err_username'] = "Bar 3 slova, brojevi, _ . ili -",
    ['err_phone'] = "Samo brojevi, razmaci i + - ( )",
    ['err_email'] = "Nije e-mail adresa",
    ['err_money'] = "Iznos, na primer 12.50",
    ['err_no_special'] = "Bez posebnih znakova",
    -- console lines for the server owner
    ['warn_running'] = "%s je pokrenut - ukloni \"ensure %s\" iz server.cfg, MULTIhelpers ga zamenjuje.",
    ['warn_started'] = "%s je pokrenut pored MULTIhelpers - ukloni \"ensure %s\" iz server.cfg.",
    ['callback_error'] = "greška u callback-u: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Pritisni %s u označenom polju",
    ['progress_busy'] = "Već nešto radiš",
    ['progress_dead'] = "To ne možeš dok si mrtav",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Kamen",
    ["mg_paper"] = "Papir",
    ["mg_scissors"] = "Makaze",
    ["mg_win"] = "Pobeđuješ",
    ["mg_lose"] = "Gubiš",
    ["mg_tie"] = "Nerešeno",
}

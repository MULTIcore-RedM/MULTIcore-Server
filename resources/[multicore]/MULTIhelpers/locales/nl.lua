-- MULTIhelpers :: nl
Locales = Locales or {}
Locales['nl'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Bevestigen",
    ['cancel'] = "Annuleren",
    ['yes'] = "Ja",
    ['no'] = "Nee",
    -- key hints under a menu
    ['key_move'] = "Bewegen",
    ['key_change'] = "Wijzigen",
    ['key_next'] = "Volgende",
    ['key_select'] = "Kiezen",
    ['key_back'] = "Terug",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Backspace",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Niet toegestaan",
    ['err_letters'] = "Alleen letters",
    ['err_numbers'] = "Alleen cijfers",
    ['err_alphanumeric'] = "Alleen letters en cijfers",
    ['err_no_symbols'] = "Geen symbolen",
    ['err_username'] = "Minstens 3 letters, cijfers, _ . of -",
    ['err_phone'] = "Alleen cijfers, spaties en + - ( )",
    ['err_email'] = "Geen geldig e-mailadres",
    ['err_money'] = "Een bedrag, bv. 12.50",
    ['err_no_special'] = "Geen speciale tekens",
    -- console lines for the server owner
    ['warn_running'] = "%s draait - haal \"ensure %s\" uit server.cfg, MULTIhelpers vervangt het.",
    ['warn_started'] = "%s is naast MULTIhelpers gestart - haal \"ensure %s\" uit server.cfg.",
    ['callback_error'] = "fout in callback: %s",
}

-- MULTIhelpers :: de
Locales = Locales or {}
Locales['de'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Bestätigen",
    ['cancel'] = "Abbrechen",
    ['yes'] = "Ja",
    ['no'] = "Nein",
    -- key hints under a menu
    ['key_move'] = "Bewegen",
    ['key_change'] = "Ändern",
    ['key_next'] = "Weiter",
    ['key_select'] = "Auswählen",
    ['key_back'] = "Zurück",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Rücktaste",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Nicht erlaubt",
    ['err_letters'] = "Nur Buchstaben",
    ['err_numbers'] = "Nur Zahlen",
    ['err_alphanumeric'] = "Nur Buchstaben und Zahlen",
    ['err_no_symbols'] = "Keine Symbole",
    ['err_username'] = "Mindestens 3 Buchstaben, Zahlen, _ . oder -",
    ['err_phone'] = "Nur Zahlen, Leerzeichen und + - ( )",
    ['err_email'] = "Keine gültige E-Mail-Adresse",
    ['err_money'] = "Ein Betrag, z. B. 12.50",
    ['err_no_special'] = "Keine Sonderzeichen",
    -- console lines for the server owner
    ['warn_running'] = "%s läuft - entferne \"ensure %s\" aus der server.cfg, MULTIhelpers ersetzt es.",
    ['warn_started'] = "%s wurde neben MULTIhelpers gestartet - entferne \"ensure %s\" aus der server.cfg.",
    ['callback_error'] = "Fehler im Callback: %s",
}

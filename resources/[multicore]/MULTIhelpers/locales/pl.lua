-- MULTIhelpers :: pl
Locales = Locales or {}
Locales['pl'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Potwierdź",
    ['cancel'] = "Anuluj",
    ['yes'] = "Tak",
    ['no'] = "Nie",
    -- key hints under a menu
    ['key_move'] = "Ruch",
    ['key_change'] = "Zmień",
    ['key_next'] = "Dalej",
    ['key_select'] = "Wybierz",
    ['key_back'] = "Wstecz",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Backspace",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Niedozwolone",
    ['err_letters'] = "Tylko litery",
    ['err_numbers'] = "Tylko cyfry",
    ['err_alphanumeric'] = "Tylko litery i cyfry",
    ['err_no_symbols'] = "Bez symboli",
    ['err_username'] = "Co najmniej 3 litery, cyfry, _ . lub -",
    ['err_phone'] = "Tylko cyfry, spacje i + - ( )",
    ['err_email'] = "To nie jest adres e-mail",
    ['err_money'] = "Kwota, np. 12.50",
    ['err_no_special'] = "Bez znaków specjalnych",
    -- console lines for the server owner
    ['warn_running'] = "%s działa - usuń \"ensure %s\" z server.cfg, MULTIhelpers go zastępuje.",
    ['warn_started'] = "%s uruchomiono obok MULTIhelpers - usuń \"ensure %s\" z server.cfg.",
    ['callback_error'] = "błąd callbacku: %s",
}

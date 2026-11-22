-- MULTIhelpers :: no (Norsk bokmål)
Locales = Locales or {}
Locales['no'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Bekreft",
    ['cancel'] = "Avbryt",
    ['yes'] = "Ja",
    ['no'] = "Nei",
    -- key hints under a menu
    ['key_move'] = "Flytt",
    ['key_change'] = "Endre",
    ['key_next'] = "Neste",
    ['key_select'] = "Velg",
    ['key_back'] = "Tilbake",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Ikke tillatt",
    ['err_letters'] = "Bare bokstaver",
    ['err_numbers'] = "Bare tall",
    ['err_alphanumeric'] = "Bare bokstaver og tall",
    ['err_no_symbols'] = "Ingen symboler",
    ['err_username'] = "Minst 3 bokstaver, tall, _ . eller -",
    ['err_phone'] = "Bare tall, mellomrom og + - ( )",
    ['err_email'] = "Ikke en e-postadresse",
    ['err_money'] = "Et beløp, som 12.50",
    ['err_no_special'] = "Ingen spesialtegn",
    -- console lines for the server owner
    ['warn_running'] = "%s kjører - fjern \"ensure %s\" fra server.cfg, MULTIhelpers tar over for den.",
    ['warn_started'] = "%s startet ved siden av MULTIhelpers - fjern \"ensure %s\" fra server.cfg.",
    ['callback_error'] = "callback-feil: %s",
}

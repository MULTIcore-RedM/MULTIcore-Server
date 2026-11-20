-- MULTIhelpers :: es
Locales = Locales or {}
Locales['es'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Confirmar",
    ['cancel'] = "Cancelar",
    ['yes'] = "Sí",
    ['no'] = "No",
    -- key hints under a menu
    ['key_move'] = "Mover",
    ['key_change'] = "Cambiar",
    ['key_next'] = "Siguiente",
    ['key_select'] = "Elegir",
    ['key_back'] = "Atrás",
    ['keyname_Enter'] = "Intro",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Retroceso",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "No permitido",
    ['err_letters'] = "Solo letras",
    ['err_numbers'] = "Solo números",
    ['err_alphanumeric'] = "Solo letras y números",
    ['err_no_symbols'] = "Sin símbolos",
    ['err_username'] = "Al menos 3 letras, números, _ . o -",
    ['err_phone'] = "Solo números, espacios y + - ( )",
    ['err_email'] = "No es un correo válido",
    ['err_money'] = "Una cantidad, p. ej. 12.50",
    ['err_no_special'] = "Sin caracteres especiales",
    -- console lines for the server owner
    ['warn_running'] = "%s está en marcha - quita \"ensure %s\" del server.cfg, MULTIhelpers lo sustituye.",
    ['warn_started'] = "%s se inició junto a MULTIhelpers - quita \"ensure %s\" del server.cfg.",
    ['callback_error'] = "error en callback: %s",
}

-- MULTIhelpers :: pt (Português, Portugal)
Locales = Locales or {}
Locales['pt'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Confirmar",
    ['cancel'] = "Cancelar",
    ['yes'] = "Sim",
    ['no'] = "Não",
    -- key hints under a menu
    ['key_move'] = "Mover",
    ['key_change'] = "Mudar",
    ['key_next'] = "Seguinte",
    ['key_select'] = "Escolher",
    ['key_back'] = "Voltar",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Não permitido",
    ['err_letters'] = "Só letras",
    ['err_numbers'] = "Só números",
    ['err_alphanumeric'] = "Só letras e números",
    ['err_no_symbols'] = "Sem símbolos",
    ['err_username'] = "Pelo menos 3 letras, números, _ . ou -",
    ['err_phone'] = "Só números, espaços e + - ( )",
    ['err_email'] = "Não é um endereço de e-mail",
    ['err_money'] = "Um valor, como 12.50",
    ['err_no_special'] = "Sem caracteres especiais",
    -- console lines for the server owner
    ['warn_running'] = "%s está a correr - retira \"ensure %s\" do server.cfg, o MULTIhelpers substitui-o.",
    ['warn_started'] = "%s arrancou junto com o MULTIhelpers - retira \"ensure %s\" do server.cfg.",
    ['callback_error'] = "erro de callback: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Prime %s na zona marcada",
    ['progress_busy'] = "Já estás a fazer algo",
    ['progress_dead'] = "Não podes fazer isso enquanto estás morto",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Pedra",
    ["mg_paper"] = "Papel",
    ["mg_scissors"] = "Tesoura",
    ["mg_win"] = "Ganhaste",
    ["mg_lose"] = "Perdeste",
    ["mg_tie"] = "Empate",
}

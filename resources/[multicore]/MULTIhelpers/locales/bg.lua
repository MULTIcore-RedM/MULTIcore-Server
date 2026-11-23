-- MULTIhelpers :: bg
Locales = Locales or {}
Locales['bg'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Потвърди",
    ['cancel'] = "Отказ",
    ['yes'] = "Да",
    ['no'] = "Не",
    -- key hints under a menu
    ['key_move'] = "Движи",
    ['key_change'] = "Смени",
    ['key_next'] = "Напред",
    ['key_select'] = "Избери",
    ['key_back'] = "Назад",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Не е позволено",
    ['err_letters'] = "Само букви",
    ['err_numbers'] = "Само цифри",
    ['err_alphanumeric'] = "Само букви и цифри",
    ['err_no_symbols'] = "Без символи",
    ['err_username'] = "Поне 3 букви, цифри, _ . или -",
    ['err_phone'] = "Само цифри, интервали и + - ( )",
    ['err_email'] = "Това не е e-mail адрес",
    ['err_money'] = "Сума, напр. 12.50",
    ['err_no_special'] = "Без специални знаци",
    -- console lines for the server owner
    ['warn_running'] = "%s работи - махнете \"ensure %s\" от server.cfg, MULTIhelpers го замества.",
    ['warn_started'] = "%s е стартиран до MULTIhelpers - махнете \"ensure %s\" от server.cfg.",
    ['callback_error'] = "грешка в callback: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Натисни %s в отбелязаната зона",
    ['progress_busy'] = "Вече правиш нещо",
    ['progress_dead'] = "Не можеш да направиш това, докато си мъртъв",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Камък",
    ["mg_paper"] = "Хартия",
    ["mg_scissors"] = "Ножица",
    ["mg_win"] = "Печелиш",
    ["mg_lose"] = "Губиш",
    ["mg_tie"] = "Равенство",
}

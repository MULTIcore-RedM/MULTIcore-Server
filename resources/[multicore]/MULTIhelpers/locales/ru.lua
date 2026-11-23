-- MULTIhelpers :: ru
Locales = Locales or {}
Locales['ru'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Подтвердить",
    ['cancel'] = "Отмена",
    ['yes'] = "Да",
    ['no'] = "Нет",
    -- key hints under a menu
    ['key_move'] = "Выбор",
    ['key_change'] = "Изменить",
    ['key_next'] = "Далее",
    ['key_select'] = "Выбрать",
    ['key_back'] = "Назад",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Backspace",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Недопустимо",
    ['err_letters'] = "Только буквы",
    ['err_numbers'] = "Только цифры",
    ['err_alphanumeric'] = "Только буквы и цифры",
    ['err_no_symbols'] = "Без символов",
    ['err_username'] = "Минимум 3 буквы, цифры, _ . или -",
    ['err_phone'] = "Только цифры, пробелы и + - ( )",
    ['err_email'] = "Неверный адрес e-mail",
    ['err_money'] = "Сумма, например 12.50",
    ['err_no_special'] = "Без спецсимволов",
    -- console lines for the server owner
    ['warn_running'] = "%s запущен - уберите \"ensure %s\" из server.cfg, MULTIhelpers его заменяет.",
    ['warn_started'] = "%s запущен рядом с MULTIhelpers - уберите \"ensure %s\" из server.cfg.",
    ['callback_error'] = "ошибка в callback: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Нажми %s в отмеченной зоне",
    ['progress_busy'] = "Ты уже чем-то занят",
    ['progress_dead'] = "Нельзя сделать это, пока ты мёртв",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Камень",
    ["mg_paper"] = "Бумага",
    ["mg_scissors"] = "Ножницы",
    ["mg_win"] = "Вы выиграли",
    ["mg_lose"] = "Вы проиграли",
    ["mg_tie"] = "Ничья",
}

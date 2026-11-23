Locales = Locales or {}
Locales['ru'] = {
    -- general
    ['notify_title'] = "Отель",
    ['too_far'] = "Вы слишком далеко от стойки регистрации.",
    ['not_enough_money'] = "У вас недостаточно денег.",
    ['bad_amount'] = "Введите правильную сумму.",
    ['not_owner'] = "Это может сделать только постоялец, снявший этот номер.",
    ['no_active_room'] = "Вы не в гостиничном номере.",

    -- hotels
    ['hotel_valentine'] = "Отель Valentine",
    ['hotel_strawberry'] = "Отель Strawberry",
    ['hotel_rhodes'] = "Отель Rhodes",
    ['hotel_stdenis'] = "Отель Saint Denis",
    ['hotel_blackwater'] = "Отель Blackwater",
    ['hotel_tumbleweed'] = "Отель Tumbleweed",
    ['hotel_annesburg'] = "Отель Annesburg",

    -- renting and checking in
    ['already_have_room'] = "У вас уже есть номер в этом отеле.",
    ['no_free_room'] = "Сейчас свободных номеров нет. Попробуйте позже.",
    ['rented'] = "Вы сняли номер %s (%s).",
    ['no_room_here'] = "У вас нет номера в этом отеле.",
    ['not_a_guest'] = "Вы не гость в этом отеле.",
    ['guest_checked_in'] = "Вы заселились как гость в номер %s.",
    ['room_lost'] = "На вашем номере %s закончился кредит, номер освобождён.",

    -- credit
    ['credit_too_high'] = "На номере может быть не больше $%s кредита.",
    ['credit_added'] = "Добавлено $%s кредита. Сейчас кредит: $%s.",
    ['cannot_withdraw'] = "Нельзя снять больше кредита, чем есть на номере.",
    ['credit_withdrawn'] = "Снято $%s кредита. Сейчас кредит: $%s.",

    -- locker
    ['locker_label'] = "Шкафчик номера %s",
    ['locker_failed'] = "Не удалось открыть шкафчик номера.",

    -- guests
    ['player_not_found'] = "Игрок не найден.",
    ['player_not_near'] = "Этот игрок недостаточно близко.",
    ['nobody_near'] = "Рядом нет никого, кого можно пригласить.",
    ['already_guest'] = "Этот игрок уже гость.",
    ['max_guests'] = "В этом номере уже максимум гостей (%s).",
    ['guest_added'] = "%s теперь гость вашего номера.",
    ['guest_removed'] = "%s больше не гость вашего номера.",
    ['you_were_invited'] = "%s пригласил вас в номер %s (%s).",
    ['you_were_removed'] = "Вы больше не гость номера %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Подождите %s сек., прежде чем снова выгонять гостей.",
    ['no_guests_to_evict'] = "Некого выгонять.",
    ['evicted'] = "Гостей выгнано из вашего номера: %s.",
    ['evicted_and_removed'] = "Гостей выгнано и убрано из списка гостей: %s.",
    ['you_were_evicted'] = "%s выгнал вас из номера.",
    ['evict_confirm'] = "Гостей, которые сразу покинут ваш номер: %s. Продолжить?",

    -- telegrams
    ['telegram_sender'] = "Регистратура отеля",
    ['tg_invite_subject'] = "Приглашение в номер отеля",
    ['tg_invite_body'] = "%s пригласил вас в номер %s (%s). Обратитесь к стойке регистрации, чтобы заселиться как гость.",
    ['tg_evicted_subject'] = "Вас выгнали из номера",
    ['tg_evicted_body'] = "%s выгнал вас из номера %s. Позже вы всё равно можете заселиться как гость.",
    ['tg_evicted_body_removed'] = "%s выгнал вас из номера %s и отозвал ваше приглашение.",
    ['tg_low_subject'] = "Кредит номера заканчивается",
    ['tg_low_body'] = "Кредит номера %s (%s) заканчивается: осталось $%s. Пополните кредит в меню номера.",
    ['tg_lost_subject'] = "Номер освобождён",
    ['tg_lost_body'] = "На номере %s (%s) закончился кредит, поэтому вас выселили. Спасибо, что остановились у нас.",

    -- logs (MULTIserver)
    ['log_rented'] = "Снят номер в отеле",
    ['log_evicted'] = "Гости отеля выгнаны",
    ['log_lost'] = "Номер в отеле потерян",

    -- desk menu
    ['menu_check_in'] = "Заселиться",
    ['menu_check_in_desc'] = "Подняться в номер %s. Кредит: $%s",
    ['menu_rent'] = "Снять номер ($%s)",
    ['menu_rent_desc'] = "Деньги станут первым кредитом вашего номера.",
    ['menu_guest_check_in'] = "Заселиться как гость",
    ['menu_guest_check_in_desc'] = "Подняться в номер, куда вас пригласили.",

    -- room menu
    ['room_title'] = "Номер %s",
    ['badge_guest'] = "Гость",
    ['menu_add_credit'] = "Пополнить кредит",
    ['menu_credit_now'] = "Сейчас кредит: $%s",
    ['menu_remove_credit'] = "Снять кредит",
    ['menu_remove_credit_desc'] = "Вернуть деньги с кредита номера.",
    ['menu_guests'] = "Гости",
    ['menu_guests_desc'] = "Пригласить игроков или отозвать приглашение.",
    ['menu_evict'] = "Выгнать гостей",
    ['menu_evict_desc'] = "Сразу выпроводить всех гостей из номера.",
    ['menu_locker'] = "Шкафчик номера",
    ['menu_locker_desc'] = "Храните свои вещи.",
    ['menu_guest_access'] = "Доступ гостя",
    ['menu_owner'] = "Номер: %s",
    ['menu_leave'] = "Покинуть номер",
    ['menu_leave_desc'] = "Спуститься обратно на улицу.",
    ['menu_mail'] = "Телеграммы",
    ['menu_mail_desc'] = "Читать и отправлять телеграммы.",
    ['input_add_label'] = "Сумма пополнения (сейчас кредит: $%s)",
    ['input_remove_label'] = "Сумма для снятия (сейчас кредит: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Пригласить игрока",
    ['menu_add_guest_desc'] = "Игроки рядом с вами.",
    ['menu_current_guests'] = "Гости",
    ['menu_no_guests'] = "Нет гостей",
    ['menu_no_guests_desc'] = "Вы ещё никого не пригласили.",
    ['menu_guest_row'] = "Приглашён: %s. Выберите, чтобы отозвать приглашение.",
    ['menu_invite'] = "Пригласить игрока",
    ['menu_invite_row'] = "ID %s. Выберите, чтобы пригласить.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Меню номера",
    ['target_desk'] = "Стойка регистрации",
    ['target_room'] = "Меню номера",

    -- page
    ['ui_subtitle'] = "Обслуживание гостей",
    ['ui_back'] = "Назад",
    ['ui_close'] = "Закрыть",
    ['ui_cancel'] = "Отмена",
    ['ui_confirm'] = "Подтвердить",
    ['ui_amount'] = "Сумма",
    ['ui_max'] = "Макс.",
    ['ui_valid_amount'] = "Введите правильную сумму",
    ['ui_success'] = "Успех",
    ['ui_error'] = "Ошибка",
    ['ui_info'] = "Инфо",
    ['ui_notice'] = "Уведомление",
}

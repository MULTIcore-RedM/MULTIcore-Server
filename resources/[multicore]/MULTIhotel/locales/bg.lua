Locales = Locales or {}
Locales['bg'] = {
    -- general
    ['notify_title'] = "Хотел",
    ['too_far'] = "Твърде далеч сте от рецепцията.",
    ['not_enough_money'] = "Нямате достатъчно пари.",
    ['bad_amount'] = "Въведете валидна сума.",
    ['not_owner'] = "Само гостът, който е наел стаята, може да направи това.",
    ['no_active_room'] = "Не сте в хотелска стая.",

    -- hotels
    ['hotel_valentine'] = "Хотел Valentine",
    ['hotel_strawberry'] = "Хотел Strawberry",
    ['hotel_rhodes'] = "Хотел Rhodes",
    ['hotel_stdenis'] = "Хотел Saint Denis",
    ['hotel_blackwater'] = "Хотел Blackwater",
    ['hotel_tumbleweed'] = "Хотел Tumbleweed",
    ['hotel_annesburg'] = "Хотел Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Вече имате стая в този хотел.",
    ['no_free_room'] = "В момента няма свободна стая. Опитайте по-късно.",
    ['rented'] = "Наехте стая %s (%s).",
    ['no_room_here'] = "Нямате стая в този хотел.",
    ['not_a_guest'] = "Не сте гост в този хотел.",
    ['guest_checked_in'] = "Настанихте се като гост в стая %s.",
    ['room_lost'] = "Кредитът на стая %s свърши и тя беше освободена.",

    -- credit
    ['credit_too_high'] = "Една стая може да има най-много $%s кредит.",
    ['credit_added'] = "Добавени $%s кредит. Кредит сега: $%s.",
    ['cannot_withdraw'] = "Не можете да изтеглите повече кредит, отколкото има стаята.",
    ['credit_withdrawn'] = "Изтеглени $%s кредит. Кредит сега: $%s.",

    -- locker
    ['locker_label'] = "Шкаф на стая %s",
    ['locker_failed'] = "Шкафът на стаята не можа да се отвори.",

    -- guests
    ['player_not_found'] = "Играчът не е намерен.",
    ['player_not_near'] = "Този играч не е достатъчно близо.",
    ['nobody_near'] = "Няма никой достатъчно близо, когото да поканите.",
    ['already_guest'] = "Този играч вече е гост.",
    ['max_guests'] = "Тази стая вече има максималния брой гости (%s).",
    ['guest_added'] = "%s вече е гост на вашата стая.",
    ['guest_removed'] = "%s вече не е гост на вашата стая.",
    ['you_were_invited'] = "%s ви покани в стая %s (%s).",
    ['you_were_removed'] = "Вече не сте гост на стая %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Изчакайте %s секунди, преди отново да изгоните гости.",
    ['no_guests_to_evict'] = "Няма гости за изгонване.",
    ['evicted'] = "Изгонени гости от стаята ви: %s.",
    ['evicted_and_removed'] = "Изгонени и премахнати от списъка гости: %s.",
    ['you_were_evicted'] = "%s ви изгони от стаята.",
    ['evict_confirm'] = "Това веднага ще изведе гости от стаята ви: %s. Продължавате ли?",

    -- telegrams
    ['telegram_sender'] = "Хотелска рецепция",
    ['tg_invite_subject'] = "Покана за хотелска стая",
    ['tg_invite_body'] = "%s ви покани в стая %s (%s). Обърнете се към рецепцията, за да се настаните като гост.",
    ['tg_evicted_subject'] = "Изгонен от хотелска стая",
    ['tg_evicted_body'] = "%s ви изгони от стая %s. По-късно пак можете да се настаните като гост.",
    ['tg_evicted_body_removed'] = "%s ви изгони от стая %s и оттегли поканата ви.",
    ['tg_low_subject'] = "Кредитът на стаята намалява",
    ['tg_low_body'] = "Кредитът на стая %s (%s) намалява: остават $%s. Добавете кредит от менюто на стаята.",
    ['tg_lost_subject'] = "Стаята е освободена",
    ['tg_lost_body'] = "Кредитът на стая %s (%s) свърши, затова бяхте отписан. Благодарим, че отседнахте при нас.",

    -- logs (MULTIserver)
    ['log_rented'] = "Наета хотелска стая",
    ['log_evicted'] = "Изгонени хотелски гости",
    ['log_lost'] = "Загубена хотелска стая",

    -- desk menu
    ['menu_check_in'] = "Настаняване",
    ['menu_check_in_desc'] = "Качете се в стая %s. Кредит: $%s",
    ['menu_rent'] = "Наемане на стая ($%s)",
    ['menu_rent_desc'] = "Парите стават първият кредит на стаята ви.",
    ['menu_guest_check_in'] = "Настаняване като гост",
    ['menu_guest_check_in_desc'] = "Качете се в стаята, в която сте поканени.",

    -- room menu
    ['room_title'] = "Стая %s",
    ['badge_guest'] = "Гост",
    ['menu_add_credit'] = "Добавяне на кредит",
    ['menu_credit_now'] = "Кредит сега: $%s",
    ['menu_remove_credit'] = "Изтегляне на кредит",
    ['menu_remove_credit_desc'] = "Вземете пари обратно от кредита на стаята.",
    ['menu_guests'] = "Гости",
    ['menu_guests_desc'] = "Поканете играчи или оттеглете покана.",
    ['menu_evict'] = "Изгонване на гости",
    ['menu_evict_desc'] = "Веднага изведете всички гости от стаята.",
    ['menu_locker'] = "Шкаф на стаята",
    ['menu_locker_desc'] = "Съхранявайте вещите си.",
    ['menu_guest_access'] = "Достъп на гост",
    ['menu_owner'] = "Стая на %s",
    ['menu_leave'] = "Напускане на стаята",
    ['menu_leave_desc'] = "Слезте обратно на улицата.",
    ['menu_mail'] = "Телеграми",
    ['menu_mail_desc'] = "Четете и изпращайте телеграми.",
    ['input_add_label'] = "Сума за добавяне (кредит сега: $%s)",
    ['input_remove_label'] = "Сума за изтегляне (кредит сега: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Покани играч",
    ['menu_add_guest_desc'] = "Играчи близо до вас.",
    ['menu_current_guests'] = "Гости",
    ['menu_no_guests'] = "Няма гости",
    ['menu_no_guests_desc'] = "Още не сте поканили никого.",
    ['menu_guest_row'] = "Поканен: %s. Изберете, за да оттеглите поканата.",
    ['menu_invite'] = "Покани играч",
    ['menu_invite_row'] = "ID %s. Изберете, за да поканите.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Меню на стаята",
    ['target_desk'] = "Рецепция",
    ['target_room'] = "Меню на стаята",

    -- page
    ['ui_subtitle'] = "Обслужване на гости",
    ['ui_back'] = "Назад",
    ['ui_close'] = "Затвори",
    ['ui_cancel'] = "Отказ",
    ['ui_confirm'] = "Потвърди",
    ['ui_amount'] = "Сума",
    ['ui_max'] = "Макс",
    ['ui_valid_amount'] = "Въведете валидна сума",
    ['ui_success'] = "Успех",
    ['ui_error'] = "Грешка",
    ['ui_info'] = "Инфо",
    ['ui_notice'] = "Внимание",
}

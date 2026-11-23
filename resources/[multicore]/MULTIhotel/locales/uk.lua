Locales = Locales or {}
Locales['uk'] = {
    -- general
    ['notify_title'] = "Готель",
    ['too_far'] = "Ви надто далеко від стійки реєстрації.",
    ['not_enough_money'] = "У вас недостатньо грошей.",
    ['bad_amount'] = "Введіть правильну суму.",
    ['not_owner'] = "Це може зробити лише гість, який винайняв цю кімнату.",
    ['no_active_room'] = "Ви не в готельній кімнаті.",

    -- hotels
    ['hotel_valentine'] = "Готель Valentine",
    ['hotel_strawberry'] = "Готель Strawberry",
    ['hotel_rhodes'] = "Готель Rhodes",
    ['hotel_stdenis'] = "Готель Saint Denis",
    ['hotel_blackwater'] = "Готель Blackwater",
    ['hotel_tumbleweed'] = "Готель Tumbleweed",
    ['hotel_annesburg'] = "Готель Annesburg",

    -- renting and checking in
    ['already_have_room'] = "У вас уже є кімната в цьому готелі.",
    ['no_free_room'] = "Зараз немає вільних кімнат. Спробуйте пізніше.",
    ['rented'] = "Ви винайняли кімнату %s (%s).",
    ['no_room_here'] = "У вас немає кімнати в цьому готелі.",
    ['not_a_guest'] = "Ви не гість цього готелю.",
    ['guest_checked_in'] = "Ви заселилися як гість у кімнату %s.",
    ['room_lost'] = "На вашій кімнаті %s скінчився кредит, і її звільнено.",

    -- credit
    ['credit_too_high'] = "На кімнаті може бути щонайбільше $%s кредиту.",
    ['credit_added'] = "Додано $%s кредиту. Тепер кредит: $%s.",
    ['cannot_withdraw'] = "Не можна зняти більше кредиту, ніж є на кімнаті.",
    ['credit_withdrawn'] = "Знято $%s кредиту. Тепер кредит: $%s.",

    -- locker
    ['locker_label'] = "Шафка кімнати %s",
    ['locker_failed'] = "Не вдалося відкрити шафку кімнати.",

    -- guests
    ['player_not_found'] = "Гравця не знайдено.",
    ['player_not_near'] = "Цей гравець недостатньо близько.",
    ['nobody_near'] = "Поруч немає нікого, кого можна запросити.",
    ['already_guest'] = "Цей гравець уже гість.",
    ['max_guests'] = "У цій кімнаті вже найбільша дозволена кількість гостей (%s).",
    ['guest_added'] = "%s тепер гість вашої кімнати.",
    ['guest_removed'] = "%s більше не гість вашої кімнати.",
    ['you_were_invited'] = "%s запросив вас до кімнати %s (%s).",
    ['you_were_removed'] = "Ви більше не гість кімнати %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Зачекайте %s с, перш ніж знову виганяти гостей.",
    ['no_guests_to_evict'] = "Немає гостей, яких можна вигнати.",
    ['evicted'] = "Гостей вигнано з вашої кімнати: %s.",
    ['evicted_and_removed'] = "Гостей вигнано й вилучено зі списку гостей: %s.",
    ['you_were_evicted'] = "%s вигнав вас із кімнати.",
    ['evict_confirm'] = "Це одразу виведе з вашої кімнати гостей: %s. Продовжити?",

    -- telegrams
    ['telegram_sender'] = "Готельна рецепція",
    ['tg_invite_subject'] = "Запрошення до готельної кімнати",
    ['tg_invite_body'] = "%s запросив вас до кімнати %s (%s). Зверніться на рецепцію, щоб заселитися як гість.",
    ['tg_evicted_subject'] = "Вас вигнали з готельної кімнати",
    ['tg_evicted_body'] = "%s вигнав вас із кімнати %s. Пізніше ви ще можете заселитися як гість.",
    ['tg_evicted_body_removed'] = "%s вигнав вас із кімнати %s і відкликав ваше запрошення.",
    ['tg_low_subject'] = "Кредит кімнати закінчується",
    ['tg_low_body'] = "Кредит кімнати %s (%s) закінчується: лишилося $%s. Поповніть кредит у меню кімнати.",
    ['tg_lost_subject'] = "Кімнату звільнено",
    ['tg_lost_body'] = "На кімнаті %s (%s) скінчився кредит, тож вас виселено. Дякуємо, що зупинялися в нас.",

    -- logs (MULTIserver)
    ['log_rented'] = "Готельну кімнату винайнято",
    ['log_evicted'] = "Гостей готелю вигнано",
    ['log_lost'] = "Готельну кімнату втрачено",

    -- desk menu
    ['menu_check_in'] = "Заселитися",
    ['menu_check_in_desc'] = "Піднятися до кімнати %s. Кредит: $%s",
    ['menu_rent'] = "Винайняти кімнату ($%s)",
    ['menu_rent_desc'] = "Гроші стануть першим кредитом вашої кімнати.",
    ['menu_guest_check_in'] = "Заселитися як гість",
    ['menu_guest_check_in_desc'] = "Піднятися до кімнати, куди вас запросили.",

    -- room menu
    ['room_title'] = "Кімната %s",
    ['badge_guest'] = "Гість",
    ['menu_add_credit'] = "Додати кредит",
    ['menu_credit_now'] = "Тепер кредит: $%s",
    ['menu_remove_credit'] = "Зняти кредит",
    ['menu_remove_credit_desc'] = "Повернути гроші з кредиту кімнати.",
    ['menu_guests'] = "Гості",
    ['menu_guests_desc'] = "Запросіть гравців або відкличте запрошення.",
    ['menu_evict'] = "Вигнати гостей",
    ['menu_evict_desc'] = "Одразу вивести всіх гостей із кімнати.",
    ['menu_locker'] = "Шафка кімнати",
    ['menu_locker_desc'] = "Зберігайте свої речі.",
    ['menu_guest_access'] = "Доступ гостя",
    ['menu_owner'] = "Кімната: %s",
    ['menu_leave'] = "Вийти з кімнати",
    ['menu_leave_desc'] = "Спуститися назад на вулицю.",
    ['menu_mail'] = "Телеграми",
    ['menu_mail_desc'] = "Читати й надсилати телеграми.",
    ['input_add_label'] = "Сума для додавання (кредит: $%s)",
    ['input_remove_label'] = "Сума для зняття (кредит: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Запросити гравця",
    ['menu_add_guest_desc'] = "Гравці поруч із вами.",
    ['menu_current_guests'] = "Гості",
    ['menu_no_guests'] = "Немає гостей",
    ['menu_no_guests_desc'] = "Ви ще нікого не запросили.",
    ['menu_guest_row'] = "Запрошено: %s. Виберіть, щоб відкликати запрошення.",
    ['menu_invite'] = "Запросити гравця",
    ['menu_invite_row'] = "ID %s. Виберіть, щоб запросити.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Меню кімнати",
    ['target_desk'] = "Рецепція",
    ['target_room'] = "Меню кімнати",

    -- page
    ['ui_subtitle'] = "Обслуговування гостей",
    ['ui_back'] = "Назад",
    ['ui_close'] = "Закрити",
    ['ui_cancel'] = "Скасувати",
    ['ui_confirm'] = "Підтвердити",
    ['ui_amount'] = "Сума",
    ['ui_max'] = "Макс",
    ['ui_valid_amount'] = "Введіть правильну суму",
    ['ui_success'] = "Успіх",
    ['ui_error'] = "Помилка",
    ['ui_info'] = "Інфо",
    ['ui_notice'] = "Увага",
}

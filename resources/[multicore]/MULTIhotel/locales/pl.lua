Locales = Locales or {}
Locales['pl'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Jesteś za daleko od recepcji.",
    ['not_enough_money'] = "Nie masz wystarczająco pieniędzy.",
    ['bad_amount'] = "Podaj prawidłową kwotę.",
    ['not_owner'] = "Tylko gość, który wynajął ten pokój, może to zrobić.",
    ['no_active_room'] = "Nie jesteś w pokoju hotelowym.",

    -- hotels
    ['hotel_valentine'] = "Hotel Valentine",
    ['hotel_strawberry'] = "Hotel Strawberry",
    ['hotel_rhodes'] = "Hotel Rhodes",
    ['hotel_stdenis'] = "Hotel Saint Denis",
    ['hotel_blackwater'] = "Hotel Blackwater",
    ['hotel_tumbleweed'] = "Hotel Tumbleweed",
    ['hotel_annesburg'] = "Hotel Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Masz już pokój w tym hotelu.",
    ['no_free_room'] = "Nie ma teraz wolnego pokoju. Spróbuj później.",
    ['rented'] = "Wynająłeś pokój %s – %s.",
    ['no_room_here'] = "Nie masz pokoju w tym hotelu.",
    ['not_a_guest'] = "Nie jesteś gościem w tym hotelu.",
    ['guest_checked_in'] = "Zameldowano jako gość w pokoju %s.",
    ['room_lost'] = "W twoim pokoju %s skończył się kredyt i pokój został oddany.",

    -- credit
    ['credit_too_high'] = "Pokój może mieć najwyżej $%s kredytu.",
    ['credit_added'] = "Dodano $%s kredytu. Kredyt teraz: $%s.",
    ['cannot_withdraw'] = "Nie możesz wypłacić więcej kredytu, niż ma pokój.",
    ['credit_withdrawn'] = "Wypłacono $%s kredytu. Kredyt teraz: $%s.",

    -- locker
    ['locker_label'] = "Szafka w pokoju %s",
    ['locker_failed'] = "Nie udało się otworzyć szafki w pokoju.",

    -- guests
    ['player_not_found'] = "Nie znaleziono tego gracza.",
    ['player_not_near'] = "Ten gracz nie jest wystarczająco blisko.",
    ['nobody_near'] = "Nikt nie jest wystarczająco blisko, by go zaprosić.",
    ['already_guest'] = "Ten gracz jest już gościem.",
    ['max_guests'] = "Ten pokój ma już maksymalną liczbę gości (%s).",
    ['guest_added'] = "%s jest teraz gościem twojego pokoju.",
    ['guest_removed'] = "%s nie jest już gościem twojego pokoju.",
    ['you_were_invited'] = "%s zaprosił cię do pokoju %s – %s.",
    ['you_were_removed'] = "Nie jesteś już gościem pokoju %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Odczekaj %s s, zanim znów wyrzucisz gości.",
    ['no_guests_to_evict'] = "Nie ma gości do wyrzucenia.",
    ['evicted'] = "Wyrzucono gości z twojego pokoju: %s.",
    ['evicted_and_removed'] = "Wyrzucono gości i usunięto ich z listy gości: %s.",
    ['you_were_evicted'] = "%s wyrzucił cię z pokoju.",
    ['evict_confirm'] = "Liczba gości, którzy od razu opuszczą twój pokój: %s. Kontynuować?",

    -- telegrams
    ['telegram_sender'] = "Recepcja hotelu",
    ['tg_invite_subject'] = "Zaproszenie do pokoju hotelowego",
    ['tg_invite_body'] = "%s zaprosił cię do pokoju %s – %s. Zgłoś się do recepcji, aby zameldować się jako gość.",
    ['tg_evicted_subject'] = "Wyrzucenie z pokoju hotelowego",
    ['tg_evicted_body'] = "%s wyrzucił cię z pokoju %s. Później nadal możesz zameldować się jako gość.",
    ['tg_evicted_body_removed'] = "%s wyrzucił cię z pokoju %s i cofnął twoje zaproszenie.",
    ['tg_low_subject'] = "Kończy się kredyt pokoju",
    ['tg_low_body'] = "Kredyt pokoju %s – %s się kończy: zostało $%s. Doładuj kredyt w menu pokoju.",
    ['tg_lost_subject'] = "Pokój oddany",
    ['tg_lost_body'] = "W pokoju %s – %s skończył się kredyt, więc zostałeś wymeldowany. Dziękujemy za pobyt.",

    -- logs (MULTIserver)
    ['log_rented'] = "Wynajęto pokój hotelowy",
    ['log_evicted'] = "Wyrzucono gości hotelu",
    ['log_lost'] = "Utracono pokój hotelowy",

    -- desk menu
    ['menu_check_in'] = "Zamelduj się",
    ['menu_check_in_desc'] = "Idź do pokoju %s. Kredyt: $%s",
    ['menu_rent'] = "Wynajmij pokój ($%s)",
    ['menu_rent_desc'] = "Pieniądze staną się pierwszym kredytem twojego pokoju.",
    ['menu_guest_check_in'] = "Meldunek gościa",
    ['menu_guest_check_in_desc'] = "Idź do pokoju, do którego cię zaproszono.",

    -- room menu
    ['room_title'] = "Pokój %s",
    ['badge_guest'] = "Gość",
    ['menu_add_credit'] = "Dodaj kredyt",
    ['menu_credit_now'] = "Kredyt teraz: $%s",
    ['menu_remove_credit'] = "Wypłać kredyt",
    ['menu_remove_credit_desc'] = "Odbierz pieniądze z kredytu pokoju.",
    ['menu_guests'] = "Goście",
    ['menu_guests_desc'] = "Zaproś graczy lub cofnij zaproszenie.",
    ['menu_evict'] = "Wyrzuć gości",
    ['menu_evict_desc'] = "Od razu wyproś wszystkich gości z pokoju.",
    ['menu_locker'] = "Szafka w pokoju",
    ['menu_locker_desc'] = "Przechowuj swoje rzeczy.",
    ['menu_guest_access'] = "Dostęp gościa",
    ['menu_owner'] = "Pokój: %s",
    ['menu_leave'] = "Opuść pokój",
    ['menu_leave_desc'] = "Zejdź z powrotem na ulicę.",
    ['menu_mail'] = "Telegramy",
    ['menu_mail_desc'] = "Czytaj i wysyłaj telegramy.",
    ['input_add_label'] = "Kwota do dodania (kredyt teraz: $%s)",
    ['input_remove_label'] = "Kwota do wypłaty (kredyt teraz: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Zaproś gracza",
    ['menu_add_guest_desc'] = "Gracze w pobliżu.",
    ['menu_current_guests'] = "Goście",
    ['menu_no_guests'] = "Brak gości",
    ['menu_no_guests_desc'] = "Nikogo jeszcze nie zaprosiłeś.",
    ['menu_guest_row'] = "Zaproszony: %s. Wybierz, aby cofnąć zaproszenie.",
    ['menu_invite'] = "Zaproś gracza",
    ['menu_invite_row'] = "ID %s. Wybierz, aby zaprosić.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Menu pokoju",
    ['target_desk'] = "Recepcja",
    ['target_room'] = "Menu pokoju",

    -- page
    ['ui_subtitle'] = "Obsługa gości",
    ['ui_back'] = "Wstecz",
    ['ui_close'] = "Zamknij",
    ['ui_cancel'] = "Anuluj",
    ['ui_confirm'] = "Potwierdź",
    ['ui_amount'] = "Kwota",
    ['ui_max'] = "Maks.",
    ['ui_valid_amount'] = "Podaj prawidłową kwotę",
    ['ui_success'] = "Sukces",
    ['ui_error'] = "Błąd",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Uwaga",
}

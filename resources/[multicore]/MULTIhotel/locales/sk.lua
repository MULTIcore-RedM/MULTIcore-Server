Locales = Locales or {}
Locales['sk'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Si príliš ďaleko od recepcie.",
    ['not_enough_money'] = "Nemáš dosť peňazí.",
    ['bad_amount'] = "Zadaj platnú sumu.",
    ['not_owner'] = "To môže urobiť iba hosť, ktorý si izbu prenajal.",
    ['no_active_room'] = "Nie si v hotelovej izbe.",

    -- hotels
    ['hotel_valentine'] = "Hotel Valentine",
    ['hotel_strawberry'] = "Hotel Strawberry",
    ['hotel_rhodes'] = "Hotel Rhodes",
    ['hotel_stdenis'] = "Hotel Saint Denis",
    ['hotel_blackwater'] = "Hotel Blackwater",
    ['hotel_tumbleweed'] = "Hotel Tumbleweed",
    ['hotel_annesburg'] = "Hotel Annesburg",

    -- renting and checking in
    ['already_have_room'] = "V tomto hoteli už izbu máš.",
    ['no_free_room'] = "Teraz nie je voľná žiadna izba. Skús to neskôr.",
    ['rented'] = "Prenajal si si izbu %s (%s).",
    ['no_room_here'] = "V tomto hoteli nemáš izbu.",
    ['not_a_guest'] = "V tomto hoteli nie si hosť.",
    ['guest_checked_in'] = "Ubytovaný ako hosť v izbe %s.",
    ['room_lost'] = "Tvojej izbe %s došiel kredit a bola uvoľnená.",

    -- credit
    ['credit_too_high'] = "Izba môže mať najviac $%s kreditu.",
    ['credit_added'] = "Pridaný kredit $%s. Kredit teraz: $%s.",
    ['cannot_withdraw'] = "Nemôžeš vybrať viac kreditu, než izba má.",
    ['credit_withdrawn'] = "Vybraný kredit $%s. Kredit teraz: $%s.",

    -- locker
    ['locker_label'] = "Skrinka izby %s",
    ['locker_failed'] = "Skrinku izby sa nepodarilo otvoriť.",

    -- guests
    ['player_not_found'] = "Hráč sa nenašiel.",
    ['player_not_near'] = "Ten hráč nie je dosť blízko.",
    ['nobody_near'] = "Nikto nie je dosť blízko, aby si ho pozval.",
    ['already_guest'] = "Ten hráč už je hosť.",
    ['max_guests'] = "Izba už má najvyšší povolený počet hostí (%s).",
    ['guest_added'] = "%s je teraz hosťom tvojej izby.",
    ['guest_removed'] = "%s už nie je hosťom tvojej izby.",
    ['you_were_invited'] = "%s ťa pozval do izby %s (%s).",
    ['you_were_removed'] = "Už nie si hosťom izby %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Počkaj %s sekúnd, než znova vyhodíš hostí.",
    ['no_guests_to_evict'] = "Nie sú tu žiadni hostia na vyhodenie.",
    ['evicted'] = "Z tvojej izby vyhodených hostí: %s.",
    ['evicted_and_removed'] = "Vyhodených a zo zoznamu hostí odobratých hostí: %s.",
    ['you_were_evicted'] = "%s ťa vyhodil z izby.",
    ['evict_confirm'] = "Týmto hneď pošleš z izby hostí: %s. Pokračovať?",

    -- telegrams
    ['telegram_sender'] = "Hotelová recepcia",
    ['tg_invite_subject'] = "Pozvánka do hotelovej izby",
    ['tg_invite_body'] = "%s ťa pozval do izby %s (%s). Na recepcii sa ubytuj ako hosť.",
    ['tg_evicted_subject'] = "Vyhodenie z hotelovej izby",
    ['tg_evicted_body'] = "%s ťa vyhodil z izby %s. Neskôr sa tam môžeš znova ubytovať ako hosť.",
    ['tg_evicted_body_removed'] = "%s ťa vyhodil z izby %s a vzal späť tvoju pozvánku.",
    ['tg_low_subject'] = "Kredit izby dochádza",
    ['tg_low_body'] = "Kredit izby %s (%s) dochádza: zostáva $%s. Kredit doplníš v ponuke izby.",
    ['tg_lost_subject'] = "Izba uvoľnená",
    ['tg_lost_body'] = "Izbe %s (%s) došiel kredit, preto si bol odhlásený. Ďakujeme, že si u nás býval.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotelová izba prenajatá",
    ['log_evicted'] = "Hostia vyhodení z hotela",
    ['log_lost'] = "Hotelová izba stratená",

    -- desk menu
    ['menu_check_in'] = "Ubytovať sa",
    ['menu_check_in_desc'] = "Choď hore do izby %s. Kredit: $%s",
    ['menu_rent'] = "Prenajať izbu ($%s)",
    ['menu_rent_desc'] = "Peniaze sa stanú prvým kreditom tvojej izby.",
    ['menu_guest_check_in'] = "Ubytovať sa ako hosť",
    ['menu_guest_check_in_desc'] = "Choď hore do izby, kam ťa pozvali.",

    -- room menu
    ['room_title'] = "Izba %s",
    ['badge_guest'] = "Hosť",
    ['menu_add_credit'] = "Pridať kredit",
    ['menu_credit_now'] = "Kredit teraz: $%s",
    ['menu_remove_credit'] = "Vybrať kredit",
    ['menu_remove_credit_desc'] = "Vezmi si peniaze späť z kreditu izby.",
    ['menu_guests'] = "Hostia",
    ['menu_guests_desc'] = "Pozvi hráčov alebo vezmi pozvánku späť.",
    ['menu_evict'] = "Vyhodiť hostí",
    ['menu_evict_desc'] = "Hneď pošli všetkých hostí z izby.",
    ['menu_locker'] = "Skrinka izby",
    ['menu_locker_desc'] = "Ulož si svoje veci.",
    ['menu_guest_access'] = "Prístup hosťa",
    ['menu_owner'] = "Izba: %s",
    ['menu_leave'] = "Opustiť izbu",
    ['menu_leave_desc'] = "Vráť sa dolu na ulicu.",
    ['menu_mail'] = "Telegramy",
    ['menu_mail_desc'] = "Čítaj a posielaj telegramy.",
    ['input_add_label'] = "Suma na pridanie (kredit teraz: $%s)",
    ['input_remove_label'] = "Suma na výber (kredit teraz: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Pozvať hráča",
    ['menu_add_guest_desc'] = "Hráči blízko teba.",
    ['menu_current_guests'] = "Hostia",
    ['menu_no_guests'] = "Žiadni hostia",
    ['menu_no_guests_desc'] = "Zatiaľ si nikoho nepozval.",
    ['menu_guest_row'] = "Pozvaný: %s. Vyber na zrušenie pozvánky.",
    ['menu_invite'] = "Pozvať hráča",
    ['menu_invite_row'] = "ID %s. Vyber na pozvanie.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Ponuka izby",
    ['target_desk'] = "Recepcia",
    ['target_room'] = "Ponuka izby",

    -- page
    ['ui_subtitle'] = "Služby pre hostí",
    ['ui_back'] = "Späť",
    ['ui_close'] = "Zavrieť",
    ['ui_cancel'] = "Zrušiť",
    ['ui_confirm'] = "Potvrdiť",
    ['ui_amount'] = "Suma",
    ['ui_max'] = "Max",
    ['ui_valid_amount'] = "Zadaj platnú sumu",
    ['ui_success'] = "Hotovo",
    ['ui_error'] = "Chyba",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Upozornenie",
}

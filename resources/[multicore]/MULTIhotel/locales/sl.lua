Locales = Locales or {}
Locales['sl'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Predaleč si od recepcije.",
    ['not_enough_money'] = "Nimaš dovolj denarja.",
    ['bad_amount'] = "Vnesi veljaven znesek.",
    ['not_owner'] = "To lahko stori le gost, ki je najel to sobo.",
    ['no_active_room'] = "Nisi v hotelski sobi.",

    -- hotels
    ['hotel_valentine'] = "Hotel Valentine",
    ['hotel_strawberry'] = "Hotel Strawberry",
    ['hotel_rhodes'] = "Hotel Rhodes",
    ['hotel_stdenis'] = "Hotel Saint Denis",
    ['hotel_blackwater'] = "Hotel Blackwater",
    ['hotel_tumbleweed'] = "Hotel Tumbleweed",
    ['hotel_annesburg'] = "Hotel Annesburg",

    -- renting and checking in
    ['already_have_room'] = "V tem hotelu že imaš sobo.",
    ['no_free_room'] = "Trenutno ni proste sobe. Poskusi pozneje.",
    ['rented'] = "Najel si sobo %s – %s.",
    ['no_room_here'] = "V tem hotelu nimaš sobe.",
    ['not_a_guest'] = "V tem hotelu nisi gost.",
    ['guest_checked_in'] = "Prijavljen si kot gost v sobo %s.",
    ['room_lost'] = "Tvoji sobi %s je zmanjkalo dobroimetja, zato je bila oddana.",

    -- credit
    ['credit_too_high'] = "Soba ima lahko največ $%s dobroimetja.",
    ['credit_added'] = "Dodano $%s dobroimetja. Dobroimetje zdaj: $%s.",
    ['cannot_withdraw'] = "Ne moreš dvigniti več dobroimetja, kot ga ima soba.",
    ['credit_withdrawn'] = "Dvignjeno $%s dobroimetja. Dobroimetje zdaj: $%s.",

    -- locker
    ['locker_label'] = "Omarica sobe %s",
    ['locker_failed'] = "Omarice sobe ni bilo mogoče odpreti.",

    -- guests
    ['player_not_found'] = "Tega igralca ni bilo mogoče najti.",
    ['player_not_near'] = "Ta igralec ni dovolj blizu.",
    ['nobody_near'] = "Nikogar ni dovolj blizu, da bi ga povabil.",
    ['already_guest'] = "Ta igralec je že gost.",
    ['max_guests'] = "Ta soba ima že največ dovoljenih gostov (%s).",
    ['guest_added'] = "%s je zdaj gost tvoje sobe.",
    ['guest_removed'] = "%s ni več gost tvoje sobe.",
    ['you_were_invited'] = "%s te je povabil v sobo %s – %s.",
    ['you_were_removed'] = "Nisi več gost sobe %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Počakaj %s s, preden spet vržeš goste ven.",
    ['no_guests_to_evict'] = "Ni gostov, ki bi jih vrgel ven.",
    ['evicted'] = "Gostov, vrženih iz tvoje sobe: %s.",
    ['evicted_and_removed'] = "Gostov, vrženih ven in odstranjenih s seznama gostov: %s.",
    ['you_were_evicted'] = "%s te je vrgel iz sobe.",
    ['evict_confirm'] = "S tem takoj pošlješ iz sobe toliko gostov: %s. Nadaljujem?",

    -- telegrams
    ['telegram_sender'] = "Hotelska recepcija",
    ['tg_invite_subject'] = "Povabilo v hotelsko sobo",
    ['tg_invite_body'] = "%s te je povabil v sobo %s – %s. Na recepciji se prijavi kot gost.",
    ['tg_evicted_subject'] = "Vržen iz hotelske sobe",
    ['tg_evicted_body'] = "%s te je vrgel iz sobe %s. Pozneje se še vedno lahko prijaviš kot gost.",
    ['tg_evicted_body_removed'] = "%s te je vrgel iz sobe %s in preklical tvoje povabilo.",
    ['tg_low_subject'] = "Dobroimetje sobe pohaja",
    ['tg_low_body'] = "Dobroimetje za sobo %s – %s pohaja: ostalo je $%s. Dodaj dobroimetje v meniju sobe.",
    ['tg_lost_subject'] = "Soba oddana",
    ['tg_lost_body'] = "Sobi %s – %s je zmanjkalo dobroimetja, zato si bil odjavljen. Hvala, ker ste bivali pri nas.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotelska soba najeta",
    ['log_evicted'] = "Hotelski gostje vrženi ven",
    ['log_lost'] = "Hotelska soba izgubljena",

    -- desk menu
    ['menu_check_in'] = "Prijava",
    ['menu_check_in_desc'] = "Pojdi gor v sobo %s. Dobroimetje: $%s",
    ['menu_rent'] = "Najemi sobo ($%s)",
    ['menu_rent_desc'] = "Denar postane prvo dobroimetje tvoje sobe.",
    ['menu_guest_check_in'] = "Prijava gosta",
    ['menu_guest_check_in_desc'] = "Pojdi gor v sobo, v katero si povabljen.",

    -- room menu
    ['room_title'] = "Soba %s",
    ['badge_guest'] = "Gost",
    ['menu_add_credit'] = "Dodaj dobroimetje",
    ['menu_credit_now'] = "Dobroimetje zdaj: $%s",
    ['menu_remove_credit'] = "Dvigni dobroimetje",
    ['menu_remove_credit_desc'] = "Vzemi denar nazaj iz dobroimetja sobe.",
    ['menu_guests'] = "Gostje",
    ['menu_guests_desc'] = "Povabi igralce ali prekliči povabilo.",
    ['menu_evict'] = "Vrzi goste ven",
    ['menu_evict_desc'] = "Takoj pošlji vse goste iz sobe.",
    ['menu_locker'] = "Omarica sobe",
    ['menu_locker_desc'] = "Shrani svoje stvari.",
    ['menu_guest_access'] = "Dostop gosta",
    ['menu_owner'] = "Soba: %s",
    ['menu_leave'] = "Zapusti sobo",
    ['menu_leave_desc'] = "Vrni se dol na ulico.",
    ['menu_mail'] = "Telegrami",
    ['menu_mail_desc'] = "Beri in pošiljaj telegrame.",
    ['input_add_label'] = "Znesek za dodati (dobroimetje zdaj: $%s)",
    ['input_remove_label'] = "Znesek za dvig (dobroimetje zdaj: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Povabi igralca",
    ['menu_add_guest_desc'] = "Igralci blizu tebe.",
    ['menu_current_guests'] = "Gostje",
    ['menu_no_guests'] = "Ni gostov",
    ['menu_no_guests_desc'] = "Nikogar še nisi povabil.",
    ['menu_guest_row'] = "Povabljen %s. Izberi za preklic povabila.",
    ['menu_invite'] = "Povabi igralca",
    ['menu_invite_row'] = "ID %s. Izberi za povabilo.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Meni sobe",
    ['target_desk'] = "Recepcija",
    ['target_room'] = "Meni sobe",

    -- page
    ['ui_subtitle'] = "Storitve za goste",
    ['ui_back'] = "Nazaj",
    ['ui_close'] = "Zapri",
    ['ui_cancel'] = "Prekliči",
    ['ui_confirm'] = "Potrdi",
    ['ui_amount'] = "Znesek",
    ['ui_max'] = "Najv.",
    ['ui_valid_amount'] = "Vnesi veljaven znesek",
    ['ui_success'] = "Uspeh",
    ['ui_error'] = "Napaka",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Obvestilo",
}

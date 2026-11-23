Locales = Locales or {}
Locales['hr'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Predaleko si od recepcije.",
    ['not_enough_money'] = "Nemaš dovoljno novca.",
    ['bad_amount'] = "Unesi ispravan iznos.",
    ['not_owner'] = "To može samo gost koji je unajmio ovu sobu.",
    ['no_active_room'] = "Nisi u hotelskoj sobi.",

    -- hotels
    ['hotel_valentine'] = "Hotel Valentine",
    ['hotel_strawberry'] = "Hotel Strawberry",
    ['hotel_rhodes'] = "Hotel Rhodes",
    ['hotel_stdenis'] = "Hotel Saint Denis",
    ['hotel_blackwater'] = "Hotel Blackwater",
    ['hotel_tumbleweed'] = "Hotel Tumbleweed",
    ['hotel_annesburg'] = "Hotel Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Već imaš sobu u ovom hotelu.",
    ['no_free_room'] = "Trenutno nema slobodne sobe. Pokušaj kasnije.",
    ['rented'] = "Unajmio si sobu %s – %s.",
    ['no_room_here'] = "Nemaš sobu u ovom hotelu.",
    ['not_a_guest'] = "Nisi gost u ovom hotelu.",
    ['guest_checked_in'] = "Prijavljen si kao gost u sobu %s.",
    ['room_lost'] = "Tvojoj sobi %s ponestalo je kredita pa je predana.",

    -- credit
    ['credit_too_high'] = "Soba može imati najviše $%s kredita.",
    ['credit_added'] = "Dodano $%s kredita. Kredit sada: $%s.",
    ['cannot_withdraw'] = "Ne možeš uzeti više kredita nego što soba ima.",
    ['credit_withdrawn'] = "Uzeto $%s kredita. Kredit sada: $%s.",

    -- locker
    ['locker_label'] = "Ormarić sobe %s",
    ['locker_failed'] = "Ormarić sobe nije se mogao otvoriti.",

    -- guests
    ['player_not_found'] = "Taj igrač nije pronađen.",
    ['player_not_near'] = "Taj igrač nije dovoljno blizu.",
    ['nobody_near'] = "Nitko nije dovoljno blizu da ga pozoveš.",
    ['already_guest'] = "Taj igrač je već gost.",
    ['max_guests'] = "Ova soba već ima najviše dopuštenih gostiju (%s).",
    ['guest_added'] = "%s je sada gost tvoje sobe.",
    ['guest_removed'] = "%s više nije gost tvoje sobe.",
    ['you_were_invited'] = "%s te pozvao u sobu %s – %s.",
    ['you_were_removed'] = "Više nisi gost sobe %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Pričekaj %s s prije nego opet izbaciš goste.",
    ['no_guests_to_evict'] = "Nema gostiju za izbaciti.",
    ['evicted'] = "Izbačeno gostiju iz tvoje sobe: %s.",
    ['evicted_and_removed'] = "Izbačeno gostiju i maknuto s popisa gostiju: %s.",
    ['you_were_evicted'] = "%s te izbacio iz sobe.",
    ['evict_confirm'] = "Ovo odmah šalje van iz tvoje sobe gostiju: %s. Nastaviti?",

    -- telegrams
    ['telegram_sender'] = "Hotelska recepcija",
    ['tg_invite_subject'] = "Poziv u hotelsku sobu",
    ['tg_invite_body'] = "%s te pozvao u sobu %s – %s. Na recepciji se prijavi kao gost.",
    ['tg_evicted_subject'] = "Izbačen iz hotelske sobe",
    ['tg_evicted_body'] = "%s te izbacio iz sobe %s. Kasnije se i dalje možeš prijaviti kao gost.",
    ['tg_evicted_body_removed'] = "%s te izbacio iz sobe %s i povukao tvoj poziv.",
    ['tg_low_subject'] = "Kredit sobe je pri kraju",
    ['tg_low_body'] = "Kredit za sobu %s – %s je pri kraju: preostalo $%s. Dodaj kredit u izborniku sobe.",
    ['tg_lost_subject'] = "Soba predana",
    ['tg_lost_body'] = "Sobi %s – %s ponestalo je kredita pa si odjavljen. Hvala što ste odsjeli kod nas.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotelska soba unajmljena",
    ['log_evicted'] = "Hotelski gosti izbačeni",
    ['log_lost'] = "Hotelska soba izgubljena",

    -- desk menu
    ['menu_check_in'] = "Prijava",
    ['menu_check_in_desc'] = "Idi gore u sobu %s. Kredit: $%s",
    ['menu_rent'] = "Unajmi sobu ($%s)",
    ['menu_rent_desc'] = "Novac postaje prvi kredit tvoje sobe.",
    ['menu_guest_check_in'] = "Prijava gosta",
    ['menu_guest_check_in_desc'] = "Idi gore u sobu u koju si pozvan.",

    -- room menu
    ['room_title'] = "Soba %s",
    ['badge_guest'] = "Gost",
    ['menu_add_credit'] = "Dodaj kredit",
    ['menu_credit_now'] = "Kredit sada: $%s",
    ['menu_remove_credit'] = "Uzmi kredit",
    ['menu_remove_credit_desc'] = "Vrati novac iz kredita sobe.",
    ['menu_guests'] = "Gosti",
    ['menu_guests_desc'] = "Pozovi igrače ili povuci poziv.",
    ['menu_evict'] = "Izbaci goste",
    ['menu_evict_desc'] = "Odmah pošalji sve goste van iz sobe.",
    ['menu_locker'] = "Ormarić sobe",
    ['menu_locker_desc'] = "Spremi svoje stvari.",
    ['menu_guest_access'] = "Pristup gosta",
    ['menu_owner'] = "Soba: %s",
    ['menu_leave'] = "Napusti sobu",
    ['menu_leave_desc'] = "Vrati se dolje na ulicu.",
    ['menu_mail'] = "Brzojavi",
    ['menu_mail_desc'] = "Čitaj i šalji brzojave.",
    ['input_add_label'] = "Iznos za dodati (kredit sada: $%s)",
    ['input_remove_label'] = "Iznos za uzeti (kredit sada: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Pozovi igrača",
    ['menu_add_guest_desc'] = "Igrači blizu tebe.",
    ['menu_current_guests'] = "Gosti",
    ['menu_no_guests'] = "Nema gostiju",
    ['menu_no_guests_desc'] = "Još nikoga nisi pozvao.",
    ['menu_guest_row'] = "Pozvan %s. Odaberi za povlačenje poziva.",
    ['menu_invite'] = "Pozovi igrača",
    ['menu_invite_row'] = "ID %s. Odaberi za poziv.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Izbornik sobe",
    ['target_desk'] = "Recepcija",
    ['target_room'] = "Izbornik sobe",

    -- page
    ['ui_subtitle'] = "Usluge za goste",
    ['ui_back'] = "Natrag",
    ['ui_close'] = "Zatvori",
    ['ui_cancel'] = "Odustani",
    ['ui_confirm'] = "Potvrdi",
    ['ui_amount'] = "Iznos",
    ['ui_max'] = "Maks.",
    ['ui_valid_amount'] = "Unesi ispravan iznos",
    ['ui_success'] = "Uspjeh",
    ['ui_error'] = "Greška",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Obavijest",
}

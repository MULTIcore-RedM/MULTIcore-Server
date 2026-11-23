Locales = Locales or {}
Locales['fi'] = {
    -- general
    ['notify_title'] = "Hotelli",
    ['too_far'] = "Olet liian kaukana vastaanotosta.",
    ['not_enough_money'] = "Sinulla ei ole tarpeeksi rahaa.",
    ['bad_amount'] = "Anna kelvollinen summa.",
    ['not_owner'] = "Vain huoneen vuokrannut asukas voi tehdä sen.",
    ['no_active_room'] = "Et ole hotellihuoneessa.",

    -- hotels
    ['hotel_valentine'] = "Valentinen hotelli",
    ['hotel_strawberry'] = "Strawberryn hotelli",
    ['hotel_rhodes'] = "Rhodesin hotelli",
    ['hotel_stdenis'] = "Saint Denisin hotelli",
    ['hotel_blackwater'] = "Blackwaterin hotelli",
    ['hotel_tumbleweed'] = "Tumbleweedin hotelli",
    ['hotel_annesburg'] = "Annesburgin hotelli",

    -- renting and checking in
    ['already_have_room'] = "Sinulla on jo huone tässä hotellissa.",
    ['no_free_room'] = "Vapaita huoneita ei ole juuri nyt. Yritä myöhemmin.",
    ['rented'] = "Vuokrasit huoneen %s (%s).",
    ['no_room_here'] = "Sinulla ei ole huonetta tässä hotellissa.",
    ['not_a_guest'] = "Et ole vieras tässä hotellissa.",
    ['guest_checked_in'] = "Kirjauduit vieraana huoneeseen %s.",
    ['room_lost'] = "Huoneesi %s saldo loppui ja huoneesta luovuttiin.",

    -- credit
    ['credit_too_high'] = "Huoneen saldo voi olla enintään $%s.",
    ['credit_added'] = "Lisätty $%s saldoa. Saldo nyt: $%s.",
    ['cannot_withdraw'] = "Et voi nostaa enempää kuin huoneen saldossa on.",
    ['credit_withdrawn'] = "Nostettu $%s saldosta. Saldo nyt: $%s.",

    -- locker
    ['locker_label'] = "Huoneen %s kaappi",
    ['locker_failed'] = "Huoneen kaappia ei voitu avata.",

    -- guests
    ['player_not_found'] = "Pelaajaa ei löytynyt.",
    ['player_not_near'] = "Se pelaaja ei ole tarpeeksi lähellä.",
    ['nobody_near'] = "Kukaan ei ole tarpeeksi lähellä kutsuttavaksi.",
    ['already_guest'] = "Se pelaaja on jo vieras.",
    ['max_guests'] = "Huoneessa on jo suurin sallittu määrä vieraita (%s).",
    ['guest_added'] = "%s on nyt huoneesi vieras.",
    ['guest_removed'] = "%s ei ole enää huoneesi vieras.",
    ['you_were_invited'] = "%s kutsui sinut huoneeseen %s (%s).",
    ['you_were_removed'] = "Et ole enää huoneen %s vieras.",

    -- throwing guests out
    ['evict_cooldown'] = "Odota %s sekuntia ennen kuin heität vieraita taas ulos.",
    ['no_guests_to_evict'] = "Ulos heitettäviä vieraita ei ole.",
    ['evicted'] = "Vieraita heitetty ulos huoneestasi: %s.",
    ['evicted_and_removed'] = "Vieraita heitetty ulos ja poistettu vieraslistalta: %s.",
    ['you_were_evicted'] = "%s heitti sinut ulos huoneesta.",
    ['evict_confirm'] = "Tämä lähettää heti huoneestasi pois vieraita: %s. Jatketaanko?",

    -- telegrams
    ['telegram_sender'] = "Hotellin vastaanotto",
    ['tg_invite_subject'] = "Kutsu hotellihuoneeseen",
    ['tg_invite_body'] = "%s kutsui sinut huoneeseen %s (%s). Kysy vastaanotosta, niin pääset kirjautumaan vieraana.",
    ['tg_evicted_subject'] = "Heitetty ulos hotellihuoneesta",
    ['tg_evicted_body'] = "%s heitti sinut ulos huoneesta %s. Voit silti kirjautua myöhemmin vieraana.",
    ['tg_evicted_body_removed'] = "%s heitti sinut ulos huoneesta %s ja perui kutsusi.",
    ['tg_low_subject'] = "Huoneen saldo vähissä",
    ['tg_low_body'] = "Huoneen %s (%s) saldo on vähissä: $%s jäljellä. Lisää saldoa huoneen valikosta.",
    ['tg_lost_subject'] = "Huoneesta luovuttu",
    ['tg_lost_body'] = "Huoneen %s (%s) saldo loppui, joten sinut on kirjattu ulos. Kiitos, että majoituit luonamme.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotellihuone vuokrattu",
    ['log_evicted'] = "Hotellin vieraat heitetty ulos",
    ['log_lost'] = "Hotellihuone menetetty",

    -- desk menu
    ['menu_check_in'] = "Kirjaudu sisään",
    ['menu_check_in_desc'] = "Mene ylös huoneeseen %s. Saldo: $%s",
    ['menu_rent'] = "Vuokraa huone ($%s)",
    ['menu_rent_desc'] = "Rahasta tulee huoneesi ensimmäinen saldo.",
    ['menu_guest_check_in'] = "Kirjaudu vieraana",
    ['menu_guest_check_in_desc'] = "Mene ylös huoneeseen, johon sinut kutsuttiin.",

    -- room menu
    ['room_title'] = "Huone %s",
    ['badge_guest'] = "Vieras",
    ['menu_add_credit'] = "Lisää saldoa",
    ['menu_credit_now'] = "Saldo nyt: $%s",
    ['menu_remove_credit'] = "Nosta saldoa",
    ['menu_remove_credit_desc'] = "Ota rahaa takaisin huoneen saldosta.",
    ['menu_guests'] = "Vieraat",
    ['menu_guests_desc'] = "Kutsu pelaajia tai peru kutsu.",
    ['menu_evict'] = "Heitä vieraat ulos",
    ['menu_evict_desc'] = "Lähetä heti kaikki vieraat pois huoneesta.",
    ['menu_locker'] = "Huoneen kaappi",
    ['menu_locker_desc'] = "Säilytä tavarasi.",
    ['menu_guest_access'] = "Vieraan pääsy",
    ['menu_owner'] = "Huoneen haltija: %s",
    ['menu_leave'] = "Poistu huoneesta",
    ['menu_leave_desc'] = "Palaa alas kadulle.",
    ['menu_mail'] = "Sähkeet",
    ['menu_mail_desc'] = "Lue ja lähetä sähkeitä.",
    ['input_add_label'] = "Lisättävä summa (saldo nyt: $%s)",
    ['input_remove_label'] = "Nostettava summa (saldo nyt: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Kutsu pelaaja",
    ['menu_add_guest_desc'] = "Lähelläsi olevat pelaajat.",
    ['menu_current_guests'] = "Vieraat",
    ['menu_no_guests'] = "Ei vieraita",
    ['menu_no_guests_desc'] = "Et ole vielä kutsunut ketään.",
    ['menu_guest_row'] = "Kutsuttu: %s. Valitse peruaksesi kutsun.",
    ['menu_invite'] = "Kutsu pelaaja",
    ['menu_invite_row'] = "ID %s. Valitse kutsuaksesi.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Huoneen valikko",
    ['target_desk'] = "Vastaanotto",
    ['target_room'] = "Huoneen valikko",

    -- page
    ['ui_subtitle'] = "Vieraspalvelu",
    ['ui_back'] = "Takaisin",
    ['ui_close'] = "Sulje",
    ['ui_cancel'] = "Peruuta",
    ['ui_confirm'] = "Vahvista",
    ['ui_amount'] = "Summa",
    ['ui_max'] = "Maks.",
    ['ui_valid_amount'] = "Anna kelvollinen summa",
    ['ui_success'] = "Onnistui",
    ['ui_error'] = "Virhe",
    ['ui_info'] = "Tieto",
    ['ui_notice'] = "Ilmoitus",
}

Locales = Locales or {}
Locales['no'] = {
    -- general
    ['notify_title'] = "Hotell",
    ['too_far'] = "Du er for langt fra resepsjonen.",
    ['not_enough_money'] = "Du har ikke nok penger.",
    ['bad_amount'] = "Skriv inn et gyldig beløp.",
    ['not_owner'] = "Bare gjesten som leide rommet kan gjøre det.",
    ['no_active_room'] = "Du er ikke på et hotellrom.",

    -- hotels
    ['hotel_valentine'] = "Valentine Hotell",
    ['hotel_strawberry'] = "Strawberry Hotell",
    ['hotel_rhodes'] = "Rhodes Hotell",
    ['hotel_stdenis'] = "Saint Denis Hotell",
    ['hotel_blackwater'] = "Blackwater Hotell",
    ['hotel_tumbleweed'] = "Tumbleweed Hotell",
    ['hotel_annesburg'] = "Annesburg Hotell",

    -- renting and checking in
    ['already_have_room'] = "Du har allerede et rom på dette hotellet.",
    ['no_free_room'] = "Det er ingen ledige rom akkurat nå. Prøv igjen senere.",
    ['rented'] = "Du leide rom %s på %s.",
    ['no_room_here'] = "Du har ikke noe rom på dette hotellet.",
    ['not_a_guest'] = "Du er ikke gjest på dette hotellet.",
    ['guest_checked_in'] = "Sjekket inn som gjest på rom %s.",
    ['room_lost'] = "Rommet ditt %s gikk tom for kreditt og ble gitt opp.",

    -- credit
    ['credit_too_high'] = "Et rom kan ha høyst $%s i kreditt.",
    ['credit_added'] = "La til $%s i kreditt. Kreditt nå: $%s.",
    ['cannot_withdraw'] = "Du kan ikke ta ut mer kreditt enn rommet har.",
    ['credit_withdrawn'] = "Tok ut $%s i kreditt. Kreditt nå: $%s.",

    -- locker
    ['locker_label'] = "Skap på rom %s",
    ['locker_failed'] = "Romskapet kunne ikke åpnes.",

    -- guests
    ['player_not_found'] = "Spilleren ble ikke funnet.",
    ['player_not_near'] = "Den spilleren er ikke nær nok.",
    ['nobody_near'] = "Ingen er nær nok til å bli invitert.",
    ['already_guest'] = "Den spilleren er allerede gjest.",
    ['max_guests'] = "Rommet har allerede så mange gjester som det kan ha (%s).",
    ['guest_added'] = "%s er nå gjest på rommet ditt.",
    ['guest_removed'] = "%s er ikke lenger gjest på rommet ditt.",
    ['you_were_invited'] = "%s inviterte deg til rom %s på %s.",
    ['you_were_removed'] = "Du er ikke lenger gjest på rom %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Vent %s sekunder før du kaster ut gjester igjen.",
    ['no_guests_to_evict'] = "Det er ingen gjester å kaste ut.",
    ['evicted'] = "%s gjest(er) kastet ut av rommet ditt.",
    ['evicted_and_removed'] = "%s gjest(er) kastet ut og fjernet fra gjestelisten.",
    ['you_were_evicted'] = "%s kastet deg ut av rommet.",
    ['evict_confirm'] = "Dette sender %s gjest(er) ut av rommet ditt med en gang. Fortsette?",

    -- telegrams
    ['telegram_sender'] = "Hotellresepsjonen",
    ['tg_invite_subject'] = "Invitasjon til hotellrom",
    ['tg_invite_body'] = "%s inviterte deg til rom %s på %s. Spør i resepsjonen for å sjekke inn som gjest.",
    ['tg_evicted_subject'] = "Kastet ut av et hotellrom",
    ['tg_evicted_body'] = "%s kastet deg ut av rom %s. Du kan fortsatt sjekke inn som gjest senere.",
    ['tg_evicted_body_removed'] = "%s kastet deg ut av rom %s og trakk tilbake invitasjonen din.",
    ['tg_low_subject'] = "Romkreditten er i ferd med å ta slutt",
    ['tg_low_body'] = "Kreditten for rom %s på %s er i ferd med å ta slutt: $%s igjen. Fyll på i rommenyen.",
    ['tg_lost_subject'] = "Rommet gitt opp",
    ['tg_lost_body'] = "Rom %s på %s gikk tom for kreditt, så du er sjekket ut. Takk for at du bodde hos oss.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotellrom leid",
    ['log_evicted'] = "Hotellgjester kastet ut",
    ['log_lost'] = "Hotellrom mistet",

    -- desk menu
    ['menu_check_in'] = "Sjekk inn",
    ['menu_check_in_desc'] = "Gå opp til rom %s. Kreditt: $%s",
    ['menu_rent'] = "Lei et rom ($%s)",
    ['menu_rent_desc'] = "Pengene blir rommets første kreditt.",
    ['menu_guest_check_in'] = "Sjekk inn som gjest",
    ['menu_guest_check_in_desc'] = "Gå opp til rommet du ble invitert til.",

    -- room menu
    ['room_title'] = "Rom %s",
    ['badge_guest'] = "Gjest",
    ['menu_add_credit'] = "Legg til kreditt",
    ['menu_credit_now'] = "Kreditt nå: $%s",
    ['menu_remove_credit'] = "Ta ut kreditt",
    ['menu_remove_credit_desc'] = "Få penger tilbake fra rommets kreditt.",
    ['menu_guests'] = "Gjester",
    ['menu_guests_desc'] = "Inviter spillere eller trekk tilbake en invitasjon.",
    ['menu_evict'] = "Kast ut gjester",
    ['menu_evict_desc'] = "Send alle gjester ut av rommet med en gang.",
    ['menu_locker'] = "Romskap",
    ['menu_locker_desc'] = "Oppbevar tingene dine.",
    ['menu_guest_access'] = "Gjestetilgang",
    ['menu_owner'] = "Rommet til %s",
    ['menu_leave'] = "Forlat rommet",
    ['menu_leave_desc'] = "Gå ned til gaten igjen.",
    ['menu_mail'] = "Telegrammer",
    ['menu_mail_desc'] = "Les og send telegrammer.",
    ['input_add_label'] = "Beløp å legge til (kreditt nå: $%s)",
    ['input_remove_label'] = "Beløp å ta ut (kreditt nå: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Inviter en spiller",
    ['menu_add_guest_desc'] = "Spillere nær deg.",
    ['menu_current_guests'] = "Gjester",
    ['menu_no_guests'] = "Ingen gjester",
    ['menu_no_guests_desc'] = "Du har ikke invitert noen ennå.",
    ['menu_guest_row'] = "Invitert: %s. Velg for å trekke tilbake invitasjonen.",
    ['menu_invite'] = "Inviter en spiller",
    ['menu_invite_row'] = "ID %s. Velg for å invitere.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Rommeny",
    ['target_desk'] = "Resepsjon",
    ['target_room'] = "Rommeny",

    -- page
    ['ui_subtitle'] = "Gjesteservice",
    ['ui_back'] = "Tilbake",
    ['ui_close'] = "Lukk",
    ['ui_cancel'] = "Avbryt",
    ['ui_confirm'] = "Bekreft",
    ['ui_amount'] = "Beløp",
    ['ui_max'] = "Maks",
    ['ui_valid_amount'] = "Skriv inn et gyldig beløp",
    ['ui_success'] = "Fullført",
    ['ui_error'] = "Feil",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Merknad",
}

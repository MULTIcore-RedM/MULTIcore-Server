Locales = Locales or {}
Locales['nl'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Je bent te ver van de receptie.",
    ['not_enough_money'] = "Je hebt niet genoeg geld.",
    ['bad_amount'] = "Voer een geldig bedrag in.",
    ['not_owner'] = "Alleen de gast die deze kamer huurt kan dat doen.",
    ['no_active_room'] = "Je bent niet in een hotelkamer.",

    -- hotels
    ['hotel_valentine'] = "Hotel Valentine",
    ['hotel_strawberry'] = "Hotel Strawberry",
    ['hotel_rhodes'] = "Hotel Rhodes",
    ['hotel_stdenis'] = "Hotel Saint Denis",
    ['hotel_blackwater'] = "Hotel Blackwater",
    ['hotel_tumbleweed'] = "Hotel Tumbleweed",
    ['hotel_annesburg'] = "Hotel Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Je hebt al een kamer in dit hotel.",
    ['no_free_room'] = "Er is nu geen kamer vrij. Probeer het later nog eens.",
    ['rented'] = "Je hebt kamer %s gehuurd in het %s.",
    ['no_room_here'] = "Je hebt geen kamer in dit hotel.",
    ['not_a_guest'] = "Je bent geen gast in dit hotel.",
    ['guest_checked_in'] = "Als gast ingecheckt in kamer %s.",
    ['room_lost'] = "Je kamer %s had geen krediet meer en is opgegeven.",

    -- credit
    ['credit_too_high'] = "Een kamer kan hoogstens $%s krediet hebben.",
    ['credit_added'] = "$%s krediet toegevoegd. Krediet nu: $%s.",
    ['cannot_withdraw'] = "Je kunt niet meer krediet opnemen dan de kamer heeft.",
    ['credit_withdrawn'] = "$%s krediet opgenomen. Krediet nu: $%s.",

    -- locker
    ['locker_label'] = "Kluisje kamer %s",
    ['locker_failed'] = "Het kluisje van de kamer kon niet worden geopend.",

    -- guests
    ['player_not_found'] = "Die speler is niet gevonden.",
    ['player_not_near'] = "Die speler is niet dichtbij genoeg.",
    ['nobody_near'] = "Er is niemand dichtbij genoeg om uit te nodigen.",
    ['already_guest'] = "Die speler is al een gast.",
    ['max_guests'] = "Deze kamer heeft al het maximale aantal gasten (%s).",
    ['guest_added'] = "%s is nu een gast van je kamer.",
    ['guest_removed'] = "%s is geen gast meer van je kamer.",
    ['you_were_invited'] = "%s heeft je uitgenodigd in kamer %s in het %s.",
    ['you_were_removed'] = "Je bent geen gast meer van kamer %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Wacht %s seconden voordat je weer gasten eruit zet.",
    ['no_guests_to_evict'] = "Er zijn geen gasten om eruit te zetten.",
    ['evicted'] = "%s gast(en) uit je kamer gezet.",
    ['evicted_and_removed'] = "%s gast(en) eruit gezet en van de gastenlijst gehaald.",
    ['you_were_evicted'] = "%s heeft je uit de kamer gezet.",
    ['evict_confirm'] = "Hiermee moeten %s gast(en) meteen je kamer uit. Doorgaan?",

    -- telegrams
    ['telegram_sender'] = "Hotelreceptie",
    ['tg_invite_subject'] = "Uitnodiging voor een hotelkamer",
    ['tg_invite_body'] = "%s heeft je uitgenodigd in kamer %s in het %s. Vraag bij de receptie om als gast in te checken.",
    ['tg_evicted_subject'] = "Uit een hotelkamer gezet",
    ['tg_evicted_body'] = "%s heeft je uit kamer %s gezet. Je kunt later nog steeds als gast inchecken.",
    ['tg_evicted_body_removed'] = "%s heeft je uit kamer %s gezet en je uitnodiging ingetrokken.",
    ['tg_low_subject'] = "Kamerkrediet raakt op",
    ['tg_low_body'] = "Het krediet van kamer %s in het %s raakt op: nog $%s over. Voeg krediet toe via het kamermenu.",
    ['tg_lost_subject'] = "Kamer opgegeven",
    ['tg_lost_body'] = "Kamer %s in het %s had geen krediet meer, dus je bent uitgecheckt. Bedankt voor je verblijf.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotelkamer gehuurd",
    ['log_evicted'] = "Hotelgasten eruit gezet",
    ['log_lost'] = "Hotelkamer verloren",

    -- desk menu
    ['menu_check_in'] = "Inchecken",
    ['menu_check_in_desc'] = "Naar boven, naar kamer %s. Krediet: $%s",
    ['menu_rent'] = "Kamer huren ($%s)",
    ['menu_rent_desc'] = "Het geld wordt het eerste krediet van je kamer.",
    ['menu_guest_check_in'] = "Inchecken als gast",
    ['menu_guest_check_in_desc'] = "Naar boven, naar de kamer waar je bent uitgenodigd.",

    -- room menu
    ['room_title'] = "Kamer %s",
    ['badge_guest'] = "Gast",
    ['menu_add_credit'] = "Krediet toevoegen",
    ['menu_credit_now'] = "Krediet nu: $%s",
    ['menu_remove_credit'] = "Krediet opnemen",
    ['menu_remove_credit_desc'] = "Geld terugnemen uit het kamerkrediet.",
    ['menu_guests'] = "Gasten",
    ['menu_guests_desc'] = "Spelers uitnodigen of een uitnodiging intrekken.",
    ['menu_evict'] = "Gasten eruit zetten",
    ['menu_evict_desc'] = "Alle gasten meteen de kamer uit sturen.",
    ['menu_locker'] = "Kamerkluisje",
    ['menu_locker_desc'] = "Berg je spullen op.",
    ['menu_guest_access'] = "Gasttoegang",
    ['menu_owner'] = "Kamer van %s",
    ['menu_leave'] = "Kamer verlaten",
    ['menu_leave_desc'] = "Terug naar beneden, de straat op.",
    ['menu_mail'] = "Telegrammen",
    ['menu_mail_desc'] = "Telegrammen lezen en versturen.",
    ['input_add_label'] = "Bedrag om toe te voegen (krediet nu: $%s)",
    ['input_remove_label'] = "Bedrag om op te nemen (krediet nu: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Speler uitnodigen",
    ['menu_add_guest_desc'] = "Spelers bij jou in de buurt.",
    ['menu_current_guests'] = "Gasten",
    ['menu_no_guests'] = "Geen gasten",
    ['menu_no_guests_desc'] = "Je hebt nog niemand uitgenodigd.",
    ['menu_guest_row'] = "%s uitgenodigd. Kies om de uitnodiging in te trekken.",
    ['menu_invite'] = "Speler uitnodigen",
    ['menu_invite_row'] = "ID %s. Kies om uit te nodigen.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Kamermenu",
    ['target_desk'] = "Receptie",
    ['target_room'] = "Kamermenu",

    -- page
    ['ui_subtitle'] = "Gastenservice",
    ['ui_back'] = "Terug",
    ['ui_close'] = "Sluiten",
    ['ui_cancel'] = "Annuleren",
    ['ui_confirm'] = "Bevestigen",
    ['ui_amount'] = "Bedrag",
    ['ui_max'] = "Max",
    ['ui_valid_amount'] = "Voer een geldig bedrag in",
    ['ui_success'] = "Gelukt",
    ['ui_error'] = "Fout",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Melding",
}

Locales = Locales or {}
Locales['de'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Du bist zu weit von der Rezeption entfernt.",
    ['not_enough_money'] = "Du hast nicht genug Geld.",
    ['bad_amount'] = "Gib einen gültigen Betrag ein.",
    ['not_owner'] = "Das kann nur der Gast, der dieses Zimmer gemietet hat.",
    ['no_active_room'] = "Du bist in keinem Hotelzimmer.",

    -- hotels
    ['hotel_valentine'] = "Hotel Valentine",
    ['hotel_strawberry'] = "Hotel Strawberry",
    ['hotel_rhodes'] = "Hotel Rhodes",
    ['hotel_stdenis'] = "Hotel Saint Denis",
    ['hotel_blackwater'] = "Hotel Blackwater",
    ['hotel_tumbleweed'] = "Hotel Tumbleweed",
    ['hotel_annesburg'] = "Hotel Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Du hast bereits ein Zimmer in diesem Hotel.",
    ['no_free_room'] = "Gerade ist kein Zimmer frei. Versuch es später noch einmal.",
    ['rented'] = "Du hast Zimmer %s im %s gemietet.",
    ['no_room_here'] = "Du hast kein Zimmer in diesem Hotel.",
    ['not_a_guest'] = "Du bist kein Gast in diesem Hotel.",
    ['guest_checked_in'] = "Als Gast in Zimmer %s eingecheckt.",
    ['room_lost'] = "Das Guthaben für dein Zimmer %s ist aufgebraucht, das Zimmer wurde aufgegeben.",

    -- credit
    ['credit_too_high'] = "Ein Zimmer kann höchstens $%s Guthaben haben.",
    ['credit_added'] = "$%s Guthaben hinzugefügt. Guthaben jetzt: $%s.",
    ['cannot_withdraw'] = "Du kannst nicht mehr Guthaben abheben, als das Zimmer hat.",
    ['credit_withdrawn'] = "$%s Guthaben abgehoben. Guthaben jetzt: $%s.",

    -- locker
    ['locker_label'] = "Schrank Zimmer %s",
    ['locker_failed'] = "Der Zimmerschrank konnte nicht geöffnet werden.",

    -- guests
    ['player_not_found'] = "Dieser Spieler wurde nicht gefunden.",
    ['player_not_near'] = "Dieser Spieler ist nicht nah genug.",
    ['nobody_near'] = "Niemand ist nah genug, um eingeladen zu werden.",
    ['already_guest'] = "Dieser Spieler ist bereits Gast.",
    ['max_guests'] = "Dieses Zimmer hat bereits die maximale Anzahl an Gästen (%s).",
    ['guest_added'] = "%s ist jetzt Gast in deinem Zimmer.",
    ['guest_removed'] = "%s ist kein Gast mehr in deinem Zimmer.",
    ['you_were_invited'] = "%s hat dich in Zimmer %s im %s eingeladen.",
    ['you_were_removed'] = "Du bist kein Gast mehr in Zimmer %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Warte %s Sekunden, bevor du wieder Gäste rauswirfst.",
    ['no_guests_to_evict'] = "Es sind keine Gäste zum Rauswerfen da.",
    ['evicted'] = "%s Gast/Gäste aus deinem Zimmer geworfen.",
    ['evicted_and_removed'] = "%s Gast/Gäste rausgeworfen und von der Gästeliste gestrichen.",
    ['you_were_evicted'] = "%s hat dich aus dem Zimmer geworfen.",
    ['evict_confirm'] = "Damit müssen %s Gast/Gäste sofort dein Zimmer verlassen. Fortfahren?",

    -- telegrams
    ['telegram_sender'] = "Hotelrezeption",
    ['tg_invite_subject'] = "Einladung in ein Hotelzimmer",
    ['tg_invite_body'] = "%s hat dich in Zimmer %s im %s eingeladen. Frag an der Rezeption, um als Gast einzuchecken.",
    ['tg_evicted_subject'] = "Aus einem Hotelzimmer geworfen",
    ['tg_evicted_body'] = "%s hat dich aus Zimmer %s geworfen. Du kannst später trotzdem wieder als Gast einchecken.",
    ['tg_evicted_body_removed'] = "%s hat dich aus Zimmer %s geworfen und deine Einladung zurückgenommen.",
    ['tg_low_subject'] = "Zimmerguthaben wird knapp",
    ['tg_low_body'] = "Das Guthaben für Zimmer %s im %s wird knapp: noch $%s. Lade im Zimmermenü Guthaben auf.",
    ['tg_lost_subject'] = "Zimmer aufgegeben",
    ['tg_lost_body'] = "Das Guthaben für Zimmer %s im %s ist aufgebraucht, daher wurdest du ausgecheckt. Danke für deinen Aufenthalt.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotelzimmer gemietet",
    ['log_evicted'] = "Hotelgäste rausgeworfen",
    ['log_lost'] = "Hotelzimmer verloren",

    -- desk menu
    ['menu_check_in'] = "Einchecken",
    ['menu_check_in_desc'] = "Hoch in Zimmer %s. Guthaben: $%s",
    ['menu_rent'] = "Zimmer mieten ($%s)",
    ['menu_rent_desc'] = "Das Geld wird das erste Guthaben deines Zimmers.",
    ['menu_guest_check_in'] = "Als Gast einchecken",
    ['menu_guest_check_in_desc'] = "Hoch in das Zimmer, in das du eingeladen wurdest.",

    -- room menu
    ['room_title'] = "Zimmer %s",
    ['badge_guest'] = "Gast",
    ['menu_add_credit'] = "Guthaben hinzufügen",
    ['menu_credit_now'] = "Guthaben jetzt: $%s",
    ['menu_remove_credit'] = "Guthaben abheben",
    ['menu_remove_credit_desc'] = "Geld aus dem Zimmerguthaben zurücknehmen.",
    ['menu_guests'] = "Gäste",
    ['menu_guests_desc'] = "Spieler einladen oder eine Einladung zurücknehmen.",
    ['menu_evict'] = "Gäste rauswerfen",
    ['menu_evict_desc'] = "Alle Gäste sofort aus dem Zimmer schicken.",
    ['menu_locker'] = "Zimmerschrank",
    ['menu_locker_desc'] = "Verstau deine Sachen.",
    ['menu_guest_access'] = "Gastzugang",
    ['menu_owner'] = "Zimmer von %s",
    ['menu_leave'] = "Zimmer verlassen",
    ['menu_leave_desc'] = "Zurück runter auf die Straße.",
    ['menu_mail'] = "Telegramme",
    ['menu_mail_desc'] = "Telegramme lesen und senden.",
    ['input_add_label'] = "Betrag zum Einzahlen (Guthaben jetzt: $%s)",
    ['input_remove_label'] = "Betrag zum Abheben (Guthaben jetzt: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Spieler einladen",
    ['menu_add_guest_desc'] = "Spieler in deiner Nähe.",
    ['menu_current_guests'] = "Gäste",
    ['menu_no_guests'] = "Keine Gäste",
    ['menu_no_guests_desc'] = "Du hast noch niemanden eingeladen.",
    ['menu_guest_row'] = "%s eingeladen. Auswählen, um die Einladung zurückzunehmen.",
    ['menu_invite'] = "Spieler einladen",
    ['menu_invite_row'] = "ID %s. Auswählen, um einzuladen.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Zimmermenü",
    ['target_desk'] = "Rezeption",
    ['target_room'] = "Zimmermenü",

    -- page
    ['ui_subtitle'] = "Gästeservice",
    ['ui_back'] = "Zurück",
    ['ui_close'] = "Schließen",
    ['ui_cancel'] = "Abbrechen",
    ['ui_confirm'] = "Bestätigen",
    ['ui_amount'] = "Betrag",
    ['ui_max'] = "Max",
    ['ui_valid_amount'] = "Bitte gib einen gültigen Betrag ein",
    ['ui_success'] = "Erfolg",
    ['ui_error'] = "Fehler",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Hinweis",
}

Locales = Locales or {}
Locales['ro'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Ești prea departe de recepție.",
    ['not_enough_money'] = "Nu ai destui bani.",
    ['bad_amount'] = "Introdu o sumă validă.",
    ['not_owner'] = "Doar oaspetele care a închiriat camera poate face asta.",
    ['no_active_room'] = "Nu ești într-o cameră de hotel.",

    -- hotels
    ['hotel_valentine'] = "Hotelul Valentine",
    ['hotel_strawberry'] = "Hotelul Strawberry",
    ['hotel_rhodes'] = "Hotelul Rhodes",
    ['hotel_stdenis'] = "Hotelul Saint Denis",
    ['hotel_blackwater'] = "Hotelul Blackwater",
    ['hotel_tumbleweed'] = "Hotelul Tumbleweed",
    ['hotel_annesburg'] = "Hotelul Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Ai deja o cameră la acest hotel.",
    ['no_free_room'] = "Nu e nicio cameră liberă acum. Încearcă mai târziu.",
    ['rented'] = "Ai închiriat camera %s la %s.",
    ['no_room_here'] = "Nu ai o cameră la acest hotel.",
    ['not_a_guest'] = "Nu ești invitat la acest hotel.",
    ['guest_checked_in'] = "Te-ai cazat ca invitat în camera %s.",
    ['room_lost'] = "Camera ta %s a rămas fără credit și a fost eliberată.",

    -- credit
    ['credit_too_high'] = "O cameră poate avea cel mult $%s credit.",
    ['credit_added'] = "Ai adăugat $%s credit. Credit acum: $%s.",
    ['cannot_withdraw'] = "Nu poți retrage mai mult credit decât are camera.",
    ['credit_withdrawn'] = "Ai retras $%s credit. Credit acum: $%s.",

    -- locker
    ['locker_label'] = "Dulapul camerei %s",
    ['locker_failed'] = "Dulapul camerei nu a putut fi deschis.",

    -- guests
    ['player_not_found'] = "Jucătorul nu a fost găsit.",
    ['player_not_near'] = "Jucătorul nu e destul de aproape.",
    ['nobody_near'] = "Nu e nimeni destul de aproape ca să-l inviți.",
    ['already_guest'] = "Jucătorul este deja invitat.",
    ['max_guests'] = "Camera are deja numărul maxim de invitați (%s).",
    ['guest_added'] = "%s este acum invitat în camera ta.",
    ['guest_removed'] = "%s nu mai este invitat în camera ta.",
    ['you_were_invited'] = "%s te-a invitat în camera %s la %s.",
    ['you_were_removed'] = "Nu mai ești invitat în camera %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Așteaptă %s secunde înainte să dai iar afară invitații.",
    ['no_guests_to_evict'] = "Nu sunt invitați de dat afară.",
    ['evicted'] = "%s invitat(i) dat(i) afară din camera ta.",
    ['evicted_and_removed'] = "%s invitat(i) dat(i) afară și scos(și) de pe lista de invitați.",
    ['you_were_evicted'] = "%s te-a dat afară din cameră.",
    ['evict_confirm'] = "Asta scoate imediat %s invitat(i) din camera ta. Continui?",

    -- telegrams
    ['telegram_sender'] = "Recepția hotelului",
    ['tg_invite_subject'] = "Invitație într-o cameră de hotel",
    ['tg_invite_body'] = "%s te-a invitat în camera %s la %s. Întreabă la recepție ca să te cazezi ca invitat.",
    ['tg_evicted_subject'] = "Dat afară dintr-o cameră de hotel",
    ['tg_evicted_body'] = "%s te-a dat afară din camera %s. Te poți caza din nou ca invitat mai târziu.",
    ['tg_evicted_body_removed'] = "%s te-a dat afară din camera %s și ți-a retras invitația.",
    ['tg_low_subject'] = "Creditul camerei e pe terminate",
    ['tg_low_body'] = "Creditul camerei %s la %s e pe terminate: au rămas $%s. Adaugă credit din meniul camerei.",
    ['tg_lost_subject'] = "Cameră eliberată",
    ['tg_lost_body'] = "Camera %s la %s a rămas fără credit, așa că ai fost decazat. Îți mulțumim că ai stat la noi.",

    -- logs (MULTIserver)
    ['log_rented'] = "Cameră de hotel închiriată",
    ['log_evicted'] = "Invitați ai hotelului dați afară",
    ['log_lost'] = "Cameră de hotel pierdută",

    -- desk menu
    ['menu_check_in'] = "Cazare",
    ['menu_check_in_desc'] = "Urcă în camera %s. Credit: $%s",
    ['menu_rent'] = "Închiriază o cameră ($%s)",
    ['menu_rent_desc'] = "Banii devin primul credit al camerei tale.",
    ['menu_guest_check_in'] = "Cazare ca invitat",
    ['menu_guest_check_in_desc'] = "Urcă în camera în care ai fost invitat.",

    -- room menu
    ['room_title'] = "Camera %s",
    ['badge_guest'] = "Invitat",
    ['menu_add_credit'] = "Adaugă credit",
    ['menu_credit_now'] = "Credit acum: $%s",
    ['menu_remove_credit'] = "Retrage credit",
    ['menu_remove_credit_desc'] = "Ia înapoi bani din creditul camerei.",
    ['menu_guests'] = "Invitați",
    ['menu_guests_desc'] = "Invită jucători sau retrage o invitație.",
    ['menu_evict'] = "Dă afară invitații",
    ['menu_evict_desc'] = "Scoate imediat toți invitații din cameră.",
    ['menu_locker'] = "Dulapul camerei",
    ['menu_locker_desc'] = "Păstrează-ți lucrurile.",
    ['menu_guest_access'] = "Acces invitat",
    ['menu_owner'] = "Camera lui %s",
    ['menu_leave'] = "Părăsește camera",
    ['menu_leave_desc'] = "Coboară înapoi în stradă.",
    ['menu_mail'] = "Telegrame",
    ['menu_mail_desc'] = "Citește și trimite telegrame.",
    ['input_add_label'] = "Suma de adăugat (credit acum: $%s)",
    ['input_remove_label'] = "Suma de retras (credit acum: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Invită un jucător",
    ['menu_add_guest_desc'] = "Jucători aproape de tine.",
    ['menu_current_guests'] = "Invitați",
    ['menu_no_guests'] = "Niciun invitat",
    ['menu_no_guests_desc'] = "Nu ai invitat încă pe nimeni.",
    ['menu_guest_row'] = "Invitat: %s. Alege ca să retragi invitația.",
    ['menu_invite'] = "Invită un jucător",
    ['menu_invite_row'] = "ID %s. Alege ca să inviți.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Meniul camerei",
    ['target_desk'] = "Recepție",
    ['target_room'] = "Meniul camerei",

    -- page
    ['ui_subtitle'] = "Servicii pentru oaspeți",
    ['ui_back'] = "Înapoi",
    ['ui_close'] = "Închide",
    ['ui_cancel'] = "Anulează",
    ['ui_confirm'] = "Confirmă",
    ['ui_amount'] = "Sumă",
    ['ui_max'] = "Max",
    ['ui_valid_amount'] = "Introdu o sumă validă",
    ['ui_success'] = "Succes",
    ['ui_error'] = "Eroare",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Notificare",
}

Locales = Locales or {}
Locales['hu'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Túl messze vagy a recepciótól.",
    ['not_enough_money'] = "Nincs elég pénzed.",
    ['bad_amount'] = "Adj meg egy érvényes összeget.",
    ['not_owner'] = "Ezt csak az a vendég teheti meg, aki kibérelte a szobát.",
    ['no_active_room'] = "Nem vagy hotelszobában.",

    -- hotels
    ['hotel_valentine'] = "Valentine Hotel",
    ['hotel_strawberry'] = "Strawberry Hotel",
    ['hotel_rhodes'] = "Rhodes Hotel",
    ['hotel_stdenis'] = "Saint Denis Hotel",
    ['hotel_blackwater'] = "Blackwater Hotel",
    ['hotel_tumbleweed'] = "Tumbleweed Hotel",
    ['hotel_annesburg'] = "Annesburg Hotel",

    -- renting and checking in
    ['already_have_room'] = "Már van szobád ebben a hotelben.",
    ['no_free_room'] = "Most nincs szabad szoba. Próbáld később.",
    ['rented'] = "Kibérelted a(z) %s. szobát (%s).",
    ['no_room_here'] = "Nincs szobád ebben a hotelben.",
    ['not_a_guest'] = "Nem vagy vendég ebben a hotelben.",
    ['guest_checked_in'] = "Bejelentkeztél vendégként a(z) %s. szobába.",
    ['room_lost'] = "A(z) %s. szobád egyenlege elfogyott, ezért a szobát feladtuk.",

    -- credit
    ['credit_too_high'] = "Egy szoba egyenlege legfeljebb $%s lehet.",
    ['credit_added'] = "$%s egyenleg hozzáadva. Jelenlegi egyenleg: $%s.",
    ['cannot_withdraw'] = "Nem vehetsz ki többet, mint amennyi a szoba egyenlege.",
    ['credit_withdrawn'] = "$%s egyenleg kivéve. Jelenlegi egyenleg: $%s.",

    -- locker
    ['locker_label'] = "%s. szoba szekrénye",
    ['locker_failed'] = "A szoba szekrényét nem sikerült kinyitni.",

    -- guests
    ['player_not_found'] = "A játékos nem található.",
    ['player_not_near'] = "Az a játékos nincs elég közel.",
    ['nobody_near'] = "Senki sincs elég közel, hogy meghívd.",
    ['already_guest'] = "Az a játékos már vendég.",
    ['max_guests'] = "Ebben a szobában már a megengedett legtöbb vendég van (%s).",
    ['guest_added'] = "%s mostantól a szobád vendége.",
    ['guest_removed'] = "%s már nem a szobád vendége.",
    ['you_were_invited'] = "%s meghívott a(z) %s. szobába (%s).",
    ['you_were_removed'] = "Már nem vagy a(z) %s. szoba vendége.",

    -- throwing guests out
    ['evict_cooldown'] = "Várj %s másodpercet, mielőtt újra kidobod a vendégeket.",
    ['no_guests_to_evict'] = "Nincs kit kidobni.",
    ['evicted'] = "%s vendég kidobva a szobádból.",
    ['evicted_and_removed'] = "%s vendég kidobva és törölve a vendéglistáról.",
    ['you_were_evicted'] = "%s kidobott a szobából.",
    ['evict_confirm'] = "Ezzel azonnal kiküldesz %s vendéget a szobádból. Folytatod?",

    -- telegrams
    ['telegram_sender'] = "Hotel recepció",
    ['tg_invite_subject'] = "Meghívás hotelszobába",
    ['tg_invite_body'] = "%s meghívott a(z) %s. szobába (%s). Kérd a recepción, hogy vendégként bejelentkezhess.",
    ['tg_evicted_subject'] = "Kidobtak egy hotelszobából",
    ['tg_evicted_body'] = "%s kidobott a(z) %s. szobából. Később még bejelentkezhetsz vendégként.",
    ['tg_evicted_body_removed'] = "%s kidobott a(z) %s. szobából, és visszavonta a meghívásodat.",
    ['tg_low_subject'] = "Fogy a szoba egyenlege",
    ['tg_low_body'] = "A(z) %s. szoba (%s) egyenlege fogyóban: $%s maradt. Egyenleget a szoba menüjében adhatsz hozzá.",
    ['tg_lost_subject'] = "Szoba feladva",
    ['tg_lost_body'] = "A(z) %s. szoba (%s) egyenlege elfogyott, ezért kijelentkeztettünk. Köszönjük, hogy nálunk szálltál meg.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotelszoba kibérelve",
    ['log_evicted'] = "Hotelvendégek kidobva",
    ['log_lost'] = "Hotelszoba elveszett",

    -- desk menu
    ['menu_check_in'] = "Bejelentkezés",
    ['menu_check_in_desc'] = "Menj fel a(z) %s. szobába. Egyenleg: $%s",
    ['menu_rent'] = "Szoba bérlése ($%s)",
    ['menu_rent_desc'] = "A pénz a szobád első egyenlege lesz.",
    ['menu_guest_check_in'] = "Bejelentkezés vendégként",
    ['menu_guest_check_in_desc'] = "Menj fel a szobába, ahová meghívtak.",

    -- room menu
    ['room_title'] = "%s. szoba",
    ['badge_guest'] = "Vendég",
    ['menu_add_credit'] = "Egyenleg feltöltése",
    ['menu_credit_now'] = "Jelenlegi egyenleg: $%s",
    ['menu_remove_credit'] = "Egyenleg kivétele",
    ['menu_remove_credit_desc'] = "Pénz visszavétele a szoba egyenlegéből.",
    ['menu_guests'] = "Vendégek",
    ['menu_guests_desc'] = "Hívj meg játékosokat, vagy vond vissza a meghívást.",
    ['menu_evict'] = "Vendégek kidobása",
    ['menu_evict_desc'] = "Minden vendéget azonnal kiküld a szobából.",
    ['menu_locker'] = "Szobaszekrény",
    ['menu_locker_desc'] = "Tárold a holmidat.",
    ['menu_guest_access'] = "Vendég hozzáférés",
    ['menu_owner'] = "Szoba gazdája: %s",
    ['menu_leave'] = "Szoba elhagyása",
    ['menu_leave_desc'] = "Vissza le az utcára.",
    ['menu_mail'] = "Táviratok",
    ['menu_mail_desc'] = "Táviratok olvasása és küldése.",
    ['input_add_label'] = "Hozzáadandó összeg (jelenlegi egyenleg: $%s)",
    ['input_remove_label'] = "Kiveendő összeg (jelenlegi egyenleg: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Játékos meghívása",
    ['menu_add_guest_desc'] = "A közeledben lévő játékosok.",
    ['menu_current_guests'] = "Vendégek",
    ['menu_no_guests'] = "Nincsenek vendégek",
    ['menu_no_guests_desc'] = "Még senkit sem hívtál meg.",
    ['menu_guest_row'] = "Meghívva: %s. Válaszd ki a meghívás visszavonásához.",
    ['menu_invite'] = "Játékos meghívása",
    ['menu_invite_row'] = "ID %s. Válaszd ki a meghíváshoz.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Szoba menü",
    ['target_desk'] = "Recepció",
    ['target_room'] = "Szoba menü",

    -- page
    ['ui_subtitle'] = "Vendégszolgálat",
    ['ui_back'] = "Vissza",
    ['ui_close'] = "Bezárás",
    ['ui_cancel'] = "Mégse",
    ['ui_confirm'] = "Megerősítés",
    ['ui_amount'] = "Összeg",
    ['ui_max'] = "Max",
    ['ui_valid_amount'] = "Adj meg egy érvényes összeget",
    ['ui_success'] = "Siker",
    ['ui_error'] = "Hiba",
    ['ui_info'] = "Infó",
    ['ui_notice'] = "Figyelem",
}

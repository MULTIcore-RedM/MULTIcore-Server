Locales = Locales or {}
Locales['cs'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Jsi moc daleko od recepce.",
    ['not_enough_money'] = "Nemáš dost peněz.",
    ['bad_amount'] = "Zadej platnou částku.",
    ['not_owner'] = "To může udělat jen host, který si pokoj pronajal.",
    ['no_active_room'] = "Nejsi v hotelovém pokoji.",

    -- hotels
    ['hotel_valentine'] = "Hotel Valentine",
    ['hotel_strawberry'] = "Hotel Strawberry",
    ['hotel_rhodes'] = "Hotel Rhodes",
    ['hotel_stdenis'] = "Hotel Saint Denis",
    ['hotel_blackwater'] = "Hotel Blackwater",
    ['hotel_tumbleweed'] = "Hotel Tumbleweed",
    ['hotel_annesburg'] = "Hotel Annesburg",

    -- renting and checking in
    ['already_have_room'] = "V tomto hotelu už pokoj máš.",
    ['no_free_room'] = "Teď není volný žádný pokoj. Zkus to později.",
    ['rented'] = "Pronajal sis pokoj %s (%s).",
    ['no_room_here'] = "V tomto hotelu nemáš pokoj.",
    ['not_a_guest'] = "V tomto hotelu nejsi host.",
    ['guest_checked_in'] = "Ubytován jako host v pokoji %s.",
    ['room_lost'] = "Tvému pokoji %s došel kredit a byl uvolněn.",

    -- credit
    ['credit_too_high'] = "Pokoj může mít nejvýš $%s kreditu.",
    ['credit_added'] = "Přidáno $%s kreditu. Kredit teď: $%s.",
    ['cannot_withdraw'] = "Nemůžeš vybrat víc kreditu, než pokoj má.",
    ['credit_withdrawn'] = "Vybráno $%s kreditu. Kredit teď: $%s.",

    -- locker
    ['locker_label'] = "Skříňka pokoje %s",
    ['locker_failed'] = "Skříňku pokoje se nepodařilo otevřít.",

    -- guests
    ['player_not_found'] = "Hráč nebyl nalezen.",
    ['player_not_near'] = "Ten hráč není dost blízko.",
    ['nobody_near'] = "Nikdo není dost blízko, abys ho pozval.",
    ['already_guest'] = "Ten hráč už je host.",
    ['max_guests'] = "Pokoj už má nejvyšší povolený počet hostů (%s).",
    ['guest_added'] = "%s je teď hostem tvého pokoje.",
    ['guest_removed'] = "%s už není hostem tvého pokoje.",
    ['you_were_invited'] = "%s tě pozval do pokoje %s (%s).",
    ['you_were_removed'] = "Už nejsi hostem pokoje %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Počkej %s sekund, než znovu vyhodíš hosty.",
    ['no_guests_to_evict'] = "Nejsou tu žádní hosté k vyhození.",
    ['evicted'] = "Z tvého pokoje vyhozeno hostů: %s.",
    ['evicted_and_removed'] = "Vyhozeno a ze seznamu hostů odebráno hostů: %s.",
    ['you_were_evicted'] = "%s tě vyhodil z pokoje.",
    ['evict_confirm'] = "Tímto hned pošleš z pokoje hostů: %s. Pokračovat?",

    -- telegrams
    ['telegram_sender'] = "Hotelová recepce",
    ['tg_invite_subject'] = "Pozvánka do hotelového pokoje",
    ['tg_invite_body'] = "%s tě pozval do pokoje %s (%s). Na recepci se ubytuj jako host.",
    ['tg_evicted_subject'] = "Vyhození z hotelového pokoje",
    ['tg_evicted_body'] = "%s tě vyhodil z pokoje %s. Později se tam můžeš znovu ubytovat jako host.",
    ['tg_evicted_body_removed'] = "%s tě vyhodil z pokoje %s a vzal zpět tvou pozvánku.",
    ['tg_low_subject'] = "Kredit pokoje dochází",
    ['tg_low_body'] = "Kredit pokoje %s (%s) dochází: zbývá $%s. Kredit doplníš v nabídce pokoje.",
    ['tg_lost_subject'] = "Pokoj uvolněn",
    ['tg_lost_body'] = "Pokoji %s (%s) došel kredit, a proto jsi byl odhlášen. Děkujeme, že jsi u nás bydlel.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotelový pokoj pronajat",
    ['log_evicted'] = "Hosté vyhozeni z hotelu",
    ['log_lost'] = "Hotelový pokoj ztracen",

    -- desk menu
    ['menu_check_in'] = "Ubytovat se",
    ['menu_check_in_desc'] = "Jdi nahoru do pokoje %s. Kredit: $%s",
    ['menu_rent'] = "Pronajmout pokoj ($%s)",
    ['menu_rent_desc'] = "Peníze se stanou prvním kreditem tvého pokoje.",
    ['menu_guest_check_in'] = "Ubytovat se jako host",
    ['menu_guest_check_in_desc'] = "Jdi nahoru do pokoje, kam tě pozvali.",

    -- room menu
    ['room_title'] = "Pokoj %s",
    ['badge_guest'] = "Host",
    ['menu_add_credit'] = "Přidat kredit",
    ['menu_credit_now'] = "Kredit teď: $%s",
    ['menu_remove_credit'] = "Vybrat kredit",
    ['menu_remove_credit_desc'] = "Vezmi si peníze zpět z kreditu pokoje.",
    ['menu_guests'] = "Hosté",
    ['menu_guests_desc'] = "Pozvi hráče nebo vezmi pozvánku zpět.",
    ['menu_evict'] = "Vyhodit hosty",
    ['menu_evict_desc'] = "Hned pošli všechny hosty z pokoje.",
    ['menu_locker'] = "Skříňka pokoje",
    ['menu_locker_desc'] = "Ulož si své věci.",
    ['menu_guest_access'] = "Přístup hosta",
    ['menu_owner'] = "Pokoj: %s",
    ['menu_leave'] = "Opustit pokoj",
    ['menu_leave_desc'] = "Vrať se dolů na ulici.",
    ['menu_mail'] = "Telegramy",
    ['menu_mail_desc'] = "Čti a posílej telegramy.",
    ['input_add_label'] = "Částka k přidání (kredit teď: $%s)",
    ['input_remove_label'] = "Částka k výběru (kredit teď: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Pozvat hráče",
    ['menu_add_guest_desc'] = "Hráči blízko tebe.",
    ['menu_current_guests'] = "Hosté",
    ['menu_no_guests'] = "Žádní hosté",
    ['menu_no_guests_desc'] = "Zatím jsi nikoho nepozval.",
    ['menu_guest_row'] = "Pozván: %s. Vyber pro zrušení pozvánky.",
    ['menu_invite'] = "Pozvat hráče",
    ['menu_invite_row'] = "ID %s. Vyber pro pozvání.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Nabídka pokoje",
    ['target_desk'] = "Recepce",
    ['target_room'] = "Nabídka pokoje",

    -- page
    ['ui_subtitle'] = "Služby pro hosty",
    ['ui_back'] = "Zpět",
    ['ui_close'] = "Zavřít",
    ['ui_cancel'] = "Zrušit",
    ['ui_confirm'] = "Potvrdit",
    ['ui_amount'] = "Částka",
    ['ui_max'] = "Max",
    ['ui_valid_amount'] = "Zadej platnou částku",
    ['ui_success'] = "Hotovo",
    ['ui_error'] = "Chyba",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Upozornění",
}

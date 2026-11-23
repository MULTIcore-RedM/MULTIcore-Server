Locales = Locales or {}
Locales['it'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Sei troppo lontano dalla reception.",
    ['not_enough_money'] = "Non hai abbastanza soldi.",
    ['bad_amount'] = "Inserisci un importo valido.",
    ['not_owner'] = "Solo il cliente che ha affittato questa stanza può farlo.",
    ['no_active_room'] = "Non sei in una stanza d'hotel.",

    -- hotels
    ['hotel_valentine'] = "Hotel di Valentine",
    ['hotel_strawberry'] = "Hotel di Strawberry",
    ['hotel_rhodes'] = "Hotel di Rhodes",
    ['hotel_stdenis'] = "Hotel di Saint Denis",
    ['hotel_blackwater'] = "Hotel di Blackwater",
    ['hotel_tumbleweed'] = "Hotel di Tumbleweed",
    ['hotel_annesburg'] = "Hotel di Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Hai già una stanza in questo hotel.",
    ['no_free_room'] = "Al momento non ci sono stanze libere. Riprova più tardi.",
    ['rented'] = "Hai affittato la stanza %s all'%s.",
    ['no_room_here'] = "Non hai una stanza in questo hotel.",
    ['not_a_guest'] = "Non sei ospite in questo hotel.",
    ['guest_checked_in'] = "Check-in come ospite nella stanza %s.",
    ['room_lost'] = "La tua stanza %s ha esaurito il credito ed è stata lasciata.",

    -- credit
    ['credit_too_high'] = "Una stanza può contenere al massimo $%s di credito.",
    ['credit_added'] = "Aggiunti $%s di credito. Credito attuale: $%s.",
    ['cannot_withdraw'] = "Non puoi ritirare più credito di quanto ne abbia la stanza.",
    ['credit_withdrawn'] = "Ritirati $%s di credito. Credito attuale: $%s.",

    -- locker
    ['locker_label'] = "Armadietto stanza %s",
    ['locker_failed'] = "Impossibile aprire l'armadietto della stanza.",

    -- guests
    ['player_not_found'] = "Giocatore non trovato.",
    ['player_not_near'] = "Quel giocatore non è abbastanza vicino.",
    ['nobody_near'] = "Non c'è nessuno abbastanza vicino da invitare.",
    ['already_guest'] = "Quel giocatore è già ospite.",
    ['max_guests'] = "Questa stanza ha già il numero massimo di ospiti (%s).",
    ['guest_added'] = "%s ora è ospite della tua stanza.",
    ['guest_removed'] = "%s non è più ospite della tua stanza.",
    ['you_were_invited'] = "%s ti ha invitato nella stanza %s all'%s.",
    ['you_were_removed'] = "Non sei più ospite della stanza %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Aspetta %s secondi prima di cacciare di nuovo gli ospiti.",
    ['no_guests_to_evict'] = "Non ci sono ospiti da cacciare.",
    ['evicted'] = "%s ospite/i cacciato/i dalla tua stanza.",
    ['evicted_and_removed'] = "%s ospite/i cacciato/i e tolto/i dalla lista ospiti.",
    ['you_were_evicted'] = "%s ti ha cacciato dalla stanza.",
    ['evict_confirm'] = "Così %s ospite/i lasceranno subito la tua stanza. Procedere?",

    -- telegrams
    ['telegram_sender'] = "Reception dell'hotel",
    ['tg_invite_subject'] = "Invito in una stanza d'hotel",
    ['tg_invite_body'] = "%s ti ha invitato nella stanza %s all'%s. Chiedi alla reception per fare il check-in come ospite.",
    ['tg_evicted_subject'] = "Cacciato da una stanza d'hotel",
    ['tg_evicted_body'] = "%s ti ha cacciato dalla stanza %s. Puoi comunque fare il check-in come ospite più tardi.",
    ['tg_evicted_body_removed'] = "%s ti ha cacciato dalla stanza %s e ha ritirato il tuo invito.",
    ['tg_low_subject'] = "Credito della stanza in esaurimento",
    ['tg_low_body'] = "Il credito della stanza %s all'%s sta finendo: restano $%s. Aggiungi credito dal menu della stanza.",
    ['tg_lost_subject'] = "Stanza lasciata",
    ['tg_lost_body'] = "La stanza %s all'%s ha esaurito il credito, quindi è stato fatto il check-out. Grazie per aver soggiornato da noi.",

    -- logs (MULTIserver)
    ['log_rented'] = "Stanza d'hotel affittata",
    ['log_evicted'] = "Ospiti dell'hotel cacciati",
    ['log_lost'] = "Stanza d'hotel persa",

    -- desk menu
    ['menu_check_in'] = "Check-in",
    ['menu_check_in_desc'] = "Sali alla stanza %s. Credito: $%s",
    ['menu_rent'] = "Affitta una stanza ($%s)",
    ['menu_rent_desc'] = "I soldi diventano il primo credito della tua stanza.",
    ['menu_guest_check_in'] = "Check-in ospite",
    ['menu_guest_check_in_desc'] = "Sali alla stanza in cui sei stato invitato.",

    -- room menu
    ['room_title'] = "Stanza %s",
    ['badge_guest'] = "Ospite",
    ['menu_add_credit'] = "Aggiungi credito",
    ['menu_credit_now'] = "Credito attuale: $%s",
    ['menu_remove_credit'] = "Ritira credito",
    ['menu_remove_credit_desc'] = "Riprendi soldi dal credito della stanza.",
    ['menu_guests'] = "Ospiti",
    ['menu_guests_desc'] = "Invita giocatori o ritira un invito.",
    ['menu_evict'] = "Caccia gli ospiti",
    ['menu_evict_desc'] = "Manda subito fuori dalla stanza tutti gli ospiti.",
    ['menu_locker'] = "Armadietto della stanza",
    ['menu_locker_desc'] = "Riponi le tue cose.",
    ['menu_guest_access'] = "Accesso ospite",
    ['menu_owner'] = "Stanza di %s",
    ['menu_leave'] = "Lascia la stanza",
    ['menu_leave_desc'] = "Torna giù in strada.",
    ['menu_mail'] = "Telegrammi",
    ['menu_mail_desc'] = "Leggi e invia telegrammi.",
    ['input_add_label'] = "Importo da aggiungere (credito attuale: $%s)",
    ['input_remove_label'] = "Importo da ritirare (credito attuale: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Invita un giocatore",
    ['menu_add_guest_desc'] = "Giocatori vicino a te.",
    ['menu_current_guests'] = "Ospiti",
    ['menu_no_guests'] = "Nessun ospite",
    ['menu_no_guests_desc'] = "Non hai ancora invitato nessuno.",
    ['menu_guest_row'] = "%s invitato. Seleziona per ritirare l'invito.",
    ['menu_invite'] = "Invita un giocatore",
    ['menu_invite_row'] = "ID %s. Seleziona per invitare.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Menu della stanza",
    ['target_desk'] = "Reception",
    ['target_room'] = "Menu della stanza",

    -- page
    ['ui_subtitle'] = "Servizio clienti",
    ['ui_back'] = "Indietro",
    ['ui_close'] = "Chiudi",
    ['ui_cancel'] = "Annulla",
    ['ui_confirm'] = "Conferma",
    ['ui_amount'] = "Importo",
    ['ui_max'] = "Max",
    ['ui_valid_amount'] = "Inserisci un importo valido",
    ['ui_success'] = "Successo",
    ['ui_error'] = "Errore",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Avviso",
}

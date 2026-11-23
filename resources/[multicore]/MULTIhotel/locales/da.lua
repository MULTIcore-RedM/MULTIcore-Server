Locales = Locales or {}
Locales['da'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Du er for langt fra receptionen.",
    ['not_enough_money'] = "Du har ikke penge nok.",
    ['bad_amount'] = "Indtast et gyldigt beløb.",
    ['not_owner'] = "Kun gæsten, der lejede værelset, kan gøre det.",
    ['no_active_room'] = "Du er ikke på et hotelværelse.",

    -- hotels
    ['hotel_valentine'] = "Valentine Hotel",
    ['hotel_strawberry'] = "Strawberry Hotel",
    ['hotel_rhodes'] = "Rhodes Hotel",
    ['hotel_stdenis'] = "Saint Denis Hotel",
    ['hotel_blackwater'] = "Blackwater Hotel",
    ['hotel_tumbleweed'] = "Tumbleweed Hotel",
    ['hotel_annesburg'] = "Annesburg Hotel",

    -- renting and checking in
    ['already_have_room'] = "Du har allerede et værelse på dette hotel.",
    ['no_free_room'] = "Der er intet ledigt værelse lige nu. Prøv igen senere.",
    ['rented'] = "Du lejede værelse %s på %s.",
    ['no_room_here'] = "Du har intet værelse på dette hotel.",
    ['not_a_guest'] = "Du er ikke gæst på dette hotel.",
    ['guest_checked_in'] = "Tjekket ind som gæst på værelse %s.",
    ['room_lost'] = "Dit værelse %s løb tør for tilgodehavende og blev opgivet.",

    -- credit
    ['credit_too_high'] = "Et værelse kan højst have $%s til gode.",
    ['credit_added'] = "Tilføjede $%s til gode. Til gode nu: $%s.",
    ['cannot_withdraw'] = "Du kan ikke hæve mere, end værelset har til gode.",
    ['credit_withdrawn'] = "Hævede $%s. Til gode nu: $%s.",

    -- locker
    ['locker_label'] = "Skab på værelse %s",
    ['locker_failed'] = "Værelsets skab kunne ikke åbnes.",

    -- guests
    ['player_not_found'] = "Spilleren blev ikke fundet.",
    ['player_not_near'] = "Den spiller er ikke tæt nok på.",
    ['nobody_near'] = "Der er ingen tæt nok på at invitere.",
    ['already_guest'] = "Den spiller er allerede gæst.",
    ['max_guests'] = "Værelset har allerede så mange gæster, som det må have (%s).",
    ['guest_added'] = "%s er nu gæst på dit værelse.",
    ['guest_removed'] = "%s er ikke længere gæst på dit værelse.",
    ['you_were_invited'] = "%s inviterede dig til værelse %s på %s.",
    ['you_were_removed'] = "Du er ikke længere gæst på værelse %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Vent %s sekunder, før du smider gæster ud igen.",
    ['no_guests_to_evict'] = "Der er ingen gæster at smide ud.",
    ['evicted'] = "%s gæst(er) smidt ud af dit værelse.",
    ['evicted_and_removed'] = "%s gæst(er) smidt ud og fjernet fra gæstelisten.",
    ['you_were_evicted'] = "%s smed dig ud af værelset.",
    ['evict_confirm'] = "Dette sender straks %s gæst(er) ud af dit værelse. Fortsæt?",

    -- telegrams
    ['telegram_sender'] = "Hotellets reception",
    ['tg_invite_subject'] = "Invitation til hotelværelse",
    ['tg_invite_body'] = "%s inviterede dig til værelse %s på %s. Spørg i receptionen for at tjekke ind som gæst.",
    ['tg_evicted_subject'] = "Smidt ud af et hotelværelse",
    ['tg_evicted_body'] = "%s smed dig ud af værelse %s. Du kan stadig tjekke ind som gæst senere.",
    ['tg_evicted_body_removed'] = "%s smed dig ud af værelse %s og trak din invitation tilbage.",
    ['tg_low_subject'] = "Værelsets tilgodehavende er ved at slippe op",
    ['tg_low_body'] = "Tilgodehavendet for værelse %s på %s er ved at slippe op: $%s tilbage. Fyld op i værelsets menu.",
    ['tg_lost_subject'] = "Værelset opgivet",
    ['tg_lost_body'] = "Værelse %s på %s løb tør for tilgodehavende, så du er blevet tjekket ud. Tak fordi du boede hos os.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotelværelse lejet",
    ['log_evicted'] = "Hotelgæster smidt ud",
    ['log_lost'] = "Hotelværelse mistet",

    -- desk menu
    ['menu_check_in'] = "Tjek ind",
    ['menu_check_in_desc'] = "Gå op til værelse %s. Til gode: $%s",
    ['menu_rent'] = "Lej et værelse ($%s)",
    ['menu_rent_desc'] = "Pengene bliver dit værelses første tilgodehavende.",
    ['menu_guest_check_in'] = "Tjek ind som gæst",
    ['menu_guest_check_in_desc'] = "Gå op til det værelse, du blev inviteret til.",

    -- room menu
    ['room_title'] = "Værelse %s",
    ['badge_guest'] = "Gæst",
    ['menu_add_credit'] = "Fyld op",
    ['menu_credit_now'] = "Til gode nu: $%s",
    ['menu_remove_credit'] = "Hæv tilgodehavende",
    ['menu_remove_credit_desc'] = "Få penge tilbage fra værelsets tilgodehavende.",
    ['menu_guests'] = "Gæster",
    ['menu_guests_desc'] = "Inviter spillere eller træk en invitation tilbage.",
    ['menu_evict'] = "Smid gæster ud",
    ['menu_evict_desc'] = "Send straks alle gæster ud af værelset.",
    ['menu_locker'] = "Værelsets skab",
    ['menu_locker_desc'] = "Opbevar dine ting.",
    ['menu_guest_access'] = "Gæsteadgang",
    ['menu_owner'] = "Værelse tilhørende %s",
    ['menu_leave'] = "Forlad værelset",
    ['menu_leave_desc'] = "Gå ned på gaden igen.",
    ['menu_mail'] = "Telegrammer",
    ['menu_mail_desc'] = "Læs og send telegrammer.",
    ['input_add_label'] = "Beløb at fylde op (til gode nu: $%s)",
    ['input_remove_label'] = "Beløb at hæve (til gode nu: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Inviter en spiller",
    ['menu_add_guest_desc'] = "Spillere tæt på dig.",
    ['menu_current_guests'] = "Gæster",
    ['menu_no_guests'] = "Ingen gæster",
    ['menu_no_guests_desc'] = "Du har ikke inviteret nogen endnu.",
    ['menu_guest_row'] = "Inviteret: %s. Vælg for at trække invitationen tilbage.",
    ['menu_invite'] = "Inviter en spiller",
    ['menu_invite_row'] = "ID %s. Vælg for at invitere.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Værelsesmenu",
    ['target_desk'] = "Reception",
    ['target_room'] = "Værelsesmenu",

    -- page
    ['ui_subtitle'] = "Gæsteservice",
    ['ui_back'] = "Tilbage",
    ['ui_close'] = "Luk",
    ['ui_cancel'] = "Annuller",
    ['ui_confirm'] = "Bekræft",
    ['ui_amount'] = "Beløb",
    ['ui_max'] = "Maks",
    ['ui_valid_amount'] = "Indtast et gyldigt beløb",
    ['ui_success'] = "Udført",
    ['ui_error'] = "Fejl",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Besked",
}

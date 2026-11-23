Locales = Locales or {}
Locales['sv'] = {
    -- general
    ['notify_title'] = "Hotell",
    ['too_far'] = "Du är för långt från receptionen.",
    ['not_enough_money'] = "Du har inte tillräckligt med pengar.",
    ['bad_amount'] = "Ange ett giltigt belopp.",
    ['not_owner'] = "Bara gästen som hyrde rummet kan göra det.",
    ['no_active_room'] = "Du är inte i ett hotellrum.",

    -- hotels
    ['hotel_valentine'] = "Valentine Hotell",
    ['hotel_strawberry'] = "Strawberry Hotell",
    ['hotel_rhodes'] = "Rhodes Hotell",
    ['hotel_stdenis'] = "Saint Denis Hotell",
    ['hotel_blackwater'] = "Blackwater Hotell",
    ['hotel_tumbleweed'] = "Tumbleweed Hotell",
    ['hotel_annesburg'] = "Annesburg Hotell",

    -- renting and checking in
    ['already_have_room'] = "Du har redan ett rum på det här hotellet.",
    ['no_free_room'] = "Det finns inget ledigt rum just nu. Försök igen senare.",
    ['rented'] = "Du hyrde rum %s på %s.",
    ['no_room_here'] = "Du har inget rum på det här hotellet.",
    ['not_a_guest'] = "Du är inte gäst på det här hotellet.",
    ['guest_checked_in'] = "Incheckad som gäst i rum %s.",
    ['room_lost'] = "Ditt rum %s fick slut på tillgodo och lämnades.",

    -- credit
    ['credit_too_high'] = "Ett rum kan ha högst $%s tillgodo.",
    ['credit_added'] = "La till $%s i tillgodo. Tillgodo nu: $%s.",
    ['cannot_withdraw'] = "Du kan inte ta ut mer än rummet har tillgodo.",
    ['credit_withdrawn'] = "Tog ut $%s ur tillgodo. Tillgodo nu: $%s.",

    -- locker
    ['locker_label'] = "Skåp i rum %s",
    ['locker_failed'] = "Rummets skåp kunde inte öppnas.",

    -- guests
    ['player_not_found'] = "Spelaren hittades inte.",
    ['player_not_near'] = "Den spelaren är inte tillräckligt nära.",
    ['nobody_near'] = "Ingen är tillräckligt nära för att bjudas in.",
    ['already_guest'] = "Den spelaren är redan gäst.",
    ['max_guests'] = "Rummet har redan så många gäster som tillåts (%s).",
    ['guest_added'] = "%s är nu gäst i ditt rum.",
    ['guest_removed'] = "%s är inte längre gäst i ditt rum.",
    ['you_were_invited'] = "%s bjöd in dig till rum %s på %s.",
    ['you_were_removed'] = "Du är inte längre gäst i rum %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Vänta %s sekunder innan du kastar ut gäster igen.",
    ['no_guests_to_evict'] = "Det finns inga gäster att kasta ut.",
    ['evicted'] = "%s gäst(er) utkastade ur ditt rum.",
    ['evicted_and_removed'] = "%s gäst(er) utkastade och borttagna från gästlistan.",
    ['you_were_evicted'] = "%s kastade ut dig ur rummet.",
    ['evict_confirm'] = "Detta skickar genast ut %s gäst(er) ur ditt rum. Fortsätta?",

    -- telegrams
    ['telegram_sender'] = "Hotellreceptionen",
    ['tg_invite_subject'] = "Inbjudan till hotellrum",
    ['tg_invite_body'] = "%s bjöd in dig till rum %s på %s. Fråga i receptionen för att checka in som gäst.",
    ['tg_evicted_subject'] = "Utkastad ur ett hotellrum",
    ['tg_evicted_body'] = "%s kastade ut dig ur rum %s. Du kan fortfarande checka in som gäst senare.",
    ['tg_evicted_body_removed'] = "%s kastade ut dig ur rum %s och drog tillbaka din inbjudan.",
    ['tg_low_subject'] = "Rummets tillgodo håller på att ta slut",
    ['tg_low_body'] = "Tillgodo för rum %s på %s håller på att ta slut: $%s kvar. Fyll på i rummets meny.",
    ['tg_lost_subject'] = "Rummet lämnat",
    ['tg_lost_body'] = "Rum %s på %s fick slut på tillgodo, så du har checkats ut. Tack för att du bodde hos oss.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotellrum hyrt",
    ['log_evicted'] = "Hotellgäster utkastade",
    ['log_lost'] = "Hotellrum förlorat",

    -- desk menu
    ['menu_check_in'] = "Checka in",
    ['menu_check_in_desc'] = "Gå upp till rum %s. Tillgodo: $%s",
    ['menu_rent'] = "Hyr ett rum ($%s)",
    ['menu_rent_desc'] = "Pengarna blir ditt rums första tillgodo.",
    ['menu_guest_check_in'] = "Checka in som gäst",
    ['menu_guest_check_in_desc'] = "Gå upp till rummet du blev inbjuden till.",

    -- room menu
    ['room_title'] = "Rum %s",
    ['badge_guest'] = "Gäst",
    ['menu_add_credit'] = "Fyll på tillgodo",
    ['menu_credit_now'] = "Tillgodo nu: $%s",
    ['menu_remove_credit'] = "Ta ut tillgodo",
    ['menu_remove_credit_desc'] = "Få tillbaka pengar från rummets tillgodo.",
    ['menu_guests'] = "Gäster",
    ['menu_guests_desc'] = "Bjud in spelare eller dra tillbaka en inbjudan.",
    ['menu_evict'] = "Kasta ut gäster",
    ['menu_evict_desc'] = "Skicka genast ut alla gäster ur rummet.",
    ['menu_locker'] = "Rummets skåp",
    ['menu_locker_desc'] = "Förvara dina saker.",
    ['menu_guest_access'] = "Gäståtkomst",
    ['menu_owner'] = "Rummet tillhör %s",
    ['menu_leave'] = "Lämna rummet",
    ['menu_leave_desc'] = "Gå tillbaka ner till gatan.",
    ['menu_mail'] = "Telegram",
    ['menu_mail_desc'] = "Läs och skicka telegram.",
    ['input_add_label'] = "Belopp att fylla på (tillgodo nu: $%s)",
    ['input_remove_label'] = "Belopp att ta ut (tillgodo nu: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Bjud in en spelare",
    ['menu_add_guest_desc'] = "Spelare nära dig.",
    ['menu_current_guests'] = "Gäster",
    ['menu_no_guests'] = "Inga gäster",
    ['menu_no_guests_desc'] = "Du har inte bjudit in någon än.",
    ['menu_guest_row'] = "Inbjuden: %s. Välj för att dra tillbaka inbjudan.",
    ['menu_invite'] = "Bjud in en spelare",
    ['menu_invite_row'] = "ID %s. Välj för att bjuda in.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Rummets meny",
    ['target_desk'] = "Receptionen",
    ['target_room'] = "Rummets meny",

    -- page
    ['ui_subtitle'] = "Gästservice",
    ['ui_back'] = "Tillbaka",
    ['ui_close'] = "Stäng",
    ['ui_cancel'] = "Avbryt",
    ['ui_confirm'] = "Bekräfta",
    ['ui_amount'] = "Belopp",
    ['ui_max'] = "Max",
    ['ui_valid_amount'] = "Ange ett giltigt belopp",
    ['ui_success'] = "Klart",
    ['ui_error'] = "Fel",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Meddelande",
}

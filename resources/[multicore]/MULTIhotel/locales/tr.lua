Locales = Locales or {}
Locales['tr'] = {
    -- general
    ['notify_title'] = "Otel",
    ['too_far'] = "Resepsiyona çok uzaksın.",
    ['not_enough_money'] = "Yeterli paran yok.",
    ['bad_amount'] = "Geçerli bir miktar gir.",
    ['not_owner'] = "Bunu sadece bu odayı kiralayan misafir yapabilir.",
    ['no_active_room'] = "Bir otel odasında değilsin.",

    -- hotels
    ['hotel_valentine'] = "Valentine Oteli",
    ['hotel_strawberry'] = "Strawberry Oteli",
    ['hotel_rhodes'] = "Rhodes Oteli",
    ['hotel_stdenis'] = "Saint Denis Oteli",
    ['hotel_blackwater'] = "Blackwater Oteli",
    ['hotel_tumbleweed'] = "Tumbleweed Oteli",
    ['hotel_annesburg'] = "Annesburg Oteli",

    -- renting and checking in
    ['already_have_room'] = "Bu otelde zaten bir odan var.",
    ['no_free_room'] = "Şu an boş oda yok. Daha sonra tekrar dene.",
    ['rented'] = "%s numaralı odayı kiraladın (%s).",
    ['no_room_here'] = "Bu otelde odan yok.",
    ['not_a_guest'] = "Bu otelde misafir değilsin.",
    ['guest_checked_in'] = "%s numaralı odaya misafir olarak giriş yaptın.",
    ['room_lost'] = "%s numaralı odanın kredisi bitti ve oda bırakıldı.",

    -- credit
    ['credit_too_high'] = "Bir odada en fazla $%s kredi olabilir.",
    ['credit_added'] = "$%s kredi eklendi. Şu anki kredi: $%s.",
    ['cannot_withdraw'] = "Odada olandan fazla kredi çekemezsin.",
    ['credit_withdrawn'] = "$%s kredi çekildi. Şu anki kredi: $%s.",

    -- locker
    ['locker_label'] = "Oda %s dolabı",
    ['locker_failed'] = "Oda dolabı açılamadı.",

    -- guests
    ['player_not_found'] = "O oyuncu bulunamadı.",
    ['player_not_near'] = "O oyuncu yeterince yakın değil.",
    ['nobody_near'] = "Davet edilecek kadar yakında kimse yok.",
    ['already_guest'] = "O oyuncu zaten misafir.",
    ['max_guests'] = "Bu oda zaten en fazla misafir sayısına ulaştı (%s).",
    ['guest_added'] = "%s artık odanın misafiri.",
    ['guest_removed'] = "%s artık odanın misafiri değil.",
    ['you_were_invited'] = "%s seni %s numaralı odaya davet etti (%s).",
    ['you_were_removed'] = "Artık %s numaralı odanın misafiri değilsin.",

    -- throwing guests out
    ['evict_cooldown'] = "Misafirleri tekrar çıkarmadan önce %s saniye bekle.",
    ['no_guests_to_evict'] = "Çıkarılacak misafir yok.",
    ['evicted'] = "%s misafir odandan çıkarıldı.",
    ['evicted_and_removed'] = "%s misafir çıkarıldı ve misafir listesinden silindi.",
    ['you_were_evicted'] = "%s seni odadan çıkardı.",
    ['evict_confirm'] = "Bu, %s misafiri hemen odandan çıkarır. Devam edilsin mi?",

    -- telegrams
    ['telegram_sender'] = "Otel Resepsiyonu",
    ['tg_invite_subject'] = "Otel odası daveti",
    ['tg_invite_body'] = "%s seni %s numaralı odaya davet etti (%s). Misafir olarak giriş yapmak için resepsiyona sor.",
    ['tg_evicted_subject'] = "Otel odasından çıkarıldın",
    ['tg_evicted_body'] = "%s seni %s numaralı odadan çıkardı. Daha sonra yine misafir olarak giriş yapabilirsin.",
    ['tg_evicted_body_removed'] = "%s seni %s numaralı odadan çıkardı ve davetini geri aldı.",
    ['tg_low_subject'] = "Oda kredisi azalıyor",
    ['tg_low_body'] = "%s numaralı odanın kredisi azalıyor (%s): $%s kaldı. Oda menüsünden kredi ekle.",
    ['tg_lost_subject'] = "Oda bırakıldı",
    ['tg_lost_body'] = "%s numaralı odanın kredisi bitti (%s), bu yüzden çıkışın yapıldı. Bizi tercih ettiğin için teşekkürler.",

    -- logs (MULTIserver)
    ['log_rented'] = "Otel odası kiralandı",
    ['log_evicted'] = "Otel misafirleri çıkarıldı",
    ['log_lost'] = "Otel odası kaybedildi",

    -- desk menu
    ['menu_check_in'] = "Giriş yap",
    ['menu_check_in_desc'] = "%s numaralı odaya çık. Kredi: $%s",
    ['menu_rent'] = "Oda kirala ($%s)",
    ['menu_rent_desc'] = "Para, odanın ilk kredisi olur.",
    ['menu_guest_check_in'] = "Misafir girişi",
    ['menu_guest_check_in_desc'] = "Davet edildiğin odaya çık.",

    -- room menu
    ['room_title'] = "Oda %s",
    ['badge_guest'] = "Misafir",
    ['menu_add_credit'] = "Kredi ekle",
    ['menu_credit_now'] = "Şu anki kredi: $%s",
    ['menu_remove_credit'] = "Kredi çek",
    ['menu_remove_credit_desc'] = "Oda kredisinden paranı geri al.",
    ['menu_guests'] = "Misafirler",
    ['menu_guests_desc'] = "Oyuncu davet et veya bir daveti geri al.",
    ['menu_evict'] = "Misafirleri çıkar",
    ['menu_evict_desc'] = "Tüm misafirleri hemen odadan çıkar.",
    ['menu_locker'] = "Oda dolabı",
    ['menu_locker_desc'] = "Eşyalarını sakla.",
    ['menu_guest_access'] = "Misafir erişimi",
    ['menu_owner'] = "Oda sahibi: %s",
    ['menu_leave'] = "Odadan çık",
    ['menu_leave_desc'] = "Sokağa geri in.",
    ['menu_mail'] = "Telgraflar",
    ['menu_mail_desc'] = "Telgraf oku ve gönder.",
    ['input_add_label'] = "Eklenecek miktar (şu anki kredi: $%s)",
    ['input_remove_label'] = "Çekilecek miktar (şu anki kredi: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Oyuncu davet et",
    ['menu_add_guest_desc'] = "Yakınındaki oyuncular.",
    ['menu_current_guests'] = "Misafirler",
    ['menu_no_guests'] = "Misafir yok",
    ['menu_no_guests_desc'] = "Henüz kimseyi davet etmedin.",
    ['menu_guest_row'] = "Davetli: %s. Daveti geri almak için seç.",
    ['menu_invite'] = "Oyuncu davet et",
    ['menu_invite_row'] = "ID %s. Davet etmek için seç.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Oda menüsü",
    ['target_desk'] = "Resepsiyon",
    ['target_room'] = "Oda menüsü",

    -- page
    ['ui_subtitle'] = "Misafir Hizmetleri",
    ['ui_back'] = "Geri",
    ['ui_close'] = "Kapat",
    ['ui_cancel'] = "İptal",
    ['ui_confirm'] = "Onayla",
    ['ui_amount'] = "Miktar",
    ['ui_max'] = "Maks",
    ['ui_valid_amount'] = "Lütfen geçerli bir miktar gir",
    ['ui_success'] = "Başarılı",
    ['ui_error'] = "Hata",
    ['ui_info'] = "Bilgi",
    ['ui_notice'] = "Uyarı",
}

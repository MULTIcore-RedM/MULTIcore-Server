-- MULTIhelpers :: tr
Locales = Locales or {}
Locales['tr'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Onayla",
    ['cancel'] = "İptal",
    ['yes'] = "Evet",
    ['no'] = "Hayır",
    -- key hints under a menu
    ['key_move'] = "Hareket",
    ['key_change'] = "Değiştir",
    ['key_next'] = "Sonraki",
    ['key_select'] = "Seç",
    ['key_back'] = "Geri",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Backspace",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "İzin verilmiyor",
    ['err_letters'] = "Yalnızca harf",
    ['err_numbers'] = "Yalnızca rakam",
    ['err_alphanumeric'] = "Yalnızca harf ve rakam",
    ['err_no_symbols'] = "Sembol yok",
    ['err_username'] = "En az 3 harf, rakam, _ . veya -",
    ['err_phone'] = "Yalnızca rakam, boşluk ve + - ( )",
    ['err_email'] = "Geçerli bir e-posta değil",
    ['err_money'] = "Bir tutar, ör. 12.50",
    ['err_no_special'] = "Özel karakter yok",
    -- console lines for the server owner
    ['warn_running'] = "%s çalışıyor - server.cfg dosyasından \"ensure %s\" satırını kaldırın, MULTIhelpers onun yerini tutar.",
    ['warn_started'] = "%s, MULTIhelpers ile birlikte başlatıldı - server.cfg dosyasından \"ensure %s\" satırını kaldırın.",
    ['callback_error'] = "callback hatası: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "İşaretli alanda %s tuşuna bas",
    ['progress_busy'] = "Zaten bir şey yapıyorsun",
    ['progress_dead'] = "Ölüyken bunu yapamazsın",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Taş",
    ["mg_paper"] = "Kâğıt",
    ["mg_scissors"] = "Makas",
    ["mg_win"] = "Kazandın",
    ["mg_lose"] = "Kaybettin",
    ["mg_tie"] = "Berabere",
}

-- MULTIhelpers :: ar (same keys as the English master)
Locales = Locales or {}
Locales['ar'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "تأكيد",
    ['cancel'] = "إلغاء",
    ['yes'] = "نعم",
    ['no'] = "لا",
    -- key hints under a menu
    ['key_move'] = "تحرك",
    ['key_change'] = "تغيير",
    ['key_next'] = "التالي",
    ['key_select'] = "اختيار",
    ['key_back'] = "رجوع",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "غير مسموح",
    ['err_letters'] = "حروف فقط",
    ['err_numbers'] = "أرقام فقط",
    ['err_alphanumeric'] = "حروف وأرقام فقط",
    ['err_no_symbols'] = "بلا رموز",
    ['err_username'] = "3 على الأقل من الحروف أو الأرقام أو _ . -",
    ['err_phone'] = "أرقام ومسافات و+ - ( ) فقط",
    ['err_email'] = "ليس عنوان بريد إلكتروني",
    ['err_money'] = "مبلغ، مثل 12.50",
    ['err_no_special'] = "بلا رموز خاصة",
    -- console lines for the server owner
    ['warn_running'] = "%s يعمل - احذف \"ensure %s\" من server.cfg، فـ MULTIhelpers يحل محله.",
    ['warn_started'] = "%s بدأ بجانب MULTIhelpers - احذف \"ensure %s\" من server.cfg.",
    ['callback_error'] = "خطأ في callback: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "اضغط %s داخل المنطقة المحددة",
    ['progress_busy'] = "أنت تقوم بشيء بالفعل",
    ['progress_dead'] = "لا يمكنك فعل ذلك وأنت ميت",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "حجر",
    ["mg_paper"] = "ورقة",
    ["mg_scissors"] = "مقص",
    ["mg_win"] = "لقد فزت",
    ["mg_lose"] = "لقد خسرت",
    ["mg_tie"] = "تعادل",
}

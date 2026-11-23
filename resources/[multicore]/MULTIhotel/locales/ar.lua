Locales = Locales or {}
Locales['ar'] = {
    -- general
    ['notify_title'] = "الفندق",
    ['too_far'] = "أنت بعيد جدًا عن مكتب الاستقبال.",
    ['not_enough_money'] = "ليس لديك مال كافٍ.",
    ['bad_amount'] = "أدخل مبلغًا صالحًا.",
    ['not_owner'] = "لا يستطيع ذلك إلا النزيل الذي استأجر هذه الغرفة.",
    ['no_active_room'] = "أنت لست في غرفة فندق.",

    -- hotels
    ['hotel_valentine'] = "فندق Valentine",
    ['hotel_strawberry'] = "فندق Strawberry",
    ['hotel_rhodes'] = "فندق Rhodes",
    ['hotel_stdenis'] = "فندق Saint Denis",
    ['hotel_blackwater'] = "فندق Blackwater",
    ['hotel_tumbleweed'] = "فندق Tumbleweed",
    ['hotel_annesburg'] = "فندق Annesburg",

    -- renting and checking in
    ['already_have_room'] = "لديك غرفة في هذا الفندق بالفعل.",
    ['no_free_room'] = "لا توجد غرفة شاغرة الآن. حاول لاحقًا.",
    ['rented'] = "استأجرت الغرفة %s في %s.",
    ['no_room_here'] = "ليست لديك غرفة في هذا الفندق.",
    ['not_a_guest'] = "أنت لست ضيفًا في هذا الفندق.",
    ['guest_checked_in'] = "سجّلت دخولك ضيفًا في الغرفة %s.",
    ['room_lost'] = "نفد رصيد غرفتك %s فتم التخلي عنها.",

    -- credit
    ['credit_too_high'] = "تتسع الغرفة لرصيد أقصاه $%s.",
    ['credit_added'] = "أضفت $%s إلى الرصيد. الرصيد الآن: $%s.",
    ['cannot_withdraw'] = "لا يمكنك سحب رصيد أكثر مما في الغرفة.",
    ['credit_withdrawn'] = "سحبت $%s من الرصيد. الرصيد الآن: $%s.",

    -- locker
    ['locker_label'] = "خزانة الغرفة %s",
    ['locker_failed'] = "تعذّر فتح خزانة الغرفة.",

    -- guests
    ['player_not_found'] = "لم يُعثر على هذا اللاعب.",
    ['player_not_near'] = "هذا اللاعب ليس قريبًا بما يكفي.",
    ['nobody_near'] = "لا أحد قريب بما يكفي لدعوته.",
    ['already_guest'] = "هذا اللاعب ضيف بالفعل.",
    ['max_guests'] = "بلغت هذه الغرفة الحد الأقصى من الضيوف (%s).",
    ['guest_added'] = "أصبح %s ضيفًا في غرفتك.",
    ['guest_removed'] = "لم يعد %s ضيفًا في غرفتك.",
    ['you_were_invited'] = "دعاك %s إلى الغرفة %s في %s.",
    ['you_were_removed'] = "لم تعد ضيفًا في الغرفة %s.",

    -- throwing guests out
    ['evict_cooldown'] = "انتظر %s ثانية قبل طرد الضيوف مرة أخرى.",
    ['no_guests_to_evict'] = "لا يوجد ضيوف لطردهم.",
    ['evicted'] = "طُرد %s ضيف من غرفتك.",
    ['evicted_and_removed'] = "طُرد %s ضيف وأُزيلوا من قائمة الضيوف.",
    ['you_were_evicted'] = "طردك %s من الغرفة.",
    ['evict_confirm'] = "سيُخرج هذا %s ضيف من غرفتك فورًا. هل تتابع؟",

    -- telegrams
    ['telegram_sender'] = "استقبال الفندق",
    ['tg_invite_subject'] = "دعوة إلى غرفة فندق",
    ['tg_invite_body'] = "دعاك %s إلى الغرفة %s في %s. اطلب من مكتب الاستقبال تسجيل دخولك ضيفًا.",
    ['tg_evicted_subject'] = "طُردت من غرفة فندق",
    ['tg_evicted_body'] = "طردك %s من الغرفة %s. لا يزال بإمكانك تسجيل الدخول ضيفًا لاحقًا.",
    ['tg_evicted_body_removed'] = "طردك %s من الغرفة %s وسحب دعوتك.",
    ['tg_low_subject'] = "رصيد الغرفة يوشك على النفاد",
    ['tg_low_body'] = "رصيد الغرفة %s في %s يوشك على النفاد: تبقّى $%s. أضف رصيدًا من قائمة الغرفة.",
    ['tg_lost_subject'] = "تم التخلي عن الغرفة",
    ['tg_lost_body'] = "نفد رصيد الغرفة %s في %s، لذا تم تسجيل خروجك. شكرًا لإقامتك معنا.",

    -- logs (MULTIserver)
    ['log_rented'] = "استئجار غرفة فندق",
    ['log_evicted'] = "طرد ضيوف من الفندق",
    ['log_lost'] = "خسارة غرفة فندق",

    -- desk menu
    ['menu_check_in'] = "تسجيل الدخول",
    ['menu_check_in_desc'] = "اصعد إلى الغرفة %s. الرصيد: $%s",
    ['menu_rent'] = "استئجار غرفة ($%s)",
    ['menu_rent_desc'] = "يصبح المال أول رصيد لغرفتك.",
    ['menu_guest_check_in'] = "دخول الضيف",
    ['menu_guest_check_in_desc'] = "اصعد إلى الغرفة التي دُعيت إليها.",

    -- room menu
    ['room_title'] = "الغرفة %s",
    ['badge_guest'] = "ضيف",
    ['menu_add_credit'] = "إضافة رصيد",
    ['menu_credit_now'] = "الرصيد الآن: $%s",
    ['menu_remove_credit'] = "سحب رصيد",
    ['menu_remove_credit_desc'] = "استرد مالًا من رصيد الغرفة.",
    ['menu_guests'] = "الضيوف",
    ['menu_guests_desc'] = "ادعُ لاعبين أو اسحب دعوة.",
    ['menu_evict'] = "طرد الضيوف",
    ['menu_evict_desc'] = "أخرج كل الضيوف من الغرفة فورًا.",
    ['menu_locker'] = "خزانة الغرفة",
    ['menu_locker_desc'] = "خزّن أغراضك.",
    ['menu_guest_access'] = "دخول الضيف",
    ['menu_owner'] = "غرفة %s",
    ['menu_leave'] = "مغادرة الغرفة",
    ['menu_leave_desc'] = "انزل إلى الشارع.",
    ['menu_mail'] = "البرقيات",
    ['menu_mail_desc'] = "اقرأ البرقيات وأرسلها.",
    ['input_add_label'] = "المبلغ المضاف (الرصيد الآن: $%s)",
    ['input_remove_label'] = "المبلغ المسحوب (الرصيد الآن: $%s)",

    -- guest menu
    ['menu_add_guest'] = "دعوة لاعب",
    ['menu_add_guest_desc'] = "اللاعبون القريبون منك.",
    ['menu_current_guests'] = "الضيوف",
    ['menu_no_guests'] = "لا ضيوف",
    ['menu_no_guests_desc'] = "لم تدعُ أحدًا بعد.",
    ['menu_guest_row'] = "مدعو: %s. اختر لسحب الدعوة.",
    ['menu_invite'] = "دعوة لاعب",
    ['menu_invite_row'] = "المعرّف %s. اختر للدعوة.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "قائمة الغرفة",
    ['target_desk'] = "مكتب الاستقبال",
    ['target_room'] = "قائمة الغرفة",

    -- page
    ['ui_subtitle'] = "خدمات الضيوف",
    ['ui_back'] = "رجوع",
    ['ui_close'] = "إغلاق",
    ['ui_cancel'] = "إلغاء",
    ['ui_confirm'] = "تأكيد",
    ['ui_amount'] = "المبلغ",
    ['ui_max'] = "الأقصى",
    ['ui_valid_amount'] = "يرجى إدخال مبلغ صالح",
    ['ui_success'] = "تم",
    ['ui_error'] = "خطأ",
    ['ui_info'] = "معلومة",
    ['ui_notice'] = "تنبيه",
}

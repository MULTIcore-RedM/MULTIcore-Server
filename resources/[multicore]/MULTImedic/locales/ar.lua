-- MULTImedic: Arabic (same keys as the English master file)
Locales = Locales or {}
Locales['ar'] = {
    -- death screen (NUI)
    ['ui_title'] = 'أنت فاقد الوعي',
    ['ui_sub'] = 'انتظر طبيبًا، أو حتى تعود إليك قوتك',
    ['ui_sub_ready'] = 'يمكنك النهوض على قدميك',
    ['ui_wait'] = 'يمكنك النهوض بعد',
    ['ui_hold_respawn'] = 'اضغط مطولًا للنهوض عند الطبيب',
    ['ui_fee'] = "أجرة الطبيب: $%s",
    ['ui_call'] = 'اطلب طبيبًا',
    ['ui_call_sending'] = 'جارٍ إرسال الخبر...',
    ['ui_call_sent'] = 'أُرسل في طلب طبيب',
    ['ui_call_none'] = 'لم يجب أي طبيب',
    ['ui_call_wait'] = 'طلبت قبل لحظات',
    ['ui_call_failed'] = 'تعذّر إرسال الطلب',
    ['ui_call_again'] = 'اطلب مجددًا بعد %ss',
    ['ui_medics'] = 'الأطباء في المنطقة: %s',
    ['ui_no_medics'] = 'لا طبيب في المناوبة',

    -- respawn
    ['too_early'] = 'لست قويًا بما يكفي للنهوض بعد.',
    ['respawned'] = 'أفقت عند %s.',
    ['respawned_fee'] = 'أفقت عند %s. تقاضى الطبيب $%s.',
    ['lost_cash'] = 'ضاعت نقودك.',
    ['lost_bloodmoney'] = 'ضاع مال الدم الذي معك.',

    -- doctor calls
    ['alert_text'] = '%s سقط ويحتاج إلى طبيب',
    ['alert_default'] = 'شخص ما يحتاج إلى طبيب',
    ['doctor_called'] = 'أُرسل الخبر إلى الأطباء.',
    ['no_medics'] = 'لا طبيب في المناوبة الآن.',
    ['call_cooldown'] = 'أرسلت طلبًا للتو. انتظر قليلًا.',

    -- medic actions
    ['reviving'] = 'جارٍ الإنعاش...',
    ['treating'] = 'جارٍ علاج الجروح...',
    ['target_revive'] = 'إنعاش',
    ['target_treat'] = 'علاج الجروح',
    ['not_medic'] = 'أنت لست طبيبًا في المناوبة.',
    ['no_player'] = 'لا لاعب هناك.',
    ['nobody_down'] = 'لا أحد قربك ساقط.',
    ['not_down'] = 'هذا الشخص ليس فاقدًا للوعي.',
    ['is_down'] = 'هذا الشخص فاقد للوعي؛ أنعشه أولًا.',
    ['too_far'] = 'أنت بعيد جدًا.',
    ['you_revived'] = 'أنعشت %s.',
    ['revived_by'] = '%s أعادك إلى الوعي.',
    ['you_treated'] = "عالجت جروح %s.",
    ['treated_by'] = '%s عالج جروحك.',

    -- injuries
    ['injury_worse'] = 'حالة %s لديك: %s.',
    ['injury_better'] = 'تحسّن أحد جروحك.',
    ['no_injuries'] = 'ليس لديك جروح لعلاجها.',
    ["need_item"] = "تحتاج إلى %s.",
    ["cannot_now"] = "لا يمكنك فعل ذلك الآن.",
    ["bandaging"] = "جارٍ التضميد...",
    ["bandaged"] = "ضمّدت جروحك.",
    ["lost_items"] = "ضاع كل ما كنت تحمله.",
    ['bleeding'] = 'أنت تنزف.',
    ['part_head'] = 'الرأس',
    ['part_torso'] = 'الصدر',
    ['part_left_arm'] = 'الذراع اليسرى',
    ['part_right_arm'] = 'الذراع اليمنى',
    ['part_left_leg'] = 'الساق اليسرى',
    ['part_right_leg'] = 'الساق اليمنى',
    ['state_healthy'] = 'سليم',
    ['state_injured'] = 'مصاب',
    ['state_broken'] = 'مكسور',
    ['state_bleeding'] = 'ينزف',

    -- hospitals
    ['place_valentine'] = 'طبيب Valentine',
    ['place_blackwater'] = 'طبيب Blackwater',
    ['place_strawberry'] = 'طبيب Strawberry',
    ['place_armadillo'] = 'طبيب Armadillo',
    ['place_tumbleweed'] = 'طبيب Tumbleweed',
    ['place_saintdenis'] = 'طبيب Saint Denis',
    ['place_rhodes'] = 'طبيب Rhodes',
    ['place_vanhorn'] = 'طبيب Van Horn',
    ['place_annesburg'] = 'طبيب Annesburg',

    -- commands
    ['cmd_revive'] = 'أنعش نفسك أو لاعبًا (مشرف)',
    ['cmd_heal'] = 'عالج نفسك أو لاعبًا (مشرف)',
    ['cmd_kill'] = 'اقتل لاعبًا (مشرف)',
    ['cmd_id'] = 'رقم اللاعب',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) مات',
    ['log_text'] = '%s قُتل على يد %s (السبب %s)',
    ['log_unknown'] = 'غير معروف',
}

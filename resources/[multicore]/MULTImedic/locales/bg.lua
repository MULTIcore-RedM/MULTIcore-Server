-- MULTImedic: Български
Locales = Locales or {}
Locales['bg'] = {
    -- death screen (NUI)
    ['ui_title'] = 'В безсъзнание сте',
    ['ui_sub'] = 'Чакайте лекар или силите ви да се върнат',
    ['ui_sub_ready'] = 'Можете да се изправите',
    ['ui_wait'] = 'Можете да се съживите след',
    ['ui_hold_respawn'] = 'Задръжте, за да се събудите при лекаря',
    ['ui_fee'] = "Такса за лекаря: $%s",
    ['ui_call'] = 'Повикай лекар',
    ['ui_call_sending'] = 'Изпращаме вест...',
    ['ui_call_sent'] = 'Пратено е за лекар',
    ['ui_call_none'] = 'Никой лекар не отговори',
    ['ui_call_wait'] = 'Току-що повикахте',
    ['ui_call_failed'] = 'Повикването не можа да се изпрати',
    ['ui_call_again'] = 'отново след %sс',
    ['ui_medics'] = 'Лекари в областта: %s',
    ['ui_no_medics'] = 'Няма лекар на смяна',

    -- respawn
    ['too_early'] = 'Още не сте достатъчно силни да станете.',
    ['respawned'] = 'Свестихте се при %s.',
    ['respawned_fee'] = 'Свестихте се при %s. Лекарят взе $%s.',
    ['lost_cash'] = 'Парите ви ги няма.',
    ['lost_bloodmoney'] = 'Кървавите ви пари ги няма.',

    -- doctor calls
    ['alert_text'] = '%s е на земята и има нужда от лекар',
    ['alert_default'] = 'Някой има нужда от лекар',
    ['doctor_called'] = 'Вестта е изпратена до лекарите.',
    ['no_medics'] = 'В момента няма лекар на смяна.',
    ['call_cooldown'] = 'Току-що изпратихте повикване. Изчакайте малко.',

    -- medic actions
    ['reviving'] = 'Свестявате...',
    ['treating'] = 'Лекувате рани...',
    ['target_revive'] = 'Свести',
    ['target_treat'] = 'Лекувай рани',
    ['not_medic'] = 'Не сте лекар на смяна.',
    ['no_player'] = 'Там няма играч.',
    ['nobody_down'] = 'Никой наблизо не е на земята.',
    ['not_down'] = 'Този човек не е в безсъзнание.',
    ['is_down'] = 'Този човек е в безсъзнание; първо го свестете.',
    ['too_far'] = 'Твърде далеч сте.',
    ['you_revived'] = 'Свестихте %s.',
    ['revived_by'] = '%s ви свести.',
    ['you_treated'] = "Излекувахте раните на %s.",
    ['treated_by'] = '%s излекува раните ви.',

    -- injuries
    ['injury_worse'] = 'Състояние: %s — %s.',
    ['injury_better'] = 'Една от раните ви е по-добре.',
    ['no_injuries'] = 'Нямате рани за лекуване.',
    ["need_item"] = "Нужен ви е %s.",
    ["cannot_now"] = "Не можете да направите това сега.",
    ["bandaging"] = "Превързвате...",
    ["bandaged"] = "Закърпихте се.",
    ["lost_items"] = "Всичко, което носехте, го няма.",
    ['bleeding'] = 'Кървите.',
    ['part_head'] = 'глава',
    ['part_torso'] = 'гърди',
    ['part_left_arm'] = 'лява ръка',
    ['part_right_arm'] = 'дясна ръка',
    ['part_left_leg'] = 'ляв крак',
    ['part_right_leg'] = 'десен крак',
    ['state_healthy'] = 'здраво',
    ['state_injured'] = 'ранено',
    ['state_broken'] = 'счупено',
    ['state_bleeding'] = 'кърви',

    -- hospitals
    ['place_valentine'] = 'лекаря във Valentine',
    ['place_blackwater'] = 'лекаря в Blackwater',
    ['place_strawberry'] = 'лекаря в Strawberry',
    ['place_armadillo'] = 'лекаря в Armadillo',
    ['place_tumbleweed'] = 'лекаря в Tumbleweed',
    ['place_saintdenis'] = 'лекаря в Saint Denis',
    ['place_rhodes'] = 'лекаря в Rhodes',
    ['place_vanhorn'] = 'лекаря във Van Horn',
    ['place_annesburg'] = 'лекаря в Annesburg',

    -- commands
    ['cmd_revive'] = 'Свести себе си или играч (админ)',
    ['cmd_heal'] = 'Излекувай себе си или играч (админ)',
    ['cmd_kill'] = 'Убий играч (админ)',
    ['cmd_id'] = 'ID на играча',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) загина',
    ['log_text'] = '%s беше убит от %s (причина %s)',
    ['log_unknown'] = 'неизвестно',
}

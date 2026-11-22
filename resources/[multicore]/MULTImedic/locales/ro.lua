-- MULTImedic: Română
Locales = Locales or {}
Locales['ro'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Ești inconștient',
    ['ui_sub'] = 'Așteaptă un doctor sau să-ți revină puterile',
    ['ui_sub_ready'] = 'Te poți ridica din nou',
    ['ui_wait'] = 'Poți reapărea în',
    ['ui_hold_respawn'] = 'Ține apăsat ca să reapari la doctor',
    ['ui_fee'] = "Taxa doctorului: $%s",
    ['ui_call'] = 'Cheamă un doctor',
    ['ui_call_sending'] = 'Se trimite vorbă...',
    ['ui_call_sent'] = 'S-a trimis după un doctor',
    ['ui_call_none'] = 'Niciun doctor n-a răspuns',
    ['ui_call_wait'] = 'Ai chemat adineauri',
    ['ui_call_failed'] = 'Chemarea nu a putut fi trimisă',
    ['ui_call_again'] = 'cheamă iar în %ss',
    ['ui_medics'] = 'Doctori în teritoriu: %s',
    ['ui_no_medics'] = 'Niciun doctor de serviciu',

    -- respawn
    ['too_early'] = 'Încă nu ești destul de puternic să te ridici.',
    ['respawned'] = 'Ți-ai revenit la %s.',
    ['respawned_fee'] = 'Ți-ai revenit la %s. Doctorul a cerut $%s.',
    ['lost_cash'] = 'Banii tăi s-au dus.',
    ['lost_bloodmoney'] = 'Banii pătați de sânge s-au dus.',

    -- doctor calls
    ['alert_text'] = '%s e la pământ și are nevoie de un doctor',
    ['alert_default'] = 'Cineva are nevoie de un doctor',
    ['doctor_called'] = 'Doctorii au fost anunțați.',
    ['no_medics'] = 'Niciun doctor nu e de serviciu acum.',
    ['call_cooldown'] = 'Abia ai trimis o chemare. Așteaptă puțin.',

    -- medic actions
    ['reviving'] = 'Readuci la viață...',
    ['treating'] = 'Tratezi rănile...',
    ['target_revive'] = 'Readu la viață',
    ['target_treat'] = 'Tratează rănile',
    ['not_medic'] = 'Nu ești doctor de serviciu.',
    ['no_player'] = 'Niciun jucător acolo.',
    ['nobody_down'] = 'Nimeni de lângă tine nu e la pământ.',
    ['not_down'] = 'Persoana nu e inconștientă.',
    ['is_down'] = 'Persoana e inconștientă; readu-o întâi la viață.',
    ['too_far'] = 'Ești prea departe.',
    ['you_revived'] = 'L-ai readus la viață pe %s.',
    ['revived_by'] = '%s te-a readus la viață.',
    ['you_treated'] = "I-ai tratat rănile lui %s.",
    ['treated_by'] = '%s ți-a tratat rănile.',

    -- injuries
    ['injury_worse'] = '%s: %s.',
    ['injury_better'] = 'Una din răni arată mai bine.',
    ['no_injuries'] = 'Nu ai răni de tratat.',
    ["need_item"] = "Ai nevoie de: %s.",
    ["cannot_now"] = "Nu poți face asta acum.",
    ["bandaging"] = "Bandajezi...",
    ["bandaged"] = "Te-ai pansat.",
    ["lost_items"] = "Tot ce aveai la tine s-a dus.",
    ['bleeding'] = 'Sângerezi.',
    ['part_head'] = 'capul',
    ['part_torso'] = 'pieptul',
    ['part_left_arm'] = 'brațul stâng',
    ['part_right_arm'] = 'brațul drept',
    ['part_left_leg'] = 'piciorul stâng',
    ['part_right_leg'] = 'piciorul drept',
    ['state_healthy'] = 'sănătos',
    ['state_injured'] = 'rănit',
    ['state_broken'] = 'rupt',
    ['state_bleeding'] = 'sângerează',

    -- hospitals
    ['place_valentine'] = 'doctorul din Valentine',
    ['place_blackwater'] = 'doctorul din Blackwater',
    ['place_strawberry'] = 'doctorul din Strawberry',
    ['place_armadillo'] = 'doctorul din Armadillo',
    ['place_tumbleweed'] = 'doctorul din Tumbleweed',
    ['place_saintdenis'] = 'doctorul din Saint Denis',
    ['place_rhodes'] = 'doctorul din Rhodes',
    ['place_vanhorn'] = 'doctorul din Van Horn',
    ['place_annesburg'] = 'doctorul din Annesburg',

    -- commands
    ['cmd_revive'] = 'Readu la viață pe tine sau un jucător (admin)',
    ['cmd_heal'] = 'Vindecă-te pe tine sau un jucător (admin)',
    ['cmd_kill'] = 'Omoară un jucător (admin)',
    ['cmd_id'] = 'ID jucător',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) a murit',
    ['log_text'] = '%s a fost ucis de %s (cauza %s)',
    ['log_unknown'] = 'necunoscut',
}

-- MULTImedic: Magyar
Locales = Locales or {}
Locales['hu'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Eszméletlen vagy',
    ['ui_sub'] = 'Várj egy orvosra, vagy amíg visszatér az erőd',
    ['ui_sub_ready'] = 'Újra lábra állhatsz',
    ['ui_wait'] = 'Újraéledés ennyi idő múlva',
    ['ui_hold_respawn'] = 'Tartsd lenyomva az orvosnál éledéshez',
    ['ui_fee'] = "Orvosi díj: $%s",
    ['ui_call'] = 'Orvos hívása',
    ['ui_call_sending'] = 'Üzenet küldése...',
    ['ui_call_sent'] = 'Orvosért küldtek',
    ['ui_call_none'] = 'Egy orvos sem válaszolt',
    ['ui_call_wait'] = 'Az előbb már hívtál',
    ['ui_call_failed'] = 'A hívást nem sikerült elküldeni',
    ['ui_call_again'] = 'újra hívhatsz %smp múlva',
    ['ui_medics'] = 'Orvosok a területen: %s',
    ['ui_no_medics'] = 'Nincs szolgálatban orvos',

    -- respawn
    ['too_early'] = 'Még nem vagy elég erős, hogy felállj.',
    ['respawned'] = 'Magadhoz tértél: %s.',
    ['respawned_fee'] = 'Magadhoz tértél: %s. Az orvos $%s-t kért.',
    ['lost_cash'] = 'Elveszett a készpénzed.',
    ['lost_bloodmoney'] = 'Elveszett a vérdíjad.',

    -- doctor calls
    ['alert_text'] = '%s a földön fekszik, orvos kell neki',
    ['alert_default'] = 'Valakinek orvos kell',
    ['doctor_called'] = 'Üzentek az orvosoknak.',
    ['no_medics'] = 'Most nincs szolgálatban orvos.',
    ['call_cooldown'] = 'Épp most hívtál. Várj egy kicsit.',

    -- medic actions
    ['reviving'] = 'Élesztés...',
    ['treating'] = 'Sebek ellátása...',
    ['target_revive'] = 'Élesztés',
    ['target_treat'] = 'Sebek ellátása',
    ['not_medic'] = 'Nem vagy szolgálatban lévő orvos.',
    ['no_player'] = 'Nincs ott játékos.',
    ['nobody_down'] = 'A közeledben senki sem fekszik a földön.',
    ['not_down'] = 'Ez a személy nem eszméletlen.',
    ['is_down'] = 'Ez a személy eszméletlen; előbb éleszd fel.',
    ['too_far'] = 'Túl messze vagy.',
    ['you_revived'] = 'Felélesztetted: %s.',
    ['revived_by'] = '%s visszahozott.',
    ['you_treated'] = "Ellátod %s sebeit.",
    ['treated_by'] = '%s ellátta a sebeidet.',

    -- injuries
    ['injury_worse'] = 'Sérülés (%s): %s.',
    ['injury_better'] = 'Az egyik sebed jobban van.',
    ['no_injuries'] = 'Nincs ellátandó sebed.',
    ["need_item"] = "Kell hozzá: %s.",
    ["cannot_now"] = "Ezt most nem teheted meg.",
    ["bandaging"] = "Kötözés...",
    ["bandaged"] = "Bekötözted magad.",
    ["lost_items"] = "Mindened elveszett, amit vittél.",
    ['bleeding'] = 'Vérzel.',
    ['part_head'] = 'fej',
    ['part_torso'] = 'mellkas',
    ['part_left_arm'] = 'bal kar',
    ['part_right_arm'] = 'jobb kar',
    ['part_left_leg'] = 'bal láb',
    ['part_right_leg'] = 'jobb láb',
    ['state_healthy'] = 'ép',
    ['state_injured'] = 'sérült',
    ['state_broken'] = 'törött',
    ['state_bleeding'] = 'vérzik',

    -- hospitals
    ['place_valentine'] = 'Valentine orvosa',
    ['place_blackwater'] = 'Blackwater orvosa',
    ['place_strawberry'] = 'Strawberry orvosa',
    ['place_armadillo'] = 'Armadillo orvosa',
    ['place_tumbleweed'] = 'Tumbleweed orvosa',
    ['place_saintdenis'] = 'Saint Denis orvosa',
    ['place_rhodes'] = 'Rhodes orvosa',
    ['place_vanhorn'] = 'Van Horn orvosa',
    ['place_annesburg'] = 'Annesburg orvosa',

    -- commands
    ['cmd_revive'] = 'Magad vagy egy játékos élesztése (admin)',
    ['cmd_heal'] = 'Magad vagy egy játékos gyógyítása (admin)',
    ['cmd_kill'] = 'Játékos megölése (admin)',
    ['cmd_id'] = 'Játékos azonosító',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) meghalt',
    ['log_text'] = '%s halálát okozta: %s (ok: %s)',
    ['log_unknown'] = 'ismeretlen',
}

-- MULTImedic: Suomi
Locales = Locales or {}
Locales['fi'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Olet tajuton',
    ['ui_sub'] = 'Odota lääkäriä tai että voimasi palaavat',
    ['ui_sub_ready'] = 'Voit nousta taas jaloillesi',
    ['ui_wait'] = 'Voit herätä uudelleen',
    ['ui_hold_respawn'] = 'Pidä pohjassa herätäksesi lääkärillä',
    ['ui_fee'] = "Lääkärin palkkio: $%s",
    ['ui_call'] = 'Kutsu lääkäri',
    ['ui_call_sending'] = 'Lähetetään sanaa...',
    ['ui_call_sent'] = 'Lääkäriä on lähetetty hakemaan',
    ['ui_call_none'] = 'Yksikään lääkäri ei vastannut',
    ['ui_call_wait'] = 'Kutsuit juuri äsken',
    ['ui_call_failed'] = 'Kutsua ei voitu lähettää',
    ['ui_call_again'] = 'kutsu uudelleen %ss kuluttua',
    ['ui_medics'] = 'Lääkäreitä alueella: %s',
    ['ui_no_medics'] = 'Yksikään lääkäri ei ole päivystyksessä',

    -- respawn
    ['too_early'] = 'Et ole vielä tarpeeksi vahva noustaksesi.',
    ['respawned'] = 'Heräsit: %s.',
    ['respawned_fee'] = 'Heräsit: %s. Lääkäri veloitti $%s.',
    ['lost_cash'] = 'Käteisesi on poissa.',
    ['lost_bloodmoney'] = 'Veriraha on poissa.',

    -- doctor calls
    ['alert_text'] = '%s on maassa ja tarvitsee lääkäriä',
    ['alert_default'] = 'Joku tarvitsee lääkäriä',
    ['doctor_called'] = 'Lääkäreille on lähetetty sana.',
    ['no_medics'] = 'Yksikään lääkäri ei ole nyt päivystyksessä.',
    ['call_cooldown'] = 'Lähetit juuri kutsun. Odota hetki.',

    -- medic actions
    ['reviving'] = 'Elvytetään...',
    ['treating'] = 'Hoidetaan haavoja...',
    ['target_revive'] = 'Elvytä',
    ['target_treat'] = 'Hoida haavat',
    ['not_medic'] = 'Et ole päivystävä lääkäri.',
    ['no_player'] = 'Siellä ei ole pelaajaa.',
    ['nobody_down'] = 'Kukaan lähelläsi ei ole maassa.',
    ['not_down'] = 'Henkilö ei ole tajuton.',
    ['is_down'] = 'Henkilö on tajuton; elvytä hänet ensin.',
    ['too_far'] = 'Olet liian kaukana.',
    ['you_revived'] = 'Elvytit: %s.',
    ['revived_by'] = '%s toi sinut takaisin.',
    ['you_treated'] = "Hoidit haavat: %s.",
    ['treated_by'] = '%s hoiti haavasi.',

    -- injuries
    ['injury_worse'] = 'Vamma: %s (%s).',
    ['injury_better'] = 'Yksi haavoistasi on parempi.',
    ['no_injuries'] = 'Sinulla ei ole hoidettavia haavoja.',
    ["need_item"] = "Tarvitset: %s.",
    ["cannot_now"] = "Et voi tehdä sitä juuri nyt.",
    ["bandaging"] = "Sidotaan...",
    ["bandaged"] = "Paikkasit itsesi.",
    ["lost_items"] = "Kaikki, mitä kannoit, on poissa.",
    ['bleeding'] = 'Vuodat verta.',
    ['part_head'] = 'pää',
    ['part_torso'] = 'rintakehä',
    ['part_left_arm'] = 'vasen käsi',
    ['part_right_arm'] = 'oikea käsi',
    ['part_left_leg'] = 'vasen jalka',
    ['part_right_leg'] = 'oikea jalka',
    ['state_healthy'] = 'terve',
    ['state_injured'] = 'loukkaantunut',
    ['state_broken'] = 'murtunut',
    ['state_bleeding'] = 'vuotaa verta',

    -- hospitals
    ['place_valentine'] = 'Valentinen lääkäri',
    ['place_blackwater'] = 'Blackwaterin lääkäri',
    ['place_strawberry'] = 'Strawberryn lääkäri',
    ['place_armadillo'] = 'Armadillon lääkäri',
    ['place_tumbleweed'] = 'Tumbleweedin lääkäri',
    ['place_saintdenis'] = 'Saint Denisin lääkäri',
    ['place_rhodes'] = 'Rhodesin lääkäri',
    ['place_vanhorn'] = 'Van Hornin lääkäri',
    ['place_annesburg'] = 'Annesburgin lääkäri',

    -- commands
    ['cmd_revive'] = 'Elvytä itsesi tai pelaaja (ylläpito)',
    ['cmd_heal'] = 'Paranna itsesi tai pelaaja (ylläpito)',
    ['cmd_kill'] = 'Tapa pelaaja (ylläpito)',
    ['cmd_id'] = 'Pelaajan ID',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) kuoli',
    ['log_text'] = '%s kuoli, tappaja %s (syy %s)',
    ['log_unknown'] = 'tuntematon',
}

-- MULTImedic: Hrvatski
Locales = Locales or {}
Locales['hr'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Bez svijesti si',
    ['ui_sub'] = 'Čekaj liječnika ili da ti se vrati snaga',
    ['ui_sub_ready'] = 'Možeš se opet dići na noge',
    ['ui_wait'] = 'Možeš se ponovno pojaviti za',
    ['ui_hold_respawn'] = 'Drži za ponovno pojavljivanje kod liječnika',
    ['ui_fee'] = "Liječnička naknada: $%s",
    ['ui_call'] = 'Pozovi liječnika',
    ['ui_call_sending'] = 'Šaljem poruku...',
    ['ui_call_sent'] = 'Poslano je po liječnika',
    ['ui_call_none'] = 'Nijedan liječnik se nije javio',
    ['ui_call_wait'] = 'Upravo si zvao',
    ['ui_call_failed'] = 'Poziv nije moguće poslati',
    ['ui_call_again'] = 'ponovni poziv za %ss',
    ['ui_medics'] = 'Liječnika na području: %s',
    ['ui_no_medics'] = 'Nijedan liječnik nije na dužnosti',

    -- respawn
    ['too_early'] = 'Još nemaš snage ustati.',
    ['respawned'] = 'Došao si k sebi: %s.',
    ['respawned_fee'] = 'Došao si k sebi: %s. Liječnik je naplatio $%s.',
    ['lost_cash'] = 'Tvoj novac je nestao.',
    ['lost_bloodmoney'] = 'Tvoj krvavi novac je nestao.',

    -- doctor calls
    ['alert_text'] = '%s je pao i treba liječnika',
    ['alert_default'] = 'Netko treba liječnika',
    ['doctor_called'] = 'Liječnicima je poslana poruka.',
    ['no_medics'] = 'Trenutno nijedan liječnik nije na dužnosti.',
    ['call_cooldown'] = 'Upravo si poslao poziv. Pričekaj malo.',

    -- medic actions
    ['reviving'] = 'Oživljavanje...',
    ['treating'] = 'Liječenje rana...',
    ['target_revive'] = 'Oživi',
    ['target_treat'] = 'Previj rane',
    ['not_medic'] = 'Nisi liječnik na dužnosti.',
    ['no_player'] = 'Tamo nema igrača.',
    ['nobody_down'] = 'Nitko u blizini nije pao.',
    ['not_down'] = 'Ta osoba nije bez svijesti.',
    ['is_down'] = 'Ta osoba je bez svijesti; prvo je oživi.',
    ['too_far'] = 'Predaleko si.',
    ['you_revived'] = 'Oživio si: %s.',
    ['revived_by'] = '%s te vratio k svijesti.',
    ['you_treated'] = "Previo si rane: %s.",
    ['treated_by'] = '%s ti je previo rane.',

    -- injuries
    ['injury_worse'] = 'Dio tijela: %s, stanje: %s.',
    ['injury_better'] = 'Jedna ti je rana bolje.',
    ['no_injuries'] = 'Nemaš rana za previjanje.',
    ["need_item"] = "Trebaš: %s.",
    ["cannot_now"] = "To sada ne možeš.",
    ["bandaging"] = "Previjanje...",
    ["bandaged"] = "Sam si se zakrpao.",
    ["lost_items"] = "Sve što si nosio je nestalo.",
    ['bleeding'] = 'Krvariš.',
    ['part_head'] = 'glava',
    ['part_torso'] = 'prsa',
    ['part_left_arm'] = 'lijeva ruka',
    ['part_right_arm'] = 'desna ruka',
    ['part_left_leg'] = 'lijeva noga',
    ['part_right_leg'] = 'desna noga',
    ['state_healthy'] = 'zdravo',
    ['state_injured'] = 'ozlijeđeno',
    ['state_broken'] = 'slomljeno',
    ['state_bleeding'] = 'krvari',

    -- hospitals
    ['place_valentine'] = 'liječnik u Valentineu',
    ['place_blackwater'] = 'liječnik u Blackwateru',
    ['place_strawberry'] = 'liječnik u Strawberryju',
    ['place_armadillo'] = 'liječnik u Armadillu',
    ['place_tumbleweed'] = 'liječnik u Tumbleweedu',
    ['place_saintdenis'] = 'liječnik u Saint Denisu',
    ['place_rhodes'] = 'liječnik u Rhodesu',
    ['place_vanhorn'] = 'liječnik u Van Hornu',
    ['place_annesburg'] = 'liječnik u Annesburgu',

    -- commands
    ['cmd_revive'] = 'Oživi sebe ili igrača (admin)',
    ['cmd_heal'] = 'Izliječi sebe ili igrača (admin)',
    ['cmd_kill'] = 'Ubij igrača (admin)',
    ['cmd_id'] = 'ID igrača',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) je umro',
    ['log_text'] = '%s je ubijen, ubojica: %s (uzrok %s)',
    ['log_unknown'] = 'nepoznato',
}

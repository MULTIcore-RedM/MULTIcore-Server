-- MULTImedic: Serbian
Locales = Locales or {}
Locales['sr'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Bez svesti si',
    ['ui_sub'] = 'Sačekaj doktora ili da ti se snaga vrati',
    ['ui_sub_ready'] = 'Možeš ponovo da ustaneš',
    ['ui_wait'] = 'Možeš da se vratiš za',
    ['ui_hold_respawn'] = 'Drži da se vratiš kod doktora',
    ['ui_fee'] = "Doktorski honorar: $%s",
    ['ui_call'] = 'Pozovi doktora',
    ['ui_call_sending'] = 'Šalje se poruka...',
    ['ui_call_sent'] = 'Poslato je po doktora',
    ['ui_call_none'] = 'Nijedan doktor se nije javio',
    ['ui_call_wait'] = 'Upravo si zvao',
    ['ui_call_failed'] = 'Poziv nije mogao da se pošalje',
    ['ui_call_again'] = 'novi poziv za %ss',
    ['ui_medics'] = 'Doktora na teritoriji: %s',
    ['ui_no_medics'] = 'Nijedan doktor nije na dužnosti',

    -- respawn
    ['too_early'] = 'Još nemaš snage da ustaneš.',
    ['respawned'] = 'Došao si sebi kod: %s.',
    ['respawned_fee'] = 'Došao si sebi kod: %s. Doktor je naplatio $%s.',
    ['lost_cash'] = 'Gotovine više nema.',
    ['lost_bloodmoney'] = 'Krvavog novca više nema.',

    -- doctor calls
    ['alert_text'] = '%s je pao i treba mu doktor',
    ['alert_default'] = 'Nekome treba doktor',
    ['doctor_called'] = 'Doktorima je poslata poruka.',
    ['no_medics'] = 'Trenutno nijedan doktor nije na dužnosti.',
    ['call_cooldown'] = 'Upravo si poslao poziv. Sačekaj malo.',

    -- medic actions
    ['reviving'] = 'Oživljavanje...',
    ['treating'] = 'Previjanje rana...',
    ['target_revive'] = 'Oživi',
    ['target_treat'] = 'Previj rane',
    ['not_medic'] = 'Nisi doktor na dužnosti.',
    ['no_player'] = 'Tu nema igrača.',
    ['nobody_down'] = 'Niko blizu tebe nije pao.',
    ['not_down'] = 'Ta osoba nije bez svesti.',
    ['is_down'] = 'Ta osoba je bez svesti; prvo je oživi.',
    ['too_far'] = 'Predaleko si.',
    ['you_revived'] = 'Oživeo si: %s.',
    ['revived_by'] = '%s te je vratio.',
    ['you_treated'] = "Previo si rane: %s.",
    ['treated_by'] = '%s ti je previo rane.',

    -- injuries
    ['injury_worse'] = 'Stanje (%s): %s.',
    ['injury_better'] = 'Jedna rana ti je bolje.',
    ['no_injuries'] = 'Nemaš rana za previjanje.',
    ["need_item"] = "Treba ti %s.",
    ["cannot_now"] = "To sada ne možeš.",
    ["bandaging"] = "Previjanje...",
    ["bandaged"] = "Zakrpio si se.",
    ["lost_items"] = "Sve što si nosio je nestalo.",
    ['bleeding'] = 'Krvariš.',
    ['part_head'] = 'glava',
    ['part_torso'] = 'grudi',
    ['part_left_arm'] = 'leva ruka',
    ['part_right_arm'] = 'desna ruka',
    ['part_left_leg'] = 'leva noga',
    ['part_right_leg'] = 'desna noga',
    ['state_healthy'] = 'zdravo',
    ['state_injured'] = 'povređeno',
    ['state_broken'] = 'slomljeno',
    ['state_bleeding'] = 'krvari',

    -- hospitals
    ['place_valentine'] = 'Doktor (Valentine)',
    ['place_blackwater'] = 'Doktor (Blackwater)',
    ['place_strawberry'] = 'Doktor (Strawberry)',
    ['place_armadillo'] = 'Doktor (Armadillo)',
    ['place_tumbleweed'] = 'Doktor (Tumbleweed)',
    ['place_saintdenis'] = 'Doktor (Saint Denis)',
    ['place_rhodes'] = 'Doktor (Rhodes)',
    ['place_vanhorn'] = 'Doktor (Van Horn)',
    ['place_annesburg'] = 'Doktor (Annesburg)',

    -- commands
    ['cmd_revive'] = 'Oživi sebe ili igrača (admin)',
    ['cmd_heal'] = 'Izleči sebe ili igrača (admin)',
    ['cmd_kill'] = 'Ubij igrača (admin)',
    ['cmd_id'] = 'Id igrača',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) je umro',
    ['log_text'] = '%s je ubijen od strane %s (uzrok %s)',
    ['log_unknown'] = 'nepoznato',
}

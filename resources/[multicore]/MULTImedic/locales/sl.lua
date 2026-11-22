-- MULTImedic: Slovenian
Locales = Locales or {}
Locales['sl'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Nezavesten si',
    ['ui_sub'] = 'Počakaj na zdravnika ali da se ti vrnejo moči',
    ['ui_sub_ready'] = 'Lahko se spet postaviš na noge',
    ['ui_wait'] = 'Ponovno se lahko pojaviš čez',
    ['ui_hold_respawn'] = 'Drži za vrnitev pri zdravniku',
    ['ui_fee'] = "Zdravnikov honorar: $%s",
    ['ui_call'] = 'Pokliči zdravnika',
    ['ui_call_sending'] = 'Pošiljam sporočilo ...',
    ['ui_call_sent'] = 'Po zdravnika so poslali',
    ['ui_call_none'] = 'Noben zdravnik se ni odzval',
    ['ui_call_wait'] = 'Klical si pred trenutkom',
    ['ui_call_failed'] = 'Klica ni bilo mogoče poslati',
    ['ui_call_again'] = 'znova čez %ss',
    ['ui_medics'] = 'Zdravniki na ozemlju: %s',
    ['ui_no_medics'] = 'Noben zdravnik ni v službi',

    -- respawn
    ['too_early'] = 'Še nisi dovolj močan, da bi vstal.',
    ['respawned'] = 'Prišel si k sebi: %s.',
    ['respawned_fee'] = 'Prišel si k sebi: %s. Zdravnik je zaračunal $%s.',
    ['lost_cash'] = 'Tvoje gotovine ni več.',
    ['lost_bloodmoney'] = 'Tvojega krvavega denarja ni več.',

    -- doctor calls
    ['alert_text'] = '%s je na tleh in potrebuje zdravnika',
    ['alert_default'] = 'Nekdo potrebuje zdravnika',
    ['doctor_called'] = 'Zdravnikom je bilo sporočeno.',
    ['no_medics'] = 'Trenutno ni nobenega zdravnika v službi.',
    ['call_cooldown'] = 'Pravkar si klical. Počakaj trenutek.',

    -- medic actions
    ['reviving'] = 'Oživljanje ...',
    ['treating'] = 'Oskrba ran ...',
    ['target_revive'] = 'Oživi',
    ['target_treat'] = 'Oskrbi rane',
    ['not_medic'] = 'Nisi zdravnik v službi.',
    ['no_player'] = 'Tam ni igralca.',
    ['nobody_down'] = 'Nihče blizu tebe ni na tleh.',
    ['not_down'] = 'Ta oseba ni nezavestna.',
    ['is_down'] = 'Ta oseba je nezavestna; najprej jo oživi.',
    ['too_far'] = 'Predaleč si.',
    ['you_revived'] = 'Oživil si: %s.',
    ['revived_by'] = '%s te je spravil k sebi.',
    ['you_treated'] = "Oskrbel si rane: %s.",
    ['treated_by'] = '%s ti je oskrbel rane.',

    -- injuries
    ['injury_worse'] = 'Poškodba – %s: %s.',
    ['injury_better'] = 'Ena od tvojih ran je boljša.',
    ['no_injuries'] = 'Nimaš ran za oskrbo.',
    ["need_item"] = "Potrebuješ: %s.",
    ["cannot_now"] = "Tega zdaj ne moreš storiti.",
    ["bandaging"] = "Povijanje ...",
    ["bandaged"] = "Sam si se zakrpal.",
    ["lost_items"] = "Vsega, kar si nosil, ni več.",
    ['bleeding'] = 'Krvaviš.',
    ['part_head'] = 'glava',
    ['part_torso'] = 'prsni koš',
    ['part_left_arm'] = 'leva roka',
    ['part_right_arm'] = 'desna roka',
    ['part_left_leg'] = 'leva noga',
    ['part_right_leg'] = 'desna noga',
    ['state_healthy'] = 'zdravo',
    ['state_injured'] = 'poškodovano',
    ['state_broken'] = 'zlomljeno',
    ['state_bleeding'] = 'krvavi',

    -- hospitals
    ['place_valentine'] = 'zdravnik v Valentine',
    ['place_blackwater'] = 'zdravnik v Blackwater',
    ['place_strawberry'] = 'zdravnik v Strawberry',
    ['place_armadillo'] = 'zdravnik v Armadillo',
    ['place_tumbleweed'] = 'zdravnik v Tumbleweed',
    ['place_saintdenis'] = 'zdravnik v Saint Denis',
    ['place_rhodes'] = 'zdravnik v Rhodes',
    ['place_vanhorn'] = 'zdravnik v Van Horn',
    ['place_annesburg'] = 'zdravnik v Annesburg',

    -- commands
    ['cmd_revive'] = 'Oživi sebe ali igralca (admin)',
    ['cmd_heal'] = 'Pozdravi sebe ali igralca (admin)',
    ['cmd_kill'] = 'Ubij igralca (admin)',
    ['cmd_id'] = 'ID igralca',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) je umrl',
    ['log_text'] = '%s je bil ubit, ubijalec: %s (vzrok %s)',
    ['log_unknown'] = 'neznano',
}

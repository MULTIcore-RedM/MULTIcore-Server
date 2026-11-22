-- MULTImedic: Norsk (bokmål)
Locales = Locales or {}
Locales['no'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Du er bevisstløs',
    ['ui_sub'] = 'Vent på en doktor, eller til kreftene kommer tilbake',
    ['ui_sub_ready'] = 'Du kan komme deg på beina igjen',
    ['ui_wait'] = 'Du kan våkne igjen om',
    ['ui_hold_respawn'] = 'Hold for å våkne hos doktoren',
    ['ui_fee'] = "Doktorens honorar: $%s",
    ['ui_call'] = 'Tilkall en doktor',
    ['ui_call_sending'] = 'Sender bud...',
    ['ui_call_sent'] = 'Det er sendt bud etter en doktor',
    ['ui_call_none'] = 'Ingen doktor svarte',
    ['ui_call_wait'] = 'Du tilkalte nettopp',
    ['ui_call_failed'] = 'Budet kunne ikke sendes',
    ['ui_call_again'] = 'tilkall igjen om %ss',
    ['ui_medics'] = 'Doktorer i området: %s',
    ['ui_no_medics'] = 'Ingen doktor er på vakt',

    -- respawn
    ['too_early'] = 'Du er ikke sterk nok til å reise deg ennå.',
    ['respawned'] = 'Du våknet hos %s.',
    ['respawned_fee'] = 'Du våknet hos %s. Doktoren tok $%s.',
    ['lost_cash'] = 'Kontantene dine er borte.',
    ['lost_bloodmoney'] = 'Blodpengene dine er borte.',

    -- doctor calls
    ['alert_text'] = '%s ligger nede og trenger en doktor',
    ['alert_default'] = 'Noen trenger en doktor',
    ['doctor_called'] = 'Det er sendt bud til doktorene.',
    ['no_medics'] = 'Ingen doktor er på vakt akkurat nå.',
    ['call_cooldown'] = 'Du sendte nettopp bud. Vent litt.',

    -- medic actions
    ['reviving'] = 'Gjenoppliver...',
    ['treating'] = 'Behandler sår...',
    ['target_revive'] = 'Gjenoppliv',
    ['target_treat'] = 'Behandle sår',
    ['not_medic'] = 'Du er ikke en doktor på vakt.',
    ['no_player'] = 'Ingen spiller der.',
    ['nobody_down'] = 'Ingen nær deg ligger nede.',
    ['not_down'] = 'Den personen er ikke bevisstløs.',
    ['is_down'] = 'Den personen er bevisstløs; gjenoppliv vedkommende først.',
    ['too_far'] = 'Du er for langt unna.',
    ['you_revived'] = 'Du gjenopplivet %s.',
    ['revived_by'] = '%s fikk deg tilbake.',
    ['you_treated'] = "Du behandlet sårene til %s.",
    ['treated_by'] = '%s behandlet sårene dine.',

    -- injuries
    ['injury_worse'] = 'Skade: %s (%s).',
    ['injury_better'] = 'Et av sårene dine er bedre.',
    ['no_injuries'] = 'Du har ingen sår å behandle.',
    ["need_item"] = "Du trenger en %s.",
    ["cannot_now"] = "Du kan ikke gjøre det akkurat nå.",
    ["bandaging"] = "Bandasjerer...",
    ["bandaged"] = "Du lappet deg sammen.",
    ["lost_items"] = "Alt du bar på er borte.",
    ['bleeding'] = 'Du blør.',
    ['part_head'] = 'hode',
    ['part_torso'] = 'bryst',
    ['part_left_arm'] = 'venstre arm',
    ['part_right_arm'] = 'høyre arm',
    ['part_left_leg'] = 'venstre bein',
    ['part_right_leg'] = 'høyre bein',
    ['state_healthy'] = 'frisk',
    ['state_injured'] = 'skadet',
    ['state_broken'] = 'brukket',
    ['state_bleeding'] = 'blør',

    -- hospitals
    ['place_valentine'] = 'doktoren i Valentine',
    ['place_blackwater'] = 'doktoren i Blackwater',
    ['place_strawberry'] = 'doktoren i Strawberry',
    ['place_armadillo'] = 'doktoren i Armadillo',
    ['place_tumbleweed'] = 'doktoren i Tumbleweed',
    ['place_saintdenis'] = 'doktoren i Saint Denis',
    ['place_rhodes'] = 'doktoren i Rhodes',
    ['place_vanhorn'] = 'doktoren i Van Horn',
    ['place_annesburg'] = 'doktoren i Annesburg',

    -- commands
    ['cmd_revive'] = 'Gjenoppliv deg selv eller en spiller (admin)',
    ['cmd_heal'] = 'Helbred deg selv eller en spiller (admin)',
    ['cmd_kill'] = 'Drep en spiller (admin)',
    ['cmd_id'] = 'Spiller-ID',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) døde',
    ['log_text'] = '%s ble drept av %s (årsak %s)',
    ['log_unknown'] = 'ukjent',
}

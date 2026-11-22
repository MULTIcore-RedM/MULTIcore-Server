-- MULTImedic: Dansk
Locales = Locales or {}
Locales['da'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Du er bevidstløs',
    ['ui_sub'] = 'Vent på en læge, eller på at kræfterne vender tilbage',
    ['ui_sub_ready'] = 'Du kan komme på benene igen',
    ['ui_wait'] = 'Du kan genopstå om',
    ['ui_hold_respawn'] = 'Hold for at vågne hos lægen',
    ['ui_fee'] = "Lægens honorar: $%s",
    ['ui_call'] = 'Send bud efter en læge',
    ['ui_call_sending'] = 'Sender bud...',
    ['ui_call_sent'] = 'Der er sendt bud efter en læge',
    ['ui_call_none'] = 'Ingen læge svarede',
    ['ui_call_wait'] = 'Du kaldte for et øjeblik siden',
    ['ui_call_failed'] = 'Buddet kunne ikke sendes',
    ['ui_call_again'] = 'kald igen om %ss',
    ['ui_medics'] = 'Læger i territoriet: %s',
    ['ui_no_medics'] = 'Ingen læge på vagt',

    -- respawn
    ['too_early'] = 'Du er ikke stærk nok til at rejse dig endnu.',
    ['respawned'] = 'Du kom til dig selv hos %s.',
    ['respawned_fee'] = 'Du kom til dig selv hos %s. Lægen tog $%s.',
    ['lost_cash'] = 'Dine kontanter er væk.',
    ['lost_bloodmoney'] = 'Dine blodpenge er væk.',

    -- doctor calls
    ['alert_text'] = '%s er nede og har brug for en læge',
    ['alert_default'] = 'Nogen har brug for en læge',
    ['doctor_called'] = 'Der er sendt bud til lægerne.',
    ['no_medics'] = 'Ingen læge er på vagt lige nu.',
    ['call_cooldown'] = 'Du har lige sendt et bud. Vent et øjeblik.',

    -- medic actions
    ['reviving'] = 'Genopliver...',
    ['treating'] = 'Behandler sår...',
    ['target_revive'] = 'Genopliv',
    ['target_treat'] = 'Behandl sår',
    ['not_medic'] = 'Du er ikke en læge på vagt.',
    ['no_player'] = 'Ingen spiller der.',
    ['nobody_down'] = 'Ingen nær dig er nede.',
    ['not_down'] = 'Den person er ikke bevidstløs.',
    ['is_down'] = 'Den person er bevidstløs; genopliv vedkommende først.',
    ['too_far'] = 'Du er for langt væk.',
    ['you_revived'] = 'Du genoplivede %s.',
    ['revived_by'] = '%s bragte dig tilbage.',
    ['you_treated'] = "Du behandlede %ss sår.",
    ['treated_by'] = '%s behandlede dine sår.',

    -- injuries
    ['injury_worse'] = '%s: %s.',
    ['injury_better'] = 'Et af dine sår har det bedre.',
    ['no_injuries'] = 'Du har ingen sår at behandle.',
    ["need_item"] = "Du skal bruge en %s.",
    ["cannot_now"] = "Det kan du ikke lige nu.",
    ["bandaging"] = "Forbinder...",
    ["bandaged"] = "Du lappede dig selv sammen.",
    ["lost_items"] = "Alt, hvad du bar på, er væk.",
    ['bleeding'] = 'Du bløder.',
    ['part_head'] = 'hoved',
    ['part_torso'] = 'bryst',
    ['part_left_arm'] = 'venstre arm',
    ['part_right_arm'] = 'højre arm',
    ['part_left_leg'] = 'venstre ben',
    ['part_right_leg'] = 'højre ben',
    ['state_healthy'] = 'rask',
    ['state_injured'] = 'såret',
    ['state_broken'] = 'brækket',
    ['state_bleeding'] = 'bløder',

    -- hospitals
    ['place_valentine'] = 'lægen i Valentine',
    ['place_blackwater'] = 'lægen i Blackwater',
    ['place_strawberry'] = 'lægen i Strawberry',
    ['place_armadillo'] = 'lægen i Armadillo',
    ['place_tumbleweed'] = 'lægen i Tumbleweed',
    ['place_saintdenis'] = 'lægen i Saint Denis',
    ['place_rhodes'] = 'lægen i Rhodes',
    ['place_vanhorn'] = 'lægen i Van Horn',
    ['place_annesburg'] = 'lægen i Annesburg',

    -- commands
    ['cmd_revive'] = 'Genopliv dig selv eller en spiller (admin)',
    ['cmd_heal'] = 'Helbred dig selv eller en spiller (admin)',
    ['cmd_kill'] = 'Dræb en spiller (admin)',
    ['cmd_id'] = 'Spiller-id',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) døde',
    ['log_text'] = '%s blev dræbt af %s (årsag %s)',
    ['log_unknown'] = 'ukendt',
}

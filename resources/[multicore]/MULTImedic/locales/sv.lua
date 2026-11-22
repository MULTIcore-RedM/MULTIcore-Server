-- MULTImedic: Svenska
Locales = Locales or {}
Locales['sv'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Du är medvetslös',
    ['ui_sub'] = 'Vänta på en doktor, eller på att krafterna återvänder',
    ['ui_sub_ready'] = 'Du kan ta dig upp på fötter igen',
    ['ui_wait'] = 'Du kan återuppstå om',
    ['ui_hold_respawn'] = 'Håll in för att vakna hos doktorn',
    ['ui_fee'] = "Doktorns arvode: $%s",
    ['ui_call'] = 'Skicka efter en doktor',
    ['ui_call_sending'] = 'Skickar bud...',
    ['ui_call_sent'] = 'Bud har skickats efter en doktor',
    ['ui_call_none'] = 'Ingen doktor svarade',
    ['ui_call_wait'] = 'Du ropade nyss',
    ['ui_call_failed'] = 'Budet kunde inte skickas',
    ['ui_call_again'] = 'ropa igen om %ss',
    ['ui_medics'] = 'Doktorer i territoriet: %s',
    ['ui_no_medics'] = 'Ingen doktor i tjänst',

    -- respawn
    ['too_early'] = 'Du är inte stark nog att resa dig än.',
    ['respawned'] = 'Du vaknade hos %s.',
    ['respawned_fee'] = 'Du vaknade hos %s. Doktorn tog $%s.',
    ['lost_cash'] = 'Dina kontanter är borta.',
    ['lost_bloodmoney'] = 'Dina blodspengar är borta.',

    -- doctor calls
    ['alert_text'] = '%s ligger nere och behöver en doktor',
    ['alert_default'] = 'Någon behöver en doktor',
    ['doctor_called'] = 'Bud har skickats till doktorerna.',
    ['no_medics'] = 'Ingen doktor är i tjänst just nu.',
    ['call_cooldown'] = 'Du skickade precis ett bud. Vänta en stund.',

    -- medic actions
    ['reviving'] = 'Återupplivar...',
    ['treating'] = 'Behandlar sår...',
    ['target_revive'] = 'Återuppliva',
    ['target_treat'] = 'Behandla sår',
    ['not_medic'] = 'Du är ingen doktor i tjänst.',
    ['no_player'] = 'Ingen spelare där.',
    ['nobody_down'] = 'Ingen nära dig ligger nere.',
    ['not_down'] = 'Den personen är inte medvetslös.',
    ['is_down'] = 'Den personen är medvetslös; återuppliva först.',
    ['too_far'] = 'Du är för långt bort.',
    ['you_revived'] = 'Du återupplivade %s.',
    ['revived_by'] = '%s väckte liv i dig.',
    ['you_treated'] = "Du behandlade %ss sår.",
    ['treated_by'] = '%s behandlade dina sår.',

    -- injuries
    ['injury_worse'] = '%s: %s.',
    ['injury_better'] = 'Ett av dina sår har blivit bättre.',
    ['no_injuries'] = 'Du har inga sår att behandla.',
    ["need_item"] = "Du behöver en %s.",
    ["cannot_now"] = "Du kan inte göra det just nu.",
    ["bandaging"] = "Lägger förband...",
    ["bandaged"] = "Du lappade ihop dig själv.",
    ["lost_items"] = "Allt du bar på är borta.",
    ['bleeding'] = 'Du blöder.',
    ['part_head'] = 'huvud',
    ['part_torso'] = 'bröst',
    ['part_left_arm'] = 'vänster arm',
    ['part_right_arm'] = 'höger arm',
    ['part_left_leg'] = 'vänster ben',
    ['part_right_leg'] = 'höger ben',
    ['state_healthy'] = 'frisk',
    ['state_injured'] = 'skadad',
    ['state_broken'] = 'bruten',
    ['state_bleeding'] = 'blöder',

    -- hospitals
    ['place_valentine'] = 'doktorn i Valentine',
    ['place_blackwater'] = 'doktorn i Blackwater',
    ['place_strawberry'] = 'doktorn i Strawberry',
    ['place_armadillo'] = 'doktorn i Armadillo',
    ['place_tumbleweed'] = 'doktorn i Tumbleweed',
    ['place_saintdenis'] = 'doktorn i Saint Denis',
    ['place_rhodes'] = 'doktorn i Rhodes',
    ['place_vanhorn'] = 'doktorn i Van Horn',
    ['place_annesburg'] = 'doktorn i Annesburg',

    -- commands
    ['cmd_revive'] = 'Återuppliva dig själv eller en spelare (admin)',
    ['cmd_heal'] = 'Hela dig själv eller en spelare (admin)',
    ['cmd_kill'] = 'Döda en spelare (admin)',
    ['cmd_id'] = 'Spelar-id',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) dog',
    ['log_text'] = '%s dödades av %s (orsak %s)',
    ['log_unknown'] = 'okänd',
}

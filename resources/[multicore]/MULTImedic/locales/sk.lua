-- MULTImedic: Slovenčina
Locales = Locales or {}
Locales['sk'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Si v bezvedomí',
    ['ui_sub'] = 'Počkaj na lekára, alebo kým sa ti vráti sila',
    ['ui_sub_ready'] = 'Môžeš sa znova postaviť na nohy',
    ['ui_wait'] = 'Oživenie možné o',
    ['ui_hold_respawn'] = 'Podrž a preberieš sa u lekára',
    ['ui_fee'] = "Poplatok lekárovi: $%s",
    ['ui_call'] = 'Zavolať lekára',
    ['ui_call_sending'] = 'Posiela sa správa...',
    ['ui_call_sent'] = 'Po lekára už poslali',
    ['ui_call_none'] = 'Žiadny lekár neodpovedal',
    ['ui_call_wait'] = 'Volal si pred chvíľou',
    ['ui_call_failed'] = 'Volanie sa nepodarilo odoslať',
    ['ui_call_again'] = 'znova o %ss',
    ['ui_medics'] = 'Lekári na území: %s',
    ['ui_no_medics'] = 'Žiadny lekár nie je v službe',

    -- respawn
    ['too_early'] = 'Ešte nemáš dosť síl vstať.',
    ['respawned'] = 'Prebral si sa: %s.',
    ['respawned_fee'] = 'Prebral si sa: %s. Lekár si účtoval $%s.',
    ['lost_cash'] = 'Tvoja hotovosť je preč.',
    ['lost_bloodmoney'] = 'Tvoje krvavé peniaze sú preč.',

    -- doctor calls
    ['alert_text'] = '%s leží na zemi a potrebuje lekára',
    ['alert_default'] = 'Niekto potrebuje lekára',
    ['doctor_called'] = 'Lekárom bola poslaná správa.',
    ['no_medics'] = 'Práve teraz nie je v službe žiadny lekár.',
    ['call_cooldown'] = 'Práve si volal. Chvíľu počkaj.',

    -- medic actions
    ['reviving'] = 'Oživovanie...',
    ['treating'] = 'Ošetrovanie rán...',
    ['target_revive'] = 'Oživiť',
    ['target_treat'] = 'Ošetriť rany',
    ['not_medic'] = 'Nie si lekár v službe.',
    ['no_player'] = 'Nie je tam žiadny hráč.',
    ['nobody_down'] = 'Nikto pri tebe neleží na zemi.',
    ['not_down'] = 'Tá osoba nie je v bezvedomí.',
    ['is_down'] = 'Tá osoba je v bezvedomí; najprv ju oživ.',
    ['too_far'] = 'Si príliš ďaleko.',
    ['you_revived'] = 'Oživil si: %s.',
    ['revived_by'] = '%s ťa priviedol späť.',
    ['you_treated'] = "Ošetril si rany: %s.",
    ['treated_by'] = '%s ti ošetril rany.',

    -- injuries
    ['injury_worse'] = 'Zranenie (%s): %s.',
    ['injury_better'] = 'Jedna z tvojich rán sa zlepšila.',
    ['no_injuries'] = 'Nemáš žiadne rany na ošetrenie.',
    ["need_item"] = "Potrebuješ: %s.",
    ["cannot_now"] = "Toto teraz nemôžeš urobiť.",
    ["bandaging"] = "Obväzovanie...",
    ["bandaged"] = "Ošetril si sa.",
    ["lost_items"] = "Všetko, čo si niesol, je preč.",
    ['bleeding'] = 'Krvácaš.',
    ['part_head'] = 'hlava',
    ['part_torso'] = 'hruď',
    ['part_left_arm'] = 'ľavá ruka',
    ['part_right_arm'] = 'pravá ruka',
    ['part_left_leg'] = 'ľavá noha',
    ['part_right_leg'] = 'pravá noha',
    ['state_healthy'] = 'zdravé',
    ['state_injured'] = 'zranené',
    ['state_broken'] = 'zlomené',
    ['state_bleeding'] = 'krváca',

    -- hospitals
    ['place_valentine'] = 'lekár vo Valentine',
    ['place_blackwater'] = 'lekár v Blackwater',
    ['place_strawberry'] = 'lekár v Strawberry',
    ['place_armadillo'] = 'lekár v Armadillo',
    ['place_tumbleweed'] = 'lekár v Tumbleweed',
    ['place_saintdenis'] = 'lekár v Saint Denis',
    ['place_rhodes'] = 'lekár v Rhodes',
    ['place_vanhorn'] = 'lekár vo Van Horn',
    ['place_annesburg'] = 'lekár v Annesburg',

    -- commands
    ['cmd_revive'] = 'Oživiť seba alebo hráča (admin)',
    ['cmd_heal'] = 'Vyliečiť seba alebo hráča (admin)',
    ['cmd_kill'] = 'Zabiť hráča (admin)',
    ['cmd_id'] = 'Id hráča',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) zomrel',
    ['log_text'] = '%s zabil(a) %s (príčina %s)',
    ['log_unknown'] = 'neznáme',
}

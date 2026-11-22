-- MULTImedic: Čeština
Locales = Locales or {}
Locales['cs'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Jsi v bezvědomí',
    ['ui_sub'] = 'Počkej na doktora, nebo až se ti vrátí síly',
    ['ui_sub_ready'] = 'Můžeš se znovu postavit',
    ['ui_wait'] = 'Oživení možné za',
    ['ui_hold_respawn'] = 'Podrž pro probuzení u doktora',
    ['ui_fee'] = "Poplatek doktorovi: $%s",
    ['ui_call'] = 'Zavolat doktora',
    ['ui_call_sending'] = 'Posílá se zpráva...',
    ['ui_call_sent'] = 'Pro doktora už se poslalo',
    ['ui_call_none'] = 'Žádný doktor se neozval',
    ['ui_call_wait'] = 'Před chvílí jsi volal',
    ['ui_call_failed'] = 'Volání nešlo odeslat',
    ['ui_call_again'] = 'znovu za %ss',
    ['ui_medics'] = 'Doktorů v kraji: %s',
    ['ui_no_medics'] = 'Žádný doktor nemá službu',

    -- respawn
    ['too_early'] = 'Ještě nemáš sílu vstát.',
    ['respawned'] = 'Probral ses: %s.',
    ['respawned_fee'] = 'Probral ses: %s. Doktor si účtoval $%s.',
    ['lost_cash'] = 'Tvoje hotovost je pryč.',
    ['lost_bloodmoney'] = 'Tvoje krvavé peníze jsou pryč.',

    -- doctor calls
    ['alert_text'] = '%s je na zemi a potřebuje doktora',
    ['alert_default'] = 'Někdo potřebuje doktora',
    ['doctor_called'] = 'Doktorům byla poslána zpráva.',
    ['no_medics'] = 'Teď nemá službu žádný doktor.',
    ['call_cooldown'] = 'Právě jsi volal. Chvíli počkej.',

    -- medic actions
    ['reviving'] = 'Oživuješ...',
    ['treating'] = 'Ošetřuješ rány...',
    ['target_revive'] = 'Oživit',
    ['target_treat'] = 'Ošetřit rány',
    ['not_medic'] = 'Nejsi doktor ve službě.',
    ['no_player'] = 'Není tam žádný hráč.',
    ['nobody_down'] = 'Nikdo poblíž není na zemi.',
    ['not_down'] = 'Ten člověk není v bezvědomí.',
    ['is_down'] = 'Ten člověk je v bezvědomí; nejdřív ho oživ.',
    ['too_far'] = 'Jsi moc daleko.',
    ['you_revived'] = 'Oživil jsi: %s.',
    ['revived_by'] = '%s tě přivedl zpět.',
    ['you_treated'] = "Ošetřil jsi rány: %s.",
    ['treated_by'] = '%s ti ošetřil rány.',

    -- injuries
    ['injury_worse'] = '%s: %s.',
    ['injury_better'] = 'Jedna z tvých ran se zlepšila.',
    ['no_injuries'] = 'Nemáš žádné rány k ošetření.',
    ["need_item"] = "Potřebuješ: %s.",
    ["cannot_now"] = "Teď to nemůžeš udělat.",
    ["bandaging"] = "Obvazuješ...",
    ["bandaged"] = "Ošetřil ses.",
    ["lost_items"] = "Všechno, co jsi měl u sebe, je pryč.",
    ['bleeding'] = 'Krvácíš.',
    ['part_head'] = 'hlava',
    ['part_torso'] = 'hrudník',
    ['part_left_arm'] = 'levá paže',
    ['part_right_arm'] = 'pravá paže',
    ['part_left_leg'] = 'levá noha',
    ['part_right_leg'] = 'pravá noha',
    ['state_healthy'] = 'zdravé',
    ['state_injured'] = 'zraněné',
    ['state_broken'] = 'zlomené',
    ['state_bleeding'] = 'krvácí',

    -- hospitals
    ['place_valentine'] = 'doktor ve Valentine',
    ['place_blackwater'] = 'doktor v Blackwater',
    ['place_strawberry'] = 'doktor ve Strawberry',
    ['place_armadillo'] = 'doktor v Armadillu',
    ['place_tumbleweed'] = 'doktor v Tumbleweed',
    ['place_saintdenis'] = 'doktor v Saint Denis',
    ['place_rhodes'] = 'doktor v Rhodes',
    ['place_vanhorn'] = 'doktor ve Van Horn',
    ['place_annesburg'] = 'doktor v Annesburgu',

    -- commands
    ['cmd_revive'] = 'Oživit sebe nebo hráče (admin)',
    ['cmd_heal'] = 'Vyléčit sebe nebo hráče (admin)',
    ['cmd_kill'] = 'Zabít hráče (admin)',
    ['cmd_id'] = 'ID hráče',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) zemřel',
    ['log_text'] = '%s byl zabit hráčem %s (příčina %s)',
    ['log_unknown'] = 'neznámé',
}

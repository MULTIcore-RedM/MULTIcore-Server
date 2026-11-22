-- MULTImedic: Greek
Locales = Locales or {}
Locales['el'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Είσαι αναίσθητος',
    ['ui_sub'] = 'Περίμενε γιατρό ή να γυρίσουν οι δυνάμεις σου',
    ['ui_sub_ready'] = 'Μπορείς να σηκωθείς ξανά',
    ['ui_wait'] = 'Μπορείς να επανέλθεις σε',
    ['ui_hold_respawn'] = 'Κράτα πατημένο για επάνοδο στον γιατρό',
    ['ui_fee'] = "Αμοιβή γιατρού: $%s",
    ['ui_call'] = 'Φώναξε γιατρό',
    ['ui_call_sending'] = 'Στέλνεται μήνυμα...',
    ['ui_call_sent'] = 'Στάλθηκε μήνυμα σε γιατρό',
    ['ui_call_none'] = 'Κανένας γιατρός δεν απάντησε',
    ['ui_call_wait'] = 'Μόλις κάλεσες',
    ['ui_call_failed'] = 'Η κλήση δεν στάλθηκε',
    ['ui_call_again'] = 'νέα κλήση σε %ss',
    ['ui_medics'] = 'Γιατροί στην περιοχή: %s',
    ['ui_no_medics'] = 'Κανένας γιατρός σε υπηρεσία',

    -- respawn
    ['too_early'] = 'Δεν έχεις ακόμη τη δύναμη να σηκωθείς.',
    ['respawned'] = 'Συνήλθες: %s.',
    ['respawned_fee'] = 'Συνήλθες: %s. Ο γιατρός χρέωσε $%s.',
    ['lost_cash'] = 'Τα μετρητά σου χάθηκαν.',
    ['lost_bloodmoney'] = 'Τα ματωμένα χρήματά σου χάθηκαν.',

    -- doctor calls
    ['alert_text'] = 'Ο %s έπεσε και χρειάζεται γιατρό',
    ['alert_default'] = 'Κάποιος χρειάζεται γιατρό',
    ['doctor_called'] = 'Στάλθηκε μήνυμα στους γιατρούς.',
    ['no_medics'] = 'Κανένας γιατρός δεν είναι σε υπηρεσία τώρα.',
    ['call_cooldown'] = 'Μόλις έστειλες κλήση. Περίμενε λίγο.',

    -- medic actions
    ['reviving'] = 'Επαναφορά...',
    ['treating'] = 'Περιποίηση τραυμάτων...',
    ['target_revive'] = 'Επανάφερε',
    ['target_treat'] = 'Περιποιήσου τραύματα',
    ['not_medic'] = 'Δεν είσαι γιατρός σε υπηρεσία.',
    ['no_player'] = 'Δεν υπάρχει παίκτης εκεί.',
    ['nobody_down'] = 'Κανείς κοντά σου δεν έχει πέσει.',
    ['not_down'] = 'Αυτό το άτομο δεν είναι αναίσθητο.',
    ['is_down'] = 'Αυτό το άτομο είναι αναίσθητο· επανάφερέ το πρώτα.',
    ['too_far'] = 'Είσαι πολύ μακριά.',
    ['you_revived'] = 'Επανέφερες τον %s.',
    ['revived_by'] = 'Ο %s σε επανέφερε.',
    ['you_treated'] = "Περιποιήθηκες τα τραύματα του %s.",
    ['treated_by'] = 'Ο %s περιποιήθηκε τα τραύματά σου.',

    -- injuries
    ['injury_worse'] = 'Το %s σου είναι %s.',
    ['injury_better'] = 'Ένα από τα τραύματά σου βελτιώθηκε.',
    ['no_injuries'] = 'Δεν έχεις τραύματα για περιποίηση.',
    ["need_item"] = "Χρειάζεσαι %s.",
    ["cannot_now"] = "Δεν μπορείς να το κάνεις τώρα.",
    ["bandaging"] = "Επίδεση...",
    ["bandaged"] = "Μπάλωσες τον εαυτό σου.",
    ["lost_items"] = "Ό,τι κουβαλούσες χάθηκε.",
    ['bleeding'] = 'Αιμορραγείς.',
    ['part_head'] = 'κεφάλι',
    ['part_torso'] = 'στήθος',
    ['part_left_arm'] = 'αριστερό χέρι',
    ['part_right_arm'] = 'δεξί χέρι',
    ['part_left_leg'] = 'αριστερό πόδι',
    ['part_right_leg'] = 'δεξί πόδι',
    ['state_healthy'] = 'υγιές',
    ['state_injured'] = 'χτυπημένο',
    ['state_broken'] = 'σπασμένο',
    ['state_bleeding'] = 'ματωμένο',

    -- hospitals
    ['place_valentine'] = 'Γιατρός Valentine',
    ['place_blackwater'] = 'Γιατρός Blackwater',
    ['place_strawberry'] = 'Γιατρός Strawberry',
    ['place_armadillo'] = 'Γιατρός Armadillo',
    ['place_tumbleweed'] = 'Γιατρός Tumbleweed',
    ['place_saintdenis'] = 'Γιατρός Saint Denis',
    ['place_rhodes'] = 'Γιατρός Rhodes',
    ['place_vanhorn'] = 'Γιατρός Van Horn',
    ['place_annesburg'] = 'Γιατρός Annesburg',

    -- commands
    ['cmd_revive'] = 'Επανάφερε εσένα ή έναν παίκτη (admin)',
    ['cmd_heal'] = 'Γιάτρεψε εσένα ή έναν παίκτη (admin)',
    ['cmd_kill'] = 'Σκότωσε έναν παίκτη (admin)',
    ['cmd_id'] = 'Id παίκτη',

    -- death log (rsg-log)
    ['log_title'] = 'Ο %s (%s) πέθανε',
    ['log_text'] = 'Ο %s σκοτώθηκε από %s (αιτία %s)',
    ['log_unknown'] = 'άγνωστο',
}

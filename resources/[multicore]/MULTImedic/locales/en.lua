-- MULTImedic: English (master file, every key lives here first)
Locales = Locales or {}
Locales['en'] = {
    -- death screen (NUI)
    ['ui_title'] = 'You are unconscious',
    ['ui_sub'] = 'Wait for a doctor, or for your strength to return',
    ['ui_sub_ready'] = 'You can get back on your feet',
    ['ui_wait'] = 'You can respawn in',
    ['ui_hold_respawn'] = 'Hold to respawn at the doctor',
    ['ui_fee'] = "Doctor's fee: $%s",
    ['ui_call'] = 'Call for a doctor',
    ['ui_call_sending'] = 'Sending word...',
    ['ui_call_sent'] = 'A doctor has been sent for',
    ['ui_call_none'] = 'No doctor answered',
    ['ui_call_wait'] = 'You called a moment ago',
    ['ui_call_failed'] = 'The call could not be sent',
    ['ui_call_again'] = 'call again in %ss',
    ['ui_medics'] = 'Doctors in the territory: %s',
    ['ui_no_medics'] = 'No doctor is on duty',

    -- respawn
    ['too_early'] = 'You are not strong enough to get up yet.',
    ['respawned'] = 'You came to at the %s.',
    ['respawned_fee'] = 'You came to at the %s. The doctor charged $%s.',
    ['lost_cash'] = 'Your cash is gone.',
    ['lost_bloodmoney'] = 'Your blood money is gone.',

    -- doctor calls
    ['alert_text'] = '%s is down and needs a doctor',
    ['alert_default'] = 'Someone needs a doctor',
    ['doctor_called'] = 'Word has been sent to the doctors.',
    ['no_medics'] = 'No doctor is on duty right now.',
    ['call_cooldown'] = 'You have just sent a call. Wait a moment.',

    -- medic actions
    ['reviving'] = 'Reviving...',
    ['treating'] = 'Treating wounds...',
    ['target_revive'] = 'Revive',
    ['target_treat'] = 'Treat wounds',
    ['not_medic'] = 'You are not a doctor on duty.',
    ['no_player'] = 'No player there.',
    ['nobody_down'] = 'Nobody near you is down.',
    ['not_down'] = 'That person is not unconscious.',
    ['is_down'] = 'That person is unconscious; revive them first.',
    ['too_far'] = 'You are too far away.',
    ['you_revived'] = 'You revived %s.',
    ['revived_by'] = '%s brought you back.',
    ['you_treated'] = "You treated %s's wounds.",
    ['treated_by'] = '%s treated your wounds.',

    -- injuries
    ['injury_worse'] = 'Your %s is %s.',
    ['injury_better'] = 'One of your wounds is better.',
    ['no_injuries'] = 'You have no wounds to treat.',
    ["need_item"] = "You need a %s.",
    ["cannot_now"] = "You cannot do that right now.",
    ["bandaging"] = "Bandaging...",
    ["bandaged"] = "You patched yourself up.",
    ["lost_items"] = "Everything you carried is gone.",
    ['bleeding'] = 'You are bleeding.',
    ['part_head'] = 'head',
    ['part_torso'] = 'chest',
    ['part_left_arm'] = 'left arm',
    ['part_right_arm'] = 'right arm',
    ['part_left_leg'] = 'left leg',
    ['part_right_leg'] = 'right leg',
    ['state_healthy'] = 'healthy',
    ['state_injured'] = 'hurt',
    ['state_broken'] = 'broken',
    ['state_bleeding'] = 'bleeding',

    -- hospitals
    ['place_valentine'] = 'Valentine doctor',
    ['place_blackwater'] = 'Blackwater doctor',
    ['place_strawberry'] = 'Strawberry doctor',
    ['place_armadillo'] = 'Armadillo doctor',
    ['place_tumbleweed'] = 'Tumbleweed doctor',
    ['place_saintdenis'] = 'Saint Denis doctor',
    ['place_rhodes'] = 'Rhodes doctor',
    ['place_vanhorn'] = 'Van Horn doctor',
    ['place_annesburg'] = 'Annesburg doctor',

    -- commands
    ['cmd_revive'] = 'Revive yourself or a player (admin)',
    ['cmd_heal'] = 'Heal yourself or a player (admin)',
    ['cmd_kill'] = 'Kill a player (admin)',
    ['cmd_id'] = 'Player id',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) died',
    ['log_text'] = '%s was killed by %s (cause %s)',
    ['log_unknown'] = 'unknown',
}

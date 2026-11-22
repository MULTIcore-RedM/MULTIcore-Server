-- MULTImedic: Chinese (Simplified)
Locales = Locales or {}
Locales['zh'] = {
    -- death screen (NUI)
    ['ui_title'] = '你失去了知觉',
    ['ui_sub'] = '等待医生，或等你恢复体力',
    ['ui_sub_ready'] = '你可以重新站起来了',
    ['ui_wait'] = '可重生倒计时',
    ['ui_hold_respawn'] = '按住在医生处重生',
    ['ui_fee'] = "医疗费：$%s",
    ['ui_call'] = '呼叫医生',
    ['ui_call_sending'] = '正在传信……',
    ['ui_call_sent'] = '已派人去请医生',
    ['ui_call_none'] = '没有医生回应',
    ['ui_call_wait'] = '你刚刚呼叫过',
    ['ui_call_failed'] = '呼叫没能送出',
    ['ui_call_again'] = '%s秒后可再次呼叫',
    ['ui_medics'] = '本地区医生：%s',
    ['ui_no_medics'] = '没有医生值班',

    -- respawn
    ['too_early'] = '你还没力气站起来。',
    ['respawned'] = '你在%s醒了过来。',
    ['respawned_fee'] = '你在%s醒了过来。医生收了 $%s。',
    ['lost_cash'] = '你的现金没了。',
    ['lost_bloodmoney'] = '你的血钱没了。',

    -- doctor calls
    ['alert_text'] = '%s 倒下了，需要医生',
    ['alert_default'] = '有人需要医生',
    ['doctor_called'] = '已经通知医生了。',
    ['no_medics'] = '现在没有医生值班。',
    ['call_cooldown'] = '你刚发过呼叫，请稍等。',

    -- medic actions
    ['reviving'] = '正在救治……',
    ['treating'] = '正在处理伤口……',
    ['target_revive'] = '救醒',
    ['target_treat'] = '处理伤口',
    ['not_medic'] = '你不是值班医生。',
    ['no_player'] = '那里没有玩家。',
    ['nobody_down'] = '你附近没有人倒下。',
    ['not_down'] = '此人没有昏迷。',
    ['is_down'] = '此人已昏迷，请先救醒。',
    ['too_far'] = '你离得太远了。',
    ['you_revived'] = '你救醒了 %s。',
    ['revived_by'] = '%s 把你救了回来。',
    ['you_treated'] = "你处理了 %s 的伤口。",
    ['treated_by'] = '%s 处理了你的伤口。',

    -- injuries
    ['injury_worse'] = '你的%s%s了。',
    ['injury_better'] = '你的一处伤好些了。',
    ['no_injuries'] = '你没有需要处理的伤。',
    ["need_item"] = "你需要%s。",
    ["cannot_now"] = "你现在不能这么做。",
    ["bandaging"] = "正在包扎……",
    ["bandaged"] = "你给自己包扎好了。",
    ["lost_items"] = "你身上的东西全没了。",
    ['bleeding'] = '你在流血。',
    ['part_head'] = '头部',
    ['part_torso'] = '胸口',
    ['part_left_arm'] = '左臂',
    ['part_right_arm'] = '右臂',
    ['part_left_leg'] = '左腿',
    ['part_right_leg'] = '右腿',
    ['state_healthy'] = '无碍',
    ['state_injured'] = '受伤',
    ['state_broken'] = '骨折',
    ['state_bleeding'] = '流血',

    -- hospitals
    ['place_valentine'] = 'Valentine 诊所',
    ['place_blackwater'] = 'Blackwater 诊所',
    ['place_strawberry'] = 'Strawberry 诊所',
    ['place_armadillo'] = 'Armadillo 诊所',
    ['place_tumbleweed'] = 'Tumbleweed 诊所',
    ['place_saintdenis'] = 'Saint Denis 诊所',
    ['place_rhodes'] = 'Rhodes 诊所',
    ['place_vanhorn'] = 'Van Horn 诊所',
    ['place_annesburg'] = 'Annesburg 诊所',

    -- commands
    ['cmd_revive'] = '救醒自己或某个玩家（管理员）',
    ['cmd_heal'] = '治疗自己或某个玩家（管理员）',
    ['cmd_kill'] = '杀死某个玩家（管理员）',
    ['cmd_id'] = '玩家 ID',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) 死亡',
    ['log_text'] = '%s 被 %s 杀死（死因 %s）',
    ['log_unknown'] = '未知',
}

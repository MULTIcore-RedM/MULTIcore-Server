-- MULTImedic: Japanese
Locales = Locales or {}
Locales['ja'] = {
    -- death screen (NUI)
    ['ui_title'] = '意識を失った',
    ['ui_sub'] = '医者を待つか、体力が戻るのを待とう',
    ['ui_sub_ready'] = '立ち上がれるようになった',
    ['ui_wait'] = 'リスポーンまで',
    ['ui_hold_respawn'] = '長押しで医者の所でリスポーン',
    ['ui_fee'] = "治療費: $%s",
    ['ui_call'] = '医者を呼ぶ',
    ['ui_call_sending'] = '知らせを送っている…',
    ['ui_call_sent'] = '医者を呼びに行かせた',
    ['ui_call_none'] = '医者は応じなかった',
    ['ui_call_wait'] = 'さっき呼んだばかりだ',
    ['ui_call_failed'] = '呼び出しを送れなかった',
    ['ui_call_again'] = '%s秒後に再度呼べる',
    ['ui_medics'] = 'この地域の医者: %s',
    ['ui_no_medics'] = '勤務中の医者はいない',

    -- respawn
    ['too_early'] = 'まだ起き上がる力がない。',
    ['respawned'] = '%sで目を覚ました。',
    ['respawned_fee'] = '%sで目を覚ました。治療費 $%s を払った。',
    ['lost_cash'] = '現金がなくなった。',
    ['lost_bloodmoney'] = '血の金がなくなった。',

    -- doctor calls
    ['alert_text'] = '%s が倒れていて医者が必要だ',
    ['alert_default'] = '誰かが医者を必要としている',
    ['doctor_called'] = '医者たちに知らせた。',
    ['no_medics'] = '今は勤務中の医者がいない。',
    ['call_cooldown'] = '呼んだばかりだ。少し待て。',

    -- medic actions
    ['reviving'] = '蘇生中…',
    ['treating'] = '傷を手当て中…',
    ['target_revive'] = '蘇生する',
    ['target_treat'] = '傷を手当てする',
    ['not_medic'] = '勤務中の医者ではない。',
    ['no_player'] = 'そこにプレイヤーはいない。',
    ['nobody_down'] = '近くに倒れている者はいない。',
    ['not_down'] = 'その人は気を失っていない。',
    ['is_down'] = 'その人は気を失っている。先に蘇生させろ。',
    ['too_far'] = '遠すぎる。',
    ['you_revived'] = '%s を蘇生させた。',
    ['revived_by'] = '%s に助けられた。',
    ['you_treated'] = "%s の傷を手当てした。",
    ['treated_by'] = '%s に傷を手当てしてもらった。',

    -- injuries
    ['injury_worse'] = '%sが%sの状態だ。',
    ['injury_better'] = '傷のひとつが良くなった。',
    ['no_injuries'] = '手当てする傷はない。',
    ["need_item"] = "%sが必要だ。",
    ["cannot_now"] = "今はそれができない。",
    ["bandaging"] = "包帯を巻いている…",
    ["bandaged"] = "自分で手当てした。",
    ["lost_items"] = "持ち物がすべてなくなった。",
    ['bleeding'] = '出血している。',
    ['part_head'] = '頭',
    ['part_torso'] = '胸',
    ['part_left_arm'] = '左腕',
    ['part_right_arm'] = '右腕',
    ['part_left_leg'] = '左脚',
    ['part_right_leg'] = '右脚',
    ['state_healthy'] = '無事',
    ['state_injured'] = '負傷',
    ['state_broken'] = '骨折',
    ['state_bleeding'] = '出血',

    -- hospitals
    ['place_valentine'] = 'Valentine の医者',
    ['place_blackwater'] = 'Blackwater の医者',
    ['place_strawberry'] = 'Strawberry の医者',
    ['place_armadillo'] = 'Armadillo の医者',
    ['place_tumbleweed'] = 'Tumbleweed の医者',
    ['place_saintdenis'] = 'Saint Denis の医者',
    ['place_rhodes'] = 'Rhodes の医者',
    ['place_vanhorn'] = 'Van Horn の医者',
    ['place_annesburg'] = 'Annesburg の医者',

    -- commands
    ['cmd_revive'] = '自分か他のプレイヤーを蘇生（管理者）',
    ['cmd_heal'] = '自分か他のプレイヤーを回復（管理者）',
    ['cmd_kill'] = 'プレイヤーを殺す（管理者）',
    ['cmd_id'] = 'プレイヤーID',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) が死亡',
    ['log_text'] = '%s が %s に殺された（死因 %s）',
    ['log_unknown'] = '不明',
}

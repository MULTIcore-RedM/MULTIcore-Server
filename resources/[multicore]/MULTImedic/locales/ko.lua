-- MULTImedic: 한국어
Locales = Locales or {}
Locales['ko'] = {
    -- death screen (NUI)
    ['ui_title'] = '의식을 잃었습니다',
    ['ui_sub'] = '의사를 기다리거나 기운이 돌아오길 기다리세요',
    ['ui_sub_ready'] = '다시 일어설 수 있습니다',
    ['ui_wait'] = '부활까지 남은 시간',
    ['ui_hold_respawn'] = '길게 눌러 의사에게서 깨어나기',
    ['ui_fee'] = "치료비: $%s",
    ['ui_call'] = '의사 부르기',
    ['ui_call_sending'] = '연락하는 중...',
    ['ui_call_sent'] = '의사를 불렀습니다',
    ['ui_call_none'] = '응답한 의사가 없습니다',
    ['ui_call_wait'] = '방금 불렀습니다',
    ['ui_call_failed'] = '연락을 보낼 수 없습니다',
    ['ui_call_again'] = '%s초 후 다시 부르기',
    ['ui_medics'] = '이 지역의 의사: %s',
    ['ui_no_medics'] = '근무 중인 의사가 없습니다',

    -- respawn
    ['too_early'] = '아직 일어설 기운이 없습니다.',
    ['respawned'] = '%s에서 정신을 차렸습니다.',
    ['respawned_fee'] = '%s에서 정신을 차렸습니다. 의사가 $%s을(를) 받았습니다.',
    ['lost_cash'] = '현금이 사라졌습니다.',
    ['lost_bloodmoney'] = '피 묻은 돈이 사라졌습니다.',

    -- doctor calls
    ['alert_text'] = '%s이(가) 쓰러져 의사가 필요합니다',
    ['alert_default'] = '누군가 의사가 필요합니다',
    ['doctor_called'] = '의사들에게 연락했습니다.',
    ['no_medics'] = '지금은 근무 중인 의사가 없습니다.',
    ['call_cooldown'] = '방금 연락했습니다. 잠시 기다리세요.',

    -- medic actions
    ['reviving'] = '살리는 중...',
    ['treating'] = '상처 치료 중...',
    ['target_revive'] = '살리기',
    ['target_treat'] = '상처 치료',
    ['not_medic'] = '근무 중인 의사가 아닙니다.',
    ['no_player'] = '그곳에 플레이어가 없습니다.',
    ['nobody_down'] = '근처에 쓰러진 사람이 없습니다.',
    ['not_down'] = '그 사람은 의식이 있습니다.',
    ['is_down'] = '그 사람은 의식이 없습니다. 먼저 살리세요.',
    ['too_far'] = '너무 멀리 있습니다.',
    ['you_revived'] = '%s을(를) 살렸습니다.',
    ['revived_by'] = '%s이(가) 당신을 살려냈습니다.',
    ['you_treated'] = "%s의 상처를 치료했습니다.",
    ['treated_by'] = '%s이(가) 당신의 상처를 치료했습니다.',

    -- injuries
    ['injury_worse'] = '%s 상태: %s.',
    ['injury_better'] = '상처 하나가 나아졌습니다.',
    ['no_injuries'] = '치료할 상처가 없습니다.',
    ["need_item"] = "%s이(가) 필요합니다.",
    ["cannot_now"] = "지금은 그렇게 할 수 없습니다.",
    ["bandaging"] = "붕대 감는 중...",
    ["bandaged"] = "스스로 응급 처치를 했습니다.",
    ["lost_items"] = "지니고 있던 것을 모두 잃었습니다.",
    ['bleeding'] = '피를 흘리고 있습니다.',
    ['part_head'] = '머리',
    ['part_torso'] = '가슴',
    ['part_left_arm'] = '왼팔',
    ['part_right_arm'] = '오른팔',
    ['part_left_leg'] = '왼다리',
    ['part_right_leg'] = '오른다리',
    ['state_healthy'] = '건강함',
    ['state_injured'] = '다침',
    ['state_broken'] = '부러짐',
    ['state_bleeding'] = '출혈',

    -- hospitals
    ['place_valentine'] = 'Valentine 의원',
    ['place_blackwater'] = 'Blackwater 의원',
    ['place_strawberry'] = 'Strawberry 의원',
    ['place_armadillo'] = 'Armadillo 의원',
    ['place_tumbleweed'] = 'Tumbleweed 의원',
    ['place_saintdenis'] = 'Saint Denis 의원',
    ['place_rhodes'] = 'Rhodes 의원',
    ['place_vanhorn'] = 'Van Horn 의원',
    ['place_annesburg'] = 'Annesburg 의원',

    -- commands
    ['cmd_revive'] = '자신 또는 플레이어 살리기 (관리자)',
    ['cmd_heal'] = '자신 또는 플레이어 치료 (관리자)',
    ['cmd_kill'] = '플레이어 죽이기 (관리자)',
    ['cmd_id'] = '플레이어 ID',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) 사망',
    ['log_text'] = '%s 사망, 가해자: %s (원인 %s)',
    ['log_unknown'] = '알 수 없음',
}

-- MULTImedic: Tiếng Việt
Locales = Locales or {}
Locales['vi'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Bạn đã bất tỉnh',
    ['ui_sub'] = 'Chờ bác sĩ, hoặc chờ sức lực trở lại',
    ['ui_sub_ready'] = 'Bạn có thể đứng dậy rồi',
    ['ui_wait'] = 'Bạn có thể hồi sinh sau',
    ['ui_hold_respawn'] = 'Giữ để hồi sinh ở chỗ bác sĩ',
    ['ui_fee'] = "Tiền bác sĩ: $%s",
    ['ui_call'] = 'Gọi bác sĩ',
    ['ui_call_sending'] = 'Đang báo tin...',
    ['ui_call_sent'] = 'Đã cho người đi gọi bác sĩ',
    ['ui_call_none'] = 'Không bác sĩ nào trả lời',
    ['ui_call_wait'] = 'Bạn vừa gọi lúc nãy',
    ['ui_call_failed'] = 'Không gửi được lời gọi',
    ['ui_call_again'] = 'gọi lại sau %ss',
    ['ui_medics'] = 'Bác sĩ trong vùng: %s',
    ['ui_no_medics'] = 'Không có bác sĩ trực',

    -- respawn
    ['too_early'] = 'Bạn chưa đủ sức để đứng dậy.',
    ['respawned'] = 'Bạn tỉnh lại ở %s.',
    ['respawned_fee'] = 'Bạn tỉnh lại ở %s. Bác sĩ lấy $%s.',
    ['lost_cash'] = 'Tiền mặt của bạn đã mất.',
    ['lost_bloodmoney'] = 'Tiền máu của bạn đã mất.',

    -- doctor calls
    ['alert_text'] = '%s đã gục và cần bác sĩ',
    ['alert_default'] = 'Có người cần bác sĩ',
    ['doctor_called'] = 'Đã báo tin cho các bác sĩ.',
    ['no_medics'] = 'Hiện không có bác sĩ trực.',
    ['call_cooldown'] = 'Bạn vừa gọi xong. Chờ một chút.',

    -- medic actions
    ['reviving'] = 'Đang cứu tỉnh...',
    ['treating'] = 'Đang chữa vết thương...',
    ['target_revive'] = 'Cứu tỉnh',
    ['target_treat'] = 'Chữa vết thương',
    ['not_medic'] = 'Bạn không phải bác sĩ đang trực.',
    ['no_player'] = 'Không có người chơi ở đó.',
    ['nobody_down'] = 'Không ai gần bạn bị gục.',
    ['not_down'] = 'Người đó không bất tỉnh.',
    ['is_down'] = 'Người đó đang bất tỉnh; hãy cứu tỉnh trước.',
    ['too_far'] = 'Bạn ở quá xa.',
    ['you_revived'] = 'Bạn đã cứu tỉnh %s.',
    ['revived_by'] = '%s đã cứu bạn tỉnh lại.',
    ['you_treated'] = "Bạn đã chữa vết thương cho %s.",
    ['treated_by'] = '%s đã chữa vết thương cho bạn.',

    -- injuries
    ['injury_worse'] = 'Phần %s của bạn bị %s.',
    ['injury_better'] = 'Một vết thương của bạn đã đỡ hơn.',
    ['no_injuries'] = 'Bạn không có vết thương nào cần chữa.',
    ["need_item"] = "Bạn cần %s.",
    ["cannot_now"] = "Bây giờ bạn không thể làm việc đó.",
    ["bandaging"] = "Đang băng bó...",
    ["bandaged"] = "Bạn đã tự băng bó.",
    ["lost_items"] = "Mọi thứ bạn mang theo đã mất.",
    ['bleeding'] = 'Bạn đang chảy máu.',
    ['part_head'] = 'đầu',
    ['part_torso'] = 'ngực',
    ['part_left_arm'] = 'tay trái',
    ['part_right_arm'] = 'tay phải',
    ['part_left_leg'] = 'chân trái',
    ['part_right_leg'] = 'chân phải',
    ['state_healthy'] = 'lành lặn',
    ['state_injured'] = 'thương',
    ['state_broken'] = 'gãy',
    ['state_bleeding'] = 'chảy máu',

    -- hospitals
    ['place_valentine'] = 'phòng bác sĩ Valentine',
    ['place_blackwater'] = 'phòng bác sĩ Blackwater',
    ['place_strawberry'] = 'phòng bác sĩ Strawberry',
    ['place_armadillo'] = 'phòng bác sĩ Armadillo',
    ['place_tumbleweed'] = 'phòng bác sĩ Tumbleweed',
    ['place_saintdenis'] = 'phòng bác sĩ Saint Denis',
    ['place_rhodes'] = 'phòng bác sĩ Rhodes',
    ['place_vanhorn'] = 'phòng bác sĩ Van Horn',
    ['place_annesburg'] = 'phòng bác sĩ Annesburg',

    -- commands
    ['cmd_revive'] = 'Cứu tỉnh bản thân hoặc người chơi (admin)',
    ['cmd_heal'] = 'Chữa lành bản thân hoặc người chơi (admin)',
    ['cmd_kill'] = 'Giết một người chơi (admin)',
    ['cmd_id'] = 'ID người chơi',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) đã chết',
    ['log_text'] = '%s bị giết bởi %s (nguyên nhân %s)',
    ['log_unknown'] = 'không rõ',
}

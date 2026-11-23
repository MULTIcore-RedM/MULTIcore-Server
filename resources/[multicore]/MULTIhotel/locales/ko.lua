Locales = Locales or {}
Locales['ko'] = {
    -- general
    ['notify_title'] = "호텔",
    ['too_far'] = "프런트에서 너무 멀리 있습니다.",
    ['not_enough_money'] = "돈이 부족합니다.",
    ['bad_amount'] = "올바른 금액을 입력하세요.",
    ['not_owner'] = "이 방을 빌린 투숙객만 할 수 있습니다.",
    ['no_active_room'] = "호텔 방 안에 있지 않습니다.",

    -- hotels
    ['hotel_valentine'] = "Valentine 호텔",
    ['hotel_strawberry'] = "Strawberry 호텔",
    ['hotel_rhodes'] = "Rhodes 호텔",
    ['hotel_stdenis'] = "Saint Denis 호텔",
    ['hotel_blackwater'] = "Blackwater 호텔",
    ['hotel_tumbleweed'] = "Tumbleweed 호텔",
    ['hotel_annesburg'] = "Annesburg 호텔",

    -- renting and checking in
    ['already_have_room'] = "이미 이 호텔에 방이 있습니다.",
    ['no_free_room'] = "지금은 빈방이 없습니다. 나중에 다시 오세요.",
    ['rented'] = "%s호실을 빌렸습니다 (%s).",
    ['no_room_here'] = "이 호텔에 방이 없습니다.",
    ['not_a_guest'] = "이 호텔의 손님이 아닙니다.",
    ['guest_checked_in'] = "손님으로 %s호실에 체크인했습니다.",
    ['room_lost'] = "%s호실의 적립금이 바닥나 방을 내놓았습니다.",

    -- credit
    ['credit_too_high'] = "방에는 적립금을 최대 $%s까지 넣을 수 있습니다.",
    ['credit_added'] = "적립금 $%s을(를) 넣었습니다. 현재 적립금: $%s.",
    ['cannot_withdraw'] = "방에 있는 적립금보다 많이 꺼낼 수 없습니다.",
    ['credit_withdrawn'] = "적립금 $%s을(를) 꺼냈습니다. 현재 적립금: $%s.",

    -- locker
    ['locker_label'] = "%s호실 사물함",
    ['locker_failed'] = "방 사물함을 열 수 없었습니다.",

    -- guests
    ['player_not_found'] = "그 플레이어를 찾을 수 없습니다.",
    ['player_not_near'] = "그 플레이어가 충분히 가까이 있지 않습니다.",
    ['nobody_near'] = "초대할 만큼 가까이 있는 사람이 없습니다.",
    ['already_guest'] = "그 플레이어는 이미 손님입니다.",
    ['max_guests'] = "이 방은 이미 손님 수가 최대입니다 (%s).",
    ['guest_added'] = "%s 님이 이제 당신 방의 손님입니다.",
    ['guest_removed'] = "%s 님은 더 이상 당신 방의 손님이 아닙니다.",
    ['you_were_invited'] = "%s 님이 당신을 %s호실에 초대했습니다 (%s).",
    ['you_were_removed'] = "더 이상 %s호실의 손님이 아닙니다.",

    -- throwing guests out
    ['evict_cooldown'] = "다시 손님을 내보내려면 %s초 기다리세요.",
    ['no_guests_to_evict'] = "내보낼 손님이 없습니다.",
    ['evicted'] = "손님 %s명을 방에서 내보냈습니다.",
    ['evicted_and_removed'] = "손님 %s명을 내보내고 손님 목록에서 뺐습니다.",
    ['you_were_evicted'] = "%s 님이 당신을 방에서 내보냈습니다.",
    ['evict_confirm'] = "손님 %s명을 즉시 방에서 내보냅니다. 진행할까요?",

    -- telegrams
    ['telegram_sender'] = "호텔 프런트",
    ['tg_invite_subject'] = "호텔 방 초대",
    ['tg_invite_body'] = "%s 님이 당신을 %s호실에 초대했습니다 (%s). 프런트에서 손님으로 체크인하세요.",
    ['tg_evicted_subject'] = "호텔 방에서 쫓겨남",
    ['tg_evicted_body'] = "%s 님이 당신을 %s호실에서 내보냈습니다. 나중에 다시 손님으로 체크인할 수 있습니다.",
    ['tg_evicted_body_removed'] = "%s 님이 당신을 %s호실에서 내보내고 초대를 취소했습니다.",
    ['tg_low_subject'] = "방 적립금 부족",
    ['tg_low_body'] = "%s호실 (%s)의 적립금이 얼마 남지 않았습니다: $%s 남음. 방 메뉴에서 적립금을 넣으세요.",
    ['tg_lost_subject'] = "방을 내놓음",
    ['tg_lost_body'] = "%s호실 (%s)의 적립금이 바닥나 체크아웃되었습니다. 저희 호텔을 이용해 주셔서 감사합니다.",

    -- logs (MULTIserver)
    ['log_rented'] = "호텔 방 대여",
    ['log_evicted'] = "호텔 손님 내보냄",
    ['log_lost'] = "호텔 방 상실",

    -- desk menu
    ['menu_check_in'] = "체크인",
    ['menu_check_in_desc'] = "%s호실로 올라갑니다. 적립금: $%s",
    ['menu_rent'] = "방 빌리기 ($%s)",
    ['menu_rent_desc'] = "이 돈이 방의 첫 적립금이 됩니다.",
    ['menu_guest_check_in'] = "손님 체크인",
    ['menu_guest_check_in_desc'] = "초대받은 방으로 올라갑니다.",

    -- room menu
    ['room_title'] = "%s호실",
    ['badge_guest'] = "손님",
    ['menu_add_credit'] = "적립금 넣기",
    ['menu_credit_now'] = "현재 적립금: $%s",
    ['menu_remove_credit'] = "적립금 꺼내기",
    ['menu_remove_credit_desc'] = "방 적립금에서 돈을 돌려받습니다.",
    ['menu_guests'] = "손님",
    ['menu_guests_desc'] = "플레이어를 초대하거나 초대를 취소합니다.",
    ['menu_evict'] = "손님 내보내기",
    ['menu_evict_desc'] = "모든 손님을 즉시 방에서 내보냅니다.",
    ['menu_locker'] = "방 사물함",
    ['menu_locker_desc'] = "물건을 보관합니다.",
    ['menu_guest_access'] = "손님 이용",
    ['menu_owner'] = "%s 님의 방",
    ['menu_leave'] = "방 나가기",
    ['menu_leave_desc'] = "거리로 내려갑니다.",
    ['menu_mail'] = "전보",
    ['menu_mail_desc'] = "전보 읽고 보내기.",
    ['input_add_label'] = "넣을 금액 (현재 적립금: $%s)",
    ['input_remove_label'] = "꺼낼 금액 (현재 적립금: $%s)",

    -- guest menu
    ['menu_add_guest'] = "플레이어 초대",
    ['menu_add_guest_desc'] = "가까이 있는 플레이어.",
    ['menu_current_guests'] = "손님",
    ['menu_no_guests'] = "손님 없음",
    ['menu_no_guests_desc'] = "아직 아무도 초대하지 않았습니다.",
    ['menu_guest_row'] = "%s 님 초대됨. 선택하면 초대를 취소합니다.",
    ['menu_invite'] = "플레이어 초대",
    ['menu_invite_row'] = "ID %s. 선택하면 초대합니다.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "방 메뉴",
    ['target_desk'] = "프런트",
    ['target_room'] = "방 메뉴",

    -- page
    ['ui_subtitle'] = "손님 서비스",
    ['ui_back'] = "뒤로",
    ['ui_close'] = "닫기",
    ['ui_cancel'] = "취소",
    ['ui_confirm'] = "확인",
    ['ui_amount'] = "금액",
    ['ui_max'] = "최대",
    ['ui_valid_amount'] = "올바른 금액을 입력하세요",
    ['ui_success'] = "성공",
    ['ui_error'] = "오류",
    ['ui_info'] = "정보",
    ['ui_notice'] = "알림",
}

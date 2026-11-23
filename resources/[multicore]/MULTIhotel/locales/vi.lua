Locales = Locales or {}
Locales['vi'] = {
    -- general
    ['notify_title'] = "Khách sạn",
    ['too_far'] = "Bạn ở quá xa quầy lễ tân.",
    ['not_enough_money'] = "Bạn không đủ tiền.",
    ['bad_amount'] = "Nhập số tiền hợp lệ.",
    ['not_owner'] = "Chỉ khách đã thuê phòng này mới làm được việc đó.",
    ['no_active_room'] = "Bạn không ở trong phòng khách sạn.",

    -- hotels
    ['hotel_valentine'] = "Khách sạn Valentine",
    ['hotel_strawberry'] = "Khách sạn Strawberry",
    ['hotel_rhodes'] = "Khách sạn Rhodes",
    ['hotel_stdenis'] = "Khách sạn Saint Denis",
    ['hotel_blackwater'] = "Khách sạn Blackwater",
    ['hotel_tumbleweed'] = "Khách sạn Tumbleweed",
    ['hotel_annesburg'] = "Khách sạn Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Bạn đã có phòng ở khách sạn này.",
    ['no_free_room'] = "Hiện không còn phòng trống. Hãy thử lại sau.",
    ['rented'] = "Bạn đã thuê phòng %s tại %s.",
    ['no_room_here'] = "Bạn không có phòng ở khách sạn này.",
    ['not_a_guest'] = "Bạn không phải khách của khách sạn này.",
    ['guest_checked_in'] = "Đã nhận phòng %s với tư cách khách.",
    ['room_lost'] = "Phòng %s của bạn đã hết quỹ phòng và đã bị trả lại.",

    -- credit
    ['credit_too_high'] = "Một phòng chỉ giữ tối đa $%s quỹ phòng.",
    ['credit_added'] = "Đã thêm $%s vào quỹ phòng. Quỹ hiện có: $%s.",
    ['cannot_withdraw'] = "Bạn không thể rút nhiều hơn số quỹ phòng đang có.",
    ['credit_withdrawn'] = "Đã rút $%s từ quỹ phòng. Quỹ hiện có: $%s.",

    -- locker
    ['locker_label'] = "Tủ đồ phòng %s",
    ['locker_failed'] = "Không mở được tủ đồ của phòng.",

    -- guests
    ['player_not_found'] = "Không tìm thấy người chơi đó.",
    ['player_not_near'] = "Người chơi đó không ở đủ gần.",
    ['nobody_near'] = "Không có ai đủ gần để mời.",
    ['already_guest'] = "Người chơi đó đã là khách.",
    ['max_guests'] = "Phòng này đã đủ số khách tối đa (%s).",
    ['guest_added'] = "%s giờ là khách của phòng bạn.",
    ['guest_removed'] = "%s không còn là khách của phòng bạn.",
    ['you_were_invited'] = "%s đã mời bạn đến phòng %s tại %s.",
    ['you_were_removed'] = "Bạn không còn là khách của phòng %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Hãy đợi %s giây trước khi đuổi khách lần nữa.",
    ['no_guests_to_evict'] = "Không có khách nào để đuổi.",
    ['evicted'] = "Đã đuổi %s khách ra khỏi phòng bạn.",
    ['evicted_and_removed'] = "Đã đuổi %s khách và xóa khỏi danh sách khách.",
    ['you_were_evicted'] = "%s đã đuổi bạn ra khỏi phòng.",
    ['evict_confirm'] = "Việc này sẽ đưa %s khách ra khỏi phòng bạn ngay lập tức. Tiếp tục?",

    -- telegrams
    ['telegram_sender'] = "Lễ tân khách sạn",
    ['tg_invite_subject'] = "Lời mời vào phòng khách sạn",
    ['tg_invite_body'] = "%s đã mời bạn đến phòng %s tại %s. Hãy hỏi quầy lễ tân để nhận phòng với tư cách khách.",
    ['tg_evicted_subject'] = "Bị đuổi khỏi phòng khách sạn",
    ['tg_evicted_body'] = "%s đã đuổi bạn ra khỏi phòng %s. Sau này bạn vẫn có thể nhận phòng với tư cách khách.",
    ['tg_evicted_body_removed'] = "%s đã đuổi bạn ra khỏi phòng %s và rút lại lời mời của bạn.",
    ['tg_low_subject'] = "Quỹ phòng sắp hết",
    ['tg_low_body'] = "Quỹ của phòng %s tại %s sắp hết: còn $%s. Hãy thêm quỹ ở menu phòng.",
    ['tg_lost_subject'] = "Phòng đã bị trả lại",
    ['tg_lost_body'] = "Phòng %s tại %s đã hết quỹ phòng nên bạn đã được trả phòng. Cảm ơn bạn đã lưu trú cùng chúng tôi.",

    -- logs (MULTIserver)
    ['log_rented'] = "Đã thuê phòng khách sạn",
    ['log_evicted'] = "Đã đuổi khách khách sạn",
    ['log_lost'] = "Mất phòng khách sạn",

    -- desk menu
    ['menu_check_in'] = "Nhận phòng",
    ['menu_check_in_desc'] = "Lên phòng %s. Quỹ phòng: $%s",
    ['menu_rent'] = "Thuê phòng ($%s)",
    ['menu_rent_desc'] = "Số tiền này trở thành quỹ đầu tiên của phòng bạn.",
    ['menu_guest_check_in'] = "Khách nhận phòng",
    ['menu_guest_check_in_desc'] = "Lên phòng mà bạn được mời.",

    -- room menu
    ['room_title'] = "Phòng %s",
    ['badge_guest'] = "Khách",
    ['menu_add_credit'] = "Thêm quỹ phòng",
    ['menu_credit_now'] = "Quỹ hiện có: $%s",
    ['menu_remove_credit'] = "Rút quỹ phòng",
    ['menu_remove_credit_desc'] = "Lấy lại tiền từ quỹ phòng.",
    ['menu_guests'] = "Khách",
    ['menu_guests_desc'] = "Mời người chơi hoặc rút lại lời mời.",
    ['menu_evict'] = "Đuổi khách",
    ['menu_evict_desc'] = "Đưa mọi khách ra khỏi phòng ngay lập tức.",
    ['menu_locker'] = "Tủ đồ phòng",
    ['menu_locker_desc'] = "Cất đồ của bạn.",
    ['menu_guest_access'] = "Quyền của khách",
    ['menu_owner'] = "Phòng của %s",
    ['menu_leave'] = "Rời phòng",
    ['menu_leave_desc'] = "Xuống lại đường phố.",
    ['menu_mail'] = "Điện tín",
    ['menu_mail_desc'] = "Đọc và gửi điện tín.",
    ['input_add_label'] = "Số tiền thêm (quỹ hiện có: $%s)",
    ['input_remove_label'] = "Số tiền rút (quỹ hiện có: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Mời người chơi",
    ['menu_add_guest_desc'] = "Người chơi ở gần bạn.",
    ['menu_current_guests'] = "Khách",
    ['menu_no_guests'] = "Không có khách",
    ['menu_no_guests_desc'] = "Bạn chưa mời ai.",
    ['menu_guest_row'] = "Đã mời %s. Chọn để rút lại lời mời.",
    ['menu_invite'] = "Mời người chơi",
    ['menu_invite_row'] = "ID %s. Chọn để mời.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Menu phòng",
    ['target_desk'] = "Quầy lễ tân",
    ['target_room'] = "Menu phòng",

    -- page
    ['ui_subtitle'] = "Dịch vụ khách",
    ['ui_back'] = "Quay lại",
    ['ui_close'] = "Đóng",
    ['ui_cancel'] = "Hủy",
    ['ui_confirm'] = "Xác nhận",
    ['ui_amount'] = "Số tiền",
    ['ui_max'] = "Tối đa",
    ['ui_valid_amount'] = "Vui lòng nhập số tiền hợp lệ",
    ['ui_success'] = "Thành công",
    ['ui_error'] = "Lỗi",
    ['ui_info'] = "Thông tin",
    ['ui_notice'] = "Thông báo",
}

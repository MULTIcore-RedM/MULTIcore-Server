Locales = Locales or {}
Locales['th'] = {
    -- general
    ['notify_title'] = "โรงแรม",
    ['too_far'] = "คุณอยู่ไกลจากเคาน์เตอร์ต้อนรับเกินไป",
    ['not_enough_money'] = "คุณมีเงินไม่พอ",
    ['bad_amount'] = "ใส่จำนวนเงินให้ถูกต้อง",
    ['not_owner'] = "เฉพาะแขกที่เช่าห้องนี้เท่านั้นที่ทำได้",
    ['no_active_room'] = "คุณไม่ได้อยู่ในห้องพักโรงแรม",

    -- hotels
    ['hotel_valentine'] = "โรงแรม Valentine",
    ['hotel_strawberry'] = "โรงแรม Strawberry",
    ['hotel_rhodes'] = "โรงแรม Rhodes",
    ['hotel_stdenis'] = "โรงแรม Saint Denis",
    ['hotel_blackwater'] = "โรงแรม Blackwater",
    ['hotel_tumbleweed'] = "โรงแรม Tumbleweed",
    ['hotel_annesburg'] = "โรงแรม Annesburg",

    -- renting and checking in
    ['already_have_room'] = "คุณมีห้องที่โรงแรมนี้อยู่แล้ว",
    ['no_free_room'] = "ตอนนี้ไม่มีห้องว่าง ลองใหม่ภายหลัง",
    ['rented'] = "คุณเช่าห้อง %s ที่ %s แล้ว",
    ['no_room_here'] = "คุณไม่มีห้องที่โรงแรมนี้",
    ['not_a_guest'] = "คุณไม่ใช่แขกของโรงแรมนี้",
    ['guest_checked_in'] = "เช็กอินเป็นแขกเข้าห้อง %s แล้ว",
    ['room_lost'] = "ห้อง %s ของคุณเงินล่วงหน้าหมด จึงถูกคืนห้องแล้ว",

    -- credit
    ['credit_too_high'] = "ห้องหนึ่งเก็บเงินล่วงหน้าได้มากสุด $%s",
    ['credit_added'] = "เติมเงินล่วงหน้า $%s แล้ว ยอดตอนนี้: $%s",
    ['cannot_withdraw'] = "ถอนเงินล่วงหน้าเกินยอดที่ห้องมีไม่ได้",
    ['credit_withdrawn'] = "ถอนเงินล่วงหน้า $%s แล้ว ยอดตอนนี้: $%s",

    -- locker
    ['locker_label'] = "ตู้เก็บของห้อง %s",
    ['locker_failed'] = "เปิดตู้เก็บของในห้องไม่ได้",

    -- guests
    ['player_not_found'] = "ไม่พบผู้เล่นคนนั้น",
    ['player_not_near'] = "ผู้เล่นคนนั้นอยู่ไม่ใกล้พอ",
    ['nobody_near'] = "ไม่มีใครอยู่ใกล้พอที่จะเชิญ",
    ['already_guest'] = "ผู้เล่นคนนั้นเป็นแขกอยู่แล้ว",
    ['max_guests'] = "ห้องนี้มีแขกครบจำนวนสูงสุดแล้ว (%s)",
    ['guest_added'] = "%s เป็นแขกของห้องคุณแล้ว",
    ['guest_removed'] = "%s ไม่ได้เป็นแขกของห้องคุณอีกต่อไป",
    ['you_were_invited'] = "%s เชิญคุณไปที่ห้อง %s ที่ %s",
    ['you_were_removed'] = "คุณไม่ได้เป็นแขกของห้อง %s อีกต่อไป",

    -- throwing guests out
    ['evict_cooldown'] = "รอ %s วินาทีก่อนไล่แขกออกอีกครั้ง",
    ['no_guests_to_evict'] = "ไม่มีแขกให้ไล่ออก",
    ['evicted'] = "ไล่แขก %s คนออกจากห้องของคุณแล้ว",
    ['evicted_and_removed'] = "ไล่แขก %s คนออกและลบออกจากรายชื่อแขกแล้ว",
    ['you_were_evicted'] = "%s ไล่คุณออกจากห้อง",
    ['evict_confirm'] = "จะส่งแขก %s คนออกจากห้องของคุณทันที ดำเนินการต่อไหม?",

    -- telegrams
    ['telegram_sender'] = "แผนกต้อนรับโรงแรม",
    ['tg_invite_subject'] = "คำเชิญเข้าห้องพักโรงแรม",
    ['tg_invite_body'] = "%s เชิญคุณไปที่ห้อง %s ที่ %s ติดต่อเคาน์เตอร์ต้อนรับเพื่อเช็กอินเป็นแขก",
    ['tg_evicted_subject'] = "ถูกไล่ออกจากห้องพักโรงแรม",
    ['tg_evicted_body'] = "%s ไล่คุณออกจากห้อง %s คุณยังเช็กอินเป็นแขกได้ในภายหลัง",
    ['tg_evicted_body_removed'] = "%s ไล่คุณออกจากห้อง %s และยกเลิกคำเชิญของคุณ",
    ['tg_low_subject'] = "เงินล่วงหน้าของห้องใกล้หมด",
    ['tg_low_body'] = "เงินล่วงหน้าของห้อง %s ที่ %s ใกล้หมด: เหลือ $%s เติมเงินได้ที่เมนูห้อง",
    ['tg_lost_subject'] = "คืนห้องแล้ว",
    ['tg_lost_body'] = "ห้อง %s ที่ %s เงินล่วงหน้าหมด คุณจึงถูกเช็กเอาต์แล้ว ขอบคุณที่เข้าพักกับเรา",

    -- logs (MULTIserver)
    ['log_rented'] = "เช่าห้องพักโรงแรม",
    ['log_evicted'] = "ไล่แขกโรงแรมออก",
    ['log_lost'] = "เสียห้องพักโรงแรม",

    -- desk menu
    ['menu_check_in'] = "เช็กอิน",
    ['menu_check_in_desc'] = "ขึ้นไปที่ห้อง %s เงินล่วงหน้า: $%s",
    ['menu_rent'] = "เช่าห้อง ($%s)",
    ['menu_rent_desc'] = "เงินนี้จะเป็นเงินล่วงหน้าก้อนแรกของห้อง",
    ['menu_guest_check_in'] = "เช็กอินแขก",
    ['menu_guest_check_in_desc'] = "ขึ้นไปที่ห้องที่คุณได้รับเชิญ",

    -- room menu
    ['room_title'] = "ห้อง %s",
    ['badge_guest'] = "แขก",
    ['menu_add_credit'] = "เติมเงินล่วงหน้า",
    ['menu_credit_now'] = "ยอดตอนนี้: $%s",
    ['menu_remove_credit'] = "ถอนเงินล่วงหน้า",
    ['menu_remove_credit_desc'] = "รับเงินคืนจากเงินล่วงหน้าของห้อง",
    ['menu_guests'] = "แขก",
    ['menu_guests_desc'] = "เชิญผู้เล่นหรือยกเลิกคำเชิญ",
    ['menu_evict'] = "ไล่แขกออก",
    ['menu_evict_desc'] = "ส่งแขกทุกคนออกจากห้องทันที",
    ['menu_locker'] = "ตู้เก็บของในห้อง",
    ['menu_locker_desc'] = "เก็บของของคุณ",
    ['menu_guest_access'] = "สิทธิ์ของแขก",
    ['menu_owner'] = "ห้องของ %s",
    ['menu_leave'] = "ออกจากห้อง",
    ['menu_leave_desc'] = "ลงกลับไปที่ถนน",
    ['menu_mail'] = "โทรเลข",
    ['menu_mail_desc'] = "อ่านและส่งโทรเลข",
    ['input_add_label'] = "จำนวนที่จะเติม (ยอดตอนนี้: $%s)",
    ['input_remove_label'] = "จำนวนที่จะถอน (ยอดตอนนี้: $%s)",

    -- guest menu
    ['menu_add_guest'] = "เชิญผู้เล่น",
    ['menu_add_guest_desc'] = "ผู้เล่นที่อยู่ใกล้คุณ",
    ['menu_current_guests'] = "แขก",
    ['menu_no_guests'] = "ไม่มีแขก",
    ['menu_no_guests_desc'] = "คุณยังไม่ได้เชิญใครเลย",
    ['menu_guest_row'] = "เชิญ %s แล้ว เลือกเพื่อยกเลิกคำเชิญ",
    ['menu_invite'] = "เชิญผู้เล่น",
    ['menu_invite_row'] = "ID %s เลือกเพื่อเชิญ",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "เมนูห้อง",
    ['target_desk'] = "เคาน์เตอร์ต้อนรับ",
    ['target_room'] = "เมนูห้อง",

    -- page
    ['ui_subtitle'] = "บริการแขก",
    ['ui_back'] = "กลับ",
    ['ui_close'] = "ปิด",
    ['ui_cancel'] = "ยกเลิก",
    ['ui_confirm'] = "ยืนยัน",
    ['ui_amount'] = "จำนวนเงิน",
    ['ui_max'] = "สูงสุด",
    ['ui_valid_amount'] = "กรุณาใส่จำนวนเงินให้ถูกต้อง",
    ['ui_success'] = "สำเร็จ",
    ['ui_error'] = "ผิดพลาด",
    ['ui_info'] = "ข้อมูล",
    ['ui_notice'] = "แจ้งเตือน",
}

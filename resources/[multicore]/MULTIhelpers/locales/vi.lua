-- MULTIhelpers :: vi
Locales = Locales or {}
Locales['vi'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Xác nhận",
    ['cancel'] = "Hủy",
    ['yes'] = "Có",
    ['no'] = "Không",
    -- key hints under a menu
    ['key_move'] = "Di chuyển",
    ['key_change'] = "Đổi",
    ['key_next'] = "Tiếp",
    ['key_select'] = "Chọn",
    ['key_back'] = "Quay lại",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Không được phép",
    ['err_letters'] = "Chỉ chữ cái",
    ['err_numbers'] = "Chỉ chữ số",
    ['err_alphanumeric'] = "Chỉ chữ cái và chữ số",
    ['err_no_symbols'] = "Không dùng ký hiệu",
    ['err_username'] = "Ít nhất 3 ký tự: chữ, số, _ . hoặc -",
    ['err_phone'] = "Chỉ số, dấu cách và + - ( )",
    ['err_email'] = "Không phải địa chỉ e-mail",
    ['err_money'] = "Một số tiền, ví dụ 12.50",
    ['err_no_special'] = "Không dùng ký tự đặc biệt",
    -- console lines for the server owner
    ['warn_running'] = "%s đang chạy - hãy xóa \"ensure %s\" khỏi server.cfg, MULTIhelpers sẽ thay thế nó.",
    ['warn_started'] = "%s khởi động cùng MULTIhelpers - hãy xóa \"ensure %s\" khỏi server.cfg.",
    ['callback_error'] = "lỗi callback: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Nhấn %s trong vùng được đánh dấu",
    ['progress_busy'] = "Bạn đang bận làm việc khác",
    ['progress_dead'] = "Không thể làm điều đó khi đã chết",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Búa",
    ["mg_paper"] = "Bao",
    ["mg_scissors"] = "Kéo",
    ["mg_win"] = "Bạn thắng",
    ["mg_lose"] = "Bạn thua",
    ["mg_tie"] = "Hòa",
}

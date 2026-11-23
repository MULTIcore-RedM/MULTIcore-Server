-- MULTIhelpers :: th (same keys as the English master)
Locales = Locales or {}
Locales['th'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "ยืนยัน",
    ['cancel'] = "ยกเลิก",
    ['yes'] = "ใช่",
    ['no'] = "ไม่",
    -- key hints under a menu
    ['key_move'] = "เลื่อน",
    ['key_change'] = "เปลี่ยน",
    ['key_next'] = "ถัดไป",
    ['key_select'] = "เลือก",
    ['key_back'] = "กลับ",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "ไม่อนุญาต",
    ['err_letters'] = "ตัวอักษรเท่านั้น",
    ['err_numbers'] = "ตัวเลขเท่านั้น",
    ['err_alphanumeric'] = "ตัวอักษรและตัวเลขเท่านั้น",
    ['err_no_symbols'] = "ห้ามใช้สัญลักษณ์",
    ['err_username'] = "อย่างน้อย 3 ตัว ใช้ตัวอักษร ตัวเลข _ . หรือ -",
    ['err_phone'] = "ตัวเลข ช่องว่าง และ + - ( ) เท่านั้น",
    ['err_email'] = "ไม่ใช่ที่อยู่อีเมล",
    ['err_money'] = "จำนวนเงิน เช่น 12.50",
    ['err_no_special'] = "ห้ามใช้อักขระพิเศษ",
    -- console lines for the server owner
    ['warn_running'] = "%s กำลังทำงาน - ลบ \"ensure %s\" ออกจาก server.cfg เพราะ MULTIhelpers ทำหน้าที่แทนแล้ว",
    ['warn_started'] = "%s เริ่มทำงานพร้อมกับ MULTIhelpers - ลบ \"ensure %s\" ออกจาก server.cfg",
    ['callback_error'] = "callback ผิดพลาด: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "กด %s ในช่วงที่ทำเครื่องหมายไว้",
    ['progress_busy'] = "คุณกำลังทำอย่างอื่นอยู่",
    ['progress_dead'] = "ทำแบบนั้นไม่ได้ขณะที่ตายอยู่",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "ค้อน",
    ["mg_paper"] = "กระดาษ",
    ["mg_scissors"] = "กรรไกร",
    ["mg_win"] = "คุณชนะ",
    ["mg_lose"] = "คุณแพ้",
    ["mg_tie"] = "เสมอ",
}

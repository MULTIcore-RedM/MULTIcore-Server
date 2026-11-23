-- MULTIhelpers :: ko
Locales = Locales or {}
Locales['ko'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "확인",
    ['cancel'] = "취소",
    ['yes'] = "예",
    ['no'] = "아니요",
    -- key hints under a menu
    ['key_move'] = "이동",
    ['key_change'] = "변경",
    ['key_next'] = "다음",
    ['key_select'] = "선택",
    ['key_back'] = "뒤로",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "허용되지 않음",
    ['err_letters'] = "글자만 가능",
    ['err_numbers'] = "숫자만 가능",
    ['err_alphanumeric'] = "글자와 숫자만 가능",
    ['err_no_symbols'] = "기호 사용 불가",
    ['err_username'] = "글자, 숫자, _ . - 로 3자 이상",
    ['err_phone'] = "숫자, 공백, + - ( ) 만 가능",
    ['err_email'] = "이메일 주소가 아닙니다",
    ['err_money'] = "금액 (예: 12.50)",
    ['err_no_special'] = "특수 문자 사용 불가",
    -- console lines for the server owner
    ['warn_running'] = "%s 실행 중 - server.cfg에서 \"ensure %s\"를 지우세요. MULTIhelpers가 대신합니다.",
    ['warn_started'] = "%s이(가) MULTIhelpers와 함께 시작됨 - server.cfg에서 \"ensure %s\"를 지우세요.",
    ['callback_error'] = "콜백 오류: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "표시된 구간에서 %s 키를 눌러",
    ['progress_busy'] = "이미 다른 일을 하는 중이다",
    ['progress_dead'] = "죽은 상태에서는 할 수 없다",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "바위",
    ["mg_paper"] = "보",
    ["mg_scissors"] = "가위",
    ["mg_win"] = "이겼습니다",
    ["mg_lose"] = "졌습니다",
    ["mg_tie"] = "비겼습니다",
}

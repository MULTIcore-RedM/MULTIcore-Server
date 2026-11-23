-- MULTIhelpers :: ja (Japanese)
Locales = Locales or {}
Locales['ja'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "決定",
    ['cancel'] = "キャンセル",
    ['yes'] = "はい",
    ['no'] = "いいえ",
    -- key hints under a menu
    ['key_move'] = "移動",
    ['key_change'] = "変更",
    ['key_next'] = "次へ",
    ['key_select'] = "選択",
    ['key_back'] = "戻る",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "使用できない",
    ['err_letters'] = "文字のみ",
    ['err_numbers'] = "数字のみ",
    ['err_alphanumeric'] = "文字と数字のみ",
    ['err_no_symbols'] = "記号は使えない",
    ['err_username'] = "3文字以上: 文字、数字、_ . -",
    ['err_phone'] = "数字、空白、+ - ( ) のみ",
    ['err_email'] = "メールアドレスではない",
    ['err_money'] = "金額を入力（例: 12.50）",
    ['err_no_special'] = "特殊文字は使えない",
    -- console lines for the server owner
    ['warn_running'] = "%s が動作中 - server.cfg から \"ensure %s\" を削除してくれ。MULTIhelpers が代わりを務める。",
    ['warn_started'] = "%s が MULTIhelpers と一緒に起動した - server.cfg から \"ensure %s\" を削除してくれ。",
    ['callback_error'] = "コールバックエラー: %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "マークされた範囲で %s を押せ",
    ['progress_busy'] = "もう別のことをしている",
    ['progress_dead'] = "死んでいる間はできない",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "グー",
    ["mg_paper"] = "パー",
    ["mg_scissors"] = "チョキ",
    ["mg_win"] = "あなたの勝ち",
    ["mg_lose"] = "あなたの負け",
    ["mg_tie"] = "あいこ",
}

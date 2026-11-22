-- MULTIhelpers :: zh (Chinese, Simplified)
Locales = Locales or {}
Locales['zh'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "确认",
    ['cancel'] = "取消",
    ['yes'] = "是",
    ['no'] = "否",
    -- key hints under a menu
    ['key_move'] = "移动",
    ['key_change'] = "更改",
    ['key_next'] = "下一个",
    ['key_select'] = "选择",
    ['key_back'] = "返回",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "不允许",
    ['err_letters'] = "只能输入字母",
    ['err_numbers'] = "只能输入数字",
    ['err_alphanumeric'] = "只能输入字母和数字",
    ['err_no_symbols'] = "不能有符号",
    ['err_username'] = "至少 3 个字符：字母、数字、_ . 或 -",
    ['err_phone'] = "只能输入数字、空格和 + - ( )",
    ['err_email'] = "不是电子邮件地址",
    ['err_money'] = "请输入金额，如 12.50",
    ['err_no_special'] = "不能有特殊字符",
    -- console lines for the server owner
    ['warn_running'] = "%s 正在运行 - 请从 server.cfg 中删除 \"ensure %s\"，MULTIhelpers 会代替它。",
    ['warn_started'] = "%s 与 MULTIhelpers 一起启动了 - 请从 server.cfg 中删除 \"ensure %s\"。",
    ['callback_error'] = "回调错误：%s",
}

Locales = Locales or {}
Locales['zh'] = {
    -- general
    ['notify_title'] = "旅馆",
    ['too_far'] = "你离前台太远了。",
    ['not_enough_money'] = "你的钱不够。",
    ['bad_amount'] = "请输入有效金额。",
    ['not_owner'] = "只有租下这间房的住客才能这么做。",
    ['no_active_room'] = "你不在旅馆房间里。",

    -- hotels
    ['hotel_valentine'] = "Valentine 旅馆",
    ['hotel_strawberry'] = "Strawberry 旅馆",
    ['hotel_rhodes'] = "Rhodes 旅馆",
    ['hotel_stdenis'] = "Saint Denis 旅馆",
    ['hotel_blackwater'] = "Blackwater 旅馆",
    ['hotel_tumbleweed'] = "Tumbleweed 旅馆",
    ['hotel_annesburg'] = "Annesburg 旅馆",

    -- renting and checking in
    ['already_have_room'] = "你在这家旅馆已经有房间了。",
    ['no_free_room'] = "现在没有空房。请稍后再试。",
    ['rented'] = "你租下了 %s 号房（%s）。",
    ['no_room_here'] = "你在这家旅馆没有房间。",
    ['not_a_guest'] = "你不是这家旅馆的客人。",
    ['guest_checked_in'] = "已作为客人入住 %s 号房。",
    ['room_lost'] = "你的 %s 号房预存金已用完，房间已退掉。",

    -- credit
    ['credit_too_high'] = "一间房最多只能预存 $%s。",
    ['credit_added'] = "已预存 $%s。当前预存金：$%s。",
    ['cannot_withdraw'] = "取出的金额不能超过房间的预存金。",
    ['credit_withdrawn'] = "已取出预存金 $%s。当前预存金：$%s。",

    -- locker
    ['locker_label'] = "%s 号房储物柜",
    ['locker_failed'] = "无法打开房间储物柜。",

    -- guests
    ['player_not_found'] = "找不到该玩家。",
    ['player_not_near'] = "该玩家离你不够近。",
    ['nobody_near'] = "附近没有可以邀请的人。",
    ['already_guest'] = "该玩家已经是客人了。",
    ['max_guests'] = "这间房的客人已达上限（%s）。",
    ['guest_added'] = "%s 现在是你房间的客人。",
    ['guest_removed'] = "%s 不再是你房间的客人。",
    ['you_were_invited'] = "%s 邀请你去 %s 号房（%s）。",
    ['you_were_removed'] = "你不再是 %s 号房的客人。",

    -- throwing guests out
    ['evict_cooldown'] = "请等待 %s 秒后再赶走客人。",
    ['no_guests_to_evict'] = "没有可赶走的客人。",
    ['evicted'] = "已将 %s 位客人赶出你的房间。",
    ['evicted_and_removed'] = "已赶走 %s 位客人并将其移出客人名单。",
    ['you_were_evicted'] = "%s 把你赶出了房间。",
    ['evict_confirm'] = "这会立即把 %s 位客人请出你的房间。确定吗？",

    -- telegrams
    ['telegram_sender'] = "旅馆前台",
    ['tg_invite_subject'] = "旅馆房间邀请",
    ['tg_invite_body'] = "%s 邀请你去 %s 号房（%s）。请到前台以客人身份入住。",
    ['tg_evicted_subject'] = "被赶出旅馆房间",
    ['tg_evicted_body'] = "%s 把你赶出了 %s 号房。之后你仍可以客人身份入住。",
    ['tg_evicted_body_removed'] = "%s 把你赶出了 %s 号房，并收回了你的邀请。",
    ['tg_low_subject'] = "房间预存金不足",
    ['tg_low_body'] = "%s 号房（%s）的预存金不足：仅剩 $%s。请在房间菜单中预存。",
    ['tg_lost_subject'] = "房间已退",
    ['tg_lost_body'] = "%s 号房（%s）的预存金已用完，你已退房。感谢你的光临。",

    -- logs (MULTIserver)
    ['log_rented'] = "旅馆房间已租出",
    ['log_evicted'] = "旅馆客人被赶走",
    ['log_lost'] = "旅馆房间已失去",

    -- desk menu
    ['menu_check_in'] = "入住",
    ['menu_check_in_desc'] = "上楼去 %s 号房。预存金：$%s",
    ['menu_rent'] = "租一间房（$%s）",
    ['menu_rent_desc'] = "这笔钱将成为房间的首笔预存金。",
    ['menu_guest_check_in'] = "客人入住",
    ['menu_guest_check_in_desc'] = "上楼去你受邀的房间。",

    -- room menu
    ['room_title'] = "%s 号房",
    ['badge_guest'] = "客人",
    ['menu_add_credit'] = "增加预存金",
    ['menu_credit_now'] = "当前预存金：$%s",
    ['menu_remove_credit'] = "取出预存金",
    ['menu_remove_credit_desc'] = "从房间预存金中取回钱。",
    ['menu_guests'] = "客人",
    ['menu_guests_desc'] = "邀请玩家或收回邀请。",
    ['menu_evict'] = "赶走客人",
    ['menu_evict_desc'] = "立即把所有客人请出房间。",
    ['menu_locker'] = "房间储物柜",
    ['menu_locker_desc'] = "存放你的物品。",
    ['menu_guest_access'] = "客人权限",
    ['menu_owner'] = "%s 的房间",
    ['menu_leave'] = "离开房间",
    ['menu_leave_desc'] = "下楼回到街上。",
    ['menu_mail'] = "电报",
    ['menu_mail_desc'] = "阅读和发送电报。",
    ['input_add_label'] = "增加金额（当前预存金：$%s）",
    ['input_remove_label'] = "取出金额（当前预存金：$%s）",

    -- guest menu
    ['menu_add_guest'] = "邀请玩家",
    ['menu_add_guest_desc'] = "你附近的玩家。",
    ['menu_current_guests'] = "客人",
    ['menu_no_guests'] = "没有客人",
    ['menu_no_guests_desc'] = "你还没有邀请任何人。",
    ['menu_guest_row'] = "已邀请 %s。选择以收回邀请。",
    ['menu_invite'] = "邀请玩家",
    ['menu_invite_row'] = "ID %s。选择以邀请。",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "房间菜单",
    ['target_desk'] = "前台",
    ['target_room'] = "房间菜单",

    -- page
    ['ui_subtitle'] = "宾客服务",
    ['ui_back'] = "返回",
    ['ui_close'] = "关闭",
    ['ui_cancel'] = "取消",
    ['ui_confirm'] = "确认",
    ['ui_amount'] = "金额",
    ['ui_max'] = "最大",
    ['ui_valid_amount'] = "请输入有效金额",
    ['ui_success'] = "成功",
    ['ui_error'] = "错误",
    ['ui_info'] = "信息",
    ['ui_notice'] = "提示",
}

Locales = Locales or {}
Locales['ja'] = {
    -- general
    ['notify_title'] = "ホテル",
    ['too_far'] = "フロントから離れすぎています。",
    ['not_enough_money'] = "お金が足りません。",
    ['bad_amount'] = "正しい金額を入力してください。",
    ['not_owner'] = "この部屋を借りた宿泊客しかできません。",
    ['no_active_room'] = "ホテルの部屋にいません。",

    -- hotels
    ['hotel_valentine'] = "Valentine ホテル",
    ['hotel_strawberry'] = "Strawberry ホテル",
    ['hotel_rhodes'] = "Rhodes ホテル",
    ['hotel_stdenis'] = "Saint Denis ホテル",
    ['hotel_blackwater'] = "Blackwater ホテル",
    ['hotel_tumbleweed'] = "Tumbleweed ホテル",
    ['hotel_annesburg'] = "Annesburg ホテル",

    -- renting and checking in
    ['already_have_room'] = "このホテルにはすでに部屋があります。",
    ['no_free_room'] = "今は空き部屋がありません。後でもう一度どうぞ。",
    ['rented'] = "%s 号室を借りました（%s）。",
    ['no_room_here'] = "このホテルに部屋がありません。",
    ['not_a_guest'] = "このホテルの客ではありません。",
    ['guest_checked_in'] = "客として %s 号室にチェックインしました。",
    ['room_lost'] = "%s 号室の積立金が尽きたため、部屋を手放しました。",

    -- credit
    ['credit_too_high'] = "部屋に積み立てられるのは最大 $%s までです。",
    ['credit_added'] = "$%s を積み立てました。積立金：$%s。",
    ['cannot_withdraw'] = "部屋の積立金より多くは引き出せません。",
    ['credit_withdrawn'] = "積立金から $%s を引き出しました。積立金：$%s。",

    -- locker
    ['locker_label'] = "%s 号室のロッカー",
    ['locker_failed'] = "部屋のロッカーを開けられませんでした。",

    -- guests
    ['player_not_found'] = "そのプレイヤーが見つかりません。",
    ['player_not_near'] = "そのプレイヤーは近くにいません。",
    ['nobody_near'] = "招待できる人が近くにいません。",
    ['already_guest'] = "そのプレイヤーはすでに客です。",
    ['max_guests'] = "この部屋の客はすでに上限です（%s）。",
    ['guest_added'] = "%s があなたの部屋の客になりました。",
    ['guest_removed'] = "%s はもうあなたの部屋の客ではありません。",
    ['you_were_invited'] = "%s があなたを %s 号室に招待しました（%s）。",
    ['you_were_removed'] = "あなたはもう %s 号室の客ではありません。",

    -- throwing guests out
    ['evict_cooldown'] = "次に客を追い出すまで %s 秒待ってください。",
    ['no_guests_to_evict'] = "追い出す客がいません。",
    ['evicted'] = "%s 人の客を部屋から追い出しました。",
    ['evicted_and_removed'] = "%s 人の客を追い出し、客リストから外しました。",
    ['you_were_evicted'] = "%s に部屋から追い出されました。",
    ['evict_confirm'] = "%s 人の客をすぐに部屋から出します。よろしいですか？",

    -- telegrams
    ['telegram_sender'] = "ホテルのフロント",
    ['tg_invite_subject'] = "ホテルの部屋への招待",
    ['tg_invite_body'] = "%s があなたを %s 号室に招待しました（%s）。フロントで客としてチェックインしてください。",
    ['tg_evicted_subject'] = "ホテルの部屋から追い出されました",
    ['tg_evicted_body'] = "%s があなたを %s 号室から追い出しました。後でまた客としてチェックインできます。",
    ['tg_evicted_body_removed'] = "%s があなたを %s 号室から追い出し、招待を取り消しました。",
    ['tg_low_subject'] = "部屋の積立金が残りわずか",
    ['tg_low_body'] = "%s 号室（%s）の積立金が残りわずかです：残り $%s。部屋のメニューで積み立ててください。",
    ['tg_lost_subject'] = "部屋を手放しました",
    ['tg_lost_body'] = "%s 号室（%s）の積立金が尽きたため、チェックアウトとなりました。ご宿泊ありがとうございました。",

    -- logs (MULTIserver)
    ['log_rented'] = "ホテルの部屋を貸出",
    ['log_evicted'] = "ホテルの客を追い出し",
    ['log_lost'] = "ホテルの部屋を喪失",

    -- desk menu
    ['menu_check_in'] = "チェックイン",
    ['menu_check_in_desc'] = "%s 号室へ上がる。積立金：$%s",
    ['menu_rent'] = "部屋を借りる（$%s）",
    ['menu_rent_desc'] = "支払ったお金が部屋の最初の積立金になります。",
    ['menu_guest_check_in'] = "客としてチェックイン",
    ['menu_guest_check_in_desc'] = "招待された部屋へ上がる。",

    -- room menu
    ['room_title'] = "%s 号室",
    ['badge_guest'] = "客",
    ['menu_add_credit'] = "積み立てる",
    ['menu_credit_now'] = "積立金：$%s",
    ['menu_remove_credit'] = "積立金を引き出す",
    ['menu_remove_credit_desc'] = "部屋の積立金からお金を戻す。",
    ['menu_guests'] = "客",
    ['menu_guests_desc'] = "プレイヤーを招待、または招待を取り消す。",
    ['menu_evict'] = "客を追い出す",
    ['menu_evict_desc'] = "すべての客をすぐに部屋から出す。",
    ['menu_locker'] = "部屋のロッカー",
    ['menu_locker_desc'] = "持ち物をしまう。",
    ['menu_guest_access'] = "客としての利用",
    ['menu_owner'] = "%s の部屋",
    ['menu_leave'] = "部屋を出る",
    ['menu_leave_desc'] = "通りへ下りる。",
    ['menu_mail'] = "電報",
    ['menu_mail_desc'] = "電報を読む・送る。",
    ['input_add_label'] = "積み立てる金額（積立金：$%s）",
    ['input_remove_label'] = "引き出す金額（積立金：$%s）",

    -- guest menu
    ['menu_add_guest'] = "プレイヤーを招待",
    ['menu_add_guest_desc'] = "近くにいるプレイヤー。",
    ['menu_current_guests'] = "客",
    ['menu_no_guests'] = "客なし",
    ['menu_no_guests_desc'] = "まだ誰も招待していません。",
    ['menu_guest_row'] = "%s を招待中。選ぶと招待を取り消します。",
    ['menu_invite'] = "プレイヤーを招待",
    ['menu_invite_row'] = "ID %s。選ぶと招待します。",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "部屋のメニュー",
    ['target_desk'] = "フロント",
    ['target_room'] = "部屋のメニュー",

    -- page
    ['ui_subtitle'] = "宿泊客サービス",
    ['ui_back'] = "戻る",
    ['ui_close'] = "閉じる",
    ['ui_cancel'] = "キャンセル",
    ['ui_confirm'] = "確認",
    ['ui_amount'] = "金額",
    ['ui_max'] = "最大",
    ['ui_valid_amount'] = "正しい金額を入力してください",
    ['ui_success'] = "成功",
    ['ui_error'] = "エラー",
    ['ui_info'] = "情報",
    ['ui_notice'] = "お知らせ",
}

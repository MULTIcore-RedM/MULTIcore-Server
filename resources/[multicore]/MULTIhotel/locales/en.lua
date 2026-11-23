Locales = Locales or {}
Locales['en'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "You are too far from the front desk.",
    ['not_enough_money'] = "You do not have enough money.",
    ['bad_amount'] = "Enter a valid amount.",
    ['not_owner'] = "Only the guest who rented this room can do that.",
    ['no_active_room'] = "You are not in a hotel room.",

    -- hotels
    ['hotel_valentine'] = "Valentine Hotel",
    ['hotel_strawberry'] = "Strawberry Hotel",
    ['hotel_rhodes'] = "Rhodes Hotel",
    ['hotel_stdenis'] = "Saint Denis Hotel",
    ['hotel_blackwater'] = "Blackwater Hotel",
    ['hotel_tumbleweed'] = "Tumbleweed Hotel",
    ['hotel_annesburg'] = "Annesburg Hotel",

    -- renting and checking in
    ['already_have_room'] = "You already have a room at this hotel.",
    ['no_free_room'] = "There is no free room right now. Try again later.",
    ['rented'] = "You rented room %s at the %s.",
    ['no_room_here'] = "You do not have a room at this hotel.",
    ['not_a_guest'] = "You are not a guest at this hotel.",
    ['guest_checked_in'] = "Checked in as a guest to room %s.",
    ['room_lost'] = "Your room %s ran out of credit and was given up.",

    -- credit
    ['credit_too_high'] = "A room can hold at most $%s of credit.",
    ['credit_added'] = "Added $%s of credit. Credit now: $%s.",
    ['cannot_withdraw'] = "You cannot take out more credit than the room holds.",
    ['credit_withdrawn'] = "Took out $%s of credit. Credit now: $%s.",

    -- locker
    ['locker_label'] = "Room %s locker",
    ['locker_failed'] = "The room locker could not be opened.",

    -- guests
    ['player_not_found'] = "That player was not found.",
    ['player_not_near'] = "That player is not close enough.",
    ['nobody_near'] = "There is nobody close enough to invite.",
    ['already_guest'] = "That player is already a guest.",
    ['max_guests'] = "This room already has the most guests it may have (%s).",
    ['guest_added'] = "%s is now a guest of your room.",
    ['guest_removed'] = "%s is no longer a guest of your room.",
    ['you_were_invited'] = "%s invited you to room %s at the %s.",
    ['you_were_removed'] = "You are no longer a guest of room %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Wait %s seconds before throwing guests out again.",
    ['no_guests_to_evict'] = "There are no guests to throw out.",
    ['evicted'] = "%s guest(s) thrown out of your room.",
    ['evicted_and_removed'] = "%s guest(s) thrown out and removed from the guest list.",
    ['you_were_evicted'] = "%s threw you out of the room.",
    ['evict_confirm'] = "This sends %s guest(s) out of your room right away. Go ahead?",

    -- telegrams
    ['telegram_sender'] = "Hotel Reception",
    ['tg_invite_subject'] = "Hotel room invitation",
    ['tg_invite_body'] = "%s invited you to room %s at the %s. Ask at the front desk to check in as a guest.",
    ['tg_evicted_subject'] = "Thrown out of a hotel room",
    ['tg_evicted_body'] = "%s threw you out of room %s. You can still check in as a guest later.",
    ['tg_evicted_body_removed'] = "%s threw you out of room %s and took back your invitation.",
    ['tg_low_subject'] = "Room credit running low",
    ['tg_low_body'] = "The credit for room %s at the %s is running low: $%s left. Add credit at the room menu.",
    ['tg_lost_subject'] = "Room given up",
    ['tg_lost_body'] = "Room %s at the %s ran out of credit, so you have been checked out. Thank you for staying with us.",

    -- logs (MULTIserver)
    ['log_rented'] = "Hotel room rented",
    ['log_evicted'] = "Hotel guests thrown out",
    ['log_lost'] = "Hotel room lost",

    -- desk menu
    ['menu_check_in'] = "Check in",
    ['menu_check_in_desc'] = "Go up to room %s. Credit: $%s",
    ['menu_rent'] = "Rent a room ($%s)",
    ['menu_rent_desc'] = "The money becomes your room's first credit.",
    ['menu_guest_check_in'] = "Guest check in",
    ['menu_guest_check_in_desc'] = "Go up to the room you were invited to.",

    -- room menu
    ['room_title'] = "Room %s",
    ['badge_guest'] = "Guest",
    ['menu_add_credit'] = "Add credit",
    ['menu_credit_now'] = "Credit now: $%s",
    ['menu_remove_credit'] = "Take out credit",
    ['menu_remove_credit_desc'] = "Get money back from the room's credit.",
    ['menu_guests'] = "Guests",
    ['menu_guests_desc'] = "Invite players or take an invitation back.",
    ['menu_evict'] = "Throw guests out",
    ['menu_evict_desc'] = "Send every guest out of the room right away.",
    ['menu_locker'] = "Room locker",
    ['menu_locker_desc'] = "Store your things.",
    ['menu_guest_access'] = "Guest access",
    ['menu_owner'] = "Room of %s",
    ['menu_leave'] = "Leave the room",
    ['menu_leave_desc'] = "Go back down to the street.",
    ['menu_mail'] = "Telegrams",
    ['menu_mail_desc'] = "Read and send telegrams.",
    ['input_add_label'] = "Amount to add (credit now: $%s)",
    ['input_remove_label'] = "Amount to take out (credit now: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Invite a player",
    ['menu_add_guest_desc'] = "Players close to you.",
    ['menu_current_guests'] = "Guests",
    ['menu_no_guests'] = "No guests",
    ['menu_no_guests_desc'] = "You have not invited anyone yet.",
    ['menu_guest_row'] = "Invited %s. Pick to take the invitation back.",
    ['menu_invite'] = "Invite a player",
    ['menu_invite_row'] = "ID %s. Pick to invite.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Room menu",
    ['target_desk'] = "Front desk",
    ['target_room'] = "Room menu",

    -- page
    ['ui_subtitle'] = "Guest Services",
    ['ui_back'] = "Back",
    ['ui_close'] = "Close",
    ['ui_cancel'] = "Cancel",
    ['ui_confirm'] = "Confirm",
    ['ui_amount'] = "Amount",
    ['ui_max'] = "Max",
    ['ui_valid_amount'] = "Please enter a valid amount",
    ['ui_success'] = "Success",
    ['ui_error'] = "Error",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Notice",
}

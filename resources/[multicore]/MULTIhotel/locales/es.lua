Locales = Locales or {}
Locales['es'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Estás demasiado lejos de la recepción.",
    ['not_enough_money'] = "No tienes suficiente dinero.",
    ['bad_amount'] = "Introduce una cantidad válida.",
    ['not_owner'] = "Solo el huésped que alquiló esta habitación puede hacer eso.",
    ['no_active_room'] = "No estás en una habitación de hotel.",

    -- hotels
    ['hotel_valentine'] = "Hotel de Valentine",
    ['hotel_strawberry'] = "Hotel de Strawberry",
    ['hotel_rhodes'] = "Hotel de Rhodes",
    ['hotel_stdenis'] = "Hotel de Saint Denis",
    ['hotel_blackwater'] = "Hotel de Blackwater",
    ['hotel_tumbleweed'] = "Hotel de Tumbleweed",
    ['hotel_annesburg'] = "Hotel de Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Ya tienes una habitación en este hotel.",
    ['no_free_room'] = "No hay habitaciones libres ahora mismo. Vuelve más tarde.",
    ['rented'] = "Alquilaste la habitación %s en el %s.",
    ['no_room_here'] = "No tienes una habitación en este hotel.",
    ['not_a_guest'] = "No eres invitado en este hotel.",
    ['guest_checked_in'] = "Te registraste como invitado en la habitación %s.",
    ['room_lost'] = "Tu habitación %s se quedó sin crédito y fue entregada.",

    -- credit
    ['credit_too_high'] = "Una habitación puede tener como máximo $%s de crédito.",
    ['credit_added'] = "Añadiste $%s de crédito. Crédito actual: $%s.",
    ['cannot_withdraw'] = "No puedes retirar más crédito del que tiene la habitación.",
    ['credit_withdrawn'] = "Retiraste $%s de crédito. Crédito actual: $%s.",

    -- locker
    ['locker_label'] = "Armario de la habitación %s",
    ['locker_failed'] = "No se pudo abrir el armario de la habitación.",

    -- guests
    ['player_not_found'] = "No se encontró a ese jugador.",
    ['player_not_near'] = "Ese jugador no está lo bastante cerca.",
    ['nobody_near'] = "No hay nadie lo bastante cerca para invitar.",
    ['already_guest'] = "Ese jugador ya es invitado.",
    ['max_guests'] = "Esta habitación ya tiene el máximo de invitados permitido (%s).",
    ['guest_added'] = "%s ahora es invitado de tu habitación.",
    ['guest_removed'] = "%s ya no es invitado de tu habitación.",
    ['you_were_invited'] = "%s te invitó a la habitación %s en el %s.",
    ['you_were_removed'] = "Ya no eres invitado de la habitación %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Espera %s segundos antes de volver a echar a los invitados.",
    ['no_guests_to_evict'] = "No hay invitados a los que echar.",
    ['evicted'] = "%s invitado(s) echado(s) de tu habitación.",
    ['evicted_and_removed'] = "%s invitado(s) echado(s) y quitado(s) de la lista de invitados.",
    ['you_were_evicted'] = "%s te echó de la habitación.",
    ['evict_confirm'] = "Esto echará a %s invitado(s) de tu habitación de inmediato. ¿Continuar?",

    -- telegrams
    ['telegram_sender'] = "Recepción del hotel",
    ['tg_invite_subject'] = "Invitación a una habitación de hotel",
    ['tg_invite_body'] = "%s te invitó a la habitación %s en el %s. Pregunta en la recepción para registrarte como invitado.",
    ['tg_evicted_subject'] = "Echado de una habitación de hotel",
    ['tg_evicted_body'] = "%s te echó de la habitación %s. Aún puedes registrarte como invitado más tarde.",
    ['tg_evicted_body_removed'] = "%s te echó de la habitación %s y retiró tu invitación.",
    ['tg_low_subject'] = "Queda poco crédito en la habitación",
    ['tg_low_body'] = "El crédito de la habitación %s en el %s se está acabando: quedan $%s. Añade crédito en el menú de la habitación.",
    ['tg_lost_subject'] = "Habitación entregada",
    ['tg_lost_body'] = "La habitación %s en el %s se quedó sin crédito, así que se ha cerrado tu estancia. Gracias por alojarte con nosotros.",

    -- logs (MULTIserver)
    ['log_rented'] = "Habitación de hotel alquilada",
    ['log_evicted'] = "Invitados del hotel echados",
    ['log_lost'] = "Habitación de hotel perdida",

    -- desk menu
    ['menu_check_in'] = "Registrarse",
    ['menu_check_in_desc'] = "Subir a la habitación %s. Crédito: $%s",
    ['menu_rent'] = "Alquilar una habitación ($%s)",
    ['menu_rent_desc'] = "El dinero será el primer crédito de tu habitación.",
    ['menu_guest_check_in'] = "Registro de invitado",
    ['menu_guest_check_in_desc'] = "Subir a la habitación a la que te invitaron.",

    -- room menu
    ['room_title'] = "Habitación %s",
    ['badge_guest'] = "Invitado",
    ['menu_add_credit'] = "Añadir crédito",
    ['menu_credit_now'] = "Crédito actual: $%s",
    ['menu_remove_credit'] = "Retirar crédito",
    ['menu_remove_credit_desc'] = "Recuperar dinero del crédito de la habitación.",
    ['menu_guests'] = "Invitados",
    ['menu_guests_desc'] = "Invitar jugadores o retirar una invitación.",
    ['menu_evict'] = "Echar a los invitados",
    ['menu_evict_desc'] = "Sacar a todos los invitados de la habitación de inmediato.",
    ['menu_locker'] = "Armario de la habitación",
    ['menu_locker_desc'] = "Guarda tus cosas.",
    ['menu_guest_access'] = "Acceso de invitado",
    ['menu_owner'] = "Habitación de %s",
    ['menu_leave'] = "Salir de la habitación",
    ['menu_leave_desc'] = "Volver a bajar a la calle.",
    ['menu_mail'] = "Telegramas",
    ['menu_mail_desc'] = "Leer y enviar telegramas.",
    ['input_add_label'] = "Cantidad a añadir (crédito actual: $%s)",
    ['input_remove_label'] = "Cantidad a retirar (crédito actual: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Invitar a un jugador",
    ['menu_add_guest_desc'] = "Jugadores cerca de ti.",
    ['menu_current_guests'] = "Invitados",
    ['menu_no_guests'] = "Sin invitados",
    ['menu_no_guests_desc'] = "Aún no has invitado a nadie.",
    ['menu_guest_row'] = "%s invitado. Elige para retirar la invitación.",
    ['menu_invite'] = "Invitar a un jugador",
    ['menu_invite_row'] = "ID %s. Elige para invitar.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Menú de la habitación",
    ['target_desk'] = "Recepción",
    ['target_room'] = "Menú de la habitación",

    -- page
    ['ui_subtitle'] = "Atención al huésped",
    ['ui_back'] = "Atrás",
    ['ui_close'] = "Cerrar",
    ['ui_cancel'] = "Cancelar",
    ['ui_confirm'] = "Confirmar",
    ['ui_amount'] = "Cantidad",
    ['ui_max'] = "Máx.",
    ['ui_valid_amount'] = "Introduce una cantidad válida",
    ['ui_success'] = "Éxito",
    ['ui_error'] = "Error",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Aviso",
}

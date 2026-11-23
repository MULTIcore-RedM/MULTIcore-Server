Locales = Locales or {}
Locales['fr'] = {
    -- general
    ['notify_title'] = "Hôtel",
    ['too_far'] = "Tu es trop loin de la réception.",
    ['not_enough_money'] = "Tu n'as pas assez d'argent.",
    ['bad_amount'] = "Saisis un montant valide.",
    ['not_owner'] = "Seul le client qui a loué cette chambre peut faire ça.",
    ['no_active_room'] = "Tu n'es pas dans une chambre d'hôtel.",

    -- hotels
    ['hotel_valentine'] = "Hôtel de Valentine",
    ['hotel_strawberry'] = "Hôtel de Strawberry",
    ['hotel_rhodes'] = "Hôtel de Rhodes",
    ['hotel_stdenis'] = "Hôtel de Saint Denis",
    ['hotel_blackwater'] = "Hôtel de Blackwater",
    ['hotel_tumbleweed'] = "Hôtel de Tumbleweed",
    ['hotel_annesburg'] = "Hôtel d'Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Tu as déjà une chambre dans cet hôtel.",
    ['no_free_room'] = "Aucune chambre libre pour le moment. Reviens plus tard.",
    ['rented'] = "Tu as loué la chambre %s à l'%s.",
    ['no_room_here'] = "Tu n'as pas de chambre dans cet hôtel.",
    ['not_a_guest'] = "Tu n'es pas invité dans cet hôtel.",
    ['guest_checked_in'] = "Arrivée enregistrée en tant qu'invité dans la chambre %s.",
    ['room_lost'] = "Ta chambre %s n'avait plus de crédit et a été libérée.",

    -- credit
    ['credit_too_high'] = "Une chambre peut contenir au maximum $%s de crédit.",
    ['credit_added'] = "$%s de crédit ajoutés. Crédit actuel : $%s.",
    ['cannot_withdraw'] = "Tu ne peux pas retirer plus de crédit que la chambre n'en contient.",
    ['credit_withdrawn'] = "$%s de crédit retirés. Crédit actuel : $%s.",

    -- locker
    ['locker_label'] = "Casier de la chambre %s",
    ['locker_failed'] = "Le casier de la chambre n'a pas pu être ouvert.",

    -- guests
    ['player_not_found'] = "Ce joueur est introuvable.",
    ['player_not_near'] = "Ce joueur n'est pas assez proche.",
    ['nobody_near'] = "Personne n'est assez proche pour être invité.",
    ['already_guest'] = "Ce joueur est déjà invité.",
    ['max_guests'] = "Cette chambre a déjà le nombre maximum d'invités (%s).",
    ['guest_added'] = "%s est maintenant invité dans ta chambre.",
    ['guest_removed'] = "%s n'est plus invité dans ta chambre.",
    ['you_were_invited'] = "%s t'a invité dans la chambre %s à l'%s.",
    ['you_were_removed'] = "Tu n'es plus invité dans la chambre %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Attends %s secondes avant de mettre à nouveau des invités dehors.",
    ['no_guests_to_evict'] = "Il n'y a aucun invité à mettre dehors.",
    ['evicted'] = "%s invité(s) mis dehors de ta chambre.",
    ['evicted_and_removed'] = "%s invité(s) mis dehors et retirés de la liste des invités.",
    ['you_were_evicted'] = "%s t'a mis dehors de la chambre.",
    ['evict_confirm'] = "Cela fait sortir %s invité(s) de ta chambre immédiatement. Continuer ?",

    -- telegrams
    ['telegram_sender'] = "Réception de l'hôtel",
    ['tg_invite_subject'] = "Invitation dans une chambre d'hôtel",
    ['tg_invite_body'] = "%s t'a invité dans la chambre %s à l'%s. Adresse-toi à la réception pour t'enregistrer en tant qu'invité.",
    ['tg_evicted_subject'] = "Mis dehors d'une chambre d'hôtel",
    ['tg_evicted_body'] = "%s t'a mis dehors de la chambre %s. Tu pourras quand même revenir plus tard en tant qu'invité.",
    ['tg_evicted_body_removed'] = "%s t'a mis dehors de la chambre %s et a retiré ton invitation.",
    ['tg_low_subject'] = "Crédit de la chambre presque épuisé",
    ['tg_low_body'] = "Le crédit de la chambre %s à l'%s est presque épuisé : il reste $%s. Ajoute du crédit depuis le menu de la chambre.",
    ['tg_lost_subject'] = "Chambre libérée",
    ['tg_lost_body'] = "La chambre %s à l'%s n'a plus de crédit, ton séjour est donc terminé. Merci d'avoir séjourné chez nous.",

    -- logs (MULTIserver)
    ['log_rented'] = "Chambre d'hôtel louée",
    ['log_evicted'] = "Invités de l'hôtel mis dehors",
    ['log_lost'] = "Chambre d'hôtel perdue",

    -- desk menu
    ['menu_check_in'] = "S'enregistrer",
    ['menu_check_in_desc'] = "Monter à la chambre %s. Crédit : $%s",
    ['menu_rent'] = "Louer une chambre ($%s)",
    ['menu_rent_desc'] = "L'argent devient le premier crédit de ta chambre.",
    ['menu_guest_check_in'] = "Arrivée d'un invité",
    ['menu_guest_check_in_desc'] = "Monter à la chambre où tu as été invité.",

    -- room menu
    ['room_title'] = "Chambre %s",
    ['badge_guest'] = "Invité",
    ['menu_add_credit'] = "Ajouter du crédit",
    ['menu_credit_now'] = "Crédit actuel : $%s",
    ['menu_remove_credit'] = "Retirer du crédit",
    ['menu_remove_credit_desc'] = "Récupérer de l'argent sur le crédit de la chambre.",
    ['menu_guests'] = "Invités",
    ['menu_guests_desc'] = "Inviter des joueurs ou retirer une invitation.",
    ['menu_evict'] = "Mettre les invités dehors",
    ['menu_evict_desc'] = "Faire sortir tous les invités de la chambre immédiatement.",
    ['menu_locker'] = "Casier de la chambre",
    ['menu_locker_desc'] = "Range tes affaires.",
    ['menu_guest_access'] = "Accès invité",
    ['menu_owner'] = "Chambre de %s",
    ['menu_leave'] = "Quitter la chambre",
    ['menu_leave_desc'] = "Redescendre dans la rue.",
    ['menu_mail'] = "Télégrammes",
    ['menu_mail_desc'] = "Lire et envoyer des télégrammes.",
    ['input_add_label'] = "Montant à ajouter (crédit actuel : $%s)",
    ['input_remove_label'] = "Montant à retirer (crédit actuel : $%s)",

    -- guest menu
    ['menu_add_guest'] = "Inviter un joueur",
    ['menu_add_guest_desc'] = "Joueurs proches de toi.",
    ['menu_current_guests'] = "Invités",
    ['menu_no_guests'] = "Aucun invité",
    ['menu_no_guests_desc'] = "Tu n'as encore invité personne.",
    ['menu_guest_row'] = "%s invité. Sélectionne pour retirer l'invitation.",
    ['menu_invite'] = "Inviter un joueur",
    ['menu_invite_row'] = "ID %s. Sélectionne pour inviter.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Menu de la chambre",
    ['target_desk'] = "Réception",
    ['target_room'] = "Menu de la chambre",

    -- page
    ['ui_subtitle'] = "Service clientèle",
    ['ui_back'] = "Retour",
    ['ui_close'] = "Fermer",
    ['ui_cancel'] = "Annuler",
    ['ui_confirm'] = "Confirmer",
    ['ui_amount'] = "Montant",
    ['ui_max'] = "Max",
    ['ui_valid_amount'] = "Saisis un montant valide",
    ['ui_success'] = "Succès",
    ['ui_error'] = "Erreur",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Avis",
}

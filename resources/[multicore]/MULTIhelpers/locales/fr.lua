-- MULTIhelpers :: fr
Locales = Locales or {}
Locales['fr'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Confirmer",
    ['cancel'] = "Annuler",
    ['yes'] = "Oui",
    ['no'] = "Non",
    -- key hints under a menu
    ['key_move'] = "Déplacer",
    ['key_change'] = "Changer",
    ['key_next'] = "Suivant",
    ['key_select'] = "Choisir",
    ['key_back'] = "Retour",
    ['keyname_Enter'] = "Entrée",
    ['keyname_Escape'] = "Échap",
    ['keyname_Backspace'] = "Retour arr.",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Non autorisé",
    ['err_letters'] = "Lettres uniquement",
    ['err_numbers'] = "Chiffres uniquement",
    ['err_alphanumeric'] = "Lettres et chiffres uniquement",
    ['err_no_symbols'] = "Pas de symboles",
    ['err_username'] = "Au moins 3 lettres, chiffres, _ . ou -",
    ['err_phone'] = "Chiffres, espaces et + - ( ) uniquement",
    ['err_email'] = "Adresse e-mail invalide",
    ['err_money'] = "Un montant, par ex. 12.50",
    ['err_no_special'] = "Pas de caractères spéciaux",
    -- console lines for the server owner
    ['warn_running'] = "%s est lancé - retirez \"ensure %s\" du server.cfg, MULTIhelpers le remplace.",
    ['warn_started'] = "%s a démarré à côté de MULTIhelpers - retirez \"ensure %s\" du server.cfg.",
    ['callback_error'] = "erreur de callback : %s",
    -- skill bar (syn_minigame) and QB progress bar
    ['skill_hint'] = "Appuie sur %s dans la zone marquée",
    ['progress_busy'] = "Tu fais déjà quelque chose",
    ['progress_dead'] = "Impossible quand tu es mort",
    -- bcc-minigames stand-in: rock, paper, scissors
    ["mg_rock"] = "Pierre",
    ["mg_paper"] = "Feuille",
    ["mg_scissors"] = "Ciseaux",
    ["mg_win"] = "Vous gagnez",
    ["mg_lose"] = "Vous perdez",
    ["mg_tie"] = "Égalité",
}

-- MULTIhelpers :: el
Locales = Locales or {}
Locales['el'] = {
    -- buttons (used only when the calling script gives none)
    ['confirm'] = "Επιβεβαίωση",
    ['cancel'] = "Άκυρο",
    ['yes'] = "Ναι",
    ['no'] = "Όχι",
    -- key hints under a menu
    ['key_move'] = "Μετακίνηση",
    ['key_change'] = "Αλλαγή",
    ['key_next'] = "Επόμενο",
    ['key_select'] = "Επιλογή",
    ['key_back'] = "Πίσω",
    ['keyname_Enter'] = "Enter",
    ['keyname_Escape'] = "Esc",
    ['keyname_Backspace'] = "Bksp",
    ['keyname_Tab'] = "Tab",
    -- input check messages (used only when the calling script gives none)
    ['err_not_allowed'] = "Δεν επιτρέπεται",
    ['err_letters'] = "Μόνο γράμματα",
    ['err_numbers'] = "Μόνο αριθμοί",
    ['err_alphanumeric'] = "Μόνο γράμματα και αριθμοί",
    ['err_no_symbols'] = "Χωρίς σύμβολα",
    ['err_username'] = "Τουλάχιστον 3 γράμματα, αριθμοί, _ . ή -",
    ['err_phone'] = "Μόνο αριθμοί, κενά και + - ( )",
    ['err_email'] = "Δεν είναι διεύθυνση e-mail",
    ['err_money'] = "Ένα ποσό, π.χ. 12.50",
    ['err_no_special'] = "Χωρίς ειδικούς χαρακτήρες",
    -- console lines for the server owner
    ['warn_running'] = "Το %s τρέχει - αφαίρεσε το \"ensure %s\" από το server.cfg, το MULTIhelpers το αντικαθιστά.",
    ['warn_started'] = "Το %s ξεκίνησε μαζί με το MULTIhelpers - αφαίρεσε το \"ensure %s\" από το server.cfg.",
    ['callback_error'] = "σφάλμα callback: %s",
}

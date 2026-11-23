Locales = Locales or {}
Locales['pt'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Estás demasiado longe da receção.",
    ['not_enough_money'] = "Não tens dinheiro suficiente.",
    ['bad_amount'] = "Introduz um valor válido.",
    ['not_owner'] = "Só o hóspede que alugou este quarto pode fazer isso.",
    ['no_active_room'] = "Não estás num quarto de hotel.",

    -- hotels
    ['hotel_valentine'] = "Hotel de Valentine",
    ['hotel_strawberry'] = "Hotel de Strawberry",
    ['hotel_rhodes'] = "Hotel de Rhodes",
    ['hotel_stdenis'] = "Hotel de Saint Denis",
    ['hotel_blackwater'] = "Hotel de Blackwater",
    ['hotel_tumbleweed'] = "Hotel de Tumbleweed",
    ['hotel_annesburg'] = "Hotel de Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Já tens um quarto neste hotel.",
    ['no_free_room'] = "Não há nenhum quarto livre agora. Tenta mais tarde.",
    ['rented'] = "Alugaste o quarto %s no %s.",
    ['no_room_here'] = "Não tens quarto neste hotel.",
    ['not_a_guest'] = "Não és convidado neste hotel.",
    ['guest_checked_in'] = "Deste entrada como convidado no quarto %s.",
    ['room_lost'] = "O teu quarto %s ficou sem crédito e foi entregue.",

    -- credit
    ['credit_too_high'] = "Um quarto pode ter no máximo $%s de crédito.",
    ['credit_added'] = "Juntaste $%s de crédito. Crédito agora: $%s.",
    ['cannot_withdraw'] = "Não podes tirar mais crédito do que o quarto tem.",
    ['credit_withdrawn'] = "Tiraste $%s de crédito. Crédito agora: $%s.",

    -- locker
    ['locker_label'] = "Cacifo do quarto %s",
    ['locker_failed'] = "Não foi possível abrir o cacifo do quarto.",

    -- guests
    ['player_not_found'] = "Esse jogador não foi encontrado.",
    ['player_not_near'] = "Esse jogador não está perto o suficiente.",
    ['nobody_near'] = "Não há ninguém perto o suficiente para convidar.",
    ['already_guest'] = "Esse jogador já é convidado.",
    ['max_guests'] = "Este quarto já tem o máximo de convidados permitido (%s).",
    ['guest_added'] = "%s é agora convidado do teu quarto.",
    ['guest_removed'] = "%s já não é convidado do teu quarto.",
    ['you_were_invited'] = "%s convidou-te para o quarto %s no %s.",
    ['you_were_removed'] = "Já não és convidado do quarto %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Espera %s segundos antes de expulsar convidados outra vez.",
    ['no_guests_to_evict'] = "Não há convidados para expulsar.",
    ['evicted'] = "%s convidado(s) expulso(s) do teu quarto.",
    ['evicted_and_removed'] = "%s convidado(s) expulso(s) e retirado(s) da lista de convidados.",
    ['you_were_evicted'] = "%s expulsou-te do quarto.",
    ['evict_confirm'] = "Isto manda já %s convidado(s) para fora do teu quarto. Continuar?",

    -- telegrams
    ['telegram_sender'] = "Receção do Hotel",
    ['tg_invite_subject'] = "Convite para quarto de hotel",
    ['tg_invite_body'] = "%s convidou-te para o quarto %s no %s. Pede na receção para dar entrada como convidado.",
    ['tg_evicted_subject'] = "Expulso de um quarto de hotel",
    ['tg_evicted_body'] = "%s expulsou-te do quarto %s. Ainda podes dar entrada como convidado mais tarde.",
    ['tg_evicted_body_removed'] = "%s expulsou-te do quarto %s e retirou o teu convite.",
    ['tg_low_subject'] = "Crédito do quarto a acabar",
    ['tg_low_body'] = "O crédito do quarto %s no %s está a acabar: restam $%s. Junta crédito no menu do quarto.",
    ['tg_lost_subject'] = "Quarto entregue",
    ['tg_lost_body'] = "O quarto %s no %s ficou sem crédito, por isso foi feita a tua saída. Obrigado pela tua estadia.",

    -- logs (MULTIserver)
    ['log_rented'] = "Quarto de hotel alugado",
    ['log_evicted'] = "Convidados do hotel expulsos",
    ['log_lost'] = "Quarto de hotel perdido",

    -- desk menu
    ['menu_check_in'] = "Dar entrada",
    ['menu_check_in_desc'] = "Sobe ao quarto %s. Crédito: $%s",
    ['menu_rent'] = "Alugar um quarto ($%s)",
    ['menu_rent_desc'] = "O dinheiro passa a ser o primeiro crédito do teu quarto.",
    ['menu_guest_check_in'] = "Entrada de convidado",
    ['menu_guest_check_in_desc'] = "Sobe ao quarto para onde foste convidado.",

    -- room menu
    ['room_title'] = "Quarto %s",
    ['badge_guest'] = "Convidado",
    ['menu_add_credit'] = "Juntar crédito",
    ['menu_credit_now'] = "Crédito agora: $%s",
    ['menu_remove_credit'] = "Tirar crédito",
    ['menu_remove_credit_desc'] = "Recupera dinheiro do crédito do quarto.",
    ['menu_guests'] = "Convidados",
    ['menu_guests_desc'] = "Convida jogadores ou retira um convite.",
    ['menu_evict'] = "Expulsar convidados",
    ['menu_evict_desc'] = "Manda já todos os convidados para fora do quarto.",
    ['menu_locker'] = "Cacifo do quarto",
    ['menu_locker_desc'] = "Guarda as tuas coisas.",
    ['menu_guest_access'] = "Acesso de convidado",
    ['menu_owner'] = "Quarto de %s",
    ['menu_leave'] = "Sair do quarto",
    ['menu_leave_desc'] = "Volta a descer para a rua.",
    ['menu_mail'] = "Telegramas",
    ['menu_mail_desc'] = "Lê e envia telegramas.",
    ['input_add_label'] = "Valor a juntar (crédito agora: $%s)",
    ['input_remove_label'] = "Valor a tirar (crédito agora: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Convidar um jogador",
    ['menu_add_guest_desc'] = "Jogadores perto de ti.",
    ['menu_current_guests'] = "Convidados",
    ['menu_no_guests'] = "Sem convidados",
    ['menu_no_guests_desc'] = "Ainda não convidaste ninguém.",
    ['menu_guest_row'] = "Convidado: %s. Escolhe para retirar o convite.",
    ['menu_invite'] = "Convidar um jogador",
    ['menu_invite_row'] = "ID %s. Escolhe para convidar.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Menu do quarto",
    ['target_desk'] = "Receção",
    ['target_room'] = "Menu do quarto",

    -- page
    ['ui_subtitle'] = "Serviço aos Hóspedes",
    ['ui_back'] = "Voltar",
    ['ui_close'] = "Fechar",
    ['ui_cancel'] = "Cancelar",
    ['ui_confirm'] = "Confirmar",
    ['ui_amount'] = "Valor",
    ['ui_max'] = "Máx",
    ['ui_valid_amount'] = "Introduz um valor válido",
    ['ui_success'] = "Sucesso",
    ['ui_error'] = "Erro",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Aviso",
}

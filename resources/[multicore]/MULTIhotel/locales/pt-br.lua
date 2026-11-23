Locales = Locales or {}
Locales['pt-br'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Você está longe demais da recepção.",
    ['not_enough_money'] = "Você não tem dinheiro suficiente.",
    ['bad_amount'] = "Digite um valor válido.",
    ['not_owner'] = "Só o hóspede que alugou este quarto pode fazer isso.",
    ['no_active_room'] = "Você não está em um quarto de hotel.",

    -- hotels
    ['hotel_valentine'] = "Hotel de Valentine",
    ['hotel_strawberry'] = "Hotel de Strawberry",
    ['hotel_rhodes'] = "Hotel de Rhodes",
    ['hotel_stdenis'] = "Hotel de Saint Denis",
    ['hotel_blackwater'] = "Hotel de Blackwater",
    ['hotel_tumbleweed'] = "Hotel de Tumbleweed",
    ['hotel_annesburg'] = "Hotel de Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Você já tem um quarto neste hotel.",
    ['no_free_room'] = "Não há quarto livre agora. Tente de novo mais tarde.",
    ['rented'] = "Você alugou o quarto %s no %s.",
    ['no_room_here'] = "Você não tem um quarto neste hotel.",
    ['not_a_guest'] = "Você não é convidado neste hotel.",
    ['guest_checked_in'] = "Check-in feito como convidado no quarto %s.",
    ['room_lost'] = "Seu quarto %s ficou sem crédito e foi devolvido.",

    -- credit
    ['credit_too_high'] = "Um quarto pode ter no máximo $%s de crédito.",
    ['credit_added'] = "$%s de crédito adicionados. Crédito agora: $%s.",
    ['cannot_withdraw'] = "Você não pode retirar mais crédito do que o quarto tem.",
    ['credit_withdrawn'] = "$%s de crédito retirados. Crédito agora: $%s.",

    -- locker
    ['locker_label'] = "Armário do quarto %s",
    ['locker_failed'] = "Não foi possível abrir o armário do quarto.",

    -- guests
    ['player_not_found'] = "Esse jogador não foi encontrado.",
    ['player_not_near'] = "Esse jogador não está perto o suficiente.",
    ['nobody_near'] = "Não há ninguém perto o suficiente para convidar.",
    ['already_guest'] = "Esse jogador já é convidado.",
    ['max_guests'] = "Este quarto já tem o máximo de convidados permitido (%s).",
    ['guest_added'] = "%s agora é convidado do seu quarto.",
    ['guest_removed'] = "%s não é mais convidado do seu quarto.",
    ['you_were_invited'] = "%s convidou você para o quarto %s no %s.",
    ['you_were_removed'] = "Você não é mais convidado do quarto %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Espere %s segundos antes de expulsar convidados de novo.",
    ['no_guests_to_evict'] = "Não há convidados para expulsar.",
    ['evicted'] = "%s convidado(s) expulso(s) do seu quarto.",
    ['evicted_and_removed'] = "%s convidado(s) expulso(s) e tirado(s) da lista de convidados.",
    ['you_were_evicted'] = "%s expulsou você do quarto.",
    ['evict_confirm'] = "Isso tira %s convidado(s) do seu quarto na hora. Continuar?",

    -- telegrams
    ['telegram_sender'] = "Recepção do hotel",
    ['tg_invite_subject'] = "Convite para quarto de hotel",
    ['tg_invite_body'] = "%s convidou você para o quarto %s no %s. Fale com a recepção para fazer o check-in como convidado.",
    ['tg_evicted_subject'] = "Expulso de um quarto de hotel",
    ['tg_evicted_body'] = "%s expulsou você do quarto %s. Você ainda pode fazer o check-in como convidado mais tarde.",
    ['tg_evicted_body_removed'] = "%s expulsou você do quarto %s e cancelou seu convite.",
    ['tg_low_subject'] = "Crédito do quarto acabando",
    ['tg_low_body'] = "O crédito do quarto %s no %s está acabando: restam $%s. Adicione crédito no menu do quarto.",
    ['tg_lost_subject'] = "Quarto devolvido",
    ['tg_lost_body'] = "O quarto %s no %s ficou sem crédito, então seu check-out foi feito. Obrigado pela estadia.",

    -- logs (MULTIserver)
    ['log_rented'] = "Quarto de hotel alugado",
    ['log_evicted'] = "Convidados do hotel expulsos",
    ['log_lost'] = "Quarto de hotel perdido",

    -- desk menu
    ['menu_check_in'] = "Fazer check-in",
    ['menu_check_in_desc'] = "Subir para o quarto %s. Crédito: $%s",
    ['menu_rent'] = "Alugar um quarto ($%s)",
    ['menu_rent_desc'] = "O dinheiro vira o primeiro crédito do seu quarto.",
    ['menu_guest_check_in'] = "Check-in de convidado",
    ['menu_guest_check_in_desc'] = "Subir para o quarto para o qual você foi convidado.",

    -- room menu
    ['room_title'] = "Quarto %s",
    ['badge_guest'] = "Convidado",
    ['menu_add_credit'] = "Adicionar crédito",
    ['menu_credit_now'] = "Crédito agora: $%s",
    ['menu_remove_credit'] = "Retirar crédito",
    ['menu_remove_credit_desc'] = "Pegar de volta dinheiro do crédito do quarto.",
    ['menu_guests'] = "Convidados",
    ['menu_guests_desc'] = "Convidar jogadores ou cancelar um convite.",
    ['menu_evict'] = "Expulsar convidados",
    ['menu_evict_desc'] = "Tirar todos os convidados do quarto na hora.",
    ['menu_locker'] = "Armário do quarto",
    ['menu_locker_desc'] = "Guarde suas coisas.",
    ['menu_guest_access'] = "Acesso de convidado",
    ['menu_owner'] = "Quarto de %s",
    ['menu_leave'] = "Sair do quarto",
    ['menu_leave_desc'] = "Descer de volta para a rua.",
    ['menu_mail'] = "Telegramas",
    ['menu_mail_desc'] = "Ler e enviar telegramas.",
    ['input_add_label'] = "Valor a adicionar (crédito agora: $%s)",
    ['input_remove_label'] = "Valor a retirar (crédito agora: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Convidar um jogador",
    ['menu_add_guest_desc'] = "Jogadores perto de você.",
    ['menu_current_guests'] = "Convidados",
    ['menu_no_guests'] = "Nenhum convidado",
    ['menu_no_guests_desc'] = "Você ainda não convidou ninguém.",
    ['menu_guest_row'] = "%s convidado. Escolha para cancelar o convite.",
    ['menu_invite'] = "Convidar um jogador",
    ['menu_invite_row'] = "ID %s. Escolha para convidar.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Menu do quarto",
    ['target_desk'] = "Recepção",
    ['target_room'] = "Menu do quarto",

    -- page
    ['ui_subtitle'] = "Atendimento ao hóspede",
    ['ui_back'] = "Voltar",
    ['ui_close'] = "Fechar",
    ['ui_cancel'] = "Cancelar",
    ['ui_confirm'] = "Confirmar",
    ['ui_amount'] = "Valor",
    ['ui_max'] = "Máx.",
    ['ui_valid_amount'] = "Digite um valor válido",
    ['ui_success'] = "Sucesso",
    ['ui_error'] = "Erro",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Aviso",
}

-- MULTImedic: Português (Portugal)
Locales = Locales or {}
Locales['pt'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Estás inconsciente',
    ['ui_sub'] = 'Espera por um médico, ou que te voltem as forças',
    ['ui_sub_ready'] = 'Já te podes pôr de pé',
    ['ui_wait'] = 'Podes reaparecer dentro de',
    ['ui_hold_respawn'] = 'Mantém premido para reaparecer no médico',
    ['ui_fee'] = "Honorários do médico: $%s",
    ['ui_call'] = 'Chamar um médico',
    ['ui_call_sending'] = 'A mandar recado...',
    ['ui_call_sent'] = 'Mandaram chamar um médico',
    ['ui_call_none'] = 'Nenhum médico respondeu',
    ['ui_call_wait'] = 'Chamaste há pouco',
    ['ui_call_failed'] = 'Não foi possível enviar o chamado',
    ['ui_call_again'] = 'chamar outra vez em %ss',
    ['ui_medics'] = 'Médicos no território: %s',
    ['ui_no_medics'] = 'Nenhum médico de serviço',

    -- respawn
    ['too_early'] = 'Ainda não tens forças para te levantares.',
    ['respawned'] = 'Voltaste a ti no %s.',
    ['respawned_fee'] = 'Voltaste a ti no %s. O médico cobrou $%s.',
    ['lost_cash'] = 'O teu dinheiro desapareceu.',
    ['lost_bloodmoney'] = 'O teu dinheiro de sangue desapareceu.',

    -- doctor calls
    ['alert_text'] = '%s está caído e precisa de um médico',
    ['alert_default'] = 'Alguém precisa de um médico',
    ['doctor_called'] = 'Mandou-se recado aos médicos.',
    ['no_medics'] = 'De momento não há nenhum médico de serviço.',
    ['call_cooldown'] = 'Acabaste de chamar. Espera um pouco.',

    -- medic actions
    ['reviving'] = 'A reanimar...',
    ['treating'] = 'A tratar feridas...',
    ['target_revive'] = 'Reanimar',
    ['target_treat'] = 'Tratar feridas',
    ['not_medic'] = 'Não és um médico de serviço.',
    ['no_player'] = 'Não há ali nenhum jogador.',
    ['nobody_down'] = 'Ninguém perto de ti está caído.',
    ['not_down'] = 'Essa pessoa não está inconsciente.',
    ['is_down'] = 'Essa pessoa está inconsciente; reanima-a primeiro.',
    ['too_far'] = 'Estás demasiado longe.',
    ['you_revived'] = 'Reanimaste %s.',
    ['revived_by'] = '%s trouxe-te de volta.',
    ['you_treated'] = "Trataste as feridas de %s.",
    ['treated_by'] = '%s tratou-te as feridas.',

    -- injuries
    ['injury_worse'] = 'Parte do corpo: %s, estado: %s.',
    ['injury_better'] = 'Uma das tuas feridas está melhor.',
    ['no_injuries'] = 'Não tens feridas para tratar.',
    ["need_item"] = "Precisas de: %s.",
    ["cannot_now"] = "Agora não podes fazer isso.",
    ["bandaging"] = "A ligar...",
    ["bandaged"] = "Fizeste um curativo a ti mesmo.",
    ["lost_items"] = "Tudo o que levavas desapareceu.",
    ['bleeding'] = 'Estás a sangrar.',
    ['part_head'] = 'cabeça',
    ['part_torso'] = 'peito',
    ['part_left_arm'] = 'braço esquerdo',
    ['part_right_arm'] = 'braço direito',
    ['part_left_leg'] = 'perna esquerda',
    ['part_right_leg'] = 'perna direita',
    ['state_healthy'] = 'são',
    ['state_injured'] = 'ferido',
    ['state_broken'] = 'partido',
    ['state_bleeding'] = 'a sangrar',

    -- hospitals
    ['place_valentine'] = 'médico de Valentine',
    ['place_blackwater'] = 'médico de Blackwater',
    ['place_strawberry'] = 'médico de Strawberry',
    ['place_armadillo'] = 'médico de Armadillo',
    ['place_tumbleweed'] = 'médico de Tumbleweed',
    ['place_saintdenis'] = 'médico de Saint Denis',
    ['place_rhodes'] = 'médico de Rhodes',
    ['place_vanhorn'] = 'médico de Van Horn',
    ['place_annesburg'] = 'médico de Annesburg',

    -- commands
    ['cmd_revive'] = 'Reanimar-te a ti ou a um jogador (admin)',
    ['cmd_heal'] = 'Curar-te a ti ou a um jogador (admin)',
    ['cmd_kill'] = 'Matar um jogador (admin)',
    ['cmd_id'] = 'ID do jogador',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) morreu',
    ['log_text'] = '%s foi morto por %s (causa %s)',
    ['log_unknown'] = 'desconhecido',
}

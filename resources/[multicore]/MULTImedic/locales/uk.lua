-- MULTImedic: Українська
Locales = Locales or {}
Locales['uk'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Ви непритомні',
    ['ui_sub'] = 'Чекайте на лікаря або поки не повернуться сили',
    ['ui_sub_ready'] = 'Ви можете звестися на ноги',
    ['ui_wait'] = 'Відродження через',
    ['ui_hold_respawn'] = 'Утримуйте, щоб прийти до тями в лікаря',
    ['ui_fee'] = "Плата лікарю: $%s",
    ['ui_call'] = 'Покликати лікаря',
    ['ui_call_sending'] = 'Надсилаємо звістку...',
    ['ui_call_sent'] = 'По лікаря послали',
    ['ui_call_none'] = 'Жоден лікар не відповів',
    ['ui_call_wait'] = 'Ви щойно кликали',
    ['ui_call_failed'] = 'Не вдалося надіслати виклик',
    ['ui_call_again'] = 'знову через %sс',
    ['ui_medics'] = 'Лікарів у краї: %s',
    ['ui_no_medics'] = 'Жоден лікар не на зміні',

    -- respawn
    ['too_early'] = 'Ви ще надто слабкі, щоб підвестися.',
    ['respawned'] = 'Ви прийшли до тями у %s.',
    ['respawned_fee'] = 'Ви прийшли до тями у %s. Лікар узяв $%s.',
    ['lost_cash'] = 'Ваша готівка зникла.',
    ['lost_bloodmoney'] = 'Ваші криваві гроші зникли.',

    -- doctor calls
    ['alert_text'] = '%s лежить і потребує лікаря',
    ['alert_default'] = 'Комусь потрібен лікар',
    ['doctor_called'] = 'Звістку лікарям надіслано.',
    ['no_medics'] = 'Зараз жоден лікар не на зміні.',
    ['call_cooldown'] = 'Ви щойно надіслали виклик. Зачекайте трохи.',

    -- medic actions
    ['reviving'] = 'Приводите до тями...',
    ['treating'] = 'Обробляєте рани...',
    ['target_revive'] = 'Привести до тями',
    ['target_treat'] = 'Обробити рани',
    ['not_medic'] = 'Ви не лікар на зміні.',
    ['no_player'] = 'Там немає гравця.',
    ['nobody_down'] = 'Поруч ніхто не лежить.',
    ['not_down'] = 'Ця людина при тямі.',
    ['is_down'] = 'Ця людина непритомна; спершу приведіть її до тями.',
    ['too_far'] = 'Ви надто далеко.',
    ['you_revived'] = 'Ви привели до тями: %s.',
    ['revived_by'] = '%s привів вас до тями.',
    ['you_treated'] = "Ви обробили рани: %s.",
    ['treated_by'] = '%s обробив ваші рани.',

    -- injuries
    ['injury_worse'] = 'Стан: %s — %s.',
    ['injury_better'] = 'Одна з ваших ран загоїлася краще.',
    ['no_injuries'] = 'У вас немає ран, які треба лікувати.',
    ["need_item"] = "Вам потрібен %s.",
    ["cannot_now"] = "Зараз цього зробити не можна.",
    ["bandaging"] = "Перев’язуєте...",
    ["bandaged"] = "Ви себе підлатали.",
    ["lost_items"] = "Усе, що ви несли, зникло.",
    ['bleeding'] = 'Ви стікаєте кров’ю.',
    ['part_head'] = 'голова',
    ['part_torso'] = 'груди',
    ['part_left_arm'] = 'ліва рука',
    ['part_right_arm'] = 'права рука',
    ['part_left_leg'] = 'ліва нога',
    ['part_right_leg'] = 'права нога',
    ['state_healthy'] = 'ціле',
    ['state_injured'] = 'поранено',
    ['state_broken'] = 'зламано',
    ['state_bleeding'] = 'кровоточить',

    -- hospitals
    ['place_valentine'] = 'лікаря у Valentine',
    ['place_blackwater'] = 'лікаря у Blackwater',
    ['place_strawberry'] = 'лікаря у Strawberry',
    ['place_armadillo'] = 'лікаря в Armadillo',
    ['place_tumbleweed'] = 'лікаря у Tumbleweed',
    ['place_saintdenis'] = 'лікаря в Saint Denis',
    ['place_rhodes'] = 'лікаря у Rhodes',
    ['place_vanhorn'] = 'лікаря у Van Horn',
    ['place_annesburg'] = 'лікаря в Annesburg',

    -- commands
    ['cmd_revive'] = 'Привести до тями себе або гравця (адмін)',
    ['cmd_heal'] = 'Вилікувати себе або гравця (адмін)',
    ['cmd_kill'] = 'Вбити гравця (адмін)',
    ['cmd_id'] = 'ID гравця',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) загинув',
    ['log_text'] = '%s вбив %s (причина %s)',
    ['log_unknown'] = 'невідомо',
}

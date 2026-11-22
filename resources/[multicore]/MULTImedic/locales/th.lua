-- MULTImedic: Thai (same keys as the English master file)
Locales = Locales or {}
Locales['th'] = {
    -- death screen (NUI)
    ['ui_title'] = 'คุณหมดสติ',
    ['ui_sub'] = 'รอหมอ หรือรอให้แรงกลับคืนมา',
    ['ui_sub_ready'] = 'คุณลุกขึ้นได้แล้ว',
    ['ui_wait'] = 'ฟื้นได้ในอีก',
    ['ui_hold_respawn'] = 'กดค้างเพื่อฟื้นที่หมอ',
    ['ui_fee'] = "ค่าหมอ: $%s",
    ['ui_call'] = 'เรียกหมอ',
    ['ui_call_sending'] = 'กำลังส่งข่าว...',
    ['ui_call_sent'] = 'ส่งคนไปตามหมอแล้ว',
    ['ui_call_none'] = 'ไม่มีหมอตอบรับ',
    ['ui_call_wait'] = 'คุณเพิ่งเรียกไปเมื่อครู่',
    ['ui_call_failed'] = 'ส่งการเรียกไม่ได้',
    ['ui_call_again'] = 'เรียกอีกครั้งใน %ss',
    ['ui_medics'] = 'หมอในพื้นที่: %s',
    ['ui_no_medics'] = 'ไม่มีหมอเข้าเวร',

    -- respawn
    ['too_early'] = 'คุณยังไม่มีแรงพอจะลุกขึ้น',
    ['respawned'] = 'คุณฟื้นขึ้นที่%s',
    ['respawned_fee'] = 'คุณฟื้นขึ้นที่%s หมอคิดค่ารักษา $%s',
    ['lost_cash'] = 'เงินสดของคุณหายไปหมด',
    ['lost_bloodmoney'] = 'เงินเปื้อนเลือดของคุณหายไปหมด',

    -- doctor calls
    ['alert_text'] = '%s ล้มลงและต้องการหมอ',
    ['alert_default'] = 'มีคนต้องการหมอ',
    ['doctor_called'] = 'ส่งข่าวถึงหมอแล้ว',
    ['no_medics'] = 'ตอนนี้ไม่มีหมอเข้าเวร',
    ['call_cooldown'] = 'คุณเพิ่งเรียกไป รอสักครู่',

    -- medic actions
    ['reviving'] = 'กำลังช่วยฟื้น...',
    ['treating'] = 'กำลังรักษาบาดแผล...',
    ['target_revive'] = 'ช่วยฟื้น',
    ['target_treat'] = 'รักษาบาดแผล',
    ['not_medic'] = 'คุณไม่ใช่หมอที่เข้าเวร',
    ['no_player'] = 'ไม่มีผู้เล่นตรงนั้น',
    ['nobody_down'] = 'ไม่มีใครใกล้คุณที่ล้มอยู่',
    ['not_down'] = 'คนนี้ไม่ได้หมดสติ',
    ['is_down'] = 'คนนี้หมดสติอยู่ ช่วยฟื้นก่อน',
    ['too_far'] = 'คุณอยู่ไกลเกินไป',
    ['you_revived'] = 'คุณช่วยฟื้น %s แล้ว',
    ['revived_by'] = '%s ช่วยให้คุณฟื้น',
    ['you_treated'] = "คุณรักษาบาดแผลให้ %s แล้ว",
    ['treated_by'] = '%s รักษาบาดแผลให้คุณ',

    -- injuries
    ['injury_worse'] = '%sของคุณ%s',
    ['injury_better'] = 'บาดแผลหนึ่งของคุณดีขึ้นแล้ว',
    ['no_injuries'] = 'คุณไม่มีบาดแผลให้รักษา',
    ["need_item"] = "คุณต้องมี %s",
    ["cannot_now"] = "ตอนนี้ทำแบบนั้นไม่ได้",
    ["bandaging"] = "กำลังพันแผล...",
    ["bandaged"] = "คุณทำแผลให้ตัวเองแล้ว",
    ["lost_items"] = "ของทุกอย่างที่คุณพกมาหายไปหมด",
    ['bleeding'] = 'คุณกำลังเลือดออก',
    ['part_head'] = 'ศีรษะ',
    ['part_torso'] = 'หน้าอก',
    ['part_left_arm'] = 'แขนซ้าย',
    ['part_right_arm'] = 'แขนขวา',
    ['part_left_leg'] = 'ขาซ้าย',
    ['part_right_leg'] = 'ขาขวา',
    ['state_healthy'] = 'ปกติดี',
    ['state_injured'] = 'บาดเจ็บ',
    ['state_broken'] = 'หัก',
    ['state_bleeding'] = 'เลือดออก',

    -- hospitals
    ['place_valentine'] = 'หมอ Valentine',
    ['place_blackwater'] = 'หมอ Blackwater',
    ['place_strawberry'] = 'หมอ Strawberry',
    ['place_armadillo'] = 'หมอ Armadillo',
    ['place_tumbleweed'] = 'หมอ Tumbleweed',
    ['place_saintdenis'] = 'หมอ Saint Denis',
    ['place_rhodes'] = 'หมอ Rhodes',
    ['place_vanhorn'] = 'หมอ Van Horn',
    ['place_annesburg'] = 'หมอ Annesburg',

    -- commands
    ['cmd_revive'] = 'ช่วยฟื้นตัวเองหรือผู้เล่น (แอดมิน)',
    ['cmd_heal'] = 'รักษาตัวเองหรือผู้เล่น (แอดมิน)',
    ['cmd_kill'] = 'ฆ่าผู้เล่น (แอดมิน)',
    ['cmd_id'] = 'ไอดีผู้เล่น',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) เสียชีวิต',
    ['log_text'] = '%s ถูกฆ่าโดย %s (สาเหตุ %s)',
    ['log_unknown'] = 'ไม่ทราบ',
}

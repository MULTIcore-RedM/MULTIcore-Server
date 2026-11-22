-- MULTImedic: Indonesian
Locales = Locales or {}
Locales['id'] = {
    -- death screen (NUI)
    ['ui_title'] = 'Kamu pingsan',
    ['ui_sub'] = 'Tunggu dokter, atau sampai tenagamu pulih',
    ['ui_sub_ready'] = 'Kamu bisa berdiri lagi',
    ['ui_wait'] = 'Kamu bisa muncul kembali dalam',
    ['ui_hold_respawn'] = 'Tahan untuk muncul kembali di dokter',
    ['ui_fee'] = "Biaya dokter: $%s",
    ['ui_call'] = 'Panggil dokter',
    ['ui_call_sending'] = 'Mengirim kabar...',
    ['ui_call_sent'] = 'Dokter sudah dipanggil',
    ['ui_call_none'] = 'Tak ada dokter yang menjawab',
    ['ui_call_wait'] = 'Kamu baru saja memanggil',
    ['ui_call_failed'] = 'Panggilan tidak bisa dikirim',
    ['ui_call_again'] = 'panggil lagi dalam %ss',
    ['ui_medics'] = 'Dokter di wilayah: %s',
    ['ui_no_medics'] = 'Tidak ada dokter yang bertugas',

    -- respawn
    ['too_early'] = 'Kamu belum cukup kuat untuk bangun.',
    ['respawned'] = 'Kamu siuman di %s.',
    ['respawned_fee'] = 'Kamu siuman di %s. Dokter menagih $%s.',
    ['lost_cash'] = 'Uang tunaimu hilang.',
    ['lost_bloodmoney'] = 'Uang darahmu hilang.',

    -- doctor calls
    ['alert_text'] = '%s tumbang dan butuh dokter',
    ['alert_default'] = 'Seseorang butuh dokter',
    ['doctor_called'] = 'Kabar sudah dikirim ke para dokter.',
    ['no_medics'] = 'Tidak ada dokter yang bertugas saat ini.',
    ['call_cooldown'] = 'Kamu baru saja memanggil. Tunggu sebentar.',

    -- medic actions
    ['reviving'] = 'Menyadarkan...',
    ['treating'] = 'Merawat luka...',
    ['target_revive'] = 'Sadarkan',
    ['target_treat'] = 'Rawat luka',
    ['not_medic'] = 'Kamu bukan dokter yang bertugas.',
    ['no_player'] = 'Tidak ada pemain di sana.',
    ['nobody_down'] = 'Tak ada orang tumbang di dekatmu.',
    ['not_down'] = 'Orang itu tidak pingsan.',
    ['is_down'] = 'Orang itu pingsan; sadarkan dia dulu.',
    ['too_far'] = 'Kamu terlalu jauh.',
    ['you_revived'] = 'Kamu menyadarkan %s.',
    ['revived_by'] = '%s menyadarkanmu.',
    ['you_treated'] = "Kamu merawat luka %s.",
    ['treated_by'] = '%s merawat lukamu.',

    -- injuries
    ['injury_worse'] = '%s kamu %s.',
    ['injury_better'] = 'Salah satu lukamu membaik.',
    ['no_injuries'] = 'Kamu tidak punya luka untuk dirawat.',
    ["need_item"] = "Kamu butuh %s.",
    ["cannot_now"] = "Kamu tidak bisa melakukannya sekarang.",
    ["bandaging"] = "Membalut...",
    ["bandaged"] = "Kamu mengobati dirimu sendiri.",
    ["lost_items"] = "Semua yang kamu bawa hilang.",
    ['bleeding'] = 'Kamu berdarah.',
    ['part_head'] = 'kepala',
    ['part_torso'] = 'dada',
    ['part_left_arm'] = 'lengan kiri',
    ['part_right_arm'] = 'lengan kanan',
    ['part_left_leg'] = 'kaki kiri',
    ['part_right_leg'] = 'kaki kanan',
    ['state_healthy'] = 'sehat',
    ['state_injured'] = 'terluka',
    ['state_broken'] = 'patah',
    ['state_bleeding'] = 'berdarah',

    -- hospitals
    ['place_valentine'] = 'dokter Valentine',
    ['place_blackwater'] = 'dokter Blackwater',
    ['place_strawberry'] = 'dokter Strawberry',
    ['place_armadillo'] = 'dokter Armadillo',
    ['place_tumbleweed'] = 'dokter Tumbleweed',
    ['place_saintdenis'] = 'dokter Saint Denis',
    ['place_rhodes'] = 'dokter Rhodes',
    ['place_vanhorn'] = 'dokter Van Horn',
    ['place_annesburg'] = 'dokter Annesburg',

    -- commands
    ['cmd_revive'] = 'Sadarkan dirimu atau pemain (admin)',
    ['cmd_heal'] = 'Sembuhkan dirimu atau pemain (admin)',
    ['cmd_kill'] = 'Bunuh pemain (admin)',
    ['cmd_id'] = 'ID pemain',

    -- death log (rsg-log)
    ['log_title'] = '%s (%s) mati',
    ['log_text'] = '%s dibunuh oleh %s (penyebab %s)',
    ['log_unknown'] = 'tidak diketahui',
}

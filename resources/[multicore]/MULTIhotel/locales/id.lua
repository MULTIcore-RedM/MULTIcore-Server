Locales = Locales or {}
Locales['id'] = {
    -- general
    ['notify_title'] = "Hotel",
    ['too_far'] = "Kamu terlalu jauh dari meja resepsionis.",
    ['not_enough_money'] = "Uangmu tidak cukup.",
    ['bad_amount'] = "Masukkan jumlah yang valid.",
    ['not_owner'] = "Hanya tamu yang menyewa kamar ini yang bisa melakukannya.",
    ['no_active_room'] = "Kamu tidak berada di kamar hotel.",

    -- hotels
    ['hotel_valentine'] = "Hotel Valentine",
    ['hotel_strawberry'] = "Hotel Strawberry",
    ['hotel_rhodes'] = "Hotel Rhodes",
    ['hotel_stdenis'] = "Hotel Saint Denis",
    ['hotel_blackwater'] = "Hotel Blackwater",
    ['hotel_tumbleweed'] = "Hotel Tumbleweed",
    ['hotel_annesburg'] = "Hotel Annesburg",

    -- renting and checking in
    ['already_have_room'] = "Kamu sudah punya kamar di hotel ini.",
    ['no_free_room'] = "Tidak ada kamar kosong saat ini. Coba lagi nanti.",
    ['rented'] = "Kamu menyewa kamar %s di %s.",
    ['no_room_here'] = "Kamu tidak punya kamar di hotel ini.",
    ['not_a_guest'] = "Kamu bukan tamu di hotel ini.",
    ['guest_checked_in'] = "Check-in sebagai tamu ke kamar %s.",
    ['room_lost'] = "Kredit kamarmu %s habis dan kamarnya dilepas.",

    -- credit
    ['credit_too_high'] = "Sebuah kamar hanya bisa menyimpan kredit maksimal $%s.",
    ['credit_added'] = "Menambah kredit $%s. Kredit sekarang: $%s.",
    ['cannot_withdraw'] = "Kamu tidak bisa mengambil kredit lebih dari yang ada di kamar.",
    ['credit_withdrawn'] = "Mengambil kredit $%s. Kredit sekarang: $%s.",

    -- locker
    ['locker_label'] = "Loker kamar %s",
    ['locker_failed'] = "Loker kamar tidak bisa dibuka.",

    -- guests
    ['player_not_found'] = "Pemain itu tidak ditemukan.",
    ['player_not_near'] = "Pemain itu tidak cukup dekat.",
    ['nobody_near'] = "Tidak ada yang cukup dekat untuk diundang.",
    ['already_guest'] = "Pemain itu sudah menjadi tamu.",
    ['max_guests'] = "Kamar ini sudah mencapai batas tamu (%s).",
    ['guest_added'] = "%s sekarang tamu kamarmu.",
    ['guest_removed'] = "%s bukan lagi tamu kamarmu.",
    ['you_were_invited'] = "%s mengundangmu ke kamar %s di %s.",
    ['you_were_removed'] = "Kamu bukan lagi tamu kamar %s.",

    -- throwing guests out
    ['evict_cooldown'] = "Tunggu %s detik sebelum mengusir tamu lagi.",
    ['no_guests_to_evict'] = "Tidak ada tamu untuk diusir.",
    ['evicted'] = "%s tamu diusir dari kamarmu.",
    ['evicted_and_removed'] = "%s tamu diusir dan dihapus dari daftar tamu.",
    ['you_were_evicted'] = "%s mengusirmu dari kamar.",
    ['evict_confirm'] = "Ini akan langsung mengeluarkan %s tamu dari kamarmu. Lanjutkan?",

    -- telegrams
    ['telegram_sender'] = "Resepsionis Hotel",
    ['tg_invite_subject'] = "Undangan kamar hotel",
    ['tg_invite_body'] = "%s mengundangmu ke kamar %s di %s. Minta di meja resepsionis untuk check-in sebagai tamu.",
    ['tg_evicted_subject'] = "Diusir dari kamar hotel",
    ['tg_evicted_body'] = "%s mengusirmu dari kamar %s. Kamu masih bisa check-in sebagai tamu nanti.",
    ['tg_evicted_body_removed'] = "%s mengusirmu dari kamar %s dan menarik undanganmu.",
    ['tg_low_subject'] = "Kredit kamar hampir habis",
    ['tg_low_body'] = "Kredit untuk kamar %s di %s hampir habis: sisa $%s. Tambah kredit di menu kamar.",
    ['tg_lost_subject'] = "Kamar dilepas",
    ['tg_lost_body'] = "Kredit kamar %s di %s habis, jadi kamu sudah check-out. Terima kasih telah menginap bersama kami.",

    -- logs (MULTIserver)
    ['log_rented'] = "Kamar hotel disewa",
    ['log_evicted'] = "Tamu hotel diusir",
    ['log_lost'] = "Kamar hotel hilang",

    -- desk menu
    ['menu_check_in'] = "Check-in",
    ['menu_check_in_desc'] = "Naik ke kamar %s. Kredit: $%s",
    ['menu_rent'] = "Sewa kamar ($%s)",
    ['menu_rent_desc'] = "Uangnya menjadi kredit pertama kamarmu.",
    ['menu_guest_check_in'] = "Check-in tamu",
    ['menu_guest_check_in_desc'] = "Naik ke kamar tempat kamu diundang.",

    -- room menu
    ['room_title'] = "Kamar %s",
    ['badge_guest'] = "Tamu",
    ['menu_add_credit'] = "Tambah kredit",
    ['menu_credit_now'] = "Kredit sekarang: $%s",
    ['menu_remove_credit'] = "Ambil kredit",
    ['menu_remove_credit_desc'] = "Ambil kembali uang dari kredit kamar.",
    ['menu_guests'] = "Tamu",
    ['menu_guests_desc'] = "Undang pemain atau tarik undangan.",
    ['menu_evict'] = "Usir tamu",
    ['menu_evict_desc'] = "Langsung keluarkan semua tamu dari kamar.",
    ['menu_locker'] = "Loker kamar",
    ['menu_locker_desc'] = "Simpan barang-barangmu.",
    ['menu_guest_access'] = "Akses tamu",
    ['menu_owner'] = "Kamar milik %s",
    ['menu_leave'] = "Tinggalkan kamar",
    ['menu_leave_desc'] = "Turun kembali ke jalan.",
    ['menu_mail'] = "Telegram",
    ['menu_mail_desc'] = "Baca dan kirim telegram.",
    ['input_add_label'] = "Jumlah yang ditambah (kredit sekarang: $%s)",
    ['input_remove_label'] = "Jumlah yang diambil (kredit sekarang: $%s)",

    -- guest menu
    ['menu_add_guest'] = "Undang pemain",
    ['menu_add_guest_desc'] = "Pemain di dekatmu.",
    ['menu_current_guests'] = "Tamu",
    ['menu_no_guests'] = "Tidak ada tamu",
    ['menu_no_guests_desc'] = "Kamu belum mengundang siapa pun.",
    ['menu_guest_row'] = "Mengundang %s. Pilih untuk menarik undangan.",
    ['menu_invite'] = "Undang pemain",
    ['menu_invite_row'] = "ID %s. Pilih untuk mengundang.",

    -- interaction
    ['prompt_desk'] = "%s",
    ['prompt_room'] = "Menu kamar",
    ['target_desk'] = "Meja resepsionis",
    ['target_room'] = "Menu kamar",

    -- page
    ['ui_subtitle'] = "Layanan Tamu",
    ['ui_back'] = "Kembali",
    ['ui_close'] = "Tutup",
    ['ui_cancel'] = "Batal",
    ['ui_confirm'] = "Konfirmasi",
    ['ui_amount'] = "Jumlah",
    ['ui_max'] = "Maks",
    ['ui_valid_amount'] = "Masukkan jumlah yang valid",
    ['ui_success'] = "Berhasil",
    ['ui_error'] = "Galat",
    ['ui_info'] = "Info",
    ['ui_notice'] = "Pemberitahuan",
}

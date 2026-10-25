# Audit skill Studio — 24 Oktober 2026

## Hasil aktual
- 42 kartu tersimpan (30 Base + 12 Fusion), 84 slot skill cetak.
- **0/84 slot terhubung ke skill battle.** Semua 42 kartu menghasilkan 0 runtime skill saat masuk battle.
- Salinan RFID untuk 30 kartu Base juga menghasilkan 0 runtime skill.
- Percobaan aktivasi setiap slot ditolak: “Special Skill tidak ditemukan pada Card ini.” AP, HP, giliran dan event tetap sama.
- 41 slot memiliki definisi katalog dengan nama sama, tetapi tidak ada definisi bernama sama yang aktif. Kesamaan nama bukan bukti bahwa efeknya sesuai.

## Metode
`tests/battle/studioSavedSkillAudit.sql` menggunakan data kartu tersimpan, trigger snapshot asli, salinan RFID dengan binding sumber, dan `submit_battle_action`. Fixture memakai `origin_type=fusion`/UID null untuk Fusion. Seluruh battle, salinan, action receipts dan event percobaan di-rollback; kartu pengguna tidak diubah.

Regresi engine terpisah (`remoteSkillSmoke.sql`) lulus untuk real heal, AP override, dua skill independen, idempotency, token, CD2, persistensi cooldown lintas zona, dan penolakan skill nonaktif/battle selesai. Ini **bukan** kelulusan efek 84 skill Studio: efeknya belum terpasang sehingga belum dapat diuji.

## Pekerjaan yang masih diperlukan
Setiap skill perlu definisi executable (target, efek, kondisi, AP, cooldown dan batas pemakaian), binding slot 1/2 ke kartu, lalu pengujian efek per skill. Jangan mengaktifkan semua definisi katalog berdasarkan nama atau menganggap teks cetak otomatis menjadi aturan battle.

Rincian setiap slot: [CSV audit](studio-skill-audit-2026-10-24.csv).

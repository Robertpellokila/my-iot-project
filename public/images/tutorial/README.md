# Panduan battle interaktif

Home memakai screenshot Player Battle dan Public Battle (Stadium) dengan penanda
bernomor yang membuka penjelasan menu. Teks/aturan ada di `src/data/battleGuide.js`;
koordinat ada di `src/data/battle-guide-screens.json`.

Perbarui screenshot setelah layout berubah:

```sh
node scripts/capture-battle-guide.mjs
```

Script menjalankan Vite terpisah pada port 5185 dan Chrome headless, memakai
fixture Alya/Raka, memalsukan permintaan battle, dan memblokir realtime. Tidak ada
akun, UID, atau pertandingan sungguhan yang diubah. Ilustrasi yang sudah publik
dapat dibaca lewat RPC publik; ilustrasi starter lokal menjadi fallback offline.
Chrome dan konfigurasi Vite project diperlukan.

Fixture kartu dan kedua skill dibagi dengan tes panel aksi melalui
`scripts/lib/battle-demo.mjs`. Screenshot pemain memilih Coby sehingga konteks
kartu, kedua skill, AP, dan panel aksi terbaru terlihat. Perbarui juga penjelasan
di `battleGuide.js` jika label/alur tombol berubah.

Output: `player-battle-guide.jpg`, `public-battle-guide.jpg`, dan koordinat penanda.
Kedua gambar lazy-loaded dengan ukuran tetap. Ponsel menyediakan daftar tombol
menu yang sama dan menggulir ke penjelasan setelah penanda dipilih.

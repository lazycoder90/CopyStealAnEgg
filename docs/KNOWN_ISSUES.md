# Known issues

Format: gejala, langkah reproduksi, dugaan penyebab, status.

Tidak ada bug terbuka yang diketahui pada fitur yang diuji otomatis; batasan di bawah belum terverifikasi.

## Batasan pengujian (bukan bug, tapi belum teruji)
- Multi-pemain sungguhan dan latensi jaringan (PvP diuji dengan bot).
- DataStore asli (Studio memakai mock store), pembelian Robux, perangkat mobile.
- Pemeriksaan tipe statis antarmodul (`luau-lsp`) tidak tersedia.

## UI di perangkat sentuh kecil
- `UIScale` pada ScreenGui menyusutkan isi ke pojok kiri atas, jadi skala UI hanya aktif untuk perangkat sentuh berlayar pendek (< 600 px); di desktop skala selalu 1. Tata letak ponsel belum terverifikasi: perlu dicek di emulator/ponsel. Perbaikan menyeluruh membutuhkan satu container akar per ScreenGui (Size = 1/skala) dan hanya layak dilakukan dengan uji visual langsung.

## Pengujian visual
- Tool `screen_capture` MCP sering menggantung (>120 dtk) dan `Camera.ViewportSize` terbaca 1x1 pada sesi Play otomatis, sehingga tata letak visual (UI, kamera sinematik, efek atmosfer) tidak terverifikasi lewat screenshot untuk Wave 4-5. Tes struktur (jumlah/pemilik elemen, atribut) lulus; penampilan perlu dicek manual di Studio.

## Temuan review yang sengaja tidak diubah (risiko rendah / keputusan desain)
- **ProcessReceipt tidak menunggu penyimpanan profil.** Grant Robux dikembalikan `PurchaseGranted` setelah perubahan di memori; jika server crash sebelum ProfileStore menyimpan, pembelian bisa hilang. Mitigasi lanjutan: tunggu simpan profil (ProfileStore auto-save + `EndSession`) sebelum mengembalikan hasil. Belum diuji karena ID produk masih 0.
- **`ClaimFreeBasket` bisa dipanggil dari mana saja** (chip HUD "Basket ready!" memang mengirimnya); cooldown 15 menit tetap berlaku.
- **`LeaderboardService` tidak menulis nilai akhir saat pemain keluar** (tulis tiap 120 detik); papan dunia bisa tertinggal sampai 2 menit.
- **`PlacementService.place`: `consume` mengeluarkan telur dari profil korban sebelum `insert`** dan `insert` tidak dibungkus pcall. Tidak ada pemicu yang diketahui (semua langkah sinkron), tapi bila `insert` melempar error, telur curian bisa hilang. Perbaikan defensif: pcall + kembalikan ke korban.
- **Tata letak top-center** (ZoneBanner, Carry, Toasts, AnnouncementFeed, StealAlert, Tutorial) bisa tumpang tindih sesaat saat beberapa muncul bersamaan; tidak terverifikasi secara visual.
- **Aset visual & audio** masih placeholder (bentuk dasar; 9 suara bawaan Studio tanpa musik).

## Diperbaiki berdasarkan review kode (terbukti oleh suite `Hardening`)
Grace roda tak lagi memaafkan teleport jauh; stun tidak bisa dibatalkan oleh Slow Mode/Trail/roda; imunitas tutorial dibatasi jendela newbie 5 menit dan percepatan tutorial hanya untuk telur pertama berrarity rendah; pencuri kehilangan proteksi newbie; kebal-pickup berlaku pada `recover`; "dicuri" dihitung sekali per telur; Skip Growth mewajibkan tier produk yang dibeli; provider income yang error tidak lagi mematikan income semua pemain; badge Shield/alert tahan respawn; stack HUD ditambatkan dari atas; sinematik punya batas waktu keras.

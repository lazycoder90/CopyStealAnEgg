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

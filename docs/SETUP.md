# Setup: menguji game lewat Claude + Roblox Studio

Tujuan: Claude bisa menekan Play, membaca Output, dan mengambil screenshot di Studio sendiri.
Anda hanya perlu melakukan langkah di bawah **sekali**.

## 1. Mulai ulang Claude Code (sekali)
1. Ketik `/exit` di Claude Code.
2. Jalankan `claude --continue` di folder proyek ini (percakapan dilanjutkan).
3. Saat muncul pertanyaan untuk menyetujui server `Roblox_Studio`, pilih setuju.

## 2. Nyalakan MCP di Roblox Studio (sekali)
1. Buka Roblox Studio dan login.
2. Buka panel **Assistant**.
3. Klik tombol **…** lalu **Manage MCP Servers**.
4. Nyalakan **Enable Studio as MCP server**.
5. Saat Claude terhubung, muncul indikator hijau di tempat yang sama.

Jika menu tidak ada atau berbeda, pastikan Studio versi terbaru dan sudah login. Kirim screenshot ke Claude.

## 3. Selesai
Setelah itu cukup minta Claude, misalnya: "tes game-nya". Claude akan build, membuka Studio, menekan Play,
membaca Output, dan melaporkan hasilnya.

## Jika koneksi putus
- Matikan lalu nyalakan lagi toggle **Enable Studio as MCP server**.
- Atau mulai ulang Claude Code (`/exit`, lalu `claude --continue`).

## Catatan keamanan
Klien MCP yang terhubung bisa membaca dan mengubah isi place yang terbuka di Studio.
Hanya place hasil build dari repo ini yang dipakai, dan place itu selalu bisa dibangun ulang dengan
`rojo build default.project.json -o build/NestBandits.rbxl`.

## Perintah pengembangan (dijalankan Claude)
- Tes logika: `lune run tests/run`
- Lint: `selene src`
- Format: `stylua --check src tests`
- Build place: `rojo build default.project.json -o build/NestBandits.rbxl`

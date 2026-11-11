# PROGRESS: sumber kebenaran pengerjaan otonom

Rencana: `/Users/eko/.claude/plans/binary-sauteeing-riddle.md` (strategi) dan `docs/PLAN.md` (spesifikasi fitur).

## Cara melanjutkan jika sesi terputus
1. `cd` ke folder proyek. Pastikan `rojo serve default.project.json` berjalan (port 34872) dan Studio tersambung (Plugins → Rojo → Connect).
2. Baca bagian "Checklist" di bawah, lanjutkan dari item pertama yang belum `[x]`.
3. Uji lewat MCP Roblox_Studio: `start_stop_play`, lalu `ServerStorage.TestBridge:Invoke("test.run", "<Feature>")`.

## Keputusan
- Git: remote `git@github.com:lazycoder90/CopyStealAnEgg.git`, branch `main`. Commit identitas lokal repo: "Claude Code". Push di akhir tiap gelombang.
- Scope dipangkas: lihat `docs/DEFERRED.md`.
- `luau-lsp` tidak dipasang (unduhan binary luar ditolak pengaman). Pengganti: stub bertipe, laporan boot, tes Lune, tes Studio.
- Skenario uji Studio berada di `src/server/Tests/*.luau` (ikut tersinkron lewat Rojo), dijalankan lewat TestBridge `test.run`, bukan `tests/studio/` (lebih kecil untuk dipanggil dari MCP).
- Stub bertipe dibuat per gelombang (tepat sebelum agen dijalankan), bukan seluruh fase di awal, supaya tidak menebak API yang belum ada.

## Checklist
- [x] Fase 0: fondasi (commit b399424)
- [x] Langkah 0: git, remote, Rojo live sync
- [x] Wave 0: infrastruktur kontrak (commit b14ceb6)
- [x] Wave 1 / Fase 1: core loop (peta, telur, carry, place, hatch, pet, income, klien). Studio: Boot 17, CoreLoop 50, Life 27, Death 9 = 103 lulus; Lune 942 lulus.
- [x] Wave 2 / Fase 2+3: Speed/Wheel/Upgrade/Trail/AntiExploit, Guardian/Zone/Tutorial/Impact, Steal/Defense/Bots. Studio: 367 pemeriksaan lulus (Boot 17, CoreLoop 50, Life 27, Death 9, Progression 62, Guardian 46, Tutorial 35, Steal 57, Defense 64); Lune 1471.
- [ ] Wave 3 / Fase 4
- [ ] Wave 4 / Fase 5
- [ ] Wave 5 / Fase 6+7
- [ ] Review kode paralel + soak test
- [ ] Laporan akhir

## Catatan Wave 1
- Rekomendasi ekonomi dari simulasi (docs/ECONOMY.md) BELUM diterapkan: harga Sprint Wheel `1500*5.5^(L-1)`, hadiah speed Index `recSpeed*0.0005*slot`, wheel maxLevel ~30. Terapkan di Wave 2 saat Sprint Wheel dibangun (spec Formulas perlu diubah bersamanya).
- Pemindahan ke Coop saat spawn memakai pengecekan berulang (engine menaruh karakter di SpawnLocation sesaat setelah CharacterAdded).
- Tes Studio yang memindahkan pemain harus menunggu >= 1.2 detik setelah wipe/rejoin.
- Cara menjalankan tes: `ServerStorage.TestBridge:Invoke("test.run", "<Boot|CoreLoop|Life|Death>")` setelah Play.

## Catatan Wave 2
- BUG NYATA ditemukan lewat jalan sungguhan: celah lantai 30 stud antara hub (z<=120) dan lane (z>=150). Diperbaiki: `Layout.hubZMax = 150`. Tes teleport tidak menangkapnya; gunakan `character_navigation` untuk uji jalan.
- AntiExploit aktif: teleport uji harus lewat `TestBridge.teleport` (memberi grace). Tool navigasi MCP dengan speed > 1 memicu rubber-band (wajar).
- `EggSpawnService.takeEgg` kini tahan terhadap model telur yang sudah hancur.
- Daftar suite Studio: Boot, CoreLoop, Life, Death, Progression, Guardian, Tutorial, Steal (~50 dtk), Defense (~45 dtk). Selalu `bot.removeAll` setelah suite berbot.
- docs/ECONOMY.md rec #2 (hadiah speed Index) dan #3 diterapkan di Wave 3 / sudah (wheel maxLevel 30).

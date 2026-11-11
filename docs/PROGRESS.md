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
- [x] Wave 3 / Fase 4: Sell, Inventory, Growing Eggs, Index, Fuse, Mutation NPC, Offline, Free Basket, Friend Boost, Leaderboard. Studio total 609 pemeriksaan lulus (17 suite); Lune 1751.
- [x] Wave 4 / Fase 5: Day/Night + Moonlit, Egg Reset + Announcement, Bud (Companion), Dash Derby, Starwhale (Relay puzzle, Compass, odd eggs, pods, trade). Studio total ~903 pemeriksaan (24 suite) lulus; Lune 6938.
- [x] Wave 5 / Fase 6+7: Monetization (ID 0 = nonaktif aman), Badge, Settings, Shop, NEXT UPDATE, Sound/Atmosphere/Juice/Cinematic/Graphics/Settings UI. Studio total ~1018 pemeriksaan (27 suite) lulus; Lune 7161.
- [x] Review kode paralel (3 reviewer) + perbaikan + soak test 30x (~60 menit waktu-game: 0 pelanggaran invarian, instance/memori stabil)
- [x] Laporan akhir (lihat pesan terakhir dan docs/SETUP.md)

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

## Catatan Wave 3
- Hub stall dibangun di `Layout.hubStalls` (trails, sell, fuse, mutation, basket, boardMoney, boardTrophy); klien membuka panel lewat `ProximityPromptService.PromptTriggered` + nama prompt di Config tiap fitur.
- Rumus hadiah speed Index: `round(5 + (slot-1) + recSpeed*0.0005*slot)` (naik monoton; docs/ECONOMY.md rec #2 disesuaikan agar zona awal tidak datar).
- Leaderboard memakai OrderedDataStore bila tersedia, fallback ke pemain di server (Studio tanpa API).
- Daftar suite Studio: Boot, CoreLoop, Life, Death, Progression, Sell, Inventory, Offline, FreeBasket, Leaderboard, Index, Fuse, Mutation, Guardian, Tutorial, Steal, Defense. Tes yang mengubah data harus mengembalikannya (invarian berkala mencetak error merah jika ada nilai tidak sah).

## Catatan Wave 4
- Fuzz remote (`Fuzz` suite, `Net.inject` hanya Studio): ~1500 panggilan berbahaya, 0 error, state stabil tidak berubah.
- Suite baru: Fuzz, DayNight, EggReset, Companion, Race (~60 dtk), Starwhale. Peringatan `[AntiExploit] ... dikembalikan` di Output berasal dari tes Progression yang sengaja teleport 300 stud tanpa grace (wajar).
- Pola bug tes yang berulang: helper `call` yang memakai `result.ok and result.result or nil` mengubah hasil `false` menjadi `nil`. Jangan pakai pola itu untuk hasil boolean.
- Badge HUD kini auto-lebar untuk teks panjang ("OPEN 4:52").

## Catatan Wave 5
- BUG NYATA ditemukan di integrasi: `UIScale` pada ScreenGui menyusutkan UI ke pojok kiri atas -> skala dibatasi (desktop 1.0). Sinematik menggantung bila klien tidak merender -> batas waktu keras + watchdog.
- Suite baru: Leak, Settings, Cinematic, Monetization.
- Tinggal: review kode paralel, soak test, laporan akhir.

## Catatan akhir
- Studio: 28 suite (~1044 pemeriksaan) lulus; Lune 7161 asersi lulus; Selene dan StyLua bersih; Output bersih.
- Review kode menemukan 8 masalah server + 6 klien + 4 ekonomi; yang valid sudah diperbaiki dan diuji (Hardening 26 pemeriksaan).

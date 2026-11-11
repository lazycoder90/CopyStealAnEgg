# Panduan: menjalankan, menguji, dan melengkapi "Nest Bandits"

## 1. Menjalankan game di Studio
1. Di folder proyek jalankan `rojo serve default.project.json` (port standar 34872).
2. Buka Roblox Studio, buat/ buka place kosong, lalu **Plugins -> Rojo -> Connect**. Semua file di `src/` akan tersinkron.
3. Tekan **Play**. Server mencetak `[NestBandits] Server siap. Modul dimuat: N gagal: 0`.
4. Data tersimpan permanen hanya jika place sudah dipublikasikan dan **Game Settings -> Security -> Enable Studio Access to API Services** aktif. Tanpa itu game tetap berjalan penuh (data di memori selama sesi).

Alternatif tanpa Rojo live: `rojo build default.project.json -o build/NestBandits.rbxl` lalu buka file tersebut.

## 2. Cara main (ringkas)
- **Loop:** lari ke lane -> ambil telur dari sarang (tahan `E`) -> bawa pulang melewati garis oranye (Hearth Line) -> taruh di Coop (`E` / tombol Place) -> tunggu tumbuh -> `E` pada telur "Egg Ready!" untuk menetas -> pet menghasilkan uang per detik.
- Guardian di tiap zona bangun saat telur diambil dan mengejar. Kecepatan (Speed) menentukan zona yang aman; naikkan Speed lewat **Sprint Wheel** di Coop dan **Trail**.
- Curi telur pemain lain dari Coop mereka (tahan `E`); lindungi Coop dengan **Frying Pan** (ayunkan ke pencuri), **Trap**, dan **Shield**.
- Tombol HUD: kiri = Shop, Index, Slow, Trap, Shield; kanan = Eggs (telur tumbuh/siap), Pets, Bag, Bud, Race, Settings. Kios di hub: Trails, Sell, Fuse, Yolk Lab (mutasi), Free Basket, Signal Tower (Tilly), papan Leaderboard dan NEXT UPDATE.
- Event: siang/malam (malam tumbuh x30 dan peluang Moonlit), Egg Reset tiap 10 menit, Dash Derby tiap 20 menit, Starwhale tiap 40 menit.

## 3. Perintah admin (hanya Studio; ketik di chat)
`/cash <n>` `/speed <n>` `/wipe` `/resync` `/timescale <1..1000>` `/advance <detik>` `/wheel <level>` `/pen <level>` `/slots <n>` `/trail <id|none>` `/guardian <zona> wake|sleep` `/tp <zona|hub>` `/tutorial skip|reset|<1..8>` `/shield` `/trap` `/night` `/day` `/reset` `/bud <1..4>` `/race start [zona]|close|skip` `/starwhale [zona]|end|fix`

## 4. Menjalankan tes
- **Lune (logika murni, ~7000 asersi):** `lune run tests/run`
- **Gerbang statis:** `selene src tools` dan `stylua --check src tests tools`
- **Studio (setelah Play):** dari MCP/command bar server:
  `game.ServerStorage.TestBridge:Invoke("test.run", "<Suite>")`
  Suite: Boot, CoreLoop, Life, Death, Progression, Sell, Inventory, Offline, FreeBasket, Leaderboard, Index, Fuse, Mutation, Guardian, Tutorial, Steal, Defense, DayNight, EggReset, Companion, Race, Starwhale, Fuzz, Leak, Cinematic, Monetization, Settings, Hardening.
  Suite berbot memanggil `bot.removeAll` setelah selesai. Beberapa suite lambat (Steal ~50 dtk, Defense ~45 dtk, Race ~60 dtk, Leak ~10 dtk).

## 5. Yang HARUS Anda isi sendiri (tidak bisa saya buat)
Semua ID Robux masih `0`, sehingga fitur terkait tampil "Coming soon" dan tidak pernah memanggil Roblox API.
1. Buat di **Creator Dashboard**: gamepass (2x Money, 2x Speed, VIP, +3 Equip, Lucky Hatch, Fast Growth), developer product (Skip Growth bertingkat, Grow All, Wheel +1, paket uang, Shield 10 menit, potion, trail), dan badge. Tulis ID-nya di `src/shared/Config/MonetizationConfig.luau` dan `BadgeConfig.luau`.
2. Isi `MonetizationConfig.nextUpdateAt` (unix detik) untuk papan NEXT UPDATE.
3. Publikasikan place dan aktifkan akses API Studio agar DataStore dan leaderboard dunia teruji.
4. Daftar `ADMIN_USER_IDS` di `src/shared/Config/Constants.luau` bila ingin admin di server live.

## 6. Daftar uji manual untuk Anda (belum bisa saya uji otomatis)
- **Dua pemain sungguhan** (Studio -> Test -> Clients and Servers): curi, pukul dengan Pan, Trap, Shield, rasa adil catch guardian pada latensi nyata.
- **Perangkat mobile** (emulator Studio atau ponsel): ukuran tombol, tombol Drop/Place, Pan lewat tap.
- **DataStore asli**: keluar-masuk server, penyimpanan telur/pet, penghasilan offline.
- **Pembelian Robux**: setelah ID diisi, uji gamepass/product dan receipt.
- **Kualitas visual**: semua model dibangun dari bentuk dasar (placeholder gaya blok). Ganti dengan model final lewat `assets/` (lihat docs/PLAN.md §2.9-2.10).

## 7. Struktur proyek
`src/shared` (config, logika murni, tipe, jaringan), `src/server` (Systems, Services, Tests), `src/client` (Controllers, UI), `tests/unit` (Lune), `tools` (simulasi ekonomi), `docs` (PLAN, CONTRACTS, CHANGES, DEFERRED, ECONOMY, PROGRESS, KNOWN_ISSUES).
Ditunda dengan sengaja: lihat `docs/DEFERRED.md`. Masalah dan batasan yang diketahui: `docs/KNOWN_ISSUES.md`.

# Plan: "Nest Bandits" — Game Roblox Original bergenre Steal & Defend Egg

## Context
Pengguna ingin membuat game Roblox dengan mekanik seperti video tutorial "steal an egg" (`~/Downloads/steal an egg tutorial.mp4`, 32 menit). Video sudah diubah menjadi 382 frame (1 frame/5 detik, 43 contact sheet 3×3 di `/private/tmp/claude-501/-Users-eko-project-roblox-copyStealAnEgg/3bbaf975-1dfc-4d4a-bfe3-c88f84279486/scratchpad/sheets/`) dan dianalisa oleh 3 agen. Hasilnya dikonsolidasikan di `/private/tmp/claude-501/-Users-eko-project-roblox-copyStealAnEgg/3bbaf975-1dfc-4d4a-bfe3-c88f84279486/scratchpad/feature_catalog.md`. Plan ini disusun oleh agen perencana dengan model **Fable**.

Keputusan pengguna: game **original** bertema telur dengan gaya sendiri. **Mekaniknya sama**, tetapi nama, karakter, zona, NPC, art, dan UI dibuat orisinal (bukan salinan game referensi). Folder proyek `/Users/eko/project/roblox/copyStealAnEgg` masih kosong. Kita mulai dari nol dengan Rojo + Wally + Luau.

---

## 1. Identitas Game

### 1.1 Judul & Premis
- **Judul kerja: "Nest Bandits"**. Alternatif: "Yolk Heist" atau "Eggnap Run". Cek dulu di Roblox supaya tidak bentrok.
- **Premis:** Di **Shellwick Valley**, raksasa penjaga sarang (**Nestwardens**) tidur di sepanjang **The Long Nest Road**. Pemain adalah "Bandit" yang punya **Coop** (kandang) di **Bandit Camp**.
- **Garis aman** bernama **Hearth Line**: tiang lentera dan garis oranye bertuliskan "SAFE". Nestwarden tidak bisa melewatinya.

### 1.2 Arah Seni
- Voxel/low-poly "chunky", pastel hangat, outline gelap tipis. Pola cangkang berbeda per zona.
- **Tema UI "Eggshell & Yolk":** panel krem, tombol kuning-oranye, teks putih dengan stroke cokelat, merah bata untuk aksi bahaya.
- **Banner zona** memakai **Danger Meter** (1–5 ikon cangkang retak), bukan emoji.
- **Placeholder:** semua model awal dibuat dari primitive oleh `MapBuilder`/`ModelFactory`. Model final dibuat di Studio lalu diekspor ke `.rbxm` (§2.9).

### 1.3 Rarity (10 tier)
| Idx | Nama | Warna | Efek |
|---|---|---|---|
| 1 | Common | #B8B8B8 | – |
| 2 | Uncommon | #6BD66B | – |
| 3 | Rare | #4FA3FF | – |
| 4 | Epic | #C25BFF | – |
| 5 | Legendary | #FFC43D | shimmer |
| 6 | Mythic | #FF4B4B | shimmer |
| 7 | **Astral** | #7A5CFF | gradien bergerak |
| 8 | **Void** | #111111 + stroke cyan | glitch |
| 9 | **Timeless** | #FF8AD8 | gradien pink-putih |
| 10 | **Primordial** | pelangi | pelangi berputar |

### 1.4 Mutasi (multiplier ditambahkan, bukan dikalikan)
Rumus: `mutMult = 1 + Σ(m_i − 1)`. Maksimal 3 mutasi per item, tidak boleh duplikat. Tampilan: "Pearl + Amber".

| Mutasi | Mult | Sumber |
|---|---|---|
| Pearl | x1.5 | hatch 4%, NPC (sukses 70%) |
| Amber | x2 | hatch 1.5%, NPC (45%) |
| Starlit | x3 | hatch 0.4%, NPC (20%) |
| Moonlit | x2.5 | otomatis saat malam |
| Orbital | x4 | tukar Stardust (event Starwhale) |
| Prism | x6 | hanya dari Fuse |

### 1.5 Zona, Nestwarden & Makhluk (12 zona × 8 = 96)
- Jendela rarity zona z: `o = floor((z−1)/2)`, rarity slot = `[o,o,o+1,o+1,o+2,o+3,o+4,o+5] + 1`.
- Singkatan rarity: C=Common, U=Uncommon, R=Rare, E=Epic, L=Legendary, M=Mythic, A=Astral, V=Void, T=Timeless, P=Primordial.

| # | Zona | Danger | Nestwarden | Makhluk slot 1→8 |
|---|---|---|---|---|
| 1 | Mossy Meadow | 1 | Grumblemoss (kura-kura lumut) | Pebble Chick C, Moss Pup C, Clover Bunny U, Puddle Duckling U, Acorn Squirrel R, Bramble Fox E, Thistle Stag L, Sunpetal Griffin M |
| 2 | Reedwater Marsh | 1 | Old Croakbeard (kodok tua) | Reed Newt C, Mud Piglet C, Lily Frog U, Dragonfly Kit U, Heron Hatchling R, Bog Otter E, Willowshell Turtle L, Marsh Hydra M |
| 3 | Canopy Tangle | 2 | Vinemaw (sloth bersulur) | Leafhopper Gecko U, Banana Bat U, Parrot Puff R, Tree Frogling R, Jaguar Cub E, Orchid Mantis L, Canopy Tapir M, Emerald Quetzal A |
| 4 | Dunebake Desert | 2 | Sandcrank (armadillo-kumbang) | Dune Jerboa U, Cactus Hedgehog U, Fennec Kit R, Sun Lizard R, Scarab Beetle E, Mirage Camel L, Sandstorm Serpent M, Oasis Sphinxcat A |
| 5 | Frostpeak Tundra | 3 | Brrumble (yak es) | Snow Owlet R, Frost Seal Pup R, Penguin Knight E, Arctic Hare E, Glacier Lynx L, Aurora Moose M, Crystal Mammoth A, Blizzard Wyrm V |
| 6 | Cinder Caldera | 3 | Magmole (tikus tanah lava) | Ember Salamander R, Ash Beetle R, Cinder Hound E, Magma Snail E, Obsidian Rhino L, Flarefeather M, Volcano Drake A, Core Golem V |
| 7 | Coral Abyss | 4 | Tidejaw (kepiting karang) | Bubble Puffer E, Coral Seahorse E, Reef Ray L, Lantern Angler L, Kelp Narwhal M, Pearl Leviathan A, Abyss Squid V, Tidal Kraken T |
| 8 | Fossil Badlands | 4 | Ossidon (dino fosil) | Amber Raptorling E, Trilo Bug E, Bonecrest Hatchling L, Tusk Boar L, Saber Kitten M, Thunderneck Sauropod A, Skyfin Glider V, Elder Tyrant T |
| 9 | Lantern Grove | 5 | Paperwing (ngengat lentera) | Lantern Firefly L, Origami Fox L, Moonpetal Koi M, Lantern Raccoon M, Petal Qilin A, Ink Dragon V, Silkmoth Empress T, Grove Sovereign P |
| 10 | Starfall Crater | 5 | Nebulynx (lynx kosmis) | Meteor Mouse L, Comet Kitten L, Orbit Jelly M, Nova Bunny M, Galaxy Whelp A, Blackhole Toad V, Constellation Stag T, Quasar Lion P |
| 11 | Clockwork Spire | 5 | Gearhulk (golem jam) | Tinker Mouse M, Brass Owlet M, Steam Ferret A, Cog Crab A, Copper Dragonfly V, Chrono Tortoise T, Pendulum Drake P, Gearheart Titan P |
| 12 | Gloomrift | 5+ | Umbrageist (bayangan bermata banyak, bos intro) | Shade Imp M, Gloom Bat M, Nightmare Pony A, Hex Hound A, Rift Chimera V, Eclipse Wyvern T, Voidcrown Behemoth P, Last Ember P |

- **Limited:** Starwhale Calf, Stardust Axolotl, Comet Courier Pigeon, Sproutling Elder.
- **Zona 13–14** disiapkan untuk update berikutnya.

### 1.6 Padanan Fitur Referensi → Versi Kita
| Referensi | Versi kita |
|---|---|
| NPC mutasi | Professor Albumen di Yolk Lab |
| NPC UFO | Astronomer Tilly di Signal Tower |
| Event UFO | The Starwhale Visit |
| UFO debris | Stardust Shards |
| Decoder | Star Compass |
| Puzzle pipa | Realign the Star Relay (5×5) |
| Wisp | Sproutling "Bud" (Seed→Sprout→Bloom→Elder) |
| Treadmill | Sprint Wheel |
| Bat | Frying Pan ("CLANG!") |
| Trap | Sticky Yolk Trap ("STUCK!" 7 detik) |
| Shield | Shell Shield |
| Free chest | Free Basket |
| Race | Dash Derby (mata uang Trophies) |
| Papan leaderboard | papan "TOP BANDITS – MONEY/S" |
| Papan iklan | Lucky Billboard |

---

## 2. Arsitektur

### 2.1 Toolchain
- **Rokit:** rojo 7.x, wally, lune (unit test & simulasi ekonomi), selene, stylua.
- **Wally:** sleitnick/signal, sleitnick/trove, osyrisrblx/t, roblox/testez.
- **ProfileStore:** dari Wally, atau vendor ke `src/server/Vendor/` kalau tidak tersedia.
- **Networking:** modul `Net` buatan sendiri, semua remote dideklarasikan di satu file.
- **UI:** dibangun dengan kode lewat `UIBuilder.create()` plus `Store` reaktif berbasis Signal. Tidak memakai Fusion/React.

### 2.2 Struktur Repo
```
copyStealAnEgg/
  default.project.json  rokit.toml  wally.toml  selene.toml  stylua.toml
  assets/ map/ guardians/ creatures/ eggs/ props/      (.rbxm dari Studio)
  src/
    server/  -> ServerScriptService.Server
      init.server.luau  Services/  Systems/(MapBuilder, ModelFactory, GuardianBrain, ZoneRegistry)
      Admin/AdminCommands.luau  Vendor/
    client/  -> StarterPlayerScripts.Client
      init.client.luau  Controllers/  UI/(Theme, UIBuilder, Components/, Screens/)
    shared/  -> ReplicatedStorage.Shared
      Config/ Zones, Creatures, Eggs, Rarities, Mutations, Progression, Economy, Events,
              Monetization, Tutorial, Constants
      Logic/  NumberFormat, Formulas, EggRoll, WeightRoll, FuseLogic, PipePuzzle, RNG, TimeFormat
              (murni, tanpa API Roblox, bisa dites dengan Lune)
      Net/    Remotes.luau, Net.luau
      Util/
    starterGui/ (LoadingScreen)
  tests/ unit/*.spec.luau (Lune)  studio/*.spec.luau (TestEZ)
  tools/ sim_economy.luau  gen_creature_table.luau
```
- **`default.project.json`** juga memetakan:
  - `ReplicatedStorage.Packages`, `ServerScriptService.ServerPackages`
  - `ReplicatedStorage.Assets` ← `assets/`
  - `Workspace.Map` (opsional)
- **Setelan dunia:** `StreamingEnabled=true`, MaxPlayers 8, CollisionGroups dibuat lewat kode.

### 2.3 Pola Service
- Setiap service punya `Init()` (tanpa yield) dan `Start()`.
- Bootstrap memanggil semua service secara berurutan.
- Ada satu Clock terpusat dengan tick 1 Hz dan 10 Hz.

### 2.4 Service Server
| Service | Tanggung jawab |
|---|---|
| DataService | ProfileStore, session lock, schema + migrasi, store `PlayerData_v1` / `PlayerData_DEV` |
| StateReplicator | snapshot awal + patch `{path,value}` ke klien pemilik |
| PlotService | 8 Coop, assign/release, batas area, pagar sesuai pen level, `Workspace.Plots.Plot_i` (attr OwnerUserId) |
| ZoneService | deteksi zona dari posisi Z, `PlayerZoneChanged`, Hearth Line |
| EggSpawnService | nest kecil + Grand Nest, roll telur, respawn |
| EggResetService | timer global "ALL EGGS RESET!" + pengumuman telur langka |
| AnnouncementService | feed atas layar + system chat |
| CarryService | satu-satunya pemilik state carry: pickup, weld, drop, timeout, cek waktu tempuh |
| GuardianService | state machine Nestwarden (Sleep/Alert/Chase/Catch/Return) |
| PlacementService | validasi penempatan di Coop |
| GrowthService | tick progres, multiplier, Ready, skala visual, pertumbuhan offline |
| HatchService | roll mutasi/gender, buat pet, Index found, reveal |
| PetService | inventaris, equip/Equip Best, slot, kapasitas 250, lock, replikasi pet aktif |
| IncomeService | tick 1 Hz, tambah cash, popup "+$X", leaderstats |
| StealService | prompt Steal di Coop orang lain, proteksi, alert, recovery |
| DefenseService | Pan, Trap, Shield |
| SpeedService | stat → WalkSpeed, Sprint Wheel, trail, Slow Mode, validasi gerak |
| UpgradeService | pen, wheel (cash/Robux), slot equip, trail |
| SellService | jual telur/pet sekaligus banyak |
| FuseService | Fuse 3→1 |
| MutationService | roll saat hatch, Moonlit, NPC Albumen |
| IndexService | found/claimed, reward, Claim All, bonus zona, tab Limited |
| DayNightService | siklus, ClockTime, ×30, Moonlit |
| RaceService | Dash Derby |
| StarwhaleEventService | rantai event Starwhale |
| CompanionService | Bud |
| QuestTracker | bus event gameplay |
| OfflineEarningsService | penghasilan offline |
| FreeChestService | Free Basket |
| FriendBoostService | boost teman |
| MonetizationService | gamepass, ProcessReceipt idempoten, rewarded ads |
| LeaderboardService | leaderboard |
| BadgeService | badge |
| TutorialService | tutorial |
| AntiExploit | rate limit, validasi `t`, cek kecepatan posisi, cek waktu tempuh carry |
| AdminService | command admin |

### 2.5 Controller Klien
- **State & input:** StateController, InputController
- **HUD & notifikasi:** HUDController, NotificationController, ZoneBannerController
- **Telur & pet:** CarryController (vignette, RUN!!, Drop), PlacementController (ghost preview), HotbarController (Backpack dimatikan), PetVisualController (pet di-render & berkeliaran di klien), EggVisualController
- **Gameplay:** GuardianFXController, PanController, SprintWheelController, SlowModeController
- **Event:** DayNightController, RaceController, StarwhaleController, CompanionController
- **Lainnya:** TutorialController, CinematicController, SoundController, AdminPanelController

### 2.6 Skema Profil
```lua
{ version=1, cash=0, totalEarned=0, peakIncome=0, speedBase=10,
  wheelLevel=1, penLevel=1, equipSlots=3, plotExpansion=0,
  trails={owned={}, equipped=nil},
  pets={[uid]={id,kg,g,muts,eq,lock,t}},
  eggs={[uid]={id,kg,muts,growTotal,progress,placed={x,z}|nil,stolenFrom,t}},
  gear={pan=1,trap=0,compass=0},
  boosts={growth2xUntil=0,lucky2xUntil=0,speed2xUntil=0},
  index={found={},claimed={},zoneBonus={}},
  trophies=0, stardust=0, raceBest={},
  starwhale={relayFixed=false,eggsFoundThisVisit=0,lastVisitId=0},
  companion={stage=1,progress={},claimed={}},
  freeBasketAt=0, shieldReadyAt=0, newbieProtectUntil=0, lastOnline=0,
  stats={grabbed,stolen,beenStolen,hatched,caught,bonks,playtime},
  tutorial={step=1,done=false},
  settings={music,sfx,slowMode,lowGfx},
  receipts={}, badges={} }
```
Telur yang sedang dibawa **tidak** masuk profil. Statusnya hanya ada di memori CarryService.

### 2.7 Remote
**C2S** (semuanya rate-limited dan divalidasi dengan `t`):
- Telur: DropEgg, PlaceEgg(pos), PlaceFromInventory, PocketEgg, HatchEgg
- Pet: EquipPet, UnequipPet, EquipBest, LockPet
- Upgrade & jual: BuyEquipSlot, UpgradePen, UpgradeWheel(currency), BuyTrail, EquipTrail, SellItems, FuseSubmit
- Mutasi & klaim: BuyMutation, ApplyMutation, ClaimIndex, ClaimIndexAll, ClaimFreeBasket
- PvP & gerak: SetSlowMode, SwingPan, PlaceTrap, ActivateShield
- Event: SubmitRelay, TradeStardust, ClaimCompanionStage
- Monetisasi: RequestSkipGrowth, RequestGrowAll, RequestRewardedAd
- Lainnya: TutorialAck, SetSetting, AdminCommand

**S2C:**
- State: StateInit, StatePatch
- Notifikasi: Notify, Announce, Toast
- Carry & PvP: CarryChanged, GuardianAlert, StealAlert, Caught, Bonked, Trapped
- Hasil aksi: HatchReveal, OfflineEarnings, FuseResult, MutationResult
- Event & efek: DayNight, EggReset, RaceState, StarwhaleState, IncomePopup, PlayFX

**RemoteFunction:** GetRelayPuzzle, GetLeaderboard.

Pickup, Steal, Hatch, dan interaksi NPC memakai **ProximityPrompt** di server.

### 2.8 Keamanan (server-authoritative)
- Klien hanya mengirim niat. Semua harga dihitung server lewat `Economy.trySpend`.
- **Pickup:** jarak ≤ MaxActivationDistance+2.
- **Place:** ada waktu tempuh minimum `dist/maxWalk×0.8`. Kalau lebih cepat, telur ditolak dan kembali ke sarang.
- **Speed:** WalkSpeed diatur server. Posisi HRP disampel tiap 0.5 detik. Kalau `Δpos > walk·dt·1.6+8`, pemain di-rubber-band. 5 pelanggaran dalam 60 detik berarti kick.
- **Pan:** dicek di server (jarak ≤9, sudut ≤70°, cooldown 1.2 detik).
- **ProcessReceipt** idempoten. Remote dibatasi 10 panggilan/detik (Sell 2/detik).

### 2.9 Aset 3D
1. `MapBuilder` membangun hub, 8 Coop, Hearth Line, dan 12 zona (masing-masing 300×120 stud), lengkap dengan nest dan titik guardian. Semuanya dari `Zones.luau`. `ModelFactory` membuat placeholder makhluk, guardian, dan telur dari primitive. Hasilnya game **bisa dimainkan tanpa aset**.
2. Model final dibuat di Studio, lalu *Save to File* (`.rbxm`) ke `assets/<kategori>/<id>.rbxm`. Rojo memetakannya ke `ReplicatedStorage.Assets`. ModelFactory memakai aset ini kalau ada, dan placeholder kalau tidak. Peta final ada di `assets/map/Map.rbxm` dengan marker berbasis tag CollectionService (Nest, GrandNest, GuardianHome, CoopSpot, WheelSpot).
3. Tanpa Terrain. Konvensi: PrimaryPart sebagai root, attribute `Id`, tinggi dinormalisasi.

### 2.10 Strategi Aset (direkomendasikan: mudah, umum, hasilnya bagus)
Gaya voxel/blocky dipilih karena paling mudah dibuat konsisten dan tetap terlihat rapi.

| Kebutuhan | Tool / sumber utama | Catatan |
|---|---|---|
| Makhluk (96) dan telur | **Blockbench** (gratis) | Dibuat untuk model blocky. Satu tool untuk modeling, texture painting pixel-art, rig bone, dan animasi idle/jalan. Ekspor FBX/glTF. |
| Guardian raksasa (12) | **Blockbench** | Rig bone + animasi tidur/bangun/lari/tangkap. |
| Props lingkungan (pohon, batu, kristal, pagar) | **Kenney** dan **Quaternius** (CC0, gratis) | Gaya low-poly yang konsisten. Quaternius juga punya pack hewan low-poly beranimasi yang bisa dijadikan basis lalu di-recolor. |
| Peta / lane / hub | Part bawaan Studio + MaterialVariant | Cepat, ringan, dan tetap terlihat bagus dengan Lighting Future + Atmosphere + Bloom. |
| Draft cepat (opsional) | AI text-to-3D (generator 3D bawaan Roblox Studio jika tersedia, Meshy, atau Tripo) | Hanya untuk draft. Rapikan di Blockbench, kurangi polycount, dan cek lisensi komersial. |
| Ikon pet/telur di UI | **ViewportFrame** (render model langsung) | Tidak perlu menggambar 96 ikon. |
| Ikon UI dan tombol | Figma (gratis) atau ikon CC0 (Kenney UI pack) | Font bawaan Roblox: Fredoka One / Luckiest Guy. |
| Musik dan SFX | Creator Store audio (musik berlisensi gratis untuk Roblox) | Aset audio harus milik sendiri atau berlisensi untuk dipakai di Roblox. |
| VFX | ParticleEmitter, Beam, Trail bawaan, ditambah texture partikel CC0 | Untuk Zzz, efek retak, CLANG, dan trail speed. |

**Pipeline per model:**
1. Buat di Blockbench (≤ ~5k tris, texture ≤1024²).
2. Ekspor FBX/glTF.
3. Impor lewat **3D Importer** di Studio (menghasilkan MeshPart + Bone + AnimationController).
4. Upload animasi.
5. Atur PrimaryPart dan attribute `Id`.
6. Simpan ke `assets/<kategori>/<id>.rbxm`.
7. `ModelFactory` otomatis memakai model ini menggantikan placeholder.

**Prioritas produksi:**
1. Telur: satu template model, varian per zona cukup lewat recolor/texture.
2. 12 guardian.
3. Makhluk zona 1–3.
4. Props hub.
5. Sisa makhluk.

Trik hemat: buat 6–8 "rig dasar" (berkaki 4, burung, ikan, serangga, ular, bipedal). Setiap makhluk adalah variasi rig dasar dengan kepala/aksesori/texture berbeda, jadi animasinya bisa dipakai ulang.

**Hindari:** model dari Toolbox/Creator Store yang berisi script (risiko backdoor/virus). Kalau terpaksa memakainya, pakai mesh saja dan hapus semua Script. Hindari juga aset yang meniru game atau IP lain.

---

## 3. Config & Angka Awal

### 3.1 NumberFormat
- Suffix K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc…, 3 digit signifikan.
- Cash ditulis dengan koma sampai 999,999.
- Fungsi: `fmt`, `fmtMoney`, `fmtRate`, `fmtTime`.

### 3.2 Zona
- Panjang 300 stud per zona.
- Respawn nest kecil 45 detik. Grand Nest hanya respawn saat Global Reset (10 menit).
- Spawn weight nest kecil (slot 1–5): [35,25,18,14,8]. Grand Nest (slot 6–8): [75,22,3]. Luck mengalikan bobot slot ≥4 dengan ×2.
- Guardian: wakeDelay 1.2s, leash 700, catchRadius 7.

| z | recSpeed | Zb (Common $/s) | guardianSpeedStat | zoneFactor |
|---|---|---|---|---|
| 1 | – | 3 | 10 | 1.0 |
| 2 | 1K | 30 | 1K | 1.6 |
| 3 | 8K | 300 | 8K | 2.2 |
| 4 | 50K | 3K | 50K | 2.8 |
| 5 | 170K | 30K | 170K | 3.4 |
| 6 | 2M | 300K | 2M | 4.0 |
| 7 | 25M | 3M | 25M | 4.6 |
| 8 | 300M | 30M | 300M | 5.2 |
| 9 | 2.5B | 300M | 2.5B | 5.8 |
| 10 | 7B | 3B | 7B | 6.4 |
| 11 | 80B | 30B | 80B | 7.0 |
| 12 | 1T | 300B | 1T | 7.6 |

### 3.3 Rarity
| Rarity | incomeMult R | hatchBase |
|---|---|---|
| Common | 1 | 10s |
| Uncommon | 3 | 20s |
| Rare | 8 | 45s |
| Epic | 20 | 90s |
| Legendary | 50 | 3m |
| Mythic | 120 | 6m |
| Astral | 300 | 15m |
| Void | 800 | 30m |
| Timeless | 2000 | 60m |
| Primordial | 5000 | 120m |

- Legendary ke atas diumumkan ke seluruh server. Primordial juga memutar suara global.
- `hatchTime = hatchBase × zoneFactor × rand(0.85,1.15)`. Maksimal sekitar 15.2 jam. Telur tutorial 3 detik.
- `baseIncome = Zb × R × slotVar` (slot ganjil 1.0, genap 1.5). Tabel dibuat oleh `tools/gen_creature_table.luau`.

### 3.4 Berat
- `kg = baseKg × clamp(exp(N(0,1)×0.3), 0.6, 2.5)`. Ada 1% peluang "Hefty" (×2.5–4).
- `weightMult = (kg/baseKg)^0.6`. Gender ♂/♀ hanya kosmetik.
- Skala visual: `(0.6+0.4×progress) × clamp(kg/baseKg, 0.8, 1.5)`.

### 3.5 Pendapatan
- `petIncome = baseIncome × weightMult × mutMult`
- `income/s = Σ petIncome aktif × (1 + friendBoost(0.1/teman, max 0.5) + companionBuff + 0.02×zonaIndexLengkap) × (2xMoney ? 2 : 1)`

### 3.6 Speed
- `effectiveSpeed = speedBase × trailMult × (2xSpeed ? 2 : 1) × (potion ? 1.5 : 1)`
- `walkSpeed = clamp(16 + 9·log10(eff/10+1), 16, 170)`. Contoh: 10→18.7, 170K→54, 7B→95.6, 1Qa→142.
- Guardian memakai rumus yang sama dengan statnya, ×1.05 saat mengejar.
- Slow Mode membatasi kecepatan ke ≤20.

### 3.7 Sprint Wheel
- Server memberi 3 step/detik selama HRP berada di volume roda. Lantai berupa conveyor mundur, jadi pemain yang diam akan terdorong keluar.
- `gainPerStep(L) = round(2×1.75^(L−1))`. Contoh: L14 sekitar +2.9K.
- `price(L→L+1) = 500×3^(L−1)`. Level maksimal 40. Ada alternatif dev product Robux 19/49/99.

### 3.8 Pen Upgrade
| Lv | Harga | Slot telur | Pet terlihat | Bonus |
|---|---|---|---|---|
| 1 | – | 4 | 3 | pagar kayu |
| 2 | $1M | 5 | 4 | |
| 3 | $75M | 6 | 5 | pagar batu |
| 4 | $1B | 7 | 6 | Shield +15s |
| 5 | $15B | 8 | 7 | |
| 6 | $200B | 9 | 8 | trap max 2 |
| 7 | $1.5T | 10 | 9 | pagar kristal |
| 8 | $8T | 11 | 10 | offline cap +12h |
| 9 | $30T | 12 | 11 | |
| 10 | $100T | 13 | 12 | pagar emas |
| 11 | $500T | 14 | 14 | pagar Primordial + aura |

Ada juga "Unlock: $1K", ekspansi +1 slot telur yang muncul di tutorial.

### 3.9 Slot Equip
Mulai dari 3 slot. Harga slot berikutnya:

| Slot | Harga |
|---|---|
| 4 | $5K |
| 5 | $50K |
| 6 | $500K |
| 7 | $3M |
| 8 | $15M |
| 9 | $40M |
| 10 | $75M |
| 11 | $500M |
| 12 | $50B |
| 13 | $500T |
| 14 | $5Qa |

Gamepass +3 Equip.

### 3.10 Trail
| Trail | Mult | Cash | R$ |
|---|---|---|---|
| Dust Puff | x1.25 | $2K | – |
| Leaf Swirl | x1.5 | $40K | – |
| Bubble Stream | x2 | $600K | – |
| Spark Ribbon | x2.75 | $5M | 49 |
| Sunflare | x3.5 | $30M | 79 |
| Ember Comet | x4 | $750M | 119 |
| Astral Wake | x5 | $20B | 199 |
| Void Glitch | x7 | $500B | 349 |
| Timeless Bloom | x10 | $12.5T | 499 |
| Primordial Prism | x14 | $250T | 799 |
| Prismatic Crown | x20 | $5Qa | 1100 |

Hanya satu trail yang aktif.

### 3.11 Sell & Offline
- **Sell telur** = 80 × proyeksi $/s. **Sell pet** = 100 × petIncome (pet yang terkunci atau aktif tidak bisa dijual).
- **Offline:**
  - `perDay = income/s × 3600`
  - `earned = perDay × min(elapsed, cap)/86400`
  - cap 24 jam (+12 jam di pen L8, ×2 untuk VIP)
  - Telur ikut tumbuh offline dengan kecepatan ×1.
  - Banner: "You earned $X while away! ($Y/day offline)"

### 3.12 Ekonomi Lain
- **Free Basket** (cooldown 15 menit): 60% 3 menit income · 20% Speed Potion · 10% Trap · 8% telur · 2% Lucky Potion.
- **Trap:** harga `max($10K, 2 menit income)`, bertahan 5 menit, freeze 7 detik.
- **Shield:** gratis tiap 10 menit, aktif 60 detik. Dev product 30 R$ untuk 10 menit.
- **Index reward per spesies:** cash `baseIncome×120`, speed `max(5, recSpeed×0.02×slot)`. Zona lengkap memberi +2% income dan badge.
- **Mutasi NPC:** Pearl/Amber/Starlit seharga 30×/80×/250× proyeksi $/s, peluang sukses 70/45/20%. Kalau gagal, uang hilang.
- **Stardust:** 40 = Orbital, 25 = telur Starwhale Calf, 60 = telur Stardust Axolotl, 15 = Lucky Potion.
- **Simulasi ekonomi** (`tools/sim_economy.luau`) menargetkan: zona 2 sekitar 5 menit, zona 5 sekitar 45 menit, zona 9 sekitar 6 jam, zona 12 sekitar 30 jam.

---

## 4. Perilaku Mekanik

### 4.1 Telur Dunia
- `EggEntity{uid,speciesId,kg,muts,zone,nestId,state}` disimpan di `Workspace.WorldEggs`.
- Prompt "Grab" (hold 0.3 detik, jarak 10).
- Billboard muncul kalau jarak <40: nama, rarity, kg, $/s, waktu hatch.

### 4.2 Carry
**Pickup** (divalidasi server):
- Telur di-weld di atas kepala.
- Klien menampilkan "RUN!!", vignette merah, tombol Drop, dan musik tegang.
- Event `EggGrabbed` dikirim dan guardian bangun.

**Drop** (tombol/G, tertangkap, kena Pan, atau mati):
- Telur jatuh dan bisa diambil siapa saja.
- Telur dari lane kembali ke sarang setelah 15 detik.
- Telur curian kembali ke korban setelah 20 detik.

**Place** (ghost preview, tekan E). Validasi berurutan:
1. Plot milik sendiri dan jarak ≤14. Kalau gagal: "Get closer to your area to place an egg!"
2. Masih di dalam batas plot. Kalau gagal: "Cannot place egg here!"
3. Jarak ke telur lain ≥6. Kalau gagal: "Egg is too close to another egg!"
4. Masih ada slot kosong. Kalau gagal: "Your Coop is full!"
5. Lolos cek waktu tempuh.

**Aturan lain:**
- Hanya bisa membawa 1 telur. Membawa telur tidak memperlambat (diatur lewat config `carrySlowPct`).
- Kalau pemain leave saat membawa telur, telur dikembalikan.
- `PocketEgg` menyimpan telur ke inventaris (maksimal 15) dan progresnya ikut tersimpan.

### 4.3 Nestwarden AI
- Humanoid dengan NetworkOwner server. Collision group Guardians tidak bertabrakan dengan pemain.
- **Sleep:** animasi tidur dan efek Zzz.
- **Alert:** tanda "!", raungan, kamera bergetar dalam radius 150, selama 1.2 detik (0.8 detik untuk Grand Nest).
- **Chase:** mengejar carrier terdekat dengan `MoveTo` tiap 0.1 detik. Pengejaran lurus di lane; Pathfinding hanya dipakai kalau flag diaktifkan. Guardian boleh menyeberang zona.
- **Catch** (≤7 stud):
  - telur jatuh dan langsung kembali ke sarang
  - pemain ragdoll 1.5 detik plus impulse
  - layar "CAUGHT!"
  - kebal pickup 2 detik
- **Return:** terjadi kalau target melewati Hearth Line, menjatuhkan telur, atau leave; atau guardian melewati leash 700, atau sudah mengejar 25 detik. Guardian berjalan pulang dengan kecepatan ×0.6.
- Guardian tidak pernah melewati Hearth Line. Guardian tidak di-tick kalau tidak ada pemain dalam radius 400.

### 4.4 Mencuri
**Syarat:**
- Prompt "Steal" (hold 1 detik) hanya muncul untuk non-pemilik.
- Pencuri tidak sedang membawa telur.
- Korban tidak sedang memakai Shield dan tidak dalam masa newbie (5 menit pertama dan selama tutorial).
- Pencuri tidak sedang dalam tutorial.

**Hasil:**
- Telur keluar dari profil korban beserta progresnya.
- Pencuri melihat "You stole an EGG!".
- Korban mendapat toast "<Name> is stealing your egg!", tanda "!" muncul di atas Coop, ada panah ke pencuri, dan alarm berbunyi.

**Setelah itu:**
- Kalau pemilik mengambil kembali telur yang jatuh, telur langsung kembali ke tempatnya ("Egg recovered!").
- Kalau pencuri berhasil menaruhnya, kepemilikan pindah dan progres tetap.

### 4.5 Pertahanan
- **Frying Pan** (hotbar slot 1):
  - hanya berefek ke pemain yang membawa telur: telur jatuh, knockback, "CLANG!", stun 0.5 detik
  - tidak ada knockback ke non-carrier
  - cooldown 1.2 detik, tidak berfungsi di spawn pad
- **Sticky Yolk Trap:**
  - dipasang dalam radius 30 dari Coop sendiri (1 buah, 2 kalau pen L6)
  - aktif saat dilewati carrier yang bukan pemilik: HRP di-anchor 7 detik, layar "STUCK!"
  - sekali pakai, pemilik mendapat notifikasi
- **Shell Shield:**
  - kubah yang mendorong keluar non-pemilik (dicek tiap 0.2 detik) dan menonaktifkan prompt Steal
  - timer tampil di atas Coop

### 4.6 Area
- Hearth Line memisahkan hub dan lane.
- Spawn pad bebas PvP.
- Lane adalah area liar: guardian aktif dan Pan aktif.

### 4.7 Slow Mode
Toggle yang membatasi WalkSpeed ke 20. Setelan disimpan di profil.

### 4.8 Siang/Malam
- Siang 240 detik, malam 90 detik.
- HUD menampilkan ikon matahari/bulan dan "in 4m 19s". BigCountdown muncul 10 detik terakhir.
- **Malam:**
  - pertumbuhan telur ×30
  - setiap 15 detik ada peluang Moonlit 1.5% per telur ("Moonlit mutation applied!")
  - sarang bercahaya

### 4.9 Global Egg Reset
- Setiap 10 menit: countdown 5 detik, lalu "ALL EGGS RESET!" dan semua nest di-roll ulang.
- Spawn Legendary+ diumumkan: "A Mythic Sunpetal Griffin Egg spawned in Mossy Meadow!" (berwarna, muncul di feed dan system chat).

### 4.10 Dash Derby
**Jadwal:**
- Setiap 20 menit. "Race in 2:54" (3 menit), lalu "Race open! 4:52" (5 menit).
- Pengumuman: "A race has appeared in <Zone>!"
- Zona dipilih acak dengan bobot.

**Aturan:**
- Gate, 6 checkpoint, finish. Mode time trial, boleh dicoba berulang.
- Waktu dihitung server dari posisi.
- Guardian zona tersebut ditidurkan selama race.

**Hasil:**
- Podium 1ST/2ND/3RD.
- Trophies:
  - dasar 50×zona
  - juara 1/2/3: ×4/×3/×2
  - rekor pribadi: +25×zona
  - tampil sebagai "+2,025 Trophies"
- Trophy Shop: trail Laurel Streak, potion, trap, skin Pan.

### 4.11 Starwhale Visit
1. Tilly: "Help me repair the Star Relay!"
2. **Puzzle 5×5** "ROTATE TILES TO CONNECT THE POWER":
   - grid dibuat dari seed dan dijamin bisa diselesaikan
   - server memvalidasi dengan BFS di `Logic/PipePuzzle`
   - kalau berhasil, pemain mendapat **Star Compass**
3. **Starwhale muncul** tiap 40 menit di ceruk zona 2–10:
   - pengumuman "A Starwhale has been sighted! Leaves in 4:48"
   - tidak terlihat sampai jarak <80
4. **Kompas:** panah plus bunyi bip yang makin cepat ("Hold your Compass to track it!").
5. **Cari telur:** "STARWHALE FOUND! Find 3 odd eggs! 0/3". Posisi telur di-seed per pemain dan divalidasi server.
6. **Interior** (Y=−500, 60 detik): "Crack the crystal pods for Stardust!" Setiap pod butuh 3 pukulan Pan dan memberi 1–4 Stardust.
7. **Trade** di Tilly (§3.12). Satu kunjungan per Starwhale per pemain. Makhluk Limited masuk Index.

### 4.12 Bud (Companion)
- Mengikuti pemain lewat AlignPosition di klien.
- Panel "Grow Your Bud": stage, quest, CLAIM, dan "Your progress is saved".

| Stage | Quest | Hadiah |
|---|---|---|
| 1 Seed→Sprout | Grab 20 Mossy Meadow eggs, Hatch 5 | +5% income |
| 2 Sprout→Bloom | Grab 15 Canopy Tangle, Hatch a Frostpeak creature | +5% speed |
| 3 Bloom→Elder | Steal 5 from players, Hatch any Astral | +10% income |
| 4 Elder | Grab any Timeless egg | telur Sproutling Elder + badge |

### 4.13 Fuse
- Panel: "Bring 3 same creatures to Fuse! Better creatures give more Luck!"
- Syarat: 3 pet dengan spesies sama, tidak aktif, tidak terkunci. Biaya 10× income.
- `luck = clamp(Σ(weightMult×mutMult)/3 − 1, 0, 2)`
- **Hasil:**
  - 65%: spesies sama, kg = Σkg×0.6, mutasi digabung
  - (30%+10%×luck): naik ke slot berikutnya (slot 8 lanjut ke slot 1 zona berikutnya)
  - (2%+3%×luck): ditambah mutasi Prism
- Hasil ditampilkan dengan komponen HatchReveal.

### 4.14 Mutasi NPC
1. Albumen membuka panel. Pemain memilih mutasi, melihat harga dan peluang, lalu Buy.
2. Muncul "Click on an egg to apply the mutation". Telur di-highlight, lalu `ApplyMutation(uid)`.
3. Server memvalidasi, memotong cash, lalu roll.
4. Kalau berhasil: "Pearl mutation applied!". Kalau gagal: "The mutation failed...".
5. Mutasi hanya untuk telur.

### 4.15 Growing Eggs
- `progress += dt × (malam ?30) × (2x ?2) × (pass ?1.5)`
- Saat siap: "Egg Ready!", prompt "Hatch!", dan telur bergoyang.
- **Panel:**
  - 2 badge (tumbuh/siap)
  - daftar: ikon, rarity, kg, sisa waktu, tombol Open (bisa dari jauh) atau Skip
  - tombol Grow All
  - "2x Egg Growth +5 min — Watch Now!"
- **Skip Growth** bertingkat: <5m 9 R$, <30m 19 R$, <2h 39 R$, <8h 79 R$, lebih dari itu 129 R$. Server mencatat pending uid sampai ProcessReceipt.

### 4.16 Hatch
- Validasi siap dan milik sendiri. Roll mutasi dan gender, buat pet, tandai Index, auto-equip kalau ada slot.
- Kalau storage penuh (250): "Pet storage full!"
- **HatchReveal** layar penuh: animasi retak, rarity besar, "Pearl + Amber Thistle Stag", $/s, kg, ♂/♀, NEW!. Legendary+ diumumkan.

### 4.17 Pet & Income
- **PetsPanel:** "9/9 Active", "+1 EQUIP [$75M]", Unequip/Equip, Equip Best, lock.
- Pet berkeliaran di Coop (di-render klien dari `Plot_i.ActivePets`). Billboard menampilkan rarity, nama, $/s. Popup "+$X" digabung.
- Leaderstats Speed dan Money/s.

### 4.18 Index
- Tab World (12 zona × 8, belum ditemukan tampil "???") dan Limited.
- Progres "3/8" per zona dan "Unlocked: 32/96".
- Reward: CLAIM!/CLAIMED!/CLAIM ALL (n)!. Badge di HUD.

### 4.19 Sell
- Dibuka dari stand SELL.
- Tab Eggs/Pets, sort Weight/Value, Select All, kartu item, "Total Value", tombol Sell.
- Konfirmasi kalau ada item ≥Mythic. Total dihitung ulang di server.

### 4.20 Inventaris
- Tab Pets/Eggs/Gear, "All Items", pencarian, kapasitas "Pets: 66/250" dan "Eggs: 3/15".

### 4.21 Free Basket, Friend Boost, Lucky Billboard
- **Free Basket:** label "FREE!" dengan countdown.
- **Friend Boost:** dihitung ulang setiap ada yang join/leave. Tampil "Friend Boost +20%".
- **Lucky Billboard:** "Watch an ad to collect $X" (X = 10 menit income).

### 4.22 Tutorial
0. Cinematic 8 detik (bisa di-skip): lane, mata Umbrageist terbuka, judul.
1. "Grab an Egg!": jejak kaki kuning menuju telur Moss Pup tutorial (3 detik, guardian tidak bangun).
2. "Bring it home!"
3. "Place it in your Coop!"
4. "Wait… then Hatch!"
5. Reveal sekitar $5/s.
6. "Upgrade your Coop!": tunjuk Unlock $1K (dapat bonus $1K).
7. "Run on the Sprint Wheel!" (30 step).
8. Selesai. Proteksi newbie berlaku sampai menit ke-5.

### 4.23 Monetisasi
- **Gamepass:**

  | Gamepass | Harga (R$) |
  |---|---|
  | 2x Money | 199 |
  | 2x Speed | 149 |
  | VIP | 299 |
  | +3 Equip | 249 |
  | Lucky Hatch | 199 |
  | Fast Growth | 249 |
  | Extra Trap | 99 |

- **Penawaran pemain baru:** "x2 Speed — ONLY 3 R$" (15 menit).
- **Dev product:** Skip Growth, Grow All, Wheel +1, trail Robux, cash pack (relatif terhadap income), Shield, potion.
- **Rewarded ads:** pakai AdService. API dan kelayakan wilayah/umur harus diverifikasi; kalau tidak tersedia, fallback ke versi gratis tiap 30 menit atau disembunyikan.
- **Shop:** tab Featured/Gamepasses/Cash/Potions/Trails/Trophy Shop.
- **Badge:** First Hatch, First Steal, Zone 5/9/12, Index zona, Win Race, Starwhale Visitor, Bud Elder.

### 4.24 Leaderboard
- Papan "TOP BANDITS – MONEY/S" dan "MOST TROPHIES" lewat OrderedDataStore.
- Nilai di-encode `floor(log10(x+1)×1e9)`.
- Tulis tiap 120 detik, baca tiap 60 detik.

---

## 5. Spesifikasi UI/HUD
- **Kiri tengah:** Shop (badge "!"), Index (badge angka), Slow Mode.
- **Kanan tengah:** Eggs (2 badge), Pets, Trophy, Event orb.
- **Kiri bawah:** Speed (+), Cash, Friend Boost, Stardust, Trophies.
- **Tengah bawah:** hotbar 10 slot (1 Pan, 2 Compass, 3 Trap, 4–10 potion/gear).
- **Kanan bawah:** timer siang/malam, race, Egg Reset, ikon boost.
- **Atas:** banner zona (nama, Danger Meter, "Recommended: 170K" merah kalau kurang), feed pengumuman (3 baris), banner offline, BigCountdown.
- **Overlay:**
  - CarryOverlay (RUN!!, vignette, Drop, label STOLEN!)
  - CAUGHT!, CLANG!, STUCK! 7
  - StealAlert
  - popup PenUpgrade dan WheelUpgrade ("Successfully upgraded…")
- **Billboard dunia:** papan Coop, Unlock $1K, "+N/step", ikon rumah, "!" saat dicuri, timer Shield, tanda "X recommended".
- **Modal:** GrowingEggs, Pets, Inventory, Sell, Index, Fuse, Mutation, TrailsShop, Shop, FreeBasket, Companion, RelayPuzzle, TillyTrade, RacePodium, HatchReveal, Confirm, Settings, TutorialOverlay, AdminPanel.
- **Mobile:** tombol ≥44px, UIScale, tombol Drop/Pan/Place besar di kanan bawah.

---

## 6. Fase Implementasi

### Fase 0: Fondasi
**Deliverable:**
- toolchain, `default.project.json`, bootstrap
- Net/Remotes, DataService, StateReplicator
- NumberFormat/Formulas + test Lune
- rate limiter
- AdminService (`/cash`, `/speed`, `/wipe`, `/timescale`)
- UIBuilder/Theme

**Selesai jika:** `rojo serve` sinkron, cash tersimpan setelah rejoin, test Lune hijau.

### Fase 1: MVP Core Loop
**Deliverable:**
- MapBuilder (hub, 8 Coop, Hearth Line, zona 1–3), PlotService
- EggSpawnService, CarryService, PlacementService, GrowthService
- HatchService + reveal, PetService (3 slot), IncomeService
- HUD, CarryOverlay
- Config 12 zona
- telur tutorial

**Selesai jika:** loop grab → bawa → place (3 error teruji) → hatch → income berjalan, dan data persisten setelah rejoin.

### Fase 2: Speed, Progresi, Zona, Guardian
**Deliverable:**
- SpeedService, Sprint Wheel
- UpgradeService (pen, slot, $1K, wheel), TrailsShop
- 12 zona + banner + tanda recommended
- GuardianService, ZoneService
- leaderstats, tutorial, PetsPanel

**Selesai jika:**
- speed 10 tertangkap di zona 3, sedangkan speed 50K lolos zona 4
- guardian pulang setelah pemain melewati Hearth Line
- pemain yang diam di roda tidak mendapat step
- harga sesuai config

### Fase 3: PvP
**Deliverable:**
- StealService, DefenseService
- safe zone
- AntiExploit (posisi + waktu tempuh)

**Selesai jika** (3 pemain):
- curi lalu pukul, telur kembali
- trap 7 detik berfungsi
- Shield memblokir
- teleport ditolak

### Fase 4: Koleksi & Ekonomi Lanjut
**Deliverable:**
- Inventory, Sell, Index, Fuse
- Mutation (hatch + NPC)
- GrowingEggs, Offline, FreeBasket, FriendBoost
- Leaderboard

**Selesai jika:**
- total sell sesuai rumus
- klaim Index hanya bisa sekali
- distribusi Fuse sesuai di 10.000 roll
- mutasi bisa gagal
- `/offline 7200` menghasilkan nilai yang benar

### Fase 5: Event Dunia
**Deliverable:**
- DayNight, EggReset + Announcement
- Race + Trophy Shop
- Starwhale (lengkap)
- Bud, QuestTracker

**Selesai jika:**
- `/night` memberi ×30
- `/reset eggs` menampilkan pengumuman
- `/race start` dengan 2 pemain dan podium benar
- `/event starwhale` berjalan end-to-end dan puzzle palsu ditolak
- Bud stage 1 berfungsi

### Fase 6: Monetisasi & Polish
**Deliverable:**
- Monetization (receipt idempoten), Shop, Skip/Grow All
- offer 3 R$, badge
- cinematic, SFX/musik, VFX
- UI mobile, low-graphics, optimisasi
- aset final `.rbxm`
- lokalisasi ID/EN

**Selesai jika:**
- receipt yang diulang tidak memberi item ganda
- 8 pemain dengan Heartbeat <5ms
- tampilan mobile terbaca

### Fase 7: Live Ops
- event musiman (dimensi + telur musiman + tab Limited)
- lab terbatas dengan countdown
- papan NEXT UPDATE
- zona 13–14
- skin Pan
- trading (opsional)

---

## 7. Verifikasi
1. **Lune** (`lune run tests/run.luau`): NumberFormat, walkSpeed monoton, harga, distribusi berat/spawn, peluang Fuse, PipePuzzle (generator selalu solvable dan grid acak ditolak), rumus sell/offline.
2. **TestEZ di Studio:** `Economy.trySpend`, validator Placement, ProcessReceipt idempoten.
3. **Local Server 2–8 pemain** (Studio → Test → Clients and Servers): curi, pukul, trap, shield, race, dan guardian mengejar 2 carrier.
4. **Admin commands:** `/cash /speed /wheel /pen /give pet|egg /grow all /timescale /night /day /reset eggs /race start /event starwhale /guardian /offline /seed /wipe /tp zone /unlockindex`.
5. **DataStore:** aktifkan Studio API Access dan pakai `PlayerData_DEV`. Uji rejoin, session lock, BindToClose, migrasi versi.
6. **Simulasi ekonomi** setiap kali config berubah (`lune run tools/sim_economy.luau`).
7. `selene src` dan `stylua --check src` harus bersih di akhir tiap fase.

---

## 8. Risiko & Keputusan Terbuka
- **Kemiripan dengan referensi:** nama, UI, dan art wajib berbeda. Hindari layout warna yang identik.
- **WalkSpeed tinggi:** risiko tunneling. Batasi di 170, buat dinding tebal, dan tuning rumus log.
- **Humanoid guardian tersangkut:** fallback pakai AlignPosition kinematik.
- **False positive anti-exploit:** pakai whitelist flag saat knockback/conveyor, dan kick hanya setelah pelanggaran berulang.
- **Telur curian saat korban leave:** default tetap milik pencuri. Alternatifnya dikembalikan lewat ProfileStore MessageAsync.
- **Ketersediaan AdService** dan nama paket Wally perlu diverifikasi saat setup.
- **Keseimbangan ekonomi endgame:** wajib disimulasikan.
- **Performa:** pet di-render di klien, guardian idle, popup digabung, StreamingEnabled.
- **Default yang dipakai** (bisa diubah pengguna):
  - judul "Nest Bandits"
  - 8 pemain per server
  - teks in-game bahasa Inggris plus lokalisasi ID
  - tanpa rebirth (sesuai referensi)
  - trading ditunda ke Fase 7
  - aset final dibuat di Studio, placeholder dulu

## File Kunci
- `default.project.json`
- `src/shared/Config/{Zones,Creatures,Rarities,Progression}.luau`
- `src/shared/Logic/{Formulas,NumberFormat}.luau`
- `src/server/Services/CarryService.luau` (inti carry/steal/guardian)
- `src/server/Services/DataService.luau`

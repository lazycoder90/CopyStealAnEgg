# CONTRACTS: API nyata (akhir Wave 1)

Sumber kebenaran tetap kode di `src/`. Dokumen ini meringkas API publik yang boleh dipakai agen lain.
Konstanta nama attribute/tag/folder SELALU dari `src/shared/Types.luau` (`Types.Attr/Tags/Names/NestState`).

## Aturan arsitektur
- `Boot` memuat otomatis semua modul `src/server/Systems/*` lalu `src/server/Services/*` (urut nama). Setiap modul boleh punya `Init()` (sinkron, tanpa yield, tanpa memanggil service lain; DI SINI daftarkan hook lifecycle, InvariantChecker, TestBridge, AdminService command), `Start()` (loop/koneksi/`Net.on`; boleh yield), `Ready()` (hanya DataService).
- Klien: `src/client/Boot.luau` memuat semua `Controllers/*`: `Init()` lalu `Start()` SINKRON (Start tidak boleh yield sebelum menyambung listener `Net.connect`; kerja yang yield → `task.spawn`). `ClientReady` dikirim setelah semua Start.
- `require` antar modul bersama (`src/shared/Logic`, `src/shared/Config`) memakai string relatif (`require("./RNG")`, `require("../Config/Zones")`) agar bisa dites di Lune. Modul server/klien memakai `require(Shared.X.Y)` / `require(script.Parent.X)`.
- Dilarang require berputar. Gunakan sinyal (`Signal`) atau `GameEvents`.
- Dilarang `PlayerRemoving:Connect` untuk data game. Pakai `PlayerLifecycle.onLeaving`.
- Jangan simpan referensi tabel data pemain; selalu `DataService.getByUserId(userId)` (tabel berganti saat simulateRejoin).
- Kepemilikan selalu `userId` (number), bukan objek Player (bot uji tidak punya Player).
- Semua remote C2S lewat `Net.on(name, validator, handler)`; validator dari `Util/Check` (`Check.args(Check.uid, Check.bool, ...)`). Nama remote ada di `src/shared/Net/Remotes.luau` (hanya agen utama yang menambah).
- Mata uang/stat numerik (`cash`, `trophies`, `stardust`, `speedBase`) hanya lewat `CurrencyService`.
- Replikasi ke klien: `StateReplicator.set(userId, "path.dot", value)` (nilai nil = hapus). Field baru di profil: minta agen utama menambah ke `Config/ProfileTemplate.luau`.
- Waktu: `Clock.now()` (detik dinding + offset admin) untuk cooldown/timestamp tersimpan; `Clock.every1Hz(fn(dt))` dt = waktu-game (dipengaruhi timeScale; HANYA untuk ekonomi). Untuk gerak guardian, anti-exploit, race pakai waktu nyata (`os.clock`, Heartbeat dt).
- Angka acak: `Logic/RNG` (`RNG.new(seed)`), bukan math.random, agar bisa diulang.

## Server API (ringkas)
- `DataService`: `getByUserId(userId)`, `get(player)`, `all()` -> `{ {userId, data, player?, virtual} }`, `registerVirtual(userId, data?, character?)`, `unregisterVirtual(userId)`, `wipe(userId)`, `simulateRejoin(userId)`, `deepCopy`.
- `PlayerLifecycle.onJoin(name, order, fn(ctx))`, `.onLeaving(name, order, fn(ctx))`; ctx = `{userId, player?, data, name}`. Order: Carry 10, Steal 20, Trap 30, Guardian 40, PlotService join 5, Growth 50, Pet 60, lain 100, StateReplicator 1000.
- `CurrencyService`: `get/add(userId, field, amount>=0)/trySpend/set`.
- `StateReplicator`: `set(userId, path, value)`, `resync(userId)`.
- `Actors`: `getPlayer/getCharacter/getRoot/getHumanoid/getName(userId)`, `registerBot(userId, model)`, `unregisterBot`, `isBot`.
- `Clock`: `now()`, `advance(sec)`, `every1Hz(fn)`, `every10Hz(fn)`, `timeScale`.
- `GameEvents` (Signal; payload tabel): `EggSpawned, EggGrabbed{userId,eggUid,speciesId,rarity,zone,grand}, EggPlaced{userId,eggUid,speciesId,stolen}, EggHatched{userId,petUid,speciesId,rarity,zone,isNew}, EggStolen{thiefId,victimId,eggUid,speciesId,rarity}, PlayerCaught{userId,zone}, Bonked{userId,byUserId}, ZoneChanged{userId,zone}, PurchaseGranted{userId,kind,id}`.
- `TestBridge.register(name, fn)` (Init); skenario uji di `src/server/Tests/<Nama>.luau` (`return function(T) ... end`, `T.player/T.userId/T.check(name, cond, detail)/T.wait`). Dijalankan agen utama lewat `ServerStorage.TestBridge:Invoke("test.run", "<Nama>")`.
- `InvariantChecker.register(name, fn(entry)->{string})` per pemain, `registerWorld(name, fn()->{string})`.
- `AdminService.register(name, fn(player, args)->string)`.
- `PlotService`: `getPlot(userId)`, `getPlotByIndex(i)`, `getOwnerUserId(plot)`, `getFloor(plot)`, `localToWorld(plot,x,z)`, `worldToLocal(plot,pos)->x,z`, `isInsideLocal(x,z,inset)`, `distanceToPlot(plot,pos)`, `isReservedLocal(x,z)`, `teleportToPlot(userId, onlyIfFar?)`.
  Plot Model: atribut `OwnerUserId`, `PlotIndex`; anak `Floor` (atas di y=0, 80x1x80), `SpawnPoint`, `SignAnchor`, Folder `Eggs` (model telur placed) dan `ActivePets`.
- `EggSpawnService`: `getEntity(uid)`, `getNest(id)`, `entityPosition(entity)`, `takeEgg`, `dropEggAt`, `destroyEntity`, `returnToNest`, `resetAll()`, `stats()`, `onGrabRequested` (Signal). Entity: `{uid, speciesId, kg, muts, rarity, zone, nestId, growTotal, grand, state, model}`.
- `CarryService`: `get(userId)`, `isCarrying`, `start(userId, state)`, `drop(userId, reason)`, `forceReturn(userId, reason)`, `consume(userId)`, `tryPickupWorld`, `setPickupImmunity(userId, sec)`, `notify(userId, msg, kind)`, `registerKind(name, impl)`.
  Impl kind: `describe(state)->{eggUid,speciesId,name,rarity,kg,projectedIncome,stolen}`, `model(state)->Model` (ditempel ke kepala), `drop(state,userId,reason,groundPos)`, `returnHome(state,userId,reason)`, `consume(state,userId)->eggData{uid,id,kg,muts,growTotal,progress,stolenFrom}`. Alasan: `placed|dropped|caught|died|left|bonked|returned`. `kind="wild"` sudah ada.
- `PlacementService.place(userId, worldPos) -> ok, err`.
- `GrowthService`: `ensureModel(userId, uid)`, `removeModel`, `getModel`, `setFrozen(userId, uid, bool)`/`isFrozen` (telur yang sedang dicuri), `setGlobalMultiplier(name, v)`, `addMultiplierProvider(name, fn(userId))`, `multiplier(userId)`, `onHatchRequested` (Signal).
- `PetService`: `equip/unequip(userId, uid)`, `equipBest`, `setLock`, `addPet`, `refreshPlot`, `equippedCount`, `petCount`, `petIncome(pet)`.
- `IncomeService`: `addBonus(name, fn(userId)->additive)`, `addMultiplier(name, fn(userId)->mult)`, `compute(userId, data)`.
- `HatchService`: `hatch(userId, eggUid)->ok, payload|err`, `addLuckProvider`, `setSeed`.
- `AntiExploit` (stub, diisi agen Progresi): `grace(userId, seconds, reason)`, `inGrace(userId)`. WAJIB dipanggil sistem yang memindahkan pemain secara sah (knockback, dorongan Shield, conveyor, teleport, respawn).

## Logika murni / config (Lune-testable)
`Config/{Zones,Rarities,Creatures,Eggs,Layout,Progression,Mutations,Constants,ProfileTemplate}`, `Logic/{Formulas,NumberFormat,RNG,RateLimiter,WeightRoll,EggRoll,PetMath,MutationLogic,FuseLogic,PipePuzzle,NestLayout}`. Layout: sumbu lane = +Z; `Layout.hearthLineZ`, `zoneZStart/zoneZEnd/zoneAtZ`, `plotCenter(i)`, `plotReserved`, `NestLayout.grandPosition(zone)`.

## Klien
- `StateController.get("path.dot")`, `.changed:Connect(function(path, value))`, `.isReady`.
- `HUDController.registerButton(slot "left"|"right", {id,text,order,color?,onClick,badge?})`.
- `ModalController.register(name, builder(container)->cleanup?, title?)`, `.open(name)`, `.close()`.
- `NotificationController.push(message, kind)`; `CarryController.isCarrying()/getPayload()/changed`.
- Komponen: `UI/Components/{Button,Panel,Modal}`, `UI/Theme` (Colors Cream/Yolk/YolkDark/Brown/Brick/Danger/Mint/White; Fonts Title/Body), `UI/UIBuilder.create(class, props, children)`.
- Remote S2C payload bertipe ada di `Types.luau` (CarryChangedPayload, HatchRevealPayload, CaughtPayload, BonkedPayload, TrappedPayload, StealAlertPayload, GuardianAlertPayload).

## Konvensi pengujian
- Tes Lune: `tests/unit/<Nama>.spec.luau` (`return function(t) t.eq/near/truthy end`). Agen TIDAK mengedit `tests/run.luau`; agen utama mendaftarkannya.
- Tes Studio: `src/server/Tests/<Nama>.luau`. Setelah `DataService.wipe`/`simulateRejoin` tunggu >= 1.2 detik (pemain dipindahkan ke Coop sampai ~0.85 detik). Bot uji: `Systems/Bots.luau` (dibuat agen PvP).

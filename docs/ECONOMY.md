# Simulasi Ekonomi "Nest Bandits"

Dihasilkan oleh `lune run tools/sim_economy` (deterministik, seed tetap, selesai < 1 detik).
Mode eksplorasi: `lune run tools/sim_economy -- wheelPriceRatio=5.5 indexSpeedFactor=0.0005` mencetak satu baris waktu tercapai per zona.
Semua angka di bawah berasal dari Config/Logic yang ada (Zones, Rarities, Eggs, Creatures, PetMath, EggRoll, Formulas, Progression).

## Asumsi pemain "rata-rata serakah"

| Asumsi | Nilai |
|---|---|
| Waktu bermain aktif | 75% dari waktu (sisanya baca UI, mati, loading) |
| Pembagian waktu aktif | 50% dijatah ke Sprint Wheel, 50% ke lari ambil telur; kalau slot telur penuh, waktu lari pindah ke roda |
| Efisiensi roda | 80% (conveyor mendorong pemain keluar), 3 step/detik |
| Telur per perjalanan | 1 (aturan carry); perjalanan = 8 dtk ambil/taruh + 2 x jarak / walkSpeed, jarak nest = 235 + 300 x (zona - 0.5) stud |
| Pemilihan zona | zona dengan nilai telur per detik tertinggi (income harapan / max(waktu trip, waktu slot terpakai)); tidak pernah ke zona dengan speed < recSpeed/3 |
| Peluang sukses bawa pulang | 90% jika speed >= recSpeed; 30% jika recSpeed/3 <= speed < recSpeed (gagal = hilang 10 dtk + trip) |
| Grand Nest | diambil sekali tiap 600 dtk (Global Reset) pada zona >= 3 |
| Siang/malam | 240 dtk siang + 90 dtk malam, tumbuh x30 saat malam (rata-rata x8.9); Moonlit 4% per malam per telur (Mutations.moonlitChancePerNight); mutasi hatch dari Mutations tanpa luck |
| Hatch | pemain langsung membuka telur yang siap (remote hatch dari panel); waktu hatch dari EggRoll.hatchTime |
| Kebijakan jual | pet di luar slot equip langsung dijual (100 x income); equip = pet income tertinggi; telur tidak pernah dijual |
| Index | reward pertama per spesies: cash baseIncome x 120 dan speed max(5, recSpeed x faktor x slot); zona lengkap +2% income |
| Pembelian | selalu yang termurah yang tersedia di antara: upgrade wheel, slot equip, pen, trail (urut), Unlock $1K |
| Lain-lain | friend boost, potion, gamepass, Fuse, mutasi NPC, offline diabaikan; speed = speedBase x trail |

Waktu tercapai = saat effectiveSpeed (speedBase x trail) >= recSpeed zona.

## Hasil dengan konstanta saat ini (baseline)

| Zona | recSpeed | Waktu tercapai | Target | Selisih |
|---|---|---|---|---|
| 2 | 1K | 5.8 mnt | 5 mnt | +17% |
| 3 | 8K | 11.0 mnt | | |
| 4 | 50K | 19.2 mnt | | |
| 5 | 170K | 23.8 mnt | 45 mnt | -47% |
| 6 | 2M | 29.7 mnt | | |
| 7 | 25M | 39.1 mnt | | |
| 8 | 300M | 57.3 mnt | | |
| 9 | 2.5B | 75.7 mnt | 6 jam | -79% |
| 10 | 7B | 87.3 mnt | | |
| 11 | 80B | 1.9 jam | | |
| 12 | 1T | 2.5 jam | 30 jam | -92% |

Kesimpulan: awal game (zona 2) sudah pas, tetapi setelah itu progres terlalu cepat. Income naik x10 per zona sedangkan harga wheel hanya x3 per level (gain x1.75), sehingga umpan balik uang -> speed -> zona berikutnya tidak punya rem. Semua pen/slot/trail terbeli dalam ~2 jam dan Wheel Lv40 tercapai di jam ke-13. Reward speed Index (recSpeed x 0.02 x slot) juga memberi lonjakan besar di zona akhir.

## Rekomendasi perubahan konstanta

| # | Perubahan | Dari | Ke | Alasan |
|---|---|---|---|---|
| 1 | `Formulas.wheelUpgradePrice(L)` | `500 * 3^(L-1)` | `1500 * 5.5^(L-1)` | Rem utama: harga wheel harus tumbuh lebih cepat daripada income per zona |
| 2 | Reward speed Index per spesies (PLAN 3.12) | `max(5, recSpeed * 0.02 * slot)` | `max(5, recSpeed * 0.0005 * slot)` | Dengan 0.02, mengoleksi satu zona memberi speed hampir setara zona berikutnya; sendirian faktor ini memangkas zona 12 dari ~30 jam ke ~5 jam |
| 3 | `Progression.wheel.maxLevel` | 40 | 30 (atau biarkan 40 sebagai "endgame") | Dengan harga baru, Lv27 baru tercapai di jam ke-72; Lv40 praktis tak terjangkau |

Konstanta lain (income Zb, hatchBase, zoneFactor, harga pen/slot/trail, gain wheel 1.75) tidak perlu diubah.
Catatan: `Formulas.wheelGainPerStep` tidak diubah; hanya harga. Tes `Formulas.spec` memuat nilai `wheelUpgradePrice` (L1 = 500, L5 = 40500) sehingga perlu diperbarui jika rekomendasi 1 diterapkan.

## Hasil dengan rekomendasi 1 + 2

| Zona | recSpeed | Waktu tercapai | Target | Selisih |
|---|---|---|---|---|
| 2 | 1K | 6.0 mnt | 5 mnt | +20% |
| 3 | 8K | 15.1 mnt | | |
| 4 | 50K | 27.4 mnt | | |
| 5 | 170K | 38.1 mnt | 45 mnt | -15% |
| 6 | 2M | 72.1 mnt | | |
| 7 | 25M | 2.3 jam | | |
| 8 | 300M | 4.2 jam | | |
| 9 | 2.5B | 6.7 jam | 6 jam | +11% |
| 10 | 7B | 7.7 jam | | |
| 11 | 80B | 13.8 jam | | |
| 12 | 1T | 29.8 jam | 30 jam | -1% |

Semua target berada dalam +-30%.

### Milestone (dengan rekomendasi)

| Waktu | Kejadian |
|---|---|
| 4 mnt | Unlock $1K |
| 6 mnt | Trail Dust Puff |
| 7.4 mnt | Slot equip 4 |
| 15.7 mnt | Pen Lv2 ($1M) |
| 38 mnt | Slot equip 8-9 dan Trail Sunflare |
| 40 mnt | Pen Lv3 |
| 1.7 jam | Slot equip 12 |
| 2.0 jam | Pen Lv6 |
| 4.1 jam | Pen Lv9 |
| 6.0 jam | Pen Lv11 |
| 6.9 jam | Slot equip 14 |
| 7.1 jam | Trail Prismatic Crown |
| 7.9 jam | Wheel Lv20 |
| 29.7 jam | Wheel Lv25 |

## Sensitivitas asumsi (konstanta rekomendasi)

| Varian | Z2 | Z5 | Z9 | Z12 |
|---|---|---|---|---|
| acuan | 6.0 mnt | 38.1 mnt | 6.7 jam | 29.8 jam |
| activity 0.5 | 8.5 mnt | 45.8 mnt | 9.2 jam | 37.7 jam |
| activity 1.0 | 4.7 mnt | 24.2 mnt | 5.6 jam | 24.6 jam |
| wheelShare 0.3 | 7.7 mnt | 44.5 mnt | 8.6 jam | 38.0 jam |
| wheelShare 0.7 | 6.6 mnt | 30.7 mnt | 6.0 jam | 25.5 jam |
| wheelEfficiency 0.5 | 7.9 mnt | 56.6 mnt | 9.5 jam | 36.1 jam |
| successAtRec 0.7 | 6.0 mnt | 35.1 mnt | 6.7 jam | 29.6 jam |
| tidak berani nekat (riskFloor 1) | 5.8 mnt | 43.8 mnt | 8.2 jam | 37.7 jam |

Hasil tetap dalam kisaran target untuk pemain yang lebih santai maupun lebih efisien, kecuali pemain dengan activity 0.5 atau efisiensi roda 0.5 yang melewati target zona 9/12 sebesar 30-50%. Angka ini perlu divalidasi dengan playtest nyata.

## Keterbatasan model
- Pemain tunggal, tanpa PvP/steal, tanpa Fuse dan mutasi NPC (keduanya hanya mempercepat).
- Pemain tidak pernah memegang telur lama untuk dijual; kebijakan sell/hatch yang lebih pintar akan mempercepat progres.
- Kebijakan beli termurah-dulu bukan optimal; pemain ahli bisa lebih cepat.

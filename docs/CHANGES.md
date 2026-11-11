# Perubahan terhadap docs/PLAN.md

Koreksi spesifikasi hasil kajian (Fable). Isi lengkap ada di rencana eksekusi; ringkasan:

1. Steal: telur tetap di profil korban sampai pencuri Place (transfer atomik). Korban leave → carry dibatalkan.
2. Telur liar yang dibawa hanya di memori.
3. `eggs[uid].pos` berupa koordinat lokal plot; `eggs[uid].loc = "placed" | "pocket"`; semua key string.
4. Offline dihitung sekali saat join; hanya jika `lastOnline > 0`; `lastOnline` diperbarui tiap 30 detik.
5. Malam ×30 rata-rata ≈ 8.9×; Moonlit 1 roll per malam per telur (3–5%); `/night` memaksa fase.
6. Mutasi mata uang hanya lewat `CurrencyService`; `leaderstats` StringValue.
7. ProcessReceipt idempoten; `pendingSkip` di profil; ID produk 0 = nonaktif.
8. Guardian kinematik (Anchored, CFrame di sumbu lane), bukan Humanoid; tanpa Pathfinding.
9. Knockback/ragdoll diterapkan klien; server menegakkan WalkSpeed=0 dan kebal pickup.
10. `AntiExploit.grace()` wajib untuk gerakan sah; tanpa kick di v1.
11. Prompt disembunyikan lokal di klien; server tetap memvalidasi.
12. Nest state machine Empty/Occupied/Carried/Dropped.
13. Race: trophy sekali per event; guardian tidak ditidurkan.
14. StreamingEnabled=false untuk v1.
15. Starwhale tanpa interior; tanpa RemoteFunction GetRelayPuzzle.

## Penyimpangan implementasi
- Skenario uji Studio ada di `src/server/Tests/` (bukan `tests/studio/`).
- Stub bertipe dibuat per gelombang.
- `GameEvents` berada di `src/server/Systems/GameEvents.luau` (hanya server).

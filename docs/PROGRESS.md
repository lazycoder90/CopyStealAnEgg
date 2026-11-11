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
- [ ] Wave 0: infrastruktur kontrak (Types, Check, Maid, RNG, Net validator, Clock.now, PlayerLifecycle, CurrencyService, DataService virtual, TestBridge, InvariantChecker, autoloader)
- [ ] Wave 1 / Fase 1: core loop
- [ ] Wave 2 / Fase 2+3
- [ ] Wave 3 / Fase 4
- [ ] Wave 4 / Fase 5
- [ ] Wave 5 / Fase 6+7
- [ ] Review kode paralel + soak test
- [ ] Laporan akhir

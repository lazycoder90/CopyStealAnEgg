--!nonstrict
-- Siklus hidup pemain (dan bot uji). SEMUA service mendaftar di sini; dilarang PlayerRemoving:Connect liar.
--
-- PlayerLifecycle.onJoin(name, order, fn)     fn(ctx) dipanggil setelah profil termuat
-- PlayerLifecycle.onLeaving(name, order, fn)  fn(ctx) dipanggil SEBELUM profil dilepas (data masih valid)
-- ctx = { userId: number, player: Player?, data: table, name: string }
-- Urutan: order kecil lebih dulu. Konvensi order: Carry 10, Steal 20, Trap 30, Guardian 40, lain 100, StateReplicator 1000.
-- Hook didaftarkan di Init() (bukan Start), karena pemain baru mulai diproses setelah semua Start selesai.

local PlayerLifecycle = {}

local joinHooks = {}
local leaveHooks = {}

local function register(list, name: string, order: number, fn)
	assert(type(fn) == "function", "hook harus fungsi: " .. name)
	table.insert(list, { name = name, order = order, fn = fn, seq = #list })
	table.sort(list, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.seq < b.seq
	end)
end

local function run(list, ctx, label: string)
	for _, hook in list do
		local ok, err = pcall(hook.fn, ctx)
		if not ok then
			warn(`[PlayerLifecycle] {label} '{hook.name}' gagal untuk {ctx.userId}: {err}`)
		end
	end
end

function PlayerLifecycle.onJoin(name: string, order: number, fn)
	register(joinHooks, name, order, fn)
end

function PlayerLifecycle.onLeaving(name: string, order: number, fn)
	register(leaveHooks, name, order, fn)
end

function PlayerLifecycle.runJoin(ctx)
	run(joinHooks, ctx, "onJoin")
end

function PlayerLifecycle.runLeaving(ctx)
	run(leaveHooks, ctx, "onLeaving")
end

return PlayerLifecycle

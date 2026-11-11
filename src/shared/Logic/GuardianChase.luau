--!strict
-- Kinematika pengejaran Nestwarden (murni 2D, tanpa API Roblox).
-- state = { x, z, mode }. Guardian tidak pernah melewati Hearth Line (z >= minZ).

export type Point = { x: number, z: number }
export type State = { x: number, z: number, mode: string? }
export type Params = {
	speed: number,
	catchRadius: number,
	hearthLineZ: number,
	minZ: number?, -- default hearthLineZ + 4
}
export type Context = {
	target: Point?, -- nil = target hilang/keluar
	targetCarrying: boolean, -- target masih membawa telur
	hearthLineZ: number,
	homeX: number,
	homeZ: number,
	leash: number,
	chaseTime: number,
	maxChaseSeconds: number,
}

local GuardianChase = {}

local DEFAULT_MARGIN = 4

local function floorZ(params: Params): number
	return math.max(
		params.minZ or (params.hearthLineZ + DEFAULT_MARGIN),
		params.hearthLineZ + DEFAULT_MARGIN
	)
end

function GuardianChase.distance(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Bergerak lurus ke titik (px, pz) dengan kecepatan konstan; tidak pernah melampaui titik (overshoot-safe).
-- Mengembalikan state baru dan apakah sudah tiba.
function GuardianChase.moveToward(
	state: State,
	px: number,
	pz: number,
	dt: number,
	params: Params
): (State, boolean)
	local minZ = floorZ(params)
	local goalZ = math.max(pz, minZ)
	local dx, dz = px - state.x, goalZ - state.z
	local dist = math.sqrt(dx * dx + dz * dz)
	local stepLen = math.max(params.speed, 0) * math.max(dt, 0)
	local nx, nz
	local arrived
	if dist <= stepLen or dist < 1e-9 then
		nx, nz = px, goalZ
		arrived = true
	else
		local k = stepLen / dist
		nx, nz = state.x + dx * k, state.z + dz * k
		arrived = false
	end
	return { x = nx, z = math.max(nz, minZ), mode = state.mode }, arrived
end

-- Satu langkah pengejaran. Mengembalikan state baru dan caught (jarak ke target <= catchRadius).
function GuardianChase.step(
	state: State,
	target: Point,
	dt: number,
	params: Params
): (State, boolean)
	-- Sudah dalam jangkauan sebelum bergerak: tertangkap tanpa perlu bergerak.
	if GuardianChase.distance(state, target) <= params.catchRadius then
		return { x = state.x, z = math.max(state.z, floorZ(params)), mode = state.mode }, true
	end
	local nextState = GuardianChase.moveToward(state, target.x, target.z, dt, params)
	return nextState, GuardianChase.distance(nextState, target) <= params.catchRadius
end

-- Aturan pulang. Mengembalikan (harusPulang, alasan).
function GuardianChase.shouldReturn(state: State, ctx: Context): (boolean, string?)
	local target = ctx.target
	if target == nil then
		return true, "target_gone"
	end
	if not ctx.targetCarrying then
		return true, "target_dropped"
	end
	if target.z < ctx.hearthLineZ then
		return true, "crossed_hearth"
	end
	if GuardianChase.distance(state, { x = ctx.homeX, z = ctx.homeZ }) > ctx.leash then
		return true, "leash"
	end
	if ctx.chaseTime > ctx.maxChaseSeconds then
		return true, "timeout"
	end
	return false, nil
end

return GuardianChase

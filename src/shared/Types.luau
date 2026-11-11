--!strict
-- Kontrak bersama server/klien: tipe data dan SEMUA nama attribute/tag/folder.
-- ATURAN: dilarang menulis string literal attribute/tag/folder di luar file ini.

local Types = {}

export type Uid = string
export type Muts = { string }

export type EggData = {
	id: string, -- speciesId
	kg: number,
	muts: Muts,
	growTotal: number, -- detik waktu-game yang dibutuhkan
	progress: number, -- detik waktu-game yang sudah berjalan
	loc: "placed" | "pocket",
	pos: { x: number, z: number }?, -- koordinat LOKAL plot (hanya jika placed)
	stolenFrom: number?, -- userId pemilik awal
	t: number,
}

export type PetData = {
	id: string,
	kg: number,
	g: string, -- "M" | "F"
	muts: Muts,
	eq: boolean,
	lock: boolean,
	t: number,
}

-- Payload remote S2C (urutan argumen = urutan field di sini; selalu satu tabel).
export type CarryChangedPayload = {
	state: "Carrying" | "None",
	eggUid: string?,
	speciesId: string?,
	name: string?,
	rarity: number?,
	kg: number?,
	projectedIncome: number?,
	stolen: boolean?,
	reason: string?, -- alasan berhenti: "placed" | "dropped" | "caught" | "died" | "left" | "bonked" | "returned"
}

export type HatchRevealPayload = {
	petUid: string,
	speciesId: string,
	name: string,
	rarity: number,
	muts: Muts,
	kg: number,
	gender: string,
	income: number,
	isNew: boolean,
}

export type CaughtPayload = { knock: Vector3, zone: number? } -- knock = arah * kekuatan (klien menerapkan)
export type BonkedPayload = { knock: Vector3 }
export type TrappedPayload = { seconds: number }
export type StealAlertPayload = {
	thiefUserId: number,
	thiefName: string,
	eggUid: string,
	speciesId: string,
	name: string,
}
export type GuardianAlertPayload = { zone: number, guardianId: string }

export type NotifyKind = "info" | "error" | "success" | "admin"

-- Nama attribute pada Instance.
Types.Attr = {
	OwnerUserId = "OwnerUserId", -- Plot: userId pemilik (0 = kosong)
	PlotIndex = "PlotIndex",
	EggUid = "EggUid",
	SpeciesId = "SpeciesId",
	Rarity = "Rarity",
	Kg = "Kg",
	Income = "Income", -- proyeksi $/s
	ZoneIndex = "ZoneIndex",
	NestId = "NestId",
	NestState = "NestState", -- Empty | Occupied | Carried | Dropped
	Progress = "Progress", -- 0..1
	Ready = "Ready",
	GrowTotal = "GrowTotal",
	GrowRemaining = "GrowRemaining", -- detik sisa (untuk billboard klien)
	PetUid = "PetUid",
	Muts = "Muts", -- string "Pearl,Amber"
	Gender = "Gender",
	HatchTime = "HatchTime",
	IsGrand = "IsGrand",
	-- Wave 2
	ShieldUntil = "ShieldUntil", -- Plot: Clock.now() saat Shell Shield berakhir (0 = tidak aktif)
	StealAlert = "StealAlert", -- Plot: true saat ada yang mencuri (tanda "!")
	GuardianId = "GuardianId",
	GuardianState = "GuardianState", -- Sleep | Alert | Chase | Return
	TrapOwner = "TrapOwner",
	Carried = "Carried", -- Model telur placed yang sedang dibawa pencuri
	PenLevel = "PenLevel", -- Plot: level pen (visual pagar)
	WheelGain = "WheelGain", -- Model roda: speed per step saat ini
	WheelLevel = "WheelLevel",
}

-- Nama tag CollectionService.
Types.Tags = {
	WorldEgg = "NB_WorldEgg",
	PlacedEgg = "NB_PlacedEgg",
	Nest = "NB_Nest",
	Coop = "NB_Coop",
	HearthLine = "NB_HearthLine",
	SpawnPad = "NB_SpawnPad",
	Guardian = "NB_Guardian",
	Trap = "NB_Trap",
	Shield = "NB_Shield",
}

-- Nama folder/Instance penting di Workspace dan ReplicatedStorage.
Types.Names = {
	Map = "Map",
	Plots = "Plots",
	WorldEggs = "WorldEggs",
	Guardians = "Guardians",
	Effects = "Effects",
	Remotes = "Remotes",
	PlotEggs = "Eggs", -- anak Plot: telur placed
	PlotPets = "ActivePets", -- anak Plot: pet aktif (klien yang merender)
	PlotSpawn = "SpawnPoint",
	PlotFloor = "Floor",
	GrabPrompt = "GrabPrompt",
	HatchPrompt = "HatchPrompt",
	StealPrompt = "StealPrompt",
	TestBridge = "TestBridge",
	PlotWheel = "Wheel", -- anak Plot: model Sprint Wheel
	PlotExpansionSign = "ExpansionSign", -- anak Plot: papan "Unlock: $1K"
	PlotPenSign = "PenSign", -- anak Plot: papan upgrade pen
	Bots = "Bots", -- folder bot uji di Workspace
}

-- Nama nest state.
Types.NestState = {
	Empty = "Empty",
	Occupied = "Occupied",
	Carried = "Carried",
	Dropped = "Dropped",
}

return Types

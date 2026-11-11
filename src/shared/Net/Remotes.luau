-- Deklarasi semua remote (docs/PLAN.md §2.7). Net.luau membuatnya di server saat start.
-- Nilai = rate limit default (panggilan/detik) untuk remote C2S.

return {
	-- Klien -> Server (semua divalidasi & dibatasi rate di server)
	C2S = {
		-- Telur
		DropEgg = 5,
		PlaceEgg = 5,
		PlaceFromInventory = 5,
		PocketEgg = 5,
		HatchEgg = 5,
		-- Pet
		EquipPet = 10,
		UnequipPet = 10,
		EquipBest = 2,
		LockPet = 10,
		-- Upgrade & jual
		BuyEquipSlot = 3,
		UpgradePen = 3,
		UpgradeWheel = 3,
		BuyTrail = 3,
		EquipTrail = 5,
		SellItems = 2,
		FuseSubmit = 2,
		-- Mutasi, Index, chest
		BuyMutation = 3,
		ApplyMutation = 3,
		ClaimIndex = 10,
		ClaimIndexAll = 2,
		ClaimFreeBasket = 2,
		-- Gerak & pertahanan
		SetSlowMode = 5,
		SwingPan = 5,
		PlaceTrap = 3,
		ActivateShield = 2,
		-- Event
		SubmitRelay = 3,
		TradeStardust = 3,
		ClaimCompanionStage = 3,
		-- Monetisasi
		RequestSkipGrowth = 2,
		RequestGrowAll = 2,
		RequestRewardedAd = 2,
		-- Lainnya
		TutorialAck = 5,
		SetSetting = 5,
		AdminCommand = 5,
	},

	-- Server -> Klien
	S2C = {
		"StateInit",
		"StatePatch",
		"Notify",
		"Announce",
		"Toast",
		"CarryChanged",
		"GuardianAlert",
		"StealAlert",
		"Caught",
		"Bonked",
		"Trapped",
		"HatchReveal",
		"OfflineEarnings",
		"FuseResult",
		"MutationResult",
		"DayNight",
		"EggReset",
		"RaceState",
		"StarwhaleState",
		"IncomePopup",
		"PlayFX",
	},

	-- RemoteFunction (jarang dipakai, dibungkus pcall + timeout di klien)
	Functions = { "GetRelayPuzzle", "GetLeaderboard" },
}

--!strict
-- Central gameplay / economy tuning. Everything here can be changed without touching service code.

local GameConfig = {}

GameConfig.CurrentYear = 2026

GameConfig.Economy = {
	StartingCash = 25000,
	QuickSellRate = 0.85, -- share of market value paid when selling straight to the market
	BaseIncomePerMinute = 120, -- every player earns this while online
	DisplayIncomeRate = 0.0015, -- per minute, share of a displayed car's value
	DisplayIncomeCapPerCar = 2500, -- per minute
	IncomeTickSeconds = 10,
	LevelUpBonusPerLevel = 1500,
	MarketIndex = {
		UpdateSeconds = 180,
		MaxStep = 0.035, -- max change per update
		Min = 0.85,
		Max = 1.2,
	},
}

GameConfig.Yard = {
	Rows = 2,
	PerRow = 9, -- 2 x 9 = 18 lots
	LotSpacing = 9, -- studs between lot centres in a row
	AisleWidth = 10,
	RevealTarpSeconds = 4.5, -- tarp is removed on the server after this
	RevealHoldSeconds = 14, -- revealed car stays on its lot this long
	RestockSeconds = 18, -- delay before the empty lot gets a new tarp
	PriceRounding = 50,
}

GameConfig.Plots = {
	Count = 8,
	Width = 130, -- local X
	Depth = 190, -- local Z
	BoulevardWidth = 64,
	Spacing = 145, -- distance between plot centres along a side
}

-- Showroom capacity levels (cars that can be displayed / later sold to NPCs).
-- RobuxProduct is optional; when set, the level can also be bought with Robux (MonetizationConfig).
GameConfig.DisplayLevels = {
	{ Capacity = 2, Cost = 0 },
	{ Capacity = 6, Cost = 40000 },
	{ Capacity = 10, Cost = 140000 },
	{ Capacity = 15, Cost = 420000 },
	{ Capacity = 20, Cost = 1100000 },
	{ Capacity = 25, Cost = 2600000 },
	{ Capacity = 30, Cost = 6000000 },
	{ Capacity = 35, Cost = 14000000 },
	{ Capacity = 40, Cost = 32000000 },
}

GameConfig.Garage = {
	StartSlots = 30,
}

GameConfig.Data = {
	StoreName = "CarMarketTycoon_v1",
	AutosaveSeconds = 120,
	SessionLockSeconds = 1800, -- a lock older than this is treated as stale (crashed server)
	LoadAttempts = 6,
	MaxSalesHistory = 40,
	SchemaVersion = 1,
}

GameConfig.RateLimits = {
	-- requests allowed per `Per` seconds
	BuyLot = { Count = 4, Per = 3 },
	SellVehicle = { Count = 8, Per = 3 },
	ToggleDisplay = { Count = 6, Per = 3 },
	BuyDisplayUpgrade = { Count = 3, Per = 3 },
	GetSnapshot = { Count = 6, Per = 5 },
}

-- XP curve: level n requires XPBase * (n-1)^XPExponent total xp
GameConfig.Progression = {
	XPBase = 120,
	XPExponent = 1.6,
	MaxLevel = 200,
}

function GameConfig.levelFromXP(xp: number): number
	local p = GameConfig.Progression
	local level = math.floor((math.max(xp, 0) / p.XPBase) ^ (1 / p.XPExponent) + 1e-6) + 1
	return math.clamp(level, 1, p.MaxLevel)
end

function GameConfig.xpForLevel(level: number): number
	local p = GameConfig.Progression
	return math.ceil(p.XPBase * (level - 1) ^ p.XPExponent)
end

return GameConfig

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

-- Testing helpers. They only work inside Roblox Studio (RunService:IsStudio()),
-- so a published game is never affected even if you forget to switch them off.
GameConfig.TestMode = {
	FreeLotsInStudio = true, -- every lot costs $0 when you press Play in Studio
	FreeUpgradesInStudio = true, -- showroom upgrades and tuning cost $0 in Studio
}

function GameConfig.freeUpgrades(): boolean
	return GameConfig.TestMode.FreeUpgradesInStudio and game:GetService("RunService"):IsStudio()
end

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
	CenterGap = 190, -- free space in the middle of the map for the Mega Market
}

-- Selling showroom cars to NPC buyers
GameConfig.Sales = {
	MinPriceRate = 0.5, -- listing price limits relative to market value
	MaxPriceRate = 3.0,
	OfferTimeoutSeconds = 20,
	SpawnIntervalSeconds = { 10, 22 }, -- per plot with listings
	MaxNPCPerPlot = 2,
	PlotSaleCooldownSeconds = 20, -- at most one NPC purchase per plot in this time
	DemandDropPerSale = 0.06, -- class demand falls after each NPC purchase...
	DemandRecoveryPerMinute = 0.05, -- ...and recovers over time
	DemandMin = 0.6,
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

-- The dealership building grows with the showroom level
GameConfig.ShowroomTiers = {
	{ MinLevel = 1, NameUA = "Маленький гараж" },
	{ MinLevel = 2, NameUA = "Великий гараж" },
	{ MinLevel = 4, NameUA = "Автосалон" },
	{ MinLevel = 6, NameUA = "Преміум-шоурум" },
	{ MinLevel = 8, NameUA = "Люкс-центр" },
}

function GameConfig.showroomTier(level: number): number
	local tier = 1
	for i, t in GameConfig.ShowroomTiers do
		if level >= t.MinLevel then
			tier = i
		end
	end
	return tier
end

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
	ApplyTuning = { Count = 6, Per = 3 },
	SetListing = { Count = 6, Per = 3 },
	RespondOffer = { Count = 6, Per = 3 },
	SpinFree = { Count = 2, Per = 3 },
	PromptProduct = { Count = 3, Per = 5 },
	Teleport = { Count = 2, Per = 4 },
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

--!strict
-- Lot (tarp) tiers. Each lot in a yard rolls a tier; the tier changes the rarity odds and the price.
-- Price = expected market value of the tier * PriceMargin (computed on the server at start-up,
-- so adding cars to VehicleDatabase rebalances prices automatically).

export type TarpTier = {
	Key: string,
	NameUA: string,
	Weight: number,
	PriceMargin: number,
	RarityMultipliers: { [string]: number },
	Colors: { Color3 },
	Material: Enum.Material,
	StrapColor: Color3,
	TrimColor: Color3?,
	TagColor: Color3,
	Sparkle: boolean,
}

local TarpConfig = {}

TarpConfig.Order = { "Canvas", "Premium", "Elite" }

TarpConfig.Tiers = {
	Canvas = {
		Key = "Canvas",
		NameUA = "Стандарт",
		Weight = 72,
		PriceMargin = 0.7,
		RarityMultipliers = {
			Common = 1.6, Uncommon = 1.1, Rare = 0.55, Epic = 0.25,
			Legendary = 0.09, Mythic = 0.02, Exclusive = 0.004,
		},
		Colors = {
			Color3.fromRGB(96, 104, 72), Color3.fromRGB(150, 132, 96), Color3.fromRGB(84, 98, 116),
			Color3.fromRGB(112, 84, 64), Color3.fromRGB(70, 92, 120), Color3.fromRGB(120, 120, 112),
		},
		Material = Enum.Material.Fabric,
		StrapColor = Color3.fromRGB(40, 38, 34),
		TrimColor = nil,
		TagColor = Color3.fromRGB(190, 196, 206),
		Sparkle = false,
	},
	Premium = {
		Key = "Premium",
		NameUA = "Преміум",
		Weight = 23,
		PriceMargin = 0.78,
		RarityMultipliers = {
			Common = 1, Uncommon = 1, Rare = 1, Epic = 1, Legendary = 1, Mythic = 1, Exclusive = 1,
		},
		Colors = {
			Color3.fromRGB(28, 36, 72), Color3.fromRGB(92, 22, 36), Color3.fromRGB(36, 38, 44),
			Color3.fromRGB(20, 64, 58),
		},
		Material = Enum.Material.Leather,
		StrapColor = Color3.fromRGB(200, 164, 80),
		TrimColor = nil,
		TagColor = Color3.fromRGB(90, 170, 255),
		Sparkle = false,
	},
	Elite = {
		Key = "Elite",
		NameUA = "Еліт",
		Weight = 5,
		PriceMargin = 0.8,
		RarityMultipliers = {
			Common = 0.1, Uncommon = 0.35, Rare = 0.9, Epic = 1.6,
			Legendary = 2.4, Mythic = 3, Exclusive = 3.5,
		},
		Colors = { Color3.fromRGB(14, 14, 18), Color3.fromRGB(236, 232, 224), Color3.fromRGB(40, 16, 56) },
		Material = Enum.Material.Fabric,
		StrapColor = Color3.fromRGB(230, 186, 70),
		TrimColor = Color3.fromRGB(255, 200, 70),
		TagColor = Color3.fromRGB(255, 200, 70),
		Sparkle = true,
	},
} :: { [string]: TarpTier }

function TarpConfig.get(key: string): TarpTier
	return TarpConfig.Tiers[key] or TarpConfig.Tiers.Canvas
end

return TarpConfig

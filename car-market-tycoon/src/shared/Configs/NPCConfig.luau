-- NPC buyers. MaxRatio = highest price / market value they pay without haggling;
-- above that (up to MaxRatio * HaggleLimit) they make an offer inside OfferRange (* value).
local NPCConfig = {}

NPCConfig.Types = {
	{ Key = "Regular", NameUA = "Звичайний покупець", Weight = 34, Classes = { "Budget", "Sedan", "Wagon", "Electric" },
		MinRarity = 1, MaxRarity = 2, MaxRatio = 1.08, OfferRange = { 0.82, 0.96 }, Color = Color3.fromRGB(90, 140, 200) },
	{ Key = "Practical", NameUA = "Практичний покупець", Weight = 24, Classes = { "Sedan", "Wagon", "SUV", "Pickup", "Electric" },
		MinRarity = 1, MaxRarity = 3, MaxRatio = 1.12, OfferRange = { 0.86, 0.98 }, Color = Color3.fromRGB(110, 170, 110) },
	{ Key = "Sport", NameUA = "Любитель спорту", Weight = 18, Classes = { "SportCoupe", "Muscle", "Supercar", "Sedan", "Wagon" },
		MinRarity = 2, MaxRarity = 5, MaxRatio = 1.18, OfferRange = { 0.9, 1.03 }, Color = Color3.fromRGB(220, 70, 60) },
	{ Key = "Collector", NameUA = "Колекціонер", Weight = 12, Classes = nil,
		MinRarity = 3, MaxRarity = 4, MaxRatio = 1.25, OfferRange = { 0.95, 1.1 }, Color = Color3.fromRGB(170, 100, 230) },
	{ Key = "RichCollector", NameUA = "Багатий колекціонер", Weight = 8, Classes = nil,
		MinRarity = 5, MaxRarity = 7, MaxRatio = 1.35, OfferRange = { 1.0, 1.16 }, Color = Color3.fromRGB(240, 190, 60) },
	{ Key = "VIP", NameUA = "VIP-покупець", Weight = 4, Classes = nil,
		MinRarity = 1, MaxRarity = 7, MaxRatio = 1.6, OfferRange = { 1.1, 1.3 }, Color = Color3.fromRGB(30, 30, 34) },
}

NPCConfig.HaggleLimit = 1.6 -- above MaxRatio * this the buyer just leaves
NPCConfig.WalkSpeed = 12
NPCConfig.InspectSeconds = { 3, 6 }

return NPCConfig

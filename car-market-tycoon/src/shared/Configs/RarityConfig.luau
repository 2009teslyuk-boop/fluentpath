--!strict
-- Rarity tiers. Weights are the base odds (relative, they do not need to sum to 100).
-- Tarp tiers (TarpConfig) multiply these weights, so the odds a player sees depend on the lot.

export type Rarity = {
	Key: string,
	Index: number,
	NameUA: string,
	Weight: number,
	Color: Color3,
	Color2: Color3, -- second gradient stop for UI frames
	Glow: boolean, -- persistent glow on the car model
	Suspense: number, -- extra seconds of tension before the tarp flies off
	Pillar: number, -- height of the light pillar on reveal (0 = none)
	Particles: number, -- burst size on reveal
	Announce: boolean, -- server-wide announcement
	XP: number,
	Sound: string,
}

local RarityConfig = {}

RarityConfig.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Exclusive" }

RarityConfig.Rarities = {
	Common = {
		Key = "Common", Index = 1, NameUA = "Звичайний", Weight = 40,
		Color = Color3.fromRGB(168, 175, 186), Color2 = Color3.fromRGB(110, 116, 128),
		Glow = false, Suspense = 0, Pillar = 0, Particles = 10, Announce = false, XP = 10,
		Sound = "rbxasset://sounds/electronicpingshort.wav",
	},
	Uncommon = {
		Key = "Uncommon", Index = 2, NameUA = "Незвичайний", Weight = 25,
		Color = Color3.fromRGB(76, 214, 110), Color2 = Color3.fromRGB(30, 140, 70),
		Glow = false, Suspense = 0, Pillar = 0, Particles = 18, Announce = false, XP = 18,
		Sound = "rbxasset://sounds/electronicpingshort.wav",
	},
	Rare = {
		Key = "Rare", Index = 3, NameUA = "Рідкісний", Weight = 17,
		Color = Color3.fromRGB(60, 150, 255), Color2 = Color3.fromRGB(30, 80, 200),
		Glow = false, Suspense = 0.4, Pillar = 0, Particles = 28, Announce = false, XP = 30,
		Sound = "rbxasset://sounds/electronicpingshort.wav",
	},
	Epic = {
		Key = "Epic", Index = 4, NameUA = "Епічний", Weight = 10,
		Color = Color3.fromRGB(176, 92, 255), Color2 = Color3.fromRGB(100, 40, 200),
		Glow = false, Suspense = 0.8, Pillar = 18, Particles = 40, Announce = false, XP = 55,
		Sound = "rbxasset://sounds/electronicpingshort.wav",
	},
	Legendary = {
		Key = "Legendary", Index = 5, NameUA = "Легендарний", Weight = 5,
		Color = Color3.fromRGB(255, 196, 46), Color2 = Color3.fromRGB(230, 120, 20),
		Glow = true, Suspense = 1.6, Pillar = 45, Particles = 70, Announce = true, XP = 110,
		Sound = "rbxasset://sounds/electronicpingshort.wav",
	},
	Mythic = {
		Key = "Mythic", Index = 6, NameUA = "Міфічний", Weight = 2,
		Color = Color3.fromRGB(255, 56, 72), Color2 = Color3.fromRGB(160, 10, 40),
		Glow = true, Suspense = 2.2, Pillar = 70, Particles = 100, Announce = true, XP = 220,
		Sound = "rbxasset://sounds/electronicpingshort.wav",
	},
	Exclusive = {
		Key = "Exclusive", Index = 7, NameUA = "Ексклюзив", Weight = 1,
		Color = Color3.fromRGB(120, 255, 236), Color2 = Color3.fromRGB(255, 90, 230),
		Glow = true, Suspense = 3, Pillar = 140, Particles = 160, Announce = true, XP = 500,
		Sound = "rbxasset://sounds/electronicpingshort.wav",
	},
} :: { [string]: Rarity }

function RarityConfig.get(key: string): Rarity
	return RarityConfig.Rarities[key] or RarityConfig.Rarities.Common
end

function RarityConfig.index(key: string): number
	return RarityConfig.get(key).Index
end

-- Probability of every rarity given optional per-rarity weight multipliers.
function RarityConfig.odds(multipliers: { [string]: number }?): { [string]: number }
	local total = 0
	local raw = {}
	for _, key in RarityConfig.Order do
		local w = RarityConfig.Rarities[key].Weight * ((multipliers and multipliers[key]) or 1)
		raw[key] = w
		total += w
	end
	local result = {}
	for key, w in raw do
		result[key] = if total > 0 then w / total else 0
	end
	return result
end

return RarityConfig

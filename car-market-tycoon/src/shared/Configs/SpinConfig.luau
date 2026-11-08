-- Wheel of fortune. Chance values are percentages (shown to players before every spin).
-- One free spin every FreeCooldownSeconds; extra spins are a 20 Robux Developer Product
-- (hidden for players whose region restricts paid random items, via PolicyService).
local SpinConfig = {}

SpinConfig.FreeCooldownSeconds = 24 * 60 * 60

SpinConfig.Prizes = {
	{ Key = "Cash5k", NameUA = "$5 000", Kind = "cash", Amount = 5000, Chance = 28, Color = Color3.fromRGB(120, 230, 140) },
	{ Key = "Cash15k", NameUA = "$15 000", Kind = "cash", Amount = 15000, Chance = 18, Color = Color3.fromRGB(120, 230, 140) },
	{ Key = "Cash50k", NameUA = "$50 000", Kind = "cash", Amount = 50000, Chance = 8, Color = Color3.fromRGB(150, 255, 160) },
	{ Key = "Cash250k", NameUA = "$250 000", Kind = "cash", Amount = 250000, Chance = 1.5, Color = Color3.fromRGB(255, 210, 80) },
	{ Key = "XP", NameUA = "+400 XP", Kind = "xp", Amount = 400, Chance = 14, Color = Color3.fromRGB(110, 170, 255) },
	{ Key = "Garage", NameUA = "+2 місця в гаражі", Kind = "garage", Amount = 2, Chance = 6, Color = Color3.fromRGB(200, 200, 210) },
	{ Key = "CarRare", NameUA = "Rare авто", Kind = "car", Rarity = "Rare", Chance = 14, Color = Color3.fromRGB(60, 150, 255) },
	{ Key = "CarEpic", NameUA = "Epic авто", Kind = "car", Rarity = "Epic", Chance = 7, Color = Color3.fromRGB(176, 92, 255) },
	{ Key = "CarLegendary", NameUA = "Legendary авто", Kind = "car", Rarity = "Legendary", Chance = 2.7, Color = Color3.fromRGB(255, 196, 46) },
	{ Key = "CarMythic", NameUA = "Mythic авто", Kind = "car", Rarity = "Mythic", Chance = 0.6, Color = Color3.fromRGB(255, 56, 72) },
	{ Key = "CarExclusive", NameUA = "Exclusive авто", Kind = "car", Rarity = "Exclusive", Chance = 0.19997, Color = Color3.fromRGB(120, 255, 236) },
	{ Key = "Limited_nero", NameUA = "Velocci Corsa Nero", Kind = "limited", ProductKey = "Car_velocci_nero", Chance = 0.00001, Color = Color3.fromRGB(255, 40, 40) },
	{ Key = "Limited_fulmine", NameUA = "Aurelia Fulmine", Kind = "limited", ProductKey = "Car_aurelia_fulmine", Chance = 0.00001, Color = Color3.fromRGB(255, 200, 60) },
	{ Key = "Limited_eclipse", NameUA = "Halcyon Eclipse", Kind = "limited", ProductKey = "Car_halcyon_eclipse", Chance = 0.00001, Color = Color3.fromRGB(150, 90, 255) },
}

function SpinConfig.get(key: string)
	for i, prize in SpinConfig.Prizes do
		if prize.Key == key then
			return prize, i
		end
	end
	return nil, nil
end

return SpinConfig

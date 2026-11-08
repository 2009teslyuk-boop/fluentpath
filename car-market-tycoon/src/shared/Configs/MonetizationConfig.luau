-- Robux shop. Create the items in the Creator Dashboard (creator.roblox.com -> your experience ->
-- Monetization): Developer Products for everything in `Products`, Game Passes for `GamePasses`,
-- with the prices below, then paste their IDs here. Items with ID 0 show "not configured".
--
-- Cash rate: about $1 000 per 1 R$ for the smallest pack (= 3-4 standard lots per 25 R$) and up to
-- +60% bonus for big packs. A standard lot costs ~$7 200, a premium lot ~$61 000, an elite lot
-- ~$260 000 and the last showroom upgrade $32M, so packs speed progress up without skipping it.
local MonetizationConfig = {}

MonetizationConfig.Products = {
	-- wheel of fortune / limited cars ---------------------------------------------------------
	SpinPaid = { ProductId = 0, PriceRobux = 20, NameUA = "Прокрутка колеса фортуни" },
	Car_velocci_nero = { ProductId = 0, PriceRobux = 800, ModelKey = "velocci_nero", NameUA = "Velocci Corsa Nero" },
	Car_aurelia_fulmine = { ProductId = 0, PriceRobux = 1000, ModelKey = "aurelia_fulmine", NameUA = "Aurelia Fulmine" },
	Car_halcyon_eclipse = { ProductId = 0, PriceRobux = 5000, ModelKey = "halcyon_eclipse", NameUA = "Halcyon Eclipse" },

	-- in-game cash packs ---------------------------------------------------------------------------
	Cash_25 = { ProductId = 0, PriceRobux = 25, Kind = "cash", Amount = 25000, NameUA = "Жменя готівки" },
	Cash_99 = { ProductId = 0, PriceRobux = 99, Kind = "cash", Amount = 110000, NameUA = "Пачка грошей", Bonus = 11 },
	Cash_249 = { ProductId = 0, PriceRobux = 249, Kind = "cash", Amount = 300000, NameUA = "Кейс грошей", Bonus = 20 },
	Cash_499 = { ProductId = 0, PriceRobux = 499, Kind = "cash", Amount = 650000, NameUA = "Сейф", Bonus = 30 },
	Cash_999 = { ProductId = 0, PriceRobux = 999, Kind = "cash", Amount = 1400000, NameUA = "Інкасаторська машина", Bonus = 40 },
	Cash_2499 = { ProductId = 0, PriceRobux = 2499, Kind = "cash", Amount = 4000000, NameUA = "Банківське сховище", Bonus = 60 },

	-- slots ----------------------------------------------------------------------------------------
	GarageSlots = { ProductId = 0, PriceRobux = 49, Kind = "garage", Amount = 10, Cap = 300, NameUA = "+10 місць у гаражі" },
	ShowroomLevel = { ProductId = 0, PriceRobux = 149, Kind = "showroom", NameUA = "+1 рівень шоуруму" },

	-- timed boosts (stack in time) ------------------------------------------------------------------
	Boost_Cash30 = { ProductId = 0, PriceRobux = 39, Kind = "boost", Boost = "cash", Minutes = 30, NameUA = "x2 дохід на 30 хв" },
	Boost_Cash120 = { ProductId = 0, PriceRobux = 119, Kind = "boost", Boost = "cash", Minutes = 120, NameUA = "x2 дохід на 2 год" },
	Boost_Luck30 = { ProductId = 0, PriceRobux = 59, Kind = "boost", Boost = "luck", Minutes = 30, NameUA = "Удача x1.5 на 30 хв" },
}

-- Game Passes (bought once, kept forever)
MonetizationConfig.GamePasses = {
	VIP = {
		GamePassId = 0, PriceRobux = 299, NameUA = "VIP",
		Description = "+25% до всього доходу, безкоштовна прокрутка кожні 12 год, золотий значок VIP над головою",
	},
	DoubleIncome = {
		GamePassId = 0, PriceRobux = 199, NameUA = "x2 пасивний дохід",
		Description = "Назавжди подвоює пасивний дохід (база + шоурум)",
	},
	FastYard = {
		GamePassId = 0, PriceRobux = 99, NameUA = "Швидкий ярд",
		Description = "Нові брезенти з'являються втричі швидше",
	},
	Dealer = {
		GamePassId = 0, PriceRobux = 149, NameUA = "Досвідчений продавець",
		Description = "Покупці приходять удвічі частіше, на ділянці до 4 покупців, попит падає повільніше",
	},
	Lucky = {
		GamePassId = 0, PriceRobux = 399, NameUA = "Щасливий брезент",
		Description = "Під брезентами частіше Epic і вище (x1.25 до шансу)",
	},
	PremiumTuning = {
		GamePassId = 0, PriceRobux = 249, NameUA = "Преміум-тюнінг",
		Description = "Ексклюзивні фарби, кований золотий диск, веселкова підсвітка та інше",
	},
}

-- shop layout
MonetizationConfig.LimitedCars = { "Car_velocci_nero", "Car_aurelia_fulmine", "Car_halcyon_eclipse" }
MonetizationConfig.CashPacks = { "Cash_25", "Cash_99", "Cash_249", "Cash_499", "Cash_999", "Cash_2499" }
MonetizationConfig.PassOrder = { "VIP", "DoubleIncome", "FastYard", "Dealer", "Lucky", "PremiumTuning" }
MonetizationConfig.ExtraProducts = { "GarageSlots", "ShowroomLevel", "Boost_Cash30", "Boost_Cash120", "Boost_Luck30" }

-- effect sizes
MonetizationConfig.Effects = {
	VIPIncome = 1.25,
	VIPSpinCooldownSeconds = 12 * 60 * 60,
	DoubleIncome = 2,
	CashBoost = 2,
	FastYardRestockFactor = 1 / 3,
	DealerSpawnFactor = 0.5,
	DealerMaxNPC = 4,
	DealerDemandDropFactor = 0.5,
	LuckyMultiplier = 1.25, -- for Epic, Legendary, Mythic, Exclusive
	LuckBoostMultiplier = 1.5,
}

function MonetizationConfig.byProductId(id: number): (string?, any)
	if id == 0 then
		return nil, nil
	end
	for key, product in MonetizationConfig.Products do
		if product.ProductId == id then
			return key, product
		end
	end
	return nil, nil
end

function MonetizationConfig.byGamePassId(id: number): (string?, any)
	if id == 0 then
		return nil, nil
	end
	for key, pass in MonetizationConfig.GamePasses do
		if pass.GamePassId == id then
			return key, pass
		end
	end
	return nil, nil
end

return MonetizationConfig

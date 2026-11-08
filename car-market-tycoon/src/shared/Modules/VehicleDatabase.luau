-- Vehicle Database: every brand, model, trim, colour and special "find" lives here.
-- All brands and models are original/fictional. To add a car, append an entry to `Models`:
-- the generator, pricing, builder and UI pick it up automatically.
--
-- Body = archetype in VehicleBuilder (hatch, oldsedan, sedan, wagon, suv, pickup, coupe,
--        muscle, supercar, hypercar, luxury, electric, concept)
-- Style = optional overrides for the archetype (dimensions, lights, spoiler, extras ...)

local VehicleDatabase = {}

VehicleDatabase.Classes = {
	Budget = { NameUA = "Бюджетний", Usage = 1.25 },
	Sedan = { NameUA = "Седан", Usage = 1.1 },
	Wagon = { NameUA = "Універсал", Usage = 1.1 },
	SUV = { NameUA = "Позашляховик", Usage = 1.0 },
	Pickup = { NameUA = "Пікап", Usage = 1.15 },
	SportCoupe = { NameUA = "Спортивне купе", Usage = 0.8 },
	Muscle = { NameUA = "Мускул-кар", Usage = 0.7 },
	Supercar = { NameUA = "Суперкар", Usage = 0.35 },
	Hypercar = { NameUA = "Гіперкар", Usage = 0.15 },
	Luxury = { NameUA = "Люкс", Usage = 0.6 },
	Electric = { NameUA = "Електромобіль", Usage = 0.9 },
	Concept = { NameUA = "Концепт-кар", Usage = 0.02 },
}

VehicleDatabase.ClassOrder = {
	"Budget", "Sedan", "Wagon", "SUV", "Pickup", "SportCoupe",
	"Muscle", "Supercar", "Hypercar", "Luxury", "Electric", "Concept",
}

-- Trim sets: PriceMult / PowerMult / Weight
VehicleDatabase.TrimSets = {
	Standard = {
		{ Name = "Base", PriceMult = 1.0, PowerMult = 1.0, Weight = 50 },
		{ Name = "Comfort", PriceMult = 1.12, PowerMult = 1.05, Weight = 30 },
		{ Name = "Sport", PriceMult = 1.25, PowerMult = 1.18, Weight = 15 },
		{ Name = "Limited", PriceMult = 1.45, PowerMult = 1.25, Weight = 5 },
	},
	Utility = {
		{ Name = "Work", PriceMult = 0.95, PowerMult = 1.0, Weight = 40 },
		{ Name = "XLT", PriceMult = 1.12, PowerMult = 1.08, Weight = 35 },
		{ Name = "Trail Pro", PriceMult = 1.3, PowerMult = 1.2, Weight = 20 },
		{ Name = "Platinum", PriceMult = 1.5, PowerMult = 1.25, Weight = 5 },
	},
	Performance = {
		{ Name = "GT", PriceMult = 1.0, PowerMult = 1.0, Weight = 50 },
		{ Name = "GTS", PriceMult = 1.18, PowerMult = 1.12, Weight = 30 },
		{ Name = "R", PriceMult = 1.38, PowerMult = 1.28, Weight = 15 },
		{ Name = "Track Edition", PriceMult = 1.65, PowerMult = 1.4, Weight = 5 },
	},
	Exotic = {
		{ Name = "Coupe", PriceMult = 1.0, PowerMult = 1.0, Weight = 55 },
		{ Name = "Spider", PriceMult = 1.12, PowerMult = 1.0, Weight = 25 },
		{ Name = "Competizione", PriceMult = 1.35, PowerMult = 1.18, Weight = 15 },
		{ Name = "Aperta", PriceMult = 1.6, PowerMult = 1.25, Weight = 5 },
	},
	Luxury = {
		{ Name = "Executive", PriceMult = 1.0, PowerMult = 1.0, Weight = 55 },
		{ Name = "Long", PriceMult = 1.15, PowerMult = 1.0, Weight = 30 },
		{ Name = "Black Badge", PriceMult = 1.4, PowerMult = 1.15, Weight = 12 },
		{ Name = "Atelier", PriceMult = 1.8, PowerMult = 1.15, Weight = 3 },
	},
	Unique = {
		{ Name = "Standard", PriceMult = 1.0, PowerMult = 1.0, Weight = 70 },
		{ Name = "Launch Edition", PriceMult = 1.3, PowerMult = 1.08, Weight = 25 },
		{ Name = "One-Off", PriceMult = 1.8, PowerMult = 1.15, Weight = 5 },
	},
}

-- Paint colours. Finish: gloss | metallic | matte | pearl | chrome
VehicleDatabase.Colors = {
	{ Key = "ArcticWhite", NameUA = "Арктичний білий", Color = Color3.fromRGB(236, 238, 240), Finish = "gloss", Weight = 14, ValueMult = 1.0 },
	{ Key = "JetBlack", NameUA = "Чорний", Color = Color3.fromRGB(18, 18, 22), Finish = "gloss", Weight = 14, ValueMult = 1.0 },
	{ Key = "Silver", NameUA = "Сріблястий", Color = Color3.fromRGB(176, 182, 190), Finish = "metallic", Weight = 12, ValueMult = 1.0 },
	{ Key = "Graphite", NameUA = "Графіт", Color = Color3.fromRGB(70, 74, 82), Finish = "metallic", Weight = 11, ValueMult = 1.0 },
	{ Key = "NavyBlue", NameUA = "Темно-синій", Color = Color3.fromRGB(24, 40, 86), Finish = "metallic", Weight = 8, ValueMult = 1.0 },
	{ Key = "RacingRed", NameUA = "Гоночний червоний", Color = Color3.fromRGB(196, 20, 28), Finish = "gloss", Weight = 8, ValueMult = 1.02 },
	{ Key = "Sand", NameUA = "Пісочний", Color = Color3.fromRGB(196, 178, 140), Finish = "gloss", Weight = 5, ValueMult = 0.98 },
	{ Key = "Forest", NameUA = "Лісовий зелений", Color = Color3.fromRGB(30, 74, 48), Finish = "metallic", Weight = 5, ValueMult = 1.0 },
	{ Key = "Mocha", NameUA = "Мока", Color = Color3.fromRGB(92, 64, 48), Finish = "metallic", Weight = 4, ValueMult = 0.98 },
	{ Key = "SkyBlue", NameUA = "Небесний", Color = Color3.fromRGB(110, 170, 220), Finish = "gloss", Weight = 4, ValueMult = 1.0 },
	{ Key = "Sunburst", NameUA = "Сонячний жовтий", Color = Color3.fromRGB(250, 196, 20), Finish = "gloss", Weight = 3, ValueMult = 1.04 },
	{ Key = "Tangerine", NameUA = "Мандариновий", Color = Color3.fromRGB(250, 110, 20), Finish = "gloss", Weight = 3, ValueMult = 1.04 },
	{ Key = "Lime", NameUA = "Лайм", Color = Color3.fromRGB(150, 220, 30), Finish = "gloss", Weight = 2, ValueMult = 1.06 },
	{ Key = "Teal", NameUA = "Бірюзовий", Color = Color3.fromRGB(0, 140, 140), Finish = "metallic", Weight = 2, ValueMult = 1.06 },
	{ Key = "Burgundy", NameUA = "Бордо", Color = Color3.fromRGB(100, 16, 34), Finish = "metallic", Weight = 2, ValueMult = 1.06 },
	{ Key = "Bronze", NameUA = "Бронза", Color = Color3.fromRGB(150, 100, 56), Finish = "metallic", Weight = 1.5, ValueMult = 1.08 },
	{ Key = "MatteBlack", NameUA = "Матовий чорний", Color = Color3.fromRGB(30, 30, 32), Finish = "matte", Weight = 1.2, ValueMult = 1.12 },
	{ Key = "PearlWhite", NameUA = "Перламутр", Color = Color3.fromRGB(246, 240, 230), Finish = "pearl", Weight = 1.2, ValueMult = 1.12 },
	{ Key = "CandyRed", NameUA = "Кенді червоний", Color = Color3.fromRGB(170, 0, 24), Finish = "pearl", Weight = 0.8, ValueMult = 1.16 },
	{ Key = "MidnightPurple", NameUA = "Опівнічний фіолет", Color = Color3.fromRGB(56, 20, 92), Finish = "pearl", Weight = 0.6, ValueMult = 1.2 },
	{ Key = "MatteMilitary", NameUA = "Матовий хакі", Color = Color3.fromRGB(80, 88, 60), Finish = "matte", Weight = 0.6, ValueMult = 1.15 },
	{ Key = "Chameleon", NameUA = "Хамелеон", Color = Color3.fromRGB(60, 120, 150), Finish = "pearl", Weight = 0.25, ValueMult = 1.3 },
	{ Key = "LiquidGold", NameUA = "Рідке золото", Color = Color3.fromRGB(212, 166, 60), Finish = "chrome", Weight = 0.12, ValueMult = 1.45 },
	{ Key = "MirrorChrome", NameUA = "Дзеркальний хром", Color = Color3.fromRGB(200, 206, 214), Finish = "chrome", Weight = 0.08, ValueMult = 1.55 },
}

VehicleDatabase.Interiors = {
	{ Key = "Black", Color = Color3.fromRGB(26, 26, 28), Weight = 50 },
	{ Key = "Grey", Color = Color3.fromRGB(90, 92, 96), Weight = 20 },
	{ Key = "Tan", Color = Color3.fromRGB(170, 120, 74), Weight = 15 },
	{ Key = "Red", Color = Color3.fromRGB(140, 20, 24), Weight = 8 },
	{ Key = "Cream", Color = Color3.fromRGB(226, 214, 190), Weight = 7 },
}

-- Special "finds". Chance is rolled independently for each generated car.
VehicleDatabase.Finds = {
	LowMileage = { NameUA = "Малий пробіг", Chance = 0.04, ValueMult = 1.2 },
	SpecialEdition = { NameUA = "Особлива комплектація", Chance = 0.025, ValueMult = 1.3 },
	BarnFind = { NameUA = "Знахідка з сараю", Chance = 0.015, ValueMult = 1.4 },
	FamousOwner = { NameUA = "Унікальна історія", Chance = 0.01, ValueMult = 1.5 },
	Collector = { NameUA = "Колекційний екземпляр", Chance = 0.008, ValueMult = 1.6 },
	RareColor = { NameUA = "Рідкісний колір", Chance = 0, ValueMult = 1.0 }, -- auto, value is in the colour
}

VehicleDatabase.FindOrder = { "Collector", "FamousOwner", "BarnFind", "SpecialEdition", "LowMileage", "RareColor" }

VehicleDatabase.Stories = {
	"Простояв 20 років у сараї фермера під Полтавою — оригінальна фарба.",
	"Належав відомому гонщику, у бардачку знайшли його рукавички.",
	"Знімався в рекламному ролику — на дверях ледь видно сліди кріплення камери.",
	"Перший власник проїжджав лише по неділях до моря.",
	"Подарунок на весілля, який так і не виїхав за межі міста.",
	"Був службовим авто посольства, повна сервісна історія.",
	"Виграний у лотерею й одразу поставлений на зберігання.",
	"Учасник ралі-рейду, на рамі вигравіювано номер екіпажу.",
}

-- Models. BasePrice is the price of a pristine, average car of that model.
VehicleDatabase.Models = {
	-- COMMON ------------------------------------------------------------------
	{ Key = "vantor_pico", Brand = "Vantor", Model = "Pico", Class = "Budget", Body = "hatch",
		Rarity = "Common", BasePrice = 3600, Power = 75, YearMin = 2001, YearMax = 2014, Trims = "Standard",
		Style = { L = 11.6, Lights = "round" } },
	{ Key = "ostrava_1300", Brand = "Ostrava", Model = "1300", Class = "Budget", Body = "oldsedan",
		Rarity = "Common", BasePrice = 3000, Power = 64, YearMin = 1978, YearMax = 1994, Trims = "Standard",
		Style = {} },
	{ Key = "vantor_civa", Brand = "Vantor", Model = "Civa", Class = "Sedan", Body = "sedan",
		Rarity = "Common", BasePrice = 5200, Power = 120, YearMin = 2006, YearMax = 2018, Trims = "Standard",
		Style = {} },
	{ Key = "kessler_kombi", Brand = "Kessler", Model = "Kombi", Class = "Wagon", Body = "wagon",
		Rarity = "Common", BasePrice = 5400, Power = 110, YearMin = 2004, YearMax = 2016, Trims = "Standard",
		Style = { Rack = true } },
	{ Key = "ridgeback_trail", Brand = "Ridgeback", Model = "Trail", Class = "Pickup", Body = "pickup",
		Rarity = "Common", BasePrice = 6000, Power = 150, YearMin = 1998, YearMax = 2012, Trims = "Utility",
		Style = { Lights = "round", L = 16.4 } },

	-- UNCOMMON ----------------------------------------------------------------
	{ Key = "nordhaus_avant", Brand = "Nordhaus", Model = "Avant", Class = "Wagon", Body = "wagon",
		Rarity = "Uncommon", BasePrice = 11000, Power = 190, YearMin = 2012, YearMax = 2022, Trims = "Standard",
		Style = { W = 6.6, Clr = 0.8, Lights = "slim", Grille = "mesh" } },
	{ Key = "ridgeback_ranger", Brand = "Ridgeback", Model = "Ranger", Class = "SUV", Body = "suv",
		Rarity = "Uncommon", BasePrice = 12500, Power = 210, YearMin = 2008, YearMax = 2020, Trims = "Utility",
		Style = { SpareWheel = true, BullBar = true } },
	{ Key = "tsukumo_sora", Brand = "Tsukumo", Model = "Sora", Class = "Sedan", Body = "sedan",
		Rarity = "Uncommon", BasePrice = 10500, Power = 165, YearMin = 2014, YearMax = 2024, Trims = "Standard",
		Style = { Spoiler = "lip" } },
	{ Key = "volta_spark", Brand = "Volta", Model = "Spark", Class = "Electric", Body = "hatch",
		Rarity = "Uncommon", BasePrice = 13500, Power = 150, YearMin = 2018, YearMax = 2026, Trims = "Standard",
		Style = { Grille = "closed", Lights = "bar", LightBar = true, Accent = Color3.fromRGB(80, 220, 255) } },

	-- RARE --------------------------------------------------------------------
	{ Key = "stallion_thunder", Brand = "Stallion", Model = "Thunder", Class = "Muscle", Body = "muscle",
		Rarity = "Rare", BasePrice = 24000, Power = 420, YearMin = 1967, YearMax = 1974, Trims = "Performance",
		Style = { Lights = "round" } },
	{ Key = "tsukumo_kaze", Brand = "Tsukumo", Model = "Kaze GT", Class = "SportCoupe", Body = "coupe",
		Rarity = "Rare", BasePrice = 27000, Power = 320, YearMin = 1994, YearMax = 2002, Trims = "Performance",
		Style = { Spoiler = "wing", Lights = "slim" } },
	{ Key = "nordhaus_velo", Brand = "Nordhaus", Model = "Velo R", Class = "Sedan", Body = "sedan",
		Rarity = "Rare", BasePrice = 31000, Power = 450, YearMin = 2016, YearMax = 2025, Trims = "Performance",
		Style = { Clr = 0.7, W = 6.7, Grille = "mesh", Spoiler = "lip", QuadExhaust = true } },
	{ Key = "atlas_frontier", Brand = "Atlas", Model = "Frontier", Class = "SUV", Body = "suv",
		Rarity = "Rare", BasePrice = 29000, Power = 400, YearMin = 2015, YearMax = 2025, Trims = "Utility",
		Style = { L = 16, W = 7.2, Lights = "slim", Grille = "tall", Chrome = true } },
	{ Key = "volta_arc", Brand = "Volta", Model = "Arc", Class = "Electric", Body = "electric",
		Rarity = "Rare", BasePrice = 33000, Power = 480, YearMin = 2020, YearMax = 2026, Trims = "Standard",
		Style = { Accent = Color3.fromRGB(80, 220, 255) } },

	-- EPIC --------------------------------------------------------------------
	{ Key = "kessler_gts", Brand = "Kessler", Model = "GT-S", Class = "SportCoupe", Body = "coupe",
		Rarity = "Epic", BasePrice = 68000, Power = 520, YearMin = 2018, YearMax = 2026, Trims = "Performance",
		Style = { W = 6.8, H = 1.85, Clr = 0.6, Spoiler = "duck", QuadExhaust = true, Diffuser = true } },
	{ Key = "monarch_regent", Brand = "Monarch", Model = "Regent", Class = "Luxury", Body = "luxury",
		Rarity = "Epic", BasePrice = 82000, Power = 460, YearMin = 2016, YearMax = 2026, Trims = "Luxury",
		Style = { L = 15.6 } },
	{ Key = "stallion_hellfire", Brand = "Stallion", Model = "Hellfire", Class = "Muscle", Body = "muscle",
		Rarity = "Epic", BasePrice = 74000, Power = 800, YearMin = 2018, YearMax = 2025, Trims = "Performance",
		Style = { Lights = "slim", Spoiler = "wing", W = 7, Accent = Color3.fromRGB(255, 60, 20) } },
	{ Key = "volta_surge", Brand = "Volta", Model = "Surge", Class = "Electric", Body = "electric",
		Rarity = "Epic", BasePrice = 79000, Power = 1020, YearMin = 2022, YearMax = 2026, Trims = "Unique",
		Style = { H = 2.0, Clr = 0.6, W = 6.9, Spoiler = "lip", Diffuser = true, Accent = Color3.fromRGB(255, 80, 200) } },

	-- LEGENDARY ---------------------------------------------------------------
	{ Key = "velocci_strada", Brand = "Velocci", Model = "Strada", Class = "Supercar", Body = "supercar",
		Rarity = "Legendary", BasePrice = 210000, Power = 720, YearMin = 2014, YearMax = 2024, Trims = "Exotic",
		Style = {} },
	{ Key = "aurelia_vento", Brand = "Aurelia", Model = "Vento", Class = "Supercar", Body = "supercar",
		Rarity = "Legendary", BasePrice = 245000, Power = 770, YearMin = 2016, YearMax = 2026, Trims = "Exotic",
		Style = { Lights = "bar", Spoiler = "bigwing", Fin = true, W = 7.2 } },
	{ Key = "monarch_sovereign", Brand = "Monarch", Model = "Sovereign", Class = "Luxury", Body = "luxury",
		Rarity = "Legendary", BasePrice = 260000, Power = 590, YearMin = 2018, YearMax = 2026, Trims = "Luxury",
		Style = { L = 17.2, H = 2.75, W = 7.1 } },

	-- MYTHIC ------------------------------------------------------------------
	{ Key = "aurelia_tempesta", Brand = "Aurelia", Model = "Tempesta", Class = "Hypercar", Body = "hypercar",
		Rarity = "Mythic", BasePrice = 880000, Power = 1200, YearMin = 2019, YearMax = 2026, Trims = "Unique",
		Style = {} },
	{ Key = "halcyon_zero", Brand = "Halcyon", Model = "Zero", Class = "Hypercar", Body = "hypercar",
		Rarity = "Mythic", BasePrice = 1100000, Power = 1600, YearMin = 2021, YearMax = 2026, Trims = "Unique",
		Style = { Lights = "slim", Accent = Color3.fromRGB(0, 200, 255) } },
	{ Key = "velocci_inferno", Brand = "Velocci", Model = "Inferno", Class = "Hypercar", Body = "hypercar",
		Rarity = "Mythic", BasePrice = 960000, Power = 1050, YearMin = 2013, YearMax = 2016, Trims = "Unique",
		Style = { Fin = false, Spoiler = "wing", Accent = Color3.fromRGB(255, 120, 20) } },

	-- EXCLUSIVE ---------------------------------------------------------------
	{ Key = "halcyon_aether", Brand = "Halcyon", Model = "Aether", Class = "Concept", Body = "concept",
		Rarity = "Exclusive", BasePrice = 3000000, Power = 1900, YearMin = 2026, YearMax = 2026, Trims = "Unique",
		Style = { Accent = Color3.fromRGB(120, 255, 236) } },
	{ Key = "nova_x1", Brand = "Nova", Model = "Prototype X1", Class = "Concept", Body = "concept",
		Rarity = "Exclusive", BasePrice = 3500000, Power = 2100, YearMin = 2026, YearMax = 2026, Trims = "Unique",
		Style = { Accent = Color3.fromRGB(255, 90, 230), W = 7.6, Spoiler = "bigwing" } },
	{ Key = "monarch_celestial", Brand = "Monarch", Model = "Celestial", Class = "Concept", Body = "luxury",
		Rarity = "Exclusive", BasePrice = 2800000, Power = 1000, YearMin = 2026, YearMax = 2026, Trims = "Unique",
		Style = { L = 17.6, Lights = "bar", Grille = "closed", LightBar = true, Accent = Color3.fromRGB(255, 220, 140) } },
}

-- Indexes -------------------------------------------------------------------
VehicleDatabase.ByKey = {}
VehicleDatabase.ByRarity = {}
for _, model in VehicleDatabase.Models do
	assert(VehicleDatabase.ByKey[model.Key] == nil, "Duplicate vehicle key " .. model.Key)
	VehicleDatabase.ByKey[model.Key] = model
	VehicleDatabase.ByRarity[model.Rarity] = VehicleDatabase.ByRarity[model.Rarity] or {}
	table.insert(VehicleDatabase.ByRarity[model.Rarity], model)
end

VehicleDatabase.ColorByKey = {}
for _, color in VehicleDatabase.Colors do
	VehicleDatabase.ColorByKey[color.Key] = color
end

VehicleDatabase.InteriorByKey = {}
for _, interior in VehicleDatabase.Interiors do
	VehicleDatabase.InteriorByKey[interior.Key] = interior
end

function VehicleDatabase.getModel(key: string)
	return VehicleDatabase.ByKey[key]
end

function VehicleDatabase.getTrim(model, trimName: string)
	for _, trim in VehicleDatabase.TrimSets[model.Trims] do
		if trim.Name == trimName then
			return trim
		end
	end
	return VehicleDatabase.TrimSets[model.Trims][1]
end

function VehicleDatabase.displayName(record): string
	local model = VehicleDatabase.ByKey[record.modelKey]
	if not model then
		return "Невідоме авто"
	end
	return model.Brand .. " " .. model.Model
end

return VehicleDatabase

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
	-- tuning-only paints (Weight = 0: never on a random car)
	{ Key = "NardoGrey", NameUA = "Цементний сірий", Color = Color3.fromRGB(128, 132, 134), Finish = "gloss", Weight = 0, ValueMult = 1.0 },
	{ Key = "AcidGreen", NameUA = "Кислотний зелений", Color = Color3.fromRGB(120, 255, 40), Finish = "gloss", Weight = 0, ValueMult = 1.0 },
	{ Key = "IceBlue", NameUA = "Крижаний синій", Color = Color3.fromRGB(150, 210, 255), Finish = "matte", Weight = 0, ValueMult = 1.0 },
	{ Key = "SunsetPearl", NameUA = "Перламутровий захід", Color = Color3.fromRGB(255, 120, 60), Finish = "pearl", Weight = 0, ValueMult = 1.0 },
	{ Key = "RoyalBlue", NameUA = "Королівський синій", Color = Color3.fromRGB(20, 60, 200), Finish = "metallic", Weight = 0, ValueMult = 1.0 },
	{ Key = "HotPink", NameUA = "Гарячий рожевий", Color = Color3.fromRGB(255, 60, 160), Finish = "pearl", Weight = 0, ValueMult = 1.0 },
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
	Limited = { NameUA = "Лімітована серія", Chance = 0, ValueMult = 1.0 }, -- Robux cars
}

VehicleDatabase.FindOrder = { "Collector", "FamousOwner", "BarnFind", "SpecialEdition", "LowMileage", "RareColor", "Limited" }

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
-- Body = archetype in VehicleBuilder; Dims = real dimensions in metres (L, W, H, WB, D ...);
-- Style = archetype overrides. Names and brands are original (no real trademarks or logos);
-- the comment shows the real-world class each car is modelled on.
VehicleDatabase.Models = {
	-- COMMON ------------------------------------------------------------------
	{ Key = "vantor_pico", Brand = "Vantor", Model = "Pico", Class = "Budget", Body = "hatch", -- city hatchback
		Rarity = "Common", BasePrice = 3600, Power = 95, YearMin = 2004, YearMax = 2016, Trims = "Standard",
		Dims = { L = 4.05, W = 1.73, H = 1.47, WB = 2.47, D = 0.62 }, Style = { Rim = "steel" } },
	{ Key = "ostrava_1300", Brand = "Ostrava", Model = "1300", Class = "Budget", Body = "oldsedan", -- classic saloon
		Rarity = "Common", BasePrice = 3000, Power = 64, YearMin = 1978, YearMax = 1994, Trims = "Standard" },
	{ Key = "vantor_civa", Brand = "Vantor", Model = "Civa", Class = "Sedan", Body = "sedan", -- compact saloon
		Rarity = "Common", BasePrice = 5200, Power = 140, YearMin = 2008, YearMax = 2020, Trims = "Standard" },
	{ Key = "kessler_kombi", Brand = "Kessler", Model = "Kombi", Class = "Wagon", Body = "wagon", -- family estate
		Rarity = "Common", BasePrice = 5400, Power = 130, YearMin = 2006, YearMax = 2017, Trims = "Standard",
		Dims = { L = 4.7, W = 1.8, H = 1.48, WB = 2.7, D = 0.64, TW = 0.22 },
		Style = { Grille = "wide", Head = { Style = "slim", Z = 0.06, Len = 0.3, W = 0.4, Inset = 0.08 }, Diffuser = false, Exhaust = "single", Rim = "sport5" } },
	{ Key = "ridgeback_trail", Brand = "Ridgeback", Model = "Trail", Class = "Pickup", Body = "pickup", -- older work pickup
		Rarity = "Common", BasePrice = 6000, Power = 180, YearMin = 1998, YearMax = 2012, Trims = "Utility",
		Dims = { L = 5.4, H = 1.82, WB = 3.3, D = 0.76 }, Style = { Head = { Style = "quadround", Z = 0, Len = 0.06, W = 0.18, Inset = 0.08 }, Rim = "steel" } },

	-- UNCOMMON ----------------------------------------------------------------
	{ Key = "nordhaus_avant", Brand = "Nordhaus", Model = "Tourer 5", Class = "Wagon", Body = "wagon", -- premium estate
		Rarity = "Uncommon", BasePrice = 11000, Power = 250, YearMin = 2014, YearMax = 2023, Trims = "Standard",
		Dims = { L = 4.94, W = 1.88, D = 0.7, TW = 0.25 }, Style = { Diffuser = false, Rim = "sport5" } },
	{ Key = "ridgeback_ranger", Brand = "Ridgeback", Model = "Ranger", Class = "SUV", Body = "crossover", -- rugged mid SUV
		Rarity = "Uncommon", BasePrice = 12500, Power = 230, YearMin = 2010, YearMax = 2021, Trims = "Utility",
		Style = { BullBar = true, Flares = true, Grille = "slats", Rim = "dish6" } },
	{ Key = "tsukumo_sora", Brand = "Tsukumo", Model = "Sora", Class = "Sedan", Body = "sedan", -- mid-size saloon
		Rarity = "Uncommon", BasePrice = 10500, Power = 200, YearMin = 2016, YearMax = 2025, Trims = "Standard",
		Dims = { L = 4.88, W = 1.84, H = 1.44, WB = 2.82, D = 0.68 }, Style = { Spoiler = "lip", Head = { Style = "angular", Z = 0.06, Len = 0.34, W = 0.4, Inset = 0.08 } } },
	{ Key = "volta_spark", Brand = "Volta", Model = "Spark", Class = "Electric", Body = "hatch", -- electric hatchback
		Rarity = "Uncommon", BasePrice = 13500, Power = 200, YearMin = 2019, YearMax = 2026, Trims = "Standard",
		Style = { Grille = "closed", Exhaust = "none", LightBar = true, Rim = "turbine", Accent = Color3.fromRGB(80, 220, 255) } },
	{ Key = "kessler_terra", Brand = "Kessler", Model = "Terra 5", Class = "SUV", Body = "crossover", -- compact premium SUV (Q5 class)
		Rarity = "Uncommon", BasePrice = 14500, Power = 265, YearMin = 2017, YearMax = 2026, Trims = "Standard" },

	-- RARE --------------------------------------------------------------------
	{ Key = "stallion_thunder", Brand = "Stallion", Model = "Thunder 69", Class = "Muscle", Body = "muscle", -- classic muscle car
		Rarity = "Rare", BasePrice = 24000, Power = 420, YearMin = 1967, YearMax = 1972, Trims = "Performance",
		Dims = { L = 4.75, W = 1.82, H = 1.3, D = 0.68, TW = 0.24 },
		Style = { Head = { Style = "round", Z = 0, Len = 0.06, W = 0.18, Inset = 0.12 }, Chrome = true, Grille = "wide", Rim = "dish6", Exhaust = "dual" } },
	{ Key = "tsukumo_kaze", Brand = "Tsukumo", Model = "Kaze GT", Class = "SportCoupe", Body = "jdm", -- JDM sports coupe (Supra class)
		Rarity = "Rare", BasePrice = 27000, Power = 340, YearMin = 2019, YearMax = 2026, Trims = "Performance" },
	{ Key = "nordhaus_velo", Brand = "Nordhaus", Model = "Velo M", Class = "Sedan", Body = "sportsedan", -- super saloon (M5 class)
		Rarity = "Rare", BasePrice = 31000, Power = 600, YearMin = 2018, YearMax = 2026, Trims = "Performance",
		Style = { Caliper = Color3.fromRGB(30, 80, 200) } },
	{ Key = "atlas_frontier", Brand = "Atlas", Model = "Frontier X", Class = "SUV", Body = "suv", -- large premium SUV (X5 class)
		Rarity = "Rare", BasePrice = 29000, Power = 400, YearMin = 2018, YearMax = 2026, Trims = "Utility" },
	{ Key = "volta_arc", Brand = "Volta", Model = "Arc", Class = "Electric", Body = "electric", -- electric liftback (Model S class)
		Rarity = "Rare", BasePrice = 33000, Power = 670, YearMin = 2021, YearMax = 2026, Trims = "Standard",
		Style = { Accent = Color3.fromRGB(80, 220, 255) } },
	{ Key = "kessler_ts", Brand = "Kessler", Model = "TS Coupé", Class = "SportCoupe", Body = "coupe", -- compact sports coupe (TT class)
		Rarity = "Rare", BasePrice = 25500, Power = 310, YearMin = 2015, YearMax = 2023, Trims = "Performance" },

	-- EPIC --------------------------------------------------------------------
	{ Key = "kessler_gts", Brand = "Kessler", Model = "RS Touring", Class = "Wagon", Body = "wagon", -- performance estate (RS6 class)
		Rarity = "Epic", BasePrice = 68000, Power = 630, YearMin = 2020, YearMax = 2026, Trims = "Performance",
		Style = { Flares = false, Exhaust = "dual", Caliper = Color3.fromRGB(200, 30, 30), Rim = "y7" } },
	{ Key = "monarch_regent", Brand = "Monarch", Model = "Regent", Class = "Luxury", Body = "luxury", -- executive limousine (S-class)
		Rarity = "Epic", BasePrice = 82000, Power = 500, YearMin = 2017, YearMax = 2026, Trims = "Luxury",
		Dims = { L = 5.3, W = 1.92, H = 1.5, WB = 3.2, D = 0.76 }, Style = { Grille = "wide", Chrome = true, Tail = { Style = "slim", Z = 0.05, Len = 0.2, W = 0.44, Inset = 0.04 } } },
	{ Key = "stallion_hellfire", Brand = "Stallion", Model = "Hellfire", Class = "Muscle", Body = "muscle", -- modern supercharged muscle
		Rarity = "Epic", BasePrice = 74000, Power = 800, YearMin = 2018, YearMax = 2025, Trims = "Performance",
		Dims = { W = 1.97 }, Style = { Spoiler = "wing", Accent = Color3.fromRGB(255, 60, 20), Caliper = Color3.fromRGB(255, 200, 0) } },
	{ Key = "volta_surge", Brand = "Volta", Model = "Surge", Class = "Electric", Body = "electric", -- tri-motor EV
		Rarity = "Epic", BasePrice = 79000, Power = 1020, YearMin = 2022, YearMax = 2026, Trims = "Unique",
		Dims = { H = 1.4, D = 0.74 }, Style = { Spoiler = "lip", Diffuser = true, Rim = "twin10", Accent = Color3.fromRGB(255, 80, 200) } },
	{ Key = "halden_9x", Brand = "Halden", Model = "9X Turbo", Class = "SportCoupe", Body = "rearengine", -- rear-engined icon (911 class)
		Rarity = "Epic", BasePrice = 86000, Power = 650, YearMin = 2020, YearMax = 2026, Trims = "Performance",
		Style = { Caliper = Color3.fromRGB(255, 210, 0) } },
	{ Key = "atlas_commander", Brand = "Atlas", Model = "Commander", Class = "SUV", Body = "offroad", -- boxy luxury off-roader (G class)
		Rarity = "Epic", BasePrice = 92000, Power = 585, YearMin = 2018, YearMax = 2026, Trims = "Luxury" },

	-- LEGENDARY ---------------------------------------------------------------
	{ Key = "velocci_strada", Brand = "Velocci", Model = "Strada V8", Class = "Supercar", Body = "italian", -- Italian V8 supercar
		Rarity = "Legendary", BasePrice = 210000, Power = 720, YearMin = 2019, YearMax = 2026, Trims = "Exotic",
		Style = { Caliper = Color3.fromRGB(255, 210, 0) } },
	{ Key = "aurelia_vento", Brand = "Aurelia", Model = "Vento V10", Class = "Supercar", Body = "wedge", -- V10 wedge supercar
		Rarity = "Legendary", BasePrice = 245000, Power = 640, YearMin = 2016, YearMax = 2026, Trims = "Exotic",
		Style = { Caliper = Color3.fromRGB(40, 200, 90) } },
	{ Key = "monarch_sovereign", Brand = "Monarch", Model = "Sovereign", Class = "Luxury", Body = "luxury", -- ultra-luxury limousine
		Rarity = "Legendary", BasePrice = 260000, Power = 570, YearMin = 2018, YearMax = 2026, Trims = "Luxury" },
	{ Key = "aurelia_toro", Brand = "Aurelia", Model = "Toro V12", Class = "Supercar", Body = "wedge", -- V12 flagship wedge
		Rarity = "Legendary", BasePrice = 330000, Power = 780, YearMin = 2017, YearMax = 2024, Trims = "Exotic",
		Dims = { L = 4.87, W = 2.1, H = 1.14, WB = 2.7, D = 0.72, TW = 0.36 }, Style = { Spoiler = "wing", Caliper = Color3.fromRGB(255, 160, 0) } },

	-- MYTHIC ------------------------------------------------------------------
	{ Key = "aurelia_tempesta", Brand = "Aurelia", Model = "Tempesta", Class = "Hypercar", Body = "wedge", -- limited V12 hybrid
		Rarity = "Mythic", BasePrice = 880000, Power = 1000, YearMin = 2020, YearMax = 2026, Trims = "Unique",
		Dims = { L = 4.98, W = 2.12, H = 1.13, WB = 2.73, D = 0.74, TW = 0.36 }, Style = { Spoiler = "bigwing", Fin = true, Rim = "turbine" } },
	{ Key = "halcyon_zero", Brand = "Halcyon", Model = "Zero", Class = "Hypercar", Body = "hyper", -- W16 hypercar
		Rarity = "Mythic", BasePrice = 1100000, Power = 1600, YearMin = 2021, YearMax = 2026, Trims = "Unique",
		Style = { Accent = Color3.fromRGB(0, 200, 255), Caliper = Color3.fromRGB(0, 120, 255) } },
	{ Key = "velocci_inferno", Brand = "Velocci", Model = "Inferno", Class = "Hypercar", Body = "italian", -- V12 hybrid hypercar
		Rarity = "Mythic", BasePrice = 960000, Power = 960, YearMin = 2013, YearMax = 2016, Trims = "Unique",
		Dims = { L = 4.7, W = 1.99, H = 1.12, WB = 2.65, D = 0.72, TW = 0.34 }, Style = { Spoiler = "wing", Fin = true, Accent = Color3.fromRGB(255, 120, 20) } },

	-- EXCLUSIVE ---------------------------------------------------------------
	{ Key = "halcyon_aether", Brand = "Halcyon", Model = "Aether", Class = "Concept", Body = "concept",
		Rarity = "Exclusive", BasePrice = 3000000, Power = 1900, YearMin = 2026, YearMax = 2026, Trims = "Unique",
		Style = { Accent = Color3.fromRGB(120, 255, 236) } },
	{ Key = "nova_x1", Brand = "Nova", Model = "Prototype X1", Class = "Concept", Body = "concept",
		Rarity = "Exclusive", BasePrice = 3500000, Power = 2100, YearMin = 2026, YearMax = 2026, Trims = "Unique",
		Dims = { W = 2.18 }, Style = { Accent = Color3.fromRGB(255, 90, 230), Spoiler = "bigwing" } },
	{ Key = "monarch_celestial", Brand = "Monarch", Model = "Celestial", Class = "Concept", Body = "luxury",
		Rarity = "Exclusive", BasePrice = 2800000, Power = 1000, YearMin = 2026, YearMax = 2026, Trims = "Unique",
		Dims = { L = 5.9, H = 1.55 }, Style = { Head = { Style = "bar", Z = 0.04, Len = 0.1, W = 0.42, Inset = 0.04 }, Grille = "closed", LightBar = true, Canopy = true, Accent = Color3.fromRGB(255, 220, 140) } },

	-- LIMITED (Robux, one per player; in spins only with a 0.00001% chance; never in lots) -----------
	{ Key = "velocci_nero", Brand = "Velocci", Model = "Corsa Nero", Class = "Supercar", Body = "italian",
		Rarity = "Exclusive", BasePrice = 4000000, Power = 1050, YearMin = 2026, YearMax = 2026, Trims = "Unique",
		RobuxOnly = true, FixedColor = "MatteBlack", Untradeable = true,
		Style = { Spoiler = "bigwing", Fin = true, Caliper = Color3.fromRGB(255, 30, 30), RimColor = Color3.fromRGB(200, 30, 36), Accent = Color3.fromRGB(255, 40, 40) } },
	{ Key = "aurelia_fulmine", Brand = "Aurelia", Model = "Fulmine", Class = "Hypercar", Body = "wedge",
		Rarity = "Exclusive", BasePrice = 6000000, Power = 1250, YearMin = 2026, YearMax = 2026, Trims = "Unique",
		RobuxOnly = true, FixedColor = "LiquidGold", Untradeable = true,
		Dims = { L = 5.0, W = 2.15, H = 1.1, WB = 2.75, D = 0.74, TW = 0.37 },
		Style = { Spoiler = "bigwing", Fin = true, SideGlow = true, Rim = "turbine", Accent = Color3.fromRGB(255, 200, 60), Caliper = Color3.fromRGB(255, 200, 60) } },
	{ Key = "halcyon_eclipse", Brand = "Halcyon", Model = "Eclipse", Class = "Hypercar", Body = "hyper",
		Rarity = "Exclusive", BasePrice = 20000000, Power = 2500, YearMin = 2026, YearMax = 2026, Trims = "Unique",
		RobuxOnly = true, FixedColor = "MidnightPurple", Untradeable = true,
		Style = { SideGlow = true, LightBar = true, Canopy = true, Accent = Color3.fromRGB(150, 90, 255), Caliper = Color3.fromRGB(150, 90, 255) } },
}

-- Indexes -------------------------------------------------------------------
VehicleDatabase.ByKey = {}
VehicleDatabase.ByRarity = {}
for _, model in VehicleDatabase.Models do
	assert(VehicleDatabase.ByKey[model.Key] == nil, "Duplicate vehicle key " .. model.Key)
	VehicleDatabase.ByKey[model.Key] = model
	if not model.RobuxOnly then -- limited Robux cars never appear in lots
		VehicleDatabase.ByRarity[model.Rarity] = VehicleDatabase.ByRarity[model.Rarity] or {}
		table.insert(VehicleDatabase.ByRarity[model.Rarity], model)
	end
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

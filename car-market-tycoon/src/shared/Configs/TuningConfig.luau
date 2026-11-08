-- Tuning shop. Cost = max(MinCost, model BasePrice * CostFrac). Installed parts add
-- ValueRetention of their cost to the car's market value. Level = required player level.
-- PowerMult multiplies the car's power (performance parts).
local VehicleDatabase = require(script.Parent.Parent.Modules.VehicleDatabase)

local TuningConfig = {}

TuningConfig.ValueRetention = 0.6

TuningConfig.Categories = {
	{ Key = "Paint", NameUA = "Фарба", Group = "Зовнішність" },
	{ Key = "Rims", NameUA = "Диски", Group = "Зовнішність" },
	{ Key = "RimColor", NameUA = "Колір дисків", Group = "Зовнішність" },
	{ Key = "Spoiler", NameUA = "Спойлер", Group = "Зовнішність" },
	{ Key = "Underglow", NameUA = "Підсвітка", Group = "Зовнішність" },
	{ Key = "Tint", NameUA = "Тонування", Group = "Зовнішність" },
	{ Key = "Suspension", NameUA = "Підвіска", Group = "Техніка" },
	{ Key = "Engine", NameUA = "Двигун", Group = "Техніка" },
	{ Key = "Turbo", NameUA = "Турбіна", Group = "Техніка" },
	{ Key = "Transmission", NameUA = "Трансмісія", Group = "Техніка" },
	{ Key = "Brakes", NameUA = "Гальма", Group = "Техніка" },
	{ Key = "Tires", NameUA = "Шини", Group = "Техніка" },
}

local STOCK = { Key = "stock", NameUA = "Заводське", Remove = true }

local paintCost = {
	gloss = { 0.03, 1500, 1, "Звичайна" },
	metallic = { 0.05, 3000, 1, "Звичайна" },
	matte = { 0.08, 6000, 4, "Рідкісна" },
	pearl = { 0.1, 9000, 6, "Рідкісна" },
	chrome = { 0.25, 40000, 15, "Ексклюзивна" },
}

local paints = { STOCK }
for _, color in VehicleDatabase.Colors do
	local c = paintCost[color.Finish] or paintCost.gloss
	table.insert(paints, {
		Key = color.Key,
		NameUA = color.NameUA,
		CostFrac = c[1],
		MinCost = c[2],
		Level = c[3],
		Tier = c[4],
		Swatch = color.Color,
	})
end

TuningConfig.Options = {
	Paint = paints,
	Rims = {
		STOCK,
		{ Key = "sport5", NameUA = "Sport 5", CostFrac = 0.02, MinCost = 1500, Level = 1, Tier = "Звичайні" },
		{ Key = "y7", NameUA = "Y-Spoke 7", CostFrac = 0.025, MinCost = 2000, Level = 2, Tier = "Звичайні" },
		{ Key = "dish6", NameUA = "Deep Dish 6", CostFrac = 0.03, MinCost = 2500, Level = 3, Tier = "Звичайні" },
		{ Key = "twin10", NameUA = "Twin 10", CostFrac = 0.04, MinCost = 4000, Level = 5, Tier = "Рідкісні" },
		{ Key = "turbine", NameUA = "Turbine Aero", CostFrac = 0.06, MinCost = 8000, Level = 9, Tier = "Рідкісні" },
		{ Key = "steel", NameUA = "Сталеві", CostFrac = 0.005, MinCost = 300, Level = 1, Tier = "Звичайні" },
	},
	RimColor = {
		STOCK,
		{ Key = "Silver", NameUA = "Срібло", CostFrac = 0.005, MinCost = 500, Level = 1 },
		{ Key = "Black", NameUA = "Чорний", CostFrac = 0.008, MinCost = 800, Level = 1 },
		{ Key = "Gunmetal", NameUA = "Графіт", CostFrac = 0.008, MinCost = 800, Level = 1 },
		{ Key = "White", NameUA = "Білий", CostFrac = 0.01, MinCost = 1000, Level = 2 },
		{ Key = "Red", NameUA = "Червоний", CostFrac = 0.012, MinCost = 1200, Level = 3 },
		{ Key = "Bronze", NameUA = "Бронза", CostFrac = 0.015, MinCost = 2000, Level = 5 },
		{ Key = "Gold", NameUA = "Золото", CostFrac = 0.03, MinCost = 6000, Level = 10, Tier = "Рідкісні" },
	},
	Spoiler = {
		STOCK,
		{ Key = "none", NameUA = "Без спойлера", CostFrac = 0.002, MinCost = 300, Level = 1 },
		{ Key = "lip", NameUA = "Ліп", CostFrac = 0.01, MinCost = 1000, Level = 1 },
		{ Key = "duck", NameUA = "Дактейл", CostFrac = 0.015, MinCost = 1800, Level = 3 },
		{ Key = "wing", NameUA = "Антикрило", CostFrac = 0.03, MinCost = 3500, Level = 5 },
		{ Key = "bigwing", NameUA = "Трекове крило", CostFrac = 0.05, MinCost = 9000, Level = 12, Tier = "Рідкісні" },
	},
	Underglow = {
		STOCK,
		{ Key = "cyan", NameUA = "Бірюзова", CostFrac = 0.01, MinCost = 2000, Level = 2, Data = { color = { 0, 220, 255 } } },
		{ Key = "pink", NameUA = "Рожева", CostFrac = 0.01, MinCost = 2000, Level = 2, Data = { color = { 255, 60, 200 } } },
		{ Key = "green", NameUA = "Зелена", CostFrac = 0.01, MinCost = 2000, Level = 2, Data = { color = { 60, 255, 90 } } },
		{ Key = "red", NameUA = "Червона", CostFrac = 0.01, MinCost = 2000, Level = 2, Data = { color = { 255, 40, 40 } } },
		{ Key = "purple", NameUA = "Фіолетова", CostFrac = 0.012, MinCost = 2500, Level = 4, Data = { color = { 150, 70, 255 } } },
		{ Key = "gold", NameUA = "Золота", CostFrac = 0.02, MinCost = 6000, Level = 10, Tier = "Рідкісна", Data = { color = { 255, 190, 40 } } },
	},
	Tint = {
		STOCK,
		{ Key = "tint", NameUA = "Тонування 70%", CostFrac = 0.006, MinCost = 600, Level = 1 },
	},
	Suspension = {
		STOCK,
		{ Key = "sport", NameUA = "Спортивна (-3 см)", CostFrac = 0.02, MinCost = 2000, Level = 2, Data = { drop = 0.03 } },
		{ Key = "slammed", NameUA = "Пневма (-5 см)", CostFrac = 0.04, MinCost = 5000, Level = 8, Tier = "Рідкісна", Data = { drop = 0.05 } },
	},
	Engine = {
		STOCK,
		{ Key = "stage1", NameUA = "Stage 1 (+8%)", CostFrac = 0.05, MinCost = 2500, Level = 1, PowerMult = 1.08 },
		{ Key = "stage2", NameUA = "Stage 2 (+16%)", CostFrac = 0.1, MinCost = 6000, Level = 5, PowerMult = 1.16 },
		{ Key = "stage3", NameUA = "Stage 3 (+28%)", CostFrac = 0.18, MinCost = 15000, Level = 12, PowerMult = 1.28, Tier = "Рідкісний" },
	},
	Turbo = {
		STOCK,
		{ Key = "turbo", NameUA = "Турбіна (+12%)", CostFrac = 0.08, MinCost = 5000, Level = 3, PowerMult = 1.12 },
		{ Key = "twinturbo", NameUA = "Бі-турбо (+22%)", CostFrac = 0.14, MinCost = 12000, Level = 10, PowerMult = 1.22, Tier = "Рідкісна" },
	},
	Transmission = {
		STOCK,
		{ Key = "sport", NameUA = "Спортивна (+3%)", CostFrac = 0.03, MinCost = 2000, Level = 2, PowerMult = 1.03 },
		{ Key = "race", NameUA = "Гоночна (+6%)", CostFrac = 0.06, MinCost = 6000, Level = 8, PowerMult = 1.06 },
	},
	Brakes = {
		STOCK,
		{ Key = "sport", NameUA = "Спортивні (червоні супорти)", CostFrac = 0.02, MinCost = 1500, Level = 1 },
		{ Key = "ceramic", NameUA = "Карбон-кераміка", CostFrac = 0.06, MinCost = 8000, Level = 10, Tier = "Рідкісні" },
	},
	Tires = {
		STOCK,
		{ Key = "sport", NameUA = "Спортивні (+2%)", CostFrac = 0.015, MinCost = 1000, Level = 1, PowerMult = 1.02 },
		{ Key = "slick", NameUA = "Напівслік (+4%)", CostFrac = 0.03, MinCost = 3000, Level = 6, PowerMult = 1.04 },
	},
}

function TuningConfig.getOption(category: string, key: string)
	local list = TuningConfig.Options[category]
	if not list then
		return nil
	end
	for _, option in list do
		if option.Key == key then
			return option
		end
	end
	return nil
end

function TuningConfig.cost(option, basePrice: number): number
	if option.Remove then
		return 0
	end
	local raw = math.max(option.MinCost or 0, basePrice * (option.CostFrac or 0))
	return math.floor(raw / 50 + 0.5) * 50
end

-- Power with all installed performance parts.
function TuningConfig.effectivePower(record): number
	local power = record.power or 0
	for category, mod in record.mods or {} do
		if type(mod) == "table" then
			local option = TuningConfig.getOption(category, mod.key)
			if option and option.PowerMult then
				power *= option.PowerMult
			end
		end
	end
	return math.floor(power)
end

return TuningConfig

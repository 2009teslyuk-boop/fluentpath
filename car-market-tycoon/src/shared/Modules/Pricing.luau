-- Market value of a vehicle record. Pure function: the server is the only authority that
-- uses it for money; the client only uses values the server sent.
local VehicleDatabase = require(script.Parent.VehicleDatabase)

local Pricing = {}

Pricing.Factors = {
	ConditionFloor = 0.55, -- value multiplier at 0% condition
	MileageRef = 300000, -- km where the mileage factor bottoms out
	MileageMin = 0.6,
	MileageMax = 1.08,
	DamageDivisor = 250,
	YearSpread = 0.2, -- newest year of a model is worth +10%, oldest -10%
	Rounding = 10,
}

function Pricing.breakdown(record, marketIndex: number?)
	local model = VehicleDatabase.getModel(record.modelKey)
	if not model then
		return { total = 0 }
	end
	local f = Pricing.Factors
	local trim = VehicleDatabase.getTrim(model, record.trim)
	-- a repainted car loses the bonus of a rare factory colour
	local color = if record.mods and record.mods.Paint then nil else VehicleDatabase.ColorByKey[record.color]

	local yearFactor = 1
	if model.YearMax > model.YearMin then
		local t = (record.year - model.YearMin) / (model.YearMax - model.YearMin)
		yearFactor = 1 - f.YearSpread / 2 + f.YearSpread * math.clamp(t, 0, 1)
	end
	local conditionFactor = f.ConditionFloor + (1 - f.ConditionFloor) * math.clamp(record.condition / 100, 0, 1)
	local mileageFactor = math.clamp(f.MileageMax - record.mileage / f.MileageRef, f.MileageMin, f.MileageMax)
	local damageFactor = 1 - math.clamp(record.damage, 0, 100) / f.DamageDivisor

	local findsFactor = 1
	for _, findKey in record.finds or {} do
		local find = VehicleDatabase.Finds[findKey]
		if find then
			findsFactor *= find.ValueMult
		end
	end

	local modsValue = 0
	for _, mod in record.mods or {} do
		if type(mod) == "table" and type(mod.value) == "number" then
			modsValue += mod.value
		end
	end

	local index = marketIndex or 1
	local raw = model.BasePrice
		* trim.PriceMult
		* (color and color.ValueMult or 1)
		* yearFactor
		* conditionFactor
		* mileageFactor
		* damageFactor
		* findsFactor
		* index
		+ modsValue

	return {
		base = model.BasePrice,
		trim = trim.PriceMult,
		color = color and color.ValueMult or 1,
		year = yearFactor,
		condition = conditionFactor,
		mileage = mileageFactor,
		damage = damageFactor,
		finds = findsFactor,
		market = index,
		mods = modsValue,
		total = math.max(f.Rounding, math.floor(raw / f.Rounding + 0.5) * f.Rounding),
	}
end

function Pricing.value(record, marketIndex: number?): number
	return Pricing.breakdown(record, marketIndex).total
end

return Pricing

-- Rolls random vehicles. Runs on the server only (records are authoritative there).
local HttpService = game:GetService("HttpService")

local Configs = script.Parent.Parent.Configs
local GameConfig = require(Configs.GameConfig)
local RarityConfig = require(Configs.RarityConfig)
local VehicleDatabase = require(script.Parent.VehicleDatabase)
local Util = require(script.Parent.Util)

local VehicleGenerator = {}

function VehicleGenerator.rollRarity(rng: Random, multipliers: { [string]: number }?): string
	return Util.weightedPick(rng, RarityConfig.Order, function(key)
		local pool = VehicleDatabase.ByRarity[key]
		if not pool or #pool == 0 then
			return 0
		end
		return RarityConfig.Rarities[key].Weight * ((multipliers and multipliers[key]) or 1)
	end)
end

local function pickColor(rng: Random)
	return Util.weightedPick(rng, VehicleDatabase.Colors, function(c)
		return c.Weight
	end)
end

-- Creates a full vehicle record for a given rarity.
function VehicleGenerator.generate(rng: Random, rarity: string, forcedModelKey: string?)
	local model = if forcedModelKey
		then VehicleDatabase.getModel(forcedModelKey)
		else VehicleDatabase.ByRarity[rarity][rng:NextInteger(1, #VehicleDatabase.ByRarity[rarity])]
	assert(model, "No model for rarity " .. tostring(rarity))

	local trim = Util.weightedPick(rng, VehicleDatabase.TrimSets[model.Trims], function(t)
		return t.Weight
	end)
	local color = (model.FixedColor and VehicleDatabase.ColorByKey[model.FixedColor]) or pickColor(rng)
	local interior = Util.weightedPick(rng, VehicleDatabase.Interiors, function(i)
		return i.Weight
	end)

	local year = rng:NextInteger(model.YearMin, model.YearMax)
	local age = math.max(0, GameConfig.CurrentYear - year)
	local usage = VehicleDatabase.Classes[model.Class].Usage
	local mileage = math.floor((age + rng:NextNumber() * 0.8) * rng:NextInteger(3000, 16000) * usage)
	local condition = math.floor(100 - (rng:NextNumber() ^ 1.6) * 62)
	local damage = math.floor(math.max(0, (100 - condition) * (0.2 + rng:NextNumber() * 0.7)))

	local finds = {}
	local story = nil
	local serial = nil
	for _, key in VehicleDatabase.FindOrder do
		local find = VehicleDatabase.Finds[key]
		if find.Chance > 0 and rng:NextNumber() < find.Chance then
			table.insert(finds, key)
		end
	end
	if table.find(finds, "LowMileage") then
		mileage = rng:NextInteger(40, 4000)
		condition = math.max(condition, rng:NextInteger(88, 100))
		damage = math.min(damage, 3)
	end
	if table.find(finds, "BarnFind") then
		condition = rng:NextInteger(30, 58)
		damage = rng:NextInteger(15, 40)
		story = VehicleDatabase.Stories[1]
	end
	if table.find(finds, "FamousOwner") then
		story = VehicleDatabase.Stories[rng:NextInteger(2, #VehicleDatabase.Stories)]
	end
	if table.find(finds, "Collector") then
		serial = rng:NextInteger(1, 100)
	end
	if color.ValueMult >= 1.15 then
		table.insert(finds, "RareColor")
	end

	local trimName = trim.Name
	if table.find(finds, "SpecialEdition") then
		local set = VehicleDatabase.TrimSets[model.Trims]
		trimName = set[#set].Name -- best trim of the set
		trim = set[#set]
	end

	local power = math.floor(model.Power * trim.PowerMult * (0.97 + rng:NextNumber() * 0.06))

	return {
		id = HttpService:GenerateGUID(false),
		modelKey = model.Key,
		rarity = model.Rarity,
		trim = trimName,
		year = year,
		color = color.Key,
		interior = interior.Key,
		mileage = mileage,
		condition = condition,
		damage = damage,
		power = power,
		finds = finds,
		story = story,
		serial = serial,
		mods = {},
		acquiredAt = os.time(),
		paid = 0,
	}
end

-- Limited (Robux) car: always pristine, fixed colour, marked as a limited series.
function VehicleGenerator.generateLimited(rng: Random, modelKey: string)
	local record = VehicleGenerator.generate(rng, "Exclusive", modelKey)
	record.condition, record.damage, record.mileage = 100, 0, 0
	record.finds = { "Limited" }
	record.story = nil
	record.serial = nil
	return record
end

function VehicleGenerator.roll(rng: Random, multipliers: { [string]: number }?)
	return VehicleGenerator.generate(rng, VehicleGenerator.rollRarity(rng, multipliers))
end

return VehicleGenerator

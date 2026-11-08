-- Tuning: validates and installs visual / performance parts. Costs are computed on the server
-- from TuningConfig and the model's base price; the client only sends category + option key.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TuningConfig = require(Shared.Configs.TuningConfig)
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)

local CustomizationService = {}

local Services

local function isKey(v: any): boolean
	return type(v) == "string" and #v > 0 and #v <= 40
end

function CustomizationService.apply(player: Player, vehicleId: any, category: any, optionKey: any)
	if not isKey(vehicleId) or #vehicleId > 64 or not isKey(category) or not isKey(optionKey) then
		return { ok = false, error = "Невірний запит" }
	end
	local data = Services.PlayerDataService.getData(player)
	local record = data and data.vehicles[vehicleId]
	if not record then
		return { ok = false, error = "Цього авто немає у вашому гаражі" }
	end
	local option = TuningConfig.getOption(category, optionKey)
	if not option then
		return { ok = false, error = "Такої деталі немає" }
	end
	record.mods = record.mods or {}
	local installed = record.mods[category]
	if option.Remove then
		if not installed then
			return { ok = false, error = "Уже стоїть заводська деталь" }
		end
		record.mods[category] = nil
	else
		if installed and installed.key == option.Key then
			return { ok = false, error = "Ця деталь уже встановлена" }
		end
		if (data.level or 1) < (option.Level or 1) then
			return { ok = false, error = ("Потрібен рівень %d"):format(option.Level) }
		end
		local model = VehicleDatabase.getModel(record.modelKey)
		local cost = TuningConfig.cost(option, model and model.BasePrice or 0)
		if not Services.EconomyService.trySpend(player, cost, ("tuning %s/%s"):format(category, option.Key)) then
			return { ok = false, error = "Недостатньо коштів" }
		end
		local mod = { key = option.Key, value = math.floor(cost * TuningConfig.ValueRetention) }
		if option.Data then
			for k, v in option.Data do
				mod[k] = v
			end
		end
		record.mods[category] = mod
	end

	if table.find(data.displayed, vehicleId) then
		Services.VehicleService.refreshDisplayModel(player, vehicleId)
	end
	Services.VehicleService.pushInventory(player)
	Services.EconomyService.pushState(player)
	return { ok = true, vehicle = Services.VehicleService.serialize(record, data) }
end

function CustomizationService.init(services)
	Services = services
end

return CustomizationService

-- Inventory (garage), selling to the market, showroom display and inventory replication.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)
local VehicleBuilder = require(Shared.Modules.VehicleBuilder)
local Pricing = require(Shared.Modules.Pricing)
local RarityFX = require(Shared.Modules.RarityFX)
local Net = require(Shared.Modules.Net)
local Util = require(Shared.Modules.Util)

local VehicleService = {}

local Services
local displayModels: { [Player]: { [string]: Model } } = {}

function VehicleService.valueOf(record): number
	local model = VehicleDatabase.getModel(record.modelKey)
	local index = if model then Services.EconomyService.getMarketIndex(model.Class) else 1
	return Pricing.value(record, index)
end

-- Data sent to the client for one vehicle.
function VehicleService.serialize(record, data)
	local model = VehicleDatabase.getModel(record.modelKey)
	local value = VehicleService.valueOf(record)
	return {
		id = record.id,
		modelKey = record.modelKey,
		brand = model and model.Brand or "?",
		model = model and model.Model or "?",
		class = model and model.Class or "Sedan",
		rarity = record.rarity,
		trim = record.trim,
		year = record.year,
		color = record.color,
		interior = record.interior,
		mileage = record.mileage,
		condition = record.condition,
		damage = record.damage,
		power = record.power,
		finds = record.finds,
		story = record.story,
		serial = record.serial,
		mods = record.mods,
		paid = record.paid,
		acquiredAt = record.acquiredAt,
		value = value,
		quickSell = math.floor(value * GameConfig.Economy.QuickSellRate),
		displayed = data ~= nil and table.find(data.displayed, record.id) ~= nil,
	}
end

function VehicleService.pushInventory(player: Player)
	local data = Services.PlayerDataService.getData(player)
	if not data then
		return
	end
	local list = {}
	for _, record in data.vehicles do
		table.insert(list, VehicleService.serialize(record, data))
	end
	Net.get("InventoryChanged"):FireClient(player, list)
end

function VehicleService.hasGarageSpace(player: Player): boolean
	local data = Services.PlayerDataService.getData(player)
	return data ~= nil and Util.count(data.vehicles) < data.garageSlots
end

-- Adds a vehicle that the server generated (never one sent by a client).
function VehicleService.addVehicle(player: Player, record)
	local data = Services.PlayerDataService.getData(player)
	if not data or data.vehicles[record.id] then
		return false
	end
	data.vehicles[record.id] = record
	data.collection[record.modelKey] = (data.collection[record.modelKey] or 0) + 1
	local counts = data.stats.rarityCounts
	counts[record.rarity] = (counts[record.rarity] or 0) + 1
	local value = VehicleService.valueOf(record)
	if value > data.stats.bestValue then
		data.stats.bestValue = value
		data.stats.bestName = VehicleDatabase.displayName(record)
	end
	return true
end

local function capacityOf(data): number
	local level = GameConfig.DisplayLevels[data.displayLevel] or GameConfig.DisplayLevels[1]
	return level.Capacity
end

function VehicleService.displayIncomePerMinute(player: Player): number
	local data = Services.PlayerDataService.getData(player)
	if not data then
		return 0
	end
	local cfg = GameConfig.Economy
	local total = 0
	for _, id in data.displayed do
		local record = data.vehicles[id]
		if record then
			total += math.min(VehicleService.valueOf(record) * cfg.DisplayIncomeRate, cfg.DisplayIncomeCapPerCar)
		end
	end
	return total
end

-- Places / moves / removes showroom models so they match data.displayed.
function VehicleService.layoutShowroom(player: Player)
	local data = Services.PlayerDataService.getData(player)
	local plot = Services.PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	local models = displayModels[player] or {}
	displayModels[player] = models
	local wanted = {}
	for i, id in data.displayed do
		wanted[id] = i
	end
	for id, model in models do
		if not wanted[id] then
			model:Destroy()
			models[id] = nil
		end
	end
	for id, spot in wanted do
		local target = plot.cframe * Services.PlotService.spotLocalCFrame(spot)
		local model = models[id]
		if not model then
			local record = data.vehicles[id]
			model = VehicleBuilder.build(record)
			model.Name = "Display_" .. id
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			model:SetAttribute("OwnerUserId", player.UserId)
			RarityFX.applyGlow(model, record.rarity)
			models[id] = model
			model:PivotTo(target)
			model.Parent = plot.showroom
		else
			model:PivotTo(target)
		end
	end
	Services.PlotService.refreshSpots(plot, capacityOf(data))
end

function VehicleService.sell(player: Player, id: any)
	if type(id) ~= "string" or #id > 64 then
		return { ok = false, error = "Невірний запит" }
	end
	local data = Services.PlayerDataService.getData(player)
	local record = data and data.vehicles[id]
	if not record then
		return { ok = false, error = "Цього авто немає у вашому гаражі" }
	end
	local value = VehicleService.valueOf(record)
	local payout = math.floor(value * GameConfig.Economy.QuickSellRate)

	-- remove first, then pay: the record can never be sold twice
	data.vehicles[id] = nil
	local displayIndex = table.find(data.displayed, id)
	if displayIndex then
		table.remove(data.displayed, displayIndex)
	end
	Services.EconomyService.addCash(player, payout, "quick sell " .. record.modelKey)
	data.stats.carsSold += 1
	table.insert(data.salesHistory, 1, {
		name = VehicleDatabase.displayName(record),
		rarity = record.rarity,
		price = payout,
		paid = record.paid or 0,
		buyer = "Market",
		time = os.time(),
	})
	while #data.salesHistory > GameConfig.Data.MaxSalesHistory do
		table.remove(data.salesHistory)
	end

	Services.YardService.onVehicleLeft(player, id)
	VehicleService.layoutShowroom(player)
	VehicleService.pushInventory(player)
	Services.EconomyService.pushState(player)
	return { ok = true, payout = payout, profit = payout - (record.paid or 0) }
end

function VehicleService.toggleDisplay(player: Player, id: any)
	if type(id) ~= "string" or #id > 64 then
		return { ok = false, error = "Невірний запит" }
	end
	local data = Services.PlayerDataService.getData(player)
	if not data or not data.vehicles[id] then
		return { ok = false, error = "Цього авто немає у вашому гаражі" }
	end
	local index = table.find(data.displayed, id)
	local displayed
	if index then
		table.remove(data.displayed, index)
		displayed = false
	else
		if #data.displayed >= capacityOf(data) then
			return { ok = false, error = "Шоурум заповнений — розширте його" }
		end
		table.insert(data.displayed, id)
		displayed = true
		Services.YardService.onVehicleLeft(player, id)
	end
	VehicleService.layoutShowroom(player)
	VehicleService.pushInventory(player)
	Services.EconomyService.pushState(player)
	return { ok = true, displayed = displayed }
end

function VehicleService.setupPlayer(player: Player)
	VehicleService.layoutShowroom(player)
end

function VehicleService.cleanupPlayer(player: Player)
	local models = displayModels[player]
	if models then
		for _, model in models do
			model:Destroy()
		end
	end
	displayModels[player] = nil
end


function VehicleService.init(services)
	Services = services
end

return VehicleService

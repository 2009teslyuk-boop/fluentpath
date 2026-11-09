-- Inventory (garage), selling (market / NPC), showroom display + price tags, replication.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local TuningConfig = require(Shared.Configs.TuningConfig)
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)
local VehicleBuilder = require(Shared.Modules.VehicleBuilder)
local Pricing = require(Shared.Modules.Pricing)
local RarityFX = require(Shared.Modules.RarityFX)
local Format = require(Shared.Modules.Format)
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

function VehicleService.isTradeable(record): boolean
	local model = VehicleDatabase.getModel(record.modelKey)
	return not (model and model.Untradeable)
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
		power = TuningConfig.effectivePower(record),
		basePower = record.power,
		finds = record.finds,
		story = record.story,
		serial = record.serial,
		mods = record.mods,
		paid = record.paid,
		acquiredAt = record.acquiredAt,
		value = value,
		quickSell = math.floor(value * GameConfig.Economy.QuickSellRate),
		displayed = data ~= nil and table.find(data.displayed, record.id) ~= nil,
		listedPrice = data ~= nil and data.listings[record.id] or nil,
		tradeable = VehicleService.isTradeable(record),
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

function VehicleService.capacityOf(data): number
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

local function updatePriceTag(model: Model, price: number?)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local tag = root:FindFirstChild("PriceTag") :: BillboardGui?
	if not price then
		if tag then
			tag:Destroy()
		end
		return
	end
	if not tag then
		local newTag = Instance.new("BillboardGui")
		newTag.Name = "PriceTag"
		newTag.Size = UDim2.fromScale(6.5, 1.6)
		newTag.StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y / 2 + 2.2, 0)
		newTag.MaxDistance = 80
		newTag.LightInfluence = 0
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(14, 40, 22)
		frame.BackgroundTransparency = 0.1
		frame.Parent = newTag
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(110, 232, 140)
		stroke.Thickness = 2
		stroke.Parent = frame
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(150, 255, 170)
		label.Parent = frame
		newTag.Parent = root
		tag = newTag
	end
	local label = (tag :: BillboardGui):FindFirstChild("Text", true) :: TextLabel
	label.Text = "ПРОДАЄТЬСЯ · " .. Format.money(price)
end

local FULL_DETAIL_SPOTS = 12 -- cars beyond this spot use the lighter model (no interior / lug nuts)

local function buildDisplayModel(player: Player, record, spot: number): Model
	local model = VehicleBuilder.build(record, { lowDetail = spot > FULL_DETAIL_SPOTS })
	model.Name = "Display_" .. record.id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("OwnerUserId", player.UserId)
	RarityFX.applyGlow(model, record.rarity)
	return model
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
			model = buildDisplayModel(player, data.vehicles[id], spot)
			models[id] = model
			model:PivotTo(target)
			model.Parent = plot.showroom
		else
			model:PivotTo(target)
		end
		model:SetAttribute("SpotIndex", spot)
		updatePriceTag(model, data.listings[id])
	end
	Services.PlotService.refreshSpots(plot, VehicleService.capacityOf(data))
	local previousTier = Services.PlotService.setShowroomTier(plot, data.displayLevel, player.DisplayName)
	if previousTier and previousTier > 0 then
		local tier = GameConfig.ShowroomTiers[GameConfig.showroomTier(data.displayLevel)]
		Services.EconomyService.notify(player, ("Ваш автосалон перебудовано: %s!"):format(tier.NameUA), "level")
	end
end

-- Rebuilds one showroom model (after tuning).
function VehicleService.refreshDisplayModel(player: Player, id: string)
	local models = displayModels[player]
	if models and models[id] then
		models[id]:Destroy()
		models[id] = nil
	end
	VehicleService.layoutShowroom(player)
end

-- Detaches a showroom model so a caller can animate it away (NPC drives the car off).
function VehicleService.takeDisplayModel(player: Player, id: string): Model?
	local models = displayModels[player]
	local model = models and models[id]
	if models then
		models[id] = nil
	end
	return model
end

function VehicleService.getDisplayModel(player: Player, id: string): Model?
	local models = displayModels[player]
	return models and models[id]
end

-- Removes a vehicle from the garage and pays the seller. Single code path for every sale.
function VehicleService.completeSale(player: Player, id: string, price: number, buyer: string)
	local data = Services.PlayerDataService.getData(player)
	local record = data and data.vehicles[id]
	if not record then
		return nil
	end
	price = math.floor(price)
	-- remove first, then pay: the record can never be sold twice
	data.vehicles[id] = nil
	data.listings[id] = nil
	local displayIndex = table.find(data.displayed, id)
	if displayIndex then
		table.remove(data.displayed, displayIndex)
	end
	Services.EconomyService.addCash(player, price, ("sale %s to %s"):format(record.modelKey, buyer))
	data.stats.carsSold += 1
	table.insert(data.salesHistory, 1, {
		name = VehicleDatabase.displayName(record),
		rarity = record.rarity,
		price = price,
		paid = record.paid or 0,
		buyer = buyer,
		time = os.time(),
	})
	while #data.salesHistory > GameConfig.Data.MaxSalesHistory do
		table.remove(data.salesHistory)
	end
	Services.YardService.onVehicleLeft(player, id)
	VehicleService.layoutShowroom(player)
	VehicleService.pushInventory(player)
	Services.EconomyService.pushState(player)
	return record
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
	if not VehicleService.isTradeable(record) then
		return { ok = false, error = "Лімітоване авто не продається" }
	end
	local payout = math.floor(VehicleService.valueOf(record) * GameConfig.Economy.QuickSellRate)
	VehicleService.completeSale(player, id, payout, "Market")
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
		data.listings[id] = nil
		displayed = false
	else
		if #data.displayed >= VehicleService.capacityOf(data) then
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

-- Puts a car up for sale to NPC buyers (price = nil removes the listing).
function VehicleService.setListing(player: Player, id: any, price: any, autoSell: any)
	if type(id) ~= "string" or #id > 64 then
		return { ok = false, error = "Невірний запит" }
	end
	local data = Services.PlayerDataService.getData(player)
	local record = data and data.vehicles[id]
	if not record then
		return { ok = false, error = "Цього авто немає у вашому гаражі" }
	end
	if type(autoSell) == "boolean" then
		data.settings.autoSell = autoSell
	end
	if price == nil then
		data.listings[id] = nil
		VehicleService.layoutShowroom(player)
		VehicleService.pushInventory(player)
		return { ok = true, listed = false }
	end
	if type(price) ~= "number" or price ~= price or price == math.huge then
		return { ok = false, error = "Невірна ціна" }
	end
	if not VehicleService.isTradeable(record) then
		return { ok = false, error = "Лімітоване авто не продається" }
	end
	local value = VehicleService.valueOf(record)
	local cfg = GameConfig.Sales
	price = math.floor(price)
	if price < value * cfg.MinPriceRate or price > value * cfg.MaxPriceRate then
		return {
			ok = false,
			error = ("Ціна має бути від %s до %s"):format(Format.money(value * cfg.MinPriceRate), Format.money(value * cfg.MaxPriceRate)),
		}
	end
	if not table.find(data.displayed, id) then
		-- a listed car must stand in the showroom so buyers can see it
		if #data.displayed >= VehicleService.capacityOf(data) then
			return { ok = false, error = "Шоурум заповнений — звільніть місце або розширте його" }
		end
		table.insert(data.displayed, id)
		Services.YardService.onVehicleLeft(player, id)
	end
	data.listings[id] = price
	VehicleService.layoutShowroom(player)
	VehicleService.pushInventory(player)
	Services.EconomyService.pushState(player)
	return { ok = true, listed = true, price = price }
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

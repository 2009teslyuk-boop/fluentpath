-- Mega Market: wheel of fortune (free daily spin, extra spins for Robux) and limited cars sold
-- for Robux once per player. Purchases go through MarketplaceService Developer Products with an
-- idempotent ProcessReceipt that saves the data before confirming the purchase.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpinConfig = require(Shared.Configs.SpinConfig)
local GameConfig = require(Shared.Configs.GameConfig)
local MonetizationConfig = require(Shared.Configs.MonetizationConfig)
local RarityConfig = require(Shared.Configs.RarityConfig)
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)
local VehicleGenerator = require(Shared.Modules.VehicleGenerator)
local Format = require(Shared.Modules.Format)
local Net = require(Shared.Modules.Net)
local Util = require(Shared.Modules.Util)

local ShopService = {}

local Services
local rng = Random.new()
local paidRandomRestricted: { [Player]: boolean } = {}
local ownedPasses: { [Player]: { [string]: boolean } } = {}
local MAX_RECEIPTS = 100
local Effects = MonetizationConfig.Effects

function ShopService.hasPass(player: Player, key: string): boolean
	local passes = ownedPasses[player]
	return passes ~= nil and passes[key] == true
end

function ShopService.ownedPasses(player: Player): { [string]: boolean }
	return ownedPasses[player] or {}
end

-- Timed boosts ("cash", "luck"): seconds left (0 when inactive).
function ShopService.boostLeft(player: Player, kind: string): number
	local data = Services.PlayerDataService.getData(player)
	local untilTime = data and data.boosts and data.boosts[kind] or 0
	return math.max(0, untilTime - os.time())
end

-- Multiplier for passive income from passes and boosts.
function ShopService.incomeMultiplier(player: Player): number
	local m = 1
	if ShopService.hasPass(player, "VIP") then
		m *= Effects.VIPIncome
	end
	if ShopService.hasPass(player, "DoubleIncome") then
		m *= Effects.DoubleIncome
	end
	if ShopService.boostLeft(player, "cash") > 0 then
		m *= Effects.CashBoost
	end
	return m
end

-- Multiplier for Epic+ odds under tarps.
function ShopService.luckMultiplier(player: Player): number
	local m = 1
	if ShopService.hasPass(player, "Lucky") then
		m *= Effects.LuckyMultiplier
	end
	if ShopService.boostLeft(player, "luck") > 0 then
		m *= Effects.LuckBoostMultiplier
	end
	return m
end

local function addVipTag(player: Player, character: Model)
	if not ShopService.hasPass(player, "VIP") then
		return
	end
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not head or head:FindFirstChild("VipTag") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Size = UDim2.fromScale(3, 0.9)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 80
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "★ VIP ★"
	label.TextColor3 = Color3.fromRGB(255, 205, 70)
	label.TextStrokeTransparency = 0.3
	label.Parent = tag
	tag.Parent = head
end

local function setPass(player: Player, key: string)
	ownedPasses[player] = ownedPasses[player] or {}
	ownedPasses[player][key] = true
	if key == "VIP" and player.Character then
		task.spawn(addVipTag, player, player.Character)
	end
end

local function grantCar(player: Player, record, source: string)
	local data = Services.PlayerDataService.getData(player)
	record.paid = 0
	record.acquiredAt = os.time()
	Services.VehicleService.addVehicle(player, record)
	Services.EconomyService.addXP(player, RarityConfig.get(record.rarity).XP)
	local payload = Services.VehicleService.serialize(record, data)
	if RarityConfig.get(record.rarity).Announce then
		Net.get("Announce"):FireAllClients({
			ownerUserId = player.UserId,
			ownerName = player.DisplayName,
			rarity = record.rarity,
			name = VehicleDatabase.displayName(record),
			value = payload.value,
			source = source,
		})
	end
	return payload
end

local function grantLimited(player: Player, productKey: string)
	local data = Services.PlayerDataService.getData(player)
	local product = MonetizationConfig.Products[productKey]
	if not data or not product then
		return nil
	end
	data.limitedOwned[productKey] = os.time()
	local record = VehicleGenerator.generateLimited(rng, product.ModelKey)
	return grantCar(player, record, "limited")
end

-- Rolls the wheel and applies the prize. Returns what the client needs to animate it.
local function doSpin(player: Player)
	local data = Services.PlayerDataService.getData(player)
	if not data then
		return nil
	end
	data.spins += 1
	local prize = Util.weightedPick(rng, SpinConfig.Prizes, function(p)
		return p.Chance
	end)
	local note = nil
	if prize.Kind == "limited" and data.limitedOwned[prize.ProductKey] then
		-- each limited car only once: an owner gets an Exclusive car instead
		prize = SpinConfig.get("CarExclusive")
		note = " (лімітка вже ваша)"
	end
	local _, index = SpinConfig.get(prize.Key)
	local result = { key = prize.Key, index = index, name = prize.NameUA .. (note or ""), kind = prize.Kind }

	if prize.Kind == "cash" then
		Services.EconomyService.addCash(player, prize.Amount, "spin " .. prize.Key)
	elseif prize.Kind == "xp" then
		Services.EconomyService.addXP(player, prize.Amount)
	elseif prize.Kind == "garage" then
		data.garageSlots += prize.Amount
	elseif prize.Kind == "limited" then
		result.vehicle = grantLimited(player, prize.ProductKey)
	elseif prize.Kind == "car" then
		local record = VehicleGenerator.generate(rng, prize.Rarity)
		if Services.VehicleService.hasGarageSpace(player) then
			result.vehicle = grantCar(player, record, "spin")
		else
			local cash = math.floor(Services.VehicleService.valueOf(record) * 0.85)
			Services.EconomyService.addCash(player, cash, "spin car (garage full)")
			result.name = ("%s → %s (гараж заповнений)"):format(prize.NameUA, Format.money(cash))
		end
	end
	Services.VehicleService.pushInventory(player)
	Services.EconomyService.pushState(player)
	return result
end

function ShopService.freeSpinReadyAt(data, player: Player?): number
	local cooldown = SpinConfig.FreeCooldownSeconds
	if player and ShopService.hasPass(player, "VIP") then
		cooldown = Effects.VIPSpinCooldownSeconds
	end
	return (data.lastFreeSpin or 0) + cooldown
end

function ShopService.isPaidRandomRestricted(player: Player): boolean
	return paidRandomRestricted[player] == true
end

function ShopService.spinFree(player: Player)
	local data = Services.PlayerDataService.getData(player)
	if not data then
		return { ok = false, error = "Дані ще завантажуються" }
	end
	if os.time() < ShopService.freeSpinReadyAt(data, player) then
		return { ok = false, error = "Безкоштовна прокрутка буде доступна пізніше" }
	end
	data.lastFreeSpin = os.time()
	local result = doSpin(player)
	return { ok = true, result = result }
end

function ShopService.promptProduct(player: Player, productKey: any)
	if type(productKey) ~= "string" then
		return { ok = false, error = "Невірний запит" }
	end
	local data = Services.PlayerDataService.getData(player)
	if not data then
		return { ok = false, error = "Дані ще завантажуються" }
	end
	local pass = MonetizationConfig.GamePasses[productKey]
	if pass then
		if pass.GamePassId == 0 then
			return { ok = false, error = "Пропуск ще не налаштовано (GamePassId = 0 у MonetizationConfig)" }
		end
		if ShopService.hasPass(player, productKey) then
			return { ok = false, error = "Цей пропуск уже ваш" }
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
		return { ok = true }
	end
	local product = MonetizationConfig.Products[productKey]
	if not product then
		return { ok = false, error = "Такого товару немає" }
	end
	if product.ProductId == 0 then
		return { ok = false, error = "Товар ще не налаштовано (ProductId = 0 у MonetizationConfig)" }
	end
	if productKey == "SpinPaid" and paidRandomRestricted[player] then
		return { ok = false, error = "Платні прокрутки недоступні у вашому регіоні" }
	end
	if product.ModelKey and data.limitedOwned[productKey] then
		return { ok = false, error = "Це лімітоване авто вже ваше — його можна купити лише раз" }
	end
	if product.Kind == "garage" and data.garageSlots >= product.Cap then
		return { ok = false, error = ("Гараж уже максимального розміру (%d)"):format(product.Cap) }
	end
	if product.Kind == "showroom" and data.displayLevel >= #GameConfig.DisplayLevels then
		return { ok = false, error = "Шоурум уже максимального розміру" }
	end
	MarketplaceService:PromptProductPurchase(player, product.ProductId)
	return { ok = true }
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = Services.PlayerDataService.getData(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if data.receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local productKey, product = MonetizationConfig.byProductId(receipt.ProductId)
	if not productKey then
		warn("[Shop] Unknown product id " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if productKey == "SpinPaid" then
		local result = doSpin(player)
		Net.get("SpinResult"):FireClient(player, result)
	elseif product.Kind == "cash" then
		Services.EconomyService.addCash(player, product.Amount, "robux pack " .. productKey)
		Services.EconomyService.notify(player, ("Нараховано %s!"):format(Format.money(product.Amount)), "success")
	elseif product.Kind == "garage" then
		data.garageSlots = math.min(product.Cap, data.garageSlots + product.Amount)
		Services.EconomyService.notify(player, ("Гараж розширено до %d місць"):format(data.garageSlots), "success")
	elseif product.Kind == "showroom" then
		if data.displayLevel < #GameConfig.DisplayLevels then
			data.displayLevel += 1
			Services.VehicleService.layoutShowroom(player)
			Services.EconomyService.notify(player, ("Шоурум розширено до %d місць"):format(GameConfig.DisplayLevels[data.displayLevel].Capacity), "success")
		else
			Services.EconomyService.addCash(player, 1000000, "showroom level compensation")
			Services.EconomyService.notify(player, "Шоурум уже максимальний — нараховано $1 000 000", "info")
		end
	elseif product.Kind == "boost" then
		data.boosts = data.boosts or {}
		local current = math.max(os.time(), data.boosts[product.Boost] or 0)
		data.boosts[product.Boost] = current + product.Minutes * 60
		Services.EconomyService.notify(player, product.NameUA .. " активовано!", "level")
	elseif product.ModelKey then
		if data.limitedOwned[productKey] then
			-- bought twice through a race between two prompts: compensate instead of a duplicate
			Services.EconomyService.addCash(player, 250000, "duplicate limited purchase compensation")
			Services.EconomyService.notify(player, "Це авто вже ваше — нараховано компенсацію $250 000", "info")
		else
			local vehicle = grantLimited(player, productKey)
			Net.get("SpinResult"):FireClient(player, { kind = "limited", name = product.NameUA, vehicle = vehicle, purchased = true })
		end
	end

	data.receipts[receipt.PurchaseId] = os.time()
	if Util.count(data.receipts) > MAX_RECEIPTS then
		-- drop the oldest receipt ids
		local list = {}
		for id, t in data.receipts do
			table.insert(list, { id = id, t = t })
		end
		table.sort(list, function(a, b)
			return a.t < b.t
		end)
		for i = 1, #list - MAX_RECEIPTS do
			data.receipts[list[i].id] = nil
		end
	end
	print(("[Shop] %s purchased %s (%s)"):format(player.Name, productKey, receipt.PurchaseId))
	Services.VehicleService.pushInventory(player)
	Services.EconomyService.pushState(player)

	if not Services.PlayerDataService.saveNow(player) then
		-- the grant stays in memory; Roblox retries the receipt and the id check prevents a double grant
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.setupPlayer(player: Player)
	ownedPasses[player] = {}
	task.spawn(function()
		for key, pass in MonetizationConfig.GamePasses do
			if pass.GamePassId ~= 0 then
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
				end)
				if ok and owns and player.Parent then
					setPass(player, key)
				end
			end
		end
		if player.Parent then
			Services.EconomyService.pushState(player)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		addVipTag(player, character)
	end)
	task.spawn(function()
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		-- if the policy cannot be read, be safe and hide paid random spins
		paidRandomRestricted[player] = not ok or (info and info.ArePaidRandomItemsRestricted) == true
		if player.Parent then
			Services.EconomyService.pushState(player)
		end
	end)
end

function ShopService.cleanupPlayer(player: Player)
	paidRandomRestricted[player] = nil
	ownedPasses[player] = nil
end

function ShopService.init(services)
	Services = services
end

function ShopService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		local key, pass = MonetizationConfig.byGamePassId(gamePassId)
		if key and Services.PlayerDataService.isLoaded(player) then
			setPass(player, key)
			print(("[Shop] %s bought game pass %s"):format(player.Name, key))
			Services.EconomyService.notify(player, ("Пропуск «%s» активовано!"):format(pass.NameUA), "level")
			Services.EconomyService.pushState(player)
		end
	end)
end

return ShopService

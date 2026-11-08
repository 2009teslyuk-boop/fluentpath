-- Mega Market: wheel of fortune (free daily spin, extra spins for Robux) and limited cars sold
-- for Robux once per player. Purchases go through MarketplaceService Developer Products with an
-- idempotent ProcessReceipt that saves the data before confirming the purchase.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpinConfig = require(Shared.Configs.SpinConfig)
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
local MAX_RECEIPTS = 100

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

function ShopService.freeSpinReadyAt(data): number
	return (data.lastFreeSpin or 0) + SpinConfig.FreeCooldownSeconds
end

function ShopService.isPaidRandomRestricted(player: Player): boolean
	return paidRandomRestricted[player] == true
end

function ShopService.spinFree(player: Player)
	local data = Services.PlayerDataService.getData(player)
	if not data then
		return { ok = false, error = "Дані ще завантажуються" }
	end
	if os.time() < ShopService.freeSpinReadyAt(data) then
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
	local product = MonetizationConfig.Products[productKey]
	local data = Services.PlayerDataService.getData(player)
	if not product or not data then
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
end

function ShopService.init(services)
	Services = services
end

function ShopService.start()
	MarketplaceService.ProcessReceipt = processReceipt
end

return ShopService

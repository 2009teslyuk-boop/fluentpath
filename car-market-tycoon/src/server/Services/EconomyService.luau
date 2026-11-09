-- Money, XP / levels, passive income, market index and player state replication.
-- Every change of cash goes through this service (server authority only).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)
local Net = require(Shared.Modules.Net)
local Util = require(Shared.Modules.Util)

local EconomyService = {}

local Services
local marketIndex: { [string]: number } = {}
local marketFolder: Folder
local rng = Random.new()

local function isValidAmount(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function log(player: Player, kind: string, amount: number, reason: string)
	-- Transaction log (server output). Replace with an analytics / MessagingService sink if needed.
	print(("[Economy] %s %s %d (%s)"):format(player.Name, kind, amount, reason))
end

local function updateLeaderstats(player: Player, data)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local cash = stats:FindFirstChild("Cash") :: IntValue?
	local level = stats:FindFirstChild("Level") :: IntValue?
	if cash then
		cash.Value = math.floor(data.cash)
	end
	if level then
		level.Value = data.level
	end
end

function EconomyService.getCash(player: Player): number
	local data = Services.PlayerDataService.getData(player)
	return data and data.cash or 0
end

function EconomyService.addCash(player: Player, amount: number, reason: string, silent: boolean?): boolean
	local data = Services.PlayerDataService.getData(player)
	if not data or not isValidAmount(amount) or amount < 0 then
		return false
	end
	amount = math.floor(amount)
	data.cash += amount
	data.stats.totalEarned += amount
	if not silent then
		log(player, "+", amount, reason)
	end
	updateLeaderstats(player, data)
	return true
end

-- Atomic check-and-deduct (no yields between the check and the write).
function EconomyService.trySpend(player: Player, amount: number, reason: string): boolean
	local data = Services.PlayerDataService.getData(player)
	if not data or not isValidAmount(amount) or amount < 0 then
		return false
	end
	amount = math.floor(amount)
	if data.cash < amount then
		return false
	end
	data.cash -= amount
	data.stats.totalSpent += amount
	log(player, "-", amount, reason)
	updateLeaderstats(player, data)
	return true
end

function EconomyService.addXP(player: Player, amount: number)
	local data = Services.PlayerDataService.getData(player)
	if not data or not isValidAmount(amount) or amount <= 0 then
		return
	end
	data.xp += math.floor(amount)
	local newLevel = GameConfig.levelFromXP(data.xp)
	while data.level < newLevel do
		data.level += 1
		local bonus = data.level * GameConfig.Economy.LevelUpBonusPerLevel
		EconomyService.addCash(player, bonus, "level up")
		EconomyService.notify(player, ("Новий рівень %d! Бонус %s"):format(data.level, "$" .. tostring(bonus)), "level")
	end
	updateLeaderstats(player, data)
end

function EconomyService.getMarketIndex(class: string): number
	return marketIndex[class] or 1
end

function EconomyService.notify(player: Player, text: string, kind: string?)
	Net.get("Notify"):FireClient(player, { text = text, kind = kind or "info" })
end

function EconomyService.incomePerMinute(player: Player): number
	local income = GameConfig.Economy.BaseIncomePerMinute
	if Services.VehicleService then
		income += Services.VehicleService.displayIncomePerMinute(player)
	end
	return math.floor(income * Services.ShopService.incomeMultiplier(player))
end

function EconomyService.buildState(player: Player)
	local data = Services.PlayerDataService.getData(player)
	if not data then
		return nil
	end
	local levels = GameConfig.DisplayLevels
	local current = levels[data.displayLevel] or levels[1]
	local nextLevel = levels[data.displayLevel + 1]
	return {
		cash = data.cash,
		xp = data.xp,
		level = data.level,
		xpLevelStart = GameConfig.xpForLevel(data.level),
		xpNextLevel = GameConfig.xpForLevel(data.level + 1),
		displayLevel = data.displayLevel,
		displayCapacity = current.Capacity,
		displayedCount = #data.displayed,
		nextDisplayCapacity = nextLevel and nextLevel.Capacity or nil,
		nextDisplayCost = nextLevel and nextLevel.Cost or nil,
		garageCount = Util.count(data.vehicles),
		garageSlots = data.garageSlots,
		incomePerMinute = EconomyService.incomePerMinute(player),
		stats = data.stats,
		plotIndex = Services.PlotService.getPlot(player) and (Services.PlotService.getPlot(player) :: any).index or nil,
		serverTime = os.time(),
		freeSpinReadyAt = Services.ShopService.freeSpinReadyAt(data, player),
		passes = Services.ShopService.ownedPasses(player),
		cashBoostLeft = Services.ShopService.boostLeft(player, "cash"),
		luckBoostLeft = Services.ShopService.boostLeft(player, "luck"),
		incomeMultiplier = Services.ShopService.incomeMultiplier(player),
		paidSpinAllowed = not Services.ShopService.isPaidRandomRestricted(player),
		limitedOwned = data.limitedOwned,
		autoSell = data.settings.autoSell,
		listingsCount = Util.count(data.listings),
		showroomTier = GameConfig.showroomTier(data.displayLevel),
		decorCount = #data.decor,
	}
end

function EconomyService.pushState(player: Player)
	local state = EconomyService.buildState(player)
	if state then
		Net.get("StateChanged"):FireClient(player, state)
	end
end

function EconomyService.setupPlayer(player: Player)
	local data = Services.PlayerDataService.getData(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = stats
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = stats
	stats.Parent = player
	updateLeaderstats(player, data)
end

local function updateMarket()
	local cfg = GameConfig.Economy.MarketIndex
	for _, class in VehicleDatabase.ClassOrder do
		local current = marketIndex[class] or 1
		-- random walk with a soft pull back to 1.0
		local step = (rng:NextNumber() * 2 - 1) * cfg.MaxStep + (1 - current) * 0.08
		current = math.clamp(current + step, cfg.Min, cfg.Max)
		marketIndex[class] = math.floor(current * 1000 + 0.5) / 1000
		marketFolder:SetAttribute(class, marketIndex[class])
	end
end

function EconomyService.init(services)
	Services = services
	marketFolder = Instance.new("Folder")
	marketFolder.Name = "MarketIndex"
	marketFolder.Parent = ReplicatedStorage
	for _, class in VehicleDatabase.ClassOrder do
		marketIndex[class] = 1
		marketFolder:SetAttribute(class, 1)
	end
end

function EconomyService.start()
	-- market fluctuations
	task.spawn(function()
		while true do
			task.wait(GameConfig.Economy.MarketIndex.UpdateSeconds)
			updateMarket()
			for _, player in Players:GetPlayers() do
				if Services.PlayerDataService.isLoaded(player) then
					Services.VehicleService.pushInventory(player)
				end
			end
		end
	end)
	-- passive income
	task.spawn(function()
		local tick = GameConfig.Economy.IncomeTickSeconds
		while true do
			task.wait(tick)
			for _, player in Players:GetPlayers() do
				if Services.PlayerDataService.isLoaded(player) and Services.PlotService.getPlot(player) then
					local amount = EconomyService.incomePerMinute(player) * tick / 60
					EconomyService.addCash(player, amount, "income", true)
					EconomyService.pushState(player)
				end
			end
		end
	end)
end

return EconomyService

-- Binds every client -> server request. Each request is rate limited per player, only accepted
-- once the player's data is loaded, wrapped in pcall, and arguments are validated by the handler.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local Net = require(Shared.Modules.Net)

local RemoteService = {}

local Services
local buckets: { [Player]: { [string]: { tokens: number, updated: number } } } = {}

local function allow(player: Player, name: string): boolean
	local limit = GameConfig.RateLimits[name]
	if not limit then
		return true
	end
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[name]
	if not bucket then
		bucket = { tokens = limit.Count, updated = now }
		playerBuckets[name] = bucket
	end
	bucket.tokens = math.min(limit.Count, bucket.tokens + (now - bucket.updated) * (limit.Count / limit.Per))
	bucket.updated = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function bind(name: string, handler: (Player, ...any) -> any)
	local remote = Net.get(name) :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, ...)
		if not allow(player, name) then
			return { ok = false, error = "Забагато запитів, зачекайте секунду" }
		end
		if not Services.PlayerDataService.isLoaded(player) or not Services.PlotService.getPlot(player) then
			return { ok = false, error = "Дані ще завантажуються" }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(("[Remote] %s failed for %s: %s"):format(name, player.Name, tostring(result)))
			return { ok = false, error = "Помилка сервера, спробуйте ще раз" }
		end
		return result
	end
end

function RemoteService.init(services)
	Services = services
end

function RemoteService.start()
	bind("BuyLot", function(player, lotIndex)
		return Services.YardService.buyLot(player, lotIndex)
	end)
	bind("SellVehicle", function(player, id)
		return Services.VehicleService.sell(player, id)
	end)
	bind("ToggleDisplay", function(player, id)
		return Services.VehicleService.toggleDisplay(player, id)
	end)
	bind("BuyDisplayUpgrade", function(player)
		return Services.UpgradeService.buyDisplayUpgrade(player)
	end)
	bind("GetSnapshot", function(player)
		local data = Services.PlayerDataService.getData(player)
		local inventory = {}
		for _, record in data.vehicles do
			table.insert(inventory, Services.VehicleService.serialize(record, data))
		end
		return { ok = true, state = Services.EconomyService.buildState(player), inventory = inventory }
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return RemoteService

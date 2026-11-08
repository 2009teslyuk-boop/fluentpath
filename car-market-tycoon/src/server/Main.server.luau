-- Server entry point: initialises every service and wires the player session pipeline.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)

Net.setupServer()

local ORDER = {
	"WorldService",
	"PlotService",
	"PlayerDataService",
	"EconomyService",
	"VehicleService",
	"YardService",
	"UpgradeService",
	"CustomizationService",
	"SalesService",
	"ShopService",
	"RemoteService",
}

local Services = {}
for _, name in ORDER do
	Services[name] = require(script.Parent.Services[name])
end
for _, name in ORDER do
	local service = Services[name]
	if service.init then
		service.init(Services)
	end
end

local PlayerDataService = Services.PlayerDataService

-- Session pipeline ---------------------------------------------------------------------------
PlayerDataService.ProfileLoaded:Connect(function(player: Player)
	local plot = Services.PlotService.assign(player)
	if not plot then
		player:Kick("Усі ділянки на цьому сервері зайняті. Спробуйте інший сервер.")
		return
	end
	Services.EconomyService.setupPlayer(player)
	Services.YardService.setupPlayer(player)
	Services.VehicleService.setupPlayer(player)
	Services.SalesService.setupPlayer(player)
	Services.ShopService.setupPlayer(player)
	Services.EconomyService.pushState(player)
	Services.VehicleService.pushInventory(player)
end)

PlayerDataService.ProfileReleasing:Connect(function(player: Player)
	Services.YardService.cleanupPlayer(player)
	Services.SalesService.cleanupPlayer(player)
	Services.ShopService.cleanupPlayer(player)
	Services.VehicleService.cleanupPlayer(player)
end)

for _, name in ORDER do
	local service = Services[name]
	if service.start then
		task.spawn(service.start)
	end
end

print("[CarMarketTycoon] Server ready")

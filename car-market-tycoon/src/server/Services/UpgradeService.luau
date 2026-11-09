-- Showroom capacity upgrades (2 -> 40 display spots), paid with in-game cash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)

local UpgradeService = {}

local Services

function UpgradeService.buyDisplayUpgrade(player: Player)
	local data = Services.PlayerDataService.getData(player)
	if not data then
		return { ok = false, error = "Дані ще завантажуються" }
	end
	local nextLevel = GameConfig.DisplayLevels[data.displayLevel + 1]
	if not nextLevel then
		return { ok = false, error = "Шоурум уже максимального розміру" }
	end
	local cost = if GameConfig.freeUpgrades() then 0 else nextLevel.Cost
	if not Services.EconomyService.trySpend(player, cost, "display upgrade " .. (data.displayLevel + 1)) then
		return { ok = false, error = "Недостатньо коштів" }
	end
	data.displayLevel += 1
	Services.VehicleService.layoutShowroom(player)
	Services.EconomyService.pushState(player)
	return { ok = true, level = data.displayLevel, capacity = nextLevel.Capacity }
end

function UpgradeService.init(services)
	Services = services
end

return UpgradeService

-- Client-side mirror of the server state (read only: every change comes from the server).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local StateController = {}
StateController.state = nil :: any
StateController.inventory = {} :: { any }
StateController.StateChanged = Signal.new()
StateController.InventoryChanged = Signal.new()
StateController.Ready = Signal.new()
StateController.isReady = false

local function setState(state)
	if not state then
		return
	end
	StateController.state = state
	StateController.StateChanged:Fire(state)
	if not StateController.isReady then
		StateController.isReady = true
		StateController.Ready:Fire()
	end
end

local function setInventory(list)
	StateController.inventory = list or {}
	StateController.InventoryChanged:Fire(StateController.inventory)
end

function StateController.findVehicle(id: string)
	for _, vehicle in StateController.inventory do
		if vehicle.id == id then
			return vehicle
		end
	end
	return nil
end

function StateController.init()
	Net.get("StateChanged").OnClientEvent:Connect(setState)
	Net.get("InventoryChanged").OnClientEvent:Connect(setInventory)
	task.spawn(function()
		local remote = Net.get("GetSnapshot")
		while not StateController.isReady do
			local ok, result = pcall(function()
				return remote:InvokeServer()
			end)
			if ok and type(result) == "table" and result.ok then
				setInventory(result.inventory)
				setState(result.state)
				break
			end
			task.wait(2)
		end
	end)
end

return StateController

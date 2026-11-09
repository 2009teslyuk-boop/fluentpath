-- Remote definitions. The server creates every remote at start-up; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Functions = {
	"BuyLot", "SellVehicle", "ToggleDisplay", "BuyDisplayUpgrade", "GetSnapshot",
	"ApplyTuning", "SetListing", "RespondOffer", "SpinFree", "PromptProduct", "Teleport", "PlaceDecor", "RemoveDecor",
}
Net.Events = { "StateChanged", "InventoryChanged", "LotRevealed", "Announce", "Notify", "OfferReceived", "SpinResult" }

local FOLDER_NAME = "Remotes"

function Net.setupServer(): Folder
	assert(RunService:IsServer(), "Net.setupServer is server only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in Net.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Net.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

function Net.get(name: string): any
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name)
end

return Net

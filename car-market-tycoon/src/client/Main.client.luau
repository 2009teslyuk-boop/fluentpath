-- Client entry point.
local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"StateController",
	"HUDController",
	"RevealController",
	"YardController",
	"InventoryController",
	"ShowroomController",
	"MarketController",
}

for _, name in ORDER do
	local ok, err = pcall(function()
		require(Controllers:WaitForChild(name)).init()
	end)
	if not ok then
		warn(("[Client] %s failed to start: %s"):format(name, tostring(err)))
	end
end

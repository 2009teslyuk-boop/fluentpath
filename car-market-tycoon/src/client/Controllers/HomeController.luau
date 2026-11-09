-- "Додому" menu button: teleports the player to their own plot (server validated).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)

local HUDController = require(script.Parent.HUDController)

local HomeController = {}

local function teleport(destination: string)
	local ok, result = pcall(function()
		return Net.get("Teleport"):InvokeServer(destination)
	end)
	if not (ok and type(result) == "table" and result.ok) then
		HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
	end
end

function HomeController.init()
	HUDController.addMenuButton(6, "ДОДОМУ", "До свого автосалону", function()
		teleport("home")
	end)
	HUDController.addMenuButton(7, "ДО МАРКЕТУ", "Центр карти", function()
		teleport("shop")
	end)
end

return HomeController

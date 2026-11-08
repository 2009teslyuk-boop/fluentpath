-- Market overview: live price index per vehicle class (server driven fluctuations).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local C = require(UI.Components)
local create = C.create

local HUDController = require(script.Parent.HUDController)

local MarketController = {}

local modal
local rows = {} :: { [string]: TextLabel }

local function refresh()
	local folder = ReplicatedStorage:FindFirstChild("MarketIndex")
	if not folder then
		return
	end
	for class, label in rows do
		local index = folder:GetAttribute(class) or 1
		local pct = (index - 1) * 100
		label.Text = ("%s%.1f%%"):format(if pct >= 0 then "+" else "", pct)
		label.TextColor3 = if pct > 0.05 then Theme.Money elseif pct < -0.05 then Theme.Danger else Theme.Muted
	end
end

function MarketController.init()
	modal = C.modal("MarketUI", "РИНОК", Vector2.new(560, 560), 11)
	local content = modal.content
	C.label({
		Text = "Ціни на класи авто змінюються кожні кілька хвилин. Продавайте, коли ваш клас у плюсі.",
		TextColor3 = Theme.Muted,
		TextSize = 14,
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -48, 0, 40),
		Parent = content,
	})
	local list = create("Frame", {
		Position = UDim2.fromOffset(24, 64),
		Size = UDim2.new(1, -48, 1, -80),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		create("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 54), CellPadding = UDim2.fromOffset(12, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, class in VehicleDatabase.ClassOrder do
		local cell = create("Frame", { LayoutOrder = i, BackgroundColor3 = Theme.Panel2, Parent = list }, {
			C.corner(Theme.CornerSmall),
			C.label({ Text = VehicleDatabase.Classes[class].NameUA, Font = Theme.FontBold, TextSize = 15, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.62, 0, 1, 0) }),
		})
		rows[class] = C.label({
			Text = "+0.0%",
			Font = Theme.FontBlack,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.6, 0, 0, 0),
			Size = UDim2.new(0.4, -12, 1, 0),
			Parent = cell,
		})
	end
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("MarketIndex")
		folder.AttributeChanged:Connect(refresh)
		refresh()
	end)
	HUDController.addMenuButton(3, "РИНОК", "Індекси цін", function()
		if modal.isOpen() then
			modal.close()
		else
			refresh()
			modal.open()
		end
	end)
end

return MarketController

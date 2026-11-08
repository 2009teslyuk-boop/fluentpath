-- Garage: grid of rarity-framed vehicle cards, sorting, a rotating 3D preview of the selected
-- car (ViewportFrame) and actions (display in the showroom / quick sell).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Format = require(Shared.Modules.Format)
local RarityConfig = require(Shared.Configs.RarityConfig)
local VehicleBuilder = require(Shared.Modules.VehicleBuilder)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local C = require(UI.Components)
local create = C.create

local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)
local RevealController = require(script.Parent.RevealController)

local InventoryController = {}

local modal
local grid: ScrollingFrame
local summary: TextLabel
local detail: Frame
local detailBody: ScrollingFrame
local viewport: ViewportFrame
local viewportCamera: Camera
local displayButton: TextButton
local sellButton: TextButton
local emptyLabel: TextLabel

local sortMode = "value"
local selectedId: string? = nil
local previewModel: Model? = nil
local previewId: string? = nil
local previewConnection: RBXScriptConnection? = nil
local busy = false

local SORTS = {
	{ key = "value", text = "Цінність" },
	{ key = "rarity", text = "Рідкість" },
	{ key = "new", text = "Нові" },
}

local function sortedInventory()
	local list = table.clone(StateController.inventory)
	table.sort(list, function(a, b)
		if sortMode == "rarity" then
			local ra, rb = RarityConfig.index(a.rarity), RarityConfig.index(b.rarity)
			if ra ~= rb then
				return ra > rb
			end
			return a.value > b.value
		elseif sortMode == "new" then
			return (a.acquiredAt or 0) > (b.acquiredAt or 0)
		end
		return a.value > b.value
	end)
	return list
end

local function setPreview(vehicle)
	if vehicle and previewModel and previewId == vehicle.id then
		return -- same car, keep the rotating preview
	end
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	previewId = vehicle and vehicle.id
	if not vehicle then
		return
	end
	local model, dims = VehicleBuilder.build(vehicle)
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	previewModel = model
	local angle = 0.6
	local center = Vector3.new(0, dims.H * 0.4, 0)
	local distance = dims.L * 0.95 + 3
	local function place()
		local dir = CFrame.Angles(0, angle, 0).LookVector
		viewportCamera.CFrame = CFrame.lookAt(center + dir * distance + Vector3.new(0, dims.H * 0.9 + 1.5, 0), center)
	end
	place()
	if previewConnection then
		previewConnection:Disconnect()
	end
	previewConnection = RunService.RenderStepped:Connect(function(dt)
		angle += dt * 0.5
		place()
	end)
end

local function stopPreview()
	if previewConnection then
		previewConnection:Disconnect()
		previewConnection = nil
	end
	setPreview(nil)
end

local function showDetail(vehicle)
	for _, child in detailBody:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not vehicle then
		detail.Visible = false
		stopPreview()
		return
	end
	detail.Visible = true
	RevealController.buildVehicleDetails(detailBody, vehicle)
	C.label({
		LayoutOrder = 10,
		Text = "Вартість " .. Format.money(vehicle.value) .. "   ·   Куплено за " .. Format.money(vehicle.paid or 0),
		TextSize = 14,
		Font = Theme.FontBold,
		TextColor3 = Theme.Money,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = detailBody,
	})
	displayButton.Text = if vehicle.displayed then "ПРИБРАТИ З ШОУРУМУ" else "ВИСТАВИТИ В ШОУРУМ"
	sellButton.Text = "ПРОДАТИ ЗА " .. Format.moneyShort(vehicle.quickSell)
	setPreview(vehicle)
end

local function card(vehicle, order: number)
	local rarity = RarityConfig.get(vehicle.rarity)
	local selected = vehicle.id == selectedId
	local button = create("TextButton", {
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if selected then Theme.Panel3 else Theme.Panel2,
		Parent = grid,
	}, {
		C.corner(Theme.CornerSmall),
		C.stroke(rarity.Color, if selected then 2.5 else 1.4, if selected then 0 else 0.25),
		create("Frame", { Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, {
			C.gradient(rarity.Color, rarity.Color2, 0),
		}),
		C.label({ Text = string.upper(rarity.NameUA), TextColor3 = rarity.Color, Font = Theme.FontBlack, TextSize = 11, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 14) }),
		C.label({ Text = vehicle.brand .. " " .. vehicle.model, Font = Theme.FontBold, TextSize = 15, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 36), TextYAlignment = Enum.TextYAlignment.Top }),
		C.label({ Text = Format.moneyShort(vehicle.value), Font = Theme.FontBlack, TextColor3 = Theme.Money, TextSize = 16, Position = UDim2.new(0, 10, 1, -26), Size = UDim2.new(1, -20, 0, 20) }),
	})
	if vehicle.displayed then
		C.label({ Text = "У ШОУРУМІ", TextColor3 = Theme.Accent, Font = Theme.FontBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0, 10, 1, -24), Size = UDim2.new(1, -20, 0, 16), Parent = button })
	end
	if vehicle.finds and #vehicle.finds > 0 then
		C.label({ Text = "★", TextColor3 = Theme.Gold, Font = Theme.FontBlack, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(10, 7), Size = UDim2.new(1, -20, 0, 18), Parent = button })
	end
	button.Activated:Connect(function()
		C.playClick()
		selectedId = vehicle.id
		InventoryController.refresh()
	end)
end

function InventoryController.refresh()
	if not modal or not modal.isOpen() then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local list = sortedInventory()
	local total = 0
	for i, vehicle in list do
		total += vehicle.value
		card(vehicle, i)
	end
	local state = StateController.state
	summary.Text = ("%d / %d авто · загальна вартість %s"):format(#list, state and state.garageSlots or 0, Format.money(total))
	emptyLabel.Visible = #list == 0
	local selected = selectedId and StateController.findVehicle(selectedId)
	if not selected then
		selectedId = list[1] and list[1].id
		selected = list[1]
	end
	showDetail(selected)
end

local function act(remoteName: string, successText: (any) -> string)
	if busy or not selectedId then
		return
	end
	busy = true
	local id = selectedId
	local ok, result = pcall(function()
		return Net.get(remoteName):InvokeServer(id)
	end)
	busy = false
	if ok and type(result) == "table" and result.ok then
		HUDController.toast(successText(result), "success")
	else
		HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
	end
end

local function build()
	modal = C.modal("InventoryUI", "ГАРАЖ", Vector2.new(1060, 600), 11)
	local content = modal.content
	modal.onClose = stopPreview

	summary = C.label({ Text = "", TextColor3 = Theme.Muted, TextSize = 14, Position = UDim2.fromOffset(22, 12), Size = UDim2.new(0.5, 0, 0, 22), Parent = content })

	local sortBar = create("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 22, 0, 40),
		Size = UDim2.new(0.55, -30, 0, 34),
		BackgroundTransparency = 1,
		Parent = content,
	}, { C.list(Enum.FillDirection.Horizontal, 8) })
	for i, sort in SORTS do
		C.button({ Text = sort.text, LayoutOrder = i, Size = UDim2.fromOffset(110, 34), TextSize = 14, Parent = sortBar }, "secondary", function()
			sortMode = sort.key
			InventoryController.refresh()
		end)
	end

	grid = create("ScrollingFrame", {
		Position = UDim2.fromOffset(22, 84),
		Size = UDim2.new(0.55, -30, 1, -100),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(176, 112), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
	})
	emptyLabel = C.label({
		Text = "Гараж порожній. Купіть лот під брезентом на своїй ділянці!",
		TextColor3 = Theme.Muted,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(22, 160),
		Size = UDim2.new(0.55, -30, 0, 60),
		Visible = false,
		Parent = content,
	})

	detail = create("Frame", {
		Position = UDim2.new(0.55, 0, 0, 12),
		Size = UDim2.new(0.45, -22, 1, -28),
		BackgroundColor3 = Theme.Panel2,
		Parent = content,
	}, { C.corner(Theme.CornerSmall) })

	viewportCamera = create("Camera", { FieldOfView = 40 })
	viewport = create("ViewportFrame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 160),
		BackgroundColor3 = Color3.fromRGB(16, 18, 24),
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, -0.4),
		CurrentCamera = viewportCamera,
		Parent = detail,
	}, { C.corner(Theme.CornerSmall), C.gradient(Color3.fromRGB(60, 66, 84), Color3.fromRGB(20, 22, 30), 90) })
	viewportCamera.Parent = viewport

	detailBody = create("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 178),
		Size = UDim2.new(1, -22, 1, -248),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = detail,
	}, { C.list(Enum.FillDirection.Vertical, 6) })

	local actions = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(1, -24, 0, 48),
		BackgroundTransparency = 1,
		Parent = detail,
	}, { C.list(Enum.FillDirection.Horizontal, 8) })
	displayButton = C.button({ Text = "ВИСТАВИТИ", LayoutOrder = 1, Size = UDim2.new(0.55, -4, 1, 0), TextSize = 14, Parent = actions }, "primary", function()
		act("ToggleDisplay", function(result)
			return if result.displayed then "Авто виставлено в шоурум" else "Авто прибрано з шоуруму"
		end)
	end)
	sellButton = C.button({ Text = "ПРОДАТИ", LayoutOrder = 2, Size = UDim2.new(0.45, -4, 1, 0), TextSize = 14, Parent = actions }, "money", function()
		act("SellVehicle", function(result)
			return "Продано за " .. Format.money(result.payout)
		end)
	end)

	StateController.InventoryChanged:Connect(function()
		InventoryController.refresh()
	end)
end

function InventoryController.toggle()
	if modal.isOpen() then
		modal.close()
	else
		modal.open()
		InventoryController.refresh()
	end
end

function InventoryController.init()
	build()
	HUDController.addMenuButton(1, "ГАРАЖ", "Ваші автомобілі", InventoryController.toggle)
end

return InventoryController

-- Tuning garage: categories, parts with prices / level locks, live 3D preview of the selected part
-- before buying, power before -> after. The server validates and charges.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Format = require(Shared.Modules.Format)
local TuningConfig = require(Shared.Configs.TuningConfig)
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)
local VehicleBuilder = require(Shared.Modules.VehicleBuilder)
local Util = require(Shared.Modules.Util)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local C = require(UI.Components)
local create = C.create

local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)

local TuningController = {}

local modal
local viewport: ViewportFrame
local viewportCamera: Camera
local tabs: Frame
local optionsList: ScrollingFrame
local infoLabel: TextLabel
local powerLabel: TextLabel
local buyButton: TextButton

local vehicleId: string? = nil
local category = "Paint"
local selectedOption: string? = nil
local previewModel: Model? = nil
local rotateConnection: RBXScriptConnection? = nil
local angle = 0.7
local busy = false

local function needsPass(option): boolean
	local passes = StateController.state and StateController.state.passes
	return option.RequiresPass ~= nil and not (passes and passes[option.RequiresPass])
end

local function currentVehicle()
	return vehicleId and StateController.findVehicle(vehicleId)
end

local function previewRecord(vehicle)
	-- copy of the vehicle with the selected (not yet bought) part applied
	local record = Util.deepCopy(vehicle)
	record.mods = record.mods or {}
	if selectedOption then
		local option = TuningConfig.getOption(category, selectedOption)
		if option and option.Remove then
			record.mods[category] = nil
		elseif option then
			local mod = { key = option.Key, value = 0 }
			for k, v in option.Data or {} do
				mod[k] = v
			end
			record.mods[category] = mod
		end
	end
	return record
end

local function rebuildPreview()
	local vehicle = currentVehicle()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	if not vehicle then
		return
	end
	local model, dims = VehicleBuilder.build(previewRecord(vehicle))
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	previewModel = model
	local center = Vector3.new(0, dims.H * 0.38, 0)
	local distance = dims.L * 0.85 + 3
	if rotateConnection then
		rotateConnection:Disconnect()
	end
	rotateConnection = RunService.RenderStepped:Connect(function(dt)
		angle += dt * 0.35
		local dir = CFrame.Angles(0, angle, 0).LookVector
		viewportCamera.CFrame = CFrame.lookAt(center + dir * distance + Vector3.new(0, dims.H * 0.75 + 1.2, 0), center)
	end)
end

local function stop()
	if rotateConnection then
		rotateConnection:Disconnect()
		rotateConnection = nil
	end
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
end

local function refreshInfo()
	local vehicle = currentVehicle()
	if not vehicle then
		return
	end
	local model = VehicleDatabase.getModel(vehicle.modelKey)
	local state = StateController.state
	local level = state and state.level or 1
	local cash = state and state.cash or 0
	local option = selectedOption and TuningConfig.getOption(category, selectedOption)
	local installed = vehicle.mods and vehicle.mods[category]
	local cost = if option then TuningConfig.cost(option, model and model.BasePrice or 0) else 0

	local before = TuningConfig.effectivePower(vehicle)
	local after = TuningConfig.effectivePower(previewRecord(vehicle))
	powerLabel.Text = if after ~= before then ("Потужність: %d → %d к.с."):format(before, after) else ("Потужність: %d к.с."):format(before)
	powerLabel.TextColor3 = if after > before then Theme.Money elseif after < before then Theme.Danger else Theme.Text
	infoLabel.Text = ("%s %s · вартість %s"):format(vehicle.brand, vehicle.model, Format.money(vehicle.value))

	if not option then
		buyButton.Text = "ОБЕРІТЬ ДЕТАЛЬ"
		C.setEnabled(buyButton, false)
		return
	end
	local isInstalled = (option.Remove and installed == nil) or (installed and installed.key == option.Key)
	if isInstalled then
		buyButton.Text = "ВЖЕ ВСТАНОВЛЕНО"
		C.setEnabled(buyButton, false)
	elseif needsPass(option) then
		buyButton.Text = "ВІДКРИТИ ПРЕМІУМ-ТЮНІНГ (R$)"
		C.setEnabled(buyButton, not busy)
	elseif level < (option.Level or 1) then
		buyButton.Text = ("ПОТРІБЕН РІВЕНЬ %d"):format(option.Level)
		C.setEnabled(buyButton, false)
	elseif cash < cost then
		buyButton.Text = "НЕДОСТАТНЬО КОШТІВ · " .. Format.money(cost)
		C.setEnabled(buyButton, false)
	else
		buyButton.Text = if option.Remove then "ПОВЕРНУТИ ЗАВОДСЬКЕ" else "ВСТАНОВИТИ ЗА " .. Format.money(cost)
		C.setEnabled(buyButton, not busy)
	end
end

local function refreshOptions()
	for _, child in optionsList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local vehicle = currentVehicle()
	if not vehicle then
		return
	end
	local model = VehicleDatabase.getModel(vehicle.modelKey)
	local level = StateController.state and StateController.state.level or 1
	local installed = vehicle.mods and vehicle.mods[category]
	for i, option in TuningConfig.Options[category] do
		local isInstalled = (option.Remove and installed == nil) or (installed ~= nil and installed.key == option.Key)
		local premiumLocked = needsPass(option)
		local locked = premiumLocked or level < (option.Level or 1)
		local selected = option.Key == selectedOption
		local cost = TuningConfig.cost(option, model and model.BasePrice or 0)
		local row = create("TextButton", {
			LayoutOrder = i,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, -8, 0, 46),
			BackgroundColor3 = if selected then Theme.Panel3 else Theme.Panel2,
			Parent = optionsList,
		}, {
			C.corner(Theme.CornerSmall),
			C.stroke(if selected then Theme.Accent elseif isInstalled then Theme.Money else Theme.Stroke, if selected then 2 else 1),
			C.label({ Text = option.NameUA, Font = Theme.FontBold, TextSize = 15, Position = UDim2.fromOffset(if option.Swatch then 44 else 12, 4), Size = UDim2.new(0.62, -40, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false }),
			C.label({
				Text = if isInstalled then "встановлено" elseif premiumLocked then "преміум · потрібен пропуск" elseif locked then ("рівень %d"):format(option.Level) else (option.Tier or ""),
				TextSize = 12,
				TextColor3 = if isInstalled then Theme.Money elseif locked then Theme.Danger else Theme.Muted,
				Position = UDim2.fromOffset(if option.Swatch then 44 else 12, 25),
				Size = UDim2.new(0.62, -40, 0, 16),
			}),
			C.label({
				Text = if option.Remove then "—" else Format.money(cost),
				Font = Theme.FontBlack,
				TextSize = 15,
				TextColor3 = Theme.Money,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(0.6, 0, 0, 0),
				Size = UDim2.new(0.4, -12, 1, 0),
			}),
		})
		if option.Swatch then
			create("Frame", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = option.Swatch, Parent = row }, {
				C.corner(UDim.new(1, 0)),
				C.stroke(Color3.new(1, 1, 1), 1, 0.6),
			})
		end
		row.Activated:Connect(function()
			C.playClick()
			selectedOption = option.Key
			refreshOptions()
			rebuildPreview()
			refreshInfo()
		end)
	end
end

local function refreshTabs()
	for _, child in tabs:GetChildren() do
		if child:IsA("TextButton") then
			local active = child.Name == category
			child.TextColor3 = if active then Color3.fromRGB(8, 20, 30) else Theme.Text
			local gradient = child:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient.Color = if active then ColorSequence.new(Theme.Accent, Theme.AccentDark) else ColorSequence.new(Theme.Panel3, Theme.Panel2)
			end
		end
	end
end

local function build()
	modal = C.modal("TuningUI", "ТЮНІНГ", Vector2.new(1080, 600), 13)
	modal.onClose = stop
	local content = modal.content

	local left = create("Frame", {
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.new(0.5, -24, 1, -30),
		BackgroundColor3 = Theme.Panel2,
		Parent = content,
	}, { C.corner(Theme.CornerSmall) })
	viewportCamera = create("Camera", { FieldOfView = 38 })
	viewport = create("ViewportFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -96),
		BackgroundColor3 = Color3.fromRGB(16, 18, 24),
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, -0.4),
		CurrentCamera = viewportCamera,
		Parent = left,
	}, { C.corner(Theme.CornerSmall), C.gradient(Color3.fromRGB(64, 70, 90), Color3.fromRGB(18, 20, 28), 90) })
	viewportCamera.Parent = viewport
	infoLabel = C.label({ Text = "", TextSize = 14, TextColor3 = Theme.Muted, Position = UDim2.new(0, 14, 1, -82), Size = UDim2.new(1, -28, 0, 20), Parent = left })
	powerLabel = C.label({ Text = "", Font = Theme.FontBlack, TextSize = 20, Position = UDim2.new(0, 14, 1, -58), Size = UDim2.new(1, -28, 0, 26), Parent = left })
	C.label({ Text = "Превʼю показує деталь до покупки", TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.new(0, 14, 1, -28), Size = UDim2.new(1, -28, 0, 16), Parent = left })

	local right = create("Frame", {
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0.5, -18, 1, -30),
		BackgroundTransparency = 1,
		Parent = content,
	})
	tabs = create("Frame", { Size = UDim2.new(1, 0, 0, 112), BackgroundTransparency = 1, Parent = right }, {
		create("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, 32), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, cat in TuningConfig.Categories do
		local tab = C.button({ Name = cat.Key, Text = cat.NameUA, TextSize = 13, LayoutOrder = i, Parent = tabs }, "secondary", function()
			category = cat.Key
			selectedOption = nil
			refreshTabs()
			refreshOptions()
			rebuildPreview()
			refreshInfo()
		end)
		tab.Name = cat.Key
	end
	optionsList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 1, -184),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = right,
	}, { C.list(Enum.FillDirection.Vertical, 6) })
	buyButton = C.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 54),
		Text = "ОБЕРІТЬ ДЕТАЛЬ",
		TextSize = 17,
		Parent = right,
	}, "gold", function()
		if busy or not vehicleId or not selectedOption then
			return
		end
		local option = TuningConfig.getOption(category, selectedOption)
		if option and needsPass(option) then
			local ok, result = pcall(function()
				return Net.get("PromptProduct"):InvokeServer(option.RequiresPass)
			end)
			if not (ok and type(result) == "table" and result.ok) then
				HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
			end
			return
		end
		busy = true
		refreshInfo()
		local id, cat, key = vehicleId, category, selectedOption
		local ok, result = pcall(function()
			return Net.get("ApplyTuning"):InvokeServer(id, cat, key)
		end)
		busy = false
		if ok and type(result) == "table" and result.ok then
			HUDController.toast("Деталь встановлено!", "success")
		else
			HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
		end
		refreshInfo()
	end)

	StateController.InventoryChanged:Connect(function()
		if modal.isOpen() then
			if not currentVehicle() then
				modal.close()
				return
			end
			refreshOptions()
			refreshInfo()
		end
	end)
	StateController.StateChanged:Connect(function()
		if modal.isOpen() then
			refreshInfo()
		end
	end)
end

function TuningController.open(id: string)
	vehicleId = id
	category = "Paint"
	selectedOption = nil
	modal.open()
	refreshTabs()
	refreshOptions()
	rebuildPreview()
	refreshInfo()
end

function TuningController.init()
	build()
end

return TuningController

-- Plot decoration: catalogue with 3D previews, placement mode (ghost that follows the mouse /
-- finger, green = allowed, red = not allowed, R to rotate) and remove mode.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Format = require(Shared.Modules.Format)
local DecorConfig = require(Shared.Configs.DecorConfig)
local GameConfig = require(Shared.Configs.GameConfig)
local DecorBuilder = require(Shared.Modules.DecorBuilder)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local C = require(UI.Components)
local create = C.create

local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)

local DecorController = {}

local modal
local bar: Frame
local barLabel: TextLabel
local mode: string? = nil -- "place" | "remove"
local currentKey: string? = nil
local rotation = 0
local ghost: Model? = nil
local ghostHighlight: Highlight? = nil
local zoneParts = {} :: { BasePart }
local pointer: Vector2? = nil
local usingTouch = false
local localPos: Vector3? = nil
local valid = false
local hoverModel: Model? = nil
local hoverHighlight: Highlight? = nil
local busy = false

local function plotCFrame(): CFrame?
	local state = StateController.state
	local plots = workspace:FindFirstChild("PlayerPlots")
	local plot = state and state.plotIndex and plots and plots:FindFirstChild("Plot_" .. state.plotIndex)
	local base = plot and plot:FindFirstChild("Base")
	if base and base:IsA("BasePart") then
		return base.CFrame * CFrame.new(0, 0.3, 0)
	end
	return nil
end

local function decorFolder(): Instance?
	local state = StateController.state
	local plots = workspace:FindFirstChild("PlayerPlots")
	local plot = state and state.plotIndex and plots and plots:FindFirstChild("Plot_" .. state.plotIndex)
	return plot and plot:FindFirstChild("Decor")
end

local function pointerRay(): Ray?
	local camera = workspace.CurrentCamera
	if usingTouch then
		if not pointer then
			return nil
		end
		return camera:ScreenPointToRay(pointer.X, pointer.Y)
	end
	local m = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(m.X, m.Y)
end

local function overlapsExisting(key: string, x: number, z: number, cf: CFrame): boolean
	local folder = decorFolder()
	local radius = DecorConfig.ByKey[key].Radius
	if not folder then
		return false
	end
	for _, model in folder:GetChildren() do
		local otherKey = model:GetAttribute("DecorKey")
		local other = otherKey and DecorConfig.ByKey[otherKey]
		if other and model:IsA("Model") then
			local p = cf:PointToObjectSpace(model:GetPivot().Position)
			local min = (radius + other.Radius) * 0.8
			if (p.X - x) ^ 2 + (p.Z - z) ^ 2 < min * min then
				return true
			end
		end
	end
	return false
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	ghostHighlight = nil
end

local function showZones(show: boolean)
	for _, p in zoneParts do
		p:Destroy()
	end
	table.clear(zoneParts)
	local cf = plotCFrame()
	if not show or not cf then
		return
	end
	for _, zone in DecorConfig.Zones do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(80, 255, 140)
		part.Transparency = 0.8
		part.Size = Vector3.new(zone.x1 - zone.x0, 0.06, zone.z1 - zone.z0)
		part.CFrame = cf * CFrame.new((zone.x0 + zone.x1) / 2, 0.36, (zone.z0 + zone.z1) / 2)
		part.Parent = workspace.CurrentCamera
		table.insert(zoneParts, part)
	end
end

local function setHover(model: Model?)
	if hoverModel == model then
		return
	end
	if hoverHighlight then
		hoverHighlight:Destroy()
		hoverHighlight = nil
	end
	hoverModel = model
	if model then
		local h = Instance.new("Highlight")
		h.FillColor = Theme.Danger
		h.FillTransparency = 0.5
		h.OutlineColor = Theme.Danger
		h.Parent = model
		hoverHighlight = h
	end
end

local function exitMode()
	mode = nil
	currentKey = nil
	clearGhost()
	setHover(nil)
	showZones(false)
	bar.Visible = false
end

local function updateBar()
	if mode == "place" and currentKey then
		local item = DecorConfig.ByKey[currentKey]
		local price = if GameConfig.freeUpgrades() then "безкоштовно (тест)" else Format.money(item.Price)
		barLabel.Text = ("%s · %s · R — повернути · Q — вийти"):format(item.NameUA, price)
	elseif mode == "remove" then
		barLabel.Text = ("Режим видалення: натисніть на предмет (повернення %d%% ціни)"):format(math.floor(DecorConfig.RefundRate * 100))
	end
end

local function enterPlace(key: string)
	exitMode()
	mode = "place"
	currentKey = key
	rotation = 0
	local model = DecorBuilder.build(key)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			if d.Transparency < 1 then
				d.Transparency = math.max(d.Transparency, 0.35)
			end
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	local h = Instance.new("Highlight")
	h.FillTransparency = 0.7
	h.OutlineTransparency = 0
	h.Parent = model
	model.Parent = workspace.CurrentCamera
	ghost = model
	ghostHighlight = h
	showZones(true)
	bar.Visible = true
	updateBar()
end

local function enterRemove()
	exitMode()
	mode = "remove"
	bar.Visible = true
	updateBar()
end

local function tryPlace()
	if busy or mode ~= "place" or not currentKey or not localPos then
		return
	end
	if not valid then
		HUDController.toast("Тут не можна ставити — оберіть зелену зону", "error")
		return
	end
	busy = true
	local key, pos, rot = currentKey, localPos, rotation
	local ok, result = pcall(function()
		return Net.get("PlaceDecor"):InvokeServer(key, pos.X, pos.Z, rot)
	end)
	busy = false
	if ok and type(result) == "table" and result.ok then
		C.playClick()
	else
		HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
	end
end

local function tryRemove()
	if busy or not hoverModel then
		return
	end
	local id = hoverModel:GetAttribute("DecorId")
	if not id then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return Net.get("RemoveDecor"):InvokeServer(id)
	end)
	busy = false
	if ok and type(result) == "table" and result.ok then
		HUDController.toast(if result.refund > 0 then "Прибрано, повернено " .. Format.money(result.refund) else "Прибрано", "success")
		setHover(nil)
	else
		HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
	end
end

local function step()
	if not mode then
		return
	end
	local cf = plotCFrame()
	local ray = pointerRay()
	if not cf or not ray then
		return
	end
	if mode == "place" and ghost and currentKey then
		if math.abs(ray.Direction.Y) < 1e-4 then
			return
		end
		local floorY = cf.Position.Y
		local t = (floorY - ray.Origin.Y) / ray.Direction.Y
		if t < 0 then
			return
		end
		local world = ray.Origin + ray.Direction * t
		local lp = cf:PointToObjectSpace(world)
		local x = math.floor(lp.X * 2 + 0.5) / 2
		local z = math.floor(lp.Z * 2 + 0.5) / 2
		localPos = Vector3.new(x, 0, z)
		valid = DecorConfig.isValid(currentKey, x, z) and not overlapsExisting(currentKey, x, z, cf)
		ghost:PivotTo(cf * CFrame.new(x, 0, z) * CFrame.Angles(0, rotation * math.pi / 2, 0))
		if ghostHighlight then
			local color = if valid then Color3.fromRGB(80, 255, 140) else Theme.Danger
			ghostHighlight.FillColor = color
			ghostHighlight.OutlineColor = color
		end
	elseif mode == "remove" then
		local folder = decorFolder()
		if not folder then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { folder }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		local model = nil
		if hit then
			local node: Instance? = hit.Instance
			while node and node.Parent ~= folder do
				node = node.Parent
			end
			model = node
		end
		setHover(model :: Model?)
	end
end

local function buildCatalog()
	modal = C.modal("DecorUI", "ДЕКОР ДІЛЯНКИ", Vector2.new(980, 580), 12)
	local content = modal.content
	C.label({
		Text = "Оберіть предмет і поставте його на зеленій зоні ділянки (біля паркану, на газонах, за ярдом). Предмети зберігаються.",
		TextColor3 = Theme.Muted,
		TextSize = 13,
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -240, 0, 36),
		Parent = content,
	})
	C.button({ Text = "ПРИБРАТИ ДЕКОР", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 8), Size = UDim2.fromOffset(200, 40), TextSize = 14, Parent = content }, "danger", function()
		modal.close()
		enterRemove()
	end)
	local grid = create("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 1, -70),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(176, 196), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, item in DecorConfig.Items do
		local card = create("TextButton", {
			LayoutOrder = i,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Panel2,
			Parent = grid,
		}, { C.corner(Theme.CornerSmall), C.stroke(Theme.Stroke, 1) })
		local camera = create("Camera", { FieldOfView = 40 })
		local viewport = create("ViewportFrame", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 120),
			BackgroundColor3 = Color3.fromRGB(18, 20, 26),
			Ambient = Color3.fromRGB(160, 160, 170),
			LightDirection = Vector3.new(-0.5, -1, -0.4),
			CurrentCamera = camera,
			Parent = card,
		}, { C.corner(Theme.CornerSmall) })
		camera.Parent = viewport
		local preview = DecorBuilder.build(item.Key)
		preview:PivotTo(CFrame.new())
		preview.Parent = viewport
		local _, size = preview:GetBoundingBox()
		local extent = math.max(size.X, size.Y, size.Z)
		local center = Vector3.new(0, size.Y / 2, 0)
		camera.CFrame = CFrame.lookAt(center + Vector3.new(extent * 0.9, extent * 0.6, -extent * 1.2), center)
		C.label({ Text = item.NameUA, Font = Theme.FontBold, TextSize = 14, Position = UDim2.fromOffset(10, 130), Size = UDim2.new(1, -20, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = card })
		local priceLabel = C.label({ Text = Format.money(item.Price), Font = Theme.FontBlack, TextSize = 15, TextColor3 = Theme.Money, Position = UDim2.fromOffset(10, 150), Size = UDim2.new(1, -20, 0, 18), Parent = card })
		local levelLabel = C.label({ Text = "", TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(10, 170), Size = UDim2.new(1, -20, 0, 16), Parent = card })
		local function refresh()
			local level = StateController.state and StateController.state.level or 1
			local locked = level < item.Level and not GameConfig.freeUpgrades()
			levelLabel.Text = if locked then ("потрібен рівень %d"):format(item.Level) else "натисніть, щоб поставити"
			levelLabel.TextColor3 = if locked then Theme.Danger else Theme.Muted
			priceLabel.Text = if GameConfig.freeUpgrades() then "$0 (тест)" else Format.money(item.Price)
		end
		refresh()
		StateController.StateChanged:Connect(refresh)
		card.Activated:Connect(function()
			C.playClick()
			local level = StateController.state and StateController.state.level or 1
			if level < item.Level and not GameConfig.freeUpgrades() then
				HUDController.toast(("Цей предмет відкривається на рівні %d"):format(item.Level), "error")
				return
			end
			modal.close()
			enterPlace(item.Key)
		end)
	end
end

local function buildBar()
	local gui = C.screen("DecorBarUI", 9)
	bar = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(760, 64),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		Parent = gui,
	}, { C.corner(), C.stroke(Theme.Accent, 1.5) })
	C.scaled(bar)
	barLabel = C.label({ Text = "", Font = Theme.FontBold, TextSize = 14, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -420, 1, 0), Parent = bar })
	local buttons = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(400, 46), BackgroundTransparency = 1, Parent = bar }, {
		C.list(Enum.FillDirection.Horizontal, 8),
	})
	C.button({ Text = "ПОВЕРНУТИ", LayoutOrder = 1, Size = UDim2.fromOffset(122, 46), TextSize = 13, Parent = buttons }, "secondary", function()
		rotation = (rotation + 1) % 4
	end)
	C.button({ Text = "ПОСТАВИТИ", LayoutOrder = 2, Size = UDim2.fromOffset(130, 46), TextSize = 13, Parent = buttons }, "money", function()
		if mode == "place" then
			tryPlace()
		else
			tryRemove()
		end
	end)
	C.button({ Text = "ГОТОВО", LayoutOrder = 3, Size = UDim2.fromOffset(122, 46), TextSize = 13, Parent = buttons }, "primary", function()
		exitMode()
	end)
end

function DecorController.init()
	buildCatalog()
	buildBar()
	HUDController.addMenuButton(3, "ДЕКОР", "Прикрасьте ділянку", function()
		if mode then
			exitMode()
		end
		if modal.isOpen() then
			modal.close()
		else
			modal.open()
		end
	end)
	RunService.RenderStepped:Connect(step)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not mode then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			usingTouch = true
			if not processed then
				pointer = Vector2.new(input.Position.X, input.Position.Y)
			end
			return
		end
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			usingTouch = false
			if mode == "place" then
				tryPlace()
			else
				tryRemove()
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			rotation = (rotation + 1) % 4
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
			exitMode()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			usingTouch = false
		end
	end)
end

return DecorController

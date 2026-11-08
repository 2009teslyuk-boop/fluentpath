-- UI building helpers: declarative instance creation, buttons with hover / press animation,
-- modal windows and a responsive UIScale for PC / tablet / phone.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Theme = require(script.Parent.Theme)

local Components = {}

local FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local clickSound: Sound? = nil

function Components.playClick()
	if not clickSound then
		local s = Instance.new("Sound")
		s.SoundId = "rbxasset://sounds/button.wav"
		s.Volume = 0.4
		s.Parent = SoundService
		clickSound = s
	end
	SoundService:PlayLocalSound(clickSound :: Sound)
end

-- create("Frame", { Size = ..., Parent = ... }, { child1, child2 })
function Components.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local create = Components.create

function Components.corner(radius: UDim?): UICorner
	return create("UICorner", { CornerRadius = radius or Theme.Corner })
end

function Components.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Components.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return create("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Components.gradient(c1: Color3, c2: Color3, rotation: number?): UIGradient
	return create("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 90 })
end

function Components.list(direction: Enum.FillDirection?, spacing: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, spacing or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function Components.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.FontMedium,
		TextColor3 = Theme.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return create("TextLabel", defaults)
end

-- style: "primary" | "secondary" | "danger" | "gold"
function Components.button(props: { [string]: any }, style: string?, onClick: (() -> ())?): TextButton
	local colors = {
		primary = { Theme.Accent, Theme.AccentDark, Color3.fromRGB(8, 20, 30) },
		secondary = { Theme.Panel3, Theme.Panel2, Theme.Text },
		danger = { Color3.fromRGB(255, 96, 106), Color3.fromRGB(190, 40, 60), Color3.new(1, 1, 1) },
		gold = { Color3.fromRGB(255, 214, 96), Color3.fromRGB(230, 140, 30), Color3.fromRGB(40, 24, 4) },
		money = { Color3.fromRGB(120, 240, 150), Color3.fromRGB(40, 170, 90), Color3.fromRGB(6, 30, 14) },
	}
	local c = colors[style or "primary"] or colors.primary
	local defaults = {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.FontBold,
		TextSize = 17,
		TextColor3 = c[3],
		Size = UDim2.fromOffset(160, 46),
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = create("TextButton", defaults, {
		Components.corner(Theme.CornerSmall),
		Components.gradient(c[1], c[2], 90),
		create("UIScale", { Name = "PressScale" }),
	})
	local scale = button:FindFirstChild("PressScale") :: UIScale
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 0.95 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	end)
	if onClick then
		button.Activated:Connect(function()
			if button.Active then
				Components.playClick()
				onClick()
			end
		end)
	end
	return button
end

function Components.setEnabled(button: GuiButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	button.BackgroundTransparency = if enabled then 0 else 0.55
	if button:IsA("TextButton") then
		button.TextTransparency = if enabled then 0 else 0.4
	end
end

-- Responsive scale: layouts are designed for a 1280x760 screen. A UIScale is attached to each
-- anchored container (never to the ScreenGui itself), so containers scale around their anchor
-- point and stay glued to their screen edge on PC, tablet and phone.
local currentScale = 1
local scaleTargets: { UIScale } = {}
local scaleListeners: { (number) -> () } = {}

local function computeScale(): number
	local size = workspace.CurrentCamera.ViewportSize
	return math.clamp(math.min(size.X / 1280, size.Y / 760), 0.62, 1.25)
end

local function refreshScale()
	currentScale = computeScale()
	for i = #scaleTargets, 1, -1 do
		local s = scaleTargets[i]
		if s.Parent then
			s.Scale = currentScale
		else
			table.remove(scaleTargets, i)
		end
	end
	for _, fn in scaleListeners do
		task.spawn(fn, currentScale)
	end
end

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
currentScale = computeScale()

function Components.getScale(): number
	return currentScale
end

function Components.onScaleChanged(fn: (number) -> ())
	table.insert(scaleListeners, fn)
end

function Components.scaled(object: GuiObject): UIScale
	local uiScale = create("UIScale", { Name = "Responsive", Scale = currentScale, Parent = object })
	table.insert(scaleTargets, uiScale)
	return uiScale
end

function Components.screen(name: string, displayOrder: number?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local gui = create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = playerGui,
	})
	return gui
end

-- Modal window: dimmed backdrop + centred panel. Returns { gui, window, content, open, close, isOpen }
function Components.modal(name: string, title: string, size: Vector2, displayOrder: number?)
	local gui = Components.screen(name, displayOrder or 10)
	gui.Enabled = false
	local backdrop = create("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local holder = create("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local window = create("CanvasGroup", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Theme.Panel,
		Parent = holder,
	}, {
		Components.corner(),
		Components.stroke(Theme.Stroke, 1.5),
		create("UIScale", { Name = "OpenScale" }),
	})
	local header = create("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.Panel2,
		Size = UDim2.new(1, 0, 0, 58),
		Parent = window,
	})
	local titleLabel = Components.label({
		Name = "Title",
		Text = title,
		Font = Theme.FontBlack,
		TextSize = 22,
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -90, 1, 0),
		Parent = header,
	})
	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		Parent = window,
	})

	local api = {}
	api.gui = gui
	api.window = window
	api.content = content
	api.title = titleLabel
	api.onClose = nil :: (() -> ())?

	local closeButton = Components.button({
		Text = "X",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -50, 0, 9),
		TextSize = 18,
		Parent = header,
	}, "secondary", function()
		api.close()
	end)
	closeButton.Name = "Close"

	local openScale = window:FindFirstChild("OpenScale") :: UIScale
	local closeToken = nil
	function api.open()
		closeToken = nil
		gui.Enabled = true
		openScale.Scale = 0.9 * currentScale
		window.GroupTransparency = 1
		TweenService:Create(openScale, POP, { Scale = currentScale }):Play()
		TweenService:Create(window, FAST, { GroupTransparency = 0 }):Play()
	end
	function api.close()
		if not gui.Enabled then
			return
		end
		local token = {}
		closeToken = token
		local tween = TweenService:Create(window, FAST, { GroupTransparency = 1 })
		TweenService:Create(openScale, FAST, { Scale = 0.94 * currentScale }):Play()
		tween:Play()
		tween.Completed:Once(function()
			if closeToken == token then
				gui.Enabled = false
			end
		end)
		if api.onClose then
			api.onClose()
		end
	end
	function api.isOpen(): boolean
		return gui.Enabled
	end
	backdrop.Activated:Connect(function()
		api.close()
	end)
	Components.onScaleChanged(function(scale)
		if gui.Enabled then
			openScale.Scale = scale
		end
	end)
	return api
end

function Components.rarityColor(rarityConfig, key: string): Color3
	return rarityConfig.get(key).Color
end

return Components

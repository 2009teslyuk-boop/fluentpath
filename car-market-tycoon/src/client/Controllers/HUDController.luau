-- HUD: cash / income, level & XP, side menu, toasts, server-wide announcements, loading screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Format = require(Shared.Modules.Format)
local RarityConfig = require(Shared.Configs.RarityConfig)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local C = require(UI.Components)
local create = C.create

local StateController = require(script.Parent.StateController)

local HUDController = {}

local gui: ScreenGui
local menu: Frame
local toastHolder: Frame
local bannerHolder: Frame

local function buildTopLeft()
	local topLeft = create("Frame", {
		Name = "TopLeft",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(290, 124),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	C.scaled(topLeft)
	local cashPill = create("Frame", {
		Name = "Cash",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(290, 66),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.08,
		Parent = topLeft,
	}, { C.corner(), C.stroke(Theme.Stroke, 1.2) })
	create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = cashPill,
	}, {
		C.corner(UDim.new(1, 0)),
		C.gradient(Theme.Gold, Color3.fromRGB(230, 140, 30), 120),
		C.label({ Text = "$", Font = Theme.FontBlack, TextSize = 26, TextColor3 = Color3.fromRGB(50, 30, 0), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center }),
	})
	local amount = C.label({
		Name = "Amount",
		Text = "$0",
		Font = Theme.FontBlack,
		TextSize = 26,
		TextColor3 = Theme.Money,
		Position = UDim2.fromOffset(66, 8),
		Size = UDim2.new(1, -76, 0, 30),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = cashPill,
	})
	local income = C.label({
		Name = "Income",
		Text = "+$0 / хв",
		Font = Theme.FontMedium,
		TextSize = 14,
		TextColor3 = Theme.Muted,
		Position = UDim2.fromOffset(66, 38),
		Size = UDim2.new(1, -76, 0, 18),
		Parent = cashPill,
	})

	local levelPill = create("Frame", {
		Name = "Level",
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.fromOffset(290, 50),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.08,
		Parent = topLeft,
	}, { C.corner(), C.stroke(Theme.Stroke, 1.2) })
	local levelText = C.label({
		Text = "РІВЕНЬ 1",
		Font = Theme.FontBold,
		TextSize = 15,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(0.5, 0, 0, 20),
		Parent = levelPill,
	})
	local garageText = C.label({
		Text = "Гараж 0/30",
		Font = Theme.FontMedium,
		TextSize = 13,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.new(0.5, -14, 0, 20),
		Parent = levelPill,
	})
	local barBack = create("Frame", {
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 0, 8),
		BackgroundColor3 = Theme.Panel3,
		Parent = levelPill,
	}, { C.corner(UDim.new(1, 0)) })
	local barFill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = barBack,
	}, { C.corner(UDim.new(1, 0)), C.gradient(Theme.Accent, Color3.fromRGB(140, 110, 255), 0) })

	-- animated counter
	local shown = create("NumberValue", { Value = 0 })
	shown.Changed:Connect(function(v)
		amount.Text = Format.money(v)
	end)
	local first = true
	StateController.StateChanged:Connect(function(state)
		if first then
			shown.Value = state.cash
			first = false
		else
			TweenService:Create(shown, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = state.cash }):Play()
		end
		local extra = ""
		if state.incomeMultiplier and state.incomeMultiplier > 1.001 then
			extra ..= ("  ·  x%.2g"):format(state.incomeMultiplier)
		end
		if state.cashBoostLeft and state.cashBoostLeft > 0 then
			extra ..= ("  ·  буст %d хв"):format(math.ceil(state.cashBoostLeft / 60))
		end
		if state.luckBoostLeft and state.luckBoostLeft > 0 then
			extra ..= ("  ·  удача %d хв"):format(math.ceil(state.luckBoostLeft / 60))
		end
		income.Text = ("+%s / хв%s"):format(Format.money(state.incomePerMinute), extra)
		levelText.Text = ("РІВЕНЬ %d"):format(state.level)
		garageText.Text = ("Гараж %d/%d"):format(state.garageCount, state.garageSlots)
		local span = math.max(1, state.xpNextLevel - state.xpLevelStart)
		local t = math.clamp((state.xp - state.xpLevelStart) / span, 0, 1)
		TweenService:Create(barFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(t, 1) }):Play()
	end)
end

function HUDController.addMenuButton(order: number, title: string, subtitle: string, onClick: () -> ())
	local button = C.button({
		Name = title,
		Text = "",
		LayoutOrder = order,
		Size = UDim2.fromOffset(150, 54),
		Parent = menu,
	}, "secondary", onClick)
	C.stroke(Theme.Stroke, 1.2).Parent = button
	C.label({
		Text = title,
		Font = Theme.FontBlack,
		TextSize = 17,
		Position = UDim2.fromOffset(14, 9),
		Size = UDim2.new(1, -20, 0, 22),
		Parent = button,
	})
	C.label({
		Text = subtitle,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Muted,
		Position = UDim2.fromOffset(14, 31),
		Size = UDim2.new(1, -20, 0, 16),
		Parent = button,
	})
	return button
end

-- kind: info | success | error | level
function HUDController.toast(text: string, kind: string?)
	local color = ({
		success = Theme.Money,
		error = Theme.Danger,
		level = Theme.Gold,
	})[kind or "info"] or Theme.Accent
	local toast = create("CanvasGroup", {
		Size = UDim2.fromOffset(440, 46),
		BackgroundColor3 = Theme.Panel,
		GroupTransparency = 1,
		Parent = toastHolder,
	}, {
		C.corner(Theme.CornerSmall),
		C.stroke(color, 1.5),
		create("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0 }),
		C.label({ Text = text, TextSize = 15, Font = Theme.FontMedium, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -28, 1, 0) }),
	})
	TweenService:Create(toast, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
	task.delay(3.2, function()
		local t = TweenService:Create(toast, TweenInfo.new(0.3), { GroupTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		toast:Destroy()
	end)
end

local function announce(info)
	local rarity = RarityConfig.get(info.rarity)
	local isMine = info.ownerUserId == Players.LocalPlayer.UserId
	local banner = create("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(620, 74),
		BackgroundColor3 = Color3.new(1, 1, 1),
		GroupTransparency = 1,
		Parent = bannerHolder,
	}, {
		C.corner(),
		C.gradient(rarity.Color2:Lerp(Color3.new(0, 0, 0), 0.35), Theme.Panel, 0),
		C.stroke(rarity.Color, 2.5),
		C.label({
			Text = string.upper(rarity.NameUA) .. "!",
			Font = Theme.FontBlack,
			TextSize = 22,
			TextColor3 = rarity.Color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 28),
		}),
		C.label({
			Text = (if isMine then "Ви відкрили " else info.ownerName .. " відкриває ") .. info.name .. " · " .. Format.money(info.value),
			Font = Theme.FontMedium,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(10, 38),
			Size = UDim2.new(1, -20, 0, 26),
		}),
	})
	local scale = create("UIScale", { Scale = 0.7, Parent = banner })
	TweenService:Create(banner, TweenInfo.new(0.3), { GroupTransparency = 0 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if info.rarity == "Exclusive" then
		-- rainbow sweep across the stroke for the rarest cars
		local stroke = banner:FindFirstChildOfClass("UIStroke") :: UIStroke
		task.spawn(function()
			local started = os.clock()
			while banner.Parent and os.clock() - started < 6 do
				stroke.Color = Color3.fromHSV((os.clock() * 0.6) % 1, 0.7, 1)
				task.wait()
			end
		end)
	end
	task.delay(6, function()
		local t = TweenService:Create(banner, TweenInfo.new(0.4), { GroupTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		banner:Destroy()
	end)
end

local function buildLoading()
	local overlay = create("Frame", {
		Name = "Loading",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		ZIndex = 50,
		Parent = gui,
	}, {
		C.label({
			Text = "CAR MARKET TYCOON",
			Font = Theme.FontBlack,
			TextSize = 44,
			TextColor3 = Theme.Accent,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(700, 60),
			ZIndex = 51,
		}),
		C.label({
			Text = "Завантаження вашого автосалону…",
			TextSize = 18,
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.53),
			Size = UDim2.fromOffset(700, 30),
			ZIndex = 51,
		}),
	})
	local function hide()
		local t = TweenService:Create(overlay, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
		for _, child in overlay:GetChildren() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			end
		end
		t:Play()
		t.Completed:Wait()
		overlay:Destroy()
	end
	if StateController.isReady then
		task.spawn(hide)
	else
		StateController.Ready:Once(hide)
	end
end

function HUDController.init()
	gui = C.screen("MainUI", 1)
	buildTopLeft()

	menu = create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(150, 480),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { C.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Right) })
	C.scaled(menu)

	toastHolder = create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(440, 220),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	C.scaled(toastHolder)

	bannerHolder = create("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(620, 240),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	C.scaled(bannerHolder)

	buildLoading()

	Net.get("Notify").OnClientEvent:Connect(function(message)
		if type(message) == "table" and type(message.text) == "string" then
			HUDController.toast(message.text, message.kind)
		end
	end)
	Net.get("Announce").OnClientEvent:Connect(announce)
end

return HUDController

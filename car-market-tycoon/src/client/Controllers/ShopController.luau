-- Mega Market UI: wheel of fortune (free daily spin + 20 R$ spins, odds shown before spinning,
-- roulette animation) and limited Robux cars (one purchase per player). Also spins the
-- decorative wheels in the world locally.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Format = require(Shared.Modules.Format)
local SpinConfig = require(Shared.Configs.SpinConfig)
local MonetizationConfig = require(Shared.Configs.MonetizationConfig)
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)
local VehicleBuilder = require(Shared.Modules.VehicleBuilder)
local Pricing = require(Shared.Modules.Pricing)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local C = require(UI.Components)
local create = C.create

local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)

local player = Players.LocalPlayer
local ShopController = {}

local modal
local pages = {} :: { [string]: Frame }
local tabButtons = {} :: { [string]: TextButton }
local strip: Frame
local stripHolder: Frame
local resultLabel: TextLabel
local freeButton: TextButton
local paidButton: TextButton
local limitedCards = {} :: { [string]: { button: TextButton, status: TextLabel } }
local spinning = false
local refreshProducts: () -> () -- defined below, used by refreshButtons

local TILE_W, TILE_GAP = 132, 8
local STRIP_TILES = 46
local WIN_INDEX = 38

local function prizeTile(prize, order: number)
	return create("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(TILE_W, 120),
		BackgroundColor3 = Theme.Panel2,
	}, {
		C.corner(Theme.CornerSmall),
		C.stroke(prize.Color, 2),
		create("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = prize.Color, BorderSizePixel = 0 }),
		C.label({
			Text = prize.NameUA,
			Font = Theme.FontBlack,
			TextSize = 16,
			TextColor3 = prize.Color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(6, 26),
			Size = UDim2.new(1, -12, 0, 60),
		}),
		C.label({
			Text = Format.percent(prize.Chance / 100),
			TextSize = 12,
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 1, -24),
			Size = UDim2.new(1, 0, 0, 16),
		}),
	})
end

local function randomPrize(rng: Random)
	-- tiles on the strip are drawn from the real odds, so rare tiles are rare on the strip too
	local total = 0
	for _, p in SpinConfig.Prizes do
		total += p.Chance
	end
	local roll = rng:NextNumber() * total
	for _, p in SpinConfig.Prizes do
		roll -= p.Chance
		if roll <= 0 then
			return p
		end
	end
	return SpinConfig.Prizes[1]
end

local function animateSpin(result)
	for _, child in strip:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local rng = Random.new()
	local winner = SpinConfig.get(result.key) or SpinConfig.Prizes[1]
	for i = 1, STRIP_TILES do
		local prize = if i == WIN_INDEX then winner else randomPrize(rng)
		-- tease: show a rare tile right next to the winner
		if i == WIN_INDEX + 1 and winner.Kind ~= "limited" then
			prize = SpinConfig.Prizes[#SpinConfig.Prizes - rng:NextInteger(0, 3)]
		end
		prizeTile(prize, i).Parent = strip
	end
	local holderWidth = stripHolder.AbsoluteSize.X / math.max(0.01, C.getScale())
	local step = TILE_W + TILE_GAP
	local jitter = rng:NextNumber(-TILE_W * 0.35, TILE_W * 0.35)
	local target = -((WIN_INDEX - 1) * step + TILE_W / 2 - holderWidth / 2 + jitter)
	strip.Position = UDim2.fromOffset(0, 0)
	local tween = TweenService:Create(strip, TweenInfo.new(5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(target, 0),
	})
	tween:Play()
	tween.Completed:Wait()
	resultLabel.Text = "Виграш: " .. tostring(result.name)
	resultLabel.TextColor3 = winner.Color
	HUDController.toast("Колесо фортуни: " .. tostring(result.name), "success")
end

local function refreshButtons()
	local state = StateController.state
	if not state or not modal then
		return
	end
	local now = state.serverTime and (state.serverTime + (os.time() - (ShopController.stateReceivedAt or os.time()))) or os.time()
	local remaining = (state.freeSpinReadyAt or 0) - now
	if spinning then
		freeButton.Text = "КРУТИТЬСЯ…"
		C.setEnabled(freeButton, false)
	elseif remaining > 0 then
		freeButton.Text = ("БЕЗКОШТОВНО ЧЕРЕЗ %02d:%02d:%02d"):format(remaining // 3600, (remaining % 3600) // 60, remaining % 60)
		C.setEnabled(freeButton, false)
	else
		freeButton.Text = "КРУТИТИ БЕЗКОШТОВНО"
		C.setEnabled(freeButton, true)
	end
	local product = MonetizationConfig.Products.SpinPaid
	if state.paidSpinAllowed == false then
		paidButton.Text = "НЕДОСТУПНО У ВАШОМУ РЕГІОНІ"
		C.setEnabled(paidButton, false)
	else
		paidButton.Text = ("КРУТИТИ ЗА R$ %d"):format(product.PriceRobux)
		C.setEnabled(paidButton, not spinning)
	end
	refreshProducts()
	for key, card in limitedCards do
		local owned = state.limitedOwned and state.limitedOwned[key]
		card.button.Text = if owned then "ВЖЕ ВАШЕ" else ("КУПИТИ · R$ %d"):format(MonetizationConfig.Products[key].PriceRobux)
		C.setEnabled(card.button, not owned)
		card.status.Text = if owned then "У вашому гаражі" else "Одна покупка на гравця · у колесі шанс 0.00001%"
	end
end

local productButtons = {} :: { [string]: { button: TextButton, sub: TextLabel?, baseSub: string } }

local function formatLeft(seconds: number): string
	if seconds >= 3600 then
		return ("%d год %02d хв"):format(seconds // 3600, (seconds % 3600) // 60)
	end
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

function refreshProducts()
	local state = StateController.state
	if not state then
		return
	end
	local passes = state.passes or {}
	for key, refs in productButtons do
		local pass = MonetizationConfig.GamePasses[key]
		local product = MonetizationConfig.Products[key]
		local enabled, text = true, ("R$ %d"):format(if pass then pass.PriceRobux else product.PriceRobux)
		if pass and passes[key] then
			enabled, text = false, "ВЖЕ ВАШЕ"
		elseif (key == "ShowroomLevel" and not state.nextDisplayCapacity) or (key == "GarageSlots" and product and state.garageSlots >= product.Cap) then
			enabled, text = false, "МАКСИМУМ"
		end
		refs.button.Text = text
		C.setEnabled(refs.button, enabled)
		if refs.sub and product and product.Kind == "boost" then
			local left = if product.Boost == "cash" then state.cashBoostLeft else state.luckBoostLeft
			local elapsed = os.time() - (ShopController.stateReceivedAt or os.time())
			left = math.max(0, (left or 0) - elapsed)
			refs.sub.Text = if left > 0 then refs.baseSub .. " · активно ще " .. formatLeft(left) else refs.baseSub
		elseif refs.sub and key == "ShowroomLevel" then
			refs.sub.Text = if state.nextDisplayCapacity then ("Зараз %d → %d місць"):format(state.displayCapacity, state.nextDisplayCapacity) else "Шоурум максимальний"
		elseif refs.sub and key == "GarageSlots" then
			refs.sub.Text = ("Зараз %d місць (максимум %d)"):format(state.garageSlots, product.Cap)
		end
	end
end

local function prompt(productKey: string)
	local ok, result = pcall(function()
		return Net.get("PromptProduct"):InvokeServer(productKey)
	end)
	if not (ok and type(result) == "table" and result.ok) then
		HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
	end
end

local function showTab(name: string)
	for key, page in pages do
		page.Visible = key == name
	end
	for key, button in tabButtons do
		local gradient = button:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = if key == name then ColorSequence.new(Theme.Gold, Color3.fromRGB(230, 140, 30)) else ColorSequence.new(Theme.Panel3, Theme.Panel2)
		end
		button.TextColor3 = if key == name then Color3.fromRGB(40, 24, 4) else Theme.Text
	end
end

local function buildWheelPage(page: Frame)
	stripHolder = create("Frame", {
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(0.66, -24, 0, 150),
		BackgroundColor3 = Theme.Background,
		ClipsDescendants = true,
		Parent = page,
	}, { C.corner(Theme.CornerSmall), C.stroke(Theme.Gold, 1.5, 0.3) })
	strip = create("Frame", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, STRIP_TILES * (TILE_W + TILE_GAP), 1, 0),
		BackgroundTransparency = 1,
		Parent = stripHolder,
	}, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, TILE_GAP), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingLeft = UDim.new(0, 0) }),
	})
	for i = 1, 8 do
		prizeTile(SpinConfig.Prizes[i], i).Parent = strip
	end
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 60, 70),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = stripHolder,
	})
	resultLabel = C.label({
		Text = "Один безкоштовний оберт щодня. Шанси кожного призу — праворуч.",
		Font = Theme.FontBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(18, 172),
		Size = UDim2.new(0.66, -24, 0, 40),
		Parent = page,
	})
	freeButton = C.button({ Text = "", Position = UDim2.fromOffset(18, 226), Size = UDim2.new(0.66, -24, 0, 56), TextSize = 18, Parent = page }, "money", function()
		if spinning then
			return
		end
		spinning = true
		refreshButtons()
		local ok, result = pcall(function()
			return Net.get("SpinFree"):InvokeServer()
		end)
		if ok and type(result) == "table" and result.ok then
			animateSpin(result.result)
		else
			HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
		end
		spinning = false
		refreshButtons()
	end)
	paidButton = C.button({ Text = "", Position = UDim2.fromOffset(18, 292), Size = UDim2.new(0.66, -24, 0, 56), TextSize = 18, Parent = page }, "gold", function()
		if not spinning then
			prompt("SpinPaid")
		end
	end)
	C.label({
		Text = "Платна прокрутка — це випадковий приз. Перед покупкою перевірте шанси. Лімітовані авто можна виграти з шансом 0.00001% або купити напряму у вкладці «Лімітовані авто».",
		TextSize = 12,
		TextColor3 = Theme.Muted,
		Position = UDim2.fromOffset(18, 360),
		Size = UDim2.new(0.66, -24, 0, 48),
		Parent = page,
	})

	local odds = create("ScrollingFrame", {
		Position = UDim2.new(0.66, 0, 0, 10),
		Size = UDim2.new(0.34, -18, 1, -24),
		BackgroundColor3 = Theme.Panel2,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = page,
	}, { C.corner(Theme.CornerSmall), C.padding(10), C.list(Enum.FillDirection.Vertical, 4) })
	C.label({ LayoutOrder = 0, Text = "ШАНСИ ПРИЗІВ", Font = Theme.FontBlack, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), Parent = odds })
	for i, prize in SpinConfig.Prizes do
		local row = create("Frame", { LayoutOrder = i, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = odds })
		C.label({ Text = prize.NameUA, TextSize = 13, TextColor3 = prize.Color, Size = UDim2.new(0.68, 0, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = row })
		C.label({ Text = Format.percent(prize.Chance / 100), TextSize = 13, Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.66, 0), Size = UDim2.new(0.34, 0, 1, 0), Parent = row })
	end
end

local function buildLimitedPage(page: Frame)
	local row = create("Frame", {
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -36, 1, -24),
		BackgroundTransparency = 1,
		Parent = page,
	}, { C.list(Enum.FillDirection.Horizontal, 12) })
	local rng = Random.new(5)
	for i, key in MonetizationConfig.LimitedCars do
		local product = MonetizationConfig.Products[key]
		local model = VehicleDatabase.getModel(product.ModelKey)
		local card = create("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1 / #MonetizationConfig.LimitedCars, -8, 1, 0),
			BackgroundColor3 = Theme.Panel2,
			Parent = row,
		}, { C.corner(Theme.CornerSmall), C.stroke(Theme.Gold, 1.5) })
		local camera = create("Camera", { FieldOfView = 36 })
		local viewport = create("ViewportFrame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 170),
			BackgroundColor3 = Color3.fromRGB(16, 18, 24),
			Ambient = Color3.fromRGB(150, 150, 160),
			LightDirection = Vector3.new(-0.6, -1, -0.4),
			CurrentCamera = camera,
			Parent = card,
		}, { C.corner(Theme.CornerSmall), C.gradient(Color3.fromRGB(70, 60, 30), Color3.fromRGB(20, 18, 14), 90) })
		camera.Parent = viewport
		local record = {
			id = "preview_" .. key,
			modelKey = product.ModelKey,
			rarity = "Exclusive",
			color = model and model.FixedColor or "JetBlack",
			interior = "Black",
			mods = {},
			trim = "Standard",
			year = 2026,
			mileage = 0,
			condition = 100,
			damage = 0,
			finds = { "Limited" },
		}
		local car, dims = VehicleBuilder.build(record)
		car:PivotTo(CFrame.new())
		car.Parent = viewport
		local center = Vector3.new(0, dims.H * 0.35, 0)
		local angle = rng:NextNumber(0, 6)
		RunService.RenderStepped:Connect(function(dt)
			if modal.isOpen() and page.Visible then
				angle += dt * 0.4
				local dir = CFrame.Angles(0, angle, 0).LookVector
				camera.CFrame = CFrame.lookAt(center + dir * (dims.L * 0.85 + 3) + Vector3.new(0, dims.H * 0.7 + 1, 0), center)
			end
		end)
		C.label({ Text = product.NameUA, Font = Theme.FontBlack, TextSize = 20, Position = UDim2.fromOffset(14, 186), Size = UDim2.new(1, -28, 0, 26), Parent = card })
		C.label({
			Text = ("%d к.с. · вартість %s · не продається"):format(model and model.Power or 0, Format.moneyShort(Pricing.value(record))),
			TextSize = 13,
			TextColor3 = Theme.Muted,
			Position = UDim2.fromOffset(14, 214),
			Size = UDim2.new(1, -28, 0, 34),
			Parent = card,
		})
		C.label({ Text = ("R$ %d"):format(product.PriceRobux), Font = Theme.FontBlack, TextSize = 30, TextColor3 = Theme.Gold, Position = UDim2.fromOffset(14, 252), Size = UDim2.new(1, -28, 0, 36), Parent = card })
		local status = C.label({ Text = "", TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(14, 292), Size = UDim2.new(1, -28, 0, 30), Parent = card })
		local button = C.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.new(1, -24, 0, 50), Text = "", TextSize = 16, Parent = card }, "gold", function()
			prompt(key)
		end)
		limitedCards[key] = { button = button, status = status }
	end
end

local function productCard(parent: Instance, order: number, key: string, title: string, big: string?, sub: string, accent: Color3, badge: string?)
	local card = create("Frame", { LayoutOrder = order, BackgroundColor3 = Theme.Panel2, Parent = parent }, {
		C.corner(Theme.CornerSmall),
		C.stroke(accent, 1.5, 0.2),
		create("Frame", { Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = accent, BorderSizePixel = 0 }),
	})
	C.label({ Text = title, Font = Theme.FontBlack, TextSize = 16, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = card })
	local y = 34
	if big then
		C.label({ Text = big, Font = Theme.FontBlack, TextSize = 26, TextColor3 = Theme.Money, Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, 30), Parent = card })
		y += 32
	end
	local subLabel = C.label({ Text = sub, TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 1, -(y + 56)), TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	if badge then
		create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(74, 22),
			BackgroundColor3 = Color3.fromRGB(60, 46, 12),
			Font = Theme.FontBlack,
			TextSize = 12,
			TextColor3 = Theme.Gold,
			Text = badge,
			Parent = card,
		}, { C.corner(UDim.new(1, 0)) })
	end
	local button = C.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 40), Text = "", TextSize = 15, Parent = card }, "gold", function()
		prompt(key)
	end)
	productButtons[key] = { button = button, sub = subLabel, baseSub = sub }
	return card
end

local function buildCashPage(page: Frame)
	C.label({
		Text = "Ігрова валюта за Robux. Курс ~$1 000 за 1 R$, великі пакети з бонусом до +60%. Гроші нараховуються одразу й зберігаються.",
		TextSize = 13,
		TextColor3 = Theme.Muted,
		Position = UDim2.fromOffset(18, 4),
		Size = UDim2.new(1, -36, 0, 34),
		Parent = page,
	})
	local grid = create("Frame", { Position = UDim2.fromOffset(18, 42), Size = UDim2.new(1, -36, 1, -56), BackgroundTransparency = 1, Parent = page }, {
		create("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0.5, -6), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, key in MonetizationConfig.CashPacks do
		local product = MonetizationConfig.Products[key]
		local perRobux = math.floor(product.Amount / product.PriceRobux)
		productCard(grid, i, key, product.NameUA, Format.money(product.Amount), ("≈ %s за 1 R$"):format(Format.money(perRobux)), Theme.Money, if product.Bonus then ("+%d%%"):format(product.Bonus) else nil)
	end
end

local function buildPerksPage(page: Frame)
	local passes = create("Frame", { Position = UDim2.fromOffset(18, 4), Size = UDim2.new(1, -36, 0, 268), BackgroundTransparency = 1, Parent = page }, {
		create("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0, 128), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, key in MonetizationConfig.PassOrder do
		local pass = MonetizationConfig.GamePasses[key]
		productCard(passes, i, key, pass.NameUA, nil, pass.Description, Theme.Gold, "НАЗАВЖДИ")
	end
	local extras = create("Frame", { Position = UDim2.fromOffset(18, 284), Size = UDim2.new(1, -36, 0, 150), BackgroundTransparency = 1, Parent = page }, {
		create("UIGridLayout", { CellSize = UDim2.new(1 / #MonetizationConfig.ExtraProducts, -10, 1, 0), CellPadding = UDim2.fromOffset(12, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local subs = {
		GarageSlots = "Більше машин у гаражі",
		ShowroomLevel = "Наступний рівень шоуруму без грошей",
		Boost_Cash30 = "Подвоює пасивний дохід",
		Boost_Cash120 = "Подвоює пасивний дохід",
		Boost_Luck30 = "Під брезентами частіше Epic+",
	}
	for i, key in MonetizationConfig.ExtraProducts do
		local product = MonetizationConfig.Products[key]
		productCard(extras, i, key, product.NameUA, nil, subs[key] or "", Theme.Accent, nil)
	end
end

local function build()
	modal = C.modal("ShopUI", "МЕГА-МАРКЕТ", Vector2.new(1040, 560), 12)
	local content = modal.content
	local tabBar = create("Frame", { Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 0, 40), BackgroundTransparency = 1, Parent = content }, {
		C.list(Enum.FillDirection.Horizontal, 8),
	})
	for i, tab in { { "wheel", "КОЛЕСО ФОРТУНИ" }, { "limited", "ЛІМІТОВАНІ АВТО" }, { "cash", "ГРОШІ" }, { "perks", "ПЕРЕВАГИ" } } do
		tabButtons[tab[1]] = C.button({ Text = tab[2], LayoutOrder = i, Size = UDim2.fromOffset(210, 40), TextSize = 15, Parent = tabBar }, "secondary", function()
			showTab(tab[1])
		end)
		pages[tab[1]] = create("Frame", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), BackgroundTransparency = 1, Visible = false, Parent = content })
	end
	buildWheelPage(pages.wheel)
	buildLimitedPage(pages.limited)
	buildCashPage(pages.cash)
	buildPerksPage(pages.perks)
	showTab("wheel")
end

function ShopController.open(tab: string?)
	showTab(tab or "wheel")
	refreshButtons()
	modal.open()
end

local function spinDecorWheels()
	-- every client spins the decorative wheels itself (no network traffic)
	local wheels = {}
	local rainbows = {} :: { BasePart }
	local function track(inst: Instance)
		if inst:IsA("Model") and inst:GetAttribute("SpinDecor") then
			table.insert(wheels, { model = inst, base = nil })
		elseif inst:IsA("BasePart") and inst:GetAttribute("Rainbow") then
			table.insert(rainbows, inst)
		end
	end
	for _, d in workspace:GetDescendants() do
		track(d)
	end
	workspace.DescendantAdded:Connect(track)
	local angle = 0
	RunService.Heartbeat:Connect(function(dt)
		angle += dt * 0.6
		local hue = (os.clock() * 0.25) % 1
		for i = #rainbows, 1, -1 do
			local part = rainbows[i]
			if not part.Parent then
				table.remove(rainbows, i)
			else
				local color = Color3.fromHSV(hue, 0.9, 1)
				part.Color = color
				local light = part:FindFirstChildOfClass("PointLight")
				if light then
					light.Color = color
				end
			end
		end
		for i = #wheels, 1, -1 do
			local w = wheels[i]
			if not w.model.Parent then
				table.remove(wheels, i)
			elseif w.model.PrimaryPart then
				w.base = w.base or w.model:GetPivot()
				w.model:PivotTo(w.base * CFrame.Angles(angle, 0, 0)) -- hub X axis = wheel axle
			end
		end
	end)
end

function ShopController.init()
	build()
	HUDController.addMenuButton(4, "МАГАЗИН", "Колесо та лімітки", function()
		if modal.isOpen() then
			modal.close()
		else
			ShopController.open("wheel")
		end
	end)
	StateController.StateChanged:Connect(function()
		ShopController.stateReceivedAt = os.time()
		refreshButtons()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if modal.isOpen() then
				refreshButtons()
			end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(p, who)
		local tab = p:GetAttribute("ShopTab")
		if who == player and tab then
			ShopController.open(tab)
		end
	end)
	Net.get("SpinResult").OnClientEvent:Connect(function(result)
		if type(result) ~= "table" then
			return
		end
		if result.purchased then
			HUDController.toast("Лімітоване авто " .. tostring(result.name) .. " додано у ваш гараж!", "level")
		elseif modal.isOpen() then
			task.spawn(function()
				spinning = true
				refreshButtons()
				animateSpin(result)
				spinning = false
				refreshButtons()
			end)
		else
			HUDController.toast("Колесо фортуни: " .. tostring(result.name), "success")
		end
	end)
	spinDecorWheels()
end

return ShopController

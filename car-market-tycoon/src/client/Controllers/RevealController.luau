-- Tarp reveal: suspense shake, tarp flying off, camera move + orbit, rarity effects and the
-- result card. Other players see the tarp fly and the burst too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Format = require(Shared.Modules.Format)
local RarityConfig = require(Shared.Configs.RarityConfig)
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)
local VehicleBuilder = require(Shared.Modules.VehicleBuilder)
local RarityFX = require(Shared.Modules.RarityFX)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local C = require(UI.Components)
local create = C.create

local HUDController = require(script.Parent.HUDController)

local player = Players.LocalPlayer
local RevealController = {}
RevealController.isPlaying = false

local gui: ScreenGui
local card: CanvasGroup?
local flash: Frame
local orbitConnection: RBXScriptConnection?

local function sound(id: string, speed: number?, volume: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed or 1
	s.Volume = volume or 0.6
	s.Parent = SoundService
	SoundService:PlayLocalSound(s)
	task.delay(4, function()
		s:Destroy()
	end)
end

local function getControls()
	local ok, controls = pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		return module:GetControls()
	end)
	return if ok then controls else nil
end

local function findLot(plotIndex: number?, lotIndex: number): Instance?
	local plots = workspace:FindFirstChild("PlayerPlots")
	local plot = plots and plotIndex and plots:FindFirstChild("Plot_" .. plotIndex)
	local yard = plot and plot:FindFirstChild("Yard")
	return yard and yard:FindFirstChild(("Lot_%02d"):format(lotIndex))
end

-- Shake (suspense) + lift + fly away. Purely local, the server deletes the tarp afterwards.
local function animateTarp(tarp: Model, rarityKey: string, withSuspense: boolean)
	local rarity = RarityConfig.get(rarityKey)
	local parts = {}
	for _, d in tarp:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, { part = d, cf = d.CFrame })
		elseif d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter") then
			(d :: any).Enabled = false
		end
	end
	local root = tarp.PrimaryPart
	if withSuspense and rarity.Suspense > 0 and root then
		local glow = create("PointLight", { Color = rarity.Color, Brightness = 0, Range = 18, Parent = root })
		TweenService:Create(glow, TweenInfo.new(rarity.Suspense), { Brightness = 6 }):Play()
		local steps = math.max(1, math.floor(rarity.Suspense / 0.2))
		for i = 1, steps do
			local amp = 0.05 + 0.18 * (i / steps)
			for _, p in parts do
				p.part.CFrame = p.cf * CFrame.new((math.random() - 0.5) * amp, math.random() * amp, (math.random() - 0.5) * amp)
			end
			if i % 3 == 0 then
				sound("rbxasset://sounds/electronicpingshort.wav", 0.5 + i / steps, 0.25)
			end
			task.wait(0.1)
			for _, p in parts do
				p.part.CFrame = p.cf
			end
			task.wait(0.1)
		end
	end

	sound("rbxasset://sounds/swoosh.wav", 0.9, 0.8)
	for _, p in parts do
		TweenService:Create(p.part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = p.cf + Vector3.new(0, 1.4, 0),
		}):Play()
	end
	task.wait(0.22)
	local center = tarp:GetPivot().Position
	local wind = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
	wind = if wind.Magnitude > 0.01 then wind.Unit * 10 else Vector3.new(10, 0, 0)
	for _, p in parts do
		local spread = (p.cf.Position - center) * 0.6
		local target = (p.cf + Vector3.new(0, 18 + math.random() * 10, 0) + wind + spread)
			* CFrame.Angles(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
		TweenService:Create(p.part, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = target,
			Transparency = 1,
		}):Play()
	end
end

local function revealEffects(car: Model?, rarityKey: string, local_: boolean)
	local rarity = RarityConfig.get(rarityKey)
	local root = car and car.PrimaryPart
	if not root then
		return
	end
	RarityFX.burst(root, rarityKey)
	if rarity.Pillar > 0 then
		RarityFX.pillar(root.Position - Vector3.new(0, root.Size.Y / 2, 0), rarityKey, 6, workspace)
	end
	if local_ and rarity.Index >= 5 then
		flash.BackgroundColor3 = rarity.Color
		flash.BackgroundTransparency = 0.25
		TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		for i = 1, 3 do
			task.delay(i * 0.18, sound, rarity.Sound, 0.8 + i * 0.25, 0.6)
		end
	elseif local_ then
		sound(rarity.Sound, 1 + rarity.Index * 0.08, 0.6)
	end
	if rarityKey == "Exclusive" then
		for i = 1, 3 do
			task.delay(i * 0.5, RarityFX.burst, root, rarityKey)
		end
	end
end

local function focusCFrame(carCF: CFrame, dims, angle: number): CFrame
	local center = carCF.Position + Vector3.new(0, dims.H * 0.35, 0)
	local dist = math.max(dims.L, 12) * 0.9 + 4
	local dir = (carCF * CFrame.Angles(0, angle, 0)).LookVector
	return CFrame.lookAt(center + dir * dist + Vector3.new(0, dims.H * 0.8 + 2.5, 0), center)
end

local function statCell(parent: Instance, order: number, title: string, value: string)
	create("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = Theme.Panel2,
		Parent = parent,
	}, {
		C.corner(Theme.CornerSmall),
		C.label({ Text = title, TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -16, 0, 14) }),
		C.label({ Text = value, TextSize = 16, Font = Theme.FontBold, Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -16, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false }),
	})
end

-- Builds the detail card used by the reveal (and reused by the garage for consistency).
function RevealController.buildVehicleDetails(parent: Instance, vehicle)
	local rarity = RarityConfig.get(vehicle.rarity)
	local color = VehicleDatabase.ColorByKey[vehicle.color]
	local class = VehicleDatabase.Classes[vehicle.class]

	C.label({
		LayoutOrder = 1,
		Text = vehicle.brand .. " " .. vehicle.model,
		Font = Theme.FontBlack,
		TextSize = 28,
		Size = UDim2.new(1, 0, 0, 34),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = parent,
	})
	C.label({
		LayoutOrder = 2,
		Text = ("%s · %d · %s"):format(vehicle.trim, vehicle.year, class and class.NameUA or vehicle.class),
		TextColor3 = Theme.Muted,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = parent,
	})

	local grid = create("Frame", { LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 158), Parent = parent }, {
		create("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 48), CellPadding = UDim2.fromOffset(10, 7), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	statCell(grid, 1, "Потужність", ("%d к.с."):format(vehicle.power))
	statCell(grid, 2, "Пробіг", Format.km(vehicle.mileage))
	statCell(grid, 3, "Стан", ("%d%%"):format(vehicle.condition))
	statCell(grid, 4, "Пошкодження", ("%d%%"):format(vehicle.damage))
	statCell(grid, 5, "Колір", color and color.NameUA or vehicle.color)
	statCell(grid, 6, "Рідкість", rarity.NameUA)

	if vehicle.finds and #vehicle.finds > 0 then
		local chips = create("Frame", { LayoutOrder = 4, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = parent }, {
			C.list(Enum.FillDirection.Horizontal, 6),
		})
		for _, key in vehicle.finds do
			local find = VehicleDatabase.Finds[key]
			local text = find and find.NameUA or key
			if key == "Collector" and vehicle.serial then
				text ..= (" #%d/100"):format(vehicle.serial)
			end
			create("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				BackgroundColor3 = Color3.fromRGB(60, 46, 12),
				Font = Theme.FontBold,
				TextSize = 13,
				TextColor3 = Theme.Gold,
				Text = "  ★ " .. text .. "  ",
				Parent = chips,
			}, { C.corner(UDim.new(1, 0)), C.stroke(Theme.Gold, 1, 0.4) })
		end
	end
	if vehicle.story then
		C.label({
			LayoutOrder = 5,
			Text = "«" .. vehicle.story .. "»",
			TextSize = 13,
			TextColor3 = Theme.Muted,
			Size = UDim2.new(1, 0, 0, 34),
			Parent = parent,
		})
	end
end

local function closeCard(restore: () -> ())
	if card then
		local c = card
		card = nil
		local t = TweenService:Create(c, TweenInfo.new(0.2), { GroupTransparency = 1 })
		t:Play()
		t.Completed:Once(function()
			c:Destroy()
		end)
	end
	restore()
end

local function showCard(vehicle, paid: number, restore: () -> ())
	local rarity = RarityConfig.get(vehicle.rarity)
	local panel = create("CanvasGroup", {
		Name = "RevealCard",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 40, 0.5, 0),
		Size = UDim2.fromOffset(430, 600),
		BackgroundColor3 = Theme.Panel,
		GroupTransparency = 1,
		Parent = gui,
	}, { C.corner(), C.stroke(rarity.Color, 2.5) })
	C.scaled(panel)
	card = panel

	create("Frame", {
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = panel,
	}, {
		C.gradient(rarity.Color, rarity.Color2, 0),
		C.label({ Text = "НОВИЙ АВТОМОБІЛЬ", TextSize = 13, Font = Theme.FontBold, TextColor3 = Color3.fromRGB(20, 20, 24), Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -40, 0, 16) }),
		C.label({ Text = string.upper(rarity.NameUA), TextSize = 30, Font = Theme.FontBlack, TextColor3 = Color3.fromRGB(14, 14, 18), Position = UDim2.fromOffset(20, 28), Size = UDim2.new(1, -40, 0, 36) }),
	})

	local body = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 88),
		Size = UDim2.new(1, -40, 1, -180),
		Parent = panel,
	}, { C.list(Enum.FillDirection.Vertical, 8) })
	RevealController.buildVehicleDetails(body, vehicle)

	local profit = vehicle.value - paid
	create("Frame", {
		LayoutOrder = 10,
		BackgroundColor3 = Theme.Panel2,
		Size = UDim2.new(1, 0, 0, 66),
		Parent = body,
	}, {
		C.corner(Theme.CornerSmall),
		C.label({ Text = "Ринкова вартість", TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(0.6, 0, 0, 14) }),
		C.label({ Text = Format.money(vehicle.value), TextSize = 26, Font = Theme.FontBlack, TextColor3 = Theme.Money, Position = UDim2.fromOffset(12, 24), Size = UDim2.new(0.6, 0, 0, 32) }),
		C.label({ Text = "Сплачено " .. Format.money(paid), TextSize = 12, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0.5, -12, 0, 14) }),
		C.label({
			Text = (if profit >= 0 then "+" else "") .. Format.money(profit),
			TextSize = 18,
			Font = Theme.FontBold,
			TextColor3 = if profit >= 0 then Theme.Money else Theme.Danger,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.5, 0, 0, 28),
			Size = UDim2.new(0.5, -12, 0, 24),
		}),
	})

	local buttons = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -18),
		Size = UDim2.new(1, -40, 0, 50),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { C.list(Enum.FillDirection.Horizontal, 8) })

	local busy = false
	local function action(remoteName: string, okText: (any) -> string)
		if busy then
			return
		end
		busy = true
		local ok, result = pcall(function()
			return Net.get(remoteName):InvokeServer(vehicle.id)
		end)
		if ok and type(result) == "table" and result.ok then
			HUDController.toast(okText(result), "success")
			closeCard(restore)
		else
			HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
			busy = false
		end
	end

	C.button({ Text = "У ГАРАЖ", Size = UDim2.new(0.3, -6, 1, 0), LayoutOrder = 1, Parent = buttons }, "secondary", function()
		closeCard(restore)
	end)
	C.button({ Text = "ВИСТАВИТИ", Size = UDim2.new(0.3, -6, 1, 0), LayoutOrder = 2, Parent = buttons }, "primary", function()
		action("ToggleDisplay", function()
			return "Авто виставлено в шоурум"
		end)
	end)
	C.button({ Text = "ПРОДАТИ " .. Format.moneyShort(vehicle.quickSell), Size = UDim2.new(0.4, 0, 1, 0), LayoutOrder = 3, TextSize = 15, Parent = buttons }, "money", function()
		action("SellVehicle", function(result)
			return "Продано за " .. Format.money(result.payout)
		end)
	end)

	TweenService:Create(panel, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -24, 0.5, 0),
		GroupTransparency = 0,
	}):Play()

	if vehicle.rarity == "Exclusive" then
		local stroke = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
		task.spawn(function()
			while panel.Parent do
				stroke.Color = Color3.fromHSV((os.clock() * 0.4) % 1, 0.6, 1)
				task.wait()
			end
		end)
	end
end

-- Full reveal for the local player, driven by the BuyLot result.
function RevealController.play(result)
	if RevealController.isPlaying then
		return
	end
	RevealController.isPlaying = true
	local vehicle = result.vehicle
	local rarity = RarityConfig.get(vehicle.rarity)
	local camera = workspace.CurrentCamera
	local controls = getControls()

	local lot = findLot(result.plotIndex, result.lotIndex)
	local car = lot and (lot:WaitForChild("Vehicle", 4) :: Model?)
	local tarp = lot and lot:FindFirstChild("Tarp") :: Model?
	local carCF = if car then car:GetPivot() elseif tarp then tarp:GetPivot() else nil
	local dims = VehicleBuilder.getDimensions(vehicle.modelKey)

	local restored = false
	local function restore()
		if restored then
			return
		end
		restored = true
		if orbitConnection then
			orbitConnection:Disconnect()
			orbitConnection = nil
		end
		camera.CameraType = Enum.CameraType.Custom
		if controls then
			controls:Enable()
		end
		RevealController.isPlaying = false
	end

	if controls then
		controls:Disable()
	end
	local angle = math.rad(35)
	if carCF then
		camera.CameraType = Enum.CameraType.Scriptable
		local tween = TweenService:Create(camera, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			CFrame = focusCFrame(carCF, dims, angle),
		})
		tween:Play()
		tween.Completed:Wait()
	end

	if tarp and tarp.Parent then
		animateTarp(tarp, vehicle.rarity, true)
	else
		task.wait(rarity.Suspense)
	end
	revealEffects(car, vehicle.rarity, true)

	if carCF then
		local frozen = carCF
		orbitConnection = RunService.RenderStepped:Connect(function(dt)
			angle += dt * 0.28
			camera.CFrame = camera.CFrame:Lerp(focusCFrame(frozen, dims, angle), math.min(1, dt * 4))
		end)
	end
	task.wait(0.5)
	showCard(vehicle, result.paid or vehicle.paid or 0, restore)

	-- safety: never leave the player stuck in the reveal camera
	task.delay(60, function()
		if not restored then
			closeCard(restore)
		end
	end)
end

function RevealController.init()
	gui = C.screen("RevealUI", 20)
	flash = create("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = gui,
	})

	-- other players' reveals: tarp flies + burst, no camera
	Net.get("LotRevealed").OnClientEvent:Connect(function(info)
		if type(info) ~= "table" or info.ownerUserId == player.UserId then
			return
		end
		local lot = findLot(info.plotIndex, info.lotIndex)
		if not lot then
			return -- not streamed in for this client
		end
		local tarp = lot:FindFirstChild("Tarp") :: Model?
		if tarp then
			task.spawn(function()
				animateTarp(tarp, info.rarity, true)
				revealEffects(lot:FindFirstChild("Vehicle") :: Model?, info.rarity, false)
			end)
		end
	end)
end

return RevealController

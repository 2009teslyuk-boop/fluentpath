-- Builds the shared world: lighting, ground, the boulevard and the Mega Market in the middle of
-- the map (wheel of fortune, limited Robux cars on podiums, shop counter).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local MonetizationConfig = require(Shared.Configs.MonetizationConfig)
local SpinConfig = require(Shared.Configs.SpinConfig)
local VehicleBuilder = require(Shared.Modules.VehicleBuilder)
local VehicleGenerator = require(Shared.Modules.VehicleGenerator)
local RarityFX = require(Shared.Modules.RarityFX)
local Build = require(script.Parent.Parent.Lib.Build)

local V3, CF = Vector3.new, CFrame.new
local M = Enum.Material

local WorldService = {}

WorldService.Folders = {} :: { [string]: Folder }

local PLAZA_HALF = 92 -- the plaza covers z = -92..92 (between the plot rows)
local ROAD_HALF = 380
WorldService.ShopSpawnCFrame = CF(0, 4, -70) * CFrame.Angles(0, math.pi, 0)

local ACCENT = Color3.fromRGB(64, 210, 255)
local GOLD = Color3.fromRGB(255, 200, 70)

local function effect(className: string, name: string): any
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

local function setupLighting()
	Lighting.ClockTime = 16.7
	Lighting.GeographicLatitude = 38
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.Ambient = Color3.fromRGB(58, 60, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(122, 126, 140)

	local atmosphere = effect("Atmosphere", "CMT_Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(205, 196, 186)
	atmosphere.Decay = Color3.fromRGB(108, 112, 128)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.3

	local bloom = effect("BloomEffect", "CMT_Bloom")
	bloom.Intensity = 0.55
	bloom.Size = 28
	bloom.Threshold = 1.35

	local cc = effect("ColorCorrectionEffect", "CMT_ColorCorrection")
	cc.Brightness = 0.02
	cc.Contrast = 0.1
	cc.Saturation = 0.08
	cc.TintColor = Color3.fromRGB(255, 249, 242)

	local rays = effect("SunRaysEffect", "CMT_SunRays")
	rays.Intensity = 0.05
	rays.Spread = 0.7
end

local function buildGround(roads: Folder)
	local plots = GameConfig.Plots
	local length = ROAD_HALF * 2
	Build.part(roads, "Grass", V3(1400, 1, 1400), CF(0, -0.5, 0), Color3.fromRGB(70, 98, 58), M.Grass)
	Build.part(roads, "Boulevard", V3(plots.BoulevardWidth, 0.2, length), CF(0, 0.1, 0), Color3.fromRGB(44, 46, 52), M.Asphalt)

	for _, sign in { -1, 1 } do
		local from, to = PLAZA_HALF + 4, ROAD_HALF - 6
		local mid = sign * (from + to) / 2
		local len = to - from
		-- lane markings
		local z = from + 3
		while z < to do
			for _, x in { -plots.BoulevardWidth / 4, plots.BoulevardWidth / 4 } do
				Build.part(roads, "LaneMark", V3(0.4, 0.04, 6), CF(x, 0.22, sign * z), Color3.fromRGB(230, 230, 220), M.SmoothPlastic, { CanCollide = false })
			end
			z += 14
		end
		-- median with trees
		Build.part(roads, "Median", V3(6, 0.6, len - 20), CF(0, 0.3, mid), Color3.fromRGB(150, 150, 146), M.Concrete)
		Build.part(roads, "MedianGrass", V3(5, 0.1, len - 21), CF(0, 0.62, mid), Color3.fromRGB(78, 120, 60), M.Grass, { CanCollide = false })
		z = from + 24
		while z < to - 12 do
			Build.tree(roads, V3(0, 0.6, sign * z), 0.85)
			z += 46
		end
		-- sidewalks + lamps
		for _, side in { -1, 1 } do
			local x = side * (plots.BoulevardWidth / 2 + 3)
			Build.part(roads, "Sidewalk", V3(6, 0.4, len), CF(x, 0.2, mid), Color3.fromRGB(176, 176, 170), M.Concrete)
			z = from + 14
			while z < to - 6 do
				-- the lamp arm points along -Z in lamp space; rotate it towards the centre line
				Build.lamp(roads, CF(x, 0.4, sign * z) * CFrame.Angles(0, side * math.pi / 2, 0), Color3.fromRGB(255, 226, 180))
				z += 48
			end
		end
	end
end

-- Decorative wheel of fortune (spun locally by every client: attribute SpinDecor).
local function buildWheel(parent: Instance, cf: CFrame, radius: number)
	local wheel = Build.model(parent, "FortuneWheel")
	wheel:SetAttribute("SpinDecor", true)
	local hub = Build.part(wheel, "Hub", V3(1.2, radius * 0.22, radius * 0.22), cf * CFrame.Angles(0, math.pi / 2, 0), GOLD, M.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	wheel.PrimaryPart = hub
	Build.part(wheel, "Rim", V3(0.6, radius * 2 + 1, radius * 2 + 1), cf * CF(0, 0, -0.1) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(30, 30, 36), M.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	local count = 12
	for i = 1, count do
		local prize = SpinConfig.Prizes[(i - 1) % 11 + 1]
		local angle = (i / count) * math.pi * 2
		Build.part(wheel, "Segment", V3(radius * 0.52, radius * 0.5, 0.4), cf * CFrame.Angles(0, 0, angle) * CF(radius * 0.5, 0, 0.15), prize.Color, M.Neon, { CanCollide = false, Transparency = 0.1 })
		Build.part(wheel, "Divider", V3(radius, 0.25, 0.5), cf * CFrame.Angles(0, 0, angle + math.pi / count) * CF(radius / 2, 0, 0.2), Color3.fromRGB(240, 240, 240), M.SmoothPlastic, { CanCollide = false })
	end
	for i = 1, 24 do
		local angle = (i / 24) * math.pi * 2
		Build.part(wheel, "Bulb", V3(0.7, 0.7, 0.7), cf * CFrame.Angles(0, 0, angle) * CF(radius + 0.2, 0, 0.3), Color3.fromRGB(255, 240, 200), M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
	end
	-- pointer at the top
	Build.part(parent, "WheelPointer", V3(1.6, 3, 0.6), cf * CF(0, radius + 1.8, 0.4), Color3.fromRGB(255, 60, 70), M.Neon, { ClassName = "WedgePart", CanCollide = false })
	return wheel
end

local function shopPrompt(part: BasePart, text: string, tab: string)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = text
	prompt.ObjectText = "Мега-маркет"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("ShopTab", tab)
	prompt.Parent = attachment
	return prompt
end

local function buildMegaMarket(buildings: Folder, market: Folder)
	local mall = Build.model(buildings, "MegaMarket")
	local width, depth, height = 150, 96, 34

	Build.part(market, "Plaza", V3(300, 0.3, PLAZA_HALF * 2), CF(0, 0.15, 0), Color3.fromRGB(196, 192, 184), M.Pavement)
	for _, sign in { -1, 1 } do
		Build.part(market, "PlazaTrim", V3(300, 0.32, 0.6), CF(0, 0.16, sign * (PLAZA_HALF - 0.3)), ACCENT, M.Neon, { CanCollide = false })
		for _, x in { -60, -30, 30, 60 } do
			Build.tree(market, V3(x, 0.3, sign * (depth / 2 + 18)), 0.8)
		end
	end

	Build.part(mall, "Floor", V3(width, 0.6, depth), CF(0, 0.3, 0), Color3.fromRGB(30, 32, 38), M.Marble, { Reflectance = 0.15 })
	-- glass facades with an entrance on both sides
	local doorGap = 30
	local glassW = (width - doorGap) / 2
	for _, sign in { -1, 1 } do
		local z = sign * (depth / 2 - 1)
		for _, side in { -1, 1 } do
			Build.part(mall, "Facade", V3(glassW, height - 2, 0.4), CF(side * (doorGap / 2 + glassW / 2), (height - 2) / 2 + 0.6, z), Color3.fromRGB(150, 190, 220), M.Glass, { Transparency = 0.55, Reflectance = 0.2 })
		end
		Build.part(mall, "DoorHeader", V3(doorGap, 8, 0.6), CF(0, height - 4, z), Color3.fromRGB(46, 48, 56), M.Metal)
		Build.part(mall, "EntranceLight", V3(doorGap, 0.4, 0.4), CF(0, height - 8.2, z + sign * 0.4), GOLD, M.Neon, { CanCollide = false })
		local sign3 = Build.part(mall, "Sign", V3(84, 12, 1), CF(0, height + 9, z + sign * 1.2), Color3.fromRGB(12, 14, 18), M.SmoothPlastic)
		Build.sign(sign3, if sign > 0 then Enum.NormalId.Back else Enum.NormalId.Front, "MEGA MARKET", GOLD, Enum.Font.GothamBlack, 10)
		for _, dy in { 15.4, 2.6 } do
			Build.part(mall, "SignTrim", V3(86, 0.4, 0.4), CF(0, height + dy, z + sign * 1.8), GOLD, M.Neon, { CanCollide = false })
		end
	end
	for i = 0, 10 do
		local x = -width / 2 + i * (width / 10)
		for _, z in { -depth / 2 + 1, depth / 2 - 1 } do
			Build.part(mall, "Column", V3(1.6, height, 1.6), CF(x, height / 2, z), Color3.fromRGB(56, 60, 68), M.Metal)
		end
	end
	for _, side in { -1, 1 } do
		Build.part(mall, "SideWall", V3(1, height, depth), CF(side * width / 2, height / 2, 0), Color3.fromRGB(210, 210, 206), M.Concrete)
	end
	Build.part(mall, "Roof", V3(width + 6, 2, depth + 6), CF(0, height + 1, 0), Color3.fromRGB(36, 38, 44), M.Metal)
	for _, sign in { -1, 1 } do
		Build.part(mall, "RoofTrim", V3(width + 6, 0.5, 0.5), CF(0, height + 0.2, sign * (depth / 2 + 3)), ACCENT, M.Neon, { CanCollide = false })
	end
	for i = -2, 2 do
		for _, z in { -24, 24 } do
			local lamp = Build.part(mall, "CeilingLight", V3(9, 0.3, 3), CF(i * 28, height - 0.4, z), Color3.fromRGB(255, 244, 228), M.Neon, { CanCollide = false })
			Build.spotLight(lamp, Color3.fromRGB(255, 240, 220), 44, 1.6, 120)
		end
	end

	-- big wheels of fortune on both facades (above the entrances) and one inside
	for _, sign in { -1, 1 } do
		buildWheel(mall, CF(0, height + 26, sign * (depth / 2 + 1)) * (if sign > 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)), 9)
	end
	buildWheel(mall, CF(0, 15, -10) * CFrame.Angles(0, math.pi, 0), 8)

	-- shop counter in the middle
	local counter = Build.part(mall, "Counter", V3(28, 4, 6), CF(0, 2.6, 4), Color3.fromRGB(20, 22, 28), M.Marble, { Reflectance = 0.2 })
	Build.part(mall, "CounterTop", V3(28.4, 0.3, 6.4), CF(0, 4.75, 4), GOLD, M.Neon, { CanCollide = false })
	shopPrompt(counter, "ВІДКРИТИ МАГАЗИН", "wheel")

	-- limited cars on podiums
	local rng = Random.new(77)
	for i, productKey in MonetizationConfig.LimitedCars do
		local product = MonetizationConfig.Products[productKey]
		local x = (i - 2) * 44
		local podiumCF = CF(x, 0.6, 26)
		Build.part(mall, "Podium", V3(1.2, 24, 24), podiumCF * CF(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(16, 16, 20), M.Glass, { Shape = Enum.PartType.Cylinder, Reflectance = 0.25 })
		local ring = Build.part(mall, "PodiumRing", V3(0.3, 25, 25), podiumCF * CF(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), GOLD, M.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		local record = VehicleGenerator.generateLimited(rng, product.ModelKey)
		local car = VehicleBuilder.build(record)
		car.Name = "Limited_" .. product.ModelKey
		car:PivotTo(podiumCF * CF(0, 1.2, 0) * CFrame.Angles(0, math.rad(160 + i * 20), 0))
		car.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		car.Parent = mall
		RarityFX.applyGlow(car, record.rarity)

		local board = Build.part(mall, "PriceBoard", V3(12, 4, 0.4), podiumCF * CF(0, 3.2, 13.5), Color3.fromRGB(12, 12, 16), M.SmoothPlastic)
		Build.sign(board, Enum.NormalId.Back, ("%s · R$ %d"):format(product.NameUA, product.PriceRobux), GOLD, Enum.Font.GothamBlack, 24)
		shopPrompt(ring, ("КУПИТИ ЗА R$ %d"):format(product.PriceRobux), "limited")
	end
end

function WorldService.init()
	setupLighting()
	local folders = WorldService.Folders
	for _, name in { "MainMarket", "PlayerPlots", "NPCZones", "Roads", "Buildings" } do
		folders[name] = Build.folder(workspace, name)
	end

	buildGround(folders.Roads)
	buildMegaMarket(folders.Buildings, folders.MainMarket)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MarketSpawn"
	spawn.Anchored = true
	spawn.Size = V3(12, 0.4, 12)
	spawn.CFrame = CF(0, 0.5, -70)
	spawn.Color = ACCENT
	spawn.Material = M.Neon
	spawn.Transparency = 0.3
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folders.MainMarket
	-- remove a default baseplate / spawn if the place still has them
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	local defaultSpawn = workspace:FindFirstChild("SpawnLocation")
	if defaultSpawn and defaultSpawn:IsA("SpawnLocation") then
		defaultSpawn:Destroy()
	end
end

return WorldService

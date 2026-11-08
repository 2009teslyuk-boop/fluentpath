-- Builds the shared world: lighting, ground, boulevard, the central market hall and its showcase.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local VehicleBuilder = require(Shared.Modules.VehicleBuilder)
local VehicleGenerator = require(Shared.Modules.VehicleGenerator)
local RarityFX = require(Shared.Modules.RarityFX)
local Build = require(script.Parent.Parent.Lib.Build)

local V3, CF = Vector3.new, CFrame.new
local M = Enum.Material

local WorldService = {}

WorldService.Folders = {} :: { [string]: Folder }
WorldService.SpawnCFrame = CF(0, 4, -300)

local HALL_Z = -365
local PLAZA_Z = -302

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
	local length = 600 -- boulevard runs from the plaza (z = -300) to the south end (z = 300)
	local half = length / 2
	Build.part(roads, "Grass", V3(1400, 1, 1400), CF(0, -0.5, 0), Color3.fromRGB(70, 98, 58), M.Grass)
	Build.part(roads, "Boulevard", V3(plots.BoulevardWidth, 0.2, length), CF(0, 0.1, 0), Color3.fromRGB(44, 46, 52), M.Asphalt)

	-- lane markings
	local z = -half + 6
	while z < half - 6 do
		for _, x in { -plots.BoulevardWidth / 4, plots.BoulevardWidth / 4 } do
			Build.part(roads, "LaneMark", V3(0.4, 0.04, 6), CF(x, 0.22, z), Color3.fromRGB(230, 230, 220), M.SmoothPlastic, { CanCollide = false })
		end
		z += 14
	end

	-- median with trees
	local medianLength = length - 60
	Build.part(roads, "Median", V3(6, 0.6, medianLength), CF(0, 0.3, 0), Color3.fromRGB(150, 150, 146), M.Concrete)
	Build.part(roads, "MedianGrass", V3(5, 0.1, medianLength - 1), CF(0, 0.62, 0), Color3.fromRGB(78, 120, 60), M.Grass, { CanCollide = false })
	z = -medianLength / 2 + 20
	while z < medianLength / 2 - 10 do
		Build.tree(roads, V3(0, 0.6, z), 0.85)
		z += 48
	end

	-- sidewalks + lamps
	for _, side in { -1, 1 } do
		local x = side * (plots.BoulevardWidth / 2 + 3)
		Build.part(roads, "Sidewalk", V3(6, 0.4, length), CF(x, 0.2, 0), Color3.fromRGB(176, 176, 170), M.Concrete)
		z = -half + 24
		while z < half - 10 do
			-- the lamp arm points along -Z in lamp space; rotate it towards the centre line
			Build.lamp(roads, CF(x, 0.4, z) * CFrame.Angles(0, side * math.pi / 2, 0), Color3.fromRGB(255, 226, 180))
			z += 48
		end
	end
end

local function buildHall(buildings: Folder, market: Folder)
	local hall = Build.model(buildings, "MarketHall")
	local width, depth, height = 220, 84, 30
	local front = HALL_Z + depth / 2 -- the facade faces +Z (towards the plots)

	Build.part(market, "Plaza", V3(260, 0.3, 40), CF(0, 0.15, PLAZA_Z - 3), Color3.fromRGB(196, 192, 184), M.Pavement)
	Build.part(hall, "Floor", V3(width, 0.6, depth), CF(0, 0.3, HALL_Z), Color3.fromRGB(34, 36, 42), M.Marble, { Reflectance = 0.12 })

	-- columns
	for i = 0, 11 do
		local x = -width / 2 + i * (width / 11)
		for _, z in { front - 1, HALL_Z - depth / 2 + 1 } do
			Build.part(hall, "Column", V3(2, height, 2), CF(x, height / 2, z), Color3.fromRGB(58, 62, 70), M.Metal)
		end
	end
	-- facade glass with a central entrance
	local doorGap = 28
	local glassW = (width - doorGap) / 2
	for _, side in { -1, 1 } do
		Build.part(hall, "Facade", V3(glassW, height - 2, 0.4), CF(side * (doorGap / 2 + glassW / 2), (height - 2) / 2 + 0.6, front - 1),
			Color3.fromRGB(150, 190, 220), M.Glass, { Transparency = 0.55, Reflectance = 0.2 })
	end
	Build.part(hall, "DoorHeader", V3(doorGap, 8, 0.6), CF(0, height - 4, front - 1), Color3.fromRGB(58, 62, 70), M.Metal)
	-- walls + roof
	Build.part(hall, "BackWall", V3(width, height, 1), CF(0, height / 2, HALL_Z - depth / 2), Color3.fromRGB(200, 200, 196), M.Concrete)
	for _, side in { -1, 1 } do
		Build.part(hall, "SideWall", V3(1, height, depth), CF(side * width / 2, height / 2, HALL_Z), Color3.fromRGB(200, 200, 196), M.Concrete)
	end
	Build.part(hall, "Roof", V3(width + 6, 2, depth + 6), CF(0, height + 1, HALL_Z), Color3.fromRGB(40, 42, 48), M.Metal)
	Build.part(hall, "RoofTrim", V3(width + 6, 0.5, 0.5), CF(0, height + 0.2, front + 3), Color3.fromRGB(64, 210, 255), M.Neon, { CanCollide = false })

	-- big sign facing the plots (the Back face of a part points to +Z)
	local sign = Build.part(hall, "Sign", V3(110, 14, 1), CF(0, height + 10, front + 1), Color3.fromRGB(14, 16, 20), M.SmoothPlastic)
	Build.sign(sign, Enum.NormalId.Back, "CAR MARKET TYCOON", Color3.fromRGB(110, 225, 255), Enum.Font.GothamBlack, 10)
	Build.part(hall, "SignFrame", V3(112, 0.4, 0.4), CF(0, height + 17, front + 1.6), Color3.fromRGB(64, 210, 255), M.Neon, { CanCollide = false })
	Build.part(hall, "SignFrame", V3(112, 0.4, 0.4), CF(0, height + 3, front + 1.6), Color3.fromRGB(64, 210, 255), M.Neon, { CanCollide = false })

	-- interior lights
	for i = -2, 2 do
		local lamp = Build.part(hall, "CeilingLight", V3(8, 0.3, 3), CF(i * 40, height - 0.4, HALL_Z), Color3.fromRGB(255, 244, 228), M.Neon, { CanCollide = false })
		Build.spotLight(lamp, Color3.fromRGB(255, 240, 220), 40, 1.6, 120)
	end

	-- showcase podiums with a few dream cars (look, don't touch)
	local showcase = { "monarch_sovereign", "halcyon_aether", "aurelia_vento" }
	local rng = Random.new(2026)
	for i, key in showcase do
		local x = (i - 2) * 48
		local podiumCF = CF(x, 0.6, HALL_Z + 4)
		Build.part(hall, "Podium", V3(1, 26, 26), podiumCF * CF(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(22, 24, 30), M.Glass, { Shape = Enum.PartType.Cylinder, Reflectance = 0.2 })
		Build.part(hall, "PodiumRing", V3(0.3, 27, 27), podiumCF * CF(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(64, 210, 255), M.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		local record = VehicleGenerator.generate(rng, "Common", key) -- rarity comes from the model itself
		record.condition, record.damage, record.mileage = 100, 0, 12
		local car = VehicleBuilder.build(record)
		car.Name = "Showcase_" .. key
		car:PivotTo(podiumCF * CF(0, 1, 0) * CFrame.Angles(0, math.rad(200 + i * 25), 0))
		car.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		car.Parent = hall
		RarityFX.applyGlow(car, record.rarity)
	end
end

function WorldService.init()
	setupLighting()
	local folders = WorldService.Folders
	for _, name in { "MainMarket", "PlayerPlots", "NPCZones", "Roads", "Buildings" } do
		folders[name] = Build.folder(workspace, name)
	end

	buildGround(folders.Roads)
	buildHall(folders.Buildings, folders.MainMarket)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MarketSpawn"
	spawn.Anchored = true
	spawn.Size = V3(12, 0.4, 12)
	spawn.CFrame = CF(0, 0.5, PLAZA_Z)
	spawn.Color = Color3.fromRGB(64, 210, 255)
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

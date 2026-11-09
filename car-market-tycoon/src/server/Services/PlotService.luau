-- Player plots: builds 8 dealership plots along the boulevard, assigns them to players,
-- exposes lot / showroom spot positions and teleports players home.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local Build = require(script.Parent.Parent.Lib.Build)
local ShowroomBuilder = require(script.Parent.Parent.Lib.ShowroomBuilder)

local V3, CF = Vector3.new, CFrame.new
local M = Enum.Material

local PlotService = {}

local Services

-- local layout (plot space: -Z faces the boulevard)
PlotService.FloorY = 0.3
local SHOWROOM_ROWS_Z = { -73, -52, -31, -10 }
local SPOT_COLUMNS = 10
local SPOT_SPACING = 10
local YARD_ROWS_Z = { 36, 64 } -- row 1 faces +Z (towards the aisle), row 2 faces -Z
local SPAWN_LOCAL = CF(0, 3.5, 10)

local ACCENTS = {
	Color3.fromRGB(64, 210, 255), Color3.fromRGB(255, 120, 60), Color3.fromRGB(140, 255, 120),
	Color3.fromRGB(255, 80, 180), Color3.fromRGB(255, 210, 70), Color3.fromRGB(150, 110, 255),
	Color3.fromRGB(80, 255, 220), Color3.fromRGB(255, 70, 80),
}

export type Plot = {
	index: number,
	cframe: CFrame,
	model: Model,
	yard: Folder,
	showroom: Folder,
	owner: Player?,
	accent: Color3,
	spotPads: { BasePart },
	spotStrips: { BasePart },
	signLabel: TextLabel,
	characterConnection: RBXScriptConnection?,
	building: Model?,
	buildingTier: number?,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

function PlotService.plotCFrame(index: number): CFrame
	local cfg = GameConfig.Plots
	local perSide = cfg.Count / 2
	local side = if index <= perSide then -1 else 1
	local k = (index - 1) % perSide -- 0..perSide-1 along the boulevard
	local half = perSide / 2
	-- plots leave a gap in the middle of the map for the Mega Market
	local j = if k < half then (half - 1 - k) else (k - half)
	local sign = if k < half then -1 else 1
	local z = sign * (cfg.CenterGap / 2 + cfg.Width / 2 + j * cfg.Spacing)
	local x = side * (cfg.BoulevardWidth / 2 + cfg.Depth / 2 + 6)
	return CF(x, 0, z) * CFrame.Angles(0, side * math.pi / 2, 0)
end

function PlotService.lotLocalCFrame(lotIndex: number): CFrame
	local yard = GameConfig.Yard
	local row = if lotIndex <= yard.PerRow then 1 else 2
	local col = (lotIndex - 1) % yard.PerRow + 1
	local x = (col - (yard.PerRow + 1) / 2) * yard.LotSpacing
	local cf = CF(x, PlotService.FloorY, YARD_ROWS_Z[row])
	if row == 1 then
		cf *= CFrame.Angles(0, math.pi, 0) -- nose towards +Z (the aisle)
	end
	return cf
end

function PlotService.spotLocalCFrame(spotIndex: number): CFrame
	local row = math.ceil(spotIndex / SPOT_COLUMNS)
	local col = (spotIndex - 1) % SPOT_COLUMNS + 1
	local x = (col - (SPOT_COLUMNS + 1) / 2) * SPOT_SPACING
	return CF(x, PlotService.FloorY, SHOWROOM_ROWS_Z[math.clamp(row, 1, #SHOWROOM_ROWS_Z)])
end

function PlotService.maxSpots(): number
	return SPOT_COLUMNS * #SHOWROOM_ROWS_Z
end

local function buildPlot(index: number, parent: Instance): Plot
	local cfg = GameConfig.Plots
	local base = PlotService.plotCFrame(index)
	local accent = ACCENTS[(index - 1) % #ACCENTS + 1]
	local model = Build.model(parent, "Plot_" .. index)
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	local W, D = cfg.Width, cfg.Depth

	local function P(name, size, localCF, color, material, props)
		return Build.part(model, name, size, base * localCF, color, material, props)
	end

	-- floors
	P("Base", V3(W, 1, D), CF(0, -0.3, 0), Color3.fromRGB(128, 130, 136), M.Concrete)
	P("ShowroomFloor", V3(W - 4, 0.1, 88), CF(0, 0.25, -40.5), Color3.fromRGB(36, 38, 44), M.Marble, { Reflectance = 0.14, CanCollide = false })
	P("Walkway", V3(W - 4, 0.1, 12), CF(0, 0.25, 9.8), Color3.fromRGB(196, 194, 188), M.Pavement, { CanCollide = false })
	P("YardFloor", V3(W - 4, 0.1, 78), CF(0, 0.25, 55), Color3.fromRGB(58, 60, 66), M.Asphalt, { CanCollide = false })
	P("AccentLine", V3(W - 4, 0.12, 0.4), CF(0, 0.27, 3.8), accent, M.Neon, { CanCollide = false })
	P("AccentLine", V3(W - 4, 0.12, 0.4), CF(0, 0.27, 15.8), accent, M.Neon, { CanCollide = false })

	-- fences
	for _, side in { -1, 1 } do
		P("SideWall", V3(1, 3, D), CF(side * (W / 2 - 0.5), 1.5, 0), Color3.fromRGB(210, 210, 204), M.Concrete)
		P("SideWallCap", V3(1.3, 0.25, D), CF(side * (W / 2 - 0.5), 3.1, 0), accent, M.Neon, { CanCollide = false })
		P("FrontRail", V3(W / 2 - 22, 2.4, 0.5), CF(side * (22 + (W / 2 - 22) / 2), 1.2, -D / 2 + 0.5), Color3.fromRGB(170, 200, 220), M.Glass, { Transparency = 0.5 })
	end
	P("BackWall", V3(W, 6, 1), CF(0, 3, D / 2 - 0.5), Color3.fromRGB(210, 210, 204), M.Concrete)

	-- entrance gate with the dealership sign (faces the boulevard: Front face = -Z)
	for _, side in { -1, 1 } do
		P("GatePillar", V3(2.4, 18, 2.4), CF(side * 21, 9, -D / 2 + 1), Color3.fromRGB(46, 48, 56), M.Metal)
		P("GateLight", V3(0.4, 16, 0.4), CF(side * 21, 9, -D / 2 - 0.25), accent, M.Neon, { CanCollide = false })
	end
	local sign = P("Sign", V3(44, 6, 1.2), CF(0, 17, -D / 2 + 1), Color3.fromRGB(16, 18, 22), M.SmoothPlastic)
	local signLabel = Build.sign(sign, Enum.NormalId.Front, "ВІЛЬНА ДІЛЯНКА", Color3.new(1, 1, 1), Enum.Font.GothamBlack, 14)
	P("SignTrim", V3(44.4, 0.3, 0.3), CF(0, 20.1, -D / 2 + 0.3), accent, M.Neon, { CanCollide = false })
	P("SignTrim", V3(44.4, 0.3, 0.3), CF(0, 13.9, -D / 2 + 0.3), accent, M.Neon, { CanCollide = false })

	-- showroom spots
	local spotPads, spotStrips = {}, {}
	for i = 1, PlotService.maxSpots() do
		local local_ = PlotService.spotLocalCFrame(i)
		spotPads[i] = P("SpotPad", V3(8.6, 0.06, 18), local_ * CF(0, 0.02, 0), Color3.fromRGB(56, 58, 66), M.SmoothPlastic, { CanCollide = false, Reflectance = 0.1 })
		spotStrips[i] = P("SpotStrip", V3(8.6, 0.08, 0.25), local_ * CF(0, 0.04, -9), Color3.fromRGB(70, 72, 80), M.SmoothPlastic, { CanCollide = false })
	end

	-- yard lot pads with numbers
	for lot = 1, GameConfig.Yard.Rows * GameConfig.Yard.PerRow do
		local local_ = PlotService.lotLocalCFrame(lot)
		P("LotPad", V3(GameConfig.Yard.LotSpacing - 0.6, 0.05, 19), local_ * CF(0, 0.02, 0), Color3.fromRGB(74, 76, 84), M.SmoothPlastic, { CanCollide = false })
		local marker = P("LotNumber", V3(3, 0.06, 1.6), local_ * CF(0, 0.05, -10.6), Color3.fromRGB(240, 240, 236), M.SmoothPlastic, { CanCollide = false })
		Build.sign(marker, Enum.NormalId.Top, string.format("%02d", lot), Color3.fromRGB(30, 30, 34), Enum.Font.GothamBlack, 30)
	end

	-- spawn marker + lamps + greenery
	P("HomePad", V3(0.2, 7, 7), SPAWN_LOCAL * CF(0, -3.15, 0) * CFrame.Angles(0, 0, math.pi / 2), accent, M.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.25 })
	for _, x in { -(W / 2 - 4), W / 2 - 4 } do
		for _, z in { 30, 70 } do -- the showroom building has its own lights
			Build.lamp(model, base * CF(x, 0.2, z) * CFrame.Angles(0, if x < 0 then -math.pi / 2 else math.pi / 2, 0), Color3.fromRGB(255, 236, 205))
		end
	end
	for _, x in { -40, -30, 30, 40 } do
		Build.tree(model, (base * CF(x, 0.2, -D / 2 + 5)).Position, 0.6)
	end

	local yard = Build.folder(model, "Yard")
	local showroom = Build.folder(model, "Showroom")

	return {
		index = index,
		cframe = base,
		model = model,
		yard = yard,
		showroom = showroom,
		owner = nil,
		accent = accent,
		spotPads = spotPads,
		spotStrips = spotStrips,
		signLabel = signLabel,
		characterConnection = nil,
		building = nil,
		buildingTier = nil,
	}
end

function PlotService.refreshSpots(plot: Plot, capacity: number)
	for i, pad in plot.spotPads do
		local active = i <= capacity
		pad.Color = if active then Color3.fromRGB(92, 96, 108) else Color3.fromRGB(44, 46, 52)
		pad.Transparency = if active then 0 else 0.35
		local strip = plot.spotStrips[i]
		strip.Color = if active then plot.accent else Color3.fromRGB(70, 72, 80)
		strip.Material = if active then M.Neon else M.SmoothPlastic
	end
end

-- Rebuilds the dealership building when the showroom level reaches a new tier.
-- Returns the previous tier when the building changed, otherwise nil.
function PlotService.setShowroomTier(plot: Plot, level: number, ownerName: string): number?
	local tier = GameConfig.showroomTier(level)
	if plot.buildingTier == tier and plot.building and plot.building.Parent then
		return nil
	end
	local previous = plot.buildingTier
	if plot.building then
		plot.building:Destroy()
	end
	local building = ShowroomBuilder.build(tier, plot.cframe, plot.accent, ownerName)
	building.Parent = plot.model
	plot.building = building
	plot.buildingTier = tier
	return previous or 0
end

function PlotService.spawnCFrame(plot: Plot): CFrame
	return plot.cframe * SPAWN_LOCAL * CFrame.Angles(0, math.pi, 0)
end

function PlotService.teleportTo(player: Player, target: CFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 5)
	end)
	if character.Parent then
		character:PivotTo(target)
	end
end

function PlotService.teleportHome(player: Player)
	local plot = byPlayer[player]
	if plot then
		PlotService.teleportTo(player, PlotService.spawnCFrame(plot))
	end
end

function PlotService.assign(player: Player): Plot?
	if byPlayer[player] then
		return byPlayer[player]
	end
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			byPlayer[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plot.signLabel.Text = string.upper(player.DisplayName) .. " MOTORS"
			plot.characterConnection = player.CharacterAdded:Connect(function()
				task.defer(PlotService.teleportHome, player)
			end)
			if player.Character then
				task.defer(PlotService.teleportHome, player)
			end
			return plot
		end
	end
	return nil
end

function PlotService.release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.owner = nil
	if plot.characterConnection then
		plot.characterConnection:Disconnect()
		plot.characterConnection = nil
	end
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.signLabel.Text = "ВІЛЬНА ДІЛЯНКА"
	plot.yard:ClearAllChildren()
	plot.showroom:ClearAllChildren()
	if plot.building then
		plot.building:Destroy()
		plot.building = nil
	end
	plot.buildingTier = nil
	PlotService.refreshSpots(plot, 0)
end

function PlotService.getPlot(player: Player): Plot?
	return byPlayer[player]
end

function PlotService.init(services)
	Services = services
	local parent = Services.WorldService.Folders.PlayerPlots
	for i = 1, GameConfig.Plots.Count do
		plots[i] = buildPlot(i, parent)
		PlotService.refreshSpots(plots[i], 0)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- PlayerDataService releases data first (its ProfileReleasing handlers run synchronously)
		task.defer(PlotService.release, player)
	end)
end

return PlotService

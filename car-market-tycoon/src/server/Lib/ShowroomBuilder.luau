-- Dealership buildings that grow with the showroom level:
-- 1 small garage -> 2 big garage -> 3 glass dealership -> 4 premium showroom -> 5 two-storey luxury centre.
-- Coordinates are in plot space (-Z faces the boulevard). Display spots: 10 columns (x = -45..45,
-- step 10) in rows at z = -73, -52, -31, -10. NPC buyers enter through a gap around x = 0.
local Build = require(script.Parent.Build)

local V3, CF = Vector3.new, CFrame.new
local M = Enum.Material
local CYL_UP = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y

local ShowroomBuilder = {}

local ROWS_Z = { -73, -52, -31, -10 }
local COLUMN_ORDER = { 5, 6, 4, 7, 3, 8, 2, 9, 1, 10 } -- spots fill from the centre outwards

local function spotPositions(count: number)
	local list = {}
	for i = 1, count do
		local row = math.ceil(i / 10)
		local col = COLUMN_ORDER[(i - 1) % 10 + 1]
		table.insert(list, Vector3.new((col - 5.5) * 10, 0, ROWS_Z[row]))
	end
	return list
end

function ShowroomBuilder.build(tier: number, base: CFrame, accent: Color3, ownerName: string): Model
	local model = Instance.new("Model")
	model.Name = "ShowroomBuilding"
	model:SetAttribute("Tier", tier)

	local function P(name: string, size: Vector3, localCF: CFrame, color: Color3, material: Enum.Material, props: { [string]: any }?)
		return Build.part(model, name, size, base * localCF, color, material, props)
	end
	-- box between two corners on the floor
	local function box(name, x0, x1, z0, z1, y0, y1, color, material, props)
		return P(name, V3(math.abs(x1 - x0), y1 - y0, math.abs(z1 - z0)), CF((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, props)
	end
	local function glass(name, x0, x1, z0, z1, y0, y1, tint)
		return box(name, x0, x1, z0, z1, y0, y1, tint or Color3.fromRGB(160, 200, 225), M.Glass, { Transparency = 0.62, Reflectance = 0.2 })
	end
	local function lamp(x: number, z: number, y: number, color: Color3, range: number, size: Vector3?)
		local panel = P("LightPanel", size or V3(6, 0.25, 1.4), CF(x, y, z), color, M.Neon, { CanCollide = false })
		Build.spotLight(panel, color, range, 1.4, 120, Enum.NormalId.Bottom)
		return panel
	end
	local function plant(x: number, z: number, scale: number)
		P("Pot", V3(1.6, 2.2, 2.2) * scale, CF(x, 0.3 + 0.8 * scale, z) * CYL_UP, Color3.fromRGB(40, 40, 44), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
		P("Bush", V3(3, 3, 3) * scale, CF(x, 0.3 + 2.8 * scale, z), Color3.fromRGB(60, 120, 60), M.Grass, { Shape = Enum.PartType.Ball, CanCollide = false })
	end
	local function sign(text: string, width: number, height: number, cf: CFrame, textColor: Color3, frame: Color3)
		local board = P("Sign", V3(width, height, 0.5), cf, Color3.fromRGB(14, 14, 18), M.SmoothPlastic)
		Build.sign(board, Enum.NormalId.Front, text, textColor, Enum.Font.GothamBlack, 12)
		P("SignTrim", V3(width + 0.4, 0.3, 0.3), cf * CF(0, height / 2 + 0.15, -0.3), frame, M.Neon, { CanCollide = false })
		P("SignTrim", V3(width + 0.4, 0.3, 0.3), cf * CF(0, -height / 2 - 0.15, -0.3), frame, M.Neon, { CanCollide = false })
		return board
	end
	local function rollDoor(x0: number, x1: number, z: number, y: number)
		P("RollerDrum", V3(math.abs(x1 - x0) - 0.4, 1.4, 1.4), CF((x0 + x1) / 2, y, z), Color3.fromRGB(150, 154, 160), M.Metal, { Shape = Enum.PartType.Cylinder })
	end
	local function podiums(count: number, ring: Color3)
		for _, p in spotPositions(count) do
			P("Turntable", V3(0.14, 9.5, 9.5), CF(p.X, 0.37, p.Z) * CYL_UP, Color3.fromRGB(26, 26, 30), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CanCollide = false, Reflectance = 0.25 })
			P("TurntableRing", V3(0.1, 10.2, 10.2), CF(p.X, 0.36, p.Z) * CYL_UP, ring, M.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		end
	end
	local name = string.upper(ownerName)

	if tier == 1 then
		-- small corrugated-metal garage in the centre (spots 1-2) ------------------------------------------
		local x0, x1, z0, z1, h = -12, 12, -83, -62, 8 -- centred on spots 1-2
		local metal = Color3.fromRGB(122, 126, 132)
		box("GarageFloor", x0, x1, z0, z1, 0.28, 0.34, Color3.fromRGB(104, 104, 106), M.Concrete)
		box("OilStain", -3, 2, -77, -70, 0.34, 0.35, Color3.fromRGB(60, 58, 56), M.Concrete, { CanCollide = false })
		box("WallLeft", x0 - 0.5, x0, z0, z1, 0.3, h, metal, M.CorrodedMetal)
		box("WallRight", x1, x1 + 0.5, z0, z1, 0.3, h, metal, M.CorrodedMetal)
		box("WallBack", x0 - 0.5, x1 + 0.5, z1, z1 + 0.5, 0.3, h, metal, M.CorrodedMetal)
		box("Roof", x0 - 1, x1 + 1, z0 - 1.2, z1 + 0.8, h, h + 0.5, Color3.fromRGB(70, 72, 78), M.CorrodedMetal)
		box("Gutter", x0 - 1, x1 + 1, z0 - 1.4, z0 - 1.1, h - 0.2, h + 0.1, Color3.fromRGB(150, 150, 150), M.Metal)
		box("Header", x0, x1, z0 - 0.3, z0 + 0.3, h - 1.5, h, Color3.fromRGB(90, 92, 98), M.Metal)
		rollDoor(x0, x1, z0 + 0.6, h - 0.8)
		for _, x in { x0 + 0.3, x1 - 0.3 } do
			box("DoorRail", x - 0.15, x + 0.15, z0 - 0.15, z0 + 0.15, 0.3, h - 1.5, Color3.fromRGB(70, 70, 74), M.Metal)
		end
		-- workbench, pegboard with tools, tyres, barrel
		box("Workbench", -11.5, -8.6, -63.6, -62.5, 0.3, 3.2, Color3.fromRGB(120, 86, 56), M.Wood)
		box("Pegboard", -11.4, -4, -62.45, -62.35, 3.8, 6.6, Color3.fromRGB(150, 116, 80), M.WoodPlanks)
		for i, c in { Color3.fromRGB(200, 40, 40), Color3.fromRGB(240, 200, 40), Color3.fromRGB(40, 110, 200), Color3.fromRGB(60, 60, 64) } do
			box("Tool", -10.6 + i * 1.4, -10.3 + i * 1.4, -62.6, -62.45, 4.4, 6, c, M.SmoothPlastic, { CanCollide = false })
		end
		for k = 0, 2 do
			P("Tyre", V3(0.9, 2.4, 2.4), CF(-10.6, 0.75 + k * 0.92, -70) * CYL_UP, Color3.fromRGB(24, 24, 26), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
		end
		P("Barrel", V3(2.6, 1.8, 1.8), CF(10.4, 1.6, -66) * CYL_UP, Color3.fromRGB(190, 40, 30), M.Metal, { Shape = Enum.PartType.Cylinder })
		P("Cable", V3(0.08, 1.2, 0.08), CF(0, h - 0.6, -72.5), Color3.fromRGB(20, 20, 20), M.SmoothPlastic, { CanCollide = false })
		local bulb = P("Bulb", V3(0.7, 0.7, 0.7), CF(0, h - 1.4, -72.5), Color3.fromRGB(255, 220, 160), M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
		Build.pointLight(bulb, Color3.fromRGB(255, 214, 160), 24, 1.6)
		sign("ГАРАЖ " .. name, 18, 2.4, CF(0, h + 1.8, z0 - 1.4), Color3.fromRGB(255, 220, 160), accent)
	elseif tier == 2 then
		-- large brick garage with five roller-door bays (row 1) -------------------------------------
		local x0, x1, z0, z1, h = -56, 56, -86, -62, 10 -- front kept behind the buyer lane (z = -83.5)
		local brick = Color3.fromRGB(150, 84, 64)
		box("GarageFloor", x0, x1, z0, z1, 0.28, 0.34, Color3.fromRGB(120, 122, 126), M.Concrete)
		box("WallLeft", x0 - 0.8, x0, z0, z1, 0.3, h, brick, M.Brick)
		box("WallRight", x1, x1 + 0.8, z0, z1, 0.3, h, brick, M.Brick)
		box("WallBack", x0 - 0.8, x1 + 0.8, z1, z1 + 0.8, 0.3, h, brick, M.Brick)
		box("Header", x0 - 0.8, x1 + 0.8, z0 - 0.4, z0 + 0.4, h - 1.6, h, brick, M.Brick)
		box("Roof", x0 - 1.5, x1 + 1.5, z0 - 1.5, z1 + 1.5, h, h + 0.6, Color3.fromRGB(60, 62, 68), M.Metal)
		for _, x in { -36, -12, 12, 36 } do
			box("Skylight", x - 6, x + 6, -77, -69, h + 0.6, h + 0.7, Color3.fromRGB(180, 210, 230), M.Glass, { Transparency = 0.4 })
		end
		local bays = { -56, -30, -10, 10, 30, 56 }
		for i = 1, #bays do
			box("Pillar", bays[i] - 0.7, bays[i] + 0.7, z0 - 0.7, z0 + 0.7, 0.3, h - 1.6, brick, M.Brick)
			if i < #bays then
				rollDoor(bays[i] + 0.7, bays[i + 1] - 0.7, z0 + 0.9, h - 0.9)
				box("BayLight", bays[i] + 2, bays[i + 1] - 2, z0 - 0.5, z0 - 0.3, h - 1.75, h - 1.6, Color3.fromRGB(255, 240, 210), M.Neon, { CanCollide = false })
			end
		end
		for _, x in { -40, -20, 0, 20, 40 } do
			lamp(x, -73, h - 0.4, Color3.fromRGB(235, 245, 255), 28, V3(8, 0.2, 0.6))
		end
		for _, x in { -51, -30, -10, 10, 30, 51 } do
			box("ToolCabinet", x - 1.4, x + 1.4, -63.4, -62.2, 0.3, 3.4, Color3.fromRGB(200, 30, 36), M.Metal)
		end
		box("Stripe", x0, x1, z0 - 0.45, z0 - 0.42, 1, 1.4, accent, M.Neon, { CanCollide = false })
		sign(name .. " AUTO", 40, 4, CF(0, h + 2.6, z0 - 1.6), Color3.new(1, 1, 1), accent)
	elseif tier == 3 then
		-- glass dealership (rows 1-2) ---------------------------------------------------------------------
		local x0, x1, z0, z1, h = -57, 57, -86, -40, 14
		local steel = Color3.fromRGB(48, 52, 60)
		box("ShowroomFloor", x0, x1, z0, z1, 0.28, 0.33, Color3.fromRGB(214, 214, 218), M.Marble, { Reflectance = 0.12 })
		for _, x in { x0, -38, -19, -8, 8, 19, 38, x1 } do
			box("Column", x - 0.6, x + 0.6, z0 - 0.6, z0 + 0.6, 0.3, h, steel, M.Metal)
			box("ColumnBack", x - 0.6, x + 0.6, z1 - 0.6, z1 + 0.6, 0.3, h, steel, M.Metal)
		end
		glass("FrontGlass", x0, -8, z0 - 0.2, z0 + 0.2, 0.3, h)
		glass("FrontGlass", 8, x1, z0 - 0.2, z0 + 0.2, 0.3, h)
		box("EntranceHeader", -8, 8, z0 - 0.4, z0 + 0.4, 9, h, steel, M.Metal)
		glass("SideGlass", x0 - 0.2, x0 + 0.2, z0, z1, 0.3, h)
		glass("SideGlass", x1 - 0.2, x1 + 0.2, z0, z1, 0.3, h)
		box("BackWall", x0, -6, z1, z1 + 0.6, 0.3, h, Color3.fromRGB(236, 236, 232), M.SmoothPlastic)
		box("BackWall", 6, x1, z1, z1 + 0.6, 0.3, h, Color3.fromRGB(236, 236, 232), M.SmoothPlastic)
		box("BackHeader", -6, 6, z1, z1 + 0.6, 9, h, Color3.fromRGB(236, 236, 232), M.SmoothPlastic)
		-- roof: solid ring + glass skylight
		box("RoofFront", x0 - 1, x1 + 1, z0 - 1, z0 + 6, h, h + 0.8, steel, M.Metal)
		box("RoofBack", x0 - 1, x1 + 1, z1 - 6, z1 + 1, h, h + 0.8, steel, M.Metal)
		box("RoofLeft", x0 - 1, x0 + 6, z0 + 6, z1 - 6, h, h + 0.8, steel, M.Metal)
		box("RoofRight", x1 - 6, x1 + 1, z0 + 6, z1 - 6, h, h + 0.8, steel, M.Metal)
		box("Skylight", x0 + 6, x1 - 6, z0 + 6, z1 - 6, h + 0.2, h + 0.4, Color3.fromRGB(190, 220, 240), M.Glass, { Transparency = 0.45 })
		box("RoofEdgeGlow", x0 - 1, x1 + 1, z0 - 1.05, z0 - 0.95, h + 0.3, h + 0.5, accent, M.Neon, { CanCollide = false })
		box("Canopy", -10, 10, z0 - 6, z0, 9.2, 9.7, steel, M.Metal)
		for _, x in { -9, 9 } do
			box("CanopyPost", x - 0.3, x + 0.3, z0 - 5.8, z0 - 5.2, 0.3, 9.2, steel, M.Metal)
		end
		for _, x in { -40, -14, 14, 40 } do
			for _, z in { -78, -50 } do
				lamp(x, z, h - 0.3, Color3.fromRGB(255, 246, 232), 30)
			end
		end
		box("Reception", 50.5, 55.5, -80, -76, 0.3, 3.4, Color3.fromRGB(30, 32, 38), M.Marble, { Reflectance = 0.2 })
		box("ReceptionTop", 50.3, 55.7, -80.2, -75.8, 3.4, 3.6, accent, M.Neon, { CanCollide = false })
		for _, p in { { -53, -83 }, { 53, -46 }, { -53, -46 } } do
			plant(p[1], p[2], 0.9)
		end
		sign(name .. " MOTORS", 54, 5, CF(0, h + 3.6, z0 - 0.8), Color3.new(1, 1, 1), accent)
	else
		local premium = tier == 4
		local x0, x1 = if premium then -58 else -59, if premium then 58 else 59
		local z0, z1 = if premium then -87 else -88, if premium then -19 else 2
		local h = if premium then 16 else 24
		local gold = Color3.fromRGB(230, 182, 70)
		local trim = if premium then accent else gold
		local floorColor = if premium then Color3.fromRGB(40, 42, 48) else Color3.fromRGB(16, 16, 18)
		local columnColor = if premium then Color3.fromRGB(240, 240, 236) else Color3.fromRGB(236, 226, 206)

		box("ShowroomFloor", x0, x1, z0, z1, 0.28, 0.33, floorColor, M.Marble, { Reflectance = if premium then 0.2 else 0.28 })
		-- inlay lines along the buyer lanes
		for _, z in { -83.5, -62.5, -41.5, -20.5 } do
			if z > z0 and z < z1 then
				box("Inlay", x0 + 2, x1 - 2, z - 0.15, z + 0.15, 0.33, 0.345, trim, M.Neon, { CanCollide = false })
			end
		end
		podiums(if premium then 30 else 40, trim)

		-- round columns along the front and back
		for _, x in { x0, -40, -22, -11, 11, 22, 40, x1 } do
			for _, z in { z0, z1 } do
				P("Column", V3(h, 1.6, 1.6), CF(x, 0.3 + h / 2, z) * CYL_UP, columnColor, M.Marble, { Shape = Enum.PartType.Cylinder })
				P("ColumnCap", V3(0.5, 2.2, 2.2), CF(x, h - 0.2, z) * CYL_UP, trim, M.Metal, { Shape = Enum.PartType.Cylinder, Reflectance = 0.3 })
			end
		end
		glass("FrontGlass", x0, -11, z0 - 0.2, z0 + 0.2, 0.3, h)
		glass("FrontGlass", 11, x1, z0 - 0.2, z0 + 0.2, 0.3, h)
		box("Portal", -11, 11, z0 - 0.5, z0 + 0.5, 11, h, Color3.fromRGB(20, 20, 24), M.SmoothPlastic)
		for _, x in { -10.6, 10.6 } do
			box("PortalGlow", x - 0.2, x + 0.2, z0 - 0.7, z0 - 0.5, 0.3, 11, trim, M.Neon, { CanCollide = false })
		end
		box("PortalGlowTop", -10.8, 10.8, z0 - 0.7, z0 - 0.5, 10.8, 11.2, trim, M.Neon, { CanCollide = false })
		glass("SideGlass", x0 - 0.2, x0 + 0.2, z0, z1, 0.3, h)
		glass("SideGlass", x1 - 0.2, x1 + 0.2, z0, z1, 0.3, h)
		box("BackWall", x0, -7, z1, z1 + 0.6, 0.3, h, Color3.fromRGB(240, 240, 236), M.SmoothPlastic)
		box("BackWall", 7, x1, z1, z1 + 0.6, 0.3, h, Color3.fromRGB(240, 240, 236), M.SmoothPlastic)
		box("BackHeader", -7, 7, z1, z1 + 0.6, 10, h, Color3.fromRGB(240, 240, 236), M.SmoothPlastic)

		-- roof: beam grid with glass panels
		box("RoofGlass", x0, x1, z0, z1, h + 0.1, h + 0.3, Color3.fromRGB(190, 220, 240), M.Glass, { Transparency = 0.5 })
		local beamColor = if premium then Color3.fromRGB(236, 236, 236) else gold
		local x = x0
		while x <= x1 + 0.01 do
			box("RoofBeam", x - 0.4, x + 0.4, z0, z1, h + 0.3, h + 1, beamColor, M.Metal)
			x += (x1 - x0) / 8
		end
		box("RoofEdge", x0 - 1, x1 + 1, z0 - 1, z0 + 1, h, h + 1.4, Color3.fromRGB(24, 24, 28), M.Metal)
		box("RoofEdgeGlow", x0 - 1, x1 + 1, z0 - 1.1, z0 - 1, h + 0.5, h + 0.8, trim, M.Neon, { CanCollide = false })
		for _, lx in { -36, -12, 12, 36 } do
			local z = z0 + 10
			while z < z1 - 4 do
				lamp(lx, z, h - 0.4, Color3.fromRGB(255, 248, 236), 34, V3(8, 0.2, 2))
				z += 22
			end
		end

		-- entrance canopy, red carpet, pylons
		box("Canopy", -14, 14, z0 - 7, z0, 10.6, 11.2, Color3.fromRGB(20, 20, 24), M.SmoothPlastic)
		box("CanopyGlow", -14, 14, z0 - 7.1, z0 - 7, 10.6, 11.2, trim, M.Neon, { CanCollide = false })
		for _, cx in { -13, 13 } do
			P("CanopyColumn", V3(10.3, 1, 1), CF(cx, 0.3 + 10.3 / 2, z0 - 6.5) * CYL_UP, trim, M.Metal, { Shape = Enum.PartType.Cylinder, Reflectance = 0.3 })
		end
		box("RedCarpet", -4, 4, -94, z0, 0.3, 0.36, Color3.fromRGB(150, 16, 24), M.Fabric, { CanCollide = false })
		for _, px in { x0 - 0.5, x1 + 0.5 } do
			box("Pylon", px - 0.9, px + 0.9, z0 - 1.5, z0 + 0.3, 0.3, h + 6, Color3.fromRGB(18, 18, 22), M.SmoothPlastic)
			box("PylonGlow", px - 0.2, px + 0.2, z0 - 1.6, z0 - 1.5, 2, h + 5, trim, M.Neon, { CanCollide = false })
		end

		-- lounges
		for _, side in { -1, 1 } do
			local lx = side * (if premium then 53.5 else 55)
			box("Sofa", lx - 1.6, lx + 1.6, -70, -62, 0.3, 1.6, Color3.fromRGB(30, 30, 34), M.Leather)
			box("SofaBack", lx + side * 1.2 - 0.4, lx + side * 1.2 + 0.4, -70, -62, 1.6, 3.2, Color3.fromRGB(30, 30, 34), M.Leather)
			P("CoffeeTable", V3(0.6, 3, 3), CF(lx - side * 3, 1.1, -66) * CYL_UP, Color3.fromRGB(20, 20, 24), M.Glass, { Shape = Enum.PartType.Cylinder, Reflectance = 0.3 })
			plant(lx, -84, 1)
		end
		box("Reception", -57, -51, -80, -76, 0.3, 3.4, Color3.fromRGB(20, 20, 24), M.Marble, { Reflectance = 0.25 })
		box("ReceptionTop", -57.2, -50.8, -80.2, -75.8, 3.4, 3.6, trim, M.Neon, { CanCollide = false })

		if not premium then
			-- second floor: mezzanines with glass railings, a ramp and the VIP lounge
			local deckY = 12
			for _, side in { -1, 1 } do
				local inner = side * 51
				local outer = side * 59
				box("Mezzanine", math.min(inner, outer), math.max(inner, outer), -82, -24, deckY - 0.6, deckY, Color3.fromRGB(28, 28, 32), M.Marble, { Reflectance = 0.2 })
				box("MezzanineEdge", inner - 0.15, inner + 0.15, -82, -24, deckY - 0.6, deckY, gold, M.Neon, { CanCollide = false })
				glass("Railing", inner - 0.1, inner + 0.1, -82, -24, deckY, deckY + 3)
				for _, z in { -76, -60, -44, -30 } do
					box("DeckSofa", side * 56 - 1.4, side * 56 + 1.4, z - 3, z + 3, deckY, deckY + 1.4, Color3.fromRGB(110, 20, 30), M.Leather)
				end
			end
			-- ramp up to the right mezzanine
			Build.part(model, "Ramp", V3(7, deckY, 20), base * CF(55, 0.3 + deckY / 2, -14) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(36, 36, 40), M.Marble, { ClassName = "WedgePart" })
			box("Bar", -58, -52, -55, -49, deckY, deckY + 3.4, Color3.fromRGB(20, 20, 24), M.Marble, { Reflectance = 0.25 })
			box("BarTop", -58.2, -51.8, -55.2, -48.8, deckY + 3.4, deckY + 3.6, gold, M.Neon, { CanCollide = false })
			local vip = box("VipSign", -58.6, -58.4, -60, -42, deckY + 4.5, deckY + 7.5, Color3.fromRGB(14, 14, 18), M.SmoothPlastic)
			Build.sign(vip, Enum.NormalId.Right, "VIP LOUNGE", gold, Enum.Font.GothamBlack, 12)
			-- chandeliers
			for _, cx in { -25, 0, 25 } do
				local cz = -45
				P("ChandelierRod", V3(0.15, 3, 0.15), CF(cx, h - 1.5, cz), gold, M.Metal, { CanCollide = false })
				local core = P("Chandelier", V3(2.4, 2.4, 2.4), CF(cx, h - 3.6, cz), Color3.fromRGB(255, 240, 210), M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
				Build.pointLight(core, Color3.fromRGB(255, 236, 200), 40, 1.6)
				for k = 1, 8 do
					local a = (k / 8) * math.pi * 2
					P("Crystal", V3(0.7, 0.7, 0.7), CF(cx + math.cos(a) * 2.4, h - 4.4, cz + math.sin(a) * 2.4), Color3.fromRGB(255, 250, 240), M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
				end
			end
		end

		sign(name .. (if premium then " PREMIUM" else " LUXURY"), if premium then 60 else 72, if premium then 5.5 else 7, CF(0, h + (if premium then 4 else 5), z0 - 1.2), if premium then Color3.new(1, 1, 1) else gold, trim)
	end

	return model
end

return ShowroomBuilder

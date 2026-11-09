-- Builds decoration models (used by the server for placed decor and by the client for previews).
-- Pivot: ground centre. Front of the item faces -Z.
local DecorBuilder = {}

local V3, CF = Vector3.new, CFrame.new
local M = Enum.Material
local CYL_UP = CFrame.Angles(0, 0, math.pi / 2)

function DecorBuilder.build(key: string, accent: Color3?, label: string?): Model
	local accentColor = accent or Color3.fromRGB(64, 210, 255)
	local model = Instance.new("Model")
	model.Name = "Decor_" .. key
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.Size = V3(1, 1, 1)
	root.CFrame = CF(0, 0.5, 0)
	root.PivotOffset = CF(0, -0.5, 0)
	root.Parent = model
	model.PrimaryPart = root

	local function P(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?)
		local p = Instance.new((props and props.ClassName) or "Part")
		p.Name = name
		p.Anchored = true
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or M.SmoothPlastic
		if props then
			for k, v in props do
				if k ~= "ClassName" then
					(p :: any)[k] = v
				end
			end
		end
		p.Parent = model
		return p
	end
	local function cyl(name, height, diameter, cf, color, material, props)
		local p = P(name, V3(height, diameter, diameter), cf * CYL_UP, color, material, props)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function ball(name, d, pos, color, material, props)
		local p = P(name, V3(d, d, d), CF(pos), color, material, props)
		p.Shape = Enum.PartType.Ball
		return p
	end
	local GREEN = Color3.fromRGB(62, 124, 58)
	local TRUNK = Color3.fromRGB(96, 70, 48)

	if key == "bush" then
		ball("Bush", 2.6, V3(0, 1.1, 0), GREEN, M.Grass, { CanCollide = false })
		ball("Bush2", 1.8, V3(0.7, 1.6, 0.3), GREEN:Lerp(Color3.new(1, 1, 0), 0.08), M.Grass, { CanCollide = false })
	elseif key == "cones" then
		for i, x in { -0.8, 0, 0.8 } do
			local z = if i == 2 then 0.5 else -0.2
			cyl("ConeBase", 0.12, 1, CF(x, 0.06, z), Color3.fromRGB(20, 20, 20))
			for k = 0, 3 do
				local d = 0.75 - k * 0.17
				cyl("Cone", 0.3, d, CF(x, 0.27 + k * 0.3, z), if k == 1 then Color3.new(1, 1, 1) else Color3.fromRGB(255, 110, 20))
			end
		end
	elseif key == "tires" then
		for k = 0, 3 do
			cyl("Tire", 0.85, 2.3, CF((k % 2) * 0.15, 0.43 + k * 0.86, 0), Color3.fromRGB(24, 24, 26))
			cyl("TireRim", 0.87, 1.3, CF((k % 2) * 0.15, 0.43 + k * 0.86, 0), Color3.fromRGB(70, 70, 74))
		end
	elseif key == "rock" then
		P("Rock", V3(2.6, 1.4, 2), CF(0, 0.6, 0) * CFrame.Angles(0.1, 0.4, 0.15), Color3.fromRGB(120, 116, 110), M.Slate)
		P("Rock2", V3(1.4, 1, 1.2), CF(0.9, 0.5, 0.6) * CFrame.Angles(0.3, 1.2, 0.1), Color3.fromRGB(104, 100, 96), M.Slate)
	elseif key == "hedge" then
		P("Hedge", V3(4.2, 2.2, 1.4), CF(0, 1.1, 0), GREEN, M.Grass)
	elseif key == "flowers" then
		P("Bed", V3(3.4, 0.5, 2.2), CF(0, 0.25, 0), Color3.fromRGB(120, 90, 60), M.Brick)
		P("Soil", V3(3.1, 0.1, 1.9), CF(0, 0.52, 0), Color3.fromRGB(70, 50, 34), M.Ground)
		local colors = { Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 210, 60), Color3.fromRGB(180, 90, 255), Color3.fromRGB(255, 255, 255) }
		for i = 1, 12 do
			local x = ((i - 1) % 4 - 1.5) * 0.7
			local z = (math.floor((i - 1) / 4) - 1) * 0.55
			cyl("Stem", 0.5, 0.08, CF(x, 0.8, z), GREEN)
			ball("Flower", 0.4, V3(x, 1.1, z), colors[(i % #colors) + 1], M.SmoothPlastic, { CanCollide = false })
		end
	elseif key == "bench" then
		for k = 0, 2 do
			P("Seat", V3(3.8, 0.12, 0.32), CF(0, 1.1, -0.35 + k * 0.36), Color3.fromRGB(150, 100, 60), M.Wood)
		end
		for k = 0, 1 do
			P("Back", V3(3.8, 0.3, 0.1), CF(0, 1.6 + k * 0.45, 0.6) * CFrame.Angles(-0.15, 0, 0), Color3.fromRGB(150, 100, 60), M.Wood)
		end
		for _, x in { -1.6, 1.6 } do
			P("Leg", V3(0.15, 1.1, 1.2), CF(x, 0.55, 0), Color3.fromRGB(40, 42, 46), M.Metal)
			P("BackLeg", V3(0.12, 1.2, 0.12), CF(x, 1.7, 0.62), Color3.fromRGB(40, 42, 46), M.Metal)
		end
	elseif key == "tree_oak" then
		cyl("Trunk", 5, 1.1, CF(0, 2.5, 0), TRUNK, M.Wood)
		ball("Crown", 6, V3(0, 6.2, 0), GREEN, M.Grass, { CanCollide = false })
		ball("Crown2", 4.2, V3(1.6, 7.4, 0.8), GREEN:Lerp(Color3.new(0, 0, 0), 0.08), M.Grass, { CanCollide = false })
		ball("Crown3", 3.8, V3(-1.5, 7, -0.9), GREEN:Lerp(Color3.new(1, 1, 0), 0.06), M.Grass, { CanCollide = false })
	elseif key == "tree_pine" then
		cyl("Trunk", 2.4, 0.8, CF(0, 1.2, 0), TRUNK, M.Wood)
		for k = 0, 4 do
			local d = 4.6 - k * 0.85
			cyl("Needles", 1.5, d, CF(0, 2.4 + k * 1.25, 0), Color3.fromRGB(34, 84, 50), M.Grass, { CanCollide = false })
		end
		ball("Top", 0.8, V3(0, 8.7, 0), Color3.fromRGB(34, 84, 50), M.Grass, { CanCollide = false })
	elseif key == "lamp" then
		cyl("Pole", 9, 0.4, CF(0, 4.5, 0), Color3.fromRGB(36, 38, 44), M.Metal)
		cyl("Base", 0.6, 1.2, CF(0, 0.3, 0), Color3.fromRGB(36, 38, 44), M.Metal)
		local head = ball("Lantern", 1.2, V3(0, 9.4, 0), Color3.fromRGB(255, 236, 196), M.Neon, { CanCollide = false })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 226, 180)
		light.Range = 18
		light.Brightness = 1.5
		light.Parent = head
	elseif key == "planter" then
		P("Planter", V3(2.6, 1.4, 2.6), CF(0, 0.7, 0), Color3.fromRGB(230, 230, 226), M.Concrete)
		cyl("Trunk", 2.8, 0.4, CF(0, 2.6, 0), TRUNK, M.Wood)
		ball("Crown", 2.8, V3(0, 4.4, 0), GREEN, M.Grass, { CanCollide = false })
	elseif key == "flag" then
		cyl("Pole", 12, 0.3, CF(0, 6, 0), Color3.fromRGB(220, 220, 224), M.Metal)
		ball("Finial", 0.5, V3(0, 12.2, 0), Color3.fromRGB(230, 182, 70), M.Metal)
		local flag = P("Flag", V3(0.08, 2.4, 3.6), CF(0, 10.5, 1.85), accentColor, M.Fabric)
		flag:SetAttribute("Flap", 1)
	elseif key == "palm" then
		local y = 0
		for k = 0, 6 do
			cyl("Trunk", 1.3, 0.75 - k * 0.04, CF(k * 0.12, y + 0.65, 0) * CFrame.Angles(0, 0, -0.04 * k), Color3.fromRGB(140, 104, 70), M.Wood)
			y += 1.25
		end
		for k = 1, 7 do
			local a = (k / 7) * math.pi * 2
			P("Leaf", V3(0.15, 0.9, 4.2), CF(0.8, y + 0.2, 0) * CFrame.Angles(0, a, 0) * CF(0, 0, -1.9) * CFrame.Angles(-0.35, 0, 0), Color3.fromRGB(70, 140, 60), M.Grass, { CanCollide = false })
		end
		ball("Coconuts", 0.9, V3(0.8, y - 0.2, 0), Color3.fromRGB(90, 64, 40), M.SmoothPlastic)
	elseif key == "neon_sale" then
		for _, x in { -1.6, 1.6 } do
			P("Post", V3(0.25, 3, 0.25), CF(x, 1.5, 0), Color3.fromRGB(30, 30, 34), M.Metal)
		end
		local board = P("Board", V3(4, 1.8, 0.3), CF(0, 3.6, 0), Color3.fromRGB(14, 14, 18), M.SmoothPlastic)
		P("Frame", V3(4.2, 0.12, 0.35), CF(0, 4.5, 0), Color3.fromRGB(255, 60, 150), M.Neon, { CanCollide = false })
		P("Frame", V3(4.2, 0.12, 0.35), CF(0, 2.7, 0), Color3.fromRGB(255, 60, 150), M.Neon, { CanCollide = false })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.Text = "SALE"
		text.TextColor3 = Color3.fromRGB(255, 90, 170)
		text.Parent = gui
		gui.Parent = board
	elseif key == "balloons" then
		local colors = { Color3.fromRGB(255, 60, 70), Color3.fromRGB(255, 255, 255), accentColor }
		for i = 0, 16 do
			local a = math.pi * i / 16
			local x = math.cos(a) * 2.8
			local y = math.sin(a) * 4.2 + 0.6
			ball("Balloon", 0.9, V3(x, y, 0), colors[(i % #colors) + 1], M.SmoothPlastic, { CanCollide = false, Reflectance = 0.2 })
		end
		for _, x in { -2.8, 2.8 } do
			P("Weight", V3(0.8, 0.6, 0.8), CF(x, 0.3, 0), Color3.fromRGB(40, 40, 44), M.Metal)
		end
	elseif key == "searchlight" then
		P("Base", V3(2, 1, 2), CF(0, 0.5, 0), Color3.fromRGB(40, 42, 48), M.Metal)
		local head = cyl("Head", 1.4, 1.4, CF(0, 1.6, 0) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(60, 62, 68), M.Metal)
		local beam = P("Beam", V3(40, 1.2, 1.2), CF(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2 - 0.35) * CF(20.5, 0, 0), Color3.fromRGB(255, 250, 220), M.Neon, { CanCollide = false, Transparency = 0.82, CastShadow = false })
		beam.Shape = Enum.PartType.Cylinder
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Right
		light.Range = 40
		light.Brightness = 3
		light.Angle = 20
		light.Parent = head
	elseif key == "billboard" then
		for _, x in { -3, 3 } do
			P("Leg", V3(0.6, 8, 0.6), CF(x, 4, 0), Color3.fromRGB(50, 52, 58), M.Metal)
		end
		local board = P("Board", V3(8.4, 4, 0.4), CF(0, 9.6, 0), Color3.fromRGB(14, 14, 18), M.SmoothPlastic)
		P("Trim", V3(8.8, 0.25, 0.5), CF(0, 11.7, 0), accentColor, M.Neon, { CanCollide = false })
		P("Trim", V3(8.8, 0.25, 0.5), CF(0, 7.5, 0), accentColor, M.Neon, { CanCollide = false })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.Text = (label or "CAR MARKET") .. "\nНАЙКРАЩІ АВТО"
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Parent = gui
		gui.Parent = board
	elseif key == "fountain" then
		cyl("Pool", 0.9, 9, CF(0, 0.45, 0), Color3.fromRGB(210, 210, 206), M.Marble)
		cyl("Water", 0.2, 8.2, CF(0, 0.85, 0), Color3.fromRGB(80, 170, 230), M.Glass, { Transparency = 0.3, CanCollide = false })
		cyl("Column", 2.4, 1.2, CF(0, 2, 0), Color3.fromRGB(220, 220, 216), M.Marble)
		cyl("Bowl", 0.5, 3.6, CF(0, 3.3, 0), Color3.fromRGB(220, 220, 216), M.Marble)
		local top = cyl("TopWater", 0.15, 3.2, CF(0, 3.6, 0), Color3.fromRGB(80, 170, 230), M.Glass, { Transparency = 0.3, CanCollide = false })
		local spray = Instance.new("ParticleEmitter")
		spray.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
		spray.Transparency = NumberSequence.new(0.3, 1)
		spray.Size = NumberSequence.new(0.25, 0.1)
		spray.Speed = NumberRange.new(6, 8)
		spray.SpreadAngle = Vector2.new(12, 12)
		spray.Acceleration = Vector3.new(0, -18, 0)
		spray.Lifetime = NumberRange.new(0.8, 1)
		spray.Rate = 40
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Parent = top
	elseif key == "trophy" then
		P("Pedestal", V3(2.6, 2, 2.6), CF(0, 1, 0), Color3.fromRGB(20, 20, 24), M.Marble, { Reflectance = 0.2 })
		local gold = Color3.fromRGB(240, 190, 60)
		cyl("Stem", 1, 0.5, CF(0, 2.5, 0), gold, M.Metal, { Reflectance = 0.4 })
		cyl("Cup", 1.6, 1.8, CF(0, 3.8, 0), gold, M.Metal, { Reflectance = 0.4 })
		for _, x in { -1.1, 1.1 } do
			P("Handle", V3(0.2, 1, 0.2), CF(x, 3.9, 0), gold, M.Metal, { Reflectance = 0.4 })
		end
		local glow = Instance.new("PointLight")
		glow.Color = gold
		glow.Range = 12
		glow.Brightness = 1.2
		glow.Parent = model:FindFirstChild("Cup")
	end
	return model
end

return DecorBuilder

-- Small helpers for building map geometry from code.
local Build = {}

local SMOOTH = Enum.SurfaceType.Smooth

function Build.part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): BasePart
	local className = (props and props.ClassName) or "Part"
	local p = Instance.new(className) :: BasePart
	p.Name = name
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if props then
		for k, v in props do
			if k ~= "ClassName" then
				(p :: any)[k] = v
			end
		end
	end
	p.Parent = parent
	return p
end

function Build.folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Build.model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- SurfaceGui with one big text label. Returns the label.
function Build.sign(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?, pixelsPerStud: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 20
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font or Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = gui
	return label
end

function Build.spotLight(parent: BasePart, color: Color3, range: number, brightness: number, angle: number?, face: Enum.NormalId?)
	local light = Instance.new("SpotLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Angle = angle or 90
	light.Face = face or Enum.NormalId.Bottom
	light.Shadows = false
	light.Parent = parent
	return light
end

function Build.pointLight(parent: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

-- Simple stylised tree (trunk + two leaf balls)
function Build.tree(parent: Instance, position: Vector3, scale: number)
	local model = Build.model(parent, "Tree")
	local trunkH = 7 * scale
	Build.part(model, "Trunk", Vector3.new(trunkH, 1.1 * scale, 1.1 * scale), CFrame.new(position + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(96, 70, 48), Enum.Material.Wood, { Shape = Enum.PartType.Cylinder, CanCollide = true })
	Build.part(model, "Leaves", Vector3.new(7, 7, 7) * scale, CFrame.new(position + Vector3.new(0, trunkH + 1.5 * scale, 0)),
		Color3.fromRGB(64, 120, 58), Enum.Material.Grass, { Shape = Enum.PartType.Ball, CanCollide = false })
	Build.part(model, "Leaves2", Vector3.new(5, 5, 5) * scale, CFrame.new(position + Vector3.new(1.2 * scale, trunkH + 4 * scale, 0.6 * scale)),
		Color3.fromRGB(80, 140, 66), Enum.Material.Grass, { Shape = Enum.PartType.Ball, CanCollide = false })
	return model
end

-- Street lamp with a downward spot light
function Build.lamp(parent: Instance, cf: CFrame, color: Color3)
	local model = Build.model(parent, "Lamp")
	Build.part(model, "Pole", Vector3.new(16, 0.6, 0.6), cf * CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(40, 42, 48), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	Build.part(model, "Arm", Vector3.new(0.4, 0.4, 3), cf * CFrame.new(0, 16, -1.2), Color3.fromRGB(40, 42, 48), Enum.Material.Metal)
	local head = Build.part(model, "Head", Vector3.new(1.4, 0.3, 1.8), cf * CFrame.new(0, 15.8, -2.6), color, Enum.Material.Neon, { CanCollide = false })
	Build.spotLight(head, color, 34, 2.2, 110, Enum.NormalId.Bottom)
	return model
end

return Build

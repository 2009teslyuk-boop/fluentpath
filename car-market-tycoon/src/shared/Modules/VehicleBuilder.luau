-- Procedural car models built from Parts / WedgeParts / cylinders.
-- Every body archetype has its own proportions and silhouette; database entries can override
-- any parameter through `Style`. Local space: front of the car is -Z, origin on the ground.

local VehicleDatabase = require(script.Parent.VehicleDatabase)

local VehicleBuilder = {}

local V3 = Vector3.new
local CF = CFrame.new
local FLIP = CFrame.Angles(0, math.pi, 0)
local FACE_Z = CFrame.Angles(0, math.pi / 2, 0) -- turns a cylinder's axis from X to Z

local SMOOTH = Enum.SurfaceType.Smooth
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal

local COLORS = {
	Dark = Color3.fromRGB(22, 22, 25),
	Tire = Color3.fromRGB(26, 26, 28),
	Chrome = Color3.fromRGB(214, 218, 224),
	Rim = Color3.fromRGB(198, 202, 210),
	RimDark = Color3.fromRGB(52, 54, 60),
	Glass = Color3.fromRGB(24, 30, 40),
	Head = Color3.fromRGB(236, 244, 255),
	Tail = Color3.fromRGB(255, 28, 40),
	Plate = Color3.fromRGB(236, 236, 230),
	Carbon = Color3.fromRGB(30, 30, 33),
}

-- Body archetypes ------------------------------------------------------------------------
-- L/W/H: length, width, body height   Clr: ground clearance   R/TW: wheel radius / tire width
-- Hood: hood length   WS/Roof/RW: windshield, roof and rear-window lengths   CabH: cabin height
-- FA/RA: axle offsets from the front/back   Rear: notch | fastback | hatch | wagon | bed
VehicleBuilder.Archetypes = {
	hatch = {
		L = 12, W = 6.0, H = 2.2, Clr = 0.85, R = 1.1, TW = 0.9, Hood = 3.0, WS = 1.5, Roof = 0, RW = 0.9,
		CabH = 2.0, Rear = "hatch", FA = 2.3, RA = 2.2, Seats = 2, HoodRise = 0.22, DeckRise = 0,
		Lights = "slim", Grille = "wide", Exhaust = "single", Spokes = 5,
	},
	oldsedan = {
		L = 13.5, W = 6.2, H = 2.3, Clr = 0.9, R = 1.05, TW = 0.85, Hood = 3.8, WS = 1.2, Roof = 3.0, RW = 1.2,
		CabH = 1.95, Rear = "notch", FA = 2.6, RA = 2.6, Seats = 2, HoodRise = 0.1, DeckRise = 0.1,
		Lights = "round", Grille = "wide", Exhaust = "single", Chrome = true, Boxy = true, Spokes = 4,
	},
	sedan = {
		L = 14, W = 6.4, H = 2.35, Clr = 0.9, R = 1.2, TW = 0.95, Hood = 3.9, WS = 1.8, Roof = 2.8, RW = 1.6,
		CabH = 2.0, Rear = "notch", FA = 2.7, RA = 2.8, Seats = 2, HoodRise = 0.25, DeckRise = 0.2,
		Lights = "slim", Grille = "wide", Exhaust = "dual", Spokes = 5,
	},
	wagon = {
		L = 14.6, W = 6.4, H = 2.35, Clr = 0.95, R = 1.2, TW = 0.95, Hood = 3.8, WS = 1.7, Roof = 0, RW = 0.35,
		CabH = 2.1, Rear = "wagon", FA = 2.7, RA = 2.7, Seats = 2, HoodRise = 0.22, DeckRise = 0,
		Lights = "slim", Grille = "wide", Exhaust = "single", Spokes = 5,
	},
	suv = {
		L = 15, W = 7.0, H = 3.0, Clr = 1.5, R = 1.55, TW = 1.15, Hood = 3.8, WS = 1.5, Roof = 0, RW = 0.4,
		CabH = 2.4, Rear = "wagon", FA = 2.9, RA = 2.9, Seats = 2, HoodRise = 0.15, DeckRise = 0,
		Lights = "quad", Grille = "tall", Exhaust = "dual", Rack = true, Boxy = true, Spokes = 6,
	},
	pickup = {
		L = 17, W = 7.0, H = 3.0, Clr = 1.7, R = 1.6, TW = 1.2, Hood = 4.2, WS = 1.4, Roof = 3.5, RW = 0.3,
		CabH = 2.4, Rear = "bed", FA = 3.0, RA = 3.2, Seats = 2, HoodRise = 0.15, DeckRise = 0,
		Lights = "quad", Grille = "tall", Exhaust = "single", Boxy = true, Spokes = 6,
	},
	coupe = {
		L = 13.8, W = 6.4, H = 2.0, Clr = 0.7, R = 1.2, TW = 1.0, Hood = 4.2, WS = 1.9, Roof = 1.8, RW = 3.2,
		CabH = 1.75, Rear = "fastback", FA = 2.6, RA = 2.6, Seats = 1, HoodRise = 0.25, DeckRise = 0.12,
		Lights = "slim", Grille = "mesh", Exhaust = "dual", Spoiler = "lip", Spokes = 5, DarkRims = true,
	},
	muscle = {
		L = 15.4, W = 6.8, H = 2.35, Clr = 0.85, R = 1.3, TW = 1.15, Hood = 5.6, WS = 1.6, Roof = 2.0, RW = 2.4,
		CabH = 1.75, Rear = "fastback", FA = 2.9, RA = 2.9, Seats = 2, HoodRise = 0.18, DeckRise = 0.15,
		Lights = "round", Grille = "wide", Exhaust = "dual", Spoiler = "duck", Scoop = true, Spokes = 5,
	},
	supercar = {
		L = 14.4, W = 7.0, H = 1.75, Clr = 0.55, R = 1.3, TW = 1.2, Hood = 3.6, WS = 2.4, Roof = 1.3, RW = 3.4,
		CabH = 1.55, Rear = "fastback", FA = 2.6, RA = 2.7, Seats = 1, HoodRise = 0.18, DeckRise = 0.3,
		Lights = "slim", Grille = "mesh", Exhaust = "quad", Spoiler = "wing", Intakes = true, Diffuser = true,
		Spokes = 10, DarkRims = true,
	},
	hypercar = {
		L = 15, W = 7.2, H = 1.6, Clr = 0.45, R = 1.35, TW = 1.3, Hood = 3.4, WS = 2.8, Roof = 1.0, RW = 3.8,
		CabH = 1.5, Rear = "fastback", FA = 2.7, RA = 2.8, Seats = 1, HoodRise = 0.15, DeckRise = 0.35,
		Lights = "bar", Grille = "mesh", Exhaust = "quad", Spoiler = "bigwing", Intakes = true, Diffuser = true,
		Fin = true, LightBar = true, Spokes = 10, DarkRims = true,
	},
	luxury = {
		L = 16.5, W = 6.9, H = 2.6, Clr = 1.0, R = 1.35, TW = 1.05, Hood = 5.0, WS = 1.9, Roof = 3.6, RW = 1.7,
		CabH = 2.1, Rear = "notch", FA = 3.0, RA = 3.1, Seats = 2, HoodRise = 0.2, DeckRise = 0.18,
		Lights = "slim", Grille = "tall", Exhaust = "dual", Chrome = true, Spokes = 6,
	},
	electric = {
		L = 14.4, W = 6.6, H = 2.3, Clr = 0.85, R = 1.25, TW = 1.0, Hood = 3.2, WS = 2.4, Roof = 2.8, RW = 2.4,
		CabH = 1.95, Rear = "fastback", FA = 2.6, RA = 2.7, Seats = 2, HoodRise = 0.2, DeckRise = 0.1,
		Lights = "bar", Grille = "closed", Exhaust = "none", LightBar = true, Spokes = 5,
	},
	concept = {
		L = 15.5, W = 7.4, H = 1.5, Clr = 0.5, R = 1.4, TW = 1.3, Hood = 3.0, WS = 3.4, Roof = 0.6, RW = 4.4,
		CabH = 1.55, Rear = "fastback", FA = 2.8, RA = 2.9, Seats = 1, HoodRise = 0.12, DeckRise = 0.3,
		Lights = "bar", Grille = "closed", Exhaust = "none", Intakes = true, Diffuser = true, Fin = true,
		LightBar = true, SideGlow = true, Canopy = true, Spokes = 10, DarkRims = true,
	},
}

local styleCache: { [string]: any } = {}

function VehicleBuilder.getStyle(modelKey: string)
	if styleCache[modelKey] then
		return styleCache[modelKey]
	end
	local model = VehicleDatabase.getModel(modelKey)
	local base = VehicleBuilder.Archetypes[model and model.Body or "sedan"] or VehicleBuilder.Archetypes.sedan
	local style = table.clone(base)
	if model and model.Style then
		for k, v in model.Style do
			style[k] = v
		end
	end
	style.Fin = style.Fin == true
	styleCache[modelKey] = style
	return style
end

local function computeLayout(s)
	local zF, zR = -s.L / 2, s.L / 2
	local h1 = math.max(s.H * 0.55, 2 * s.R + 0.08 - s.Clr)
	h1 = math.min(h1, s.H - 0.45)
	local h2 = s.H - h1
	local cabStart = zF + s.Hood
	local roof = s.Roof
	if s.Rear == "wagon" or s.Rear == "hatch" then
		roof = math.max(0.6, (zR - 0.45 - s.RW) - (cabStart + s.WS))
	end
	local cabEnd = cabStart + s.WS + roof + s.RW
	return {
		zF = zF,
		zR = zR,
		h1 = h1,
		h2 = h2,
		lowTop = s.Clr + h1,
		belt = s.Clr + s.H,
		cabStart = cabStart,
		roof = roof,
		cabEnd = cabEnd,
		gw = s.W - 0.8,
		height = s.Clr + s.H + s.CabH,
	}
end

-- Size information without building (used for tarps and cameras).
function VehicleBuilder.getDimensions(modelKey: string)
	local s = VehicleBuilder.getStyle(modelKey)
	local layout = computeLayout(s)
	return {
		L = s.L,
		W = s.W + 0.3,
		H = layout.height,
		Belt = layout.belt,
		CabH = s.CabH,
		CabStart = layout.cabStart,
		CabEnd = layout.cabEnd,
		-- highest point of the body below the cabin (wheel arches can rise above the beltline)
		BodyTop = math.max(layout.belt, if 2 * s.R + 0.1 > layout.lowTop then 2 * s.R + 0.25 else 0),
	}
end

local function finishProps(finish: string): (Enum.Material, number)
	if finish == "metallic" then
		return PLASTIC, 0.18
	elseif finish == "matte" then
		return PLASTIC, 0
	elseif finish == "pearl" then
		return PLASTIC, 0.26
	elseif finish == "chrome" then
		return PLASTIC, 0.5
	end
	return PLASTIC, 0.08
end

local function make(className: string, parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, props: { [string]: any }?)
	local p = Instance.new(className) :: BasePart
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- options: { lowDetail: boolean? }
function VehicleBuilder.build(record, options: { lowDetail: boolean? }?)
	local opts = options or {}
	local s = VehicleBuilder.getStyle(record.modelKey)
	local lay = computeLayout(s)
	local paint = VehicleDatabase.ColorByKey[record.color] or VehicleDatabase.Colors[1]
	local interior = VehicleDatabase.InteriorByKey[record.interior] or VehicleDatabase.Interiors[1]
	local mods = record.mods or {}

	local paintColor = paint.Color
	local paintMaterial, paintRefl = finishProps(paint.Finish)
	local accent = s.Accent or COLORS.Head
	local rimColor = s.RimColor or (if s.DarkRims then COLORS.RimDark else COLORS.Rim)
	local glassTransparency = if mods.Tint then 0.12 else 0.32

	local L, W, R, TW = s.L, s.W, s.R, s.TW
	local zF, zR, h1, h2 = lay.zF, lay.zR, lay.h1, lay.h2
	local lowTop, belt, cabStart, roof, cabEnd, gw = lay.lowTop, lay.belt, lay.cabStart, lay.roof, lay.cabEnd, lay.gw
	local WS, RW, CabH = s.WS, s.RW, s.CabH

	local car = Instance.new("Model")
	car.Name = "Vehicle"

	local function bodyPart(className, name, size, cf, extra)
		local props = { Reflectance = paintRefl }
		if extra then
			for k, v in extra do
				props[k] = v
			end
		end
		return make(className, car, name, size, cf, paintColor, paintMaterial, props)
	end
	local function dark(name, size, cf, className)
		return make(className or "Part", car, name, size, cf, COLORS.Dark, PLASTIC)
	end
	local function chrome(name, size, cf, className, extra)
		local props = { Reflectance = 0.45 }
		if extra then
			for k, v in extra do
				props[k] = v
			end
		end
		return make(className or "Part", car, name, size, cf, COLORS.Chrome, PLASTIC, props)
	end
	local function glass(className, name, size, cf)
		return make(className, car, name, size, cf, COLORS.Glass, GLASS, {
			Transparency = glassTransparency,
			Reflectance = 0.25,
			CanCollide = true,
		})
	end
	local function neon(name, size, cf, color, className)
		return make(className or "Part", car, name, size, cf, color, NEON)
	end

	-- Root (invisible, used as pivot / hit box) ---------------------------------------
	local root = make("Part", car, "Root", V3(W, lay.height, L), CF(0, lay.height / 2, 0), Color3.new(1, 1, 1), PLASTIC, {
		Transparency = 1,
		CanQuery = true,
	})
	root.PivotOffset = CF(0, -lay.height / 2, 0)
	car.PrimaryPart = root

	-- Main body --------------------------------------------------------------------------
	bodyPart("Part", "LowerBody", V3(W - 0.4, h1, L - 0.8), CF(0, s.Clr + h1 / 2, 0), { CanCollide = true, CastShadow = true })
	bodyPart("Part", "Shoulder", V3(W, h2, L - 1.4), CF(0, lowTop + h2 / 2, 0), { CanCollide = true, CastShadow = true })
	if s.Boxy then
		bodyPart("Part", "Nose", V3(W - 0.1, h2 * 0.9, 0.7), CF(0, lowTop + h2 * 0.45, zF + 0.35))
		bodyPart("Part", "Tail", V3(W - 0.1, h2 * 0.95, 0.7), CF(0, lowTop + h2 * 0.475, zR - 0.35))
	else
		bodyPart("WedgePart", "Nose", V3(W, h2, 0.7), CF(0, lowTop + h2 / 2, zF + 0.35))
		bodyPart("WedgePart", "Tail", V3(W, h2, 0.7), CF(0, lowTop + h2 / 2, zR - 0.35) * FLIP)
	end
	bodyPart("Part", "FrontBumper", V3(W - 0.6, h1 * 0.94, 0.4), CF(0, s.Clr + h1 * 0.47, zF + 0.2))
	bodyPart("Part", "RearBumper", V3(W - 0.6, h1 * 0.94, 0.4), CF(0, s.Clr + h1 * 0.47, zR - 0.2))
	dark("Splitter", V3(W - 0.8, 0.12, 0.7), CF(0, s.Clr + 0.06, zF + 0.3))
	dark("Underbody", V3(W - 0.9, 0.1, L - 1.2), CF(0, s.Clr + 0.05, 0))

	if s.HoodRise > 0 then
		local hoodLen = cabStart - (zF + 0.7)
		bodyPart("WedgePart", "Hood", V3(W - 0.3, s.HoodRise, hoodLen), CF(0, belt + s.HoodRise / 2, zF + 0.7 + hoodLen / 2))
	end

	local deckLen = (zR - 0.7) - cabEnd
	if (s.Rear == "notch" or s.Rear == "fastback") and deckLen > 0.25 and s.DeckRise > 0 then
		bodyPart("WedgePart", "Deck", V3(W - 0.3, s.DeckRise, deckLen), CF(0, belt + s.DeckRise / 2, cabEnd + deckLen / 2) * FLIP)
	end

	-- Greenhouse -------------------------------------------------------------------------
	glass("WedgePart", "Windshield", V3(gw, CabH, WS), CF(0, belt + CabH / 2, cabStart + WS / 2))
	glass("Part", "CabinGlass", V3(gw, CabH - 0.18, roof), CF(0, belt + (CabH - 0.18) / 2, cabStart + WS + roof / 2))
	if s.Canopy then
		glass("Part", "Roof", V3(gw + 0.1, 0.18, roof + 0.05), CF(0, belt + CabH - 0.09, cabStart + WS + roof / 2))
	else
		bodyPart("Part", "Roof", V3(gw + 0.1, 0.18, roof + 0.05), CF(0, belt + CabH - 0.09, cabStart + WS + roof / 2), { CastShadow = true })
	end
	if RW > 0.05 then
		glass("WedgePart", "RearWindow", V3(gw, CabH, RW), CF(0, belt + CabH / 2, cabStart + WS + roof + RW / 2) * FLIP)
	end

	for _, side in { -1, 1 } do
		local px = side * gw / 2
		-- A-pillar following the windshield slope
		local aCenter = V3(px, belt + CabH / 2, cabStart + WS / 2)
		local aLen = math.sqrt(WS * WS + CabH * CabH)
		local aPillar = bodyPart("Part", "APillar", V3(0.12, 0.12, aLen), CFrame.lookAt(aCenter, aCenter + V3(0, CabH, WS)))
		if s.Canopy then
			aPillar.Color = COLORS.Carbon
		end
		-- C-pillar following the rear window
		if RW > 0.05 then
			local cCenter = V3(px, belt + CabH / 2, cabStart + WS + roof + RW / 2)
			local cLen = math.sqrt(RW * RW + CabH * CabH)
			bodyPart("Part", "CPillar", V3(0.12, 0.12, cLen), CFrame.lookAt(cCenter, cCenter + V3(0, -CabH, RW)))
		end
		-- B-pillar
		if roof > 1.6 then
			local bz = cabStart + WS + roof * (if s.Seats >= 2 then 0.45 else 0.8)
			dark("BPillar", V3(0.1, CabH - 0.2, 0.26), CF(px, belt + (CabH - 0.2) / 2, bz))
		end
		-- Window trim along the beltline
		local trimLen = WS + roof + RW
		if s.Chrome then
			chrome("WindowTrim", V3(0.07, 0.08, trimLen), CF(px + side * 0.03, belt + 0.04, cabStart + trimLen / 2))
		else
			dark("WindowTrim", V3(0.06, 0.08, trimLen), CF(px + side * 0.03, belt + 0.04, cabStart + trimLen / 2))
		end
		-- Mirrors
		bodyPart("Part", "Mirror", V3(0.32, 0.24, 0.36), CF(side * (W / 2 + 0.12), belt + 0.3, cabStart + 0.5))
		dark("MirrorArm", V3(0.32, 0.07, 0.12), CF(side * (W / 2 - 0.08), belt + 0.22, cabStart + 0.55))
	end

	-- Door seams + handles (one thin part across the width shows on both sides) ----------------
	local seams = { cabStart + 0.15 }
	if s.Rear ~= "bed" and s.Seats >= 2 and roof > 2.2 then
		table.insert(seams, cabStart + WS + roof * 0.45)
		table.insert(seams, math.min(cabStart + WS + roof + 0.15, zR - 1.2))
	else
		table.insert(seams, cabStart + WS + roof * 0.9)
	end
	local seamH = s.H - 0.3
	for i, z in seams do
		dark("DoorSeam", V3(W + 0.02, seamH, 0.05), CF(0, s.Clr + 0.12 + seamH / 2, z))
		if i < #seams then
			chrome("DoorHandle", V3(W + 0.04, 0.08, 0.34), CF(0, lowTop + h2 * 0.55, seams[i + 1] - 0.45))
		end
	end

	-- Wheels -------------------------------------------------------------------------------
	local wheelX = W / 2 - TW / 2 + 0.06
	local axles = { zF + s.FA, zR - s.RA }
	local wheelTop = 2 * R
	local spokes = if opts.lowDetail then 0 else (s.Spokes or 5)
	for _, z in axles do
		for _, side in { -1, 1 } do
			local x = side * wheelX
			local c = CF(x, R, z)
			make("Part", car, "Tire", V3(TW, 2 * R, 2 * R), c, COLORS.Tire, PLASTIC, { Shape = Enum.PartType.Cylinder, CastShadow = true })
			make("Part", car, "Rim", V3(TW + 0.04, R * 1.32, R * 1.32), c, rimColor, METAL, { Shape = Enum.PartType.Cylinder, Reflectance = 0.2 })
			make("Part", car, "RimBarrel", V3(TW + 0.06, R * 1.08, R * 1.08), c, COLORS.Dark, PLASTIC, { Shape = Enum.PartType.Cylinder })
			local faceX = x + side * (TW / 2 + 0.05)
			for i = 1, spokes do
				local angle = (i / spokes) * math.pi * 2
				local width = if spokes >= 10 then 0.1 else 0.2
				make("Part", car, "Spoke", V3(0.08, width, R * 0.56), CF(faceX, R, z) * CFrame.Angles(angle, 0, 0) * CF(0, 0, -R * 0.29), rimColor, METAL, { Reflectance = 0.2 })
			end
			make("Part", car, "Hub", V3(TW + 0.12, R * 0.3, R * 0.3), c, COLORS.Chrome, PLASTIC, { Shape = Enum.PartType.Cylinder, Reflectance = 0.4 })

			-- Fender / wheel arch where the wheel reaches above the lower body
			if wheelTop + 0.1 > lowTop then
				local fz = 2 * R + 0.5
				bodyPart("Part", "Fender", V3(TW + 0.14, 0.3, fz), CF(x, wheelTop + 0.1, z))
				bodyPart("WedgePart", "FenderFront", V3(TW + 0.14, 0.3, 0.45), CF(x, wheelTop + 0.1, z - fz / 2 - 0.225))
				bodyPart("WedgePart", "FenderRear", V3(TW + 0.14, 0.3, 0.45), CF(x, wheelTop + 0.1, z + fz / 2 + 0.225) * FLIP)
			end
		end
	end

	-- Front lights / grille ------------------------------------------------------------------
	local headY = lowTop + 0.05
	local lights = s.Lights
	for _, side in { -1, 1 } do
		if lights == "round" then
			neon("Headlight", V3(0.5, 0.62, 0.62), CF(side * (W / 2 - 0.75), headY, zF + 0.2) * FACE_Z, COLORS.Head, "Part").Shape = Enum.PartType.Cylinder
			neon("Headlight", V3(0.5, 0.5, 0.5), CF(side * (W / 2 - 1.4), headY, zF + 0.2) * FACE_Z, COLORS.Head, "Part").Shape = Enum.PartType.Cylinder
		elseif lights == "quad" then
			neon("Headlight", V3(0.6, 0.32, 0.5), CF(side * (W / 2 - 0.75), headY, zF + 0.25), COLORS.Head)
			neon("Headlight", V3(0.6, 0.32, 0.5), CF(side * (W / 2 - 1.45), headY, zF + 0.25), COLORS.Head)
		elseif lights == "bar" then
			neon("Headlight", V3(0.9, 0.22, 0.6), CF(side * (W / 2 - 0.9), headY, zF + 0.3), COLORS.Head)
		else
			neon("Headlight", V3(1.5, 0.22, 0.6), CF(side * (W / 2 - 1.05), headY, zF + 0.3), COLORS.Head)
		end
		-- tail lights
		if lights == "bar" or s.LightBar then
			neon("Taillight", V3(1.0, 0.24, 0.6), CF(side * (W / 2 - 0.9), headY, zR - 0.3), COLORS.Tail)
		elseif lights == "round" then
			neon("Taillight", V3(0.5, 0.55, 0.55), CF(side * (W / 2 - 0.8), headY, zR - 0.2) * FACE_Z, COLORS.Tail).Shape = Enum.PartType.Cylinder
		else
			neon("Taillight", V3(1.3, 0.3, 0.6), CF(side * (W / 2 - 0.95), headY, zR - 0.3), COLORS.Tail)
		end
	end
	if lights == "bar" or s.LightBar then
		neon("LightBarFront", V3(W - 1.6, 0.08, 0.4), CF(0, headY, zF + 0.22), accent)
		neon("LightBarRear", V3(W - 1.6, 0.1, 0.4), CF(0, headY, zR - 0.22), COLORS.Tail)
	end

	local grilleY = s.Clr + h1 * 0.55
	if s.Grille == "tall" then
		local gwid, ght = W * 0.32, math.max(0.6, h1 * 0.8)
		dark("Grille", V3(gwid, ght, 0.1), CF(0, grilleY, zF - 0.03))
		chrome("GrilleTop", V3(gwid + 0.2, 0.12, 0.14), CF(0, grilleY + ght / 2, zF - 0.03))
		chrome("GrilleBottom", V3(gwid + 0.2, 0.12, 0.14), CF(0, grilleY - ght / 2, zF - 0.03))
		for i = -1, 1 do
			chrome("GrilleSlat", V3(0.06, ght, 0.12), CF(i * gwid / 4, grilleY, zF - 0.03))
		end
		chrome("GrilleSide", V3(0.12, ght, 0.14), CF(-gwid / 2, grilleY, zF - 0.03))
		chrome("GrilleSide", V3(0.12, ght, 0.14), CF(gwid / 2, grilleY, zF - 0.03))
	elseif s.Grille == "mesh" then
		dark("Grille", V3(W * 0.66, h1 * 0.42, 0.1), CF(0, s.Clr + h1 * 0.4, zF - 0.03))
		dark("IntakeL", V3(0.8, h1 * 0.3, 0.1), CF(-(W / 2 - 0.9), s.Clr + h1 * 0.3, zF - 0.03))
		dark("IntakeR", V3(0.8, h1 * 0.3, 0.1), CF(W / 2 - 0.9, s.Clr + h1 * 0.3, zF - 0.03))
	elseif s.Grille == "wide" then
		dark("Grille", V3(W * 0.5, h1 * 0.42, 0.1), CF(0, grilleY, zF - 0.03))
		if s.Chrome then
			chrome("GrilleFrame", V3(W * 0.52, 0.08, 0.12), CF(0, grilleY + h1 * 0.21, zF - 0.03))
		end
	elseif s.Grille == "closed" and s.Accent then
		neon("GrilleAccent", V3(W * 0.4, 0.06, 0.08), CF(0, grilleY, zF - 0.02), accent)
	end

	make("Part", car, "PlateRear", V3(1.4, 0.42, 0.06), CF(0, s.Clr + h1 * 0.55, zR + 0.03), COLORS.Plate, PLASTIC)

	if s.Chrome then
		chrome("BeltChrome", V3(W + 0.02, 0.06, L - 2.2), CF(0, belt - 0.06, 0))
		chrome("BumperChromeF", V3(W - 0.5, 0.1, 0.46), CF(0, s.Clr + h1 * 0.3, zF + 0.2))
		chrome("BumperChromeR", V3(W - 0.5, 0.1, 0.46), CF(0, s.Clr + h1 * 0.3, zR - 0.2))
	end

	-- Exhaust ---------------------------------------------------------------------------------
	local exhaust = if s.QuadExhaust then "quad" else s.Exhaust
	local exhaustXs = {}
	if exhaust == "single" then
		exhaustXs = { W / 2 - 1.3 }
	elseif exhaust == "dual" then
		exhaustXs = { -(W / 2 - 1.3), W / 2 - 1.3 }
	elseif exhaust == "quad" then
		exhaustXs = { -(W / 2 - 1.2), -(W / 2 - 1.65), W / 2 - 1.2, W / 2 - 1.65 }
	end
	for _, x in exhaustXs do
		chrome("Exhaust", V3(0.6, 0.34, 0.34), CF(x, s.Clr + 0.22, zR + 0.05) * FACE_Z, "Part", { Shape = Enum.PartType.Cylinder })
	end

	-- Spoilers ---------------------------------------------------------------------------------
	local spoiler = mods.Spoiler and mods.Spoiler.style or s.Spoiler
	if spoiler and (s.Rear == "notch" or s.Rear == "fastback") then
		if spoiler == "lip" then
			bodyPart("WedgePart", "Spoiler", V3(W - 0.8, 0.22, 0.5), CF(0, belt + 0.11, zR - 0.95))
		elseif spoiler == "duck" then
			bodyPart("WedgePart", "Spoiler", V3(W - 0.4, 0.4, 1.0), CF(0, belt + 0.2, zR - 1.2))
		elseif spoiler == "wing" or spoiler == "bigwing" then
			local big = spoiler == "bigwing"
			local postH = if big then 1.1 else 0.7
			local wz = zR - (if big then 0.8 else 1.0)
			local plateColor = if big then COLORS.Carbon else paintColor
			for _, side in { -1, 1 } do
				dark("WingPost", V3(0.12, postH, 0.35), CF(side * (W / 2 - 1.3), belt + postH / 2, wz))
				dark("WingEndplate", V3(0.06, 0.45, 1.05), CF(side * (W / 2 - (if big then 0.12 else 0.28)), belt + postH + 0.05, wz))
			end
			make("Part", car, "Wing", V3(W - (if big then 0.2 else 0.5), 0.1, 1.0), CF(0, belt + postH + 0.05, wz) * CFrame.Angles(0.08, 0, 0), plateColor, paintMaterial, { Reflectance = paintRefl })
		end
	elseif spoiler and s.Rear == "hatch" then
		bodyPart("Part", "RoofSpoiler", V3(gw, 0.12, 0.6), CF(0, belt + CabH - 0.06, cabStart + WS + roof + 0.15))
	end

	-- Extras -----------------------------------------------------------------------------------
	if s.Scoop then
		local scoopZ = zF + s.Hood * 0.55
		bodyPart("Part", "HoodScoop", V3(1.5, 0.3, 1.6), CF(0, belt + s.HoodRise * 0.5 + 0.15, scoopZ))
		dark("ScoopInlet", V3(1.3, 0.18, 0.06), CF(0, belt + s.HoodRise * 0.5 + 0.17, scoopZ - 0.8))
	end
	if s.Rack then
		local roofY = belt + CabH + 0.07
		for _, side in { -1, 1 } do
			dark("RoofRail", V3(0.12, 0.14, roof * 0.9), CF(side * (gw / 2 - 0.25), roofY, cabStart + WS + roof / 2))
		end
		for _, t in { 0.3, 0.7 } do
			dark("CrossBar", V3(gw - 0.3, 0.08, 0.12), CF(0, roofY + 0.08, cabStart + WS + roof * t))
		end
	end
	if s.Intakes then
		local iy = h2 * 0.9 + h1 * 0.35
		dark("SideIntake", V3(W + 0.04, iy, 1.4), CF(0, belt - 0.05 - iy / 2, cabStart + WS + roof + RW * 0.25))
	end
	if s.Fin then
		bodyPart("WedgePart", "Fin", V3(0.14, CabH * 0.9, RW + 0.8), CF(0, belt + CabH * 0.45 + 0.05, cabStart + WS + roof + (RW + 0.8) / 2) * FLIP)
	end
	if s.Diffuser then
		dark("Diffuser", V3(W - 1.2, 0.35, 0.9), CF(0, s.Clr + 0.12, zR - 0.4))
		for i = -1, 1 do
			dark("DiffuserFin", V3(0.06, 0.45, 0.9), CF(i * (W - 1.2) / 4, s.Clr + 0.15, zR - 0.35))
		end
	end
	if s.SideGlow then
		neon("SideGlow", V3(W + 0.02, 0.06, L - 3.2), CF(0, s.Clr + 0.25, 0), accent)
	end
	if s.SpareWheel then
		local sy = lowTop + 0.2
		make("Part", car, "SpareTire", V3(0.7, 2 * R * 0.9, 2 * R * 0.9), CF(0, sy, zR + 0.38) * FACE_Z, COLORS.Tire, PLASTIC, { Shape = Enum.PartType.Cylinder })
		make("Part", car, "SpareRim", V3(0.74, R * 1.1, R * 1.1), CF(0, sy, zR + 0.38) * FACE_Z, rimColor, METAL, { Shape = Enum.PartType.Cylinder })
	end
	if s.BullBar then
		for _, y in { s.Clr + h1 * 0.4, s.Clr + h1 * 0.85 } do
			dark("BullBar", V3(W * 0.62, 0.14, 0.14), CF(0, y, zF - 0.35))
		end
		for _, side in { -1, 1 } do
			dark("BullBarPost", V3(0.14, h1 * 0.6, 0.14), CF(side * W * 0.29, s.Clr + h1 * 0.62, zF - 0.35))
		end
	end
	if s.Rear == "bed" then
		local bedStart = cabEnd + 0.15
		local bedLen = (zR - 0.7) - bedStart
		local wallH = 0.85
		for _, side in { -1, 1 } do
			bodyPart("Part", "BedWall", V3(0.2, wallH, bedLen), CF(side * (W / 2 - 0.1), belt + wallH / 2, bedStart + bedLen / 2))
		end
		bodyPart("Part", "BedFront", V3(W, wallH, 0.2), CF(0, belt + wallH / 2, bedStart + 0.1))
		bodyPart("Part", "Tailgate", V3(W, wallH, 0.2), CF(0, belt + wallH / 2, zR - 0.8))
		dark("BedLiner", V3(W - 0.4, 0.05, bedLen - 0.4), CF(0, belt + 0.025, bedStart + bedLen / 2))
	end

	-- Mods with a visual result ----------------------------------------------------------------
	if mods.Underglow and typeof(mods.Underglow.color) == "table" then
		local c = mods.Underglow.color
		local glowColor = Color3.fromRGB(c[1] or 0, c[2] or 200, c[3] or 255)
		local glow = neon("Underglow", V3(W - 1.2, 0.06, L - 2.4), CF(0, s.Clr - 0.02, 0), glowColor)
		local light = Instance.new("PointLight")
		light.Color = glowColor
		light.Range = 10
		light.Brightness = 2
		light.Parent = glow
	end

	-- Interior -----------------------------------------------------------------------------------
	if not opts.lowDetail then
		local inner = interior.Color
		make("Part", car, "Dashboard", V3(gw - 0.1, 0.32, 0.7), CF(0, belt + 0.16, cabStart + WS * 0.55), COLORS.Dark, PLASTIC)
		make("Part", car, "SteeringWheel", V3(0.07, 0.7, 0.7), CF(-gw / 4, belt + 0.55, cabStart + WS * 0.85) * CFrame.Angles(-0.35, 0, 0) * FACE_Z, COLORS.Dark, PLASTIC, { Shape = Enum.PartType.Cylinder })
		local seatZ = cabStart + WS + 0.45
		for _, side in { -1, 1 } do
			make("Part", car, "SeatBack", V3(gw / 2 - 0.35, 1.0, 0.26), CF(side * gw / 4, belt + 0.45, seatZ + 0.45) * CFrame.Angles(-0.18, 0, 0), inner, PLASTIC)
		end
		if s.Seats >= 2 and roof > 2.4 then
			make("Part", car, "RearBench", V3(gw - 0.4, 0.9, 0.26), CF(0, belt + 0.4, seatZ + 2.1) * CFrame.Angles(-0.18, 0, 0), inner, PLASTIC)
		end
	end

	car:SetAttribute("VehicleId", record.id)
	car:SetAttribute("ModelKey", record.modelKey)
	car:SetAttribute("Rarity", record.rarity)
	return car, { L = L, W = W, H = lay.height, Belt = belt }
end

return VehicleBuilder

-- Procedural car models, v2.
-- Every body archetype is described in real-world metres (length, width, wheelbase, overhang,
-- wheel size) with a side profile of the body top line and of the roof line. The builder lofts
-- that profile into many thin slices (boxes + wedges), cuts real wheel arches out of the body,
-- lays lights on the body surface and adds the details. 1 m = 2.8 studs (a Roblox character is
-- about 1.8 m tall), so the cars have real proportions.
--
-- Mesh override: put a Model named after the vehicle key into ReplicatedStorage.Assets.VehicleModels
-- (front facing -Z, pivot on the ground in the centre, painted parts with attribute Paint = true)
-- and it is used instead of the procedural body.
--
-- Local space: front of the car is -Z, origin on the ground in the centre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleDatabase = require(script.Parent.VehicleDatabase)

local VehicleBuilder = {}

local S = 2.8 -- studs per metre
VehicleBuilder.StudsPerMeter = S

local V3 = Vector3.new
local CF = CFrame.new
local FLIP = CFrame.Angles(0, math.pi, 0)
local FACE_Z = CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis X -> Z

local SMOOTH = Enum.SurfaceType.Smooth
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal

local COLORS = {
	Dark = Color3.fromRGB(20, 20, 23),
	Trim = Color3.fromRGB(14, 14, 16),
	Tire = Color3.fromRGB(24, 24, 26),
	Chrome = Color3.fromRGB(214, 218, 224),
	Glass = Color3.fromRGB(20, 26, 36),
	Head = Color3.fromRGB(236, 244, 255),
	HeadHousing = Color3.fromRGB(40, 44, 52),
	Tail = Color3.fromRGB(255, 22, 36),
	Plate = Color3.fromRGB(236, 236, 230),
	Carbon = Color3.fromRGB(28, 28, 31),
	Disc = Color3.fromRGB(90, 92, 98),
}

VehicleBuilder.RimColors = {
	Silver = Color3.fromRGB(198, 202, 210),
	Black = Color3.fromRGB(28, 28, 32),
	Gunmetal = Color3.fromRGB(70, 74, 82),
	Gold = Color3.fromRGB(212, 170, 70),
	Bronze = Color3.fromRGB(150, 104, 60),
	Red = Color3.fromRGB(200, 30, 36),
	White = Color3.fromRGB(236, 236, 236),
}

-- Rim styles: number of spokes and spoke width (fraction of the rim radius)
VehicleBuilder.RimStyles = {
	sport5 = { Spokes = 5, Width = 0.2 },
	twin10 = { Spokes = 10, Width = 0.09 },
	turbine = { Spokes = 14, Width = 0.07 },
	dish6 = { Spokes = 6, Width = 0.14 },
	y7 = { Spokes = 7, Width = 0.15 },
	steel = { Spokes = 0, Width = 0 },
}

--[[ Archetypes (metres). Body / Roof = { {z, y}, ... } with z measured from the front bumper.
	L, W, H        length, width (without mirrors), height
	FO, WB         front overhang, wheelbase
	D, TW, Clr     tyre diameter, tyre width, ground clearance
	WS0..RW1       windshield base, windshield top (= roof start), roof end, rear window bottom
	GH             greenhouse width as a fraction of the body width
	Rear           notch | fastback | hatch | wagon | bed
]]
VehicleBuilder.Archetypes = {
	-- compact hatchback (Golf / Polo class)
	hatch = {
		L = 4.28, W = 1.79, H = 1.46, FO = 0.88, WB = 2.63, D = 0.66, TW = 0.22, Clr = 0.13, GH = 0.84,
		Body = { { 0, 0.58 }, { 0.06, 0.68 }, { 0.2, 0.78 }, { 0.6, 0.86 }, { 1.2, 0.93 }, { 1.3, 0.95 }, { 3.9, 1.0 }, { 4.12, 1.0 }, { 4.22, 0.9 }, { 4.28, 0.62 } },
		WS0 = 1.3, WS1 = 2.0, R1 = 3.78, RW1 = 4.12,
		Roof = { { 2.0, 1.42 }, { 2.8, 1.46 }, { 3.78, 1.42 }, { 4.12, 0 } },
		Rear = "hatch", Doors = 4,
		Head = { Style = "slim", Z = 0.1, Len = 0.3, W = 0.36, Inset = 0.1 },
		Tail = { Style = "slim", Z = 0.06, Len = 0.2, W = 0.36, Inset = 0.06 },
		Grille = "wide", Exhaust = "single", Rim = "y7",
	},
	-- boxy classic saloon (old Eastern-European sedan)
	oldsedan = {
		L = 4.13, W = 1.62, H = 1.44, FO = 0.78, WB = 2.42, D = 0.6, TW = 0.18, Clr = 0.17, GH = 0.86,
		Body = { { 0, 0.64 }, { 0.04, 0.8 }, { 0.1, 0.83 }, { 1.4, 0.86 }, { 3.45, 0.9 }, { 4.05, 0.88 }, { 4.13, 0.66 } },
		WS0 = 1.42, WS1 = 1.95, R1 = 2.95, RW1 = 3.42,
		Roof = { { 1.95, 1.42 }, { 2.45, 1.44 }, { 2.95, 1.42 }, { 3.42, 0 } },
		Rear = "notch", Doors = 4, Chrome = true,
		Head = { Style = "quadround", Z = 0.0, Len = 0.06, W = 0.17, Inset = 0.06 },
		Tail = { Style = "slim", Z = 0.03, Len = 0.08, W = 0.42, Inset = 0.04 },
		Grille = "wide", Exhaust = "single", Rim = "steel",
	},
	-- compact saloon (Civic / Corolla class)
	sedan = {
		L = 4.65, W = 1.8, H = 1.42, FO = 0.92, WB = 2.7, D = 0.66, TW = 0.22, Clr = 0.13, GH = 0.82,
		Body = { { 0, 0.6 }, { 0.06, 0.7 }, { 0.25, 0.79 }, { 0.7, 0.85 }, { 1.5, 0.93 }, { 1.62, 0.95 }, { 3.8, 0.99 }, { 4.05, 1.0 }, { 4.42, 1.0 }, { 4.58, 0.92 }, { 4.65, 0.66 } },
		WS0 = 1.62, WS1 = 2.38, R1 = 3.3, RW1 = 4.05,
		Roof = { { 2.38, 1.39 }, { 2.8, 1.42 }, { 3.3, 1.37 }, { 4.05, 0 } },
		Rear = "notch", Doors = 4,
		Head = { Style = "slim", Z = 0.08, Len = 0.34, W = 0.38, Inset = 0.08 },
		Tail = { Style = "slim", Z = 0.05, Len = 0.22, W = 0.44, Inset = 0.04 },
		Grille = "wide", Exhaust = "dual", Rim = "sport5",
	},
	-- executive super saloon (M5 / E63 class)
	sportsedan = {
		L = 4.98, W = 1.9, H = 1.47, FO = 0.92, WB = 2.98, D = 0.72, TW = 0.28, Clr = 0.12, GH = 0.8,
		Body = { { 0, 0.6 }, { 0.06, 0.7 }, { 0.22, 0.79 }, { 0.7, 0.86 }, { 1.55, 0.95 }, { 1.78, 0.98 }, { 3.9, 1.0 }, { 4.12, 1.02 }, { 4.62, 1.03 }, { 4.84, 0.97 }, { 4.94, 0.84 }, { 4.98, 0.66 } },
		WS0 = 1.78, WS1 = 2.52, R1 = 3.55, RW1 = 4.12,
		Roof = { { 2.52, 1.43 }, { 2.98, 1.47 }, { 3.55, 1.42 }, { 4.12, 0 } },
		Rear = "notch", Doors = 4,
		Head = { Style = "angular", Z = 0.06, Len = 0.36, W = 0.42, Inset = 0.08 },
		Tail = { Style = "slim", Z = 0.06, Len = 0.26, W = 0.46, Inset = 0.04 },
		Grille = "wide", Exhaust = "quad", Rim = "twin10", Diffuser = true, Spoiler = "lip",
	},
	-- full-size luxury limousine
	luxury = {
		L = 5.76, W = 2.0, H = 1.62, FO = 0.86, WB = 3.55, D = 0.8, TW = 0.27, Clr = 0.15, GH = 0.82,
		Body = { { 0, 0.72 }, { 0.04, 0.96 }, { 0.12, 1.0 }, { 1.9, 1.05 }, { 2.1, 1.07 }, { 4.7, 1.1 }, { 5.1, 1.11 }, { 5.55, 1.08 }, { 5.7, 0.98 }, { 5.76, 0.76 } },
		WS0 = 2.1, WS1 = 2.75, R1 = 4.35, RW1 = 5.0,
		Roof = { { 2.75, 1.58 }, { 3.5, 1.62 }, { 4.35, 1.58 }, { 5.0, 0 } },
		Rear = "notch", Doors = 4, Chrome = true,
		Head = { Style = "slim", Z = 0.04, Len = 0.22, W = 0.4, Inset = 0.06 },
		Tail = { Style = "vertical", Z = 0.02, Len = 0.1, W = 0.14, Inset = 0.04 },
		Grille = "tall", Exhaust = "hidden", Rim = "dish6",
	},
	-- performance estate (RS6 class)
	wagon = {
		L = 5.0, W = 1.95, H = 1.46, FO = 0.95, WB = 2.93, D = 0.74, TW = 0.29, Clr = 0.12, GH = 0.8,
		Body = { { 0, 0.58 }, { 0.06, 0.68 }, { 0.25, 0.78 }, { 0.75, 0.85 }, { 1.6, 0.94 }, { 1.78, 0.97 }, { 4.6, 1.02 }, { 4.86, 0.98 }, { 4.95, 0.86 }, { 5.0, 0.62 } },
		WS0 = 1.78, WS1 = 2.5, R1 = 4.4, RW1 = 4.86,
		Roof = { { 2.5, 1.43 }, { 3.4, 1.46 }, { 4.4, 1.39 }, { 4.86, 0 } },
		Rear = "wagon", Doors = 4, Rack = true,
		Head = { Style = "angular", Z = 0.06, Len = 0.38, W = 0.44, Inset = 0.08 },
		Tail = { Style = "bar", Z = 0.04, Len = 0.14, W = 0.4, Inset = 0.04 },
		Grille = "hex", Exhaust = "dual", Rim = "y7", Diffuser = true,
	},
	-- large premium SUV (X5 / GLE class)
	suv = {
		L = 4.92, W = 2.0, H = 1.75, FO = 0.93, WB = 2.97, D = 0.8, TW = 0.28, Clr = 0.21, GH = 0.82,
		Body = { { 0, 0.82 }, { 0.04, 0.96 }, { 0.22, 1.05 }, { 0.7, 1.09 }, { 1.5, 1.14 }, { 1.68, 1.16 }, { 4.55, 1.2 }, { 4.82, 1.16 }, { 4.9, 1.0 }, { 4.92, 0.8 } },
		WS0 = 1.68, WS1 = 2.42, R1 = 4.45, RW1 = 4.82,
		Roof = { { 2.42, 1.72 }, { 3.4, 1.75 }, { 4.45, 1.69 }, { 4.82, 0 } },
		Rear = "wagon", Doors = 4, Rack = true,
		Head = { Style = "angular", Z = 0.05, Len = 0.34, W = 0.46, Inset = 0.08 },
		Tail = { Style = "slim", Z = 0.05, Len = 0.2, W = 0.5, Inset = 0.04 },
		Grille = "wide", Exhaust = "dual", Rim = "y7",
	},
	-- compact premium SUV (Q5 / X3 class)
	crossover = {
		L = 4.68, W = 1.89, H = 1.66, FO = 0.9, WB = 2.82, D = 0.76, TW = 0.25, Clr = 0.2, GH = 0.82,
		Body = { { 0, 0.78 }, { 0.04, 0.91 }, { 0.22, 0.99 }, { 0.7, 1.03 }, { 1.45, 1.09 }, { 1.6, 1.1 }, { 4.3, 1.15 }, { 4.58, 1.1 }, { 4.65, 0.95 }, { 4.68, 0.76 } },
		WS0 = 1.6, WS1 = 2.32, R1 = 4.1, RW1 = 4.58,
		Roof = { { 2.32, 1.63 }, { 3.2, 1.66 }, { 4.1, 1.58 }, { 4.58, 0 } },
		Rear = "wagon", Doors = 4, Rack = true,
		Head = { Style = "angular", Z = 0.05, Len = 0.32, W = 0.42, Inset = 0.08 },
		Tail = { Style = "bar", Z = 0.04, Len = 0.14, W = 0.42, Inset = 0.04 },
		Grille = "hex", Exhaust = "dual", Rim = "sport5",
	},
	-- boxy off-roader (G-class style)
	offroad = {
		L = 4.87, W = 1.98, H = 1.97, FO = 0.82, WB = 2.89, D = 0.82, TW = 0.28, Clr = 0.24, GH = 0.86,
		Body = { { 0, 0.82 }, { 0.03, 1.06 }, { 0.1, 1.12 }, { 1.6, 1.16 }, { 1.72, 1.18 }, { 4.8, 1.22 }, { 4.87, 1.2 } },
		WS0 = 1.72, WS1 = 1.96, R1 = 4.76, RW1 = 4.82,
		Roof = { { 1.96, 1.95 }, { 4.76, 1.97 }, { 4.82, 0 } },
		Rear = "wagon", Doors = 4, Spare = true, Flares = true,
		Head = { Style = "round", Z = 0.0, Len = 0.08, W = 0.22, Inset = 0.12 },
		Tail = { Style = "vertical", Z = 0.0, Len = 0.06, W = 0.12, Inset = 0.04 },
		Grille = "slats", Exhaust = "single", Rim = "dish6",
	},
	-- full-size pickup (F-150 class)
	pickup = {
		L = 5.9, W = 2.03, H = 1.96, FO = 0.95, WB = 3.68, D = 0.84, TW = 0.3, Clr = 0.24, GH = 0.84,
		Body = { { 0, 0.86 }, { 0.04, 1.12 }, { 0.15, 1.2 }, { 1.75, 1.28 }, { 1.9, 1.3 }, { 3.48, 1.3 }, { 3.5, 0.98 }, { 5.9, 0.98 } },
		WS0 = 1.9, WS1 = 2.5, R1 = 3.4, RW1 = 3.48,
		Roof = { { 2.5, 1.93 }, { 3.0, 1.96 }, { 3.4, 1.95 }, { 3.48, 0 } },
		Rear = "bed", Doors = 4, Bed = { Z0 = 3.5, Z1 = 5.9, Top = 1.3 },
		Head = { Style = "angular", Z = 0.03, Len = 0.26, W = 0.4, Inset = 0.06 },
		Tail = { Style = "vertical", Z = 0.0, Len = 0.06, W = 0.1, Inset = 0.03 },
		Grille = "tall", Exhaust = "single", Rim = "dish6", Flares = true,
	},
	-- compact sports coupe (TT class)
	coupe = {
		L = 4.19, W = 1.83, H = 1.37, FO = 0.86, WB = 2.5, D = 0.68, TW = 0.25, Clr = 0.12, GH = 0.8,
		Body = { { 0, 0.57 }, { 0.05, 0.66 }, { 0.2, 0.75 }, { 0.7, 0.84 }, { 1.3, 0.89 }, { 1.42, 0.9 }, { 3.55, 0.95 }, { 3.9, 0.95 }, { 4.08, 0.88 }, { 4.19, 0.68 } },
		WS0 = 1.42, WS1 = 2.1, R1 = 2.55, RW1 = 3.9,
		Roof = { { 2.1, 1.34 }, { 2.35, 1.37 }, { 2.55, 1.36 }, { 3.0, 1.27 }, { 3.5, 1.1 }, { 3.9, 0 } },
		Rear = "fastback", Doors = 2,
		Head = { Style = "angular", Z = 0.06, Len = 0.3, W = 0.4, Inset = 0.07 },
		Tail = { Style = "slim", Z = 0.06, Len = 0.18, W = 0.4, Inset = 0.04 },
		Grille = "hex", Exhaust = "dual", Rim = "y7", Spoiler = "lip",
	},
	-- rear-engined sports car (911 class)
	rearengine = {
		L = 4.52, W = 1.85, H = 1.3, FO = 0.98, WB = 2.45, D = 0.7, TW = 0.3, Clr = 0.11, GH = 0.78,
		Body = { { 0, 0.55 }, { 0.06, 0.66 }, { 0.35, 0.72 }, { 1.1, 0.78 }, { 1.42, 0.84 }, { 3.6, 0.92 }, { 4.2, 0.95 }, { 4.42, 0.9 }, { 4.52, 0.66 } },
		WS0 = 1.42, WS1 = 2.02, R1 = 2.55, RW1 = 4.25,
		Roof = { { 2.02, 1.27 }, { 2.3, 1.3 }, { 2.55, 1.28 }, { 3.2, 1.17 }, { 3.8, 1.03 }, { 4.25, 0 } },
		Rear = "fastback", Doors = 2,
		Head = { Style = "round", Z = 0.22, Len = 0.26, W = 0.24, Inset = 0.14, Laid = true },
		Tail = { Style = "bar", Z = 0.12, Len = 0.12, W = 0.32, Inset = 0.04 },
		Grille = "slots", Exhaust = "center", Rim = "twin10", Spoiler = "duck",
	},
	-- front-engined muscle car (Mustang / Camaro class)
	muscle = {
		L = 4.8, W = 1.92, H = 1.38, FO = 0.9, WB = 2.72, D = 0.72, TW = 0.28, Clr = 0.13, GH = 0.8,
		Body = { { 0, 0.66 }, { 0.05, 0.78 }, { 0.2, 0.85 }, { 1.9, 0.94 }, { 2.05, 0.96 }, { 4.1, 1.0 }, { 4.55, 1.01 }, { 4.72, 0.98 }, { 4.8, 0.7 } },
		WS0 = 2.05, WS1 = 2.65, R1 = 3.25, RW1 = 4.15,
		Roof = { { 2.65, 1.35 }, { 2.95, 1.38 }, { 3.25, 1.34 }, { 3.7, 1.2 }, { 4.15, 0 } },
		Rear = "fastback", Doors = 2, Scoop = true,
		Head = { Style = "slim", Z = 0.04, Len = 0.26, W = 0.36, Inset = 0.1 },
		Tail = { Style = "triple", Z = 0.03, Len = 0.1, W = 0.42, Inset = 0.05 },
		Grille = "wide", Exhaust = "quad", Rim = "sport5", Spoiler = "duck",
	},
	-- V10/V12 wedge supercar (Huracán / Aventador class)
	wedge = {
		L = 4.52, W = 1.93, H = 1.17, FO = 1.05, WB = 2.62, D = 0.7, TW = 0.33, Clr = 0.1, GH = 0.78,
		Body = { { 0, 0.42 }, { 0.08, 0.52 }, { 0.6, 0.64 }, { 1.3, 0.76 }, { 1.4, 0.78 }, { 2.9, 0.86 }, { 3.2, 0.9 }, { 4.3, 0.98 }, { 4.44, 0.94 }, { 4.52, 0.72 } },
		WS0 = 1.4, WS1 = 2.3, R1 = 2.75, RW1 = 4.3,
		Roof = { { 2.3, 1.15 }, { 2.5, 1.17 }, { 2.75, 1.15 }, { 3.4, 1.06 }, { 4.3, 0 } },
		Rear = "fastback", Doors = 2, Intakes = true, Vents = true, EngineGlass = true,
		Head = { Style = "angular", Z = 0.12, Len = 0.42, W = 0.3, Inset = 0.06 },
		Tail = { Style = "bar", Z = 0.06, Len = 0.08, W = 0.5, Inset = 0.04 },
		Grille = "mesh", Exhaust = "center", Rim = "y7", Diffuser = true,
	},
	-- mid-engined Italian supercar (F8 / 296 class)
	italian = {
		L = 4.61, W = 1.98, H = 1.21, FO = 1.08, WB = 2.65, D = 0.7, TW = 0.32, Clr = 0.1, GH = 0.78,
		Body = { { 0, 0.45 }, { 0.08, 0.56 }, { 0.45, 0.66 }, { 1.25, 0.78 }, { 1.42, 0.8 }, { 3.2, 0.88 }, { 4.35, 0.96 }, { 4.5, 0.92 }, { 4.61, 0.7 } },
		WS0 = 1.42, WS1 = 2.25, R1 = 2.7, RW1 = 4.25,
		Roof = { { 2.25, 1.18 }, { 2.5, 1.21 }, { 2.7, 1.19 }, { 3.4, 1.07 }, { 4.25, 0 } },
		Rear = "fastback", Doors = 2, Intakes = true, EngineGlass = true,
		Head = { Style = "angular", Z = 0.1, Len = 0.4, W = 0.32, Inset = 0.06 },
		Tail = { Style = "quadround", Z = 0.02, Len = 0.08, W = 0.15, Inset = 0.08 },
		Grille = "mesh", Exhaust = "quad", Rim = "sport5", Diffuser = true, Spoiler = "lip",
	},
	-- hypercar (Chiron / Jesko class)
	hyper = {
		L = 4.54, W = 2.04, H = 1.21, FO = 1.0, WB = 2.71, D = 0.72, TW = 0.36, Clr = 0.11, GH = 0.76,
		Body = { { 0, 0.48 }, { 0.08, 0.6 }, { 0.5, 0.7 }, { 1.3, 0.82 }, { 1.45, 0.84 }, { 3.3, 0.92 }, { 4.3, 0.98 }, { 4.46, 0.92 }, { 4.54, 0.7 } },
		WS0 = 1.45, WS1 = 2.2, R1 = 2.85, RW1 = 4.25,
		Roof = { { 2.2, 1.18 }, { 2.55, 1.21 }, { 2.85, 1.18 }, { 3.5, 1.06 }, { 4.25, 0 } },
		Rear = "fastback", Doors = 2, Intakes = true, Fin = true, EngineGlass = true,
		Head = { Style = "quad", Z = 0.1, Len = 0.3, W = 0.34, Inset = 0.06 },
		Tail = { Style = "bar", Z = 0.04, Len = 0.08, W = 0.5, Inset = 0.04 },
		Grille = "horseshoe", Exhaust = "center", Rim = "turbine", Diffuser = true, Spoiler = "bigwing",
	},
	-- electric liftback saloon (Model S class)
	electric = {
		L = 4.97, W = 1.96, H = 1.44, FO = 0.9, WB = 2.96, D = 0.72, TW = 0.25, Clr = 0.13, GH = 0.8,
		Body = { { 0, 0.6 }, { 0.06, 0.7 }, { 0.3, 0.8 }, { 1.2, 0.9 }, { 1.45, 0.94 }, { 4.05, 1.0 }, { 4.6, 1.0 }, { 4.85, 0.95 }, { 4.97, 0.66 } },
		WS0 = 1.45, WS1 = 2.35, R1 = 3.45, RW1 = 4.55,
		Roof = { { 2.35, 1.41 }, { 2.9, 1.44 }, { 3.45, 1.4 }, { 4.0, 1.24 }, { 4.55, 0 } },
		Rear = "fastback", Doors = 4, Canopy = true,
		Head = { Style = "slim", Z = 0.1, Len = 0.3, W = 0.36, Inset = 0.08 },
		Tail = { Style = "bar", Z = 0.06, Len = 0.12, W = 0.42, Inset = 0.04 },
		Grille = "closed", Exhaust = "none", Rim = "turbine",
	},
	-- Japanese sports coupe (Supra / GT-R class)
	jdm = {
		L = 4.38, W = 1.85, H = 1.29, FO = 0.98, WB = 2.47, D = 0.7, TW = 0.28, Clr = 0.12, GH = 0.78,
		Body = { { 0, 0.52 }, { 0.06, 0.62 }, { 0.4, 0.7 }, { 1.3, 0.8 }, { 1.6, 0.84 }, { 3.6, 0.92 }, { 4.15, 0.97 }, { 4.3, 0.93 }, { 4.38, 0.7 } },
		WS0 = 1.6, WS1 = 2.25, R1 = 2.65, RW1 = 3.95,
		Roof = { { 2.25, 1.26 }, { 2.45, 1.29 }, { 2.65, 1.28 }, { 3.3, 1.12 }, { 3.95, 0 } },
		Rear = "fastback", Doors = 2,
		Head = { Style = "angular", Z = 0.08, Len = 0.32, W = 0.36, Inset = 0.07 },
		Tail = { Style = "bar", Z = 0.05, Len = 0.1, W = 0.46, Inset = 0.04 },
		Grille = "mesh", Exhaust = "dual", Rim = "twin10", Spoiler = "duck", Diffuser = true,
	},
	-- show concept (teardrop canopy, light strips)
	concept = {
		L = 4.9, W = 2.1, H = 1.12, FO = 1.05, WB = 2.85, D = 0.76, TW = 0.36, Clr = 0.1, GH = 0.74,
		Body = { { 0, 0.4 }, { 0.1, 0.52 }, { 0.6, 0.64 }, { 1.35, 0.76 }, { 1.5, 0.78 }, { 3.4, 0.86 }, { 4.6, 0.92 }, { 4.8, 0.86 }, { 4.9, 0.62 } },
		WS0 = 1.5, WS1 = 2.4, R1 = 2.8, RW1 = 4.55,
		Roof = { { 2.4, 1.1 }, { 2.6, 1.12 }, { 2.8, 1.1 }, { 3.6, 1.0 }, { 4.55, 0 } },
		Rear = "fastback", Doors = 2, Canopy = true, SideGlow = true, LightBar = true, Intakes = true, Fin = true,
		Head = { Style = "bar", Z = 0.06, Len = 0.14, W = 0.4, Inset = 0.04 },
		Tail = { Style = "bar", Z = 0.04, Len = 0.08, W = 0.5, Inset = 0.04 },
		Grille = "closed", Exhaust = "none", Rim = "turbine", Diffuser = true,
	},
}

-- Helpers ----------------------------------------------------------------------------------

local function interp(points, z: number): number
	if z <= points[1][1] then
		return points[1][2]
	end
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if z <= b[1] then
			local span = b[1] - a[1]
			local t = if span > 1e-6 then (z - a[1]) / span else 1
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return points[#points][2]
end

local function scalePoints(points, kz: number, ky: number)
	local out = {}
	for i, p in points do
		out[i] = { p[1] * kz, p[2] * ky }
	end
	return out
end

local styleCache: { [string]: any } = {}

-- Fully resolved spec (metres) for a vehicle key: archetype + database Dims/Style overrides.
function VehicleBuilder.getStyle(modelKey: string)
	if styleCache[modelKey] then
		return styleCache[modelKey]
	end
	local model = VehicleDatabase.getModel(modelKey)
	local base = VehicleBuilder.Archetypes[model and model.Body or "sedan"] or VehicleBuilder.Archetypes.sedan
	local s = table.clone(base)
	if model and model.Style then
		for k, v in model.Style do
			s[k] = v
		end
	end
	local dims = (model and model.Dims) or {}
	local kz = (dims.L or base.L) / base.L
	local ky = (dims.H or base.H) / base.H
	s.L = base.L * kz
	s.H = base.H * ky
	s.W = dims.W or base.W
	s.FO = dims.FO or base.FO * kz
	s.WB = dims.WB or base.WB * kz
	s.D = dims.D or base.D
	s.TW = dims.TW or base.TW
	s.Clr = dims.Clr or base.Clr
	s.Body = scalePoints(base.Body, kz, ky)
	s.Roof = scalePoints(base.Roof, kz, ky)
	s.WS0, s.WS1, s.R1, s.RW1 = base.WS0 * kz, base.WS1 * kz, base.R1 * kz, base.RW1 * kz
	if base.Bed then
		s.Bed = { Z0 = base.Bed.Z0 * kz, Z1 = base.Bed.Z1 * kz, Top = base.Bed.Top * ky }
	end
	-- the roof line ends on the body at the rear window
	s.Roof[#s.Roof][2] = interp(s.Body, s.RW1)
	s.Width = s.Width or {
		{ 0, 0.86 }, { s.L * 0.06, 0.96 }, { s.L * 0.18, 1 }, { s.L * 0.84, 1 }, { s.L * 0.95, 0.96 }, { s.L, 0.88 },
	}
	styleCache[modelKey] = s
	return s
end

local function geometry(s)
	local R = s.D / 2
	local Ra = R + 0.07 -- arch radius (gap between tyre and arch)
	local axles = { s.FO, s.FO + s.WB }

	local function bodyTop(z)
		return interp(s.Body, z)
	end
	local function archY(z)
		local y = 0
		for _, a in axles do
			local dz = math.abs(z - a)
			if dz < Ra then
				y = math.max(y, R + math.sqrt(Ra * Ra - dz * dz))
			end
		end
		return y
	end
	local function topAdj(z)
		local arch = archY(z)
		if arch > 0 then
			return math.max(bodyTop(z), arch + (if s.Flares then 0.09 else 0.05))
		end
		return bodyTop(z)
	end
	local function cabinTop(z)
		if z <= s.WS1 then
			local t = math.clamp((z - s.WS0) / math.max(0.01, s.WS1 - s.WS0), 0, 1)
			return bodyTop(s.WS0) + (s.Roof[1][2] - bodyTop(s.WS0)) * t
		end
		return interp(s.Roof, z)
	end
	local function widthF(z)
		return interp(s.Width, z)
	end
	-- lowest point of the body over a segment that intersects an arch (nil if no arch)
	local function archBottom(z0, z1)
		local best = nil
		for _, a in axles do
			local dz = if z0 <= a and a <= z1 then 0 else math.min(math.abs(z0 - a), math.abs(z1 - a))
			if dz < Ra - 1e-4 then
				local b = R + math.sqrt(Ra * Ra - dz * dz)
				best = math.max(best or 0, b)
			end
		end
		return best
	end

	-- slice positions
	local breaks = { 0, s.L, s.WS0, s.WS1, s.R1, s.RW1 }
	for _, p in s.Body do
		table.insert(breaks, p[1])
	end
	for _, p in s.Roof do
		table.insert(breaks, p[1])
	end
	for _, p in s.Width do
		table.insert(breaks, p[1])
	end
	for _, a in axles do
		table.insert(breaks, a)
		for _, k in { 0.3, 0.6, 0.82, 0.95, 1 } do
			table.insert(breaks, a - Ra * k)
			table.insert(breaks, a + Ra * k)
		end
	end
	if s.Bed then
		table.insert(breaks, s.Bed.Z0)
		table.insert(breaks, s.Bed.Z1)
	end
	table.sort(breaks)
	local unique = {}
	for _, z in breaks do
		if z >= 0 and z <= s.L and (#unique == 0 or z - unique[#unique] > 0.015) then
			table.insert(unique, z)
		end
	end
	if unique[#unique] < s.L then
		unique[#unique] = s.L
	end

	local maxTop = 0
	for _, z in unique do
		maxTop = math.max(maxTop, topAdj(z))
	end

	return {
		R = R,
		Ra = Ra,
		axles = axles,
		bodyTop = bodyTop,
		topAdj = topAdj,
		cabinTop = cabinTop,
		widthF = widthF,
		archBottom = archBottom,
		breaks = unique,
		maxTop = maxTop,
	}
end

-- Size information without building (used for tarps, cameras and previews). Values in studs.
function VehicleBuilder.getDimensions(modelKey: string)
	local s = VehicleBuilder.getStyle(modelKey)
	local g = geometry(s)
	local L = s.L * S
	local belt = g.bodyTop(s.WS0) * S
	local height = 0
	for _, p in s.Roof do
		height = math.max(height, p[2])
	end
	height *= S
	return {
		L = L,
		W = s.W * S + 0.5,
		H = height,
		Belt = belt,
		CabH = height - belt,
		CabStart = -L / 2 + s.WS0 * S,
		CabEnd = -L / 2 + s.RW1 * S,
		BodyTop = g.maxTop * S,
	}
end

local function finishProps(finish: string): (Enum.Material, number)
	if finish == "metallic" then
		return PLASTIC, 0.16
	elseif finish == "matte" then
		return PLASTIC, 0
	elseif finish == "pearl" then
		return PLASTIC, 0.24
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

local function fromTemplate(record, template: Model)
	local car = template:Clone()
	car.Name = "Vehicle"
	local paint = VehicleDatabase.ColorByKey[(record.mods and record.mods.Paint and record.mods.Paint.key) or record.color]
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			if paint and (d:GetAttribute("Paint") == true or d.Name == "Paint") then
				d.Color = paint.Color
			end
		end
	end
	if not car.PrimaryPart then
		car.PrimaryPart = car:FindFirstChildWhichIsA("BasePart", true)
	end
	local size = car:GetExtentsSize()
	car:SetAttribute("VehicleId", record.id)
	car:SetAttribute("ModelKey", record.modelKey)
	car:SetAttribute("Rarity", record.rarity)
	return car, { L = size.Z, W = size.X, H = size.Y, Belt = size.Y * 0.6 }
end

local function findTemplate(modelKey: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("VehicleModels")
	local template = folder and folder:FindFirstChild(modelKey)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

-- options: { lowDetail: boolean? }
function VehicleBuilder.build(record, options: { lowDetail: boolean? }?)
	local template = findTemplate(record.modelKey)
	if template then
		return fromTemplate(record, template)
	end

	local opts = options or {}
	local s = VehicleBuilder.getStyle(record.modelKey)
	local g = geometry(s)
	local mods = record.mods or {}

	local paintKey = (mods.Paint and mods.Paint.key) or record.color
	local paint = VehicleDatabase.ColorByKey[paintKey] or VehicleDatabase.Colors[1]
	local interior = VehicleDatabase.InteriorByKey[record.interior] or VehicleDatabase.Interiors[1]
	local paintColor = paint.Color
	local paintMaterial, paintRefl = finishProps(paint.Finish)
	local accent = s.Accent or COLORS.Head
	local rimStyleKey = (mods.Rims and mods.Rims.key) or s.Rim or "sport5"
	local rimStyle = VehicleBuilder.RimStyles[rimStyleKey] or VehicleBuilder.RimStyles.sport5
	local rimColor = (mods.RimColor and VehicleBuilder.RimColors[mods.RimColor.key])
		or s.RimColor
		or (if rimStyleKey == "steel" then COLORS.Disc else VehicleBuilder.RimColors.Silver)
	local caliperColor = s.Caliper or (if mods.Brakes then Color3.fromRGB(220, 30, 30) else COLORS.Disc)
	local glassTransparency = if mods.Tint then 0.1 else 0.3
	local drop = (mods.Suspension and tonumber(mods.Suspension.drop)) or 0 -- metres

	local Ls = s.L * S
	local function zl(zm: number): number
		return -Ls / 2 + zm * S
	end
	local yOff = -drop * S
	local function yl(ym: number): number
		return ym * S + yOff
	end

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
	local function dark(name, size, cf, className, color)
		return make(className or "Part", car, name, size, cf, color or COLORS.Dark, PLASTIC)
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
	local function neon(name, size, cf, color, className)
		return make(className or "Part", car, name, size, cf, color, NEON)
	end

	-- Root (invisible pivot / hit box)
	local heightS = 0
	for _, p in s.Roof do
		heightS = math.max(heightS, p[2] * S)
	end
	local root = make("Part", car, "Root", V3(s.W * S, heightS, Ls), CF(0, heightS / 2, 0), Color3.new(1, 1, 1), PLASTIC, {
		Transparency = 1,
		CanQuery = true,
	})
	root.PivotOffset = CF(0, -heightS / 2, 0)
	car.PrimaryPart = root

	-- Slice builder (boxes are merged when neighbouring slices are identical) -------------------
	local pending: { [string]: any } = {}
	local function flush(kind: string)
		local b = pending[kind]
		if not b then
			return
		end
		pending[kind] = nil
		local size = V3(b.w, b.t - b.b, b.z1 - b.z0)
		local cf = CF(0, (b.b + b.t) / 2, (b.z0 + b.z1) / 2)
		if kind == "glass" then
			make("Part", car, "Glass", size, cf, COLORS.Glass, GLASS, { Transparency = glassTransparency, Reflectance = 0.25, CanCollide = true })
		elseif kind == "tub" then
			dark("WheelWell", size, cf)
		else
			bodyPart("Part", "Body", size, cf, { CanCollide = true, CastShadow = true })
		end
	end
	local function box(kind: string, w: number, z0: number, z1: number, bottom: number, top: number)
		if top - bottom < 0.02 or z1 - z0 < 0.005 then
			return
		end
		local b = pending[kind]
		if b and math.abs(b.w - w) < 1e-3 and math.abs(b.b - bottom) < 1e-3 and math.abs(b.t - top) < 1e-3 and math.abs(b.z1 - z0) < 1e-3 then
			b.z1 = z1
			return
		end
		flush(kind)
		pending[kind] = { w = w, z0 = z0, z1 = z1, b = bottom, t = top }
	end
	local function slope(kind: string, w: number, z0: number, z1: number, base: number, t0: number, t1: number)
		local hi = math.max(t0, t1)
		local h = hi - base
		if h < 0.012 or z1 - z0 < 0.005 then
			return
		end
		local cf = CF(0, base + h / 2, (z0 + z1) / 2) * (if t1 >= t0 then CFrame.identity else FLIP)
		local size = V3(w, h, z1 - z0)
		if kind == "glass" then
			make("WedgePart", car, "Glass", size, cf, COLORS.Glass, GLASS, { Transparency = glassTransparency, Reflectance = 0.25 })
		else
			bodyPart("WedgePart", "Body", size, cf, { CastShadow = true })
		end
	end

	-- Body ------------------------------------------------------------------------------------
	local Wm = s.W
	local twS = s.TW * S
	local breaks = g.breaks
	for i = 1, #breaks - 1 do
		local z0, z1 = breaks[i], breaks[i + 1]
		local zc = (z0 + z1) / 2
		local w = Wm * S * g.widthF(zc)
		local t0, t1 = yl(g.topAdj(z0)), yl(g.topAdj(z1))
		local arch = g.archBottom(z0, z1)
		local lift = if zc < 0.12 or zc > s.L - 0.12 then 0.06 else 0
		local bottom = if arch then yl(arch) else yl(s.Clr + lift)
		local low = math.min(t0, t1)
		box("body", w, zl(z0), zl(z1), bottom, low)
		if math.abs(t1 - t0) > 0.01 then
			flush("body")
			slope("body", w, zl(z0), zl(z1), math.max(low, bottom), t0, t1)
		end
		if arch then
			box("tub", w - 2 * (twS + 0.1), zl(z0), zl(z1), yl(s.Clr + 0.04), bottom)
		else
			flush("tub")
		end
	end
	flush("body")
	flush("tub")

	-- Greenhouse --------------------------------------------------------------------------------
	local GH = s.GH or 0.8
	for i = 1, #breaks - 1 do
		local z0, z1 = breaks[i], breaks[i + 1]
		if z0 >= s.WS0 - 1e-4 and z1 <= s.RW1 + 1e-4 then
			local zc = (z0 + z1) / 2
			local gw = Wm * S * g.widthF(zc) * GH
			local gb = yl(math.min(g.bodyTop(z0), g.bodyTop(z1))) - 0.05
			local c0, c1 = yl(g.cabinTop(z0)), yl(g.cabinTop(z1))
			local low = math.min(c0, c1)
			box("glass", gw, zl(z0), zl(z1), gb, low)
			if math.abs(c1 - c0) > 0.01 then
				flush("glass")
				slope("glass", gw, zl(z0), zl(z1), math.max(low, gb), c0, c1)
			end
		end
	end
	flush("glass")

	-- Roof skin + pillars ---------------------------------------------------------------------
	local function lineBetween(name, p0: Vector3, p1: Vector3, width: number, thickness: number, color: Color3?, material: Enum.Material?, extra)
		local len = (p1 - p0).Magnitude
		if len < 0.01 then
			return nil
		end
		local mid = (p0 + p1) / 2
		local props = { Reflectance = if color then 0.05 else paintRefl }
		if extra then
			for k, v in extra do
				props[k] = v
			end
		end
		return make("Part", car, name, V3(width, thickness, len), CFrame.lookAt(mid, p1), color or paintColor, material or paintMaterial, props)
	end

	local roofColor = if s.Canopy then nil elseif s.RoofBlack then COLORS.Trim else nil
	for i = 1, #breaks - 1 do
		local z0, z1 = breaks[i], breaks[i + 1]
		if z0 >= s.WS1 - 1e-4 and z1 <= s.R1 + 1e-4 then
			local gw = Wm * S * g.widthF((z0 + z1) / 2) * GH
			local p0 = V3(0, yl(g.cabinTop(z0)) + 0.06, zl(z0))
			local p1 = V3(0, yl(g.cabinTop(z1)) + 0.06, zl(z1))
			if s.Canopy then
				make("Part", car, "GlassRoof", V3(gw + 0.08, 0.1, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), COLORS.Glass, GLASS, { Transparency = 0.15, Reflectance = 0.35 })
			else
				lineBetween("Roof", p0, p1, gw + 0.1, 0.12, roofColor, if roofColor then PLASTIC else nil, { CastShadow = true })
			end
		end
	end

	for _, side in { -1, 1 } do
		local function px(z)
			return side * (Wm * S * g.widthF(z) * GH / 2)
		end
		-- A pillar
		lineBetween("APillar", V3(px(s.WS0), yl(g.bodyTop(s.WS0)), zl(s.WS0)), V3(px(s.WS1), yl(g.cabinTop(s.WS1)) + 0.03, zl(s.WS1)), 0.14, 0.14, if s.Canopy then COLORS.Trim else nil, if s.Canopy then PLASTIC else nil)
		-- C / D pillar (wide on saloons)
		local cWidth = if s.Rear == "notch" then 0.34 else 0.16
		lineBetween("CPillar", V3(px(s.R1), yl(g.cabinTop(s.R1)) + 0.03, zl(s.R1)), V3(px(s.RW1), yl(g.bodyTop(s.RW1)), zl(s.RW1)), cWidth, cWidth, if s.Canopy then COLORS.Trim else nil, if s.Canopy then PLASTIC else nil)
		-- B pillar (black, flush)
		if s.Doors >= 4 and s.R1 - s.WS1 > 0.8 then
			local bz = s.WS1 + (s.R1 - s.WS1) * 0.42
			local yb = yl(g.bodyTop(bz))
			local yt = yl(g.cabinTop(bz))
			dark("BPillar", V3(0.1, yt - yb, 0.22), CF(px(bz) + side * 0.02, (yb + yt) / 2, zl(bz)), "Part", COLORS.Trim)
		end
		-- beltline trim (chrome on luxury cars)
		local beltColor = if s.Chrome then COLORS.Chrome else COLORS.Trim
		lineBetween("BeltTrim", V3(px(s.WS0) + side * 0.03, yl(g.bodyTop(s.WS0)) + 0.02, zl(s.WS0)), V3(px(s.RW1) + side * 0.03, yl(g.bodyTop(s.RW1)) + 0.02, zl(s.RW1)), 0.06, 0.07, beltColor, PLASTIC, { Reflectance = if s.Chrome then 0.45 else 0 })
		-- mirrors
		local mz = s.WS0 + 0.18
		local mx = side * (Wm * S * g.widthF(mz) / 2 + 0.18)
		bodyPart("Part", "Mirror", V3(0.36, 0.28, 0.42), CF(mx, yl(g.bodyTop(mz)) + 0.36, zl(mz)) * CFrame.Angles(0, side * 0.12, 0))
		dark("MirrorGlass", V3(0.3, 0.22, 0.05), CF(mx, yl(g.bodyTop(mz)) + 0.36, zl(mz) + 0.2), "Part", Color3.fromRGB(150, 170, 190))
		dark("MirrorArm", V3(0.3, 0.08, 0.14), CF(mx - side * 0.25, yl(g.bodyTop(mz)) + 0.24, zl(mz) + 0.05))
	end

	-- Door seams and handles ---------------------------------------------------------------------
	local frontArchEnd = g.axles[1] + g.Ra + 0.06
	local rearArchStart = g.axles[2] - g.Ra - 0.06
	local seams = { math.max(frontArchEnd, s.WS0 - 0.05) }
	if s.Doors >= 4 then
		table.insert(seams, s.WS1 + (s.R1 - s.WS1) * 0.42)
		table.insert(seams, math.min(rearArchStart, s.RW1 - 0.1))
	else
		table.insert(seams, math.min(rearArchStart - 0.18, s.WS1 + (s.R1 - s.WS1) * 0.95))
	end
	if s.Rear == "bed" then
		seams[#seams] = math.min(seams[#seams], s.RW1 - 0.05)
	end
	for i, z in seams do
		if z > 0 and z < s.L then
			local top = yl(g.bodyTop(z)) - 0.06
			local bottom = yl(s.Clr) + 0.08
			dark("DoorSeam", V3(Wm * S * g.widthF(z) + 0.02, top - bottom, 0.04), CF(0, (top + bottom) / 2, zl(z)), "Part", COLORS.Trim)
			if i < #seams then
				local hz = seams[i + 1] - 0.22
				chrome("DoorHandle", V3(Wm * S * g.widthF(hz) + 0.05, 0.08, 0.36), CF(0, yl(g.bodyTop(hz)) - 0.32, zl(hz)))
			end
		end
	end

	-- Wheels with brake discs and calipers ------------------------------------------------------
	local spokes = if opts.lowDetail then 0 else rimStyle.Spokes
	local Rs = g.R * S
	for ai, a in g.axles do
		for _, side in { -1, 1 } do
			local x = side * (Wm * S * g.widthF(a) / 2 - twS / 2 - 0.04)
			local c = CF(x, Rs, zl(a))
			make("Part", car, "Tire", V3(twS, 2 * Rs, 2 * Rs), c, COLORS.Tire, PLASTIC, { Shape = Enum.PartType.Cylinder, CastShadow = true })
			make("Part", car, "TireWall", V3(twS + 0.02, 2 * Rs * 0.9, 2 * Rs * 0.9), c, Color3.fromRGB(34, 34, 36), PLASTIC, { Shape = Enum.PartType.Cylinder })
			local faceX = x + side * (twS / 2 + 0.02)
			local rimR = Rs * 0.72
			make("Part", car, "Rim", V3(0.06, rimR * 2, rimR * 2), CF(faceX, Rs, zl(a)), rimColor, METAL, { Shape = Enum.PartType.Cylinder, Reflectance = 0.25 })
			if spokes > 0 then
				make("Part", car, "RimBarrel", V3(0.07, rimR * 1.78, rimR * 1.78), CF(faceX + side * 0.01, Rs, zl(a)), COLORS.Dark, PLASTIC, { Shape = Enum.PartType.Cylinder })
				-- brake disc + caliper visible between the spokes
				make("Part", car, "BrakeDisc", V3(0.075, rimR * 1.3, rimR * 1.3), CF(faceX + side * 0.015, Rs, zl(a)), COLORS.Disc, METAL, { Shape = Enum.PartType.Cylinder })
				make("Part", car, "Caliper", V3(0.09, rimR * 0.36, rimR * 0.5), CF(faceX + side * 0.02, Rs + rimR * 0.5, zl(a) + (if ai == 1 then rimR * 0.35 else -rimR * 0.35)), caliperColor, PLASTIC)
				for k = 1, spokes do
					local angle = (k / spokes) * math.pi * 2
					make("Part", car, "Spoke", V3(0.06, rimR * rimStyle.Width * 2, rimR * 0.82), CF(faceX + side * 0.04, Rs, zl(a)) * CFrame.Angles(angle, 0, 0) * CF(0, 0, -rimR * 0.5), rimColor, METAL, { Reflectance = 0.25 })
				end
			end
			make("Part", car, "Hub", V3(0.1, rimR * 0.36, rimR * 0.36), CF(faceX + side * 0.05, Rs, zl(a)), COLORS.Chrome, PLASTIC, { Shape = Enum.PartType.Cylinder, Reflectance = 0.4 })
			if s.Flares then
				-- off-road wheel arch flares (black plastic)
				local archTop = yl(g.R + g.Ra) + 0.02
				dark("Flare", V3(0.14, 0.16, g.Ra * 2 * S), CF(side * (Wm * S * g.widthF(a) / 2 + 0.03), archTop, zl(a)), "Part", COLORS.Trim)
			end
		end
	end

	-- Lights -----------------------------------------------------------------------------------
	-- a piece lying on the body surface between two z positions (metres)
	local function onSurface(name, zA, zB, xCenter, width, lift, color, material, thickness)
		local p0 = V3(xCenter, yl(g.bodyTop(zA) + lift), zl(zA))
		local p1 = V3(xCenter, yl(g.bodyTop(zB) + lift), zl(zB))
		return lineBetween(name, p0, p1, width, thickness or 0.06, color, material, { Reflectance = 0 })
	end
	local function lampDisk(name, zm, xCenter, diameter, color)
		-- round lamp lying on the surface, facing along the surface normal
		local zA, zB = zm - 0.05, zm + 0.05
		local p0 = V3(xCenter, yl(g.bodyTop(zA)), zl(zA))
		local p1 = V3(xCenter, yl(g.bodyTop(zB)), zl(zB))
		local d = (p1 - p0).Unit
		local normal = V3(0, -d.Z, d.Y)
		if normal.Y < 0 then
			normal = -normal
		end
		local center = (p0 + p1) / 2 + normal * 0.02
		return make("Part", car, name, V3(0.06, diameter * S, diameter * S), CFrame.lookAt(center, center + normal) * FACE_Z, color, NEON, { Shape = Enum.PartType.Cylinder })
	end
	local function faceDisk(name, front: boolean, x, y, diameter, color)
		local z = if front then zl(0) - 0.02 else zl(s.L) + 0.02
		return make("Part", car, name, V3(0.1, diameter * S, diameter * S), CF(x, y, z) * FACE_Z, color, NEON, { Shape = Enum.PartType.Cylinder })
	end

	local head = s.Head
	for _, side in { -1, 1 } do
		local wf = g.widthF(head.Z + head.Len / 2)
		local hx = side * (Wm * wf / 2 - head.Inset - head.W / 2) * S
		if head.Style == "round" and not head.Laid then
			faceDisk("Headlight", true, hx, yl(g.bodyTop(0.05) - head.W / 2 - 0.04), head.W, COLORS.Head)
		elseif head.Style == "round" then
			lampDisk("Headlight", head.Z + head.Len / 2, hx, head.W, COLORS.Head)
		elseif head.Style == "quadround" then
			for k = 0, 1 do
				faceDisk("Headlight", true, side * (Wm / 2 - head.Inset - head.W / 2 - k * (head.W + 0.03)) * S, yl(g.bodyTop(0.05) - head.W / 2 - 0.03), head.W, COLORS.Head)
			end
		elseif head.Style == "quad" then
			for k = 0, 1 do
				local qx = side * (Wm * wf / 2 - head.Inset - head.W * 0.25 - k * head.W * 0.5) * S
				onSurface("HeadHousing", head.Z, head.Z + head.Len, qx, head.W * 0.45 * S, 0.004, COLORS.HeadHousing, PLASTIC)
				onSurface("Headlight", head.Z + 0.03, head.Z + head.Len - 0.03, qx, head.W * 0.32 * S, 0.008, COLORS.Head, NEON)
			end
		else
			-- slim / angular / bar: housing, lens and a daytime running light strip
			onSurface("HeadHousing", head.Z, head.Z + head.Len, hx, head.W * S, 0.004, COLORS.HeadHousing, PLASTIC)
			local lensW = if head.Style == "angular" then head.W * 0.55 else head.W * 0.8
			onSurface("Headlight", head.Z + 0.02, head.Z + head.Len - 0.04, hx + side * (head.W - lensW) * 0.25 * S, lensW * S, 0.008, COLORS.Head, NEON)
			onSurface("DRL", head.Z + 0.01, head.Z + head.Len * 0.7, hx - side * head.W * 0.42 * S, 0.06 * S, 0.012, accent, NEON)
		end

		-- tail lights
		local tail = s.Tail
		local tz1 = s.L - tail.Z
		local tz0 = tz1 - tail.Len
		local twf = g.widthF(tz1)
		local tx = side * (Wm * twf / 2 - tail.Inset - tail.W / 2) * S
		if tail.Style == "vertical" then
			local topY = if s.Bed then yl(s.Bed.Top) - 0.08 else yl(g.bodyTop(s.L - 0.02)) - 0.06
			neon("Taillight", V3(tail.W * S, 0.45 * S, 0.06), CF(tx, topY - 0.45 * S / 2, zl(s.L) + 0.02), COLORS.Tail)
		elseif tail.Style == "round" or tail.Style == "quadround" then
			local y = yl(g.bodyTop(s.L - 0.02)) - tail.W * S / 2 - 0.05
			local count = if tail.Style == "quadround" then 2 else 1
			for k = 0, count - 1 do
				faceDisk("Taillight", false, side * (Wm * twf / 2 - tail.Inset - tail.W / 2 - k * (tail.W + 0.05)) * S, y, tail.W, COLORS.Tail)
			end
		elseif tail.Style == "triple" then
			for k = 0, 2 do
				local seg = tail.W / 3
				onSurface("Taillight", tz0, tz1, side * (Wm * twf / 2 - tail.Inset - seg / 2 - k * seg) * S, seg * 0.75 * S, 0.008, COLORS.Tail, NEON)
			end
		else
			onSurface("TailHousing", tz0 - 0.02, tz1, tx, (tail.W + 0.04) * S, 0.004, COLORS.Trim, PLASTIC)
			onSurface("Taillight", tz0, tz1 - 0.01, tx, tail.W * S, 0.008, COLORS.Tail, NEON)
		end
	end
	if s.Tail.Style == "bar" or s.LightBar then
		local tz1 = s.L - s.Tail.Z
		onSurface("TailBar", tz1 - 0.05, tz1, 0, (Wm * 0.62) * S, 0.009, COLORS.Tail, NEON)
	end
	if s.Head.Style == "bar" or s.LightBar then
		onSurface("FrontBar", s.Head.Z, s.Head.Z + 0.04, 0, (Wm * 0.62) * S, 0.012, accent, NEON)
	end

	-- Grille / front face ----------------------------------------------------------------------
	local faceTop = g.bodyTop(0)
	local faceZ = zl(0) - 0.02
	local clr = s.Clr
	local grille = s.Grille
	if grille == "wide" then
		local y0, y1 = clr + 0.2, faceTop - 0.03
		if y1 > y0 then
			dark("Grille", V3(Wm * 0.48 * S, (y1 - y0) * S, 0.06), CF(0, yl((y0 + y1) / 2), faceZ))
		end
		dark("LowerIntake", V3(Wm * 0.7 * S, 0.1 * S, 0.06), CF(0, yl(clr + 0.1), faceZ))
		if s.Chrome then
			chrome("GrilleChrome", V3(Wm * 0.5 * S, 0.03 * S, 0.08), CF(0, yl(faceTop - 0.03), faceZ))
		end
	elseif grille == "hex" then
		local y0, y1 = clr + 0.06, faceTop - 0.02
		dark("Grille", V3(Wm * 0.42 * S, (y1 - y0) * S, 0.06), CF(0, yl((y0 + y1) / 2), faceZ))
		chrome("GrilleFrame", V3(Wm * 0.44 * S, 0.025 * S, 0.08), CF(0, yl(y1), faceZ), "Part", { Color = COLORS.Disc })
		for _, side in { -1, 1 } do
			dark("SideIntake", V3(Wm * 0.14 * S, 0.12 * S, 0.06), CF(side * Wm * 0.36 * S, yl(clr + 0.12), faceZ))
		end
	elseif grille == "tall" then
		local y0, y1 = clr + 0.28, faceTop + 0.06
		local gw = Wm * 0.3 * S
		local gh = (y1 - y0) * S
		local gy = yl((y0 + y1) / 2)
		dark("Grille", V3(gw, gh, 0.08), CF(0, gy, faceZ))
		for k = -2, 2 do
			chrome("GrilleSlat", V3(0.05, gh, 0.1), CF(k * gw / 5, gy, faceZ - 0.01))
		end
		chrome("GrilleFrameTop", V3(gw + 0.14, 0.1, 0.12), CF(0, gy + gh / 2, faceZ - 0.01))
		chrome("GrilleFrameBottom", V3(gw + 0.14, 0.1, 0.12), CF(0, gy - gh / 2, faceZ - 0.01))
		dark("LowerIntake", V3(Wm * 0.6 * S, 0.08 * S, 0.06), CF(0, yl(clr + 0.12), faceZ))
	elseif grille == "mesh" then
		dark("Intake", V3(Wm * 0.5 * S, math.max(0.06, faceTop - clr - 0.12) * S, 0.06), CF(0, yl(clr + 0.05 + (faceTop - clr - 0.12) / 2), faceZ))
		for _, side in { -1, 1 } do
			dark("CornerIntake", V3(Wm * 0.18 * S, math.max(0.06, faceTop - clr - 0.08) * S, 0.06), CF(side * Wm * 0.36 * S, yl(clr + 0.04 + (faceTop - clr - 0.08) / 2), faceZ))
		end
	elseif grille == "horseshoe" then
		local h = math.max(0.1, faceTop - clr - 0.06)
		dark("Grille", V3(Wm * 0.18 * S, h * S, 0.06), CF(0, yl(clr + 0.04 + h / 2), faceZ))
		chrome("GrilleRim", V3(Wm * 0.2 * S, 0.03 * S, 0.08), CF(0, yl(clr + 0.04 + h), faceZ))
		for _, side in { -1, 1 } do
			dark("Intake", V3(Wm * 0.2 * S, h * 0.8 * S, 0.06), CF(side * Wm * 0.3 * S, yl(clr + 0.04 + h * 0.4), faceZ))
		end
	elseif grille == "slats" then
		local y0, y1 = clr + 0.3, faceTop - 0.04
		for k = 0, 3 do
			local y = y0 + (y1 - y0) * (k + 0.5) / 4
			dark("GrilleSlat", V3(Wm * 0.45 * S, 0.035 * S, 0.06), CF(0, yl(y), faceZ))
		end
		dark("Bumper", V3(Wm * 0.95 * S, 0.12 * S, 0.12), CF(0, yl(clr + 0.16), faceZ - 0.04), "Part", COLORS.Trim)
	elseif grille == "slots" then
		for k = 0, 2 do
			dark("Slot", V3(Wm * (0.2 + k * 0.05) * S, 0.03 * S, 0.06), CF(0, yl(clr + 0.08 + k * 0.06), faceZ))
		end
	elseif grille == "closed" and s.Accent then
		neon("GrilleAccent", V3(Wm * 0.4 * S, 0.06, 0.06), CF(0, yl(faceTop - 0.05), faceZ), accent)
	end

	-- rear face: plate, diffuser, exhaust
	local rearZ = zl(s.L) + 0.02
	local rearTop = if s.Bed then s.Bed.Top else g.bodyTop(s.L)
	make("Part", car, "PlateRear", V3(0.52 * S, 0.12 * S, 0.05), CF(0, yl(clr + (rearTop - clr) * 0.55), rearZ + 0.01), COLORS.Plate, PLASTIC)
	if s.Diffuser then
		dark("Diffuser", V3(Wm * 0.7 * S, 0.12 * S, 0.3 * S), CF(0, yl(clr + 0.05), zl(s.L - 0.15)))
		for k = -2, 2 do
			dark("DiffuserFin", V3(0.05, 0.16 * S, 0.3 * S), CF(k * Wm * 0.14 * S, yl(clr + 0.06), zl(s.L - 0.14)))
		end
	end
	local exhaustXs = {}
	if s.Exhaust == "single" then
		exhaustXs = { Wm * 0.32 }
	elseif s.Exhaust == "dual" then
		exhaustXs = { -Wm * 0.32, Wm * 0.32 }
	elseif s.Exhaust == "quad" then
		exhaustXs = { -Wm * 0.36, -Wm * 0.28, Wm * 0.28, Wm * 0.36 }
	elseif s.Exhaust == "center" then
		exhaustXs = { -0.07, 0.07 }
	end
	for _, x in exhaustXs do
		chrome("Exhaust", V3(0.3 * S, 0.09 * S, 0.09 * S), CF(x * S, yl(clr + 0.09), rearZ - 0.1) * FACE_Z, "Part", { Shape = Enum.PartType.Cylinder })
		dark("ExhaustHole", V3(0.31 * S, 0.065 * S, 0.065 * S), CF(x * S, yl(clr + 0.09), rearZ - 0.1) * FACE_Z, "Part")
			.Shape = Enum.PartType.Cylinder
	end

	-- Spoilers -----------------------------------------------------------------------------------
	local spoiler = (mods.Spoiler and mods.Spoiler.key) or s.Spoiler
	if spoiler == "none" then
		spoiler = nil
	end
	local hasDeck = s.Rear == "notch" or s.Rear == "fastback"
	if spoiler and hasDeck then
		local deckZ = s.L - 0.22
		local deckY = yl(g.bodyTop(deckZ))
		if spoiler == "lip" then
			bodyPart("WedgePart", "Spoiler", V3(Wm * 0.78 * S, 0.06 * S, 0.18 * S), CF(0, deckY + 0.03 * S, zl(s.L - 0.14)))
		elseif spoiler == "duck" then
			bodyPart("WedgePart", "Spoiler", V3(Wm * 0.9 * S, 0.1 * S, 0.34 * S), CF(0, yl(g.bodyTop(s.L - 0.24)) + 0.05 * S, zl(s.L - 0.22)))
		elseif spoiler == "wing" or spoiler == "bigwing" then
			local big = spoiler == "bigwing"
			local postH = (if big then 0.42 else 0.26) * S
			local wz = zl(s.L - (if big then 0.22 else 0.3))
			local plateColor = if big then COLORS.Carbon else paintColor
			for _, side in { -1, 1 } do
				dark("WingPost", V3(0.05 * S, postH, 0.1 * S), CF(side * Wm * 0.3 * S, deckY + postH / 2, wz), "Part", COLORS.Carbon)
				dark("WingEndplate", V3(0.02 * S, 0.16 * S, 0.34 * S), CF(side * Wm * (if big then 0.5 else 0.44) * S, deckY + postH, wz), "Part", COLORS.Carbon)
			end
			make("Part", car, "Wing", V3(Wm * (if big then 1.0 else 0.88) * S, 0.03 * S, 0.3 * S), CF(0, deckY + postH, wz) * CFrame.Angles(0.1, 0, 0), plateColor, paintMaterial, { Reflectance = paintRefl })
		end
	elseif spoiler then
		-- roof spoiler for hatchbacks / estates / SUVs
		local gw = Wm * S * g.widthF(s.R1) * GH
		local y = yl(g.cabinTop(s.R1)) + 0.08
		bodyPart("Part", "RoofSpoiler", V3(gw, 0.08, 0.26 * S), CF(0, y, zl(s.R1) + 0.12 * S) * CFrame.Angles(0.15, 0, 0))
	end

	-- Extras ----------------------------------------------------------------------------------------
	if s.Scoop then
		local z0, z1 = s.WS0 * 0.35, s.WS0 * 0.75
		onSurface("HoodScoop", z0, z1, 0, Wm * 0.28 * S, 0.06, nil, nil, 0.16)
		onSurface("ScoopInlet", z0 - 0.01, z0 + 0.06, 0, Wm * 0.24 * S, 0.09, COLORS.Trim, PLASTIC, 0.12)
	end
	if s.Vents then
		for _, side in { -1, 1 } do
			onSurface("HoodVent", s.WS0 * 0.5, s.WS0 * 0.8, side * Wm * 0.16 * S, Wm * 0.12 * S, 0.006, COLORS.Trim, PLASTIC)
		end
	end
	if s.EngineGlass then
		-- louvres over the engine cover
		for k = 1, 3 do
			local z = s.R1 + (s.RW1 - s.R1) * (k / 4)
			local gw = Wm * S * g.widthF(z) * GH * 0.7
			make("Part", car, "Louvre", V3(gw, 0.05, 0.08), CF(0, yl(g.cabinTop(z)) + 0.04, zl(z)), COLORS.Trim, PLASTIC)
		end
	end
	if s.Rack then
		for _, side in { -1, 1 } do
			local x = side * (Wm * S * GH / 2 - 0.2)
			lineBetween("RoofRail", V3(x, yl(g.cabinTop(s.WS1 + 0.15)) + 0.16, zl(s.WS1 + 0.15)), V3(x, yl(g.cabinTop(s.R1 - 0.05)) + 0.16, zl(s.R1 - 0.05)), 0.1, 0.1, COLORS.Trim, PLASTIC)
		end
	end
	if s.Intakes then
		local z0 = g.axles[2] - g.Ra - 0.55
		local z1 = g.axles[2] - g.Ra - 0.06
		local zc = (z0 + z1) / 2
		local top = g.bodyTop(zc) - 0.08
		local bottom = s.Clr + 0.16
		if top > bottom then
			dark("SideIntake", V3(Wm * S * g.widthF(zc) + 0.04, (top - bottom) * S, (z1 - z0) * S), CF(0, yl((top + bottom) / 2), zl(zc)), "Part", COLORS.Trim)
		end
	end
	if s.Fin then
		lineBetween("Fin", V3(0, yl(g.cabinTop(s.R1)) + 0.15, zl(s.R1)), V3(0, yl(g.bodyTop(s.L - 0.3)) + 0.15, zl(s.L - 0.3)), 0.1, 0.32)
	end
	if s.SideGlow then
		neon("SideGlow", V3(Wm * S + 0.03, 0.06, (s.WB - 2 * g.Ra - 0.1) * S), CF(0, yl(s.Clr + 0.06), zl(s.FO + s.WB / 2)), accent)
	end
	if s.Spare then
		local y = yl(s.Clr + 0.6)
		make("Part", car, "SpareTire", V3(0.26 * S, s.D * 0.95 * S, s.D * 0.95 * S), CF(0, y, rearZ + 0.13 * S) * FACE_Z, COLORS.Tire, PLASTIC, { Shape = Enum.PartType.Cylinder })
		make("Part", car, "SpareCover", V3(0.27 * S, s.D * 0.75 * S, s.D * 0.75 * S), CF(0, y, rearZ + 0.13 * S) * FACE_Z, paintColor, paintMaterial, { Shape = Enum.PartType.Cylinder })
	end
	if s.BullBar then
		for _, y in { s.Clr + 0.18, faceTop - 0.04 } do
			dark("BullBar", V3(Wm * 0.62 * S, 0.05 * S, 0.05 * S), CF(0, yl(y), faceZ - 0.12 * S), "Part", COLORS.Trim)
		end
	end
	if s.Bed then
		local bz0, bz1 = zl(s.Bed.Z0), zl(s.Bed.Z1)
		local floorY = yl(g.bodyTop(s.Bed.Z0 + 0.1))
		local topY = yl(s.Bed.Top)
		local wallH = topY - floorY
		local bw = Wm * S
		for _, side in { -1, 1 } do
			bodyPart("Part", "BedWall", V3(0.07 * S, wallH, bz1 - bz0), CF(side * (bw / 2 - 0.035 * S), floorY + wallH / 2, (bz0 + bz1) / 2))
			dark("BedRail", V3(0.09 * S, 0.04, bz1 - bz0), CF(side * (bw / 2 - 0.045 * S), topY + 0.02, (bz0 + bz1) / 2), "Part", COLORS.Trim)
		end
		bodyPart("Part", "BedFront", V3(bw, wallH, 0.06 * S), CF(0, floorY + wallH / 2, bz0 + 0.03 * S))
		bodyPart("Part", "Tailgate", V3(bw, wallH, 0.06 * S), CF(0, floorY + wallH / 2, bz1 - 0.03 * S))
		dark("BedLiner", V3(bw - 0.14 * S, 0.03, bz1 - bz0 - 0.12 * S), CF(0, floorY + 0.015, (bz0 + bz1) / 2), "Part", COLORS.Trim)
	end

	-- Mods with a visual result -------------------------------------------------------------------------
	if mods.Underglow and typeof(mods.Underglow.color) == "table" then
		local c = mods.Underglow.color
		local glowColor = Color3.fromRGB(c[1] or 0, c[2] or 200, c[3] or 255)
		local glow = neon("Underglow", V3(Wm * 0.8 * S, 0.05, (s.WB - 0.2) * S), CF(0, yl(s.Clr) - 0.02, zl(s.FO + s.WB / 2)), glowColor)
		local light = Instance.new("PointLight")
		light.Color = glowColor
		light.Range = 12
		light.Brightness = 2.5
		light.Parent = glow
	end

	-- Interior ------------------------------------------------------------------------------------------
	if not opts.lowDetail then
		local inner = interior.Color
		local belt = yl(g.bodyTop(s.WS0 + 0.4))
		local gw = Wm * S * GH
		make("Part", car, "Dashboard", V3(gw - 0.2, 0.14 * S, 0.3 * S), CF(0, belt + 0.07 * S, zl(s.WS0 + 0.25)), COLORS.Dark, PLASTIC)
		make("Part", car, "SteeringWheel", V3(0.03 * S, 0.36 * S, 0.36 * S), CF(-gw / 4, belt + 0.22 * S, zl(s.WS0 + 0.5)) * CFrame.Angles(-0.4, 0, 0) * FACE_Z, COLORS.Dark, PLASTIC, { Shape = Enum.PartType.Cylinder })
		local seatZ = math.max(s.WS1, s.WS0 + 0.75) + 0.15
		for _, side in { -1, 1 } do
			make("Part", car, "SeatBack", V3(gw / 2 - 0.4, 0.55 * S, 0.1 * S), CF(side * gw / 4, belt + 0.18 * S, zl(seatZ)) * CFrame.Angles(-0.2, 0, 0), inner, PLASTIC)
		end
		if s.Doors >= 4 and s.R1 - seatZ > 0.9 then
			make("Part", car, "RearBench", V3(gw - 0.4, 0.5 * S, 0.1 * S), CF(0, belt + 0.16 * S, zl(seatZ + 0.85)) * CFrame.Angles(-0.2, 0, 0), inner, PLASTIC)
		end
	end

	car:SetAttribute("VehicleId", record.id)
	car:SetAttribute("ModelKey", record.modelKey)
	car:SetAttribute("Rarity", record.rarity)
	return car, { L = Ls, W = s.W * S, H = heightS, Belt = yl(g.bodyTop(s.WS0)) }
end

return VehicleBuilder

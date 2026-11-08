-- Visual effects per rarity (glow, sparkles, highlight, light pillar, reveal bursts).
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local RarityConfig = require(script.Parent.Parent.Configs.RarityConfig)

local RarityFX = {}

local function sparkleEmitter(color: Color3, color2: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "RaritySparkles"
	e.Color = ColorSequence.new(color, color2)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	return e
end

-- Persistent glow for Legendary / Mythic / Exclusive cars (server side: visible to everyone).
function RarityFX.applyGlow(model: Model, rarityKey: string)
	local rarity = RarityConfig.get(rarityKey)
	local root = model.PrimaryPart
	if not rarity.Glow or not root then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "RarityGlow"
	light.Color = rarity.Color
	light.Range = 12 + rarity.Index * 1.5
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = root

	local emitter = sparkleEmitter(rarity.Color, rarity.Color2)
	emitter.Rate = if rarityKey == "Exclusive" then 14 else 5
	emitter.Parent = root

	if rarityKey == "Exclusive" or rarityKey == "Mythic" then
		local highlight = Instance.new("Highlight")
		highlight.Name = "RarityHighlight"
		highlight.FillTransparency = 1
		highlight.OutlineColor = rarity.Color
		highlight.OutlineTransparency = if rarityKey == "Exclusive" then 0.1 else 0.45
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
	end
end

-- One-shot burst of particles (client side, during the reveal).
function RarityFX.burst(part: BasePart, rarityKey: string)
	local rarity = RarityConfig.get(rarityKey)
	local emitter = sparkleEmitter(rarity.Color, rarity.Color2)
	emitter.Speed = NumberRange.new(6, 14 + rarity.Index * 2)
	emitter.Lifetime = NumberRange.new(0.8, 1.8)
	emitter.Drag = 2.5
	emitter.Acceleration = Vector3.new(0, -4, 0)
	emitter.Parent = part
	emitter:Emit(rarity.Particles)
	Debris:AddItem(emitter, 3)
end

-- Vertical beam of light; height and colour depend on the rarity.
function RarityFX.pillar(position: Vector3, rarityKey: string, duration: number, parent: Instance)
	local rarity = RarityConfig.get(rarityKey)
	if rarity.Pillar <= 0 then
		return nil
	end
	local beam = Instance.new("Part")
	beam.Name = "RarityPillar"
	beam.Shape = Enum.PartType.Cylinder
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = rarity.Color
	beam.Transparency = 1
	beam.Size = Vector3.new(rarity.Pillar, 0.6, 0.6)
	beam.CFrame = CFrame.new(position + Vector3.new(0, rarity.Pillar / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Parent = parent

	local width = 2 + rarity.Index * 0.6
	TweenService:Create(beam, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(rarity.Pillar, width, width),
		Transparency = 0.45,
	}):Play()
	task.delay(math.max(0.5, duration - 1), function()
		if beam.Parent then
			TweenService:Create(beam, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = Vector3.new(rarity.Pillar, 0.2, 0.2),
				Transparency = 1,
			}):Play()
		end
	end)
	Debris:AddItem(beam, duration + 0.2)
	return beam
end

return RarityFX

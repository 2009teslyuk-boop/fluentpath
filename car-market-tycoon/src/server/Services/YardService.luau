-- The auction yard of every plot: 18 tarp-covered lots (2 rows x 9).
-- The car under a tarp is rolled on the server and kept only in server memory until purchase,
-- so clients cannot peek at the rarity. Buying is validated and applied atomically.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local RarityConfig = require(Shared.Configs.RarityConfig)
local TarpConfig = require(Shared.Configs.TarpConfig)
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)
local VehicleBuilder = require(Shared.Modules.VehicleBuilder)
local VehicleGenerator = require(Shared.Modules.VehicleGenerator)
local Pricing = require(Shared.Modules.Pricing)
local RarityFX = require(Shared.Modules.RarityFX)
local Net = require(Shared.Modules.Net)
local Util = require(Shared.Modules.Util)
local Format = require(Shared.Modules.Format)
local Build = require(script.Parent.Parent.Lib.Build)

local V3, CF = Vector3.new, CFrame.new
local FLIP = CFrame.Angles(0, math.pi, 0)

local YardService = {}

local Services
local rng = Random.new()
local tierPrices: { [string]: number } = {}

type Lot = {
	index: number,
	state: string, -- "available" | "revealing" | "empty"
	tier: string,
	price: number,
	record: any?, -- hidden until bought
	folder: Model,
	tarp: Model?,
	vehicleId: string?,
	version: number,
}

local yards: { [Player]: { lots: { Lot } } } = {}

local LOT_COUNT = GameConfig.Yard.Rows * GameConfig.Yard.PerRow

-- Expected value per tier -> lot prices ------------------------------------------------------
local function computeTierPrices()
	local sampler = Random.new(12345)
	local meanByRarity = {}
	for _, rarity in RarityConfig.Order do
		local pool = VehicleDatabase.ByRarity[rarity]
		if pool and #pool > 0 then
			local total, samples = 0, 400
			for _ = 1, samples do
				total += Pricing.value(VehicleGenerator.generate(sampler, rarity))
			end
			meanByRarity[rarity] = total / samples
		end
	end
	for _, tierKey in TarpConfig.Order do
		local tier = TarpConfig.get(tierKey)
		local odds = RarityConfig.odds(tier.RarityMultipliers)
		local ev = 0
		for rarity, p in odds do
			ev += p * (meanByRarity[rarity] or 0)
		end
		tierPrices[tierKey] = Util.roundTo(ev * tier.PriceMargin, GameConfig.Yard.PriceRounding)
		print(("[Yard] Tier %s: expected value %d, lot price %d"):format(tierKey, math.floor(ev), tierPrices[tierKey]))
	end
end

local function silhouetteHint(dims): string
	local low = dims.H < 3.6
	local long = dims.L >= 14
	local tall = dims.H >= 4.8
	if tall and long then
		return "Високий і довгий силует"
	elseif tall then
		return "Високий силует"
	elseif low and long then
		return "Довгий низький силует"
	elseif low then
		return "Дуже низький силует"
	elseif long then
		return "Довгий силует"
	end
	return "Звичайний силует"
end

-- Tarp model shaped after the hidden car's dimensions ----------------------------------------------------
local function buildTarp(lot: Lot, owner: Player, record, lotCF: CFrame): Model
	local tier = TarpConfig.get(lot.tier)
	local dims = VehicleBuilder.getDimensions(record.modelKey)
	local model = Instance.new("Model")
	model.Name = "Tarp"
	local color = tier.Colors[rng:NextInteger(1, #tier.Colors)]
	local darker = color:Lerp(Color3.new(0, 0, 0), 0.25)
	local L = dims.L + 0.5 + rng:NextNumber() * 0.4
	local W = dims.W + 0.35
	local bodyH = dims.BodyTop + 0.15
	local cabH = dims.CabH + 0.12

	local function piece(name, size, cf, c, props)
		local p = Build.part(model, name, size, cf, c or color, tier.Material, props)
		p.CanQuery = false
		p.CanTouch = false
		return p
	end

	local drape = piece("Drape", V3(W, bodyH, L), CF(0, bodyH / 2, 0), color, { CanCollide = true, CastShadow = true })
	-- cabin hump: front wedge + box + rear wedge
	local cabLen = math.max(2, dims.CabEnd - dims.CabStart)
	local a, b, c = cabLen * 0.3 + 0.2, cabLen * 0.45, cabLen * 0.25 + 0.2
	local zs = dims.CabStart - 0.2
	local humpY = bodyH + cabH / 2 - 0.08
	piece("HumpFront", V3(W - 0.8, cabH, a), CF(0, humpY, zs + a / 2), color, { ClassName = "WedgePart", CastShadow = true })
	piece("Hump", V3(W - 0.8, cabH, b), CF(0, humpY, zs + a + b / 2), color, { CastShadow = true })
	piece("HumpRear", V3(W - 0.8, cabH, c), CF(0, humpY, zs + a + b + c / 2) * FLIP, color, { ClassName = "WedgePart", CastShadow = true })
	piece("Hem", V3(W + 0.45, 0.4, L + 0.45), CF(0, 0.2, 0), darker)
	for _, z in { -L * 0.3, L * 0.3 } do
		piece("Strap", V3(W + 0.1, bodyH + 0.06, 0.32), CF(0, bodyH / 2 + 0.02, z), tier.StrapColor)
	end
	for _ = 1, 3 do
		local z = (rng:NextNumber() - 0.5) * L * 0.7
		piece("Fold", V3(W * (0.5 + rng:NextNumber() * 0.4), 0.12, 0.45), CF(0, bodyH + 0.02, z) * CFrame.Angles(0, (rng:NextNumber() - 0.5) * 0.5, (rng:NextNumber() - 0.5) * 0.06), darker)
	end
	if tier.TrimColor then
		local trim = Build.part(model, "Trim", V3(W + 0.5, 0.08, L + 0.5), CF(0, 0.42, 0), tier.TrimColor, Enum.Material.Neon, { CanCollide = false, CanQuery = false })
		trim.CanTouch = false
	end
	if tier.Sparkle then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(tier.TagColor)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Rate = 3
		sparkle.Speed = NumberRange.new(0.2, 0.8)
		sparkle.Shape = Enum.ParticleEmitterShape.Box
		sparkle.Parent = drape
	end

	drape.PivotOffset = CF(0, -bodyH / 2, 0)
	model.PrimaryPart = drape

	-- price tag
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Tag"
	billboard.Size = UDim2.fromScale(6, 1.7)
	billboard.StudsOffsetWorldSpace = V3(0, bodyH / 2 + cabH + 2.2, 0)
	billboard.MaxDistance = 70
	billboard.LightInfluence = 0
	billboard.Parent = drape
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	frame.BackgroundTransparency = 0.15
	frame.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = tier.TagColor
	stroke.Thickness = 2
	stroke.Parent = frame
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.45)
	title.Position = UDim2.fromScale(0, 0.06)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = tier.TagColor
	title.Text = ("ЛОТ %02d · %s"):format(lot.index, string.upper(tier.NameUA))
	title.Parent = frame
	local price = Instance.new("TextLabel")
	price.BackgroundTransparency = 1
	price.Size = UDim2.fromScale(1, 0.42)
	price.Position = UDim2.fromScale(0, 0.52)
	price.Font = Enum.Font.GothamBlack
	price.TextScaled = true
	price.TextColor3 = Color3.fromRGB(130, 235, 150)
	price.Text = Format.money(lot.price)
	price.Parent = frame

	-- proximity prompt at the nose (the aisle side)
	local attachment = Instance.new("Attachment")
	attachment.Name = "PromptAttachment"
	attachment.Position = V3(0, 2.2 - bodyH / 2, -L / 2 - 0.6)
	attachment.Parent = drape
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "InspectPrompt"
	prompt.ActionText = "ОГЛЯНУТИ АВТОМОБІЛЬ"
	prompt.ObjectText = ("Лот %02d · %s"):format(lot.index, tier.NameUA)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("LotIndex", lot.index)
	prompt:SetAttribute("OwnerUserId", owner.UserId)
	prompt.Parent = attachment

	model:SetAttribute("LotIndex", lot.index)
	model:SetAttribute("Tier", lot.tier)
	model:SetAttribute("Price", lot.price)
	model:SetAttribute("Hint", silhouetteHint(dims))
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:PivotTo(lotCF)
	return model
end

local function lotCFrame(player: Player, index: number): CFrame?
	local plot = Services.PlotService.getPlot(player)
	if not plot then
		return nil
	end
	return plot.cframe * Services.PlotService.lotLocalCFrame(index)
end

local function restock(player: Player, lot: Lot)
	local cf = lotCFrame(player, lot.index)
	if not cf then
		return
	end
	lot.version += 1
	if lot.tarp then
		lot.tarp:Destroy()
	end
	local tier = Util.weightedPick(rng, TarpConfig.Order, function(key)
		return TarpConfig.get(key).Weight
	end)
	lot.tier = tier
	-- small random spread so neighbouring lots of the same tier do not all look identical
	local jitter = 0.94 + rng:NextNumber() * 0.12
	lot.price = Util.roundTo(tierPrices[tier] * jitter, GameConfig.Yard.PriceRounding)
	lot.record = VehicleGenerator.roll(rng, TarpConfig.get(tier).RarityMultipliers)
	lot.vehicleId = nil
	lot.state = "available"
	lot.tarp = buildTarp(lot, player, lot.record, cf)
	lot.tarp.Parent = lot.folder
end

function YardService.setupPlayer(player: Player)
	local plot = Services.PlotService.getPlot(player)
	if not plot then
		return
	end
	local yard = { lots = {} }
	yards[player] = yard
	for i = 1, LOT_COUNT do
		local folder = Instance.new("Model")
		folder.Name = ("Lot_%02d"):format(i)
		folder.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		folder.Parent = plot.yard
		local lot: Lot = {
			index = i,
			state = "empty",
			tier = "Canvas",
			price = 0,
			record = nil,
			folder = folder,
			tarp = nil,
			vehicleId = nil,
			version = 0,
		}
		yard.lots[i] = lot
		restock(player, lot)
	end
end

function YardService.cleanupPlayer(player: Player)
	local yard = yards[player]
	if not yard then
		return
	end
	for _, lot in yard.lots do
		lot.version += 1
		lot.folder:Destroy()
	end
	yards[player] = nil
end

-- Called when a vehicle leaves the garage (sold) or goes to the showroom while still on its lot.
function YardService.onVehicleLeft(player: Player, vehicleId: string)
	local yard = yards[player]
	if not yard then
		return
	end
	for _, lot in yard.lots do
		if lot.vehicleId == vehicleId then
			local vehicle = lot.folder:FindFirstChild("Vehicle")
			if vehicle then
				vehicle:Destroy()
			end
			lot.vehicleId = nil
		end
	end
end

function YardService.buyLot(player: Player, lotIndex: any)
	if type(lotIndex) ~= "number" or lotIndex ~= lotIndex or lotIndex % 1 ~= 0 or lotIndex < 1 or lotIndex > LOT_COUNT then
		return { ok = false, error = "Невірний лот" }
	end
	local yard = yards[player]
	local data = Services.PlayerDataService.getData(player)
	if not yard or not data then
		return { ok = false, error = "Ділянка ще не готова" }
	end
	local lot = yard.lots[lotIndex]
	if lot.state ~= "available" or not lot.record then
		return { ok = false, error = "Цей лот уже продано" }
	end
	if not Services.VehicleService.hasGarageSpace(player) then
		return { ok = false, error = "Гараж заповнений — продайте авто або розширте гараж" }
	end
	if not Services.EconomyService.trySpend(player, lot.price, ("lot %d (%s)"):format(lotIndex, lot.tier)) then
		return { ok = false, error = "Недостатньо коштів" }
	end

	-- commit (no yields above this line)
	local record = lot.record
	lot.record = nil
	lot.state = "revealing"
	lot.vehicleId = record.id
	record.paid = lot.price
	record.acquiredAt = os.time()
	Services.VehicleService.addVehicle(player, record)
	data.stats.lotsOpened += 1
	Services.EconomyService.addXP(player, RarityConfig.get(record.rarity).XP)

	-- build the real car under the tarp
	local cf = lotCFrame(player, lotIndex) :: CFrame
	local car = VehicleBuilder.build(record)
	car.Name = "Vehicle"
	car:PivotTo(cf)
	car.Parent = lot.folder
	RarityFX.applyGlow(car, record.rarity)
	if lot.tarp then
		local prompt = lot.tarp:FindFirstChild("InspectPrompt", true)
		if prompt then
			(prompt :: ProximityPrompt).Enabled = false
		end
	end

	local payload = Services.VehicleService.serialize(record, data)
	local plot = Services.PlotService.getPlot(player)
	local reveal = {
		ownerUserId = player.UserId,
		ownerName = player.DisplayName,
		plotIndex = plot and plot.index,
		lotIndex = lotIndex,
		rarity = record.rarity,
		name = VehicleDatabase.displayName(record),
		value = payload.value,
	}
	Net.get("LotRevealed"):FireAllClients(reveal)
	if RarityConfig.get(record.rarity).Announce then
		Net.get("Announce"):FireAllClients(reveal)
	end

	-- timeline: tarp removed -> car leaves the lot -> new tarp
	local version = lot.version
	local yardCfg = GameConfig.Yard
	task.delay(yardCfg.RevealTarpSeconds + RarityConfig.get(record.rarity).Suspense, function()
		if lot.version == version and lot.tarp then
			lot.tarp:Destroy()
			lot.tarp = nil
		end
	end)
	task.delay(yardCfg.RevealHoldSeconds, function()
		if lot.version ~= version or yards[player] == nil then
			return
		end
		YardService.onVehicleLeft(player, record.id)
		lot.state = "empty"
		task.wait(yardCfg.RestockSeconds)
		if lot.version == version and yards[player] then
			restock(player, lot)
		end
	end)

	Services.VehicleService.pushInventory(player)
	Services.EconomyService.pushState(player)
	return { ok = true, vehicle = payload, paid = lot.price, lotIndex = lotIndex, plotIndex = reveal.plotIndex }
end

function YardService.getTierPrices()
	return tierPrices
end

function YardService.init(services)
	Services = services
	computeTierPrices()
	ReplicatedStorage:SetAttribute("TierPrice_Canvas", tierPrices.Canvas)
	ReplicatedStorage:SetAttribute("TierPrice_Premium", tierPrices.Premium)
	ReplicatedStorage:SetAttribute("TierPrice_Elite", tierPrices.Elite)
end

return YardService

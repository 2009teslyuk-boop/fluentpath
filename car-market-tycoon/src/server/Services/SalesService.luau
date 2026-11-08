-- NPC buyers for showroom listings: they walk onto the plot, inspect a listed car that matches
-- their taste, then buy (auto-sell), make an offer the owner must accept, or leave.
-- Demand per class drops after every NPC purchase and recovers over time, and every plot has a
-- cooldown between purchases, so NPCs never buy everything at once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local NPCConfig = require(Shared.Configs.NPCConfig)
local RarityConfig = require(Shared.Configs.RarityConfig)
local VehicleDatabase = require(Shared.Modules.VehicleDatabase)
local Format = require(Shared.Modules.Format)
local Net = require(Shared.Modules.Net)
local Util = require(Shared.Modules.Util)

local SalesService = {}

local Services
local rng = Random.new()
local cfg = GameConfig.Sales

type PlotSales = { npcs: number, nextSpawn: number, lastSale: number, rigs: { Model } }
local plotSales: { [Player]: PlotSales } = {}
local offers: { [string]: any } = {}
local demand: { [string]: number } = {}

local SKIN = {
	Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(141, 85, 54), Color3.fromRGB(96, 60, 40),
}

function SalesService.getDemand(class: string): number
	return demand[class] or 1
end

local function publishDemand(class: string)
	local folder = ReplicatedStorage:FindFirstChild("MarketIndex")
	if folder then
		folder:SetAttribute("Demand_" .. class, math.floor((demand[class] or 1) * 100 + 0.5) / 100)
	end
end

local function matches(npcType, record): boolean
	local model = VehicleDatabase.getModel(record.modelKey)
	if not model then
		return false
	end
	local r = RarityConfig.index(record.rarity)
	if r < npcType.MinRarity or r > npcType.MaxRarity then
		return false
	end
	return npcType.Classes == nil or table.find(npcType.Classes, model.Class) ~= nil
end

local function spawnRig(npcType, cf: CFrame, parent: Instance)
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = npcType.Color
	desc.LeftLegColor = Color3.fromRGB(40, 42, 50)
	desc.RightLegColor = Color3.fromRGB(40, 42, 50)
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[Sales] Could not create NPC rig: " .. tostring(rig))
		return nil
	end
	rig.Name = "Buyer_" .. npcType.Key
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = NPCConfig.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rig:PivotTo(cf)
	rig.Parent = parent
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end

	local head = rig:FindFirstChild("Head") :: BasePart?
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.fromScale(7, 1.4)
	bubble.StudsOffset = Vector3.new(0, 2.4, 0)
	bubble.MaxDistance = 60
	bubble.LightInfluence = 0
	bubble.Parent = head or root
	local title = Instance.new("TextLabel")
	title.Name = "Type"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.4)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = npcType.Color:Lerp(Color3.new(1, 1, 1), 0.4)
	title.TextStrokeTransparency = 0.4
	title.Text = npcType.NameUA
	title.Parent = bubble
	local say = Instance.new("TextLabel")
	say.Name = "Say"
	say.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	say.BackgroundTransparency = 0.15
	say.Position = UDim2.fromScale(0, 0.45)
	say.Size = UDim2.fromScale(1, 0.55)
	say.Font = Enum.Font.GothamMedium
	say.TextScaled = true
	say.TextColor3 = Color3.new(1, 1, 1)
	say.Text = "Подивлюся, що тут є…"
	say.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = say
	return rig, humanoid, say
end

local function walkTo(humanoid: Humanoid, position: Vector3, timeout: number)
	local finished = false
	local connection = humanoid.MoveToFinished:Connect(function()
		finished = true
	end)
	local started = os.clock()
	local lastIssue = -10
	while not finished and humanoid.Parent and os.clock() - started < timeout do
		if os.clock() - lastIssue > 6 then
			-- MoveTo stops by itself after 8 seconds, so long walks re-issue it
			humanoid:MoveTo(position)
			lastIssue = os.clock()
		end
		task.wait(0.2)
	end
	connection:Disconnect()
end

local function driveAway(model: Model, plotCFrame: CFrame)
	local start = model:GetPivot()
	local value = Instance.new("CFrameValue")
	value.Value = start
	value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	-- roll forward (towards the boulevard) while fading out
	local target = start + plotCFrame.LookVector * 28
	TweenService:Create(value, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = target }):Play()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			TweenService:Create(d, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Light") then
			d:Destroy()
		end
	end
	task.delay(2.6, function()
		model:Destroy()
		value:Destroy()
	end)
end

local function executeSale(player: Player, id: string, price: number, npcType): boolean
	local data = Services.PlayerDataService.getData(player)
	local plot = Services.PlotService.getPlot(player)
	if not data or not plot or data.listings[id] == nil or not data.vehicles[id] then
		return false
	end
	local model = Services.VehicleService.takeDisplayModel(player, id)
	local record = Services.VehicleService.completeSale(player, id, price, npcType.NameUA)
	if not record then
		if model then
			model:Destroy()
		end
		return false
	end
	local st = plotSales[player]
	if st then
		st.lastSale = os.clock()
	end
	local vehicleModel = VehicleDatabase.getModel(record.modelKey)
	local class = vehicleModel and vehicleModel.Class or "Sedan"
	demand[class] = math.max(cfg.DemandMin, (demand[class] or 1) - cfg.DemandDropPerSale)
	publishDemand(class)
	Services.EconomyService.addXP(player, 25 + RarityConfig.index(record.rarity) * 10)
	Services.EconomyService.notify(player, ("%s купив %s за %s"):format(npcType.NameUA, VehicleDatabase.displayName(record), Format.money(price)), "success")
	if model then
		driveAway(model, plot.cframe)
	end
	return true
end

-- Sends an offer to the owner and waits for the answer (or the timeout).
local function makeOffer(player: Player, id: string, price: number, npcType, value: number): boolean
	local data = Services.PlayerDataService.getData(player)
	local record = data and data.vehicles[id]
	if not record then
		return false
	end
	local offerId = HttpService:GenerateGUID(false)
	local offer = { player = player, vehicleId = id, price = price, result = nil :: boolean? }
	offers[offerId] = offer
	Net.get("OfferReceived"):FireClient(player, {
		id = offerId,
		buyer = npcType.NameUA,
		price = price,
		listed = data.listings[id],
		value = value,
		name = VehicleDatabase.displayName(record),
		rarity = record.rarity,
		timeout = cfg.OfferTimeoutSeconds,
	})
	local deadline = os.clock() + cfg.OfferTimeoutSeconds
	while offer.result == nil and os.clock() < deadline and player.Parent do
		task.wait(0.25)
	end
	offers[offerId] = nil
	return offer.result == true
end

function SalesService.respondOffer(player: Player, offerId: any, accept: any)
	if type(offerId) ~= "string" or #offerId > 64 then
		return { ok = false, error = "Невірний запит" }
	end
	local offer = offers[offerId]
	if not offer or offer.player ~= player or offer.result ~= nil then
		return { ok = false, error = "Пропозиція вже недійсна" }
	end
	offer.result = accept == true
	return { ok = true }
end

local function visit(player: Player)
	local st = plotSales[player]
	local plot = Services.PlotService.getPlot(player)
	if not st or not plot then
		return
	end
	st.npcs += 1
	local npcType = Util.weightedPick(rng, NPCConfig.Types, function(t)
		return t.Weight
	end)
	local base = plot.cframe
	local startCF = base * CFrame.new(rng:NextNumber(-8, 8), 3, -101)
	local rig, humanoid, say = spawnRig(npcType, startCF, Services.WorldService.Folders.NPCZones)
	if not rig then
		st.npcs -= 1
		return
	end
	table.insert(st.rigs, rig)

	local function at(x: number, z: number): Vector3
		return (base * CFrame.new(x, 3, z)).Position
	end
	local function leave(text: string?)
		if text then
			say.Text = text
		end
		task.wait(1.5)
		walkTo(humanoid, at(0, -90), 20)
		walkTo(humanoid, startCF.Position, 10)
		local index = table.find(st.rigs, rig)
		if index then
			table.remove(st.rigs, index)
		end
		rig:Destroy()
		st.npcs -= 1
	end

	walkTo(humanoid, at(rng:NextNumber(-4, 4), -90), 15)

	local data = Services.PlayerDataService.getData(player)
	if not data or not rig.Parent then
		leave()
		return
	end
	local candidates = {}
	for id in data.listings do
		local record = data.vehicles[id]
		if record and table.find(data.displayed, id) and matches(npcType, record) then
			table.insert(candidates, id)
		end
	end
	if #candidates == 0 then
		walkTo(humanoid, at(rng:NextNumber(-30, 30), -83.5), 15)
		leave("Нічого для мене немає…")
		return
	end
	local id = candidates[rng:NextInteger(1, #candidates)]
	local spot = table.find(data.displayed, id) or 1
	local spotCF = Services.PlotService.spotLocalCFrame(spot)
	local laneZ = spotCF.Position.Z - 10.5
	say.Text = "О, цікаве авто!"
	walkTo(humanoid, at(0, laneZ), 20)
	walkTo(humanoid, at(spotCF.Position.X, laneZ), 15)
	say.Text = "Оглядаю…"
	task.wait(rng:NextNumber(NPCConfig.InspectSeconds[1], NPCConfig.InspectSeconds[2]))

	data = Services.PlayerDataService.getData(player)
	local record = data and data.vehicles[id]
	local price = data and data.listings[id]
	if not record or not price or not rig.Parent then
		leave("Ой, його вже продали")
		return
	end
	if os.clock() - st.lastSale < cfg.PlotSaleCooldownSeconds then
		leave("Подумаю й повернуся…")
		return
	end
	local value = Services.VehicleService.valueOf(record)
	local model = VehicleDatabase.getModel(record.modelKey)
	local d = SalesService.getDemand(model and model.Class or "Sedan")
	local maxRatio = npcType.MaxRatio * d
	local ratio = price / math.max(1, value)

	if ratio <= maxRatio then
		if data.settings.autoSell then
			say.Text = "Беру! " .. Format.money(price)
			executeSale(player, id, price, npcType)
			leave()
		else
			say.Text = "Готовий купити за " .. Format.money(price)
			if makeOffer(player, id, price, npcType, value) and executeSale(player, id, price, npcType) then
				leave("Дякую за угоду!")
			else
				leave("Шкода…")
			end
		end
	elseif ratio <= maxRatio * NPCConfig.HaggleLimit then
		local range = npcType.OfferRange
		local offerPrice = math.floor(value * rng:NextNumber(range[1], range[2]) * d / 10) * 10
		offerPrice = math.min(offerPrice, price - 10)
		if offerPrice < value * cfg.MinPriceRate then
			leave("Задорого для мене")
			return
		end
		say.Text = "Пропоную " .. Format.money(offerPrice)
		if makeOffer(player, id, offerPrice, npcType, value) and executeSale(player, id, offerPrice, npcType) then
			leave("Чудова угода!")
		else
			leave("Ну, як знаєте…")
		end
	else
		leave("Задорого!")
	end
end

function SalesService.setupPlayer(player: Player)
	plotSales[player] = { npcs = 0, nextSpawn = os.clock() + 8, lastSale = -1000, rigs = {} }
end

function SalesService.cleanupPlayer(player: Player)
	local st = plotSales[player]
	if st then
		for _, rig in st.rigs do
			rig:Destroy()
		end
	end
	plotSales[player] = nil
	for _, offer in offers do
		if offer.player == player then
			offer.result = false
		end
	end
end

function SalesService.init(services)
	Services = services
	for _, class in VehicleDatabase.ClassOrder do
		demand[class] = 1
	end
end

function SalesService.start()
	for _, class in VehicleDatabase.ClassOrder do
		publishDemand(class)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, st in plotSales do
				local data = Services.PlayerDataService.getData(player)
				if data and next(data.listings) ~= nil and st.npcs < cfg.MaxNPCPerPlot and now >= st.nextSpawn then
					st.nextSpawn = now + rng:NextNumber(cfg.SpawnIntervalSeconds[1], cfg.SpawnIntervalSeconds[2])
					task.spawn(visit, player)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for class, d in demand do
				if d < 1 then
					demand[class] = math.min(1, d + cfg.DemandRecoveryPerMinute)
					publishDemand(class)
				end
			end
		end
	end)
end

return SalesService

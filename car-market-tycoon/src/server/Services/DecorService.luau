-- Plot decorations: placement / removal validated on the server, saved in the player's data and
-- rebuilt when the player joins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DecorConfig = require(Shared.Configs.DecorConfig)
local GameConfig = require(Shared.Configs.GameConfig)
local DecorBuilder = require(Shared.Modules.DecorBuilder)

local DecorService = {}

local Services

local function decorFolder(plot): Folder
	local folder = plot.model:FindFirstChild("Decor")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Decor"
		folder.Parent = plot.model
	end
	return folder :: Folder
end

local function spawnModel(player: Player, entry)
	local plot = Services.PlotService.getPlot(player)
	if not plot then
		return
	end
	local model = DecorBuilder.build(entry.k, plot.accent, string.upper(player.DisplayName))
	model.Name = "Decor_" .. entry.id
	model:SetAttribute("DecorId", entry.id)
	model:SetAttribute("DecorKey", entry.k)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:PivotTo(plot.cframe * CFrame.new(entry.x, DecorConfig.FloorY, entry.z) * CFrame.Angles(0, (entry.r or 0) * math.pi / 2, 0))
	model.Parent = decorFolder(plot)
end

local function overlaps(data, key: string, x: number, z: number): boolean
	local radius = DecorConfig.ByKey[key].Radius
	for _, e in data.decor do
		local other = DecorConfig.ByKey[e.k]
		if other then
			local dx, dz = e.x - x, e.z - z
			local min = (radius + other.Radius) * 0.8
			if dx * dx + dz * dz < min * min then
				return true
			end
		end
	end
	return false
end

function DecorService.place(player: Player, key: any, x: any, z: any, r: any)
	if type(key) ~= "string" or type(x) ~= "number" or type(z) ~= "number" then
		return { ok = false, error = "Невірний запит" }
	end
	local item = DecorConfig.ByKey[key]
	local data = Services.PlayerDataService.getData(player)
	if not item or not data then
		return { ok = false, error = "Такого предмета немає" }
	end
	x = math.floor(x * 2 + 0.5) / 2
	z = math.floor(z * 2 + 0.5) / 2
	local rot = if type(r) == "number" then math.clamp(math.floor(r), 0, 3) else 0
	if #data.decor >= DecorConfig.MaxItems then
		return { ok = false, error = ("Максимум %d предметів декору"):format(DecorConfig.MaxItems) }
	end
	if (data.level or 1) < item.Level and not GameConfig.freeUpgrades() then
		return { ok = false, error = ("Потрібен рівень %d"):format(item.Level) }
	end
	if not DecorConfig.isValid(key, x, z) then
		return { ok = false, error = "Тут не можна ставити декор (лоти, проходи або будівля)" }
	end
	if overlaps(data, key, x, z) then
		return { ok = false, error = "Занадто близько до іншого предмета" }
	end
	local price = if GameConfig.freeUpgrades() then 0 else item.Price
	if not Services.EconomyService.trySpend(player, price, "decor " .. key) then
		return { ok = false, error = "Недостатньо коштів" }
	end
	data.decorNextId = (data.decorNextId or 1) + 1
	local entry = { id = tostring(data.decorNextId), k = key, x = x, z = z, r = rot, paid = price }
	table.insert(data.decor, entry)
	spawnModel(player, entry)
	Services.EconomyService.pushState(player)
	return { ok = true, id = entry.id }
end

function DecorService.remove(player: Player, id: any)
	if type(id) ~= "string" or #id > 12 then
		return { ok = false, error = "Невірний запит" }
	end
	local data = Services.PlayerDataService.getData(player)
	local plot = Services.PlotService.getPlot(player)
	if not data or not plot then
		return { ok = false, error = "Дані ще завантажуються" }
	end
	for i, e in data.decor do
		if e.id == id then
			table.remove(data.decor, i)
			local refund = math.floor((e.paid or 0) * DecorConfig.RefundRate)
			if refund > 0 then
				Services.EconomyService.addCash(player, refund, "decor refund")
			end
			local model = decorFolder(plot):FindFirstChild("Decor_" .. id)
			if model then
				model:Destroy()
			end
			Services.EconomyService.pushState(player)
			return { ok = true, refund = refund }
		end
	end
	return { ok = false, error = "Цього предмета вже немає" }
end

function DecorService.setupPlayer(player: Player)
	local data = Services.PlayerDataService.getData(player)
	if not data then
		return
	end
	for _, entry in data.decor do
		if DecorConfig.ByKey[entry.k] then
			spawnModel(player, entry)
		end
	end
end

function DecorService.cleanupPlayer(player: Player)
	local plot = Services.PlotService.getPlot(player)
	if plot then
		decorFolder(plot):ClearAllChildren()
	end
end

function DecorService.init(services)
	Services = services
end

return DecorService

-- Yard lots: shows the "ОГЛЯНУТИ АВТОМОБІЛЬ" prompt only on the player's own plot, opens the
-- inspection window (tier, price, silhouette hint, rarity odds) and sends the purchase request.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Format = require(Shared.Modules.Format)
local RarityConfig = require(Shared.Configs.RarityConfig)
local TarpConfig = require(Shared.Configs.TarpConfig)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local C = require(UI.Components)
local create = C.create

local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)
local RevealController = require(script.Parent.RevealController)

local player = Players.LocalPlayer
local YardController = {}

local modal
local currentLot: number? = nil
local currentPrice = 0
local refs = {} :: { [string]: any }
local oddsRows = {} :: { [string]: { bar: Frame, value: TextLabel } }
local buying = false

local function isLotPrompt(prompt: ProximityPrompt): boolean
	return prompt:GetAttribute("LotIndex") ~= nil
end

local function applyOwnership(prompt: ProximityPrompt)
	if isLotPrompt(prompt) then
		prompt.Enabled = prompt:GetAttribute("OwnerUserId") == player.UserId
	end
end

local function refreshBuyButton()
	local cash = StateController.state and StateController.state.cash or 0
	local canAfford = cash >= currentPrice
	C.setEnabled(refs.buy, canAfford and not buying)
	refs.buy.Text = if buying then "ВІДКРИВАЄМО…" elseif canAfford then "КУПИТИ ТА ВІДКРИТИ" else "НЕДОСТАТНЬО КОШТІВ"
	refs.after.Text = "Баланс після покупки: " .. Format.money(cash - currentPrice)
	refs.after.TextColor3 = if canAfford then Theme.Muted else Theme.Danger
end

local function buildModal()
	modal = C.modal("InspectUI", "ЛОТ", Vector2.new(640, 470), 12)
	local content = modal.content

	local left = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(22, 18),
		Size = UDim2.new(0.48, -22, 1, -100),
		Parent = content,
	}, { C.list(Enum.FillDirection.Vertical, 10) })

	refs.tier = create("TextLabel", {
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		BackgroundColor3 = Theme.Panel3,
		Font = Theme.FontBold,
		TextSize = 15,
		TextColor3 = Theme.Text,
		Text = "  ТАРИФ  ",
		Parent = left,
	}, { C.corner(UDim.new(1, 0)) })
	refs.tierStroke = C.stroke(Theme.Accent, 1.5)
	refs.tierStroke.Parent = refs.tier

	C.label({ LayoutOrder = 2, Text = "Що під брезентом — невідомо до покупки.", TextColor3 = Theme.Muted, TextSize = 14, Size = UDim2.new(1, 0, 0, 36), Parent = left })
	refs.hint = C.label({ LayoutOrder = 3, Text = "Силует: —", TextSize = 15, Font = Theme.FontBold, Size = UDim2.new(1, 0, 0, 22), Parent = left })
	C.label({ LayoutOrder = 4, Text = "Ціна лота", TextColor3 = Theme.Muted, TextSize = 13, Size = UDim2.new(1, 0, 0, 16), Parent = left })
	refs.price = C.label({ LayoutOrder = 5, Text = "$0", TextColor3 = Theme.Money, Font = Theme.FontBlack, TextSize = 40, Size = UDim2.new(1, 0, 0, 46), Parent = left })
	refs.after = C.label({ LayoutOrder = 6, Text = "", TextColor3 = Theme.Muted, TextSize = 13, Size = UDim2.new(1, 0, 0, 18), Parent = left })

	local right = create("Frame", {
		BackgroundColor3 = Theme.Panel2,
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(0.5, -22, 1, -110),
		Parent = content,
	}, { C.corner(Theme.CornerSmall), C.padding(12), C.list(Enum.FillDirection.Vertical, 6) })
	C.label({ LayoutOrder = 0, Text = "ШАНСИ РІДКОСТІ", Font = Theme.FontBlack, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), Parent = right })
	for i, key in RarityConfig.Order do
		local rarity = RarityConfig.get(key)
		local row = create("Frame", { LayoutOrder = i, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 27), Parent = right })
		C.label({ Text = rarity.NameUA, TextColor3 = rarity.Color, Font = Theme.FontBold, TextSize = 13, Size = UDim2.new(0.42, 0, 1, 0), Parent = row })
		local back = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.42, 0, 0.5, 0),
			Size = UDim2.new(0.36, 0, 0, 8),
			BackgroundColor3 = Theme.Panel3,
			Parent = row,
		}, { C.corner(UDim.new(1, 0)) })
		local bar = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = rarity.Color, Parent = back }, { C.corner(UDim.new(1, 0)) })
		local value = C.label({ Text = "0%", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.78, 0, 0, 0), Size = UDim2.new(0.22, 0, 1, 0), Parent = row })
		oddsRows[key] = { bar = bar, value = value }
	end

	local buttons = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -20),
		Size = UDim2.new(1, -44, 0, 54),
		BackgroundTransparency = 1,
		Parent = content,
	}, { C.list(Enum.FillDirection.Horizontal, 10) })
	C.button({ Text = "СКАСУВАТИ", LayoutOrder = 1, Size = UDim2.new(0.32, 0, 1, 0), Parent = buttons }, "secondary", function()
		modal.close()
	end)
	refs.buy = C.button({ Text = "КУПИТИ ТА ВІДКРИТИ", LayoutOrder = 2, Size = UDim2.new(0.68, -10, 1, 0), TextSize = 18, Parent = buttons }, "gold", function()
		YardController.buy()
	end)
	StateController.StateChanged:Connect(function()
		if modal.isOpen() then
			refreshBuyButton()
		end
	end)
end

function YardController.open(prompt: ProximityPrompt)
	if RevealController.isPlaying or buying then
		return
	end
	local tarp = prompt:FindFirstAncestorOfClass("Model")
	if not tarp then
		return
	end
	local tierKey = tarp:GetAttribute("Tier") or "Canvas"
	local tier = TarpConfig.get(tierKey)
	currentLot = prompt:GetAttribute("LotIndex")
	currentPrice = tarp:GetAttribute("Price") or 0

	modal.title.Text = ("ЛОТ %02d"):format(currentLot or 0)
	refs.tier.Text = "  БРЕЗЕНТ «" .. string.upper(tier.NameUA) .. "»  "
	refs.tier.TextColor3 = tier.TagColor
	refs.tierStroke.Color = tier.TagColor
	refs.hint.Text = "Силует: " .. tostring(tarp:GetAttribute("Hint") or "—")
	refs.price.Text = Format.money(currentPrice)

	local odds = RarityConfig.odds(tier.RarityMultipliers)
	local maxP = 0
	for _, p in odds do
		maxP = math.max(maxP, p)
	end
	for key, row in oddsRows do
		local p = odds[key] or 0
		row.bar.Size = UDim2.fromScale(if maxP > 0 then math.max(0.02, p / maxP) else 0, 1)
		row.value.Text = Format.percent(p)
	end
	refreshBuyButton()
	modal.open()
end

function YardController.buy()
	if buying or not currentLot then
		return
	end
	buying = true
	refreshBuyButton()
	local lotIndex = currentLot
	local ok, result = pcall(function()
		return Net.get("BuyLot"):InvokeServer(lotIndex)
	end)
	buying = false
	if ok and type(result) == "table" and result.ok then
		modal.close()
		task.spawn(RevealController.play, result)
	else
		HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
		refreshBuyButton()
	end
end

function YardController.init()
	buildModal()

	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			applyOwnership(d)
		end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			applyOwnership(d)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and isLotPrompt(prompt) and prompt:GetAttribute("OwnerUserId") == player.UserId then
			YardController.open(prompt)
		end
	end)
end

return YardController

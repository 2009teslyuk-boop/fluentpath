-- Selling to NPC buyers: price dialog (presets, custom price, auto-sell toggle) and the offer
-- pop-ups NPCs send when they want to haggle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Format = require(Shared.Modules.Format)
local GameConfig = require(Shared.Configs.GameConfig)
local RarityConfig = require(Shared.Configs.RarityConfig)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local C = require(UI.Components)
local create = C.create

local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)

local SaleController = {}

local modal
local refs = {} :: { [string]: any }
local vehicleId: string? = nil
local price = 0
local autoSell = true
local offerHolder: Frame

local PRESETS = { 0.95, 1.0, 1.1, 1.2, 1.35, 1.6 }

local function vehicle()
	return vehicleId and StateController.findVehicle(vehicleId)
end

local function refresh()
	local v = vehicle()
	if not v then
		return
	end
	refs.name.Text = v.brand .. " " .. v.model
	refs.value.Text = "Ринкова вартість: " .. Format.money(v.value)
	refs.price.Text = Format.money(price)
	local ratio = price / math.max(1, v.value)
	refs.ratio.Text = ("%d%% від вартості"):format(math.floor(ratio * 100 + 0.5))
	refs.ratio.TextColor3 = if ratio <= 1.1 then Theme.Money elseif ratio <= 1.35 then Theme.Gold else Theme.Danger
	refs.auto.Text = if autoSell then "✓  Автоматично продавати за цією ціною" else "✗  Питати мене перед кожним продажем"
	refs.auto.TextColor3 = if autoSell then Theme.Money else Theme.Muted
	refs.remove.Visible = v.listedPrice ~= nil
end

local function submit(remove: boolean)
	local id = vehicleId
	if not id then
		return
	end
	local ok, result = pcall(function()
		return Net.get("SetListing"):InvokeServer(id, if remove then nil else price, autoSell)
	end)
	if ok and type(result) == "table" and result.ok then
		HUDController.toast(if remove then "Знято з продажу" else "Виставлено на продаж за " .. Format.money(price) .. " — чекайте покупців!", "success")
		modal.close()
	else
		HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
	end
end

local function build()
	modal = C.modal("SaleUI", "ПРОДАЖ ПОКУПЦЯМ", Vector2.new(560, 500), 14)
	local body = create("Frame", {
		Position = UDim2.fromOffset(22, 14),
		Size = UDim2.new(1, -44, 1, -28),
		BackgroundTransparency = 1,
		Parent = modal.content,
	}, { C.list(Enum.FillDirection.Vertical, 9) })
	refs.name = C.label({ LayoutOrder = 1, Text = "", Font = Theme.FontBlack, TextSize = 24, Size = UDim2.new(1, 0, 0, 28), Parent = body })
	refs.value = C.label({ LayoutOrder = 2, Text = "", TextColor3 = Theme.Muted, TextSize = 14, Size = UDim2.new(1, 0, 0, 18), Parent = body })
	refs.price = C.label({ LayoutOrder = 3, Text = "", Font = Theme.FontBlack, TextColor3 = Theme.Money, TextSize = 38, Size = UDim2.new(1, 0, 0, 44), Parent = body })
	refs.ratio = C.label({ LayoutOrder = 4, Text = "", Font = Theme.FontBold, TextSize = 14, Size = UDim2.new(1, 0, 0, 18), Parent = body })

	local presets = create("Frame", { LayoutOrder = 5, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = body }, {
		C.list(Enum.FillDirection.Horizontal, 6),
	})
	for i, rate in PRESETS do
		C.button({ Text = ("%d%%"):format(math.floor(rate * 100 + 0.5)), LayoutOrder = i, Size = UDim2.new(1 / #PRESETS, -5, 1, 0), TextSize = 14, Parent = presets }, "secondary", function()
			local v = vehicle()
			if v then
				price = math.floor(v.value * rate / 10) * 10
				refresh()
			end
		end)
	end

	local custom = create("TextBox", {
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.Panel2,
		Font = Theme.FontBold,
		TextSize = 16,
		TextColor3 = Theme.Text,
		PlaceholderText = "Або введіть свою ціну…",
		PlaceholderColor3 = Theme.Muted,
		Text = "",
		ClearTextOnFocus = true,
		Parent = body,
	}, { C.corner(Theme.CornerSmall), C.stroke(Theme.Stroke, 1) })
	custom.FocusLost:Connect(function()
		local n = tonumber((custom.Text:gsub("[^%d]", "")))
		if n then
			price = math.floor(n)
			refresh()
		end
		custom.Text = ""
	end)

	refs.auto = create("TextButton", {
		LayoutOrder = 7,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Panel2,
		AutoButtonColor = false,
		Font = Theme.FontBold,
		TextSize = 14,
		Text = "",
		Parent = body,
	}, { C.corner(Theme.CornerSmall) })
	refs.auto.Activated:Connect(function()
		C.playClick()
		autoSell = not autoSell
		refresh()
	end)
	C.label({
		LayoutOrder = 8,
		Text = "Звичайні покупці платять до ~108% вартості, любителі спорту ~118%, колекціонери ~125–135%, VIP — до 160%. Дорожче — будуть торгуватися. Попит падає після кожного продажу.",
		TextSize = 12,
		TextColor3 = Theme.Muted,
		Size = UDim2.new(1, 0, 0, 46),
		Parent = body,
	})
	local buttons = create("Frame", { LayoutOrder = 9, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Parent = body }, {
		C.list(Enum.FillDirection.Horizontal, 8),
	})
	refs.remove = C.button({ Text = "ЗНЯТИ З ПРОДАЖУ", LayoutOrder = 1, Size = UDim2.new(0.38, -4, 1, 0), TextSize = 14, Parent = buttons }, "danger", function()
		submit(true)
	end)
	C.button({ Text = "ВИСТАВИТИ НА ПРОДАЖ", LayoutOrder = 2, Size = UDim2.new(0.62, -4, 1, 0), TextSize = 15, Parent = buttons }, "money", function()
		submit(false)
	end)
end

function SaleController.open(id: string)
	local v = StateController.findVehicle(id)
	if not v then
		return
	end
	if not v.tradeable then
		HUDController.toast("Лімітоване авто не продається", "error")
		return
	end
	vehicleId = id
	price = v.listedPrice or math.floor(v.value * 1.1 / 10) * 10
	autoSell = if StateController.state then StateController.state.autoSell ~= false else true
	refresh()
	modal.open()
end

-- Offer pop-up -------------------------------------------------------------------------------
local function showOffer(offer)
	local rarity = RarityConfig.get(offer.rarity)
	local card = create("CanvasGroup", {
		Size = UDim2.fromOffset(380, 150),
		BackgroundColor3 = Theme.Panel,
		GroupTransparency = 1,
		Parent = offerHolder,
	}, { C.corner(), C.stroke(Theme.Gold, 2) })
	C.label({ Text = offer.buyer .. " пропонує", TextSize = 13, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 16), Parent = card })
	C.label({ Text = Format.money(offer.price), Font = Theme.FontBlack, TextSize = 28, TextColor3 = Theme.Money, Position = UDim2.fromOffset(16, 26), Size = UDim2.new(1, -32, 0, 32), Parent = card })
	C.label({
		Text = ("за %s · вартість %s%s"):format(offer.name, Format.money(offer.value), if offer.listed then " · ваша ціна " .. Format.money(offer.listed) else ""),
		TextSize = 12,
		TextColor3 = rarity.Color,
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 0, 30),
		Parent = card,
	})
	local bar = create("Frame", { Position = UDim2.new(0, 16, 0, 92), Size = UDim2.new(1, -32, 0, 4), BackgroundColor3 = Theme.Gold, Parent = card }, { C.corner(UDim.new(1, 0)) })
	local row = create("Frame", { Position = UDim2.new(0, 16, 1, -50), Size = UDim2.new(1, -32, 0, 40), BackgroundTransparency = 1, Parent = card }, {
		C.list(Enum.FillDirection.Horizontal, 8),
	})
	local done = false
	local function close()
		if done then
			return
		end
		done = true
		local t = TweenService:Create(card, TweenInfo.new(0.25), { GroupTransparency = 1 })
		t:Play()
		t.Completed:Once(function()
			card:Destroy()
		end)
	end
	local function respond(accept: boolean)
		if done then
			return
		end
		task.spawn(function()
			local ok, result = pcall(function()
				return Net.get("RespondOffer"):InvokeServer(offer.id, accept)
			end)
			if not (ok and type(result) == "table" and result.ok) then
				HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
			end
		end)
		close()
	end
	C.button({ Text = "ВІДХИЛИТИ", LayoutOrder = 1, Size = UDim2.new(0.4, -4, 1, 0), TextSize = 14, Parent = row }, "secondary", function()
		respond(false)
	end)
	C.button({ Text = "ПРИЙНЯТИ", LayoutOrder = 2, Size = UDim2.new(0.6, -4, 1, 0), TextSize = 15, Parent = row }, "money", function()
		respond(true)
	end)
	TweenService:Create(card, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	local timeout = tonumber(offer.timeout) or GameConfig.Sales.OfferTimeoutSeconds
	TweenService:Create(bar, TweenInfo.new(timeout, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 4) }):Play()
	task.delay(timeout, close)
end

function SaleController.init()
	build()
	local gui = C.screen("OffersUI", 15)
	offerHolder = create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(380, 480),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	C.scaled(offerHolder)
	Net.get("OfferReceived").OnClientEvent:Connect(function(offer)
		if type(offer) == "table" and type(offer.id) == "string" then
			showOffer(offer)
		end
	end)
end

return SaleController

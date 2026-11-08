-- Showroom: capacity upgrades (2 -> 40 spots) and income overview.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Format = require(Shared.Modules.Format)
local GameConfig = require(Shared.Configs.GameConfig)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local C = require(UI.Components)
local create = C.create

local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)

local ShowroomController = {}

local modal
local refs = {} :: { [string]: any }
local levelDots = {} :: { Frame }
local busy = false

local function refresh()
	local state = StateController.state
	if not state or not modal then
		return
	end
	refs.capacity.Text = ("%d / %d місць зайнято"):format(state.displayedCount, state.displayCapacity)
	refs.income.Text = ("Дохід: %s / хв (база %s + шоурум)"):format(
		Format.money(state.incomePerMinute),
		Format.money(GameConfig.Economy.BaseIncomePerMinute)
	)
	for i, dot in levelDots do
		dot.BackgroundColor3 = if i <= state.displayLevel then Theme.Accent else Theme.Panel3
	end
	if state.nextDisplayCost then
		refs.next.Text = ("Наступний рівень: %d місць"):format(state.nextDisplayCapacity)
		refs.buy.Text = "РОЗШИРИТИ ЗА " .. Format.moneyShort(state.nextDisplayCost)
		C.setEnabled(refs.buy, state.cash >= state.nextDisplayCost and not busy)
	else
		refs.next.Text = "Максимальний розмір шоуруму"
		refs.buy.Text = "МАКСИМУМ"
		C.setEnabled(refs.buy, false)
	end
end

local function build()
	modal = C.modal("ShowroomUI", "ШОУРУМ", Vector2.new(620, 420), 11)
	local content = modal.content
	local body = create("Frame", {
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.new(1, -48, 1, -100),
		BackgroundTransparency = 1,
		Parent = content,
	}, { C.list(Enum.FillDirection.Vertical, 10) })

	C.label({ LayoutOrder = 1, Text = "Виставлені авто приносять пасивний дохід і приваблюють покупців. Розширюйте шоурум, щоб показувати більше машин.", TextColor3 = Theme.Muted, TextSize = 14, Size = UDim2.new(1, 0, 0, 40), Parent = body })
	refs.capacity = C.label({ LayoutOrder = 2, Text = "", Font = Theme.FontBlack, TextSize = 28, Size = UDim2.new(1, 0, 0, 34), Parent = body })
	refs.income = C.label({ LayoutOrder = 3, Text = "", TextColor3 = Theme.Money, Font = Theme.FontBold, TextSize = 15, Size = UDim2.new(1, 0, 0, 20), Parent = body })

	local dots = create("Frame", { LayoutOrder = 4, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Parent = body }, {
		C.list(Enum.FillDirection.Horizontal, 8),
	})
	for i, level in GameConfig.DisplayLevels do
		local dot = create("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(54, 52), BackgroundColor3 = Theme.Panel3, Parent = dots }, {
			C.corner(Theme.CornerSmall),
			C.label({ Text = tostring(level.Capacity), Font = Theme.FontBlack, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4) }),
			C.label({ Text = "місць", TextSize = 10, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 32) }),
		})
		levelDots[i] = dot
	end
	refs.next = C.label({ LayoutOrder = 5, Text = "", TextSize = 15, Size = UDim2.new(1, 0, 0, 20), Parent = body })

	refs.buy = C.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.new(1, -48, 0, 54),
		Text = "РОЗШИРИТИ",
		TextSize = 18,
		Parent = content,
	}, "gold", function()
		if busy then
			return
		end
		busy = true
		local ok, result = pcall(function()
			return Net.get("BuyDisplayUpgrade"):InvokeServer()
		end)
		busy = false
		if ok and type(result) == "table" and result.ok then
			HUDController.toast(("Шоурум розширено до %d місць!"):format(result.capacity), "success")
		else
			HUDController.toast(if ok and type(result) == "table" then result.error else "Немає зв'язку з сервером", "error")
		end
		refresh()
	end)

	StateController.StateChanged:Connect(refresh)
end

function ShowroomController.init()
	build()
	HUDController.addMenuButton(2, "ШОУРУМ", "Місця та дохід", function()
		if modal.isOpen() then
			modal.close()
		else
			refresh()
			modal.open()
		end
	end)
end

return ShowroomController

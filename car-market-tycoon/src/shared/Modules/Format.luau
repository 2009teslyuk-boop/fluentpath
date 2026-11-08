local Format = {}

local function withSeparators(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	out = out:gsub("^ ", "")
	return (if n < 0 then "-" else "") .. out
end

function Format.number(n: number): string
	return withSeparators(n)
end

function Format.money(n: number): string
	return "$" .. withSeparators(n)
end

-- $12.4K / $3.2M / $1.05B
function Format.moneyShort(n: number): string
	local a = math.abs(n)
	local sign = if n < 0 then "-" else ""
	if a >= 1e9 then
		return string.format("%s$%.2fB", sign, a / 1e9)
	elseif a >= 1e6 then
		return string.format("%s$%.2fM", sign, a / 1e6)
	elseif a >= 1e4 then
		return string.format("%s$%.1fK", sign, a / 1e3)
	end
	return sign .. "$" .. withSeparators(a)
end

function Format.km(n: number): string
	return withSeparators(n) .. " км"
end

function Format.percent(x: number): string
	if x < 0.001 then
		return string.format("%.3f%%", x * 100)
	elseif x < 0.01 then
		return string.format("%.2f%%", x * 100)
	elseif x < 0.1 then
		return string.format("%.1f%%", x * 100)
	end
	return string.format("%d%%", math.floor(x * 100 + 0.5))
end

return Format

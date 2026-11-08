local Util = {}

function Util.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[Util.deepCopy(k)] = Util.deepCopy(v)
	end
	return copy :: any
end

-- Fills keys that are missing in `target` from `template` (recursively). Does not overwrite.
function Util.reconcile(target: { [any]: any }, template: { [any]: any })
	for k, v in template do
		if target[k] == nil then
			target[k] = Util.deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil and #v == 0 then
			-- only recurse into dictionaries, arrays are kept as stored
			Util.reconcile(target[k], v)
		end
	end
end

-- Picks an element of `list` using `weightOf(element)` as relative weight.
function Util.weightedPick<T>(rng: Random, list: { T }, weightOf: (T) -> number): T
	local total = 0
	for _, item in list do
		total += math.max(0, weightOf(item))
	end
	local roll = rng:NextNumber() * total
	for _, item in list do
		roll -= math.max(0, weightOf(item))
		if roll <= 0 then
			return item
		end
	end
	return list[#list]
end

function Util.count(dict: { [any]: any }): number
	local n = 0
	for _ in dict do
		n += 1
	end
	return n
end

function Util.roundTo(value: number, step: number): number
	return math.floor(value / step + 0.5) * step
end

return Util

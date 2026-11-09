-- Plot decorations: catalogue, prices and the zones (plot space) where they may be placed.
-- Plot space: -Z faces the boulevard, the showroom is z = -94..3, walkway z = 3..16, yard z = 16..95.
local DecorConfig = {}

DecorConfig.MaxItems = 80
DecorConfig.RefundRate = 0.5
DecorConfig.FloorY = 0.3

DecorConfig.Items = {
	{ Key = "bush", NameUA = "Кущ", Price = 500, Level = 1, Radius = 1.4 },
	{ Key = "cones", NameUA = "Конуси", Price = 400, Level = 1, Radius = 1.4 },
	{ Key = "tires", NameUA = "Стос шин", Price = 600, Level = 1, Radius = 1.4 },
	{ Key = "rock", NameUA = "Камінь", Price = 700, Level = 1, Radius = 1.6 },
	{ Key = "hedge", NameUA = "Жива огорожа", Price = 800, Level = 1, Radius = 2.2 },
	{ Key = "flowers", NameUA = "Клумба", Price = 1200, Level = 1, Radius = 1.8 },
	{ Key = "bench", NameUA = "Лавка", Price = 1500, Level = 1, Radius = 2.1 },
	{ Key = "tree_oak", NameUA = "Дуб", Price = 2000, Level = 1, Radius = 3.0 },
	{ Key = "tree_pine", NameUA = "Ялина", Price = 2500, Level = 2, Radius = 2.4 },
	{ Key = "lamp", NameUA = "Ліхтар", Price = 3000, Level = 2, Radius = 0.9 },
	{ Key = "planter", NameUA = "Вазон з деревцем", Price = 3500, Level = 2, Radius = 2.0 },
	{ Key = "flag", NameUA = "Прапор автосалону", Price = 4000, Level = 3, Radius = 1.0 },
	{ Key = "palm", NameUA = "Пальма", Price = 6000, Level = 3, Radius = 2.6 },
	{ Key = "neon_sale", NameUA = "Неон «SALE»", Price = 8000, Level = 4, Radius = 2.2 },
	{ Key = "balloons", NameUA = "Арка з кульок", Price = 10000, Level = 4, Radius = 3.2 },
	{ Key = "searchlight", NameUA = "Прожектор", Price = 15000, Level = 6, Radius = 1.6 },
	{ Key = "billboard", NameUA = "Білборд", Price = 20000, Level = 5, Radius = 4.2 },
	{ Key = "fountain", NameUA = "Фонтан", Price = 25000, Level = 5, Radius = 4.6 },
	{ Key = "trophy", NameUA = "Золотий кубок", Price = 120000, Level = 10, Radius = 2.2 },
}

DecorConfig.ByKey = {}
for _, item in DecorConfig.Items do
	DecorConfig.ByKey[item.Key] = item
end

-- Rectangles where decorations are allowed (outside lots, buyer lanes and the buildings).
DecorConfig.Zones = {
	{ x0 = -63, x1 = -16, z0 = -93.6, z1 = -88.4 }, -- front garden (left of the entrance)
	{ x0 = 16, x1 = 63, z0 = -93.6, z1 = -88.4 }, -- front garden (right)
	{ x0 = -63.6, x1 = -59.8, z0 = -88.4, z1 = 3 }, -- along the left fence
	{ x0 = 59.8, x1 = 63.6, z0 = -88.4, z1 = 3 }, -- along the right fence
	{ x0 = -63.6, x1 = -16, z0 = 4.3, z1 = 15.3 }, -- walkway, left of the spawn
	{ x0 = 16, x1 = 63.6, z0 = 4.3, z1 = 15.3 }, -- walkway, right of the spawn
	{ x0 = -63.6, x1 = -43, z0 = 16.5, z1 = 93.6 }, -- left of the yard
	{ x0 = 43, x1 = 63.6, z0 = 16.5, z1 = 93.6 }, -- right of the yard
	{ x0 = -43, x1 = 43, z0 = 76, z1 = 93.6 }, -- behind the yard
}

function DecorConfig.isValid(key: string, x: number, z: number): boolean
	local item = DecorConfig.ByKey[key]
	if not item or x ~= x or z ~= z then
		return false
	end
	local r = item.Radius
	for _, zone in DecorConfig.Zones do
		if x - r >= zone.x0 - 0.01 and x + r <= zone.x1 + 0.01 and z - r >= zone.z0 - 0.01 and z + r <= zone.z1 + 0.01 then
			return true
		end
	end
	-- small items may straddle two touching zones: accept when the centre is inside a zone
	if r <= 1.5 then
		for _, zone in DecorConfig.Zones do
			if x >= zone.x0 and x <= zone.x1 and z >= zone.z0 and z <= zone.z1 then
				return true
			end
		end
	end
	return false
end

return DecorConfig

-- Robux products. Create the Developer Products in the Creator Dashboard
-- (creator.roblox.com -> your experience -> Monetization -> Developer Products) with these prices
-- and paste their IDs into ProductId. Products with ProductId = 0 are shown as "not configured".
local MonetizationConfig = {}

MonetizationConfig.Products = {
	SpinPaid = { ProductId = 0, PriceRobux = 20, NameUA = "Прокрутка колеса фортуни" },
	Car_velocci_nero = { ProductId = 0, PriceRobux = 800, ModelKey = "velocci_nero", NameUA = "Velocci Corsa Nero" },
	Car_aurelia_fulmine = { ProductId = 0, PriceRobux = 1000, ModelKey = "aurelia_fulmine", NameUA = "Aurelia Fulmine" },
	Car_halcyon_eclipse = { ProductId = 0, PriceRobux = 5000, ModelKey = "halcyon_eclipse", NameUA = "Halcyon Eclipse" },
}

-- display order in the shop
MonetizationConfig.LimitedCars = { "Car_velocci_nero", "Car_aurelia_fulmine", "Car_halcyon_eclipse" }

function MonetizationConfig.byProductId(id: number): (string?, any)
	if id == 0 then
		return nil, nil
	end
	for key, product in MonetizationConfig.Products do
		if product.ProductId == id then
			return key, product
		end
	end
	return nil, nil
end

return MonetizationConfig

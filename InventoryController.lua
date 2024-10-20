local ContentProvider = game:GetService("ContentProvider")
local DDS = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local knit = {}

function knit.__knit__(Knit)
	local controller = Knit.CreateController {
		Name = script.Name;
		
		Inventories = {}
	}
	
	local assets;
	
	function controller:Activated()
		assets = self.Assets
		
		self.InterfaceHandler = assets.Handlers.InterfaceHandler
		self.DataController = assets.Controllers.DataController

		self:__listener__()
	end

	function controller:__listener__()
		self.Services.InventoryService.ListenToInventories:Connect(function(inventories)
			for _, items in inventories do
				local interface = assets.Handlers.InterfaceHandler:SetUI(items:GetAttribute("ScreenGui"))
				
				local inventory = self:SetInventory(interface, items)
			end
		end)
	end

	function controller:SetInventory(interface, items)
		local inventory = self:GetInventory(interface) or assets.Classes.Inventory.new(interface, items)
		
		rawset(self.Inventories, interface, inventory)
		
		return inventory
	end
	
	function controller:GetInventory(interface)
		return rawget(self.Inventories, interface)
	end

	return controller
end

return knit

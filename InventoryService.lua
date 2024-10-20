local ContentProvider = game:GetService("ContentProvider")
local DDS = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local knit = {}

function knit.__knit__(Knit)
	local assets;
	
	local service = Knit.CreateService {
		Name = script.Name;
		DefaultInfo = {Amount = 0, Equipped = true, Type = "Default"};
		Client = {
			ListenToInventories = Knit.CreateSignal(),
		};
	}
	
	function service:Initialized()
		assets = self.Assets
		
		self.Equipped = assets.KnitModules.Signal.new()
		self.Used = assets.KnitModules.Signal.new()
		self.Deleted = assets.KnitModules.Signal.new()
		
		self:__listener__()
	end
	
	function service:__listener__()
		self.Equipped:Connect(function(plr: Player, key: string, equipped: boolean, data: {Type: string, Equipped: boolean})
			-- ADD EVERYTING YOU WANT
		end)
		
		self.Used:Connect(function(plr: Player, key: string, amount: number, data: {Type: string, Amount: number})
			-- ADD EVERYTHING YOU WANT
		end)
	end
	
	function service:Login(plr: Player)
		local cache = assets.Handlers.DataHandler:GetPlayerData(plr)
		
		local inventories = {}
		
		for _, folder in assets.Instances.Inventory:GetChildren() do
			local defaultInfo = self.DefaultInfo
			local key = folder.Name

			table.insert(inventories, folder)
			
			local data = rawget(cache.Data, key)
			
			if data then
				--for id, item in data do
				--	if rawget(item, "Amount")then
				--		local amount = rawget(item, "Amount")
						
				--		if amount <= 0 then
				--			cache:ArrayAdd({key}, id, nil)
				--		end
				--	end
				--end
				
				continue 
			end
			
			cache:ArrayAdd({}, key, {})
		end
		
		self.Client.ListenToInventories:Fire(plr, inventories)
	end
	
	function service:Remove(plr: Player, path: table, index)
		if not index then return end
		if typeof(index) ~= "number" then return end
		if tostring(index) == "nan" then return end
		
		local cache = assets.Handlers.DataHandler:GetPlayerData(plr)
		cache:ArrayRemove(path, index)
		
		return true
	end
	
	function service:Add(plr: Player, path: table, key: string, value: number)
		local cache = assets.Handlers.DataHandler:GetPlayerData(plr)
		
		local k = path[#path]
		rawset(path, #path, nil)
		
		local data = assets.Shared.PathUtility:Search(cache.Data, path, "/")
		
		if not rawget(data, k) then
			cache:ArrayAdd(path, k, {[key] = value})
		else
			table.insert(path, k)
			data = assets.Shared.PathUtility:Search(cache.Data, path, "/")
			local old = data[key]
			
			cache:ArrayAdd(path, key, if typeof(old) == "number" then old+value else value)
		end
	end
	
	function service:Set(plr: Player, path: table, key: string, value)
		local cache = assets.Handlers.DataHandler:GetPlayerData(plr)
		
		cache:ArrayAdd(path, key, value)
	end
	
	function service:Get(plr: Player, path: any)
		local cache = assets.Handlers.DataHandler:GetPlayerData(plr)
		
		local data = assets.Shared.PathUtility:Search(cache.Data, path, "/")

		return data
	end
	
	function service:Equip(plr: Player, path: string, id: string)
		local cache = assets.Handlers.DataHandler:GetPlayerData(plr)

		local inventory = assets.Shared.PathUtility:Search(cache.Data, path, "/")
		local dir = assets.Shared.PathUtility:GetHierarchy(path, "/")
		
		local item = rawget(inventory, id)
		
		if item == nil then
			warn("Cannot equip", id, "if the", plr.DisplayName, "doesn't own it")
			return
		elseif rawget(item, "Equipped") == true then
			return true
		end
		
		if rawget(item, "Amount") <= 0 then
			return
		end
		
		local bool = false
		
		for checkId, _ in inventory do
			local clone = table.clone(dir)
			table.insert(clone, checkId)
			
			local bool = (checkId == id)
			
			cache:ArrayAdd(clone, "Equipped", bool)
		end
		
		self.Equipped:Fire(plr, dir[#dir], bool, item)

		return true
	end
	
	function service:Use(plr: Player, path: table, id: string, removeAmount: number, delete)
		if not id then return end
		if tostring(id) == "nan" then return end
		if not removeAmount then return end
		if tostring(removeAmount) == "nan" then return end
		if not tonumber(removeAmount) then return end
		if removeAmount <= 0 then return end
		
		local cache = assets.Handlers.DataHandler:GetPlayerData(plr)

		local inventory = assets.Shared.PathUtility:Search(cache.Data, path, "/")
		local dir = assets.Shared.PathUtility:GetHierarchy(path, "/")

		local item = rawget(inventory, id)
		
		if rawget(dir, 1) then
			
		end
		
		if item == nil then
			warn("Cannot equip", id, "if the", plr.DisplayName, "doesn't own it")
			return
		elseif rawget(item, "Amount") then
			local amount = rawget(item, "Amount") or 0
			
			if delete and dir[1] == "Characters" then
				local lockedPlayers = self.Services.MorphService:GetLocked(plr)

				local playerAmount = rawget(lockedPlayers, item.Type)
				
				if playerAmount then
					if (amount-removeAmount) < playerAmount then 
						self.Assets.Handlers.NotificationHandler:Notify(plr, "Error", "Cannot delete players that are Equipped or Party")
						return 
					end
				end
			end
			
			local clone = table.clone(dir)
			table.insert(clone, id)
			
			removeAmount = if amount-removeAmount < 0 then amount
				else removeAmount
			
			cache:ArrayAdd(clone, "Amount", amount-removeAmount)
			
			if not delete then
				self.Assets.Handlers.NotificationHandler:Notify(plr, "Success", "Successfully used (".. removeAmount .."x) ".. item.Type)
				self.Used:Fire(plr, dir[#dir], removeAmount, item)
			else
				self.Assets.Handlers.NotificationHandler:Notify(plr, "Success", "Successfully sold (".. removeAmount .."x) ".. item.Type)
				self.Deleted:Fire(plr, dir[#dir], removeAmount, item)
			end
			
			return id, rawget(inventory, id)
		end
	end
	
	function service:GetEquipped(plr: Player, path: string)
		local equipped = {}
		
		local cache = assets.Handlers.DataHandler:GetPlayerData(plr)
		if not cache then return end
		
		local inventory = assets.Shared.PathUtility:Search(cache.Data, path, "/")
		
		for key, data in inventory do
			if data.Equipped then
				table.insert(equipped, {Key = key, Data = data})
			end
		end
		
		return equipped
	end
	
	function service:Select(plr: Player, path: string, id: string)
		local cache = assets.Handlers.DataHandler:GetPlayerData(plr)

		local inventory = assets.Shared.PathUtility:Search(cache.Data, path, "/")
		local dir = assets.Shared.PathUtility:GetHierarchy(path, "/")
		
		local amount = 0

		local item = rawget(inventory, id)
		if not item then return end
		
		for _, selection in cache.Data.Selection do
			if selection == item.Type then
				amount += 1
			end
		end
		
		if #cache.Data.Selection == 5 then warn("Cannot select more than 5 players") return end
		if amount >= item.Amount then
			return
		end
		
		cache:ArrayInsert({"Selection"}, item.Type)
	end
	
	function service.Client:Delete(plr: Player, path: table, id: string, removeAmount: number)
		return self.Server:Use(plr, path, id, removeAmount, true)
	end
	
	function service.Client:Use(plr: Player, path: table, id: string, removeAmount: number)
		return self.Server:Use(plr, path, id, removeAmount)
	end
	
	function service.Client:Equip(...)
		return self.Server:Equip(...)
	end
	
	function service.Client:Select(...)
		return self.Server:Select(...)
	end
	
	function service.Client:Remove(...)
		return self.Server:Remove(...)
	end
	
	return service
end

return knit

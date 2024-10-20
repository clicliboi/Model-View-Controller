local Players = game:GetService("Players")
local Rep = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

local Mouse = Player:GetMouse()

-- Disbaling tooltips
local assets;
local services;

-- This is the main code
local class = {}

local _template;

function class:Activated(bind : BindableEvent)
	assets = self.Assets
	services = self.Services
end

function class.new(...)
	local self = setmetatable({}, _template)

	self:__init__(...)

	return self
end

_template = {
	__init__ = function(self, Interface, Items)
		self.Interface = Interface
		
		self.CanInteract = true
		
		self.ShowcaseFrame = self.Interface.main.Showcase
		self.InventoryFrame = self.Interface.main.Inventory
		
		self.ButtonFrame = assets.Handlers.InterfaceHandler:GetUI("DefaultUI").LeftBar:FindFirstChild(self.Interface.Name)
		
		self.NotifyFrame = self.ButtonFrame.Notification
		self.NotifyFrame.Text = 0
		self.NotifyFrame.Visible = false
		
		self.Icon = self.ShowcaseFrame.Icon
		self.Tools = self.ShowcaseFrame.Tools
		
		self.Items = Items
		self.Type = Items:GetAttribute("Type") or "USE"
		
		self.Settings = self.Items:GetAttributes()
		self.Path = assets.Shared.PathUtility:GetHierarchy(self.Settings.DataPath, "/")
		self.Frames = {}
		
		self.New = {}
		
		self.Amount = Items:GetAttribute("Range").Min
		self.Max = Items:GetAttribute("Range").Max
		self.Notifications = 0
		self.Tools.Amount.Text = self.Amount
		
		self.FrameStorage = assets.Shared.PathUtility:Search(assets.Instances.UI.Elements, rawget(self.Settings, "Frames"), "/") or 
			self.Interface
		
		self.Removed = assets.KnitModules.Signal.new()
		
		assets.Controllers.DataController:GetData(function(replica)
			self.Replica = replica
			
			local Data = assets.Shared.PathUtility:Search(self.Replica.Data, self.Settings.DataPath, "/")
			for id, properties in Data or {} do
				self:SetItem(id, properties, true)
			end

			self.Interface.Enabled = false

			self.ShowcaseFrame.Visible = true
			self.Icon.Visible = false
			self.Tools.Visible = false

			if self.Items.Name == "Characters" then
				for _, slot: Frame in self.Interface.main.Party:GetChildren() do
					if not slot:IsA("Frame") then continue end

					slot.Button.MouseButton1Down:Connect(function()
						if not slot:FindFirstChild("Icon") then return end
						
						local removed = services.InventoryService:Remove({"Selection"}, slot.LayoutOrder)
						
						if removed then
							slot.Select.Visible = true
							if slot:FindFirstChild("Icon") then
								slot.Icon:Destroy()
							end

							local order = slot.LayoutOrder
							slot.LayoutOrder = 5	

							for _, other in self.Interface.main.Party:GetChildren() do 
								if not other:IsA("Frame") then continue end
								if other == slot then continue end

								other.LayoutOrder = if other.LayoutOrder > order then other.LayoutOrder-1
									else other.LayoutOrder
							end
						end
					end)
				end

				for index, value in self.Replica.Data.Selection do
					self:SetSelection(index, value)
				end
			end

			self:__listener__()
		end)
	end,
	
	__listener__ = function(self)
		self.Replica:ListenToRaw(function(_, path, index, value)
			local type = rawget(path, 1)
			
			if rawget(self.Path, 1) == type then
				if index == "Amount" then		
					self:SetInformation(
						self.InventoryFrame:FindFirstChild(path[#path]), 
						value
					)
				elseif typeof(value) == "table" then
					self:SetItem(index, value)
				end
			end
		end)
		
		self.InventoryFrame.ChildAdded:Connect(function(frame)
			if not frame:IsA("Frame") then return end

			if not frame:GetAttribute("Old") then
				rawset(self.New, frame, true)
				frame.New.Visible = true
				self:Notify(true)
				
				frame:SetAttribute("Old", true)
			end
		end)
		
		if self.Items.Name == "Characters" then
			self.Replica:ListenToArrayInsert({"Selection"}, function(...)
				self:SetSelection(...)
			end)
		end
		
		self.Tools.Amount:GetPropertyChangedSignal("Text"):Connect(function()
			local text: string = self.Tools.Amount.Text

			if not tonumber(text) then
				self.Tools.Amount.Text = self.Amount
			else
				local number = tonumber(text)
				
				self.Amount = if number >= 0 and number > self.Max then self.Max
					elseif number >= 0 then number 
					else 1
			end
		end)

		self.Tools.Add.MouseButton1Down:Connect(function()
			if (self.Amount+1) > self.Max then return end
			self.Amount += 1
			self.Tools.Amount.Text = self.Amount
		end)

		self.Tools.Subtract.MouseButton1Down:Connect(function()
			self.Amount -= 1
			
			if self.Amount < 1 then self.Amount = 1 
				return 
			end
			
			self.Tools.Amount.Text = self.Amount
		end)

		self.Interface:GetPropertyChangedSignal("Enabled"):Connect(function()
			self:Enable(self.Interface.Enabled)
		end)
		
		if self.Items.Name == "Characters" then
			self.Tools.Select.MouseButton1Down:Connect(function()
				if not self.SelectedFrame then return end
				local properties = rawget(self.Frames, self.SelectedFrame)
				
				services.InventoryService:Select(self.Settings.DataPath, properties.Id)
			end)
		end
		
		if self.Tools:FindFirstChild("Delete") then
			self.Tools.Delete.MouseButton1Down:Connect(function()
				if self.Amount == 0 then return end
				if not self.SelectedFrame then return end
				
				assets.Handlers.InterfaceHandler:RemoveUI("ConfirmUI")
				local confirmUI = assets.Handlers.InterfaceHandler:SetUI("ConfirmUI", true)
				
				if confirmUI then
					local properties = rawget(self.Frames, self.SelectedFrame)
					
					self.CanInteract = false
					
					local displayAmount = if self.Amount >= (rawget(properties, "Amount")) then "ALL"
						else self.Amount.."x"
					
					confirmUI.main.Message.Text = string.format("Are you sure you want to delete %s %s?", "(".. displayAmount ..")", properties.Type)
					
					confirmUI.main.YES.MouseButton1Down:Connect(function()
						assets.Handlers.InterfaceHandler:RemoveUI("ConfirmUI")
						self.CanInteract = true
						
						services.InventoryService:Delete(self.Settings.DataPath, properties.Id, self.Amount)
					end)
					
					confirmUI.main.NO.MouseButton1Down:Connect(function()
						assets.Handlers.InterfaceHandler:RemoveUI("ConfirmUI")
						self.CanInteract = true
					end)
				end
			end)
		end
		
		if self.Type == "EQUIP" then
			if self.Settings.Unequipable then
				self.Tools.Equip.MouseButton1Down:Connect(function()
					if not self.SelectedFrame then return end
					local properties = rawget(self.Frames, self.SelectedFrame)

					self:SetEquipped(services.InventoryService:Equip(self.Settings.DataPath, properties.Id))
				end)
				
				self.Tools.Unequip.MouseButton1Down:Connect(function()
					if not self.SelectedFrame then return end
					local properties = rawget(self.Frames, self.SelectedFrame)
					
					self:SetEquipped(services.InventoryService:Equip(self.Settings.DataPath, properties.Id))
				end)
			end
		elseif self.Type == "USE" then
			self.Tools.Equip.MouseButton1Down:Connect(function()
				if not self.SelectedFrame then return end
				local properties = rawget(self.Frames, self.SelectedFrame)

				services.InventoryService:Use(self.Settings.DataPath, properties.Id, self.Amount)
			end)
		end
	end,
	
	Notify = function(self, add)
		if self.Interface.Enabled then
			self.Notifications = 0
			self.NotifyFrame.Visible = false
			self.NotifyFrame.Text = self.Notifications
			return
		end
		
		if add then
			self.Notifications += 1
		end
		
		self.NotifyFrame.Visible = (self.Notifications > 0)
		self.NotifyFrame.Text = self.Notifications
	end,
	
	SetEquipped = function(self, equipped)
		if self.Settings.Unequipable then
			self.Tools.Equip.Visible = if equipped then false else true
			self.Tools.Unequip.Visible = if equipped then true else false
		end
	end,
	
	Enable = function(self, enable: boolean)
		self.Interface.Enabled = enable or false
		
		if enable then
			self.Notifications = 0
		end
		
		self:Notify()
		
		if not enable then
			for frame in self.New do
				frame.New.Visible = false

				rawset(self.New, frame, nil)
			end
			
			assets.Handlers.InterfaceHandler:RemoveUI("ConfirmUI")
			self.CanInteract = true
		end
		
		self:Select(nil)
	end,
	
	SetInformation = function(self, infoFrame, amount)
		infoFrame.Amount.Text = (amount or 0).."x"
		infoFrame.Amount.Visible = true 
		
		infoFrame.Parent = self.InventoryFrame
		infoFrame.Visible = if amount > 0 then true else false
		
		if self.SelectedFrame == infoFrame.Icon then
			self:Select(if amount > 0 then infoFrame.Icon else nil)
		end
	end,
	
	SetItem = function(self, id, properties, setup)
		local item = self.Items:FindFirstChild(properties.Type, true)
		if not item then return end
		
		rawset(properties, "Id", id)
		
		local topFrame = self.InventoryFrame:FindFirstChild(properties.Type)
		
		local settingsInstance = if item:FindFirstChild("Settings") then item.Settings
			else item
		
		local itemSettings = settingsInstance:GetAttributes()
		
		if topFrame then
			local amount = rawget(properties, "Amount") or 0
			task.defer(self.SetInformation, self, topFrame, amount)
			
			return 
		end
		
		topFrame = assets.Instances.UI.Elements.Objects.InventoryFrame:Clone()
		topFrame.Name = id
		
		local getFrame = rawget(itemSettings, "Frame") or item.Parent.Name
		
		local frame = self.FrameStorage:FindFirstChild(getFrame):Clone()
		frame.Parent = topFrame
		
		assets.Libraries.AppearanceLibrary:SetFrame(frame, settingsInstance)
		
		if setup then
			topFrame:SetAttribute("Old", true)
		end
		
		frame.Name = "Icon"
		rawset(self.Frames, frame, properties)
		frame.Button.MouseButton1Down:Connect(function()
			local select = if self.SelectedFrame == nil or self.SelectedFrame ~= frame then true 
				else false
			
			self:Select(if select then frame else nil)
		end)
		
		self:SetInformation(topFrame, rawget(properties, "Amount"))
	end,
	
	Select = function(self, frame)		
		if not self.CanInteract then return end
		self.SelectedFrame = frame
		
		if frame then
			rawset(self.New, frame.Parent, nil)
			frame.Parent.New.Visible = false
		end
		
		local function appear(button, enable)
			local buttonEffect = assets.Classes.ButtonEffect.get(button)
			if not buttonEffect then 
				return 
			end
			
			if enable then
				buttonEffect:OpenAnimation(true)
			else
				buttonEffect:CancelAnimation(true)
			end
		end
		
		for f in self.Frames do
			if f == frame then continue end
			
			appear(f.Button, false)
		end
		
		appear(
			if frame then frame.Button
				else nil,
			true
		)
		
		self:Showcase()
	end,
	
	Showcase = function(self)
		local clone = self.Icon:FindFirstChild("CLONE")
		if clone then
			clone:Destroy()
		end

		self.Icon.Visible = false
		self.Tools.Visible = false
		
		if not self.SelectedFrame then 
			self.Icon.Visible = false
			self.Tools.Visible = false
			
			return 
		end
		
		local frame = self.SelectedFrame
		local properties = rawget(self.Frames, frame)
		
		self.Icon.Visible = true
		self.Tools.Visible = true

		local unequipable = self.Settings.Unequipable or false
		local amount;

		local clone = frame:Clone()
		clone.Parent = self.Icon
		clone.Name = "CLONE"
		
		self.Icon.Title.Text = properties.Type
		self.Icon.Title.Visible = (self.Path[1] ~= "Characters")
		--if rawget(itemInfo.Settings, "TextColor") then
		--	icon.Title.Visible = true
		--	icon.Title.TextColor3 = itemInfo.Settings.TextColor
		--end

		local amount = rawget(properties, "Amount") or 0
		self.Icon.Amount.Visible = true
		self.Icon.Amount.Text = amount
		
		self.Icon.Low.Visible = true

		self.Tools.Equip.Text = if self.Type == "USE" then "USE" else "EQUIP"
		
		if self.Icon:FindFirstChild("Sell") then
			local item = assets.Instances.Inventory.Characters:FindFirstChild(properties.Type, true)
			
			local itemSettings = if item:FindFirstChild("Settings") then item.Settings:GetAttributes()
				else item:GetAttributes()
			
			self.Icon.Sell.Visible = if rawget(itemSettings, "Sell") then true else false
			self.Icon.Sell.Text = "Sell:"..(rawget(itemSettings, "Sell") or "")
		end
		
		self:SetEquipped(rawget(properties, "Equipped"))
	end,
	
	SetSelection = function(self, index, value)
		local selection = self.Replica.Data.Selection

		local slot: Frame;
		
		for _, frame: Frame in self.Interface.main.Party:GetChildren()do
			if not frame:IsA("Frame") then continue end
			
			if index == frame.LayoutOrder then
				slot = frame
				break
			end
		end
		
		if not slot then return end
		
		local item = self.Items:FindFirstChild(value or "", true)
		if not item then 
			slot.Select.Visible = true
			if slot:FindFirstChild("Icon") then
				slot.Icon:Destroy()
			end
			
			return
		end
		
		slot.Select.Visible = false
		
		local getFrame = if item:FindFirstChild("Settings") then item.Settings:GetAttribute("Frame") or item.Parent.Name
			else item:GetAttribute("Frame") or item.Parent.Name
		
		local frame = self.FrameStorage:FindFirstChild(getFrame):Clone()
		frame.Parent = slot
		frame.Name = "Icon"
		frame.ZIndex = 2

		local itemConfig = if item:FindFirstChild("Settings") then item.Settings
			else item

		assets.Libraries.AppearanceLibrary:SetFrame(frame, itemConfig)
	end,
	
	Disable = function(self)
		
	end,

	Destroy = function(self)
		self:Disable()

		for _, craftFrame in self.CraftFrames do
			craftFrame:Destroy()
		end

		setmetatable(self, nil)
		table.clear(self)
		table.freeze(self)

		self = nil
	end,

	__index = function(_, k)
		return _template[k]
	end,
}

return class

-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Imports
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local UserCardStat = {}
UserCardStat.__index = UserCardStat

local function columnHeight(): number
	return Config.CardHeight - Config.CardPadding * 2
end

function UserCardStat.new(parent, stat, player)
	local self = setmetatable({}, UserCardStat)
	self.Stat = stat
	self.Player = player

	local h = columnHeight()
	self.Root = Util.newView(parent, "Stat_" .. stat.Name)
	self.Root.IgnoreMouse = true

	self.NameLabel = Util.newLabel(self.Root, "StatName", stat:GetDisplayName(), Config.CardStatNameSize,
		Config.DimTextColor, Enums.HorizontalAlignment.Center)
	Util.place(self.NameLabel, 0, h / 2 - 15, Config.CardStatColumnWidth, 14)

	self.ValueLabel = Util.newLabel(self.Root, "StatValue", stat:GetDisplayValue(player), Config.CardStatValueSize,
		Config.TextColor, Enums.HorizontalAlignment.Center)
	Util.place(self.ValueLabel, 0, h / 2 - 1, Config.CardStatColumnWidth, 16)

	self._statConn = player.StatChanged:Connect(function(changed, _value)
		if changed ~= stat then
			return
		end
		self.NameLabel.Text = stat:GetDisplayName()
		self.ValueLabel.Text = stat:GetDisplayValue(player)
	end)
	self._propConn = stat.PropertyChanged:Connect(function(_prop)
		self.NameLabel.Text = stat:GetDisplayName()
	end)

	return self
end

function UserCardStat:SetX(x: number)
	Util.place(self.Root, x, 0, Config.CardStatColumnWidth, columnHeight())
end

function UserCardStat:Destroy()
	self._statConn:Disconnect()
	self._propConn:Disconnect()
	self.Root:Delete()
end

return UserCardStat

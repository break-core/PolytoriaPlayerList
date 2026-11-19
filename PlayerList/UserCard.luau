-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Imports
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)
local UserCardStat = require(script.Parent.UserCardStat)

local UserCard = {}
UserCard.__index = UserCard

function UserCard.new(parent, player, onClicked: () -> ())
	local self = setmetatable({}, UserCard)
	self.Player = player
	self.Width = Config.CardWidth
	self._statRows = {}
	self._statConns = {}
	self._destroyed = false

	self.Root = Util.newView(parent, "UserCard", Config.CardColor)
	self.Root.CornerRadius = 8

	local mask = Util.newView(self.Root, "Avatar")
	mask.Color = Color.White
	mask.CornerRadius = 8
	mask.MaskMode = Enums.UIMaskMode.ClipOnly
	mask.IgnoreMouse = true
	Util.place(mask, Config.CardPadding, Config.CardPadding, Config.AvatarSize, Config.AvatarSize)

	local icon = Util.newImage(mask, "Icon")
	icon.StretchMode = Enums.ImageStretchMode.Covered
	Util.place(icon, 0, 0, Config.AvatarSize, Config.AvatarSize)
	icon.ImageType = Enums.ImageType.UserAvatarHeadshot
	icon.ImageID = tostring(player.UserID)

	local badgeX = Config.CardPadding + Config.AvatarSize + 8
	self.Badge = Util.newImage(self.Root, "Badge")
	Util.place(self.Badge, badgeX, (Config.CardHeight - Config.BadgeSize) / 2, Config.BadgeSize, Config.BadgeSize)
	self._nameX = badgeX + Config.BadgeSize + 4
	self.UsernameLabel = Util.newLabel(self.Root, "Username", player.Name, Config.CardNameSize)
	Util.watchRole(self.Badge, self.UsernameLabel, player, function()
		return not self._destroyed
	end)

	self.StatsContainer = Util.newView(self.Root, "Stats")
	self.StatsContainer.IgnoreMouse = true

	self._conns = {
		self.Root.MouseUp:Connect(onClicked),
		Stats.ChildAdded:Connect(function(child)
			if child:IsA("Stat") then
				self:AddStat(child)
			end
		end),
		Stats.ChildRemoved:Connect(function(child)
			self:RemoveStat(child)
		end),
	}

	for _, stat in Util.getStats() do
		self:AddStat(stat)
	end
	self:RefreshBox()

	return self
end

function UserCard:AddStat(stat)
	if self._statConns[stat] ~= nil then
		return
	end
	self._statConns[stat] = stat.PropertyChanged:Connect(function(_prop)
		self:OnStatVisibilityChanged(stat)
	end)

	if stat.Visible then
		self:CreateStatRow(stat)
	end
end

function UserCard:CreateStatRow(stat)
	if self._statRows[stat] ~= nil then
		return
	end
	self._statRows[stat] = UserCardStat.new(self.StatsContainer, stat, self.Player)
	self:RefreshBox()
end

function UserCard:OnStatVisibilityChanged(stat)
	local hasRow = self._statRows[stat] ~= nil
	if stat.Visible and not hasRow then
		self:CreateStatRow(stat)
	elseif not stat.Visible and hasRow then
		self:RemoveStatRow(stat)
	end
end

function UserCard:RemoveStat(stat)
	local conn = self._statConns[stat]
	if conn ~= nil then
		conn:Disconnect()
		self._statConns[stat] = nil
	end
	self:RemoveStatRow(stat)
end

function UserCard:RemoveStatRow(stat)
	local row = self._statRows[stat]
	if row ~= nil then
		row:Destroy()
		self._statRows[stat] = nil
		self:RefreshBox()
	end
end

function UserCard:RefreshBox()
	local visible = Stats:GetVisibleStats()
	self.Width = Util.panelWidth(#visible)

	local columns = {}
	for _, stat in visible do
		local row = self._statRows[stat]
		if row ~= nil then
			table.insert(columns, row)
		end
	end

	local h = Config.CardHeight - Config.CardPadding * 2
	local statsW = Util.columnsWidth(#columns, Config.CardStatColumnWidth)
	local statsX = self.Width - Config.CardPadding - statsW
	for i, row in columns do
		row:SetX((i - 1) * (Config.CardStatColumnWidth + Config.StatColumnSpacing))
	end

	Util.place(self.Root, -self.Width, 0, self.Width, Config.CardHeight)
	Util.place(self.StatsContainer, statsX, Config.CardPadding, statsW, h)
	local nameW = statsX - self._nameX - (#columns > 0 and Config.StatColumnSpacing or 0)
	Util.place(self.UsernameLabel, self._nameX, Config.CardPadding, math.max(nameW, 0), h)
end

function UserCard:Destroy()
	self._destroyed = true
	for _, conn in self._conns do
		conn:Disconnect()
	end
	for stat in self._statConns do
		self:RemoveStat(stat)
	end
	self.Root:Delete()
end

return UserCard

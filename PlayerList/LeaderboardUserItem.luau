-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Imports
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local LeaderboardUserItem = {}
LeaderboardUserItem.__index = LeaderboardUserItem

function LeaderboardUserItem.new(leaderboard, player, seq: number)
	local self = setmetatable({}, LeaderboardUserItem)
	self.Leaderboard = leaderboard
	self.TargetPlayer = player
	self.Seq = seq
	self.StatLabels = {}
	self.Destroyed = false

	self.Row = Util.newView(leaderboard.Content, "Player_" .. tostring(player.UserID))

	self.Badge = Util.newImage(self.Row, "Badge")
	Util.place(self.Badge, 0, (Config.RowHeight - Config.BadgeSize) / 2, Config.BadgeSize, Config.BadgeSize)
	self.UsernameLabel = Util.newLabel(self.Row, "Username", player.Name, Config.RowTextSize)
	Util.watchRole(self.Badge, self.UsernameLabel, player, function()
		return not self.Destroyed
	end)

	self._conns = {
		player.StatChanged:Connect(function(stat, _value)
			self:UpdateStat(stat)
		end),
		Util.onRelease(self.Row, function()
			if leaderboard.UserOptions ~= nil then
				leaderboard.UserOptions:PopupAt(self)
			end
		end),
	}

	return self
end

function LeaderboardUserItem:AddStat(stat)
	self.StatLabels[stat] = Util.newLabel(self.Row, "Stat_" .. stat.Name, "", Config.RowStatSize, Config.TextColor,
		Enums.HorizontalAlignment.Center)
	self:UpdateStat(stat)
end

function LeaderboardUserItem:UpdateStat(stat)
	local label = self.StatLabels[stat]
	if label == nil then
		return
	end
	label.Text = stat:GetDisplayValue(self.TargetPlayer)
	self.Leaderboard:QueueSortList()
end

function LeaderboardUserItem:Layout(rowWidth: number)
	local statsW = Util.layoutStatColumns(self.StatLabels, self.Leaderboard.VisibleStats, rowWidth, Config.RowHeight)
	local nameX = Config.BadgeSize + 3
	local nameW = rowWidth - nameX - statsW - (statsW > 0 and 8 or 0)
	Util.place(self.UsernameLabel, nameX, 0, math.max(nameW, 0), Config.RowHeight)
end

function LeaderboardUserItem:Destroy()
	self.Destroyed = true
	for _, conn in self._conns do
		conn:Disconnect()
	end
	self.Row:Delete()
end

return LeaderboardUserItem

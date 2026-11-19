-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Imports
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local LeaderboardTeamItem = {}
LeaderboardTeamItem.__index = LeaderboardTeamItem

local function create(leaderboard, name: string, seq: number)
	local self = setmetatable({}, LeaderboardTeamItem)
	self.Leaderboard = leaderboard
	self.Seq = seq
	self.StatLabels = {}
	self.IsCollapsed = false
	self.IsNeutral = false
	self.Destroyed = false

	self.Row = Util.newView(leaderboard.Content, name)
	self.Row.CornerRadius = 4

	self.TeamNameLabel = Util.newLabel(self.Row, "TeamName", "", Config.RowTextSize)

	self._conns = {
		self.Row.MouseDown:Connect(function()
			self:ToggleCollapse()
		end),
	}

	return self
end

function LeaderboardTeamItem.new(leaderboard, team, seq: number)
	local self = create(leaderboard, "Team_" .. team.Name, seq)
	self.TargetTeam = team
	self:ApplyTeam()
	table.insert(self._conns, team.PropertyChanged:Connect(function(_prop)
		self:ApplyTeam()
	end))
	return self
end

function LeaderboardTeamItem.newNeutral(leaderboard, name: string, color, seq: number)
	local self = create(leaderboard, "NeutralTeam", seq)
	self.IsNeutral = true
	self.TeamNameLabel.Text = name
	self:Tint(color)
	return self
end

function LeaderboardTeamItem:Tint(color)
	Util.paint(self.Row, "Color", Util.withAlpha(color, color.A * Config.TeamPanelAlpha))
end

function LeaderboardTeamItem:ApplyTeam()
	self:Tint(self.TargetTeam.Color)
	self.TeamNameLabel.Text = self.TargetTeam:GetDisplayName()
end

function LeaderboardTeamItem:ToggleCollapse()
	self.IsCollapsed = not self.IsCollapsed
	self.Leaderboard:OnTeamCollapseToggled(self)
end

function LeaderboardTeamItem:SetCollapsed(collapsed: boolean)
	self.IsCollapsed = collapsed
end

function LeaderboardTeamItem:AddStat(stat)
	self.StatLabels[stat] = Util.newLabel(self.Row, "Stat_" .. stat.Name, "", Config.RowStatSize, Config.TextColor,
		Enums.HorizontalAlignment.Center)
	self:UpdateStat(stat)
end

function LeaderboardTeamItem:UpdateStat(stat)
	local label = self.StatLabels[stat]
	if label == nil then
		return
	end

	local total
	if self.IsNeutral then
		total = self.Leaderboard:GetNeutralStatTotal(stat)
	else
		total = stat:GetTotalForTeam(self.TargetTeam)
	end
	label.Text = Util.toKMB(total)
	self.Leaderboard:QueueSortList()
end

function LeaderboardTeamItem:Layout(rowWidth: number)
	local statsW = Util.layoutStatColumns(self.StatLabels, self.Leaderboard.VisibleStats, rowWidth, Config.RowHeight)
	local nameW = rowWidth - 4 - statsW - (statsW > 0 and 8 or 0)
	Util.place(self.TeamNameLabel, 4, 0, math.max(nameW, 0), Config.RowHeight)
end

function LeaderboardTeamItem:Destroy()
	self.Destroyed = true
	for _, conn in self._conns do
		conn:Disconnect()
	end
	self.Row:Delete()
end

return LeaderboardTeamItem

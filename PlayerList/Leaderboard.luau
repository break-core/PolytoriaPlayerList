-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Imports
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)
local LeaderboardUserItem = require(script.Parent.LeaderboardUserItem)
local LeaderboardTeamItem = require(script.Parent.LeaderboardTeamItem)

local Leaderboard = {}
Leaderboard.__index = Leaderboard

function Leaderboard.new(parent, localPlayer)
	local self = setmetatable({}, Leaderboard)
	self.LocalPlayer = localPlayer
	self.UserOptions = nil -- our copy of user options
	self.PlayerToItem = {} -- player to leaderboard user item
	self.PlayerCount = 0
	self.TeamToItem = {} -- team to leaderboard team item
	self.NeutralItem = nil
	self.VisibleStats = {}
	self.Width = Config.CardWidth

	self._order = {} -- items in display order
	self._seq = 0
	self._sortQueued = false
	self._playerConns = {} -- all players and their connections
	self._statConns = {} -- all stats and property changed connections

	-- various views setup
	self.Container = Util.newView(parent, "Container", Config.ListColor)
	self.Container.CornerRadius = 8

	self.Scroll = Util.anchorTopLeft(Instance.New("UIScrollView", self.Container))
	self.Scroll.Name = "Leaderboard"
	self.Scroll.HorizontalScrollMode = Enums.UIScrollMode.Disabled
	self.Scroll.VerticalScrollMode = Enums.UIScrollMode.Auto

	self.Content = Util.newView(self.Scroll, "Layout")
	self.Content.IgnoreMouse = true

	self.Header = Util.newView(self.Content, "Header")
	self.Header.IgnoreMouse = true
	self.HeaderTitle = Util.newLabel(self.Header, "Title", Config.TitleText, Config.TitleSize, Config.HeaderTextColor)
	self.HeaderStats = Util.newView(self.Header, "Stats")
	self.HeaderStats.IgnoreMouse = true

	-- master connections list for the leaderboard
	self._conns = {
		-- player added
		Players.PlayerAdded:Connect(function(player)
			self:OnPlayerAdded(player)
		end),
		-- player removed
		Players.PlayerRemoved:Connect(function(player)
			self:RemovePlayer(player)
		end),
		-- stat added
		Stats.ChildAdded:Connect(function(child)
			if child:IsA("Stat") then
				self:WatchStat(child)
				self:OnStatDefinitionChanged()
			end
		end),
		-- stat removed
		Stats.ChildRemoved:Connect(function(child)
			if self:UnwatchStat(child) then
				self:OnStatDefinitionChanged()
			end
		end),
		-- team added
		Teams.ChildAdded:Connect(function(child)
			if child:IsA("Team") then
				self:Refresh()
			end
		end),
		-- team removed
		Teams.ChildRemoved:Connect(function(child)
			if child:IsA("Team") then
				self:Refresh()
			end
		end),
	}
	
	-- Now watch the rest of the stats
	for _, stat in Util.getStats() do
		self:WatchStat(stat)
	end

	-- fresh!
	self:Refresh()
	return self
end

-- sets user options. use this function instead of setting the member directly
function Leaderboard:SetUserOptions(userOptions)
	self.UserOptions = userOptions
end

-- Increments the internal seq
-- IIRC we don't use this function but I ported it anyways
function Leaderboard:NextSeq(): number
	self._seq += 1
	return self._seq
end

-- Calculates the row width to use for the leaderboard
function Leaderboard:RowWidth(): number
	return self.Width - Config.ListPadding * 2
end

-- Pulls a stat and watches it for changes so we can update it on the leaderboard
function Leaderboard:WatchStat(stat)
	if self._statConns[stat] ~= nil then
		return
	end
	self._statConns[stat] = stat.PropertyChanged:Connect(function(_prop)
		self:OnStatDefinitionChanged()
	end)
end

-- Opposite of WatchStat
function Leaderboard:UnwatchStat(stat): boolean
	local conn = self._statConns[stat]
	if conn == nil then
		return false
	end
	conn:Disconnect()
	self._statConns[stat] = nil
	return true
end

-- Runs when a stat's properties change in any way, refreshing the leaderboard
function Leaderboard:OnStatDefinitionChanged()
	self:Refresh()
end

-- Creates the leaderboards header
function Leaderboard:CreateHeader()
	-- Kill any children (no wait thats too edgy)
	for _, child in self.HeaderStats:GetChildren() do
		child:Delete()
	end

	-- build the header title and stats
	local rowWidth = self:RowWidth()
	local statsW = Util.columnsWidth(#self.VisibleStats, Config.StatColumnWidth)
	Util.place(self.HeaderTitle, 4, 0, rowWidth - 4 - statsW, Config.HeaderHeight)
	Util.place(self.HeaderStats, rowWidth - statsW, 0, statsW, Config.HeaderHeight)

	-- build all the stats for any visible stats
	for i, stat in self.VisibleStats do
		local label = Util.newLabel(self.HeaderStats, "Stat_" .. stat.Name, stat:GetDisplayName(), Config.HeaderStatSize, Config.HeaderTextColor, Enums.HorizontalAlignment.Center)
		Util.place(label, (i - 1) * (Config.StatColumnWidth + Config.StatColumnSpacing), 0, Config.StatColumnWidth, Config.HeaderHeight)
	end
end

-- Removes a players connections to the leaderboard
function Leaderboard:DisconnectPlayer(player)
	local conns = self._playerConns[player]
	if conns ~= nil then
		for _, conn in conns do
			conn:Disconnect()
		end
		self._playerConns[player] = nil
	end
end

-- Main leaderboard refresh function
function Leaderboard:Refresh()
	-- first we save any team items collapsed
	local savedTeamCollapse = {}
	for team, item in self.TeamToItem do
		savedTeamCollapse[team] = item.IsCollapsed
	end
	
	-- then we save any collapsed neutral items
	local savedNeutralCollapse = self.NeutralItem ~= nil and self.NeutralItem.IsCollapsed

	-- now we force user options to disappear
	if self.UserOptions ~= nil then
		self.UserOptions:Disappear()
	end
	
	-- next disconnect a player and destroy their items
	for player, item in self.PlayerToItem do
		self:DisconnectPlayer(player)
		item:Destroy()
	end
	
	-- then destroy team items
	for _, item in self.TeamToItem do
		item:Destroy()
	end
	
	-- then destroy neutral items
	if self.NeutralItem ~= nil then
		self.NeutralItem:Destroy()
	end
	
	-- now reinitialize these values to be safe
	self.PlayerToItem = {}
	self.PlayerCount = 0
	self.TeamToItem = {}
	self.NeutralItem = nil
	self._order = {}

	-- reupdate stats and the header
	self.VisibleStats = Stats:GetVisibleStats()
	self.Width = Util.panelWidth(#self.VisibleStats)
	self:CreateHeader()

	-- add back all players
	for _, player in Players:GetPlayers() do
		self:AddPlayer(player)
	end
	
	-- add back the local player
	if self.PlayerToItem[self.LocalPlayer] == nil then
		self:AddPlayer(self.LocalPlayer)
	end
	
	-- add back teams
	for _, team in Teams:GetTeams() do
		self:AddTeam(team)
	end
	
	-- create the neutral team
	self:CreateNeutralTeam()

	-- sort the list
	self:SortList()
	-- restore collapsed items
	for team, item in self.TeamToItem do
		if savedTeamCollapse[team] then
			item:SetCollapsed(true)
		end
	end
	
	-- restore collapsed neutral item
	if savedNeutralCollapse and self.NeutralItem ~= nil then
		self.NeutralItem:SetCollapsed(true)
	end

	-- team visibility setup
	self:ApplyTeamVisibility()
end

-- Add a player to the leaderboard
function Leaderboard:AddPlayer(player)
	-- skip if a player already corresponds to an item
	if self.PlayerToItem[player] ~= nil then
		return
	end

	-- build a new leaderboard user item and give it all the stats
	local item = LeaderboardUserItem.new(self, player, self:NextSeq())
	for _, stat in self.VisibleStats do
		item:AddStat(stat)
	end
	item:Layout(self:RowWidth())

	-- then have the player update their stats and their team
	self._playerConns[player] = {
		player.StatChanged:Connect(function(stat, _value)
			self:OnPlayerStatChanged(stat)
		end),
		player.TeamChanged:Connect(function(team)
			self:OnPlayerTeamChanged(team)
		end),
	}
	
	-- now make the new item correspond back to the player we added
	self.PlayerToItem[player] = item
	self.PlayerCount += 1
	
	-- order the item
	table.insert(self._order, item)

	-- team visibility setup
	self:ApplyTeamVisibility()
end

-- Handles a player being added to the game
function Leaderboard:OnPlayerAdded(player)
	-- add the player
	self:AddPlayer(player)
	
	-- make a neutral team if no neutral item exists
	if player.Team == nil and self.NeutralItem == nil then
		self:CreateNeutralTeam()
	end
	
	-- update team totals
	self:UpdateTeamTotals()
	
	-- sort list
	self:QueueSortList()
end

-- Adds a team to the leaderboard
function Leaderboard:AddTeam(team)
	-- add the team item and set it up
	local item = LeaderboardTeamItem.new(self, team, self:NextSeq())
	for _, stat in self.VisibleStats do
		item:AddStat(stat)
	end
	item:Layout(self:RowWidth())

	-- map it, order it, and update the leaderboard
	self.TeamToItem[team] = item
	table.insert(self._order, item)
	self:LeaderboardUpdate()
end

-- Removes a player from the leaderboard
function Leaderboard:RemovePlayer(player)
	-- if we already removed this player, then no need to remove them again
	local item = self.PlayerToItem[player]
	if item == nil then
		return
	end

	self:DisconnectPlayer(player)

	-- disappear the options for that user
	if self.UserOptions ~= nil and self.UserOptions.Target == item then
		self.UserOptions:Disappear()
	end

	item:Destroy()
	self.PlayerToItem[player] = nil
	self.PlayerCount -= 1

	-- in C# this was a deferred call to RefreshAfterRemove
	-- this is equivalent i think
	spawn(function()
		wait(0)
		self:RefreshAfterRemove()
	end)
end

-- Refreshing for after a player got removed
function Leaderboard:RefreshAfterRemove()
	-- if nobody is on the neutral team, get rid of that team
	if self.NeutralItem ~= nil and #self:GetNeutralPlayers() == 0 then
		self:DestroyNeutralTeam()
	end
	
	-- team updating stuff
	self:UpdateTeamTotals()
	self:ApplyTeamVisibility()
end

-- Creates the neutral team
function Leaderboard:CreateNeutralTeam()
	-- if the neutral item already exists, or there are no teams, or nobody is on neutral team, exit
	if self.NeutralItem ~= nil or #Teams:GetTeams() == 0 or #self:GetNeutralPlayers() == 0 then
		return
	end

	-- create the neutral item
	local item = LeaderboardTeamItem.newNeutral(self, Config.NeutralTeamName, Config.NeutralTeamColor, self:NextSeq())
	self.NeutralItem = item
	for _, stat in self.VisibleStats do
		item:AddStat(stat)
	end
	item:Layout(self:RowWidth())
	
	-- order it
	table.insert(self._order, item)
end

-- Destroys the neutral team item
function Leaderboard:DestroyNeutralTeam()
	if self.NeutralItem ~= nil then
		self.NeutralItem:Destroy()
		self.NeutralItem = nil
	end
end

-- Gets a list of all players who are neutral
-- If their team is nil, it means they are neutral
function Leaderboard:GetNeutralPlayers()
	local list = {}
	for player in self.PlayerToItem do
		if player.Team == nil then
			table.insert(list, player)
		end
	end
	return list
end

-- Get the total number of neutral stats in action
function Leaderboard:GetNeutralStatTotal(stat): number
	local total = 0
	for player in self.PlayerToItem do
		if player.Team == nil then
			total += Util.numericStat(stat, player) or 0
		end
	end
	return total
end

function Leaderboard:UpdateTeamTotals()
	-- For all visible stats...
	for _, stat in self.VisibleStats do
		-- Update all team item stats
		for _, item in self.TeamToItem do
			item:UpdateStat(stat)
		end
		
		-- Update neutral item stats
		if self.NeutralItem ~= nil then
			self.NeutralItem:UpdateStat(stat)
		end
	end
end

function Leaderboard:OnPlayerTeamChanged(team)
	-- update neutral team
	if team == nil and self.NeutralItem == nil then
		self:CreateNeutralTeam()
	elseif team ~= nil and self.NeutralItem ~= nil and #self:GetNeutralPlayers() == 0 then
		self:DestroyNeutralTeam()
	end

	-- update other team stuff
	self:UpdateTeamTotals()
	self:QueueSortList()
	self:ApplyTeamVisibility()
end

-- updates stats when a player stat gets changed
function Leaderboard:OnPlayerStatChanged(stat)
	if not stat.Visible then
		return
	end
	for _, item in self.TeamToItem do
		item:UpdateStat(stat)
	end
	if self.NeutralItem ~= nil then
		self.NeutralItem:UpdateStat(stat)
	end
end

function Leaderboard:OnTeamCollapseToggled(_teamItem)
	self:ApplyTeamVisibility()
end

-- sorts the leaderboard list
function Leaderboard:SortList()
	-- get the first stat child
	local first = Stats:GetChildren()[1]

	-- a saved version of the first stat child, or nil if both conditions fail
	local stat = if first ~= nil and first:IsA("Stat") then first else nil

	-- we cant script Team.Index but this will work just fine, because Team.Index is equal to
	-- the order of the team itself in Teams
	local teamIndex = {}
	for i, child in Teams:GetChildren() do
		teamIndex[child] = i
	end

	-- for all teams and items, determine
	-- the team's index, it's item type (0), its value, and the item itself into a big table
	local all = {}
	for team, item in self.TeamToItem do
		table.insert(all, {
			TeamIndex = teamIndex[team] or Util.NO_TEAM_INDEX,
			ItemType = 0,
			Value = if stat ~= nil then stat:GetTotalForTeam(team) else nil,
			Item = item,
		})
	end
	
	-- same thing goes for player to item
	for player, item in self.PlayerToItem do
		local team = player.Team
		table.insert(all, {
			TeamIndex = if team ~= nil then (teamIndex[team] or Util.NO_TEAM_INDEX) else Util.NO_TEAM_INDEX,
			ItemType = 1,
			Value = if stat ~= nil then Util.numericStat(stat, player) else nil,
			Item = item,
		})
	end
	
	-- and the neutral team
	if self.NeutralItem ~= nil then
		table.insert(all, { TeamIndex = Util.NO_TEAM_INDEX, ItemType = 0, Value = nil, Item = self.NeutralItem })
	end

	table.sort(all, function(a, b)
		-- if index a isn't the same as index b, return whether a is less than b
		if a.TeamIndex ~= b.TeamIndex then
			return a.TeamIndex < b.TeamIndex
		end
		
		-- same check for item type
		if a.ItemType ~= b.ItemType then
			return a.ItemType < b.ItemType
		end
		
		-- extra sorting i forgot what this does
		if stat ~= nil then
			local aHas, bHas = a.Value ~= nil, b.Value ~= nil
			if aHas ~= bHas then
				return aHas
			end
			if aHas and a.Value ~= b.Value then
				return a.Value > b.Value
			end
		end
		return a.Item.Seq < b.Item.Seq
	end)

	-- order in the court!
	local order = {}
	for _, entry in all do
		table.insert(order, entry.Item)
	end
	self._order = order

	-- update leaderboard
	self:LeaderboardUpdate()
end

-- queues a SortList call
function Leaderboard:QueueSortList()
	-- if sort already queued, exit
	if self._sortQueued then
		return
	end
	self._sortQueued = true

	spawn(function()
		wait(0)
		self._sortQueued = false
		self:SortList()
	end)
end

function Leaderboard:ApplyTeamVisibility()
	for player, item in self.PlayerToItem do
		local visible = true
		local team = player.Team

		-- teams become visible when they're not collapsed
		if team ~= nil and self.TeamToItem[team] ~= nil then
			visible = not self.TeamToItem[team].IsCollapsed
		elseif team == nil and self.NeutralItem ~= nil then
			visible = not self.NeutralItem.IsCollapsed
		end

		item.Row.Visible = visible
	end

	-- update leaderboard
	self:LeaderboardUpdate()
end

function Leaderboard:GetMaxHeight(): number
	-- IsMobileBuild can't be scripted so we get around it with this
	if not Input.IsTouchscreen then
		return Config.ListMaxHeight
	end
	
	-- otherwise we calculate this extra stuff for mobile users
	local reservedBottom = 240
	local top = Config.Margin + Config.ListTop
	return math.clamp(Input.ScreenHeight - reservedBottom - top, 120, Config.ListMaxHeight)
end

-- leaderboard updating
function Leaderboard:LeaderboardUpdate()
	-- this will never be seen but yeah sure
	self.Container.Visible = self.PlayerCount > 0
	if self.PlayerCount == 0 then
		return
	end

	-- extra updating
	local rowWidth = self:RowWidth()
	Util.place(self.Header, 0, 0, rowWidth, Config.HeaderHeight)

	local y = Config.HeaderHeight + Config.RowSpacing
	for _, item in self._order do
		if not item.Destroyed and item.Row.Visible then
			Util.place(item.Row, 0, y, rowWidth, Config.RowHeight)
			y += Config.RowHeight + Config.RowSpacing
		end
	end
	local contentHeight = y - Config.RowSpacing
	Util.place(self.Content, 0, 0, rowWidth, contentHeight)

	local height = math.min(contentHeight + Config.ListPadding * 2, self:GetMaxHeight())
	Util.place(self.Container, -self.Width, 0, self.Width, height)
	Util.place(self.Scroll, Config.ListPadding, Config.ListPadding, rowWidth, height - Config.ListPadding * 2)
end

-- fully destroys the leaderboard
function Leaderboard:Destroy()
	for _, conn in self._conns do
		conn:Disconnect()
	end
	for stat in self._statConns do
		self:UnwatchStat(stat)
	end
	for player, item in self.PlayerToItem do
		self:DisconnectPlayer(player)
		item:Destroy()
	end
	for _, item in self.TeamToItem do
		item:Destroy()
	end
	self:DestroyNeutralTeam()
	self.Container:Delete()
end

return Leaderboard

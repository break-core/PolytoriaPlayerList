-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Imports
local Config = require(script.Config)
local Util = require(script.Util)
local UserCard = require(script.UserCard)
local Leaderboard = require(script.Leaderboard)
local LeaderboardUserOptions = require(script.LeaderboardUserOptions)
local LeaderboardOpener = require(script.LeaderboardOpener)

-- Reliable way of fetching the local player
local localPlayer = Players.LocalPlayer
while localPlayer == nil do
	wait(0.1)
	localPlayer = Players.LocalPlayer
end

-- Turn off the core player list
if Config.HideCorePlayerList then
	CoreUI.UseLeaderboard = false
	CoreUI.UseUserCard = false
end

-- The main GUI of our custom player list
local gui = Instance.New("GUI", PlayerGUI)
gui.Name = "CustomPlayerList"
gui.ZIndex = 5
gui.AvoidCoreUI = false

local PlayerList = {} :: any
PlayerList.IsLeaderboardShown = true

-- The length of all animations played
local ANIM_LENGTH = 0.3

-- Raw animation data for the player list
-- TODO: this is ugly, fix
local ANIMATIONS = {
	open = {
		Card = { { 0, Config.CloseSlide, 0.26794335 }, { 0.3, 0, 0.36602142 } },
		Alpha = { { 0, 0, 0.26794335 }, { 0.3, 1, 0.36602142 } },
		List = { { 0, Config.CloseListExtraSlide, 0.35355353 }, { 0.3, 0, 1 } },
	},
	close = {
		Card = { { 0, 0, 0.36602142 }, { 0.3, Config.CloseSlide, 1 } },
		Alpha = { { 0, 1, 0.36602142 }, { 0.3, 0, 1 } },
		List = { { 0, 0, 0.22531264 }, { 0.3, Config.CloseListExtraSlide, 1 } },
	},
}

-- The currently active animation in play from the PlayerList
local activeAnim = nil

-- We create this first, then have the card draw over it later
LeaderboardOpener.new(gui, PlayerList)

-- Internally the UserCard has it's own pivot node for a few things:
-- 1. For anchoring everything to the top right corner
-- 2. Movement when opening and closing
-- 3. Fading
-- 4. Holding LeaderboardUserOptions (so it can move and fade when everything else does)
-- Here we try and mimic that pivot node for accuracy
local pivot = Util.newPivot(gui, "Pivot", -Config.Margin, Config.Margin)
pivot.PositionRelative = Vector2.New(1, 0)
Util.addFadeRoot(pivot)

-- Now we create the user card, where clicking it toggles the leaderboard 
local userCard = UserCard.new(pivot, localPlayer, function()
	PlayerList:ToggleLeaderboard()
end)

-- Now a pivot for the player list
local listPivot = Util.newPivot(pivot, "PlayerlistPivot", 0, Config.ListTop)

-- And then the leaderboard itself
local leaderboard = Leaderboard.new(listPivot, localPlayer)

-- Now setup our user options
local userOptions = LeaderboardUserOptions.new(pivot)
leaderboard:SetUserOptions(userOptions)

-- And then hold a binding reference to the important stuff
PlayerList.UserCard = userCard
PlayerList.Leaderboard = leaderboard
PlayerList.UserOptions = userOptions

-- Helper function to mimic Godot's AnimationPlayer
-- When playing an animation, this draws one frame of the anim at a time
local function applyFrame(anim, t: number)
	pivot.PositionOffset = Vector2.New(-Config.Margin + Util.sampleKeys(anim.Card, t), Config.Margin)
	Util.setOpacity(pivot, Util.sampleKeys(anim.Alpha, t))
	listPivot.PositionOffset = Vector2.New(Util.sampleKeys(anim.List, t), Config.ListTop)
end

-- This plays an animation of `name` on the PlayerList's active anim
-- applyFrame is actually what does the frame drawing
local function play(name: string)
	if activeAnim ~= nil then
		activeAnim:Cancel()
	end

	-- Grab the open or close anim data and play it
	local anim = ANIMATIONS[name]
	activeAnim = Util.playTimeline(ANIM_LENGTH, function(t)
		applyFrame(anim, t)
	end)
end

-- Opens the player list
-- Will not do anything unless the leaderboard isn't shown
function PlayerList:Open()
	if self.IsLeaderboardShown then
		return
	end
	self.IsLeaderboardShown = true
	play("open")
end

-- The opposite of PlayerList:Open
function PlayerList:Close()
	if not self.IsLeaderboardShown then
		return
	end
	self.IsLeaderboardShown = false
	play("close")
end

-- Rather than just controlling one state, this does both open and close
-- Best to call this
function PlayerList:ToggleLeaderboard()
	self.IsLeaderboardShown = not self.IsLeaderboardShown
	play(if self.IsLeaderboardShown then "open" else "close")
end

-- Handle toggling the leaderboard
Input.KeyDown:Connect(function(key, gameFocused)
	if key == Config.ToggleKey and gameFocused then
		PlayerList:ToggleLeaderboard()
	end
end)

-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--[[
	!! Master configuration for the custom playerlist !!
	
	Most of these are features solely for pros. The easy ones are:
	- HideCorePlayerList
	- ToggleKey
	- CreatorNameStyle
	- NameStyles
	
	If you know what you're doing, happy customizing!
]]

local Config = {
	-- Hides Polytoria's core player list for you. Always true.
	-- Disabling this will have the main player list and the custom one active at once.
	HideCorePlayerList = true,

	-- The main key used to toggle the player list
	-- If you want Polytoria behavior, keep this as Enums.KeyCode.Tab
	ToggleKey = Enums.KeyCode.Tab,

	-- Layout in pixels
	Margin = 16,
	CardWidth = 260,
	CardHeight = 48,
	CardPadding = 4,
	AvatarSize = 40,
	ListTop = 52,
	ListPadding = 8,
	ListMaxHeight = 300,
	HeaderHeight = 15,
	RowHeight = 20,
	RowSpacing = 4,
	BadgeSize = 16,
	StatColumnWidth = 70,
	CardStatColumnWidth = 56,
	StatColumnSpacing = 15,
	MinNameWidth = 60,

	CloseSlide = 240,
	CloseListExtraSlide = 64,

	PopupWidth = 160,
	PopupMinHeight = 35,
	PopupButtonHeight = 32,

	-- Colors
	CardColor = Color.New(0.08, 0.08, 0.08, 0.49803922),
	ListColor = Color.New(0, 0, 0, 0.49803922),
	HeaderTextColor = Color.New(0.776, 0.8, 0.824, 0.85),
	TextColor = Color.White,
	DimTextColor = Color.New(1, 1, 1, 0.49803922),

	TeamPanelAlpha = 0.49803922,
	NeutralTeamName = "Neutral Team",
	NeutralTeamColor = Color.New(0.56, 0.61, 0.66),

	ButtonFontColor = Color.New(0.875, 0.875, 0.875),
	ButtonFontHoverColor = Color.New(0.95, 0.95, 0.95),
	ButtonFontPressedColor = Color.White,
	ButtonFontHoverPressedColor = Color.White,

	FontPreset = Enums.FontPreset.Montserrat,
	FontWeight = Enums.FontWeight.SemiBold,

	-- These font sizes are actually in Godot pixel units
	-- We use Util.px to convert these to equivalent FontSize units
	CardNameSize = 16,
	CardStatNameSize = 10,
	CardStatValueSize = 12,
	TitleSize = 11,
	HeaderStatSize = 13,
	RowTextSize = 13,
	RowStatSize = 16,
	ButtonTextSize = 16,
	TitleText = "Playerlist",

	-- Fun thing I implemented: Godot rich text BB code support for usernames.
	-- You can change this to whatever you want. For example, this makes the creator's name rainbow and wavey
	CreatorNameStyle = "[rainbow][wave amp=50 freq=7 connected=1]{name}[/wave][/rainbow]",
	
	-- Alternatively, you can set individual player names with special colors
	-- The syntax is [username: formattedString]. Include {name} to use that player's username
	NameStyles = {},

	-- Manual role badge image setup, where you use a returned role like:
	-- "admin" = "linktoimage"
	-- I would link in the actual badge icons but they're locked behind Godot shenanigans
	BadgeImages = {},

	-- Use this when you want to add player-specific options on the leaderboard. The syntax is a table for each option containing:
	-- Text, a string containing what text you want to show.
	-- Visible, a function with any parameters that returns a boolean determining the options visibility
	-- Action, a function taking any parameters and returning nothing dictating how the action should work
	PlayerOptions = {},
}

return Config

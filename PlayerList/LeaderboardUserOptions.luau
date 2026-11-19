-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Imports
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local LeaderboardUserOptions = {}
LeaderboardUserOptions.__index = LeaderboardUserOptions

local APPEAR_LENGTH = 0.6
local APPEAR_SCALE = {
	{ 0, 0.8, 1.1892073 },
	{ 0.13333334, 1.1, 0.8122525 },
	{ 0.3, 0.98, 0.8408964 },
	{ 0.6, 1, 1 },
}
local APPEAR_ALPHA = { { 0, 0, 0.81225234 }, { 0.13333334, 1, 1 } }

local DISAPPEAR_LENGTH = 0.4
local DISAPPEAR_SCALE = { { 0, 1, 0.25881612 }, { 0.4, 0.8, 1.1892073 } }
local DISAPPEAR_ALPHA = { { 0, 1, 0.25881612 }, { 0.4, 0, 0.81225234 } }

function LeaderboardUserOptions.new(parent)
	local self = setmetatable({}, LeaderboardUserOptions)
	self.Active = false
	self.Target = nil
	self._anim = nil

	self.Root = Util.newPivot(parent, "UserOptions", 0, 0)
	self.Root.Visible = false

	self.Pivot = Util.newPivot(self.Root, "Pivot", 0, 0)
	Util.addFadeRoot(self.Pivot)

	self.Panel = Util.newView(self.Pivot, "PanelContainer", Config.ListColor)
	self.Panel.CornerRadius = 8

	local arrowClip = Util.newView(self.Pivot, "Arrow")
	arrowClip.IgnoreMouse = true
	arrowClip.ClipDescendants = true
	Util.place(arrowClip, -8, -7, 8, 14)
	local diamond = Util.newView(arrowClip, "Shape", Config.ListColor)
	diamond.IgnoreMouse = true
	diamond.PivotPoint = Vector2.New(0.5, 0.5)
	diamond.Rotation = 45
	Util.place(diamond, 0, 7, 9.9, 9.9)

	self._clickConn = Input.KeyUp:Connect(function(key, _gameFocused)
		if key ~= Enums.KeyCode.MouseLeft or not self.Active then
			return
		end
		local mouse = Input.MousePosition
		if Util.isInside(self.Panel, mouse) then
			return
		end
		if self.Target ~= nil and Util.isInside(self.Target.Row, mouse) then
			return
		end
		self:Disappear()
	end)

	return self
end

function LeaderboardUserOptions:Play(length: number, scaleKeys, alphaKeys, done: (() -> ())?)
	if self._anim ~= nil then
		self._anim:Cancel()
	end
	self._anim = Util.playTimeline(length, function(t)
		local s = Util.sampleKeys(scaleKeys, t)
		self.Pivot.Scale = Vector2.New(s, s)
		Util.setOpacity(self.Pivot, Util.sampleKeys(alphaKeys, t))
	end, done)
end

function LeaderboardUserOptions:Build(player): number
	for _, child in self.Panel:GetChildren() do
		child:Delete()
	end

	local count = 0
	for i, option in Config.PlayerOptions do
		if option.Visible == nil or option.Visible(player) then
			Util.newFlatButton(self.Panel, "Option" .. i, option.Text, 8, count * Config.PopupButtonHeight,
				Config.PopupWidth - 8, Config.PopupButtonHeight, function()
					self:Disappear()
					option.Action(player)
				end)
			count += 1
		end
	end

	local height = math.max(Config.PopupMinHeight, count * Config.PopupButtonHeight)
	Util.place(self.Panel, -Config.PopupWidth - 8, -18, Config.PopupWidth, height)
	return count
end

function LeaderboardUserOptions:PopupAt(item)
	if self.Active then
		return
	end
	if self:Build(item.TargetPlayer) == 0 then
		return
	end
	self.Active = true
	self.Target = item

	local origin = self.Root.Parent.AbsolutePosition
	local rowPos = item.Row.AbsolutePosition
	self.Root.PositionOffset = Vector2.New(rowPos.X - 16 - origin.X, rowPos.Y + 11 - origin.Y)

	self.Root.Visible = true
	self:Play(APPEAR_LENGTH, APPEAR_SCALE, APPEAR_ALPHA)
end

function LeaderboardUserOptions:Disappear()
	if not self.Active then
		return
	end
	self.Active = false
	self.Target = nil
	self:Play(DISAPPEAR_LENGTH, DISAPPEAR_SCALE, DISAPPEAR_ALPHA, function()
		if not self.Active then
			self.Root.Visible = false
		end
	end)
end

function LeaderboardUserOptions:Destroy()
	if self._anim ~= nil then
		self._anim:Cancel()
	end
	self._clickConn:Disconnect()
	self.Root:Delete()
end

return LeaderboardUserOptions

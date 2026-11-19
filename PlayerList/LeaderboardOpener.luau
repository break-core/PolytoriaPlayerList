-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Imports
local Util = require(script.Parent.Util)

local LeaderboardOpener = {}
LeaderboardOpener.__index = LeaderboardOpener

function LeaderboardOpener.new(parent, playerList)
	local self = setmetatable({}, LeaderboardOpener)

	self.Root = Util.newView(parent, "LeaderboardOpener")
	self.Root.PositionRelative = Vector2.New(1, 0)
	self.Root.PivotPoint = Vector2.New(1, 0)

	Util.place(self.Root, -13, 16, 263, 49)

	self._conn = self.Root.MouseUp:Connect(function()
		if not playerList.IsLeaderboardShown then
			playerList:Open()
		end
	end)

	return self
end

function LeaderboardOpener:Destroy()
	self._conn:Disconnect()
	self.Root:Delete()
end

return LeaderboardOpener

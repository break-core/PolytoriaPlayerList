-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Imports
local Config = require(script.Parent.Config)

local Util = {}

local FONT_SCALE = 1.35

Util.NO_TEAM_INDEX = math.huge

function Util.px(size: number): number
	return size / FONT_SCALE
end

function Util.withAlpha(c, alpha: number)
	return Color.New(c.R, c.G, c.B, alpha)
end

local painted = {}
local fadeRoots = {}
local paintCount = 0

function Util.addFadeRoot(root)
	fadeRoots[root] = 1
end

local function rootsOf(inst)
	local roots = {}
	for root in fadeRoots do
		if inst == root or inst:IsDescendantOf(root) then
			table.insert(roots, root)
		end
	end
	return roots
end

local function opacityOf(entry): number
	local a = 1
	for _, root in entry.Roots do
		a *= fadeRoots[root] or 1
	end
	return a
end

local function prune()
	for inst in painted do
		if inst.ClassName == nil then
			painted[inst] = nil
		end
	end
end

function Util.paint(inst, prop: string, color)
	local entry = painted[inst]
	if entry == nil then
		entry = { Props = {}, Roots = rootsOf(inst) }
		painted[inst] = entry

		paintCount += 1
		if paintCount % 256 == 0 then
			prune()
		end
	end
	entry.Props[prop] = color
	inst[prop] = Util.withAlpha(color, color.A * opacityOf(entry))
end

function Util.setOpacity(root, opacity: number)
	fadeRoots[root] = opacity
	for inst, entry in painted do
		if inst.ClassName == nil then
			painted[inst] = nil
		elseif table.find(entry.Roots, root) then
			local a = opacityOf(entry)
			for prop, c in entry.Props do
				inst[prop] = Util.withAlpha(c, c.A * a)
			end
		end
	end
end

function Util.ease(x: number, c: number): number
	x = math.clamp(x, 0, 1)
	if c > 0 then
		if c < 1 then
			return 1 - (1 - x) ^ (1 / c)
		end
		return x ^ c
	elseif c < 0 then
		if x < 0.5 then
			return ((x * 2) ^ -c) * 0.5
		end
		return (1 - ((1 - (x - 0.5) * 2) ^ -c)) * 0.5 + 0.5
	end
	return 0
end

function Util.sampleKeys(keys, t: number): number
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			local f = (t - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * Util.ease(f, a[3])
		end
	end
	return keys[#keys][2]
end

function Util.playTimeline(length: number, step: (number) -> (), done: (() -> ())?)
	step(0)
	local tw = Tween:NewTween()
	tw:TweenNumber(0, length, length, step)
	if done ~= nil then
		tw.Finished:Connect(done)
	end
	return tw
end

function Util.anchorTopLeft(ui)
	ui.PositionRelative = Vector2.New(0, 0)
	ui.PivotPoint = Vector2.New(0, 0)
	return ui
end

function Util.place(ui, x: number, y: number, w: number, h: number)
	ui.PositionOffset = Vector2.New(x, y)
	ui.SizeOffset = Vector2.New(w, h)
end

local font = nil
function Util.font()
	if font == nil or font.ClassName == nil then
		font = BuiltInFontAsset.New()
		font.FontPreset = Config.FontPreset
		font.FontWeight = Config.FontWeight
	end
	return font
end

function Util.newView(parent, name: string, color)
	local v = Util.anchorTopLeft(Instance.New("UIView", parent))
	v.Name = name
	if color ~= nil and color.A > 0 then
		Util.paint(v, "Color", color)
	else
		v.Color = Color.Transparent
	end
	return v
end

function Util.newPivot(parent, name: string, x: number, y: number)
	local v = Util.newView(parent, name)
	v.IgnoreMouse = true
	Util.place(v, x, y, 0, 0)
	return v
end

function Util.newLabel(parent, name: string, text: string, size: number, color, align)
	local l = Util.anchorTopLeft(Instance.New("UILabel", parent))
	l.Name = name
	l.Color = Color.Transparent
	l.FontAsset = Util.font()
	l.Text = text
	l.FontSize = Util.px(size)
	Util.paint(l, "TextColor", color or Config.TextColor)
	l.HorizontalAlignment = align or Enums.HorizontalAlignment.Left
	l.VerticalAlignment = Enums.VerticalAlignment.Middle
	l.TextTrimming = Enums.TextTrimming.CharacterEllipsis
	l.IgnoreMouse = true
	return l
end

function Util.newImage(parent, name: string)
	local img = Util.anchorTopLeft(Instance.New("UIImage", parent))
	img.Name = name
	img.IgnoreMouse = true
	img.StretchMode = Enums.ImageStretchMode.Centered
	Util.paint(img, "Color", Color.White)
	return img
end

function Util.isInside(ui, point): boolean
	if ui == nil or not ui.IsVisibleInTree then
		return false
	end
	local p = ui.AbsolutePosition
	local s = ui.AbsoluteSize
	return point.X >= p.X and point.Y >= p.Y and point.X <= p.X + s.X and point.Y <= p.Y + s.Y
end

function Util.onRelease(ui, callback: () -> ())
	return ui.MouseUp:Connect(function()
		if Util.isInside(ui, Input.MousePosition) then
			callback()
		end
	end)
end

function Util.newFlatButton(parent, name: string, text: string, x: number, y: number, w: number, h: number,
	onPressed: () -> ())
	local btn = Util.newView(parent, name)
	Util.place(btn, x, y, w, h)

	local label = Util.newLabel(btn, "Text", text, Config.ButtonTextSize, Config.ButtonFontColor)
	Util.place(label, 8, 0, math.max(w - 8, 0), h)

	local hovered, pressed = false, false
	local function refresh()
		local c = Config.ButtonFontColor
		if pressed and hovered then
			c = Config.ButtonFontHoverPressedColor
		elseif pressed then
			c = Config.ButtonFontPressedColor
		elseif hovered then
			c = Config.ButtonFontHoverColor
		end
		Util.paint(label, "TextColor", c)
	end

	btn.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	btn.MouseExit:Connect(function()
		hovered = false
		refresh()
	end)
	btn.MouseDown:Connect(function()
		pressed = true
		refresh()
	end)
	btn.MouseUp:Connect(function()
		local inside = Util.isInside(btn, Input.MousePosition)
		pressed = false
		refresh()
		if inside then
			onPressed()
		end
	end)

	return btn
end

function Util.columnsWidth(count: number, columnWidth: number): number
	if count == 0 then
		return 0
	end
	return count * columnWidth + (count - 1) * Config.StatColumnSpacing
end

function Util.panelWidth(statCount: number): number
	local cardNeeded = Config.CardPadding + Config.AvatarSize + 8 + Config.BadgeSize + 4 + Config.MinNameWidth
		+ Config.StatColumnSpacing + Util.columnsWidth(statCount, Config.CardStatColumnWidth) + Config.CardPadding
	local listNeeded = Config.ListPadding * 2 + Config.BadgeSize + 3 + Config.MinNameWidth + 8
		+ Util.columnsWidth(statCount, Config.StatColumnWidth)
	return math.max(Config.CardWidth, cardNeeded, listNeeded)
end

function Util.layoutStatColumns(labels, visibleStats, rowWidth: number, height: number): number
	local statsW = Util.columnsWidth(#visibleStats, Config.StatColumnWidth)
	for i, stat in visibleStats do
		local label = labels[stat]
		if label ~= nil then
			Util.place(label, rowWidth - statsW + (i - 1) * (Config.StatColumnWidth + Config.StatColumnSpacing), 0,
				Config.StatColumnWidth, height)
		end
	end
	return statsW
end

local function roundTrim(n: number, decimals: number): string
	local m = 10 ^ decimals
	local r = math.floor(math.abs(n) * m + 0.5) / m
	local s = string.format("%." .. decimals .. "f", r)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	if n < 0 and s ~= "0" then
		s = "-" .. s
	end
	return s
end

function Util.toKMB(num: number): string
	if num > 999999999 or num < -999999999 then
		return roundTrim(num / 1e9, 3) .. "B"
	elseif num > 999999 or num < -999999 then
		return roundTrim(num / 1e6, 2) .. "M"
	elseif num > 999 or num < -999 then
		return roundTrim(num / 1e3, 1) .. "K"
	end
	return tostring(num)
end

function Util.numericStat(stat, player): number?
	local v = stat:Get(player)
	if type(v) == "number" then
		return v
	end
	return nil
end

function Util.getStats()
	local list = {}
	for _, child in Stats:GetChildren() do
		if child:IsA("Stat") then
			table.insert(list, child)
		end
	end
	return list
end

function Util.badgeImageFor(player): string?
	local role = ""
	if player.IsCreator then
		role = "creator"
	elseif player.UserRoleClass ~= nil and player.UserRoleClass ~= "" then
		role = player.UserRoleClass
	elseif player.IsAdmin then
		role = "admin"
	end
	if role == "" then
		return nil
	end
	return Config.BadgeImages[role]
end

function Util.applyBadge(image, player)
	local id = Util.badgeImageFor(player)
	image.Visible = id ~= nil
	if id ~= nil and image.ImageID ~= id then
		image.ImageType = Enums.ImageType.Asset
		image.ImageID = id
	end
end

local function escapeBBCode(text: string): string
	return (string.gsub(text, "%[", "[lb]"))
end

function Util.nameStyleFor(player): string?
	local style = Config.NameStyles[player.Name]
	if style == nil and player.IsCreator then
		style = Config.CreatorNameStyle
	end
	return style
end

function Util.applyName(label, player)
	local style = Util.nameStyleFor(player)
	if style == nil or style == "" then
		label.UseRichText = false
		label.Text = player.Name
		return
	end
	local name = escapeBBCode(player.Name)
	label.UseRichText = true

	label.Text = (string.gsub(style, "{name}", function()
		return name
	end))
end

function Util.watchRole(badge, nameLabel, player, isAlive: () -> boolean)
	Util.applyBadge(badge, player)
	Util.applyName(nameLabel, player)
	spawn(function()
		for _ = 1, 5 do
			wait(2)
			if not isAlive() then
				return
			end
			Util.applyBadge(badge, player)
			Util.applyName(nameLabel, player)
		end
	end)
end

return Util

-- Vape session card. Tween-driven motion, no render loop or minimum display time.
local TweenService = game:GetService('TweenService')
local screen = {Value = 0, Tweens = {}, AccentObjects = {}, Steps = {}}
local palette = {
	Main = Color3.fromRGB(26, 25, 26),
	Text = Color3.fromRGB(224, 228, 226),
	Accent = Color3.fromRGB(103, 235, 193)
}
local function create(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end
local function round(object, radius)
	create('UICorner', object, {CornerRadius = UDim.new(0, radius)})
end
local function accent(object, property)
	object[property] = palette.Accent
	screen.AccentObjects[#screen.AccentObjects + 1] = {object, property}
	return object
end
local function text(parent, value, position, size, fontSize, color, bold)
	return create('TextLabel', parent, {
		BackgroundTransparency = 1, Position = position, Size = size,
		Text = value, TextSize = fontSize, TextColor3 = color or palette.Text,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd
	})
end
local function motion(object, duration, properties, repeatCount)
	if screen.ReducedMotion then
		if not repeatCount then for key, value in pairs(properties) do object[key] = value end end
		return
	end
	-- One tracked tween per object; progress updates replace their predecessor.
	local previous = screen.Tweens[object]
	if previous then previous:Cancel() end
	local tween = TweenService:Create(object, TweenInfo.new(duration,
		Enum.EasingStyle.Quart, Enum.EasingDirection.Out, repeatCount or 0), properties)
	screen.Tweens[object] = tween
	tween:Play()
end

local function readJSON(path)
	local ok, value = pcall(function()
		return game:GetService('HttpService'):JSONDecode(readfile(path))
	end)
	return ok and type(value) == 'table' and value or {}
end
local colors = readJSON('newvape/profiles/color.txt')
pcall(function()
	if colors.Main then palette.Main = Color3.fromRGB(unpack(colors.Main)) end
	if colors.Text then palette.Text = Color3.fromRGB(unpack(colors.Text)) end
end)
pcall(function()
	local saved = readJSON('newvape/profiles/'..game.GameId..'.gui.txt')
	local settings = saved.Categories.Main.Settings
	local reduced = settings.GUI['Reduced motion']
	screen.ReducedMotion = type(reduced) == 'table' and reduced.Enabled == true
	for _, pane in pairs(settings) do
		local color = type(pane) == 'table' and pane['GUI Theme']
		if type(color) == 'table' and color.Hue and color.Sat and color.Value then
			palette.Accent = Color3.fromHSV(color.Hue, color.Sat, color.Value)
		end
	end
end)

function screen:SetTheme(ui, color)
	if ui and ui.Main then palette.Main = ui.Main end
	if ui and ui.Text then palette.Text = ui.Text end
	if color and color.Hue then palette.Accent = Color3.fromHSV(color.Hue, color.Sat, color.Value) end
	if self.Panel then self.Panel.BackgroundColor3 = palette.Main end
	for _, item in ipairs(self.AccentObjects) do item[1][item[2]] = palette.Accent end
end
function screen:HideLoadingScreen(immediate)
	local gui = self.LoadingScreen
	if not gui then return end
	for _, tween in pairs(self.Tweens) do tween:Cancel() end
	self.Tweens = {}
	self.LoadingScreen, self.LoadingStatus, self.Progress, self.Panel = nil, nil, nil, nil
	self.AccentObjects, self.Steps = {}, {}
	if shared.VapeLoading == self then shared.VapeLoading = nil end
	if immediate or self.ReducedMotion then
		gui:Destroy()
	else
		local group = gui:FindFirstChild('SessionCard')
		if group then
			local fade = TweenService:Create(group, TweenInfo.new(0.16), {GroupTransparency = 1})
			fade:Play()
		end
		task.delay(0.18, function() gui:Destroy() end)
	end
end
function screen:WaitForMinimumDisplay() end
function screen:SetLoadingProgress(value, message)
	if not self.LoadingScreen then return end
	if type(value) == 'number' and value == value then
		self.Value = math.max(self.Value, math.clamp(value, 0, 1))
		motion(self.Progress, 0.2, {Size = UDim2.fromScale(self.Value, 1)})
		self.Percent.Text = string.format('%02d', math.floor(self.Value * 100))..'%'
		local stage = self.Value >= 1 and 4 or self.Value >= 0.85 and 3 or self.Value >= 0.5 and 2 or 1
		for index, step in ipairs(self.Steps) do
			step.Dot.BackgroundTransparency = index <= stage and 0 or 0.82
			step.Label.TextTransparency = index <= stage and 0 or 0.55
			step.Number.Text = index < stage and '+' or tostring(index)
		end
	end
	if message then self.LoadingStatus.Text = tostring(message) end
end
function screen:ShowLoadingScreen()
	self:HideLoadingScreen(true)
	self.Value = 0
	local parent = game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')
	local previous = parent:FindFirstChild('VapeLoadingScreen')
	if previous then previous:Destroy() end
	local gui = create('ScreenGui', parent, {Name = 'VapeLoadingScreen', ResetOnSpawn = false, DisplayOrder = 10000})
	self.LoadingScreen = gui
	shared.VapeLoading = self
	gui.Destroying:Connect(function()
		if self.LoadingScreen ~= gui then return end
		for _, tween in pairs(self.Tweens) do tween:Cancel() end
		self.Tweens, self.AccentObjects, self.Steps = {}, {}, {}
		self.LoadingScreen, self.LoadingStatus, self.Progress, self.Panel = nil, nil, nil, nil
		if shared.VapeLoading == self then shared.VapeLoading = nil end
	end)
	local panel = create('CanvasGroup', gui, {
		Name = 'SessionCard', AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(540, 310),
		BackgroundColor3 = palette.Main, BorderSizePixel = 0, GroupTransparency = 1
	})
	self.Panel = panel
	round(panel, 18)
	local fit = create('UIScale', panel, {Scale = 1})
	local function resize()
		local size = gui.AbsoluteSize
		fit.Scale = math.max(0.1, math.min(1, (size.X - 32) / 540, (size.Y - 32) / 310))
	end
	gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(resize)
	resize()
	create('UIStroke', panel, {Color = palette.Text, Transparency = 0.88, Thickness = 1})
	-- Clipped contour geometry is static: inexpensive depth without image downloads.
	local art = create('Frame', panel, {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true
	})
	for i = 1, 6 do
		local ring = create('Frame', art, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -15, 0, 12),
			Size = UDim2.fromOffset(110 + i * 46, 78 + i * 36), Rotation = -28,
			BackgroundTransparency = 1
		})
		round(ring, 65)
		accent(create('UIStroke', ring, {Thickness = 1, Transparency = 0.91 - i * 0.008}), 'Color')
	end
	local rail = accent(create('Frame', panel, {
		Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -56, 0, 2), BorderSizePixel = 0
	}), 'BackgroundColor3')
	create('UIGradient', rail, {Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1)
	})})
	text(panel, 'vape', UDim2.fromOffset(28, 23), UDim2.fromOffset(130, 48), 42, palette.Text, true)
	accent(text(panel, 'V4', UDim2.fromOffset(141, 35), UDim2.fromOffset(36, 22), 14, nil, true), 'TextColor3')
	text(panel, 'POV / FRONTLINES', UDim2.fromOffset(29, 79), UDim2.fromOffset(250, 16), 10, palette.Text).TextTransparency = 0.42
	text(panel, 'Your session, ready to go.', UDim2.fromOffset(28, 121), UDim2.fromOffset(470, 28), 22, palette.Text, true)
	self.LoadingStatus = text(panel, 'Preparing your interface', UDim2.fromOffset(29, 155), UDim2.fromOffset(410, 22), 12, palette.Text)
	self.LoadingStatus.TextTransparency = 0.3
	self.Percent = accent(text(panel, '00%', UDim2.fromOffset(451, 153), UDim2.fromOffset(61, 24), 18, nil, true), 'TextColor3')
	self.Percent.TextXAlignment = Enum.TextXAlignment.Right
	local track = create('Frame', panel, {
		Position = UDim2.fromOffset(28, 192), Size = UDim2.new(1, -56, 0, 5),
		BackgroundColor3 = palette.Text, BackgroundTransparency = 0.92, BorderSizePixel = 0, ClipsDescendants = true
	})
	round(track, 3)
	self.Progress = accent(create('Frame', track, {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0}), 'BackgroundColor3')
	round(self.Progress, 3)
	local sheen = create('UIGradient', self.Progress, {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(160, 200, 185)),
		Offset = Vector2.new(-1, 0)
	})
	motion(sheen, 1.8, {Offset = Vector2.new(1, 0)}, -1)
	for index, name in ipairs({'Interface', 'Modules', 'Profile'}) do
		local x = 28 + (index - 1) * 164
		local dot = accent(create('Frame', panel, {
			Position = UDim2.fromOffset(x, 219), Size = UDim2.fromOffset(20, 20), BorderSizePixel = 0
		}), 'BackgroundColor3')
		round(dot, 6)
		local number = text(dot, tostring(index), UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 10, palette.Main, true)
		number.TextXAlignment = Enum.TextXAlignment.Center
		local label = text(panel, name, UDim2.fromOffset(x + 29, 218), UDim2.fromOffset(115, 22), 11, palette.Text)
		self.Steps[index] = {Dot = dot, Label = label, Number = number}
	end
	create('Frame', panel, {
		Position = UDim2.fromOffset(28, 260), Size = UDim2.new(1, -56, 0, 1),
		BackgroundColor3 = palette.Text, BackgroundTransparency = 0.92, BorderSizePixel = 0
	})
	text(panel, 'Made for your next session.', UDim2.fromOffset(28, 270), UDim2.fromOffset(280, 22), 10, palette.Text).TextTransparency = 0.45
	local close = create('TextButton', panel, {
		Position = UDim2.fromOffset(358, 265), Size = UDim2.fromOffset(158, 34),
		Text = 'Hide loading screen', Font = Enum.Font.Gotham, TextSize = 10,
		BackgroundTransparency = 1, TextColor3 = palette.Text, TextTransparency = 0.35
	})
	close.Activated:Connect(function() self:HideLoadingScreen(true) end)
	self:SetLoadingProgress(0)
	motion(panel, 0.22, {GroupTransparency = 0})
end
local ok, err = pcall(screen.ShowLoadingScreen, screen)
if not ok then
	screen:HideLoadingScreen(true)
	warn('[Vape] Loading UI unavailable: '..tostring(err))
end
return screen

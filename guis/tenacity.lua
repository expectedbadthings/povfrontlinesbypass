-- Tenacity 5.1 interface port. Roblox module/control and profile APIs are preserved.
local tenacity = {
	ActiveBinds = {},
	Categories = {},
	GUIColor = {
		Hue = 0.46,
		Sat = 0.96,
		Value = 0.52
	},
	HeldKeybinds = {},
	Loaded = false,
	Libraries = {},
	Modules = {},
	Place = game.PlaceId,
	Profile = 'default',
	RecentModules = {},
	RainbowSliders = {},
	Settings = {},
	SettingToggleNotifications = {},
	ThreadFix = setthreadidentity and true or false,
	ToggleNotifications = {},
	Version = '5.1-rbx',
	Build = 'r12-sidegui-controls',
	Windows = {}
}
shared.TenacityBuild = tenacity.Build

local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local tweenService = cloneref(game:GetService('TweenService'))
local inputService = cloneref(game:GetService('UserInputService'))
local textService = cloneref(game:GetService('TextService'))
local guiService = cloneref(game:GetService('GuiService'))
local runService = cloneref(game:GetService('RunService'))
local httpService = cloneref(game:GetService('HttpService'))
local lightingService = cloneref(game:GetService('Lighting'))

local fontsize = Instance.new('GetTextBoundsParams')
fontsize.Width = math.huge
local notifications
local gettenacityasset
local components
local clickgui
local topographyBackground
local scaledgui
local toolblur
local tooltip
local TextGUI
local scale = {Scale = 1}
local gui

local isfile = isfile or function(file)
	local success, data = pcall(function()
		return readfile(file)
	end)

	return success and data ~= nil and data ~= ''
end

local function loadJson(path)
	local success, data = pcall(function()
		return httpService:JSONDecode(readfile(path))
	end)

	return success and type(data) == 'table' and data or nil
end

-- Search terms are literal; #terms match category names and @terms are state filters.
-- Plain terms search both module names and their tooltips so you can search by purpose too.
local function matchesModuleSearch(name, category, description, query)
	name = tostring(name or ''):lower()
	category = tostring(category or ''):lower()
	description = tostring(description or ''):lower()
	local searchable = name..' '..description
	for term in query:lower():gmatch('%S+') do
		if term:sub(1, 1) == '#' then
			if #term > 1 and not category:find(term:sub(2), 1, true) then return false end
		elseif term:sub(1, 1) ~= '@' and not searchable:find(term, 1, true) then
			return false
		end
	end
	return true
end

local favoriteData = loadJson('tenacity/profiles/favorites.json') or {}
tenacity.Favorites = {}
for name, selected in pairs(favoriteData) do
	if type(name) == 'string' and selected == true then tenacity.Favorites[name] = true end
end

-- Keep the Recent search filter useful between sessions.
local recentData = loadJson('tenacity/profiles/recent.json') or {}
for _, name in ipairs(recentData) do
	if type(name) == 'string' and not table.find(tenacity.RecentModules, name) then
		table.insert(tenacity.RecentModules, name)
		if #tenacity.RecentModules >= 16 then break end
	end
end

local function matchesModuleState(module, name, query)
	for term in query:lower():gmatch('%S+') do
		if (term == '@on' or term == '@enabled') and not module.Enabled then return false end
		if (term == '@off' or term == '@disabled') and module.Enabled then return false end
		if (term == '@fav' or term == '@favorite' or term == '@favorites') and not tenacity.Favorites[name] then return false end
		if term == '@recent' and not table.find(tenacity.RecentModules, name) then return false end
	end
	return true
end
function tenacity:ToggleFavorite(name)
	local previous = self.Favorites[name]
	self.Favorites[name] = not previous or nil
	local ok, err = pcall(function()
		writefile('tenacity/profiles/favorites.json', httpService:JSONEncode(self.Favorites))
	end)
	if not ok then
		self.Favorites[name] = previous
		self:CreateNotification('Favorites', 'Could not save: '..tostring(err), 4, 'alert')
	end
	if self.SearchBar then self.SearchBar:Refresh() end
	return ok
end

local recentDirty = false
local recentWritePending = false
function tenacity:FlushRecent()
	if not recentDirty then return end
	local ok = pcall(function()
		writefile('tenacity/profiles/recent.json', httpService:JSONEncode(self.RecentModules))
	end)
	if ok then recentDirty = false end
end

function tenacity:RecordRecent(name)
	if self.Loaded ~= true then return end
	local current = table.find(self.RecentModules, name)
	if current == 1 then return end
	if current then table.remove(self.RecentModules, current) end
	table.insert(self.RecentModules, 1, name)
	while #self.RecentModules > 16 do table.remove(self.RecentModules) end
	recentDirty = true
	if not recentWritePending then
		recentWritePending = true
		task.delay(0.5, function()
			recentWritePending = false
			if tenacity.Loaded ~= nil then tenacity:FlushRecent() end
		end)
	end
	if self.SearchBar and self.SearchBar.Filter == 'Recent' then self.SearchBar:Refresh() end
end
local color = {}
local uipallet = {}
do
	function color.Dark(col, num)
		local h, s, v = col:ToHSV()
		return Color3.fromHSV(h, s, math.clamp(select(3, uipallet.Main:ToHSV()) > 0.5 and v + num or v - num, 0, 1))
	end

	function color.Light(col, num)
		local h, s, v = col:ToHSV()
		return Color3.fromHSV(h, s, math.clamp(select(3, uipallet.Main:ToHSV()) > 0.5 and v - num or v + num, 0, 1))
	end

	function tenacity:Color(h)
		local s = 0.74 + (0.26 * math.min(h / 0.045, 1))

		if h > 0.577 then
			s = 1 - (0.48 * math.min((h - 0.577) / 0.088, 1))
		end

		if h > 0.674 then
			s = 0.52 + (0.48 * math.min((h - 0.674) / 0.149, 1))
		end

		if h > 0.869 then
			s = 1 - (0.26 * math.min((h - 0.869) / 0.131, 1))
		end

		return h, s, 1
	end

	function tenacity:TextColor(h, s, v)
		if v >= 0.7 and (s < 0.6 or h > 0.04 and h < 0.56) then
			return Color3.new(0.19, 0.19, 0.19)
		end

		return Color3.new(1, 1, 1)
	end
end

local function getfontbounds(text, size, font)
	fontsize.Text = text
	fontsize.Size = size
	if typeof(font) == 'Font' then
		fontsize.Font = font
	end

	return textService:GetTextBoundsAsync(fontsize)
end

do
	local tenacityAssets = {
		['tenacity/assets/new/add.png'] = 'rbxassetid://121642387707174',
		['tenacity/assets/new/aim.png'] = 'rbxassetid://122207028123421',
		['tenacity/assets/new/allowedicon.png'] = 'rbxassetid://112336790299036',
		['tenacity/assets/new/allowediconmini.png'] = 'rbxassetid://90142384730147',
		['tenacity/assets/new/back.png'] = 'rbxassetid://80523803497740',
		['tenacity/assets/new/backmini.png'] = 'rbxassetid://85859225495272',
		['tenacity/assets/new/bind.png'] = 'rbxassetid://81399857677684',
		['tenacity/assets/new/bindbkg.png'] = 'rbxassetid://101996225428926',
		['tenacity/assets/new/movement.png'] = 'rbxassetid://126929923309265',
		['tenacity/assets/new/blur.png'] = 'rbxassetid://79246816170155',
		['tenacity/assets/new/blurnoti.png'] = 'rbxassetid://124705876663719',
		['tenacity/assets/new/close.png'] = 'rbxassetid://121816018671466',
		['tenacity/assets/new/closemini.png'] = 'rbxassetid://108320409341289',
		['tenacity/assets/new/closetiny.png'] = 'rbxassetid://71393233149714',
		['tenacity/assets/new/colorpreview.png'] = 'rbxassetid://140438628568318',
		['tenacity/assets/new/combat.png'] = 'rbxassetid://94762732349053',
		['tenacity/assets/new/customtheme.png'] = 'rbxassetid://91756736022800',
		['tenacity/assets/new/discord.png'] = 'rbxassetid://99871463341003',
		['tenacity/assets/new/downexpand.png'] = 'rbxassetid://94197751291504',
		['tenacity/assets/new/downexpandslider.png'] = 'rbxassetid://90289944682645',
		['tenacity/assets/new/edit.png'] = 'rbxassetid://105801951237137',
		['tenacity/assets/new/editlarge.png'] = 'rbxassetid://119233876755282',
		['tenacity/assets/new/expandarrow.png'] = 'rbxassetid://86360332526471',
		['tenacity/assets/new/friends.png'] = 'rbxassetid://92957214042038',
		['tenacity/assets/new/player.png'] = 'rbxassetid://93264756888499',
		['tenacity/assets/new/legit_mode_icon.png'] = 'rbxassetid://102858626075156',
		['tenacity/assets/new/legit_switch.png'] = 'rbxassetid://127508881124779',
		['tenacity/assets/new/min.png'] = 'rbxassetid://82175054487146',
		['tenacity/assets/new/noti_alert.png'] = 'rbxassetid://82356478726846',
		['tenacity/assets/new/noti_info.png'] = 'rbxassetid://102614825645099',
		['tenacity/assets/new/noti_warning.png'] = 'rbxassetid://119631730212167',
		['tenacity/assets/new/notification.png'] = 'rbxassetid://90300780458781',
		['tenacity/assets/new/npcs.png'] = 'rbxassetid://104434365485227',
		['tenacity/assets/new/overlaydots.png'] = 'rbxassetid://78012624671930',
		['tenacity/assets/new/overlays.png'] = 'rbxassetid://136535637407545',
		['tenacity/assets/new/overlayslarge.png'] = 'rbxassetid://127574141208160',
		['tenacity/assets/new/pin.png'] = 'rbxassetid://92459145800579',
		['tenacity/assets/new/players.png'] = 'rbxassetid://105137446428129',
		['tenacity/assets/new/profiles.png'] = 'rbxassetid://126051451865127',
		['tenacity/assets/new/radar.png'] = 'rbxassetid://97983828696086',
		['tenacity/assets/new/rainbow_1.png'] = 'rbxassetid://101329996188554',
		['tenacity/assets/new/rainbow_2.png'] = 'rbxassetid://72739074644654',
		['tenacity/assets/new/rainbow_3.png'] = 'rbxassetid://100716555253397',
		['tenacity/assets/new/rainbow_4.png'] = 'rbxassetid://133424174227092',
		['tenacity/assets/new/range.png'] = 'rbxassetid://107794917650053',
		['tenacity/assets/new/rangeindicator.png'] = 'rbxassetid://107038094175283',
		['tenacity/assets/new/render.png'] = 'rbxassetid://125472576898654',
		['tenacity/assets/new/search.png'] = 'rbxassetid://115611852955611',
		['tenacity/assets/new/settingdots.png'] = 'rbxassetid://130896840048276',
		['tenacity/assets/new/settings.png'] = 'rbxassetid://73820177347303',
		['tenacity/assets/new/settingsmini.png'] = 'rbxassetid://115732118290997',
		['tenacity/assets/new/targetinfo.png'] = 'rbxassetid://121604266095276',
		['tenacity/assets/new/textgui.png'] = 'rbxassetid://99438663817412',
		['tenacity/assets/new/theme.png'] = 'rbxassetid://111525258317113',
		['tenacity/assets/new/misc.png'] = 'rbxassetid://108303206513893',
		['tenacity/assets/new/exploit.png'] = 'rbxassetid://118917453153459'
	}

	local function createDownloader(text)
		if tenacity.Loaded ~= true then
			local downloader = tenacity.Downloader
			if not downloader then
				downloader = Instance.new('TextLabel')
				downloader.BackgroundTransparency = 1
				downloader.FontFace = uipallet.Font
				downloader.Size = UDim2.new(1, 0, 0, 40)
				downloader.TextColor3 = Color3.new(1, 1, 1)
				downloader.TextSize = 20
				downloader.TextStrokeTransparency = 0
				downloader.Parent = tenacity.gui
				tenacity.Downloader = downloader
			end

			downloader.Text = 'Downloading '..text
		end
	end

	local function downloadFile(path, callback)
	if shared.TenacityRuntime then return shared.TenacityRuntime.Read(path, callback) end
		if not isfile(path) then
			createDownloader(path)

			local success, data = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/expectedbadthings/TenacityForRoblox/'..readfile('tenacity/profiles/commit.txt')..'/'..select(1, path:gsub('tenacity/', '')), true)
			end)

			if not success or data == '404: Not Found' then
				error(data)
			end

			if path:find('.lua') then
				data = '--Tenacity cached source file.\n'..data
			end

			writefile(path, data)
		end

		return (callback or readfile)(path)
	end

	-- Prefer the built-in Roblox asset ids. The old desktop path synchronously
	-- touched/downloaded local files even when the exact icon already had an
	-- rbxassetid mapping, which caused a very noticeable hitch during injection.
	-- Unknown/custom assets still fall back to getcustomasset, but only once.
	local resolvedAssetCache = {}
	gettenacityasset = function(path)
		local cached = resolvedAssetCache[path]
		if cached then return cached end

		local mapped = tenacityAssets[path]
		if mapped then
			resolvedAssetCache[path] = mapped
			return mapped
		end

		local resolved = ''
		if getcustomasset then
			resolved = downloadFile(path, getcustomasset)
		end
		resolvedAssetCache[path] = resolved
		return resolved
	end
end

local tween = {tweens = {}}

-- Replace per-object motion safely, including rapid cancellation/reversal.
function tween:Tween(obj, info, goal, group)
	group = group or 'tweens'
	self[group] = self[group] or {}
	local active = self[group]
	local previous = active[obj]
	if previous then
		active[obj] = nil
		previous:Cancel()
	end
	local visible = obj.Parent ~= nil
	local ancestor = obj
	while visible and ancestor do
		if ancestor:IsA('GuiObject') and not ancestor.Visible then visible = false end
		if ancestor:IsA('ScreenGui') and not ancestor.Enabled then visible = false end
		ancestor = ancestor.Parent
	end
	if not visible or (tenacity.ReducedMotion and tenacity.ReducedMotion.Enabled) then
		for prop, value in goal do obj[prop] = value end
		return
	end
	local motion = tweenService:Create(obj, info, goal)
	active[obj] = motion
	motion.Completed:Once(function()
		if active[obj] == motion then active[obj] = nil end
	end)
	motion:Play()
	return motion
end
function tween:Cancel(obj, group)
	local active = self[group or 'tweens']
	if active and active[obj] then
		local motion = active[obj]
		active[obj] = nil
		motion:Cancel()
	end
end
function tween:CancelAll()
	for _, active in pairs(self) do
		if type(active) == 'table' then
			for obj, motion in pairs(active) do active[obj] = nil; motion:Cancel() end
		end
	end
end
uipallet = {
	Main = Color3.fromRGB(25, 25, 25),
	MainColor = Color3.fromRGB(12, 163, 232),
	SecondaryColor = Color3.fromRGB(12, 232, 199),
	Text = Color3.new(1, 1, 1),
	Font = Font.fromEnum(Enum.Font.Arial),
	FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold),
	Tween = TweenInfo.new(0.16, Enum.EasingStyle.Linear),
	Themes = {
		['Legacy Green'] = {{Color3.fromRGB(5, 166, 126), Color3.fromRGB(5, 166, 126)}, 4, 6},
		Aubergine = {{Color3.fromRGB(170, 7, 107), Color3.fromRGB(97, 4, 95)}, 1, 8},
		Aqua = {{Color3.fromRGB(185, 250, 255), Color3.fromRGB(79, 199, 200)}, 6},
		Banana = {{Color3.fromRGB(253, 236, 177), Color3.fromRGB(255, 255, 255)}, 3},
		Blend = {{Color3.fromRGB(71, 148, 253), Color3.fromRGB(71, 253, 160)}, 4, 6},
		Blossom = {{Color3.fromRGB(226, 208, 249), Color3.fromRGB(49, 119, 115)}, 9, 10},
		Bubblegum = {{Color3.fromRGB(243, 145, 216), Color3.fromRGB(152, 165, 243)}, 8, 9},
		['Candy Cane'] = {{Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 255, 255)}, 1},
		Cherry = {{Color3.fromRGB(187, 55, 125), Color3.fromRGB(251, 211, 233)}, 1, 8, 9},
		Christmas = {{Color3.fromRGB(255, 64, 64), Color3.fromRGB(255, 255, 255), Color3.fromRGB(64, 255, 64)}, 1, 4},
		Coral = {{Color3.fromRGB(244, 168, 150), Color3.fromRGB(52, 133, 151)}, 2, 7, 9},
		Creida = {{Color3.fromRGB(156, 164, 224), Color3.fromRGB(54, 57, 78)}, 10},
		['Creida Two'] = {{Color3.fromRGB(154, 202, 235), Color3.fromRGB(88, 130, 161)}, 10},
		['Digital Horizon'] = {{Color3.fromRGB(95, 195, 228), Color3.fromRGB(229, 93, 135)}, 1, 6, 9},
		Express = {{Color3.fromRGB(173, 83, 137), Color3.fromRGB(60, 16, 83)}, 8, 9},
		Gothic = {{Color3.fromRGB(31, 30, 30), Color3.fromRGB(196, 190, 190)}, 10},
		Halogen = {{Color3.fromRGB(255, 65, 108), Color3.fromRGB(255, 75, 43)}, 1, 2},
		Hyper = {{Color3.fromRGB(236, 110, 173), Color3.fromRGB(52, 148, 230)}, 6, 7, 9},
		Legacy = {{Color3.fromRGB(112, 206, 255), Color3.fromRGB(112, 206, 255)}, 6, 7},
		['Lime Water'] = {{Color3.fromRGB(18, 255, 247), Color3.fromRGB(179, 255, 171)}, 4, 6},
		Lush = {{Color3.fromRGB(168, 224, 99), Color3.fromRGB(86, 171, 47)}, 4, 5},
		Magic = {{Color3.fromRGB(74, 0, 224), Color3.fromRGB(142, 45, 226)}, 7, 8},
		May = {{Color3.fromRGB(170, 7, 107), Color3.fromRGB(238, 79, 238)}, 8, 9},
		['Orange Juice'] = {{Color3.fromRGB(252, 74, 26), Color3.fromRGB(247, 183, 51)}, 2, 3},
		Pastel = {{Color3.fromRGB(243, 155, 178), Color3.fromRGB(207, 196, 243)}, 9},
		Peony = {{Color3.fromRGB(226, 208, 249), Color3.fromRGB(207, 171, 255)}, 9, 10},
		Pumpkin = {{Color3.fromRGB(241, 166, 98), Color3.fromRGB(255, 216, 169), Color3.fromRGB(227, 139, 42)}, 2},
		Purple = {{Color3.fromRGB(82, 67, 145), Color3.fromRGB(117, 95, 207)}, 8},
		Rainbow = {{Color3.new(1, 1, 1), Color3.new(1, 1, 1)}, 10},
		Rue = {{Color3.fromRGB(234, 118, 176), Color3.fromRGB(31, 30, 30)}, 9},
		Satin = {{Color3.fromRGB(215, 60, 67), Color3.fromRGB(140, 23, 39)}, 1},
		Shadow = {{Color3.fromRGB(97, 131, 255), Color3.fromRGB(206, 212, 255)}, 6},
		['Snowy Sky'] = {{Color3.fromRGB(1, 171, 179), Color3.fromRGB(234, 234, 234), Color3.fromRGB(18, 232, 232)}, 6, 10},
		['Steel Fade'] = {{Color3.fromRGB(66, 134, 244), Color3.fromRGB(55, 59, 68)}, 7, 10},
		Sundae = {{Color3.fromRGB(206, 74, 126), Color3.fromRGB(122, 44, 77)}, 1, 8, 9},
		Sunkist = {{Color3.fromRGB(242, 201, 76), Color3.fromRGB(242, 153, 74)}, 2, 3},
		Water = {{Color3.fromRGB(12, 232, 199), Color3.fromRGB(12, 163, 232)}, 6, 7},
		Winter = {{Color3.new(1, 1, 1), Color3.new(1, 1, 1)}, 10},
		Wood = {{Color3.fromRGB(79, 109, 81), Color3.fromRGB(170, 139, 87), Color3.fromRGB(240, 235, 206)}, 5}
	},
	ThemeObjects = {},
	ThemeSolidObjects = setmetatable({}, {__mode = 'k'}),
	-- Enabled module rows use one shared screen-space theme packet instead of
	-- owning individual UIGradients. Each row samples the same animated field.
	ModuleThemeObjects = setmetatable({}, {__mode = 'k'})
}

-- Palettes transcribed from Tenacity utils/render/Theme.java.
for name, theme in {
		['Spearmint'] = {{Color3.fromRGB(97, 194, 162), Color3.fromRGB(65, 130, 108)}, 9},
		['Jade Green'] = {{Color3.fromRGB(0, 168, 107), Color3.fromRGB(0, 105, 66)}, 9},
		['Green Spirit'] = {{Color3.fromRGB(0, 135, 62), Color3.fromRGB(159, 226, 191)}, 9},
		['Rosy Pink'] = {{Color3.fromRGB(255, 102, 204), Color3.fromRGB(191, 77, 153)}, 9},
		['Magenta'] = {{Color3.fromRGB(213, 63, 119), Color3.fromRGB(157, 68, 110)}, 9},
		['Hot Pink'] = {{Color3.fromRGB(231, 84, 128), Color3.fromRGB(172, 79, 198)}, 9},
		['Lavender'] = {{Color3.fromRGB(219, 166, 247), Color3.fromRGB(152, 115, 172)}, 9},
		['Amethyst'] = {{Color3.fromRGB(144, 99, 205), Color3.fromRGB(98, 67, 140)}, 9},
		['Purple Fire'] = {{Color3.fromRGB(104, 71, 141), Color3.fromRGB(177, 162, 202)}, 9},
		['Sunset Pink'] = {{Color3.fromRGB(255, 145, 20), Color3.fromRGB(245, 105, 231)}, 9},
		['Blaze Orange'] = {{Color3.fromRGB(255, 169, 77), Color3.fromRGB(255, 130, 0)}, 9},
		['Pink Blood'] = {{Color3.fromRGB(228, 0, 70), Color3.fromRGB(255, 166, 201)}, 9},
		['Pastel'] = {{Color3.fromRGB(255, 109, 106), Color3.fromRGB(191, 82, 80)}, 9},
		['Neon Red'] = {{Color3.fromRGB(210, 39, 48), Color3.fromRGB(184, 25, 42)}, 9},
		['Deep Ocean'] = {{Color3.fromRGB(60, 82, 145), Color3.fromRGB(0, 20, 64)}, 9},
		['Chambray Blue'] = {{Color3.fromRGB(33, 46, 182), Color3.fromRGB(60, 82, 145)}, 9},
		['Mint Blue'] = {{Color3.fromRGB(66, 158, 157), Color3.fromRGB(40, 94, 93)}, 9},
		['Pacific Blue'] = {{Color3.fromRGB(5, 169, 199), Color3.fromRGB(4, 115, 135)}, 9},
		['Tropical Ice'] = {{Color3.fromRGB(102, 255, 209), Color3.fromRGB(6, 149, 255)}, 9},
		Tenacity = {{Color3.fromRGB(236, 133, 209), Color3.fromRGB(28, 167, 222)}, 9},
		['Red Coffee'] = {{Color3.new(0, 0, 0), Color3.fromRGB(225, 34, 59)}, 1},
} do uipallet.Themes[name] = theme end

local themecolors = {
	Color3.fromRGB(248, 57, 57),
	Color3.fromRGB(250, 128, 55),
	Color3.fromRGB(252, 255, 53),
	Color3.fromRGB(128, 255, 50),
	Color3.fromRGB(50, 128, 50),
	Color3.fromRGB(50, 200, 255),
	Color3.fromRGB(50, 105, 200),
	Color3.fromRGB(128, 52, 255),
	Color3.fromRGB(255, 128, 255),
	Color3.fromRGB(100, 100, 110)
}

local themeNames = {'Tenacity', 'Spearmint', 'Jade Green', 'Green Spirit', 'Rosy Pink', 'Magenta', 'Hot Pink', 'Lavender', 'Amethyst', 'Purple Fire', 'Sunset Pink', 'Blaze Orange', 'Pink Blood', 'Pastel', 'Neon Red', 'Red Coffee', 'Deep Ocean', 'Chambray Blue', 'Mint Blue', 'Pacific Blue', 'Tropical Ice'}

do
	local data = isfile('tenacity/profiles/color.txt') and loadJson('tenacity/profiles/color.txt')
	if data then
		uipallet.Main = data.Main and Color3.fromRGB(unpack(data.Main)) or uipallet.Main
		uipallet.Text = data.Text and Color3.fromRGB(unpack(data.Text)) or uipallet.Text
		uipallet.Font = data.Font and Font.new(
			data.Font:find('rbxasset') and data.Font
			or string.format('rbxasset://fonts/families/%s.json', data.Font)
		) or uipallet.Font
		uipallet.FontSemiBold = Font.new(uipallet.Font.Family, Enum.FontWeight.SemiBold)
	end

	fontsize.Font = uipallet.Font
end

-- Animated named gradient themes ------------------------------------------------
-- GUI accents are theme-only now. The legacy HSV GUI color remains only as a
-- compatibility shim for external modules; it is no longer user-facing.
tenacity.ActiveThemeName = 'Tenacity'
tenacity.ThemePhase = 0

local function getThemePalette(name)
	local theme = uipallet.Themes[name]
	if not theme then return nil end

	-- The supplied Rainbow preset uses white placeholders. Expand it using the
	-- supplied theme color wheel so Rainbow is actually multicolor.
	if name == 'Rainbow' then
		local rainbow = {}
		for index = 1, 9 do
			table.insert(rainbow, themecolors[index])
		end
		return rainbow
	end

	return theme[1]
end

local function sampleThemeColor(colors, alpha)
	if not colors or #colors == 0 then
		return Color3.fromRGB(12, 163, 232)
	end
	if #colors == 1 then
		return colors[1]
	end

	alpha = alpha % 1
	local scaled = alpha * #colors
	local base = math.floor(scaled)
	local first = (base % #colors) + 1
	local second = (first % #colors) + 1
	local blend = scaled - base

	-- Cosine easing makes each palette transition melt into the next instead of
	-- looking like a linear RGB conveyor belt. The palette still wraps perfectly.
	blend = (1 - math.cos(blend * math.pi)) * 0.5
	return colors[first]:Lerp(colors[second], blend)
end

function tenacity:IsGradientThemeActive()
	local name = self.ActiveThemeName or (self.GradientTheme and self.GradientTheme.Value) or 'Tenacity'
	return uipallet.Themes[name] ~= nil
end

function tenacity:GetThemeColors(name)
	return getThemePalette(name or self.ActiveThemeName or (self.GradientTheme and self.GradientTheme.Value) or 'Tenacity')
end

function tenacity:GetThemeColor(offset)
	local colors = self:GetThemeColors()
	if not colors then
		return Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value)
	end
	return sampleThemeColor(colors, (self.ThemePhase or 0) + (offset or 0))
end

function tenacity:GetThemeSequence(offset, phase)
	local colors = self:GetThemeColors()
	if not colors then
		return ColorSequence.new(Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value))
	end

	if self.ActiveThemeName == 'Tenacity' then return ColorSequence.new(colors[1]) end

	-- More samples = a genuinely smooth travelling gradient. Animation happens by
	-- moving the sampled palette through a stationary UIGradient, not by spinning it.
	local steps = math.clamp(#colors * 4, 10, 18)
	local keypoints = {}
	local flow = phase == nil and (self.ThemePhase or 0) or phase
	for index = 0, steps do
		local position = index / steps
		table.insert(keypoints, ColorSequenceKeypoint.new(
			position,
			sampleThemeColor(colors, position + flow + (offset or 0))
		))
	end
	return ColorSequence.new(keypoints)
end

function tenacity:RegisterThemeGradient(gradient, offset, rotation)
	if typeof(gradient) ~= 'Instance' or not gradient:IsA('UIGradient') then return nil end
	if not self:IsGradientThemeActive() then
		gradient.Enabled = false
		uipallet.ThemeObjects[gradient] = nil
		return gradient
	end

	local metadata = uipallet.ThemeObjects[gradient]
	if type(metadata) ~= 'table' then
		metadata = {}
		uipallet.ThemeObjects[gradient] = metadata
	end

	local newOffset = offset or metadata.Offset or 0
	local newRotation = rotation or metadata.Rotation or gradient.Rotation or 0
	local themeName = self.ActiveThemeName or (self.GradientTheme and self.GradientTheme.Value) or 'Tenacity'
	local refresh = metadata.Theme ~= themeName or metadata.Offset ~= newOffset

	metadata.Offset = newOffset
	metadata.Rotation = newRotation
	metadata.Theme = themeName

	gradient.Enabled = true
	gradient.Rotation = newRotation
	gradient.Offset = Vector2.zero
	if refresh then
		gradient.Color = self:GetThemeSequence(newOffset, self.ThemePhase or 0)
	end
	return gradient
end

function tenacity:UnregisterThemeGradient(gradient)
	if typeof(gradient) == 'Instance' and gradient:IsA('UIGradient') then
		gradient.Enabled = false
		gradient.Offset = Vector2.zero
	end
	uipallet.ThemeObjects[gradient] = nil
end

function tenacity:ApplyThemeGradient(object, property, offset, enabled, rotation)
	if typeof(object) ~= 'Instance' or not object:IsA('GuiObject') then return false end
	local gradient = object:FindFirstChild('AnimatedThemeGradient')
	local active = enabled ~= false and self:IsGradientThemeActive()

	if not active then
		if gradient then self:UnregisterThemeGradient(gradient) end
		return false
	end

	if not gradient then
		gradient = Instance.new('UIGradient')
		gradient.Name = 'AnimatedThemeGradient'
		gradient.Parent = object
	end

	property = property or 'BackgroundColor3'
	pcall(function()
		object[property] = Color3.new(1, 1, 1)
	end)
	self:RegisterThemeGradient(gradient, offset or 0, rotation or 0)
	return true
end


-- Some controls need only one property themed (for example a UIStroke, icon or
-- text label on a neutral surface). These get a continuously animated sampled
-- theme color without tinting the rest of the object.
function tenacity:RegisterThemeSolid(object, property, offset)
	if typeof(object) ~= 'Instance' then return object end
	property = property or (object:IsA('UIStroke') and 'Color' or 'BackgroundColor3')
	uipallet.ThemeSolidObjects[object] = {Property = property, Offset = offset or 0}
	pcall(function() object[property] = self:GetThemeColor(offset or 0) end)
	return object
end

function tenacity:UnregisterThemeSolid(object)
	uipallet.ThemeSolidObjects[object] = nil
end

-- Shared module theme packet ---------------------------------------------------
-- Roblox UIGradient is local to each GuiObject, so giving every module row its
-- own gradient makes the same theme restart inside every 40px button. That reads
-- like a bevel/3D shine. Modules instead sample one diagonal screen-space color
-- field. Every enabled row is flat on its own, but all rows together form one
-- continuous animated theme across the whole screen.
function tenacity:GetModuleThemePacketColor(object)
	local colors = self:GetThemeColors()
	if not colors then return uipallet.MainColor end

	local screenSize = scaledgui and scaledgui.AbsoluteSize or Vector2.new(1920, 1080)
	local sizeX = math.max(screenSize.X, 1)
	local sizeY = math.max(screenSize.Y, 1)
	local position = object and object.AbsolutePosition or Vector2.zero
	local objectSize = object and object.AbsoluteSize or Vector2.zero
	local centerX = position.X + (objectSize.X * 0.5)
	local centerY = position.Y + (objectSize.Y * 0.5)
	local normalizedX = math.clamp(centerX / sizeX, 0, 1)
	local normalizedY = math.clamp(centerY / sizeY, 0, 1)

	-- One top-left -> bottom-right field. Keep the span below a full palette loop
	-- so opposite corners do not wrap back to the exact same color.
	local diagonal = ((normalizedX + normalizedY) * 0.5) * 0.72
	return sampleThemeColor(colors, (self.ThemePhase or 0) + diagonal)
end

function tenacity:RegisterModuleThemeObject(object)
	if typeof(object) ~= 'Instance' or not object:IsA('GuiObject') then return object end
	uipallet.ModuleThemeObjects[object] = true
	object.BackgroundColor3 = self:GetModuleThemePacketColor(object)
	return object
end

function tenacity:UnregisterModuleThemeObject(object)
	uipallet.ModuleThemeObjects[object] = nil
end

function tenacity:UpdateModuleThemePacket()
	for object in uipallet.ModuleThemeObjects do
		if not object or not object.Parent then
			uipallet.ModuleThemeObjects[object] = nil
		else
			object.BackgroundColor3 = self:GetModuleThemePacketColor(object)
		end
	end
end

function tenacity:ClearThemeGradients()
	for gradient in uipallet.ThemeObjects do
		if gradient and gradient.Parent then
			gradient.Enabled = false
			gradient.Offset = Vector2.zero
		end
	end
	table.clear(uipallet.ThemeObjects)
end

function tenacity:UpdateThemeGradients()
	if not self:IsGradientThemeActive() then return end
	local phase = self.ThemePhase or 0
	local themeName = self.ActiveThemeName or (self.GradientTheme and self.GradientTheme.Value) or 'Tenacity'
	for gradient, metadata in uipallet.ThemeObjects do
		if not gradient or not gradient.Parent then
			uipallet.ThemeObjects[gradient] = nil
		else
			local offset = type(metadata) == 'table' and (metadata.Offset or 0) or 0
			local baseRotation = type(metadata) == 'table' and (metadata.Rotation or 0) or 0
			if type(metadata) == 'table' then
				metadata.Theme = themeName
			end

			-- Keep geometry completely stable. Only the colors travel through it.
			gradient.Rotation = baseRotation
			gradient.Offset = Vector2.zero
			gradient.Color = self:GetThemeSequence(offset, phase)
		end
	end

	for object, metadata in uipallet.ThemeSolidObjects do
		if not object or not object.Parent then
			uipallet.ThemeSolidObjects[object] = nil
		else
			pcall(function()
				object[metadata.Property] = self:GetThemeColor(metadata.Offset or 0)
			end)
		end
	end

	self:UpdateModuleThemePacket()
end
-- Animated named gradient themes end --------------------------------------------

tenacity.Libraries = {
	color = color,
	getfontbounds = getfontbounds,
	gettenacityasset = gettenacityasset,
	tween = tween,
	uipallet = uipallet,
}


-- Universal HUD compatibility ----------------------------------------------
-- universal.lua expects these helpers to exist on the main Tenacity table.
-- Keep them in the GUI itself so every game/universal module sees them.
tenacity.HUDAccentObjects = setmetatable({}, {__mode = 'k'})

function tenacity:GetGUIColorRGB()
	return self:GetThemeColor(0)
end

function tenacity:RegisterHUDAccent(object, property)
	if typeof(object) ~= 'Instance' then
		return object
	end

	if not property then
		if object:IsA('UIStroke') then
			property = 'Color'
		elseif object:IsA('ImageLabel') or object:IsA('ImageButton') then
			property = 'ImageColor3'
		elseif object:IsA('TextLabel') or object:IsA('TextButton') then
			property = 'TextColor3'
		else
			property = 'BackgroundColor3'
		end
	end

	self.HUDAccentObjects[object] = property

	pcall(function()
		object[property] = self:GetGUIColorRGB()
	end)
	if not object:IsA('GuiObject') then
		self:RegisterThemeSolid(object, property, 0)
	end

	object.Destroying:Once(function()
		if self.HUDAccentObjects then
			self.HUDAccentObjects[object] = nil
		end
	end)

	return object
end

function tenacity:StyleHUDCard(object)
	if typeof(object) ~= 'Instance' or not object:IsA('GuiObject') then
		return object
	end

	-- Match the ClickGUI surface without overwriting the caller's opacity.
	object.BorderSizePixel = 0
	object.BackgroundColor3 = uipallet.Main

	local cardCorner = object:FindFirstChild('HUDCardCorner')
		or object:FindFirstChildWhichIsA('UICorner')

	if not cardCorner then
		cardCorner = Instance.new('UICorner')
		cardCorner.Name = 'HUDCardCorner'
		cardCorner.CornerRadius = UDim.new(0, 6)
		cardCorner.Parent = object
	end

	local cardStroke = object:FindFirstChild('HUDCardStroke')
	if not cardStroke then
		cardStroke = Instance.new('UIStroke')
		cardStroke.Name = 'HUDCardStroke'
		cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		cardStroke.Color = color.Light(uipallet.Main, 0.08)
		cardStroke.Transparency = 0.42
		cardStroke.Thickness = 1
		cardStroke.Parent = object
	end

	-- Small accent edge; deliberately subtle so widgets still retain their
	-- own layout/content while visually belonging to this GUI.
	local accentEdge = object:FindFirstChild('HUDAccentEdge')
	if not accentEdge then
		accentEdge = Instance.new('Frame')
		accentEdge.Name = 'HUDAccentEdge'
		accentEdge.AnchorPoint = Vector2.new(0, 0.5)
		accentEdge.BackgroundColor3 = self:GetGUIColorRGB()
		accentEdge.BorderSizePixel = 0
		accentEdge.Position = UDim2.new(0, 0, 0.5, 0)
		accentEdge.Size = UDim2.new(0, 2, 1, -12)
		accentEdge.ZIndex = math.max(object.ZIndex + 1, 2)
		accentEdge.Parent = object

		local edgeCorner = Instance.new('UICorner')
		edgeCorner.CornerRadius = UDim.new(1, 0)
		edgeCorner.Parent = accentEdge

		self:RegisterHUDAccent(accentEdge, 'BackgroundColor3')
	end

	return object
end
-- Universal HUD compatibility end ------------------------------------------

local function addBlur(parent, notif, old)
	local blur
	if old then
		blur = Instance.new('ImageLabel')
		blur.Name = 'Blur'
		blur.Size = UDim2.new(1, 89, 1, 52)
		blur.Position = UDim2.fromOffset(-48, -31)
		blur.BackgroundTransparency = 1
		blur.Image = gettenacityasset('tenacity/assets/new/'..(notif and 'blurnoti' or 'blur')..'.png')
		blur.ScaleType = Enum.ScaleType.Slice
		blur.SliceCenter = Rect.new(52, 31, 261, 502)
		blur.Parent = parent
	else
		blur = Instance.new('UIShadow')
		blur.BlurRadius = UDim.new(0, 13)
		blur.Transparency = 0.25
		blur.Parent = parent
	end

	return blur
end

local function addCorner(parent, radius)
	local corner = Instance.new('UICorner')
	corner.CornerRadius = radius or UDim.new(0, 5)
	corner.Parent = parent

	return corner
end

-- GUI style system -------------------------------------------------------------
-- new.lua keeps Tenacity 5.1 as the default presentation while allowing the same
-- live interface to switch to the newer modern styling without reinjection.
tenacity.GUIStyleName = 'Dropdown'
tenacity.GUIStyleObjects = setmetatable({}, {__mode = 'k'})

local function styleCorner(object, radius)
	if not object then return end
	local corner = object:FindFirstChild('ModernStyleCorner') or object:FindFirstChildWhichIsA('UICorner')
	if not corner then
		corner = Instance.new('UICorner')
		corner.Name = 'ModernStyleCorner'
		corner.Parent = object
	end
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

local function styleStroke(object, transparency, thickness, useExisting)
	if not object then return end
	local stroke = object:FindFirstChild('ModernStyleStroke')
	if not stroke and useExisting then stroke = object:FindFirstChildWhichIsA('UIStroke') end
	if not stroke then
		stroke = Instance.new('UIStroke')
		stroke.Name = 'ModernStyleStroke'
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = object
	end
	stroke.Color = color.Light(uipallet.Main, 0.12)
	stroke.Transparency = transparency
	stroke.Thickness = thickness or 1
	return stroke
end

local function styleShadow(object, modern)
	if not object then return end
	local shadow = object:FindFirstChildWhichIsA('UIShadow')
	if shadow then
		shadow.BlurRadius = UDim.new(0, modern and 18 or 13)
		shadow.Transparency = modern and 0.34 or 0.25
	end
end

local function styleAccent(object, modern, y)
	if not object then return end
	local accent = object:FindFirstChild('ModernHeaderAccent')
	if not accent then
		accent = Instance.new('Frame')
		accent.Name = 'ModernHeaderAccent'
		accent.BorderSizePixel = 0
		accent.Position = UDim2.fromOffset(10, y or 37)
		accent.Size = UDim2.new(1, -20, 0, 1)
		accent.ZIndex = math.max(object.ZIndex + 5, 5)
		accent.Parent = object
	end
	accent.Visible = modern
	if modern then
		tenacity:RegisterThemeSolid(accent, 'BackgroundColor3', 0.08)
	else
		tenacity:UnregisterThemeSolid(accent)
	end
end

function tenacity:ApplyGUIStyleObject(object, role)
	if typeof(object) ~= 'Instance' or not object.Parent then return end
	local modern = self.GUIStyleName == 'Modern'

	if role == 'MainWindow' then
		object.BackgroundColor3 = color.Dark(uipallet.Main, modern and 0.012 or 0.02)
		object.BackgroundTransparency = modern and 0.025 or 0
		styleCorner(object, modern and 11 or 5)
		styleStroke(object, modern and 0.62 or 0.8, modern and 1.15 or 1, true)
		styleShadow(object, modern)
		styleAccent(object, modern, 37)
	elseif role == 'CategoryWindow' then
		object.BackgroundColor3 = modern and color.Dark(uipallet.Main, 0.012) or uipallet.Main
		object.BackgroundTransparency = modern and 0.018 or 0
		styleCorner(object, modern and 10 or 5)
		styleStroke(object, modern and 0.65 or 0.8, modern and 1.1 or 1, true)
		styleShadow(object, modern)
		styleAccent(object, modern, 37)
		local outline = object:FindFirstChildWhichIsA('UIStroke')
		if outline then
			outline.Transparency = 0.12
			self:RegisterThemeSolid(outline, 'Color', 0.08)
		end
	elseif role == 'CategoryListWindow' then
		object.BackgroundColor3 = modern and color.Dark(uipallet.Main, 0.012) or uipallet.Main
		object.BackgroundTransparency = modern and 0.018 or 0
		styleCorner(object, modern and 10 or 5)
		styleStroke(object, modern and 0.65 or 0.8, modern and 1.1 or 1, true)
		styleShadow(object, modern)
		styleAccent(object, modern, 41)
	elseif role == 'SearchWindow' then
		object.BackgroundColor3 = color.Dark(uipallet.Main, modern and 0.012 or 0.02)
		object.BackgroundTransparency = modern and 0.025 or 0
		styleCorner(object, modern and 11 or 5)
		styleStroke(object, modern and 0.62 or 0.8, modern and 1.1 or 1, true)
		styleShadow(object, modern)
	elseif role == 'AuxiliaryWindow' then
		object.BackgroundColor3 = modern and color.Dark(uipallet.Main, 0.008) or uipallet.Main
		object.BackgroundTransparency = modern and 0.018 or 0
		styleCorner(object, modern and 12 or 5)
		styleStroke(object, modern and 0.68 or 1, modern and 1.1 or 1, false)
		styleShadow(object, modern)
	elseif role == 'SettingsPane' then
		object.BackgroundTransparency = modern and 0.02 or 0
		styleCorner(object, modern and 10 or 5)
		styleStroke(object, modern and 0.72 or 1, modern and 1.05 or 1, false)
		styleAccent(object, modern, 40)
	elseif role == 'SettingsBody' then
		object.BackgroundColor3 = modern and color.Dark(uipallet.Main, 0.008) or uipallet.Main
		object.BackgroundTransparency = modern and 0.02 or 0
	elseif role == 'ModuleRow' then
		local background = object:FindFirstChild('ThemeBackground')
		if background then styleCorner(background, modern and 6 or 0) end
		local accent = object:FindFirstChild('ModernModuleAccent')
		if not accent then
			accent = Instance.new('Frame')
			accent.Name = 'ModernModuleAccent'
			accent.BorderSizePixel = 0
			accent.Position = UDim2.fromOffset(4, 12)
			accent.Size = UDim2.fromOffset(2, 16)
			accent.ZIndex = object.ZIndex + 4
			accent.Parent = object
			styleCorner(accent, 2)
		end
		accent.Visible = modern
		if modern then
			self:RegisterThemeSolid(accent, 'BackgroundColor3', 0.08)
		else
			self:UnregisterThemeSolid(accent)
		end
	elseif role == 'ControlRow' then
		styleCorner(object, modern and 6 or 0)
		styleStroke(object, modern and 0.9 or 1, 1, false)
	elseif role == 'ControlHolder' then
		styleCorner(object, modern and 7 or 5)
		styleStroke(object, modern and 0.82 or 1, 1, false)
	elseif role == 'ToggleTrack' then
		object.Position = UDim2.new(1, modern and -32 or -30, 0, modern and 8 or 9)
		object.Size = UDim2.fromOffset(modern and 24 or 22, modern and 14 or 12)
		styleStroke(object, modern and 0.76 or 1, 1, false)
		local knob = object:FindFirstChildWhichIsA('Frame')
		if knob then
			knob.Size = UDim2.fromOffset(modern and 10 or 8, modern and 10 or 8)
		end
	elseif role == 'ImageToggleTrack' then
		object.Position = UDim2.new(1, modern and -32 or -30, 0, modern and 13 or 14)
		object.Size = UDim2.fromOffset(modern and 24 or 22, modern and 14 or 12)
		styleStroke(object, modern and 0.76 or 1, 1, false)
		local knob = object:FindFirstChildWhichIsA('Frame')
		if knob then knob.Size = UDim2.fromOffset(modern and 10 or 8, modern and 10 or 8) end
	elseif role == 'SliderTrack' then
		object.Size = UDim2.new(1, -20, 0, modern and 3 or 2)
		styleCorner(object, modern and 2 or 0)
	end
end

function tenacity:RegisterGUIStyleObject(object, role)
	if typeof(object) ~= 'Instance' then return object end
	self.GUIStyleObjects[object] = role
	object.Destroying:Once(function()
		if self.GUIStyleObjects then self.GUIStyleObjects[object] = nil end
	end)
	self:ApplyGUIStyleObject(object, role)
	return object
end

function tenacity:ApplyGUIStyle()
	for object, role in self.GUIStyleObjects do
		if object and object.Parent then
			self:ApplyGUIStyleObject(object, role)
		else
			self.GUIStyleObjects[object] = nil
		end
	end
	self:UpdateGUI()
end
-- GUI style system end ---------------------------------------------------------

-- Shared motion curves for the ClickGUI. Kept short enough to feel responsive,
-- but eased so dropdowns/windows no longer snap between states.
local uiMotionFast = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local uiMotion = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local uiMotionPop = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- Topography removed. GUI background is blur-only.

local function addCloseButton(parent, mini, offset)
	local close = Instance.new('ImageButton')
	close.AutoButtonColor = false
	close.BackgroundColor3 = Color3.new(1, 1, 1)
	close.BackgroundTransparency = 1
	close.Image = gettenacityasset('tenacity/assets/new/'..(mini and 'closemini' or 'close')..'.png')
	close.ImageColor3 = color.Light(uipallet.Text, 0.2)
	close.ImageTransparency = 0.5
	close.Name = 'Close'
	close.Position = offset or (mini and UDim2.new(1, -28, 0, 11) or UDim2.new(1, -35, 0, 9))
	close.Size = mini and UDim2.fromOffset(20, 20) or UDim2.fromOffset(24, 24)
	close.Parent = parent
	addCorner(close, UDim.new(1, 0))

	close.MouseEnter:Connect(function()
		close.ImageTransparency = 0.3
		tween:Tween(close, uipallet.Tween, {
			BackgroundTransparency = 0.6
		})
	end)

	close.MouseLeave:Connect(function()
		close.ImageTransparency = 0.5
		tween:Tween(close, uipallet.Tween, {
			BackgroundTransparency = 1
		})
	end)

	return close
end

local function clampWindowToViewport(object)
	if not object or not object.Parent or not gui or not scale then return end
	pcall(function()
		local currentScale = math.max(scale.Scale, 0.01)
		local viewport = gui.AbsoluteSize / currentScale
		local objectSize = object.AbsoluteSize / currentScale
		local padding = 8
		local maxX = math.max(padding, viewport.X - math.min(objectSize.X, math.max(1, viewport.X - (padding * 2))) - padding)
		local maxY = math.max(padding, viewport.Y - math.min(objectSize.Y, math.max(1, viewport.Y - (padding * 2))) - padding)
		object.Position = UDim2.fromOffset(
			math.clamp(object.Position.X.Offset, padding, maxX),
			math.clamp(object.Position.Y.Offset, padding, maxY)
		)
	end)
end

local function clampAllCategoryWindows()
	for _, category in tenacity.Categories do
		if category.Object and category.Type ~= 'Overlay' then
			clampWindowToViewport(category.Object)
		end
	end
end

local function addDragHandler(gui, window, headerHeight)
	gui.InputBegan:Connect(function(input)
		if window and not window.Visible then return end
		if tenacity.LockLayout and tenacity.LockLayout.Enabled then return end

		if
			(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
			and (input.Position.Y - gui.AbsolutePosition.Y < (headerHeight and headerHeight * gui.AbsoluteSize.Y / math.max(gui.Size.Y.Offset, 1) or 40) or window)
		then
			local dragPosition = Vector2.new(
				gui.AbsolutePosition.X - input.Position.X,
				gui.AbsolutePosition.Y - input.Position.Y + guiService:GetGuiInset().Y
			) / scale.Scale

			local releaseConnection
			local moveConnection = inputService.InputChanged:Connect(function(newInput)
				if tenacity.LockLayout and tenacity.LockLayout.Enabled then return end
				if input.UserInputType == Enum.UserInputType.Touch and newInput ~= input then return end
				if newInput.UserInputType == (input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
					local position = newInput.Position
					if inputService:IsKeyDown(Enum.KeyCode.LeftShift) then
						dragPosition = (dragPosition // 3) * 3
						position = (position // 3) * 3
					end

					gui.Position = UDim2.fromOffset((position.X / scale.Scale) + dragPosition.X, (position.Y / scale.Scale) + dragPosition.Y)
				end
			end)

			releaseConnection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					moveConnection:Disconnect()
					releaseConnection:Disconnect()
					clampWindowToViewport(gui)
				end
			end)
		end
	end)
end

local function addMaid(obj)
	obj.Connections = {}

	function obj:Clean(callback)
		if typeof(callback) == 'Instance' then
			table.insert(self.Connections, {
				Disconnect = function()
					callback:ClearAllChildren()
					callback:Destroy()
				end
			})
		elseif type(callback) == 'thread' then
			table.insert(self.Connections, {
				Disconnect = function()
					if coroutine.status(callback) ~= 'dead' then
						task.cancel(callback)
					end
				end
			})
		elseif type(callback) == 'function' then
			table.insert(self.Connections, {
				Disconnect = callback
			})
		else
			table.insert(self.Connections, callback)
		end
	end
end

local function addTooltip(gui, text, customText, visCheck)
	if not text then return end

	local function tooltipMoved(x, y)
		if visCheck and visCheck() then
			return
		end

		local isRight = x + 16 + tooltip.Size.X.Offset > (scale.Scale * 1920)
		tooltip.Position = UDim2.fromOffset(
			(isRight and x - (tooltip.Size.X.Offset * scale.Scale) - 16 or x + 16) / scale.Scale,
			((y + 11) - (tooltip.Size.Y.Offset / 2)) / scale.Scale
		)

		tooltip.Visible = toolblur.Enabled
	end

	local function callback()
		local newText = customText()
		tooltip.Text = newText
		local tooltipSize = getfontbounds(tooltip.ContentText, tooltip.TextSize, uipallet.Font)
		tooltip.Size = UDim2.fromOffset(tooltipSize.X + 10, tooltipSize.Y + 10)
	end

	gui.MouseEnter:Connect(function(x, y)
		if visCheck and visCheck() then
			return
		end

		tooltip.Text = text
		local tooltipSize = getfontbounds(tooltip.ContentText, tooltip.TextSize, uipallet.Font)
		tooltip.Size = UDim2.fromOffset(tooltipSize.X + 10, tooltipSize.Y + 10)
		tooltipMoved(x, y)

		if customText then
			tenacity.CurrentTooltip = callback
			callback()
		end
	end)
	gui.MouseMoved:Connect(tooltipMoved)
	gui.MouseLeave:Connect(function()
		if visCheck and visCheck() then
			return
		end

		tooltip.Visible = false
		tenacity.CurrentTooltip = nil
	end)
end

local function createSignal()
	local signal = {
		Connections = {}
	}

	function signal:Connect(callback)
		table.insert(self.Connections, callback)

		return {
			Disconnect = function()
				local index = table.find(signal.Connections, callback)
				if index then
					table.remove(signal.Connections, index)
				end
			end
		}
	end

	function signal:Fire(...)
		for _, callback in self.Connections do
			task.spawn(callback, ...)
		end
	end

	return signal
end

local function checkKeybinds(compare, target, key)
	if type(target) == 'table' then
		if table.find(target, key) then
			for _, key in target do
				if not table.find(compare, key) then
					return false
				end
			end

			return true
		end
	end

	return false
end

local function getTableSize(dict)
	local size = 0
	for _ in dict do
		size += 1
	end

	return size
end

local function randomString()
	local array = {}
	for i = 1, math.random(10, 100) do
		array[i] = string.char(math.random(32, 126))
	end

	return table.concat(array)
end

local function removeTags(text)
	text = text:gsub('<br%s*/>', '\n')
	return text:gsub('<[^<>]->', '')
end

local guiBlurEffect
local guiBlurTween

function tenacity:BlurCheck()
	if self.Loaded == nil then
		if guiBlurTween then
			guiBlurTween:Cancel()
			guiBlurTween = nil
		end

		if guiBlurEffect then
			pcall(function()
				guiBlurEffect.Enabled = false
				guiBlurEffect.Size = 0
				guiBlurEffect:Destroy()
			end)
			guiBlurEffect = nil
		end

		return
	end

	local clickVisible = clickgui and clickgui.Visible
	local auxiliaryVisible = self.Auxiliary and self.Auxiliary.Window and self.Auxiliary.Window.Visible
	local shouldBlur = self.Blur and self.Blur.Enabled and (clickVisible or auxiliaryVisible)

	if not guiBlurEffect or not guiBlurEffect.Parent then
		guiBlurEffect = Instance.new('BlurEffect')
		guiBlurEffect.Name = 'TenacityGUIBlur'
		guiBlurEffect.Enabled = false
		guiBlurEffect.Size = 0
		guiBlurEffect.Parent = lightingService
	end

	if guiBlurTween then
		guiBlurTween:Cancel()
		guiBlurTween = nil
	end

	if shouldBlur then
		guiBlurEffect.Enabled = true
		guiBlurTween = tweenService:Create(
			guiBlurEffect,
			TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{Size = 16}
		)
		guiBlurTween:Play()
	else
		if not guiBlurEffect.Enabled then
			guiBlurEffect.Size = 0
			return
		end

		guiBlurTween = tweenService:Create(
			guiBlurEffect,
			TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{Size = 0}
		)
		guiBlurTween:Play()

		task.delay(0.13, function()
			if guiBlurEffect and guiBlurEffect.Parent and guiBlurEffect.Size <= 0.05 then
				guiBlurEffect.Enabled = false
			end
		end)
	end
end

function tenacity:CreateCategory(props)
	return components.Category(props)
end

function tenacity:CreateCategoryList(props)
	return components.CategoryList(props)
end

-- Session actions keep their own state; they never enter saved module options.
function tenacity:BulkDisable()
	if not self.Loaded or self.SwitchingProfile then return end
	local snapshot = {Profile = self.Profile, Modules = {}}
	local failed = 0
	for name, module in self.Modules do
		if module.Enabled then
			local ok = pcall(module.Toggle, module, true)
			if not module.Enabled then snapshot.Modules[name] = module end
			if not ok or module.Enabled then failed += 1 end
		end
	end
	local count = getTableSize(snapshot.Modules)
	if count > 0 then self.BulkUndo = snapshot end
	self:CreateNotification('Modules', count..' disabled. Undo is available in General.'..(failed > 0 and (' '..failed..' failed.') or ''), 4, failed > 0 and 'warning' or 'info')
end

function tenacity:UndoBulkDisable()
	local snapshot = self.BulkUndo
	if not self.Loaded or self.SwitchingProfile then return end
	if not snapshot or snapshot.Profile ~= self.Profile then
		self:CreateNotification('Modules', 'Nothing to undo in this profile.', 3)
		return
	end
	local restored, failed = 0, 0
	for name, original in snapshot.Modules do
		local module = self.Modules[name]
		if module ~= original or module.Enabled then
			snapshot.Modules[name] = nil
		elseif module.Bind and module.Bind.Hold then
			-- A hold binding must be activated by physically holding its key.
			snapshot.Modules[name] = nil
		else
			local ok = pcall(module.Toggle, module, true)
			if ok and module.Enabled then
				restored += 1
				snapshot.Modules[name] = nil
			else
				failed += 1
			end
		end
	end
	if not next(snapshot.Modules) then self.BulkUndo = nil end
	self:CreateNotification('Modules', restored..' restored.'..(failed > 0 and (' '..failed..' failed; undo can retry.') or ''), 3, failed > 0 and 'warning' or 'info')
end

function tenacity:SwitchProfile(name)
	if not self.Loaded or self.SwitchingProfile or name == self.Profile then return false end
	if type(name) ~= 'string' or not self.Categories.Profiles:GetValue(name) then return false end
	local path = 'tenacity/profiles/'..name..self.Place..'.txt'
	local target = isfile(path) and loadJson(path) or nil
	if isfile(path) and (not target or type(target.Modules) ~= 'table' or type(target.Categories) ~= 'table') then
		self:CreateNotification('Profiles', 'Cannot switch: target profile is invalid.', 5, 'alert')
		return false
	end
	local previous = self.Profile
	self.SwitchingProfile = true
	self.ProfileSwitchThread = coroutine.running()
	local saved, err = pcall(self.Save, self)
	if not saved then
		self.SwitchingProfile = false
		self.ProfileSwitchThread = nil
		self:CreateNotification('Profiles', 'Current profile could not be saved: '..tostring(err), 5, 'alert')
		return false
	end
	local ok, failure = pcall(function()
		if not target then
			-- Newly added profiles start as a copy of the current setup.
			self.Profile = name
			self:Save()
		else
			if type(target.Auxiliary) == 'table' then
				for moduleName, data in target.Auxiliary do
					if target.Modules[moduleName] == nil then target.Modules[moduleName] = data end
				end
			end
			for moduleName, module in self.Modules do
				if module.Enabled and not target.Modules[moduleName] then module:Toggle(true) end
			end
		end
		self:Load(true, name)
		assert(self.Loaded and self.Profile == name, 'Profile did not finish loading')
		self:Save()
	end)
	if ok then
		self.PreviousProfile = previous
		self.BulkUndo = nil
	else
		local recovered = pcall(self.Load, self, true, previous)
		if recovered and self.Loaded then pcall(self.Save, self) end
		self:CreateNotification('Profiles', 'Switch failed: '..tostring(failure)..(recovered and self.Loaded and '. Previous profile restored.' or '. Reload the client before saving.'), 8, 'alert')
		if not recovered then self.Loaded = false end
	end
	self.SwitchingProfile = false
	self.ProfileSwitchThread = nil
	self.Categories.Profiles:ChangeValue()
	return ok
end

function tenacity:CycleProfile(direction)
	local names = {}
	for _, profile in self.Categories.Profiles.List do table.insert(names, profile.Name) end
	table.sort(names)
	if #names > 1 then self:SwitchProfile(names[((table.find(names, self.Profile) or 1) - 1 + direction) % #names + 1]) end
end

function tenacity:GetKeybindRows(activeOnly)
	local rows = {}
	for name, module in self.Modules do
		local bind = module.Bind
		if bind and bind.Keys and #bind.Keys > 0 and (not activeOnly or module.Enabled) then
			table.insert(rows, {Name = name, Keys = table.concat(bind.Keys, ' + '), Enabled = module.Enabled, Hold = bind.Hold == true})
		end
	end
	table.sort(rows, function(a, b)
		if a.Enabled ~= b.Enabled then return a.Enabled end
		return a.Name:lower() < b.Name:lower()
	end)
	return rows
end

local notificationRecent = {}
function tenacity:AllowNotification(title, text, kind, now)
	kind = kind or 'info'
	if self.NotificationMode and self.NotificationMode.Value == 'Warnings only' and kind ~= 'warning' and kind ~= 'alert' then return false end
	local cooldown = self.NotificationCooldown and self.NotificationCooldown.Value or 0
	if cooldown <= 0 then return true end
	for key, timestamp in notificationRecent do
		if now - timestamp >= cooldown then notificationRecent[key] = nil end
	end
	local key = tostring(kind)..'\0'..title..'\0'..text
	if notificationRecent[key] then return false end
	if getTableSize(notificationRecent) >= 64 then table.clear(notificationRecent) end
	notificationRecent[key] = now
	return true
end

function tenacity:CreateNotification(title, text, duration, type)
	if not self.Notifications.Enabled then
		return
	end
	title, text = tostring(title or 'Tenacity'), tostring(text or '')
	if not self:AllowNotification(title, text, type, os.clock()) then return end
	duration = math.clamp((tonumber(duration) or 3) * (self.NotificationDuration and self.NotificationDuration.Value or 1), 0.5, 30)

	-- When the Dynamic Island is enabled + visible, it becomes Tenacity's notification
	-- surface instead of spawning a second disconnected toast stack. Turning the
	-- island off (or disabling notification merge) restores the original toasts.
	local island = self.DynamicIsland
	local merge = self.DynamicIslandMergeNotifications
	if island and island.Button and island.Button.Enabled and merge and merge.Enabled
		and self.QueueDynamicIslandNotification and (island.Pinned or (clickgui and clickgui.Visible)) then
		self:QueueDynamicIslandNotification(title, text, duration, type, true)
		return
	end

	task.delay(0, function()
		if self.Loaded == nil or not notifications.Parent then return end
		if self.ThreadFix then
			setthreadidentity(8)
		end

		local existing = notifications:GetChildren()
		local limit = self.NotificationLimit and self.NotificationLimit.Value or 4
		while #existing >= limit do table.remove(existing, 1):Destroy() end
		local index = #existing + 1
		local notification = Instance.new('ImageLabel')
		notification.BackgroundTransparency = 1
		notification.Position = UDim2.new(1, 0, 1, -(29 + (78 * index)))
		notification.Image = gettenacityasset('tenacity/assets/new/notification.png')
		notification.ScaleType = Enum.ScaleType.Slice
		notification.SliceCenter = Rect.new(7, 7, 9, 9)
		notification.ZIndex = 5
		notification.Parent = notifications
		addBlur(notification, true, true)
		local iconshadow = Instance.new('ImageLabel')
		iconshadow.BackgroundTransparency = 1
		iconshadow.Image = gettenacityasset('tenacity/assets/new/noti_'..(type or 'info')..'.png')
		iconshadow.ImageColor3 = Color3.new()
		iconshadow.ImageTransparency = 0.5
		iconshadow.Position = UDim2.fromOffset(-5, -8)
		iconshadow.Size = UDim2.fromOffset(60, 60)
		iconshadow.ZIndex = 5
		iconshadow.Parent = notification
		local icon = iconshadow:Clone()
		icon.ImageColor3 = Color3.new(1, 1, 1)
		icon.ImageTransparency = 0
		icon.Position = UDim2.fromOffset(-1, -1)
		icon.Parent = iconshadow
		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.FontSemiBold
		label.Position = UDim2.fromOffset(46, 16)
		label.RichText = true
		label.Size = UDim2.new(1, -56, 0, 20)
		label.Text = "<stroke joins='round' thickness='0.3' transparency='0.5'>"..title..'</stroke>'
		label.TextColor3 = type == 'alert' and Color3.fromRGB(250, 50, 56) or Color3.new(1, 1, 1)
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.ZIndex = 5
		label.Parent = notification
		local dismiss = Instance.new('TextButton')
		dismiss.BackgroundTransparency = 1
		dismiss.Position = UDim2.new(1, -24, 0, 3)
		dismiss.Size = UDim2.fromOffset(22, 22)
		dismiss.Text = '×'
		dismiss.TextSize = 18
		dismiss.TextColor3 = uipallet.Text
		dismiss.ZIndex = 6
		dismiss.Parent = notification
		dismiss.Activated:Connect(function() notification:Destroy() end)
		local textshadow = label:Clone()
		textshadow.FontFace = uipallet.Font
		textshadow.Position = UDim2.fromOffset(47, 44)
		textshadow.RichText = false
		textshadow.Text = removeTags(text)
		textshadow.TextColor3 = Color3.new()
		textshadow.TextTransparency = 0.5
		textshadow.Parent = notification
		notification.Size = UDim2.fromOffset(math.max(getfontbounds(textshadow.Text, 14, uipallet.Font).X + 80, 266), 75)
		local textlabel = textshadow:Clone()
		textlabel.Position = UDim2.fromOffset(-1, -1)
		textlabel.RichText = true
		textlabel.Text = text
		textlabel.TextColor3 = Color3.fromRGB(170, 170, 170)
		textlabel.TextTransparency = 0
		textlabel.Parent = textshadow
		local progress = Instance.new('Frame')
		progress.BackgroundColor3 =
			type == 'alert' and Color3.fromRGB(250, 50, 56)
			or type == 'warning' and Color3.fromRGB(236, 129, 44)
			or Color3.new(1, 1, 1)
		progress.BorderSizePixel = 0
		progress.Position = UDim2.new(0, 3, 1, -4)
		progress.Size = UDim2.new(1, -13, 0, 1)
		progress.ZIndex = 5
		progress.Parent = notification

		if tween.Tween then
			tween:Tween(notification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
				AnchorPoint = Vector2.new(1, 0)
			}, 'tweenstwo')

			tween:Tween(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
				Size = UDim2.fromOffset(0, 1)
			})
		end

		task.delay(duration, function()
			if not notification.Parent then return end
			if tween.Tween then
				tween:Tween(notification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
					AnchorPoint = Vector2.new(0, 0)
				}, 'tweenstwo')
			end

			task.wait(0.2)
			notification:ClearAllChildren()
			notification:Destroy()
		end)
	end)
end

function tenacity:CreateOverlay(props)
	return components.Overlay(props)
end

function tenacity:Load(skipgui, profile)
	local guiData = {Categories = {}}
	local oldProfile = self.Profile
	local canSave = true
	local toggleCount = 0

	if isfile('tenacity/profiles/'..game.GameId..'.gui.txt') then
		guiData = loadJson('tenacity/profiles/'..game.GameId..'.gui.txt')
		if not guiData then
			guiData = {Categories = {}}
			self:CreateNotification('Tenacity', 'Failed to load GUI settings.', 10, 'alert')
			canSave = false
		end

		if guiData.v ~= 1 then
			guiData.Categories.Main = nil
		end

		self.Profile = profile or guiData.Profile or 'default'
		if self.ProfileLabel then
			self.ProfileLabel.Text = #self.Profile > 10 and self.Profile:sub(1, 10)..'...' or self.Profile
			self.ProfileLabel.Size = UDim2.fromOffset(getfontbounds(self.ProfileLabel.Text, self.ProfileLabel.TextSize, self.ProfileLabel.Font).X + 16, 24)
		end

		if not skipgui then
			for name, data in guiData.Categories do
				local category = self.Categories[name]
				if category then
					category:Load(data)
				end
			end
		end
	end

	if not self.Categories.Profiles:GetValue('default') then
		self.Categories.Profiles:ChangeValue('default', true)
	end

	if isfile('tenacity/profiles/'..self.Profile..self.Place..'.txt') then
		local mainData = loadJson('tenacity/profiles/'..self.Profile..self.Place..'.txt')
		if not mainData then
			mainData = {Categories = {}, Modules = {}}
			self:CreateNotification('Tenacity', 'Failed to load '..self.Profile..' profile.', 10, 'alert')
			canSave = false
		end

		if mainData.v ~= 1 then
			for _, data in mainData.Modules do
				data.Bind = {Keys = data.Bind}
				data.Visible = true
			end
		end

		-- New Tenacity profiles keep every module in one Modules table. If an old
		-- imported profile has the former detached bucket, merge it once on load.
		if type(mainData.Auxiliary) == 'table' then
			for name, data in mainData.Auxiliary do
				if mainData.Modules[name] == nil then mainData.Modules[name] = data end
			end
		end

		for name, data in mainData.Modules do
			local module = self.Modules[name]
			if module then
				module:Load(data)
				toggleCount += module.Enabled and 1 or 0
			end
		end

		self:UpdateTextGUI(true)
	else
		self:Save()
	end

	if self.Profile ~= oldProfile and skipgui then
		self:CreateNotification('Profile swap to <font color="#FFAA00">'..self.Profile..'</font>', toggleCount..' modules enabled', 3)
	end

	if self.Downloader then
		self.Downloader:Destroy()
		self.Downloader = nil
	end

	self.Loaded = canSave
	self.LastSaved = nil
	if self.UpdateSessionHint then self:UpdateSessionHint() end

	if inputService.TouchEnabled and not skipgui then
		local button = Instance.new('TextButton')
		button.BackgroundColor3 = Color3.new()
		button.BackgroundTransparency = 0.2
		button.Position = UDim2.new(1, -90, 0, 4)
		button.Size = UDim2.fromOffset(32, 32)
		button.Text = ''
		button.Parent = gui
		local image = Instance.new('ImageLabel')
		image.BackgroundTransparency = 1
		image.Image = gettenacityasset('tenacity/assets/tenacity/modernlogo.png')
		image.Position = UDim2.fromOffset(6, 6)
		image.Size = UDim2.fromOffset(20, 20)
		image.Parent = button
		addCorner(button, UDim.new(1, 0))

		button.MouseButton1Click:Connect(function()
			self.GUIBind.Triggered:Fire(true)
		end)
	end

	return toggleData
end

function tenacity:LoadOptions(obj, data)
	for name, componentData in data do
		local component = obj.Options[name]

		if component then
			component:Load(componentData)
		end
	end
end

function tenacity:LoadGUI()
	addMaid(tenacity)
	gui = Instance.new('ScreenGui')
	gui.Name = randomString()
	gui.DisplayOrder = 9999999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.IgnoreGuiInset = true

	if tenacity.ThreadFix then
		local holder = Instance.new('Folder')
		holder.Parent = cloneref(game:GetService('CoreGui'))
		gui.Parent = (gethui and gethui()) or cloneref(game:GetService('CoreGui'))
		tenacity.holder = holder
	else
		gui.Parent = cloneref(game:GetService('Players')).LocalPlayer.PlayerGui
		gui.ResetOnSpawn = false
		tenacity.holder = gui
	end
	tenacity.gui = gui

	scaledgui = Instance.new('Frame')
	scaledgui.BackgroundTransparency = 1
	scaledgui.Name = 'ScaledGui'
	scaledgui.Size = UDim2.fromScale(1, 1)
	scaledgui.Parent = gui
	clickgui = Instance.new('Frame')
	clickgui.BackgroundTransparency = 1
	clickgui.Name = 'ClickGui'
	clickgui.Size = UDim2.fromScale(1, 1)
	clickgui.Visible = false
	clickgui.Parent = scaledgui
	tenacity.ClickGUI = clickgui

	-- Background-only topography.
	-- ZIndex 0 keeps it behind every category/tab/module window.
	topographyBackground = Instance.new('ImageLabel')
	topographyBackground.Name = 'TopographyBackground'
	topographyBackground.Active = false
	topographyBackground.BackgroundTransparency = 1
	topographyBackground.Image = 'rbxassetid://2151741365'
	topographyBackground.ImageColor3 = tenacity:GetThemeColor(0.08)
	topographyBackground.ImageTransparency = 0.9
	topographyBackground.Visible = false
	topographyBackground.Position = UDim2.fromOffset(-180, -180)
	topographyBackground.ScaleType = Enum.ScaleType.Tile
	topographyBackground.Size = UDim2.new(1, 360, 1, 360)
	topographyBackground.TileSize = UDim2.fromOffset(300, 300)
	topographyBackground.ZIndex = 0
	topographyBackground.Parent = clickgui

	-- Optional static texture; no background animation loop.
	local shortcutHint = Instance.new('TextLabel')
	shortcutHint.BackgroundTransparency = 1
	shortcutHint.FontFace = uipallet.Font
	shortcutHint.AnchorPoint = Vector2.new(0.5, 1)
	shortcutHint.Position = UDim2.new(0.5, 0, 1, -12)
	shortcutHint.Size = UDim2.new(1, -32, 0, 24)
	shortcutHint.Text = inputService.TouchEnabled and 'Search / Save / profiles are available from Settings'
		or '/ or Ctrl+F  Search     /     Ctrl+S  Save     /     Esc  Back'
	shortcutHint.TextColor3 = uipallet.Text
	shortcutHint.TextTransparency = 0.35
	shortcutHint.TextSize = 12
	shortcutHint.TextTruncate = Enum.TextTruncate.AtEnd
	shortcutHint.Parent = clickgui
	local sessionHintRevision = 0
	function tenacity:UpdateSessionHint()
		local shortcuts = inputService.TouchEnabled and 'Search / Save in Settings'
			or '/ or Ctrl+F Search / Ctrl+S Save / Esc Back'
		shortcutHint.Text = 'Profile: '..self.Profile..'   |   '..(self.LastSaved and ('Saved '..self.LastSaved) or 'Autosave ready')..'   |   '..shortcuts
	end
	function tenacity:ShowSessionHint()
		self:UpdateSessionHint()
		sessionHintRevision += 1
		local revision = sessionHintRevision
		shortcutHint.Visible = true
		shortcutHint.TextTransparency = 0.35
		task.delay(4, function()
			if revision ~= sessionHintRevision or not shortcutHint.Parent then return end
			if self.ReducedMotion and self.ReducedMotion.Enabled then
				shortcutHint.Visible = false
				return
			end
			tween:Tween(shortcutHint, uiMotion, {TextTransparency = 1})
			task.delay(0.2, function()
				if revision == sessionHintRevision and shortcutHint.Parent then shortcutHint.Visible = false end
			end)
		end)
	end
	tenacity:UpdateSessionHint()
	local modal = Instance.new('TextButton')
	modal.BackgroundTransparency = 1
	modal.Modal = true
	modal.Text = ''
	modal.Parent = clickgui
	local cursor = Instance.new('ImageLabel')
	cursor.BackgroundTransparency = 1
	cursor.Image = 'rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png'
	cursor.Size = UDim2.fromOffset(64, 64)
	cursor.Visible = false
	cursor.Parent = gui
	notifications = Instance.new('Folder')
	notifications.Name = 'Notifications'
	notifications.Parent = scaledgui
	tooltip = Instance.new('TextLabel')
	tooltip.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
	tooltip.FontFace = uipallet.Font
	tooltip.Position = UDim2.fromScale(-1, -1)
	tooltip.RichText = true
	tooltip.Text = ''
	tooltip.TextColor3 = color.Dark(uipallet.Text, 0.16)
	tooltip.TextSize = 12
	tooltip.Visible = false
	tooltip.ZIndex = 5
	tooltip.Parent = scaledgui
	toolblur = addBlur(tooltip)
	addCorner(tooltip)
	scale = Instance.new('UIScale')
	scale.Scale = math.max(gui.AbsoluteSize.X / 1920, 0.6)
	scale.Parent = scaledgui
	scaledgui.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)
	components.GUI({})

	tenacity:CreateCategory({
		Name = 'Combat',
		Icon = gettenacityasset('tenacity/assets/new/combat.png'),
		Size = UDim2.fromOffset(13, 14)
	})
	tenacity:CreateCategory({
		Name = 'Movement',
		Icon = gettenacityasset('tenacity/assets/new/movement.png'),
		Size = UDim2.fromOffset(14, 14)
	})
	tenacity:CreateCategory({
		Name = 'Render',
		Icon = gettenacityasset('tenacity/assets/new/render.png'),
		Size = UDim2.fromOffset(15, 14)
	})
	tenacity:CreateCategory({
		Name = 'Player',
		Icon = gettenacityasset('tenacity/assets/new/player.png'),
		Size = UDim2.fromOffset(15, 14)
	})
	tenacity:CreateCategory({
		Name = 'Exploit',
		Icon = gettenacityasset('tenacity/assets/new/exploit.png'),
		Size = UDim2.fromOffset(14, 14)
	})
	tenacity:CreateCategory({
		Name = 'Misc',
		Icon = gettenacityasset('tenacity/assets/new/misc.png'),
		Size = UDim2.fromOffset(15, 14)
	})
	tenacity:CreateCategory({
		Name = 'Scripts',
		Icon = gettenacityasset('tenacity/assets/tenacity/modernlogo.png'),
		Size = UDim2.fromOffset(15, 14)
	})
	tenacity.Categories.Main:CreateDivider({
		Text = 'misc'
	})

	--[[
		Friends
	]]
	do
		local friends
		local friendscolor = {
			Hue = 1,
			Sat = 1,
			Value = 1
		}

		friends = tenacity:CreateCategoryList({
			Name = 'Friends',
			Icon = gettenacityasset('tenacity/assets/new/friends.png'),
			Size = UDim2.fromOffset(17, 16),
			Placeholder = 'Roblox username',
			Color = Color3.fromRGB(5, 134, 105),
			Function = function()
				friends.Update:Fire()
				friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
			end
		})
		friends.Update = Instance.new('BindableEvent')
		friends.ColorUpdate = Instance.new('BindableEvent')
		friends:CreateToggle({
			Name = 'Recolor visuals',
			Darker = true,
			Default = true,
			Function = function()
				friends.Update:Fire()
				friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
			end
		})
		friendscolor = friends:CreateColorSlider({
			Name = 'Friends color',
			Darker = true,
			Function = function(hue, sat, val)
				for _, v in friends.Object.Children:GetChildren() do
					local dot = v:FindFirstChild('Dot')
					if dot and dot.BackgroundColor3 ~= color.Light(uipallet.Main, 0.37) then
						dot.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
						dot.Dot.BackgroundColor3 = dot.BackgroundColor3
					end
				end

				friends.ColorUpdate:Fire(hue, sat, val)
			end
		})
		friends:CreateToggle({
			Name = 'Use friends',
			Darker = true,
			Default = true,
			Function = function()
				friends.Update:Fire()
				friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
			end
		})
		tenacity:Clean(friends.Update)
		tenacity:Clean(friends.ColorUpdate)
	end

	--[[
		Profiles
	]]
	tenacity:CreateCategoryList({
		Name = 'Profiles',
		Icon = gettenacityasset('tenacity/assets/new/profiles.png'),
		Size = UDim2.fromOffset(17, 10),
		Position = UDim2.fromOffset(12, 16),
		Placeholder = 'Type name',
		Profiles = true
	})

	--[[
		Targets
	]]
	local targets
	targets = tenacity:CreateCategoryList({
		Name = 'Targets',
		Icon = gettenacityasset('tenacity/assets/new/friends.png'),
		Size = UDim2.fromOffset(17, 16),
		Placeholder = 'Roblox username',
		Function = function()
			targets.Update:Fire()
		end
	})
	targets.Update = Instance.new('BindableEvent')
	tenacity:Clean(targets.Update)

	components.AuxiliaryWindow()
	tenacity.SearchBar = components.SearchBar()
	tenacity.Categories.Main:CreateOverlayBar()

	--[[
		Dynamic Island Overlay
	]]
	local DynamicIsland
	do
		-- Compact watermark with optional notification expansion.
		local queue = {}
		local activeNotification
		local queueWorker = false
		local notificationEpoch = 0
		local dismissEpoch = 0
		local fpsAverage = 60
		local statsAccumulator = 0
		local idleCount = 0
		local lastClock = ''

		local mergeNotifications, autoWidth, showProgress
		local showLogo, showEdition, showProfile, showModules, showFPS, showClock
		local showNotificationIcon, clickDismiss, baseWidth, maxWidth, idleHeight, notificationHeight
		local durationScale, queueLimit, queueMode, islandMotion, idleClickAction
		local accentLine

		local card, cardStroke, idleGroup, notificationGroup
		local idleLogo, idleEdition, idleDivider, idleTitle, idleMeta
		local notiIconShadow, notiIcon, notiTitle, notiBody, notiLogo, queueLabel
		local progressTrack, progressFill, accent

		local function getEnabledCount()
			local count = 0
			for _, module in tenacity.Modules do
				if module.Enabled then count += 1 end
			end
			return count
		end

		local function formatClock()
			local ok, result = pcall(os.date, '%I:%M %p')
			return ok and result or '--:--'
		end

		local function currentMotion()
			local mode = islandMotion and islandMotion.Value or 'Tenacity'
			if mode == 'None' or (tenacity.ReducedMotion and tenacity.ReducedMotion.Enabled) then return nil end
			if mode == 'Snappy' then
				return TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			elseif mode == 'Smooth' then
				return TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			end
			return TweenInfo.new(0.32, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
		end

		local function animate(object, goal, group)
			local info = currentMotion()
			if not info then
				for property, value in goal do object[property] = value end
				return nil
			end
			return tween:Tween(object, info, goal, group or 'island')
		end

		local function getTargetWidth(notification)
			local minimum = baseWidth and baseWidth.Value or 310
			if not notification or not (autoWidth and autoWidth.Enabled) then return minimum end
			local maximum = math.max(minimum, maxWidth and maxWidth.Value or 500)
			local titleWidth = getfontbounds(removeTags(notification.Title or ''), 14, uipallet.FontSemiBold).X
			local bodyWidth = getfontbounds(removeTags(notification.Text or ''), 13, uipallet.Font).X
			local iconSpace = (showNotificationIcon and showNotificationIcon.Enabled) and 72 or 24
			return math.clamp(math.max(titleWidth, bodyWidth) + iconSpace + 68, minimum, maximum)
		end

		local function resizeIsland(width, height)
			if not DynamicIsland or not DynamicIsland.Object then return end
			local object = DynamicIsland.Object
			local currentWidth = object.Size.X.Offset
			local newWidth = math.floor(width + 0.5)
			local centerShift = (currentWidth - newWidth) * 0.5
			local targetPosition = UDim2.new(object.Position.X.Scale, object.Position.X.Offset + centerShift, object.Position.Y.Scale, object.Position.Y.Offset)
			local info = currentMotion()
			if info then
				tween:Tween(object, info, {Size = UDim2.fromOffset(newWidth, object.Size.Y.Offset), Position = targetPosition}, 'island-window')
				tween:Tween(card, info, {Size = UDim2.new(1, 0, 0, height)}, 'island-card')
			else
				object.Size = UDim2.fromOffset(newWidth, object.Size.Y.Offset)
				object.Position = targetPosition
				card.Size = UDim2.new(1, 0, 0, height)
			end
		end

		local function setGroup(group, visible)
			if not group then return end
			group.Visible = true
			local info = currentMotion()
			if info then
				local motion = tween:Tween(group, info, {GroupTransparency = visible and 0 or 1}, 'island-content')
				if not visible and motion then
					motion.Completed:Once(function()
						if group.Parent and group.GroupTransparency >= 0.98 then group.Visible = false end
					end)
				end
			else
				group.GroupTransparency = visible and 0 or 1
				group.Visible = visible
			end
		end

		local function semanticColor(notificationType)
			if notificationType == 'alert' then return Color3.fromRGB(250, 50, 56) end
			if notificationType == 'warning' then return Color3.fromRGB(236, 129, 44) end
			return tenacity:GetThemeColor(0.08)
		end

		local function updateIdleText()
			if not idleTitle or not idleMeta then return end
			if showModules and showModules.Enabled then idleCount = getEnabledCount() end
			if showClock and showClock.Enabled then lastClock = formatClock() end
			local profile = tostring(tenacity.Profile or 'default')
			local title = (showProfile and showProfile.Enabled) and profile or 'Tenacity '..tenacity.Version
			if idleTitle.Text ~= title then idleTitle.Text = title end
			local bits = {}
			if showModules and showModules.Enabled then table.insert(bits, tostring(idleCount)..' modules') end
			if showFPS and showFPS.Enabled then table.insert(bits, tostring(math.floor(fpsAverage + 0.5))..' FPS') end
			if showClock and showClock.Enabled then table.insert(bits, lastClock) end
			local metadata = table.concat(bits, '  ·  ')
			if idleMeta.Text ~= metadata then idleMeta.Text = metadata end
		end

		local function updateLogoVisibility()
			if idleLogo then idleLogo.Visible = showLogo == nil or showLogo.Enabled end
			if idleEdition then idleEdition.Visible = (showLogo == nil or showLogo.Enabled) and (showEdition == nil or showEdition.Enabled) end
			if idleDivider then idleDivider.Visible = showLogo == nil or showLogo.Enabled end
			if idleTitle then idleTitle.Position = UDim2.fromOffset((showLogo == nil or showLogo.Enabled) and 114 or 14, 7) end
			local inset = (showLogo == nil or showLogo.Enabled) and 126 or 28
			if idleTitle then idleTitle.Size = UDim2.new(1, -inset, 0, 18) end
			if idleMeta then idleMeta.Size = UDim2.new(1, -inset, 0, 16) end
			if idleMeta then idleMeta.Position = UDim2.fromOffset((showLogo == nil or showLogo.Enabled) and 114 or 14, 23) end
		end

		local function updateAccentVisibility()
			if accent then accent.Visible = accentLine == nil or accentLine.Enabled end
		end

		local function presentIdle()
			activeNotification = nil
			updateIdleText()
			setGroup(notificationGroup, false)
			setGroup(idleGroup, true)
			resizeIsland(baseWidth and baseWidth.Value or 310, idleHeight and idleHeight.Value or 46)
			if progressTrack then progressTrack.Visible = false end
			if queueLabel then queueLabel.Visible = false end
			if cardStroke then cardStroke.Color = color.Light(uipallet.Main, 0.16) end
		end

		local function presentNotification(notification)
			activeNotification = notification
			local ntype = notification.Type or 'info'
			if ntype ~= 'info' and ntype ~= 'warning' and ntype ~= 'alert' then ntype = 'info' end
			local typeColor = semanticColor(ntype)
			notiTitle.Text = tostring(notification.Title or 'Tenacity')
			notiTitle.TextColor3 = ntype == 'info' and uipallet.Text or typeColor
			notiBody.Text = tostring(notification.Text or '')
			notiIconShadow.Image = gettenacityasset('tenacity/assets/new/noti_'..ntype..'.png')
			notiIcon.Image = notiIconShadow.Image
			local iconsVisible = showNotificationIcon == nil or showNotificationIcon.Enabled
			notiIconShadow.Visible = iconsVisible
			notiTitle.Position = UDim2.fromOffset(iconsVisible and 62 or 14, 10)
			notiTitle.Size = UDim2.new(1, iconsVisible and -136 or -88, 0, 20)
			notiBody.Position = UDim2.fromOffset(iconsVisible and 62 or 14, 32)
			notiBody.Size = UDim2.new(1, iconsVisible and -82 or -28, 0, 23)
			notiLogo.Visible = showLogo == nil or showLogo.Enabled
			queueLabel.Text = #queue > 0 and ('+'..#queue) or ''
			queueLabel.Visible = #queue > 0
			if cardStroke then
				tenacity:UnregisterThemeSolid(cardStroke)
				cardStroke.Color = typeColor
			end
			setGroup(idleGroup, false)
			setGroup(notificationGroup, true)
			resizeIsland(getTargetWidth(notification), notificationHeight and notificationHeight.Value or 72)
			local duration = math.max(0.15, (notification.Duration or 3) * (durationScale and durationScale.Value or 1))
			progressTrack.Visible = showProgress == nil or showProgress.Enabled
			progressFill.BackgroundColor3 = typeColor
			progressFill.Size = UDim2.new(1, 0, 1, 0)
			tween:Cancel(progressFill)
			if progressTrack.Visible then
				tween:Tween(progressFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.fromScale(0, 1)})
			end
			return duration
		end

		local function queueNotification(notification)
			local mode = queueMode and queueMode.Value or 'Queue'
			local limit = queueLimit and math.max(1, math.floor(queueLimit.Value)) or 5
			if mode == 'Replace' then
				table.clear(queue)
				notificationEpoch += 1
				table.insert(queue, 1, notification)
			elseif mode == 'Latest' then
				table.clear(queue)
				table.insert(queue, notification)
			else
				while #queue >= limit do table.remove(queue, 1) end
				table.insert(queue, notification)
			end

			if activeNotification and queueLabel then
				queueLabel.Text = #queue > 0 and ('+'..#queue) or ''
				queueLabel.Visible = #queue > 0
			end

			if queueWorker then return end
			queueWorker = true
			tenacity:Clean(task.spawn(function()
				while DynamicIsland and DynamicIsland.Button.Enabled and #queue > 0 do
					local item = table.remove(queue, 1)
					local epoch = notificationEpoch
					local dismiss = dismissEpoch
					local duration = presentNotification(item)
					local deadline = os.clock() + duration
					repeat task.wait(0.035) until os.clock() >= deadline or epoch ~= notificationEpoch or dismiss ~= dismissEpoch or not DynamicIsland.Button.Enabled
					if not DynamicIsland.Button.Enabled then break end
				end
				if not DynamicIsland.Button.Enabled then table.clear(queue) end
				queueWorker = false
				presentIdle()
			end))
		end

		function tenacity:DismissIslandNotifications()
			table.clear(queue)
			dismissEpoch += 1
			if progressFill then tween:Cancel(progressFill) end
			presentIdle()
		end

		function tenacity:QueueDynamicIslandNotification(title, body, duration, notificationType, checked)
			if not DynamicIsland or not DynamicIsland.Button.Enabled then return false end
			if not checked then
				if not self.Notifications.Enabled or not self:AllowNotification(tostring(title or 'Tenacity'), tostring(body or ''), notificationType, os.clock()) then return false end
				duration = math.clamp((tonumber(duration) or 3) * (self.NotificationDuration and self.NotificationDuration.Value or 1), 0.5, 30)
			end
			queueNotification({
				Title = tostring(title or 'Tenacity'),
				Text = tostring(body or ''),
				Duration = duration or 3,
				Type = notificationType or 'info'
			})
			return true
		end

		function tenacity:PushDynamicIslandMessage(title, body, duration, accentOffset)
			return self:QueueDynamicIslandNotification(title, body, duration, 'info')
		end

		function tenacity:PushDynamicIslandModuleMessage(name, enabled)
			if not DynamicIsland or not DynamicIsland.Button.Enabled then return end
			if not mergeNotifications or not mergeNotifications.Enabled then return end
			if not (DynamicIsland.Pinned or (clickgui and clickgui.Visible)) then return end
			if self.ToggleNotifications and not self.ToggleNotifications.Enabled then return end
			self:QueueDynamicIslandNotification(name, enabled and "<font color='#00AA00'>Enabled</font>" or "<font color='#FF5A5A'>Disabled</font>", 1.5, 'info')
		end

		DynamicIsland = tenacity:CreateOverlay({
			Name = 'Dynamic Island',
			Icon = gettenacityasset('tenacity/assets/tenacity/modernlogo.png'),
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.fromOffset(12, 12),
			CategorySize = 310
		})
		tenacity.DynamicIsland = DynamicIsland
		DynamicIsland.Object.Position = UDim2.new(0.5, -155, 0, 12)

		-- Use Overlay.Children, exactly like Tenacity's other HUD overlays. When the GUI
		-- opens the normal Tenacity overlay header appears above it; when closed/pinned,
		-- only the island remains. No fake custom editor chrome.
		card = Instance.new('ImageButton')
		card.Name = 'TenacityDynamicIsland'
		card.AutoButtonColor = false
		card.BackgroundColor3 = uipallet.Main
		card.BackgroundTransparency = 0.08
		card.BorderSizePixel = 0
		card.Image = ''
		card.ImageColor3 = Color3.new(1, 1, 1)
		card.ScaleType = Enum.ScaleType.Slice
		card.SliceCenter = Rect.new(7, 7, 9, 9)
		card.Size = UDim2.new(1, 0, 0, 46)
		card.Parent = DynamicIsland.Children
		addCorner(card, UDim.new(0, 4))
		cardStroke = Instance.new('UIStroke')
		cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		cardStroke.Transparency = 0.82
		cardStroke.Thickness = 1
		cardStroke.Parent = card
		cardStroke.Color = color.Light(uipallet.Main, 0.16)
		addBlur(card, true, true)

		idleGroup = Instance.new('CanvasGroup')
		idleGroup.BackgroundTransparency = 1
		idleGroup.Size = UDim2.fromScale(1, 1)
		idleGroup.ZIndex = 4
		idleGroup.Parent = card
		idleLogo = Instance.new('ImageLabel')
		idleLogo.BackgroundTransparency = 1
		idleLogo.Image = gettenacityasset('tenacity/assets/tenacity/modernlogo.png')
		idleLogo.Position = UDim2.fromOffset(13, 14)
		idleLogo.Size = UDim2.fromOffset(55, 16)
		idleLogo.Parent = idleGroup
		idleEdition = Instance.new('ImageLabel')
		idleEdition.BackgroundTransparency = 1
		idleEdition.Image = ''; idleEdition.Visible = false
		idleEdition.Position = UDim2.fromOffset(72, 14)
		idleEdition.Size = UDim2.fromOffset(23, 16)
		idleEdition.Parent = idleGroup
		idleDivider = Instance.new('Frame')
		idleDivider.BorderSizePixel = 0
		idleDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		idleDivider.BackgroundTransparency = 0.86
		idleDivider.Position = UDim2.fromOffset(101, 8)
		idleDivider.Size = UDim2.fromOffset(1, 30)
		idleDivider.Parent = idleGroup
		idleTitle = Instance.new('TextLabel')
		idleTitle.BackgroundTransparency = 1
		idleTitle.FontFace = uipallet.FontSemiBold
		idleTitle.Position = UDim2.fromOffset(108, 7)
		idleTitle.Size = UDim2.new(1, -120, 0, 18)
		idleTitle.Text = 'default'
		idleTitle.TextColor3 = uipallet.Text
		idleTitle.TextSize = 13
		idleTitle.TextXAlignment = Enum.TextXAlignment.Left
		idleTitle.TextTruncate = Enum.TextTruncate.AtEnd
		idleTitle.Parent = idleGroup
		idleMeta = Instance.new('TextLabel')
		idleMeta.BackgroundTransparency = 1
		idleMeta.FontFace = uipallet.Font
		idleMeta.Position = UDim2.fromOffset(108, 23)
		idleMeta.Size = UDim2.new(1, -120, 0, 16)
		idleMeta.Text = 'Ready'
		idleMeta.TextColor3 = Color3.fromRGB(170, 174, 184)
		idleMeta.TextSize = 11
		idleMeta.TextXAlignment = Enum.TextXAlignment.Left
		idleMeta.TextTruncate = Enum.TextTruncate.AtEnd
		idleMeta.Parent = idleGroup

		notificationGroup = Instance.new('CanvasGroup')
		notificationGroup.BackgroundTransparency = 1
		notificationGroup.GroupTransparency = 1
		notificationGroup.Visible = false
		notificationGroup.Size = UDim2.fromScale(1, 1)
		notificationGroup.ZIndex = 4
		notificationGroup.Parent = card
		notiIconShadow = Instance.new('ImageLabel')
		notiIconShadow.BackgroundTransparency = 1
		notiIconShadow.Image = gettenacityasset('tenacity/assets/new/noti_info.png')
		notiIconShadow.ImageColor3 = Color3.new()
		notiIconShadow.ImageTransparency = 0.48
		notiIconShadow.Position = UDim2.fromOffset(2, 4)
		notiIconShadow.Size = UDim2.fromOffset(54, 54)
		notiIconShadow.Parent = notificationGroup
		notiIcon = notiIconShadow:Clone()
		notiIcon.ImageColor3 = Color3.new(1, 1, 1)
		notiIcon.ImageTransparency = 0
		notiIcon.Position = UDim2.fromOffset(3, 3)
		notiIcon.Size = UDim2.fromScale(1, 1)
		notiIcon.Parent = notiIconShadow
		notiTitle = Instance.new('TextLabel')
		notiTitle.BackgroundTransparency = 1
		notiTitle.FontFace = uipallet.FontSemiBold
		notiTitle.Position = UDim2.fromOffset(62, 10)
		notiTitle.RichText = true
		notiTitle.Size = UDim2.new(1, -136, 0, 20)
		notiTitle.Text = 'Tenacity'
		notiTitle.TextColor3 = uipallet.Text
		notiTitle.TextSize = 14
		notiTitle.TextXAlignment = Enum.TextXAlignment.Left
		notiTitle.TextTruncate = Enum.TextTruncate.AtEnd
		notiTitle.Parent = notificationGroup
		notiBody = Instance.new('TextLabel')
		notiBody.BackgroundTransparency = 1
		notiBody.FontFace = uipallet.Font
		notiBody.Position = UDim2.fromOffset(62, 32)
		notiBody.RichText = true
		notiBody.Size = UDim2.new(1, -82, 0, 23)
		notiBody.Text = ''
		notiBody.TextColor3 = Color3.fromRGB(170, 170, 170)
		notiBody.TextSize = 13
		notiBody.TextXAlignment = Enum.TextXAlignment.Left
		notiBody.TextYAlignment = Enum.TextYAlignment.Top
		notiBody.TextTruncate = Enum.TextTruncate.AtEnd
		notiBody.Parent = notificationGroup
		notiLogo = Instance.new('ImageLabel')
		notiLogo.AnchorPoint = Vector2.new(1, 0)
		notiLogo.BackgroundTransparency = 1
		notiLogo.Image = gettenacityasset('tenacity/assets/tenacity/modernlogo.png')
		notiLogo.ImageTransparency = 0.72
		notiLogo.Position = UDim2.new(1, -14, 0, 9)
		notiLogo.Size = UDim2.fromOffset(55, 16)
		notiLogo.Parent = notificationGroup
		queueLabel = Instance.new('TextLabel')
		queueLabel.AnchorPoint = Vector2.new(1, 1)
		queueLabel.BackgroundTransparency = 1
		queueLabel.FontFace = uipallet.FontSemiBold
		queueLabel.Position = UDim2.new(1, -13, 1, -9)
		queueLabel.Size = UDim2.fromOffset(30, 14)
		queueLabel.Text = ''
		queueLabel.TextColor3 = Color3.fromRGB(170, 174, 184)
		queueLabel.TextSize = 10
		queueLabel.TextXAlignment = Enum.TextXAlignment.Right
		queueLabel.Parent = notificationGroup

		progressTrack = Instance.new('Frame')
		progressTrack.AnchorPoint = Vector2.new(0, 1)
		progressTrack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		progressTrack.BackgroundTransparency = 0.9
		progressTrack.BorderSizePixel = 0
		progressTrack.Position = UDim2.new(0, 7, 1, -4)
		progressTrack.Size = UDim2.new(1, -14, 0, 1)
		progressTrack.Visible = false
		progressTrack.ZIndex = 5
		progressTrack.Parent = card
		progressFill = Instance.new('Frame')
		progressFill.BackgroundColor3 = tenacity:GetThemeColor(0.08)
		progressFill.BorderSizePixel = 0
		progressFill.Size = UDim2.fromScale(1, 1)
		progressFill.ZIndex = 5
		progressFill.Parent = progressTrack

		accent = Instance.new('Frame')
		accent.AnchorPoint = Vector2.new(0, 1)
		accent.BackgroundColor3 = Color3.new(1, 1, 1)
		accent.BorderSizePixel = 0
		accent.Position = UDim2.new(0, 4, 0, 2)
		accent.Size = UDim2.new(1, -8, 0, 2)
		accent.ZIndex = 5
		accent.Parent = card
		local accentGradient = Instance.new('UIGradient')
		accentGradient.Parent = accent
		tenacity:RegisterThemeGradient(accentGradient, 0.08, 0)

		-- Island customization lives in the overlay's own settings, not the already
		-- crowded GUI tab.
		mergeNotifications = DynamicIsland:CreateToggle({Name = 'Merge notifications', Default = false, Tooltip = 'Route Tenacity notifications through the island while it is visible.'})
		tenacity.DynamicIslandMergeNotifications = mergeNotifications
		autoWidth = DynamicIsland:CreateToggle({Name = 'Dynamic notification width', Default = true, Tooltip = 'Expand horizontally to fit notification content.'})
		accentLine = DynamicIsland:CreateToggle({Name = 'Theme accent line', Default = true, Function = updateAccentVisibility})
		showProgress = DynamicIsland:CreateToggle({Name = 'Notification progress', Default = true})
		showNotificationIcon = DynamicIsland:CreateToggle({Name = 'Notification icons', Default = true})
		clickDismiss = DynamicIsland:CreateToggle({Name = 'Click to dismiss', Default = true})
		showLogo = DynamicIsland:CreateToggle({Name = 'Tenacity logo', Default = true, Function = updateLogoVisibility})
		showEdition = DynamicIsland:CreateToggle({Name = 'Edition badge', Default = true, Darker = true, Function = updateLogoVisibility})
		showProfile = DynamicIsland:CreateToggle({Name = 'Profile name', Default = true, Function = updateIdleText})
		showModules = DynamicIsland:CreateToggle({Name = 'Module count', Default = true, Function = updateIdleText})
		showFPS = DynamicIsland:CreateToggle({Name = 'FPS', Default = true, Function = updateIdleText})
		showClock = DynamicIsland:CreateToggle({Name = 'Clock', Default = false, Function = updateIdleText})
		idleClickAction = DynamicIsland:CreateDropdown({Name = 'Idle click', List = {'Open GUI', 'Nothing'}, Default = 'Open GUI'})
		queueMode = DynamicIsland:CreateDropdown({Name = 'Notification behavior', List = {'Queue', 'Latest', 'Replace'}, Default = 'Queue'})
		queueLimit = DynamicIsland:CreateSlider({Name = 'Queue limit', Min = 1, Max = 8, Default = 5, Decimal = 1, Function = function() end})
		durationScale = DynamicIsland:CreateSlider({Name = 'Duration scale', Min = 0.5, Max = 2, Default = 1, Decimal = 10, Suffix = 'x', Function = function() end})
		islandMotion = DynamicIsland:CreateDropdown({Name = 'Island motion', List = {'Tenacity', 'Smooth', 'Snappy', 'None'}, Default = 'Tenacity'})
		baseWidth = DynamicIsland:CreateSlider({Name = 'Idle width', Min = 240, Max = 420, Default = 310, Decimal = 1, Function = function(value, released) if released and not activeNotification then resizeIsland(value, idleHeight and idleHeight.Value or 46) end end})
		maxWidth = DynamicIsland:CreateSlider({Name = 'Max notification width', Min = 320, Max = 620, Default = 500, Decimal = 1, Function = function() end})
		idleHeight = DynamicIsland:CreateSlider({Name = 'Idle height', Min = 40, Max = 58, Default = 46, Decimal = 1, Function = function(value, released) if released and not activeNotification then resizeIsland(baseWidth and baseWidth.Value or 310, value) end end})
		notificationHeight = DynamicIsland:CreateSlider({Name = 'Notification height', Min = 62, Max = 88, Default = 72, Decimal = 1, Function = function(value, released) if released and activeNotification then resizeIsland(getTargetWidth(activeNotification), value) end end})

		addTooltip(card, 'LMB '..'dismiss/open GUI'..'  •  RMB island settings')
		card.MouseButton2Click:Connect(function()
			if clickgui.Visible then DynamicIsland:Expand(true) end
		end)

		card.MouseButton1Click:Connect(function()
			if activeNotification then
				if clickDismiss and clickDismiss.Enabled then
					dismissEpoch += 1
				end
			elseif idleClickAction and idleClickAction.Value == 'Open GUI' then
				clickgui.Visible = not clickgui.Visible
			end
		end)

		if not DynamicIsland.Button.Enabled then DynamicIsland.Button:Toggle() end
		if not DynamicIsland.Pinned then DynamicIsland:Pin() end
		DynamicIsland:Update()
		updateLogoVisibility()
		updateAccentVisibility()
		presentIdle()

		tenacity:Clean(runService.RenderStepped:Connect(function(delta)
			if not DynamicIsland or not DynamicIsland.Button.Enabled or not card or not card.Parent or not DynamicIsland.Children.Visible
				or not (DynamicIsland.Pinned or clickgui.Visible) then return end
			fpsAverage += (((delta > 0 and (1 / delta) or 60) - fpsAverage) * math.min(delta * 3, 1))
			statsAccumulator += delta
			if statsAccumulator >= 1 then
				statsAccumulator %= 1
				if not activeNotification then updateIdleText() end
			end
		end))
	end

	--[[
		General Settings
	]]

	local general = tenacity.Categories.Main.Settings:CreateSettingsPane({Name = 'General'})
	local settingConnections = {}
	tenacity.MultiKeybind = general:CreateToggle({
		Name = 'Enable Multi-Keybinding',
		Tooltip = 'Allows multiple keys to be bound to a module (eg. G + H)'
	})
	general:CreateToggle({
		Name = 'Allow setting keybinds',
		Function = function(callback)
			if callback then
				for _, container in {tenacity.Modules, tenacity.Auxiliary.Modules} do
					for _, module in container do
						for _, component in module.Options do
							if component.Type == 'Toggle' then
								local bind = components.Bind({
									Module = true
								}, nil, component)
								bind.Object.Position = UDim2.new(1, -40, 0, 5)

								table.insert(settingConnections, bind.Triggered:Connect(function(isDown)
									if bind.Hold then
										if component.Enabled ~= isDown then
											if tenacity.SettingToggleNotifications.Enabled then
												tenacity:CreateNotification(module.Name, component.Name..' '..(not component.Enabled and "<font color='#00AA00'>ON</font>" or "<font color='#FF5A5A'>OFF</font>"), 1.5)
											end

											component:Toggle()
										end
									else
										if tenacity.SettingToggleNotifications.Enabled then
											tenacity:CreateNotification(module.Name, component.Name..' '..(not component.Enabled and "<font color='#00AA00'>ON</font>" or "<font color='#FF5A5A'>OFF</font>"), 1.5)
										end

										component:Toggle()
									end
								end))

								table.insert(settingConnections, component.Object.MouseEnter:Connect(function()
									bind:SetVisible(true)
								end))

								table.insert(settingConnections, component.Object.MouseLeave:Connect(function()
									bind:SetVisible(false)
								end))
							end
						end
					end
				end
			else
				for _, container in {tenacity.Modules, tenacity.Auxiliary.Modules} do
					for _, module in container do
						for _, component in module.Options do
							if component.Bind then
								component.Bind:Destroy()
							end
						end
					end
				end

				for _, connection in settingConnections do
					connection:Disconnect()
				end
				table.clear(settingConnections)
			end
		end,
		Tooltip = 'Hover a toggle setting to bind it to a key'
	})

	function tenacity:QuickSave()
		if not self.Loaded then return end
		local ok, err = pcall(self.Save, self)
		if ok then
			self:CreateNotification('Profile', 'Saved '..self.Profile, 3)
		else
			self:CreateNotification('Profile', 'Save failed: '..tostring(err), 3, 'alert')
		end
	end
	general:CreateButton({
		Name = 'Save profile now',
		Function = function() tenacity:QuickSave() end,
		Tooltip = 'Save your current settings immediately. Shortcut: Ctrl + S while the menu is open.'
	})
	general:CreateButton({
		Name = 'Disable enabled modules',
		Function = function() tenacity:BulkDisable() end,
		Tooltip = 'Quickly turns off every currently enabled module without changing saved visibility or keybinds.'
	})
	general:CreateButton({
		Name = 'Undo bulk disable',
		Function = function() tenacity:UndoBulkDisable() end,
		Tooltip = 'Restore the last batch disabled in this profile. Hold bindings stay off until their keys are held.'
	})
	general:CreateButton({Name = 'Previous profile', Function = function() tenacity:CycleProfile(-1) end})
	general:CreateButton({Name = 'Next profile', Function = function() tenacity:CycleProfile(1) end})
	general:CreateButton({
		Name = 'Return to previous profile',
		Function = function()
			if tenacity.PreviousProfile then tenacity:SwitchProfile(tenacity.PreviousProfile) end
		end,
		Tooltip = 'Return to the setup used before the last successful switch.'
	})
	tenacity.SaveOnClose = general:CreateToggle({
		Name = 'Save when closing menu',
		Default = true,
		Tooltip = 'Save settings when the menu closes, in addition to periodic autosave'
	})
	general:CreateButton({
		Name = 'Back up current profile',
		Function = function()
			if not tenacity.Loaded then return end
			local ok, result = pcall(function()
				tenacity:Save()
				pcall(makefolder, 'tenacity/profiles/backups')
				local path = 'tenacity/profiles/backups/'..tostring(os.time())..'-'..httpService:GenerateGUID(false):sub(1, 8)..'.json'
				local snapshot = {
					Format = 1, Name = tenacity.Profile, GameId = game.GameId, PlaceId = tenacity.Place,
					GUI = httpService:JSONDecode(readfile('tenacity/profiles/'..game.GameId..'.gui.txt')),
					Profile = httpService:JSONDecode(readfile('tenacity/profiles/'..tenacity.Profile..tenacity.Place..'.txt')),
					Favorites = tenacity.Favorites
				}
				writefile(path, httpService:JSONEncode(snapshot))
				return path
			end)
			if ok then
				tenacity:CreateNotification('Profile backup', 'Saved to '..result, 6)
			else
				tenacity:CreateNotification('Profile backup', tostring(result), 6, 'alert')
			end
		end,
		Tooltip = 'Save a dated snapshot of this profile, GUI settings and favorites under profiles/backups'
	})
	general:CreateButton({
		Name = 'Reset current profile',
		Function = function()
		tenacity.Save = function() end
			if isfile('tenacity/profiles/'..tenacity.Profile..tenacity.Place..'.txt') and delfile then
				delfile('tenacity/profiles/'..tenacity.Profile..tenacity.Place..'.txt')
			end

			shared.TenacityReload = true
			if shared.TenacityDeveloper then
				loadstring(readfile('tenacity/loader.lua'), 'loader')()
			else
				assert(loadstring(shared.TenacityRuntime and shared.TenacityRuntime.Read('tenacity/loader.lua') or readfile('tenacity/loader.lua'), 'loader'))()
			end
		end,
		Tooltip = 'This will set your profile to the default settings of Tenacity'
	})

	general:CreateButton({
		Name = 'Self destruct',
		Function = function()
			tenacity:Uninject()
		end,
		Tooltip = 'Removes tenacity from the current game'
	})

	general:CreateButton({
		Name = 'Reinject',
		Function = function()
			shared.TenacityReload = true
			if shared.TenacityDeveloper then
				loadstring(readfile('tenacity/loader.lua'), 'loader')()
			else
				assert(loadstring(shared.TenacityRuntime and shared.TenacityRuntime.Read('tenacity/loader.lua') or readfile('tenacity/loader.lua'), 'loader'))()
			end
		end,
		Tooltip = 'Reloads tenacity for debugging purposes'
	})

	--[[
		Module Settings
	]]

	local modules = tenacity.Categories.Main.Settings:CreateSettingsPane({Name = 'Modules'})
	modules:CreateToggle({
		Name = 'Teams by server',
		Tooltip = 'Ignore players on your team designated by the server',
		Default = true,
		Function = function()
			if tenacity.Libraries.entity and tenacity.Libraries.entity.Running then
				tenacity.Libraries.entity.refresh()
			end
		end
	})

	modules:CreateToggle({
		Name = 'Use team color',
		Tooltip = 'Uses the TeamColor property on players for render modules',
		Default = true,
		Function = function()
			if tenacity.Libraries.entity and tenacity.Libraries.entity.Running then
				tenacity.Libraries.entity.refresh()
			end
		end
	})

	--[[
		GUI Settings
	]]

	local guipane = tenacity.Categories.Main.Settings:CreateSettingsPane({Name = 'GUI'})
	tenacity.LockLayout = guipane:CreateToggle({
		Name = 'Lock layout',
		Tooltip = 'Prevent dragging windows and overlays. Turn off to rearrange your layout.'
	})
	guipane:CreateButton({
		Name = 'Collapse all windows',
		Function = function()
			for _, category in tenacity.Categories do
				if category.ExpandedModule and category.ExpandedModule.SetExpanded then category.ExpandedModule:SetExpanded(false) end
				if category.Expanded and category.Expand then category:Expand() end
			end
		end,
		Tooltip = 'Close expanded module settings and collapse category windows without moving them.'
	})
	local advancedGUIVisible = false
	local advancedGUIOptions = {}

	local function addAdvanced(option, visibleCheck)
		advancedGUIOptions[#advancedGUIOptions + 1] = {Option = option, VisibleCheck = visibleCheck}
		if option and option.Object then option.Object.Visible = false end
		return option
	end

	local function refreshAdvancedGUI()
		for _, entry in ipairs(advancedGUIOptions) do
			local visible = advancedGUIVisible and (not entry.VisibleCheck or entry.VisibleCheck())
			if entry.Option and entry.Option.Object then entry.Option.Object.Visible = visible end
		end
	end

	-- Core appearance controls stay visible. Everything niche lives behind one button.
	tenacity.ReducedMotion = guipane:CreateToggle({
		Name = 'Reduced motion',
		Tooltip = 'Stops decorative background motion and loading-screen animations. Applies to the next launch too.'
	})
	guipane:CreateToggle({
		Name = 'Menu background',
		Default = false,
		Function = function(enabled) topographyBackground.Visible = enabled end,
		Tooltip = 'Show the subtle contour background behind your modules'
	})
	tenacity.Blur = guipane:CreateToggle({
		Name = 'Blur background',
		Function = function()
			tenacity:BlurCheck()
		end,
		Default = true,
		Tooltip = 'Blur the background of the GUI'
	})
	guipane:CreateToggle({
		Name = 'Show tooltips',
		Function = function(enabled)
			tooltip.Visible = false
			toolblur.Enabled = enabled
		end,
		Default = true,
		Tooltip = 'Show module/setting help when hovering controls'
	})

	tenacity.GUIStyle = guipane:CreateDropdown({
		Name = 'GUI Style',
		List = {'Dropdown', 'Modern', 'Compact'},
		Function = function(value)
			tenacity.GUIStyleName = table.find({'Dropdown', 'Modern', 'Compact'}, value) and value or 'Dropdown'
			if tenacity.Tenacity then tenacity.Tenacity:SetMode(tenacity.GUIStyleName) end
			tenacity:ApplyGUIStyle()
		end,
		Tooltip = 'Tenacity Dropdown, Modern sidebar, or Compact tabbed layout.'
	})

	tenacity.GradientTheme = guipane:CreateDropdown({
		Name = 'Animated theme',
		List = themeNames,
		Function = function(value)
			tenacity.ActiveThemeName = uipallet.Themes[value] and value or 'Tenacity'
			local palette = tenacity:GetThemeColors(tenacity.ActiveThemeName)
			uipallet.MainColor = palette[1] or Color3.fromRGB(12, 163, 232)
			uipallet.SecondaryColor = palette[2] or palette[1] or Color3.fromRGB(12, 232, 199)
			tenacity.ThemePhase = 0
			refreshAdvancedGUI()
			tenacity:UpdateGUI()
		end,
		Tooltip = 'Tenacity theme palettes and additional animated colors.'
	})

	local ScaleSlider = {Object = {}, Value = 1}
	tenacity.Scale = guipane:CreateToggle({
		Name = 'Auto rescale',
		Default = true,
		Function = function(callback)
			if callback then
				--scale.Scale = math.max(gui.AbsoluteSize.X / 1920, 0.6)
			else
				scale.Scale = ScaleSlider.Value
			end
			refreshAdvancedGUI()
			task.defer(clampAllCategoryWindows)
		end,
		Tooltip = 'Automatically rescales the gui using the screens resolution'
	})

	-- These are now clean defaults instead of dedicated GUI rows.
	tenacity.SingleModuleSettings = {Enabled = true}
	tenacity.SessionHint = {Enabled = false}

	tenacity.EffectUpdateRate = addAdvanced(guipane:CreateSlider({
		Name = 'FRONTLINES effect FPS', Min = 20, Max = 60, Default = 30,
		Tooltip = 'Update rate for FRONTLINES cosmetic effects. Lower values reduce visual processing cost.'
	}))

	addAdvanced(guipane:CreateToggle({
		Name = 'GUI bind indicator',
		Default = true,
		Tooltip = "Displays a message indicating your GUI upon injecting.\nI.E. 'Press RSHIFT to open GUI'"
	}))

	addAdvanced(guipane:CreateToggle({
		Name = 'Show legit mode',
		Function = function(enabled)
			clickgui.Search.Auxiliary.Visible = enabled
			clickgui.Search.AuxiliaryDivider.Visible = enabled
			clickgui.Search.TextBox.Size = UDim2.new(1, enabled and -92 or -52, 0, 37)
			clickgui.Search.TextBox.Position = UDim2.fromOffset(enabled and 50 or 10, 0)
		end,
		Default = true,
		Tooltip = 'Shows the button to switch to the legit mod menu'
	}))

	ScaleSlider = addAdvanced(guipane:CreateSlider({
		Name = 'Scale',
		Min = 0.1,
		Max = 2,
		Decimal = 10,
		Function = function(val, final)
			if final and not tenacity.Scale.Enabled then
				scale.Scale = val
				task.defer(clampAllCategoryWindows)
			end
		end,
		Default = 1,
		Darker = true,
		Visible = false
	}), function()
		return tenacity.Scale and not tenacity.Scale.Enabled
	end)

	tenacity.ThemeSpeed = addAdvanced(guipane:CreateSlider({
		Name = 'Theme animation speed',
		Min = 0.1,
		Max = 3,
		Decimal = 10,
		Default = 1,
		Tooltip = 'Controls how quickly the theme colors glide through the fixed gradient.'
	}), function()
		return tenacity:IsGradientThemeActive()
	end)

	-- Legacy rainbow timing is retained internally for ESP/Chams-style color
	-- sliders that expose their own Rainbow toggle, but it is no longer a GUI theme.
	tenacity.RainbowSpeed = {Value = 1}
	tenacity.RainbowUpdateSpeed = {Value = 60}
	tenacity.RainbowMode = {Value = 'Normal'}

	addAdvanced(guipane:CreateDropdown({
		Name = 'Search behavior',
		List = inputService.TouchEnabled and {'Pinned', 'On demand', 'Disabled'} or {'On demand', 'Pinned', 'Disabled'},
		Function = function(value)
			tenacity.SearchBar:SetMode(value)
		end,
		Tooltip = 'On demand stays hidden until / or Ctrl+F. Pinned keeps search visible. Disabled hides it completely.'
	}))

	local organizeButton = addAdvanced(guipane:CreateButton({
		Name = 'Organize GUI',
		Function = function()
			local priority = {
				GUICategory = 1,
				CombatCategory = 2,
				MovementCategory = 3,
				RenderCategory = 4,
				MiscCategory = 5,
				ExploitCategory = 6,
				PlayerCategory = 7,
				FriendsCategory = 8,
				ProfilesCategory = 9
			}
			local categories = {}
			for _, category in tenacity.Categories do
				if category.Type ~= 'Overlay' then table.insert(categories, category) end
			end
			table.sort(categories, function(a, b)
				return (priority[a.Object.Name] or 99) < (priority[b.Object.Name] or 99)
			end)
			local index = 0
			for _, category in categories do
				if category.Object.Visible then
					category.Object.Position = UDim2.fromOffset(6 + (index % 8 * 230), 60 + (index > 7 and 360 or 0))
					index += 1
				end
			end
			task.defer(clampAllCategoryWindows)
		end,
		Tooltip = 'Neatly reflows visible category windows and keeps them on-screen.'
	}))

	addAdvanced(guipane:CreateButton({
		Name = 'Reset GUI positions',
		Function = function()
			for _, category in tenacity.Categories do
				category.Object.Position = UDim2.fromOffset(6, 42)
			end
			task.defer(clampAllCategoryWindows)
		end,
		Tooltip = 'Reset category positions back to the default starting point.'
	}))

	local advancedButton
	advancedButton = guipane:CreateButton({
		Name = 'More GUI settings',
		Function = function()
			advancedGUIVisible = not advancedGUIVisible
			refreshAdvancedGUI()
			if advancedButton and advancedButton.SetText then
				advancedButton:SetText(advancedGUIVisible and 'Hide advanced settings' or 'More GUI settings')
			end
		end,
		Tooltip = 'Show the less frequently used performance, legacy rainbow, search and layout controls.'
	})
	refreshAdvancedGUI()
	tenacity:ApplyGUIStyle()

	--[[
		Notification Settings
	]]

	local notifpane = tenacity.Categories.Main.Settings:CreateSettingsPane({Name = 'Notifications'})
	tenacity.Notifications = notifpane:CreateToggle({
		Name = 'Notifications',
		Function = function(enabled)
			if tenacity.ToggleNotifications.Object then
				tenacity.ToggleNotifications.Object.Visible = enabled
			end

			if tenacity.SettingToggleNotifications.Object then
				tenacity.SettingToggleNotifications.Object.Visible = enabled
			end
		end,
		Tooltip = 'Shows notifications',
		Default = true
	})

	tenacity.ToggleNotifications = notifpane:CreateToggle({
		Name = 'Toggle alert',
		Tooltip = 'Notifies you if a module is enabled/disabled.',
		Default = true,
		Darker = true
	})
	tenacity.SettingToggleNotifications = notifpane:CreateToggle({
		Name = 'Setting toggle alert',
		Tooltip = 'Notifies you when a bound setting is toggled.',
		Default = true,
		Darker = true
	})
	tenacity.NotificationMode = notifpane:CreateDropdown({
		Name = 'Show', List = {'All', 'Warnings only'}, Default = 'All',
		Tooltip = 'Warnings only silences routine messages while keeping warnings and errors.'
	})
	tenacity.NotificationCooldown = notifpane:CreateSlider({
		Name = 'Repeat cooldown', Min = 0, Max = 10, Default = 2, Suffix = 's',
		Tooltip = 'Suppress identical messages within this interval. Zero allows all repeats.'
	})
	tenacity.NotificationDuration = notifpane:CreateSlider({Name = 'Toast duration', Min = 0.5, Max = 2, Default = 1, Decimal = 10, Suffix = 'x'})
	tenacity.NotificationLimit = notifpane:CreateSlider({Name = 'Visible toast limit', Min = 1, Max = 6, Default = 4})
	notifpane:CreateButton({
		Name = 'Dismiss all',
		Function = function()
			notifications:ClearAllChildren()
			if tenacity.DismissIslandNotifications then tenacity:DismissIslandNotifications() end
		end
	})

	-- No user-facing solid GUI color picker. External code can still read these
	-- compatibility fields, but the interface itself is driven by Animated theme.
	tenacity.GUIColor.Rainbow = false

	tenacity.GUIBind = tenacity.Categories.Main.Settings:CreateBind({
		Name = 'Rebind GUI',
		Default = {'RightShift'},
		NoRemove = true,
		Tooltip = 'Change the bind of the GUI'
	})

	run(function()
		local keybinds = tenacity:CreateOverlay({
			Name = 'Keybind HUD', Icon = gettenacityasset('tenacity/assets/new/textgui.png'),
			Size = UDim2.fromOffset(16, 12), Position = UDim2.fromOffset(12, 180), CategorySize = 260
		})
		local session
		local frames, elapsed, fps = 0, 0, 0
		local sessionStarted = os.clock()
		session = tenacity:CreateOverlay({
			Name = 'Session stats', Icon = gettenacityasset('tenacity/assets/new/textgui.png'),
			Size = UDim2.fromOffset(16, 12), Position = UDim2.fromOffset(12, 400), CategorySize = 260,
			Function = function(enabled)
				if enabled then
					frames, elapsed = 0, 0
					session:Clean(runService.RenderStepped:Connect(function(delta)
						if not session.Object.Visible then return end
						frames += 1
						elapsed += delta
						if elapsed >= 1 then fps = math.floor(frames / elapsed + 0.5); frames, elapsed = 0, 0 end
					end))
				end
			end
		})
		local function panel(overlay, caption)
			local card = Instance.new('Frame')
			card.BackgroundColor3 = uipallet.Main
			card.BackgroundTransparency = 0.08
			card.BorderSizePixel = 0
			card.Size = UDim2.new(1, 0, 0, 52)
			card.Parent = overlay.Children
			addCorner(card, UDim.new(0, 4))
			local line = Instance.new('Frame')
			line.BorderSizePixel = 0
			line.Size = UDim2.new(1, -8, 0, 2)
			line.Position = UDim2.fromOffset(4, 0)
			line.Parent = card
			tenacity:RegisterThemeSolid(line, 'BackgroundColor3', 0.08)
			local title = Instance.new('TextLabel')
			title.BackgroundTransparency = 1
			title.Position = UDim2.fromOffset(10, 4)
			title.Size = UDim2.new(1, -20, 0, 22)
			title.FontFace = uipallet.FontSemiBold
			title.Text = caption
			title.TextSize = 12
			title.TextColor3 = uipallet.Text
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = card
			return card
		end
		local keyCard = panel(keybinds, 'Keybinds')
		local sessionCard = panel(session, 'Session')
		local activeOnly = keybinds:CreateToggle({Name = 'Active only', Tooltip = 'Show only enabled modules with assigned keyboard binds.'})
		local hideEmpty = keybinds:CreateToggle({Name = 'Hide when empty', Default = true})
		local rowLimit = keybinds:CreateSlider({Name = 'Visible rows', Min = 4, Max = 20, Default = 10})
		local rowLabels = {}
		local keyLabels = {}
		local function row(card, index)
			local label = Instance.new('TextLabel')
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromOffset(10, 26 + (index - 1) * 22)
			label.Size = UDim2.new(1, -20, 0, 22)
			label.FontFace = uipallet.Font
			label.TextSize = 12
			label.TextColor3 = color.Dark(uipallet.Text, 0.2)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.Parent = card
			return label
		end
		local statsLabel = row(sessionCard, 1)
		statsLabel.Size = UDim2.new(1, -20, 0, 66)
		statsLabel.TextYAlignment = Enum.TextYAlignment.Top
		statsLabel.TextWrapped = true
		sessionCard.Size = UDim2.new(1, 0, 0, 96)
		local pingEnabled = session:CreateToggle({Name = 'Show ping', Default = true})
		session:CreateButton({Name = 'Reset session timer', Function = function() sessionStarted = os.clock() end})
		local statsService = game:GetService('Stats')
		tenacity:Clean(task.spawn(function()
			while tenacity.Loaded ~= nil do
				if keybinds.Button.Enabled and keybinds.Object.Visible then
					local rows = tenacity:GetKeybindRows(activeOnly.Enabled)
					keyCard.Visible = #rows > 0 or not hideEmpty.Enabled or clickgui.Visible
					local count = math.min(#rows, rowLimit.Value)
					local displayed = math.max(1, count + (#rows > count and 1 or 0))
					for index = 1, displayed do
						local label = rowLabels[index]
						if not label then
							label = row(keyCard, index)
							rowLabels[index] = label
							local keys = row(keyCard, index)
							keys.Position = UDim2.new(0.52, 0, 0, 26 + (index - 1) * 22)
							keys.Size = UDim2.new(0.48, -10, 0, 22)
							keys.TextXAlignment = Enum.TextXAlignment.Right
							keyLabels[index] = keys
							addTooltip(label, 'Assigned binding', function() return label:GetAttribute('FullText') or '' end)
							addTooltip(keys, 'Assigned binding', function() return label:GetAttribute('FullText') or '' end)
						end
						local item = rows[index]
						local text, tint
						if index > count then
							text = #rows == 0 and 'No assigned keybinds' or '+'..(#rows - count)..' more binds'
							tint = color.Dark(uipallet.Text, 0.35)
							label.Size = UDim2.new(1, -20, 0, 22)
							keyLabels[index].Visible = false
						else
							text = (item.Enabled and 'ON  ' or 'OFF  ')..item.Name
							tint = item.Enabled and tenacity:GetThemeColor(0.08) or color.Dark(uipallet.Text, 0.3)
							label.Size = UDim2.new(0.52, -16, 0, 22)
							keyLabels[index].Text = item.Keys..(item.Hold and ' · hold' or '')
							keyLabels[index].TextColor3 = tint
							keyLabels[index].Visible = true
						end
						label:SetAttribute('FullText', text..(index <= count and (' ['..item.Keys..']'..(item.Hold and ' (hold)' or '')) or ''))
						if label.Text ~= text then label.Text = text end
						label.TextColor3 = tint
						label.Visible = true
					end
					for index = displayed + 1, #rowLabels do rowLabels[index].Visible = false; keyLabels[index].Visible = false end
					keyCard.Size = UDim2.new(1, 0, 0, 30 + displayed * 22)
				end
				if session.Button.Enabled and session.Object.Visible then
					local seconds = math.floor(os.clock() - sessionStarted)
					local ping = ''
					if pingEnabled.Enabled then
						local ok, value = pcall(function() return statsService.Network.ServerStatsItem['Data Ping']:GetValue() end)
						ping = '  ·  '..(ok and type(value) == 'number' and math.floor(value + 0.5)..' ms' or 'Ping unavailable')
					end
					local text = string.format('%02d:%02d:%02d', seconds // 3600, seconds // 60 % 60, seconds % 60)
						..'  ·  '..fps..' FPS'..ping..'\nProfile: '..tostring(tenacity.Profile)..'\nLast save: '..(tenacity.LastSaved or 'Not saved this session')
					if statsLabel.Text ~= text then statsLabel.Text = text end
				end
				task.wait(0.5)
			end
		end))
		keybinds.Button:Toggle()
		keybinds:Pin()
		keybinds:Update()
	end)

	run(function()
		local Sort
		local FontOption
		local Scale
		local Shadow
		local Gradient
		local GradientStyle
		local Animations
		local Watermark
		local Background
		local BackgroundTransparency
		local BackgroundTint
		local HideModules
		local HideModulesList
		local HideRender
		local CustomText
		local CustomTextBox
		local CustomTextFont
		local Labels = {}
		local info = TweenInfo.new(0.3, Enum.EasingStyle.Exponential)

		local function findValidLabel(labels, index, dir)
			local label = labels[index + dir]
			if label then
				if label.Size ~= UDim2.fromOffset() then
					return label
				else
					return findValidLabel(labels, index + dir, dir)
				end
			end
		end

		TextGUI = tenacity:CreateOverlay({
			Name = 'Text GUI',
			Icon = gettenacityasset('tenacity/assets/new/textgui.png'),
			Size = UDim2.fromOffset(16, 12),
			Position = UDim2.fromOffset(12, 14),
			Function = function()
				tenacity:UpdateTextGUI()
			end
		})
		Sort = TextGUI:CreateDropdown({
			Name = 'Sort',
			List = {'Alphabetical', 'Length'},
			Function = function()
				tenacity:UpdateTextGUI()
			end
		})
		FontOption = TextGUI:CreateFont({
			Name = 'Font',
			Default = 'Arial',
			Function = function()
				tenacity:UpdateTextGUI()
			end
		})
		-- Text GUI color is inherited from the active animated theme.
		TextGUI:CreateSlider({
			Name = 'Scale',
			Min = 0.5,
			Max = 2,
			Decimal = 10,
			Default = 1,
			Function = function(val)
				if Scale then Scale.Scale = math.clamp(val, 0.5, 2) end
				tenacity:UpdateTextGUI()
			end
		})
		Shadow = TextGUI:CreateToggle({
			Name = 'Shadow',
			Tooltip = 'Renders shadowed text.',
			Function = function()
				tenacity:UpdateTextGUI()
			end
		})
		Gradient = {Enabled = true}
		GradientStyle = {Enabled = true, Object = {Visible = false}}

		Animations = TextGUI:CreateToggle({
			Name = 'Animations',
			Tooltip = 'Use animations on text gui',
			Function = function()
				tenacity:UpdateTextGUI()
			end
		})
		Watermark = TextGUI:CreateToggle({
			Name = 'Watermark',
			Tooltip = 'Renders a tenacity watermark',
			Function = function()
				tenacity:UpdateTextGUI()
			end
		})
		Background = TextGUI:CreateToggle({
			Name = 'Render background',
			Function = function(callback)
				BackgroundTransparency.Object.Visible = callback
				BackgroundTint.Object.Visible = callback
				tenacity:UpdateTextGUI()
			end
		})
		BackgroundTransparency = TextGUI:CreateSlider({
			Name = 'Transparency',
			Min = 0,
			Max = 1,
			Default = 0.5,
			Decimal = 10,
			Function = function()
				tenacity:UpdateTextGUI()
			end,
			Darker = true,
			Visible = false
		})
		BackgroundTint = TextGUI:CreateToggle({
			Name = 'Tint',
			Function = function()
				tenacity:UpdateTextGUI()
			end,
			Darker = true,
			Visible = false
		})
		HideModules = TextGUI:CreateToggle({
			Name = 'Hide modules',
			Tooltip = 'Allows you to blacklist certain modules from being shown.',
			Function = function(enabled)
				HideModulesList.Object.Visible = enabled
				tenacity:UpdateTextGUI()
			end
		})
		HideModulesList = TextGUI:CreateTextList({
			Name = 'Blacklist',
			Tooltip = 'Name of module to hide.',
			Color = Color3.fromRGB(250, 50, 56),
			Function = function()
				tenacity:UpdateTextGUI()
			end,
			Visible = false,
			Darker = true
		})
		HideRender = TextGUI:CreateToggle({
			Name = 'Hide render',
			Function = function()
				tenacity:UpdateTextGUI()
			end
		})
		CustomText = TextGUI:CreateToggle({
			Name = 'Add custom text',
			Function = function(enabled)
				CustomTextBox.Object.Visible = enabled
				CustomTextFont.Object.Visible = enabled
				tenacity:UpdateTextGUI()
			end
		})
		CustomTextBox = TextGUI:CreateTextBox({
			Name = 'Custom text',
			Function = function()
				tenacity:UpdateTextGUI()
			end,
			Darker = true,
			Visible = false
		})
		CustomTextFont = TextGUI:CreateFont({
			Name = 'Custom Font',
			Default = 'Arial',
			Function = function()
				tenacity:UpdateTextGUI()
			end,
			Darker = true,
			Visible = false
		})
		-- Custom text also follows the active animated theme.



		--[[
			Text GUI Objects
		]]

		Scale = Instance.new('UIScale')
		Scale.Parent = TextGUI.Children
		local Logo = Instance.new('ImageLabel')
		Logo.BackgroundColor3 = Color3.new()
		Logo.BackgroundTransparency = 1
		Logo.BorderSizePixel = 0
		Logo.Image = gettenacityasset('tenacity/assets/tenacity/modernlogobigger.png')
		Logo.Name = 'Logo'
		Logo.Position = UDim2.new(1, -142, 0, 3)
		Logo.Size = UDim2.fromOffset(81, 24)
		Logo.Visible = false
		Logo.Parent = TextGUI.Children
		local LogoEdition = Instance.new('ImageLabel')
		LogoEdition.BackgroundColor3 = Color3.new()
		LogoEdition.BackgroundTransparency = 1
		LogoEdition.BorderSizePixel = 0
		LogoEdition.Image = ''; LogoEdition.Visible = false
		LogoEdition.Name = 'Logo2'
		LogoEdition.Position = UDim2.new(1, -1, 0, 0)
		LogoEdition.Size = UDim2.fromOffset(35, 24)
		LogoEdition.Parent = Logo
		local LogoShadow = Logo:Clone()
		LogoShadow.ImageColor3 = Color3.new()
		LogoShadow.ImageTransparency = 0.65
		LogoShadow.Position = UDim2.fromOffset(1, 1)
		LogoShadow.Visible = true
		LogoShadow.ZIndex = 0
		LogoShadow.Parent = Logo
		LogoShadow.Logo2.ImageColor3 = Color3.new()
		LogoShadow.Logo2.ImageTransparency = 0.65
		LogoShadow.Logo2.ZIndex = 0
		local LogoGradient = Instance.new('UIGradient')
		LogoGradient.Rotation = 90
		LogoGradient.Parent = Logo
		local LogoGradient2 = Instance.new('UIGradient')
		LogoGradient2.Rotation = 90
		LogoGradient2.Parent = LogoEdition
		local LabelCustom = Instance.new('TextLabel')
		LabelCustom.BackgroundTransparency = 1
		LabelCustom.BorderSizePixel = 0
		LabelCustom.FontFace = CustomTextFont.Value
		LabelCustom.Position = UDim2.fromOffset(5, 2)
		LabelCustom.Text = ''
		LabelCustom.TextSize = 25
		LabelCustom.Visible = false
		LabelCustom.RichText = true
		local LabelCustomShadow = LabelCustom:Clone()
		LabelCustomShadow.TextColor3 = Color3.new()
		LabelCustomShadow.TextTransparency = 0.65
		LabelCustomShadow.Parent = TextGUI.Children
		LabelCustom.Parent = TextGUI.Children
		local LabelHolder = Instance.new('Frame')
		LabelHolder.Name = 'Holder'
		LabelHolder.Size = UDim2.fromScale(1, 1)
		LabelHolder.Position = UDim2.fromOffset(5, 37)
		LabelHolder.BackgroundTransparency = 1
		LabelHolder.Parent = TextGUI.Children
		local ListLayout = Instance.new('UIListLayout')
		ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		ListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ListLayout.Parent = LabelHolder

		LabelCustom:GetPropertyChangedSignal('Position'):Connect(function()
			LabelCustomShadow.Position = UDim2.new(
				LabelCustom.Position.X.Scale,
				LabelCustom.Position.X.Offset + 1,
				0,
				LabelCustom.Position.Y.Offset + 1
			)
		end)

		LabelCustom:GetPropertyChangedSignal('FontFace'):Connect(function()
			LabelCustomShadow.FontFace = LabelCustom.FontFace
		end)

		LabelCustom:GetPropertyChangedSignal('Text'):Connect(function()
			LabelCustomShadow.Text = LabelCustom.ContentText
		end)

		LabelCustom:GetPropertyChangedSignal('Size'):Connect(function()
			LabelCustomShadow.Size = LabelCustom.Size
		end)

		local oldRight = TextGUI.Children.AbsolutePosition.X > (gui.AbsoluteSize.X / 2)
		tenacity:Clean(TextGUI.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			local isRight = TextGUI.Children.AbsolutePosition.X > (gui.AbsoluteSize.X / 2)
			if oldRight ~= isRight then
				tenacity:UpdateTextGUI()
				oldRight = isRight
			end
		end))

		function tenacity:UpdateTextGUI(afterload)
			if not afterload and not tenacity.Loaded then return end
			if TextGUI.Button.Enabled then
				local isRight = TextGUI.Children.AbsolutePosition.X > (gui.AbsoluteSize.X / 2)

				Logo.Visible = Watermark.Enabled
				Logo.Position = isRight and UDim2.new(1 / Scale.Scale, -115, 0, 6) or UDim2.fromOffset(0, 6)
				LogoShadow.Visible = Shadow.Enabled
				LabelCustom.Text = CustomTextBox.Value
				LabelCustom.FontFace = CustomTextFont.Value
				LabelCustom.Visible = LabelCustom.Text ~= '' and CustomText.Enabled
				LabelCustomShadow.Visible = LabelCustom.Visible and Shadow.Enabled
				ListLayout.HorizontalAlignment = isRight and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
				LabelHolder.Size = UDim2.fromScale(1 / Scale.Scale, 1)
				LabelHolder.Position = UDim2.fromOffset(isRight and 3 or 0, 11 + (Logo.Visible and Logo.Size.Y.Offset or 0) + (LabelCustom.Visible and 28 or 0) + (Background.Enabled and 3 or 0))

				if LabelCustom.Visible then
					local size = getfontbounds(LabelCustom.ContentText, LabelCustom.TextSize, LabelCustom.FontFace)
					LabelCustom.Size = UDim2.fromOffset(size.X, size.Y)
					LabelCustom.Position = UDim2.new(isRight and 1 / Scale.Scale or 0, isRight and -size.X or 0, 0, (Logo.Visible and 32 or 8))
				end

				local Previous = {}
				for _, label in Labels do
					if label.Enabled then
						table.insert(Previous, label.Object.Name)
					end

					label.Object:Destroy()
				end
				table.clear(Labels)

				for name, module in tenacity.Modules do
					if HideModules.Enabled and table.find(HideModulesList.ListEnabled, name) then
						continue
					end

					if HideRender.Enabled and module.Category == 'Render' then
						continue
					end

					if module.Enabled or table.find(Previous, name) then
						local bkg, colorline
						local holder = Instance.new('Frame')
						holder.BackgroundTransparency = 1
						holder.ClipsDescendants = true
						holder.Name = name
						holder.Size = UDim2.fromOffset()
						holder.Parent = LabelHolder

						if Background.Enabled then
							bkg = Instance.new('Frame')
							bkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.15)
							bkg.BackgroundTransparency = BackgroundTransparency.Value
							bkg.BorderSizePixel = 0
							bkg.Size = UDim2.new(1, 0, 1, 0)
							bkg.Parent = holder
							local corner = Instance.new('UICorner')
							corner.Parent = bkg
							local line = Instance.new('Frame')
							line.BackgroundColor3 = Color3.new()
							line.BackgroundTransparency = 0.928 + (0.072 * math.clamp((BackgroundTransparency.Value - 0.5) / 0.5, 0, 1))
							line.BorderSizePixel = 0
							line.Position = UDim2.new(0, 0, 1, -1)
							line.Size = UDim2.new(1, 0, 0, 1)
							line.Parent = bkg
							local line2 = line:Clone()
							line2.Position = UDim2.new()
							line2.Name = 'Line'
							line2.Parent = bkg
							colorline = Instance.new('Frame')
							colorline.BorderSizePixel = 0
							colorline.Position = isRight and UDim2.new(1, -4, 0, 0) or UDim2.new()
							colorline.Size = UDim2.new(0, 4, 1, 0)
							colorline.Parent = bkg
							local colorcorner = Instance.new('UICorner')
							colorcorner.CornerRadius = UDim.new()
							colorcorner.Parent = colorline
						end

						local label = Instance.new('TextLabel')
						label.BackgroundTransparency = 1
						label.BorderSizePixel = 0
						label.FontFace = FontOption.Value
						label.Position = UDim2.fromOffset(isRight and 5 or 9, 2)
						label.Text = name..(module.ExtraText and " <font color='#A8A8A8'>"..module.ExtraText()..'</font>' or '')
						label.TextSize = 18
						label.RichText = true

						local size = getfontbounds(label.ContentText, label.TextSize, label.FontFace)
						label.Size = UDim2.fromOffset(size.X, size.Y)

						if Shadow.Enabled then
							local shadowlabel = label:Clone()
							shadowlabel.Position = UDim2.fromOffset(label.Position.X.Offset + 1, label.Position.Y.Offset + 1)
							shadowlabel.Text = label.ContentText
							shadowlabel.TextColor3 = Color3.new()
							shadowlabel.Parent = holder
						end

						label.Parent = holder

						local tweenSize = UDim2.fromOffset(size.X + 16, size.Y + 6)
						if Animations.Enabled then
							if not table.find(Previous, name) then
								tween:Tween(holder, info, {
									Size = tweenSize
								})
							else
								holder.Size = tweenSize
								if not module.Enabled then
									tween:Tween(holder, info, {
										Size = UDim2.fromOffset()
									})
								end
							end
						else
							holder.Size = module.Enabled and tweenSize or UDim2.fromOffset()
						end

						table.insert(Labels, {
							Background = bkg,
							Color = colorline,
							Enabled = module.Enabled,
							Object = holder,
							Text = label,
							Size = module.Enabled and tweenSize or UDim2.fromOffset()
						})
					end
				end

				if Sort.Value == 'Alphabetical' then
					table.sort(Labels, function(a, b)
						return a.Text.Text < b.Text.Text
					end)
				else
					table.sort(Labels, function(a, b)
						return a.Text.Size.X.Offset > b.Text.Size.X.Offset
					end)
				end

				for index, label in Labels do
					if label.Color then
						local topLabel = findValidLabel(Labels, index, -1)
						local bottomLabel = findValidLabel(Labels, index, 1)
						local top = (not topLabel or (topLabel.Size.X.Offset < label.Size.X.Offset)) and 4 or 0
						local bottom = (not bottomLabel or (bottomLabel.Size.X.Offset < label.Size.X.Offset)) and 4 or 0

						label.Color.Parent.Line.Visible = index ~= 1
						label.Color.UICorner.TopLeftRadius = isRight and UDim.new() or UDim.new(0, index == 1 and 4 or 0)
						label.Color.UICorner.TopRightRadius = isRight and UDim.new(0, index == 1 and 4 or 0) or UDim.new()
						label.Color.UICorner.BottomLeftRadius = isRight and UDim.new() or UDim.new(0, index == #Labels and 4 or 0)
						label.Color.UICorner.BottomRightRadius = isRight and UDim.new(0, index == #Labels and 4 or 0) or UDim.new()

						label.Background.UICorner.TopLeftRadius = UDim.new(0, top)
						label.Background.UICorner.TopRightRadius = UDim.new(0, top)
						label.Background.UICorner.BottomLeftRadius = UDim.new(0, bottom)
						label.Background.UICorner.BottomRightRadius = UDim.new(0, bottom)
					end

					label.Object.LayoutOrder = index
				end
			end

			self:UpdateGUI()
		end

		function TextGUI:UpdateColor(hue, sat, val, default)
			-- Keep the wordmark neutral; only the version badge carries the accent.
			LogoGradient.Enabled = false
			Logo.ImageColor3 = uipallet.Text
			LogoGradient2.Enabled = false
			tenacity:RegisterThemeSolid(LogoEdition, 'ImageColor3', 0.08)
			tenacity:ApplyThemeGradient(LabelCustom, 'TextColor3', 0.12, CustomText.Enabled, 0)

			for index, label in Labels do
				local offset = ((index - 1) * 0.035) % 1
				tenacity:ApplyThemeGradient(label.Text, 'TextColor3', offset, true, 0)

				if label.Color then
					tenacity:ApplyThemeGradient(label.Color, 'BackgroundColor3', offset, true, 0)
				end

				if BackgroundTint.Enabled and label.Background then
					label.Background.BackgroundColor3 = color.Dark(tenacity:GetThemeColor(offset), 0.75)
				end
			end
		end
	end)

	run(function()
		--[[
			Target Info
		]]

		local targetinfo = {
			Targets = {},
			Object = Holder,
			Health = 0,
			MaxHealth = 0
		}
		local TargetInfoOverlay
		local BackgroundTransparency = {
			Value = 0.5,
			Object = {Visible = {}}
		}
		local DisplayName
		local Mode

		TargetInfoOverlay = tenacity:CreateOverlay({
			Name = 'Target Info',
			Icon = gettenacityasset('tenacity/assets/new/targetinfo.png'),
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(12, 14),
			CategorySize = 240,
			Function = function(callback)
				if callback then
					TargetInfoOverlay:Clean(runService.RenderStepped:Connect(function()
						targetinfo:Update()
					end))
				end
			end
		})

		local Holder = Instance.new('Frame')
		Holder.Size = UDim2.fromOffset(240, 89)
		Holder.BackgroundColor3 = color.Dark(uipallet.Main, 0.1)
		Holder.BackgroundTransparency = 0.5
		Holder.Parent = TargetInfoOverlay.Children
		local BlurHolder = addBlur(Holder, nil, true)
		BlurHolder.Visible = false
		addCorner(Holder)
		local Headshot = Instance.new('ImageLabel')
		Headshot.Size = UDim2.fromOffset(26, 27)
		Headshot.Position = UDim2.fromOffset(19, 17)
		Headshot.BackgroundColor3 = uipallet.Main
		Headshot.Image = 'rbxthumb://type=AvatarHeadShot&id=1&w=420&h=420'
		Headshot.Parent = Holder
		addCorner(Headshot)
		local HurtFlash = Instance.new('Frame')
		HurtFlash.Size = UDim2.fromScale(1, 1)
		HurtFlash.BackgroundTransparency = 1
		HurtFlash.BackgroundColor3 = Color3.new(1, 0, 0)
		HurtFlash.Parent = Headshot
		addCorner(HurtFlash)
		local HeadshotBlur = addBlur(Headshot)
		HeadshotBlur.Enabled = false
		local Name = Instance.new('TextLabel')
		Name.Size = UDim2.fromOffset(145, 20)
		Name.Position = UDim2.fromOffset(54, 20)
		Name.BackgroundTransparency = 1
		Name.Text = 'Target name'
		Name.TextXAlignment = Enum.TextXAlignment.Left
		Name.TextYAlignment = Enum.TextYAlignment.Top
		Name.TextScaled = true
		Name.TextColor3 = color.Light(uipallet.Text, 0.4)
		Name.TextStrokeTransparency = 1
		Name.FontFace = uipallet.Font
		local NameShadow = Name:Clone()
		NameShadow.Position = UDim2.fromOffset(55, 21)
		NameShadow.TextColor3 = Color3.new()
		NameShadow.TextTransparency = 0.65
		NameShadow.Visible = false
		NameShadow.Parent = Holder
		for _, prop in {'Size', 'Text', 'FontFace'} do
			Name:GetPropertyChangedSignal(prop):Connect(function()
				NameShadow[prop] = Name[prop]
			end)
		end
		Name.Parent = Holder
		local HealthBKG = Instance.new('Frame')
		HealthBKG.Name = 'HealthBKG'
		HealthBKG.Size = UDim2.fromOffset(200, 9)
		HealthBKG.Position = UDim2.fromOffset(20, 56)
		HealthBKG.BackgroundColor3 = uipallet.Main
		HealthBKG.BorderSizePixel = 0
		HealthBKG.Parent = Holder
		addCorner(HealthBKG, UDim.new(1, 0))
		local Health = HealthBKG:Clone()
		Health.Size = UDim2.fromScale(0.8, 1)
		Health.Position = UDim2.new()
		Health.BackgroundColor3 = Color3.fromHSV(1 / 2.5, 0.89, 0.75)
		Health.Parent = HealthBKG
		Health:GetPropertyChangedSignal('Size'):Connect(function()
			Health.Visible = Health.Size.X.Scale > 0.01
		end)
		local Armor = Health:Clone()
		Armor.Size = UDim2.new()
		Armor.Position = UDim2.fromScale(1, 0)
		Armor.AnchorPoint = Vector2.new(1, 0)
		Armor.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
		Armor.Visible = false
		Armor.Parent = HealthBKG
		Armor:GetPropertyChangedSignal('Size'):Connect(function()
			Armor.Visible = Armor.Size.X.Scale > 0.01
		end)
		local HealthBlur = addBlur(HealthBKG)
		HealthBlur.Enabled = false
		local Stroke = Instance.new('UIStroke')
		Stroke.Enabled = false
		Stroke.Color = Color3.fromHSV(0.44, 1, 1)
		Stroke.Parent = Holder

		local ModernGlowOuter = Instance.new('UIStroke')
		ModernGlowOuter.Name = 'ModernGlowOuter'
		ModernGlowOuter.Thickness = 9
		ModernGlowOuter.Transparency = 0.82
		ModernGlowOuter.Enabled = false
		ModernGlowOuter.Parent = Holder
		local ModernGlow = Instance.new('UIStroke')
		ModernGlow.Name = 'ModernGlow'
		ModernGlow.Thickness = 4
		ModernGlow.Transparency = 0.58
		ModernGlow.Enabled = false
		ModernGlow.Parent = Holder
		local ModernAccent = Instance.new('Frame')
		ModernAccent.Name = 'ModernAccent'
		ModernAccent.Position = UDim2.fromOffset(0, 14)
		ModernAccent.Size = UDim2.new(0, 3, 1, -28)
		ModernAccent.BorderSizePixel = 0
		ModernAccent.Visible = false
		ModernAccent.Parent = Holder
		addCorner(ModernAccent, UDim.new(1, 0))
		local Status = Instance.new('TextLabel')
		Status.Name = 'Status'
		Status.Position = UDim2.fromOffset(84, 43)
		Status.Size = UDim2.fromOffset(180, 14)
		Status.BackgroundTransparency = 1
		Status.Text = 'Same'
		Status.TextSize = 11
		Status.TextXAlignment = Enum.TextXAlignment.Left
		Status.TextColor3 = color.Light(uipallet.Text, 0.28)
		Status.FontFace = uipallet.FontSemiBold
		Status.Visible = false
		Status.Parent = Holder
		local AvatarStroke = Instance.new('UIStroke')
		AvatarStroke.Thickness = 1.5
		AvatarStroke.Transparency = 0.12
		AvatarStroke.Enabled = false
		AvatarStroke.Parent = Headshot
		local HealthGlow = Instance.new('UIStroke')
		HealthGlow.Thickness = 3
		HealthGlow.Transparency = 0.68
		HealthGlow.Enabled = false
		HealthGlow.Parent = HealthBKG

		tenacity:RegisterThemeSolid(ModernGlowOuter, 'Color', 0.04)
		tenacity:RegisterThemeSolid(ModernGlow, 'Color', 0.08)
		tenacity:RegisterThemeSolid(ModernAccent, 'BackgroundColor3', 0.12)
		tenacity:RegisterThemeSolid(AvatarStroke, 'Color', 0.16)
		tenacity:RegisterThemeSolid(HealthGlow, 'Color', 0.20)

		local function applyTargetMode(val)
			local modern = val == 'Modern'
			Holder.Size = modern and UDim2.fromOffset(304, 100) or UDim2.fromOffset(240, 89)
			Headshot.Size = modern and UDim2.fromOffset(58, 58) or UDim2.fromOffset(26, 27)
			Headshot.Position = modern and UDim2.fromOffset(14, 18) or UDim2.fromOffset(19, 17)
			Name.Size = modern and UDim2.fromOffset(190, 22) or UDim2.fromOffset(145, 20)
			Name.Position = modern and UDim2.fromOffset(84, 19) or UDim2.fromOffset(54, 20)
			Name.TextXAlignment = Enum.TextXAlignment.Left
			Name.TextYAlignment = modern and Enum.TextYAlignment.Center or Enum.TextYAlignment.Top
			HealthBKG.Size = modern and UDim2.fromOffset(200, 9) or UDim2.fromOffset(200, 9)
			HealthBKG.Position = modern and UDim2.fromOffset(84, 63) or UDim2.fromOffset(20, 56)
			ModernGlowOuter.Enabled = modern
			ModernGlow.Enabled = modern
			ModernAccent.Visible = modern
			Status.Visible = modern
			AvatarStroke.Enabled = modern
			HealthGlow.Enabled = modern
			NameShadow.Visible = false
			targetinfo.Object = Holder
		end

		Mode = TargetInfoOverlay:CreateDropdown({
			Name = 'Mode',
			List = {'Classic', 'Modern'},
			Function = applyTargetMode
		})

		TargetInfoOverlay:CreateFont({
			Name = 'Font',
			Default = 'Arial',
			Function = function(val)
				Name.FontFace = val
			end
		})
		DisplayName = TargetInfoOverlay:CreateToggle({
			Name = 'Use Displayname',
			Default = true
		})
		TargetInfoOverlay:CreateToggle({
			Name = 'Render Background',
			Function = function(callback)
				Holder.BackgroundTransparency = callback and BackgroundTransparency.Value or 1
				NameShadow.Visible = not callback and Mode.Value ~= 'Modern'
				BlurHolder.Visible = callback
				HealthBlur.Enabled = not callback
				HeadshotBlur.Enabled = not callback
				BackgroundTransparency.Object.Visible = callback
			end,
			Default = true
		})
		BackgroundTransparency = TargetInfoOverlay:CreateSlider({
			Name = 'Transparency',
			Min = 0,
			Max = 1,
			Default = 0.5,
			Decimal = 10,
			Function = function(val)
				Holder.BackgroundTransparency = val
			end,
			Darker = true
		})
		-- Target HUD surfaces inherit the active animated theme.

		TargetInfoOverlay:CreateToggle({
			Name = 'Border',
			Function = function(callback)
				Stroke.Enabled = callback
				if callback then
					tenacity:RegisterThemeSolid(Stroke, 'Color', 0.16)
				else
					tenacity:UnregisterThemeSolid(Stroke)
				end
			end
		})

		-- The card itself uses the theme continuously; health keeps its semantic
		-- red/green coloring so it remains readable at a glance.
		tenacity:ApplyThemeGradient(Holder, 'BackgroundColor3', 0.02, true, 0)
		tenacity:RegisterThemeSolid(Headshot, 'BackgroundColor3', 0.10)
		tenacity:ApplyThemeGradient(HealthBKG, 'BackgroundColor3', 0.10, true, 0)

		applyTargetMode(Mode.Value)


		function targetinfo:Update()
			local entitylib = tenacity.Libraries
			if not entitylib then return end

			local cloned = table.clone(self.Targets)
			for index, expire in cloned do
				if expire < tick() then
					self.Targets[index] = nil
				end
			end
			table.clear(cloned)

			local entity, highest = nil, tick()
			for index, level in self.Targets do
				if level > highest then
					entity = index
					highest = level
				end
			end

			Holder.Visible = entity ~= nil or clickgui.Visible
			if entity then
				Name.Text = entity.Player and (DisplayName.Enabled and entity.Player.DisplayName or entity.Player.Name) or entity.Character and entity.Character.Name or Name.Text
				Headshot.Image = 'rbxthumb://type=AvatarHeadShot&id='..(entity.Player and entity.Player.UserId or 1)..'&w=420&h=420'

				if Mode.Value == 'Modern' then
					local glowPulse = (math.sin(os.clock() * 3.2) + 1) * 0.5
					ModernGlow.Transparency = 0.50 + (glowPulse * 0.16)
					ModernGlowOuter.Transparency = 0.76 + (glowPulse * 0.14)
					local targetPercent = math.clamp((entity.Health or 0) / math.max(entity.MaxHealth or 100, 1), 0, 1)
					local entlib = tenacity.Libraries.entity
					local localHum = entlib and entlib.character and entlib.character.Humanoid
					local localPercent = localHum and math.clamp(localHum.Health / math.max(localHum.MaxHealth, 1), 0, 1) or targetPercent
					local delta = localPercent - targetPercent
					Status.Text = delta > 0.08 and 'Winning  •  '..math.round((entity.Health or 0))..' HP' or delta < -0.08 and 'Losing  •  '..math.round((entity.Health or 0))..' HP' or 'Same  •  '..math.round((entity.Health or 0))..' HP'
				end

				if not entity.Character then
					entity.Health = entity.Health or 0
					entity.MaxHealth = entity.MaxHealth or 100
				end

				if entity.Health ~= self.Health or entity.MaxHealth ~= self.MaxHealth then
					local percent = math.max(entity.Health / entity.MaxHealth, 0)

					tween:Tween(Health, TweenInfo.new(0.3), {
						Size = UDim2.fromScale(math.min(percent, 1), 1), BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
					})

					tween:Tween(Armor, TweenInfo.new(0.3), {
						Size = UDim2.fromScale(math.clamp(percent - 1, 0, 0.8), 1)
					})

					if self.Health > entity.Health and self.LastTarget == entity then
						tween:Cancel(HurtFlash)
						HurtFlash.BackgroundTransparency = 0.3
						tween:Tween(HurtFlash, TweenInfo.new(0.5), {
							BackgroundTransparency = 1
						})
					end

					self.Health = entity.Health
					self.MaxHealth = entity.MaxHealth
				end

				if not entity.Character then
					table.clear(entity)
				end

				self.LastTarget = entity
			end
		end

		tenacity.Libraries.targetinfo = targetinfo
	end)

	tenacity:Clean(task.spawn(function()
		local hue = 0
		repeat
			-- ESP/Chams color rainbows are the only legacy rainbow path left. Don't
			-- wake this loop at high frequency when no render color picker is using it.
			if #tenacity.RainbowSliders == 0 then
				task.wait(0.2)
			else
				for _, component in tenacity.RainbowSliders do
					if component.Type == 'GUISlider' then
						component:SetValue(tenacity:Color(hue))
					else
						component:SetValue(hue)
					end
				end

				local delta = task.wait(1 / tenacity.RainbowUpdateSpeed.Value)
				hue = (hue + (delta * (0.2 * tenacity.RainbowSpeed.Value))) % 1
			end
		until false
	end))

	tenacity:Clean(task.spawn(function()
		local gradientAccumulator = 0
		repeat
			local delta = runService.RenderStepped:Wait()
			if tenacity:IsGradientThemeActive() then
				local reduced = tenacity.ActiveThemeName == 'Tenacity' or (tenacity.ReducedMotion and tenacity.ReducedMotion.Enabled)
				if not reduced then
					-- One full palette pass takes ~13 seconds at 1x. Slow enough to look
					-- premium, while the slider can still speed it up for louder themes.
					tenacity.ThemePhase = ((tenacity.ThemePhase or 0) + (delta * 0.075 * (tenacity.ThemeSpeed and tenacity.ThemeSpeed.Value or 1))) % 1
				end

				local overlayActive = false
				if tenacity.Overlays and tenacity.Overlays.Options then
					for _, overlay in tenacity.Overlays.Options do
						if overlay.Object and overlay.Object.Visible then
							overlayActive = true
							break
						end
					end
				end

				local visualActive = clickgui.Visible
					or (tenacity.Auxiliary and tenacity.Auxiliary.Window and tenacity.Auxiliary.Window.Visible)
					or (TextGUI and TextGUI.Button and TextGUI.Button.Enabled)
					or overlayActive
					or next(tenacity.HUDAccentObjects) ~= nil

				gradientAccumulator += delta
				local refreshInterval = reduced and 1 or (1 / 30)
				if visualActive and gradientAccumulator >= refreshInterval then
					-- Animated palettes update at 30 Hz; static accents need only a
					-- low-frequency refresh for newly visible theme objects.
					gradientAccumulator %= refreshInterval
					tenacity:UpdateThemeGradients()
				end
			elseif next(uipallet.ThemeObjects) ~= nil then
				gradientAccumulator = 0
				tenacity:ClearThemeGradients()
			end
		until false
	end))

	local cursorConnection
	tenacity:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
		tenacity:UpdateGUI()

		if clickgui.Visible and inputService.MouseEnabled then
			if cursorConnection then
				cursorConnection:Disconnect()
			end

			cursorConnection = runService.RenderStepped:Connect(function()
				local isVisible = clickgui.Visible
				for _, window in tenacity.Windows do
					isVisible = isVisible or window.Visible
				end

				if not isVisible then
					cursor.Visible = false
					cursorConnection:Disconnect()
					cursorConnection = nil
					return
				end

				cursor.Visible = not inputService.MouseIconEnabled
				if cursor.Visible then
					local mouseLocation = inputService:GetMouseLocation()
					cursor.Position = UDim2.fromOffset(mouseLocation.X - 31, mouseLocation.Y - 32)
				end
			end)
		end
	end))

	tenacity:Clean(function()
		if cursorConnection then
			cursorConnection:Disconnect()
		end
	end)

	tenacity:Clean(gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
		if tenacity.Scale.Enabled then
			scale.Scale = math.max(gui.AbsoluteSize.X / 1920, 0.6)
		end
	end))

	tenacity:Clean(notifications.ChildRemoved:Connect(function()
		for index, notif in notifications:GetChildren() do
			if tween.Tween then
				tween:Tween(notif, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
					Position = UDim2.new(1, 0, 1, -(29 + (78 * index)))
				})
			end
		end
	end))

	tenacity:Clean(scale:GetPropertyChangedSignal('Scale'):Connect(function()
		scaledgui.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)

		for _, obj in scaledgui:QueryDescendants('GuiObject >> [Visible = true]') do
			obj.Visible = false
			obj.Visible = true
		end
		task.defer(clampAllCategoryWindows)
	end))

	tenacity:Clean(tenacity.GUIBind.Triggered:Connect(function()
		if tenacity.ThreadFix then
			setthreadidentity(8)
		end

		for _, window in self.Windows do
			window.Visible = false
		end

		for _, module in self.Modules do
			if module.Bind.Mobile then
				module.Bind.Mobile.Visible = clickgui.Visible
			end
		end

		clickgui.Visible = not clickgui.Visible
		tenacity:BlurCheck()
		if clickgui.Visible then
			tenacity.SearchBar:Refresh()
			tenacity:ShowSessionHint()
			task.defer(clampAllCategoryWindows)
		elseif tenacity.SearchBar then
			tenacity.SearchBar:Close(false)
			if tenacity.ActiveSettingsPane and tenacity.ActiveSettingsPane.Object and tenacity.ActiveSettingsPane.Object.Visible then
				tenacity.ActiveSettingsPane:SetVisible(false)
			end
			local mainSettings = tenacity.Categories.Main and tenacity.Categories.Main.Settings
			if mainSettings and mainSettings.Object and mainSettings.Object.Visible then
				mainSettings:SetVisible(false)
			end
			for _, category in tenacity.Categories do
				local expanded = category.ExpandedModule
				if expanded and expanded.SetExpanded then expanded:SetExpanded(false) end
			end
		end
		if not clickgui.Visible and tenacity.SaveOnClose.Enabled and tenacity.Loaded then
			local ok, err = pcall(tenacity.Save, tenacity)
			if not ok then tenacity:CreateNotification('Profile', 'Save failed: '..tostring(err), 4, 'alert') end
		end
	end))

	tenacity:Clean(inputService.InputBegan:Connect(function(input)
		if tenacity.Tenacity and clickgui.Visible then
			local control=inputService:IsKeyDown(Enum.KeyCode.LeftControl) or inputService:IsKeyDown(Enum.KeyCode.RightControl)
			if tenacity.Tenacity.Binding or input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.Slash
				or (control and (input.KeyCode==Enum.KeyCode.F or input.KeyCode==Enum.KeyCode.S)) then return end
		end
		if clickgui.Visible and not tenacity.Binding then
			local focused = inputService:GetFocusedTextBox()
			local search = tenacity.SearchBar
			local control = inputService:IsKeyDown(Enum.KeyCode.LeftControl) or inputService:IsKeyDown(Enum.KeyCode.RightControl)
			if ((control and input.KeyCode == Enum.KeyCode.F) or (input.KeyCode == Enum.KeyCode.Slash and not control)) and (not focused or focused == search.Input) then
				search:Open(true)
				return
			elseif control and input.KeyCode == Enum.KeyCode.S and not focused then
				tenacity:QuickSave()
				return
			elseif input.KeyCode == Enum.KeyCode.Escape then
				if focused == search.Input then
					if search.Input.Text ~= '' then
						search.Input.Text = ''
					else
						search:Close(false)
					end
					return
				elseif search.Object.Visible and search.Mode == 'On demand' then
					search:Close(false)
					return
				elseif not focused then
					if tenacity.ActiveSettingsPane and tenacity.ActiveSettingsPane.Object and tenacity.ActiveSettingsPane.Object.Visible then
						tenacity.ActiveSettingsPane:SetVisible(false)
						return
					end
					local mainSettings = tenacity.Categories.Main and tenacity.Categories.Main.Settings
					if mainSettings and mainSettings.Object and mainSettings.Object.Visible then
						mainSettings:SetVisible(false)
						return
					end
					for _, category in tenacity.Categories do
						local expanded = category.ExpandedModule
						if expanded and expanded.SetExpanded then
							expanded:SetExpanded(false)
							return
						end
					end
					tenacity.GUIBind.Triggered:Fire()
					return
				end
			end

			if search.Object.Visible and search.Mode == 'On demand'
				and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
				and not search:IsPointInside(input.Position) then
				search:Close(false)
			end
		end
		if tenacity.CurrentTooltip and input.KeyCode == Enum.KeyCode.LeftShift then
			tenacity.CurrentTooltip()
		end

		if not inputService:GetFocusedTextBox() and input.KeyCode ~= Enum.KeyCode.Unknown then
			table.insert(tenacity.HeldKeybinds, input.KeyCode.Name)
			if tenacity.Binding then return end

			for _, bind in tenacity.ActiveBinds do
				if checkKeybinds(tenacity.HeldKeybinds, bind.Keys, input.KeyCode.Name) then
					bind.Triggered:Fire(true)
				end
			end
		end
	end))

	tenacity:Clean(inputService.InputEnded:Connect(function(input)
		if tenacity.CurrentTooltip and input.KeyCode == Enum.KeyCode.LeftShift then
			tenacity.CurrentTooltip()
		end

		if not inputService:GetFocusedTextBox() and input.KeyCode ~= Enum.KeyCode.Unknown then
			if tenacity.Binding then
				if not tenacity.MultiKeybind.Enabled then
					tenacity.HeldKeybinds = {input.KeyCode.Name}
				end

				tenacity.Binding:SetBind(tenacity.HeldKeybinds, true)
				tenacity.Binding = nil
			else
				for _, bind in tenacity.ActiveBinds do
					if bind.Hold and checkKeybinds(tenacity.HeldKeybinds, bind.Keys, input.KeyCode.Name) then
						bind.Triggered:Fire(false)
					end
				end
			end
		end

		local index = table.find(tenacity.HeldKeybinds, input.KeyCode.Name)
		if index then
			table.remove(tenacity.HeldKeybinds, index)
		end
	end))
end

function tenacity:Remove(obj)
	local container = (self.Modules[obj] and self.Modules or self.Auxiliary.Modules[obj] and self.Auxiliary.Modules or self.Categories)
	if container and container[obj] then
		local component = container[obj]
		local isModule = component.Type == 'Module'
		if self.ThreadFix then
			setthreadidentity(8)
		end

		if component.Destroy then
			component:Destroy()
		end

		for _, child in {'Object', 'Children', 'Toggle', 'Button'} do
			child = typeof(component[child]) == 'table' and component[child].Object or component[child]

			if typeof(child) == 'Instance' then
				child:Destroy()
				child:ClearAllChildren()
			end
		end

		if type(component) == 'table' then table.clear(component) end
		container[obj] = nil

		if isModule then
			self:SortCategories()
		end
	end
end

local savedProfiles = {}
local function writeProfile(path, data)
	if savedProfiles[path] == data then return end
	writefile(path, data)
	savedProfiles[path] = data
end

function tenacity:Save(newProfile)
	if self.SwitchingProfile and self.ProfileSwitchThread ~= coroutine.running() then return end
	if not self.Loaded then
		return
	end

	local guiData = {
		Categories = {},
		Profile = newProfile or self.Profile,
		v = 1
	}

	local mainData = {
		Modules = {},
		Categories = {},
		v = 1
	}

	for _, category in self.Categories do
		if category.Type ~= 'Overlay' then category:Save(guiData.Categories) end
	end

	for _, module in self.Modules do
		module:Save(mainData.Modules)
	end

	writeProfile('tenacity/profiles/'..game.GameId..'.gui.txt', httpService:JSONEncode(guiData))
	writeProfile('tenacity/profiles/'..self.Profile..self.Place..'.txt', httpService:JSONEncode(mainData))
	self:FlushRecent()
	self.LastSaved = os.date('%H:%M')
	if self.UpdateSessionHint then self:UpdateSessionHint() end
end

function tenacity:SaveOptions(obj)
	local data = {}
	for _, component in obj.Options do
		if not component.Save then
			continue
		end

		component:Save(data)
	end

	return data
end

function tenacity:SortCategories()
	local sorting = {}
	for _, module in self.Modules do
		sorting[module.Category] = sorting[module.Category] or {}
		table.insert(sorting[module.Category], module.Name)
	end

	for _, sort in sorting do
		table.sort(sort)

		local index = 2
		for _, name in sort do
			self.Modules[name].Index = index / 2
			self.Modules[name].Object.LayoutOrder = index
			self.Modules[name].Children.LayoutOrder = index + 1
			index += 2
		end
	end
end

function tenacity:Uninject()
	if self.Uninjecting then return end
	self.Uninjecting = true
	tween:CancelAll()
	self:Save()
	self.Loaded = nil

	for _, module in self.Modules do
		if module.Enabled then
			module:Toggle()
		end
	end

	for _, module in self.Auxiliary.Modules do
		if module.Enabled then
			module:Toggle()
		end
	end

	for _, category in self.Categories do
		if category.Type == 'Overlay' and category.Button.Enabled then
			category.Button:Toggle()
		end
	end

	for _, connection in self.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end

	if self.ThreadFix then
		setthreadidentity(8)
		clickgui.Visible = false
		self:BlurCheck()
	end

	if guiBlurTween then
		guiBlurTween:Cancel()
		guiBlurTween = nil
	end
	if guiBlurEffect then
		pcall(function()
			guiBlurEffect.Enabled = false
			guiBlurEffect.Size = 0
			guiBlurEffect:Destroy()
		end)
		guiBlurEffect = nil
	end

	tween:CancelAll()
	gui:ClearAllChildren()
	gui:Destroy()
	table.clear(self.Connections)
	table.clear(self.Libraries)
	-- Do not deep-clear self. Module/component graphs contain intentional cycles;
	-- disconnecting resources and releasing shared.Tenacity lets Luau's GC reclaim them.
	shared.Tenacity = nil
	shared.TenacityReload = nil
	shared.TenacityIndependent = nil
	shared.TenacityBuild = nil
end

local guiUpdate
function tenacity:UpdateGUI()
	if guiUpdate then
		return
	end

	guiUpdate = runService.RenderStepped:Once(function()
		if tenacity.Loaded ~= nil then
			tenacity:UpdateGUIQueue(tenacity.GUIColor.Hue, tenacity.GUIColor.Sat, tenacity.GUIColor.Value)
		end

		guiUpdate = nil
	end)
end

function tenacity:UpdateGUIQueue(hue, sat, val)
	local themeActive = tenacity:IsGradientThemeActive()
	local hudAccent = themeActive and tenacity:GetThemeColor(0) or Color3.fromHSV(hue, sat, val)
	if themeActive then
		hue, sat, val = hudAccent:ToHSV()
	end

	if TextGUI.Button.Enabled then
		TextGUI:UpdateColor(hue, sat, val, default)
	end

	if topographyBackground and topographyBackground.Parent then
		if not tenacity:ApplyThemeGradient(topographyBackground, 'ImageColor3', 0, true, 35) then
			topographyBackground.ImageColor3 = Color3.fromHSV(
				hue,
				math.min(sat * 0.62, 0.78),
				math.max(val, 0.78)
			)
		end
	end

	for object, property in tenacity.HUDAccentObjects do
		if object and object.Parent then
			if not tenacity:ApplyThemeGradient(object, property, 0, true, 0) then
				pcall(function()
					object[property] = hudAccent
				end)
			end
		else
			tenacity.HUDAccentObjects[object] = nil
		end
	end

	if not clickgui.Visible and not tenacity.Auxiliary.Window.Visible then return end
	local isRainbow = not themeActive and tenacity.GUIColor.Rainbow and tenacity.RainbowMode.Value ~= 'Retro'
	for name, component in tenacity.Categories do
		component:Color(hue, sat, val, isRainbow)
	end

	for _, component in tenacity.Modules do
		component:Color(hue, sat, val, isRainbow)
	end

	for _, component in tenacity.Overlays.Options do
		if component.Color then
			component:Color(hue, sat, val, isRainbow)
		end
	end

	for _, pane in tenacity.Settings do
		for _, component in pane.Options do
			if component.Color then
				component:Color(hue, sat, val, isRainbow)
			end
		end
	end

	if tenacity.Auxiliary.Window.Visible then
		for _, component in tenacity.Auxiliary.Modules do
			component:Color(hue, sat, val, isRainbow)
		end
	end
end

components = {
	Bind = function(props, children, api)
		local component = {
			Hold = props.Hold or false,
			Keys = {},
			Triggered = createSignal(),
			Type = 'Bind'
		}

		local bind = Instance.new('TextButton')
		bind.AnchorPoint = Vector2.new(1, 0)
		bind.AutoButtonColor = false
		bind.BackgroundColor3 = Color3.new(1, 1, 1)
		bind.BackgroundTransparency = 0.92
		bind.BorderSizePixel = 0
		bind.Name = 'Bind'
		bind.Size = UDim2.fromOffset(20, 20)
		bind.Visible = false
		bind.Text = ''
		addCorner(bind, UDim.new(0, 4))
		addTooltip(bind, '', function()
			local holdText = 'Bind functionality = '..(component.Hold and 'Enable while held' or 'Toggle')
			if inputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				holdText = "<font color='#FF5A5A'>"..holdText.."</font>"
			end

			return 'Click to bind\nShift click to modify bind functionality\n'..holdText
		end)
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = gettenacityasset('tenacity/assets/new/bind.png')
		icon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		icon.Name = 'Icon'
		icon.Position = UDim2.new(0.5, -5, 0, 5)
		icon.Size = UDim2.fromOffset(10, 10)
		icon.Parent = bind
		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.Font
		label.Position = UDim2.fromOffset(-1, 0)
		label.Size = UDim2.fromScale(1, 1)
		label.Text = ''
		label.TextColor3 = color.Dark(uipallet.Text, 0.43)
		label.TextSize = 12
		label.Visible = false
		label.Parent = bind
		local cover
		local coverlabel

		if props.Module then
			if props.Cover then
				cover = Instance.new('ImageLabel')
				cover.BackgroundTransparency = 1
				cover.Image = gettenacityasset('tenacity/assets/new/bindbkg.png')
				cover.Name = 'Cover'
				cover.ScaleType = Enum.ScaleType.Slice
				cover.SliceCenter = Rect.new(0, 0, 141, 40)
				cover.Size = UDim2.fromOffset(154, 40)
				cover.Visible = false
				cover.Parent = api.Object
				coverlabel = Instance.new('TextLabel')
				coverlabel.BackgroundTransparency = 1
				coverlabel.FontFace = uipallet.Font
				coverlabel.Name = 'Text'
				coverlabel.Size = UDim2.new(1, -10, 1, -3)
				coverlabel.Text = 'PRESS A KEY TO BIND'
				coverlabel.TextColor3 = uipallet.Text
				coverlabel.TextSize = 11
				coverlabel.Parent = cover
			end

			bind.Position = UDim2.new(1, -36, 0, 10)
			bind.Parent = api.Object
			component.Object = bind
		else
			local holder = Instance.new('TextButton')
			holder.AutoButtonColor = false
			holder.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
			holder.BorderSizePixel = 0
			holder.FontFace = uipallet.Font
			holder.Size = UDim2.new(1, 0, 0, 40)
			holder.Text = '          '..props.Name
			holder.TextColor3 = color.Dark(uipallet.Text, 0.16)
			holder.TextSize = 14
			holder.TextXAlignment = Enum.TextXAlignment.Left
			holder.Visible = props.Visible == nil or props.Visible
			holder.Parent = children
			addTooltip(holder, props.Tooltip)
			bind.Position = UDim2.new(1, -10, 0, 10)
			bind.Visible = true
			bind.Parent = holder
			component.Object = holder
		end

		function component:CreateMobileButton(position)
			self:DestroyMobileButton()

			local isHeld = false
			local button = Instance.new('TextButton')
			button.AnchorPoint = Vector2.new(0.5, 0.5)
			button.BackgroundColor3 = api.Enabled and Color3.new(0, 0.7, 0) or Color3.new()
			button.BackgroundTransparency = 0.5
			button.Font = Enum.Font.Gotham
			button.Position = UDim2.fromOffset(position.X, position.Y)
			button.Size = UDim2.fromOffset(40, 40)
			button.Text = api.Name or 'Button'
			button.TextColor3 = Color3.new(1, 1, 1)
			button.TextScaled = true
			button.Parent = gui
			local constraint = Instance.new('UITextSizeConstraint')
			constraint.MaxTextSize = 16
			constraint.Parent = button
			addCorner(button, UDim.new(1, 0))

			button.MouseButton1Down:Connect(function()
				isHeld = true

				local holdtime, holdPos = os.clock(), inputService:GetMouseLocation()
				repeat
					isHeld = (inputService:GetMouseLocation() - holdPos).Magnitude < 6

					task.wait()
				until (os.clock() - holdtime) > 1 or not isHeld

				if isHeld then
					self:DestroyMobileButton()
				end
			end)

			button.MouseButton1Up:Connect(function()
				isHeld = false
			end)

			button.MouseButton1Click:Connect(function()
				self.Triggered:Fire(true)
				button.BackgroundColor3 = api.Enabled and Color3.new(0, 0.7, 0) or Color3.new()
			end)

			self.Mobile = button
		end

		function component:Destroy()
			bind:Destroy()
			bind:ClearAllChildren()

			if self.Object then
				self.Object:Destroy()
				self.Object:ClearAllChildren()
			end

			if self.Mobile then
				self.Mobile:Destroy()
				self.Mobile = nil
			end

			local index = table.find(tenacity.ActiveBinds, self)
			if index then
				table.remove(tenacity.ActiveBinds, index)
			end
		end

		function component:DestroyMobileButton()
			if self.Mobile then
				self.Mobile:Destroy()
				self.Mobile = nil
			end
		end

		function component:Load(data)
			self.Hold = data.Hold
			self:SetBind(data.Keys)

			if data.Mobile then
				self:CreateMobileButton(Vector2.new(data.Mobile.X, data.Mobile.Y))
			end
		end

		function component:Save(data)
			data[props and props.Name or 'Bind'] = {
				Keys = self.Keys,
				Mobile = self.Mobile and {
					X = self.Mobile.Position.X.Offset,
					Y = self.Mobile.Position.Y.Offset
				},
				Hold = self.Hold
			}
		end

		function component:SetBind(keys, mouse)
			if props and props.NoRemove and #keys <= 0 then
				keys = props.Default
			end

			self.Binding = nil
			self.Keys = table.clone(keys)

			if mouse then
				icon.Image = gettenacityasset('tenacity/assets/new/edit.png')

				if cover then
					coverlabel.Text = #keys <= 0 and 'BIND REMOVED' or 'BOUND TO'
					cover.Size = UDim2.fromOffset(getfontbounds(coverlabel.Text, coverlabel.TextSize, coverlabel.FontFace).X + 20, 40)

					task.delay(1, function()
						cover.Visible = false
					end)
				end
			end

			if #keys <= 0 then
				label.Visible = false
				icon.Visible = true
				bind.Size = UDim2.fromOffset(20, 20)

				local index = table.find(tenacity.ActiveBinds, component)
				if index then
					table.remove(tenacity.ActiveBinds, index)
				end
			else
				bind.Visible = true
				label.Visible = true
				icon.Visible = false
				label.Text = table.concat(keys, ' + '):upper()
				bind.Size = UDim2.fromOffset(math.max(getfontbounds(label.Text, label.TextSize, label.FontFace).X + 10, 20), 20)

				if not table.find(tenacity.ActiveBinds, component) then
					table.insert(tenacity.ActiveBinds, component)
				end
			end
		end

		function component:SetColor(newColor)
			icon.ImageColor3 = newColor
			label.TextColor3 = newColor
		end

		function component:SetParent(parent)
			bind.Parent = parent

			if cover then
				cover.Parent = parent
			end
		end

		function component:SetVisible(visible)
			bind.Visible = #self.Keys > 0 or visible
		end

		bind.MouseEnter:Connect(function()
			label.Visible = false
			icon.Visible = not label.Visible
			icon.Image = gettenacityasset(component.Binding and 'tenacity/assets/new/close.png' or 'tenacity/assets/new/edit.png')

			if not props.Cover or not api.Enabled then
				icon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
			end
		end)

		bind.MouseLeave:Connect(function()
			label.Visible = #component.Keys > 0
			icon.Visible = not label.Visible
			icon.Image = gettenacityasset(component.Binding and 'tenacity/assets/new/close.png' or 'tenacity/assets/new/bind.png')

			if not props.Cover or not api.Enabled then
				icon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
			end
		end)

		bind.MouseButton1Click:Connect(function()
			if tenacity.Binding then
				if tenacity.Binding == component then
					component:SetBind({}, true)
					tenacity.Binding = nil
				end

				return
			end

			if props.Module and inputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				component.Hold = not component.Hold
				if tenacity.CurrentTooltip then
					tenacity.CurrentTooltip()
				end

				return
			end

			if cover then
				coverlabel.Text = 'PRESS A KEY TO BIND'
				cover.Size = UDim2.fromOffset(getfontbounds(coverlabel.Text, coverlabel.TextSize, coverlabel.FontFace).X + 20, 40)
				cover.Visible = true
			end

			component.Binding = true
			icon.Image = gettenacityasset('tenacity/assets/new/close.png')
			tenacity.Binding = component
		end)

		if props.Module then
			api.Bind = component
		else
			if props.Default then
				component:SetBind(props.Default)
			end

			api.Options[props.Name] = component
		end

		return component
	end,
	Button = function(props, children, api)
		local component = {
			Name = props.Name,
			Type = 'Button'
		}
		local button = Instance.new('TextButton')
		button.AutoButtonColor = false
		button.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
		button.BorderSizePixel = 0
		button.Size = UDim2.new(1, 0, 0, 31)
		button.Text = ''
		button.Parent = children
		component.Object = button
		addTooltip(button, props.Tooltip)
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
		holder.Position = UDim2.fromOffset(10, 2)
		holder.Size = UDim2.fromOffset(200, 27)
		holder.Parent = button
		addCorner(holder)
		tenacity:RegisterGUIStyleObject(button, 'ControlRow')
		tenacity:RegisterGUIStyleObject(holder, 'ControlHolder')
		local title = Instance.new('TextLabel')
		title.BackgroundColor3 = uipallet.Main
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(2, 2)
		title.Size = UDim2.new(1, -4, 1, -4)
		title.Text = props.Name
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 14
		title.Parent = holder
		addCorner(title, UDim.new(0, 4))
		props.Function = props.Function or function() end

		button.MouseEnter:Connect(function()
			tween:Tween(holder, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.0875)
			})
		end)

		button.MouseLeave:Connect(function()
			tween:Tween(holder, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.05)
			})
		end)

		button.MouseButton1Click:Connect(props.Function)

		function component:SetText(value)
			title.Text = value
		end

		return component
	end,
	Category = function(props, children, api)
		local component = {
			Expanded = false,
			Name = props.Name,
			Type = 'Category'
		}

		local window = Instance.new('TextButton')
		window.AutoButtonColor = false
		window.BackgroundColor3 = uipallet.Main
		window.Name = props.Name..'Category'
		window.Position = UDim2.fromOffset(236, 60)
		window.Size = UDim2.fromOffset(220, 41)
		window.Text = ''
		window.Visible = false
		window.Parent = clickgui
		addBlur(window)
		addCorner(window)
		addDragHandler(window)
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = props.Icon
		icon.ImageColor3 = uipallet.Text
		icon.Position = UDim2.fromOffset(12, (icon.Size.X.Offset > 20 and 14 or 13))
		icon.Size = props.Size
		icon.Parent = window
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Size = UDim2.new(1, -(props.Size.X.Offset > 18 and 40 or 33), 0, 41)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 0)
		title.Text = props.Name
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = window
		local pencilbutton = Instance.new('TextButton')
		pencilbutton.BackgroundTransparency = 1
		pencilbutton.Position = UDim2.new(1, -49, 0, 0)
		pencilbutton.Size = UDim2.fromOffset(20, 40)
		pencilbutton.Text = ''
		pencilbutton.Visible = false
		pencilbutton.Parent = window
		addTooltip(pencilbutton, 'Edit hidden modules')
		local pencil = Instance.new('ImageLabel')
		pencil.BackgroundTransparency = 1
		pencil.Image = gettenacityasset('tenacity/assets/new/editlarge.png')
		pencil.ImageColor3 = Color3.fromRGB(140, 140, 140)
		pencil.Size = UDim2.fromOffset(12, 12)
		pencil.Position = UDim2.fromOffset(4, 14)
		pencil.Parent = pencilbutton
		local arrowbutton = Instance.new('TextButton')
		arrowbutton.BackgroundTransparency = 1
		arrowbutton.Position = UDim2.new(1, -29, 0, 0)
		arrowbutton.Size = UDim2.fromOffset(27, 40)
		arrowbutton.Text = ''
		arrowbutton.Parent = window
		local arrow = Instance.new('ImageLabel')
		arrow.BackgroundTransparency = 1
		arrow.Image = gettenacityasset('tenacity/assets/new/downexpand.png')
		arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		arrow.Size = UDim2.fromOffset(9, 4)
		arrow.Position = UDim2.fromOffset(9, 18)
		arrow.Rotation = 180
		arrow.Parent = arrowbutton
		local done = Instance.new('TextButton')
		done.BackgroundTransparency = 1
		done.FontFace = uipallet.Font
		done.Position = UDim2.new(1, -73, 0, 0)
		done.Size = UDim2.fromOffset(42, 40)
		done.Text = 'DONE'
		done.TextColor3 = Color3.fromRGB(140, 140, 140)
		done.TextSize = 12
		done.Visible = false
		done.Parent = window
		component.Done = done
		local children = Instance.new('ScrollingFrame')
		children.BackgroundTransparency = 1
		children.BorderSizePixel = 0
		children.CanvasSize = UDim2.new()
		children.Name = 'Children'
		children.Position = UDim2.fromOffset(0, 37)
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.Size = UDim2.new(1, 0, 1, -41)
		children.Visible = false
		children.Parent = window
		local divider = Instance.new('Frame')
		divider.BackgroundColor3 = Color3.new(1, 1, 1)
		divider.BackgroundTransparency = 0.928
		divider.BorderSizePixel = 0
		divider.Position = UDim2.fromOffset(0, 37)
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Visible = false
		divider.Parent = window
		local stroke = Instance.new('UIStroke')
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(85, 85, 85)
		stroke.Transparency = 0.8
		stroke.Parent = window
		tenacity:RegisterGUIStyleObject(window, 'CategoryWindow')
		local windowlist = Instance.new('UIListLayout')
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.Parent = children

		function component:Color(hue, sat, val, isRainbow) end

		local categoryAnimation = 0
		function component:Expand()
			self.Expanded = not self.Expanded
			categoryAnimation += 1
			local animation = categoryAnimation
			local targetHeight = self.Expanded and math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601) or 41

			if self.Expanded then
				children.Visible = true
			end
			tween:Tween(arrow, uiMotionPop, {Rotation = self.Expanded and 0 or 180})
			local resizeMotion = tween:Tween(window, uiMotion, {Size = UDim2.fromOffset(220, targetHeight)})
			divider.Visible = children.CanvasPosition.Y > 10 and self.Expanded

			if not self.Expanded then
				local function finishCollapse()
					if animation == categoryAnimation and not component.Expanded then children.Visible = false end
				end
				if resizeMotion then resizeMotion.Completed:Once(finishCollapse) else finishCollapse() end
			end
		end

		function component:Load(data)
			if data.Enabled then
				self.Button:Toggle()
			end

			if data.Expanded then
				self:Expand()
			end

			if data.Position then
				window.Position = UDim2.fromOffset(data.Position.X, data.Position.Y)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				Enabled = self.Button.Enabled,
				Expanded = self.Expanded,
				Position = {
					X = window.Position.X.Offset,
					Y = window.Position.Y.Offset
				}
			}
		end

		for index, comp in components do
			component['Create'..index] = function(_, props)
				return comp(props, children, component)
			end
		end

		arrowbutton.MouseButton1Click:Connect(function()
			component:Expand()
		end)

		arrowbutton.MouseButton2Click:Connect(function()
			component:Expand()
		end)

		arrowbutton.MouseEnter:Connect(function()
			arrow.ImageColor3 = Color3.fromRGB(220, 220, 220)
		end)

		arrowbutton.MouseLeave:Connect(function()
			arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		end)

		done.MouseButton1Click:Connect(function()
			tenacity.EditGUI = false
			pencilbutton.Visible = true

			for _, category in tenacity.Categories do
				if category.Type == 'Category' then
					category.Done.Visible = false
				end
			end

			for _, module in tenacity.Modules do
				module.Object.Visible = module.Visible
				module.Object.Text = string.rep(' ', 12)..module.Name
				if module.Title then
					module.Title.Text = module.Name
					module.Title.Position = UDim2.fromOffset(12, 0)
				end
				module.Edit.Visible = false
			end
		end)

		done.MouseEnter:Connect(function()
			done.TextColor3 = Color3.fromRGB(220, 220, 220)
		end)

		done.MouseLeave:Connect(function()
			done.TextColor3 = Color3.fromRGB(140, 140, 140)
		end)

		pencilbutton.MouseButton1Click:Connect(function()
			tenacity.EditGUI = true
			pencilbutton.Visible = false

			for _, category in tenacity.Categories do
				if category.Type == 'Category' then
					category.Done.Visible = true
				end
			end

			for _, module in tenacity.Modules do
				module.Object.Visible = true
				module.Object.Text = string.rep(' ', 50)..module.Name
				if module.Title then
					module.Title.Text = module.Name
					module.Title.Position = UDim2.fromOffset(48, 0)
				end
				module.Edit.Visible = true
			end
		end)

		pencilbutton.MouseButton2Click:Connect(function()
			component:Expand()
		end)

		pencilbutton.MouseEnter:Connect(function()
			pencil.ImageColor3 = Color3.fromRGB(220, 220, 220)
		end)

		pencilbutton.MouseLeave:Connect(function()
			pencil.ImageColor3 = Color3.fromRGB(140, 140, 140)
		end)

		window.MouseEnter:Connect(function()
			pencilbutton.Visible = not tenacity.EditGUI
		end)

		window.MouseLeave:Connect(function()
			pencilbutton.Visible = false
		end)

		window.InputBegan:Connect(function(input)
			if input.Position.Y < window.AbsolutePosition.Y + 41 and input.UserInputType == Enum.UserInputType.MouseButton2 then
				component:Expand()
			end
		end)

		children:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
		end)

		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
			if component.Expanded then
				tween:Tween(window, uiMotion, {Size = UDim2.fromOffset(220, math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601))})
			end
		end)

		component.Button = tenacity.Categories.Main:CreateGUIButton({
			Name = props.Name,
			Icon = props.Icon,
			Size = props.Size,
			Window = window
		})

		component.Object = window
		tenacity.Categories[props.Name] = component

		return component
	end,
	CategoryList = function(props, children, api)
		local component = {
			Expanded = false,
			List = {},
			ListEnabled = {},
			Objects = {},
			Options = {},
			Type = 'CategoryList'
		}
		props.Color = props.Color or Color3.fromRGB(5, 134, 105)

		local window = Instance.new('TextButton')
		window.AutoButtonColor = false
		window.BackgroundColor3 = uipallet.Main
		window.Name = props.Name..'CategoryList'
		window.Position = UDim2.fromOffset(240, 46)
		window.Size = UDim2.fromOffset(220, 45)
		window.Text = ''
		window.Visible = false
		window.Parent = clickgui
		addBlur(window)
		addCorner(window)
		addDragHandler(window)
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = props.Icon
		icon.ImageColor3 = uipallet.Text
		icon.Name = 'Icon'
		icon.Size = props.Size
		icon.Position = props.Position or UDim2.fromOffset(12, (props.Size.X.Offset > 20 and 13 or 12))
		icon.Parent = window
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Name = 'Title'
		title.Size = UDim2.new(1, -(props.Size.X.Offset > 20 and 44 or 36), 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
		title.Text = props.Name
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = window
		local arrowbutton = Instance.new('TextButton')
		arrowbutton.BackgroundTransparency = 1
		arrowbutton.Name = 'Arrow'
		arrowbutton.Position = UDim2.new(1, -40, 0, 0)
		arrowbutton.Size = UDim2.fromOffset(40, 40)
		arrowbutton.Text = ''
		arrowbutton.Parent = window
		local arrow = Instance.new('ImageLabel')
		arrow.Name = 'Arrow'
		arrow.Size = UDim2.fromOffset(9, 4)
		arrow.Position = UDim2.fromOffset(15, 20)
		arrow.BackgroundTransparency = 1
		arrow.Image = gettenacityasset('tenacity/assets/new/downexpand.png')
		arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		arrow.Rotation = 180
		arrow.Parent = arrowbutton
		local children = Instance.new('ScrollingFrame')
		children.Name = 'Children'
		children.Size = UDim2.new(1, 0, 1, -45)
		children.Position = UDim2.fromOffset(0, 45)
		children.BackgroundTransparency = 1
		children.BorderSizePixel = 0
		children.Visible = false
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.CanvasSize = UDim2.new()
		children.Parent = window
		local childrentwo = Instance.new('Frame')
		childrentwo.BackgroundTransparency = 1
		childrentwo.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		childrentwo.Visible = false
		childrentwo.Parent = children
		local settings = Instance.new('ImageButton')
		settings.AutoButtonColor = false
		settings.BackgroundTransparency = 1
		settings.Image = gettenacityasset('tenacity/assets/new/settings.png')
		settings.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		settings.Name = 'Settings'
		settings.Position = UDim2.new(1, -56, 0, 15)
		settings.Size = UDim2.fromOffset(14, 14)
		settings.Parent = window
		local divider = Instance.new('Frame')
		divider.BackgroundColor3 = Color3.new(1, 1, 1)
		divider.BackgroundTransparency = 0.928
		divider.BorderSizePixel = 0
		divider.Name = 'Divider'
		divider.Position = UDim2.fromOffset(0, 41)
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Visible = false
		divider.Parent = window
		local stroke = Instance.new('UIStroke')
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(85, 85, 85)
		stroke.Transparency = 0.8
		stroke.Parent = window
		tenacity:RegisterGUIStyleObject(window, 'CategoryListWindow')
		local windowlist = Instance.new('UIListLayout')
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Padding = UDim.new(0, 4)
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.Parent = children
		local windowlisttwo = Instance.new('UIListLayout')
		windowlisttwo.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlisttwo.SortOrder = Enum.SortOrder.LayoutOrder
		windowlisttwo.Parent = childrentwo
		local addbkg = Instance.new('Frame')
		addbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		addbkg.Position = UDim2.fromOffset(10, 45)
		addbkg.Size = UDim2.fromOffset(200, 31)
		addbkg.Parent = children
		addCorner(addbkg)
		local addbox = addbkg:Clone()
		addbox.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		addbox.Position = UDim2.fromOffset(1, 1)
		addbox.Size = UDim2.new(1, -2, 1, -2)
		addbox.Parent = addbkg
		local addvalue = Instance.new('TextBox')
		addvalue.BackgroundTransparency = 1
		addvalue.ClearTextOnFocus = false
		addvalue.FontFace = uipallet.Font
		addvalue.PlaceholderText = props.Placeholder or 'Add entry...'
		addvalue.PlaceholderColor3 = Color3.new(0.8, 0.8, 0.8)
		addvalue.Position = UDim2.fromOffset(10, 0)
		addvalue.Size = UDim2.new(1, -35, 1, 0)
		addvalue.Text = ''
		addvalue.TextColor3 = Color3.new(1, 1, 1)
		addvalue.TextSize = 13
		addvalue.TextXAlignment = Enum.TextXAlignment.Left
		addvalue.Parent = addbkg
		local addbutton = Instance.new('ImageButton')
		addbutton.BackgroundTransparency = 1
		addbutton.Image = gettenacityasset('tenacity/assets/new/add.png')
		addbutton.ImageColor3 = props.Color
		addbutton.ImageTransparency = 0.3
		addbutton.Position = UDim2.new(1, -26, 0, 8)
		addbutton.Size = UDim2.fromOffset(16, 16)
		addbutton.Parent = addbkg
		local cursedpadding = Instance.new('Frame')
		cursedpadding.BackgroundTransparency = 1
		cursedpadding.Size = UDim2.fromOffset()
		cursedpadding.Parent = children
		props.Function = props.Function or function() end

		function component:CreateProfile(value, data)
			local profile = {
				Name = value
			}

			profile.Bind = components.Bind({
				Module = true,
				Cover = true
			}, nil, profile)
			profile.Bind.Object.Position = UDim2.new(1, -30, 0, 7)
			profile.Bind.Triggered:Connect(function(isPressed)
				if isPressed and tenacity.Profile ~= value then
					tenacity:SwitchProfile(value)
				end
			end)

			if data then
				profile.Bind:Load(data)
			end

			table.insert(self.List, profile)
		end

		function component:ChangeValue(value, skipGUI)
			if value then
				if props.Profiles then
					local index, profile = self:GetValue(value)
					if index then
						if value ~= 'default' then
							profile.Bind:Destroy()
							table.remove(self.List, index)

							if isfile('tenacity/profiles/'..value..tenacity.Place..'.txt') and delfile then
								delfile('tenacity/profiles/'..value..tenacity.Place..'.txt')
							end
						end
					else
						self:CreateProfile(value)
					end
				else
					local index = table.find(self.List, value)
					if index then
						table.remove(self.List, index)

						index = table.find(self.ListEnabled, value)
						if index then
							table.remove(self.ListEnabled, index)
						end
					else
						table.insert(self.List, value)
						table.insert(self.ListEnabled, value)
					end
				end
			end

			props.Function()
			for _, obj in self.Objects do
				obj:Destroy()
			end
			table.clear(self.Objects)
			self.Selected = nil

			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			for _, name in self.List do
				if props.Profiles then
					local obj = Instance.new('TextButton')
					obj.Name = name.Name
					obj.Size = UDim2.fromOffset(200, 32)
					obj.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					obj.AutoButtonColor = false
					obj.Text = ''
					obj.Parent = children
					addCorner(obj)
					local stroke = Instance.new('UIStroke')
					stroke.Color = color.Light(uipallet.Main, 0.1)
					stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					stroke.Enabled = false
					stroke.Parent = obj
					local label = Instance.new('TextLabel')
					label.Name = 'Title'
					label.Size = UDim2.new(1, -10, 1, 0)
					label.Position = UDim2.fromOffset(10, 0)
					label.BackgroundTransparency = 1
					label.Text = name.Name
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.TextColor3 = color.Dark(uipallet.Text, 0.4)
					label.TextSize = 15
					label.FontFace = uipallet.Font
					label.Parent = obj
					local dotsbutton = Instance.new('TextButton')
					dotsbutton.BackgroundTransparency = 1
					dotsbutton.Name = 'Dots'
					dotsbutton.Position = UDim2.new(1, -25, 0, 0)
					dotsbutton.Size = UDim2.fromOffset(25, 32)
					dotsbutton.Text = ''
					dotsbutton.Parent = obj
					local dots = Instance.new('ImageLabel')
					dots.BackgroundTransparency = 1
					dots.Image = gettenacityasset('tenacity/assets/new/settingdots.png')
					dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
					dots.Name = 'Dots'
					dots.Position = UDim2.fromOffset(11, 9)
					dots.Size = UDim2.fromOffset(3, 16)
					dots.Parent = dotsbutton
					name.Bind:SetParent(obj)
					name.Enabled = name.Name == tenacity.Profile

					dotsbutton.MouseButton1Click:Connect(function()
						if not name.Enabled then
							component:ChangeValue(name.Name)
						end
					end)

					dotsbutton.MouseEnter:Connect(function()
						if not name.Enabled then
							dots.ImageColor3 = uipallet.Text
						end
					end)

					dotsbutton.MouseLeave:Connect(function()
						if not name.Enabled then
							dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
						end
					end)


					obj.MouseButton1Click:Connect(function()
						tenacity:SwitchProfile(name.Name)
					end)

					obj.MouseEnter:Connect(function()
						name.Bind:SetVisible(true)
					end)

					obj.MouseLeave:Connect(function()
						name.Bind:SetVisible(false)
					end)

					if name.Enabled then
						self.Selected = obj
					else
						name.Bind:SetColor(color.Dark(uipallet.Text, 0.43))
					end

					table.insert(self.Objects, {
						Destroy = function()
							name.Bind:SetParent(nil)
							obj:Destroy()
						end
					})
				else
					local isEnabled = table.find(self.ListEnabled, name)
					local obj = Instance.new('TextButton')
					obj.Name = name
					obj.Size = UDim2.fromOffset(200, 31)
					obj.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					obj.AutoButtonColor = false
					obj.Text = ''
					obj.Parent = children
					addCorner(obj)
					local bkg = Instance.new('Frame')
					bkg.BackgroundColor3 = uipallet.Main
					bkg.Position = UDim2.fromOffset(1, 1)
					bkg.Size = UDim2.new(1, -2, 1, -2)
					bkg.Visible = false
					bkg.Parent = obj
					addCorner(bkg)
					local dot = Instance.new('Frame')
					dot.BackgroundColor3 = isEnabled and props.Color or color.Light(uipallet.Main, 0.37)
					dot.Position = UDim2.fromOffset(10, 12)
					dot.Size = UDim2.fromOffset(10, 11)
					dot.Parent = obj
					addCorner(dot, UDim.new(1, 0))
					local dotin = dot:Clone()
					dotin.BackgroundColor3 = isEnabled and props.Color or color.Light(uipallet.Main, 0.02)
					dotin.Position = UDim2.fromOffset(1, 1)
					dotin.Size = UDim2.fromOffset(8, 9)
					dotin.Parent = dot
					local label = Instance.new('TextLabel')
					label.BackgroundTransparency = 1
					label.FontFace = uipallet.Font
					label.Position = UDim2.fromOffset(30, 0)
					label.Size = UDim2.new(1, -30, 1, 0)
					label.Text = name
					label.TextColor3 = color.Dark(uipallet.Text, 0.16)
					label.TextSize = 15
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.Parent = obj
					local close = Instance.new('ImageButton')
					close.AutoButtonColor = false
					close.BackgroundColor3 = Color3.new(1, 1, 1)
					close.BackgroundTransparency = 1
					close.Image = gettenacityasset('tenacity/assets/new/closetiny.png')
					close.ImageColor3 = color.Light(uipallet.Text, 0.2)
					close.ImageTransparency = 0.5
					close.Position = UDim2.new(1, -27, 0, 8)
					close.Size = UDim2.fromOffset(18, 17)
					close.Parent = obj
					addCorner(close, UDim.new(1, 0))

					close.MouseEnter:Connect(function()
						close.ImageTransparency = 0.3
						tween:Tween(close, uipallet.Tween, {
							BackgroundTransparency = 0.6
						})
					end)

					close.MouseLeave:Connect(function()
						close.ImageTransparency = 0.5
						tween:Tween(close, uipallet.Tween, {
							BackgroundTransparency = 1
						})
					end)

					close.MouseButton1Click:Connect(function()
						component:ChangeValue(name)
					end)

					obj.MouseEnter:Connect(function()
						bkg.Visible = true
					end)

					obj.MouseLeave:Connect(function()
						bkg.Visible = false
					end)

					obj.MouseButton1Click:Connect(function()
						local index = table.find(self.ListEnabled, name)
						if index then
							table.remove(self.ListEnabled, index)
							dot.BackgroundColor3 = color.Light(uipallet.Main, 0.37)
							dotin.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
						else
							table.insert(self.ListEnabled, name)
							dot.BackgroundColor3 = props.Color
							dotin.BackgroundColor3 = props.Color
						end

						props.Function()
					end)

					table.insert(self.Objects, obj)
				end
			end

			if not skipGUI then
				tenacity:UpdateGUI()
			end
		end

		function component:Color(hue, sat, val, isRainbow)
			for _, component in self.Options do
				if component.Color then
					component:Color(hue, sat, val, isRainbow)
				end
			end

			addbutton.ImageColor3 = isRainbow and Color3.fromHSV(tenacity:Color(hue % 1)) or Color3.fromHSV(hue, sat, val)

			if self.Selected then
				self.Selected.BackgroundColor3 = isRainbow and Color3.fromHSV(tenacity:Color(hue % 1)) or Color3.fromHSV(hue, sat, val)
				self.Selected.Title.TextColor3 = (tenacity.GUIColor.Rainbow and not tenacity:IsGradientThemeActive()) and Color3.new(0.19, 0.19, 0.19) or tenacity:TextColor(hue, sat, val)
				self.Selected.Dots.Dots.ImageColor3 = self.Selected.Title.TextColor3
				self.Selected.Bind.Icon.ImageColor3 = self.Selected.Title.TextColor3
				self.Selected.Bind.TextLabel.TextColor3 = self.Selected.Title.TextColor3
			end
		end

		local categoryAnimation = 0
		function component:Expand()
			self.Expanded = not self.Expanded
			categoryAnimation += 1
			local animation = categoryAnimation
			local targetHeight = self.Expanded and math.min(51 + windowlist.AbsoluteContentSize.Y / scale.Scale, 611) or 45

			if self.Expanded then
				children.Visible = true
			end
			tween:Tween(arrow, uiMotionPop, {Rotation = self.Expanded and 0 or 180})
			local resizeMotion = tween:Tween(window, uiMotion, {Size = UDim2.fromOffset(220, targetHeight)})
			divider.Visible = children.CanvasPosition.Y > 10 and self.Expanded

			if not self.Expanded then
				local function finishCollapse()
					if animation == categoryAnimation and not component.Expanded then children.Visible = false end
				end
				if resizeMotion then resizeMotion.Completed:Once(finishCollapse) else finishCollapse() end
			end
		end

		function component:GetValue(name)
			for index, profile in self.List do
				if profile.Name == name then
					return index, profile
				end
			end
		end

		function component:Load(data)
			tenacity:LoadOptions(self, data.Options)

			if data.Enabled then
				self.Button:Toggle()
			end

			if data.Expanded then
				self:Expand()
			end

			if props.Profiles then
				for _, profile in data.List do
					self:CreateProfile(profile.Name, profile.Bind)
				end

				self:ChangeValue(nil, true)
			else
				if data.List and (#self.List > 0 or #data.List > 0) then
					self.List = data.List or {}
					self.ListEnabled = data.ListEnabled or {}
					self:ChangeValue(nil, true)
				end
			end

			if data.Position then
				window.Position = UDim2.fromOffset(data.Position.X, data.Position.Y)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				Enabled = self.Button.Enabled,
				Expanded = self.Expanded,
				List = self.List,
				ListEnabled = self.ListEnabled,
				Options = tenacity:SaveOptions(self),
				Position = {
					X = window.Position.X.Offset,
					Y = window.Position.Y.Offset
				}
			}

			if props.Profiles then
				local newList = {}

				for _, profile in self.List do
					local entry = {
						Name = profile.Name
					}

					profile.Bind:Save(entry)
					table.insert(newList, entry)
				end

				data[props.Name].List = newList
			end
		end

		for index, comp in components do
			component['Create'..index] = function(_, props)
				return comp(props, childrentwo, component)
			end
		end

		addbutton.MouseEnter:Connect(function()
			addbutton.ImageTransparency = 0
		end)

		addbutton.MouseLeave:Connect(function()
			addbutton.ImageTransparency = 0.3
		end)

		addbutton.MouseButton1Click:Connect(function()
			if not table.find(component.List, addvalue.Text) then
				component:ChangeValue(addvalue.Text)
				addvalue.Text = ''
			end
		end)

		arrowbutton.MouseEnter:Connect(function()
			arrow.ImageColor3 = Color3.fromRGB(220, 220, 220)
		end)

		arrowbutton.MouseLeave:Connect(function()
			arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		end)

		arrowbutton.MouseButton1Click:Connect(function()
			component:Expand()
		end)

		arrowbutton.MouseButton2Click:Connect(function()
			component:Expand()
		end)

		addvalue.FocusLost:Connect(function(enter)
			if enter and not table.find(component.List, addvalue.Text) then
				component:ChangeValue(addvalue.Text)
				addvalue.Text = ''
			end
		end)

		addvalue.MouseEnter:Connect(function()
			tween:Tween(addbkg, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			})
		end)

		addvalue.MouseLeave:Connect(function()
			tween:Tween(addbkg, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			})
		end)

		children:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
			divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
		end)

		settings.MouseEnter:Connect(function()
			settings.ImageColor3 = uipallet.Text
		end)

		settings.MouseLeave:Connect(function()
			settings.ImageColor3 = color.Light(uipallet.Main, 0.37)
		end)

		settings.MouseButton1Click:Connect(function()
			childrentwo.Visible = not childrentwo.Visible
		end)

		window.InputBegan:Connect(function(input)
			if input.Position.Y < window.AbsolutePosition.Y + 41 and input.UserInputType == Enum.UserInputType.MouseButton2 then
				component:Expand()
			end
		end)

		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
			if component.Expanded then
				tween:Tween(window, uiMotion, {Size = UDim2.fromOffset(220, math.min(51 + windowlist.AbsoluteContentSize.Y / scale.Scale, 611))})
			end
		end)

		windowlisttwo:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			childrentwo.Size = UDim2.fromOffset(220, windowlisttwo.AbsoluteContentSize.Y / scale.Scale)
		end)

		component.Button = tenacity.Categories.Main:CreateGUIButton({
			Name = props.Name,
			Icon = props.CategoryIcon,
			Size = props.CategorySize,
			Window = window
		})

		component.Object = window
		tenacity.Categories[props.Name] = component

		return component
	end,
	ColorSlider = function(props, children, api)
		local component = {
			Type = 'ColorSlider',
			Hue = props.DefaultHue or 0.44,
			Sat = props.DefaultSat or 1,
			Value = props.DefaultValue or 1,
			Opacity = props.DefaultOpacity or 1,
			Rainbow = false,
			Index = 0
		}

		local function createExtraSlider(name, gradientColor)
			local colorslidercustom = Instance.new('TextButton')
			colorslidercustom.AutoButtonColor = false
			colorslidercustom.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
			colorslidercustom.BorderSizePixel = 0
			colorslidercustom.Size = UDim2.new(1, 0, 0, 50)
			colorslidercustom.Text = ''
			colorslidercustom.Visible = false
			colorslidercustom.Parent = children
			local title = Instance.new('TextLabel')
			title.BackgroundTransparency = 1
			title.FontFace = uipallet.Font
			title.Position = UDim2.fromOffset(10, 2)
			title.Size = UDim2.fromOffset(60, 30)
			title.Text = name
			title.TextColor3 = color.Dark(uipallet.Text, 0.16)
			title.TextSize = 11
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = colorslidercustom
			local holder = Instance.new('Frame')
			holder.BackgroundColor3 = Color3.new(1, 1, 1)
			holder.BorderSizePixel = 0
			holder.Name = 'Holder'
			holder.Position = UDim2.fromOffset(10, 37)
			holder.Size = UDim2.new(1, -20, 0, 2)
			holder.Parent = colorslidercustom
			local uigradient = Instance.new('UIGradient')
			uigradient.Color = gradientColor
			uigradient.Parent = holder
			local fill = Instance.new('Frame')
			fill.BackgroundTransparency = 1
			fill.Name = 'Fill'
			fill.Size = UDim2.fromScale(math.clamp(name == 'Saturation' and component.Sat or name == 'Vibrance' and component.Value or component.Opacity, 0.04, 0.96), 1)
			fill.Parent = holder
			local knobholder = Instance.new('Frame')
			knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
			knobholder.BackgroundColor3 = colorslidercustom.BackgroundColor3
			knobholder.BorderSizePixel = 0
			knobholder.Position = UDim2.fromScale(1, 0.5)
			knobholder.Size = UDim2.fromOffset(24, 4)
			knobholder.Parent = fill
			local knob = Instance.new('Frame')
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.BackgroundColor3 = uipallet.Text
			knob.Position = UDim2.fromScale(0.5, 0.5)
			knob.Size = UDim2.fromOffset(14, 14)
			knob.Parent = knobholder
			addCorner(knob, UDim.new(1, 0))

			colorslidercustom.InputBegan:Connect(function(input)
				if
					(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
					and (input.Position.Y - colorslidercustom.AbsolutePosition.Y) > (20 * scale.Scale)
				then
					local releaseConnection
					local moveConnection = inputService.InputChanged:Connect(function(newInput)
						if newInput.UserInputType == (input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
							local newValue = math.clamp((newInput.Position.X - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1)
							component:SetValue(nil, name == 'Saturation' and newValue or nil, name == 'Vibrance' and newValue or nil, name == 'Opacity' and newValue or nil)
						end
					end)

					releaseConnection = input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End then
							moveConnection:Disconnect()
							releaseConnection:Disconnect()
						end
					end)
				end
			end)

			colorslidercustom.MouseEnter:Connect(function()
				tween:Tween(knob, uipallet.Tween, {
					Size = UDim2.fromOffset(16, 16)
				})
			end)

			colorslidercustom.MouseLeave:Connect(function()
				tween:Tween(knob, uipallet.Tween, {
					Size = UDim2.fromOffset(14, 14)
				})
			end)

			return colorslidercustom
		end

		local colorslider = Instance.new('TextButton')
		colorslider.AutoButtonColor = false
		colorslider.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
		colorslider.BorderSizePixel = 0
		colorslider.Size = UDim2.new(1, 0, 0, 50)
		colorslider.Text = ''
		colorslider.Visible = props.Visible == nil or props.Visible
		colorslider.Parent = children
		component.Object = colorslider
		tenacity:RegisterGUIStyleObject(colorslider, 'ControlRow')
		addTooltip(colorslider, props.Tooltip)
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(10, 2)
		title.Size = UDim2.fromOffset(60, 30)
		title.Text = props.Name
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 11
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = colorslider
		local custombox = Instance.new('TextBox')
		custombox.BackgroundTransparency = 1
		custombox.FontFace = uipallet.Font
		custombox.Position = UDim2.new(1, -69, 0, 9)
		custombox.Size = UDim2.fromOffset(60, 15)
		custombox.Text = ''
		custombox.TextColor3 = color.Dark(uipallet.Text, 0.16)
		custombox.TextSize = 11
		custombox.TextXAlignment = Enum.TextXAlignment.Right
		custombox.Visible = false
		custombox.Parent = colorslider
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = Color3.new(1, 1, 1)
		holder.BorderSizePixel = 0
		holder.Position = UDim2.fromOffset(10, 39)
		holder.Size = UDim2.new(1, -20, 0, 2)
		holder.Parent = colorslider
		tenacity:RegisterGUIStyleObject(holder, 'SliderTrack')
		local rainbowTable = {}
		for i = 0, 1, 0.1 do
			table.insert(rainbowTable, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
		end
		local uigradient = Instance.new('UIGradient')
		uigradient.Color = ColorSequence.new(rainbowTable)
		uigradient.Parent = holder
		local fill = Instance.new('Frame')
		fill.BackgroundTransparency = 1
		fill.Size = UDim2.fromScale(math.clamp(component.Hue, 0.04, 0.96), 1)
		fill.Parent = holder
		local knobholder = Instance.new('Frame')
		knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
		knobholder.BackgroundColor3 = colorslider.BackgroundColor3
		knobholder.BorderSizePixel = 0
		knobholder.Position = UDim2.fromScale(1, 0.5)
		knobholder.Size = UDim2.fromOffset(24, 4)
		knobholder.Parent = fill
		local knob = Instance.new('Frame')
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = uipallet.Text
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.Size = UDim2.fromOffset(14, 14)
		knob.Parent = knobholder
		addCorner(knob, UDim.new(1, 0))
		local preview = Instance.new('ImageButton')
		preview.BackgroundTransparency = 1
		preview.Image = gettenacityasset('tenacity/assets/new/colorpreview.png')
		preview.ImageColor3 = Color3.fromHSV(component.Hue, component.Sat, component.Value)
		preview.ImageTransparency = 1 - component.Opacity
		preview.Position = UDim2.new(1, -22, 0, 10)
		preview.Size = UDim2.fromOffset(12, 12)
		preview.Parent = colorslider
		local expand = Instance.new('TextButton')
		expand.BackgroundTransparency = 1
		expand.Position = UDim2.fromOffset(getfontbounds(title.Text, title.TextSize, title.FontFace).X + 11, 7)
		expand.Size = UDim2.fromOffset(17, 13)
		expand.Text = ''
		expand.Parent = colorslider
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = gettenacityasset('tenacity/assets/new/downexpandslider.png')
		icon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		icon.Position = UDim2.fromOffset(4, 4)
		icon.Size = UDim2.fromOffset(10, 5)
		icon.Parent = expand
		local rainbow = Instance.new('TextButton')
		rainbow.BackgroundTransparency = 1
		rainbow.Position = UDim2.new(1, -42, 0, 10)
		rainbow.Size = UDim2.fromOffset(12, 12)
		rainbow.Text = ''
		rainbow.Parent = colorslider
		local ring1 = Instance.new('ImageLabel')
		ring1.BackgroundTransparency = 1
		ring1.Image = gettenacityasset('tenacity/assets/new/rainbow_1.png')
		ring1.ImageColor3 = color.Light(uipallet.Main, 0.37)
		ring1.Size = UDim2.fromOffset(12, 12)
		ring1.Parent = rainbow
		local ring2 = Instance.fromExisting(ring1)
		ring2.Image = gettenacityasset('tenacity/assets/new/rainbow_2.png')
		ring2.Parent = rainbow
		local ring3 = Instance.fromExisting(ring1)
		ring3.Image = gettenacityasset('tenacity/assets/new/rainbow_3.png')
		ring3.Parent = rainbow
		local ring4 = Instance.fromExisting(ring1)
		ring4.Image = gettenacityasset('tenacity/assets/new/rainbow_4.png')
		ring4.Parent = rainbow
		props.Function = props.Function or function() end

		local satSlider = createExtraSlider('Saturation', ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, component.Value)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(component.Hue, 1, component.Value))
		}))

		local vibSlider = createExtraSlider('Vibrance', ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(component.Hue, component.Sat, 1))
		}))

		local opSlider = createExtraSlider('Opacity', ColorSequence.new({
			ColorSequenceKeypoint.new(0, color.Dark(uipallet.Main, 0.02)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(component.Hue, component.Sat, component.Value))
		}))

		function component:Load(data)
			if data.Rainbow ~= self.Rainbow then
				self:Toggle()
			end

			if self.Hue ~= data.Hue or self.Sat ~= data.Sat or self.Value ~= data.Value or self.Opacity ~= data.Opacity then
				self:SetValue(data.Hue, data.Sat, data.Value, data.Opacity)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				Hue = self.Hue,
				Sat = self.Sat,
				Value = self.Value,
				Opacity = self.Opacity,
				Rainbow = self.Rainbow
			}
		end

		function component:SetValue(h, s, v, o)
			self.Hue = h or self.Hue
			self.Sat = s or self.Sat
			self.Value = v or self.Value
			self.Opacity = o or self.Opacity
			preview.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
			preview.ImageTransparency = 1 - self.Opacity

			satSlider.Holder.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, self.Value)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, 1, self.Value))
			})

			vibSlider.Holder.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, 1))
			})

			opSlider.Holder.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, color.Dark(uipallet.Main, 0.02)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, self.Value))
			})

			if self.Rainbow then
				fill.Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
			else
				tween:Tween(fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
				})
			end

			if s then
				tween:Tween(satSlider.Holder.Fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
				})
			end

			if v then
				tween:Tween(vibSlider.Holder.Fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
				})
			end

			if o then
				tween:Tween(opSlider.Holder.Fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Opacity, 0.04, 0.96), 1)
				})
			end

			props.Function(self.Hue, self.Sat, self.Value, self.Opacity)
		end

		function component:Toggle()
			self.Rainbow = not self.Rainbow

			if self.Rainbow then
				table.insert(tenacity.RainbowSliders, self)

				ring1.ImageColor3 = Color3.fromRGB(5, 127, 100)
				task.delay(0.1, function()
					if not self.Rainbow then return end
					ring2.ImageColor3 = Color3.fromRGB(228, 125, 43)
					task.delay(0.1, function()
						if not self.Rainbow then return end
						ring3.ImageColor3 = Color3.fromRGB(225, 46, 52)
					end)
				end)
			else
				local index = table.find(tenacity.RainbowSliders, self)
				if index then
					table.remove(tenacity.RainbowSliders, index)
				end

				ring3.ImageColor3 = color.Light(uipallet.Main, 0.37)
				task.delay(0.1, function()
					if self.Rainbow then return end
					ring2.ImageColor3 = color.Light(uipallet.Main, 0.37)
					task.delay(0.1, function()
						if self.Rainbow then return end
						ring1.ImageColor3 = color.Light(uipallet.Main, 0.37)
					end)
				end)
			end
		end

		preview.MouseButton1Click:Connect(function()
			preview.Visible = false
			custombox.Visible = true
			custombox:CaptureFocus()

			local text = Color3.fromHSV(component.Hue, component.Sat, component.Value)
			custombox.Text = math.round(text.R * 255)..', '..math.round(text.G * 255)..', '..math.round(text.B * 255)
		end)

		local doubleClick = os.clock()
		colorslider.InputBegan:Connect(function(input)
			if
				(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
				and (input.Position.Y - colorslider.AbsolutePosition.Y) > (20 * scale.Scale)
			then
				local releaseConnection
				local moveConnection = inputService.InputChanged:Connect(function(newInput)
					if newInput.UserInputType == (input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
						component:SetValue(math.clamp((newInput.Position.X - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1))
					end
				end)

				releaseConnection = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						moveConnection:Disconnect()
						releaseConnection:Disconnect()
					end
				end)

				if doubleClick > os.clock() then
					component:Toggle()
				else
					component:SetValue(math.clamp((input.Position.X - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1))
				end

				doubleClick = os.clock() + 0.3
			end
		end)

		colorslider.MouseEnter:Connect(function()
			tween:Tween(knob, uipallet.Tween, {
				Size = UDim2.fromOffset(16, 16)
			})
		end)

		colorslider.MouseLeave:Connect(function()
			tween:Tween(knob, uipallet.Tween, {
				Size = UDim2.fromOffset(14, 14)
			})
		end)

		colorslider:GetPropertyChangedSignal('Visible'):Connect(function()
			satSlider.Visible = icon.Rotation == 180 and colorslider.Visible
			vibSlider.Visible = satSlider.Visible
			opSlider.Visible = satSlider.Visible
		end)

		expand.MouseEnter:Connect(function()
			icon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
		end)

		expand.MouseLeave:Connect(function()
			icon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		end)

		expand.MouseButton1Click:Connect(function()
			satSlider.Visible = not satSlider.Visible
			vibSlider.Visible = satSlider.Visible
			opSlider.Visible = satSlider.Visible
			icon.Rotation = satSlider.Visible and 180 or 0
		end)

		rainbow.MouseButton1Click:Connect(function()
			component:Toggle()
		end)

		custombox.FocusLost:Connect(function(enter)
			preview.Visible = true
			custombox.Visible = false

			if enter then
				local success, parsed = pcall(function()
					local commas = custombox.Text:split(',')
					return tonumber(commas[1]) and Color3.fromRGB(tonumber(commas[1]), tonumber(commas[2]), tonumber(commas[3])) or Color3.fromHex(valuebox.Text)
				end)

				if success then
					if component.Rainbow then
						component:Toggle()
					end

					component:SetValue(parsed:ToHSV())
				end
			end
		end)

		api.Options[props.Name] = component

		return component
	end,
	Divider = function(props, children, api)
		local divider = Instance.new('Frame')
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		divider.BorderSizePixel = 0
		divider.Parent = children

		if props and props.Text then
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromOffset(218, 27)
			label.BackgroundTransparency = 1
			label.Text = '          '..props.Text:upper()
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = color.Dark(uipallet.Text, 0.43)
			label.TextSize = 9
			label.FontFace = uipallet.Font
			label.Parent = children
			divider.BackgroundTransparency = 1
			--divider.Position = UDim2.fromOffset(0, 26)
			divider.Parent = label
		end
	end,
	Dropdown = function(props, children, api)
		local component = {
			Index = 0,
			Type = 'Dropdown',
			Value = props.List[1] or 'None'
		}

		local dropdown = Instance.new('TextButton')
		dropdown.AutoButtonColor = false
		dropdown.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
		dropdown.BorderSizePixel = 0
		dropdown.ClipsDescendants = true
		dropdown.Size = UDim2.new(1, 0, 0, 40)
		dropdown.Text = ''
		dropdown.Visible = props.Visible == nil or props.Visible
		dropdown.Parent = children
		component.Object = dropdown
		addTooltip(dropdown, props.Tooltip or props.Name)
		tenacity:RegisterGUIStyleObject(dropdown, 'ControlRow')

		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		holder.Position = UDim2.fromOffset(10, 4)
		holder.Size = UDim2.new(1, -20, 1, -11)
		holder.Parent = dropdown
		addCorner(holder, UDim.new(0, 6))
		tenacity:RegisterGUIStyleObject(holder, 'ControlHolder')

		local button = Instance.new('TextButton')
		button.AutoButtonColor = false
		button.BackgroundColor3 = uipallet.Main
		button.Position = UDim2.fromOffset(1, 1)
		button.Size = UDim2.new(1, -2, 1, -2)
		button.Text = ''
		button.Parent = holder
		addCorner(button, UDim.new(0, 6))

		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Size = UDim2.new(1, -26, 0, 29)
		title.Text = '         '..props.Name..' - '..component.Value
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 13
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = button

		local arrow = Instance.new('ImageLabel')
		arrow.BackgroundTransparency = 1
		arrow.Image = gettenacityasset('tenacity/assets/new/expandarrow.png')
		arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		arrow.Position = UDim2.new(1, -17, 0, 11)
		arrow.Rotation = 90
		arrow.Size = UDim2.fromOffset(4, 8)
		arrow.Parent = button

		props.Function = props.Function or function() end
		local dropdownchildren
		local optionScroller
		local searchBox
		local emptyLabel
		local dropdownOpen = false
		local dropdownAnimation = 0
		local optionEntries = {}

		local function closeDropdown()
			if not dropdownchildren then return end
			dropdownOpen = false
			dropdownAnimation += 1
			local animation = dropdownAnimation
			if searchBox then searchBox:ReleaseFocus(false) end

			tween:Tween(arrow, uiMotionFast, {Rotation = 90})
			local motion = tween:Tween(dropdown, uiMotion, {Size = UDim2.new(1, 0, 0, 40)})
			for _, entry in optionEntries do
				if entry.Parent then
					tween:Tween(entry, uiMotionFast, {TextTransparency = 1, BackgroundTransparency = 1})
				end
			end

			local function finishClose()
				if animation == dropdownAnimation and not dropdownOpen and dropdownchildren then
					dropdownchildren:Destroy()
					dropdownchildren = nil
					optionScroller = nil
					searchBox = nil
					emptyLabel = nil
					table.clear(optionEntries)
				end
			end

			if motion then
				motion.Completed:Once(finishClose)
			else
				finishClose()
			end
		end

		function component:Change(list)
			props.List = list or {}
			if dropdownchildren then closeDropdown() end
			if not table.find(props.List, self.Value) then
				self:SetValue(self.Value)
			end
		end

		function component:Load(data)
			if self.Value ~= data.Value then
				self:SetValue(data.Value)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				Value = self.Value
			}
		end

		function component:SetValue(value, isClick)
			self.Value = table.find(props.List, value) and value or props.List[1] or 'None'
			title.Text = '         '..props.Name..' - '..self.Value

			if dropdownchildren then
				closeDropdown()
			end

			props.Function(self.Value, isClick)
		end

		local function openDropdown()
			dropdownOpen = true
			dropdownAnimation += 1
			tween:Tween(arrow, uiMotionPop, {Rotation = 270})

			local values = {}
			for _, value in props.List do
				if value ~= component.Value then table.insert(values, value) end
			end

			local optionCount = #values
			local searchable = optionCount >= 2
			local searchHeight = searchable and 34 or 0
			local maxRows = 8

			dropdownchildren = Instance.new('Frame')
			dropdownchildren.BackgroundTransparency = 1
			dropdownchildren.BorderSizePixel = 0
			dropdownchildren.Position = UDim2.fromOffset(0, 28)
			dropdownchildren.Size = UDim2.new(1, 0, 0, searchHeight)
			dropdownchildren.Parent = button

			if searchable then
				local searchHolder = Instance.new('Frame')
				searchHolder.BackgroundColor3 = color.Light(uipallet.Main, 0.035)
				searchHolder.BackgroundTransparency = 0.04
				searchHolder.Position = UDim2.fromOffset(7, 4)
				searchHolder.Size = UDim2.new(1, -14, 0, 26)
				searchHolder.Parent = dropdownchildren
				addCorner(searchHolder, UDim.new(0, 5))

				local searchIcon = Instance.new('ImageLabel')
				searchIcon.BackgroundTransparency = 1
				searchIcon.Image = gettenacityasset('tenacity/assets/new/search.png')
				searchIcon.ImageColor3 = color.Dark(uipallet.Text, 0.32)
				searchIcon.Position = UDim2.fromOffset(8, 7)
				searchIcon.Size = UDim2.fromOffset(11, 11)
				searchIcon.Parent = searchHolder

				searchBox = Instance.new('TextBox')
				searchBox.BackgroundTransparency = 1
				searchBox.ClearTextOnFocus = false
				searchBox.FontFace = uipallet.Font
				searchBox.PlaceholderColor3 = color.Dark(uipallet.Text, 0.38)
				searchBox.PlaceholderText = 'Search options...'
				searchBox.Position = UDim2.fromOffset(25, 0)
				searchBox.Size = UDim2.new(1, -30, 1, 0)
				searchBox.Text = ''
				searchBox.TextColor3 = uipallet.Text
				searchBox.TextSize = 12
				searchBox.TextXAlignment = Enum.TextXAlignment.Left
				searchBox.Parent = searchHolder
			end

			optionScroller = Instance.new('ScrollingFrame')
			optionScroller.Active = true
			optionScroller.BackgroundTransparency = 1
			optionScroller.BorderSizePixel = 0
			optionScroller.CanvasSize = UDim2.new()
			optionScroller.ClipsDescendants = true
			optionScroller.Position = UDim2.fromOffset(0, searchHeight)
			optionScroller.ScrollBarImageColor3 = color.Dark(uipallet.Text, 0.16)
			optionScroller.ScrollBarImageTransparency = 1
			optionScroller.ScrollBarThickness = 2
			optionScroller.ScrollingDirection = Enum.ScrollingDirection.Y
			optionScroller.Size = UDim2.new(1, 0, 0, 0)
			optionScroller.Parent = dropdownchildren

			local optionLayout = Instance.new('UIListLayout')
			optionLayout.SortOrder = Enum.SortOrder.LayoutOrder
			optionLayout.Parent = optionScroller

			emptyLabel = Instance.new('TextLabel')
			emptyLabel.BackgroundTransparency = 1
			emptyLabel.FontFace = uipallet.Font
			emptyLabel.Position = UDim2.fromOffset(0, searchHeight)
			emptyLabel.Size = UDim2.new(1, 0, 0, 28)
			emptyLabel.Text = 'No matching options'
			emptyLabel.TextColor3 = color.Dark(uipallet.Text, 0.4)
			emptyLabel.TextSize = 11
			emptyLabel.Visible = false
			emptyLabel.Parent = dropdownchildren

			for index, value in values do
				local entry = Instance.new('TextButton')
				entry.AutoButtonColor = false
				entry.BackgroundColor3 = uipallet.Main
				entry.BackgroundTransparency = 1
				entry.BorderSizePixel = 0
				entry.FontFace = uipallet.Font
				entry.LayoutOrder = index
				entry.Name = 'Option'
				entry.Size = UDim2.new(1, -2, 0, 26)
				entry.Text = '         '..value
				entry.TextColor3 = color.Dark(uipallet.Text, 0.16)
				entry.TextTransparency = 1
				entry.TextSize = 13
				entry.TextTruncate = Enum.TextTruncate.AtEnd
				entry.TextXAlignment = Enum.TextXAlignment.Left
				entry.Parent = optionScroller
				entry:SetAttribute('SearchValue', tostring(value):lower())
				table.insert(optionEntries, entry)

				task.delay(math.min(index - 1, 7) * 0.014, function()
					if entry.Parent and dropdownOpen then
						tween:Tween(entry, uiMotion, {TextTransparency = 0, BackgroundTransparency = 0})
					end
				end)

				entry.MouseEnter:Connect(function()
					tween:Tween(entry, uiMotionFast, {
						BackgroundColor3 = color.Light(uipallet.Main, 0.02),
						TextColor3 = uipallet.Text
					})
				end)

				entry.MouseLeave:Connect(function()
					tween:Tween(entry, uiMotionFast, {
						BackgroundColor3 = uipallet.Main,
						TextColor3 = color.Dark(uipallet.Text, 0.16)
					})
				end)

				entry.MouseButton1Click:Connect(function()
					component:SetValue(value, true)
				end)
			end

			local function updateFilter()
				if not dropdownOpen or not dropdownchildren then return end
				local query = searchBox and searchBox.Text:lower():gsub('^%s+', ''):gsub('%s+$', '') or ''
				local visible = 0
				for _, entry in optionEntries do
					local matches = query == '' or entry:GetAttribute('SearchValue'):find(query, 1, true) ~= nil
					entry.Visible = matches
					if matches then visible += 1 end
				end

				local rows = math.min(visible, maxRows)
				local listHeight = rows * 26
				emptyLabel.Visible = visible == 0
				optionScroller.Visible = visible > 0
				optionScroller.CanvasPosition = Vector2.zero
				optionScroller.CanvasSize = UDim2.fromOffset(0, visible * 26)
				optionScroller.ScrollBarImageTransparency = visible > maxRows and 0.35 or 1
				optionScroller.Size = UDim2.new(1, 0, 0, visible == 0 and 0 or listHeight)

				local bodyHeight = searchHeight + (visible == 0 and 28 or listHeight) + 4
				dropdownchildren.Size = UDim2.new(1, 0, 0, bodyHeight)
				tween:Tween(dropdown, uiMotion, {Size = UDim2.new(1, 0, 0, 31 + bodyHeight)})
			end

			if searchBox then
				searchBox:GetPropertyChangedSignal('Text'):Connect(updateFilter)
			end
			updateFilter()

			-- Large dropdowns behave like a command palette: open and type immediately.
			if searchBox and optionCount > maxRows then
				task.defer(function()
					if dropdownOpen and searchBox and searchBox.Parent then searchBox:CaptureFocus() end
				end)
			end
		end

		button.MouseButton1Click:Connect(function()
			if dropdownchildren then
				closeDropdown()
			else
				openDropdown()
			end
		end)

		dropdown.MouseEnter:Connect(function()
			tween:Tween(holder, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.0875)
			})
		end)

		dropdown.MouseLeave:Connect(function()
			tween:Tween(holder, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			})
		end)

		api.Options[props.Name] = component
		return component
	end,
	Font = function(props, children, api)
		local fonts = {
			props.Default,
			'Custom'
		}

		for _, v in Enum.Font:GetEnumItems() do
			if not table.find(fonts, v.Name) then
				table.insert(fonts, v.Name)
			end
		end

		local component = {
			Value = Font.fromEnum(Enum.Font[fonts[1]])
		}
		local fontdropdown
		local fontbox
		props.Function = props.Function or function() end

		fontdropdown = components.Dropdown({
			Name = props.Name,
			List = fonts,
			Function = function(val)
				fontbox.Object.Visible = val == 'Custom' and fontdropdown.Object.Visible
				if val ~= 'Custom' then
					component.Value = Font.fromEnum(Enum.Font[val])
					props.Function(component.Value)
				else
					pcall(function()
						component.Value = Font.fromId(tonumber(fontbox.Value))
					end)

					props.Function(component.Value)
				end
			end,
			Darker = props.Darker,
			Visible = props.Visible
		}, children, api)
		component.Object = fontdropdown.Object

		fontbox = components.TextBox({
			Name = props.Name..' Asset',
			Placeholder = 'font (rbxasset)',
			Function = function()
				if fontdropdown.Value == 'Custom' then
					pcall(function()
						component.Value = Font.fromId(tonumber(fontbox.Value))
					end)

					props.Function(component.Value)
				end
			end,
			Visible = false,
			Darker = true
		}, children, api)

		fontdropdown.Object:GetPropertyChangedSignal('Visible'):Connect(function()
			fontbox.Object.Visible = fontdropdown.Object.Visible and fontdropdown.Value == 'Custom'
		end)

		return component
	end,
	GUI = function(props, children, api)
		local component = {
			Buttons = {},
			Type = 'MainWindow'
		}

		local window = Instance.new('TextButton')
		window.AutoButtonColor = false
		window.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		window.Name = 'GUICategory'
		window.Position = UDim2.fromOffset(6, 60)
		window.Text = ''
		window.Parent = clickgui
		component.Object = window
		addBlur(window)
		addCorner(window)
		addDragHandler(window)
		local logo = Instance.new('ImageLabel')
		logo.BackgroundTransparency = 1
		logo.Image = gettenacityasset('tenacity/assets/tenacity/modernlogo.png')
		logo.ImageColor3 = select(3, uipallet.Main:ToHSV()) > 0.5 and uipallet.Text or Color3.new(1, 1, 1)
		logo.Name = 'TenacityLogo'
		logo.Position = UDim2.fromOffset(12, 11)
		logo.Size = UDim2.fromOffset(55, 16)
		logo.Parent = window
		local editionLogo = Instance.new('ImageLabel')
		editionLogo.BackgroundTransparency = 1
		editionLogo.Image = ''; editionLogo.Visible = false
		editionLogo.Name = 'EditionBadge'
		editionLogo.Position = UDim2.new(1, -1, 0, 0)
		editionLogo.Size = UDim2.fromOffset(23, 16)
		editionLogo.Parent = logo

		local children = Instance.new('Frame')
		children.BackgroundTransparency = 1
		children.Position = UDim2.fromOffset(0, 37)
		children.Size = UDim2.new(1, 0, 1, -33)
		children.Parent = window
		local windowlist = Instance.new('UIListLayout')
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.Parent = children
		local settingsbutton = Instance.new('TextButton')
		settingsbutton.BackgroundTransparency = 1
		settingsbutton.Position = UDim2.new(1, -40, 0, 0)
		settingsbutton.Size = UDim2.fromOffset(40, 40)
		settingsbutton.Text = ''
		settingsbutton.Parent = window
		addTooltip(settingsbutton, 'Open settings')
		local settingsicon = Instance.new('ImageLabel')
		settingsicon.BackgroundTransparency = 1
		settingsicon.Image = gettenacityasset('tenacity/assets/new/settings.png')
		settingsicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		settingsicon.Position = UDim2.fromOffset(15, 12)
		settingsicon.Size = UDim2.fromOffset(14, 14)
		settingsicon.Parent = settingsbutton
		local discord = Instance.new('ImageButton')
		discord.BackgroundTransparency = 1
		discord.Image = gettenacityasset('tenacity/assets/new/discord.png')
		discord.Position = UDim2.new(1, -56, 0, 11)
		discord.Size = UDim2.fromOffset(16, 16)
		discord.Parent = window
		addTooltip(discord, 'Join discord')
		local stroke = Instance.new('UIStroke')
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(85, 85, 85)
		stroke.Transparency = 0.8
		stroke.Parent = window
		tenacity:RegisterGUIStyleObject(window, 'MainWindow')
		local settingspane = components.SettingsPane({
			Name = 'Settings',
			Main = true
		}, window, component)
		component.Settings = settingspane

		function component:Color(hue, sat, val, isRainbow)
			local accentColor = Color3.fromHSV(hue, sat, val)
			if not tenacity:ApplyThemeGradient(editionLogo, 'ImageColor3', 0, true, 0) then
				editionLogo.ImageColor3 = accentColor
			end

			for _, button in self.Buttons do
				if button.Enabled then
					button.Object.TextColor3 = isRainbow and Color3.fromHSV(tenacity:Color((hue - (button.Index * 0.025)) % 1)) or Color3.fromHSV(hue, sat, val)

					if button.Icon then
						button.Icon.ImageColor3 = button.Object.TextColor3
					end
				end
			end
		end

		function component:Load(data)
			for name, paneData in data.Settings do
				local pane = tenacity.Settings[name]
				if pane then
					pane:Load(paneData)
				end
			end

			if data.Position then
				window.Position = UDim2.fromOffset(data.Position.X, data.Position.Y)
			end
		end

		function component:Save(data)
			data.Main = {
				Position = {
					X = window.Position.X.Offset,
					Y = window.Position.Y.Offset
				},
				Settings = {}
			}

			for name, pane in tenacity.Settings do
				pane:Save(data.Main.Settings)
			end
		end

		for index, comp in components do
			component['Create'..index] = function(_, props)
				return comp(props, children, component)
			end
		end

		discord.MouseButton1Click:Connect(function()
			task.spawn(function()
				local body = httpService:JSONEncode({
					nonce = httpService:GenerateGUID(false),
					args = {
						invite = {code = 'VZEQJxMSnG'},
						code = 'VZEQJxMSnG'
					},
					cmd = 'INVITE_BROWSER'
				})

				for i = 1, 14 do
					task.spawn(function()
						pcall(function()
							request({
								Method = 'POST',
								Url = 'http://127.0.0.1:64'..(53 + i)..'/rpc?v=1',
								Headers = {
									['Content-Type'] = 'application/json',
									Origin = 'https://discord.com'
								},
								Body = body
							})
						end)
					end)
				end
			end)

			task.spawn(function()
				tooltip.Text = 'Copied!'
				setclipboard('https://discord.gg/VZEQJxMSnG')
			end)
		end)

		settingsbutton.MouseEnter:Connect(function()
			settingsicon.ImageColor3 = uipallet.Text
		end)

		settingsbutton.MouseLeave:Connect(function()
			settingsicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		end)

		settingsbutton.MouseButton1Click:Connect(function()
			settingspane:SetVisible(true)
		end)

		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			window.Size = UDim2.fromOffset(220, 42 + windowlist.AbsoluteContentSize.Y / scale.Scale)
			for _, button in component.Buttons do
				if button.Icon then
					button.Object.Text = string.rep(' ', 39 * scale.Scale)..button.Name
				end
			end
		end)

		tenacity.Categories.Main = component

		return component
	end,
	GUIButton = function(props, children, api)
		local component = {
			Enabled = false,
			Index = getTableSize(api.Buttons),
			Name = props.Name
		}

		local button = Instance.new('TextButton')
		button.AutoButtonColor = false
		button.BackgroundColor3 = uipallet.Main
		button.BorderSizePixel = 0
		button.FontFace = uipallet.Font
		button.Name = props.Name
		button.Size = UDim2.fromOffset(220, 40)
		button.Text = (props.Icon and string.rep(' ', 39) or props.Window and string.rep(' ', 17) or string.rep(' ', 10))..props.Name
		button.TextColor3 = color.Dark(uipallet.Text, 0.16)
		button.TextSize = 14
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Parent = children
		component.Object = button
		tenacity:RegisterGUIStyleObject(button, 'ControlRow')

		local icon
		if props.Icon then
			icon = Instance.new('ImageLabel')
			icon.BackgroundTransparency = 1
			icon.Image = props.Icon
			icon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
			icon.Position = UDim2.fromOffset(16, 13)
			icon.Size = props.Size
			icon.Parent = button
			component.Icon = icon
		end

		if props.Name == 'Profiles' then
			local label = Instance.new('TextLabel')
			label.AnchorPoint = Vector2.new(1, 0)
			label.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
			label.FontFace = uipallet.Font
			label.Position = UDim2.new(1, -36, 0, 8)
			label.Size = UDim2.fromOffset(53, 24)
			label.Text = 'default'
			label.TextColor3 = color.Dark(uipallet.Text, 0.29)
			label.TextSize = 12
			label.Parent = button
			addCorner(label)
			tenacity.ProfileLabel = label
		end

		local arrow = Instance.new('ImageLabel')
		arrow.BackgroundTransparency = 1
		arrow.Image = gettenacityasset('tenacity/assets/new/expandarrow.png')
		arrow.ImageColor3 = color.Light(uipallet.Main, 0.37)
		arrow.Name = 'Arrow'
		arrow.Position = UDim2.new(1, -20, 0, 16)
		arrow.Size = UDim2.fromOffset(4, 8)
		arrow.Parent = button
		local windowTransition = 0
		local windowHomePosition

		function component:Destroy()
			button:Destroy()
			button:ClearAllChildren()
		end

		function component:Toggle()
			if props.Window then
				self.Enabled = not self.Enabled
				windowTransition += 1
				local transition = windowTransition
				tween:Tween(arrow, uiMotionPop, {
					Position = UDim2.new(1, self.Enabled and -14 or -20, 0, 16)
				})

				tween:Tween(button, uiMotionFast, {BackgroundColor3 = color.Light(uipallet.Main, 0.02)})
				if self.Enabled then
					tenacity:RegisterThemeSolid(button, 'TextColor3', 0.02)
					if icon then tenacity:RegisterThemeSolid(icon, 'ImageColor3', 0.08) end
				else
					tenacity:UnregisterThemeSolid(button)
					button.TextColor3 = uipallet.Text
					if icon then
						tenacity:UnregisterThemeSolid(icon)
						icon.ImageColor3 = uipallet.Text
					end
				end

				if self.Enabled then
					local target = windowHomePosition or props.Window.Position
					props.Window.Visible = true
					if tenacity.ReducedMotion and tenacity.ReducedMotion.Enabled then
						props.Window.Position = target
					else
						-- Stay fully inside the window bounds: settle horizontally instead of scaling past the edge.
						props.Window.Position = target + UDim2.fromOffset(10, 0)
						tween:Tween(props.Window, uiMotionPop, {Position = target})
					end
				else
					windowHomePosition = props.Window.Position
					local target = windowHomePosition
					local motion = tween:Tween(props.Window, uiMotionFast, {Position = target + UDim2.fromOffset(8, 0)})
					local function finishClose()
						if transition == windowTransition and not component.Enabled then
							props.Window.Visible = false
							props.Window.Position = target
						end
					end
					if motion then motion.Completed:Once(finishClose) else finishClose() end
				end
			else
				props.Function()
			end
		end

		button.MouseEnter:Connect(function()
			if not component.Enabled then
				button.TextColor3 = uipallet.Text
				if icon then
					icon.ImageColor3 = uipallet.Text
				end

				button.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			end
		end)

		button.MouseLeave:Connect(function()
			if not component.Enabled then
				button.TextColor3 = color.Dark(uipallet.Text, 0.16)
				if icon then
					icon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
				end

				button.BackgroundColor3 = uipallet.Main
			end
		end)

		button.MouseButton1Click:Connect(function()
			component:Toggle()
		end)

		api.Buttons[props.Name] = component

		return component
	end,
	GUISlider = function(props, children, api)
		local component = {
			CustomColor = false,
			Hue = 0.46,
			Notch = 4,
			Rainbow = false,
			Sat = 0.96,
			Type = 'GUISlider',
			Value = 0.52
		}
		local colors = {
			Color3.fromRGB(250, 50, 56),
			Color3.fromRGB(242, 99, 33),
			Color3.fromRGB(252, 179, 22),
			Color3.fromRGB(5, 133, 104),
			Color3.fromRGB(47, 122, 229),
			Color3.fromRGB(126, 84, 217),
			Color3.fromRGB(232, 96, 152)
		}
		local colorPositions = {
			4,
			33,
			62,
			90,
			119,
			148,
			177
		}

		local function createSlider(name, gradientColor)
			local slider = Instance.new('TextButton')
			slider.Name = props.Name..'Slider'..name
			slider.Size = UDim2.fromOffset(220, 50)
			slider.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			slider.BorderSizePixel = 0
			slider.AutoButtonColor = false
			slider.Visible = false
			slider.Text = ''
			slider.Parent = children
			local title = Instance.new('TextLabel')
			title.BackgroundTransparency = 1
			title.FontFace = uipallet.Font
			title.Position = UDim2.fromOffset(10, 2)
			title.Size = UDim2.fromOffset(60, 30)
			title.Text = name
			title.TextColor3 = color.Dark(uipallet.Text, 0.16)
			title.TextSize = 11
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = slider
			local holder = Instance.new('Frame')
			holder.BackgroundColor3 = Color3.new(1, 1, 1)
			holder.BorderSizePixel = 0
			holder.Name = 'Holder'
			holder.Position = UDim2.fromOffset(10, 37)
			holder.Size = UDim2.new(1, -20, 0, 2)
			holder.Parent = slider
			local uigradient = Instance.new('UIGradient')
			uigradient.Color = gradientColor
			uigradient.Parent = holder
			local fill = Instance.new('Frame')
			fill.BackgroundTransparency = 1
			fill.Name = 'Fill'
			fill.Size = UDim2.fromScale(math.clamp(1, 0.04, 0.96), 1)
			fill.Parent = holder
			local knobholder = Instance.new('Frame')
			knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
			knobholder.BackgroundColor3 = slider.BackgroundColor3
			knobholder.BorderSizePixel = 0
			knobholder.Position = UDim2.fromScale(1, 0.5)
			knobholder.Size = UDim2.fromOffset(24, 4)
			knobholder.Parent = fill
			local knob = Instance.new('Frame')
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.BackgroundColor3 = uipallet.Text
			knob.Position = UDim2.fromScale(0.5, 0.5)
			knob.Size = UDim2.fromOffset(14, 14)
			knob.Parent = knobholder
			addCorner(knob, UDim.new(1, 0))

			if name == 'Custom color' then
				local reset = Instance.new('TextButton')
				reset.BackgroundTransparency = 1
				reset.FontFace = uipallet.Font
				reset.Position = UDim2.new(1, -52, 0, 5)
				reset.Size = UDim2.fromOffset(45, 20)
				reset.Text = 'RESET'
				reset.TextColor3 = color.Dark(uipallet.Text, 0.16)
				reset.TextSize = 11
				reset.Parent = slider

				reset.MouseButton1Click:Connect(function()
					component:SetValue(nil, nil, nil, 4)
				end)
			end

			slider.InputBegan:Connect(function(input)
				if
					(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
					and (input.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
				then
					local releaseConnection
					local moveConnection = inputService.InputChanged:Connect(function(newInput)
						if newInput.UserInputType == (input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
							local value = math.clamp((newInput.Position.X - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1)
							component:SetValue(
								name == 'Custom color' and value or nil,
								name == 'Saturation' and value or nil,
								name == 'Vibrance' and value or nil,
								name == 'Opacity' and value or nil
							)
						end
					end)

					releaseConnection = input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End then
							moveConnection:Disconnect()
							releaseConnection:Disconnect()
						end
					end)
				end
			end)

			slider.MouseEnter:Connect(function()
				tween:Tween(knob, uipallet.Tween, {
					Size = UDim2.fromOffset(16, 16)
				})
			end)

			slider.MouseLeave:Connect(function()
				tween:Tween(knob, uipallet.Tween, {
					Size = UDim2.fromOffset(14, 14)
				})
			end)

			return slider
		end

		local slider = Instance.new('TextButton')
		slider.AutoButtonColor = false
		slider.BackgroundTransparency = 1
		slider.Name = props.Name..'Slider'
		slider.Size = UDim2.fromOffset(220, 50)
		slider.Text = ''
		slider.Parent = children
		component.Object = slider
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Name = 'Title'
		title.Position = UDim2.fromOffset(10, 2)
		title.Size = UDim2.fromOffset(60, 30)
		title.Text = props.Name
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 11
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = slider
		local holder = Instance.new('Frame')
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.Name = 'Slider'
		holder.Position = UDim2.fromOffset(10, 37)
		holder.Size = UDim2.fromOffset(200, 2)
		holder.Parent = slider
		local colorXPos = 0
		for index, colorValue in colors do
			local colorframe = Instance.new('Frame')
			colorframe.BackgroundColor3 = colorValue
			colorframe.BorderSizePixel = 0
			colorframe.Position = UDim2.fromOffset(colorXPos, 0)
			colorframe.Size = UDim2.fromOffset(27 + (((index + 1) % 2) == 0 and 1 or 0), 2)
			colorframe.Parent = holder
			colorXPos += (colorframe.Size.X.Offset + 1)
		end
		local preview = Instance.new('ImageButton')
		preview.BackgroundTransparency = 1
		preview.Image = gettenacityasset('tenacity/assets/new/colorpreview.png')
		preview.ImageColor3 = Color3.fromHSV(component.Hue, component.Sat, component.Value)
		preview.Position = UDim2.new(1, -22, 0, 10)
		preview.Size = UDim2.fromOffset(12, 12)
		preview.Parent = slider
		local custombox = Instance.new('TextBox')
		custombox.BackgroundTransparency = 1
		custombox.FontFace = uipallet.Font
		custombox.Position = UDim2.new(1, -69, 0, 9)
		custombox.Size = UDim2.fromOffset(60, 15)
		custombox.Text = ''
		custombox.TextColor3 = color.Dark(uipallet.Text, 0.16)
		custombox.TextSize = 11
		custombox.TextXAlignment = Enum.TextXAlignment.Right
		custombox.Visible = false
		custombox.Parent = slider
		local expand = Instance.new('TextButton')
		expand.BackgroundTransparency = 1
		expand.Position = UDim2.new(0, getfontbounds(title.Text, title.TextSize, title.Font).X + 11, 0, 7)
		expand.Size = UDim2.fromOffset(17, 13)
		expand.Text = ''
		expand.Parent = slider
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = gettenacityasset('tenacity/assets/new/downexpandslider.png')
		icon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		icon.Position = UDim2.fromOffset(4, 4)
		icon.Size = UDim2.fromOffset(10, 5)
		icon.Parent = expand
		local rainbow = Instance.new('TextButton')
		rainbow.BackgroundTransparency = 1
		rainbow.Position = UDim2.new(1, -42, 0, 10)
		rainbow.Size = UDim2.fromOffset(12, 12)
		rainbow.Text = ''
		rainbow.Parent = slider
		local ring1 = Instance.new('ImageLabel')
		ring1.BackgroundTransparency = 1
		ring1.Image = gettenacityasset('tenacity/assets/new/rainbow_1.png')
		ring1.ImageColor3 = color.Light(uipallet.Main, 0.37)
		ring1.Size = UDim2.fromOffset(12, 12)
		ring1.Parent = rainbow
		local ring2 = Instance.fromExisting(ring1)
		ring2.Image = gettenacityasset('tenacity/assets/new/rainbow_2.png')
		ring2.Parent = rainbow
		local ring3 = Instance.fromExisting(ring1)
		ring3.Image = gettenacityasset('tenacity/assets/new/rainbow_3.png')
		ring3.Parent = rainbow
		local ring4 = Instance.fromExisting(ring1)
		ring4.Image = gettenacityasset('tenacity/assets/new/rainbow_4.png')
		ring4.Parent = rainbow
		local knob = Instance.new('ImageLabel')
		knob.BackgroundTransparency = 1
		knob.Image = gettenacityasset('tenacity/assets/new/theme.png')
		knob.ImageColor3 = colors[4]
		knob.Name = 'Knob'
		knob.Position = UDim2.fromOffset(colorPositions[4] - 3, -5)
		knob.Size = UDim2.fromOffset(26, 12)
		knob.Parent = holder
		props.Function = props.Function or function() end
		local rainbowTable = {}
		for i = 0, 1, 0.1 do
			table.insert(rainbowTable, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
		end

		local colorSlider = createSlider('Custom color', ColorSequence.new(rainbowTable))
		local satSlider = createSlider('Saturation', ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, component.Value)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(component.Hue, 1, component.Value))
		}))

		local vibSlider = createSlider('Vibrance', ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(component.Hue, component.Sat, 1))
		}))

		local normalknob = gettenacityasset('tenacity/assets/new/theme.png')
		local rainbowknob = gettenacityasset('tenacity/assets/new/customtheme.png')
		local rainbowthread
		local currentNotch

		function component:Load(data)
			if data.Rainbow then
				self:Toggle()
			end

			if self.Rainbow or data.CustomColor then
				self:SetValue(data.Hue, data.Sat, data.Value)
			else
				self:SetValue(nil, nil, nil, data.Notch)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				Hue = self.Hue,
				Sat = self.Sat,
				Value = self.Value,
				Notch = self.Notch,
				CustomColor = self.CustomColor,
				Rainbow = self.Rainbow
			}
		end

		function component:SetValue(h, s, v, n)
			if n then
				if self.Rainbow then
					self:Toggle()
				end

				self.CustomColor = false
				h, s, v = colors[n]:ToHSV()
			else
				self.CustomColor = true
			end

			self.Hue = h or self.Hue
			self.Sat = s or self.Sat
			self.Value = v or self.Value
			self.Notch = n
			preview.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)

			satSlider.Holder.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, self.Value)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, 1, self.Value))
			})

			vibSlider.Holder.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, 1))
			})

			local newNotch = (self.Rainbow or self.CustomColor) and 4 or n or currentNotch
			if self.Rainbow or self.CustomColor then
				knob.Image = rainbowknob
				knob.ImageColor3 = Color3.new(1, 1, 1)

				if newNotch ~= currentNotch then
					tween:Tween(knob, uipallet.Tween, {
						Position = UDim2.fromOffset(colorPositions[4] - 3, -5)
					})
				end
			else
				knob.Image = normalknob
				knob.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)

				if newNotch ~= currentNotch then
					tween:Tween(knob, uipallet.Tween, {
						Position = UDim2.fromOffset(colorPositions[n or 4] - 3, -5)
					})
				end
			end

			currentNotch = newNotch
			if self.Rainbow then
				if h then
					colorSlider.Holder.Fill.Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
				end

				if s then
					satSlider.Holder.Fill.Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
				end

				if v then
					vibSlider.Holder.Fill.Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
				end
			else
				if h then
					tween:Tween(colorSlider.Holder.Fill, uipallet.Tween, {
						Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
					})
				end

				if s then
					tween:Tween(satSlider.Holder.Fill, uipallet.Tween, {
						Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
					})
				end

				if v then
					tween:Tween(vibSlider.Holder.Fill, uipallet.Tween, {
						Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
					})
				end
			end

			props.Function(self.Hue, self.Sat, self.Value)
		end

		function component:Toggle()
			self.Rainbow = not self.Rainbow
			if rainbowthread then
				task.cancel(rainbowthread)
			end

			if self.Rainbow then
				knob.Image = rainbowknob
				table.insert(tenacity.RainbowSliders, self)

				ring1.ImageColor3 = Color3.fromRGB(5, 127, 100)
				rainbowthread = task.delay(0.1, function()
					ring2.ImageColor3 = Color3.fromRGB(228, 125, 43)
					rainbowthread = task.delay(0.1, function()
						ring3.ImageColor3 = Color3.fromRGB(225, 46, 52)
						rainbowthread = nil
					end)
				end)
			else
				self:SetValue(nil, nil, nil, 4)
				knob.Image = normalknob
				local index = table.find(tenacity.RainbowSliders, self)
				if index then
					table.remove(tenacity.RainbowSliders, index)
				end

				ring3.ImageColor3 = color.Light(uipallet.Main, 0.37)
				rainbowthread = task.delay(0.1, function()
					ring2.ImageColor3 = color.Light(uipallet.Main, 0.37)
					rainbowthread = task.delay(0.1, function()
						ring1.ImageColor3 = color.Light(uipallet.Main, 0.37)
						rainbowthread = nil
					end)
				end)
			end
		end

		expand.MouseEnter:Connect(function()
			icon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
		end)

		expand.MouseLeave:Connect(function()
			icon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		end)

		expand.MouseButton1Click:Connect(function()
			colorSlider.Visible = not colorSlider.Visible
			satSlider.Visible = colorSlider.Visible
			vibSlider.Visible = satSlider.Visible
			icon.Rotation = satSlider.Visible and 180 or 0
		end)

		preview.MouseButton1Click:Connect(function()
			preview.Visible = false
			custombox.Visible = true
			custombox:CaptureFocus()
			local text = Color3.fromHSV(component.Hue, component.Sat, component.Value)
			custombox.Text = math.round(text.R * 255)..', '..math.round(text.G * 255)..', '..math.round(text.B * 255)
		end)

		slider.InputBegan:Connect(function(input)
			if
				(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
				and (input.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
			then
				local releaseConnection
				local moveConnection = inputService.InputChanged:Connect(function(newInput)
					if newInput.UserInputType == (input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
						component:SetValue(nil, nil, nil, math.clamp(math.round((newInput.Position.X - holder.AbsolutePosition.X) / scale.Scale / 27), 1, 7))
					end
				end)

				releaseConnection = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						moveConnection:Disconnect()
						releaseConnection:Disconnect()
					end
				end)

				component:SetValue(nil, nil, nil, math.clamp(math.round((input.Position.X - holder.AbsolutePosition.X) / scale.Scale / 27), 1, 7))
			end
		end)

		rainbow.MouseButton1Click:Connect(function()
			component:Toggle()
		end)

		custombox.FocusLost:Connect(function(enter)
			preview.Visible = true
			custombox.Visible = false

			if enter then
				local success, parsed = pcall(function()
					local commas = custombox.Text:split(',')
					return tonumber(commas[1]) and Color3.fromRGB(tonumber(commas[1]), tonumber(commas[2]), tonumber(commas[3])) or Color3.fromHex(custombox.Text)
				end)

				if success then
					if component.Rainbow then
						component:Toggle()
					end

					component:SetValue(parsed:ToHSV())
				end
			end
		end)

		api.Options[props.Name] = component

		return component
	end,
	ImageToggle = function(props, children, api)
		local component = {
			Enabled = false,
			Index = getTableSize(api.Options),
			Type = 'ImageToggle'
		}

		local isHover = false
		local toggle = Instance.new('TextButton')
		toggle.AutoButtonColor = false
		toggle.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
		toggle.BorderSizePixel = 0
		toggle.FontFace = uipallet.Font
		toggle.Size = UDim2.new(1, 0, 0, 40)
		toggle.Text = string.rep(' ', 33 * scale.Scale)..props.Name
		toggle.TextColor3 = color.Dark(uipallet.Text, 0.16)
		toggle.TextSize = 14
		toggle.TextXAlignment = Enum.TextXAlignment.Left
		toggle.Visible = props.Visible == nil or props.Visible
		toggle.Parent = children
		component.Object = toggle
		tenacity:RegisterGUIStyleObject(toggle, 'ControlRow')
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = props.Icon
		icon.ImageColor3 = uipallet.Text
		icon.Name = 'Icon'
		icon.Position = props.Position
		icon.Size = props.Size
		icon.Parent = toggle
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		holder.Name = 'Knob'
		holder.Position = UDim2.new(1, -30, 0, 14)
		holder.Size = UDim2.fromOffset(22, 12)
		holder.Parent = toggle
		addCorner(holder, UDim.new(1, 0))
		tenacity:RegisterGUIStyleObject(holder, 'ImageToggleTrack')
		local knob = Instance.new('Frame')
		knob.BackgroundColor3 = uipallet.Main
		knob.Position = UDim2.fromOffset(2, 2)
		knob.Size = UDim2.fromOffset(8, 8)
		knob.Parent = holder
		addCorner(knob, UDim.new(1, 0))
		tenacity:ApplyGUIStyleObject(holder, 'ImageToggleTrack')
		props.Function = props.Function or function() end

		function component:Color(hue, sat, val, isRainbow)
			if self.Enabled then
				tween:Cancel(holder)
				if not tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, true, 0) then
					holder.BackgroundColor3 = isRainbow and Color3.fromHSV(tenacity:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
				end
			else
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, false, 0)
			end
		end

		function component:Toggle()
			self.Enabled = not self.Enabled
			if self.Enabled then
				tween:Cancel(holder)
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, true, 0)
			else
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, false, 0)
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = isHover and color.Light(uipallet.Main, 0.37) or color.Light(uipallet.Main, 0.14)
				})
			end

			tween:Tween(knob, uiMotionPop, {
				Position = UDim2.fromOffset(self.Enabled and 12 or 2, 2)
			})

			props.Function(self.Enabled)
		end

		scale:GetPropertyChangedSignal('Scale'):Connect(function()
			toggle.Text = string.rep(' ', 33 * scale.Scale)..props.Name
		end)

		toggle.MouseEnter:Connect(function()
			isHover = true

			if not component.Enabled then
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.37)
				})
			end
		end)

		toggle.MouseLeave:Connect(function()
			isHover = false

			if not component.Enabled then
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.14)
				})
			end
		end)

		toggle.MouseButton1Click:Connect(function()
			component:Toggle()
		end)

		if props.Default then
			component:Toggle()
		end

		api.Options[props.Name] = component

		return component
	end,
	AuxiliaryModule = function(props, children, api)
		tenacity:Remove(props.Name)
		local component = {
			Enabled = false,
			Auxiliary = true,
			Name = props.Name,
			Options = {},
			Type = 'AuxiliaryModule'
		}

		local button = Instance.new('TextButton')
		button.AutoButtonColor = false
		button.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		button.Name = props.Name
		button.Text = ''
		button.Parent = children
		component.Object = button
		addTooltip(button, props.Tooltip, nil, function()
			return tenacity.AuxiliaryVisible
		end)
		addCorner(button)
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(16, 81)
		title.Size = UDim2.new(1, -16, 0, 20)
		title.Text = props.Name
		title.TextColor3 = color.Dark(uipallet.Text, 0.31)
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = button
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		holder.Position = UDim2.new(1, -57, 0, 15)
		holder.Size = UDim2.fromOffset(22, 12)
		holder.Parent = button
		addCorner(holder, UDim.new(1, 0))
		local knob = Instance.new('Frame')
		knob.BackgroundColor3 = uipallet.Main
		knob.Position = UDim2.fromOffset(2, 2)
		knob.Size = UDim2.fromOffset(8, 8)
		knob.Parent = holder
		addCorner(knob, UDim.new(1, 0))
		local dotsbutton = Instance.new('TextButton')
		dotsbutton.BackgroundTransparency = 1
		dotsbutton.Name = 'Dots'
		dotsbutton.Position = UDim2.new(1, -27, 0, 9)
		dotsbutton.Size = UDim2.fromOffset(14, 24)
		dotsbutton.Text = ''
		dotsbutton.Parent = button
		local dots = Instance.new('ImageLabel')
		dots.BackgroundTransparency = 1
		dots.Image = gettenacityasset('tenacity/assets/new/overlaydots.png')
		dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
		dots.Name = 'Dots'
		dots.Position = UDim2.fromOffset(6, 6)
		dots.Size = UDim2.fromOffset(2, 12)
		dots.Parent = dotsbutton
		local shadow = Instance.new('TextButton')
		shadow.Name = 'Shadow'
		shadow.Size = UDim2.new(1, 0, 1, -5)
		shadow.BackgroundColor3 = Color3.new()
		shadow.BackgroundTransparency = 1
		shadow.AutoButtonColor = false
		shadow.ClipsDescendants = true
		shadow.Visible = false
		shadow.Text = ''
		shadow.Parent = api.Window
		addCorner(shadow)
		local settingspane = Instance.new('TextButton')
		settingspane.Size = UDim2.new(0, 220, 1, 0)
		settingspane.Position = UDim2.fromScale(1, 0)
		settingspane.BackgroundColor3 = uipallet.Main
		settingspane.AutoButtonColor = false
		settingspane.Text = ''
		settingspane.Parent = shadow
		local settingstitle = Instance.new('TextLabel')
		settingstitle.Name = 'Title'
		settingstitle.Size = UDim2.new(1, -36, 0, 20)
		settingstitle.Position = UDim2.fromOffset(36, 12)
		settingstitle.BackgroundTransparency = 1
		settingstitle.Text = props.Name
		settingstitle.TextXAlignment = Enum.TextXAlignment.Left
		settingstitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
		settingstitle.TextSize = 13
		settingstitle.FontFace = uipallet.Font
		settingstitle.Parent = settingspane
		local back = Instance.new('ImageButton')
		back.Name = 'Back'
		back.Size = UDim2.fromOffset(16, 16)
		back.Position = UDim2.fromOffset(11, 13)
		back.BackgroundTransparency = 1
		back.Image = gettenacityasset('tenacity/assets/new/back.png')
		back.ImageColor3 = color.Light(uipallet.Main, 0.37)
		back.Parent = settingspane
		addCorner(settingspane)
		local settingschildren = Instance.new('ScrollingFrame')
		settingschildren.BackgroundColor3 = uipallet.Main
		settingschildren.BorderSizePixel = 0
		settingschildren.CanvasSize = UDim2.new()
		settingschildren.Name = 'Children'
		settingschildren.Position = UDim2.fromOffset(0, 41)
		settingschildren.ScrollBarThickness = 2
		settingschildren.ScrollBarImageTransparency = 0.75
		settingschildren.Size = UDim2.new(1, 0, 1, -45)
		settingschildren.Parent = settingspane
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Parent = settingschildren
		if props.Size then
			local modulechildren = Instance.new('Frame')
			modulechildren.Size = props.Size
			modulechildren.BackgroundTransparency = 1
			modulechildren.Visible = false
			modulechildren.Parent = scaledgui
			addDragHandler(modulechildren, api.Window)
			local objectstroke = Instance.new('UIStroke')
			objectstroke.Color = Color3.fromRGB(5, 134, 105)
			objectstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			objectstroke.Thickness = 0
			objectstroke.Parent = modulechildren
			component.Children = modulechildren
		end
		props.Function = props.Function or function() end
		addMaid(component)

		function component:Color(hue, sat, val, isRainbow)
			if self.Enabled then
				tween:Cancel(holder)
				if not tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', (self.Index or 0) * 0.075, true, 0) then
					holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			else
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', (self.Index or 0) * 0.075, false, 0)
			end

			for _, component in self.Options do
				if component.Color then
					component:Color(hue, sat, val, isRainbow)
				end
			end
		end

		function component:Load(data)
			tenacity:LoadOptions(self, data.Options)

			if self.Enabled ~= data.Enabled then
				self:Toggle()
			end

			if data.Position and self.Children then
				self.Children.Position = UDim2.fromOffset(data.Position.X, data.Position.Y)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				Enabled = self.Enabled,
				Options = tenacity:SaveOptions(self),
				Position = self.Children and {
					X = self.Children.Position.X.Offset,
					Y = self.Children.Position.Y.Offset
				} or nil
			}
		end

		function component:Toggle()
			self.Enabled = not self.Enabled
			if self.Children then
				self.Children.Visible = self.Enabled
			end

			tween:Tween(title, uiMotionFast, {
				TextColor3 = self.Enabled and color.Light(uipallet.Text, 0.2) or color.Dark(uipallet.Text, 0.31)
			})
			tween:Tween(button, uiMotionFast, {
				BackgroundColor3 = self.Enabled and color.Light(uipallet.Main, 0.05) or color.Light(uipallet.Main, 0.02)
			})

			if self.Enabled then
				tween:Cancel(holder)
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', (self.Index or 0) * 0.075, true, 0)
			else
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', (self.Index or 0) * 0.075, false, 0)
				tween:Tween(holder, uiMotionFast, {BackgroundColor3 = color.Light(uipallet.Main, 0.14)})
			end

			tween:Tween(knob, uipallet.Tween, {
				Position = UDim2.fromOffset(self.Enabled and 12 or 2, 2)
			})

			if not self.Enabled then
				for _, v in self.Connections do
					v:Disconnect()
				end
				table.clear(self.Connections)
			end

			task.spawn(props.Function, self.Enabled)
		end

		for index, comp in components do
			component['Create'..index] = function(_, props)
				return comp(props, settingschildren, component)
			end
		end

		back.MouseEnter:Connect(function()
			back.ImageColor3 = uipallet.Text
		end)

		back.MouseLeave:Connect(function()
			back.ImageColor3 = color.Light(uipallet.Main, 0.37)
		end)

		back.MouseButton1Click:Connect(function()
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 1
			})

			tween:Tween(settingspane, uipallet.Tween, {
				Position = UDim2.fromScale(1, 0)
			})

			task.delay(0.2, function()
				shadow.Visible = false
			end)
		end)

		button.MouseEnter:Connect(function()
			if not component.Enabled then
				tween:Tween(button, uiMotionFast, {BackgroundColor3 = color.Light(uipallet.Main, 0.05)})
			end
		end)

		button.MouseLeave:Connect(function()
			if not component.Enabled then
				tween:Tween(button, uiMotionFast, {BackgroundColor3 = color.Light(uipallet.Main, 0.02)})
			end
		end)

		button.MouseButton1Click:Connect(function()
			component:Toggle()
		end)

		button.MouseButton2Click:Connect(function()
			shadow.Visible = true

			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 0.5
			})

			tween:Tween(settingspane, uipallet.Tween, {
				Position = UDim2.new(1, -220, 0, 0)
			})
		end)

		dotsbutton.MouseButton1Click:Connect(function()
			shadow.Visible = true

			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 0.5
			})

			tween:Tween(settingspane, uipallet.Tween, {
				Position = UDim2.new(1, -220, 0, 0)
			})
		end)

		dotsbutton.MouseEnter:Connect(function()
			dots.ImageColor3 = uipallet.Text
		end)

		dotsbutton.MouseLeave:Connect(function()
			dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
		end)

		shadow.MouseButton1Click:Connect(function()
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 1
			})

			tween:Tween(settingspane, uipallet.Tween, {
				Position = UDim2.fromScale(1, 0)
			})

			task.delay(0.2, function()
				shadow.Visible = false
			end)
		end)

		shadow:GetPropertyChangedSignal('Visible'):Connect(function()
			tooltip.Visible = false
			tenacity.AuxiliaryVisible = shadow.Visible
		end)

		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			settingschildren.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		end)

		api.Modules[props.Name] = component

		local sorting = {}
		for _, mod in api.Modules do
			table.insert(sorting, mod.Name)
		end
		table.sort(sorting)

		for index, name in sorting do
			api.Modules[name].Object.LayoutOrder = index
		end

		return component
	end,
	AuxiliaryWindow = function(props, children, api)
		local component = {
			Modules = {}
		}

		local window = Instance.new('Frame')
		window.BackgroundColor3 = uipallet.Main
		window.Position = UDim2.new(0.5, -350, 0.5, -190)
		window.Size = UDim2.fromOffset(700, 380)
		window.Name = 'AuxiliaryGUI'
		window.Visible = false
		window.Parent = scaledgui
		table.insert(tenacity.Windows, window)
		component.Window = window
		addBlur(window)
		addCorner(window)
		addDragHandler(window)
		tenacity:RegisterGUIStyleObject(window, 'AuxiliaryWindow')
		local modal = Instance.new('TextButton')
		modal.BackgroundTransparency = 1
		modal.Modal = true
		modal.Text = ''
		modal.Parent = window
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = gettenacityasset('tenacity/assets/new/legit_mode_icon.png')
		icon.ImageColor3 = uipallet.Text
		icon.Position = UDim2.fromOffset(18, 11)
		icon.Size = UDim2.fromOffset(16, 16)
		icon.Parent = window
		local close = Instance.new('ImageButton')
		close.BackgroundTransparency = 1
		close.Image = gettenacityasset('tenacity/assets/new/min.png')
		close.ImageColor3 = color.Light(uipallet.Main, 0.24)
		close.Position = UDim2.new(1, -31, 0, 11)
		close.Size = UDim2.fromOffset(16, 16)
		close.Parent = window
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		holder.Position = UDim2.new(1, -253, 0, 42)
		holder.Size = UDim2.fromOffset(242, 29)
		holder.Parent = window
		addCorner(holder, UDim.new(0, 4))
		tenacity:RegisterGUIStyleObject(holder, 'ControlHolder')
		local stroke = Instance.new('UIStroke')
		stroke.Color = color.Light(uipallet.Main, 0.02)
		stroke.Parent = holder
		local searchicon = Instance.new('ImageLabel')
		searchicon.BackgroundTransparency = 1
		searchicon.Image = gettenacityasset('tenacity/assets/new/search.png')
		searchicon.ImageColor3 = color.Light(uipallet.Main, 0.42)
		searchicon.Position = UDim2.new(1, -25, 0, 9)
		searchicon.Size = UDim2.fromOffset(12, 12)
		searchicon.Parent = holder
		local box = Instance.new('TextBox')
		box.BackgroundTransparency = 1
		box.ClearTextOnFocus = false
		box.FontFace = uipallet.Font
		box.PlaceholderColor3 = color.Dark(uipallet.Text, 0.16)
		box.PlaceholderText = 'Search mods'
		box.Position = UDim2.fromOffset(8, 0)
		box.Size = UDim2.new(1, -8, 1, 0)
		box.Text = ''
		box.TextColor3 = color.Dark(uipallet.Text, 0.16)
		box.TextSize = 14
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.Parent = holder
		local children = Instance.new('ScrollingFrame')
		children.BackgroundTransparency = 1
		children.BorderSizePixel = 0
		children.CanvasSize = UDim2.new()
		children.Position = UDim2.fromOffset(14, 76)
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.Size = UDim2.fromOffset(684, 301)
		children.Parent = window
		local windowlist = Instance.new('UIGridLayout')
		windowlist.CellSize = UDim2.fromOffset(163, 114)
		windowlist.CellPadding = UDim2.fromOffset(6, 6)
		windowlist.FillDirectionMaxCells = 4
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.Parent = children
		local legitTransition = 0

		function component:Show()
			legitTransition += 1
			clickgui.Visible = false
			local target = UDim2.new(0.5, -350, 0.5, -194)
			window.Position = (tenacity.ReducedMotion and tenacity.ReducedMotion.Enabled) and target or (target + UDim2.fromOffset(0, 12))
			window.Visible = true
			tenacity:BlurCheck()
			tween:Tween(window, uiMotionPop, {Position = target})
		end

		function component:Hide(returnToClickGui)
			legitTransition += 1
			local transition = legitTransition
			local target = window.Position
			local motion = tween:Tween(window, uiMotionFast, {Position = target + UDim2.fromOffset(0, 8)})
			local function finishClose()
				if transition == legitTransition then
					window.Visible = false
					window.Position = target
					if returnToClickGui then clickgui.Visible = true end
					tenacity:BlurCheck()
				end
			end
			if motion then motion.Completed:Once(finishClose) else finishClose() end
		end

		for index, comp in components do
			component['Create'..index] = function(_, props)
				return comp(props, children, component)
			end
		end

		function component:CreateModule(props)
			return components.AuxiliaryModule(props, children, component)
		end

		local function visibleCheck()
			for _, module in component.Modules do
				if module.Children then
					local visible = clickgui.Visible
					--[[for _, v2 in self.Windows do
						visible = visible or v2.Visible
					end]]

					module.Children.Visible = (not visible or window.Visible) and module.Enabled
				end
			end
		end

		box:GetPropertyChangedSignal('Text'):Connect(function()
			local query = box.Text:lower():match('^%s*(.-)%s*$')
			for name, module in component.Modules do
				module.Object.Visible = query == '' or name:lower():find(query, 1, true) ~= nil
			end
		end)

		close.MouseButton1Click:Connect(function()
			component:Hide(true)
		end)

		close.MouseEnter:Connect(function()
			close.ImageColor3 = color.Light(uipallet.Main, 0.37)
		end)

		close.MouseLeave:Connect(function()
			close.ImageColor3 = color.Light(uipallet.Main, 0.24)
		end)

		tenacity:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(visibleCheck))

		holder.MouseEnter:Connect(function()
			tween:Tween(stroke, uipallet.Tween, {
				Color = color.Light(uipallet.Main, 0.0875)
			})
		end)

		holder.MouseLeave:Connect(function()
			tween:Tween(stroke, uipallet.Tween, {
				Color = color.Light(uipallet.Main, 0.02)
			})
		end)

		window:GetPropertyChangedSignal('Visible'):Connect(function()
			tenacity:UpdateGUI()
			visibleCheck()
		end)

		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		end)

		tenacity.Auxiliary = component

		return component
	end,
	Module = function(props, children, api)
		tenacity:Remove(props.Name)
		local component = {
			Category = api.Name,
			Enabled = false,
			ExtraText = props.ExtraText,
			Index = getTableSize(tenacity.Modules),
			Name = props.Name,
			Options = {},
			Tooltip = props.Tooltip or '',
			Visible = true
		}

		local isHover = false
		local button = Instance.new('TextButton')
		button.AutoButtonColor = false
		button.BackgroundColor3 = uipallet.Main
		button.BorderSizePixel = 0
		button.FontFace = uipallet.Font
		button.Name = props.Name
		button.Size = UDim2.fromOffset(220, 40)
		-- Keep the TextButton text property for compatibility/edit-mode code, but
		-- render the visible module name in its own label. A UIGradient parented to
		-- a TextButton tints BOTH its background and text; on bright theme sections
		-- that made the module name blend into the exact same colors and disappear.
		button.Text = string.rep(' ', 12)..props.Name
		button.TextTransparency = 1
		button.Parent = children
		component.Object = button
		addTooltip(button, (props.Tooltip and (props.Tooltip..'\n') or '')..'LMB toggle • RMB settings • Shift+RMB favorite')
		tenacity:RegisterGUIStyleObject(button, 'ModuleRow')
		local themeBackground = Instance.new('Frame')
		themeBackground.BackgroundColor3 = uipallet.Main
		themeBackground.BorderSizePixel = 0
		themeBackground.Name = 'ThemeBackground'
		themeBackground.Size = UDim2.fromScale(1, 1)
		themeBackground.Parent = button
		tenacity:ApplyGUIStyleObject(button, 'ModuleRow')
		-- No per-module UIGradient here. Enabled rows sample the one shared
		-- screen-space ModuleThemePacket, which keeps the row visually flat.
		local moduleTitle = Instance.new('TextLabel')
		moduleTitle.BackgroundTransparency = 1
		moduleTitle.FontFace = uipallet.Font
		moduleTitle.Name = 'ModuleTitle'
		moduleTitle.Position = UDim2.fromOffset(12, 0)
		moduleTitle.Size = UDim2.new(1, -45, 1, 0)
		moduleTitle.Text = props.Name
		moduleTitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
		moduleTitle.TextSize = 14
		moduleTitle.TextStrokeColor3 = Color3.new()
		moduleTitle.TextStrokeTransparency = 1
		moduleTitle.TextXAlignment = Enum.TextXAlignment.Left
		moduleTitle.ZIndex = button.ZIndex + 2
		moduleTitle.Parent = button
		component.Title = moduleTitle
		local modulechildren = Instance.new('Frame')
		modulechildren.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		modulechildren.BorderSizePixel = 0
		modulechildren.ClipsDescendants = true
		modulechildren.Name = props.Name..'Children'
		modulechildren.Size = UDim2.new(1, 0, 0, 0)
		modulechildren.Visible = false
		modulechildren.Parent = children
		local windowlist = Instance.new('UIListLayout')
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.Parent = modulechildren
		local dotsbutton = Instance.new('TextButton')
		dotsbutton.BackgroundTransparency = 1
		dotsbutton.Name = 'Dots'
		dotsbutton.Position = UDim2.new(1, -25, 0, 0)
		dotsbutton.Size = UDim2.fromOffset(25, 40)
		dotsbutton.Text = ''
		dotsbutton.ZIndex = button.ZIndex + 3
		dotsbutton.Parent = button
		local dots = Instance.new('ImageLabel')
		dots.BackgroundTransparency = 1
		dots.Image = gettenacityasset('tenacity/assets/new/settingdots.png')
		dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
		dots.Name = 'Dots'
		dots.Position = UDim2.fromOffset(4, 12)
		dots.Size = UDim2.fromOffset(3, 16)
		dots.ZIndex = button.ZIndex + 4
		dots.Parent = dotsbutton
		local divider = Instance.new('Frame')
		divider.BackgroundColor3 = Color3.new(0.19, 0.19, 0.19)
		divider.BackgroundTransparency = 0.52
		divider.BorderSizePixel = 0
		divider.Name = 'Divider'
		divider.Position = UDim2.new(0, 0, 1, -1)
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Visible = false
		divider.ZIndex = button.ZIndex + 2
		divider.Parent = button
		local edit = Instance.new('TextButton')
		edit.AutoButtonColor = false
		edit.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		edit.BorderSizePixel = 0
		edit.Size = UDim2.fromOffset(40, 40)
		edit.Text = ''
		edit.Visible = false
		edit.ZIndex = button.ZIndex + 3
		edit.Parent = button
		local editbox = Instance.new('Frame')
		editbox.BorderSizePixel = 0
		editbox.Position = UDim2.fromOffset(16, 16)
		editbox.Size = UDim2.fromOffset(8, 8)
		editbox.ZIndex = button.ZIndex + 4
		editbox.Parent = edit
		local editborder = Instance.new('UIStroke')
		editborder.BorderOffset = UDim.new(0, 1)
		editborder.LineJoinMode = Enum.LineJoinMode.Miter
		editborder.Parent = editbox
		props.Function = props.Function or function() end
		component.Edit = edit
		component.Children = modulechildren
		local moduleExpanded = false
		local moduleExpandAnimation = 0
		local applyModuleVisual
		addMaid(component)

		local function setModuleExpanded(state)
			if state and tenacity.SingleModuleSettings and tenacity.SingleModuleSettings.Enabled then
				local previous = api.ExpandedModule
				if previous and previous ~= component and previous.SetExpanded then previous:SetExpanded(false) end
				api.ExpandedModule = component
			elseif not state and api.ExpandedModule == component then
				api.ExpandedModule = nil
			end
			moduleExpanded = state
			moduleExpandAnimation += 1
			local animation = moduleExpandAnimation
			local targetHeight = state and (windowlist.AbsoluteContentSize.Y / scale.Scale) or 0

			if state then
				modulechildren.Visible = true
			end
			local resizeMotion = tween:Tween(modulechildren, uiMotion, {Size = UDim2.new(1, 0, 0, targetHeight)})
			tween:Tween(dots, uiMotionFast, {Rotation = state and 90 or 0})
			component.Bind:SetVisible(isHover or state)
			if not component.Enabled then applyModuleVisual(true) end

			if not state then
				local function finishCollapse()
					if animation == moduleExpandAnimation and not moduleExpanded then modulechildren.Visible = false end
				end
				if resizeMotion then resizeMotion.Completed:Once(finishCollapse) else finishCollapse() end
			end
		end

		component.SetExpanded = setModuleExpanded
		applyModuleVisual = function(animate)
			local enabled = component.Enabled
			local active = isHover or moduleExpanded
			local idleBackground = active and color.Light(uipallet.Main, 0.02) or uipallet.Main
			local idleText = active and uipallet.Text or color.Dark(uipallet.Text, 0.16)
			local modernAccent = button:FindFirstChild('ModernModuleAccent')
			if modernAccent then
				modernAccent.BackgroundTransparency = enabled and 0 or (active and 0.45 or 0.72)
			end

			if enabled then
				if tenacity.GUIStyleName == 'Modern' then
					-- Modern keeps the Tenacity structure, but treats theme color as an accent
					-- instead of flooding the entire module row with a bright gradient.
					tenacity:UnregisterModuleThemeObject(themeBackground)
					themeBackground.BackgroundColor3 = color.Light(uipallet.Main, 0.028)
					moduleTitle.TextColor3 = uipallet.Text
					moduleTitle.TextStrokeTransparency = 1
					local accentColor = tenacity:GetThemeColor(component.Index * 0.045)
					component.Bind:SetColor(accentColor)
					dots.ImageColor3 = accentColor
				else
					-- Original Tenacity 5.1 presentation: enabled rows use the full shared
					-- screen-space theme packet.
					tenacity:RegisterModuleThemeObject(themeBackground)
					moduleTitle.TextColor3 = Color3.new(1, 1, 1)
					moduleTitle.TextStrokeColor3 = Color3.new(0, 0, 0)
					moduleTitle.TextStrokeTransparency = 0.48
					component.Bind:SetColor(moduleTitle.TextColor3)
					dots.ImageColor3 = moduleTitle.TextColor3
				end
			else
				tenacity:UnregisterModuleThemeObject(themeBackground)
				moduleTitle.TextStrokeTransparency = 1
				if animate then
					tween:Tween(themeBackground, uiMotionFast, {BackgroundColor3 = idleBackground})
					tween:Tween(moduleTitle, uiMotionFast, {TextColor3 = idleText})
				else
					themeBackground.BackgroundColor3 = idleBackground
					moduleTitle.TextColor3 = idleText
				end
				component.Bind:SetColor(color.Dark(uipallet.Text, 0.43))
				dots.ImageColor3 = active and uipallet.Text or color.Light(uipallet.Main, 0.37)
			end
		end

		function component:Color(hue, sat, val, isRainbow)
			applyModuleVisual(false)

			if self.Visible then
				local editAccent = tenacity:GetThemeColor(self.Index * 0.045)
				editbox.BackgroundColor3 = editAccent
				editborder.Color = editAccent
			end

			for _, option in self.Options do
				if option.Color then
					option:Color(hue, sat, val, isRainbow)
				end
			end
		end

		function component:Destroy()
			if api.ExpandedModule == self then api.ExpandedModule = nil end
			self.Bind:Destroy()

			for _, option in self.Options do
				if option.Type == 'Bind' then
					option:Destroy()
				end
			end
		end

		function component:Load(data)
			tenacity:LoadOptions(self, data.Options)
			self.Bind:Load(data.Bind)

			if self.Enabled ~= (data.Enabled and not self.Bind.Hold) then
				self:Toggle(true)

				if self.Bind.Mobile then
					self.Bind.Mobile.BackgroundColor3 = self.Enabled and Color3.new(0, 0.7, 0) or Color3.new()
				end
			end

			if self.Visible ~= data.Visible then
				self:SetVisible(data.Visible, true)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				Enabled = self.Enabled,
				Options = tenacity:SaveOptions(self),
				Visible = self.Visible
			}

			self.Bind:Save(data[props.Name])
		end

		function component:SetVisible(isVisible, isLoad)
			self.Visible = isVisible
			editbox.BackgroundTransparency = isVisible and 0 or 1
			editborder.Color = isVisible and editbox.BackgroundColor3 or color.Light(uipallet.Main, 0.37)

			if isLoad and not tenacity.EditGUI then
				button.Visible = isVisible
			end
		end

		function component:Toggle(multiple)
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			self.Enabled = not self.Enabled
			if clickgui.Visible and tenacity.SearchBar and tenacity.Loaded then tenacity.SearchBar:Refresh() end
			divider.Visible = self.Enabled
			-- Apply the enabled theme immediately. Previously Toggle() tweened the row
			-- back to its dark idle color and relied on a later global UpdateGUI pass,
			-- so it stayed dark until another module/menu action happened.
			applyModuleVisual(true)

			if not self.Enabled then
				for _, v in self.Connections do
					v:Disconnect()
				end
				table.clear(self.Connections)
			end

			if multiple then
				if not tenacity.TextGUIThread then
					tenacity.TextGUIThread = task.defer(function()
						if tenacity.Loaded ~= nil then
							tenacity:UpdateTextGUI()
						end

						tenacity.TextGUIThread = nil
					end)
				end
			else
				tenacity:UpdateTextGUI()
			end

			if tenacity.Loaded then tenacity:RecordRecent(props.Name) end
			if not multiple and tenacity.PushDynamicIslandModuleMessage then
				tenacity:PushDynamicIslandModuleMessage(props.Name, self.Enabled)
			end
			task.spawn(props.Function, self.Enabled)
		end

		for index, comp in components do
			component['Create'..index] = function(_, props)
				return comp(props, modulechildren, component)
			end
		end

		button.MouseEnter:Connect(function()
			isHover = true
			if not component.Enabled then applyModuleVisual(true) end
			component.Bind:SetVisible(isHover or moduleExpanded)
		end)

		button.MouseLeave:Connect(function()
			isHover = false
			if not component.Enabled then applyModuleVisual(true) end
			component.Bind:SetVisible(isHover or moduleExpanded)
		end)

		button.MouseButton1Click:Connect(function()
			if tenacity.EditGUI then
				return
			end

			component:Toggle()
		end)

		button.MouseButton2Click:Connect(function()
			if inputService:IsKeyDown(Enum.KeyCode.LeftShift) or inputService:IsKeyDown(Enum.KeyCode.RightShift) then
				if tenacity:ToggleFavorite(props.Name) then
					tenacity:CreateNotification('Favorites', props.Name..(tenacity.Favorites[props.Name] and ' added' or ' removed'), 1.5)
				end
			else
				setModuleExpanded(not moduleExpanded)
			end
		end)

		dotsbutton.MouseButton1Click:Connect(function()
			setModuleExpanded(not moduleExpanded)
		end)

		dotsbutton.MouseButton2Click:Connect(function()
			setModuleExpanded(not moduleExpanded)
		end)

		dotsbutton.MouseEnter:Connect(function()
			if not component.Enabled then
				dots.ImageColor3 = uipallet.Text
			end
		end)

		dotsbutton.MouseLeave:Connect(function()
			if not component.Enabled then
				dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
			end
		end)

		edit.MouseButton1Click:Connect(function()
			component:SetVisible(not component.Visible)
		end)

		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			if moduleExpanded then
				tween:Tween(modulechildren, uiMotion, {Size = UDim2.new(1, 0, 0, windowlist.AbsoluteContentSize.Y / scale.Scale)})
			else
				modulechildren.Size = UDim2.new(1, 0, 0, 0)
			end
		end)

		local bind = component:CreateBind({
			Module = true,
			Cover = true
		})

		bind.Triggered:Connect(function(isDown)
			if bind.Hold then
				if component.Enabled ~= isDown then
					if tenacity.ToggleNotifications.Enabled then
						tenacity:CreateNotification(props.Name, (not component.Enabled and "<font color='#00AA00'>Enabled</font>" or "<font color='#FF5A5A'>Disabled</font>"), 1.5)
					end

					component:Toggle(true)
				end
			else
				if tenacity.ToggleNotifications.Enabled then
					tenacity:CreateNotification(props.Name, (not component.Enabled and "<font color='#00AA00'>Enabled</font>" or "<font color='#FF5A5A'>Disabled</font>"), 1.5)
				end

				component:Toggle(true)
			end
		end)

		if inputService.TouchEnabled then
			local isHeld = false

			button.MouseButton1Down:Connect(function()
				isHeld = true
				local holdtime, holdPos = os.clock(), inputService:GetMouseLocation()
				repeat
					isHeld = (inputService:GetMouseLocation() - holdPos).Magnitude < 3
					task.wait()
				until (os.clock() - holdtime) > 1 or not isHeld or not clickgui.Visible

				if isHeld and clickgui.Visible then
					if tenacity.ThreadFix then
						setthreadidentity(8)
					end

					clickgui.Visible = false
					tooltip.Visible = false
					tenacity:BlurCheck()
					for _, module in tenacity.Modules do
						if module.Bind.Mobile then
							module.Bind.Mobile.Visible = true
						end
					end

					local connection
					connection = inputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.Touch then
							if tenacity.ThreadFix then
								setthreadidentity(8)
							end

							bind:CreateMobileButton(input.Position + Vector3.new(0, guiService:GetGuiInset().Y, 0))
							clickgui.Visible = true
							tenacity:BlurCheck()

							for _, module in tenacity.Modules do
								if module.Bind.Mobile then
									module.Bind.Mobile.Visible = false
								end
							end

							connection:Disconnect()
						end
					end)
				end
			end)

			button.MouseButton1Up:Connect(function()
				isHeld = false
			end)
		end

		tenacity.Modules[props.Name] = component
		tenacity:SortCategories()

		return component
	end,
	Overlay = function(props, children, api)
		local window
		local component
		component = {
			Button = tenacity.Overlays:CreateImageToggle({
				Name = props.Name,
				Function = function(callback)
					window.Visible = callback and (clickgui.Visible or component.Pinned)

					if not callback then
						for _, v in component.Connections do
							v:Disconnect()
						end
						table.clear(component.Connections)
					end

					if props.Function then
						task.spawn(props.Function, callback)
					end
				end,
				Icon = props.Icon,
				Size = props.Size,
				Position = props.Position
			}),
			Expanded = false,
			Pinned = false,
			Options = {},
			Type = 'Overlay'
		}

		window = Instance.new('TextButton')
		window.AutoButtonColor = false
		window.BackgroundColor3 = uipallet.Main
		window.Name = props.Name..'Overlay'
		window.Position = UDim2.fromOffset(240, 46)
		window.Size = UDim2.fromOffset(props.CategorySize or 220, 41)
		window.Text = ''
		window.Visible = false
		window.Parent = scaledgui
		component.Object = window
		local blur = addBlur(window)
		addCorner(window)
		addDragHandler(window)
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = props.Icon
		icon.ImageColor3 = uipallet.Text
		icon.Position = UDim2.fromOffset(12, (icon.Size.X.Offset > 14 and 14 or 13))
		icon.Size = props.Size
		icon.Parent = window
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Size = UDim2.new(1, -32, 0, 41)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 0)
		title.Text = props.Name
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = window
		local pin = Instance.new('ImageButton')
		pin.Name = 'Pin'
		pin.Size = UDim2.fromOffset(14, 14)
		pin.AnchorPoint = Vector2.new(0.5, 0.5)
		pin.Position = UDim2.new(1, -30, 0, 21)
		pin.Rotation = -30
		pin.BackgroundTransparency = 1
		pin.AutoButtonColor = false
		pin.Image = gettenacityasset('tenacity/assets/new/pin.png')
		pin.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		pin.Parent = window
		local pinScale = Instance.new('UIScale')
		pinScale.Parent = pin
		local pinRevision, pinHovered = 0, false
		local function animatePin(pop)
			pinRevision += 1
			local revision = pinRevision
			if component.Pinned then
				tenacity:RegisterThemeSolid(pin, 'ImageColor3', 0.12)
			else
				tenacity:UnregisterThemeSolid(pin)
			end
			tween:Tween(pin, uiMotion, {
				Rotation = component.Pinned and 0 or (pinHovered and -15 or -30),
				ImageColor3 = component.Pinned and tenacity:GetThemeColor(0.12) or (pinHovered and uipallet.Text or color.Dark(uipallet.Text, 0.43))
			})
			if pop and not (tenacity.ReducedMotion and tenacity.ReducedMotion.Enabled) then
				tween:Tween(pinScale, uiMotionFast, {Scale = 1.24})
				task.delay(0.12, function()
					if pin.Parent and revision == pinRevision then
						tween:Tween(pinScale, uiMotion, {Scale = pinHovered and 1.1 or 1})
					end
				end)
			else
				tween:Tween(pinScale, uiMotionFast, {Scale = pinHovered and 1.1 or 1})
			end
		end
		pin.MouseEnter:Connect(function() pinHovered = true; animatePin(false) end)
		pin.MouseLeave:Connect(function() pinHovered = false; animatePin(false) end)
		addTooltip(pin, 'Pin this overlay to keep it visible after closing the menu')
		local dotsbutton = Instance.new('TextButton')
		dotsbutton.Name = 'Dots'
		dotsbutton.Size = UDim2.fromOffset(17, 40)
		dotsbutton.Position = UDim2.new(1, -17, 0, 0)
		dotsbutton.BackgroundTransparency = 1
		dotsbutton.Text = ''
		dotsbutton.Parent = window
		local dots = Instance.new('ImageLabel')
		dots.BackgroundTransparency = 1
		dots.Image = gettenacityasset('tenacity/assets/new/overlaydots.png')
		dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
		dots.Position = UDim2.fromOffset(5, 15)
		dots.Size = UDim2.fromOffset(2, 12)
		dots.Parent = dotsbutton
		local customchildren = Instance.new('Frame')
		customchildren.BackgroundTransparency = 1
		customchildren.Position = UDim2.fromScale(0, 1)
		customchildren.Size = UDim2.new(1, 0, 0, 200)
		customchildren.Parent = window
		local children = Instance.new('ScrollingFrame')
		children.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		children.BorderSizePixel = 0
		children.CanvasSize = UDim2.new()
		children.Position = UDim2.fromOffset(0, 37)
		children.Size = UDim2.new(1, 0, 1, -41)
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.Visible = false
		children.Parent = window
		local stroke = Instance.new('UIStroke')
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(85, 85, 85)
		stroke.Transparency = 0.8
		stroke.Parent = window
		local windowlist = Instance.new('UIListLayout')
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.Parent = children
		addMaid(component)

		function component:Color(hue, sat, val, isRainbow)
			for _, component in self.Options do
				if component.Color then
					component:Color(hue, sat, val, isRainbow)
				end
			end
		end

		local expandRevision = 0
		function component:Expand(visCheck)
			if visCheck and not blur.Enabled then return end
			expandRevision += 1
			local revision = expandRevision
			self.Expanded = not self.Expanded
			if self.Expanded then children.Visible = true end
			tween:Tween(dots, uiMotionFast, {
				Rotation = self.Expanded and 90 or 0,
				ImageColor3 = self.Expanded and uipallet.Text or color.Light(uipallet.Main, 0.37)
			})
			local resizeMotion = tween:Tween(window, uiMotion, {Size = UDim2.fromOffset(window.Size.X.Offset,
				self.Expanded and math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601) or 41)})
			if not self.Expanded then
				local function finishCollapse()
					if window.Parent and revision == expandRevision and not component.Expanded then children.Visible = false end
				end
				if resizeMotion then resizeMotion.Completed:Once(finishCollapse) else finishCollapse() end
			end
		end
		function component:Load(data)
			tenacity:LoadOptions(self, data.Options)

			if self.Button.Enabled ~= data.Enabled then
				self.Button:Toggle()
			end

			if self.Pinned ~= data.Pinned then
				self:Pin()
				self:Update()
			end

			if data.Position then
				window.Position = UDim2.fromOffset(data.Position.X, data.Position.Y)
			end
		end

		function component:Pin()
			self.Pinned = not self.Pinned
			animatePin(tenacity.Loaded == true)
		end

		function component:Save(data)
			data[props.Name] = {
				Enabled = self.Button.Enabled,
				Options = tenacity:SaveOptions(self),
				Pinned = self.Pinned,
				Position = {
					X = window.Position.X.Offset,
					Y = window.Position.Y.Offset
				}
			}
		end

		function component:Update()
			tween:Cancel(window)
			window.Visible = self.Button.Enabled and (clickgui.Visible or self.Pinned)
			expandRevision += 1
			self.Expanded = false
			children.Visible = false
			dots.Rotation = 0
			if clickgui.Visible then
				window.Size = UDim2.fromOffset(window.Size.X.Offset, 41)
				window.BackgroundTransparency = 0
				blur.Enabled = true
				stroke.Enabled = true
				icon.Visible = true
				title.Visible = true
				pin.Visible = true
				dotsbutton.Visible = true
			else
				window.Size = UDim2.fromOffset(window.Size.X.Offset, 0)
				window.BackgroundTransparency = 1
				blur.Enabled = false
				stroke.Enabled = false
				icon.Visible = false
				title.Visible = false
				pin.Visible = false
				dotsbutton.Visible = false
			end
		end

		for index, comp in components do
			component['Create'..index] = function(_, props)
				return comp(props, children, component)
			end
		end

		tenacity:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
			component:Update()
		end))

		dotsbutton.MouseEnter:Connect(function()
			if not children.Visible then
				dots.ImageColor3 = uipallet.Text
			end
		end)

		dotsbutton.MouseLeave:Connect(function()
			if not children.Visible then
				dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
			end
		end)

		dotsbutton.MouseButton1Click:Connect(function()
			component:Expand(true)
		end)

		dotsbutton.MouseButton2Click:Connect(function()
			component:Expand(true)
		end)

		pin.MouseButton1Click:Connect(function()
			component:Pin()
		end)

		window.MouseButton2Click:Connect(function()
			component:Expand(true)
		end)

		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
			if component.Expanded then
				window.Size = UDim2.fromOffset(window.Size.X.Offset, math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601))
			end
		end)

		component.Children = customchildren
		tenacity.Categories[props.Name] = component

		return component
	end,
	OverlayBar = function(props, children, api)
		local component = {
			Options = {},
			Type = 'OverlayBar'
		}

		local bar = Instance.new('Frame')
		bar.Name = 'Overlays'
		bar.Size = UDim2.fromOffset(220, 36)
		bar.BackgroundColor3 = uipallet.Main
		bar.BorderSizePixel = 0
		bar.Parent = children
		components.Divider(nil, bar)
		local button = Instance.new('ImageButton')
		button.AutoButtonColor = false
		button.BackgroundTransparency = 1
		button.Image = gettenacityasset('tenacity/assets/new/overlays.png')
		button.ImageColor3 = color.Light(uipallet.Main, 0.37)
		button.Position = UDim2.new(1, -34, 0, 7)
		button.Size = UDim2.fromOffset(24, 24)
		button.Parent = bar
		addCorner(button, UDim.new(1, 0))
		addTooltip(button, 'Open overlays menu')
		local shadow = Instance.new('TextButton')
		shadow.AutoButtonColor = false
		shadow.BackgroundColor3 = Color3.new()
		shadow.BackgroundTransparency = 1
		shadow.ClipsDescendants = true
		shadow.Name = 'Shadow'
		shadow.Size = UDim2.new(1, 0, 1, -5)
		shadow.Text = ''
		shadow.Visible = false
		shadow.Parent = api.Object
		addCorner(shadow)
		local window = Instance.new('Frame')
		window.BackgroundColor3 = uipallet.Main
		window.Position = UDim2.fromScale(0, 1)
		window.Size = UDim2.fromOffset(220, 42)
		window.Parent = shadow
		addCorner(window)
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = gettenacityasset('tenacity/assets/new/overlayslarge.png')
		icon.ImageColor3 = uipallet.Text
		icon.Position = UDim2.fromOffset(10, 13)
		icon.Size = UDim2.fromOffset(14, 12)
		icon.Parent = window
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(36, 0)
		title.Size = UDim2.new(1, -36, 0, 38)
		title.Text = 'Overlays'
		title.TextColor3 = uipallet.Text
		title.TextSize = 15
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = window
		local close = addCloseButton(window, false, UDim2.new(1, -35, 0, 7))
		local divider = Instance.new('Frame')
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		divider.BorderSizePixel = 0
		divider.Position = UDim2.fromOffset(0, 37)
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Parent = window
		local childrentoggle = Instance.new('Frame')
		childrentoggle.BackgroundColor3 = uipallet.Main
		childrentoggle.BackgroundTransparency = 1
		childrentoggle.Position = UDim2.fromOffset(0, 38)
		childrentoggle.Parent = window
		local windowlist = Instance.new('UIListLayout')
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.Parent = childrentoggle

		for index, comp in components do
			component['Create'..index] = function(_, props)
				return comp(props, childrentoggle, component)
			end
		end

		button.MouseEnter:Connect(function()
			button.ImageColor3 = uipallet.Text
			tween:Tween(button, uipallet.Tween, {
				BackgroundTransparency = 0.9
			})
		end)

		button.MouseLeave:Connect(function()
			button.ImageColor3 = color.Light(uipallet.Main, 0.37)
			tween:Tween(button, uipallet.Tween, {
				BackgroundTransparency = 1
			})
		end)

		button.MouseButton1Click:Connect(function()
			shadow.Visible = true
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 0.5
			})

			tween:Tween(window, uipallet.Tween, {
				Position = UDim2.new(0, 0, 1, -(window.Size.Y.Offset))
			})
		end)

		close.MouseButton1Click:Connect(function()
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 1
			})

			tween:Tween(window, uipallet.Tween, {
				Position = UDim2.fromScale(0, 1)
			})

			task.delay(0.2, function()
				shadow.Visible = false
			end)
		end)

		shadow.MouseButton1Click:Connect(function()
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 1
			})

			tween:Tween(window, uipallet.Tween, {
				Position = UDim2.fromScale(0, 1)
			})

			task.delay(0.2, function()
				shadow.Visible = false
			end)
		end)

		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			window.Size = UDim2.fromOffset(220, math.min(37 + windowlist.AbsoluteContentSize.Y / scale.Scale, 605))
			childrentoggle.Size = UDim2.fromOffset(220, window.Size.Y.Offset - 5)
		end)

		tenacity.Overlays = component

		return component
	end,
	SearchBar = function(props, children, api)
		local component = {
			Type = 'SearchBar',
			Filter = 'All',
			Mode = inputService.TouchEnabled and 'Pinned' or 'On demand',
			ResultButtons = {},
			ResultActions = {},
			ResultNames = {},
			ResultLocations = {},
			ResultRows = {},
			SelectedIndex = 0
		}

		local function listenProperty(src, dest, prop, obj)
			dest[prop] = src[prop]
			local connection = src:GetPropertyChangedSignal(prop):Connect(function()
				dest[prop] = src[prop]
			end)

			obj.Destroying:Once(function()
				connection:Disconnect()
			end)
		end

		local search = Instance.new('Frame')
		search.AnchorPoint = Vector2.new(0.5, 0)
		search.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		search.Name = 'Search'
		search.Position = UDim2.new(0.5, 0, 0, 13)
		search.Size = UDim2.fromOffset(290, 92)
		search.Visible = inputService.TouchEnabled
		search.ZIndex = 20
		search.Parent = clickgui
		component.Object = search
		addBlur(search)
		addCorner(search)
		local searchScale = Instance.new('UIScale')
		searchScale.Scale = 1
		searchScale.Parent = search
		local searchTransition = 0
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = gettenacityasset('tenacity/assets/new/search.png')
		icon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		icon.Position = UDim2.new(1, -25, 0, 11)
		icon.Size = UDim2.fromOffset(14, 14)
		icon.ZIndex = 21
		icon.Parent = search
		local auxiliaryIcon = Instance.new('ImageButton')
		auxiliaryIcon.BackgroundTransparency = 1
		auxiliaryIcon.Image = gettenacityasset('tenacity/assets/new/legit_switch.png')
		auxiliaryIcon.Name = 'Auxiliary'
		auxiliaryIcon.Position = UDim2.fromOffset(8, 11)
		auxiliaryIcon.Size = UDim2.fromOffset(29, 16)
		auxiliaryIcon.ZIndex = 21
		auxiliaryIcon.Parent = search
		listenProperty(tenacity.Categories.Main.Object.TenacityLogo.EditionBadge, auxiliaryIcon, 'ImageColor3', auxiliaryIcon)
		local auxiliaryDivider = Instance.new('Frame')
		auxiliaryDivider.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		auxiliaryDivider.BorderSizePixel = 0
		auxiliaryDivider.Name = 'AuxiliaryDivider'
		auxiliaryDivider.Position = UDim2.fromOffset(43, 13)
		auxiliaryDivider.Size = UDim2.fromOffset(2, 12)
		auxiliaryDivider.ZIndex = 21
		auxiliaryDivider.Parent = search
		local box = Instance.new('TextBox')
		box.BackgroundTransparency = 1
		box.ClearTextOnFocus = false
		box.FontFace = uipallet.Font
		box.PlaceholderText = 'Search modules...'
		box.PlaceholderColor3 = color.Dark(uipallet.Text, 0.35)
		box.Position = UDim2.fromOffset(50, 0)
		box.Size = UDim2.new(1, -92, 0, 37)
		box.Text = ''
		box.TextColor3 = uipallet.Text
		box.TextSize = 12
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.ZIndex = 21
		box.Parent = search
		component.Input = box
		local children = Instance.new('ScrollingFrame')
		children.BackgroundTransparency = 1
		children.BorderSizePixel = 0
		children.CanvasSize = UDim2.new()
		children.Position = UDim2.fromOffset(0, 92)
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.Size = UDim2.new(1, 0, 1, -92)
		children.ZIndex = 21
		children.Parent = search
		local divider = Instance.new('Frame')
		divider.BackgroundColor3 = Color3.new(1, 1, 1)
		divider.BackgroundTransparency = 0.928
		divider.BorderSizePixel = 0
		divider.Position = UDim2.fromOffset(0, 91)
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Visible = false
		divider.ZIndex = 22
		divider.Parent = search
		local stroke = Instance.new('UIStroke')
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(85, 85, 85)
		stroke.Transparency = 0.8
		stroke.Parent = search
		tenacity:RegisterGUIStyleObject(search, 'SearchWindow')
		local windowlist = Instance.new('UIListLayout')
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.Parent = children

		local clear = Instance.new('TextButton')
		clear.BackgroundTransparency = 1
		clear.Position = UDim2.new(1, -38, 0, 0)
		clear.Size = UDim2.fromOffset(38, 37)
		clear.Text = '×'
		clear.FontFace = uipallet.Font
		clear.TextSize = 18
		clear.TextColor3 = color.Dark(uipallet.Text, 0.18)
		clear.Visible = false
		clear.ZIndex = 22
		clear.Parent = search
		clear.Activated:Connect(function()
			box.Text = ''
			box:CaptureFocus()
		end)
		local empty = Instance.new('TextLabel')
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, -20, 0, 40)
		empty.FontFace = uipallet.Font
		empty.TextSize = 12
		empty.TextColor3 = color.Dark(uipallet.Text, 0.25)
		empty.Text = 'No matching modules'
		empty.Visible = false
		empty.ZIndex = 21
		empty.Parent = children
		local filters = {'All', 'Enabled', 'Favorites', 'Recent'}
		local filterKeys = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}
		local filterButtons = {}
		for index, name in ipairs(filters) do
			local button = Instance.new('TextButton')
			button.Position = UDim2.fromOffset(7 + (index - 1) * 70, 40)
			button.Size = UDim2.fromOffset(67, 24)
			button.FontFace = uipallet.Font
			button.TextSize = 10
			button.Text = name
			button.BorderSizePixel = 0
			button.TextColor3 = uipallet.Text
			button.ZIndex = 21
			button.Parent = search
			addCorner(button, UDim.new(0, 2))
			filterButtons[name] = button
			addTooltip(button, 'Ctrl+'..index..' · '..name)
			button.Activated:Connect(function()
				component.Filter = name
				component:Refresh()
			end)
		end
		local resultCount = Instance.new('TextLabel')
		resultCount.Position = UDim2.fromOffset(10, 67)
		resultCount.Size = UDim2.new(1, -20, 0, 20)
		resultCount.BackgroundTransparency = 1
		resultCount.TextColor3 = color.Dark(uipallet.Text, 0.25)
		resultCount.FontFace = uipallet.Font
		resultCount.TextSize = 10
		resultCount.TextXAlignment = Enum.TextXAlignment.Left
		resultCount.TextTruncate = Enum.TextTruncate.AtEnd
		resultCount.Text = '#category   @on   @fav   ·   ↑↓ select'
		resultCount.ZIndex = 21
		resultCount.Parent = search
		addTooltip(resultCount, 'Enter: toggle · Shift+Enter: locate\nPage Up/Down: move one page · Ctrl+Home/End: first/last result\nCtrl+1–4: filters · Ctrl+D: favorite')
		local revision = 0

		function component:IsPointInside(point)
			local pos, size = search.AbsolutePosition, search.AbsoluteSize
			return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
		end

		function component:SetMode(value)
			self.Mode = value
			searchTransition += 1
			if value == 'Pinned' then
				searchScale.Scale = 1
				search.Visible = true
				self:Refresh()
			else
				if inputService:GetFocusedTextBox() == box then box:ReleaseFocus() end
				search.Visible = false
			end
		end

		function component:Open(focus)
			if self.Mode == 'Disabled' then return end
			searchTransition += 1
			search.Visible = true
			searchScale.Scale = 0.96
			tween:Tween(searchScale, uiMotionPop, {Scale = 1})
			self:Refresh()
			if focus then
				task.defer(function()
					if search.Visible and search.Parent then box:CaptureFocus() end
				end)
			end
		end

		function component:Close(clearQuery)
			if clearQuery and box.Text ~= '' then box.Text = '' end
			if inputService:GetFocusedTextBox() == box then box:ReleaseFocus() end
			if self.Mode == 'Pinned' then
				search.Visible = true
				return
			end
			searchTransition += 1
			local transition = searchTransition
			tween:Tween(searchScale, uiMotionFast, {Scale = 0.96})
			task.delay(0.1, function()
				if transition == searchTransition and self.Mode ~= 'Pinned' and search.Parent then
					search.Visible = false
					searchScale.Scale = 1
				end
			end)
		end

		function component:SetSelection(index, preserveScroll)
			local total = #self.ResultButtons
			if total == 0 then
				self.SelectedIndex = 0
				return
			end
			index = ((index - 1) % total) + 1
			local previous = self.ResultButtons[self.SelectedIndex]
			local previousStroke = previous and previous:FindFirstChild('SearchSelection')
			if previousStroke then previousStroke.Enabled = false end
			self.SelectedIndex = index
			local button = self.ResultButtons[index]
			local selection = button:FindFirstChild('SearchSelection')
			if selection then selection.Enabled = true end
			if preserveScroll then return end
			local y = (index - 1) * 40
			local current = children.CanvasPosition.Y
			local view = children.AbsoluteSize.Y / scale.Scale
			if y < current then
				children.CanvasPosition = Vector2.new(0, y)
			elseif y + 40 > current + view then
				children.CanvasPosition = Vector2.new(0, math.max(0, y + 40 - view))
			end
		end

		function component:Refresh()
			for name, button in pairs(filterButtons) do
				button.BackgroundColor3 = name == self.Filter and color.Light(uipallet.Main, 0.1) or uipallet.Main
			end
			revision += 1
			local current = revision
			clear.Visible = box.Text ~= ''
			icon.Visible = box.Text == ''
			task.delay(0.05, function()
				if current ~= revision or not search.Parent or not search.Visible or not clickgui.Visible then return end
				local previousName = self.ResultNames[self.SelectedIndex]
				local sameQuery = self.LastQuery == box.Text and self.LastFilter == self.Filter
				local previousScroll = children.CanvasPosition
				self.LastQuery, self.LastFilter = box.Text, self.Filter
				empty.Visible = false
				if not sameQuery then children.CanvasPosition = Vector2.zero end
				table.clear(self.ResultButtons)
				table.clear(self.ResultActions)
				table.clear(self.ResultNames)
				table.clear(self.ResultLocations)
				self.SelectedIndex = 0

				local query = box.Text:lower():match('^%s*(.-)%s*$')
				local suggestions = query == '' and self.Filter == 'All'

				local names = {}
				local scores = {}
				local plain = query:match('^[^#@%s]+') or ''
				local function matches(name)
					local module = tenacity.Modules[name]
					return module and (not suggestions or tenacity.Favorites[name] or table.find(tenacity.RecentModules, name))
						and matchesModuleSearch(name, module.Category, module.Tooltip, query)
						and matchesModuleState(module, name, query)
						and (self.Filter ~= 'Enabled' or module.Enabled)
						and (self.Filter ~= 'Favorites' or tenacity.Favorites[name])
				end
				if self.Filter == 'Recent' then
					for _, name in ipairs(tenacity.RecentModules) do
						if matches(name) then names[#names + 1] = name end
					end
				else
					for name, module in tenacity.Modules do
						if matches(name) then
							names[#names + 1] = name
							scores[name] = (plain ~= '' and name:lower():sub(1, #plain) == plain and 8 or 0)
								+ (tenacity.Favorites[name] and 2 or 0) + (module.Enabled and 1 or 0)
						end
					end
					table.sort(names, function(a, b)
						local ascore, bscore = scores[a], scores[b]
						return ascore == bscore and a:lower() < b:lower() or ascore > bscore
					end)
				end

				if suggestions then
					while #names > 8 do table.remove(names) end
				end
				-- Keep unchanged result objects and their listeners. Release only rows
				-- that left the result set or whose source module was replaced.
				local wanted = {}
				for _, name in ipairs(names) do wanted[name] = true end
				for name, row in self.ResultRows do
					if not wanted[name] or row.Module ~= tenacity.Modules[name] then
						row.Button:Destroy()
						self.ResultRows[name] = nil
					end
				end
				local matches = 0
				for _, name in ipairs(names) do
					local module = tenacity.Modules[name]
					do
						matches += 1
						local row = self.ResultRows[name]
						if not row then
							local button = module.Object:Clone()
							button.LayoutOrder = matches
							button.ZIndex = 21
							local bindObject = button:FindFirstChild('Bind')
							if bindObject then bindObject:Destroy() end
							local dotsObject = button:FindFirstChild('Dots')
							if dotsObject then dotsObject.Visible = false end
							local selection = Instance.new('UIStroke')
							selection.Name = 'SearchSelection'
							selection.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
							selection.Color = tenacity:GetGUIColorRGB()
							tenacity:RegisterThemeSolid(selection, 'Color', 0.06)
							selection.Thickness = 1
							selection.Transparency = 0.18
							selection.Enabled = false
							selection.Parent = button
							local star = Instance.new('TextButton')
							star.Position = UDim2.new(1, -34, 0, 0)
							star.Size = UDim2.fromOffset(34, 40)
							star.BackgroundTransparency = 1
							star.Text = tenacity.Favorites[name] and '★' or '☆'
							star.TextSize = 20
							star.TextColor3 = tenacity.Favorites[name] and tenacity:GetGUIColorRGB() or uipallet.Text
							if tenacity.Favorites[name] then tenacity:RegisterThemeSolid(star, 'TextColor3', 0.10) end
							star.ZIndex = 22
							star.Parent = button
							addTooltip(star, 'Add or remove favorite · Ctrl+D on selected result')
							star.Activated:Connect(function() tenacity:ToggleFavorite(name) end)

							local function activate()
								module:Toggle()
								if component.Mode == 'On demand' then component:Close(true) end
							end
							button.MouseButton1Click:Connect(activate)
							button.MouseEnter:Connect(function() component:SetSelection(button.LayoutOrder) end)
							local function locate()
								local category = tenacity.Categories[module.Category]
								if category and not category.Expanded and category.Expand then category:Expand() end
								module.Object.Parent.Parent.Visible = true
								local frame = module.Object.Parent
								local highlight = Instance.new('Frame')
								highlight.Size = UDim2.fromScale(1, 1)
								highlight.BackgroundColor3 = Color3.new(1, 1, 1)
								highlight.BackgroundTransparency = 0.6
								highlight.BorderSizePixel = 0
								highlight.Parent = module.Object
								tween:Tween(highlight, TweenInfo.new(0.5), {BackgroundTransparency = 1})
								task.delay(0.5, highlight.Destroy, highlight)
								local offset = (module.Object.AbsolutePosition.Y - frame.AbsolutePosition.Y) / scale.Scale + frame.CanvasPosition.Y
								frame.CanvasPosition = Vector2.new(0, math.clamp(offset - (frame.AbsoluteSize.Y - module.Object.AbsoluteSize.Y) / (2 * scale.Scale),
									0, math.max(0, (frame.AbsoluteCanvasSize.Y - frame.AbsoluteSize.Y) / scale.Scale)))
								if component.Mode == 'On demand' then component:Close(false) end
							end
							button.MouseButton2Click:Connect(locate)

							for _, prop in {'Text', 'TextColor3', 'BackgroundColor3'} do
								listenProperty(module.Object, button, prop, button)
							end
							local sourceBackground = module.Object:FindFirstChild('ThemeBackground')
							local resultBackground = button:FindFirstChild('ThemeBackground')
							if sourceBackground and resultBackground then
								listenProperty(sourceBackground, resultBackground, 'BackgroundColor3', button)
							end
							listenProperty(module.Object.UIGradient, button.UIGradient, 'Color', button)
							listenProperty(module.Object.UIGradient, button.UIGradient, 'Enabled', button)
							button.Parent = children
							row = {Module = module, Button = button, Star = star, Selection = selection, Activate = activate, Locate = locate}
							self.ResultRows[name] = row
						end
						row.Button.LayoutOrder = matches
						row.Selection.Enabled = false
						row.Star.Text = tenacity.Favorites[name] and '★' or '☆'
						if tenacity.Favorites[name] then
							tenacity:RegisterThemeSolid(row.Star, 'TextColor3', 0.10)
						else
							tenacity:UnregisterThemeSolid(row.Star)
							row.Star.TextColor3 = uipallet.Text
						end
						self.ResultButtons[#self.ResultButtons + 1] = row.Button
						self.ResultActions[#self.ResultActions + 1] = row.Activate
						self.ResultNames[#self.ResultNames + 1] = name
						self.ResultLocations[#self.ResultLocations + 1] = row.Locate
					end
				end
				resultCount.Text = (suggestions and 'Quick picks' or tostring(matches)..' results')..' · Enter toggle · Shift+Enter locate'
				empty.Text = suggestions and 'Star a module to keep it here' or self.Filter == 'Favorites' and 'Shift+RMB a module or star it here' or (self.Filter == 'Recent' and 'Toggle a module and it will show up here' or 'No matching modules')
				empty.Visible = matches == 0
				if sameQuery then children.CanvasPosition = previousScroll end
				if matches > 0 then self:SetSelection(sameQuery and table.find(self.ResultNames, previousName) or 1, sameQuery) end
			end)
		end

		box:GetPropertyChangedSignal('Text'):Connect(function() component:Refresh() end)
		component:Refresh()

		tenacity:Clean(inputService.InputBegan:Connect(function(input)
			if inputService:GetFocusedTextBox() ~= box or not search.Visible or not clickgui.Visible then return end
			local control = inputService:IsKeyDown(Enum.KeyCode.LeftControl) or inputService:IsKeyDown(Enum.KeyCode.RightControl)
			local shift = inputService:IsKeyDown(Enum.KeyCode.LeftShift) or inputService:IsKeyDown(Enum.KeyCode.RightShift)
			local filterIndex = table.find(filterKeys, input.KeyCode)
			if control and filterIndex then
				component.Filter = filters[filterIndex]
				component:Refresh()
			elseif control and input.KeyCode == Enum.KeyCode.D then
				local name = component.ResultNames[component.SelectedIndex]
				if name then tenacity:ToggleFavorite(name) end
			elseif input.KeyCode == Enum.KeyCode.Down then
				component:SetSelection(component.SelectedIndex + 1)
			elseif input.KeyCode == Enum.KeyCode.Up then
				component:SetSelection(component.SelectedIndex - 1)
			elseif input.KeyCode == Enum.KeyCode.PageDown or input.KeyCode == Enum.KeyCode.PageUp then
				local page = math.max(1, math.floor(children.AbsoluteSize.Y / (40 * scale.Scale)))
				local direction = input.KeyCode == Enum.KeyCode.PageDown and 1 or -1
				component:SetSelection(math.clamp(component.SelectedIndex + page * direction, 1, math.max(1, #component.ResultButtons)))
			elseif control and input.KeyCode == Enum.KeyCode.Home then
				component:SetSelection(1)
			elseif control and input.KeyCode == Enum.KeyCode.End then
				component:SetSelection(#component.ResultButtons)
			elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
				local action = (shift and component.ResultLocations or component.ResultActions)[component.SelectedIndex]
				if action then action() end
			end
		end))

		children:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
			divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
		end)

		auxiliaryIcon.MouseButton1Click:Connect(function()
			component:Close(false)
			tenacity.Auxiliary:Show()
		end)

		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then setthreadidentity(8) end
			local resultHeight = windowlist.AbsoluteContentSize.Y / scale.Scale
			children.CanvasSize = UDim2.fromOffset(0, resultHeight)
			search.Size = UDim2.fromOffset(290, 92 + math.min(resultHeight, 400))
		end)

		return component
	end,
	SettingsPane = function(props, children, api)
		local component = {
			Buttons = {},
			Options = {},
			Parent = api.Parent or children,
			Type = 'SettingsPane'
		}

		local pane = Instance.new('TextButton')
		pane.AutoButtonColor = false
		pane.BackgroundColor3 = props.Main and color.Dark(uipallet.Main, 0.02) or uipallet.Main
		pane.Size = UDim2.fromScale(1, 1)
		pane.Text = ''
		pane.Visible = false
		pane.Parent = component.Parent
		local paneTransition = 0

		function component:SetVisible(state)
			paneTransition += 1
			local transition = paneTransition
			if not props.Main then
				if state then
					tenacity.ActiveSettingsPane = component
				elseif tenacity.ActiveSettingsPane == component then
					tenacity.ActiveSettingsPane = nil
				end
			end
			if state then
				pane.Position = UDim2.fromOffset(10, 0)
				pane.Visible = true
				tween:Tween(pane, uiMotion, {Position = UDim2.fromOffset(0, 0)})
			else
				local motion = tween:Tween(pane, uiMotionFast, {Position = UDim2.fromOffset(10, 0)})
				local function finishClose()
					if transition == paneTransition then
						pane.Visible = false
						pane.Position = UDim2.fromOffset(0, 0)
					end
				end
				if motion then motion.Completed:Once(finishClose) else finishClose() end
			end
		end
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Name = 'Title'
		title.Size = UDim2.new(1, -36, 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 11)
		title.Text = props.Name
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = pane
		local close = addCloseButton(pane, true)
		local back = Instance.new('ImageButton')
		back.BackgroundTransparency = 1
		back.Image = gettenacityasset('tenacity/assets/new/backmini.png')
		back.ImageColor3 = color.Light(uipallet.Main, 0.37)
		back.Position = UDim2.fromOffset(12, 14)
		back.Size = UDim2.fromOffset(14, 14)
		back.Parent = pane
		addCorner(pane)
		tenacity:RegisterGUIStyleObject(pane, 'SettingsPane')
		local settingschildren = Instance.new('ScrollingFrame')
		settingschildren.CanvasSize = UDim2.new()
		settingschildren.ScrollBarThickness = 3
		settingschildren.ScrollBarImageTransparency = 0.45
		settingschildren.ScrollingDirection = Enum.ScrollingDirection.Y
		settingschildren.BackgroundColor3 = uipallet.Main
		settingschildren.BorderSizePixel = 0
		settingschildren.Name = 'Children'
		settingschildren.Position = UDim2.fromOffset(0, 41)
		settingschildren.Size = UDim2.new(1, 0, 1, -57)
		settingschildren.Parent = pane
		tenacity:RegisterGUIStyleObject(settingschildren, 'SettingsBody')
		local divider = Instance.new('Frame')
		divider.BackgroundColor3 = Color3.new(1, 1, 1)
		divider.BackgroundTransparency = 0.928
		divider.BorderSizePixel = 0
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Parent = settingschildren
		local listlayout = Instance.new('UIListLayout')
		listlayout.SortOrder = Enum.SortOrder.LayoutOrder
		listlayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		listlayout.Parent = settingschildren
		if props.Main then
			local versionlabel = Instance.new('TextLabel')
			versionlabel.BackgroundTransparency = 1
			versionlabel.FontFace = uipallet.Font
			versionlabel.Name = 'Version'
			versionlabel.Position = UDim2.new(0, 0, 1, -16)
			versionlabel.Size = UDim2.new(1, 0, 0, 16)
			versionlabel.Text = 'Tenacity '..tenacity.Version..' '..(
				isfile('tenacity/profiles/commit.txt') and readfile('tenacity/profiles/commit.txt'):sub(1, 6) or ''
			)..' '
			versionlabel.TextColor3 = color.Dark(uipallet.Text, 0.43)
			versionlabel.TextSize = 10
			versionlabel.TextXAlignment = Enum.TextXAlignment.Right
			versionlabel.Parent = pane
		else
			api:CreateGUIButton({
				Name = props.Name,
				Function = function()
					component:SetVisible(true)
				end
			})
		end

		function component:Load(data)
			tenacity:LoadOptions(self, data)
		end

		function component:Save(data)
			data[props.Name] = tenacity:SaveOptions(self)
		end

		for index, comp in components do
			component['Create'..index] = function(_, props)
				return comp(props, settingschildren, component)
			end
		end

		back.MouseEnter:Connect(function()
			back.ImageColor3 = uipallet.Text
		end)

		back.MouseLeave:Connect(function()
			back.ImageColor3 = color.Light(uipallet.Main, 0.37)
		end)

		back.MouseButton1Click:Connect(function()
			component:SetVisible(false)
		end)

		close.MouseButton1Click:Connect(function()
			component:SetVisible(false)
		end)

		listlayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			settingschildren.CanvasSize = UDim2.fromOffset(0, listlayout.AbsoluteContentSize.Y / scale.Scale)
		end)

		component.Object = pane
		tenacity.Settings[props.Name] = component

		return component
	end,
	Slider = function(props, children, api)
		local component = {
			Index = getTableSize(api.Options),
			Max = props.Max,
			Type = 'Slider',
			Value = props.Default or props.Min,
		}

		local slider = Instance.new('TextButton')
		slider.AutoButtonColor = false
		slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
		slider.BorderSizePixel = 0
		slider.Size = UDim2.new(1, 0, 0, 50)
		slider.Text = ''
		slider.Visible = props.Visible == nil or props.Visible
		slider.Parent = children
		component.Object = slider
		addTooltip(slider, props.Tooltip)
		tenacity:RegisterGUIStyleObject(slider, 'ControlRow')
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(10, 2)
		title.Size = UDim2.fromOffset(60, 30)
		title.Text = props.Name
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 11
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = slider
		local valuelabel = Instance.new('TextButton')
		valuelabel.BackgroundTransparency = 1
		valuelabel.FontFace = uipallet.Font
		valuelabel.Position = UDim2.new(1, -69, 0, 9)
		valuelabel.Size = UDim2.fromOffset(60, 15)
		valuelabel.Text = component.Value..(props.Suffix and ' '..(type(props.Suffix) == 'function' and props.Suffix(component.Value) or props.Suffix) or '')
		valuelabel.TextColor3 = color.Dark(uipallet.Text, 0.16)
		valuelabel.TextSize = 11
		valuelabel.TextXAlignment = Enum.TextXAlignment.Right
		valuelabel.Parent = slider
		local custombox = Instance.new('TextBox')
		custombox.BackgroundTransparency = 1
		custombox.ClearTextOnFocus = false
		custombox.FontFace = uipallet.Font
		custombox.Position = valuelabel.Position
		custombox.Size = valuelabel.Size
		custombox.Text = component.Value
		custombox.TextColor3 = color.Dark(uipallet.Text, 0.16)
		custombox.TextSize = 11
		custombox.TextXAlignment = Enum.TextXAlignment.Right
		custombox.Visible = false
		custombox.Parent = slider
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		holder.BorderSizePixel = 0
		holder.Position = UDim2.fromOffset(10, 37)
		holder.Size = UDim2.new(1, -20, 0, 2)
		holder.Parent = slider
		tenacity:RegisterGUIStyleObject(holder, 'SliderTrack')
		local fill = Instance.new('Frame')
		fill.BackgroundColor3 = tenacity:GetThemeColor(0)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(math.clamp((component.Value - props.Min) / props.Max, 0.04, 0.96), 1)
		fill.Parent = holder
		local knobholder = Instance.new('Frame')
		knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
		knobholder.BackgroundColor3 = slider.BackgroundColor3
		knobholder.BorderSizePixel = 0
		knobholder.Position = UDim2.fromScale(1, 0.5)
		knobholder.Size = UDim2.fromOffset(24, 4)
		knobholder.Parent = fill
		local knob = Instance.new('Frame')
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = tenacity:GetThemeColor(0)
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.Size = UDim2.fromOffset(14, 14)
		knob.Parent = knobholder
		addCorner(knob, UDim.new(1, 0))
		props.Function = props.Function or function() end
		props.Decimal = props.Decimal or 1

		function component:Color(hue, sat, val, isRainbow)
			if tenacity:ApplyThemeGradient(fill, 'BackgroundColor3', self.Index * 0.075, true, 0) then
				knob.BackgroundColor3 = tenacity:GetThemeColor(self.Index * 0.075)
			else
				fill.BackgroundColor3 = isRainbow and Color3.fromHSV(tenacity:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
				knob.BackgroundColor3 = fill.BackgroundColor3
			end
		end

		function component:Load(data)
			local newValue = data.Value == data.Max and data.Max ~= self.Max and self.Max or data.Value
			if self.Value ~= newValue then
				self:SetValue(newValue, nil, true)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				Value = self.Value,
				Max = self.Max
			}
		end

		function component:SetValue(value, position, wasReleased)
			if not (value == value and math.abs(value) < math.huge) then
				return
			end

			tween:Tween(fill, uipallet.Tween, {
				Size = UDim2.fromScale(math.clamp(position or math.clamp(value / props.Max, 0, 1), 0.04, 0.96), 1)
			})

			if self.Value ~= value or wasReleased then
				self.Value = value
				valuelabel.Text = self.Value..(props.Suffix and ' '..(type(props.Suffix) == 'function' and props.Suffix(self.Value) or props.Suffix) or '')
				props.Function(value, wasReleased)
			end
		end

		slider.InputBegan:Connect(function(input)
			if
				(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
				and (input.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
			then
				local newPosition = math.clamp((input.Position.X - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1)
				local lastPosition = newPosition

				local releaseConnection
				local moveConnection = inputService.InputChanged:Connect(function(newInput)
					if newInput.UserInputType == (input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
						local newPosition = math.clamp((newInput.Position.X - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1)
						component:SetValue(math.floor((props.Min + (props.Max - props.Min) * newPosition) * props.Decimal) / props.Decimal, newPosition)
						lastPosition = newPosition
					end
				end)

				releaseConnection = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						moveConnection:Disconnect()
						releaseConnection:Disconnect()
						component:SetValue(component.Value, lastPosition, true)
					end
				end)

				component:SetValue(math.floor((props.Min + (props.Max - props.Min) * newPosition) * props.Decimal) / props.Decimal, newPosition)
			end
		end)

		slider.MouseEnter:Connect(function()
			tween:Tween(knob, uipallet.Tween, {
				Size = UDim2.fromOffset(16, 16)
			})
		end)

		slider.MouseLeave:Connect(function()
			tween:Tween(knob, uipallet.Tween, {
				Size = UDim2.fromOffset(14, 14)
			})
		end)

		valuelabel.MouseButton1Click:Connect(function()
			valuelabel.Visible = false
			custombox.Visible = true
			custombox.Text = component.Value
			custombox:CaptureFocus()
		end)

		custombox.FocusLost:Connect(function(enter)
			valuelabel.Visible = true
			custombox.Visible = false

			if enter and tonumber(custombox.Text) then
				component:SetValue(tonumber(custombox.Text), nil, true)
			end
		end)

		api.Options[props.Name] = component

		return component
	end,
	Targets = function(props, children, api)
		local component = {
			Index = getTableSize(api.Options),
			Type = 'Targets'
		}

		local targets = Instance.new('TextButton')
		targets.AutoButtonColor = false
		targets.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
		targets.BorderSizePixel = 0
		targets.Size = UDim2.new(1, 0, 0, 50)
		targets.Text = ''
		targets.Visible = props.Visible == nil or props.Visible
		targets.Parent = children
		component.Object = targets
		tenacity:RegisterGUIStyleObject(targets, 'ControlRow')
		addTooltip(targets, props.Tooltip)
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		holder.Position = UDim2.fromOffset(10, 4)
		holder.Size = UDim2.new(1, -20, 1, -9)
		holder.Parent = targets
		addCorner(holder, UDim.new(0, 4))
		tenacity:RegisterGUIStyleObject(holder, 'ControlHolder')
		local button = Instance.new('TextButton')
		button.AutoButtonColor = false
		button.BackgroundColor3 = uipallet.Main
		button.Position = UDim2.fromOffset(1, 1)
		button.Size = UDim2.new(1, -2, 1, -2)
		button.Text = ''
		button.Parent = holder
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(5, 6)
		title.Size = UDim2.new(1, -5, 0, 15)
		title.Text = 'Target:'
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 15
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = button
		local items = Instance.new('TextLabel')
		items.BackgroundTransparency = 1
		items.FontFace = uipallet.Font
		items.Position = UDim2.fromOffset(5, 21)
		items.Size = UDim2.new(1, -5, 0, 15)
		items.Text = 'Ignore none'
		items.TextColor3 = color.Dark(uipallet.Text, 0.16)
		items.TextSize = 11
		items.TextTruncate = Enum.TextTruncate.AtEnd
		items.TextXAlignment = Enum.TextXAlignment.Left
		items.Parent = button
		addCorner(button, UDim.new(0, 4))
		local iconholder = Instance.new('Frame')
		iconholder.BackgroundTransparency = 1
		iconholder.Position = UDim2.fromOffset(52, 8)
		iconholder.Size = UDim2.fromOffset(65, 12)
		iconholder.Parent = button
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 6)
		layout.Parent = iconholder
		local targetswindow = Instance.new('TextButton')
		targetswindow.AutoButtonColor = false
		targetswindow.BackgroundColor3 = uipallet.Main
		targetswindow.BorderSizePixel = 0
		targetswindow.Position = UDim2.fromOffset(456, 139)
		targetswindow.Size = UDim2.fromOffset(220, 145)
		targetswindow.Text = ''
		targetswindow.Visible = false
		targetswindow.Parent = clickgui
		component.Window = targetswindow
		addBlur(targetswindow)
		addCorner(targetswindow)
		tenacity:RegisterGUIStyleObject(targetswindow, 'CategoryWindow')
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = gettenacityasset('tenacity/assets/new/aim.png')
		icon.Position = UDim2.fromOffset(10, 15)
		icon.Size = UDim2.fromOffset(18, 12)
		icon.Parent = targetswindow
		local windowtitle = Instance.new('TextLabel')
		windowtitle.BackgroundTransparency = 1
		windowtitle.FontFace = uipallet.Font
		windowtitle.Size = UDim2.new(1, -36, 0, 20)
		windowtitle.Position = UDim2.fromOffset(math.abs(windowtitle.Size.X.Offset), 11)
		windowtitle.Text = 'Target settings'
		windowtitle.TextColor3 = uipallet.Text
		windowtitle.TextSize = 13
		windowtitle.TextXAlignment = Enum.TextXAlignment.Left
		windowtitle.Parent = targetswindow
		local close = addCloseButton(targetswindow)
		props.Function = props.Function or function() end

		function component:Color(hue, sat, val, isRainbow)
			if targetswindow.Visible then
				if not tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, true, 0) then
					holder.BackgroundColor3 = isRainbow and Color3.fromHSV(tenacity:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
				end
			end

			if self.Players.Enabled then
				tween:Cancel(self.Players.Object.Frame)
				if not tenacity:ApplyThemeGradient(self.Players.Object.Frame, 'BackgroundColor3', 0.02, true, 0) then
					self.Players.Object.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			else
				tenacity:ApplyThemeGradient(self.Players.Object.Frame, 'BackgroundColor3', 0.02, false, 0)
			end

			if self.NPCs.Enabled then
				tween:Cancel(self.NPCs.Object.Frame)
				if not tenacity:ApplyThemeGradient(self.NPCs.Object.Frame, 'BackgroundColor3', 0.08, true, 0) then
					self.NPCs.Object.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			else
				tenacity:ApplyThemeGradient(self.NPCs.Object.Frame, 'BackgroundColor3', 0.08, false, 0)
			end

			if self.Invisible.Enabled then
				tween:Cancel(self.Invisible.Object.Holder)
				if not tenacity:ApplyThemeGradient(self.Invisible.Object.Holder, 'BackgroundColor3', 0.14, true, 0) then
					self.Invisible.Object.Holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			else
				tenacity:ApplyThemeGradient(self.Invisible.Object.Holder, 'BackgroundColor3', 0.14, false, 0)
			end

			if self.Walls.Enabled then
				tween:Cancel(self.Walls.Object.Holder)
				if not tenacity:ApplyThemeGradient(self.Walls.Object.Holder, 'BackgroundColor3', 0.2, true, 0) then
					self.Walls.Object.Holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			else
				tenacity:ApplyThemeGradient(self.Walls.Object.Holder, 'BackgroundColor3', 0.2, false, 0)
			end
		end

		function component:Load(data)
			if self.Players.Enabled ~= data.Players then
				self.Players:Toggle()
			end

			if self.NPCs.Enabled ~= data.NPCs then
				self.NPCs:Toggle()
			end

			if self.Invisible.Enabled ~= data.Invisible then
				self.Invisible:Toggle()
			end

			if self.Walls.Enabled ~= data.Walls then
				self.Walls:Toggle()
			end
		end

		function component:Save(data)
			data.Targets = {
				Players = self.Players.Enabled,
				NPCs = self.NPCs.Enabled,
				Invisible = self.Invisible.Enabled,
				Walls = self.Walls.Enabled
			}
		end

		function component:UpdateText()
			local newText = {}

			if self.Players.Enabled then
				table.insert(newText, 'Players')
			end

			if self.NPCs.Enabled then
				table.insert(newText, 'NPCs')
			end

			title.Text = 'Target: '..(#newText > 0 and table.concat(newText, ', ') or 'Nothing')
			title.TextColor3 = #newText > 0 and uipallet.Text or Color3.fromRGB(255, 90, 90)
		end

		component.Players = components.TargetsButton({
			Position = UDim2.fromOffset(11, 45),
			Icon = gettenacityasset('tenacity/assets/new/players.png'),
			IconSize = UDim2.fromOffset(16, 16),
			IconParent = iconholder,
			Targets = component,
			Tooltip = 'Target players',
			Function = props.Function
		}, targetswindow, iconholder)

		component.NPCs = components.TargetsButton({
			Position = UDim2.fromOffset(112, 45),
			Icon = gettenacityasset('tenacity/assets/new/npcs.png'),
			IconSize = UDim2.fromOffset(12, 16),
			IconParent = iconholder,
			Targets = component,
			Tooltip = 'Target NPCs',
			Function = props.Function
		}, targetswindow, iconholder)

		component.Invisible = components.Toggle({
			Name = 'Ignore invisible',
			Function = function()
				local newText = {}

				if component.Invisible.Enabled then
					table.insert(newText, 'invisible')
				end

				if component.Walls.Enabled then
					table.insert(newText, 'behind walls')
				end

				items.Text = 'Ignore '..(#newText > 0 and table.concat(newText, ', ') or 'none')
				props.Function()
			end
		}, targetswindow, {Options = {}})
		component.Invisible.Object.Position = UDim2.fromOffset(0, 81)

		component.Walls = components.Toggle({
			Name = 'Ignore behind walls',
			Function = function()
				local newText = {}

				if component.Invisible.Enabled then
					table.insert(newText, 'invisible')
				end

				if component.Walls.Enabled then
					table.insert(newText, 'behind walls')
				end

				items.Text = 'Ignore '..(#newText > 0 and table.concat(newText, ', ') or 'none')
				props.Function()
			end
		}, targetswindow, {Options = {}})
		component.Walls.Object.Position = UDim2.fromOffset(0, 111)

		if props.Players then
			component.Players:Toggle()
		end

		if props.NPCs then
			component.NPCs:Toggle()
		end

		if props.Invisible then
			component.Invisible:Toggle()
		end

		if props.Walls then
			component.Walls:Toggle()
		end

		close.MouseButton1Click:Connect(function()
			targetswindow.Visible = false
		end)

		button.MouseButton1Click:Connect(function()
			targetswindow.Visible = not targetswindow.Visible
			tween:Cancel(holder)

			if targetswindow.Visible then
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, true, 0)
			else
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, false, 0)
				holder.BackgroundColor3 = color.Light(uipallet.Main, 0.37)
			end
		end)

		targets.MouseEnter:Connect(function()
			if not targetswindow.Visible then
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.37)
				})
			end
		end)

		targets.MouseLeave:Connect(function()
			if not targetswindow.Visible then
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				})
			end
		end)

		targets:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			local actualPosition = (targets.AbsolutePosition + Vector2.new(0, 60)) / scale.Scale
			targetswindow.Position = UDim2.fromOffset(actualPosition.X + 223, actualPosition.Y)
		end)

		api.Options.Targets = component

		return component
	end,
	TargetsButton = function(props, children, api)
		local component = {
			Enabled = false,
			Type = 'TargetsButton'
		}

		local targetsbutton = Instance.new('TextButton')
		targetsbutton.AutoButtonColor = false
		targetsbutton.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
		targetsbutton.Position = props.Position
		targetsbutton.Size = UDim2.fromOffset(98, 31)
		targetsbutton.Text = ''
		targetsbutton.Visible = props.Visible == nil or props.Visible
		targetsbutton.Parent = children
		component.Object = targetsbutton
		addCorner(targetsbutton)
		addTooltip(targetsbutton, props.Tooltip)
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = uipallet.Main
		holder.Position = UDim2.fromOffset(1, 1)
		holder.Size = UDim2.new(1, -2, 1, -2)
		holder.Parent = targetsbutton
		addCorner(holder)
		local icon = Instance.new('ImageLabel')
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = props.Icon
		icon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = props.IconSize
		icon.Parent = holder
		props.Function = props.Function or function() end

		function component:Toggle()
			self.Enabled = not self.Enabled
			if self.Enabled then
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', 0.08, true, 0)
			else
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', 0.08, false, 0)
				holder.BackgroundColor3 = uipallet.Main
			end

			tween:Tween(icon, uipallet.Tween, {
				ImageColor3 = self.Enabled and Color3.new(1, 1, 1) or color.Light(uipallet.Main, 0.37)
			})

			props.Targets:UpdateText()
			props.Function(self.Enabled)
		end

		targetsbutton.MouseEnter:Connect(function()
			if not component.Enabled then
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = color.Dark(tenacity:GetThemeColor(0.08), 0.25)
				})

				tween:Tween(icon, uipallet.Tween, {
					ImageColor3 = Color3.new(1, 1, 1)
				})
			end
		end)

		targetsbutton.MouseLeave:Connect(function()
			if not component.Enabled then
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = uipallet.Main
				})

				tween:Tween(icon, uipallet.Tween, {
					ImageColor3 = color.Light(uipallet.Main, 0.37)
				})
			end
		end)

		targetsbutton.MouseButton1Click:Connect(function()
			component:Toggle()
		end)

		return component
	end,
	TextBox = function(props, children, api)
		local component = {
			Index = 0,
			Type = 'TextBox',
			Value = props.Default or ''
		}

		local textbox = Instance.new('TextButton')
		textbox.AutoButtonColor = false
		textbox.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
		textbox.BorderSizePixel = 0
		textbox.Size = UDim2.new(1, 0, 0, 58)
		textbox.Text = ''
		textbox.Visible = props.Visible == nil or props.Visible
		textbox.Parent = children
		component.Object = textbox
		tenacity:RegisterGUIStyleObject(textbox, 'ControlRow')
		addTooltip(textbox, props.Tooltip)
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(10, 3)
		title.Size = UDim2.new(1, -10, 0, 20)
		title.Text = props.Name
		title.TextColor3 = uipallet.Text
		title.TextSize = 12
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = textbox
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		holder.Position = UDim2.fromOffset(10, 23)
		holder.Size = UDim2.new(1, -20, 0, 29)
		holder.Parent = textbox
		addCorner(holder, UDim.new(0, 4))
		tenacity:RegisterGUIStyleObject(holder, 'ControlHolder')
		local inputbox = Instance.new('TextBox')
		inputbox.BackgroundTransparency = 1
		inputbox.ClearTextOnFocus = false
		inputbox.FontFace = uipallet.Font
		inputbox.PlaceholderColor3 = color.Dark(uipallet.Text, 0.31)
		inputbox.PlaceholderText = props.Placeholder or 'Click to set'
		inputbox.Position = UDim2.fromOffset(8, 0)
		inputbox.Size = UDim2.new(1, -8, 1, 0)
		inputbox.Text = props.Default or ''
		inputbox.TextColor3 = color.Dark(uipallet.Text, 0.16)
		inputbox.TextSize = 12
		inputbox.TextXAlignment = Enum.TextXAlignment.Left
		inputbox.Parent = holder
		props.Function = props.Function or function() end

		function component:Load(data)
			if self.Value ~= data.Value then
				self:SetValue(data.Value)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				Value = self.Value
			}
		end

		function component:SetValue(val, enter)
			self.Value = val
			inputbox.Text = val
			props.Function(enter)
		end

		textbox.MouseButton1Click:Connect(function()
			inputbox:CaptureFocus()
		end)

		inputbox.FocusLost:Connect(function(enter)
			component:SetValue(inputbox.Text, enter)
		end)

		inputbox:GetPropertyChangedSignal('Text'):Connect(function()
			component:SetValue(inputbox.Text)
		end)

		api.Options[props.Name] = component

		return component
	end,
	TextList = function(props, children, api)
		local component = {
			Index = getTableSize(api.Options),
			List = props.Default and table.clone(props.Default) or {},
			ListEnabled = props.Default and table.clone(props.Default) or {},
			Objects = {},
			Type = 'TextList',
			Window = {Visible = false}
		}

		props.Color = props.Color or Color3.fromRGB(5, 134, 105)
		local textlist = Instance.new('TextButton')
		textlist.AutoButtonColor = false
		textlist.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
		textlist.BorderSizePixel = 0
		textlist.Size = UDim2.new(1, 0, 0, 50)
		textlist.Text = ''
		textlist.Visible = props.Visible == nil or props.Visible
		textlist.Parent = children
		component.Object = textlist
		tenacity:RegisterGUIStyleObject(textlist, 'ControlRow')
		addTooltip(textlist, props.Tooltip)
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		holder.Position = UDim2.fromOffset(10, 4)
		holder.Size = UDim2.new(1, -20, 1, -9)
		holder.Parent = textlist
		addCorner(holder, UDim.new(0, 4))
		tenacity:RegisterGUIStyleObject(holder, 'ControlHolder')
		local button = Instance.new('TextButton')
		button.AutoButtonColor = false
		button.BackgroundColor3 = uipallet.Main
		button.Position = UDim2.fromOffset(1, 1)
		button.Size = UDim2.new(1, -2, 1, -2)
		button.Text = ''
		button.Parent = holder
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = gettenacityasset('tenacity/assets/new/allowediconmini.png')
		icon.Position = UDim2.fromOffset(10, 14)
		icon.Size = UDim2.fromOffset(14, 12)
		icon.Parent = button
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(35, 6)
		title.Size = UDim2.new(1, -35, 0, 15)
		title.Text = props.Name
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 15
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = button
		local amount = Instance.fromExisting(title)
		amount.Position = UDim2.fromOffset(0, 6)
		amount.Size = UDim2.new(1, -13, 0, 15)
		amount.Text = '0'
		amount.TextXAlignment = Enum.TextXAlignment.Right
		amount.Parent = button
		local items = Instance.fromExisting(title)
		items.Position = UDim2.fromOffset(35, 21)
		items.Text = 'None'
		items.TextColor3 = color.Dark(uipallet.Text, 0.43)
		items.TextSize = 11
		items.Parent = button
		addCorner(button, UDim.new(0, 4))
		local textlistwindow = Instance.new('TextButton')
		textlistwindow.AutoButtonColor = false
		textlistwindow.BackgroundColor3 = uipallet.Main
		textlistwindow.BorderSizePixel = 0
		textlistwindow.Position = UDim2.fromOffset(456, 227)
		textlistwindow.Size = UDim2.fromOffset(220, 85)
		textlistwindow.Text = ''
		textlistwindow.Visible = false
		textlistwindow.Parent = api.Auxiliary and tenacity.Auxiliary.Window or clickgui
		component.Window = textlistwindow
		addBlur(textlistwindow)
		addCorner(textlistwindow)
		tenacity:RegisterGUIStyleObject(textlistwindow, 'CategoryWindow')
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Image = gettenacityasset('tenacity/assets/new/allowedicon.png')
		icon.Position = UDim2.fromOffset(10, 13)
		icon.Size = UDim2.fromOffset(19, 16)
		icon.Parent = textlistwindow
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(36, 11)
		title.Size = UDim2.new(1, -36, 0, 20)
		title.Text = props.Name
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = textlistwindow
		local close = addCloseButton(textlistwindow)
		local boxholder = Instance.new('Frame')
		boxholder.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		boxholder.Position = UDim2.fromOffset(10, 45)
		boxholder.Size = UDim2.fromOffset(200, 31)
		boxholder.Parent = textlistwindow
		addCorner(boxholder)
		tenacity:RegisterGUIStyleObject(boxholder, 'ControlHolder')
		local boxinner = Instance.new('Frame')
		boxinner.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		boxinner.Position = UDim2.fromOffset(1, 1)
		boxinner.Size = UDim2.new(1, -2, 1, -2)
		boxinner.Parent = boxholder
		addCorner(boxinner)
		local textbox = Instance.new('TextBox')
		textbox.BackgroundTransparency = 1
		textbox.ClearTextOnFocus = false
		textbox.FontFace = uipallet.Font
		textbox.PlaceholderText = props.Placeholder or 'Add entry...'
		textbox.PlaceholderColor3 = Color3.new(0.8, 0.8, 0.8)
		textbox.Position = UDim2.fromOffset(10, 0)
		textbox.Size = UDim2.new(1, -35, 1, 0)
		textbox.Text = ''
		textbox.TextColor3 = Color3.new(1, 1, 1)
		textbox.TextSize = 13
		textbox.TextXAlignment = Enum.TextXAlignment.Left
		textbox.Parent = boxholder
		local add = Instance.new('ImageButton')
		add.BackgroundTransparency = 1
		add.Image = gettenacityasset('tenacity/assets/new/add.png')
		add.ImageColor3 = props.Color
		add.ImageTransparency = 0.3
		add.Position = UDim2.new(1, -26, 0, 8)
		add.Size = UDim2.fromOffset(16, 16)
		add.Parent = boxholder
		props.Function = props.Function or function() end

		function component:Color(hue, sat, val, isRainbow)
			if textlistwindow.Visible then
				if not tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, true, 0) then
					holder.BackgroundColor3 = isRainbow and Color3.fromHSV(tenacity:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
				end
			end
		end

		function component:ChangeValue(value)
			if value then
				local index = table.find(self.List, value)
				if index then
					table.remove(self.List, index)

					index = table.find(self.ListEnabled, value)
					if index then
						table.remove(self.ListEnabled, index)
					end
				else
					table.insert(self.List, value)
					table.insert(self.ListEnabled, value)
				end
			end

			props.Function(self.List)
			for _, v in self.Objects do
				v:Destroy()
			end
			table.clear(self.Objects)
			textlistwindow.Size = UDim2.fromOffset(220, 85 + (#self.List * 35))
			amount.Text = #self.List
			items.Text = #self.ListEnabled > 0 and table.concat(self.ListEnabled, ', ') or 'None'

			for index, value in self.List do
				local isEnabled = table.find(self.ListEnabled, value)
				local obj = Instance.new('TextButton')
				obj.AutoButtonColor = false
				obj.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				obj.Position = UDim2.fromOffset(10, 47 + (index * 35))
				obj.Size = UDim2.fromOffset(200, 31)
				obj.Text = ''
				obj.Parent = textlistwindow
				addCorner(obj)
				local bkg = Instance.new('Frame')
				bkg.BackgroundColor3 = uipallet.Main
				bkg.Position = UDim2.fromOffset(1, 1)
				bkg.Size = UDim2.new(1, -2, 1, -2)
				bkg.Visible = false
				bkg.Parent = obj
				addCorner(bkg)
				local dot = Instance.new('Frame')
				dot.BackgroundColor3 = isEnabled and props.Color or color.Light(uipallet.Main, 0.37)
				dot.Position = UDim2.fromOffset(10, 12)
				dot.Size = UDim2.fromOffset(10, 11)
				dot.Parent = obj
				addCorner(dot, UDim.new(1, 0))
				local dotin = dot:Clone()
				dotin.BackgroundColor3 = isEnabled and props.Color or color.Light(uipallet.Main, 0.02)
				dotin.Position = UDim2.fromOffset(1, 1)
				dotin.Size = UDim2.fromOffset(8, 9)
				dotin.Parent = dot
				local label = Instance.new('TextLabel')
				label.BackgroundTransparency = 1
				label.FontFace = uipallet.Font
				label.Position = UDim2.fromOffset(30, 0)
				label.Size = UDim2.new(1, -30, 1, 0)
				label.Text = value
				label.TextColor3 = color.Dark(uipallet.Text, 0.16)
				label.TextSize = 15
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.Parent = obj
				local close = Instance.new('ImageButton')
				close.AutoButtonColor = false
				close.BackgroundColor3 = Color3.new(1, 1, 1)
				close.BackgroundTransparency = 1
				close.Image = gettenacityasset('tenacity/assets/new/closetiny.png')
				close.ImageColor3 = color.Light(uipallet.Text, 0.2)
				close.ImageTransparency = 0.5
				close.Position = UDim2.new(1, -27, 0, 8)
				close.Size = UDim2.fromOffset(18, 17)
				close.Parent = obj
				addCorner(close, UDim.new(1, 0))

				close.MouseEnter:Connect(function()
					close.ImageTransparency = 0.3
					tween:Tween(close, uipallet.Tween, {
						BackgroundTransparency = 0.6
					})
				end)

				close.MouseLeave:Connect(function()
					close.ImageTransparency = 0.5
					tween:Tween(close, uipallet.Tween, {
						BackgroundTransparency = 1
					})
				end)

				close.MouseButton1Click:Connect(function()
					self:ChangeValue(value)
				end)

				obj.MouseEnter:Connect(function()
					bkg.Visible = true
				end)

				obj.MouseLeave:Connect(function()
					bkg.Visible = false
				end)

				obj.MouseButton1Click:Connect(function()
					local index = table.find(self.ListEnabled, value)
					if index then
						table.remove(self.ListEnabled, index)
						dot.BackgroundColor3 = color.Light(uipallet.Main, 0.37)
						dotin.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					else
						table.insert(self.ListEnabled, value)
						dot.BackgroundColor3 = props.Color
						dotin.BackgroundColor3 = props.Color
					end

					items.Text = #self.ListEnabled > 0 and table.concat(self.ListEnabled, ', ') or 'None'
					props.Function(self.List)
				end)

				table.insert(self.Objects, obj)
			end
		end

		function component:Load(data)
			self.List = data.List or {}
			self.ListEnabled = data.ListEnabled or {}
			self:ChangeValue()
		end

		function component:Save(data)
			data[props.Name] = {
				List = self.List,
				ListEnabled = self.ListEnabled
			}
		end

		add.MouseEnter:Connect(function()
			add.ImageTransparency = 0
		end)

		add.MouseLeave:Connect(function()
			add.ImageTransparency = 0.3
		end)

		add.MouseButton1Click:Connect(function()
			local newText = props.TextFunction and props.TextFunction(textbox.Text) or textbox.Text
			if not table.find(component.List, newText) then
				component:ChangeValue(newText)
				textbox.Text = ''
			end
		end)

		textbox.FocusLost:Connect(function(enter)
			local newText = props.TextFunction and props.TextFunction(textbox.Text) or textbox.Text
			if enter and not table.find(component.List, newText) then
				component:ChangeValue(newText)
				textbox.Text = ''
			end
		end)

		textbox.MouseEnter:Connect(function()
			tween:Tween(boxholder, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			})
		end)

		textbox.MouseLeave:Connect(function()
			tween:Tween(boxholder, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			})
		end)

		close.MouseButton1Click:Connect(function()
			textlistwindow.Visible = false
		end)

		button.MouseButton1Click:Connect(function()
			textlistwindow.Visible = not textlistwindow.Visible

			tween:Cancel(holder)
			if textlistwindow.Visible then
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, true, 0)
			else
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, false, 0)
				holder.BackgroundColor3 = color.Light(uipallet.Main, 0.37)
			end
		end)

		textlist.MouseEnter:Connect(function()
			if not textlistwindow.Visible then
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.37)
				})
			end
		end)

		textlist.MouseLeave:Connect(function()
			if not textlistwindow.Visible then
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				})
			end
		end)

		textlist:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			if tenacity.ThreadFix then
				setthreadidentity(8)
			end

			local actualPosition = (textlist.AbsolutePosition - (api.Auxiliary and tenacity.Auxiliary.Window.AbsolutePosition or -guiService:GetGuiInset())) / scale.Scale
			textlistwindow.Position = UDim2.fromOffset(actualPosition.X + 223, actualPosition.Y)
		end)

		if props.Default then
			component:ChangeValue()
		end

		api.Options[props.Name] = component

		return component
	end,
	Toggle = function(props, children, api)
		local component = {
			Enabled = false,
			Index = getTableSize(api.Options),
			Name = props.Name,
			Type = 'Toggle'
		}

		local isHover = false
		local toggle = Instance.new('TextButton')
		toggle.AutoButtonColor = false
		toggle.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
		toggle.BorderSizePixel = 0
		toggle.FontFace = uipallet.Font
		toggle.Size = UDim2.new(1, 0, 0, 30)
		toggle.Text = '          '..props.Name
		toggle.TextColor3 = color.Dark(uipallet.Text, 0.16)
		toggle.TextSize = 14
		toggle.TextXAlignment = Enum.TextXAlignment.Left
		toggle.Visible = props.Visible == nil or props.Visible
		toggle.Parent = children
		component.Object = toggle
		addTooltip(toggle, props.Tooltip)
		tenacity:RegisterGUIStyleObject(toggle, 'ControlRow')
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		holder.Name = 'Holder'
		holder.Position = UDim2.new(1, -30, 0, 9)
		holder.Size = UDim2.fromOffset(22, 12)
		holder.Parent = toggle
		addCorner(holder, UDim.new(1, 0))
		tenacity:RegisterGUIStyleObject(holder, 'ToggleTrack')
		local knob = Instance.new('Frame')
		knob.BackgroundColor3 = uipallet.Main
		knob.Position = UDim2.fromOffset(2, 2)
		knob.Size = UDim2.fromOffset(8, 8)
		knob.Parent = holder
		addCorner(knob, UDim.new(1, 0))
		tenacity:ApplyGUIStyleObject(holder, 'ToggleTrack')
		props.Function = props.Function or function() end

		function component:Color(hue, sat, val, isRainbow)
			if self.Enabled then
				tween:Cancel(holder)
				if not tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, true, 0) then
					holder.BackgroundColor3 = isRainbow and Color3.fromHSV(tenacity:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
				end
			else
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, false, 0)
			end
		end

		function component:Load(data)
			if self.Enabled ~= data.Enabled then
				self:Toggle()
			end

			if self.Bind and data.Bind then
				self.Bind:Load(data.Bind)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				Enabled = self.Enabled
			}

			if self.Bind then
				self.Bind:Save(data[props.Name])
			end
		end

		function component:Toggle()
			self.Enabled = not self.Enabled
			if self.Enabled then
				tween:Cancel(holder)
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, true, 0)
			else
				tenacity:ApplyThemeGradient(holder, 'BackgroundColor3', self.Index * 0.075, false, 0)
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = isHover and color.Light(uipallet.Main, 0.37) or color.Light(uipallet.Main, 0.14)
				})
			end

			tween:Tween(knob, uipallet.Tween, {
				Position = UDim2.fromOffset(self.Enabled and 12 or 2, 2)
			})

			props.Function(self.Enabled)
		end

		toggle.MouseEnter:Connect(function()
			isHover = true

			if not component.Enabled then
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.37)
				})
			end
		end)

		toggle.MouseLeave:Connect(function()
			isHover = false

			if not component.Enabled then
				tween:Tween(holder, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.14)
				})
			end
		end)

		toggle.MouseButton1Click:Connect(function()
			component:Toggle()
		end)

		if props.Default then
			component:Toggle()
		end

		api.Options[props.Name] = component

		return component
	end,
	TwoSlider = function(props, children, api)
		local component = {
			Index = getTableSize(api.Options),
			Max = props.Max,
			Type = 'TwoSlider',
			ValueMin = props.DefaultMin or props.Min,
			ValueMax = props.DefaultMax or 10
		}

		local twoslider = Instance.new('TextButton')
		twoslider.AutoButtonColor = false
		twoslider.BackgroundColor3 = color.Dark(children.BackgroundColor3, props.Darker and 0.02 or 0)
		twoslider.BorderSizePixel = 0
		twoslider.Size = UDim2.new(1, 0, 0, 50)
		twoslider.Text = ''
		twoslider.Visible = props.Visible == nil or props.Visible
		twoslider.Parent = children
		component.Object = twoslider
		addTooltip(twoslider, props.Tooltip)
		tenacity:RegisterGUIStyleObject(twoslider, 'ControlRow')
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(10, 2)
		title.Size = UDim2.fromOffset(60, 30)
		title.Text = props.Name
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 11
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = twoslider
		local maxvalue = Instance.new('TextButton')
		maxvalue.BackgroundTransparency = 1
		maxvalue.FontFace = uipallet.Font
		maxvalue.Position = UDim2.new(1, -69, 0, 9)
		maxvalue.Size = UDim2.fromOffset(60, 15)
		maxvalue.Text = component.ValueMax
		maxvalue.TextColor3 = color.Dark(uipallet.Text, 0.16)
		maxvalue.TextSize = 11
		maxvalue.TextXAlignment = Enum.TextXAlignment.Right
		maxvalue.Parent = twoslider
		local minvalue = maxvalue:Clone()
		minvalue.Position = UDim2.new(1, -125, 0, 9)
		minvalue.Text = component.ValueMin
		minvalue.Parent = twoslider
		local custommax = Instance.new('TextBox')
		custommax.BackgroundTransparency = 1
		custommax.ClearTextOnFocus = false
		custommax.FontFace = uipallet.Font
		custommax.Position = maxvalue.Position
		custommax.Size = UDim2.fromOffset(60, 15)
		custommax.Text = component.ValueMax
		custommax.TextColor3 = color.Dark(uipallet.Text, 0.16)
		custommax.TextSize = 11
		custommax.TextXAlignment = Enum.TextXAlignment.Right
		custommax.Visible = false
		custommax.Parent = twoslider
		local custommin = custommax:Clone()
		custommin.Position = minvalue.Position
		custommin.Parent = twoslider
		local holder = Instance.new('Frame')
		holder.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		holder.BorderSizePixel = 0
		holder.Position = UDim2.fromOffset(10, 37)
		holder.Size = UDim2.new(1, -20, 0, 2)
		holder.Parent = twoslider
		tenacity:RegisterGUIStyleObject(holder, 'SliderTrack')
		local fill = Instance.new('Frame')
		fill.BackgroundColor3 = tenacity:GetThemeColor(0)
		fill.BorderSizePixel = 0
		fill.Position = UDim2.fromScale(math.clamp(component.ValueMin / props.Max, 0.04, 0.96), 0)
		fill.Size = UDim2.fromScale(math.clamp(math.clamp(component.ValueMax / props.Max, 0, 1), 0.04, 0.96) - fill.Position.X.Scale, 1)
		fill.Parent = holder
		local knob = Instance.new('Frame')
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = twoslider.BackgroundColor3
		knob.BorderSizePixel = 0
		knob.Position = UDim2.fromScale(0, 0.5)
		knob.Size = UDim2.fromOffset(16, 4)
		knob.Parent = fill
		local knobknob = Instance.new('ImageLabel')
		knobknob.AnchorPoint = Vector2.new(0.5, 0.5)
		knobknob.BackgroundTransparency = 1
		knobknob.Image = gettenacityasset('tenacity/assets/new/range.png')
		knobknob.ImageColor3 = tenacity:GetThemeColor(0)
		knobknob.Position = UDim2.fromScale(0.5, 0.5)
		knobknob.Size = UDim2.fromOffset(9, 16)
		knobknob.Parent = knob
		local knobmax = knob:Clone()
		knobmax.Position = UDim2.fromScale(1, 0.5)
		knobmax.Parent = fill
		local knobmaxknob = knobmax.ImageLabel
		knobmaxknob.Rotation = 180
		local arrow = Instance.new('ImageLabel')
		arrow.BackgroundTransparency = 1
		arrow.Image = gettenacityasset('tenacity/assets/new/rangeindicator.png')
		arrow.ImageColor3 = color.Light(uipallet.Main, 0.14)
		arrow.Position = UDim2.new(1, -56, 0, 10)
		arrow.Size = UDim2.fromOffset(12, 6)
		arrow.Parent = twoslider
		props.Function = props.Function or function() end
		props.Decimal = props.Decimal or 1
		local random = Random.new()

		function component:Color(hue, sat, val, isRainbow)
			if tenacity:ApplyThemeGradient(fill, 'BackgroundColor3', self.Index * 0.075, true, 0) then
				local accent = tenacity:GetThemeColor(self.Index * 0.075)
				knobknob.ImageColor3 = accent
				knobmaxknob.ImageColor3 = accent
			else
				fill.BackgroundColor3 = isRainbow and Color3.fromHSV(tenacity:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
				knobknob.ImageColor3 = fill.BackgroundColor3
				knobmaxknob.ImageColor3 = fill.BackgroundColor3
			end
		end

		function component:GetRandomValue()
			return random:NextNumber(component.ValueMin, component.ValueMax)
		end

		function component:Load(data)
			if self.ValueMin ~= data.ValueMin then
				self:SetValue(false, data.ValueMin)
			end

			if self.ValueMax ~= data.ValueMax then
				self:SetValue(true, data.ValueMax)
			end
		end

		function component:Save(data)
			data[props.Name] = {
				ValueMin = self.ValueMin,
				ValueMax = self.ValueMax
			}
		end

		function component:SetValue(isMax, value)
			if not (value == value and math.abs(value) < math.huge) then
				return
			end

			self[isMax and 'ValueMax' or 'ValueMin'] = value
			maxvalue.Text = self.ValueMax
			minvalue.Text = self.ValueMin

			local size = math.clamp(math.clamp(self.ValueMin / props.Max, 0, 1), 0.04, 0.96)
			tween:Tween(fill, TweenInfo.new(0.1), {
				Position = UDim2.fromScale(size, 0),
				Size = UDim2.fromScale(math.clamp(math.clamp(self.ValueMax / props.Max, 0.04, 0.96) - size, 0, 1), 1)
			})
		end

		knob.MouseEnter:Connect(function()
			tween:Tween(knobknob, uipallet.Tween, {
				Size = UDim2.fromOffset(11, 18)
			})
		end)

		knob.MouseLeave:Connect(function()
			tween:Tween(knobknob, uipallet.Tween, {
				Size = UDim2.fromOffset(9, 16)
			})
		end)

		knobmax.MouseEnter:Connect(function()
			tween:Tween(knobmaxknob, uipallet.Tween, {
				Size = UDim2.fromOffset(11, 18)
			})
		end)

		knobmax.MouseLeave:Connect(function()
			tween:Tween(knobmaxknob, uipallet.Tween, {
				Size = UDim2.fromOffset(9, 16)
			})
		end)

		twoslider.InputBegan:Connect(function(input)
			if
				(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
				and (input.Position.Y - twoslider.AbsolutePosition.Y) > (20 * scale.Scale)
			then
				local maxCheck = (input.Position.X - knobmax.AbsolutePosition.X) > -10
				local newPosition = math.clamp((input.Position.X - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1)

				local releaseConnection
				local moveConnection = inputService.InputChanged:Connect(function(newInput)
					if newInput.UserInputType == (input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
						local newPosition = math.clamp((newInput.Position.X - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1)
						component:SetValue(maxCheck, math.floor((props.Min + (props.Max - props.Min) * newPosition) * props.Decimal) / props.Decimal, newPosition)
					end
				end)

				releaseConnection = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						moveConnection:Disconnect()
						releaseConnection:Disconnect()
					end
				end)

				component:SetValue(maxCheck, math.floor((props.Min + (props.Max - props.Min) * newPosition) * props.Decimal) / props.Decimal, newPosition)
			end
		end)

		maxvalue.MouseButton1Click:Connect(function()
			maxvalue.Visible = false
			custommax.Visible = true
			custommax.Text = component.ValueMax
			custommax:CaptureFocus()
		end)

		minvalue.MouseButton1Click:Connect(function()
			minvalue.Visible = false
			custommin.Visible = true
			custommin.Text = component.ValueMin
			custommin:CaptureFocus()
		end)

		custommax.FocusLost:Connect(function(enter)
			maxvalue.Visible = true
			custommax.Visible = false

			if enter and tonumber(custommax.Text) then
				component:SetValue(true, tonumber(custommax.Text))
			end
		end)

		custommin.FocusLost:Connect(function(enter)
			minvalue.Visible = true
			custommin.Visible = false

			if enter and tonumber(custommin.Text) then
				component:SetValue(false, tonumber(custommin.Text))
			end
		end)

		api.Options[props.Name] = component

		return component
	end,
}

tenacity.Components = setmetatable(components, {
	__newindex = function(_, index, callback)
		for _, module in tenacity.Modules do
			rawset(module, 'Create'..index, function(_, props)
				return callback(props, module.Children, module)
			end)
		end

		if tenacity.Auxiliary then
			for _, module in tenacity.Auxiliary.Modules do
				rawset(module, 'Create'..index, function(_, props)
					return callback(props, module.Children, module)
				end)
			end
		end

		rawset(components, index, callback)
	end
})

-- Retain control definitions for the independent Tenacity renderer. The hidden
-- original objects remain the compatibility model for existing game modules.
-- Compatibility constructors sometimes pass Roblox Instances as `owner`; never
-- probe arbitrary Instances for module-only fields such as `.Options`.
local function optionsOf(owner)
	if type(owner) ~= 'table' then return nil end
	local options = owner.Options
	return type(options) == 'table' and options or nil
end

-- Old GUI constructors were written with the assumption that their third
-- argument is always a module/component table. A few structural compatibility
-- controls historically passed Roblox Instances there instead. Sanitise that
-- value *before* calling any constructor so `api.Options` can never index a
-- Frame. The proxy is deliberately local/headless: an Instance never had a
-- real Options table to preserve in the first place.
local function compatibilityOwner(owner, parent)
	if type(owner) == 'table' then return owner, owner end
	if typeof(owner) == 'Instance' then
		return {
			Options = {},
			Object = owner,
			Children = parent,
			Name = owner.Name,
			Enabled = false,
			CompatibilityInstance = owner
		}, nil
	end
	return {Options = {}, Children = parent}, nil
end

tenacity.TenacityControls = setmetatable({}, {__mode = 'k'})
for kind, constructor in components do
	if kind ~= 'Font' then
		rawset(components, kind, function(props, parent, owner)
			local safeOwner, registryOwner = compatibilityOwner(owner, parent)
			local component = constructor(props, parent, safeOwner)
			if type(component) == 'table' and props then
				component.TenacityProps = props
				local ownerOptions = optionsOf(registryOwner)
				-- Only genuine module/component tables belong in the renderer registry.
				-- Compatibility Instance proxies are intentionally never registered.
				if registryOwner and (component.Type == 'Button' or (ownerOptions and ownerOptions[props.Name] == component)) then
					local controls = tenacity.TenacityControls[registryOwner] or {}
					tenacity.TenacityControls[registryOwner] = controls
					component.TenacityOrder = #controls + 1
					table.insert(controls, component)
				end
			end
			return component
		end)
	end
end
tenacity:LoadGUI()

-- Tenacity ClickGUI / SideGUI adaptation. Kept in this file so existing loaders
-- need no additional download. The Java cloud API is deliberately not emulated.
run(function()
	local ui = {Mode = 'Dropdown', Selected = 'Combat', Panels = {}, Tabs = {}, Page = 'Configs', Local = true}
	tenacity.Tenacity = ui
	local statePath = 'tenacity/profiles/tenacity-ui.json'
	local state = loadJson(statePath) or {}
	local tenacityFont=Font.fromEnum(Enum.Font.Gotham)
	uipallet.FontSemiBold=Font.fromEnum(Enum.Font.GothamBold)
	local iconFont
	local dark, raised, muted = Color3.fromRGB(20, 20, 20), Color3.fromRGB(35, 35, 35), Color3.fromRGB(165, 165, 175)
	local function create(class, parent, properties)
		local object = Instance.new(class)
		object.Name = 'Tenacity'..class
		if object:IsA('GuiObject') then object.BorderSizePixel = 0; object.ZIndex = parent.ZIndex + 1 end
		if object:IsA('TextLabel') or object:IsA('TextButton') or object:IsA('TextBox') then
			object.FontFace = tenacityFont
			object.TextSize = 14
			object.TextColor3 = uipallet.Text
			object.BackgroundTransparency = 1
		end
		for key, value in properties do object[key] = value end
		object.Parent = parent
		return object
	end
	local function label(parent, text, x, y, w, h, size)
		return create('TextLabel', parent, {Text = text, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), TextSize = size or 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
	end
	local function button(parent, text, x, y, w, action)
		local b = create('TextButton', parent, {Text = text, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 30), BackgroundTransparency = 0, BackgroundColor3 = raised, AutoButtonColor = false})
		addCorner(b, UDim.new(0, 5))
		b.MouseEnter:Connect(function() tween:Tween(b, uiMotionFast, {BackgroundColor3 = Color3.fromRGB(52, 52, 58)}) end)
		b.MouseLeave:Connect(function() tween:Tween(b, uiMotionFast, {BackgroundColor3 = raised}) end)
		b.Activated:Connect(action)
		return b
	end
	local function field(parent, placeholder, x, y, w)
		local b = create('TextBox', parent, {Text = '', PlaceholderText = placeholder, PlaceholderColor3 = muted, ClearTextOnFocus = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 30), BackgroundTransparency = 0, BackgroundColor3 = raised})
		addCorner(b, UDim.new(0, 5))
		return b
	end
	local function scroll(parent, x, y, w, h)
		return create('ScrollingFrame', parent, {BackgroundColor3 = dark, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = muted})
	end
	local function accent(object)
		tenacity:ApplyThemeGradient(object, 'BackgroundColor3', 0, true, 0)
	end
	local function persist()
		state.Mode, state.Selected = ui.Mode, ui.Selected
		state.CompactCards = ui.CompactCards
		state.Initialized = ui.Initialized
		state.Positions = {}
		for name,panel in ui.Panels or {} do state.Positions[name] = {X=panel.Object.Position.X.Offset,Y=panel.Object.Position.Y.Offset} end
		local ok, err = pcall(writefile, statePath, httpService:JSONEncode(state))
		if not ok then tenacity:CreateNotification('Tenacity', 'Could not save layout: '..tostring(err), 4, 'alert') end
	end

	-- Original Greycliff CF faces and glyphs from the supplied Java assets.
	local embeddedAssets = {
		['combat.png'] = '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',
		['movement.png'] = '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',
		['render.png'] = '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',
		['player.png'] = 'iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAFcUlEQVR4nO3dW4hVVRzH8e/fKVGzjC6UClkalZmQlqhUL13IMoogkkDyLaI3CSToQnQhsnwJeqggCKIIwiyaHuyi2BXNgqALWhkjo+YlMoeybPzFgm2FDTRznLP3+u/1/zzOMGefff6/WXufddsQQgghhBBCCCGEEEIIIYQQQmgnoxCSpgBXAVcAM4FzgEnAeOAgMAD0Ad8BG4ENZra56fcdjoGkMZJukfSupEGN3A+SHpF0ZhTCGUmLJH2t0XFQ0ipJJzV9XuF/pCJJekndsUPSlVGETEmaKWmrumtQ0oqmzzUcRdICSftUn1VRhExImitpv+r3YNPnXjxJZ0nareYs8VwE1/0Ako4H3gfmN/g2DgBzzCz1H7gzBt9WNFz85ETgaZwyz00/8E3Vk5eDG8ysF2c8twD3ZFT85H4cctkCSDoZ2AmMIy9zzexzHPHaAtyaYfGTpTjjNQA3kqfrccY8jvABP1VDuTmabGa7cMJjC3B2xsVPZuOIxwDMIG/n44jHAJxG3s7AEY8BOIG8TcIRjwEQeRvAEY8B+I287cMRjwHI/SvWVhzxGIDch12/xBF3HUGJpD2ZfhvYYWZTccRjC5B8QJ7W4ozXAKwhTy/ijNdLQFqg0Q9MJB/fpl5AMzuMIy5bADP7BXiOvDzmrfhuW4BE0mRgSyatwBfAJWb2J864bAESM0szgnKYl38YuNNj8d2T1CNpnZr1QNOfQ9HSpUDS9oaK/1o1QSVksCh0b83FXy8px3mJZZI0W1J/TcXvlTSh6XMOR5E0TdKmLhf/KUnHxYefKUljJa2UdKgLm0Pc3PT5hWGSNEvSGkmHj7HwByQ9HtvDOCXpgqqA20ZY+M2Slks6hRZz2xPYCUnTgQXAecA0II0pjKu2ifsZ2AZ8lZacm1kacg4hhBBCaCUXN4GS0jy7a4CF1dKr6dUNXBoK7slkqvoBYE81RJ0mhq4HPjSzdIOZrWwDUPWz3wbcUd25e/Qr8ArwrJl90vSbcUGSSVomqU/t0ps6p8iMZbil+wvA1bTTIeBe4Ekzy2KJWzYBkJSu729kOt9/tKXzXJLD/UEWAZCUtlZ5NbNdv7ptA7DYzAaKDoCky4G3M930qdvSvoI3mdkgDWl0OpOkGVVzWGLxk8XASkpsAdK4PfBRmk5N2QQsMrO1pbUAD0Xx//4nfF7SxGICIOki4O4mjp2pqcB9xVwCJL1TPcIt/OMP4Fwz206bW4Dqrj+K/19jm2gVa28BJL0FXFf3cR2NHUwxs/2tbAGqPf6vrfOYzkxIPYRtvgTc3nTfgwNLW3sJkJSeyTuvzmM6NJjGQ8wsTVLtutr+GyWdDlxa1/Ec6wFqezppnc3xwhzGHpyY38YAlN7lOxJzaGEALqzxWN7NbGMA0lfAMDxp04uetgXA1Q6aDeup67kDY2p+wmbI7LkIdQYgdtQYmfFtC0DsqjEy6cHYXeehKLuBZ4C+NH8uPaOXvH0MvFxNc1uebug6fJ1a+kxq65hJKyM6+LM0bXqWmX1fvUa6OdpU5/fkEUqrfy47smWspNTtnbq/OzHPzD6ly3IfmNl4pPhJNXt2Nfla/e/9gs0shfUzMpZ7ANKCy6Ptxdf73UnGcg9A6LIIQOEiAIWLABQuAlC4CEDhIgCFiwAULgJQuAhA4SIAhYsAFC4CULgIQOEiAIWLABQuAlC4CEDhIgCFiwAULgJQuAhA4SIAhcs9AEOtJsriSRs1vF+1LQC7OviboRZV/Ei+tgzxsz0dFr+TzyvrxaHLgLuqR70N5wPYATw8xO/eBJ4ALs6oBTsEvGdm64b43aPVWv9Th/lavwOvm1n/KL/HEEIIIYQQQgghhBBCCCGEEEJR/gJxy+RPGJUpUwAAAABJRU5ErkJggg==',
		['exploit.png'] = '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',
		['misc.png'] = 'iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAEBUlEQVR4nO3dz4tVZRzH8c9XKxoCI4oCF22iySDsJ6VGWVINFaFBiyCIdpG1Cjf+A+XGhYvITRThph9UYliJNFSkYtMv3Jm2aGEZVhTVyDTjJ544hpb3ztxznss895z3a3nPeT6c4XnuOec+Z77nkQAAAAAAAAAAAAAAAAAAAAAAAAAAwCiJ3IG2l0naKGmDpHFJl5yxeVbSj5L2SXo5InbXyH9Q0hOS1ki6XNJ5aq85SSckHZS0Q9IbEWGVyvZa28e9cLuqAbOQ7GW233W3fWw7DfryzgC275K0R9L5AzZNo3ttRJzsk32hpI8k3dr8SEfeYUmrIuKXHGFLcoRU3+LXa3S+qk59fp59ttD5/0qX1e0q6Qxge7Ok5xpEzEi6MiKOnyP7CknfSbqg2VG2zsqIOFTEGUDSww3bp869v8e2dNNH5//femWwJONpaVgZObLbaLykAZBu0poaG2J2G42VNACODTEjR3YbHStpAEwOMSNHdhtNlvQr4CZJUw3yDkTE6j75ByTdVv8IW+dbSSsi4q8izgAR8YWkbTWb/ynpqXn2Sduna+a3cXr4yRydn/MSkGyS9OqAbX6X9EhEfNVvp4j4Mu1X7d9lM+k5SETsValsP2776Dxz2nO2d9q+ZsDsFVW71L5LTtneW11qy34aeJrtldVv1Yv/c/pKTwMPRsSJBtmXVVPD6cHIUrXXqepp4FREfL/YBwMAAAAAAAAAAABglFAcWjaKQ0+jOPQfFIcu6vexDBSHdtw4xaFIKA7tuPU5QigOHV0Uh3bcWI4QikNHF8WhHTeZI4Ti0NFEcWiHzVEc2l0zFIdSHJoVxaFlozgUAAAAAAAAAAAAZT4NvK7PwpHpVbE/Nci+9IxXxXZh4cipiPhBo8D2Y7aPuL9Z22/ZvnrA7HHbb1ftu/ay6D22b1CpbC+1/dKAf9ivtu9bYP6E7d/cbSdtP1rqyqFbJT1bo+kfkm6PiK/7ZF8v6VNJFzU7ylaYlTQRER+W9F/BN0r6vEHe/ohY0yd/f1outf4Rts5RSdcWs2SMpKcbDqbVtm8514bqczr/bFdJekAZ5BoA6zJk3D3E7DZaV9IAWD7EjBzZbbS8pAHQc+n3AUwPMbuNpksaAOm1JU19M8TsNjpc0gB4p2H7dDf7Xo9tu6vtONtOFTQAXqimLOt6sddUZ/X59gbZbfRmRBwqbSIo3ZV+UGNuPi05e2dE9Lym2U4vQ/hE0s3Nj3TkHUnL6EbEz0WtHFrNTE0MeCZIp/17+3V+lZ223yPpfXXbPkl35Or8Yb4p9BlJG/osHJlm9l6JiF018h9KFbJp8qhDC0d+JmmHpNciwot9UAAAAAAAAAAAAAAAAAAAAAAAAAAAQIvmbzB6bCBcAxPvAAAAAElFTkSuQmCC',
		['scripts.png'] = 'iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAIRklEQVR4nO2de6xdRRXGv69CQRQBlQTEgrx8tBpBECtB4wNRIRDEF0aCiCQqiURINFU0/qMJvklsjKAGwh8qLQQIbwzRmAhoVBQpSC0iVJSHlPIotkDvZyZ3TC713pnZ5+w5Z2bP+iX3n57pnH32/vastWatmQEMwzAMwzAMwzAMwzAMwzAMwzAMwxgmzNm5pNcDWAHg7QB2B7AI9TMDYAOAOwD8EsClJG9DpWQTgKRTAJwPYHsMn98B+AbJ1aiMLAKQ9CYAvwbwPLTFTQA+RnIdKiHXkLyiwYfvONyNBpKOQOMjwL8BvATtsgnA0SR/hUYFMJPbwayATTWIIJcJaP3hO14A4BpJb0WDI4ACH+8P4CHUwRMRh+/NCfewipGgdwEE2AMD+R2Slkq6XXGelPQWtEIrAsBsm90lralVBEOYmZsqJB8G8A4Adyb4BNeWJgITQA+QfNCLYG1tIjAB9ATJB3zOY11NIjAB9AjJf3oR3J0YIk5dBCaAniH5D28O7ok0fWEJIjABZIDkfX4kuLd0EZgAMkHyXi+C9YkimEoCyQSQEZL3eBHcnyCCa6chAhNAZkje7UXgHMTiRGACmAAk/+odQxcqFiUCE8CEIHmXF8FDJYnABDBBSN7pReCmj1NEsCz3NZkAJgzJNQDeCeCRBBFcJmmXnNdjApgCJP8M4EhfXh7iQADnoDZaSgePg6Q3SNoQ+Z6nJe2LTNgIMEVI/gHAUQAeCzRz6yq+gJqwEaAbkg6T9ETgvrnPdkIGbAQoAJK/BfCViEP4thzfvV2OThthT0l93r/r3fKywIKa5S5ngJ4xAYyOs9+TxFVT946ZgDCh8vZJs3OOTk0AYWKp3EmS5VmZAMJcjYFjAgjz9cjqoOoxAcSrek4EsBkDpfkoQLMTLCcDeJGv5nVl3etIbvIicOVahwD4kk/iuK1ubPHrUGYCJV04zzVulfTtKVzLpwL37aoc32kmAHjXAvflLElZYu+SaFoAknYF8LJQEwycpgUAIFRx8xSAv2PgtC6ApYHP/kLSbXUzaFoXwLLAZ24jyAWRNIhIoGoBSFoi6Q5Jj0o6R9L2PY4AawLf+XMALlK4RFKL2+FNPwx0D1vSLdv0fbOkfTr0cX/gOo+bp/2xkh7Zpt1X+/g90woDaxbAuQv0vyGlpt5V2yrMc0JASWcv0G5G0rt7+k0mgMQb9b7Iw7sxoY/DA///KUmLthHLs4H2D0vaa8znbxNBiTdpPwAX9JDGXdohAnC5gI2B9i8F8LOeK4QmQlVOoKQdAKwCEFos4Wrtv9xnBEByC4BPR/pzZudrqIyqBADgOwBcYiY0c3cyyfV9RwCc3Qr++5E+PyfpGFRENQKQ9CEAp0eafYvk1RnnAM6K1AK6uYGLJO2NSqhCAJLcEqkfRZq5rVu/mNifS/3u1XUOwJsCJ8THA//3xQAuHmFOYioULwBJOwJYHSmKdAstTyT5bA9v/2YAf4ts+HBapP/lvpqoeIoXAIDvAXBnD4XsvjulY/2kcgBM8wfOlHQ8CqdoAUj6aMLb9s0Odn/sHEAHf8BxQc6FnYMWgKRXAzgvwe6fPUL3nXMAI/oDrt5glaTFKJRFBdfpXeJ31AzZ/Q93sPt9jwBI9AcOddEJCqVIAXj7uiwh3ne7cnbCRwAvH3cE6OgPfEbSB9AK4ySDJJ2qOCN72JKWB/rdPEp6181QSvp95Jofi9UYNl8UKum1AFZmsvupEcDWrh0m+gNu5Fntp7OLoRgT4BMpFwN4fia736v9H9EfOLi0fEExAgCwX+TtdJw7it3vOwKI+AO/QZhjURAlCcC9QX+MtHG1+q8Y83uyjABz5i3csbkhLkVBFCMAb3vdOrwnA812G2eeXdLOfUYAc5H0KgA/QJjYVjDtCmDOdqqfjDQ7zG+lMurwv1A175aEkz7mRZLzW1b7vXwWYqP3X55BQRQlAAfJnyRk/j474jx7yP7fNUoEMCdf8bpIm1NIFrfQpDgBeM4A4HbT7HuevXf7r1m7/4kE5/UKFEiRAiD5HwAfjPgDu3p/YPG0IgCl2/3Po1CKFEAHf+CNLhs4jRFAFdv9KgTQwR84Q9IJsb4kuQe1pMcRYGWtdr/oXMA8fe0o6U+RPjfG/AG/HetCbOmSA5B0kuJ8t8vv9P3aBhHbQnJzgj+wS0LevZcIQLN1ClXb/WpMwP8guTbBH4jl3ce2/5q1+6sidQrF2/3qBDDHH/hhQt79/RkjgJUJdv/jNdn9agQwZ37gtkibH/vlY72OAJJOAnBqQrx/OSqiKgF08AeeUzAiyQ3Ze486Ami2NN3N9g3C7lcrgA7+gCu+SM0BPJ1w5Pvi2uP9wQggwR94EMCKDvZ/bazAhOTj/u2eGYLdr14AAX/gFwAOInlr3xEASRfXv2eegx+rs/uDEID3B5zH745q3+Tz7EeSfCBXDoCk2xvoIADX+X+6oUa7P5fqNjSYC8l1vkJoUWQip7ccAMl/AXiv2zWEZOi0ryqoWgAOkm6NwIIP30cA+/RdBcQBPPyqTUAHXhOIAJ4B4E72bpYWBDBWBDB0WhDAklxVwEOgBQHcGIjfb0XjVO8ExiDpdhM9wp/WfYD/W+Lf/vPROIMXgIPkzQDcn9GgCTACmAAaxwTQOCaAxjEBNM40ooCdfI2+8f/s0IIARlqBa9RlAgZ/2tYUmKlJAF22bTXSeBQVCeCaTP22zE05Os1y9p2v0rk9soLGSMdVIb2SZKgcvpwRwFfIfsRvvW6MP/SfkOPhZ50HIHmlX7//U19JO/iDmHtkq/ejzvNVzrf02blhGIZhGIZhGIZhGIZhGIZhGIZhGC3wXxM5ezQkLkryAAAAAElFTkSuQmCC',
		['settings.png'] = 'iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAItUlEQVR4nO2deaxdVRWHf7uUmVam0iJDGYqSKqPQQVCDFccao0GImmo0KOIfRqIx4Q9TjUQwgKloBCHECGnK5FxoECoGJYiKUKBqygzRCi0oD4Qyfmbn7YfH47vv3nvOOlPv+pKXl/fuPWfvs/c6Z++99m+tIzmO4ziO4ziO4ziO4ziO4ziO4ziO4ziO4ziO4ziO4ziO4ziO4zidJDRVMLCLpDmSZkvaRtKYpMdCCBtrrMPukg5KPwdKmitphqQdJe2Qfm+RtDnz86CkdZI2hBBeVsepzQCAmZKWSnqfpIWSDu7x1fsl/VrStZJ+FkJ4xaj8nSQdI2mRpMXp95wSp4yGcaukNZKuCyGst6jnVgnwFeBphuc+4HRgW4M6PEC1/BE4FdjZptW2EuKj3qDxfwscULIed1APjwOfB7aza8WOE+8K4DvAKyUadgxYVqIOa6mX+4G32bZkxwGOBzaUbNgzStZhJ2A+sBRYDlybjKsKXga+CjQ22W4dwI7AecBLJRr2k8Z12h74AHA58BT2/DRet2WdOw+wAFhfsEGfjXdxRfWaAXyhgknj79Ky08ndeecUbNC1VbYksA3wkTSWW7EOmOUW8P+NHcfJIhxfdWMC2wFnAluMjOAeYC83gv9t5G2BjQUa83t1NSRwKHC3G0F1DXx2gcZ9qIHl7DWGRuDDQaZxP1GwIXep2QimARcbGcHdTRvBNLWHZwseV+t4Gsb3Jk6TdL3B6d4o6VdNGkGbDKDX5lA/tlfNhBCQtNzodI0aQWkDMKz4iQWPe0YNEEK4LW0PWxnB2iaMwOIJ8BtgNbB/0RMAh0g6ocihkjapOTYbnuswSZepa2QmNM9EP310oBQ4x9UFJ1G1rgKyAPskX78lcbNsD3WJ1PFZ/gAcNcTx0QdflCgaqR0gAD+iGhZ0bQiICp4sUXUTjeDcpMLpCRDHvh8Yll0X50v6UEXnntU1A7hnkv/FYeBL8TPgPZMdBCyJs19Ju5Uo+0U14LaWVGpLug+1bhhNNzjHLZI+2uOzKLS8DrhR0hVJULmPpFOSNrAs81QjwOmGy79exPapjdJChTT7f7Ahn0IUZs4NITxeR2GML9PWphl7VVwVQog3SC2U7rQQwiPpUd4EUbp9Xh3uX41fa1xyvl3SXRUW9+46xSNWd+1Fao5lwMeqOjlwnKQ7J/wcIYS49l9SoRHMrGGYqWRZFBUvTREVQsdWcF3HZeTsURiyX+azPZPAoyrOya6igB2AfVurLwTeXFL1ayHHPsz4esZyZdwbHUCZ7+wBxKdDVWwCLgO+m6nLY8DJaiPAigobY9AGK20EwOIplMJR1fzaAY0g/v9k4PXR5wF8PLnNy94o8fgPq6Uav5tp3ggOL3ENiwZQBv8VmJMzgnzgyepek7lkYDHqqQzPAW9V2wB2a3g+UNgIgIVDyML/DMzOHLs78Kf02Q3xZuhT1iyDaKVHi+y91CWdWkWzbB7GCBiXqf9ryDKirH2vnBFcOqhKKU0kyz4JKpHHmxDHKeBhmjWCIwao57EFOj8r69qzRBstKDkneHU+0mbFb9TX/3ySCOEYHXR7mjxGY1kCnAbcQk1GQLnOn2BdmW1c4PqC5a5WB/0F+wHzgLlTPSqT0fwTOyM4cpIyjjEq4y/Z+UCBdjmr4JOnW9qBYQFeZxBMOsETWSMA3mTU+bF+e5dcOf2+a2ri2oiTLENnSzSCo4CjgScNzhe9g/uWvL5hBTGj0/m5peWwd8lURmDR+Q/FYczI3TwooxtMEnMMpUwhbeBR4CDDedEg/gCPKUz+hbozfeT5W5zEWnR+xggOAP5Ob7zzc7tia2iGf0S/fkXXNT95MPN45/cI2Y5ZN+rebXxDxde1P3BlKis+ES4CXlNlmZ0FmJ4aqw6eKLPB5FSbxeOHFXf+k8PEOTg1k2bR36+o85+qQmnkVADwbePOH4v79t5ZHaJEwqnJuGMUsnq1KT+ABS8ZnuvIFPn8qhDUaSkpbcuFVOf1m9/0NTpT6w1W1bAMXOyd0DJS3t81NcYeLG36mp0EsKuxcmgQXrTOU+wUIEqyK47K6ceZ3nENARxooKS1YEVrw7S2VlJ0TdyObQur/M0g9XX+IiMljzU31J2tdOQcQcA7Jd1YMp3MBBemN5JZ8Y74ljPPAF4RwEnA80Z36y/TNnIUldyELfdaycSc/3b+pw1z8cWAzl1zbzO7DVs2ThZ/4BQA+LKxJ29eD7XxXdhvIRfJeupkOuabhh3ywlQdAsw2DD6ZIL5d5CTv0WKbOpcYd8ZnBtTiPWJcbhy6PudGMJzQ0+ptHBOsGKL8Q5Lq15qvuxEMpvePM3RL1gybPAE4vCJfw8WtTOTQBlJSBeuMIjFxw8yC9VlY8EXX/fhJXH7at2CHickNUuCDJZvKrseBE1IOHmtuzi5FRxrg4ArezhkdRm8xqt/StIKwJvoeRvtJkBIkVZE65lPG9TylgCMqGuGPgW+kfEExyifPBRplgPOx59yK6nrqEHW4PT/8JI/jytz3XrAILe8shm/gnOAXEwmdK6rvGQPU4bleySKSfyNuGGWp8p0D7cb48R9duTNqqPPyPvW4ps/x7819f6VGeDv4PqPzxPcEvD+E8LQqJoTwNUnfmuIrG/qcYn3u78Kp5bYGA7jU4BzPS/pgCOFh1UQI4YuSLunxcb8c/3m/xJhGGYP37y5rqN7TesQh3DnkEHKWRpnUkEVDu89uuO7T08RzoI2n5FiKcQVZFmrUSUaQXyIN4lJtXI3LuKposnxFcTfziLS5tXfSNeS9ijc1Xf+2JXm4YoiI3Z3VEhhf499aIOzcYw0neaRePYDcqnWRuoyrigaVlv0beFfTdW6zEVw1xV2zsOXb2Zf36fzo/Dq66bp2Id3LZ1Nq2C1pbz4+GQ5VB2A89fsFaXv7gTRkrUzK5k5I8B3HcRzHcRzHcRzHcRzHcRzHcRzHcRzHcRzHcRzHcRzHcRzH6Q7/Ad0lV5oeLkTKAAAAAElFTkSuQmCC',
		['check.png'] = 'iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAEYElEQVR4nO3dSYgdVRjF8VOaGFFMhKhxAgcciKDgwoWCYgsiQhYKDogabNSAbkQQMQoiuFEwDlGjicaYmNZuJ1y4CCIkILgIARfOinHARFBR4oRj/nLhNgh2utMvVfd7VXV+66brq3u+vq9uvbrVkpmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZtUMVXUDfAKdJOl/SfEmfS9pUVdWu6LqsYcAhwAT/9yMw2vTxLRBwKLCN6d3lkDoImA9snSF8N0GHp/23mZ07o+u2GgAHA28xmOV11GBBgIOAzQOG7yZoM+BA4E3qcUf0+dgsAPOATTWF7yZoE+AA4HWacXv0+dk0gLnAazTr8ulqsCDAHOBlmvcV4Fv3wwTYHxinnDPqPof96v6FfQGksVsv6cqCh11U9y90AwwgT8VrJV2tsr4rfDybKnzgKcrbkWcdiwSsIsZSJx8MWBkU/v3R5957wIqg8B/o/eBHA+4LCn9F9Ln3HnBvUPgP9uFhiXuAD4HfgW/zM3O13+wYFHB3UPgPqcuA43PwU/kDuGYIalxOjF6E/8UMg/BPZBMAtxHjYXXZXoY/6W/gioAabyHGI+qyWYY/6S/g0oI13kyMleoy4IQBwp/0J7CkQI3LgN2U96h6EP6X+zhIaZVwUYM1jjr84Q1/0m/ABQ3UeG2+6CztMXVZzeFP+hU4r8Yar8oXm6U9ri4DFgLbGxq8n4Gza6jxMoffEGANzdoFnLUP9V2SVxilrer8c3352fg0VTftB+DMAepbklcWpT3R+fATYHHBQf0eOH0WtV2cVxSlPTms4TfxiBEqZ6GktA1r8Uw/CFwo6VVJ81TWakk3VVVVclzCd8ikC7WSdgKnTFPTSF5GlrZ6WP/yG5WWOQGD/TVw4hS1nAv8ElDPml6GnwALgI8CBj3dbj7uP3WcEzAbkZ8abkX4jRUJHCtps6STVNZ2SelmUTr+G/ltXCU9LWlZWz7zG+3SwCb4TNJhkhYUPu5aSTe2Jfyk8WkKOEbSloAmKO0ZSTe0Kfyk8Z0mVVXtyC9G/FTdta6N4SdFthrlJhjpaBOsa2v4SdErVeDo/HFwsrrhWUnXV1W1Wy1VdLNhVVU788fBJ2q/9W0PPwlZq+aZIK0O9nj3bshtkDTa9vCTkO3GeSYYaelMsKEr4Sehd6uAo/I1QVtmguckXdeV8JPQFw5UVfVNvib4WMNvY9fCT4bifnWeCdI1wakaTmOSlnYt/KECHBn0BdJMNqa3gUWPT5+aYE+bRiOMOfz+NsGYw49tgg8Cw3/e4fe3CV5w+EMCWFS4CcYdfn+bYNzhD3cTvN9g+BMOv79NMJFe+R59frYXgCNqboIXHX47m+C9GsJ/yeH3twnSf/iYE30eFtMEDr8rgMOBd2cR/iv+y+9vEzj8jjfB1hm+2JkbXac1/2aSW4F38lbwn4AtEW8bNTMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzM1O9/gV7g7iQuM3UzgAAAABJRU5ErkJggg==',
		['search.png'] = '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',
		['tenacity.ttf'] = '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AAAAAAAAAAAAAAAAAAAAAP/Y//X/xP/s/7f/5//hAAD/6QAAAAAAAP/s/8QAAP/Y/83/twAA//UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/N//H/sP/sAAD/wf/LAAD/nP/s/80AAP/1/8QAAAAAAAAAAAAAAAAAAP+wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/+wAAAAA/+EAAP/1/8sAAP/Y/83/1f+//7f/9QAAAAAAAP/1AAD/zf/h/8H/7P/1AAAAAP/s/+z/2P/h/+H/7P/sAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/4f/sAAD/2P/h/+EAAAAAAAAAAAAA/7D/3//N/7n/4QAAAAD/4f/s/7AAAP/EAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/s/+H/zf/1AAD/3//fAAD/zf/YAAD/7P/s//UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/+EAAAAA/+H/4QAA/80AAAAA/+z/+//1AAD/7AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/2AAA/8v/4f/1AAAAAAAAAAAAAAAA/4MAAAAA/63/xP/N/4j/2P/h/80AAP/EAAAAAAAA/8QAAAAAAAAAAP/1/83/t//s/+wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/YAAAAAP/sAAAAAAAAAAAAAP/sAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/zf/hAAAAAAAAAAAAAAAAAAD/pQAA/+z/4f/1/+H/fQAAAAD/nAAA/+EAAAAAAAD/zQAAAAAAAAAA//X/7P/Y/+z/7P/YAAAAAAAAAAAAAAAA/9UAAAAAAAAAAAAAAAAAAAAA/8EAAAAAAAAAAP/p/30AAAAA/7kAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/+IAAAAAAAAAAAAA/80AAP+/AAAAAAAAAAAAAAAAAAAAAP/NAAAAAP/h/8QAAP/hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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AAD//wANAAMADQAXACEAKwAzAD0ARwBRAFsAZQBvAHkAAP//AA0ABAAOABgAIgAsADQAPgBIAFIAXABmAHAAegAA//8ADQAFAA8AGQAjAC0ANQA/AEkAUwBdAGcAcQB7AAD//wANAAYAEAAaACQALgA2AEAASgBUAF4AaAByAHwAAP//AA0ABwARABsAJQAvADcAQQBLAFUAXwBpAHMAfQAA//8ADQAIABIAHAAmADAAOABCAEwAVgBgAGoAdAB+AAD//wANAAkAEwAdACcAMQA5AEMATQBXAGEAawB1AH8AgGFhbHQDAmFhbHQDCmFhbHQDEmFhbHQDGmFhbHQDImFhbHQDKmFhbHQDMmFhbHQDOmFhbHQDQmFhbHQDSmNhbHQDUmNhbHQDWGNhbHQDXmNhbHQDZGNhbHQDamNhbHQDcGNhbHQDdmNhbHQDfGNhbHQDgmNhbHQDiGRub20DjmRub20DlGRub20DmmRub20DoGRub20DpmRub20DrGRub20DsmRub20DuGRub20DvmRub20DxGZyYWMDymZyYWMD1GZyYWMD3mZyYWMD6GZyYWMD8mZyYWMD/GZyYWMEBmZyYWMEEGZyYWMEGmZyYWMEJGxpZ2EELmxpZ2EENGxpZ2EEOmxpZ2EEQGxpZ2EERmxpZ2EETGxpZ2EEUmxpZ2EEWGxpZ2EEXmxpZ2EEZGxvY2wEamxvY2wEcGxvY2wEdmxvY2wEfGxvY2wEgmxvY2wEiGxvY2wEjmxvY2wElG51bXIEmm51bXIEoG51bXIEpm51bXIErG51bXIEsm51bXIEuG51bXIEvm51bXIExG51bXIEym51bXIE0G9yZG4E1m9yZG4E3G9yZG4E4m9yZG4E6G9yZG4E7m9yZG4E9G9yZG4E+m9yZG4FAG9yZG4FBm9yZG4FDHBudW0FEnBudW0FGHBudW0FHnBudW0FJHBudW0FKnBudW0FMHBudW0FNnBudW0FPHBudW0FQnBudW0FSHNhbHQFTnNhbHQFVHNhbHQFWnNhbHQFYHNhbHQFZnNhbHQFbHNhbHQFcnNhbHQFeHNhbHQFfnNhbHQFhHNzMDEFinNzMDEFkHNzMDEFlnNzMDEFnHNzMDEFonNzMDEFqHNzMDEFrnNzMDEFtHNzMDEFunNzMDEFwHN1cHMFxnN1cHMFzHN1cHMF0nN1cHMF2HN1cHMF3nN1cHMF5HN1cHMF6nN1cHMF8HN1cHMF9nN1cHMF/HRudW0GAnRudW0GCHRudW0GDnRudW0GFHRudW0GGnRudW0GIHRudW0GJnRudW0GLHRudW0GMnRudW0GOAAAAAIAAAABAAAAAgAAAAEAAAACAAAAAQAAAAIAAAABAAAAAgAAAAEAAAACAAAAAQAAAAIAAAABAAAAAgAAAAEAAAACAAAAAQAAAAIAAAABAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAwANAA4ADwAAAAMADQAOAA8AAAADAA0ADgAPAAAAAwANAA4ADwAAAAMADQAOAA8AAAADAA0ADgAPAAAAAwANAA4ADwAAAAMADQAOAA8AAAADAA0ADgAPAAAAAwANAA4ADwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEACQAAAAEAAgAAAAEACAAAAAEABQAAAAEABAAAAAEAAwAAAAEABgAAAAEABwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEAEgAAAAEAEgAAAAEAEgAAAAEAEgAAAAEAEgAAAAEAEgAA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AgwAMQIMADECDAAxAgwAMQI3ACICNwAiAjcAIgI3ACICNwAiAjcAIgI3ACICNwAiAjcAIgI3ACICNwAiA7kAIgJBADECRwAxAkEAIgFKADEBSgAxAUoAFAFKACgBowAcAaMAHAGjABwBowAcAaMAHAJDADsBPgAdAT4AHQF/AB0BPgAdAT4AHQIHACwCBwAsAgcALAIHACwCBwAsAgcALAIHACwCBwAsAgcALAIHACwCBwAsAgYAGQNnABkDZwAZA2cAGQNnABkDZwAZAd8AHwIHABkCBwAZAgcAGQIHABkCBwAZAcoAHQHKAB0BygAdAcoAHQFiAB0BTAAdAhMAHQIdAB0BrAAiAbAAIgKBABkCFwA7AjwAOwHWADsB1gA7AdYAOwLgAB4B6gA7AeoAOwPMABkCBAAjAoYAOwKGADsCUAA7AqYACwM8ADsCZwA7AxoAJwJnADsCFwA7Ap8AJwIDACcCfQAiA0wAIgJWACICRAAeAowAOwP7ADsEIAA7AhcAOwJgAA8DEwA7Ap8AJwKfACcA0wA7ANP/2APbADsCKQAnAkEAIgJBADECDgAxAZUAMQGVADEBlQAxAqQAHgIcACICHAAiA1cAGAGVACMCLAAxAiwAMQIKADECWAAFAr4AMQIqADECNwAiAioAMQJBADEB+AAiAbYAIgIHABkDxgAiAd8AHwIdACICSQAxArAAMQLVADECEQAxAiwAFALbADEB+AAiAfgAIgC8/8wC6AAxAhEAIgKBABcDGwAnAgcALAJ4AC4CWgAiAQsAIgH5ACcB/wAjAf4AHwIGACcCAAAdAdsAIgITACcCAQAfAsYAWALGARACxgCJAsYAhwLGAIUCxgCCAsYAfALGAJkCxgCBAsYAfgHIAEsBuQALALgAIwEHADcAswAjALQAIwKhACMA8gBCALgAQgIwADcAswAjAesAGQHrACMBEQAiAJYAIgC0ACMBuQAJAlgAMgEyADIBGAAYARkAMgEZADIBIgAyASIAMgKeADICYgAyAYYALQGGAC0BXwAjAV8AIwDGACMAxgAjATEAHgE3AB4BNwAeAKoAHgCqAB4AqgAeAfgAIgI5ADcCDwAjAsIAHgFE/+wCUgAjAhsAMgJEACIBqQA3Ab0ANwF1ADcBvQA3Ab0ANwG9ADcB+wA8AecAMgHBADoBvAA2Ab0ANwHCADIBwgAxAe8AMgMYACcBdAAdAqEAMgKaADICrwAyAgcALAIAAB0CxAAoBCMAKAISADQDHgAnAoUAJwLGACcCiAAjAosAJwKLACcCFgA3AYkAMgDTADsA0wA7AakANwGpADcCNwAxAAD/jQCXAAMBKAAGASEABgCwAAUBIQAGAS4ABQBuAAUArgAcAUkABQFAAAUAxAAFALUABQFKAAUAgP9RAioAIQJDACECVQAeAjYAIQJIAB4CSgAeAjYAIAEOAB4AfAAeAOcAHgDzABwBAAAeAPUAHgDpAB4A6QAeAPMAHgDqAB4BDgAeAHwAHgDnAB4A8wAcAQAAHgD1AB4A6QAeAOkAHgDzAB4A6gAeAJMAIgD5ACcA/QAjAAAAbgBuALIAxADWAOgA+gEMAR4BMAGmAbgBygI2Ao4C5gL4AwoD4gP0BDgEnASuBLYFBgUYBSoFPAVOBWAFcgWEBfQGOgaeBrAGvAbOBxoHdAecB6gHugfMB94H8AgCCBQIJghoCLIIvgjyCQQJFgkiCTQJoAnuCjIKRApWCmIK4AryCzoLTAteC3ALgguUC64LwAw4DMgM2g4ADkwOmg8KD1wPbg+AD4wP+hAMEB4Q3hDqESQRgBGSEZ4RqhHsEf4SEBIiEjQSRhJYEnIShBLwEwITNhOKE5wTrhPAE9IUIBReFHAUghSUFKYU7BT+FRAVIhW6FcwV3hXwFgIWDhYgFjIXIBcsFz4YeBj0GVYZYhluGiIaLhqoG1IbZBwCHGIcdByGHJgcpBywHMIc1B1sHcgeYB5yH1gfZB+2ICggaiCSIKQgtiDIINQg4CDyIP4hECGEIdIiBiJQIlwihCKWIqgitCLGIv4jgCPiI/QkBiQSJIIklCTcJO4lACUSJR4lMCVKJVwlziZGJlgnFieUKAYojikCKRQpJikyKZ4psCnCKoIqjir2K0IrsCvCLHYsiCzmLPgtCi0cLS4tOi1MLWYteC4YLiQuWC6qLrwuzi7aLuwvNi9uL4Avki+eL7Av9jAIMBowJjCEMQQxEDEcMYYxxjHOMiIyKjJeMnAywDMcM2wzfjPqNGA0ojUUNRw1dDV8NYQ1jDXINdA12DXgNh42kDaYNug3Mjd+N9g4Ijh2OII47jleOWY5eDogOnA6eDsiO3Y7qju8PAw8ZjzGPNg9Oj2uPfA+Aj5GPpw+6j80Pzw/eD+AP4g/wj/KQIBAiEDUQSBBakHCQgZCUkJeQsxDOkNGQ9ZEJkRMRIJExEUCRURFdkXORkhGlkcKR3hHrEgWSIRIjEiWSJ5IpkiuSLZIvkjGSM5I1kkSSUxJckmYSapJ6kn6SjpKfEsMSy5LmEv+TApMMkxETHRMok0STYhN1E4kTmROqE7UTwBPLE80T4hP3FAQUERQUFCwUMhRCFFIUVBRxlIqUrZTVFPCVHJU+FV0VcBV4FYuVp5W5lcyV2hXplfmWCZYOFhOWKhY7lk2WWpZllnWWgRaDFpOWvRbzlwCXNxdZF3KXl5fEl+oX/BgOGBgYKZgtmDMYQRhTmF8Ybhh8mJaYpJi0GL6Yy5jOmNqY6Zj6GRCZFhkaGR4ZIhkmGSoZLhkyGUIZSJlZGW8ZeZmLGZsZoZm6mcuZz5nWmewaCRoNGiQaKBovGjMaNxo5GjsaPQAAQAAAd0AXwAKAFcABQACACQANQCLAAAAig0WAAMAAQAAABgBJgABAAAAAAAAABQAAAABAAAAAAABAAwAFAABAAAAAAACAAYAIAABAAAAAAADAB0AJgABAAAAAAAEABMAQwABAAAAAAAFAA0AVgABAAAAAAAGABIAYwABAAAAAAAIAA0AdQABAAAAAAAJAA0AggABAAAAAAALAAsAjwABAAAAAAAMAAsAmgADAAEECQAAACgApQADAAEECQABACYAzQADAAEECQACAA4A8wADAAEECQADADoBAQADAAEECQAEACQBOwADAAEECQAFABoBXwADAAEECQAGACQBeQADAAEECQAIABoBnQADAAEECQAJABoBtwADAAEECQALABYB0QADAAEECQAMABYB5wADAAEECQAQABgB/QADAAEECQARAAwCFakgMjAxNiBDb25uYXJ5IEZhZ2VuR3JleWNsaWZmIENGTWVkaXVtMS4xMDA7VUtXTjtHcmV5Y2xpZmZDRi1NZWRpdW1HcmV5Y2xpZmYgQ0YgTWVkaXVtVmVyc2lvbiAxLjEwMEdyZXljbGlmZkNGLU1lZGl1bUNvbm5hcnkgRmFnZW5Db25uYXJ5IEZhZ2VuY29ubmFyeS5jb21jb25uYXJ5LmNvbQCpACAAMgAwADEANgAgAEMAbwBuAG4AYQByAHkAIABGAGEAZwBlAG4ARwByAGUAeQBjAGwAaQBmAGYAIABDAEYAIABNAGUAZABpAHUAbQBSAGUAZwB1AGwAYQByADEALgAxADAAMAA7AFUASwBXAE4AOwBHAHIAZQB5AGMAbABpAGYAZgBDAEYALQBNAGUAZABpAHUAbQBHAHIAZQB5AGMAbABpAGYAZgBDAEYALQBNAGUAZABpAHUAbQBWAGUAcgBzAGkAbwBuACAAMQAuADEAMAAwAEcAcgBlAHkAYwBsAGkAZgBmAEMARgAtAE0AZQBkAGkAdQBtAEMAbwBuAG4AYQByAHkAIABGAGEAZwBlAG4AQwBvAG4AbgBhAHIAeQAgAEYAYQBnAGUAbgBjAG8AbgBuAGEAcgB5AC4AYwBvAG0AYwBvAG4AbgBhAHIAeQAuAGMAbwBtAEcAcgBlAHkAYwBsAGkAZgBmACAAQwBGAE0AZQBkAGkAdQBtAAACAAAAAAAA/7UAMgAAAAAAAAAAAAAAAAAAAAAAAAAAAd0AAAADACQAyQECAQMAxwBiAK0BBAEFAGMArgCQACUAJgD9AP8AZAEGACcA6QEHAQgAKABlAQkAyADKAQoAywELAQwAKQAqAPgBDQEOACsBDwAsARAAzAERAM0AzgD6AM8BEgAtAC4BEwAvARQBFQEWARcA4gAwADEBGAEZARoBGwBmADIA0AEcANEAZwDTAR0BHgEfAJEArwCwADMA7QA0ADUBIAEhASIANgEjAOQA+wEkADcBJQEmAScBKAA4ANQBKQEqANUAaADWASsBLAEtAS4AOQA6AS8BMAExATIAOwA8AOsBMwC7ATQAPQE1AOYBNgBEAGkBNwE4AGsAbABqATkBOgBuAG0AoABFAEYA/gEAAG8BOwBHAOoBPAEBAEgAcAE9AHIAcwE+AHEBPwFAAEkASgD5AUEBQgBLAUMATADXAHQBRAB2AHcBRQB1AUYBRwFIAE0BSQBOAUoATwFLAUwBTQFOAOMAUABRAU8BUAFRAVIAeABSAHkBUwB7AHwAegFUAVUBVgChAH0AsQBTAO4AVABVAVcBWAFZAFYBWgDlAPwBWwCJAFcBXAFdAV4BXwBYAH4BYAFhAIAAgQB/AWIBYwFkAWUAWQBaAWYBZwFoAWkAWwBcAOwBagC6AWsAXQFsAOcBbQFuAW8AwADBAJ0AngFwAXEBcgFzAXQBdQF2AXcBeAF5AXoBewF8AX0BfgF/AYABgQGCAYMBhAGFAYYBhwGIAYkBigGLAYwBjQGOAY8BkAGRAZIBkwGUAZUBlgGXAZgBmQGaAZsBnAGdAZ4BnwGgAaEBogGjAaQBpQGmAacBqAGpAaoBqwGsAa0BrgGvAbABsQGyAbMBtAG1AbYBtwG4AbkBugG7AbwBvQCbABMAFAAVABYAFwAYABkAGgAbABwBvgG/AcABwQHCAcMBxAHFAcYBxwANAD8AwwCHAB0ADwCrAAQAowAGABEAIgCiAAUACgAeABIAQgBeAGAAPgBAAAsADACzALIAEAHIAKkAqgC+AL8AxQC0ALUAtgC3AMQAhAC9AAcByQCmAcoAhQCWAA4A7wDwALgAIACPACEAHwCVAJQAkwCnAGEApACSAJwAmgCZAKUBywCYAAgAxgC5ACMACQCIAIYAiwCKAIwAgwBfAOgAggDCAEEBzACNANsA4QDeANgAjgDcAEMA3wDaAOAA3QDZALwA9AD1APYBzQHOAc8B0AHRAdIB0wHUAdUB1gHXAdgB2QHaAdsB3AHdAd4B3wHgAeEB4gHjAeQB5QHmAecGQWJyZXZlB3VuaTAxQ0QHQW1hY3JvbgdBb2dvbmVrCkNkb3RhY2NlbnQGRGNhcm9uBkRjcm9hdAZFY2Fyb24KRWRvdGFjY2VudAdFbWFjcm9uB0VvZ29uZWsMR2NvbW1hYWNjZW50Ckdkb3RhY2NlbnQESGJhcgJJSgd1bmkwMUNGB0ltYWNyb24MS2NvbW1hYWNjZW50BkxhY3V0ZQZMY2Fyb24MTGNvbW1hYWNjZW50BExkb3QGTmFjdXRlBk5jYXJvbgxOY29tbWFhY2NlbnQDRW5nB3VuaTAxRDENT2h1bmdhcnVtbGF1dAdPbWFjcm9uB3VuaTAxRUEGUmFjdXRlBlJjYXJvbgxSY29tbWFhY2NlbnQGU2FjdXRlDFNjb21tYWFjY2VudARUYmFyBlRjYXJvbgd1bmkwMTYyB3VuaTAyMUEGVWJyZXZlB3VuaTAxRDMNVWh1bmdhcnVtbGF1dAdVbWFjcm9uB1VvZ29uZWsFVXJpbmcGV2FjdXRlC1djaXJjdW1mbGV4CVdkaWVyZXNpcwZXZ3JhdmULWWNpcmN1bWZsZXgGWWdyYXZlBlphY3V0ZQpaZG90YWNjZW50BmFicmV2ZQd1bmkwMUNFB2FtYWNyb24HYW9nb25lawpjZG90YWNjZW50BmRjYXJvbgZlY2Fyb24KZWRvdGFjY2VudAdlbWFjcm9uB2VvZ29uZWsMZ2NvbW1hYWNjZW50Cmdkb3RhY2NlbnQEaGJhcgd1bmkwMUQwCWkubG9jbFRSSwJpagdpbWFjcm9uB2lvZ29uZWsHdW5pMDIzNwxrY29tbWFhY2NlbnQGbGFjdXRlBmxjYXJvbgxsY29tbWFhY2NlbnQEbGRvdAZuYWN1dGUGbmNhcm9uDG5jb21tYWFjY2VudANlbmcHdW5pMDFEMg1vaHVuZ2FydW1sYXV0B29tYWNyb24HdW5pMDFFQgZyYWN1dGUGcmNhcm9uDHJjb21tYWFjY2VudAZzYWN1dGUMc2NvbW1hYWNjZW50BHRiYXIGdGNhcm9uB3VuaTAxNjMHdW5pMDIxQgZ1YnJldmUHdW5pMDFENA11aHVuZ2FydW1sYXV0B3VtYWNyb24HdW9nb25lawV1cmluZwZ3YWN1dGULd2NpcmN1bWZsZXgJd2RpZXJlc2lzBndncmF2ZQt5Y2lyY3VtZmxleAZ5Z3JhdmUGemFjdXRlCnpkb3RhY2NlbnQFZi5hbHQGdC5zczAxB3VuaTA0MTAHdW5pMDQxMQd1bmkwNDEyB3VuaTA0MTMHdW5pMDQwMwd1bmkwNDkwB3VuaTA0MTQHdW5pMDQxNQd1bmkwNDAxB3VuaTA0MTYHdW5pMDQxNwd1bmkwNDE4B3VuaTA0MTkHdW5pMDQxQQd1bmkwNDFCB3VuaTA0MUMHdW5pMDQxRAd1bmkwNDFFB3VuaTA0MUYHdW5pMDQyMAd1bmkwNDIxB3VuaTA0MjIHdW5pMDQyMwd1bmkwNDI0B3VuaTA0MjUHdW5pMDQyNwd1bmkwNDI2B3VuaTA0MjgHdW5pMDQyOQd1bmkwNDJDB3VuaTA0MkEHdW5pMDQyQgd1bmkwNDA0B3VuaTA0MkQHdW5pMDQwNgd1bmkwNDA3B3VuaTA0MkUHdW5pMDQyRgd1bmkwNDMwB3VuaTA0MzEHdW5pMDQzMgd1bmkwNDMzB3VuaTA0NTMHdW5pMDQ5MQd1bmkwNDM0B3VuaTA0MzUHdW5pMDQ1MQd1bmkwNDM2B3VuaTA0MzcHdW5pMDQzOAd1bmkwNDM5B3VuaTA0M0EHdW5pMDQzQgd1bmkwNDNDB3VuaTA0M0QHdW5pMDQzRQd1bmkwNDNGB3VuaTA0NDAHdW5pMDQ0MQd1bmkwNDQyB3VuaTA0NDMHdW5pMDQ0NAd1bmkwNDQ1B3VuaTA0NDcHdW5pMDQ0Ngd1bmkwNDQ4B3VuaTA0NDkHdW5pMDQ0Qwd1bmkwNDRBB3VuaTA0NEIHdW5pMDQ1NAd1bmkwNDREB3VuaTA0NTcHdW5pMDQ0RQd1bmkwNDRGB3VuaTAzOTQHdW5pMDNBOQd1bmkwM0JDB3plcm8udGYGb25lLnRmBnR3by50Zgh0aHJlZS50Zgdmb3VyLnRmB2ZpdmUudGYGc2l4LnRmCHNldmVuLnRmCGVpZ2h0LnRmB25pbmUudGYHdW5pMDBBRARFdXJvB3VuaTIwQjQHdW5pMDBCNQd1bmkwMzI2CW9uZWVpZ2h0aAx0aHJlZWVpZ2h0aHMLZml2ZWVpZ2h0aHMMc2V2ZW5laWdodGhzCXplcm8uZG5vbQhvbmUuZG5vbQh0d28uZG5vbQp0aHJlZS5kbm9tCWZvdXIuZG5vbQlmaXZlLmRub20Ic2l4LmRub20Kc2V2ZW4uZG5vbQplaWdodC5kbm9tCW5pbmUuZG5vbQl6ZXJvLm51bXIIb25lLm51bXIIdHdvLm51bXIKdGhyZWUubnVtcglmb3VyLm51bXIJZml2ZS5udW1yCHNpeC5udW1yCnNldmVuLm51bXIKZWlnaHQubnVtcgluaW5lLm51bXIHdW5pMDBCOQd1bmkwMEIyB3VuaTAwQjMAAAEAAf//AA8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABWAFYAUgBSArwAAAHqAAD/QgPy/0ICxP/zAfD/+P9CA/L/QgBWAFYAUgBSArwAAALaAeoAAP9CA/L/QgLE//MC2gH1//P/QgPy/0IAVgBWAFIAUgK8AbgC2gHqAAD/QgPy/0ICxP/zAtoB9f/z/0ID8v9CsAAsILAAVVhFWSAgS7gADlFLsAZTWliwNBuwKFlgZiCKVViwAiVhuQgACABjYyNiGyEhsABZsABDI0SyAAEAQ2BCLbABLLAgYGYtsAIsIGQgsMBQsAQmWrIoAQpDRWNFsAZFWCGwAyVZUltYISMhG4pYILBQUFghsEBZGyCwOFBYIbA4WVkgsQEKQ0VjRWFksChQWCGxAQpDRWNFILAwUFghsDBZGyCwwFBYIGYgiophILAKUFhgGyCwIFBYIbAKYBsgsDZQWCGwNmAb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',
		['tenacity-bold.ttf'] = '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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/sP/YAAAAAAAAAAAAAAAAAAD/kQAA/83/xP+6AAD/iP/NAAD/sP/N/80AAP/N/+EAAAAAAAAAAAAA/+H/xP+w/+z/xAAA/80AAAAAAAAAAAAA/+EAAAAAAAAAAAAAAAAAAAAA/9gAAAAAAAD/7AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIKAgAEAAAP/hDCAA0AHQAA/+z/8f/h//v/9f/hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/80AH//s/+z/2P/s/+wAFP/NABQAH//Y/9gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/NAAAAAP/1AAAAAAAAAAD/9QAAAAAAAAAA//UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/+wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/s/+EAAAAAAAAAAAAAAAD/7AAAAAAAAP/NAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/4f/7/8T/9f/Y/84AAAAA/+z/2P+5/84AAP/7//X/g//h/+z/4f/Y/+z/9f/s/+z/zgAAAAAAAAAAAAD/6wAAAAsAAAAAAAAAAAAA/9gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/9gAAAAAAAAAAAAAAAP/s/+wAAAAAAAAAAP/2AAD/4QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/1/+wAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/2AAAAAAAAP/1AAAAAAAA/5wAAAAAAAAAAP/sAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/84AAP/1//UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/tAAAAAAAAAAAAAAAAAAD/4gAAAAAAAP/1AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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AQEBAwBkAQcBBwBnAQsBCwBoAQ0BEABpARIBEgBtARoBGwBuAR4BHgBwAAIADwCEAJgAAACdAKYAFQCpAKkAHwCsAK8AIACxALUAJAC6AMgAKQDKANgAOADkAPcARwEhASEAWwEnAScAXAExATEAXQEzATQAXgE3ATgAYAFBAUEAYgFDAUMAYwABABEBaQFqAWsBbQFxAXIBcwF0AXcBeQF6AXwBfQF+AYABgQGCAAEAAQGkAAEAAQFQAAEAEQFJAUoBTgFPAVABUQFSAWEBYgFnAX4BvgHQAdEB0gHTAdQAAQADAWIBZwFoAAEAAQGwAAIACwD6APsAAAD9AQIAAgEFAQYACAEIAQ8ACgERAREAEgEUASAAEwEnASgAIAExATEAIgEzATMAIwE2ATcAJAFDAUMAJgABAAEBRwACAAwAAgANAAAADwAwAAwANABoAC4AagBuAGMAcACFAGgAiwCXAH4AmQCeAIsArADSAJEA1ADjALgA5QDpAMgA6wDzAM0A9QD1ANYAAgAGAP0A/wAEAQABAAADAREBEQABARQBFAADARYBFgADARcBGAACAAIAJQACAAkAAgALAA0AAgAPABMADgAiACUADgBBAEwADgBPAE8ADgBZAFsACQBdAF0ACQBvAG8ACwB5AIQADwCGAJcADwCZAJwADwC7AMYADwDJAMkADwD6APoAAgEAAQAABgEDAQMABQEEAQQAAQEIAQgABwELAQsADgEOAQ4ADgEPAQ8ACQEQARAACgERAREADQESARIACwETARMADAEYARgAAwEaARoADgEbARsACAEfAR8ABAEgASAADwEnAScADwExATEADwE0ATQADwE3ATcADwFMAUwAAQGDAYMADwACAAkBIwEjAAEBKQEpAAIBKgEqAAcBLQEtAAIBNQE1AAUBNgE2AAYBOgE6AAMBPAE8AAMBPQE+AAQAAgAaAHkAhAABAIYAlwABAJgAmAALAJkAnAABALsAxgABAMkAyQABANQA2AALAOoA6gAMAPQA9wALASABIAABASYBJgADAScBJwABASkBKQAHASoBKgAGAS4BLgAEATEBMQABATQBNAABATUBNQAKATYBNgACATcBNwABATgBOAAMATkBOQAIAT4BPgAJAUEBQQANAUQBRAAFAYMBgwABAAIAJwANAA0ABAAOAA4AAQAPABMAAgAUABcAAwAYACAABAAhACEABQAiACUACQApACkABgAxADEABgAyADMABwA0ADkACABBAEsACQBMAEwABABNAE0ACgBPAE8ACQBQAFMACwBUAFgADABZAFsADQBdAF0ADQBeAGgADgBpAGoADwBrAG4AEABvAG8AEQBwAHQAEgB1AHUAEwB4AHgAEwD7APwAAQEBAQIABAEDAQMABwEHAQcABwELAQsACQENAQ0ACgEOAQ4AAgEPAQ8ADQEQARAAEgESARIAEQEaARoAAgEbARsACQEeAR4ACQACAEwAAgAJABQACwANABQADwATAAUAIgAlAAUAMQAxAB0AQQBMAAUATwBPAAUAVABYAAYAWQBbAAcAXQBdAAcAXgBoAAgAaQBqAAoAawBuAAsAbwBvAAwAcAB0AA0AdQB1AB4AeAB4AB4AeQCEAA4AhQCFACIAhgCXAA4AmACYABAAmQCcAA4AnQCnACIAqQCpACIAqgCrAB8ArACzACIAtAC1ACMAugC6ACMAuwDGAA4AxwDHACMAyADIACIAyQDJAA4AygDNABkAzgDSACQA1ADYABAA2QDjABEA5ADpABIA6gDqABMA6wDvABIA8ADzACcA9AD3ABAA+gD6ABQBAAEAABUBAwEDABYBBAEEAAEBCAEIABsBCwELAAUBDgEOAAUBDwEPAAcBEAEQAAkBEQERAAMBEgESAAwBEwETAAIBGAEYAAQBGgEaAAUBGwEbABwBHwEfABgBIAEgAA4BIQEhACIBJwEnAA4BMQExAA4BMwEzACMBNAE0AA4BNQE1ACgBNwE3AA4BOAE4ABMBTAFMAAEBYQFhACUBYgFiABcBZwFnABcBaAFoACEBagFrAA8BbAFsACYBcQF0ACABfgGBABoBgwGDAA4AAgAgAIQAhQAFAIsAjgADAI8AlwAFAJgAmAABAJ0AngAEAJ8ApgADAKkAqQADAKwArQACAK4ArwADALEAswADALQAtQAEALoAugAEALsAyAAFAMoAzQAGAM4A0gAHANMA0wAMANQA2AAIAOQA6QAJAOoA6gAKAOsA7wAJAPAA8wALAPQA9AABAPUA9QAIAPYA9wADASEBIQAFAScBJwAFATEBMQAFATMBMwAFATcBNwAFATgBOAAKAUEBQQAFAUMBQwAFAAIAMAABAAEAGgBZAFsAEABdAF0AEABpAGoAHAB5AIQAAgCGAJcAAgCYAJgABACZAJwAAgCqAKsAAQC0ALUACAC6ALoACAC7AMYAAgDHAMcACADJAMkAAgDKAM0ADQDOANIADwDUANgABADZAOMADgDkAOkABQDqAOoABgDrAO8ABQDwAPMAFgD0APcABAEPAQ8AEAEgASAAAgEmASYAEQEnAScAAgEpASkAGQEuAS4AEgExATEAAgEzATMACAE0ATQAAgE1ATUAFAE2ATYAFQE3ATcAAgE4ATgABgE+AT4AEwFeAV4AFwFiAWIACgFnAWcACgFoAWgACwFqAWsADAFtAW0AGAFxAXQACQF3AXcAGwF5AXoABwF+AYEAAwGDAYMAAgABAWkAGgAGAAMAAwAAAAkAAAAAAAAAAQABAAEAAQAAAAAABQAAAAAAAAAAAAQABwACAAAAAgACAAgAAgAfAAIACQAHAAsADQAHAA8AEwAFACIAJQAFADEAMQABAEEATAAFAE8ATwAFAFQAWAAJAFkAWwACAF0AXQACAGkAagADAHAAdAAEAHkAhAAGAIYAlwAGAJkAnAAGALsAxgAGAMkAyQAGAM4A0gAIAOoA6gAKAPoA+gAHAQsBCwAFAQ4BDgAFAQ8BDwACARoBGgAFASABIAAGAScBJwAGATEBMQAGATQBNAAGATcBNwAGATgBOAAKAYMBgwAGAAIAAAACAAoADwATAAEAIgAlAAEAQQBMAAEATwBPAAEAmACYAAIA1ADYAAIA9AD3AAIBCwELAAEBDgEOAAEBGgEaAAEAAgALAHkAhAABAIYAlwABAJkAnAABALsAxgABAMkAyQABASABIAABAScBJwABATEBMQABATQBNAABATcBNwABAYMBgwABAAEBaAABAAEAAgADAAEAAQACAVIBUgABAXkBegADAAAAAQAAAAoBjAfKAAJERkxUAA5sYXRuADAABAAAAAD//wAMAAAACgAUAB4AKAA6AEQATgBYAGIAbAB2ADQACEFaRSAAUkNBVCAAckNSVCAAkktBWiAAsk1PTCAA0lJPTSAA8lRBVCABElRSSyABMgAA//8ADAABAAsAFQAfACkAOwBFAE8AWQBjAG0AdwAA//8ADQACAAwAFgAgACoAMgA8AEYAUABaAGQAbgB4AAD//wANAAMADQAXACEAKwAzAD0ARwBRAFsAZQBvAHkAAP//AA0ABAAOABgAIgAsADQAPgBIAFIAXABmAHAAegAA//8ADQAFAA8AGQAjAC0ANQA/AEkAUwBdAGcAcQB7AAD//wANAAYAEAAaACQALgA2AEAASgBUAF4AaAByAHwAAP//AA0ABwARABsAJQAvADcAQQBLAFUAXwBpAHMAfQAA//8ADQAIABIAHAAmADAAOABCAEwAVgBgAGoAdAB+AAD//wANAAkAEwAdACcAMQA5AEMATQBXAGEAawB1AH8AgGFhbHQDAmFhbHQDCmFhbHQDEmFhbHQDGmFhbHQDImFhbHQDKmFhbHQDMmFhbHQDOmFhbHQDQmFhbHQDSmNhbHQDUmNhbHQDWGNhbHQDXmNhbHQDZGNhbHQDamNhbHQDcGNhbHQDdmNhbHQDfGNhbHQDgmNhbHQDiGRub20DjmRub20DlGRub20DmmRub20DoGRub20DpmRub20DrGRub20DsmRub20DuGRub20DvmRub20DxGZyYWMDymZyYWMD1GZyYWMD3mZyYWMD6GZyYWMD8mZyYWMD/GZyYWMEBmZyYWMEEGZyYWMEGmZyYWMEJGxpZ2EELmxpZ2EENGxpZ2EEOmxpZ2EEQGxpZ2EERmxpZ2EETGxpZ2EEUmxpZ2EEWGxpZ2EEXmxpZ2EEZGxvY2wEamxvY2wEcGxvY2wEdmxvY2wEfGxvY2wEgmxvY2wEiGxvY2wEjmxvY2wElG51bXIEmm51bXIEoG51bXIEpm51bXIErG51bXIEsm51bXIEuG51bXIEvm51bXIExG51bXIEym51bXIE0G9yZG4E1m9yZG4E3G9yZG4E4m9yZG4E6G9yZG4E7m9yZG4E9G9yZG4E+m9yZG4FAG9yZG4FBm9yZG4FDHBudW0FEnBudW0FGHBudW0FHnBudW0FJHBudW0FKnBudW0FMHBudW0FNnBudW0FPHBudW0FQnBudW0FSHNhbHQFTnNhbHQFVHNhbHQFWnNhbHQFYHNhbHQFZnNhbHQFbHNhbHQFcnNhbHQFeHNhbHQFfnNhbHQFhHNzMDEFinNzMDEFkHNzMDEFlnNzMDEFnHNzMDEFonNzMDEFqHNzMDEFrnNzMDEFtHNzMDEFunNzMDEFwHN1cHMFxnN1cHMFzHN1cHMF0nN1cHMF2HN1cHMF3nN1cHMF5HN1cHMF6nN1cHMF8HN1cHMF9nN1cHMF/HRudW0GAnRudW0GCHRudW0GDnRudW0GFHRudW0GGnRudW0GIHRudW0GJnRudW0GLHRudW0GMnRudW0GOAAAAAIAAAABAAAAAgAAAAEAAAACAAAAAQAAAAIAAAABAAAAAgAAAAEAAAACAAAAAQAAAAIAAAABAAAAAgAAAAEAAAACAAAAAQAAAAIAAAABAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAWAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAQAMAAAAAwANAA4ADwAAAAMADQAOAA8AAAADAA0ADgAPAAAAAwANAA4ADwAAAAMADQAOAA8AAAADAA0ADgAPAAAAAwANAA4ADwAAAAMADQAOAA8AAAADAA0ADgAPAAAAAwANAA4ADwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEAEwAAAAEACQAAAAEAAgAAAAEACAAAAAEABQAAAAEABAAAAAEAAwAAAAEABgAAAAEABwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEACwAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEAAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAEQAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFAAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEAFQAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEACgAAAAEAEgAAAAEAEgAAAAEAEgAAAAEAEgAAAAEAEgAAAAEAEgAAAAEAEgAAAAEAEgAAAAEAEgAAAAEAEgAZADQAPABEAE4AVgBeAGYAbgB2AH4AhgCO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ApoAFQKaABMCmgAVApoAFQNMABMCUAA3AqMAIwKjACMCowAjAqMAIwKjACMCmAA3AqAADwKYADcCoAAPAfgANwH4ADcB+AA3AfgANwH4ADcB+AA3AfgANwH4ADcB+AA3Ae4ANwLoACMC6AAjAugAIwLoACMCiAA3AogANwD3ADcC+gA3APcANwD3/+AA9//gAPf/zQD3ADcA9//0APf/1wIDAB8CewA3AqsANwHVADcB1QA3AdUANwHVADcB5wA3AeoAFANJADcCoAA3AqAANwKgADcCoAA3AqAANwKgADcDFgAjAxYAIwMWACMDFgAjAxYAIwMWACMDFgAjAxYAIwMWACMDFgAjAxYAIwQrACMCLAA3AjYANwMWACMCRQA3AkUANwJFADcCRQA3Ah8AHgIfAB4CHwAeAh8AHgIfAB4CHAAjAhwAIwIcACMCHAAjAhwAIwJ3ADICdwAyAncAMgJ3ADICdwAyAncAMgJ3ADICdwAyAncAMgJ3ADICdwAyAqwAHgRGAB4ERgAeBEYAHgRGAB4ERgAeAnAAHgJmAB4CZgAeAmYAHgJmAB4CZgAeAjwAKAI8ACgCPAAoAjwAKAJKAB4CSgAeAkoAHgJKAB4CSgAeAkoAHgJKAB4CSgAeAkoAHgJKAB4CSgAeA5oAHgJKAC0B9QAeAisAHgIrAB4CKwAeAisAHgJKAB4CPgAeAu4AHgJaAB4CHAAeAhwAHgIcAB4CHAAeAhwAHgIcAB4CHAAeAhwAHgIcAB4BnAAZAkoAHgJKAB4CSgAeAkoAHgIqAC0CNAAFAOEAKADfAC0A3wAtAN//1ADf/9QA3//BAN8ALQDf/+gB8wAoAN//ywDf/9oBJgAFASEABQIiAC0CIgAtAN8ALQDfAC0BiwAtAN8AJwGIAC0BSwAjA3UALQIqAC0CKgAtAioALQIqAC0CKgAtAioALQI4AB4COAAeAjgAHgI4AB4COAAeAjgAHgI4AB4COAAeAjgAHgI4AB4COAAeA5gAHgJKAC0CTgAtAkoAHgF1AC0BdQAtAXUAFAF1ACYBrAAZAawAGQGsABkBrAAZAawAGQJdADcBYQAZAWEAGQHRABkBYQAZAWEAGQIlACgCJQAoAiUAKAIlACgCJQAoAiUAKAIlACgCJQAoAiUAKAIlACgCJQAoAiYAFQN8ABUDfAAVA3wAFQN8ABUDfAAVAhoAHwIoABUCKAAVAigAFQIoABUCKAAVAdEAGQHRABkB0QAZAdEAGQGCABkBaAAZAlkAGQJgABkBpQAeAakAHgKaABUCLAA3AlAANwHiADcB4gA3AeIANwMdAB4B+AA3AfgANwQCABkCFgAjAqAANwKgADcCewA3AsoACgNJADcCiAA3AxYAIwKIADcCLAA3AqMAIwIcACMCqwAeA30AHgJwAB4CbgAeAscANwQYADcEVwA3AiwANwJ8AA8DTgA3AqMAIwKjACQA9wA3APf/zQPtADcCRQAjAkoAHgJKAC0CLgAtAaMALQGjAC0BowAtAtUAHgIcAB4CHAAeA5gAFQGnACMCPgAtAj4ALQI7AC0CbQAFAuEALQJCAC0COAAeAkIALQJKAC0B9QAeAcIAHgIoABUDuQAeAhoAHwI9AB4CdgAtAu8ALQMsAC0CGwAtAj8AFAMFAC0B9QAeAfUAHgDf/8EDDgAtAi4AHgKaABMDFgAjAiUAKAKuADICbwAeATsAHgIAACMCDAAjAiYAIwIPACQCBQAZAecAHgInACMCCQAiAsYASgLGAPECxgCBAsYAgALGAHQCxgB4AsYAdwLGAI4CxgBzAsYAgAHvAEsB6QALAOkAIwEzADcA1wAjANgAIwLFACMBHQBDAOkAQwJjADcA1wAjAgMAGQIDACMBUAAfALMAHwDYACMB6QAJAlgAMgFdADIBQgAXAT0AMgE9ADIBUAAyAVAAMgKeADICYgAyAYYALQGGAC0BcwAjAXMAIwDMACMAzAAjAYYAHgGBAB8BgQAeAM4AHgDOAB4AzgAeAfUAHgJOADcCHwAeAsYAHgFh/+wCYgAeAjgAMgJmAB4BzAA3AeAANwGfADcB4AA3AeAANwHgADcB+wA8AecAMgHhADcBzgAyAeAANwHzADIB8wAxAgsAMgMnACMBjgAZAssAMgKvADIC7QAyAiUAKAIFABkCxAAoBCQAKAJDADQDFgAjApoAIwMUACMCpwAfAoYAIwKGACMCKAA3AYwAMgD3ADcA9wA3AcwANwHMADcCOAAwAAD/aQDBAAMBQgAGAUQABgDCAAUBRAAGAWgABQCQAAUA2AAcAY8ABQFVAAUA0gAFANMABQF1AAUAgP9RAioAIQJDACECVQAeAjYAIQJIAB4CSgAeAjYAIAEOAB4AfAAeAOcAHgDzABsBAAAe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bgBuAGEAcgB5AC4AYwBvAG0AYwBvAG4AbgBhAHIAeQAuAGMAbwBtAEcAcgBlAHkAYwBsAGkAZgBmACAAQwBGAEIAbwBsAGQAAAIAAAAAAAD/tQAyAAAAAAAAAAAAAAAAAAAAAAAAAAAB3QAAAAMAJADJAQIBAwDHAGIArQEEAQUAYwCuAJAAJQAmAP0A/wBkAQYAJwDpAQcBCAAoAGUBCQDIAMoBCgDLAQsBDAApACoA+AENAQ4AKwEPACwBEADMAREAzQDOAPoAzwESAC0ALgETAC8BFAEVARYBFwDiADAAMQEYARkBGgEbAGYAMgDQARwA0QBnANMBHQEeAR8AkQCvALAAMwDtADQANQEgASEBIgA2ASMA5AD7ASQANwElASYBJwEoADgA1AEpASoA1QBoANYBKwEsAS0BLgA5ADoBLwEwATEBMgA7ADwA6wEzALsBNAA9ATUA5gE2AEQAaQE3ATgAawBsAGoBOQE6AG4AbQCgAEUARgD+AQAAbwE7AEcA6gE8AQEASABwAT0AcgBzAT4AcQE/AUAASQBKAPkBQQFCAEsBQwBMANcAdAFEAHYAdwFFAHUBRgFHAUgATQFJAE4BSgBPAUsBTAFNAU4A4wBQAFEBTwFQAVEBUgB4AFIAeQFTAHsAfAB6AVQBVQFWAKEAfQCxAFMA7gBUAFUBVwFYAVkAVgFaAOUA/AFbAIkAVwFcAV0BXgFfAFgAfgFgAWEAgACBAH8BYgFjAWQBZQBZAFoBZgFnAWgBaQBbAFwA7AFqALoBawBdAWwA5wFtAW4BbwDAAMEAnQCeAXABcQFyAXMBdAF1AXYBdwF4AXkBegF7AXwBfQF+AX8BgAGBAYIBgwGEAYUBhgGHAYgBiQGKAYsBjAGNAY4BjwGQAZEBkgGTAZQBlQGWAZcBmAGZAZoBmwGcAZ0BngGfAaABoQGiAaMBpAGlAaYBpwGoAakBqgGrAawBrQGuAa8BsAGxAbIBswG0AbUBtgG3AbgBuQG6AbsBvAG9AJsAEwAUABUAFgAXABgAGQAaABsAHAG+Ab8BwAHBAcIBwwHEAcUBxgHHAA0APwDDAIcAHQAPAKsABACjAAYAEQAiAKIABQAKAB4AEgBCAF4AYAA+AEAACwAMALMAsgAQAcgAqQCqAL4AvwDFALQAtQC2ALcAxACEAL0ABwHJAKYBygCFAJYADgDvAPAAuAAgAI8AIQAfAJUAlACTAKcAYQCkAJIAnACaAJkApQHLAJgACADGALkAIwAJAIgAhgCLAIoAjACDAF8A6ACCAMIAQQHMAI0A2wDhAN4A2ACOANwAQwDfANoA4ADdANkAvAD0APUA9gHNAc4BzwHQAdEB0gHTAdQB1QHWAdcB2AHZAdoB2wHcAd0B3gHfAeAB4QHiAeMB5AHlAeYB5wZBYnJldmUHdW5pMDFDRAdBbWFjcm9uB0FvZ29uZWsKQ2RvdGFjY2VudAZEY2Fyb24GRGNyb2F0BkVjYXJvbgpFZG90YWNjZW50B0VtYWNyb24HRW9nb25lawxHY29tbWFhY2NlbnQKR2RvdGFjY2VudARIYmFyAklKB3VuaTAxQ0YHSW1hY3JvbgxLY29tbWFhY2NlbnQGTGFjdXRlBkxjYXJvbgxMY29tbWFhY2NlbnQETGRvdAZOYWN1dGUGTmNhcm9uDE5jb21tYWFjY2VudANFbmcHdW5pMDFEMQ1PaHVuZ2FydW1sYXV0B09tYWNyb24HdW5pMDFFQQZSYWN1dGUGUmNhcm9uDFJjb21tYWFjY2VudAZTYWN1dGUMU2NvbW1hYWNjZW50BFRiYXIGVGNhcm9uB3VuaTAxNjIHdW5pMDIxQQZVYnJldmUHdW5pMDFEMw1VaHVuZ2FydW1sYXV0B1VtYWNyb24HVW9nb25lawVVcmluZwZXYWN1dGULV2NpcmN1bWZsZXgJV2RpZXJlc2lzBldncmF2ZQtZY2lyY3VtZmxleAZZZ3JhdmUGWmFjdXRlClpkb3RhY2NlbnQGYWJyZXZlB3VuaTAxQ0UHYW1hY3Jvbgdhb2dvbmVrCmNkb3RhY2NlbnQGZGNhcm9uBmVjYXJvbgplZG90YWNjZW50B2VtYWNyb24HZW9nb25lawxnY29tbWFhY2NlbnQKZ2RvdGFjY2VudARoYmFyB3VuaTAxRDAJaS5sb2NsVFJLAmlqB2ltYWNyb24HaW9nb25lawd1bmkwMjM3DGtjb21tYWFjY2VudAZsYWN1dGUGbGNhcm9uDGxjb21tYWFjY2VudARsZG90Bm5hY3V0ZQZuY2Fyb24MbmNvbW1hYWNjZW50A2VuZwd1bmkwMUQyDW9odW5nYXJ1bWxhdXQHb21hY3Jvbgd1bmkwMUVCBnJhY3V0ZQZyY2Fyb24McmNvbW1hYWNjZW50BnNhY3V0ZQxzY29tbWFhY2NlbnQEdGJhcgZ0Y2Fyb24HdW5pMDE2Mwd1bmkwMjFCBnVicmV2ZQd1bmkwMUQ0DXVodW5nYXJ1bWxhdXQHdW1hY3Jvbgd1b2dvbmVrBXVyaW5nBndhY3V0ZQt3Y2lyY3VtZmxleAl3ZGllcmVzaXMGd2dyYXZlC3ljaXJjdW1mbGV4BnlncmF2ZQZ6YWN1dGUKemRvdGFjY2VudAVmLmFsdAZ0LnNzMDEHdW5pMDQxMAd1bmkwNDExB3VuaTA0MTIHdW5pMDQxMwd1bmkwNDAzB3VuaTA0OTAHdW5pMDQxNAd1bmkwNDE1B3VuaTA0MDEHdW5pMDQxNgd1bmkwNDE3B3VuaTA0MTgHdW5pMDQxOQd1bmkwNDFBB3VuaTA0MUIHdW5pMDQxQwd1bmkwNDFEB3VuaTA0MUUHdW5pMDQxRgd1bmkwNDIwB3VuaTA0MjEHdW5pMDQyMgd1bmkwNDIzB3VuaTA0MjQHdW5pMDQyNQd1bmkwNDI3B3VuaTA0MjYHdW5pMDQyOAd1bmkwNDI5B3VuaTA0MkMHdW5pMDQyQQd1bmkwNDJCB3VuaTA0MDQHdW5pMDQyRAd1bmkwNDA2B3VuaTA0MDcHdW5pMDQyRQd1bmkwNDJGB3VuaTA0MzAHdW5pMDQzMQd1bmkwNDMyB3VuaTA0MzMHdW5pMDQ1Mwd1bmkwNDkxB3VuaTA0MzQHdW5pMDQzNQd1bmkwNDUxB3VuaTA0MzYHdW5pMDQzNwd1bmkwNDM4B3VuaTA0MzkHdW5pMDQzQQd1bmkwNDNCB3VuaTA0M0MHdW5pMDQzRAd1bmkwNDNFB3VuaTA0M0YHdW5pMDQ0MAd1bmkwNDQxB3VuaTA0NDIHdW5pMDQ0Mwd1bmkwNDQ0B3VuaTA0NDUHdW5pMDQ0Nwd1bmkwNDQ2B3VuaTA0NDgHdW5pMDQ0OQd1bmkwNDRDB3VuaTA0NEEHdW5pMDQ0Qgd1bmkwNDU0B3VuaTA0NEQHdW5pMDQ1Nwd1bmkwNDRFB3VuaTA0NEYHdW5pMDM5NAd1bmkwM0E5B3VuaTAzQkMHemVyby50ZgZvbmUudGYGdHdvLnRmCHRocmVlLnRmB2ZvdXIudGYHZml2ZS50ZgZzaXgudGYIc2V2ZW4udGYIZWlnaHQudGYHbmluZS50Zgd1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',

	}
	local function decodeAsset(data)
		local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
		local values={}; for i=1,#alphabet do values[alphabet:sub(i,i)]=i-1 end
		return (data:gsub('....',function(block)
			local a,b,c,d=block:sub(1,1),block:sub(2,2),block:sub(3,3),block:sub(4,4)
			local n=(values[a] or 0)*262144+(values[b] or 0)*4096+(values[c] or 0)*64+(values[d] or 0)
			return string.char(math.floor(n/65536)%256)..(c~='=' and string.char(math.floor(n/256)%256) or '')..(d~='=' and string.char(n%256) or '')
		end))
	end
	local assetCache={}
	local function asset(name)
		if assetCache[name]~=nil then return assetCache[name] end
		local result=''
		if getcustomasset then
			-- Prefer the untouched Tenacity resource when it is shipped beside the port.
			local sourcePath='tenacity/assets/tenacity/'..name
			local ok,value=pcall(function()
				if isfile and isfile(sourcePath) then return getcustomasset(sourcePath) end
				if shared.TenacityRuntime then
					local fetched, remote = pcall(shared.TenacityRuntime.Read, sourcePath, getcustomasset)
					if fetched and remote and remote ~= '' then return remote end
				end
				if embeddedAssets[name] then
					local path='tenacity/assets/tenacity-'..name
					if not (isfile and isfile(path)) then writefile(path,decodeAsset(embeddedAssets[name])) end
					return getcustomasset(path)
				end
				return ''
			end)
			if ok and value then result=value end
		end
		assetCache[name]=result
		return result
	end
	-- Custom font loading is optional; unsupported clients use a native face.
	if getcustomasset then
		pcall(function()
			local regular,bold=asset('tenacity.ttf'),asset('tenacity-bold.ttf')
			if regular=='' or bold=='' then return end
			local path='tenacity/assets/tenacity-family.json'
			writefile(path,httpService:JSONEncode({name='Tenacity',faces={
				{name='Regular',weight=400,style='normal',assetId=regular},
				{name='Bold',weight=700,style='normal',assetId=bold}
			}}))
			local family=getcustomasset(path)
			local regularFace=Font.new(family,Enum.FontWeight.Regular,Enum.FontStyle.Normal)
			local boldFace=Font.new(family,Enum.FontWeight.Bold,Enum.FontStyle.Normal)
			local params=Instance.new('GetTextBoundsParams'); params.Font=regularFace; params.Text='Tenacity'; params.Size=16; params.Width=500
			local ok=pcall(function() textService:GetTextBoundsAsync(params) end); params:Destroy()
			if ok then tenacityFont=regularFace; uipallet.FontSemiBold=boldFace end
		end)
		pcall(function()
			local icon=asset('icon.ttf')
			if icon=='' then return end
			local path='tenacity/assets/tenacity-icon-family.json'
			writefile(path,httpService:JSONEncode({name='TenacityIcons',faces={{name='Regular',weight=400,style='normal',assetId=icon}}}))
			local family=getcustomasset(path)
			local iconFace=Font.new(family,Enum.FontWeight.Regular,Enum.FontStyle.Normal)
			local params=Instance.new('GetTextBoundsParams'); params.Font=iconFace; params.Text='g'; params.Size=18; params.Width=500
			local ok=pcall(function() textService:GetTextBoundsAsync(params) end); params:Destroy()
			if ok then iconFont=iconFace end
		end)
	end

	-- Java settings are drawn here from their definitions, never by displaying
	-- the old control Instances. Hidden model setters retain gameplay callbacks.
	ui.ControlViews = {}
	ui.MenuState = setmetatable({}, {__mode='k'})
	ui.ModuleViews = {}
	local function effectiveScale(object)
		local result=1
		while object do
			local zoom=object:FindFirstChildWhichIsA('UIScale')
			if zoom then result*=zoom.Scale end
			object=object.Parent
		end
		return math.max(result,0.01)
	end
	ui.Dragging = nil
	local function cleanText(text)
		return tostring(text or ''):gsub('Tenacity 5.1', 'Tenacity'):gsub('Tenacity', 'Tenacity'):gsub('tenacity', 'Tenacity')
	end
	-- Measure the actual loaded face, including the native-font fallback.
	local function textWidth(text, size, face)
		local params=Instance.new('GetTextBoundsParams')
		params.Text=text; params.Size=size; params.Font=face; params.Width=10000
		local ok,bounds=pcall(function() return textService:GetTextBoundsAsync(params) end)
		params:Destroy()
		return ok and bounds.X or textService:GetTextSize(text,size,Enum.Font.Gotham,Vector2.new(10000,100)).X
	end
	local function watch(object, update)
		ui.ControlViews[object] = update
		update()
	end
	local function track(parent, title, minimum, maximum, get, set, y, decimals, style)
		local modern=style=='Modern'
		local compact=style=='Compact'
		local captionX=modern and 26 or 10
		local caption=label(parent,title,captionX,y,130,22,modern and 16 or compact and 14 or 16)
		caption.Size=UDim2.new(1,modern and -94 or -84,0,22)
		local value=field(parent,'',0,y,60)
		value.Position=UDim2.new(1,-70,0,y)
		value.Size=UDim2.fromOffset(60,22)
		value.BackgroundTransparency=(modern or compact) and 0 or 1
		value.BackgroundColor3=Color3.fromRGB(64,68,75)
		value.TextSize=modern and 14 or 16
		local railX=modern and 24 or 10
		local railY=y+(modern and 27 or compact and 14 or 26)
		local rail=create('TextButton',parent,{Text='',AutoButtonColor=false,BackgroundColor3=Color3.fromRGB(modern and 30 or 64,modern and 31 or 68,modern and 35 or 75),BackgroundTransparency=0,Position=UDim2.fromOffset(railX,railY),Size=modern and UDim2.new(1,-48,0,10) or compact and UDim2.new(1,-194,0,4) or UDim2.new(1,-20,0,6)})
		if compact then rail.Position=UDim2.new(1,-190,0,railY) end
		addCorner(rail,UDim.new(0,modern and 4 or 2))
		local fill=create('Frame',rail,{Size=UDim2.fromScale(0,1)})
		accent(fill)
		local handle=create('Frame',rail,{Size=modern and UDim2.fromOffset(4,10) or UDim2.fromOffset(8,8),Position=modern and UDim2.fromOffset(-2,0) or UDim2.fromOffset(-4,-2),BackgroundColor3=Color3.new(1,1,1)})
		addCorner(handle,UDim.new(1,0))
		local hit=create('TextButton',rail,{Text='',Size=UDim2.new(1,0,0,20),Position=UDim2.fromOffset(0,-8)})
		local function commit(x,released)
			local alpha=math.clamp((x-rail.AbsolutePosition.X)/math.max(rail.AbsoluteSize.X,1),0,1)
			local precision=math.max(tonumber(decimals) or 1,1)
			local number=math.floor((minimum+(maximum-minimum)*alpha)*precision+0.5)/precision
			set(math.clamp(number,minimum,maximum),released)
		end
		hit.InputBegan:Connect(function(input)
			if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
				ui.SelectedSlider={Object=rail,Adjust=function(direction)
					local precision=math.max(tonumber(decimals) or 1,1)
					set(math.clamp((get() or minimum)+direction/precision,minimum,maximum),true)
				end}
				ui.Dragging={Input=input,Move=function(position,released) commit(position.X,released) end}
				commit(input.Position.X,false)
			end
		end)
		value.FocusLost:Connect(function()
			local number=tonumber(value.Text)
			if number and (number == number and math.abs(number) < math.huge) then set(math.clamp(number,minimum,maximum),true) end
		end)
		watch(rail,function()
			local n=get() or minimum
			local alpha=math.clamp((n-minimum)/math.max(maximum-minimum,0.00001),0,1)
			fill.Size=UDim2.fromScale(alpha,1)
			handle.Position=modern and UDim2.new(alpha,-2,0,0) or UDim2.new(alpha,-4,0,-2)
			if inputService:GetFocusedTextBox()~=value then value.Text=tostring(math.floor(n*1000+0.5)/1000) end
		end)
	end
	local function toggleControl(parent,name,get,set,style)
		local modern=style=='Modern'
		local compact=style=='Compact'
		local title=label(parent,name,modern and 26 or 10,0,140,modern and 36 or 32,16)
		title.Size=UDim2.new(1,-58,0,modern and 36 or 30)
		if compact then
			local box=create('TextButton',parent,{Text='',AutoButtonColor=false,BackgroundColor3=Color3.fromRGB(64,68,75),BackgroundTransparency=0,Position=UDim2.new(1,-32,0,6),Size=UDim2.fromOffset(20,20)})
			local inside=create('Frame',box,{BackgroundColor3=Color3.fromRGB(64,68,75),Position=UDim2.fromOffset(1,1),Size=UDim2.fromOffset(18,18)})
			local check=label(box,'✓',0,0,20,20,14); check.TextXAlignment=Enum.TextXAlignment.Center; check.FontFace=uipallet.FontSemiBold
			box.Activated:Connect(set)
			watch(box,function()
				local enabled=get(); box.BackgroundColor3=enabled and tenacity:GetThemeColor(0.5) or Color3.fromRGB(82,86,93); inside.BackgroundColor3=Color3.fromRGB(64,68,75); check.TextTransparency=enabled and 0 or 1; title.TextColor3=enabled and Color3.new(1,1,1) or muted
			end)
			return
		end
		local switch=create('TextButton',parent,{Text='',AutoButtonColor=false,BackgroundTransparency=0,Position=UDim2.new(1,modern and -54 or -45,0,modern and 10 or 9),Size=modern and UDim2.fromOffset(36,16) or UDim2.fromOffset(34,14)})
		addCorner(switch,UDim.new(1,0))
		local knob=create('Frame',switch,{BackgroundColor3=Color3.new(1,1,1),Position=UDim2.fromOffset(modern and 0 or 3,modern and 0 or 2),Size=modern and UDim2.fromOffset(16,16) or UDim2.fromOffset(10,10)})
		addCorner(knob,UDim.new(1,0))
		switch.Activated:Connect(set)
		watch(switch,function()
			local enabled=get()
			switch.BackgroundColor3=enabled and tenacity:GetThemeColor(0.5) or Color3.fromRGB(modern and 30 or 65,modern and 31 or 65,modern and 35 or 70)
			if switch:GetAttribute('Enabled')~=enabled then
				switch:SetAttribute('Enabled',enabled)
				tween:Tween(knob,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=modern and UDim2.fromOffset(enabled and 20 or 0,0) or UDim2.fromOffset(enabled and 21 or 3,2)})
			end
			title.TextColor3=enabled and Color3.new(1,1,1) or muted
		end)
	end
	function ui:DrawControls(parent, owner, includeBind, style)
		style=style or 'Dropdown'
		local modern=style=='Modern'
		local compact=style=='Compact'
		local layout = create('UIListLayout', parent, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0)})
		-- Hidden compatibility Frames can reach this function through old constructors.
		-- They have no module settings to draw, and touching Frame.Options throws.
		if type(owner) ~= 'table' then return layout end
		local ownerOptions = optionsOf(owner) or {}
		local controls, seen = {}, {}
		for _, option in tenacity.TenacityControls[owner] or {} do
			if not seen[option] then seen[option] = true; table.insert(controls, option) end
		end
		for name, option in ownerOptions do
			if type(option) == 'table' and not seen[option] then
				option.TenacityProps = option.TenacityProps or {Name = name}
				seen[option] = true; table.insert(controls, option)
			end
		end
		table.sort(controls, function(a,b)
			local first,second=a.TenacityOrder or a.Index or 0,b.TenacityOrder or b.Index or 0
			if first~=second then return first<second end
			return tostring((a.TenacityProps or {}).Name or a.Name)<tostring((b.TenacityProps or {}).Name or b.Name)
		end)
		if includeBind and owner.Bind then
			local bind = create('Frame', parent, {Size = UDim2.new(1,0,0,modern and 36 or 30), BackgroundTransparency = 1, LayoutOrder = -1})
			label(bind, 'Keybind', 10, 0, 90, 30, 13)
			local b = button(bind, '', 0, 3, 88, function() self.Binding = owner.Bind end)
			b.Position = UDim2.new(1,-98,0,3); b.Size = UDim2.fromOffset(88,24)
			watch(b, function() b.Text = self.Binding == owner.Bind and 'Press a key' or (#owner.Bind.Keys > 0 and table.concat(owner.Bind.Keys,' + ') or 'NONE') end)
		end
		for index, option in controls do
			local props = option.TenacityProps or {}
			local kind, name = option.Type, cleanText(props.Name or option.Name or 'Setting')
			local row = create('Frame', parent, {Name = 'Setting_'..name, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,modern and 44 or 32), LayoutOrder = index})
			watch(row, function() row.Visible = not option.Object or option.Object.Visible end)
			if kind == 'Toggle' or kind == 'ImageToggle' or kind == 'TargetsButton' then
				toggleControl(row,name,function() return option.Enabled end,function() option:Toggle() end,style)
			elseif kind == 'Slider' then
				row.Size=UDim2.new(1,0,0,modern and 44 or compact and 32 or 42)
				track(row,name,props.Min or 0,props.Max or option.Max or 100,function() return option.Value end,function(value,released) option:SetValue(value,nil,released) end,0,props.Decimal,style)
			elseif kind == 'TwoSlider' then
				row.Size = UDim2.new(1,0,0,82)
				track(row,name..' min',props.Min or 0,props.Max or option.Max or 100,function() return option.ValueMin end,function(value) option:SetValue(false,math.min(value,option.ValueMax)) end,0,props.Decimal,style)
				track(row,name..' max',props.Min or 0,props.Max or option.Max or 100,function() return option.ValueMax end,function(value) option:SetValue(true,math.max(value,option.ValueMin)) end,40,props.Decimal,style)
			elseif kind == 'Dropdown' then
				-- ModeComponent: 2 x 16 source units; alternatives are 15 units each.
				local baseHeight=modern and 44 or compact and 32 or 64
				local controlY=modern and 8 or compact and 5 or 22
				local controlHeight=modern and 24 or compact and 22 or 36
				local menuY=controlY+controlHeight+((modern or compact) and 4 or 8)
				row.Size=UDim2.new(1,0,0,baseHeight)
				label(row,name,modern and 26 or 10,0,modern and 92 or compact and 135 or 190,modern and 44 or compact and 32 or 20,14)
				local selection=create('TextButton',row,{Name='ModeSelection',Text='',AutoButtonColor=false,BackgroundColor3=Color3.fromRGB(45,45,45),BackgroundTransparency=0,Position=UDim2.fromOffset(10,controlY),Size=UDim2.new(1,-20,0,controlHeight)})
				if modern then selection.Position=UDim2.new(1,-128,0,controlY); selection.Size=UDim2.fromOffset(104,controlHeight); selection.BackgroundColor3=Color3.fromRGB(30,31,35)
				elseif compact then selection.Position=UDim2.new(1,-145,0,controlY); selection.Size=UDim2.fromOffset(135,controlHeight); selection.BackgroundColor3=Color3.fromRGB(64,68,75) end
				addCorner(selection,UDim.new(0,6))
				local outline=create('UIStroke',selection,{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1,Color=Color3.fromRGB(65,65,65)})
				local selected=label(selection,'',10,0,140,controlHeight,16); selected.Size=UDim2.new(1,-36,1,0)
				local arrow=label(selection,iconFont and 'z' or '⌄',0,0,24,controlHeight,20)
				arrow.Name='ModeArrow'; arrow.Position=UDim2.new(1,-28,0,0); arrow.TextXAlignment=Enum.TextXAlignment.Center
				if iconFont then arrow.FontFace=iconFont end
				local choices=scroll(row,10,menuY,180,0)
				choices.Name='ModeAlternatives'; choices.Size=UDim2.new(1,-20,0,0); choices.BackgroundColor3=Color3.fromRGB(45,45,45)
				choices.ScrollBarThickness=2; choices.ClipsDescendants=true; addCorner(choices,UDim.new(0,6))
				if modern then choices.Position=UDim2.new(1,-128,0,menuY); choices.Size=UDim2.fromOffset(104,0)
				elseif compact then choices.Position=UDim2.new(1,-145,0,menuY); choices.Size=UDim2.fromOffset(135,0) end
				local open=self.MenuState[option]==true
				local lastList,lastValue,lastOpen
				local function rebuildChoices()
					for _,child in choices:GetChildren() do if not child:IsA('UICorner') then child:Destroy() end end
					local count=0
					local choiceHeight=compact and 24 or 30
					for _,value in props.List or {} do
						if value~=option.Value then
							local choice=create('TextButton',choices,{Name='Choice_'..tostring(value),Text='  '..cleanText(value),TextSize=16,TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false,BackgroundTransparency=1,BackgroundColor3=Color3.fromRGB(64,64,64),Position=UDim2.fromOffset(3,count*choiceHeight+3),Size=UDim2.new(1,-6,0,choiceHeight-6)})
							addCorner(choice,UDim.new(0,5))
							choice.MouseEnter:Connect(function() tween:Tween(choice,uiMotionFast,{BackgroundTransparency=0}) end)
							choice.MouseLeave:Connect(function() tween:Tween(choice,uiMotionFast,{BackgroundTransparency=1}) end)
							choice.Activated:Connect(function()
								option:SetValue(value,true); open=false; self.MenuState[option]=false
								rebuildChoices()
							end)
							count+=1
						end
					end
					if count==0 then open=false; self.MenuState[option]=false end
			local height=open and math.min(count,7)*choiceHeight or 0
					local motion=TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
					tween:Tween(choices,motion,{Size=UDim2.new(choices.Size.X.Scale,choices.Size.X.Offset,0,height)})
					tween:Tween(row,motion,{Size=UDim2.new(1,0,0,open and math.max(baseHeight,menuY+height+4) or baseHeight)})
					tween:Tween(arrow,motion,{Rotation=open and 180 or 0})
					outline.Color=open and tenacity:GetThemeColor(0.5) or Color3.fromRGB(65,65,65)
					choices.Active=open
				end
				local function toggleMenu()
					open=not open; self.MenuState[option]=open; rebuildChoices()
				end
				selection.Activated:Connect(toggleMenu)
				selection.MouseButton2Click:Connect(toggleMenu)
				watch(selection,function()
					selected.Text=cleanText(option.Value)
					local values={}; for _,value in props.List or {} do table.insert(values,tostring(value)) end
					local signature=table.concat(values,'\0')
					if signature~=lastList or lastValue~=option.Value or lastOpen~=open then
						lastList=signature; lastValue=option.Value; lastOpen=open; rebuildChoices()
					end
				end)
			elseif kind == 'TextBox' then
				local labelX=modern and 32 or 10
				row.Size=UDim2.new(1,0,0,modern and 66 or compact and 32 or 58)
				label(row,name,labelX,0,modern and 205 or compact and 135 or 190,modern and 24 or compact and 32 or 22,12)
				local text=field(row,props.Placeholder or '',modern and 34 or 10,modern and 28 or compact and 5 or 24,modern and 220 or compact and 130 or 180)
				if modern then text.Size=UDim2.new(1,-68,0,28); text.BackgroundColor3=Color3.fromRGB(30,31,35)
				elseif compact then text.Position=UDim2.new(1,-140,0,5); text.Size=UDim2.fromOffset(130,22); text.BackgroundColor3=Color3.fromRGB(64,68,75)
				else text.Size=UDim2.new(1,-20,0,28) end
				text.FocusLost:Connect(function(enter) option:SetValue(text.Text,enter) end)
				watch(text,function() if inputService:GetFocusedTextBox()~=text then text.Text=tostring(option.Value or '') end end)
			elseif kind == 'ColorSlider' then
				row.Size=UDim2.new(1,0,0,modern and 44 or 32)
				label(row,name,modern and 26 or 10,0,145,modern and 44 or 30,13)
				local expanded=false
				local palette
				local swatch=button(row,'',0,7,26,function()
					expanded=not expanded
					if palette then palette:Destroy(); palette=nil end
					row.Size=UDim2.new(1,0,0,modern and 44 or 32)
					if expanded then
						local baseY=modern and 44 or 32
						palette=create('Frame',row,{BackgroundTransparency=1,Position=UDim2.fromOffset(0,baseY),Size=UDim2.new(1,0,0,222)})
						local square=create('Frame',palette,{Position=UDim2.fromOffset(10,4),Size=compact and UDim2.new(1,-44,0,100) or UDim2.new(1,-20,0,100),BackgroundColor3=Color3.fromHSV(option.Hue,1,1)})
						local white=create('Frame',square,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1)})
						create('UIGradient',white,{Transparency=NumberSequence.new(0,1)})
						local black=create('Frame',square,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0)})
						create('UIGradient',black,{Transparency=NumberSequence.new(1,0),Rotation=90})

						local pickerAsset=asset('colorpicker2.png')
						local cursor
						if pickerAsset~='' then
							cursor=create('ImageLabel',square,{BackgroundTransparency=1,Image=pickerAsset,Size=UDim2.fromOffset(8,8),ZIndex=black.ZIndex+1})
						else
							cursor=create('Frame',square,{Size=UDim2.fromOffset(8,8),BackgroundTransparency=1,ZIndex=black.ZIndex+1})
							addCorner(cursor,UDim.new(1,0)); create('UIStroke',cursor,{Color=Color3.new(1,1,1),Thickness=1.5})
						end
						local hit=create('TextButton',square,{Text='',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=cursor.ZIndex+1})
						local function choose(position)
							local sat=math.clamp((position.X-square.AbsolutePosition.X)/math.max(square.AbsoluteSize.X,1),0,1)
							local val=1-math.clamp((position.Y-square.AbsolutePosition.Y)/math.max(square.AbsoluteSize.Y,1),0,1)
							option:SetValue(option.Hue,sat,val,option.Opacity)
						end
						hit.InputBegan:Connect(function(input)
							if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then ui.Dragging={Input=input,Move=choose}; choose(input.Position) end
						end)

						local hueAsset=asset(compact and 'hue2.png' or 'hue.png')
						local hueHit
						local hueMarker
						if compact then
							hueHit=create('TextButton',palette,{Text='',AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),Position=UDim2.new(1,-24,0,4),Size=UDim2.fromOffset(10,100)})
							if hueAsset~='' then create('ImageLabel',hueHit,{BackgroundTransparency=1,Image=hueAsset,Size=UDim2.fromScale(1,1)}) else create('UIGradient',hueHit,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(.2,Color3.fromHSV(.2,1,1)),ColorSequenceKeypoint.new(.4,Color3.fromHSV(.4,1,1)),ColorSequenceKeypoint.new(.6,Color3.fromHSV(.6,1,1)),ColorSequenceKeypoint.new(.8,Color3.fromHSV(.8,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))}),Rotation=90}) end
							hueMarker=create('Frame',hueHit,{BackgroundColor3=Color3.new(1,1,1),Size=UDim2.fromOffset(12,2),Position=UDim2.fromOffset(-1,0),ZIndex=4})
						else
							hueHit=create('TextButton',palette,{Text='',AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),Position=UDim2.fromOffset(10,110),Size=UDim2.new(1,-20,0,8)})
							addCorner(hueHit,UDim.new(0,3))
							if hueAsset~='' then local img=create('ImageLabel',hueHit,{BackgroundTransparency=1,Image=hueAsset,Size=UDim2.fromScale(1,1),ScaleType=Enum.ScaleType.Stretch}); addCorner(img,UDim.new(0,3)) else create('UIGradient',hueHit,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(.2,Color3.fromHSV(.2,1,1)),ColorSequenceKeypoint.new(.4,Color3.fromHSV(.4,1,1)),ColorSequenceKeypoint.new(.6,Color3.fromHSV(.6,1,1)),ColorSequenceKeypoint.new(.8,Color3.fromHSV(.8,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))})}) end
							hueMarker=create('Frame',hueHit,{BackgroundColor3=Color3.new(1,1,1),Size=UDim2.fromOffset(2,12),Position=UDim2.fromOffset(0,-2),ZIndex=4})
						end
						local function chooseHue(position)
							local hue
							if compact then hue=math.clamp((position.Y-hueHit.AbsolutePosition.Y)/math.max(hueHit.AbsoluteSize.Y,1),0,1)
							else hue=math.clamp((position.X-hueHit.AbsolutePosition.X)/math.max(hueHit.AbsoluteSize.X,1),0,1) end
							option:SetValue(hue,option.Sat,option.Value,option.Opacity)
						end
						hueHit.InputBegan:Connect(function(input)
							if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then ui.Dragging={Input=input,Move=chooseHue}; chooseHue(input.Position) end
						end)
						watch(square,function()
							square.BackgroundColor3=Color3.fromHSV(option.Hue,1,1)
							cursor.Position=UDim2.new(option.Sat,-4,1-option.Value,-4)
							if compact then hueMarker.Position=UDim2.new(0,-1,option.Hue,-1) else hueMarker.Position=UDim2.new(option.Hue,-1,0,-2) end
						end)

						local inputY=compact and 110 or 126
						local hex=field(palette,'#RRGGBB',10,inputY,180); hex.Size=UDim2.new(1,-20,0,24)
						hex.FocusLost:Connect(function()
							local value=hex.Text:gsub('#','')
							if value:match('^%x%x%x%x%x%x$') then local c=Color3.fromHex(value); local h,s,v=c:ToHSV(); option:SetValue(h,s,v,option.Opacity) end
						end)
						watch(hex,function() if inputService:GetFocusedTextBox()~=hex then hex.Text='#'..Color3.fromHSV(option.Hue,option.Sat,option.Value):ToHex() end end)
						track(palette,'Opacity',0,1,function() return option.Opacity end,function(value) option:SetValue(option.Hue,option.Sat,option.Value,value) end,inputY+32,100,style)
						local rainbow=create('Frame',palette,{BackgroundTransparency=1,Position=UDim2.fromOffset(0,inputY+74),Size=UDim2.new(1,0,0,30)})
						toggleControl(rainbow,'Rainbow',function() return option.Rainbow end,function() option:Toggle() end,style)
						row.Size=UDim2.new(1,0,0,baseY+inputY+108)
					end
				end)
				swatch.Position=UDim2.new(1,modern and -54 or -38,0,modern and 12 or 7); swatch.Size=modern and UDim2.fromOffset(36,20) or UDim2.fromOffset(26,18)
				watch(swatch,function() swatch.BackgroundColor3=Color3.fromHSV(option.Hue,option.Sat,option.Value) end)
			elseif kind == 'TextList' then
				row.Size=UDim2.new(1,0,0,100)
				label(row,name,10,0,180,22,12)
				local entry=field(row,'Add entry...',10,24,150); entry.Size=UDim2.new(1,-62,0,26)
				button(row,'+',0,24,32,function() if entry.Text~='' then option:ChangeValue(entry.Text); entry.Text='' end end).Position=UDim2.new(1,-42,0,24)
				local list=scroll(row,10,54,180,42); list.Size=UDim2.new(1,-20,0,42)
				local signature
				watch(list,function()
					local current=table.concat(option.List or {},'\n')
					if signature==current then return end; signature=current
					for _,child in list:GetChildren() do child:Destroy() end
					for j,value in option.List or {} do local b=button(list,tostring(value)..'   ×',0,(j-1)*24,180,function() option:ChangeValue(value) end); b.Size=UDim2.new(1,0,0,24) end
				end)
			elseif kind == 'Bind' or option.SetBind then
				label(row,name,10,0,100,30,13)
				local key=button(row,'',0,3,88,function() self.Binding=option end); key.Position=UDim2.new(1,-98,0,3); key.Size=UDim2.fromOffset(88,24)
				watch(key,function() key.Text=self.Binding==option and 'Press a key' or (#option.Keys>0 and table.concat(option.Keys,' + ') or 'NONE') end)
			elseif kind == 'Button' and props.Function then
				local b=button(row,name,10,2,180,props.Function); b.Size=UDim2.new(1,-20,0,28)
			elseif kind == 'Targets' then
				row.Size=UDim2.new(1,0,0,0); row.AutomaticSize=Enum.AutomaticSize.Y
				local nested={Options={}}
				for _,key in {'Players','NPCs','Invisible','Walls'} do
					if option[key] then nested.Options[key]=option[key] end
				end
				self:DrawControls(row,nested,false,style)
			else
				row:Destroy() -- unsupported structural components have no independent value
			end
		end
		return layout
	end
	tenacity:Clean(inputService.InputChanged:Connect(function(input)
		local drag=ui.Dragging
		if drag and (input==drag.Input or input.UserInputType==Enum.UserInputType.MouseMovement) then drag.Move(input.Position,false) end
	end))
	tenacity:Clean(inputService.InputEnded:Connect(function(input)
		local drag=ui.Dragging
		if drag and (input==drag.Input or input.UserInputType==Enum.UserInputType.MouseButton1) then drag.Move(input.Position,true); ui.Dragging=nil end
	end))

	-- The original Tenacity GUI remains only as the hidden compatibility/model tree.
	-- Everything visible below is rebuilt from Tenacity's Java ClickGUI geometry.
	local legacy = create('Frame', clickgui, {Name='CompatibilityModel', Visible=false, Size=UDim2.fromScale(1,1), BackgroundTransparency=1})
	for _, object in clickgui:GetChildren() do if object~=legacy then object.Parent=legacy end end
	ui.Legacy=legacy

	local categoryNames={'Combat','Movement','Render','Player','Exploit','Misc','Scripts'}
	local mapping={Combat='Combat',Movement='Movement',Render='Render',Player='Player',Exploit='Exploit',Misc='Misc',Scripts='Scripts'}
	local categoryGlyph={Combat='c',Movement='f',Render='d',Player='e',Exploit='a',Misc='b',Scripts='g'}
	ui.Expanded={}
	ui.Panels={}
	ui.Tabs={}
	ui.ModernTabs={}
	ui.CompactTabs={}
	ui.Mode='Dropdown'
	ui.Selected='Combat'
	ui.Rows={}
	ui.ModernNavExpanded=false

	local function wipe(parent)
		for _,object in parent:GetChildren() do
			if not object:IsA('UIListLayout') then object:Destroy() end
		end
	end
	local function hardWipe(parent) for _,object in parent:GetChildren() do object:Destroy() end end
	local function stack(parent)
		return create('UIListLayout',parent,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,0)})
	end
	local function getModules(category)
		local modules={}
		for name,module in tenacity.Modules do
			local group=mapping[module.Category] or 'Misc'
			if group==category and module.Visible~=false and matchesModuleSearch(name,category,module.Tooltip,ui.Query or '') and matchesModuleState(module,name,ui.Query or '') then
				table.insert(modules,module)
			end
		end
		table.sort(modules,function(a,b) return a.Name:lower()<b.Name:lower() end)
		return modules
	end
	local function categoryIcon(parent,name,x,y,size)
		if iconFont then
			local glyph=label(parent,categoryGlyph[name] or 'g',x,y,size,size,size)
			glyph.Name='CategoryIcon'; glyph.FontFace=iconFont; glyph.TextXAlignment=Enum.TextXAlignment.Center
			return glyph
		end
		local sourceIcon=asset(name:lower()..'.png')
		if sourceIcon~='' then
			return create('ImageLabel',parent,{Name='CategoryIcon',BackgroundTransparency=1,Image=sourceIcon,ImageColor3=Color3.new(1,1,1),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size)})
		end
		local glyph=label(parent,categoryGlyph[name] or '•',x,y,size,size,math.max(14,size-2))
		if iconFont then glyph.FontFace=iconFont; glyph.TextXAlignment=Enum.TextXAlignment.Center; glyph.TextYAlignment=Enum.TextYAlignment.Center end
		return glyph
	end
	local function makeStroke(parent,offset)
		local outline=create('UIStroke',parent,{Thickness=1.5,Color=Color3.new(1,1,1),ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		local gradient=create('UIGradient',outline,{Color=tenacity:GetThemeSequence(offset or 0),Rotation=90})
		tenacity:RegisterThemeGradient(gradient,offset or 0,90)
		return outline
	end
	local function brandMark(parent,x,y,size)
		local mark=create('Frame',parent,{Name='TenacityLogoMark',BackgroundTransparency=1,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size)})
		local sourceLogo=asset('modernlogo.png')
		if sourceLogo~='' then
			create('ImageLabel',mark,{Name='SourceLogo',BackgroundTransparency=1,Image=sourceLogo,Size=UDim2.fromScale(1,1),ScaleType=Enum.ScaleType.Stretch})
		else
			local glyph=label(mark,'T',0,0,size,size,math.floor(size*0.78)); glyph.TextXAlignment=Enum.TextXAlignment.Center; glyph.FontFace=uipallet.FontSemiBold
			tenacity:ApplyThemeGradient(glyph,'TextColor3',0,true,0)
		end
		return mark
	end

	-- DropdownClickGUI / CategoryPanel.java: 105x15 panels, 14px module rows.
	-- Roblox renders these at 2x so the source geometry is preserved exactly.
	local dropdownRoot=create('Frame',clickgui,{Name='TenacityDropdown',Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
	for index,name in categoryNames do
		local window=create('Frame',dropdownRoot,{Name=name..'Panel',BackgroundColor3=Color3.fromRGB(20,20,20),Position=UDim2.fromOffset(40+(index-1)*240,40),Size=UDim2.fromOffset(210,30)})
		addCorner(window,UDim.new(0,10)); makeStroke(window,(index-1)*0.06)
		local header=create('TextButton',window,{Text='',FontFace=uipallet.FontSemiBold,TextSize=22,TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.fromOffset(210,30),AutoButtonColor=false})
		local titleWidth=textWidth(name,22,uipallet.FontSemiBold)
		local titleX=(210-titleWidth-26)/2
		local title=label(header,name,titleX,0,titleWidth,30,22); title.FontFace=uipallet.FontSemiBold
		local icon=categoryIcon(header,name,titleX+titleWidth+6,5,20)
		if icon:IsA('TextLabel') then icon.TextColor3=Color3.new(1,1,1) end
		addDragHandler(window,nil,30)
		local list=scroll(window,1,30,208,0); list.BackgroundTransparency=1; list.ScrollBarThickness=0
		local panel={Object=window,List=list,Header=header,Expanded=true}
		ui.Panels[name]=panel
		header.MouseButton2Click:Connect(function() panel.Expanded=not panel.Expanded; ui:Render() end)
	end

	-- ModernClickGui.java: 370x255 -> 740x510, with a 100->45 category rail.
	local modernShell=create('Frame',clickgui,{Name='TenacityModern',BackgroundColor3=Color3.fromRGB(30,31,35),Position=UDim2.fromOffset(260,150),Size=UDim2.fromOffset(740,510),Visible=false})
	addCorner(modernShell,UDim.new(0,20)); addDragHandler(modernShell,nil,40)
	modernShell.InputBegan:Connect(function(input)
		if input.Position.Y-modernShell.AbsolutePosition.Y<40*scale.Scale then ui.ModernDragged=true end
	end)
	local modernNav=create('Frame',modernShell,{Name='CategoryRail',BackgroundColor3=Color3.fromRGB(47,49,54),Size=UDim2.fromOffset(200,510),ClipsDescendants=true})
	addCorner(modernNav,UDim.new(0,20))
	modernNav.MouseEnter:Connect(function() ui.ModernNavExpanded=true; ui:Fit() end)
	modernNav.MouseLeave:Connect(function() ui.ModernNavExpanded=false; ui:Fit() end)
	local modernLogo=brandMark(modernNav,18,12,41)
	modernLogo.Name='TenacityModernLogo'
	local modernBrand=label(modernNav,'Tenacity',70,20,112,32,20); modernBrand.FontFace=uipallet.FontSemiBold
	local modernVersion=label(modernNav,'5.1',154,28,36,18,12); modernVersion.TextColor3=Color3.fromRGB(98,98,98)
	local modernSeparator=create('Frame',modernNav,{BackgroundColor3=Color3.fromRGB(110,110,110),Position=UDim2.fromOffset(20,70),Size=UDim2.fromOffset(160,2)})
	for index,name in categoryNames do
		local tab=create('TextButton',modernNav,{Name='Category_'..name,Text='',AutoButtonColor=false,BackgroundTransparency=1,Position=UDim2.fromOffset(16,94+(index-1)*60),Size=UDim2.fromOffset(168,36)})
		local icon=categoryIcon(tab,name,0,0,36); icon.Name='CategoryIcon'
		local caption=label(tab,name,54,0,114,36,24); caption.Name='CategoryName'; caption.FontFace=tenacityFont
		tab.Activated:Connect(function() ui.Selected=name; ui.SelectedModule=nil; ui:Render(); persist() end)
		addTooltip(tab,name)
		ui.ModernTabs[name]=tab; ui.Tabs[name]=tab
	end
	local modernHint=label(modernShell,'Click your scroll wheel while hovering a module to change a keybind',220,8,610,28,12); modernHint.TextColor3=Color3.fromRGB(128,134,141); modernHint.TextXAlignment=Enum.TextXAlignment.Center
	local modernList=scroll(modernShell,220,40,610,470); modernList.Name='ModulesPanel'; modernList.BackgroundTransparency=1; modernList.ScrollBarThickness=0
	local modernDetails=scroll(modernShell,840,0,260,510); modernDetails.Name='SettingsPanel'; modernDetails.BackgroundColor3=Color3.fromRGB(47,49,54); modernDetails.ScrollBarThickness=2; modernDetails.Visible=false
	addCorner(modernDetails,UDim.new(0,16))

	-- CompactClickgui.java: 475x300 -> 950x600. Sidebar is 90 -> 180.
	local compactShell=create('Frame',clickgui,{Name='TenacityCompact',BackgroundColor3=Color3.fromRGB(27,27,27),Position=UDim2.fromOffset(250,150),Size=UDim2.fromOffset(950,600),Visible=false})
	addDragHandler(compactShell,nil,40)
	compactShell.InputBegan:Connect(function(input)
		if input.Position.Y-compactShell.AbsolutePosition.Y<40*scale.Scale then ui.CompactDragged=true end
	end)
	local compactNav=create('Frame',compactShell,{Name='CategoryRail',BackgroundColor3=Color3.fromRGB(39,39,39),Size=UDim2.fromOffset(180,600)})
	local compactLogo=brandMark(compactNav,10,10,41); compactLogo.Name='TenacityCompactLogo'
	local compactBrand=label(compactNav,'Tenacity',66,10,108,30,22); compactBrand.FontFace=uipallet.FontSemiBold
	local compactVersion=label(compactNav,'5.1',82,36,44,18,16); compactVersion.TextColor3=Color3.new(1,1,1); compactVersion.TextXAlignment=Enum.TextXAlignment.Center
	create('Frame',compactNav,{BackgroundColor3=Color3.fromRGB(110,110,110),Position=UDim2.fromOffset(10,62),Size=UDim2.fromOffset(160,1)})
	create('Frame',compactNav,{BackgroundColor3=Color3.fromRGB(110,110,110),Position=UDim2.fromOffset(10,519),Size=UDim2.fromOffset(160,1)})
	local compactCatHeight=64
	for index,name in categoryNames do
		local tab=create('TextButton',compactNav,{Name='Category_'..name,Text='',AutoButtonColor=false,BackgroundTransparency=1,Position=UDim2.fromOffset(0,66+(index-1)*compactCatHeight),Size=UDim2.fromOffset(180,compactCatHeight)})
		local caption=label(tab,name,16,0,152,compactCatHeight,16); caption.Name='CategoryName'; caption.FontFace=uipallet.FontSemiBold
		tab.Activated:Connect(function() ui.Selected=name; ui.SelectedModule=nil; ui:Render(); persist() end)
		ui.CompactTabs[name]=tab
	end
	-- CompactClickgui.java only renders the bottom Discord banner when a real Tenacity
	-- DiscordAccount exists. Do not invent a Roblox/Tenacity profile block here.
	local compactList=scroll(compactShell,200,10,730,580); compactList.Name='ModulePanel'; compactList.BackgroundTransparency=1; compactList.ScrollBarThickness=5; compactList.ScrollBarImageColor3=Color3.fromRGB(64,68,75)
	local compactColumns={}
	for i=1,2 do
		compactColumns[i]=create('Frame',compactList,{Name='Column'..i,BackgroundTransparency=1,Position=UDim2.fromOffset((i-1)*365,0),Size=UDim2.fromOffset(345,0),AutomaticSize=Enum.AutomaticSize.Y})
	end

	-- SearchBar.java: a centered 200x25 field at GUI scale 2, not a permanent toolbar.
	local searchHint=label(clickgui,'Do CTRL+F to open the search bar',0,0,470,46,18)
	searchHint.Name='TenacitySearchHint'; searchHint.Position=UDim2.new(0.5,-235,1,-150); searchHint.TextXAlignment=Enum.TextXAlignment.Center; searchHint.TextColor3=Color3.fromRGB(130,130,135); searchHint.ZIndex=40; searchHint.TextTransparency=0.7
	local search=field(clickgui,'Search',0,0,400)
	search.Name='TenacitySearch'; search.Position=UDim2.new(0.5,-200,1,-140); search.Size=UDim2.fromOffset(400,50); search.BackgroundColor3=Color3.fromRGB(17,17,17); search.BackgroundTransparency=1; search.TextSize=24; search.TextXAlignment=Enum.TextXAlignment.Left; search.TextTransparency=1; search.PlaceholderColor3=Color3.fromRGB(150,150,155); search.ZIndex=41
	addCorner(search,UDim.new(0,10))
	local searchIcon=asset('search.png')
	if searchIcon~='' then
		local icon=create('ImageLabel',search,{BackgroundTransparency=1,Image=searchIcon,ImageColor3=muted,Position=UDim2.fromOffset(14,13),Size=UDim2.fromOffset(24,24),ZIndex=42})
		search.TextXAlignment=Enum.TextXAlignment.Left
		search.Text=''
	end
	local searchHover=false
	local function updateSearchVisual()
		local focused=inputService:GetFocusedTextBox()==search or search.Text~=''
		local active=focused or searchHover
		local bottom=focused and -260 or searchHover and -190 or -140
		tween:Tween(search,uiMotionFast,{Position=UDim2.new(0.5,-200,1,bottom),BackgroundTransparency=active and 0.15 or 1,TextTransparency=active and 0 or 1})
		tween:Tween(searchHint,uiMotionFast,{TextTransparency=active and 1 or 0.7})
	end
	local function showSearch() updateSearchVisual() end
	local function hideSearch() updateSearchVisual() end
	search.MouseEnter:Connect(function() searchHover=true; updateSearchVisual() end)
	search.MouseLeave:Connect(function() searchHover=false; updateSearchVisual() end)
	search.Focused:Connect(updateSearchVisual)
	search.FocusLost:Connect(updateSearchVisual)

	local function setExpanded(module)
		if ui.Mode=='Dropdown' then
			ui.Expanded[module.Name]=not ui.Expanded[module.Name]
			ui.SelectedSlider=nil
			local view=ui.ModuleViews[module.Name]
			if view then view.Update(); return end
		elseif ui.Mode=='Modern' then ui.SelectedModule=ui.SelectedModule==module and nil or module end
		ui:Render()
	end
	local function moduleRow(parent,module,mode,index)
		local height=mode=='Modern' and 70 or mode=='Compact' and 40 or 28
		local row=create('TextButton',parent,{Name='Module_'..module.Name,Text='',BackgroundColor3=mode=='Modern' and Color3.fromRGB(47,49,54) or mode=='Compact' and Color3.fromRGB(39,39,39) or Color3.fromRGB(20,20,20),BackgroundTransparency=0,Size=UDim2.new(1,0,0,height),LayoutOrder=index,AutoButtonColor=false})
		local name
		local marker
		local check
		local enabledOverlay
		local bindPill
		if mode=='Modern' then
			addCorner(row,UDim.new(0,10))
			local toggleArea=create('Frame',row,{BackgroundColor3=Color3.fromRGB(68,71,78),Position=UDim2.fromOffset(1,1),Size=UDim2.fromOffset(68,68)}); addCorner(toggleArea,UDim.new(0,10))
			local toggleDot=create('Frame',toggleArea,{BackgroundColor3=Color3.fromRGB(47,49,54),Position=UDim2.fromOffset(24,24),Size=UDim2.fromOffset(20,20)}); addCorner(toggleDot,UDim.new(1,0))
			enabledOverlay=create('Frame',toggleArea,{Name='EnabledAccent',BackgroundColor3=Color3.new(1,1,1),Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
			addCorner(enabledOverlay,UDim.new(0,10)); accent(enabledOverlay)
			check=label(enabledOverlay,'✓',0,0,68,68,30); check.TextXAlignment=Enum.TextXAlignment.Center; check.FontFace=uipallet.FontSemiBold
			local titleWidth=math.min(360,textWidth(cleanText(module.Name),24,tenacityFont))
			name=label(row,cleanText(module.Name),84,0,titleWidth,70,24)
			local descriptionX=110+titleWidth
			local description=label(row,cleanText(module.Tooltip or ''),descriptionX,0,math.max(0,580-descriptionX),70,18)
			description.Name='Description'; description.TextColor3=Color3.fromRGB(128,134,141); description.TextTransparency=1
			description.TextWrapped=true; description.TextTruncate=Enum.TextTruncate.AtEnd
			local settingStrip=create('Frame',row,{BackgroundColor3=Color3.fromRGB(47,49,54),Position=UDim2.new(1,-29,0,1),Size=UDim2.fromOffset(28,68)}); addCorner(settingStrip,UDim.new(0,10))
			for n=0,2 do local dot=create('Frame',settingStrip,{BackgroundColor3=Color3.new(1,1,1),Position=UDim2.fromOffset(9,10+n*20),Size=UDim2.fromOffset(10,10)}); addCorner(dot,UDim.new(1,0)) end
			row.MouseEnter:Connect(function() tween:Tween(description,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0}) end)
			row.MouseLeave:Connect(function() tween:Tween(description,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=1}) end)
		elseif mode=='Compact' then
			name=label(row,cleanText(module.Name),10,0,210,40,15); name.FontFace=uipallet.FontSemiBold
			if module.Bind then
				bindPill=create('TextButton',row,{Text='',AutoButtonColor=false,BackgroundColor3=Color3.fromRGB(64,68,75),Position=UDim2.fromOffset(132,12),Size=UDim2.fromOffset(64,16)})
				addCorner(bindPill,UDim.new(0,3))
				bindPill.Activated:Connect(function() ui.Binding=module.Bind end)
				watch(bindPill,function()
					local text=ui.Binding==module.Bind and '...' or (#module.Bind.Keys>0 and table.concat(module.Bind.Keys,'+') or 'NONE')
					bindPill.Text=text; bindPill.Size=UDim2.fromOffset(math.max(44,math.min(92,#text*8+12)),16)
					bindPill.Position=UDim2.fromOffset(math.min(235,20+#cleanText(module.Name)*7),12)
				end)
			end
			local enabledDot=create('Frame',row,{BackgroundColor3=Color3.fromRGB(64,68,75),Position=UDim2.new(1,-28,0,12),Size=UDim2.fromOffset(16,16)}); addCorner(enabledDot,UDim.new(1,0))
			check=label(enabledDot,'✓',0,0,16,16,12); check.TextXAlignment=Enum.TextXAlignment.Center; check.FontFace=uipallet.FontSemiBold
			marker=enabledDot
		else
			name=label(row,cleanText(module.Name),10,0,168,28,18)
			local arrow=asset('dropdown.png')
			if arrow~='' then
				marker=create('ImageLabel',row,{Name='ExpandArrow',BackgroundTransparency=1,Image=arrow,ImageColor3=Color3.new(1,1,1),Position=UDim2.new(1,-24,0,9),Size=UDim2.fromOffset(14,10),Rotation=ui.Expanded[module.Name] and 180 or 0})
			else
				marker=label(row,'⌄',0,0,24,28,18); marker.Name='ExpandArrow'; marker.Rotation=ui.Expanded[module.Name] and 180 or 0; marker.Position=UDim2.new(1,-28,0,0); marker.TextXAlignment=Enum.TextXAlignment.Center
			end
		end
		if check and iconFont then check.Text='o'; check.FontFace=iconFont end
		local hovered=false
		row.MouseEnter:Connect(function() hovered=true end); row.MouseLeave:Connect(function() hovered=false end)
		row.Activated:Connect(function() module:Toggle() end)
		row.MouseButton2Click:Connect(function() setExpanded(module) end)
		row.InputBegan:Connect(function(input)
			if input.UserInputType==Enum.UserInputType.MouseButton3 and module.Bind then ui.Binding=module.Bind end
		end)
		addTooltip(row,module.Tooltip or '')
		watch(row,function()
			local color=tenacity:GetThemeColor(index*0.035)
			if mode=='Dropdown' then
				local base=module.Enabled and color or Color3.fromRGB(35,37,43)
				local target=hovered and base:Lerp(Color3.new(1,1,1),0.12) or base
				local visualState=tostring(module.Enabled)..tostring(hovered)..target:ToHex()
				if row:GetAttribute('VisualState')~=visualState then
					row:SetAttribute('VisualState',visualState)
					tween:Tween(row,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{BackgroundColor3=target})
				end
				name.FontFace=module.Enabled and uipallet.FontSemiBold or tenacityFont
				name.TextColor3=Color3.new(1,1,1); name.TextTransparency=module.Enabled and 0.1 or 0.5
			else name.TextColor3=Color3.new(1,1,1) end
			if mode=='Modern' and check then
				if enabledOverlay:GetAttribute('Enabled')~=module.Enabled then
					enabledOverlay:SetAttribute('Enabled',module.Enabled)
					tween:Tween(enabledOverlay,TweenInfo.new(0.25),{BackgroundTransparency=module.Enabled and 0 or 1})
					tween:Tween(check,TweenInfo.new(0.25),{TextTransparency=module.Enabled and 0 or 1})
				end
			end
			if mode=='Compact' and marker then marker.BackgroundColor3=module.Enabled and color or Color3.fromRGB(64,68,75); if check then check.TextTransparency=module.Enabled and 0 or 1 end end
		end)
		ui.Rows[module.Name]=row
		return row
	end

	function ui:LayoutModern()
		local navWidth=self.ModernNavExpanded and 200 or 90
		modernNav.Size=UDim2.fromOffset(navWidth,510)
		modernBrand.Visible=self.ModernNavExpanded
		modernVersion.Visible=self.ModernNavExpanded
		modernSeparator.Size=UDim2.fromOffset(math.max(50,navWidth-40),2)
		for _,tab in self.ModernTabs do
			tab.Size=UDim2.fromOffset(navWidth,56)
			local caption=tab:FindFirstChild('CategoryName'); if caption then caption.Visible=self.ModernNavExpanded end
			local icon=tab:FindFirstChild('CategoryIcon')
			if icon then icon.Position=UDim2.fromOffset(self.ModernNavExpanded and 22 or 30,13) end
		end
		local contentX=navWidth+20
		modernHint.Position=UDim2.fromOffset(contentX,8)
		modernList.Position=UDim2.fromOffset(contentX,40)
		local detailOpen=self.SelectedModule~=nil and self.Mode=='Modern'
		modernDetails.Position=UDim2.fromOffset(contentX+620,0)
		modernShell.Size=UDim2.fromOffset(740+(self.ModernNavExpanded and 110 or 0)+(detailOpen and 250 or 0),510)
	end

	function ui:Render()
		self.Rows={}
		self.ModuleViews={}
		local savedScroll={Modern=modernList.CanvasPosition,Details=modernDetails.CanvasPosition,Compact=compactList.CanvasPosition}
		for name,panel in self.Panels do savedScroll[name]=panel.List.CanvasPosition end
		dropdownRoot.Visible=self.Mode=='Dropdown'
		modernShell.Visible=self.Mode=='Modern'
		compactShell.Visible=self.Mode=='Compact'

		for name,tab in self.ModernTabs do
			local selected=name==self.Selected
			tab.BackgroundTransparency=1
			local icon=tab:FindFirstChild('CategoryIcon'); if icon then icon[icon:IsA('ImageLabel') and 'ImageColor3' or 'TextColor3']=selected and tenacity:GetThemeColor(0) or Color3.fromRGB(200,200,205) end
			local caption=tab:FindFirstChild('CategoryName'); if caption then caption.TextColor3=selected and tenacity:GetThemeColor(0) or Color3.fromRGB(205,205,210) end
		end
		for name,tab in self.CompactTabs do
			local selected=name==self.Selected
			tab.BackgroundTransparency=selected and 0 or 1
			tab.BackgroundColor3=Color3.fromRGB(27,27,27)
			local caption=tab:FindFirstChild('CategoryName'); if caption then caption.TextColor3=selected and Color3.new(1,1,1) or Color3.fromRGB(190,190,195) end
		end

		for name,panel in self.Panels do
			hardWipe(panel.List)
			if self.Mode=='Dropdown' then
				local list=stack(panel.List)
				for index,module in getModules(name) do
					local row=moduleRow(panel.List,module,'Dropdown',index*2)
					local wrapper=create('Frame',panel.List,{Name='Settings_'..module.Name,BackgroundColor3=Color3.fromRGB(32,32,32),ClipsDescendants=true,Size=UDim2.new(1,0,0,0),LayoutOrder=index*2+1})
					local holder,settingsLayout
					local function updateExpansion()
						local expanded=self.Expanded[module.Name]==true
						if expanded and not holder then
							holder=create('Frame',wrapper,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
							settingsLayout=self:DrawControls(holder,module,true,'Dropdown')
							settingsLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateExpansion)
						end
						local height=expanded and settingsLayout.AbsoluteContentSize.Y/effectiveScale(holder) or 0
						tween:Tween(wrapper,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(1,0,0,height)})
						local arrow=row:FindFirstChild('ExpandArrow')
						if arrow then tween:Tween(arrow,TweenInfo.new(0.25),{Rotation=expanded and 180 or 0}) end
					end
					self.ModuleViews[module.Name]={Update=updateExpansion,Wrapper=wrapper}
					updateExpansion()
				end
				local function height()
					local actual=list.AbsoluteContentSize.Y/effectiveScale(list.Parent)
					local maxHeight=state.ScrollMode=='Value' and math.clamp(tonumber(state.TabHeight) or 250,100,500)*2 or gui.AbsoluteSize.Y/math.max(scale.Scale,0.01)*2/3
					local h=panel.Expanded and math.min(actual,maxHeight) or 0
					panel.List.Size=UDim2.fromOffset(208,h); panel.List.Visible=panel.Expanded
					tween:Tween(panel.Object,uiMotionFast,{Size=UDim2.fromOffset(210,30+h)})
				end
				list:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(height); height()
			end
		end

		hardWipe(modernList); hardWipe(modernDetails); addCorner(modernDetails,UDim.new(0,16))
		for _,column in compactColumns do hardWipe(column) end
		if self.Mode=='Modern' then
			local list=stack(modernList); list.Padding=UDim.new(0,30)
			for index,module in getModules(self.Selected) do moduleRow(modernList,module,'Modern',index) end
			local selected=self.SelectedModule
			modernDetails.Visible=selected~=nil
			if selected then
				local title=label(modernDetails,cleanText(selected.Name),10,8,240,34,20); title.TextXAlignment=Enum.TextXAlignment.Center; title.FontFace=uipallet.FontSemiBold
				local shadeTop=create('Frame',modernDetails,{BackgroundColor3=Color3.fromRGB(30,31,35),BackgroundTransparency=0.45,Position=UDim2.fromOffset(0,40),Size=UDim2.fromOffset(260,16)})
				local holder=create('Frame',modernDetails,{BackgroundTransparency=1,Position=UDim2.fromOffset(0,56),Size=UDim2.new(1,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y})
				self:DrawControls(holder,selected,false,'Modern')
			end
			self:LayoutModern()
		elseif self.Mode=='Compact' then
			modernDetails.Visible=false
			local heights={0,0}
			for _,column in compactColumns do local list=stack(column); list.Padding=UDim.new(0,20) end
			for index,module in getModules(self.Selected) do
				local side=heights[1]<=heights[2] and 1 or 2
				local card=create('Frame',compactColumns[side],{BackgroundColor3=Color3.fromRGB(35,35,35),Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=index})
				stack(card)
				moduleRow(card,module,'Compact',0)
				local controls=create('Frame',card,{BackgroundColor3=Color3.fromRGB(35,35,35),BackgroundTransparency=0,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=1})
				local layout=self:DrawControls(controls,module,false,'Compact')
				local estimated=40+math.max(0,layout.AbsoluteContentSize.Y/effectiveScale(layout.Parent))+20
				heights[side]+=estimated
			end
		else
			modernDetails.Visible=false
		end
		self:Fit()
		-- Rebuilds are limited to schema/category/search changes. Preserve scroll even
		-- when Roblox adjusts AutomaticCanvasSize while children are being replaced.
		task.defer(function()
			if not modernList.Parent then return end
			modernList.CanvasPosition=savedScroll.Modern; modernDetails.CanvasPosition=savedScroll.Details
			compactList.CanvasPosition=savedScroll.Compact
			for name,panel in self.Panels do panel.List.CanvasPosition=savedScroll[name] end
		end)
	end

	function ui:Fit()
		local viewport=gui.AbsoluteSize/math.max(scale.Scale,0.01)
		local function fitRoot(root,baseW,baseH,dragged)
			local zoom=root:FindFirstChildWhichIsA('UIScale') or create('UIScale',root,{Scale=1})
			zoom.Scale=math.max(0.35,math.min(1,(viewport.X-36)/baseW,(viewport.Y-80)/baseH))
			if not dragged then root.Position=UDim2.fromOffset((viewport.X-baseW*zoom.Scale)/2,(viewport.Y-baseH*zoom.Scale)/2) end
		end
		if self.Mode=='Modern' then
			self:LayoutModern()
			local baseW=740+(self.ModernNavExpanded and 110 or 0)+(self.SelectedModule and 250 or 0)
			fitRoot(modernShell,baseW,510,self.ModernDragged)
		elseif self.Mode=='Compact' then
			fitRoot(compactShell,950,600,self.CompactDragged)
		end
		if self.LayoutSide then self:LayoutSide(false) end
		searchHint.Visible=clickgui.Visible
		search.Visible=clickgui.Visible
	end

	function ui:Arrange()
		local viewport=gui.AbsoluteSize/math.max(scale.Scale,0.01)
		local columns=math.max(1,math.floor((viewport.X-50)/240))
		for index,name in categoryNames do
			local panel=self.Panels[name]
			panel.Object.Position=UDim2.fromOffset(40+((index-1)%columns)*240,40+math.floor((index-1)/columns)*320)
		end
		self.ModernDragged=false; self.CompactDragged=false
		self:Fit()
	end

	function ui:SetMode(mode)
		self.Mode=table.find({'Dropdown','Modern','Compact'},mode) and mode or 'Dropdown'
		self.SelectedModule=nil
		self:Render()
	end
	function ui:Filter() self.Query=search.Text; self:Render() end
	search:GetPropertyChangedSignal('Text'):Connect(function() ui:Filter(); updateSearchVisual() end)
	if tenacity.SearchBar then
		tenacity.SearchBar.Open=function(_,focus) showSearch(); if focus~=false then search:CaptureFocus() end end
		tenacity.SearchBar.Refresh=function() end
		tenacity.SearchBar.Close=function(_,clear) if clear then search.Text='' end; search:ReleaseFocus(); hideSearch() end
	end

	-- Tenacity HUD / notification presentation. Old Tenacity overlay instances remain hidden.
	local hud=create('Frame',scaledgui,{Name='TenacityHUD',BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
	-- HUDMod.java default "Tenacity" watermark: bold name + small version with the client gradient.
	local watermark=label(hud,'Tenacity',10,8,210,48,40); watermark.FontFace=uipallet.FontSemiBold; tenacity:ApplyThemeGradient(watermark,'TextColor3',0,true,0)
	local versionText=label(hud,'5.1',166,10,48,20,16); versionText.TextColor3=muted

	-- ArrayListMod.java defaults: right aligned, width-sorted, dark background (.35 alpha),
	-- black text shadow and a top rectangle using the Tenacity gradient.
	local arraylist=create('Frame',hud,{Name='TenacityArrayList',BackgroundTransparency=1,Position=UDim2.new(1,-4,0,2),AnchorPoint=Vector2.new(1,0),Size=UDim2.fromOffset(520,900)})
	local lastArray=''
	local measureCache={}
	local function measure(text,size,fontFace)
		fontFace=fontFace or tenacityFont
		local key=tostring(fontFace)..'|'..tostring(size)..'|'..text
		if measureCache[key] then return measureCache[key] end
		local params=Instance.new('GetTextBoundsParams')
		params.Text=text; params.Size=size; params.Width=1000; params.Font=fontFace
		local ok,bounds=pcall(function() return textService:GetTextBoundsAsync(params) end)
		params:Destroy()
		local width=ok and math.ceil(bounds.X) or math.ceil(#text*size*0.55)
		measureCache[key]=width
		return width
	end
	local function updateHUD()
		for _,name in {'Text GUI','TextGUI','Dynamic Island'} do local overlay=tenacity.Categories[name]; if overlay and overlay.Object then overlay.Object.Parent=legacy end end
		if tenacity.DynamicIsland and tenacity.DynamicIsland.Object then tenacity.DynamicIsland.Object.Parent=legacy end
		local names={}; for name,module in tenacity.Modules do if module.Enabled then table.insert(names,cleanText(name)) end end
		table.sort(names,function(a,b) return measure(a,20,tenacityFont)>measure(b,20,tenacityFont) end)
		local key=table.concat(names,'\n')
		if key~=lastArray then
			lastArray=key; hardWipe(arraylist)
			for index,name in names do
				local width=measure(name,20,tenacityFont)+10
				local row=create('Frame',arraylist,{Name='Array_'..name,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,(index-1)*24),Size=UDim2.fromOffset(width,24),BackgroundColor3=Color3.fromRGB(10,10,10),BackgroundTransparency=0.65})
				if index==1 then
					local top=create('Frame',row,{Position=UDim2.fromOffset(0,-2),Size=UDim2.new(1,0,0,2),BackgroundColor3=Color3.new(1,1,1)})
					tenacity:ApplyThemeGradient(top,'BackgroundColor3',0,true,0)
				end
				local shadow=label(row,name,5,3,width-8,20,20); shadow.TextXAlignment=Enum.TextXAlignment.Right; shadow.Position=UDim2.fromOffset(6,4); shadow.TextColor3=Color3.new(0,0,0); shadow.TextTransparency=0.15
				local text=label(row,name,5,2,width-8,20,20); text.TextXAlignment=Enum.TextXAlignment.Right
				tenacity:RegisterThemeSolid(text,'TextColor3',(index-1)*0.20)
			end
		end
	end

	-- NotificationsMod.java / Notification.java default: compact rounded cards that slide
	-- from the lower-right, with their fill mixed from black toward the notification color.
	local notificationHost=create('Frame',scaledgui,{Name='TenacityNotifications',BackgroundTransparency=1,Position=UDim2.new(1,-10,1,-36),AnchorPoint=Vector2.new(1,1),Size=UDim2.fromOffset(760,700),ZIndex=200})
	local notificationLayout=stack(notificationHost); notificationLayout.VerticalAlignment=Enum.VerticalAlignment.Bottom; notificationLayout.HorizontalAlignment=Enum.HorizontalAlignment.Right; notificationLayout.Padding=UDim.new(0,16)
	local function notificationType(kind)
		if kind=='disable' then return Color3.fromRGB(255,30,30),'×' end
		if kind=='alert' or kind=='warning' then return Color3.fromRGB(255,225,0),'!' end
		if kind=='info' then return Color3.new(1,1,1),'i' end
		return Color3.fromRGB(20,250,90),'✓'
	end
	function tenacity:CreateNotification(title,message,duration,kind)
		title=cleanText(title); message=cleanText(message)
		local typeColor,glyphText=notificationType(kind)
		local width=math.max(measure(title,22,uipallet.FontSemiBold),measure(message,18,tenacityFont))+70
		-- UIListLayout owns slot placement; the inner card is what slides horizontally.
		local slot=create('Frame',notificationHost,{BackgroundTransparency=1,Size=UDim2.fromOffset(width,56)})
		local card=create('Frame',slot,{BackgroundColor3=Color3.new(0,0,0):Lerp(typeColor,0.65),BackgroundTransparency=0.30,Size=UDim2.fromOffset(width,56),Position=UDim2.fromOffset(width+10,0)})
		addCorner(card,UDim.new(0,8))
		local glyph=label(card,glyphText,10,0,40,56,28); glyph.TextXAlignment=Enum.TextXAlignment.Center; glyph.TextColor3=typeColor; glyph.FontFace=uipallet.FontSemiBold
		local titleLabel=label(card,title,54,6,width-62,24,22); titleLabel.FontFace=uipallet.FontSemiBold
		local body=label(card,message,54,29,width-62,20,18); body.TextColor3=Color3.new(1,1,1)
		tween:Tween(card,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(0,0)})
		task.delay(duration or 2,function()
			if card.Parent then
				tween:Tween(card,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.fromOffset(width+10,0),BackgroundTransparency=1})
				task.delay(0.26,function() if slot.Parent then slot:Destroy() end end)
			end
		end)
	end
	function tenacity:PushDynamicIslandModuleMessage(name,enabled)
		if self.ToggleNotifications and self.ToggleNotifications.Enabled then self:CreateNotification(name,enabled and 'Enabled' or 'Disabled',2,enabled and 'success' or 'disable') end
	end

	-- SideGUI.java: one 550 x 350 surface rendered at 2x, with an 80px
	-- visible dock. The same surface slides into focus; there is no modal backdrop.
	local shade=create('Frame',clickgui,{Name='TenacitySideLayer',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Visible=true,ZIndex=100})
	local sideRoot=create('CanvasGroup',shade,{Name='TenacitySideGUI',BackgroundColor3=Color3.fromRGB(35,35,35),Size=UDim2.fromOffset(1100,700),GroupTransparency=0.3})
	addCorner(sideRoot,UDim.new(0,10))
	local sideFit=create('UIScale',sideRoot,{Scale=1})
	local side=sideRoot
	ui.SideFocused=false
	ui.SideRoot=sideRoot
	local hotbar=create('Frame',side,{Name='SideGUIHotbar',BackgroundColor3=Color3.fromRGB(25,25,25),Size=UDim2.fromOffset(1100,72)})
	addCorner(hotbar,UDim.new(0,10))
	create('Frame',hotbar,{BackgroundColor3=Color3.fromRGB(25,25,25),Position=UDim2.fromOffset(0,64),Size=UDim2.fromOffset(1100,8)})
	local heading=label(hotbar,'Tenacity',19,0,230,72,32); heading.FontFace=uipallet.FontSemiBold
	label(hotbar,'5.1',19+textWidth('Tenacity',32,uipallet.FontSemiBold)-4,10,50,22,18).TextTransparency=0.5
	local function segmented(parent,names,x,y,width,height,get,set)
		local host=create('Frame',parent,{Name='Carousel',BackgroundColor3=Color3.fromRGB(39,39,39),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(width*#names,height)})
		addCorner(host,UDim.new(0,10))
		local selected=create('Frame',host,{Name='Selection',Size=UDim2.fromOffset(width,height)}); addCorner(selected,UDim.new(0,10)); accent(selected)
		local last
		local captions={}
		for i,name in names do
			local b=create('TextButton',host,{Name=name,Text=name,TextSize=24,AutoButtonColor=false,Position=UDim2.fromOffset((i-1)*width,0),Size=UDim2.fromOffset(width,height)})
			b.Activated:Connect(function() set(name) end); captions[name]=b
		end
		watch(host,function()
			local current=get()
			if current~=last then
				last=current
				local index=table.find(names,current) or 1
				tween:Tween(selected,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromOffset((index-1)*width,0)})
			end
			for name,caption in captions do caption.TextTransparency=name==current and 0 or 0.5 end
		end)
		return host
	end
	local carousel=segmented(hotbar,{'Scripts','Configs','Info'},325,15.5,150,41,function() return ui.Page end,function(page) ui:Open(page) end)
	local sideSearch=field(hotbar,'Search',787,15.5,291)
	sideSearch.Name='SideSearch'; sideSearch.Size=UDim2.fromOffset(291,41); sideSearch.TextSize=20; sideSearch.BackgroundColor3=Color3.fromRGB(17,17,17)
	local refresh
	local refreshButton=create('TextButton',hotbar,{Name='Refresh',Text=iconFont and 'D' or '↻',TextSize=20,AutoButtonColor=false,Position=UDim2.fromOffset(748,16),Size=UDim2.fromOffset(30,40)})
	if iconFont then refreshButton.FontFace=iconFont end
	refreshButton.Activated:Connect(function() if refresh then refresh() end end); addTooltip(refreshButton,'Refresh local configs and scripts')
	local pageTitle=label(side,'Configs',16,88,700,48,40); pageTitle.FontFace=uipallet.FontSemiBold
	local body=create('Frame',side,{Name='PanelContent',BackgroundTransparency=1,Position=UDim2.fromOffset(16,140),Size=UDim2.fromOffset(1068,544)})
	local dockCover=create('TextButton',side,{Name='DockFocus',Text='',AutoButtonColor=false,Size=UDim2.fromScale(1,1),ZIndex=140})
	dockCover.Activated:Connect(function() ui:Open(ui.Page or 'Configs') end)
	dockCover.MouseEnter:Connect(function() if not ui.SideFocused then tween:Tween(sideRoot,TweenInfo.new(0.25),{GroupTransparency=0.05}) end end)
	dockCover.MouseLeave:Connect(function() if not ui.SideFocused then tween:Tween(sideRoot,TweenInfo.new(0.25),{GroupTransparency=0.3}) end end)
	function ui:CloseModal()
		if self.Modal then self.Modal:Destroy(); self.Modal=nil; return true end
		return false
	end
	function ui:LayoutSide(animate)
		local viewport=gui.AbsoluteSize/math.max(scale.Scale,0.01)
		sideFit.Scale=math.max(0.2,math.min(1,(viewport.X-24)/1100,(viewport.Y-24)/700))
		local width,height=1100*sideFit.Scale,700*sideFit.Scale
		local x,y=viewport.X-80*sideFit.Scale,(viewport.Y-height)/2
		if self.SideFocused then
			local saved=self.SidePosition
			x=saved and math.clamp(saved.X,0,math.max(0,viewport.X-width)) or (viewport.X-width)/2
			y=saved and math.clamp(saved.Y,0,math.max(0,viewport.Y-height)) or y
		end
		local position=UDim2.fromOffset(x,y)
		if animate then tween:Tween(sideRoot,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=position,GroupTransparency=self.SideFocused and 0 or 0.3})
		else sideRoot.Position=position; sideRoot.GroupTransparency=self.SideFocused and 0 or 0.3 end
		dockCover.Visible=not self.SideFocused
		body.Visible=self.SideFocused; pageTitle.Visible=self.SideFocused
	end
	function ui:Dock()
		self:CloseModal(); self.SideFocused=false; self.Dragging=nil
		sideSearch:ReleaseFocus(); self:LayoutSide(true)
	end
	local dragHeader=create('TextButton',hotbar,{Name='DragHeader',Text='',AutoButtonColor=false,Size=UDim2.fromOffset(245,72)})
	dragHeader.InputBegan:Connect(function(input)
		if not ui.SideFocused or ui.Modal or (tenacity.LockLayout and tenacity.LockLayout.Enabled) then return end
		if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
		local origin,start=sideRoot.Position,input.Position
		ui.Dragging={Input=input,Move=function(position,released)
			local delta=(position-start)/math.max(scale.Scale,0.01)
			sideRoot.Position=UDim2.fromOffset(origin.X.Offset+delta.X,origin.Y.Offset+delta.Y)
			local viewport=gui.AbsoluteSize/math.max(scale.Scale,0.01)
			local snap=sideRoot.Position.X.Offset+825*sideFit.Scale>viewport.X
			sideRoot.GroupTransparency=snap and 0.3 or 0
			if released then
				if snap then ui.SidePosition=nil; ui:Dock()
				else ui.SidePosition=Vector2.new(sideRoot.Position.X.Offset,sideRoot.Position.Y.Offset); ui:LayoutSide(true) end
			end
		end}
	end)
	local searchType=button(hotbar,'Configs',928,20,150,function()
		ui:Open(ui.Page=='Scripts' and 'Configs' or 'Scripts'); sideSearch:CaptureFocus()
	end)
	searchType.Name='SearchType'; searchType.TextSize=18; searchType.Visible=false
	local function searchSide()
		local focused=inputService:GetFocusedTextBox()==sideSearch or sideSearch.Text~=''
		carousel.Visible=not focused; refreshButton.Visible=not focused; searchType.Visible=focused
		searchType.Text=ui.Page=='Scripts' and 'Scripts' or 'Configs'
		tween:Tween(sideSearch,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(focused and 204.5 or 787,15.5),Size=UDim2.fromOffset(focused and 691 or 291,41)})
		ui.ConfigQuery=sideSearch.Text
		if ui.ConfigFilter then ui.ConfigFilter() end
		if ui.ScriptFilter then ui.ScriptFilter() end
	end
	sideSearch.Focused:Connect(searchSide); sideSearch.FocusLost:Connect(searchSide)
	sideSearch:GetPropertyChangedSignal('Text'):Connect(searchSide)
	local function clearBody()
		ui.ConfigFilter=nil; ui.ScriptFilter=nil
		for _,child in body:GetChildren() do child:Destroy() end
	end
	local function message(text, errorMessage)
		tenacity:CreateNotification('Configs', text, 5, errorMessage and 'alert' or 'info')
	end
	local function guard(action)
		if not tenacity.Loaded or tenacity.SwitchingProfile then message('Wait for the current config to finish loading.', true); return end
		local ok, err = pcall(action)
		if not ok then message(tostring(err), true) end
	end
	local function configPath(name) return 'tenacity/profiles/'..name..tenacity.Place..'.txt' end
	local function validName(name)
		return type(name) == 'string' and #name > 0 and #name <= 48 and name:match('^[%w _%-]+$') and name:match('%S')
	end
	local function addConfig(name, data)
		assert(validName(name), 'Use 1-48 letters, numbers, spaces, hyphens or underscores.')
		assert(not tenacity.Categories.Profiles:GetValue(name) and not isfile(configPath(name)), 'A config with that name already exists.')
		writefile(configPath(name), data)
		tenacity.Categories.Profiles:ChangeValue(name)
		tenacity:Save()
		message('Saved '..name)
	end
	local function modal(title,height)
		ui:CloseModal()
		local veil=create('TextButton',side,{Name='FormBackdrop',Text='',AutoButtonColor=false,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.4,Size=UDim2.fromScale(1,1),ZIndex=160})
		ui.Modal=veil
		local cover=create('Frame',veil,{Name='Form',BackgroundColor3=Color3.fromRGB(35,35,35),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(600,height),Active=true})
		addCorner(cover,UDim.new(0,10))
		local heading=label(cover,title,16,10,530,44,32); heading.FontFace=uipallet.FontSemiBold
		button(cover,'×',552,12,32,function() ui:CloseModal() end)
		return cover
	end
	local function form(title,submit,multiline)
		local height=multiline and 440 or 240
		local cover=modal(title,height)
		local inside=create('Frame',cover,{BackgroundColor3=Color3.fromRGB(29,29,29),Position=UDim2.fromOffset(16,60),Size=UDim2.fromOffset(568,height-76)})
		addCorner(inside,UDim.new(0,10))
		label(inside,'Config name',16,8,530,28,24)
		local name=field(inside,'Type here...',16,42,536); name.Size=UDim2.fromOffset(536,40); name.TextSize=18; name.BackgroundColor3=Color3.fromRGB(17,17,17)
		local data
		if multiline then
			data=field(inside,'Paste config JSON',16,96,536); data.Size=UDim2.fromOffset(536,192)
			data.MultiLine=true; data.TextWrapped=true; data.TextYAlignment=Enum.TextYAlignment.Top; data.TextSize=16
		end
		local failure=label(cover,'',20,height-53,560,20,14); failure.TextColor3=Color3.fromRGB(209,56,56)
		local busy=false
		button(cover,'Save',230,height-42,140,function()
			if busy then return end
			busy=true
			local ok,err=pcall(function()
				assert(tenacity.Loaded and not tenacity.SwitchingProfile,'Wait for the current config to finish loading.')
				submit(name.Text:match('^%s*(.-)%s*$'),data and data.Text or '')
			end)
			busy=false
			if ok then ui:CloseModal(); refresh() else failure.Text=tostring(err) end
		end)
		name:CaptureFocus()
	end
	local function exportConfig(name)
		guard(function()
			if name==tenacity.Profile then tenacity:Save() end
			local data=readfile(configPath(name))
			if setclipboard then setclipboard(data); message('Copied '..name..' to clipboard')
			else
				local cover=modal('Copy config JSON',440)
				local box=field(cover,'',16,66,568); box.Size=UDim2.fromOffset(568,314)
				box.MultiLine=true; box.TextWrapped=true; box.Text=data; box.TextYAlignment=Enum.TextYAlignment.Top
				button(cover,'Close',230,396,140,function() ui:CloseModal() end)
				box:CaptureFocus(); box.SelectionStart=1; box.CursorPosition=#data+1
			end
		end)
	end
	function ui:Configs()
		local function saveAs()
			form('Save Config',function(name)
				tenacity:Save(); addConfig(name,readfile(configPath(tenacity.Profile)))
				state.ConfigUpdated=state.ConfigUpdated or {}; state.ConfigUpdated[name]=os.time(); persist()
			end)
		end
		button(body,'Save current config',4,40,170,saveAs).TextSize=18
		button(body,'Import config',190,40,150,function()
			form('Import Config',function(name,data)
				local decoded=httpService:JSONDecode(data)
				assert(type(decoded)=='table' and decoded.v==1 and type(decoded.Modules)=='table' and type(decoded.Categories)=='table','Expected an exported Roblox config.')
				if type(decoded.Auxiliary)=='table' then
					for moduleName,value in decoded.Auxiliary do if decoded.Modules[moduleName]==nil then decoded.Modules[moduleName]=value end end
					decoded.Auxiliary=nil
				end
				for _,entries in {decoded.Modules,decoded.Categories} do
					for key,value in entries do assert(type(key)=='string' and type(value)=='table','Invalid config entry.') end
				end
				addConfig(name,httpService:JSONEncode(decoded))
				state.ConfigUpdated=state.ConfigUpdated or {}; state.ConfigUpdated[name]=os.time(); persist()
			end,true)
		end).TextSize=18
		segmented(body,{'Cloud','Local'},434,40,100,36,function() return self.Local and 'Local' or 'Cloud' end,function(name) self.Local=name=='Local'; refresh() end)
		local sort=button(body,self.ReverseSort and 'Sort: Z–A' or 'Sort: A–Z',884,0,180,function() self.ReverseSort=not self.ReverseSort; refresh() end); sort.TextSize=16
		label(body,'Active: '..tenacity.Profile,766,42,298,30,16).TextXAlignment=Enum.TextXAlignment.Right
		local list=scroll(body,0,92,1068,452); list.Name='ConfigList'; list.BackgroundColor3=Color3.fromRGB(27,27,27); list.ScrollBarThickness=3
		addCorner(list,UDim.new(0,10))
		if not self.Local then
			local title=label(list,'Cloud configs',24,24,1000,40,28); title.FontFace=uipallet.FontSemiBold
			label(list,'Cloud sharing is unavailable in this Lua port.',24,72,1000,32,20).TextColor3=muted
			button(list,'Open local configs',24,122,220,function() self.Local=true; refresh() end)
			return
		end
		local function iconAction(parent,glyph,fallback,x,tip,action,danger)
			local b=create('TextButton',parent,{Name=fallback,Text=iconFont and glyph or fallback,TextSize=iconFont and 20 or 14,AutoButtonColor=false,Position=UDim2.fromOffset(x,44),Size=UDim2.fromOffset(iconFont and 28 or 62,28)})
			if iconFont then b.FontFace=iconFont end
			b.Activated:Connect(action)
			b.MouseEnter:Connect(function() tween:Tween(b,uiMotionFast,{TextColor3=danger and Color3.fromRGB(209,56,56) or tenacity:GetThemeColor(0)}) end)
			b.MouseLeave:Connect(function() tween:Tween(b,uiMotionFast,{TextColor3=Color3.new(1,1,1)}) end)
			addTooltip(b,tip); return b
		end
		local function render()
			local previous=list.CanvasPosition
			for _,child in list:GetChildren() do if not child:IsA('UICorner') then child:Destroy() end end
			local profiles={}
			for _,profile in tenacity.Categories.Profiles.List do
				if profile.Name:lower():find((self.ConfigQuery or ''):lower(),1,true) then table.insert(profiles,profile.Name) end
			end
			table.sort(profiles,function(a,b) if self.ReverseSort then return a:lower()>b:lower() end return a:lower()<b:lower() end)
			for i,name in profiles do
				-- ConfigPanel: (534 - 36) / 3 wide, 38 high, 12-unit gaps.
				local card=create('Frame',list,{Name='Config_'..name,BackgroundColor3=Color3.fromRGB(37,37,37),Position=UDim2.fromOffset(12+(i-1)%3*356,12+math.floor((i-1)/3)*100),Size=UDim2.fromOffset(332,76)})
				addCorner(card,UDim.new(0,10))
				local title=label(card,name,6,6,320,30,26); title.FontFace=uipallet.FontSemiBold
				local updated=(state.ConfigUpdated or {})[name]
				local caption=name==tenacity.Profile and 'Currently active' or updated and ('Updated '..os.date('%b %d, %H:%M',updated)) or 'Local config'
				if iconFont then label(card,caption,8,36,170,20,16).TextColor3=muted end
				local spacing=iconFont and 36 or 72
				local lastX=iconFont and 296 or 262
				iconAction(card,'t','Load',lastX,'Load this config',function()
					guard(function()
						if name==tenacity.Profile then message(name..' is already active')
						elseif tenacity:SwitchProfile(name) then message('Loaded '..name) end
						refresh()
					end)
				end)
				iconAction(card,'u','Save',lastX-spacing,'Update with your current settings',function()
					guard(function()
						tenacity:Save()
						if name~=tenacity.Profile then writeProfile(configPath(name),readfile(configPath(tenacity.Profile))) end
						state.ConfigUpdated=state.ConfigUpdated or {}; state.ConfigUpdated[name]=os.time(); persist(); message('Updated '..name); refresh()
					end)
				end)
				iconAction(card,'C','Export',lastX-spacing*2,'Copy this config to clipboard',function() exportConfig(name) end)
				iconAction(card,'q','Delete',lastX-spacing*3,'Delete this config',function()
					guard(function()
						assert(name~='default' and name~=tenacity.Profile,'Switch to another config before deleting; default is protected.')
						assert(delfile,'This environment cannot delete config files.')
						local cover=modal('Delete Config',240)
						label(cover,'Delete "'..name..'"?',20,72,560,36,22)
						button(cover,'Cancel',144,170,140,function() ui:CloseModal() end)
						button(cover,'Delete',316,170,140,function()
							guard(function()
								assert(name~=tenacity.Profile,'The active config cannot be deleted.')
								tenacity.Categories.Profiles:ChangeValue(name)
								if state.ConfigUpdated then state.ConfigUpdated[name]=nil end
								tenacity:Save(); ui:CloseModal(); refresh()
							end)
						end)
					end)
				end,true)
			end
			if #profiles==0 then label(list,'No matching configs. Save your current config to create one.',24,24,1020,40,20) end
			list.CanvasPosition=previous
		end
		self.ConfigFilter=render
		render()
	end
	function ui:Themes()
		local list = scroll(body, 0, 0, 1068, 544)
		for i, name in themeNames do
			local b = button(list, name, 12 + (i - 1) % 3 * 356, 12 + math.floor((i - 1) / 3) * 80, 332, function() tenacity.GradientTheme:SetValue(name); persist() end)
			b.Size = UDim2.fromOffset(332, 64); b.TextSize=20
			local strip = create('Frame', b, {Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 0, 5), BackgroundColor3 = Color3.new(1, 1, 1)})
			local colors = tenacity:GetThemeColors(name)
			create('UIGradient', strip, {Color = ColorSequence.new(colors[1], colors[#colors])})
		end
	end

	function ui:Settings()
		local navigation=scroll(body,0,0,220,544)
		local content=scroll(body,236,0,832,544)
		local owners={}
		for name,pane in tenacity.Settings do
			if name~='Settings' then table.insert(owners,{Name=cleanText(name),Owner=pane}) end
		end
		for name,category in tenacity.Categories do
			if category.Type=='Overlay' and name~='Dynamic Island' and name~='Text GUI' then table.insert(owners,{Name=cleanText(name),Owner=category}) end
		end
		table.sort(owners,function(a,b) return a.Name<b.Name end)
		local function display(entry)
			wipe(content)
			local caption=label(content,entry.Name,12,6,620,30,20)
			local holder=create('Frame',content,{BackgroundTransparency=1,Position=UDim2.fromOffset(0,44),Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y})
			self:DrawControls(holder,entry.Owner,false)
		end
		for index,entry in owners do button(navigation,entry.Name,4,4+(index-1)*34,164,function() display(entry) end) end
		button(navigation,'Friends',4,4+#owners*34,164,function() self:EditList(content,'Friends') end)
		button(navigation,'Targets',4,38+#owners*34,164,function() self:EditList(content,'Targets') end)
		button(navigation,'Arrange panels',4,72+#owners*34,164,function() self:Arrange(); persist() end)
		button(navigation,'ClickGUI layout',4,106+#owners*34,164,function()
			wipe(content)
			label(content,'ClickGUI layout',12,6,620,30,20)
			label(content,'ClickGui',12,48,180,30,16)
			for index,mode in {'Dropdown','Modern','Compact'} do
				local choice=button(content,mode,190+(index-1)*142,48,132,function() ui:SetMode(mode); persist() end)
				watch(choice,function() choice.TextColor3=ui.Mode==mode and tenacity:GetThemeColor(0) or Color3.new(1,1,1) end)
			end
			label(content,'Scroll Mode',12,100,180,30,16)
			local heightRow=create('Frame',content,{BackgroundTransparency=1,Position=UDim2.fromOffset(0,148),Size=UDim2.new(1,0,0,56)})
			local modeButton=button(content,'',190,100,274,function()
				state.ScrollMode=state.ScrollMode=='Value' and 'Screen Height' or 'Value'
				ui:Render(); persist()
			end)
			watch(modeButton,function()
				modeButton.Text=state.ScrollMode=='Value' and 'Value' or 'Screen Height'
				heightRow.Visible=state.ScrollMode=='Value'
			end)
			track(heightRow,'Tab Height',100,500,function() return tonumber(state.TabHeight) or 250 end,function(value)
				state.TabHeight=value; ui:Render(); persist()
			end,0,0,'Dropdown')
		end)
		if owners[1] then display(owners[1]) end
	end
	function ui:EditList(parent,name)
		wipe(parent)
		local category=tenacity.Categories[name]
		if not category then return end
		label(parent,name,12,8,610,32,22)
		local value=field(parent,'Roblox username',12,50,470)
		button(parent,'Add',494,50,130,function() if value.Text~='' then category:ChangeValue(value.Text); self:EditList(parent,name) end end)
		local list=scroll(parent,12,92,612,330)
		for index,entry in category.List do
			local row=button(list,tostring(entry)..'    ×',4,4+(index-1)*34,598,function() category:ChangeValue(entry); self:EditList(parent,name) end)
			row.TextXAlignment=Enum.TextXAlignment.Left
		end
	end

	function ui:Scripts()
		local list=scroll(body,0,0,1068,544); list.Name='ScriptList'; list.BackgroundColor3=Color3.fromRGB(27,27,27); addCorner(list,UDim.new(0,10))
		local function render()
			for _,child in list:GetChildren() do if not child:IsA('UICorner') then child:Destroy() end end
			local modules={}
			for _,module in tenacity.Modules do
				if module.Category=='Scripts' and module.Name:lower():find((self.ConfigQuery or ''):lower(),1,true) then table.insert(modules,module) end
			end
			table.sort(modules,function(a,b) return a.Name:lower()<b.Name:lower() end)
			for index,module in modules do
				local card=create('Frame',list,{BackgroundColor3=Color3.fromRGB(37,37,37),Position=UDim2.fromOffset(12,12+(index-1)*100),Size=UDim2.fromOffset(1044,88)})
				addCorner(card,UDim.new(0,10))
				local title=label(card,module.Name,12,8,760,30,26); title.FontFace=uipallet.FontSemiBold
				label(card,cleanText(module.Tooltip or ''),12,44,760,28,18).TextColor3=muted
				local toggle=button(card,'',800,28,108,function() module:Toggle() end)
				watch(toggle,function() toggle.Text=module.Enabled and 'Disable' or 'Enable' end)
				button(card,'Settings',918,28,110,function()
					self.Selected='Scripts'; self:SetMode('Modern'); self.SelectedModule=module; self:Render(); self:Dock()
				end)
			end
			if #modules==0 then
				label(list,'No local scripts found',24,24,1000,38,28)
				label(list,'Installed modules in the Scripts category appear here.',24,72,1000,30,20).TextColor3=muted
			end
		end
		self.ScriptFilter=render; render()
	end
	function ui:Info()
		local list=scroll(body,0,0,1068,544); list.BackgroundTransparency=1
		local sections={
			{Title='Configs',Items={
				{'How do I save a config?','Open Configs and choose Save current config. Enter a name and save.'},
				{'How do I update an existing config?','Use the save icon on its card to replace it with your current settings.'},
				{'How do I share a config?','Use the export icon to copy its data. The recipient can use Import config.'},
				{'Where are cloud configs?','Cloud sharing is unavailable in this Lua port. Local configs support saving, loading, import and export.'}
			}},
			{Title='Client controls',Items={
				{'How do I open module settings?','Right-click a module. Dropdown settings expand below it; Modern settings open alongside the list.'},
				{'How do I change a keybind?','Middle-click a module, then press a key. Delete or Escape clears it. Space also clears binds in Modern.'},
				{'How do I search?','Press Ctrl+F for modules. The side panel has its own config and script search.'},
				{'How do I dock the side panel?','Press Escape, or drag its title toward the right edge and release.'}
			}}
		}
		for i,section in sections do
			local card=create('Frame',list,{BackgroundColor3=Color3.fromRGB(27,27,27),Position=UDim2.fromOffset((i-1)*544,0),Size=UDim2.fromOffset(524,0),AutomaticSize=Enum.AutomaticSize.Y})
			addCorner(card,UDim.new(0,10))
			create('UIListLayout',card,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)})
			local title=label(card,section.Title,0,0,524,54,28); title.FontFace=uipallet.FontSemiBold; title.LayoutOrder=0; title.TextXAlignment=Enum.TextXAlignment.Center
			for index,item in section.Items do
				local row=create('Frame',card,{BackgroundTransparency=1,Size=UDim2.fromOffset(524,48),ClipsDescendants=true,LayoutOrder=index})
				local open=false
				local question=button(row,item[1],12,0,500,function()
					open=not open; tween:Tween(row,TweenInfo.new(0.25),{Size=UDim2.fromOffset(524,open and 138 or 48)})
				end)
				question.Size=UDim2.fromOffset(500,44); question.TextSize=18; question.TextXAlignment=Enum.TextXAlignment.Left
				local answer=label(row,item[2],16,52,492,80,18); answer.TextWrapped=true; answer.TextYAlignment=Enum.TextYAlignment.Top; answer.TextColor3=muted
			end
			local footer=create('Frame',card,{BackgroundTransparency=1,Size=UDim2.fromOffset(524,60),LayoutOrder=10})
			button(footer,i==1 and 'Themes' or 'Settings',12,10,500,function() ui:Open(i==1 and 'Themes' or 'Settings') end)
		end
	end
	function ui:Open(page)
		self.Binding=nil; self.SelectedSlider=nil
		self:CloseModal()
		self.Page=page or self.Page or 'Configs'
		clearBody(); pageTitle.Text=self.Page
		local wasFocused=self.SideFocused
		self.SideFocused=true; shade.Visible=true
		if self.Page=='Configs' then self:Configs()
		elseif self.Page=='Themes' then self:Themes()
		elseif self.Page=='Settings' then self:Settings()
		elseif self.Page=='Scripts' then self:Scripts()
		else self:Info() end
		self:LayoutSide(not wasFocused)
		searchSide()
	end
	refresh = function() ui:Open(ui.Page) end


	local firstLoad=true
	local function refreshViews()
		for object,update in ui.ControlViews do
			if object.Parent then update() else ui.ControlViews[object]=nil end
		end
	end
	local elapsed=0
	local previousSchema=''
	tenacity:Clean(runService.Heartbeat:Connect(function(delta)
		elapsed+=delta
		if elapsed<0.1 then return end
		elapsed=0
		updateHUD()
		if clickgui.Visible then
			local names={}
			for name,module in tenacity.Modules do
				local count=0; for _ in optionsOf(module) or {} do count+=1 end
				table.insert(names,name..':'..count..':'..tostring(module.Visible))
			end
			table.sort(names)
			local schema=table.concat(names,'|')
			if schema~=previousSchema then previousSchema=schema; ui:Render() end
			refreshViews()
		end
	end))
	tenacity:Clean(gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() ui:Fit() end))
	tenacity:Clean(scale:GetPropertyChangedSignal('Scale'):Connect(function() ui:Fit() end))
	tenacity:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
		if clickgui.Visible then shade.Visible=true; ui:Render() else ui:Dock(); ui.Dragging=nil; ui.Binding=nil end
	end))
	tenacity:Clean(inputService.InputBegan:Connect(function(input,processed)
		if not clickgui.Visible then return end
		if ui.Binding and input.UserInputType==Enum.UserInputType.Keyboard then
			local key=input.KeyCode
			ui.Binding:SetBind((key==Enum.KeyCode.Escape or key==Enum.KeyCode.Delete or key==Enum.KeyCode.Backspace or (ui.Mode=='Modern' and key==Enum.KeyCode.Space)) and {} or {key.Name})
			ui.Binding=nil
			refreshViews()
			return
		end
		if input.KeyCode==Enum.KeyCode.Escape then
			if ui:CloseModal() then return end
			if ui.SideFocused then
				if sideSearch.Text~='' or inputService:GetFocusedTextBox()==sideSearch then sideSearch.Text=''; sideSearch:ReleaseFocus()
				else ui:Dock() end
			elseif inputService:GetFocusedTextBox() then inputService:GetFocusedTextBox():ReleaseFocus()
			elseif ui.SelectedModule then ui.SelectedModule=nil; ui:Render()
			else tenacity.GUIBind.Triggered:Fire(true) end
			return
		end
		if processed or inputService:GetFocusedTextBox() then return end
		if ui.SelectedSlider and ui.SelectedSlider.Object.Parent and not ui.SideFocused and (input.KeyCode==Enum.KeyCode.Left or input.KeyCode==Enum.KeyCode.Right) then
			ui.SelectedSlider.Adjust(input.KeyCode==Enum.KeyCode.Right and 1 or -1); return
		end
		if (input.KeyCode==Enum.KeyCode.F and (inputService:IsKeyDown(Enum.KeyCode.LeftControl) or inputService:IsKeyDown(Enum.KeyCode.RightControl))) or input.KeyCode==Enum.KeyCode.Slash then
			if ui.SideFocused then sideSearch:CaptureFocus()
			elseif tenacity.SearchBar then tenacity.SearchBar:Open(true) else search:CaptureFocus() end
		elseif input.KeyCode==Enum.KeyCode.S and (inputService:IsKeyDown(Enum.KeyCode.LeftControl) or inputService:IsKeyDown(Enum.KeyCode.RightControl)) then tenacity:QuickSave() end
	end))
	local originalLoad=tenacity.Load
	function tenacity:Load(...)
		local result=originalLoad(self,...)
		if firstLoad then
			firstLoad=false
			-- A one-time visual migration prevents old inherited UI preferences from
			-- overriding the requested Tenacity presentation on first launch.
			if state.Revision~=3 then
				self.GradientTheme:SetValue('Tenacity')
				self.GUIStyle:SetValue('Dropdown')
				ui:Arrange(); state.Revision=3
			else self.GUIStyle:SetValue(state.Mode or 'Dropdown') end
		end
		ui.Initialized=true
		ui:Render(); updateHUD()
		return result
	end
	local originalSave=tenacity.Save
	function tenacity:Save(...)
		originalSave(self,...)
		if self.Loaded then persist() end
	end
	ui.CompactCards=state.CompactCards==true
	ui.Selected=table.find(categoryNames,state.Selected) and state.Selected or 'Combat'
	ui:Arrange()
	if state.Revision==3 and type(state.Positions)=='table' then
		for name,position in state.Positions do
			local panel=ui.Panels[name]
			if panel and type(position)=='table' and type(position.X)=='number' and type(position.Y)=='number' then
				panel.Object.Position=UDim2.fromOffset(position.X,position.Y)
			end
		end
	end
	ui:SetMode(state.Revision==3 and state.Mode or 'Dropdown')
	updateHUD()
end)

return tenacity

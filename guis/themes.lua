-- User-supplied palettes and the shared animated theme renderer.
return function(vape, palette, runService)
	local rgb = Color3.fromRGB
	palette.Themes = {
		Aubergine = {{rgb(170,7,107), rgb(97,4,95)},1,8},
		Aqua = {{rgb(185,250,255), rgb(79,199,200)},6},
		Banana = {{rgb(253,236,177), rgb(255,255,255)},3},
		Blend = {{rgb(71,148,253), rgb(71,253,160)},4,6},
		Blossom = {{rgb(226,208,249), rgb(49,119,115)},9,10},
		Bubblegum = {{rgb(243,145,216), rgb(152,165,243)},8,9},
		['Candy Cane'] = {{rgb(255,0,0), rgb(255,255,255)},1},
		Cherry = {{rgb(187,55,125), rgb(251,211,233)},1,8,9},
		Christmas = {{rgb(255,64,64), rgb(255,255,255), rgb(64,255,64)},1,4},
		Coral = {{rgb(244,168,150), rgb(52,133,151)},2,7,9},
		Creida = {{rgb(156,164,224), rgb(54,57,78)},10},
		['Creida Two'] = {{rgb(154,202,235), rgb(88,130,161)},10},
		['Digital Horizon'] = {{rgb(95,195,228), rgb(229,93,135)},1,6,9},
		Express = {{rgb(173,83,137), rgb(60,16,83)},8,9},
		Gothic = {{rgb(31,30,30), rgb(196,190,190)},10},
		Halogen = {{rgb(255,65,108), rgb(255,75,43)},1,2},
		Hyper = {{rgb(236,110,173), rgb(52,148,230)},6,7,9},
		Legacy = {{rgb(112,206,255), rgb(112,206,255)},6,7},
		['Lime Water'] = {{rgb(18,255,247), rgb(179,255,171)},4,6},
		Lush = {{rgb(168,224,99), rgb(86,171,47)},4,5},
		Magic = {{rgb(74,0,224), rgb(142,45,226)},7,8},
		May = {{rgb(170,7,107), rgb(238,79,238)},8,9},
		['Orange Juice'] = {{rgb(252,74,26), rgb(247,183,51)},2,3},
		Pastel = {{rgb(243,155,178), rgb(207,196,243)},9},
		Peony = {{rgb(226,208,249), rgb(207,171,255)},9,10},
		Pumpkin = {{rgb(241,166,98), rgb(255,216,169), rgb(227,139,42)},2},
		Purple = {{rgb(82,67,145), rgb(117,95,207)},8},
		Rainbow = {{rgb(255,255,255), rgb(255,255,255)},10},
		Rue = {{rgb(234,118,176), rgb(31,30,30)},9},
		Satin = {{rgb(215,60,67), rgb(140,23,39)},1},
		Shadow = {{rgb(97,131,255), rgb(206,212,255)},6},
		['Snowy Sky'] = {{rgb(1,171,179), rgb(234,234,234), rgb(18,232,232)},6,10},
		['Steel Fade'] = {{rgb(66,134,244), rgb(55,59,68)},7,10},
		Sundae = {{rgb(206,74,126), rgb(122,44,77)},1,8,9},
		Sunkist = {{rgb(242,201,76), rgb(242,153,74)},2,3},
		Water = {{rgb(12,232,199), rgb(12,163,232)},6,7},
		Winter = {{rgb(255,255,255), rgb(255,255,255)},10},
		Wood = {{rgb(79,109,81), rgb(170,139,87), rgb(240,235,206)},5}
	}
	palette.ThemeColors = {rgb(248,57,57),rgb(250,128,55),rgb(252,255,53),rgb(128,255,50),rgb(50,128,50),rgb(50,200,255),rgb(50,105,200),rgb(128,52,255),rgb(255,128,255),rgb(100,100,110)}
	palette.ThemeObjects = {}
	local engine = {Names = {'Custom'}}
	for name in palette.Themes do table.insert(engine.Names, name) end
	table.sort(engine.Names, function(a,b)
		if a == b then return false end
		if a == 'Custom' then return true end
		if b == 'Custom' then return false end
		return a < b
	end)
	local elapsed = 0
	local colorUpdateElapsed = 0
	local previousTheme = 'Custom'

	function engine:IsActive()
		return vape.Theme ~= nil and palette.Themes[vape.Theme.Value] ~= nil
	end
	function engine:GetColor(offset)
		if self:IsActive() then return engine.Sample(vape.Theme.Value, elapsed / 8 + (offset or 0)) end
		return Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
	end

	function engine.Sample(name, position)
		if name == 'Rainbow' then return Color3.fromHSV(position % 1, 0.75, 1) end
		local colors = palette.Themes[name][1]
		-- Ping-pong through every supplied stop; equal endpoints stay unchanged.
		local phase = (1 - math.cos(position * math.pi * 2)) / 2 * (#colors - 1)
		local index = math.min(math.floor(phase) + 1, #colors - 1)
		return colors[index]:Lerp(colors[index + 1], phase - (index - 1))
	end

	function engine:Register(object, mode, active, foreground)
		palette.ThemeObjects[object] = {Mode = mode, Active = active, Foreground = foreground}
	end
	local function restore(object, entry)
		if not entry.Original then return end
		for property, value in entry.Original do object[property] = value end
		if entry.OwnGradient then entry.Gradient:Destroy()
		elseif entry.Gradient then
			for property, value in entry.GradientOriginal do entry.Gradient[property] = value end
		end
		entry.Original, entry.Gradient, entry.GradientOriginal, entry.OwnGradient = nil, nil, nil, nil
	end
	function engine:Update(dt)
		elapsed += dt * (vape.ThemeSpeed and vape.ThemeSpeed.Value or 1)
		local name = vape.Theme and vape.Theme.Value or 'Custom'
		local enabled = palette.Themes[name] ~= nil
		colorUpdateElapsed += dt
		-- Drive all existing GUI accent callbacks without changing the saved custom color.
		local refreshColors = vape.Loaded == true and vape.UpdateGUIQueue and (enabled or previousTheme ~= name) and (dt == 0 or colorUpdateElapsed >= 1 / 30 or previousTheme ~= name)
		if refreshColors then
			colorUpdateElapsed = 0
			if enabled then vape:UpdateGUIQueue(self:GetColor():ToHSV()) end
		end
		previousTheme = name
		local keys, darkKeys = {}, {}
		if enabled then
			for index = 0, 4 do
				local value = engine.Sample(name, elapsed / 8 + index / 8)
				keys[index + 1] = ColorSequenceKeypoint.new(index / 4, value)
				darkKeys[index + 1] = ColorSequenceKeypoint.new(index / 4, palette.Main:Lerp(value, 0.18))
			end
		end
		local sequence = enabled and ColorSequence.new(keys)
		local darkSequence = enabled and ColorSequence.new(darkKeys)
		for object, entry in palette.ThemeObjects do
			if not object.Parent then
				palette.ThemeObjects[object] = nil
			elseif not enabled or (entry.Active and not entry.Active()) then
				restore(object, entry)
				if entry.Mode == 'hud' then object.BackgroundColor3 = self:GetColor() end
			else
				local property = entry.Mode == 'image' and 'ImageColor3' or 'BackgroundColor3'
				if (entry.Mode == 'module' or entry.Mode == 'accent') and vape.Libraries and vape.Libraries.tween then
					vape.Libraries.tween:Cancel(object)
				end
				if not entry.Original then
					entry.Original = {[property] = object[property]}
					if entry.Mode == 'module' then entry.Original.TextColor3 = object.TextColor3 end
					entry.Gradient = object:FindFirstChildWhichIsA('UIGradient')
					if entry.Gradient then
						entry.GradientOriginal = {Color = entry.Gradient.Color, Rotation = entry.Gradient.Rotation, Enabled = entry.Gradient.Enabled}
					else
						entry.Gradient = Instance.new('UIGradient')
						entry.Gradient.Name = 'AnimatedTheme'
						entry.Gradient.Parent = object
						entry.OwnGradient = true
					end
				end
				object[property] = Color3.new(1,1,1)
				entry.Gradient.Enabled = true
				entry.Gradient.Color = entry.Mode == 'background' and darkSequence or sequence
				entry.Gradient.Rotation = 25 + math.sin(elapsed / 4) * 20
				if entry.Mode == 'module' then
					local color = engine.Sample(name, elapsed / 8 + 0.25)
					object.TextColor3 = color.R * 0.299 + color.G * 0.587 + color.B * 0.114 > 0.6 and rgb(24,24,24) or rgb(255,255,255)
					if entry.Foreground then entry.Foreground(object.TextColor3) end
				end
			end
		end
		if refreshColors and not enabled then vape:UpdateGUIQueue(self:GetColor():ToHSV()) end
	end
	function engine:Start()
		vape:Clean(runService.RenderStepped:Connect(function(dt) self:Update(dt) end))
		vape:Clean(function()
			for object, entry in palette.ThemeObjects do
				if object.Parent then restore(object, entry) end
			end
			table.clear(palette.ThemeObjects)
		end)
	end
	return engine
end

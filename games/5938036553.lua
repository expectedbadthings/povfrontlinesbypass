-- Femboy Shaders

-- Femboy Shaders: cosmetic-only shader presets
-- These presets only modify local Lighting/post-processing visuals.
local FemboyShaderPresets = {
    Dreamy = {
        Brightness = 2,
        Contrast = 0.12,
        Saturation = 0.18,
        BloomIntensity = 0.28,
        BloomSize = 24,
        BloomThreshold = 1.05,
        ColorShift = Color3.fromRGB(255, 205, 245),
    },
    Neon = {
        Brightness = 1.5,
        Contrast = 0.28,
        Saturation = 0.35,
        BloomIntensity = 0.55,
        BloomSize = 32,
        BloomThreshold = 0.85,
        ColorShift = Color3.fromRGB(210, 225, 255),
    },
    Soft = {
        Brightness = 2.5,
        Contrast = 0.04,
        Saturation = 0.08,
        BloomIntensity = 0.16,
        BloomSize = 18,
        BloomThreshold = 1.2,
        ColorShift = Color3.fromRGB(255, 235, 250),
    },
}

local function ApplyFemboyShaderPreset(name)
    local preset = FemboyShaderPresets[name]
    if not preset then return end

    local lighting = game:GetService("Lighting")
    lighting.Brightness = preset.Brightness
    lighting.ColorShift_Top = preset.ColorShift

    local color = lighting:FindFirstChild("FemboyShaderColor")
    if not color then
        color = Instance.new("ColorCorrectionEffect")
        color.Name = "FemboyShaderColor"
        color.Parent = lighting
    end
    color.Contrast = preset.Contrast
    color.Saturation = preset.Saturation
    color.Brightness = 0

    local bloom = lighting:FindFirstChild("FemboyShaderBloom")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "FemboyShaderBloom"
        bloom.Parent = lighting
    end
    bloom.Intensity = preset.BloomIntensity
    bloom.Size = preset.BloomSize
    bloom.Threshold = preset.BloomThreshold
end

-- Cosmetic-only Lua build; gameplay-affecting cheats and automation have been removed.
-- Retained: visual/cosmetic modules only (shaders, viewmodel/gun cosmetics,
-- custom knife, sky themes, fireflies, local VFX test dummy, headshot sound,
-- camera comfort/third-person visuals, and ammo HUD).
--
-- Local customization: additive Legit speed (+1.7 studs/second).
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local REPO_RAW = 'https://raw.githubusercontent.com/expectedbadthings/povfrontlinesbypass/main/'

local function invalidDownload(data, path)
	if type(data) ~= 'string' or data == '' then return true end
	local head = data:sub(1, 512):lower()
	if head:find('404: not found', 1, true)
		or head:find('<!doctype html', 1, true)
		or head:find('<html', 1, true)
		or head:find('<svg', 1, true)
		or head:find('repository not found', 1, true) then
		return true
	end
	if path and path:match('%.lua$') and head:match('^%s*<') then
		return true
	end
	return false
end

local function validCachedFile(path)
	if not isfile(path) then return false end
	local ok, data = pcall(readfile, path)
	return ok and not invalidDownload(data, path)
end

local function downloadFile(path, func)
	if shared.VapeRuntime then return shared.VapeRuntime.Read(path, func) end
	if not validCachedFile(path) then
		local remotePath = select(1, path:gsub('newvape/', ''))
		local suc, res = pcall(function()
			return game:HttpGet(REPO_RAW..remotePath, true)
		end)
		if not suc or invalidDownload(res, path) then
			error('Failed to download '..remotePath..' from GitHub: '..tostring(res), 2)
		end
		if path:find('.lua', 1, true) then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local runService = cloneref(game:GetService('RunService'))
local tweenService = cloneref(game:GetService('TweenService'))
local debrisService = cloneref(game:GetService('Debris'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local vape = shared.vape
local impactVisuals = assert(loadstring(downloadFile('newvape/libraries/frontlines-effects.lua'), 'Frontlines effects'))()(vape)
local entitylib = vape.Libraries.entity
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local getvapeasset = vape.Libraries.getvapeasset
local drawingactor = loadstring(downloadFile('newvape/libraries/drawing.lua'), 'drawing')(...)
local function notif(...)
	return vape:CreateNotification(...)
end

if not select(1, ...) and game.PlaceId == 5938036553 then
	if run_on_actor and getactors then
		local oldreload = shared.vapereload
		vape.Load = function()
			task.delay(0.1, function()
				vape:Uninject()
			end)
		end

		task.spawn(function()
			repeat task.wait() until not shared.vape
			local executionString = "loadfile('newvape/main.lua')("..drawingactor..")"
			for i, v in shared do
				if type(v) == 'string' then
					executionString = string.format("shared.%s = '%s'", i, v)..'\n'..executionString
				elseif type(v) == 'boolean' then
					executionString = string.format("shared.%s = %s", i, tostring(v))..'\n'..executionString
				end
			end
			if oldreload then
				executionString = 'shared.vapereload = true\n'..executionString
			end

			for i, v in getactors() do
				if tostring(v) == 'frontlines_client_actor' then
					run_on_actor(v, executionString)
					return
				end
			end
			notif('Vape', 'Failed to find actor', 10, 'alert')
		end)
	else
		vape.Load = function()
			notif('Vape', 'Missing actor functions.', 10, 'alert')
		end
	end

	return
end

local frontlines = {Functions = {}}
frontlines.KillEffectEvent = Instance.new('BindableEvent')
frontlines.LocalBulletEvent = Instance.new('BindableEvent')
frontlines.LocalHitEvent = Instance.new('BindableEvent')
frontlines.LastLocalHit = nil

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getvapeasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function getTeam(ent)
	return frontlines.Main.globals.cli_teams[ent.Id]
end

local function getKey(id, server)
	for i, v in frontlines.Main.enums[(server and 's' or 'c')..'_net_msg'] do
		if v == id then
			return i
		end
	end
end

local function hookEvent(id, rfunc)
	local suc, res = pcall(function()
		local func = frontlines.Events[frontlines.Main.exe_func_t[id]]
		local hook

		local function newFunc(...)
			if rfunc(...) then return end
			return hook(...)
		end

		hook = hookfunction(func, function(...) return newFunc(...) end)
		frontlines.Functions[func] = hook
		return function()
			if not frontlines.Functions[func] then return end
			--restorefunction(func)
			hookfunction(func, frontlines.Functions[func])
			frontlines.Functions[func] = nil
		end
	end)

	if not suc then
		notif('Vape', 'Failed to hook ('..id..')', 10, 'alert')
	end

	return type(res) == 'function' and res or function() end
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

run(function()
	repeat
		if not frontlines.ShootFunction then
			local gc = getgc(true)
			for _, v in gc do
				if type(v) == 'table' then
					if rawget(v, 'script') and v._G and v._G.append_exe_set then
						frontlines.Main = v._G
					end
				elseif type(v) == 'function' and islclosure(v) then
					local name = debug.info(v, 'n')
					if name == 'spawn_bullet' and debug.getinfo(v).nups > 11 then
						frontlines.ShootFunction = v
						frontlines.ShootRay = typeof(debug.getupvalue(v, 6)) == 'RaycastParams' and debug.getupvalue(v, 6) or debug.getupvalue(v, 5)
					elseif name == 'on_melee_hit' then
						frontlines.KnifeFunction = v
					elseif name == 'spawn_throwable' then
						frontlines.SpawnThrowable = v
						frontlines.Throwables = debug.getupvalue(v, 1)
					end
				end
			end
			table.clear(gc)
		end

		if not (frontlines.ShootFunction and (game.PlaceId == 5938036553 or game.StarterGui:GetCore('ResetButtonCallback') == false)) then
			task.wait(1)
		else
			break
		end
	until vape.Loaded == nil
	if vape.Loaded == nil then return end
	frontlines.Events = debug.getupvalue(frontlines.Main.append_exe_set, 1)
	frontlines.PickupBit = debug.getupvalue(frontlines.Events[frontlines.Main.exe_func_t.INIT_FPV_SOL_AMMO_PICKUP], 5)
	--frontlines.Chat = debug.getupvalue(frontlines.Events[frontlines.Main.exe_func_t.UPDATE_CHAT_GUI], 1)

	-- One shared FPV bullet hook. Modules listen to LocalBulletEvent / LocalHitEvent instead of
	-- stacking hookfunction calls on SPAWN_FPV_SOL_BULLET.
	hookEvent('SPAWN_FPV_SOL_BULLET', function(id, btype, origin, velocity)
		if frontlines.LocalBulletEvent then
			frontlines.LocalBulletEvent:Fire(id, btype, origin, velocity)
		end
		task.defer(function()
			if not frontlines.ResolveBulletHit then return end
			local ent, ray, headshot = frontlines.ResolveBulletHit(origin, velocity)
			if ent and ray then
				frontlines.LastLocalHit = {
					Id = ent.Id,
					Time = tick(),
					Headshot = headshot,
					Position = ray.Position
				}
				if frontlines.LocalHitEvent then
					frontlines.LocalHitEvent:Fire(ent, ray.Position, headshot, ray.Instance)
				end
			end
		end)
	end)

	local kills = sessioninfo:AddItem('Kills')
	local deaths = sessioninfo:AddItem('Deaths')

	hookEvent('SET_CLI_MATCH_KILLS', function(id)
		if id == frontlines.Main.globals.cli_state.fpv_sol_id then
			kills:Increment()
			if frontlines.KillEffectEvent then
				frontlines.KillEffectEvent:Fire()
			end
		end
	end)

	hookEvent('PLAY_FPV_SOL_DEATH_SOUND', function(self, id)
		if id == frontlines.Main.globals.cli_state.fpv_sol_id then
			deaths:Increment()
		end
	end)

	hookEvent('SET_GBL_SOL_HEALTH', function(id, health)
		local entity = entitylib.getEntity(id)
		if entity then
			entity.Health = health
			entitylib.Events.EntityUpdated:Fire(entity)
		end
	end)

	hookEvent('INIT_SOLDIER_MODEL', function(id)
		entitylib.refreshEntity(frontlines.Main.globals.soldier_models[id], id)
	end)

	hookEvent('DEINIT_SOL_STATE', function(id)
		entitylib.refreshEntity(frontlines.Main.globals.soldier_models[id], id)
	end)

	hookEvent('SET_CLI_TEAM', function(id)
		task.defer(function()
			entitylib.refreshEntity(frontlines.Main.globals.soldier_models[id], id)
		end)
	end)

	--[[if game.PlaceId == 5938036553 then
		hookEvent('UPDATE_CHAT_GUI', function(id, text)
			text = string.unpack('z', text)
			task.delay(0, function()
				local name = frontlines.Main.globals.cli_names[id]
				local plr = playersService:FindFirstChild(name)
				if not plr then return end
				for i, v in frontlines.Chat do
					if v.TextLabel.TextTransparency > 0.5 and v.TextLabel.Text:find(name) then
						v.TextLabel.Text = whitelist:tag(plr, true, true)..v.TextLabel.Text
						whitelist:process(text, plr)
						break
					end
				end
			end)
		end)
	end]]

	vape:Clean(Drawing.kill or function() end)
	vape:Clean(function()
		if frontlines.KillEffectEvent then frontlines.KillEffectEvent:Destroy() end
		if frontlines.LocalBulletEvent then frontlines.LocalBulletEvent:Destroy() end
		if frontlines.LocalHitEvent then frontlines.LocalHitEvent:Destroy() end
		for i, v in frontlines.Functions do
			hookfunction(i, v)
		end
		table.clear(frontlines.Functions)
		table.clear(frontlines)
	end)
end)
if vape.Loaded == nil then return end

run(function()
	entitylib.Wallcheck = function(origin, position, ignoreobject)
		local ray = workspace.Raycast(workspace, origin, (position - origin), frontlines.ShootRay)
		return ray and ray.Instance and (ray.Instance == workspace.Terrain or ray.Instance:IsDescendantOf(workspace.workspace)) or false
	end

	entitylib.targetCheck = function(ent)
		if ent.Player then
			if isFriend(ent.Player) then return false end
			if not select(2, whitelist:get(ent.Player)) then return false end
		end

		return getTeam({Id = frontlines.Main.globals.cli_state.id}) ~= getTeam(ent)
	end

	entitylib.getEntityColor = function(ent)
		if not (ent.Player and vape.Settings.Modules.Options['Use team color'].Enabled) then return end
		if isFriend(ent.Player, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return getTeam({Id = frontlines.Main.globals.cli_state.id}) == getTeam(ent) and Color3.fromRGB(67, 140, 229) or Color3.fromRGB(234, 50, 50)
	end

	entitylib.getEntity = function(char)
		for i, v in entitylib.List do
			if v.Id == char then
				return v, i
			end
		end
	end

	entitylib.addEntity = function(char, id, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local plr
			if game.PlaceId == 5938036553 then
				plr = playersService:FindFirstChild(frontlines.Main.globals.cli_names[id])
			else
				plr = playersService:GetPlayerByUserId(frontlines.Main.globals.cli_user_ids[id] or -1)
			end

			if not id or not frontlines.Main.globals.soldiers_alive[id] then
				entitylib.EntityThreads[char] = nil
				return
			end

			local hum = {
				HipHeight = 2,
				MoveDirection = Vector3.zero,
				Health = 100,
				MaxHealth = 100,
				GetState = function()
					return Enum.HumanoidStateType.Running
				end
			}

			if plr == lplr then
				repeat
					hum = frontlines.Main.globals.fpv_sol_instances.humanoid
					task.wait()
				until hum or not frontlines.Main
				if not frontlines.Main then
					entitylib.EntityThreads[char] = nil
					return
				end
			end

			local humrootpart = char:WaitForChild('HumanoidRootPart', 10)
			local head = humrootpart and setmetatable({Name = 'Head', Size = Vector3.one, Parent = char}, {__index = function(t, k)
				if k == 'Position' then
					return humrootpart.Position + Vector3.new(0, 3, 0)
				elseif k == 'CFrame' then
					return humrootpart.CFrame + Vector3.new(0, 3, 0)
				end
			end})

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = hum.Health,
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Id = id,
					MaxHealth = hum.MaxHealth,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
				else
					entity.Targetable = entitylib.targetCheck(entity)
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end
			end

			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.refreshEntity = function(char, id)
		entitylib.removeEntity(id)
		entitylib.addEntity(char, id)
	end

	entitylib.refresh = function()
		local cloned = table.clone(entitylib.List)
		for _, v in cloned do
			entitylib.refreshEntity(v.Character, v.Id)
		end
		table.clear(cloned)
	end

	entitylib.start = function()
		if entitylib.Running then
			entitylib.stop()
		end

		for id, actor in frontlines.Main.soldier_actors do
			if actor.main.model.Value then
				entitylib.refreshEntity(actor.main.model.Value, id)
			end
		end

		table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end))

		entitylib.Running = true
	end
end)

-- Resolve the local FPV bullet ray back to a Vape entity and classify the hit as a headshot.
-- Frontlines' hitboxes are not guaranteed to literally be named "Head", so Smart detection
-- falls back to the hit position relative to the soldier root/head proxy.
frontlines.ResolveBulletHit = function(origin, velocity)
	if typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' or velocity.Magnitude <= 0.001 then
		return
	end

	local ray = workspace:Raycast(origin, velocity.Unit * 1000, frontlines.ShootRay)
	if not ray or not ray.Instance then return end

	local hit = ray.Instance
	local ent
	local matchedHitbox
	local hash = frontlines.Main and frontlines.Main.globals and frontlines.Main.globals.soldier_hitbox_hash

	if hash then
		for hitbox, id in hash do
			if typeof(hitbox) == 'Instance' and (hit == hitbox or hit:IsDescendantOf(hitbox)) then
				matchedHitbox = hitbox
				ent = entitylib.getEntity(id)

				if not ent then
					local weld = hitbox:FindFirstChild('Weld')
					local root = weld and weld.Part0
					if root then
						if entitylib.character and root == entitylib.character.RootPart then
							ent = entitylib.character
						else
							for _, candidate in entitylib.List do
								if candidate.RootPart == root then
									ent = candidate
									break
								end
							end
						end
					end
				end
				break
			end
		end
	end

	if not ent then
		for _, candidate in entitylib.List do
			if candidate.Character and hit:IsDescendantOf(candidate.Character) then
				ent = candidate
				break
			end
		end
	end

	if not ent or ent == entitylib.character or ent.Targetable == false then return end

	local function hasHeadName(obj)
		local depth = 0
		while obj and depth < 5 do
			if tostring(obj.Name):lower():find('head', 1, true) then
				return true
			end
			obj = obj.Parent
			depth += 1
		end
		return false
	end

	local headshot = hasHeadName(hit) or hasHeadName(matchedHitbox)
	if not headshot and ent.RootPart then
		local headpos = ent.Head and ent.Head.Position or (ent.RootPart.Position + Vector3.new(0, 3, 0))
		local relativeY = ray.Position.Y - ent.RootPart.Position.Y
		headshot = relativeY >= 2.0 or (ray.Position - headpos).Magnitude <= 1.35
	end

	return ent, ray, headshot, matchedHitbox
end

entitylib.start()




run(function()
	-- High-end shader-pack inspired lighting. Roblox cannot provide hardware ray tracing here,
	-- so this builds the look from physically-inspired lighting, atmosphere and post processing.
	local lighting = game:GetService('Lighting')
	local tweens = game:GetService('TweenService')
	local runService = game:GetService('RunService')
	local rgb = Color3.fromRGB

	local RTXShaders, Preset, Strength, Exposure, Bloom, Rays, Haze, DOF, Smooth, CustomTime, Time
	local ShadowDepth, Sunlight, SaturationBoost, Vibrance, FogPower, Motion
	local active, ready = false, false
	local original, effects, owned, suppressed, atmospheres, connections, animations = {}, {}, {}, {}, {}, {}, {}
	local cameraConnection, motionConnection
	local holding = Instance.new('Folder')
	holding.Name = 'RTXShaders_OriginalAtmospheres'

	local names = {
		'Complementary Reimagined', 'SEUS PTGI', 'BSL Ultra', 'Sildurs Vibrant', 'Continuum',
		'Photon', 'Rethinking Voxels', 'Insanity', 'AstraLex', 'Super Duper Vanilla',
		'Golden Hour', 'Dreamy Sunset', 'Blue Hour', 'Crystal Day', 'Overcast',
		'Rainy Film', 'Midnight', 'Night time', 'Moonlit', 'Cyberpunk', 'Blood Moon',
		'Emerald Night', 'Arctic', 'Desert Heat', 'Cotton Candy', 'Cinematic',
		'Noir', 'Vintage Film', 'Dark Fantasy', 'Heaven', 'Void'
	}

	-- Every preset intentionally changes more than tint: direct light, ambient fill, shadow feel,
	-- specular response, atmospheric scattering, bloom profile, DOF and fog are all independent.
	local presets = {
		['Complementary Reimagined'] = {Time=14.7,Sun=4.3,Exposure=-0.16,Ambient=rgb(31,45,63),Outdoor=rgb(105,137,160),Top=rgb(255,242,211),Bottom=rgb(10,15,24),Softness=.25,Diffuse=.72,Specular=.96,Contrast=.27,Saturation=.28,Tint=rgb(247,252,255),Grade=.008,Bloom=.34,Threshold=1.42,Size=20,Halo=.08,HaloThreshold=1.8,Rays=.08,Spread=.82,Density=.22,Offset=.21,Air=rgb(184,220,248),Decay=rgb(83,120,164),Glare=.3,Haze=1.15,Fog=rgb(178,213,238),FogStart=550,FogEnd=5000,DOFFar=.07,Focus=105,Radius=90},
		['SEUS PTGI'] = {Time=16.1,Sun=4.7,Exposure=-.25,Ambient=rgb(24,31,43),Outdoor=rgb(92,108,127),Top=rgb(255,219,161),Bottom=rgb(5,8,14),Softness=.18,Diffuse=.58,Specular=1,Contrast=.33,Saturation=.2,Tint=rgb(255,244,224),Grade=.006,Bloom=.43,Threshold=1.3,Size=24,Halo=.12,HaloThreshold=1.62,Rays=.14,Spread=.78,Density=.25,Offset=.17,Air=rgb(217,229,240),Decay=rgb(101,116,145),Glare=.58,Haze=1.55,Fog=rgb(205,220,234),FogStart=500,FogEnd=4300,DOFFar=.09,Focus=95,Radius=78},
		['BSL Ultra'] = {Time=16.75,Sun=3.7,Exposure=-.10,Ambient=rgb(50,45,68),Outdoor=rgb(132,112,139),Top=rgb(255,201,151),Bottom=rgb(15,8,22),Softness=.78,Diffuse=.75,Specular=.92,Contrast=.2,Saturation=.18,Tint=rgb(255,236,220),Grade=.018,Bloom=.58,Threshold=1.08,Size=34,Halo=.2,HaloThreshold=1.35,Rays=.095,Spread=.93,Density=.30,Offset=.14,Air=rgb(242,214,201),Decay=rgb(138,108,148),Glare=.58,Haze=2.15,Fog=rgb(222,196,198),FogStart=350,FogEnd=3500,DOFFar=.11,Focus=82,Radius=70},
		['Sildurs Vibrant'] = {Time=15.5,Sun=4.5,Exposure=-.04,Ambient=rgb(37,47,62),Outdoor=rgb(112,146,166),Top=rgb(255,230,181),Bottom=rgb(7,13,18),Softness=.35,Diffuse=.78,Specular=1,Contrast=.25,Saturation=.48,Tint=rgb(255,246,227),Grade=.018,Bloom=.72,Threshold=1.0,Size=38,Halo=.27,HaloThreshold=1.24,Rays=.19,Spread=.9,Density=.25,Offset=.18,Air=rgb(189,225,255),Decay=rgb(94,125,165),Glare=.8,Haze=1.5,Fog=rgb(187,220,240),FogStart=500,FogEnd=4200,DOFFar=.08,Focus=95,Radius=85},
		['Continuum'] = {Time=15.8,Sun=4.1,Exposure=-.23,Ambient=rgb(26,32,40),Outdoor=rgb(95,108,118),Top=rgb(255,225,187),Bottom=rgb(4,5,7),Softness=.12,Diffuse=.55,Specular=1,Contrast=.38,Saturation=.06,Tint=rgb(251,245,235),Grade=-.005,Bloom=.26,Threshold=1.52,Size=18,Halo=.07,HaloThreshold=1.95,Rays=.07,Spread=.74,Density=.20,Offset=.24,Air=rgb(205,218,228),Decay=rgb(102,112,122),Glare=.28,Haze=.9,Fog=rgb(194,205,212),FogStart=700,FogEnd=6000,DOFFar=.12,Focus=115,Radius=75},
		['Photon'] = {Time=13.85,Sun=4.8,Exposure=-.08,Ambient=rgb(39,50,64),Outdoor=rgb(120,151,171),Top=rgb(255,247,220),Bottom=rgb(10,13,20),Softness=.3,Diffuse=.82,Specular=1,Contrast=.23,Saturation=.35,Tint=rgb(244,250,255),Grade=.012,Bloom=.41,Threshold=1.28,Size=26,Halo=.13,HaloThreshold=1.58,Rays=.105,Spread=.86,Density=.21,Offset=.23,Air=rgb(177,221,250),Decay=rgb(80,122,164),Glare=.36,Haze=1.05,Fog=rgb(177,214,237),FogStart=600,FogEnd=5200,DOFFar=.065,Focus=115,Radius=100},
		['Rethinking Voxels'] = {Time=15.15,Sun=4.6,Exposure=-.18,Ambient=rgb(29,38,50),Outdoor=rgb(104,128,146),Top=rgb(255,232,195),Bottom=rgb(6,9,15),Softness=.08,Diffuse=.62,Specular=1,Contrast=.34,Saturation=.27,Tint=rgb(252,248,239),Grade=.004,Bloom=.31,Threshold=1.4,Size=22,Halo=.09,HaloThreshold=1.75,Rays=.115,Spread=.8,Density=.22,Offset=.2,Air=rgb(194,221,239),Decay=rgb(86,112,143),Glare=.45,Haze=1.25,Fog=rgb(187,210,226),FogStart=600,FogEnd=5200,DOFFar=.08,Focus=105,Radius=90},
		['Insanity'] = {Time=0.15,Sun=1.3,Exposure=-.05,Ambient=rgb(20,16,31),Outdoor=rgb(50,56,84),Top=rgb(122,96,176),Bottom=rgb(0,0,0),Softness=.9,Diffuse=.45,Specular=.72,Contrast=.46,Saturation=-.18,Tint=rgb(197,207,236),Grade=-.04,Bloom=.42,Threshold=.95,Size=42,Halo=.24,HaloThreshold=1.1,Rays=.012,Spread=1,Density=.43,Offset=.05,Air=rgb(82,89,126),Decay=rgb(25,18,45),Glare=0,Haze=4.4,Fog=rgb(49,46,69),FogStart=80,FogEnd=900,DOFFar=.24,Focus=55,Radius=38},
		['AstraLex'] = {Time=17.6,Sun=4.2,Exposure=-.06,Ambient=rgb(56,38,76),Outdoor=rgb(144,99,138),Top=rgb(255,148,111),Bottom=rgb(13,5,28),Softness=.68,Diffuse=.68,Specular=1,Contrast=.25,Saturation=.43,Tint=rgb(255,221,225),Grade=.025,Bloom=.83,Threshold=.92,Size=48,Halo=.34,HaloThreshold=1.08,Rays=.21,Spread=.95,Density=.33,Offset=.12,Air=rgb(255,183,171),Decay=rgb(116,69,145),Glare=.95,Haze=2.8,Fog=rgb(213,145,168),FogStart=250,FogEnd=2600,DOFFar=.13,Focus=72,Radius=62},
		['Super Duper Vanilla'] = {Time=13.4,Sun=3.5,Exposure=.02,Ambient=rgb(60,64,72),Outdoor=rgb(137,153,165),Top=rgb(255,244,221),Bottom=rgb(24,25,28),Softness=.55,Diffuse=.86,Specular=.82,Contrast=.12,Saturation=.2,Tint=rgb(255,253,247),Grade=.01,Bloom=.24,Threshold=1.48,Size=18,Halo=.06,HaloThreshold=1.85,Rays=.055,Spread=.84,Density=.18,Offset=.28,Air=rgb(207,229,244),Decay=rgb(118,137,154),Glare=.18,Haze=.7,Fog=rgb(205,222,232),FogStart=900,FogEnd=7000,DOFFar=.045,Focus=130,Radius=115},
		['Golden Hour'] = {Time=17.35,Sun=4.4,Exposure=-.17,Ambient=rgb(52,35,64),Outdoor=rgb(148,99,101),Top=rgb(255,158,70),Bottom=rgb(17,5,16),Softness=.55,Diffuse=.62,Specular=1,Contrast=.29,Saturation=.3,Tint=rgb(255,226,194),Grade=.018,Bloom=.67,Threshold=1.02,Size=36,Halo=.24,HaloThreshold=1.28,Rays=.18,Spread=.9,Density=.33,Offset=.12,Air=rgb(255,199,143),Decay=rgb(135,79,120),Glare=1,Haze=2.65,Fog=rgb(232,166,138),FogStart=260,FogEnd=2800,DOFFar=.12,Focus=78,Radius=60},
		['Dreamy Sunset'] = {Time=18.15,Sun=3.15,Exposure=.01,Ambient=rgb(73,44,91),Outdoor=rgb(161,102,155),Top=rgb(255,133,135),Bottom=rgb(22,7,45),Softness=.82,Diffuse=.72,Specular=.88,Contrast=.16,Saturation=.37,Tint=rgb(255,218,238),Grade=.035,Bloom=.92,Threshold=.8,Size=52,Halo=.42,HaloThreshold=.95,Rays=.16,Spread=.98,Density=.37,Offset=.09,Air=rgb(255,174,205),Decay=rgb(124,81,167),Glare=.92,Haze=3.1,Fog=rgb(220,147,190),FogStart=180,FogEnd=2200,DOFFar=.19,Focus=65,Radius=48},
		['Blue Hour'] = {Time=19.1,Sun=2.15,Exposure=.08,Ambient=rgb(33,45,76),Outdoor=rgb(76,109,155),Top=rgb(159,189,255),Bottom=rgb(8,12,31),Softness=.72,Diffuse=.7,Specular=.91,Contrast=.23,Saturation=.1,Tint=rgb(218,232,255),Grade=.015,Bloom=.55,Threshold=1.02,Size=33,Halo=.19,HaloThreshold=1.28,Rays=.03,Spread=.96,Density=.31,Offset=.16,Air=rgb(128,162,218),Decay=rgb(48,64,117),Glare=.08,Haze=2.15,Fog=rgb(106,137,184),FogStart=300,FogEnd=3200,DOFFar=.12,Focus=85,Radius=66},
		['Crystal Day'] = {Time=12.5,Sun=5,Exposure=-.11,Ambient=rgb(45,59,73),Outdoor=rgb(139,176,196),Top=rgb(255,252,234),Bottom=rgb(13,20,28),Softness=.18,Diffuse=.9,Specular=1,Contrast=.29,Saturation=.24,Tint=rgb(236,250,255),Grade=.006,Bloom=.21,Threshold=1.65,Size=15,Halo=.04,HaloThreshold=2.1,Rays=.1,Spread=.72,Density=.13,Offset=.32,Air=rgb(192,230,255),Decay=rgb(104,151,183),Glare=.26,Haze=.42,Fog=rgb(201,230,246),FogStart=1200,FogEnd=9000,DOFFar=.035,Focus=150,Radius=130},
		['Overcast'] = {Time=12.9,Sun=1.9,Exposure=-.01,Ambient=rgb(71,74,79),Outdoor=rgb(137,141,145),Top=rgb(183,190,198),Bottom=rgb(36,38,41),Softness=1,Diffuse=.92,Specular=.55,Contrast=.08,Saturation=-.28,Tint=rgb(227,232,236),Grade=-.01,Bloom=.12,Threshold=1.75,Size=22,Halo=.03,HaloThreshold=2,Rays=0,Spread=1,Density=.36,Offset=.08,Air=rgb(168,176,184),Decay=rgb(99,104,111),Glare=0,Haze=3.2,Fog=rgb(159,166,172),FogStart=180,FogEnd=1800,DOFFar=.1,Focus=90,Radius=75},
		['Rainy Film'] = {Time=14.2,Sun=1.55,Exposure=-.18,Ambient=rgb(49,58,62),Outdoor=rgb(101,119,124),Top=rgb(178,195,197),Bottom=rgb(20,29,31),Softness=.95,Diffuse=.8,Specular=.72,Contrast=.27,Saturation=-.35,Tint=rgb(209,225,221),Grade=-.025,Bloom=.27,Threshold=1.2,Size=31,Halo=.11,HaloThreshold=1.48,Rays=0,Spread=1,Density=.42,Offset=.04,Air=rgb(130,155,159),Decay=rgb(61,80,82),Glare=0,Haze=4,Fog=rgb(112,133,136),FogStart=95,FogEnd=1150,DOFFar=.18,Focus=65,Radius=50},
		['Midnight'] = {Time=.25,Sun=1.75,Exposure=.16,Ambient=rgb(23,30,57),Outdoor=rgb(60,81,129),Top=rgb(142,179,255),Bottom=rgb(0,1,9),Softness=.68,Diffuse=.68,Specular=.88,Contrast=.27,Saturation=.05,Tint=rgb(207,225,255),Grade=.018,Bloom=.66,Threshold=1.0,Size=31,Halo=.21,HaloThreshold=1.25,Rays=.018,Spread=.98,Density=.29,Offset=.18,Air=rgb(103,135,205),Decay=rgb(37,45,94),Glare=0,Haze=2.1,Fog=rgb(74,97,149),FogStart=300,FogEnd=3200,DOFFar=.12,Focus=82,Radius=65},
		-- Night time is intentionally natural rather than fantasy-blue: deep navy blacks, silver moonlight,
		-- readable shadow fill, restrained bloom and a long atmospheric falloff. It is meant to look like
		-- an expensive realistic night shader while still keeping players and geometry visible.
		['Night time'] = {Time=23.72,Sun=2.18,Exposure=.09,Ambient=rgb(17,24,43),Outdoor=rgb(48,67,103),Top=rgb(126,158,216),Bottom=rgb(1,3,10),Softness=.82,Diffuse=.61,Specular=.96,Contrast=.34,Saturation=.02,Tint=rgb(214,229,255),Grade=.008,Bloom=.47,Threshold=1.18,Size=29,Halo=.16,HaloThreshold=1.42,Rays=.012,Spread=.96,Density=.255,Offset=.205,Air=rgb(108,137,187),Decay=rgb(27,38,67),Glare=.03,Haze=1.72,Fog=rgb(54,73,108),FogStart=430,FogEnd=4300,DOFFar=.085,DOFNear=.018,Focus=105,Radius=88,Latitude=41},
		['Moonlit'] = {Time=23.1,Sun=2.35,Exposure=.1,Ambient=rgb(32,39,65),Outdoor=rgb(80,98,139),Top=rgb(186,207,255),Bottom=rgb(4,6,17),Softness=.38,Diffuse=.64,Specular=1,Contrast=.31,Saturation=-.08,Tint=rgb(217,229,255),Grade=.008,Bloom=.4,Threshold=1.28,Size=22,Halo=.11,HaloThreshold=1.55,Rays=.012,Spread=.9,Density=.21,Offset=.23,Air=rgb(133,155,204),Decay=rgb(54,63,103),Glare=0,Haze=1.2,Fog=rgb(111,130,169),FogStart=520,FogEnd=4600,DOFFar=.07,Focus=110,Radius=90},
		['Cyberpunk'] = {Time=1.05,Sun=1.2,Exposure=.13,Ambient=rgb(31,13,54),Outdoor=rgb(72,54,109),Top=rgb(255,48,184),Bottom=rgb(0,13,31),Softness=.52,Diffuse=.56,Specular=1,Contrast=.42,Saturation=.48,Tint=rgb(226,203,255),Grade=.02,Bloom=1.05,Threshold=.7,Size=56,Halo=.55,HaloThreshold=.82,Rays=.025,Spread=1,Density=.34,Offset=.12,Air=rgb(93,73,162),Decay=rgb(18,52,85),Glare=.05,Haze=2.8,Fog=rgb(57,42,98),FogStart=180,FogEnd=1900,DOFFar=.18,Focus=67,Radius=47},
		['Blood Moon'] = {Time=0.6,Sun=1.35,Exposure=-.18,Ambient=rgb(52,16,18),Outdoor=rgb(104,44,44),Top=rgb(255,71,49),Bottom=rgb(8,0,0),Softness=.72,Diffuse=.48,Specular=.76,Contrast=.48,Saturation=.12,Tint=rgb(255,181,170),Grade=-.035,Bloom=.62,Threshold=.88,Size=43,Halo=.29,HaloThreshold=1.02,Rays=.018,Spread=.96,Density=.39,Offset=.08,Air=rgb(133,56,52),Decay=rgb(45,9,13),Glare=.03,Haze=3.7,Fog=rgb(83,30,31),FogStart=110,FogEnd=1200,DOFFar=.22,Focus=55,Radius=38},
		['Emerald Night'] = {Time=22.7,Sun=1.6,Exposure=.04,Ambient=rgb(12,39,34),Outdoor=rgb(44,94,82),Top=rgb(89,224,175),Bottom=rgb(0,10,12),Softness=.62,Diffuse=.62,Specular=.9,Contrast=.35,Saturation=.22,Tint=rgb(200,255,231),Grade=.006,Bloom=.68,Threshold=.86,Size=46,Halo=.31,HaloThreshold=1.05,Rays=.02,Spread=.98,Density=.34,Offset=.11,Air=rgb(65,145,123),Decay=rgb(16,64,65),Glare=.02,Haze=2.7,Fog=rgb(42,105,91),FogStart=180,FogEnd=1900,DOFFar=.16,Focus=72,Radius=54},
		['Arctic'] = {Time=11.7,Sun=4.35,Exposure=.04,Ambient=rgb(75,94,112),Outdoor=rgb(173,205,222),Top=rgb(239,250,255),Bottom=rgb(31,50,66),Softness=.78,Diffuse=.9,Specular=1,Contrast=.14,Saturation=-.08,Tint=rgb(225,247,255),Grade=.035,Bloom=.54,Threshold=1.12,Size=34,Halo=.14,HaloThreshold=1.4,Rays=.08,Spread=.88,Density=.29,Offset=.16,Air=rgb(210,242,255),Decay=rgb(121,164,190),Glare=.4,Haze=1.8,Fog=rgb(210,234,245),FogStart=340,FogEnd=3400,DOFFar=.08,Focus=95,Radius=80},
		['Desert Heat'] = {Time=14.3,Sun=5,Exposure=-.14,Ambient=rgb(74,54,38),Outdoor=rgb(173,132,91),Top=rgb(255,226,161),Bottom=rgb(28,15,5),Softness=.2,Diffuse=.75,Specular=.92,Contrast=.3,Saturation=.24,Tint=rgb(255,234,194),Grade=.012,Bloom=.44,Threshold=1.25,Size=27,Halo=.13,HaloThreshold=1.5,Rays=.2,Spread=.8,Density=.31,Offset=.1,Air=rgb(239,193,132),Decay=rgb(142,94,58),Glare=.92,Haze=3.1,Fog=rgb(224,181,124),FogStart=230,FogEnd=2200,DOFFar=.1,Focus=85,Radius=70},
		['Cotton Candy'] = {Time=18.45,Sun=2.95,Exposure=.11,Ambient=rgb(74,57,99),Outdoor=rgb(162,128,187),Top=rgb(255,174,214),Bottom=rgb(32,18,63),Softness=.9,Diffuse=.78,Specular=.86,Contrast=.12,Saturation=.38,Tint=rgb(246,224,255),Grade=.04,Bloom=.86,Threshold=.8,Size=52,Halo=.39,HaloThreshold=.92,Rays=.12,Spread=.98,Density=.35,Offset=.1,Air=rgb(224,173,235),Decay=rgb(112,92,170),Glare=.65,Haze=2.7,Fog=rgb(192,150,216),FogStart=220,FogEnd=2400,DOFFar=.17,Focus=66,Radius=50},
		['Cinematic'] = {Time=16.85,Sun=3.6,Exposure=-.27,Ambient=rgb(27,44,50),Outdoor=rgb(86,111,117),Top=rgb(255,190,133),Bottom=rgb(3,9,11),Softness=.42,Diffuse=.58,Specular=.9,Contrast=.36,Saturation=-.12,Tint=rgb(236,246,239),Grade=-.006,Bloom=.35,Threshold=1.3,Size=22,Halo=.12,HaloThreshold=1.58,Rays=.1,Spread=.86,Density=.27,Offset=.18,Air=rgb(179,203,202),Decay=rgb(71,102,112),Glare=.38,Haze=1.75,Fog=rgb(166,190,188),FogStart=420,FogEnd=3900,DOFFar=.16,Focus=72,Radius=50},
		['Noir'] = {Time=15.2,Sun=2.7,Exposure=-.32,Ambient=rgb(36,36,36),Outdoor=rgb(91,91,91),Top=rgb(205,205,205),Bottom=rgb(0,0,0),Softness=.35,Diffuse=.58,Specular=.78,Contrast=.62,Saturation=-1,Tint=rgb(238,238,238),Grade=-.05,Bloom=.16,Threshold=1.52,Size=19,Halo=.05,HaloThreshold=1.8,Rays=.035,Spread=.75,Density=.29,Offset=.14,Air=rgb(162,162,162),Decay=rgb(65,65,65),Glare=.05,Haze=2,Fog=rgb(133,133,133),FogStart=350,FogEnd=3000,DOFFar=.17,Focus=68,Radius=48},
		['Vintage Film'] = {Time=16.2,Sun=3.2,Exposure=-.08,Ambient=rgb(67,57,46),Outdoor=rgb(139,122,96),Top=rgb(255,222,167),Bottom=rgb(27,18,10),Softness=.72,Diffuse=.74,Specular=.68,Contrast=.18,Saturation=-.22,Tint=rgb(255,230,184),Grade=.028,Bloom=.32,Threshold=1.18,Size=30,Halo=.13,HaloThreshold=1.42,Rays=.06,Spread=.9,Density=.3,Offset=.13,Air=rgb(220,193,154),Decay=rgb(120,96,70),Glare=.25,Haze=2.2,Fog=rgb(199,175,141),FogStart=300,FogEnd=3000,DOFFar=.14,Focus=74,Radius=54},
		['Dark Fantasy'] = {Time=20.4,Sun=1.45,Exposure=-.27,Ambient=rgb(18,23,31),Outdoor=rgb(46,63,72),Top=rgb(88,111,125),Bottom=rgb(0,4,5),Softness=.83,Diffuse=.47,Specular=.62,Contrast=.5,Saturation=-.34,Tint=rgb(186,208,201),Grade=-.04,Bloom=.3,Threshold=1.05,Size=34,Halo=.14,HaloThreshold=1.28,Rays=.01,Spread=1,Density=.44,Offset=.03,Air=rgb(81,104,106),Decay=rgb(27,42,44),Glare=0,Haze=4.6,Fog=rgb(56,73,74),FogStart=75,FogEnd=850,DOFFar=.25,Focus=52,Radius=35},
		['Heaven'] = {Time=10.8,Sun=5,Exposure=.19,Ambient=rgb(103,114,127),Outdoor=rgb(211,224,232),Top=rgb(255,252,233),Bottom=rgb(91,111,128),Softness=1,Diffuse=1,Specular=1,Contrast=-.04,Saturation=-.04,Tint=rgb(255,250,234),Grade=.075,Bloom=1.1,Threshold=.72,Size=56,Halo=.56,HaloThreshold=.78,Rays=.24,Spread=1,Density=.34,Offset=.1,Air=rgb(238,245,248),Decay=rgb(176,194,206),Glare=1,Haze=3.3,Fog=rgb(234,241,245),FogStart=180,FogEnd=2100,DOFFar=.18,Focus=72,Radius=58},
		['Void'] = {Time=0,Sun=.75,Exposure=-.42,Ambient=rgb(4,2,11),Outdoor=rgb(17,11,33),Top=rgb(42,18,81),Bottom=rgb(0,0,0),Softness=.2,Diffuse=.22,Specular=.46,Contrast=.58,Saturation=-.28,Tint=rgb(186,170,225),Grade=-.065,Bloom=.52,Threshold=.72,Size=50,Halo=.31,HaloThreshold=.88,Rays=0,Spread=1,Density=.48,Offset=-.04,Air=rgb(45,30,75),Decay=rgb(9,4,22),Glare=0,Haze=5.2,Fog=rgb(20,12,39),FogStart=45,FogEnd=600,DOFFar=.3,Focus=45,Radius=28}
	}

	local properties = {
		'Ambient','OutdoorAmbient','Brightness','ExposureCompensation','ClockTime','ColorShift_Top','ColorShift_Bottom',
		'GlobalShadows','ShadowSoftness','EnvironmentDiffuseScale','EnvironmentSpecularScale','GeographicLatitude',
		'FogColor','FogStart','FogEnd'
	}
	local replaceClasses = {BloomEffect=true, ColorCorrectionEffect=true, SunRaysEffect=true, DepthOfFieldEffect=true, BlurEffect=true}

	local function safeSet(object, key, value) return pcall(function() object[key] = value end) end
	local function cancelTweens()
		for _, animation in ipairs(animations) do pcall(function() animation:Cancel() end) end
		table.clear(animations)
	end
	local function setProperties(object, values, animate)
		if animate then
			local animation = tweens:Create(object, TweenInfo.new(.72, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), values)
			animations[#animations + 1] = animation
			animation:Play()
		else
			for key, value in pairs(values) do safeSet(object, key, value) end
		end
	end
	local function capture(object)
		if not active or owned[object] then return end
		if object:IsA('Atmosphere') and object.Parent == lighting then
			atmospheres[object] = true
			object.Parent = holding
		elseif replaceClasses[object.ClassName] then
			if suppressed[object] == nil then suppressed[object] = object.Enabled end
			object.Enabled = false
		end
	end
	local function watchCamera()
		if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
		local camera = workspace.CurrentCamera
		if camera then
			for _, object in ipairs(camera:GetChildren()) do capture(object) end
			cameraConnection = camera.ChildAdded:Connect(capture)
		end
	end
	local function make(class, values, key)
		local object = Instance.new(class)
		object.Name = 'RTXShaders_'..(key or class)
		owned[object] = true
		for k, value in pairs(values) do safeSet(object, k, value) end
		object.Parent = lighting
		effects[key or class] = object
		return object
	end
	local function stopMotion()
		if motionConnection then motionConnection:Disconnect(); motionConnection = nil end
	end
	local function restore()
		active = false
		stopMotion()
		cancelTweens()
		for _, connection in ipairs(connections) do connection:Disconnect() end
		table.clear(connections)
		if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
		for object in pairs(owned) do pcall(function() object:Destroy() end) end
		owned, effects = {}, {}
		for key, value in pairs(original) do safeSet(lighting, key, value) end
		original = {}
		for object, enabled in pairs(suppressed) do pcall(function() object.Enabled = enabled end) end
		suppressed = {}
		for object in pairs(atmospheres) do if object.Parent == holding then safeSet(object, 'Parent', lighting) end end
		atmospheres = {}
	end

	local function apply()
		if not active or not ready then return end
		cancelTweens()
		stopMotion()
		local p = presets[Preset.Value] or presets[names[1]]
		local amount = Strength.Value / 100
		local depth = ShadowDepth.Value / 100
		local animate = Smooth.Enabled
		local timeValue = CustomTime.Enabled and Time.Value or p.Time
		local night = timeValue < 6 or timeValue > 19
		local shadowTarget = night and rgb(11,16,32) or rgb(13,19,27)
		local outdoorTarget = night and rgb(37,53,88) or rgb(51,69,87)
		local ambient = p.Ambient:Lerp(shadowTarget, depth * (night and .34 or .64))
		local outdoor = p.Outdoor:Lerp(outdoorTarget, depth * (night and .2 or .48))
		local fogScale = FogPower.Value / 100

		setProperties(lighting, {
			Brightness = p.Sun * Sunlight.Value / 100,
			ExposureCompensation = p.Exposure + Exposure.Value / 100,
			Ambient = ambient,
			OutdoorAmbient = outdoor,
			ColorShift_Top = p.Top,
			ColorShift_Bottom = p.Bottom,
			ShadowSoftness = p.Softness,
			EnvironmentDiffuseScale = math.clamp(p.Diffuse * (1 - depth * .12), 0, 1),
			EnvironmentSpecularScale = math.clamp(p.Specular, 0, 1),
			GeographicLatitude = p.Latitude or 35,
			FogColor = p.Fog,
			FogStart = p.FogStart / math.max(fogScale, .05),
			FogEnd = p.FogEnd / math.max(fogScale, .05)
		}, animate)
		lighting.GlobalShadows = true
		lighting.ClockTime = timeValue

		local sat = math.clamp((p.Saturation + SaturationBoost.Value / 100) * amount, -1, 1)
		local contrast = math.clamp(p.Contrast * amount, -1, 1)
		local vibranceAmount = Vibrance.Value / 100
		setProperties(effects.ColorCorrectionEffect, {
			Brightness = p.Grade * amount,
			Contrast = contrast,
			Saturation = sat,
			TintColor = rgb(255,255,255):Lerp(p.Tint, math.min(amount, 1.35) * .72)
		}, animate)
		setProperties(effects.Vibrance, {
			Brightness = 0,
			Contrast = .035 * vibranceAmount * amount,
			Saturation = .12 * vibranceAmount * amount,
			TintColor = rgb(255,255,255):Lerp(p.Air, .035 * vibranceAmount)
		}, animate)
		setProperties(effects.BloomEffect, {
			Intensity = p.Bloom * Bloom.Value / 100 * amount,
			Threshold = p.Threshold,
			Size = p.Size
		}, animate)
		setProperties(effects.HighlightHalo, {
			Intensity = p.Halo * Bloom.Value / 100 * amount,
			Threshold = p.HaloThreshold,
			Size = 56
		}, animate)
		setProperties(effects.SunRaysEffect, {
			Intensity = p.Rays * Rays.Value / 100 * amount,
			Spread = p.Spread
		}, animate)
		setProperties(effects.Atmosphere, {
			Density = math.clamp(p.Density * Haze.Value / 100, 0, .65),
			Offset = p.Offset,
			Color = p.Air,
			Decay = p.Decay,
			Glare = math.clamp(p.Glare * Haze.Value / 100, 0, 10),
			Haze = math.clamp(p.Haze * Haze.Value / 100, 0, 10)
		}, animate)
		setProperties(effects.DepthOfFieldEffect, {
			FarIntensity = p.DOFFar,
			FocusDistance = p.Focus,
			InFocusRadius = p.Radius,
			NearIntensity = p.DOFNear or .035
		}, animate)
		effects.DepthOfFieldEffect.Enabled = DOF.Enabled

		if Motion.Enabled then
			local baseExposure = p.Exposure + Exposure.Value / 100
			local baseHaze = math.clamp(p.Haze * Haze.Value / 100, 0, 10)
			local started = tick()
			motionConnection = runService.RenderStepped:Connect(function()
				if not active or not Motion.Enabled then return end
				local wave = math.sin((tick() - started) * .42)
				lighting.ExposureCompensation = baseExposure + wave * .018
				effects.Atmosphere.Haze = math.clamp(baseHaze + wave * .08, 0, 10)
			end)
		end
	end

	local function start()
		if active or not ready then return end
		active = true
		local ok, message = pcall(function()
			for _, key in ipairs(properties) do original[key] = lighting[key] end
			for _, object in ipairs(lighting:GetChildren()) do capture(object) end
			connections[#connections + 1] = lighting.ChildAdded:Connect(capture)
			connections[#connections + 1] = workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(watchCamera)
			watchCamera()
			make('ColorCorrectionEffect', {Brightness=0,Contrast=0,Saturation=0,TintColor=rgb(255,255,255)})
			make('ColorCorrectionEffect', {Brightness=0,Contrast=0,Saturation=0,TintColor=rgb(255,255,255)}, 'Vibrance')
			make('BloomEffect', {Intensity=0})
			make('BloomEffect', {Intensity=0}, 'HighlightHalo')
			make('SunRaysEffect', {Intensity=0})
			make('Atmosphere', {Density=0,Haze=0,Glare=0})
			make('DepthOfFieldEffect', {Enabled=false,NearIntensity=0,FarIntensity=.1,FocusDistance=80,InFocusRadius=65})
			apply()
		end)
		if not ok then
			restore()
			warn('[RTXShaders] '..tostring(message))
			task.defer(function() if RTXShaders and RTXShaders.Enabled then RTXShaders:Toggle() end end)
		end
	end
	local function changed()
		task.defer(function() if active and ready then apply() end end)
	end

	RTXShaders = vape.Categories.Render:CreateModule({
		Name = 'RTXShaders',
		Tooltip = 'Shader-pack inspired lighting with 31 visual presets, cinematic grading, atmosphere and bloom.',
		Function = function(enabled)
			if enabled then task.defer(function() if RTXShaders and RTXShaders.Enabled then start() end end) else restore() end
		end
	})
	Preset = RTXShaders:CreateDropdown({Name='Shader Pack',List=names,Default=names[1],Function=changed})
	Strength = RTXShaders:CreateSlider({Name='Shader Strength',Min=0,Max=150,Default=100,Suffix='%',Function=changed})
	ShadowDepth = RTXShaders:CreateSlider({Name='Shadow Depth',Min=0,Max=100,Default=58,Suffix='%',Function=changed})
	Sunlight = RTXShaders:CreateSlider({Name='Direct Light',Min=25,Max=175,Default=100,Suffix='%',Function=changed})
	Exposure = RTXShaders:CreateSlider({Name='Exposure',Min=-100,Max=100,Default=0,Function=changed})
	SaturationBoost = RTXShaders:CreateSlider({Name='Saturation',Min=-100,Max=100,Default=0,Suffix='%',Function=changed})
	Vibrance = RTXShaders:CreateSlider({Name='Vibrance',Min=0,Max=200,Default=100,Suffix='%',Function=changed})
	Bloom = RTXShaders:CreateSlider({Name='Bloom',Min=0,Max=200,Default=100,Suffix='%',Function=changed})
	Rays = RTXShaders:CreateSlider({Name='God Rays',Min=0,Max=200,Default=100,Suffix='%',Function=changed})
	Haze = RTXShaders:CreateSlider({Name='Atmosphere',Min=0,Max=175,Default=100,Suffix='%',Function=changed})
	FogPower = RTXShaders:CreateSlider({Name='Distance Fog',Min=25,Max=200,Default=100,Suffix='%',Function=changed})
	DOF = RTXShaders:CreateToggle({Name='Cinematic DOF',Default=false,Function=changed})
	Motion = RTXShaders:CreateToggle({Name='Living Atmosphere',Default=false,Function=changed})
	Smooth = RTXShaders:CreateToggle({Name='Smooth Transitions',Default=true,Function=changed})
	CustomTime = RTXShaders:CreateToggle({Name='Custom Time',Default=false,Function=changed})
	Time = RTXShaders:CreateSlider({Name='Time',Min=0,Max=24,Default=15,Decimal=10,Function=changed})
	ready = true
	vape:Clean(function() restore(); holding:Destroy() end)
end)
-- RTXSHADERS_END

run(function()
	local GunViewmodel
	local X, Y, Z, Pitch, Yaw, Roll, AimReset
	local model, original, applied
	local renderName = 'FrontlinesGunViewmodel'

	local function samePose(a, b)
		return (a.Position - b.Position).Magnitude < 0.0001
			and a.LookVector:Dot(b.LookVector) > 0.999999
			and a.RightVector:Dot(b.RightVector) > 0.999999
	end

	local function restore()
		if model and model.Parent and original and applied then
			-- Only undo our last offset. The game may already have supplied a new
			-- animated pose, which must never be overwritten with an older frame.
			if samePose(model:GetPivot(), applied) then model:PivotTo(original) end
		end
		model, original, applied = nil, nil, nil
	end

	local function render()
		restore()
		if not GunViewmodel.Enabled or not entitylib.isAlive then return end
		local main = frontlines.Main
		local globals = main and main.globals
		local state = globals and globals.cli_state
		local equipment = globals and globals.fpv_sol_equipment
		local gun = equipment and equipment.curr_equipment
		if not state or state.state ~= main.cli_state_t.COMBAT or not gun or gun.type == 2 or not gun.reload_params then return end
		if vape.Modules.ThirdPerson and vape.Modules.ThirdPerson.Enabled then return end
		if AimReset.Enabled and inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
		local camera = workspace.CurrentCamera
		local candidate = workspace:FindFirstChild('Model')
		if not camera or not candidate or not candidate:IsA('Model') then return end
		local base = candidate:GetPivot()
		-- Use the same FPV assembly as GunChanger, with a proximity guard to
		-- avoid touching an unrelated world model when no viewmodel is present.
		if (base.Position - camera.CFrame.Position).Magnitude > 20 then return end
		local offset = CFrame.new(X.Value, Y.Value, -Z.Value)
			* CFrame.Angles(math.rad(Pitch.Value), math.rad(Yaw.Value), math.rad(Roll.Value))
		model, original = candidate, base
		candidate:PivotTo(camera.CFrame * offset * camera.CFrame:ToObjectSpace(base))
		applied = candidate:GetPivot()
	end

	GunViewmodel = vape.Categories.Render:CreateModule({
		Name = 'GunViewmodel',
		Function = function(callback)
			if not callback then return end
			GunViewmodel:Clean(function()
				runService:UnbindFromRenderStep(renderName)
				runService:UnbindFromRenderStep(renderName..'Restore')
				restore()
			end)
			-- Clear the visual offset before simulation and camera/animation work,
			-- then apply exactly once at the end of rendering to prevent drift.
			GunViewmodel:Clean(runService.PreSimulation:Connect(restore))
			runService:BindToRenderStep(renderName..'Restore', Enum.RenderPriority.First.Value, restore)
			runService:BindToRenderStep(renderName, Enum.RenderPriority.Last.Value + 150, render)
		end,
		Tooltip = 'Adjusts the first-person firearm and hands together without changing the camera. Restores on disable; skips melee, menus and ThirdPerson.'
	})
	X = GunViewmodel:CreateSlider({Name = 'Horizontal', Min = -3, Max = 3, Default = 0, Decimal = 100, Suffix = 'studs'})
	Y = GunViewmodel:CreateSlider({Name = 'Vertical', Min = -3, Max = 3, Default = 0, Decimal = 100, Suffix = 'studs'})
	Z = GunViewmodel:CreateSlider({Name = 'Forward', Min = -3, Max = 3, Default = 0, Decimal = 100, Suffix = 'studs'})
	Pitch = GunViewmodel:CreateSlider({Name = 'Pitch', Min = -45, Max = 45, Default = 0, Suffix = '°'})
	Yaw = GunViewmodel:CreateSlider({Name = 'Yaw', Min = -45, Max = 45, Default = 0, Suffix = '°'})
	Roll = GunViewmodel:CreateSlider({Name = 'Roll', Min = -90, Max = 90, Default = 0, Suffix = '°'})
	AimReset = GunViewmodel:CreateToggle({Name = 'Reset While Right Click Held', Default = true,
		Tooltip = 'Uses the original pose while holding right mouse for aiming.'})
	GunViewmodel:CreateButton({Name = 'Reset Offsets', Function = function()
		for _, option in {X, Y, Z, Pitch, Yaw, Roll} do option:SetValue(0) end
		restore()
	end})
end)

run(function()
	local GunChanger
	local RainbowSpeed
	local Saturation
	local Brightness
	local BrightForceField
	local optionsReady = false

	local originals = {}
	local textureOriginals = {}
	local surfaceOriginals = {}
	local gunParts = {}
	local gunTextures = {}
	local gunSurfaces = {}
	local currentModel
	local lastScan = 0

	local function optionValue(option, fallback)
		return option and option.Value ~= nil and option.Value or fallback
	end

	local function optionEnabled(option, fallback)
		if option and option.Enabled ~= nil then
			return option.Enabled
		end
		return fallback
	end

	local function getFPVModel()
		local model = workspace:FindFirstChild('Model')
		return model and model:IsA('Model') and model or nil
	end

	local function currentEquipment()
		local equipment = frontlines.Main
			and frontlines.Main.globals
			and frontlines.Main.globals.fpv_sol_equipment
		return equipment and equipment.curr_equipment or nil
	end

	local function looksLikeBody(name)
		name = string.lower(tostring(name))
		return name:find('arm', 1, true)
			or name:find('hand', 1, true)
			or name:find('glove', 1, true)
			or name:find('sleeve', 1, true)
			or name:find('body', 1, true)
			or name:find('torso', 1, true)
			or name:find('head', 1, true)
	end

	local function looksLikeReticle(name)
		name = string.lower(tostring(name))
		return name:find('reticle', 1, true)
			or name:find('crosshair', 1, true)
			or name:find('cross_hair', 1, true)
			or name:find('aimdot', 1, true)
			or name:find('aim_dot', 1, true)
			or name == 'dot'
			or name:find('hud', 1, true)
	end

	local function hasIgnoredAncestor(obj, root)
		local current = obj
		while current and current ~= root do
			if looksLikeBody(current.Name) or looksLikeReticle(current.Name) then
				return true
			end
			current = current.Parent
		end
		return false
	end

	local function isCandidatePart(part, root)
		if not part:IsA('BasePart') then return false end
		if hasIgnoredAncestor(part, root) then return false end
		if part:FindFirstChildWhichIsA('SurfaceGui')
			or part:FindFirstChildWhichIsA('BillboardGui') then
			return false
		end
		return true
	end

	local function savePart(part)
		if originals[part] then return end

		local old = {
			Material = part.Material,
			MaterialVariant = part.MaterialVariant,
			Color = part.Color,
			Reflectance = part.Reflectance,
			Transparency = part.Transparency,
			LocalTransparencyModifier = part.LocalTransparencyModifier
		}

		if part:IsA('MeshPart') then
			old.TextureID = part.TextureID
		end

		originals[part] = old
	end

	local function saveTexture(obj)
		if textureOriginals[obj] then return end

		if obj:IsA('Decal') or obj:IsA('Texture') then
			textureOriginals[obj] = {
				Type = 'TextureObject',
				Transparency = obj.Transparency
			}
		elseif obj:IsA('SpecialMesh') then
			textureOriginals[obj] = {
				Type = 'SpecialMesh',
				TextureId = obj.TextureId
			}
		end
	end

	local function saveSurface(obj)
		if surfaceOriginals[obj] then return end
		surfaceOriginals[obj] = obj.Parent
	end

	local function restorePart(part)
		local old = originals[part]
		if not old then return end

		if part and part.Parent then
			pcall(function()
				part.Material = old.Material
				part.MaterialVariant = old.MaterialVariant
				part.Color = old.Color
				part.Reflectance = old.Reflectance
				part.Transparency = old.Transparency
				part.LocalTransparencyModifier = old.LocalTransparencyModifier

				if old.TextureID ~= nil and part:IsA('MeshPart') then
					part.TextureID = old.TextureID
				end
			end)
		end

		originals[part] = nil
	end

	local function restoreTexture(obj)
		local old = textureOriginals[obj]
		if not old then return end

		if obj then
			pcall(function()
				if old.Type == 'TextureObject' then
					obj.Transparency = old.Transparency
				elseif old.Type == 'SpecialMesh' then
					obj.TextureId = old.TextureId
				end
			end)
		end

		textureOriginals[obj] = nil
	end

	local function restoreSurface(obj)
		local parent = surfaceOriginals[obj]
		if not parent then return end

		if obj then
			pcall(function()
				obj.Parent = parent
			end)
		end

		surfaceOriginals[obj] = nil
	end

	local function restoreAll()
		for part in originals do
			restorePart(part)
		end

		for obj in textureOriginals do
			restoreTexture(obj)
		end

		for obj in surfaceOriginals do
			restoreSurface(obj)
		end

		table.clear(gunParts)
		table.clear(gunTextures)
		table.clear(gunSurfaces)
		currentModel = nil
	end

	local function partVolume(part)
		local size = part.Size
		return math.max(size.X * size.Y * size.Z, 0.000001)
	end

	local function findGunAssembly(model)
		local candidates = {}
		local candidateSet = {}

		for _, obj in model:GetDescendants() do
			if obj:IsA('BasePart') and isCandidatePart(obj, model) then
				table.insert(candidates, obj)
				candidateSet[obj] = true
			end
		end

		if #candidates == 0 then
			return {}, {}
		end

		local adjacency = {}
		for _, part in candidates do
			adjacency[part] = {}
		end

		for _, obj in model:GetDescendants() do
			if obj:IsA('JointInstance') or obj:IsA('WeldConstraint') then
				local p0 = obj.Part0
				local p1 = obj.Part1

				if candidateSet[p0] and candidateSet[p1] then
					table.insert(adjacency[p0], p1)
					table.insert(adjacency[p1], p0)
				end
			end
		end

		local visited = {}
		local bestParts = {}
		local bestScore = -math.huge

		for _, seed in candidates do
			if visited[seed] then continue end

			local queue = {seed}
			visited[seed] = true
			local component = {}
			local volume = 0

			while #queue > 0 do
				local part = table.remove(queue)
				table.insert(component, part)
				volume += partVolume(part)

				for _, neighbor in adjacency[part] do
					if not visited[neighbor] then
						visited[neighbor] = true
						table.insert(queue, neighbor)
					end
				end
			end

			local score = volume + (#component * 0.08)
			if score > bestScore then
				bestScore = score
				bestParts = component
			end
		end

		-- Fallback for guns whose client-side welds are hidden.
		if #bestParts <= 1 and #candidates > 1 then
			local maxVolume = 0

			for _, part in candidates do
				maxVolume = math.max(maxVolume, partVolume(part))
			end

			bestParts = {}
			for _, part in candidates do
				if partVolume(part) >= maxVolume * 0.025 then
					table.insert(bestParts, part)
				end
			end
		end

		local selected = {}
		for _, part in bestParts do
			selected[part] = true
		end

		return bestParts, selected
	end

	local function scanGun()
		local model = getFPVModel()

		if not model then
			restoreAll()
			return
		end

		if currentModel ~= model then
			restoreAll()
			currentModel = model
		end

		local newParts, selected = findGunAssembly(model)
		local newTextures = {}
		local newSurfaces = {}
		local activeParts = {}
		local activeTextures = {}
		local activeSurfaces = {}

		for _, part in newParts do
			savePart(part)
			activeParts[part] = true
		end

		for _, obj in model:GetDescendants() do
			if obj:IsA('Decal') or obj:IsA('Texture') or obj:IsA('SpecialMesh') then
				local parentPart = obj:FindFirstAncestorWhichIsA('BasePart')
				if parentPart and selected[parentPart] then
					saveTexture(obj)
					table.insert(newTextures, obj)
					activeTextures[obj] = true
				end

			elseif obj:IsA('SurfaceAppearance') then
				local parentPart = obj:FindFirstAncestorWhichIsA('BasePart')
				if parentPart and selected[parentPart] then
					saveSurface(obj)
					table.insert(newSurfaces, obj)
					activeSurfaces[obj] = true
				end
			end
		end

		for part in originals do
			if not activeParts[part] then
				restorePart(part)
			end
		end

		for obj in textureOriginals do
			if not activeTextures[obj] then
				restoreTexture(obj)
			end
		end

		for obj in surfaceOriginals do
			if not activeSurfaces[obj] then
				restoreSurface(obj)
			end
		end

		gunParts = newParts
		gunTextures = newTextures
		gunSurfaces = newSurfaces
	end

	local function applyGun(now)
		if not currentModel then return end

		local hue = (now * (optionValue(RainbowSpeed, 8) / 10)) % 1
		local rainbow = Color3.fromHSV(
			hue,
			optionValue(Saturation, 1),
			optionValue(Brightness, 1)
		)

		-- Pull SurfaceAppearance off the selected gun assembly so PBR maps
		-- cannot override the actual ForceField material.
		for _, surface in gunSurfaces do
			if surface then
				pcall(function()
					surface.Parent = nil
				end)
			end
		end

		for _, obj in gunTextures do
			if obj then
				pcall(function()
					if obj:IsA('Decal') or obj:IsA('Texture') then
						obj.Transparency = 1
					elseif obj:IsA('SpecialMesh') then
						obj.TextureId = ''
					end
				end)
			end
		end

		for _, part in gunParts do
			if part and part.Parent and part:IsDescendantOf(currentModel) then
				pcall(function()
					part.MaterialVariant = ''
					part.Material = Enum.Material.ForceField
					part.Color = rainbow
					part.Reflectance = 0
					part.Transparency = 0
					part.LocalTransparencyModifier = 0

					if part:IsA('MeshPart') then
						part.TextureID = ''
					end
				end)
			end
		end
	end

	GunChanger = vape.Categories.Render:CreateModule({
		Name = 'GunChanger',
		Function = function(callback)
			if callback then
				task.defer(function()
					while GunChanger and GunChanger.Enabled and not optionsReady do
						task.wait()
					end
					if not GunChanger or not GunChanger.Enabled then return end

					lastScan = 0

					GunChanger:Clean(runService.RenderStepped:Connect(function()
						if not optionsReady then return end

						local now = tick()
						local gun = currentEquipment()
						local model = getFPVModel()

						-- Frontlines type 2 is melee. Never recolor the knife.
						if not gun or gun.type == 2 then
							if currentModel then restoreAll() end
							return
						end

						if not model then
							if currentModel then
								restoreAll()
							end
							return
						end

						if model ~= currentModel or now - lastScan > 0.12 then
							lastScan = now
							scanGun()
						end

						applyGun(now)
					end))

					GunChanger:Clean(workspace.ChildAdded:Connect(function(obj)
						if obj.Name == 'Model' and obj:IsA('Model') then
							lastScan = 0
						end
					end))

					GunChanger:Clean(workspace.ChildRemoved:Connect(function(obj)
						if obj == currentModel then
							restoreAll()
							lastScan = 0
						end
					end))
				end)
			else
				restoreAll()
			end
		end,
		Tooltip = 'Applies a hard rainbow ForceField override to the actual Frontlines firearm assembly.'
	})

	RainbowSpeed = GunChanger:CreateSlider({
		Name = 'Rainbow Speed',
		Min = 1,
		Max = 30,
		Default = 8,
		Decimal = 10
	})

	Saturation = GunChanger:CreateSlider({
		Name = 'Saturation',
		Min = 0,
		Max = 1,
		Default = 1,
		Decimal = 100
	})

	Brightness = GunChanger:CreateSlider({
		Name = 'Brightness',
		Min = 0.1,
		Max = 1,
		Default = 1,
		Decimal = 100
	})

	BrightForceField = GunChanger:CreateToggle({
		Name = 'Bright ForceField',
		Default = true
	})

	optionsReady = true

	vape:Clean(function()
		restoreAll()
	end)
end)
-- ILLUSIONHD_GUNCHANGER_END

-- ILLUSIONHD_CUSTOMKNIFE_V8
run(function()
	local CustomKnife
	local AssetID
	local AssetModel
	local Scale
	local OffsetX
	local OffsetY
	local OffsetZ
	local RotationX
	local RotationY
	local RotationZ
	local HideOriginal

	local optionsReady = false
	local changingAssetList = false
	local template
	local visual
	local target
	local targetBoundsCF
	local targetBoundsSize
	local targetAnchor
	local targetAnchorOffset
	local lastTargetScan = 0
	local lastAppliedScale = -1
	local hiddenParts = {}

	local folder = Instance.new('Folder')
	folder.Name = 'IllusionHDCustomKnife'
	folder.Parent = gameCamera

	local function value(option, fallback)
		if option and option.Value ~= nil then
			return option.Value
		end
		return fallback
	end

	local function enabled(option, fallback)
		if option and option.Enabled ~= nil then
			return option.Enabled
		end
		return fallback
	end

	local function currentEquipment()
		local equipment = frontlines.Main
			and frontlines.Main.globals
			and frontlines.Main.globals.fpv_sol_equipment
		return equipment and equipment.curr_equipment or nil
	end

	local function lowerName(obj)
		return string.lower(tostring(obj and obj.Name or ''))
	end

	local function isBodyName(name)
		name = string.lower(tostring(name))
		return name:find('arm', 1, true)
			or name:find('hand', 1, true)
			or name:find('glove', 1, true)
			or name:find('sleeve', 1, true)
			or name:find('body', 1, true)
			or name:find('torso', 1, true)
			or name:find('head', 1, true)
	end

	local function isReticleName(name)
		name = string.lower(tostring(name))
		return name:find('reticle', 1, true)
			or name:find('crosshair', 1, true)
			or name:find('cross_hair', 1, true)
			or name:find('aimdot', 1, true)
			or name:find('aim_dot', 1, true)
			or name:find('hud', 1, true)
			or name == 'dot'
	end

	local function ignoredWeaponPart(part, root)
		local current = part
		while current and current ~= root do
			if isBodyName(current.Name) or isReticleName(current.Name) then
				return true
			end
			current = current.Parent
		end

		if part:FindFirstChildWhichIsA('SurfaceGui')
			or part:FindFirstChildWhichIsA('BillboardGui') then
			return true
		end

		return false
	end

	local function clearHidden()
		for part, oldValue in pairs(hiddenParts) do
			if part and part.Parent then
				pcall(function()
					part.LocalTransparencyModifier = oldValue
				end)
			end
		end
		table.clear(hiddenParts)
	end

	local function getWeaponParts(model)
		local parts = {}
		if not model then
			return parts
		end

		for _, obj in ipairs(model:GetDescendants()) do
			if obj:IsA('BasePart') and not ignoredWeaponPart(obj, model) then
				table.insert(parts, obj)
			end
		end

		return parts
	end

	local function hideWeapon(model)
		clearHidden()
		if not enabled(HideOriginal, true) or not model then
			return
		end

		for _, part in ipairs(getWeaponParts(model)) do
			if hiddenParts[part] == nil then
				hiddenParts[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 1
			end
		end
	end

	local function destroyVisual()
		if visual then
			visual:Destroy()
			visual = nil
		end
		target = nil
		targetBoundsCF = nil
		targetBoundsSize = nil
		targetAnchor = nil
		targetAnchorOffset = nil
		lastAppliedScale = -1
		clearHidden()
	end

	local function partCount(obj)
		if not obj then
			return 0
		end
		if obj:IsA('BasePart') then
			return 1
		end

		local count = 0
		for _, desc in ipairs(obj:GetDescendants()) do
			if desc:IsA('BasePart') then
				count = count + 1
			end
		end
		return count
	end

	local function collectAssetModels(objects)
		local choices = {}
		local names = {'Auto'}
		local used = {}

		local function addChoice(obj)
			if not obj or not obj:IsA('Model') or partCount(obj) == 0 then
				return
			end

			local base = tostring(obj.Name)
			if base == '' then
				base = 'Model'
			end

			local label = base
			local suffix = 2
			while used[label] do
				label = base .. ' #' .. tostring(suffix)
				suffix = suffix + 1
			end

			used[label] = true
			choices[label] = obj
			table.insert(names, label)
		end

		for _, root in ipairs(objects) do
			addChoice(root)
			for _, desc in ipairs(root:GetDescendants()) do
				addChoice(desc)
			end
		end

		-- Some uploaded assets contain only a MeshPart/Part and no Model.
		if #names == 1 then
			for _, root in ipairs(objects) do
				local candidates = {root}
				for _, desc in ipairs(root:GetDescendants()) do
					table.insert(candidates, desc)
				end

				for _, obj in ipairs(candidates) do
					if obj:IsA('BasePart') then
						local base = tostring(obj.Name)
						if base == '' then
							base = obj.ClassName
						end

						local label = base
						local suffix = 2
						while choices[label] do
							label = base .. ' #' .. tostring(suffix)
							suffix = suffix + 1
						end

						choices[label] = obj
						table.insert(names, label)
					end
				end
			end
		end

		return choices, names
	end

	local function chooseAssetObject(choices)
		local selected = value(AssetModel, 'Auto')
		if selected ~= 'Auto' and choices[selected] then
			return choices[selected]
		end

		local best
		local bestScore = -1

		for _, obj in pairs(choices) do
			local score = partCount(obj)
			if obj:IsA('Model') then
				score = score + 10000
			end

			if score > bestScore then
				bestScore = score
				best = obj
			end
		end

		return best
	end

	local function createTemplate(obj)
		if not obj then
			return nil
		end

		local wrapper = Instance.new('Model')
		wrapper.Name = 'CustomKnifeTemplate'

		local clone = obj:Clone()
		clone.Parent = wrapper

		for _, item in ipairs(wrapper:GetDescendants()) do
			if item:IsA('Script') or item:IsA('LocalScript') or item:IsA('ModuleScript') then
				item:Destroy()
			elseif item:IsA('BasePart') then
				item.Anchored = true
				item.CanCollide = false
				item.CanTouch = false
				item.CanQuery = false
				item.CastShadow = false
				item.Massless = true
			end
		end

		if not wrapper:FindFirstChildWhichIsA('BasePart', true) then
			wrapper:Destroy()
			return nil
		end

		-- Put the model pivot at the VISUAL center of the imported asset.
		-- This removes crazy asset pivots/offsets from Toolbox models.
		local bboxCF, bboxSize = wrapper:GetBoundingBox()

		local pivot = Instance.new('Part')
		pivot.Name = '__CustomKnifePivot'
		pivot.Size = Vector3.new(0.01, 0.01, 0.01)
		pivot.Transparency = 1
		pivot.Anchored = true
		pivot.CanCollide = false
		pivot.CanTouch = false
		pivot.CanQuery = false
		pivot.CastShadow = false
		pivot.CFrame = bboxCF
		pivot.Parent = wrapper
		wrapper.PrimaryPart = pivot

		wrapper:SetAttribute('KnifeBaseSize', bboxSize)
		return wrapper
	end

	local function rebuildVisual()
		if visual then
			visual:Destroy()
			visual = nil
		end

		lastAppliedScale = -1

		if not template or not CustomKnife or not CustomKnife.Enabled then
			return
		end

		visual = template:Clone()
		visual.Name = 'IllusionHDCustomKnifeModel'
		visual.Parent = folder
	end

	local function loadAsset(showError)
		local id = tostring(value(AssetID, '')):match('%d+')
		if not id then
			if showError then
				notif('CustomKnife', 'Enter a valid asset ID.', 5, 'alert')
			end
			return
		end

		local ok, objects = pcall(function()
			return game:GetObjects('rbxassetid://' .. id)
		end)

		if not ok or type(objects) ~= 'table' or #objects == 0 then
			notif('CustomKnife', 'Failed to load asset ' .. id, 5, 'alert')
			return
		end

		local choices, names = collectAssetModels(objects)
		local previous = value(AssetModel, 'Auto')

		if AssetModel then
			changingAssetList = true
			AssetModel:Change(names)

			if previous ~= 'Auto' and choices[previous] then
				AssetModel:SetValue(previous, false)
			else
				AssetModel:SetValue('Auto', false)
			end

			changingAssetList = false
		end

		local chosen = chooseAssetObject(choices)
		local newTemplate = createTemplate(chosen)

		for _, obj in ipairs(objects) do
			pcall(function()
				obj:Destroy()
			end)
		end

		if not newTemplate then
			notif('CustomKnife', 'No usable model or part found inside asset ' .. id, 5, 'alert')
			return
		end

		if template then
			template:Destroy()
		end

		template = newTemplate
		target = nil
		targetBoundsCF = nil
		targetBoundsSize = nil
		targetAnchor = nil
		targetAnchorOffset = nil
		lastTargetScan = 0
		rebuildVisual()
	end

	local function findKnifeTarget()
		local gun = currentEquipment()
		if not gun or gun.type ~= 2 then
			return nil
		end

		local model = workspace:FindFirstChild('Model')
		if model and model:IsA('Model') then
			return model
		end

		return nil
	end

	-- Calculate bounds using ONLY knife geometry, excluding hands/arms/reticle.
	-- The proxy model lets Roblox do the rotated bounding-box math for us.
	local function getFilteredBounds(model)
		local parts = getWeaponParts(model)
		if #parts == 0 then
			return nil, nil
		end

		local largest
		local largestVolume = -1

		for _, part in ipairs(parts) do
			local size = part.Size
			local volume = size.X * size.Y * size.Z
			if volume > largestVolume then
				largestVolume = volume
				largest = part
			end
		end

		local proxy = Instance.new('Model')
		local root = Instance.new('Part')
		root.Name = '__BoundsRoot'
		root.Size = Vector3.new(0.01, 0.01, 0.01)
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CFrame = largest and largest.CFrame or CFrame.new()
		root.Parent = proxy
		proxy.PrimaryPart = root

		for _, part in ipairs(parts) do
			local box = Instance.new('Part')
			box.Size = part.Size
			box.CFrame = part.CFrame
			box.Anchored = true
			box.Transparency = 1
			box.CanCollide = false
			box.Parent = proxy
		end

		local cf, size = proxy:GetBoundingBox()
		proxy:Destroy()
		return cf, size, largest
	end

	local function applyAutoScale()
		if not visual or not template or not targetBoundsSize then
			return
		end

		local baseSize = template:GetAttribute('KnifeBaseSize')
		if typeof(baseSize) ~= 'Vector3' then
			return
		end

		local baseMagnitude = math.max(baseSize.Magnitude, 0.001)
		local targetMagnitude = math.max(targetBoundsSize.Magnitude, 0.001)

		-- Normalize arbitrary Toolbox model size to Frontlines' actual knife size,
		-- then let the existing Scale slider act as a multiplier.
		local autoScale = math.clamp(targetMagnitude / baseMagnitude, 0.01, 100)
		local finalScale = autoScale * value(Scale, 1)

		if math.abs(finalScale - lastAppliedScale) > 0.001 then
			pcall(function()
				visual:ScaleTo(finalScale)
			end)
			lastAppliedScale = finalScale
		end
	end

	local function updateKnife()
		local gun = currentEquipment()

		-- Firearm equipped: hide custom knife but preserve it for instant return.
		if not gun or gun.type ~= 2 then
			target = nil
			targetBoundsCF = nil
			targetBoundsSize = nil
			targetAnchor = nil
			targetAnchorOffset = nil
			lastAppliedScale = -1
			clearHidden()

			if visual then
				visual.Parent = nil
			end
			return
		end

		if not visual then
			rebuildVisual()
		end
		if not visual then
			return
		end

		if folder.Parent ~= gameCamera then
			folder.Parent = gameCamera
		end
		if visual.Parent ~= folder then
			visual.Parent = folder
		end

		local now = tick()
		local newTarget = findKnifeTarget()

		-- Only rescan geometry occasionally or when Frontlines replaces workspace.Model.
		if newTarget ~= target
			or not target
			or not target.Parent
			or now - lastTargetScan > 0.12 then

			lastTargetScan = now

			if newTarget ~= target then
				clearHidden()
				lastAppliedScale = -1
				targetAnchor = nil
				targetAnchorOffset = nil
			end

			target = newTarget

			if target then
				local boundsCF, boundsSize, anchor = getFilteredBounds(target)
				targetBoundsCF = boundsCF
				targetBoundsSize = boundsSize
				targetAnchor = anchor

				if targetBoundsCF and targetAnchor and targetAnchor.Parent then
					targetAnchorOffset = targetAnchor.CFrame:ToObjectSpace(targetBoundsCF)
				else
					targetAnchorOffset = nil
				end

				hideWeapon(target)
			else
				targetBoundsCF = nil
				targetBoundsSize = nil
				targetAnchor = nil
				targetAnchorOffset = nil
			end
		end

		if not target or not target.Parent then
			return
		end

		applyAutoScale()

		-- Follow the live knife part every render frame instead of following
		-- the 0.12-second cached bounding box. This removes visible trailing.
		local liveCF = targetBoundsCF
		if targetAnchor
			and targetAnchor.Parent
			and targetAnchorOffset then
			liveCF = targetAnchor.CFrame * targetAnchorOffset
		end

		if not liveCF then
			return
		end

		local offset = CFrame.new(
			value(OffsetX, 0),
			value(OffsetY, 0),
			value(OffsetZ, 0)
		) * CFrame.Angles(
			math.rad(value(RotationX, 0)),
			math.rad(value(RotationY, 0)),
			math.rad(value(RotationZ, 0))
		)

		pcall(function()
			visual:PivotTo(liveCF * offset)
		end)
	end

	CustomKnife = vape.Categories.Render:CreateModule({
		Name = 'CustomKnife',
		Function = function(callback)
			if callback then
				if not template then
					loadAsset(true)
				else
					rebuildVisual()
				end

				lastTargetScan = 0
				local renderName = 'IllusionHDCustomKnifeFollow'
				pcall(function()
					runService:UnbindFromRenderStep(renderName)
				end)
				runService:BindToRenderStep(renderName, Enum.RenderPriority.Last.Value, updateKnife)
				CustomKnife:Clean(function()
					pcall(function()
						runService:UnbindFromRenderStep(renderName)
					end)
				end)
			else
				destroyVisual()
			end
		end,
		Tooltip = 'Loads a model from an asset ID, auto-centers/sizes it and locks it to the live Frontlines knife without render lag.'
	})

	AssetID = CustomKnife:CreateTextBox({
		Name = 'Asset ID',
		Default = '',
		Function = function()
			if optionsReady then
				loadAsset(false)
			end
		end
	})

	AssetModel = CustomKnife:CreateDropdown({
		Name = 'Asset Model',
		List = {'Auto'},
		Default = 'Auto',
		Function = function()
			if optionsReady and not changingAssetList then
				loadAsset(false)
			end
		end
	})

	Scale = CustomKnife:CreateSlider({
		Name = 'Scale',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 100,
		Function = function()
			lastAppliedScale = -1
		end
	})

	OffsetX = CustomKnife:CreateSlider({Name = 'Offset X', Min = -5, Max = 5, Default = 0, Decimal = 100})
	OffsetY = CustomKnife:CreateSlider({Name = 'Offset Y', Min = -5, Max = 5, Default = 0, Decimal = 100})
	OffsetZ = CustomKnife:CreateSlider({Name = 'Offset Z', Min = -5, Max = 5, Default = 0, Decimal = 100})
	RotationX = CustomKnife:CreateSlider({Name = 'Rotation X', Min = -180, Max = 180, Default = 0})
	RotationY = CustomKnife:CreateSlider({Name = 'Rotation Y', Min = -180, Max = 180, Default = 0})
	RotationZ = CustomKnife:CreateSlider({Name = 'Rotation Z', Min = -180, Max = 180, Default = 0})

	HideOriginal = CustomKnife:CreateToggle({
		Name = 'Hide Original',
		Default = true,
		Function = function()
			clearHidden()
			if target then
				hideWeapon(target)
			end
		end
	})

	optionsReady = true

	vape:Clean(function()
		destroyVisual()

		if template then
			template:Destroy()
			template = nil
		end

		pcall(function()
			folder:Destroy()
		end)
	end)
end)
-- ILLUSIONHD_CUSTOMKNIFE_END

-- ILLUSIONHD_SKYTHEMES_V1
run(function()
	local SkyThemes
	local Theme
	local lightingService = cloneref(game:GetService('Lighting'))
	local boykisserSky = getvapeasset('newvape/assets/new/boykesser.png')

	local skyThemes = {
			Boykisser = {
				SkyboxBk = boykisserSky,
				SkyboxDn = boykisserSky,
				SkyboxFt = boykisserSky,
				SkyboxLf = boykisserSky,
				SkyboxRt = boykisserSky,
				SkyboxUp = boykisserSky,
			},
		        NetherWorld = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://14365019002',
			            SkyboxDn = 'rbxassetid://14365023350',
			            SkyboxFt = 'rbxassetid://14365018399',
			            SkyboxLf = 'rbxassetid://14365018705',
			            SkyboxRt = 'rbxassetid://14365018143',
			            SkyboxUp = 'rbxassetid://14365019327',
		        },
		        Neptune = {
				    SkyboxBk = 'rbxassetid://218955819',
				    SkyboxDn = 'rbxassetid://218953419',
				    SkyboxFt = 'rbxassetid://218954524',
				    SkyboxLf = 'rbxassetid://218958493',
				    SkyboxRt = 'rbxassetid://218957134',
				    SkyboxUp = 'rbxassetid://218950090',
		        },
		        Velocity = {
			            SkyboxBk = 'rbxassetid://570557514',
			            SkyboxDn = 'rbxassetid://570557775',
			            SkyboxFt = 'rbxassetid://570557559',
			            SkyboxLf = 'rbxassetid://570557620',
			            SkyboxRt = 'rbxassetid://570557672',
			            SkyboxUp = 'rbxassetid://570557727',
		        },
		        Minecraft = {
			            SkyboxBk = 'rbxassetid://591058823',
			            SkyboxDn = 'rbxassetid://591059876',
			            SkyboxFt = 'rbxassetid://591058104',
			            SkyboxLf = 'rbxassetid://591057861',
			            SkyboxRt = 'rbxassetid://591057625',
			            SkyboxUp = 'rbxassetid://591059642',
		        },
		        Purple = {
			            SkyboxBk = "rbxassetid://8539982183",
			            SkyboxDn = "rbxassetid://8539981943",
			            SkyboxFt = "rbxassetid://8539981721",
			            SkyboxLf = "rbxassetid://8539981424",
			            SkyboxRt = "rbxassetid://8539980766",
			            SkyboxUp = "rbxassetid://8539981085",
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            StarCount = 3000,
		        }, 
		        ["日の出"] = {
				    SkyboxBk = "rbxassetid://600830446",
				    SkyboxDn = "rbxassetid://600831635",
				    SkyboxFt = "rbxassetid://600832720",
				    SkyboxLf = "rbxassetid://600886090",
				    SkyboxRt = "rbxassetid://600833862",
				    SkyboxUp = "rbxassetid://600835177",
		        },
		        Sakura = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=16694315897",
			            SkyboxDn = "http://www.roblox.com/asset/?id=16694319417",
			            SkyboxFt = "http://www.roblox.com/asset/?id=16694324910",
			            SkyboxLf = "http://www.roblox.com/asset/?id=16694328308",
			            SkyboxRt = "http://www.roblox.com/asset/?id=16694331447",
			            SkyboxUp = "http://www.roblox.com/asset/?id=16694334666",
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Hexagonal = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=15876463105",
			            SkyboxDn = "http://www.roblox.com/asset/?id=15876464432",
			            SkyboxFt = "http://www.roblox.com/asset/?id=15876465852",
			            SkyboxLf = "http://www.roblox.com/asset/?id=15876467260",
			            SkyboxRt = "http://www.roblox.com/asset/?id=15876469097",
			            SkyboxUp = "http://www.roblox.com/asset/?id=15876470945",
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Reality = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=6778646360",
			            SkyboxDn = "http://www.roblox.com/asset/?id=6778658683",
			            SkyboxFt = "http://www.roblox.com/asset/?id=6778648039",
			            SkyboxLf = "http://www.roblox.com/asset/?id=6778649136",
			            SkyboxRt = "http://www.roblox.com/asset/?id=6778650519",
			            SkyboxUp = "http://www.roblox.com/asset/?id=6778658364",
		        },
		        LunarNight = {
			            SkyboxBk = 'rbxassetid://187713366',
			            SkyboxDn = 'rbxassetid://187712428',
			            SkyboxFt = 'rbxassetid://187712836',
			            SkyboxLf = 'rbxassetid://187713755',
			            SkyboxRt = 'rbxassetid://187714525',
			            SkyboxUp = 'rbxassetid://187712111',
			            SunAngularSize = 0,
			            StarCount = 0,
		        },
		        FPSBoost = {
			            SkyboxBk = 'rbxassetid://11457548274',
			            SkyboxDn = 'rbxassetid://11457548274',
			            SkyboxFt = 'rbxassetid://11457548274',
			            SkyboxLf = 'rbxassetid://11457548274',
			            SkyboxRt = 'rbxassetid://11457548274',
			            SkyboxUp = 'rbxassetid://11457548274',
			            SunAngularSize = 0,
			            StarCount = 3000,
		        },
		        Etheral = {
			            SkyboxBk = 'rbxassetid://16262356578',
			            SkyboxDn = 'rbxassetid://16262358026',
			            SkyboxFt = 'rbxassetid://16262360469',
			            SkyboxLf = 'rbxassetid://16262362003',
			            SkyboxRt = 'rbxassetid://16262363873',
			            SkyboxUp = 'rbxassetid://16262366016',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Pandora = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=16739324092',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=16739325541',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=16739327056',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=16739329370',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=16739331050',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=16739332736',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Polaris = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=16823270864',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=16823272150',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=16823273508',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=16823274898',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=16823276281',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=16823277547',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Diaphanous = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=16888989874',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=16888991855',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=16888995219',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=16888998994',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=16889000916',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=16889004122',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Transcendent = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=17124357467',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=17124359797',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=17124362093',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=17124365127',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=17124367200',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=17124369657',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Truth = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=144933338",
			            SkyboxDn = "http://www.roblox.com/asset/?id=144931530",
			            SkyboxFt = "http://www.roblox.com/asset/?id=144933262",
			            SkyboxLf = "http://www.roblox.com/asset/?id=144933244",
			            SkyboxRt = "http://www.roblox.com/asset/?id=144933299",
			            SkyboxUp = "http://www.roblox.com/asset/?id=144931564",
		        },
		        RayTracing = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=271042516",
			            SkyboxDn = "http://www.roblox.com/asset/?id=271077243",
			            SkyboxFt = "http://www.roblox.com/asset/?id=271042556",
			            SkyboxLf = "http://www.roblox.com/asset/?id=271042310",
			            SkyboxRt = "http://www.roblox.com/asset/?id=271042467",
			            SkyboxUp = "http://www.roblox.com/asset/?id=271077958",
		        },
		        Nebula = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://5260808177',
			            SkyboxDn = 'rbxassetid://5260653793',
			            SkyboxFt = 'rbxassetid://5260817288',
			            SkyboxLf = 'rbxassetid://5260800833',
			            SkyboxRt = 'rbxassetid://5260811073',
			            SkyboxUp = 'rbxassetid://5260824661',
		        },
		        Planets = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://15983968922',
			            SkyboxDn = 'rbxassetid://15983966825',
			            SkyboxFt = 'rbxassetid://15983965025',
			            SkyboxLf = 'rbxassetid://15983967420',
			            SkyboxRt = 'rbxassetid://15983966246',
			            SkyboxUp = 'rbxassetid://15983964246',
			            StarCount = 3000,
		        },
		        Galaxy = {
			            SkyboxBk = "rbxassetid://159454299",
			            SkyboxDn = "rbxassetid://159454296",
			            SkyboxFt = "rbxassetid://159454293",
			            SkyboxLf = "rbxassetid://159454293",
			            SkyboxRt = "rbxassetid://159454293",
			            SkyboxUp = "rbxassetid://159454288",
			            SunAngularSize = 0,
		        }, 
		        Blues = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=17124357467',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=17124359797',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=17124362093',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=17124365127',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=17124367200',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=17124369657',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Milkyway = {
			            MoonTextureId = 'rbxassetid://1075087760',
			            SkyboxBk = 'rbxassetid://2670643994',
			            SkyboxDn = 'rbxassetid://2670643365',
			            SkyboxFt = 'rbxassetid://2670643214',
			            SkyboxLf = 'rbxassetid://2670643070',
			            SkyboxRt = 'rbxassetid://2670644173',
			            SkyboxUp = 'rbxassetid://2670644331',
			            MoonAngularSize = 1.5,
			            StarCount = 500,
		        },
		        Orange = {
			            SkyboxBk = 'rbxassetid://150939022',
			            SkyboxDn = 'rbxassetid://150939038',
			            SkyboxFt = 'rbxassetid://150939047',
			            SkyboxLf = 'rbxassetid://150939056',
			            SkyboxRt = 'rbxassetid://150939063',
			            SkyboxUp = 'rbxassetid://150939082',
		        },
		        DarkMountains = {
			            SkyboxBk = 'rbxassetid://5098814730',
			            SkyboxDn = 'rbxassetid://5098815227',
			            SkyboxFt = 'rbxassetid://5098815653',
			            SkyboxLf = 'rbxassetid://5098816155',
			            SkyboxRt = 'rbxassetid://5098820352',
			            SkyboxUp = 'rbxassetid://5098819127',
		        },
		        Space = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://166509999',
			            SkyboxDn = 'rbxassetid://166510057',
			            SkyboxFt = 'rbxassetid://166510116',
			            SkyboxLf = 'rbxassetid://166510092',
			            SkyboxRt = 'rbxassetid://166510131',
			            SkyboxUp = 'rbxassetid://166510114',
		        },
		        Void = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://14543264135',
			            SkyboxDn = 'rbxassetid://14543358958',
			            SkyboxFt = 'rbxassetid://14543257810',
			            SkyboxLf = 'rbxassetid://14543275895',
			            SkyboxRt = 'rbxassetid://14543280890',
			            SkyboxUp = 'rbxassetid://14543371676',
		        },
		        Stary = {
			            SkyboxBk = 'rbxassetid://248431616',
			            SkyboxDn = 'rbxassetid://248431677',
			            SkyboxFt = 'rbxassetid://248431598',
			            SkyboxLf = 'rbxassetid://248431686',
			            SkyboxRt = 'rbxassetid://248431611',
			            SkyboxUp = 'rbxassetid://248431605',
				    StarCount = 3000,       
		        },
			Violet = {
				    SkyboxBk = 'rbxassetid://8107841671',
				    SkyboxDn = 'rbxassetid://6444884785',
				    SkyboxFt = 'rbxassetid://8107841671',
				    SkyboxLf = 'rbxassetid://8107841671',
				    SkyboxRt = 'rbxassetid://8107841671',
				    SkyboxUp = 'rbxassetid://8107849791',
				    SunTextureId = 'rbxassetid://6196665106',
				    MoonTextureId = 'rbxassetid://6444320592',
				    MoonAngularSize = 0,
		        },
			Cloudy = {
				    SkyboxBk = 'rbxassetid://15876597103',
				    SkyboxDn = 'rbxassetid://15876592775',
				    SkyboxFt = 'rbxassetid://15876640231',
				    SkyboxLf = 'rbxassetid://15876638420',
				    SkyboxRt = 'rbxassetid://15876595486',
				    SkyboxUp = 'rbxassetid://15876639348',
				    SunTextureId = 'rbxasset://sky/sun.jpg',
				    MoonTextureId = 'rbxasset://sky/moon.jpg',
				    MoonAngularSize = 11,
		            	    SunAngularSize = 21,
				    StarCount = 3000,
		    	}
	}
	local themeNames = {'Boykisser', 'NetherWorld', 'Neptune', 'Velocity', 'Minecraft', 'Purple', '日の出', 'Sakura', 'Hexagonal', 'Reality', 'LunarNight', 'FPSBoost', 'Etheral', 'Pandora', 'Polaris', 'Diaphanous', 'Transcendent', 'Truth', 'RayTracing', 'Nebula', 'Planets', 'Galaxy', 'Blues', 'Milkyway', 'Orange', 'DarkMountains', 'Space', 'Void', 'Stary', 'Violet', 'Cloudy'}

	local skyProperties = {
		'CelestialBodiesShown',
		'MoonAngularSize',
		'MoonTextureId',
		'SkyboxBk',
		'SkyboxDn',
		'SkyboxFt',
		'SkyboxLf',
		'SkyboxRt',
		'SkyboxUp',
		'SkyboxOrientation',
		'SunAngularSize',
		'SunTextureId',
		'SunTextureId',
		'StarCount'
	}

	local defaultSky = Instance.new('Sky')
	local defaults = {}
	for _, property in skyProperties do
		pcall(function()
			defaults[property] = defaultSky[property]
		end)
	end
	defaultSky:Destroy()

	local storedSkies = Instance.new('Folder')
	storedSkies.Name = 'IllusionHDStoredSkies'
	storedSkies.Parent = vape.holder

	local activeSky

	local function resetSky(sky)
		for property, value in defaults do
			pcall(function()
				sky[property] = value
			end)
		end
	end

	local function applyTheme(name)
		local data = skyThemes[name]
		if not data then return end

		if not activeSky or not activeSky.Parent then
			activeSky = Instance.new('Sky')
			activeSky.Name = 'IllusionHDSky'
			activeSky.Parent = lightingService
		end

		-- Reset first so one theme cannot leak StarCount/sun/moon settings into another.
		resetSky(activeSky)

		for property, value in data do
			pcall(function()
				activeSky[property] = value
			end)
		end
	end

	local function storeGameSkies()
		for _, obj in lightingService:GetChildren() do
			if obj:IsA('Sky') and obj ~= activeSky then
				obj.Parent = storedSkies
			end
		end
	end

	local function restoreGameSkies()
		if activeSky then
			activeSky:Destroy()
			activeSky = nil
		end

		for _, obj in storedSkies:GetChildren() do
			if obj:IsA('Sky') then
				obj.Parent = lightingService
			end
		end
	end

	SkyThemes = vape.Categories.Render:CreateModule({
		Name = 'SkyThemes',
		Function = function(callback)
			if callback then
				storeGameSkies()
				applyTheme(Theme.Value)

				SkyThemes:Clean(lightingService.ChildAdded:Connect(function(obj)
					if obj:IsA('Sky') and obj ~= activeSky then
						task.defer(function()
							if SkyThemes.Enabled and obj.Parent == lightingService and obj ~= activeSky then
								obj.Parent = storedSkies
							end
						end)
					end
				end))
			else
				restoreGameSkies()
			end
		end,
		Tooltip = 'Replaces the game sky with selectable custom skybox themes.'
	})

	Theme = SkyThemes:CreateDropdown({
		Name = 'Theme',
		List = themeNames,
		Default = 'Purple',
		Function = function(value)
			if SkyThemes.Enabled then
				applyTheme(value)
			end
		end
	})

	vape:Clean(function()
		restoreGameSkies()
		pcall(function()
			storedSkies:Destroy()
		end)
	end)
end)
-- ILLUSIONHD_SKYTHEMES_END

-- ILLUSIONHD_FIREFLIES_V1
run(function()
	local Fireflies
	local Count
	local Radius
	local Height
	local Speed
	local Size
	local Brightness
	local ColorMode
	local PrimaryColor
	local SecondaryColor
	local Trails

	local Folder = Instance.new('Folder')
	Folder.Name = 'IllusionHDFireflies'
	Folder.Parent = workspace

	local fireflies = {}
	local rng = Random.new()

	local function currentCenter()
		if entitylib.isAlive and entitylib.character and entitylib.character.RootPart then
			return entitylib.character.RootPart.Position
		end
		if gameCamera then
			return gameCamera.CFrame.Position
		end
		return Vector3.zero
	end

	local function chooseColor(index)
		if ColorMode.Value == 'Rainbow' then
			return Color3.fromHSV((tick() * 0.08 + index / math.max(Count.Value, 1)) % 1, 0.75, 1)
		elseif ColorMode.Value == 'Warm' then
			local alpha = rng:NextNumber()
			return Color3.fromRGB(
				math.floor(255),
				math.floor(180 + 70 * alpha),
				math.floor(60 + 90 * alpha)
			)
		end

		local a = Color3.fromHSV(PrimaryColor.Hue, PrimaryColor.Sat, PrimaryColor.Value)
		local b = Color3.fromHSV(SecondaryColor.Hue, SecondaryColor.Sat, SecondaryColor.Value)
		return a:Lerp(b, rng:NextNumber())
	end

	local function randomOffset()
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = math.sqrt(rng:NextNumber()) * Radius.Value
		local y = rng:NextNumber(-Height.Value * 0.25, Height.Value)
		return Vector3.new(math.cos(angle) * dist, y, math.sin(angle) * dist)
	end

	local function respawn(data, center)
		data.Base = center + randomOffset()
		data.Offset = Vector3.zero
		data.Phase = rng:NextNumber(0, math.pi * 2)
		data.Phase2 = rng:NextNumber(0, math.pi * 2)
		data.Drift = Vector3.new(
			rng:NextNumber(-1, 1),
			rng:NextNumber(-0.3, 0.8),
			rng:NextNumber(-1, 1)
		)
		if data.Drift.Magnitude < 0.05 then
			data.Drift = Vector3.new(1, 0.2, 0)
		end
		data.Drift = data.Drift.Unit
		data.Color = chooseColor(data.Index)
		data.Part.Color = data.Color
		data.Light.Color = data.Color
		if data.Trail then
			data.Trail.Color = ColorSequence.new(data.Color)
		end
	end

	local function createFirefly(index)
		local p = Instance.new('Part')
		p.Name = 'Firefly'
		p.Shape = Enum.PartType.Ball
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Size = Vector3.one * Size.Value
		p.Transparency = 0.05
		p.Parent = Folder

		local light = Instance.new('PointLight')
		light.Brightness = Brightness.Value
		light.Range = math.max(3, Size.Value * 22)
		light.Shadows = false
		light.Parent = p

		local att0 = Instance.new('Attachment')
		att0.Position = Vector3.new(0, 0, -Size.Value * 0.4)
		att0.Parent = p

		local att1 = Instance.new('Attachment')
		att1.Position = Vector3.new(0, 0, Size.Value * 0.4)
		att1.Parent = p

		local trail = Instance.new('Trail')
		trail.Attachment0 = att0
		trail.Attachment1 = att1
		trail.FaceCamera = true
		trail.Lifetime = 0.25
		trail.MinLength = 0.01
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1)
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0)
		})
		trail.Enabled = Trails.Enabled
		trail.Parent = p

		local data = {
			Index = index,
			Part = p,
			Light = light,
			Trail = trail,
			Base = Vector3.zero,
			Offset = Vector3.zero,
			Phase = 0,
			Phase2 = 0,
			Drift = Vector3.zero,
			Color = Color3.new(1, 1, 1),
			Age = rng:NextNumber(0, 8)
		}

		respawn(data, currentCenter())
		fireflies[index] = data
	end

	local function rebuild()
		for _, data in fireflies do
			pcall(function()
				data.Part:Destroy()
			end)
		end
		table.clear(fireflies)

		if not Fireflies.Enabled then return end
		for i = 1, Count.Value do
			createFirefly(i)
		end
	end

	Fireflies = vape.Categories.Render:CreateModule({
		Name = 'Fireflies',
		Function = function(callback)
			if callback then
				rebuild()

				Fireflies:Clean(runService.RenderStepped:Connect(function(dt)
					local center = currentCenter()
					local now = tick()

					for i, data in fireflies do
						if not data.Part or not data.Part.Parent then
							continue
						end

						data.Age += dt
						local speed = Speed.Value
						local bob = Vector3.new(
							math.sin(now * (0.8 + speed * 0.35) + data.Phase) * (0.7 + speed * 0.15),
							math.sin(now * (1.2 + speed * 0.22) + data.Phase2) * (0.55 + speed * 0.12),
							math.cos(now * (0.9 + speed * 0.3) + data.Phase) * (0.7 + speed * 0.15)
						)

						data.Offset += data.Drift * dt * speed * 1.5
						local target = data.Base + data.Offset + bob

						-- If the player has moved far away, recycle the firefly around the new area.
						if (target - center).Magnitude > Radius.Value * 1.45 + Height.Value then
							respawn(data, center)
							target = data.Base
						end

						-- Small random direction changes keep movement organic.
						if math.floor(data.Age * 2) ~= math.floor((data.Age - dt) * 2) and rng:NextNumber() < 0.22 then
							local change = Vector3.new(
								rng:NextNumber(-0.65, 0.65),
								rng:NextNumber(-0.2, 0.35),
								rng:NextNumber(-0.65, 0.65)
							)
							if change.Magnitude > 0.05 then
								data.Drift = (data.Drift:Lerp(change.Unit, 0.35)).Unit
							end
						end

						if ColorMode.Value == 'Rainbow' then
							data.Color = Color3.fromHSV((now * 0.08 + i / math.max(#fireflies, 1)) % 1, 0.75, 1)
							data.Part.Color = data.Color
							data.Light.Color = data.Color
							data.Trail.Color = ColorSequence.new(data.Color)
						end

						local pulse = 0.72 + math.sin(now * 2.2 + data.Phase) * 0.28
						data.Part.Size = Vector3.one * Size.Value * (0.8 + pulse * 0.3)
						data.Light.Brightness = Brightness.Value * (0.65 + pulse * 0.65)
						data.Light.Range = math.max(3, Size.Value * 22) * (0.85 + pulse * 0.25)

						data.Part.CFrame = CFrame.new(target)
					end
				end))
			else
				for _, data in fireflies do
					pcall(function()
						data.Part:Destroy()
					end)
				end
				table.clear(fireflies)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Spawns glowing fireflies that drift around the world as you move.'
	})

	Count = Fireflies:CreateSlider({
		Name = 'Quantity',
		Min = 10,
		Max = 250,
		Default = 85
	})

	Radius = Fireflies:CreateSlider({
		Name = 'Radius',
		Min = 15,
		Max = 250,
		Default = 90,
		Suffix = ' studs'
	})

	Height = Fireflies:CreateSlider({
		Name = 'Height',
		Min = 5,
		Max = 80,
		Default = 30,
		Suffix = ' studs'
	})

	Speed = Fireflies:CreateSlider({
		Name = 'Speed',
		Min = 0.1,
		Max = 6,
		Default = 1.5,
		Decimal = 10
	})

	Size = Fireflies:CreateSlider({
		Name = 'Size',
		Min = 0.05,
		Max = 0.8,
		Default = 0.18,
		Decimal = 100,
		Function = function()
			for _, data in fireflies do
				if data.Part then
					data.Part.Size = Vector3.one * Size.Value
				end
			end
		end
	})

	Brightness = Fireflies:CreateSlider({
		Name = 'Brightness',
		Min = 0,
		Max = 5,
		Default = 1.8,
		Decimal = 10,
		Function = function()
			for _, data in fireflies do
				if data.Light then
					data.Light.Brightness = Brightness.Value
				end
			end
		end
	})

	ColorMode = Fireflies:CreateDropdown({
		Name = 'Color Mode',
		List = {'Custom', 'Warm', 'Rainbow'},
		Default = 'Warm',
		Function = function()
			for _, data in fireflies do
				respawn(data, currentCenter())
			end
		end
	})

	PrimaryColor = Fireflies:CreateColorSlider({
		Name = 'Primary Color',
		DefaultHue = 0.13,
		DefaultSat = 0.85,
		DefaultValue = 1,
		Function = function()
			if ColorMode.Value == 'Custom' then
				for _, data in fireflies do
					respawn(data, currentCenter())
				end
			end
		end
	})

	SecondaryColor = Fireflies:CreateColorSlider({
		Name = 'Secondary Color',
		DefaultHue = 0.18,
		DefaultSat = 0.7,
		DefaultValue = 1,
		Function = function()
			if ColorMode.Value == 'Custom' then
				for _, data in fireflies do
					respawn(data, currentCenter())
				end
			end
		end
	})

	Trails = Fireflies:CreateToggle({
		Name = 'Trails',
		Default = true,
		Function = function(callback)
			for _, data in fireflies do
				if data.Trail then
					data.Trail.Enabled = callback
				end
			end
		end
	})

	vape:Clean(function()
		for _, data in fireflies do
			pcall(function()
				data.Part:Destroy()
			end)
		end
		table.clear(fireflies)
		pcall(function()
			Folder:Destroy()
		end)
	end)
end)
-- ILLUSIONHD_FIREFLIES_END

-- ILLUSIONHD_EFFECTS_V4_BEGIN
-- 26 authored timelines. No aliases, asset downloads, character edits, or camera effects.
-- Trail API: https://create.roblox.com/docs/reference/engine/classes/Trail
run(function()
	local V = Vector3.new
	local ZERO, WHITE = Vector3.zero, Color3.new(1, 1, 1)
	local TAU = math.pi * 2
	local scenes, controllers = {}, {}
	local root = Instance.new('Folder')
	root.Name = 'IllusionHDV4Effects'
	root.Parent = workspace
	local HitStyles, KillStyles = {}, {}
	local HitNames = {'Needlepoint', 'Glassbite', 'Redline', 'Short Circuit', 'Inkblot', 'Hard Reset',
		'Petal Kiss', 'Cold Snap', 'Echo Chamber', 'Firecracker', 'Star Stitch', 'Orbit Trap'}
	local KillNames = {'Event Horizon', 'Heavenfall', 'Paper Moon', 'Dead Channel', 'Rose Requiem',
		'Winterglass', 'Railbreak', 'Afterimage', 'Clockwork', 'Wildfire', 'Deepwater', 'Faultline', 'Last Blossom', 'Royal Flush'}
	local palettes = {
		['Needlepoint'] = {0xffdd8b, 0xff8759}, ['Glassbite'] = {0x9cfff2, 0xb4bdff},
		['Redline'] = {0xff375c, 0xffbdce}, ['Short Circuit'] = {0x75f7ff, 0x7f80ff},
		['Inkblot'] = {0xc0a2ff, 0xf8eaff}, ['Hard Reset'] = {0x54ffc5, 0xfe62ce},
		['Petal Kiss'] = {0xff92bb, 0xffdfdb}, ['Cold Snap'] = {0xa3dcff, 0xe7fcff},
		['Echo Chamber'] = {0x7dabff, 0xba9aff}, ['Firecracker'] = {0xff8b38, 0xffe18c},
		['Star Stitch'] = {0xffdf83, 0xfff1cc}, ['Orbit Trap'] = {0xd59aff, 0x99bfff},
		['Event Horizon'] = {0x9c63ff, 0xffa5e0}, ['Heavenfall'] = {0xffd985, 0xffffec},
		['Paper Moon'] = {0xe8efff, 0x91afff}, ['Dead Channel'] = {0x70ffbc, 0xd0fff0},
		['Rose Requiem'] = {0xfa497e, 0xffb2cf}, ['Winterglass'] = {0x6dceff, 0xc8f9ff},
		['Railbreak'] = {0xff653b, 0xffd899}, ['Afterimage'] = {0x61f5ff, 0xf971ff},
		['Clockwork'] = {0xffc75e, 0xffedb0}, ['Wildfire'] = {0xff581d, 0xffce49},
		['Deepwater'] = {0x57baff, 0x9affe3}, ['Faultline'] = {0xff9951, 0xffdf92},
		['Last Blossom'] = {0xf5ffdc, 0xb5edcb}, ['Royal Flush'] = {0xff5279, 0xffd275}
	}
	local function rgb(hex)
		return Color3.fromRGB(math.floor(hex / 65536) % 256, math.floor(hex / 256) % 256, hex % 256)
	end
	local function out(t) return 1 - (1 - t)^3 end
	local function fade(t) return math.clamp((t - 0.42) / 0.58, 0, 1) end
	local function polar(angle, radius, z) return V(math.cos(angle) * radius, math.sin(angle) * radius, z or 0) end
	local function noise() return math.random() * 2 - 1 end
	local function limit(value, default, lo, hi)
		value = tonumber(value)
		return value and value == value and math.clamp(value, lo, hi) or default
	end
	local function removeScene(index)
		local s = scenes[index]
		s.Alive = false
		s.Folder:Destroy()
		table.remove(scenes, index)
	end
	local function clearController(controller)
		for i = #scenes, 1, -1 do if scenes[i].Owner == controller then removeScene(i) end end
	end

	local Scene = {}
	Scene.__index = Scene
	function Scene:count(n)
		return math.max(1, math.floor(n * self.Quality * (self.Kill and (0.85 + self.Intensity * 0.15) or 1) + 0.5))
	end
	function Scene:world(v, ground)
		return (ground and self.GroundFrame or self.Frame):PointToWorldSpace(v * self.Scale)
	end
	function Scene:part(color, shape, material)
		if self.Parts >= self.Budget then return nil end
		self.Parts = self.Parts + 1
		local p = Instance.new(shape == 'Wedge' and 'WedgePart' or 'Part')
		p.Name = self.Name
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.Material = material or Enum.Material.Neon
		p.Color, p.Transparency = color, 1
		p.Size, p.CFrame = V(0.02, 0.02, 0.02), CFrame.new(self.Position)
		if shape == 'Ball' then p.Shape = Enum.PartType.Ball end
		p.Parent = self.Folder
		return p
	end
	function Scene:track(obj, delay, duration, fn)
		if not obj then return end
		local item = {Object = obj, Start = delay or 0, Duration = math.max(duration or 1, 0.01), Update = fn}
		self.Items[#self.Items + 1] = item
		-- Initialize before adding trails; a delayed element is never flashed at the origin.
		if item.Start <= 0 then fn(obj, 0) end
	end
	function Scene:trail(part, width)
		if not part or not self.Trails or self.TrailCount >= (self.Kill and 14 or 6) then return end
		self.TrailCount = self.TrailCount + 1
		local a, b = Instance.new('Attachment'), Instance.new('Attachment')
		a.Position, b.Position = V(0, width * self.Scale, 0), V(0, -width * self.Scale, 0)
		a.Parent, b.Parent = part, part
		local trail = Instance.new('Trail')
		trail.Attachment0, trail.Attachment1 = a, b
		trail.Color = ColorSequence.new(part.Color, self.B)
		trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1)})
		trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
		trail.FaceCamera, trail.LightEmission, trail.LightInfluence = true, 1, 0
		trail.Lifetime, trail.MinLength, trail.Enabled = math.min(self.Life * 0.18, 0.22), 0.015, false
		trail.Parent = part
		self.TrailObjects[part] = trail
	end
	function Scene:dot(color, size, delay, duration, trajectory, shape, material, opacity)
		local p = self:part(color, shape or 'Ball', material)
		self:track(p, delay, duration, function(obj, u)
			local pos, spin, stretch = trajectory(u)
			obj.CFrame = self.Frame * CFrame.new(pos * self.Scale) * (spin or CFrame.new())
			local k = math.max(stretch or (1 - u * 0.65), 0.025)
			obj.Size = V(math.max(size.X * k * self.Scale, 0.015), math.max(size.Y * k * self.Scale, 0.015), math.max(size.Z * k * self.Scale, 0.015))
			obj.Transparency = math.clamp((opacity or 0.08) + fade(u) * (1 - (opacity or 0.08)), 0, 1)
		end)
		return p
	end
	function Scene:line(color, width, delay, duration, trajectory, ground)
		local p = self:part(color)
		self:track(p, delay, duration, function(obj, u)
			local a, b, alpha = trajectory(u)
			a, b = self:world(a, ground), self:world(b, ground)
			local length = (b - a).Magnitude
			if length < 0.001 then obj.Transparency = 1; return end
			obj.CFrame = CFrame.lookAt((a + b) * 0.5, b)
			local w = math.max(width * self.Scale * (1 - fade(u) * 0.7), 0.008)
			obj.Size = V(w, w, length)
			obj.Transparency = math.clamp(alpha or (0.05 + fade(u) * 0.95), 0, 1)
		end)
		return p
	end
	function Scene:arc(color, width, delay, duration, curve, ground, segments)
		local n = math.max(10, self:count(segments or 24))
		for i = 1, n do
			local t0, t1 = (i - 1) / n, i / n
			self:line(color, width, delay, duration, function(u)
				return curve(t0, u), curve(t1, u)
			end, ground)
		end
	end
	function Scene:light(delay, duration, power)
		if not self.Glow then return end
		local p = self:part(self.A)
		if not p then return end
		local light = Instance.new('PointLight')
		light.Color, light.Range, light.Brightness, light.Shadows = self.A, (self.Kill and 12 or 5) * self.Scale, 0, false
		light.Parent = p
		self:track(p, delay, duration, function(obj, u)
			obj.Transparency = 1
			light.Brightness = (power or 2) * self.Intensity * (1 - u)^2
		end)
	end
	function Scene:rayBurst(n, length, color, delay, duration, lift)
		for i = 1, self:count(n) do
			local dir = polar(i * 2.39996, 0.75 + math.random() * 0.25, noise() * 0.3)
			self:line(i % 3 == 0 and self.B or color, 0.035, delay + math.random() * 0.025, duration, function(u)
				local r = out(u) * length
				local drift = V(0, (lift or 0) * u - 0.4 * u * u, 0)
				return dir * (r + 0.08) + drift, dir * (r + 0.38 * (1 - u)) + drift
			end)
		end
	end
	function Scene:ghosts(count)
		local result, char = {}, self.Data.Character
		if char and char.Parent then
			for _, obj in ipairs(char:GetDescendants()) do
				if obj:IsA('BasePart') and obj.Transparency < 0.95 and obj.Name ~= 'HumanoidRootPart' then
					result[#result + 1] = {Size = obj.Size, Frame = obj.CFrame}
					if #result >= count then break end
				end
			end
		end
		-- Stylized body fallback keeps the finisher visible if the ragdoll was already removed.
		if #result == 0 then
			for _, item in ipairs({{V(1, 1, 1), V(0, 1.6, 0)}, {V(1.6, 1.9, 0.7), ZERO},
				{V(0.6, 1.8, 0.6), V(-1.15, 0, 0)}, {V(0.6, 1.8, 0.6), V(1.15, 0, 0)},
				{V(0.65, 1.7, 0.65), V(-0.45, -1.75, 0)}, {V(0.65, 1.7, 0.65), V(0.45, -1.75, 0)}}) do
				result[#result + 1] = {Size = item[1], Frame = self.Frame * CFrame.new(item[2])}
			end
		end
		return result
	end

	-- HIT TIMELINES -----------------------------------------------------------
	HitStyles['Needlepoint'] = function(s)
		s:light(0, 0.18, 2)
		for i = 1, 7 do
			local dir = polar(i / 7 * TAU + 0.2, 1, noise() * 0.16)
			s:line(i % 2 == 0 and WHITE or s.A, i % 2 == 0 and 0.024 or 0.045, i * 0.008, 0.68, function(u)
				local r = out(u) * 1.15
				return dir * (0.06 + r), dir * (0.52 + r - u * 0.34)
			end)
		end
		s:rayBurst(4, 0.8, s.B, 0.18, 0.7, -0.25)
	end
	HitStyles['Glassbite'] = function(s)
		for i = 1, 5 do
			local theta = i / 5 * TAU
			local joint = polar(theta, 0.5)
			local endp = polar(theta + 0.22, 1.1)
			s:line(WHITE, 0.016, 0, 0.35, function(u) return ZERO, joint * out(u) end)
			s:line(s.A, 0.018, 0.06, 0.35, function(u) return joint, joint:Lerp(endp, out(u)) end)
			local dir = polar(theta, 1.4, noise() * 0.7)
			s:dot(i % 2 == 0 and s.A or s.B, V(0.22, 0.48, 0.07), 0.17, 0.8, function(u)
				return joint * 0.5 + dir * out(u) + V(0, -u * u * 0.75, 0), CFrame.Angles(u * 7, theta, u * 3)
			end, 'Wedge', Enum.Material.Glass, 0.12)
		end
	end
	HitStyles['Redline'] = function(s)
		for i = 1, 2 do
			local sign = i == 1 and 1 or -1
			s:arc(i == 1 and s.A or WHITE, i == 1 and 0.065 or 0.022, (i - 1) * 0.16, 0.58, function(v, u)
				local a = -1.2 + v * 2.3 + out(u) * 1.7
				return V(math.cos(a) * 1.15 * sign, math.sin(a) * 0.72, 0.1 * sign)
			end, false, 18)
		end
		s:line(s.B, 0.025, 0.34, 0.5, function(u) return V(-0.4, 0.7, 0), V(0.4, -0.7, 0) * (1 + out(u) * 0.25) end)
	end
	HitStyles['Short Circuit'] = function(s)
		for branch = 1, 3 do
			local previous = ZERO
			for step = 1, 5 do
				local nextPoint = polar(branch / 3 * TAU + (step % 2 == 0 and 0.2 or -0.2), step * 0.26)
				local a, b = previous, nextPoint
				s:line(step % 2 == 0 and WHITE or s.A, 0.027, step * 0.035, 0.4, function(u)
					return a, b, math.floor(u * 8) % 3 == 1 and 0.85 or fade(u)
				end)
				previous = nextPoint
			end
			local tip = previous
			s:dot(s.B, V(0.11, 0.11, 0.11), 0.2, 0.55, function(u) return tip, nil, 1 - u end)
		end
		s:light(0.06, 0.24, 2.5)
	end
	HitStyles['Inkblot'] = function(s)
		for i = 1, 9 do
			local dir = polar(i * 2.399, 0.3 + math.random() * 0.4)
			local size = 0.2 + math.random() * 0.28
			s:dot(Color3.fromRGB(12, 8, 20), V(size, size * 1.15, 0.055), i * 0.007, 0.8, function(u)
				return dir * out(u) + V(0, -u * u * 0.2, 0), nil, math.sin(math.min(u * 2.4, math.pi)) + 0.15
			end, 'Ball', Enum.Material.SmoothPlastic, 0)
		end
		for i = 1, 3 do
			local p = polar(i * 2.1, 0.48)
			s:line(s.B, 0.018, 0.06, 0.7, function(u) return p, p + V(0.18, -0.28 - u * 0.35, 0.06) end)
		end
	end
	HitStyles['Hard Reset'] = function(s)
		for i = 1, 4 do
			local x = i % 2 == 0 and 1 or -1
			local y = i <= 2 and 1 or -1
			s:line(s.A, 0.035, 0, 0.5, function(u)
				local p = V(x, y, 0) * (0.8 - out(u) * 0.45)
				return p, p - V(x * 0.24, 0, 0)
			end)
			s:line(s.B, 0.035, 0.03, 0.5, function(u)
				local p = V(x, y, 0) * (0.8 - out(u) * 0.45)
				return p, p - V(0, y * 0.24, 0)
			end)
		end
		for i = 1, s:count(8) do
			local row, dir = (i - 4) * 0.13, i % 2 == 0 and 1 or -1
			s:dot(i % 2 == 0 and s.A or s.B, V(0.28, 0.065, 0.065), 0.28, 0.7, function(u)
				return V(dir * math.floor(u * 5) * 0.23, row, 0), nil, 1 - u * 0.7
			end, 'Block')
		end
	end
	HitStyles['Petal Kiss'] = function(s)
		for i = 1, 5 do
			local a = i / 5 * TAU
			local petal = s:dot(i % 2 == 0 and s.A or s.B, V(0.22, 0.49, 0.055), i * 0.018, 0.89, function(u)
				local open = out(math.min(u * 2, 1))
				local p = polar(a, 0.24 + open * 0.2) + V(math.sin(u * 6 + a) * u * 0.45, u * u * 0.65, 0)
				return p, CFrame.Angles(u * 2, u * 1.5, a - math.pi / 2 + u * 0.7), 0.3 + open * 0.7
			end, 'Ball', Enum.Material.SmoothPlastic)
			s:trail(petal, 0.025)
		end
		s:dot(WHITE, V(0.13, 0.13, 0.13), 0.05, 0.5, function(u) return ZERO, nil, 1 - u end)
	end
	HitStyles['Cold Snap'] = function(s)
		for i = 1, 6 do
			local a = i / 6 * TAU
			local dir = polar(a, 1)
			s:line(s.B, 0.022, 0, 0.64, function(u) return ZERO, dir * (0.18 + out(u) * 0.68) end)
			for _, sign in ipairs({-1, 1}) do
				local joint, tip = dir * 0.46, dir * 0.46 + polar(a + sign * 0.8, 0.28)
				s:line(s.A, 0.02, 0.13, 0.51, function(u) return joint, joint:Lerp(tip, out(u)) end)
			end
			s:dot(s.A, V(0.08, 0.25, 0.05), 0.5, 0.5, function(u)
				return dir * 0.75 + V(0, -u * u * 0.8, 0), CFrame.Angles(0, 0, a + u * 3)
			end, 'Wedge', Enum.Material.Glass)
		end
	end
	HitStyles['Echo Chamber'] = function(s)
		for i = 1, 3 do
			s:arc(i == 2 and s.B or s.A, 0.019, (i - 1) * 0.17, 0.62, function(v, u)
				return polar(v * TAU, 0.18 + out(u) * (0.65 + i * 0.21), (i - 2) * 0.17)
			end, false, 24)
		end
	end
	HitStyles['Firecracker'] = function(s)
		s:dot(WHITE, V(0.22, 0.22, 0.22), 0, 0.13, function(u) return ZERO, nil, 1 - u end)
		for i = 1, s:count(10) do
			local velocity = V(noise() * 1.3, 0.3 + math.random() * 1.4, noise() * 0.4)
			local p = s:dot(i % 3 == 0 and s.B or s.A, V(0.065, 0.065, 0.065), 0.05, 0.88, function(u)
				return velocity * u + V(0, -1.3 * u * u, 0)
			end)
			s:trail(p, 0.026)
		end
		for i = 1, 3 do
			s:dot(Color3.fromRGB(74, 66, 62), V(0.24, 0.24, 0.24), 0.18, 0.78, function(u)
				return V((i - 2) * 0.12, u * 0.45, -0.15), nil, 0.4 + u * 1.5
			end, 'Ball', Enum.Material.SmoothPlastic, 0.82)
		end
		s:light(0, 0.22, 3)
	end
	HitStyles['Star Stitch'] = function(s)
		for i = 0, 4 do
			local a = polar(i / 5 * TAU + math.pi / 2, 0.65)
			local b = polar((i + 2) / 5 * TAU + math.pi / 2, 0.65)
			s:line(i % 2 == 0 and s.A or s.B, 0.026, i * 0.065, 0.58, function(u) return a, a:Lerp(b, out(u)) end)
			s:dot(WHITE, V(0.07, 0.07, 0.07), 0.38, 0.6, function(u)
				return a + V(math.sin(u * 4 + i) * u * 0.3, u * 0.65, 0)
			end)
		end
	end
	HitStyles['Orbit Trap'] = function(s)
		for i = 1, 3 do
			local phase = i / 3 * TAU
			local p = s:dot(i == 2 and s.B or s.A, V(0.11, 0.11, 0.11), 0, 0.9, function(u)
				local r = (0.35 + math.sin(u * math.pi) * 0.4) * (1 - u)
				local a = phase + u * TAU * 1.3
				return V(math.cos(a) * r, math.sin(a) * r * 0.45, math.sin(a) * r * 0.65)
			end)
			s:trail(p, 0.045)
		end
		s:dot(WHITE, V(0.16, 0.16, 0.16), 0.74, 0.24, function(u) return ZERO, nil, math.sin(u * math.pi) end)
	end

	-- KILL TIMELINES ----------------------------------------------------------
	KillStyles['Event Horizon'] = function(s)
		s:dot(Color3.fromRGB(5, 2, 12), V(1.7, 1.7, 1.7), 0, 0.86, function(u)
			return ZERO, nil, math.sin(u * math.pi)^0.55
		end, 'Ball', Enum.Material.SmoothPlastic, 0)
		for i = 1, 2 do
			s:arc(i == 1 and s.A or s.B, i == 1 and 0.055 or 0.022, 0, 0.86, function(v, u)
				local a = v * TAU + u * TAU * (i == 1 and 1 or -1)
				local r = (1.2 + v * 0.85) * (1 - u * 0.91)
				return V(math.cos(a) * r, math.sin(a) * r * 0.35, math.sin(a) * r * 0.5)
			end, false, 28)
		end
		for i = 1, s:count(12) do
			local a = i * 2.39996
			local p = s:dot(i % 2 == 0 and s.A or s.B, V(0.1, 0.1, 0.1), 0.05, 0.8, function(u)
				local r = (2.4 + math.sin(i) * 0.4) * (1 - out(u))
				return polar(a + u * 4, r, math.sin(a) * r * 0.3)
			end)
			s:trail(p, 0.05)
		end
		s:line(WHITE, 0.03, 0.83, 0.17, function(u) return V(-0.65 * (1 - u), 0, 0), V(0.65 * (1 - u), 0, 0) end)
		s:light(0.8, 0.15, 4)
	end
	KillStyles['Heavenfall'] = function(s)
		for i = 1, 3 do
			local landing = V((i - 2) * 0.85, -1.8, 0)
			local start = landing + V(2.2, 8 + i, -0.5)
			s:line(i == 2 and WHITE or s.A, i == 2 and 0.18 or 0.09, (i - 1) * 0.13, 0.45, function(u)
				local head = start:Lerp(landing, math.min(u * 2.3, 1))
				return head, head:Lerp(start, (1 - u) * 0.45)
			end)
		end
		s:line(s.B, 0.23, 0.46, 0.42, function(u) return V(0, -1.8, 0), V(0, 7 * (1 - u * 0.3), 0) end)
		if s.Ground then
			for i = 1, 8 do
				local dir = polar(i / 8 * TAU, 1, 0.03)
				s:line(s.A, 0.045, 0.45, 0.5, function(u) return dir * 0.3, dir * (0.4 + out(u) * 2.6) end, true)
			end
		end
		s:light(0.43, 0.28, 6)
	end
	KillStyles['Paper Moon'] = function(s)
		for i = 1, 2 do
			s:arc(i == 1 and s.A or s.B, i == 1 and 0.13 or 0.025, (i - 1) * 0.06, 0.74, function(v, u)
				local a = -1.35 + v * 3.9 + out(u) * 0.9
				return V(math.cos(a) * (1.65 + i * 0.13), math.sin(a) * 1.95 + u * 0.65, 0)
			end, false, 28)
		end
		for i = 1, s:count(13) do
			local phase = i * 2.3999
			s:dot(i % 3 == 0 and s.B or s.A, V(0.28, 0.42, 0.025), 0.12 + (i % 4) * 0.04, 0.72, function(u)
				return V(math.cos(phase + u * 3) * (0.6 + u * 1.8), -0.8 + u * 3.8, math.sin(phase + u * 3) * 0.8),
					CFrame.Angles(u * 4 + phase, u * 2, phase)
			end, 'Block', Enum.Material.SmoothPlastic)
		end
	end
	KillStyles['Dead Channel'] = function(s)
		for i = 1, 16 do
			local y, sign = -2.1 + i * 0.26, i % 2 == 0 and 1 or -1
			s:dot(i % 3 == 0 and WHITE or s.A, V(1.45 - math.abs(y) * 0.12, 0.075, 0.15), i * 0.012, 0.7, function(u)
				local snap = math.floor(u * 7) / 7
				return V(sign * snap * snap * 3, y, 0), nil, 1 - u * 0.55
			end, 'Block')
		end
		s:line(s.B, 0.06, 0, 0.6, function(u)
			local y = -2.4 + u * 5
			return V(-1.4, y, 0.2), V(1.4, y, 0.2)
		end)
		for i = 1, 6 do
			local x = (i - 3.5) * 0.35
			s:line(s.A, 0.025, 0.66, 0.28, function(u) return V(x, -0.04, 0), V(x, 0.04 + (1 - u) * (i % 3) * 0.25, 0) end)
		end
	end
	KillStyles['Rose Requiem'] = function(s)
		for layer = 1, 2 do
			for i = 1, 7 do
				local phase = i / 7 * TAU + layer * 0.36
				s:dot(layer == 1 and s.A or s.B, V(0.48, 0.82, 0.1), layer * 0.045, 0.89, function(u)
					local r = 0.2 + out(math.min(u * 2.4, 1)) * (0.48 + layer * 0.3) + u * u
					local a = phase + u * 1.7
					return V(math.cos(a) * r, -1.5 + u * u * 4.5, math.sin(a) * r), CFrame.Angles(0.5 + u * 2, -a, phase + u)
				end, 'Ball', Enum.Material.SmoothPlastic)
			end
		end
		s:arc(s.B, 0.025, 0.1, 0.8, function(v, u)
			local a = v * TAU * 1.5 + u * 2
			return V(math.cos(a) * (0.5 + v * 0.4), -1.8 + v * 3.4, math.sin(a) * (0.5 + v * 0.4))
		end, false, 28)
	end
	KillStyles['Winterglass'] = function(s)
		for i = 1, 7 do
			local a, height = i / 7 * TAU, 1.5 + (i % 3) * 0.65
			local start = V(math.cos(a) * 0.8, -1.6, math.sin(a) * 0.8)
			s:dot(i % 2 == 0 and s.A or s.B, V(0.36, height, 0.36), i * 0.015, 0.64, function(u)
				local growth = out(math.min(u * 3, 1))
				return start + V(0, height * growth * 0.5, 0), CFrame.Angles(0, a, math.sin(a) * 0.18), growth
			end, 'Wedge', Enum.Material.Glass, 0.17)
		end
		for i = 1, s:count(16) do
			local velocity = V(noise() * 2.4, math.random() * 2.8, noise() * 2.4)
			s:dot(i % 2 == 0 and WHITE or s.A, V(0.13, 0.43, 0.1), 0.52, 0.47, function(u)
				return velocity * u + V(0, -u * u * 2, 0), CFrame.Angles(i, u * 8, u * 4)
			end, 'Wedge', Enum.Material.Glass)
		end
		s:light(0.5, 0.22, 4)
	end
	KillStyles['Railbreak'] = function(s)
		for _, sign in ipairs({-1, 1}) do
			s:line(s.A, 0.075, 0, 0.38, function(u)
				local x = sign * (2.3 - out(u) * 1.4)
				return V(x, -0.8, 0), V(x, 0.8, 0)
			end)
			s:line(s.B, 0.045, 0.05, 0.33, function(u)
				local x = sign * (2.3 - out(u) * 1.4)
				return V(x, 0.8, 0), V(x - sign * 0.5, 0.8, 0)
			end)
		end
		s:line(WHITE, 0.16, 0.34, 0.24, function(u) return V(-6, 0, 0), V(-6 + out(u) * 13, 0, 0) end)
		s:line(s.A, 0.04, 0.38, 0.54, function(u) return V(-5, 0, 0), V(7, 0, 0) end)
		for i = 1, s:count(12) do
			local y, x, z = noise() * 1.6, 2 + math.random() * 4, noise() * 0.12
			s:dot(i % 2 == 0 and s.A or s.B, V(0.35, 0.065, 0.07), 0.35, 0.6, function(u)
				return V(out(u) * x, y * u, z), CFrame.Angles(0, 0, y * 0.3)
			end, 'Block')
		end
		s:light(0.34, 0.22, 6)
	end
	KillStyles['Afterimage'] = function(s)
		local parts = s:ghosts(14)
		for copy = 1, 3 do
			for i, data in ipairs(parts) do
				local p = s:part(copy == 2 and WHITE or (copy == 1 and s.A or s.B), 'Block', Enum.Material.ForceField)
				s:track(p, (copy - 1) * 0.09, 0.76, function(obj, u)
					local drift = s.Frame:VectorToWorldSpace(V((copy - 2) * out(u) * 2.3, u * 0.8, -u * copy * 0.4) * s.Scale)
					obj.CFrame = data.Frame + (data.Frame.Position - s.Position) * (s.Scale - 1) + drift
					obj.Size = data.Size * s.Scale * (1 + u * 0.05)
					obj.Transparency = math.clamp(0.5 + u * 0.43 + (i / #parts) * u * 0.16, 0, 1)
				end)
			end
		end
	end
	KillStyles['Clockwork'] = function(s)
		for layer = 1, 2 do
			s:arc(layer == 1 and s.A or s.B, 0.035, 0, 0.68, function(v, u)
				return polar(v * TAU, (1.45 + layer * 0.23) * (0.3 + out(math.min(u * 3, 1)) * 0.7))
			end, false, 28)
		end
		for i = 1, 12 do
			local a = i / 12 * TAU
			s:line(s.A, i % 3 == 0 and 0.065 or 0.035, 0.06, 0.9, function(u)
				local fly = math.max(0, u - 0.65) * 4
				return polar(a + fly * 0.2, 1.48 + fly), polar(a + fly * 0.2, 1.63 + fly)
			end)
		end
		for i = 1, 2 do
			s:line(i == 1 and WHITE or s.B, 0.035, 0, 0.66, function(u)
				local a = (1 - math.min(u * 1.6, 1))^2 * TAU * (i == 1 and 2 or -3)
				return ZERO, polar(a, i == 1 and 1.22 or 0.8)
			end)
		end
	end
	KillStyles['Wildfire'] = function(s)
		for i = 1, s:count(11) do
			local phase = i * 2.3999
			s:dot(i % 3 == 0 and s.B or s.A, V(0.28, 1.25 + (i % 3) * 0.3, 0.16), (i % 4) * 0.055, 0.72, function(u)
				local a, r = phase + u * 2.6, 0.3 + math.sin(u * math.pi) * 0.8
				return V(math.cos(a) * r, -1.8 + u * 3.8, math.sin(a) * r), CFrame.Angles(0.2, a, math.sin(u * 7 + i) * 0.3), math.sin(u * math.pi) + 0.05
			end, 'Wedge')
		end
		for i = 1, s:count(14) do
			local dir = V(noise(), 1.6 + math.random() * 2, noise())
			local p = s:dot(s.B, V(0.06, 0.1, 0.06), 0.14, 0.84, function(u)
				return dir * u + V(math.sin(u * 6 + i) * u * 0.2, -0.5, 0)
			end)
			s:trail(p, 0.025)
		end
		s:light(0.08, 0.7, 3.5)
	end
	KillStyles['Deepwater'] = function(s)
		for i = 1, 3 do
			local start = V((i - 2) * 0.6, -1.4 + i * 0.45, 0)
			s:dot(i == 2 and s.A or s.B, V(0.9, 0.9, 0.9), (i - 1) * 0.08, 0.8, function(u)
				return start + V(math.sin(u * 5 + i) * 0.3, u * 2.8, 0), nil, 0.6 + u * 0.7
			end, 'Ball', Enum.Material.ForceField, 0.42)
		end
		for i = 1, s:count(14) do
			local phase = i * 2.3999
			s:dot(s.B, V(0.11, 0.11, 0.11), (i % 5) * 0.035, 0.8, function(u)
				return V(math.cos(phase + u * 4) * (0.6 + u * 0.4), -1.9 + u * (3.3 + i % 3), math.sin(phase + u * 4) * 0.7)
			end, 'Ball', Enum.Material.Glass, 0.28)
		end
		if s.Ground then s:arc(s.A, 0.025, 0.08, 0.78, function(v, u) return polar(v * TAU, 0.4 + out(u) * 1.7, 0.04) end, true, 28) end
	end
	KillStyles['Faultline'] = function(s)
		if s.Ground then
			for i = 1, 6 do
				local a = i / 6 * TAU
				local last = ZERO
				for j = 1, 3 do
					local nextp = polar(a + (j % 2 == 0 and 0.16 or -0.12), j * 0.8, 0.035)
					local p0, p1 = last, nextp
					s:line(s.A, 0.05, j * 0.025, 0.74, function(u) return p0, p0:Lerp(p1, out(u)) end, true)
					last = nextp
				end
			end
		end
		for i = 1, s:count(11) do
			local a, r = i * 2.3999, 0.5 + (i % 4) * 0.37
			local p = s:part(i % 4 == 0 and s.A or Color3.fromRGB(52, 46, 44), 'Block', i % 4 == 0 and Enum.Material.Neon or Enum.Material.Slate)
			s:track(p, 0.06, 0.9, function(obj, u)
				local height = math.sin(u * math.pi) * (0.5 + (i % 3) * 0.4)
				local localPoint = polar(a, r + u * 0.5, height + 0.16)
				obj.CFrame = CFrame.new(s:world(localPoint, true)) * CFrame.Angles(i + u * 2, a, u)
				obj.Size = V(0.32, 0.24, 0.4) * s.Scale * (1 - u * 0.4)
				obj.Transparency = fade(u)
			end)
		end
		s:light(0.08, 0.45, 2)
	end
	KillStyles['Last Blossom'] = function(s)
		for i = 1, s:count(19) do
			local a = i * 2.3999
			local initial = polar(a, 0.5 + (i % 3) * 0.14, math.sin(i) * 0.3)
			local dir = V(1.3 + (i % 4) * 0.35, 0.9 + (i % 3) * 0.5, math.sin(i) * 0.7)
			s:dot(i % 3 == 0 and s.B or s.A, V(0.08, 0.08, 0.08), 0, 0.96, function(u)
				local drift = math.max(0, u - 0.2) / 0.8
				return initial + dir * drift + V(0, math.sin(drift * 5 + a) * drift * 0.22, 0)
			end, 'Ball', Enum.Material.SmoothPlastic)
			s:line(s.B, 0.012, 0, 0.96, function(u)
				local drift = math.max(0, u - 0.2) / 0.8
				local p = initial + dir * drift + V(0, math.sin(drift * 5 + a) * drift * 0.22, 0)
				return p, p + V(-0.13, -0.19, 0)
			end)
		end
	end
	KillStyles['Royal Flush'] = function(s)
		for i = 1, 4 do
			local sign, angle = i - 2.5, (i - 2.5) * -0.22
			local function cardPose(u)
				local spread = out(math.min(u * 3, 1))
				local fold = math.max(0, u - 0.55) / 0.45
				return V(sign * 0.62 * spread * (1 - fold), 0.3 + math.abs(sign) * -0.16 + u * 0.6, i * 0.06),
					CFrame.Angles(0, fold * math.pi, angle * spread), 1 - fold * 0.88
			end
			s:dot(i % 2 == 0 and Color3.fromRGB(27, 19, 32) or Color3.fromRGB(247, 233, 220), V(0.65, 1.0, 0.035), i * 0.025, 0.81, cardPose, 'Block', Enum.Material.SmoothPlastic)
			s:dot(i % 2 == 0 and s.B or s.A, V(0.18, 0.18, 0.025), i * 0.025, 0.81, function(u)
				local p, rotation, scale = cardPose(u)
				return p + rotation:VectorToWorldSpace(V(0, 0, 0.035)), rotation * CFrame.Angles(0, 0, math.pi / 4), scale
			end, 'Block')
		end
		for i = 1, s:count(12) do
			local direction = V(noise() * 2.4, 1 + math.random() * 1.6, noise() * 0.7)
			s:dot(i % 2 == 0 and s.A or s.B, V(0.13, 0.18, 0.025), 0.65, 0.34, function(u)
				return direction * u + V(0, -u * u * 1.3, 0), CFrame.Angles(u * 6, i, u * 3)
			end, 'Block')
		end
	end

	local function getColors(c, name, data)
		local style = palettes[name]
		local a, b = rgb(style[1]), rgb(style[2])
		local mode = c.ColorMode.Value
		if mode == 'Custom' then
			a = Color3.fromHSV(c.Primary.Hue, c.Primary.Sat, c.Primary.Value)
			b = Color3.fromHSV(c.Secondary.Hue, c.Secondary.Sat, c.Secondary.Value)
		elseif mode == 'Theme' then
			local ok, color = pcall(function() return vape:GetGUIColorRGB() end)
			if ok and typeof(color) == 'Color3' then a, b = color, color:Lerp(WHITE, 0.65) end
		elseif mode == 'Target' then
			local color = data.Color
			if not color and data.Entity then
				local ok, result = pcall(entitylib.getEntityColor, data.Entity)
				if ok then color = result end
			end
			if typeof(color) == 'Color3' then a, b = color, color:Lerp(WHITE, 0.65) end
		elseif mode == 'Pastel' then
			a, b = a:Lerp(WHITE, 0.45), b:Lerp(WHITE, 0.45)
		elseif mode == 'Rainbow' then
			local hue = (os.clock() * 0.14) % 1
			a, b = Color3.fromHSV(hue, 0.7, 1), Color3.fromHSV((hue + 0.28) % 1, 0.65, 1)
		end
		return a, b
	end
	local function playSound(c, folder)
		if not c.Sound or not c.Sound.Enabled then return end
		local input = tostring(c.SoundFile.Value or ''):gsub('^%s+', ''):gsub('%s+$', '')
		if input == '' then return end
		if c.SoundInput ~= input then
			c.SoundInput, c.SoundAsset = input, nil
			if input:match('^%d+$') then c.SoundAsset = 'rbxassetid://'..input
			elseif input:match('^rbxassetid://') or input:match('^rbxasset://') then c.SoundAsset = input
			else
				local register = getcustomasset or getsynasset or getasset
				if register then
					local ok, asset = pcall(register, input:gsub('^file://', ''):gsub('\\', '/'))
					if ok and type(asset) == 'string' then c.SoundAsset = asset end
				end
			end
		end
		if not c.SoundAsset then return end
		local sound = Instance.new('Sound')
		sound.SoundId, sound.Volume = c.SoundAsset, limit(c.SoundVolume.Value, 0.7, 0, 2)
		sound.Parent = folder
		sound:Play()
	end
	local function makeScene(c, data)
		if not c.Active or typeof(data.Position) ~= 'Vector3' then return end
		local pos = data.Position
		if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z or pos.Magnitude > 1e7 then return end
		local names, styles = c.Kill and KillNames or HitNames, c.Kill and KillStyles or HitStyles
		local name = c.Mode.Value
		if name == 'Random' then
			local pick = math.random(1, #names)
			if names[pick] == c.LastStyle then pick = pick % #names + 1 end
			name = names[pick]
		end
		-- Old saved modes deliberately resolve to the new default, never to aliases in the menu.
		if not styles[name] then name = names[1] end
		c.LastStyle = name
		local count, total = 0, 0
		for _, scene in ipairs(scenes) do if scene.Owner == c then count = count + 1 end end
		local maxScenes = math.floor(limit(c.Limit.Value, c.Kill and 3 or 6, 1, 10))
		while count >= maxScenes do
			for i, scene in ipairs(scenes) do
				if scene.Owner == c then removeScene(i); count = count - 1; break end
			end
		end
		local q = c.Quality.Value == 'Low' and 0.65 or (c.Quality.Value == 'High' and 1.2 or 1)
		local budget = c.Kill and (q < 1 and 100 or (q > 1 and 210 or 170)) or (q < 1 and 60 or (q > 1 and 125 or 100))
		for _, scene in ipairs(scenes) do total = total + scene.Parts end
		while #scenes > 0 and total + budget > 900 do total = total - scenes[1].Parts; removeScene(1) end
		local camera = workspace.CurrentCamera or gameCamera
		local target = camera and camera.CFrame.Position or (pos + V(0, 0, 5))
		if c.Kill then target = V(target.X, pos.Y, target.Z) end
		if (target - pos).Magnitude < 0.01 then target = pos + V(0, 0, 5) end
		local basis = CFrame.lookAt(pos, target)
		local groundPos, normal = pos - V(0, 2.4, 0), V(0, 1, 0)
		if c.Kill then
			local params = RaycastParams.new()
			params.FilterType, params.IgnoreWater = Enum.RaycastFilterType.Exclude, true
			local filter = {root}
			if data.Character then filter[#filter + 1] = data.Character end
			if camera then filter[#filter + 1] = camera end
			if lplr.Character then filter[#filter + 1] = lplr.Character end
			params.FilterDescendantsInstances = filter
			local ray = workspace:Raycast(pos + V(0, 1, 0), V(0, -16, 0), params)
			if ray then groundPos, normal = ray.Position + ray.Normal * 0.06, ray.Normal end
		end
		local right = normal:Cross(V(0, 0, 1))
		if right.Magnitude < 0.01 then right = V(1, 0, 0) else right = right.Unit end
		local folder = Instance.new('Folder')
		folder.Name, folder.Parent = (c.Kill and 'Kill_' or 'Hit_')..name, root
		local a, b = getColors(c, name, data)
		local s = setmetatable({
			Name = name, Owner = c, Kill = c.Kill, Data = data, Position = pos, Frame = basis,
			GroundFrame = CFrame.fromMatrix(groundPos, right, normal:Cross(right), normal),
			Ground = c.Ground and c.Ground.Enabled or false,
			Scale = limit(c.Size.Value, 1, 0.25, 3) * (not c.Kill and data.Headshot and 1.08 or 1),
			Life = limit(c.Life.Value, c.Kill and 1.6 or 0.46, c.Kill and 0.35 or 0.1, c.Kill and 3.5 or 1.5),
			Quality = q, Intensity = c.Intensity and limit(c.Intensity.Value, 1, 0.5, 2) or 1,
			Glow = c.Glow.Enabled, Trails = c.Trails.Enabled, A = a, B = b,
			Folder = folder, Started = os.clock(), Items = {}, TrailObjects = {}, TrailCount = 0,
			Parts = 0, Budget = budget, Alive = true, EndTime = 1
		}, Scene)
		scenes[#scenes + 1] = s
		local ok, err = pcall(styles[name], s)
		if not ok then
			for i = #scenes, 1, -1 do if scenes[i] == s then removeScene(i); break end end
			warn('[illusionHD] '..name..' effect: '..tostring(err))
			return
		end
		for _, item in ipairs(s.Items) do s.EndTime = math.max(s.EndTime, item.Start + item.Duration) end
		if c.Kill then pcall(playSound, c, folder) end
	end

	local function trimHits(c)
		local now = os.clock()
		for i = #c.Pending, 1, -1 do if now - c.Pending[i].Time > 0.8 then table.remove(c.Pending, i) end end
		while #c.Pending > 48 do table.remove(c.Pending, 1) end
	end
	local function rememberDeath(c, ent)
		if not ent or ent.Id == nil then return end
		local previous, health = c.Health[ent.Id], tonumber(ent.Health) or 0
		c.Health[ent.Id] = health
		if previous and previous > 0 and health <= 0 then
			local hit = c.Hits[ent.Id]
			local part = ent.RootPart
			if hit and os.clock() - hit.Time <= 1.8 then
				local color
				pcall(function() color = entitylib.getEntityColor(ent) end)
				c.Deaths[#c.Deaths + 1] = {Id = ent.Id, Position = part and part.Position or hit.Position,
					Character = ent.Character, Entity = ent, Color = color, Headshot = hit.Headshot,
					Time = os.clock(), HitTime = hit.Time}
			end
		end
		while #c.Deaths > 24 do table.remove(c.Deaths, 1) end
	end
	local function consumeDeath(c)
		local now = os.clock()
		for i = #c.Deaths, 1, -1 do if now - c.Deaths[i].Time > 1.5 then table.remove(c.Deaths, i) end end
		local preferred = frontlines.LastLocalHit
		if preferred then
			for i, death in ipairs(c.Deaths) do if death.Id == preferred.Id then table.remove(c.Deaths, i); return death end end
		end
		-- Every cached death already requires a recent local hit; unrelated deaths are excluded.
		if #c.Deaths > 0 then return table.remove(c.Deaths, 1) end
	end
	local function reset(c)
		c.Generation = c.Generation + 1
		clearController(c)
		table.clear(c.Pending); table.clear(c.Health); table.clear(c.Hits)
		table.clear(c.Deaths); table.clear(c.Credits)
	end
	local function createController(kill)
		local c = {Kill = kill, Active = false, Generation = 0, Pending = {}, Health = {}, Hits = {}, Deaths = {}, Credits = {}}
		controllers[#controllers + 1] = c
		local names = kill and KillNames or HitNames
		local menu = {}
		for _, name in ipairs(names) do menu[#menu + 1] = name end
		menu[#menu + 1] = 'Random'
		c.Module = vape.Categories.Render:CreateModule({
			Name = kill and 'KillEffects' or 'HitEffects',
			Tooltip = kill and '14 distinct finishers with staged animation, authored palettes and bounded cleanup.'
				or '12 distinct hit reactions: fractures, ink, cuts, petals, circuitry, frost and more.',
			Function = function(enabled)
				c.Active = enabled
				reset(c)
				if not enabled then return end
				for _, ent in pairs(entitylib.List) do if ent and ent.Id ~= nil then c.Health[ent.Id] = ent.Health or 100 end end
				c.Module:Clean(frontlines.LocalHitEvent.Event:Connect(function(ent, pos, headshot)
					if not c.Active or not ent or ent.Id == nil or typeof(pos) ~= 'Vector3' then return end
					if kill then
						c.Hits[ent.Id] = {Time = os.clock(), Position = pos, Headshot = headshot}
						return
					end
					if c.Headshots.Enabled and not headshot then return end
					local hit = {Id = ent.Id, Entity = ent, Position = pos, Headshot = headshot,
						Health = ent.Health or c.Health[ent.Id] or 100, Time = os.clock()}
					if not c.Confirmed.Enabled then makeScene(c, hit) else
						trimHits(c); c.Pending[#c.Pending + 1] = hit
					end
				end))
				c.Module:Clean(entitylib.Events.EntityUpdated:Connect(function(ent)
					if not c.Active or not ent or ent.Id == nil then return end
					if kill then rememberDeath(c, ent); return end
					local health, previous = tonumber(ent.Health) or 0, c.Health[ent.Id]
					c.Health[ent.Id] = health
					trimHits(c)
					for i = #c.Pending, 1, -1 do
						local hit = c.Pending[i]
						if hit.Id == ent.Id and (health < hit.Health or (previous and health < previous)) then
							table.remove(c.Pending, i); makeScene(c, hit); break
						end
					end
				end))
				c.Module:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if ent and ent.Id ~= nil then c.Health[ent.Id] = ent.Health or 100; c.Hits[ent.Id] = nil end
				end))
				c.Module:Clean(entitylib.Events.EntityRemoved:Connect(function(ent)
					if ent and ent.Id ~= nil then
						if kill and (ent.Health or 0) <= 0 then rememberDeath(c, ent) end
						c.Health[ent.Id], c.Hits[ent.Id] = nil, nil
					end
				end))
				if kill then
					c.Module:Clean(frontlines.KillEffectEvent.Event:Connect(function()
						if not c.Active then return end
						c.Credits[#c.Credits + 1] = os.clock() + 0.5
						while #c.Credits > 8 do table.remove(c.Credits, 1) end
					end))
				end
			end
		})
		local module = c.Module
		c.Mode = module:CreateDropdown({Name = 'Mode', List = menu, Default = names[1]})
		c.ColorMode = module:CreateDropdown({Name = 'Color Mode', List = {'Style', 'Custom', 'Theme', 'Pastel', 'Target', 'Rainbow'}, Default = 'Style'})
		c.Primary = module:CreateColorSlider({Name = 'Primary Color', DefaultHue = 0.78, DefaultSat = 0.75, DefaultValue = 1})
		c.Secondary = module:CreateColorSlider({Name = 'Secondary Color', DefaultHue = 0.55, DefaultSat = 0.6, DefaultValue = 1})
		c.Size = module:CreateSlider({Name = 'Size', Min = kill and 0.5 or 0.25, Max = kill and 3 or 2.5, Default = 1, Decimal = 100})
		c.Life = module:CreateSlider({Name = 'Lifetime', Min = kill and 0.35 or 0.1, Max = kill and 3.5 or 1.5, Default = kill and 1.6 or 0.46, Decimal = 100, Suffix = 's'})
		c.Quality = module:CreateDropdown({Name = 'Quality', List = {'Low', 'Normal', 'High'}, Default = 'Normal'})
		c.Limit = module:CreateSlider({Name = 'Effect Limit', Min = 1, Max = kill and 5 or 10, Default = kill and 3 or 6})
		c.Glow = module:CreateToggle({Name = 'Dynamic Glow', Default = true})
		c.Trails = module:CreateToggle({Name = 'Motion Trails', Default = true})
		if kill then
			c.Intensity = module:CreateSlider({Name = 'Intensity', Min = 0.5, Max = 2, Default = 1, Decimal = 100})
			c.Ground = module:CreateToggle({Name = 'Ground Sigils', Default = true})
			c.Sound = module:CreateToggle({Name = 'Kill Sound', Function = function(enabled)
				if c.SoundFile then c.SoundFile.Object.Visible = enabled end
				if c.SoundVolume then c.SoundVolume.Object.Visible = enabled end
			end})
			c.SoundFile = module:CreateTextBox({Name = 'Kill Sound File / ID', Default = 'rbxassetid://9118823106', Visible = false, Darker = true,
				Function = function() c.SoundInput, c.SoundAsset = nil, nil end})
			c.SoundVolume = module:CreateSlider({Name = 'Kill Sound Volume', Min = 0, Max = 2, Default = 0.7, Decimal = 100, Visible = false, Darker = true})
		else
			c.Headshots = module:CreateToggle({Name = 'Headshots only'})
			c.Confirmed = module:CreateToggle({Name = 'Confirmed hits', Default = true})
		end
		return c
	end
	createController(false)
	createController(true)

	-- One shared update connection. Delayed stages live in their scene, not in orphaned tasks.
	local connection = runService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, c in ipairs(controllers) do
			if c.Active and c.Kill then
				for id, hit in pairs(c.Hits) do if now - hit.Time > 2 then c.Hits[id] = nil end end
				local i = 1
				while i <= #c.Credits do
					if now > c.Credits[i] then table.remove(c.Credits, i)
					else
						local death = consumeDeath(c)
						if death then table.remove(c.Credits, i); makeScene(c, death) else i = i + 1 end
					end
				end
			end
		end
		for i = #scenes, 1, -1 do
			local s = scenes[i]
			local t = (now - s.Started) / s.Life
			if not s.Owner.Active or not s.Folder.Parent or t > s.EndTime + 0.23 / s.Life then
				removeScene(i)
			else
				local ok, err = pcall(function()
					for _, item in ipairs(s.Items) do
						local u = (t - item.Start) / item.Duration
						local obj, trail = item.Object, s.TrailObjects[item.Object]
						if u >= 0 and u < 1 then
							item.Update(obj, u)
							if trail and not item.Seen then trail:Clear(); trail.Enabled = true end
							item.Seen = true
						elseif u >= 1 and not item.Done then
							if trail then trail.Enabled = false end
							item.Update(obj, 1)
							obj.Transparency = 1
							item.Done = true
						end
					end
				end)
				if not ok then warn('[illusionHD] '..s.Name..' animation: '..tostring(err)); removeScene(i) end
			end
		end
	end)
	vape:Clean(function()
		connection:Disconnect()
		for _, c in ipairs(controllers) do c.Active = false; reset(c) end
		root:Destroy()
	end)
end)
-- ILLUSIONHD_EFFECTS_V4_END

-- ILLUSIONHD_FAKEPLAYER_V1
run(function()
	local FakePlayer
	local Distance
	local SideOffset
	local HitDamage
	local LoopMode
	local LoopDelay
	local AutoRespawn
	local RespawnDelay
	local FacePlayer
	local ShowHealth

	local model
	local fakeEntity
	local healthFill
	local healthText
	local nameGui
	local bodyParts = {}
	local dead = false
	local generation = 0
	local fakeId = '__ILLUSIONHD_VFX_TEST_DUMMY__'
	local maxHealth = 100
	local mixedStep = 0

	local function safeFire(signal, a, b, c, d)
		if not signal then return end
		pcall(function()
			signal:Fire(a, b, c, d)
		end)
	end

	local function setPartVisible(part, visible)
		if not part or not part.Parent then return end
		local base = part:GetAttribute('FakePlayerBaseTransparency')
		if base == nil then base = part.Transparency end
		part.Transparency = visible and base or 1
	end

	local function setVisible(visible)
		for _, part in ipairs(bodyParts) do
			setPartVisible(part, visible)
		end
		if nameGui then nameGui.Enabled = visible and (not ShowHealth or ShowHealth.Enabled) end
	end

	local function updateHealthUI()
		if not fakeEntity then return end
		local health = math.clamp(fakeEntity.Health or 0, 0, maxHealth)
		if healthFill then
			healthFill.Size = UDim2.new(health / maxHealth, 0, 1, 0)
			healthFill.BackgroundColor3 = health > 60 and Color3.fromRGB(91, 235, 137)
				or health > 30 and Color3.fromRGB(255, 194, 86)
				or Color3.fromRGB(255, 83, 104)
		end
		if healthText then
			healthText.Text = string.format('VFX TEST  •  %d HP', math.floor(health + 0.5))
		end
	end

	local function makeBodyPart(parent, name, size, offset, color, transparency, shape)
		local part = Instance.new('Part')
		part.Name = name
		part.Size = size
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = true
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.Transparency = transparency or 0
		part:SetAttribute('FakePlayerBaseTransparency', part.Transparency)
		if shape then part.Shape = shape end
		part.CFrame = CFrame.new(offset)
		part.Parent = parent
		table.insert(bodyParts, part)
		return part
	end

	local function buildDummy()
		if model then model:Destroy() end
		table.clear(bodyParts)

		model = Instance.new('Model')
		model.Name = 'VFX Test Player'

		local root = makeBodyPart(model, 'HumanoidRootPart', Vector3.new(1.8, 2, 1), Vector3.zero, Color3.new(), 1)
		root.CastShadow = false
		local torso = makeBodyPart(model, 'UpperTorso', Vector3.new(2.15, 2.15, 1.05), Vector3.new(0, 0.65, 0), Color3.fromRGB(40, 44, 58))
		local lower = makeBodyPart(model, 'LowerTorso', Vector3.new(1.8, 1.05, 0.95), Vector3.new(0, -0.95, 0), Color3.fromRGB(58, 62, 79))
		local head = makeBodyPart(model, 'Head', Vector3.new(1.55, 1.55, 1.55), Vector3.new(0, 2.55, 0), Color3.fromRGB(213, 185, 166), 0, Enum.PartType.Ball)
		local leftArm = makeBodyPart(model, 'LeftUpperArm', Vector3.new(0.82, 2.25, 0.82), Vector3.new(-1.53, 0.58, 0), Color3.fromRGB(55, 60, 78))
		local rightArm = makeBodyPart(model, 'RightUpperArm', Vector3.new(0.82, 2.25, 0.82), Vector3.new(1.53, 0.58, 0), Color3.fromRGB(55, 60, 78))
		local leftLeg = makeBodyPart(model, 'LeftUpperLeg', Vector3.new(0.88, 2.25, 0.9), Vector3.new(-0.5, -2.42, 0), Color3.fromRGB(30, 33, 45))
		local rightLeg = makeBodyPart(model, 'RightUpperLeg', Vector3.new(0.88, 2.25, 0.9), Vector3.new(0.5, -2.42, 0), Color3.fromRGB(30, 33, 45))

		local chest = Instance.new('Part')
		chest.Name = 'VFXAccent'
		chest.Size = Vector3.new(1.52, 0.2, 1.09)
		chest.Anchored = true
		chest.CanCollide = false
		chest.CanTouch = false
		chest.CanQuery = false
		chest.CastShadow = false
		chest.Material = Enum.Material.Neon
		chest.Color = Color3.fromRGB(137, 91, 255)
		chest.CFrame = CFrame.new(0, 0.82, -0.54)
		chest:SetAttribute('FakePlayerBaseTransparency', 0.08)
		chest.Transparency = 0.08
		chest.Parent = model
		table.insert(bodyParts, chest)

		local highlight = Instance.new('Highlight')
		highlight.Name = 'VFXTestHighlight'
		highlight.Adornee = model
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillColor = Color3.fromRGB(114, 76, 255)
		highlight.FillTransparency = 0.82
		highlight.OutlineColor = Color3.fromRGB(201, 183, 255)
		highlight.OutlineTransparency = 0.24
		highlight.Parent = model

		nameGui = Instance.new('BillboardGui')
		nameGui.Name = 'VFXTesterInfo'
		nameGui.AlwaysOnTop = true
		nameGui.Size = UDim2.fromOffset(176, 42)
		nameGui.StudsOffset = Vector3.new(0, 2.15, 0)
		nameGui.MaxDistance = 120
		nameGui.Parent = head

		local panel = Instance.new('Frame')
		panel.Size = UDim2.fromScale(1, 1)
		panel.BackgroundColor3 = Color3.fromRGB(14, 15, 22)
		panel.BackgroundTransparency = 0.16
		panel.BorderSizePixel = 0
		panel.Parent = nameGui
		local panelCorner = Instance.new('UICorner')
		panelCorner.CornerRadius = UDim.new(0, 8)
		panelCorner.Parent = panel
		local panelStroke = Instance.new('UIStroke')
		panelStroke.Thickness = 1
		panelStroke.Transparency = 0.45
		panelStroke.Color = Color3.fromRGB(151, 118, 255)
		panelStroke.Parent = panel

		healthText = Instance.new('TextLabel')
		healthText.Size = UDim2.new(1, -12, 0, 22)
		healthText.Position = UDim2.fromOffset(6, 2)
		healthText.BackgroundTransparency = 1
		healthText.Font = Enum.Font.GothamBold
		healthText.TextSize = 12
		healthText.TextColor3 = Color3.fromRGB(240, 238, 255)
		healthText.TextXAlignment = Enum.TextXAlignment.Left
		healthText.Parent = panel

		local barBack = Instance.new('Frame')
		barBack.Size = UDim2.new(1, -12, 0, 7)
		barBack.Position = UDim2.new(0, 6, 1, -12)
		barBack.BackgroundColor3 = Color3.fromRGB(40, 42, 53)
		barBack.BorderSizePixel = 0
		barBack.Parent = panel
		local barBackCorner = Instance.new('UICorner')
		barBackCorner.CornerRadius = UDim.new(1, 0)
		barBackCorner.Parent = barBack

		healthFill = Instance.new('Frame')
		healthFill.Size = UDim2.fromScale(1, 1)
		healthFill.BackgroundColor3 = Color3.fromRGB(91, 235, 137)
		healthFill.BorderSizePixel = 0
		healthFill.Parent = barBack
		local fillCorner = Instance.new('UICorner')
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = healthFill

		model.PrimaryPart = root
		model.Parent = workspace

		fakeEntity = {
			Id = fakeId,
			Character = model,
			RootPart = root,
			HumanoidRootPart = root,
			Head = head,
			UpperTorso = torso,
			LowerTorso = lower,
			Health = maxHealth,
			MaxHealth = maxHealth,
			HipHeight = 2,
			NPC = true,
			Targetable = false,
			Player = nil,
			FakeVFXTester = true
		}
		dead = false
		updateHealthUI()
		safeFire(entitylib.Events.EntityAdded, fakeEntity)
		return fakeEntity
	end

	local function localRoot()
		return entitylib.character and (entitylib.character.RootPart or entitylib.character.HumanoidRootPart)
	end

	local function placeDummy()
		if not model or not model.PrimaryPart then return end
		local root = localRoot()
		local camera = workspace.CurrentCamera
		if not root then return end

		local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)
		if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) else look = look.Unit end
		local right = Vector3.new(-look.Z, 0, look.X)
		local target = root.Position + look * Distance.Value + right * SideOffset.Value
		local y = root.Position.Y

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		local filter = {model}
		if entitylib.character and entitylib.character.Character then table.insert(filter, entitylib.character.Character) end
		if workspace.CurrentCamera then table.insert(filter, workspace.CurrentCamera) end
		params.FilterDescendantsInstances = filter
		local ray = workspace:Raycast(target + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), params)
		if ray then y = ray.Position.Y + 3.55 end
		target = Vector3.new(target.X, y, target.Z)

		local cf
		if FacePlayer.Enabled then
			local face = Vector3.new(root.Position.X, target.Y, root.Position.Z)
			cf = CFrame.lookAt(target, face)
		else
			cf = CFrame.lookAt(target, target - look)
		end
		model:PivotTo(cf)
	end

	local function primeHealth()
		if not fakeEntity then return end
		if fakeEntity.Health <= 0 then fakeEntity.Health = maxHealth end
		updateHealthUI()
		-- Seed effect health caches even when the tester was enabled before HitEffects/KillEffects.
		safeFire(entitylib.Events.EntityUpdated, fakeEntity)
	end

	local function respawnDummy(reposition)
		if not FakePlayer.Enabled then return end
		if not model or not model.Parent or not fakeEntity then buildDummy() end
		generation += 1
		dead = false
		fakeEntity.Health = maxHealth
		setVisible(true)
		if nameGui then nameGui.Enabled = ShowHealth.Enabled end
		updateHealthUI()
		if reposition ~= false then placeDummy() end
		primeHealth()
	end

	local function hitPosition(headshot)
		if not fakeEntity then return Vector3.zero end
		if headshot and fakeEntity.Head then return fakeEntity.Head.Position end
		if fakeEntity.UpperTorso then return fakeEntity.UpperTorso.Position + Vector3.new(0, 0.15, 0) end
		return fakeEntity.RootPart.Position + Vector3.new(0, 1, 0)
	end

	local function markLocalHit(headshot, pos)
		local stamp = tick()
		frontlines.LastLocalHit = {Id = fakeId, Time = stamp, Headshot = headshot, Position = pos}
		task.delay(1.65, function()
			local current = frontlines.LastLocalHit
			if current and current.Id == fakeId and current.Time == stamp then
				frontlines.LastLocalHit = nil
			end
		end)
	end

	local function testHit(headshot)
		if not FakePlayer.Enabled then return end
		if not fakeEntity or not model or not model.Parent then buildDummy(); placeDummy() end
		if dead or fakeEntity.Health <= math.max(HitDamage.Value, 1) then respawnDummy(false) end
		primeHealth()

		local pos = hitPosition(headshot)
		markLocalHit(headshot, pos)
		safeFire(frontlines.LocalHitEvent, fakeEntity, pos, headshot, headshot and fakeEntity.Head or fakeEntity.UpperTorso)
		task.delay(0.018, function()
			if not FakePlayer.Enabled or not fakeEntity or dead then return end
			fakeEntity.Health = math.max(1, fakeEntity.Health - HitDamage.Value)
			updateHealthUI()
			safeFire(entitylib.Events.EntityUpdated, fakeEntity)
		end)
	end

	local function testKill(headshot)
		if not FakePlayer.Enabled then return end
		if not fakeEntity or not model or not model.Parent then buildDummy(); placeDummy() end
		if dead or fakeEntity.Health <= 0 then respawnDummy(false) end
		primeHealth()

		local thisGeneration = generation
		local pos = hitPosition(headshot)
		markLocalHit(headshot, pos)
		safeFire(frontlines.LocalHitEvent, fakeEntity, pos, headshot, headshot and fakeEntity.Head or fakeEntity.UpperTorso)

		task.delay(0.022, function()
			if not FakePlayer.Enabled or not fakeEntity or dead or thisGeneration ~= generation then return end
			dead = true
			fakeEntity.Health = 0
			updateHealthUI()
			safeFire(entitylib.Events.EntityUpdated, fakeEntity)
			task.delay(0.028, function()
				if not FakePlayer.Enabled or thisGeneration ~= generation then return end
				safeFire(frontlines.KillEffectEvent)
			end)
			-- Leave the body around briefly so clone/ghost-based kill effects can capture it.
			task.delay(0.22, function()
				if FakePlayer.Enabled and dead and thisGeneration == generation then setVisible(false) end
			end)
			if AutoRespawn.Enabled then
				task.delay(RespawnDelay.Value, function()
					if FakePlayer.Enabled and dead and thisGeneration == generation then respawnDummy(false) end
				end)
			end
		end)
	end

	local function runLoopAction(mode)
		if mode == 'Hit' then
			testHit(false)
		elseif mode == 'Headshot' then
			testHit(true)
		elseif mode == 'Kill' then
			testKill(false)
		elseif mode == 'Headshot Kill' then
			testKill(true)
		elseif mode == 'Mixed' then
			mixedStep = (mixedStep % 4) + 1
			if mixedStep == 1 then testHit(false)
			elseif mixedStep == 2 then testHit(true)
			elseif mixedStep == 3 then testHit(false)
			else testKill(mixedStep % 2 == 0) end
		end
	end

	local function destroyDummy()
		generation += 1
		if fakeEntity then safeFire(entitylib.Events.EntityRemoved, fakeEntity) end
		fakeEntity = nil
		dead = false
		healthFill = nil
		healthText = nil
		nameGui = nil
		if model then model:Destroy(); model = nil end
		table.clear(bodyParts)
	end

	FakePlayer = vape.Categories.Render:CreateModule({
		Name = 'FakePlayer',
		Function = function(callback)
			if callback then
				buildDummy()
				placeDummy()
				primeHealth()

				FakePlayer:Clean(inputService.InputBegan:Connect(function(input, processed)
					if processed or inputService:GetFocusedTextBox() or not FakePlayer.Enabled then return end
					if input.KeyCode == Enum.KeyCode.H then
						testHit(false)
					elseif input.KeyCode == Enum.KeyCode.J then
						testHit(true)
					elseif input.KeyCode == Enum.KeyCode.K then
						testKill(false)
					elseif input.KeyCode == Enum.KeyCode.L then
						respawnDummy(true)
					end
				end))

				task.spawn(function()
					while FakePlayer.Enabled do
						local mode = LoopMode.Value
						if mode ~= 'Off' then runLoopAction(mode) end
						task.wait(math.max(LoopDelay.Value, 0.12))
					end
				end)
			else
				destroyDummy()
			end
		end,
		Tooltip = 'Local VFX test dummy. H = hit, J = headshot, K = kill, L = respawn/reposition.'
	})

	Distance = FakePlayer:CreateSlider({
		Name = 'Distance', Min = 4, Max = 35, Default = 10, Decimal = 10,
		Function = function() if FakePlayer.Enabled and model then placeDummy() end end
	})
	SideOffset = FakePlayer:CreateSlider({
		Name = 'Side Offset', Min = -15, Max = 15, Default = 0, Decimal = 10,
		Function = function() if FakePlayer.Enabled and model then placeDummy() end end
	})
	HitDamage = FakePlayer:CreateSlider({Name = 'Hit Damage', Min = 1, Max = 95, Default = 24})
	LoopMode = FakePlayer:CreateDropdown({Name = 'Auto Test', List = {'Off', 'Hit', 'Headshot', 'Kill', 'Headshot Kill', 'Mixed'}, Default = 'Off'})
	LoopDelay = FakePlayer:CreateSlider({Name = 'Auto Delay', Min = 0.15, Max = 5, Default = 1.25, Decimal = 100, Suffix = 's'})
	AutoRespawn = FakePlayer:CreateToggle({Name = 'Auto Respawn', Default = true})
	RespawnDelay = FakePlayer:CreateSlider({Name = 'Respawn Delay', Min = 0.25, Max = 5, Default = 1.15, Decimal = 100, Suffix = 's'})
	FacePlayer = FakePlayer:CreateToggle({
		Name = 'Face Player', Default = true,
		Function = function() if FakePlayer.Enabled and model then placeDummy() end end
	})
	ShowHealth = FakePlayer:CreateToggle({
		Name = 'Show Health', Default = true,
		Function = function(callback) if nameGui then nameGui.Enabled = callback and not dead end end
	})

	vape:Clean(destroyDummy)
end)
-- ILLUSIONHD_FAKEPLAYER_END


run(function()
	local HeadshotSound
	local SoundFile
	local Volume
	local Pitch
	local ConfirmedHits
	local Cooldown
	local pending = {}
	local cachedPath
	local cachedAsset
	local lastPlay = 0
	local lastError = 0
	local customAsset = getcustomasset or getsynasset or getasset

	-- SoundFile is ALWAYS a real file inside the executor workspace.
	-- Examples: "headshot.mp3", "sounds/headshot.ogg", "assets/hit.wav"
	local function normalizeWorkspacePath(value)
		local path = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('\\', '/')
		path = path:gsub('^file://', '')
		path = path:gsub('^workspace/', '')
		path = path:gsub('^Workspace/', '')
		path = path:gsub('^/', '')
		return path
	end

	local function resolveWorkspaceSound(value)
		local path = normalizeWorkspacePath(value)
		if path == '' then return nil, 'No file selected.' end

		-- Explicitly reject Roblox asset IDs: this module is workspace-file only.
		if path:match('^%d+$') or path:lower():match('^rbxasset') then
			return nil, 'Use a file from your executor workspace, not a Roblox asset ID.'
		end

		if cachedPath == path and cachedAsset then
			return cachedAsset
		end

		if type(isfile) == 'function' then
			local ok, exists = pcall(isfile, path)
			if ok and not exists then
				return nil, 'File not found in workspace: '..path
			end
		end

		if not customAsset then
			return nil, 'Your executor does not provide getcustomasset/getsynasset/getasset.'
		end

		local ok, asset = pcall(customAsset, path)
		if not ok or not asset then
			return nil, 'Could not load workspace file: '..path
		end

		cachedPath = path
		cachedAsset = asset
		return asset
	end

	local function playHeadshot()
		if tick() - lastPlay < Cooldown.Value then return end

		local asset, err = resolveWorkspaceSound(SoundFile.Value)
		if not asset then
			if tick() - lastError > 2 then
				lastError = tick()
				notif('HeadshotSound', err or 'Failed to load workspace sound file.', 5, 'alert')
			end
			return
		end

		lastPlay = tick()
		local sound = Instance.new('Sound')
		sound.Name = 'VapeHeadshotSound'
		-- Roblox Sound objects still require a Content string internally.
		-- getcustomasset/getsynasset creates that Content string directly from the local workspace file.
		sound.SoundId = asset
		sound.Volume = Volume.Value
		sound.PlaybackSpeed = Pitch.Value
		sound.Parent = gameCamera
		sound:Play()
		debrisService:AddItem(sound, 8)
	end

	local function trimPending()
		local now = tick()
		for i = #pending, 1, -1 do
			if now - pending[i].Time > 0.7 then
				table.remove(pending, i)
			end
		end
	end

	HeadshotSound = vape.Categories.Render:CreateModule({
		Name = 'HeadshotSound',
		Function = function(callback)
			if callback then
				table.clear(pending)
				cachedPath = nil
				cachedAsset = nil

				HeadshotSound:Clean(frontlines.LocalHitEvent.Event:Connect(function(ent, _, headshot)
					if not headshot or not ent or not ent.Id then return end
					if not ConfirmedHits.Enabled then
						playHeadshot()
						return
					end

					trimPending()
					table.insert(pending, {
						Id = ent.Id,
						Health = ent.Health or 100,
						Time = tick()
					})
				end))

				HeadshotSound:Clean(entitylib.Events.EntityUpdated:Connect(function(ent)
					if not ent or not ent.Id then return end
					trimPending()
					for i = #pending, 1, -1 do
						local hit = pending[i]
						if hit.Id == ent.Id and (ent.Health or 0) < hit.Health then
							table.remove(pending, i)
							playHeadshot()
							break
						end
					end
				end))
			else
				table.clear(pending)
			end
		end,
		Tooltip = 'Plays a sound file directly from your executor workspace when you land a headshot.'
	})

	SoundFile = HeadshotSound:CreateTextBox({
		Name = 'Workspace Sound File',
		Default = 'headshot.mp3',
		Function = function()
			cachedPath = nil
			cachedAsset = nil
		end
	})
	Volume = HeadshotSound:CreateSlider({Name = 'Volume', Min = 0, Max = 2, Default = 1, Decimal = 100})
	Pitch = HeadshotSound:CreateSlider({Name = 'Pitch', Min = 0.5, Max = 2, Default = 1, Decimal = 100})
	Cooldown = HeadshotSound:CreateSlider({Name = 'Cooldown', Min = 0, Max = 0.5, Default = 0.03, Decimal = 100, Suffix = 's'})
	ConfirmedHits = HeadshotSound:CreateToggle({Name = 'Confirmed Hits', Default = true})
end)

run(function()
	local NoHurtCam
	
	NoHurtCam = vape.Categories.Render:CreateModule({
		Name = 'NoHurtCam',
		Function = function(callback)
			if callback then
				NoHurtCam:Clean(hookEvent('UPDATE_FPV_SOL_DAMAGE_GFX', function() return true end))
				NoHurtCam:Clean(hookEvent('UPDATE_FPV_SOL_HEALTH_SFX', function() return true end))
				NoHurtCam:Clean(hookEvent('DISPLAY_SUPPRESSION_VIGNETTE', function() return true end))
			end
		end,
		Tooltip = 'Removes camera flash after taking damage'
	})
end)

run(function()
	local VisualComfort
	local options = {}
	local tracked = {}
	local lighting = cloneref(game:GetService('Lighting'))
	local classes = {'BlurEffect', 'BloomEffect', 'DepthOfFieldEffect'}

	local function inScope(effect)
		local camera = workspace.CurrentCamera
		return effect:IsDescendantOf(lighting) or (camera and effect:IsDescendantOf(camera))
	end

	local function release(effect)
		local state = tracked[effect]
		if not state then return end
		tracked[effect] = nil
		state.Changed:Disconnect()
		state.Ancestry:Disconnect()
		-- Destroyed effects can no longer accept property writes.
		pcall(function() effect.Enabled = state.Enabled end)
	end

	local function consider(effect)
		local option = options[effect.ClassName]
		if not option or not option.Enabled or not inScope(effect) then return end
		if tracked[effect] then return end
		local state = {Enabled = effect.Enabled}
		tracked[effect] = state
		effect.Enabled = false
		state.Changed = effect:GetPropertyChangedSignal('Enabled'):Connect(function()
			if effect.Enabled then
				state.Enabled = true
				effect.Enabled = false
			end
		end)
		state.Ancestry = effect.AncestryChanged:Connect(function()
			if not inScope(effect) then release(effect) end
		end)
	end

	local function refresh()
		if not VisualComfort or not VisualComfort.Enabled then return end
		for effect in tracked do
			if not options[effect.ClassName].Enabled or not inScope(effect) then
				release(effect)
			end
		end
		for _, effect in lighting:GetDescendants() do consider(effect) end
		local camera = workspace.CurrentCamera
		if camera then
			for _, effect in camera:GetDescendants() do consider(effect) end
		end
	end

	VisualComfort = vape.Categories.Render:CreateModule({
		Name = 'VisualComfort',
		Function = function(callback)
			if callback then
				VisualComfort:Clean(function()
					for effect in tracked do release(effect) end
				end)
				VisualComfort:Clean(lighting.DescendantAdded:Connect(consider))
				VisualComfort:Clean(workspace.DescendantAdded:Connect(consider))
				VisualComfort:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(refresh))
				refresh()
			end
		end,
		Tooltip = 'Reduce post-processing for visual comfort. Restores effects when switched off.'
	})
	for index, name in {'Remove Blur', 'Remove Bloom', 'Remove Depth of Field'} do
		options[classes[index]] = VisualComfort:CreateToggle({
			Name = name, Default = true, Function = refresh
		})
	end
end)

run(function()
	local ThirdPerson
	local Distance
	local hook = false
	
	ThirdPerson = vape.Categories.Render:CreateModule({
		Name = 'ThirdPerson',
		Function = function(callback)
			if callback then
				ThirdPerson:Clean(hookEvent('STEP_FPV_SOL_CAMERA', function()
					local bone = frontlines.Main.globals.fpv_sol_instances.camera_bone
					local state = frontlines.Main.globals.cli_state
					if bone and state.state == frontlines.Main.cli_state_t.COMBAT then
						local id = state.fpv_sol_id
						local actor = frontlines.Main.soldier_actors[id]
						local cf = bone.TransformedWorldCFrame
						if actor then 
							actor.main.direction.Value = frontlines.Main.globals.fpv_sol_dir.dir 
						end
						
						gameCamera.CFrame = cf * CFrame.new(0, 2, Distance.Value)
						gameCamera.Focus = cf + cf.LookVector
						frontlines.Main.exe_set(frontlines.Main.exe_set_t.TPV_SOLDIER_JOINT_STEP, id)
						return true
					end
				end))
	
				if entitylib.isAlive then
					local char = entitylib.character.Character
					for i, v in char:GetDescendants() do
						if v:IsA('BasePart') then 
							v.LocalTransparencyModifier = v.Parent ~= char and 1 or 0 
						end
					end
				end
	
				ThirdPerson:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					local id = frontlines.Main.globals.cli_state.fpv_sol_id
					local actor = frontlines.Main.soldier_actors[id]
					if actor then
						local gun = frontlines.Main.globals.fpv_sol_equipment.curr_equipment
						frontlines.Events[frontlines.Main.exe_func_t.INIT_TPV_SOL_JOINTS](id)
						frontlines.Events[frontlines.Main.exe_func_t.INIT_TPV_SOL_EQUIPMENT_JOINTS](id, gun)
						frontlines.Events[frontlines.Main.exe_func_t.SET_SOLDIER_ANIMATION_VALUES](id, gun)
						actor.main.alive.Value = true
					end
	
					for i, v in ent.Character:GetDescendants() do
						if v:IsA('BasePart') then 
							v.LocalTransparencyModifier = v.Parent ~= ent.Character and 1 or 0 
						end
					end
				end))
			else
				if entitylib.isAlive then
					local char = entitylib.character.Character
					for i, v in char:GetDescendants() do
						if v:IsA('BasePart') then 
							v.LocalTransparencyModifier = v.Parent ~= char and 0 or 1 
						end
					end
				end
			end
		end,
		Tooltip = 'View your character in third person'
	})
	Distance = ThirdPerson:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 15,
		Default = 8
	})
end)

run(function()
	local BulletTracers
	local Material
	local Color
	local Lifetime
	local Fade
	local DrawingToggle
	local drawingobjs = {}
	
	BulletTracers = vape.Legit:CreateModule({
		Name = 'BulletTracers',
		Function = function(callback)
			if callback then 
				BulletTracers:Clean(frontlines.LocalBulletEvent.Event:Connect(function(id, btype, origin, velocity)
					if DrawingToggle.Enabled then 
						local obj = Drawing.new('Line')
						obj.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						drawingobjs[obj] = {origin, origin + (velocity.Unit * 1000), tick()}
						task.delay(Lifetime.Value, function()
							drawingobjs[obj] = nil
							obj.Visible = false
							obj:Remove()
						end)
					else
						local obj = Instance.new('Part')
						obj.Size = Vector3.new(0.05, 0.05, 1000)
						obj.CFrame = CFrame.lookAt(origin + (velocity.Unit * 500), origin + (velocity.Unit * 1000))
						obj.CanCollide = false
						obj.CanQuery = false
						obj.Anchored = true
						obj.Material = Enum.Material[Material.Value]
						obj.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						obj.Transparency = 1 - Color.Opacity
						obj.Parent = workspace
						if Fade.Enabled then 
							local tween = tweenService:Create(obj, TweenInfo.new(Lifetime.Value), {
								Transparency = 1
							})
							tween.Completed:Connect(function() 
								tween:Destroy() 
							end)
							tween:Play()
						end
						debrisService:AddItem(obj, Lifetime.Value)
					end
				end))
	
				if DrawingToggle.Enabled then
					BulletTracers:Clean(runService.RenderStepped:Connect(function()
						for obj, data in drawingobjs do 
							local from, vis = gameCamera:WorldToViewportPoint(data[1])
							local to, vis2 = gameCamera:WorldToViewportPoint(data[2])
							if vis and vis2 then
								obj.Visible = true
								obj.From = Vector2.new(from.X, from.Y)
								obj.To = Vector2.new(to.X, to.Y)
								if Fade.Enabled then 
									obj.Transparency = Color.Opacity * (1 - math.clamp((tick() - data[3]) / Lifetime.Value, 0, 1))
								end
							else
								obj.Visible = false
							end
						end
					end))
				end
			end
		end,
		Tooltip = 'Replacement tracers for bullets'
	})
	local materials = {'SmoothPlastic'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'SmoothPlastic' then 
			table.insert(materials, v.Name) 
		end
	end
	Material = BulletTracers:CreateDropdown({
		Name = 'Material',
		List = materials
	})
	Color = BulletTracers:CreateColorSlider({
		Name = 'Tracer Color',
		DefaultOpacity = 0.5
	})
	Lifetime = BulletTracers:CreateSlider({
		Name = 'Lifetime',
		Min = 0,
		Max = 0.5,
		Default = 0.2,
		Decimal = 10
	})
	Fade = BulletTracers:CreateToggle({
		Name = 'Fade',
		Default = true
	})
	DrawingToggle = BulletTracers:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if BulletTracers.Enabled then 
				BulletTracers:Toggle()
				BulletTracers:Toggle()
			end
		end
	})
end)
run(function()
 local createCuteVisuals = assert(loadstring(downloadFile('newvape/libraries/cutevisuals.lua'), 'CuteVisuals'))()
 createCuteVisuals(vape, {
  GetPosition = function()
   local character = entitylib.isAlive and entitylib.character
   local root = character and (character.RootPart or character.HumanoidRootPart)
   if not root or not root.Parent then return nil, false end
   local velocity = root.AssemblyLinearVelocity
   return root.Position - Vector3.new(0, 2.5, 0), Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 0.1
  end,
  ConnectBurst = function(module, emit)
   local lastHit, lastTime
   module:Clean(frontlines.LocalHitEvent.Event:Connect(function(_, position)
    lastHit, lastTime = position, os.clock()
   end))
   module:Clean(frontlines.KillEffectEvent.Event:Connect(function()
    if lastHit and os.clock() - lastTime < 3 then
     emit(lastHit)
    elseif entitylib.isAlive and entitylib.character.RootPart then
     emit(entitylib.character.RootPart.Position)
    end
    lastHit, lastTime = nil, nil
   end))
  end
 })
end)
run(function()
	local AmmoHUD
	local LowAmmo, ShowReserve, TextSize, VerticalPosition, Background

	AmmoHUD = vape.Categories.Render:CreateModule({
		Name = 'AmmoHUD',
		Function = function(callback)
			if not callback then return end
			local label = Instance.new('TextLabel')
			label.Name = 'FrontlinesAmmoHUD'
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Size = UDim2.fromOffset(240, 40)
			label.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
			label.BorderSizePixel = 0
			label.Font = Enum.Font.GothamMedium
			label.Text = ''
			label.Visible = false
			label.Parent = vape.gui
			AmmoHUD:Clean(label)
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = label

			local function update()
				local main = frontlines.Main
				local globals = main and main.globals
				local equipment = globals and globals.fpv_sol_equipment
				local gun = equipment and equipment.curr_equipment
				local ammo = globals and globals.fpv_sol_ammo
				local state = globals and globals.cli_state
				label.Visible = not not (entitylib.isAlive and state and state.state == main.cli_state_t.COMBAT
					and gun and gun.reload_params and ammo and type(ammo.ammo) == 'number')
				if not label.Visible then return end
				local count = math.max(0, math.floor(ammo.ammo))
				local reserve = type(ammo.reserve) == 'number' and tostring(math.max(0, math.floor(ammo.reserve))) or '--'
				label.Text = (count == 0 and 'EMPTY' or tostring(count))..(ShowReserve.Enabled and ' / '..reserve or '')
				label.TextColor3 = count <= LowAmmo.Value and Color3.fromRGB(255, 140, 105) or Color3.fromRGB(240, 243, 250)
				label.TextSize = TextSize.Value
				label.Position = UDim2.fromScale(0.5, VerticalPosition.Value / 100)
				label.BackgroundTransparency = Background.Enabled and 0.25 or 1
			end
			local elapsed = 0
			AmmoHUD:Clean(runService.Heartbeat:Connect(function(dt)
				elapsed += dt
				if elapsed >= 0.1 then
					elapsed = 0
					update()
				end
			end))
			update()
		end,
		Tooltip = 'Readable firearm ammo near the crosshair. Hides in menus, on death and when using melee.'
	})
	LowAmmo = AmmoHUD:CreateSlider({Name = 'Low Ammo Threshold', Min = 0, Max = 30, Default = 5})
	ShowReserve = AmmoHUD:CreateToggle({Name = 'Show Reserve', Default = true})
	TextSize = AmmoHUD:CreateSlider({Name = 'Text Size', Min = 14, Max = 32, Default = 22})
	VerticalPosition = AmmoHUD:CreateSlider({Name = 'Vertical Position', Min = 10, Max = 90, Default = 60, Suffix = '%'})
	Background = AmmoHUD:CreateToggle({Name = 'Background', Default = true})
end)

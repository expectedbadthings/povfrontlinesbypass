-- Deadline / PlaceId 12144402492
-- Vape API game module: custom SilentAim + ESP + Chams + NameTags for workspace.characters.

if game.PlaceId ~= 12144402492 then return end

local vape = shared.vape
if type(vape) ~= 'table' or type(vape.Categories) ~= 'table' then
	warn('[12144402492] Vape API is not ready.')
	return
end

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local CharFolder = Workspace:WaitForChild('characters', 15)
if not CharFolder then
	pcall(function()
		vape:CreateNotification('Deadline', 'workspace.characters was not found.', 10, 'alert')
	end)
	return
end

local rng = Random.new()
local unpack = table.unpack or unpack

local function notify(title, text, duration, icon)
	pcall(function()
		vape:CreateNotification(title, text, duration or 5, icon)
	end)
end

local function safeDisconnect(connection)
	if connection then
		pcall(function() connection:Disconnect() end)
	end
end

local function removeDrawing(object)
	if object then
		pcall(function() object:Remove() end)
	end
end

local function hasDrawing()
	return type(Drawing) == 'table' and type(Drawing.new) == 'function'
end

local function currentCamera()
	return Workspace.CurrentCamera
end

local function findBasePart(model, wanted)
	if not model then return nil end
	for _, name in ipairs(wanted) do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA('BasePart') then
			return part
		end
	end
	return nil
end

local function getRoot(model)
	return findBasePart(model, {'HumanoidRootPart', 'RootPart', 'root', 'Torso', 'UpperTorso'})
		or model:FindFirstChildWhichIsA('BasePart', true)
end

local function getHead(model)
	local exact = findBasePart(model, {'Head', 'head', 'HEAD', 'Helmet', 'helmet'})
	if exact then return exact end
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA('BasePart') then
			local lower = object.Name:lower()
			if lower:find('head', 1, true) or lower:find('helmet', 1, true) then
				return object
			end
		end
	end
	return nil
end

local function getTorso(model)
	return findBasePart(model, {'UpperTorso', 'Torso', 'LowerTorso', 'Chest', 'Body', 'HumanoidRootPart'}) or getRoot(model)
end

local function getHumanoid(model)
	return model and model:FindFirstChildWhichIsA('Humanoid', true) or nil
end

local function getPlayerFromModel(model)
	if not model then return nil end

	local byName = Players:FindFirstChild(model.Name)
	if byName and byName:IsA('Player') then return byName end

	local userId
	for _, attr in ipairs({'UserId', 'userId', 'user_id', 'PlayerId', 'playerId', 'player_id'}) do
		local ok, value = pcall(function() return model:GetAttribute(attr) end)
		if ok and tonumber(value) then
			userId = tonumber(value)
			break
		end
	end
	if userId then
		local ok, player = pcall(function() return Players:GetPlayerByUserId(userId) end)
		if ok and player then return player end
	end

	for _, attr in ipairs({'Username', 'username', 'PlayerName', 'playerName'}) do
		local ok, value = pcall(function() return model:GetAttribute(attr) end)
		if ok and type(value) == 'string' then
			local player = Players:FindFirstChild(value)
			if player then return player end
		end
	end

	return nil
end

local function isLocalModel(model)
	if not model then return true end
	if model == LocalPlayer.Character then return true end
	if model.Name == LocalPlayer.Name or model.Name == tostring(LocalPlayer.UserId) then return true end
	local player = getPlayerFromModel(model)
	return player == LocalPlayer
end

local function validTargetModel(model, teamCheck)
	if not model or not model.Parent or isLocalModel(model) then return false end
	local root = getRoot(model)
	if not root then return false end

	if teamCheck then
		local player = getPlayerFromModel(model)
		if player and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team then
			return false
		end
	end

	local hum = getHumanoid(model)
	if hum and hum.Health <= 0 then return false end
	return true
end

local function localPosition()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild('HumanoidRootPart')
	if root then return root.Position end
	local camera = currentCamera()
	return camera and camera.CFrame.Position or Vector3.zero
end

local function modelDisplayName(model, useDisplayName)
	local player = getPlayerFromModel(model)
	if player then
		return useDisplayName and player.DisplayName or player.Name
	end
	return model.Name
end

local function colorFrom(option, fallback)
	if option and option.Hue ~= nil then
		return Color3.fromHSV(option.Hue, option.Sat or 1, option.Value or 1)
	end
	return fallback or Color3.new(1, 1, 1)
end

-- The universal script loads first in main.lua. Hide/disable its versions so the
-- workspace.characters-aware implementations below are the visible ones for this place.
local function retireModule(name)
	local module
	if type(vape.Modules) == 'table' then
		module = vape.Modules[name]
		if not module then
			for _, value in pairs(vape.Modules) do
				if type(value) == 'table' and value.Name == name then
					module = value
					break
				end
			end
		end
	end
	if not module then return end

	pcall(function()
		if module.Enabled and type(module.Toggle) == 'function' then module:Toggle() end
	end)
	pcall(function()
		if type(module.SetVisible) == 'function' then
			module:SetVisible(false)
		elseif module.Object then
			module.Object.Visible = false
		end
	end)
end

for _, moduleName in ipairs({'SilentAim', 'ESP', 'Chams', 'NameTags'}) do
	retireModule(moduleName)
end

-- SILENT AIM ------------------------------------------------------------------
local SilentAim
local SilentMode
local AimPart
local FOV
local Range
local HitChance
local WallCheck
local TeamCheck
local ShowFOV
local CircleColor
local RayLength
local OriginCheck
local OriginDistance
local fovCircle
local fovConnection

local function aimScreenPosition()
	local camera = currentCamera()
	if not camera then return Vector2.zero end
	if SilentMode and SilentMode.Value == 'Center' then
		return camera.ViewportSize / 2
	end
	local mouse = UserInputService:GetMouseLocation()
	return Vector2.new(mouse.X, mouse.Y)
end

local function targetPart(model)
	local mode = AimPart and AimPart.Value or 'Head'
	if mode == 'Head' then
		return getHead(model) or getTorso(model)
	elseif mode == 'Torso' then
		return getTorso(model)
	elseif mode == 'Root' then
		return getRoot(model)
	elseif mode == 'Random' then
		local options = {getHead(model), getTorso(model), getRoot(model)}
		local available = {}
		for _, part in ipairs(options) do
			if part then available[#available + 1] = part end
		end
		return #available > 0 and available[rng:NextInteger(1, #available)] or nil
	end
	return getHead(model) or getRoot(model)
end

local visibilityParams = RaycastParams.new()
visibilityParams.FilterType = Enum.RaycastFilterType.Exclude
visibilityParams.IgnoreWater = true
visibilityParams.RespectCanCollide = true

local function visibleTo(part, model)
	if not WallCheck or not WallCheck.Enabled then return true end
	local camera = currentCamera()
	if not camera then return false end

	local ignore = {}
	if LocalPlayer.Character then ignore[#ignore + 1] = LocalPlayer.Character end
	visibilityParams.FilterDescendantsInstances = ignore

	local direction = part.Position - camera.CFrame.Position
	local result = Workspace:Raycast(camera.CFrame.Position, direction, visibilityParams)
	return result == nil or (result.Instance and result.Instance:IsDescendantOf(model))
end

local function getSilentTarget(origin)
	local camera = currentCamera()
	if not camera then return nil end
	local aimPoint = aimScreenPosition()
	local bestPart, bestModel, bestScore
	local maxRange = Range and Range.Value or 1000
	local maxFov = FOV and FOV.Value or 250
	local checkTeam = TeamCheck and TeamCheck.Enabled

	for _, model in ipairs(CharFolder:GetChildren()) do
		if model:IsA('Model') and validTargetModel(model, checkTeam) then
			local part = targetPart(model)
			if part then
				local distance = (part.Position - origin).Magnitude
				if distance <= maxRange then
					local screen, onScreen = camera:WorldToViewportPoint(part.Position)
					if onScreen and screen.Z > 0 then
						local score = (Vector2.new(screen.X, screen.Y) - aimPoint).Magnitude
						if score <= maxFov and (not bestScore or score < bestScore) and visibleTo(part, model) then
							bestPart, bestModel, bestScore = part, model, score
						end
					end
				end
			end
		end
	end

	return bestPart, bestModel
end

local SILENT_HOOK_KEY = '__VapeDeadline12144402492SilentHook'
local hookState = shared[SILENT_HOOK_KEY]
if type(hookState) ~= 'table' then
	hookState = {Installed = false, Enabled = false, Busy = false, Redirect = nil, Owner = nil}
	shared[SILENT_HOOK_KEY] = hookState
end

local function installSilentHook()
	if hookState.Installed then return true end
	if type(hookmetamethod) ~= 'function' or type(getnamecallmethod) ~= 'function' then
		return false
	end

	local oldNamecall
	local closure = type(newcclosure) == 'function' and newcclosure or function(func) return func end
	oldNamecall = hookmetamethod(game, '__namecall', closure(function(self, ...)
		local method = getnamecallmethod()
		local state = shared[SILENT_HOOK_KEY]
		local callerIsUs = type(checkcaller) == 'function' and checkcaller() or false

		if state and state.Enabled and not state.Busy and not callerIsUs
			and self == Workspace and method == 'Raycast' and type(state.Redirect) == 'function' then
			local args = {...}
			state.Busy = true
			local ok, changed = pcall(state.Redirect, args)
			state.Busy = false
			if ok and type(changed) == 'table' then
				return oldNamecall(self, unpack(changed))
			end
		end

		return oldNamecall(self, ...)
	end))

	hookState.Old = oldNamecall
	hookState.Installed = true
	return true
end

local function destroyFOV()
	safeDisconnect(fovConnection)
	fovConnection = nil
	removeDrawing(fovCircle)
	fovCircle = nil
end

local function createFOV()
	destroyFOV()
	if not hasDrawing() then return end
	fovCircle = Drawing.new('Circle')
	fovCircle.NumSides = 64
	fovCircle.Thickness = 1
	fovCircle.Filled = false
	fovCircle.Transparency = 1
	fovCircle.Color = colorFrom(CircleColor, Color3.fromRGB(255, 255, 255))
	fovCircle.Radius = FOV.Value
	fovCircle.Visible = ShowFOV.Enabled
	fovConnection = RunService.RenderStepped:Connect(function()
		if not fovCircle then return end
		fovCircle.Position = aimScreenPosition()
		fovCircle.Radius = FOV.Value
		fovCircle.Color = colorFrom(CircleColor, Color3.fromRGB(255, 255, 255))
		fovCircle.Visible = SilentAim.Enabled and ShowFOV.Enabled
	end)
end

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Tooltip = 'Deadline-specific silent aim for workspace.characters using the Vape module API.',
	Function = function(enabled)
		if enabled then
			if not installSilentHook() then
				notify('SilentAim', 'Your executor does not expose hookmetamethod/getnamecallmethod.', 8, 'alert')
				task.defer(function()
					if SilentAim.Enabled then SilentAim:Toggle() end
				end)
				return
			end

			hookState.Owner = vape
			hookState.Redirect = function(args)
				local origin, direction = args[1], args[2]
				if typeof(origin) ~= 'Vector3' or typeof(direction) ~= 'Vector3' then return nil end
				if direction.Magnitude < RayLength.Value then return nil end
				if rng:NextNumber(0, 100) > HitChance.Value then return nil end

				if OriginCheck.Enabled then
					local camera = currentCamera()
					local nearCamera = camera and (origin - camera.CFrame.Position).Magnitude <= OriginDistance.Value
					local nearPlayer = (origin - localPosition()).Magnitude <= OriginDistance.Value
					if not nearCamera and not nearPlayer then return nil end
				end

				local part = getSilentTarget(origin)
				if not part then return nil end
				local delta = part.Position - origin
				if delta.Magnitude <= 0.001 then return nil end

				args[2] = delta.Unit * direction.Magnitude
				return args
			end
			hookState.Enabled = true
			createFOV()
		else
			if hookState.Owner == vape then
				hookState.Enabled = false
				hookState.Redirect = nil
			end
			destroyFOV()
		end
	end,
	ExtraText = function()
		return AimPart and AimPart.Value or ''
	end
})
SilentMode = SilentAim:CreateDropdown({Name = 'Target Mode', List = {'Mouse', 'Center'}, Default = 'Mouse'})
AimPart = SilentAim:CreateDropdown({Name = 'Aim Part', List = {'Head', 'Torso', 'Root', 'Random'}, Default = 'Head'})
FOV = SilentAim:CreateSlider({Name = 'FOV', Min = 10, Max = 800, Default = 250, Suffix = 'px'})
Range = SilentAim:CreateSlider({Name = 'Range', Min = 25, Max = 3000, Default = 1000, Suffix = 'studs'})
HitChance = SilentAim:CreateSlider({Name = 'Hit Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
RayLength = SilentAim:CreateSlider({Name = 'Minimum Ray Length', Min = 1, Max = 500, Default = 25, Suffix = 'studs'})
WallCheck = SilentAim:CreateToggle({Name = 'Wall Check', Default = true})
TeamCheck = SilentAim:CreateToggle({Name = 'Team Check', Default = true})
OriginCheck = SilentAim:CreateToggle({Name = 'Origin Check', Default = true, Tooltip = 'Only redirects rays originating near your camera/character.'})
OriginDistance = SilentAim:CreateSlider({Name = 'Origin Distance', Min = 2, Max = 50, Default = 18, Suffix = 'studs', Darker = true})
ShowFOV = SilentAim:CreateToggle({Name = 'Show FOV', Default = true, Function = function(value)
	if fovCircle then fovCircle.Visible = SilentAim.Enabled and value end
end})
CircleColor = SilentAim:CreateColorSlider({Name = 'FOV Color', DefaultSat = 0, Function = function(h, s, v)
	if fovCircle then fovCircle.Color = Color3.fromHSV(h, s, v) end
end})

-- ESP -------------------------------------------------------------------------
local ESP
local ESPBoxes
local ESPTracers
local ESPFilled
local ESPTeamCheck
local ESPDistance
local ESPThickness
local ESPColor
local espObjects = {}
local espRenderConnection
local espAddedConnection
local espRemovedConnection

local function destroyESPModel(model)
	local data = espObjects[model]
	if not data then return end
	removeDrawing(data.Box)
	removeDrawing(data.Tracer)
	espObjects[model] = nil
end

local function makeESPModel(model)
	if espObjects[model] or not hasDrawing() or not model:IsA('Model') or isLocalModel(model) then return end
	local box = Drawing.new('Square')
	box.Thickness = ESPThickness and ESPThickness.Value or 1
	box.Filled = false
	box.Transparency = 1
	box.Color = colorFrom(ESPColor, Color3.fromRGB(0, 255, 255))
	box.Visible = false

	local tracer = Drawing.new('Line')
	tracer.Thickness = ESPThickness and ESPThickness.Value or 1
	tracer.Transparency = 0.8
	tracer.Color = colorFrom(ESPColor, Color3.fromRGB(0, 255, 255))
	tracer.Visible = false

	espObjects[model] = {Box = box, Tracer = tracer}
end

local function clearESP()
	safeDisconnect(espRenderConnection)
	safeDisconnect(espAddedConnection)
	safeDisconnect(espRemovedConnection)
	espRenderConnection, espAddedConnection, espRemovedConnection = nil, nil, nil
	for model in pairs(espObjects) do destroyESPModel(model) end
	table.clear(espObjects)
end

local function updateESP()
	local camera = currentCamera()
	if not camera then return end
	local origin = localPosition()
	local maxDistance = ESPDistance.Value
	local color = colorFrom(ESPColor, Color3.fromRGB(0, 255, 255))

	for model, drawings in pairs(espObjects) do
		local root = getRoot(model)
		local valid = validTargetModel(model, ESPTeamCheck.Enabled) and root ~= nil
		if valid and (root.Position - origin).Magnitude <= maxDistance then
			local rootPos, onScreen = camera:WorldToViewportPoint(root.Position)
			if onScreen and rootPos.Z > 0 then
				local top = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
				local bottom = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3.5, 0))
				local boxHeight = math.max(math.abs(top.Y - bottom.Y), 2)
				local boxWidth = boxHeight * 0.58
				local left = rootPos.X - boxWidth / 2
				local y = math.min(top.Y, bottom.Y)

				drawings.Box.Position = Vector2.new(left, y)
				drawings.Box.Size = Vector2.new(boxWidth, boxHeight)
				drawings.Box.Color = color
				drawings.Box.Thickness = ESPThickness.Value
				drawings.Box.Filled = ESPFilled.Enabled
				drawings.Box.Transparency = ESPFilled.Enabled and 0.18 or 1
				drawings.Box.Visible = ESPBoxes.Enabled

				drawings.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
				drawings.Tracer.To = Vector2.new(rootPos.X, bottom.Y)
				drawings.Tracer.Color = color
				drawings.Tracer.Thickness = ESPThickness.Value
				drawings.Tracer.Visible = ESPTracers.Enabled
				continue
			end
		end
		drawings.Box.Visible = false
		drawings.Tracer.Visible = false
	end
end

ESP = vape.Categories.Render:CreateModule({
	Name = 'ESP',
	Tooltip = 'Deadline workspace.characters box/tracer ESP using the Vape API.',
	Function = function(enabled)
		clearESP()
		if not enabled then return end
		if not hasDrawing() then
			notify('ESP', 'Drawing API is unavailable in this executor.', 8, 'alert')
			task.defer(function() if ESP.Enabled then ESP:Toggle() end end)
			return
		end

		for _, model in ipairs(CharFolder:GetChildren()) do makeESPModel(model) end
		espAddedConnection = CharFolder.ChildAdded:Connect(function(model)
			task.defer(function()
				task.wait(0.1)
				if ESP.Enabled then makeESPModel(model) end
			end)
		end)
		espRemovedConnection = CharFolder.ChildRemoved:Connect(destroyESPModel)
		espRenderConnection = RunService.RenderStepped:Connect(updateESP)
	end
})
ESPBoxes = ESP:CreateToggle({Name = 'Boxes', Default = true})
ESPTracers = ESP:CreateToggle({Name = 'Tracers', Default = false})
ESPFilled = ESP:CreateToggle({Name = 'Filled', Default = false})
ESPTeamCheck = ESP:CreateToggle({Name = 'Team Check', Default = true})
ESPDistance = ESP:CreateSlider({Name = 'Max Distance', Min = 50, Max = 5000, Default = 1500, Suffix = 'studs'})
ESPThickness = ESP:CreateSlider({Name = 'Thickness', Min = 1, Max = 4, Default = 1})
ESPColor = ESP:CreateColorSlider({Name = 'Player Color', DefaultHue = 0.5, DefaultSat = 1, DefaultValue = 1})

-- CHAMS -----------------------------------------------------------------------
local Chams
local ChamsTeamCheck
local ChamsThroughWalls
local ChamsFillColor
local ChamsOutlineColor
local ChamsFillTransparency
local ChamsOutlineTransparency
local chamObjects = {}
local chamAddedConnection
local chamRemovedConnection

local function destroyCham(model)
	local highlight = chamObjects[model]
	if highlight then pcall(function() highlight:Destroy() end) end
	chamObjects[model] = nil
end

local function updateChamObject(model)
	local highlight = chamObjects[model]
	if not highlight then return end
	local valid = validTargetModel(model, ChamsTeamCheck.Enabled)
	highlight.Enabled = valid
	highlight.FillColor = colorFrom(ChamsFillColor, Color3.fromRGB(255, 110, 190))
	highlight.OutlineColor = colorFrom(ChamsOutlineColor, Color3.fromRGB(255, 255, 255))
	highlight.FillTransparency = ChamsFillTransparency.Value
	highlight.OutlineTransparency = ChamsOutlineTransparency.Value
	highlight.DepthMode = ChamsThroughWalls.Enabled and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
end

local function makeCham(model)
	if chamObjects[model] or not model:IsA('Model') or isLocalModel(model) then return end
	local highlight = Instance.new('Highlight')
	highlight.Name = 'VapeDeadlineChams'
	highlight.Adornee = model
	highlight.Parent = model
	chamObjects[model] = highlight
	updateChamObject(model)
end

local function refreshChams()
	for model in pairs(chamObjects) do updateChamObject(model) end
end

local function clearChams()
	safeDisconnect(chamAddedConnection)
	safeDisconnect(chamRemovedConnection)
	chamAddedConnection, chamRemovedConnection = nil, nil
	for model in pairs(chamObjects) do destroyCham(model) end
	table.clear(chamObjects)
end

Chams = vape.Categories.Render:CreateModule({
	Name = 'Chams',
	Tooltip = 'Deadline Highlight chams for workspace.characters.',
	Function = function(enabled)
		clearChams()
		if not enabled then return end
		for _, model in ipairs(CharFolder:GetChildren()) do makeCham(model) end
		chamAddedConnection = CharFolder.ChildAdded:Connect(function(model)
			task.defer(function()
				task.wait(0.1)
				if Chams.Enabled then makeCham(model) end
			end)
		end)
		chamRemovedConnection = CharFolder.ChildRemoved:Connect(destroyCham)
	end
})
ChamsTeamCheck = Chams:CreateToggle({Name = 'Team Check', Default = true, Function = refreshChams})
ChamsThroughWalls = Chams:CreateToggle({Name = 'Through Walls', Default = true, Function = refreshChams})
ChamsFillColor = Chams:CreateColorSlider({Name = 'Fill Color', DefaultHue = 0.92, DefaultSat = 0.65, DefaultValue = 1, Function = refreshChams})
ChamsOutlineColor = Chams:CreateColorSlider({Name = 'Outline Color', DefaultHue = 0, DefaultSat = 0, DefaultValue = 1, Function = refreshChams})
ChamsFillTransparency = Chams:CreateSlider({Name = 'Fill Transparency', Min = 0, Max = 1, Decimal = 100, Default = 0.55, Function = refreshChams})
ChamsOutlineTransparency = Chams:CreateSlider({Name = 'Outline Transparency', Min = 0, Max = 1, Decimal = 100, Default = 0, Function = refreshChams})

-- NAMETAGS --------------------------------------------------------------------
local NameTags
local NameTagsDistance
local NameTagsHealth
local NameTagsDisplayName
local NameTagsBackground
local NameTagsTeamCheck
local NameTagsMaxDistance
local NameTagsSize
local NameTagsColor
local nametagObjects = {}
local nametagRenderConnection
local nametagAddedConnection
local nametagRemovedConnection

local function destroyNameTag(model)
	local data = nametagObjects[model]
	if not data then return end
	removeDrawing(data.Text)
	removeDrawing(data.Background)
	nametagObjects[model] = nil
end

local function makeNameTag(model)
	if nametagObjects[model] or not hasDrawing() or not model:IsA('Model') or isLocalModel(model) then return end
	local text = Drawing.new('Text')
	text.Size = NameTagsSize and NameTagsSize.Value or 14
	text.Center = true
	text.Outline = true
	text.Font = 2
	text.Color = colorFrom(NameTagsColor, Color3.fromRGB(255, 255, 100))
	text.Visible = false

	local background = Drawing.new('Square')
	background.Filled = true
	background.Color = Color3.fromRGB(15, 15, 18)
	background.Transparency = 0.65
	background.Visible = false

	nametagObjects[model] = {Text = text, Background = background}
end

local function clearNameTags()
	safeDisconnect(nametagRenderConnection)
	safeDisconnect(nametagAddedConnection)
	safeDisconnect(nametagRemovedConnection)
	nametagRenderConnection, nametagAddedConnection, nametagRemovedConnection = nil, nil, nil
	for model in pairs(nametagObjects) do destroyNameTag(model) end
	table.clear(nametagObjects)
end

local function updateNameTags()
	local camera = currentCamera()
	if not camera then return end
	local origin = localPosition()
	local maxDistance = NameTagsMaxDistance.Value
	local color = colorFrom(NameTagsColor, Color3.fromRGB(255, 255, 100))

	for model, data in pairs(nametagObjects) do
		local root = getRoot(model)
		local valid = validTargetModel(model, NameTagsTeamCheck.Enabled) and root ~= nil
		if valid then
			local distance = (root.Position - origin).Magnitude
			if distance <= maxDistance then
				local anchor = getHead(model) or root
				local screen, onScreen = camera:WorldToViewportPoint(anchor.Position + Vector3.new(0, 1.1, 0))
				if onScreen and screen.Z > 0 then
					local parts = {modelDisplayName(model, NameTagsDisplayName.Enabled)}
					if NameTagsHealth.Enabled then
						local hum = getHumanoid(model)
						if hum then parts[#parts + 1] = tostring(math.max(math.floor(hum.Health + 0.5), 0)) .. 'hp' end
					end
					if NameTagsDistance.Enabled then parts[#parts + 1] = tostring(math.floor(distance + 0.5)) .. 'm' end

					data.Text.Text = table.concat(parts, '  ')
					data.Text.Size = NameTagsSize.Value
					data.Text.Color = color
					data.Text.Position = Vector2.new(screen.X, screen.Y - NameTagsSize.Value - 4)
					data.Text.Visible = true

					local bounds = data.Text.TextBounds
					data.Background.Position = Vector2.new(screen.X - bounds.X / 2 - 5, screen.Y - NameTagsSize.Value - 6)
					data.Background.Size = Vector2.new(bounds.X + 10, bounds.Y + 6)
					data.Background.Visible = NameTagsBackground.Enabled
					continue
				end
			end
		end
		data.Text.Visible = false
		data.Background.Visible = false
	end
end

NameTags = vape.Categories.Render:CreateModule({
	Name = 'NameTags',
	Tooltip = 'Deadline names, distance and health labels for workspace.characters.',
	Function = function(enabled)
		clearNameTags()
		if not enabled then return end
		if not hasDrawing() then
			notify('NameTags', 'Drawing API is unavailable in this executor.', 8, 'alert')
			task.defer(function() if NameTags.Enabled then NameTags:Toggle() end end)
			return
		end

		for _, model in ipairs(CharFolder:GetChildren()) do makeNameTag(model) end
		nametagAddedConnection = CharFolder.ChildAdded:Connect(function(model)
			task.defer(function()
				task.wait(0.1)
				if NameTags.Enabled then makeNameTag(model) end
			end)
		end)
		nametagRemovedConnection = CharFolder.ChildRemoved:Connect(destroyNameTag)
		nametagRenderConnection = RunService.RenderStepped:Connect(updateNameTags)
	end
})
NameTagsDistance = NameTags:CreateToggle({Name = 'Distance', Default = true})
NameTagsHealth = NameTags:CreateToggle({Name = 'Health', Default = true})
NameTagsDisplayName = NameTags:CreateToggle({Name = 'Use Display Name', Default = true})
NameTagsBackground = NameTags:CreateToggle({Name = 'Background', Default = true})
NameTagsTeamCheck = NameTags:CreateToggle({Name = 'Team Check', Default = true})
NameTagsMaxDistance = NameTags:CreateSlider({Name = 'Max Distance', Min = 50, Max = 5000, Default = 1500, Suffix = 'studs'})
NameTagsSize = NameTags:CreateSlider({Name = 'Text Size', Min = 10, Max = 28, Default = 14})
NameTagsColor = NameTags:CreateColorSlider({Name = 'Text Color', DefaultHue = 0.16, DefaultSat = 0.65, DefaultValue = 1})

-- Full-session cleanup. Module toggle callbacks already clean their own state; this catches Uninject.
if type(vape.Clean) == 'function' then
	vape:Clean(function()
		if hookState.Owner == vape then
			hookState.Enabled = false
			hookState.Redirect = nil
		end
		destroyFOV()
		clearESP()
		clearChams()
		clearNameTags()
	end)
end

notify('Deadline', 'Loaded SilentAim, ESP, Chams and NameTags for 12144402492.', 6)

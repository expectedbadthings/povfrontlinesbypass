-- Initialize the UI and only the modules required by this session.
if not game:IsLoaded() then game.Loaded:Wait() end

if shared.vape then shared.vape:Uninject() end

local vape
local baseVapeLoad
local loadstring = function(...)
	local res, err = loadstring(...)
	if err then
		warn('Vape failed to compile: '..tostring(err))
		if vape then
			vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
		end
		error(err, 2)
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local gui = 'new'
local runtime = shared.VapeRuntime
if not runtime then
	-- Direct main.lua launches use the installed runtime too.
	runtime = assert(loadstring(readfile('newvape/libraries/runtime.lua'), 'runtime'))()
	shared.VapeRuntime = runtime
end
local downloadFile = runtime.Read
local loading = loadstring(downloadFile('newvape/guis/loading.lua'), 'Vape loading screen')()
loading:SetLoadingProgress(0.1, 'Loading interface')
local preload = {'newvape/guis/new.lua'}
if not shared.VapeIndependent then preload[#preload + 1] = 'newvape/games/universal.lua' end
runtime.Prefetch(preload)
local function finishLoading()
	vape.Init = nil
	loading:SetLoadingProgress(0.85, 'Applying profile')

	-- Frontlines can replace vape.Load during the actor bootstrap.
	-- Some executors lose that temporary method during the handoff, so keep
	-- the GUI's original Load function as a guaranteed fallback.
	local loadMethod = vape and vape.Load
	if type(loadMethod) ~= 'function' then
		loadMethod = baseVapeLoad
		if type(loadMethod) == 'function' then
			vape.Load = loadMethod
		end
	end

	if type(loadMethod) ~= 'function' then
		error('[illusionHD] GUI loaded without a usable Load method.', 0)
	end

	-- ADDITIONAL_MODULES_BOOTSTRAP: skip the outer Frontlines actor handoff.
	if loadMethod == baseVapeLoad and not vape.Libraries.additions then
		local ok, err = pcall(function()
			local init = loadstring(downloadFile('newvape/libraries/additions.lua'), 'Vape additions')()
			init(vape)
		end)
		if not ok then vape:CreateNotification('Additional modules', tostring(err), 12, 'alert') end
		loadMethod = vape.Load
	end
	loadMethod(vape)
	loading:SetLoadingProgress(1, 'Your session is ready')
	if vape.HideLoadingScreen then
		vape:HideLoadingScreen()
	end
	task.spawn(function()
		repeat
			task.wait(30)
			if shared.vape ~= vape or not vape.Loaded then break end
			vape:Save()
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				local cached, source = pcall(readfile, 'newvape/loader.lua')
				if cached then
					assert(loadstring(source, 'loader'))()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/expectedbadthings/povfrontlinesbypass/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = '..string.format('%q', shared.VapeCustomProfile)..'\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Settings.GUI.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.GUIBind.Keys, ' + '):upper()..' to open GUI', 5)
		end
	end
end

if not isfolder('newvape/assets/'..gui) then
	makefolder('newvape/assets/'..gui)
end
vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
if type(vape) ~= 'table' then
	error('[illusionHD] GUI file did not return the Vape table.', 0)
end
baseVapeLoad = vape.Load
if type(baseVapeLoad) ~= 'function' then
	error('[illusionHD] GUI file is missing vape:Load(). Re-upload guis/new.lua.', 0)
end
shared.vape = vape
loading:SetTheme(vape.Libraries.uipallet, vape.GUIColor)


vape.HideLoadingScreen = function(_, immediate)
	loading:HideLoadingScreen(immediate)
end
vape:Clean(function()
	loading:HideLoadingScreen(true)
end)
loading:SetLoadingProgress(0.5, 'Preparing game modules')

if not shared.VapeIndependent then
	loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
	local gamePath = 'newvape/games/'..game.PlaceId..'.lua'
	if not shared.VapeDeveloper or isfile(gamePath) then
		local source = downloadFile(gamePath, nil, true)
		if source then loadstring(source, tostring(game.PlaceId))(...) end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end

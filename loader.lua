-- Cache-first bootstrap. Set shared.VapeRefresh = true for an explicit update.
if shared.VapeBooting then return end
shared.VapeBooting = true
local previousVape = shared.vape
local ok, err = pcall(function()
	assert(type(readfile) == 'function' and type(writefile) == 'function'
		and type(makefolder) == 'function', 'Executor filesystem support is required.')
	for _, path in ipairs({'newvape', 'newvape/assets', 'newvape/assets/new',
		'newvape/games', 'newvape/guis', 'newvape/libraries', 'newvape/profiles'}) do
		pcall(makefolder, path)
	end
	local path = 'newvape/libraries/runtime.lua'
	local cached, source = pcall(readfile, path)
	local chunk = cached and type(source) == 'string' and loadstring(source, '@'..path)
	if not chunk or (shared.VapeRefresh and not shared.VapeDeveloper) then
		source = game:HttpGet('https://raw.githubusercontent.com/expectedbadthings/povfrontlinesbypass/main/libraries/runtime.lua', true)
		chunk = assert(loadstring(source, '@'..path))
		writefile(path, source)
	end
	local runtime = chunk()
	shared.VapeRuntime = runtime
	writefile('newvape/profiles/commit.txt', 'main')
	runtime.Read('newvape/loader.lua')
	if not game:IsLoaded() then game.Loaded:Wait() end
	assert(loadstring(runtime.Read('newvape/main.lua'), '@newvape/main.lua'))()
end)
shared.VapeBooting = nil
shared.VapeRefresh = nil
if not ok then
	if shared.VapeLoading then pcall(shared.VapeLoading.HideLoadingScreen, shared.VapeLoading, true) end
	if shared.vape and shared.vape ~= previousVape then pcall(function() shared.vape:Uninject() end) end
	error('[illusionHD] Startup failed: '..tostring(err), 0)
end

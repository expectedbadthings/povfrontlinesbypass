-- TenacityForRoblox bootstrap
-- Repository: https://github.com/expectedbadthings/TenacityForRoblox
if shared.TenacityBooting then return end
shared.TenacityBooting = true

local previous = shared.Tenacity
local function boot()
    assert(type(readfile)=='function' and type(writefile)=='function' and type(makefolder)=='function',
        'Executor filesystem support is required.')

    for _, path in ipairs({
        'tenacity', 'tenacity/assets', 'tenacity/assets/new', 'tenacity/assets/tenacity',
        'tenacity/games', 'tenacity/guis', 'tenacity/libraries', 'tenacity/profiles',
        'tenacity/additions', 'tenacity/additions/configs'
    }) do pcall(makefolder, path) end

    -- One-time source-cache invalidation for fixes that must replace an existing
    -- tenacity/ cache. The marker is written only after main.lua starts cleanly.
    local cacheRevision='tenacity-r12-sidegui-controls'
    local cacheRevisionPath='tenacity/profiles/cache-revision.txt'
    local revisionOK,currentRevision=pcall(readfile,cacheRevisionPath)
    local refreshForRevision=not revisionOK or currentRevision~=cacheRevision
    if refreshForRevision and not shared.TenacityDeveloper then
        shared.TenacityRefresh=true
    end

    local runtimePath='tenacity/libraries/runtime.lua'
    local cached, source=pcall(readfile,runtimePath)
    local chunk=cached and type(source)=='string' and loadstring(source,'@'..runtimePath)
    if not chunk or (shared.TenacityRefresh and not shared.TenacityDeveloper) then
        source=game:HttpGet('https://raw.githubusercontent.com/expectedbadthings/TenacityForRoblox/main/libraries/runtime.lua',true)
        chunk=assert(loadstring(source,'@'..runtimePath))
        writefile(runtimePath,source)
    end

    local runtime=chunk()
    shared.TenacityRuntime=runtime
    writefile('tenacity/profiles/commit.txt',runtime.Branch or 'main')

    -- Refresh the cached bootstrap too, then enter the new client.
    runtime.Read('tenacity/loader.lua')
    if not game:IsLoaded() then game.Loaded:Wait() end
    assert(loadstring(runtime.Read('tenacity/main.lua'),'@tenacity/main.lua'))()
    if refreshForRevision then pcall(writefile,cacheRevisionPath,cacheRevision) end
end

local ok, err = xpcall(boot, function(message)
    local trace = ''
    pcall(function() trace = debug.traceback(nil, 2) end)
    return tostring(message)..(trace ~= '' and ('\n'..trace) or '')
end)

shared.TenacityBooting=nil
shared.TenacityRefresh=nil
if not ok then
    if shared.TenacityLoading then pcall(shared.TenacityLoading.HideLoadingScreen,shared.TenacityLoading,true) end
    if shared.Tenacity and shared.Tenacity~=previous then pcall(function() shared.Tenacity:Uninject() end) end
    error('[Tenacity] Startup failed: '..tostring(err),0)
end

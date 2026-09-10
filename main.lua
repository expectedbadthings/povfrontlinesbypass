-- TenacityForRoblox session bootstrap.
if not game:IsLoaded() then game.Loaded:Wait() end
if shared.Tenacity then pcall(function() shared.Tenacity:Uninject() end) end

local core
local baseLoad
local rawLoadstring=loadstring
local function compile(source,name)
    local chunk,err=rawLoadstring(source,name)
    if not chunk then
        warn('[Tenacity] Compile failed: '..tostring(err))
        if core then core:CreateNotification('Tenacity','Failed to compile '..tostring(name)..': '..tostring(err),30,'alert') end
        error(err,2)
    end
    return chunk
end

local queue_on_teleport=queue_on_teleport or function() end
local isfile=isfile or function(file)
    local ok,value=pcall(readfile,file)
    return ok and value~=nil and value~=''
end
local cloneref=cloneref or function(value) return value end
local Players=cloneref(game:GetService('Players'))

local runtime=shared.TenacityRuntime
if not runtime then
    runtime=assert(compile(readfile('tenacity/libraries/runtime.lua'),'@tenacity/libraries/runtime.lua'))()
    shared.TenacityRuntime=runtime
end
local read=runtime.Read

local loading=compile(read('tenacity/guis/loading.lua'),'@tenacity/guis/loading.lua')()
loading:SetLoadingProgress(.08,'Starting Tenacity')

local preload={'tenacity/guis/tenacity.lua','tenacity/libraries/gui-api.lua'}
if not shared.TenacityIndependent then preload[#preload+1]='tenacity/games/universal.lua' end
runtime.Prefetch(preload)
loading:SetLoadingProgress(.22,'Building interface')

core=compile(read('tenacity/guis/tenacity.lua'),'@tenacity/guis/tenacity.lua')()
assert(type(core)=='table','Tenacity GUI did not return its core object.')
local expectedBuild='r12-sidegui-controls'
assert(core.Build==expectedBuild, 'Stale Tenacity GUI detected (got '..tostring(core.Build)..', expected '..expectedBuild..'). Install main.lua, loader.lua and guis/tenacity.lua from the same release.')
assert(type(core.Load)=='function','Tenacity GUI is missing core:Load().')
baseLoad=core.Load
shared.Tenacity=core

local apiFactory=compile(read('tenacity/libraries/gui-api.lua'),'@tenacity/libraries/gui-api.lua')()
core.API=apiFactory(core)
shared.TenacityAPI=core.API
loading:SetTheme(core.Libraries.uipallet,core.GUIColor)

core.HideLoadingScreen=function(_,immediate) loading:HideLoadingScreen(immediate) end
core:Clean(function() loading:HideLoadingScreen(true) end)

local function finish()
    core.Init=nil
    loading:SetLoadingProgress(.82,'Applying profile')

    local loadMethod=type(core.Load)=='function' and core.Load or baseLoad
    if type(loadMethod)~='function' then error('[Tenacity] No usable profile loader.',0) end

    if loadMethod==baseLoad and not core.Libraries.additions then
        local ok,err=pcall(function()
            local init=compile(read('tenacity/libraries/additions.lua'),'@tenacity/libraries/additions.lua')()
            init(core)
        end)
        if not ok then core:CreateNotification('Additional modules',tostring(err),12,'alert') end
        loadMethod=core.Load
    end

    loadMethod(core)
    loading:SetLoadingProgress(1,'Tenacity is ready')
    core:HideLoadingScreen()

    task.spawn(function()
        repeat
            task.wait(30)
            if shared.Tenacity~=core or not core.Loaded then break end
            core:Save()
        until not core.Loaded
    end)

    local queued=false
    core:Clean(Players.LocalPlayer.OnTeleport:Connect(function()
        if queued or shared.TenacityIndependent then return end
        queued=true
        core:Save()
        local teleportScript=[[
            shared.TenacityReload=true
            local ok,source=pcall(readfile,'tenacity/loader.lua')
            if ok then
                assert(loadstring(source,'@tenacity/loader.lua'))()
            else
                assert(loadstring(game:HttpGet('https://raw.githubusercontent.com/expectedbadthings/TenacityForRoblox/main/loader.lua',true),'@TenacityForRoblox/loader.lua'))()
            end
        ]]
        if shared.TenacityDeveloper then teleportScript='shared.TenacityDeveloper=true\n'..teleportScript end
        if shared.TenacityCustomProfile then teleportScript='shared.TenacityCustomProfile='..string.format('%q',shared.TenacityCustomProfile)..'\n'..teleportScript end
        queue_on_teleport(teleportScript)
    end))

    if not shared.TenacityReload and core.Categories and core.Settings.GUI
        and core.Settings.GUI.Options['GUI bind indicator'] and core.Settings.GUI.Options['GUI bind indicator'].Enabled then
        local bind=core.GUIBind and table.concat(core.GUIBind.Keys,' + '):upper() or 'RSHIFT'
        core:CreateNotification('Tenacity','Loaded — press '..bind..' to open the ClickGUI.',5)
    end
end

loading:SetLoadingProgress(.48,'Loading modules')
if not shared.TenacityIndependent then
    compile(read('tenacity/games/universal.lua'),'@tenacity/games/universal.lua')()
    local gamePath='tenacity/games/'..game.PlaceId..'.lua'
    if not shared.TenacityDeveloper or isfile(gamePath) then
        local source=read(gamePath,nil,true)
        if source then compile(source,'@'..gamePath)(...) end
    end
    finish()
else
    core.Init=finish
    return core
end

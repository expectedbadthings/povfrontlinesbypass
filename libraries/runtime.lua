-- TenacityForRoblox source/cache runtime.
-- Local cache paths always live under tenacity/, while GitHub files live at repo root.
local runtime = {
    Repo = 'expectedbadthings/TenacityForRoblox',
    Branch = 'main',
    Root = 'tenacity/',
    Stats = {Downloads = 0, DiskHits = 0, MemoryHits = 0}
}

local sources, pending, missing = {}, {}, {}
local refresh = shared.TenacityRefresh == true and not shared.TenacityDeveloper

local function remoteBase()
    return 'https://raw.githubusercontent.com/'..runtime.Repo..'/'..runtime.Branch..'/'
end

local function remotePath(path)
    assert(type(path) == 'string' and path:sub(1, #runtime.Root) == runtime.Root, 'Invalid Tenacity runtime path')
    assert(not path:find('..', 1, true), 'Unsafe Tenacity runtime path')
    return path:sub(#runtime.Root + 1)
end

local function valid(data, path)
    if type(data) ~= 'string' or #data == 0 then return false end
    if path:match('%.lua$') or path:match('%.json$') or path:match('%.txt$') or path:match('%.md$') then
        local head = data:sub(1, 512):lower()
        if head:find('404: not found', 1, true) or head:find('<!doctype html', 1, true)
            or head:find('<html', 1, true) or head:find('repository not found', 1, true) then
            return false
        end
    end
    if path:match('%.lua$') then return loadstring(data, '@'..path) ~= nil end
    return true
end

function runtime.Read(path, callback, optional)
    remotePath(path)
    while pending[path] do task.wait() end

    local data = sources[path]
    if data then
        runtime.Stats.MemoryHits += 1
    elseif missing[path] then
        if optional then return nil end
        error('Missing Tenacity runtime file: '..path, 2)
    else
        pending[path] = true
        local ok, result = pcall(function()
            if not refresh then
                local diskOK, cached = pcall(readfile, path)
                if diskOK and valid(cached, path) then
                    runtime.Stats.DiskHits += 1
                    return cached
                end
            end

            local fetched, body = pcall(game.HttpGet, game, remoteBase()..remotePath(path), true)
            runtime.Stats.Downloads += 1
            if fetched and type(body) == 'string' and body:lower():match('^%s*404: not found%s*$') and optional then
                missing[path] = true
                return nil
            end
            if not fetched or not valid(body, path) then
                error('Failed to fetch '..path..': '..tostring(body), 0)
            end
            writefile(path, body)
            return body
        end)
        pending[path] = nil
        if not ok then error(result, 2) end
        data = result
        sources[path] = data
    end

    if data == nil then return nil end
    return callback and callback(path) or data
end

function runtime.Asset(relativePath)
    local path = runtime.Root..'assets/'..relativePath
    if not getcustomasset then return '' end
    local ok, result = pcall(runtime.Read, path, getcustomasset)
    return ok and result or ''
end

-- Small bounded prefetcher: enough concurrency to hide latency without flooding executors.
function runtime.Prefetch(paths)
    local nextIndex, active, errors = 1, math.min(4, #paths), {}
    for _ = 1, active do
        task.spawn(function()
            while nextIndex <= #paths do
                local index = nextIndex
                nextIndex += 1
                local ok, err = pcall(runtime.Read, paths[index])
                if not ok then errors[#errors + 1] = tostring(err) end
            end
            active -= 1
        end)
    end
    while active > 0 do task.wait() end
    if #errors > 0 then error(table.concat(errors, '\n'), 2) end
end

function runtime.ClearMemoryCache()
    table.clear(sources)
    table.clear(missing)
end

return runtime

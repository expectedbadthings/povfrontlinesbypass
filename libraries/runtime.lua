-- Shared, session-scoped source cache. Profiles are never managed here.
local runtime = {Stats = {Downloads = 0, DiskHits = 0, MemoryHits = 0}}
local base = 'https://raw.githubusercontent.com/expectedbadthings/povfrontlinesbypass/main/'
local sources, pending, missing = {}, {}, {}
local refresh = shared.VapeRefresh == true and not shared.VapeDeveloper

local function valid(data, path)
	if type(data) ~= 'string' or data:match('^%s*$') then return false end
	local head = data:sub(1, 512):lower()
	if head:find('404: not found', 1, true) or head:find('<!doctype html', 1, true)
		or head:find('<html', 1, true) or head:find('repository not found', 1, true) then return false end
	if path:match('%.lua$') then return loadstring(data, '@'..path) ~= nil end
	return true
end

function runtime.Read(path, callback, optional)
	assert(type(path) == 'string' and path:sub(1, 8) == 'newvape/' and not path:find('..', 1, true), 'Invalid runtime path')
	while pending[path] do task.wait() end
	local data = sources[path]
	if data then
		runtime.Stats.MemoryHits = runtime.Stats.MemoryHits + 1
	elseif missing[path] then
		if optional then return nil end
		error('Missing runtime file: '..path, 2)
	else
		pending[path] = true
		local ok, result = pcall(function()
			if not refresh then
				local readOK, cached = pcall(readfile, path)
				if readOK and valid(cached, path) then
					runtime.Stats.DiskHits = runtime.Stats.DiskHits + 1
					return cached
				end
			end
			local fetched, body = pcall(game.HttpGet, game, base..path:sub(9), true)
			runtime.Stats.Downloads = runtime.Stats.Downloads + 1
			if fetched and type(body) == 'string' and body:lower():match('^%s*404: not found%s*$') and optional then
				missing[path] = true
				return nil
			end
			if not fetched or not valid(body, path) then
				error('Failed to fetch valid source for '..path..': '..tostring(body), 0)
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

-- At most three requests in flight; all workers finish before errors propagate.
function runtime.Prefetch(paths)
	local nextIndex, active, errors = 1, math.min(3, #paths), {}
	for _ = 1, active do
		task.spawn(function()
			while nextIndex <= #paths do
				local index = nextIndex
				nextIndex = nextIndex + 1
				local ok, err = pcall(runtime.Read, paths[index])
				if not ok then errors[#errors + 1] = tostring(err) end
			end
			active = active - 1
		end)
	end
	while active > 0 do task.wait() end
	if #errors > 0 then error(table.concat(errors, '\n'), 2) end
end

return runtime

-- Bundled additions and support framework; no extra downloads are required.
local sources = {}
sources['core/aim.lua'] = [==[
return function(ctx)
	local aim = {
		ars = game.PlaceId == 286090429,
		live = {},
		err = nil
	}
	local src = [=[
local key, kind, ars, mode, range, chance, head, part, walls, players, id = ...
local env = (getgenv and getgenv()) or _G
env.vtactor = type(env.vtactor) == 'table' and env.vtactor or {}
local box = env.vtactor
local old = box[key]
if type(old) == 'table' then
	for i = #old, 1, -1 do
		local val = old[i]
		if type(val) == 'table' and type(val[1]) == 'function' then
			if type(restorefunction) == 'function' then
				pcall(restorefunction, val[1])
			elseif type(hookfunction) == 'function' and type(val[2]) == 'function' then
				pcall(hookfunction, val[1], val[2])
			end
		end
	end
end
local save = {}
box[key] = save
local ps = game:GetService('Players')
local us = game:GetService('UserInputService')
local lp = ps.LocalPlayer
local rng = Random.new()
local make = Ray.new
local count = 0
local busy = false
local chan
if type(get_comm_channel) == 'function' and type(id) == 'number' then
	pcall(function() chan = get_comm_channel(id) end)
end
local function send(a, b)
	if chan then pcall(chan.Fire, chan, a, b) end
end
local function add(fn, cb)
	if type(fn) ~= 'function' or type(hookfunction) ~= 'function' then return false end
	local base
	local ok, val = pcall(hookfunction, fn, function(...)
		return cb(base, ...)
	end)
	if not ok or type(val) ~= 'function' then return false end
	base = val
	save[#save + 1] = {fn, val}
	count += 1
	return true, val
end
local function alive(plr)
	local char = plr and plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass('Humanoid')
	if not hum or hum.Health <= 0 then return end
	return char
end
local function pick(origin)
	if players == false or not lp then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local cur = us.TouchEnabled and cam.ViewportSize / 2 or us:GetMouseLocation()
	local best
	local dist = math.huge
	for _, plr in ipairs(ps:GetPlayers()) do
		if plr == lp then continue end
		if lp.Team and plr.Team and lp.Team == plr.Team then continue end
		local char = alive(plr)
		if not char then continue end
		local root = char:FindFirstChild('HumanoidRootPart')
		if not root then continue end
		local val
		if mode == 'Position' then
			val = (root.Position - origin).Magnitude
		else
			local pos, vis = cam:WorldToViewportPoint(root.Position)
			if not vis then continue end
			val = (Vector2.new(pos.X, pos.Y) - cur).Magnitude
		end
		if val > range or val >= dist then continue end
		local name = part
		if kind == 'silent' then name = rng:NextNumber(0, 100) <= head and 'Head' or 'HumanoidRootPart' end
		if name == 'RootPart' then name = 'HumanoidRootPart' end
		local hit = char:FindFirstChild(name) or root
		if not hit or not hit:IsA('BasePart') then continue end
		if walls then
			local set = RaycastParams.new()
			set.FilterType = Enum.RaycastFilterType.Exclude
			local list = {}
			if lp.Character then list[#list + 1] = lp.Character end
			set.FilterDescendantsInstances = list
			set.IgnoreWater = true
			busy = true
			local ok, ray = pcall(workspace.Raycast, workspace, origin, hit.Position - origin, set)
			busy = false
			if not ok then continue end
			if ray and not ray.Instance:IsDescendantOf(char) then continue end
		end
		dist = val
		best = hit
	end
	return best
end
local function calc(origin, dir)
	if busy or typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return origin, dir, false end
	if dir.Magnitude <= 0.0001 or rng:NextNumber(0, 100) > chance then return origin, dir, false end
	local hit = pick(origin)
	if not hit then return origin, dir, false end
	if kind == 'silent' then
		local vec = hit.Position - origin
		if vec.Magnitude <= 0.0001 then return origin, dir, false end
		return origin, vec.Unit * dir.Magnitude, true, hit
	end
	local unit = dir.Unit
	local vec = hit.CFrame:VectorToObjectSpace(unit)
	local half = hit.Size * 0.5
	local dist = math.abs(vec.X) * half.X + math.abs(vec.Y) * half.Y + math.abs(vec.Z) * half.Z
	return hit.Position - unit * (dist + 0.05), dir, true, hit
end
local function ray(beam)
	if typeof(beam) ~= 'Ray' then return beam, false end
	local origin, dir, ok, hit = calc(beam.Origin, beam.Direction)
	if not ok then return beam, false end
	busy = true
	local out = make(origin, dir)
	busy = false
	return out, true, hit
end
if ars then
	if type(getgc) == 'function' and type(islclosure) == 'function' and type(debug) == 'table' and type(debug.info) == 'function' and type(debug.getupvalues) == 'function' and type(debug.getconstants) == 'function' then
		local ok, list = pcall(getgc)
		if ok and type(list) == 'table' then
			for _, fn in pairs(list) do
				if type(fn) ~= 'function' or not islclosure(fn) then continue end
				if type(isexecutorclosure) == 'function' then
					local xok, mine = pcall(isexecutorclosure, fn)
					if xok and mine then continue end
				end
				local good, arity = pcall(debug.info, fn, 'a')
				if not good or arity ~= 2 then continue end
				local uok, ups = pcall(debug.getupvalues, fn)
				local cok, cons = pcall(debug.getconstants, fn)
				local nok, name = pcall(debug.info, fn, 'n')
				if not uok or type(ups) ~= 'table' or #ups ~= 2 then continue end
				if not cok or type(cons) ~= 'table' or #cons ~= 17 then continue end
				if not nok or type(name) ~= 'string' or #name > 10 then continue end
				add(fn, function(base, p1, p2)
					if type(base) ~= 'function' then return end
					if typeof(p1) == 'Ray' then p1 = ray(p1) end
					return base(p1, p2)
				end)
			end
		end
	end
else
	local ok, raw = add(Ray.new, function(base, origin, dir)
		if type(base) ~= 'function' then return end
		local a, b = calc(origin, dir)
		return base(a, b)
	end)
	if ok and type(raw) == 'function' then make = raw end
	add(workspace.Raycast, function(base, self, origin, dir, params)
		if type(base) ~= 'function' then return end
		local a, b = calc(origin, dir)
		return base(self, a, b, params)
	end)
	local function legacy(fn)
		add(fn, function(base, self, beam, ...)
			if type(base) ~= 'function' then return end
			local out = ray(beam)
			return base(self, out, ...)
		end)
	end
	legacy(workspace.FindPartOnRay)
	legacy(workspace.FindPartOnRayWithIgnoreList)
	legacy(workspace.FindPartOnRayWithWhitelist)
	local cam = Instance.new('Camera')
	local function camera(fn)
		add(fn, function(base, self, ...)
			if type(base) ~= 'function' then return end
			local beam = base(self, ...)
			local out = ray(beam)
			return out
		end)
	end
	camera(cam.ScreenPointToRay)
	camera(cam.ViewportPointToRay)
end
send('ready', count)
]=]
	local stop = [=[
local key = ...
local env = (getgenv and getgenv()) or _G
local box = type(env.vtactor) == 'table' and env.vtactor or nil
local old = box and box[key]
if type(old) == 'table' then
	for i = #old, 1, -1 do
		local val = old[i]
		if type(val) == 'table' and type(val[1]) == 'function' then
			if type(restorefunction) == 'function' then
				pcall(restorefunction, val[1])
			elseif type(hookfunction) == 'function' and type(val[2]) == 'function' then
				pcall(hookfunction, val[1], val[2])
			end
		end
	end
	box[key] = nil
end
]=]

	local function actors()
		if type(getactors) ~= 'function' then return {} end
		local ok, list = pcall(getactors)
		return ok and type(list) == 'table' and list or {}
	end

	local function send(actor, data, id)
		return pcall(run_on_actor, actor, src,
			data.key,
			data.kind,
			data.ars,
			data.mode,
			data.range,
			data.chance,
			data.head,
			data.part,
			data.walls,
			data.players,
			id
		)
	end

	local function clean(actor, key)
		if type(run_on_actor) ~= 'function' then return false end
		return pcall(run_on_actor, actor, stop, key)
	end

	function aim:stop(key)
		self.live[key] = nil
		for _, actor in ipairs(actors()) do clean(actor, key) end
		return true
	end

	function aim:start(key, kind, ars, data)
		self:stop(key)
		if type(run_on_actor) ~= 'function' or type(getactors) ~= 'function' then
			self.err = 'Actor execution is unavailable on this executor.'
			return false, self.err
		end
		data = type(data) == 'table' and data or {}
		local cfg = {
			key = key,
			kind = kind,
			ars = ars == true,
			mode = data.mode == 'Position' and 'Position' or 'Mouse',
			range = tonumber(data.range) or 150,
			chance = tonumber(data.chance) or 100,
			head = tonumber(data.head) or 100,
			part = data.part == 'RootPart' and 'RootPart' or 'Head',
			walls = data.walls == true,
			players = data.players ~= false
		}
		self.live[key] = cfg
		local list = actors()
		local count = 0
		local calls = 0
		local id
		local chan
		local conn
		if type(create_comm_channel) == 'function' then
			local ok, a, b = pcall(create_comm_channel)
			if ok and type(a) == 'number' and b ~= nil then
				id, chan = a, b
				local event = chan.Event
				if event and type(event.Connect) == 'function' then
					conn = event:Connect(function(msg, val)
						if msg == 'ready' then count += tonumber(val) or 0 end
					end)
				end
			end
		end
		for _, actor in ipairs(list) do
			local ok = send(actor, cfg, id)
			if ok then calls += 1 end
		end
		if conn then
			task.wait(0.05)
			pcall(conn.Disconnect, conn)
		end
		if cfg.ars and #list > 0 and conn and count == 0 then
			self.err = 'Arsenal actor hook was not found.'
			return false, self.err
		end
		if calls == 0 and #list > 0 then
			self.err = 'Actor hooks could not be installed.'
			return false, self.err
		end
		if #list == 0 and not on_actor_state_created then
			self.err = 'No actor state is available.'
			return false, self.err
		end
		self.err = nil
		return true, count
	end

	if on_actor_state_created and type(on_actor_state_created.Connect) == 'function' then
		local conn = on_actor_state_created:Connect(function(actor)
			for _, data in pairs(aim.live) do send(actor, data) end
		end)
		ctx:clean(conn)
	end
	ctx:clean(function()
		for key in pairs(aim.live) do aim:stop(key) end
	end)
	ctx.aim = aim
end
]==]
sources['core/clean.lua'] = [==[
return function(ctx)
	local bin = {items = {}, dead = false}

	local function dispose(obj)
		local kind = typeof and typeof(obj) or type(obj)
		if kind == 'RBXScriptConnection' then
			return obj:Disconnect()
		elseif kind == 'Instance' then
			return obj:Destroy()
		elseif type(obj) == 'function' then
			return obj()
		elseif type(obj) == 'table' or type(obj) == 'userdata' then
			for _, name in ipairs({'Disconnect', 'Destroy', 'Clean', 'Remove'}) do
				local ok, method = pcall(function() return obj[name] end)
				if ok and type(method) == 'function' then
					return method(obj)
				end
			end
		end
		return true
	end

	function bin:add(obj)
		if obj == nil then return nil end
		if self.dead then
			local ok, done = pcall(dispose, obj)
			if not ok or done == false then
				ctx.log:add('cleanup', nil, ok and 'cleanup returned false' or done)
				self.items[#self.items + 1] = obj
			end
			return obj
		end
		self.items[#self.items + 1] = obj
		return obj
	end

	function bin:run()
		self.dead = true
		local items = self.items
		self.items = {}
		for i = #items, 1, -1 do
			local ok, done = pcall(dispose, items[i])
			if not ok or done == false then
				ctx.log:add('cleanup', nil, ok and 'cleanup returned false' or done)
				self.items[#self.items + 1] = items[i]
			end
		end
		return #self.items == 0
	end

	function bin:mark()
		return #self.items
	end

	function bin:rollback(mark)
		if self.dead then return false end
		local items = {}
		for i = #self.items, mark + 1, -1 do
			items[#items + 1] = table.remove(self.items, i)
		end
		local complete = true
		for _, obj in ipairs(items) do
			local ok, done = pcall(dispose, obj)
			if not ok or done == false then
				complete = false
				ctx.log:add('cleanup', nil, ok and 'cleanup returned false' or done)
				self.items[#self.items + 1] = obj
			end
		end
		return complete
	end

	ctx.bin = bin
	function ctx:clean(obj)
		return self.bin:add(obj)
	end
end
]==]
sources['core/config.lua'] = [==[
return function(ctx)
	local scopes = {'place'}
	local config = {
		version = 1,
		paths = {},
		data = {modules = {}, patches = {}},
		layers = {},
		memory = {},
		bad = {},
		watchers = {},
		watched = setmetatable({}, {__mode = 'k'}),
		ticket = 0,
		scheduled = false,
		restoring = false
	}

	local function safe(val, seen, depth)
		local kind = type(val)
		if kind == 'nil' or kind == 'boolean' or kind == 'string' then return val end
		if kind == 'number' then
			if val ~= val or val == math.huge or val == -math.huge then return nil end
			return val
		end
		if kind ~= 'table' or depth >= 12 or seen[val] then return nil end
		seen[val] = true
		local out = {}
		for key, item in pairs(val) do
			if type(key) == 'string' or type(key) == 'number' then
				local clean = safe(item, seen, depth + 1)
				if clean ~= nil then out[key] = clean end
			end
		end
		seen[val] = nil
		return out
	end

	local function clean(val)
		return safe(val, {}, 0)
	end

	local function equal(a, b, seen)
		if type(a) ~= type(b) then return false end
		if type(a) ~= 'table' then return a == b end
		seen = seen or {}
		if seen[a] == b then return true end
		seen[a] = b
		for key, val in pairs(a) do if not equal(val, b[key], seen) then return false end end
		for key in pairs(b) do if a[key] == nil then return false end end
		return true
	end

	local function validrecord(item, module)
		if type(item) ~= 'table' then return false end
		if item.enabled ~= nil and type(item.enabled) ~= 'boolean' then return false end
		if item.options ~= nil and type(item.options) ~= 'table' then return false end
		if module and item.category ~= nil and type(item.category) ~= 'string' then return false end
		if module and item.bind ~= nil and type(item.bind) ~= 'table' and type(item.bind) ~= 'string' then
			return false
		end
		if module and item.visible ~= nil and type(item.visible) ~= 'boolean' then return false end
		return true
	end

	local function valid(data)
		if type(data) ~= 'table' or data.version ~= nil and data.version ~= 1 then return false end
		for key, module in pairs({modules = true, patches = false}) do
			local list = data[key]
			if list ~= nil and type(list) ~= 'table' then return false end
			for name, item in pairs(list or {}) do
				if type(name) ~= 'string' or not validrecord(item, module) then return false end
			end
		end
		return true
	end

	local function optiondata(list)
		local out = {}
		for _, entry in ipairs(list) do
			local opt = entry.obj or entry
			if type(opt) == 'table' and type(opt.Save) == 'function' then
				local ok, msg = pcall(opt.Save, opt, out)
				if not ok then
					ctx.log:add('config_serialize', entry.name, msg)
					return nil, false
				end
			end
		end
		return clean(out) or {}, true
	end

	local function moduleoptions(mod)
		local list = {}
		for name, opt in pairs(mod.Options or {}) do list[#list + 1] = {name = name, obj = opt} end
		return optiondata(list)
	end

	local function moduledata(item)
		local options, ok = moduleoptions(item.obj)
		if not ok then return nil, false end
		local visible = type(ctx.vapeapi.getvisible) == 'function' and select(1, ctx.vapeapi:getvisible(item.obj)) or nil
		return {
			category = item.category,
			enabled = item.obj.Enabled == true,
			visible = type(visible) == 'boolean' and visible or nil,
			bind = clean(ctx.vapeapi:savebind(item.obj)),
			options = options
		}, true
	end

	local function patchdata(patch)
		local options, ok = optiondata(patch.options)
		if not ok then return nil, false end
		return {enabled = patch.enabled, options = options}, true
	end

	local function mergeoptions(dst, src)
		dst = type(dst) == 'table' and dst or {}
		for name, val in pairs(src) do dst[name] = clean(val) end
		return dst
	end

	local function mergeitem(dst, src, module)
		dst = type(dst) == 'table' and dst or {}
		if src.enabled ~= nil then dst.enabled = src.enabled end
		if module and src.category ~= nil then dst.category = src.category end
		if module and src.bind ~= nil then dst.bind = clean(src.bind) end
		if module and src.visible ~= nil then dst.visible = src.visible == true end
		if src.options ~= nil then dst.options = mergeoptions(dst.options, src.options) end
		return dst
	end

	local function merge(dst, src)
		for name, item in pairs(src.modules or {}) do
			dst.modules[name] = mergeitem(dst.modules[name], item, true)
		end
		for id, item in pairs(src.patches or {}) do
			dst.patches[id] = mergeitem(dst.patches[id], item, false)
		end
		return dst
	end

	function config:setpaths()
		local base = 'configs/profiles/'..ctx.profile.dir..'/'
		local target = ctx.target
		self.paths = {
			place = base..'place-'..tostring(target.placeid)..'.json'
		}
		self.legacy = {
			place = base..tostring(target.placeid)..'.json'
		}
	end

	local function fieldowner(config, key, name, field, declared)
		for i = #scopes, 1, -1 do
			local scope = scopes[i]
			local layer = config.layers[scope]
			local item = layer and layer[key] and layer[key][name]
			if item and item[field] ~= nil then return scope end
		end
		return 'place'
	end

	local function optionowner(config, key, name, option, declared)
		for i = #scopes, 1, -1 do
			local scope = scopes[i]
			local layer = config.layers[scope]
			local item = layer and layer[key] and layer[key][name]
			local options = item and item.options
			if type(options) == 'table' then
				if options[option] ~= nil then return scope end
			end
		end
		return 'place'
	end

	local function record(data, key, name)
		data[key][name] = data[key][name] or {}
		return data[key][name]
	end

	function config:collect(scope)
		local prior = clean(self.layers[scope]) or {}
		local data = {
			version = self.version,
			profile = ctx.profile.name,
			target = clean(ctx.target),
			modules = type(prior.modules) == 'table' and prior.modules or {},
			patches = type(prior.patches) == 'table' and prior.patches or {}
		}
		for name, item in pairs(ctx.mods) do
			local current, ok = moduledata(item)
			if not ok then return nil, false end
			for _, field in ipairs({'category', 'enabled', 'visible', 'bind'}) do
				if current[field] ~= nil and fieldowner(self, 'modules', name, field, item.scope) == scope then
					record(data, 'modules', name)[field] = clean(current[field])
				end
			end
			for option, val in pairs(current.options) do
				if optionowner(self, 'modules', name, option, item.scope) == scope then
					local saved = record(data, 'modules', name)
					saved.options = type(saved.options) == 'table' and saved.options or {}
					saved.options[option] = clean(val)
				end
			end
		end
		for _, patch in ipairs(ctx.patchsys.order) do
			local current, ok = patchdata(patch)
			if not ok then return nil, false end
			if fieldowner(self, 'patches', patch.id, 'enabled', patch.scope) == scope then
				record(data, 'patches', patch.id).enabled = current.enabled
			end
			for option, val in pairs(current.options) do
				if optionowner(self, 'patches', patch.id, option, patch.scope) == scope then
					local saved = record(data, 'patches', patch.id)
					saved.options = type(saved.options) == 'table' and saved.options or {}
					saved.options[option] = clean(val)
				end
			end
		end
		return data, true
	end

	local function rawvalid(path)
		local raw = ctx.store:read(path)
		if not raw then return nil, nil end
		local data = ctx.store:decode(raw, path)
		if valid(data) then return data, raw end
		return nil, raw
	end

	local function backpath(path)
		return type(ctx.store.backup) == 'function' and ctx.store:backup(path) or path..'.bak'
	end

	local function temppath(path)
		return type(ctx.store.temp) == 'function' and ctx.store:temp(path) or path..'.tmp'
	end

	function config:read(path)
		local data, raw = rawvalid(path)
		if data then
			self.bad[path] = nil
			return data
		end
		if raw then self.bad[path] = true end
		local backup = rawvalid(backpath(path))
		if backup then return backup end
		local legacy = rawvalid(path..'.bak')
		if legacy then return legacy end
	end

	function config:atomic(path, data)
		local raw = ctx.store:encode(data, path)
		if not raw then return false end
		local olddata, oldraw = rawvalid(path)
		if olddata and equal(olddata, data) or oldraw == raw then
			self.bad[path] = nil
			return true
		end
		local backupfile = backpath(path)
		local backup, backupraw = rawvalid(backupfile)
		if not backup then backup, backupraw = rawvalid(path..'.bak') end
		if oldraw and not olddata and not backup then
			self.bad[path] = true
			ctx.log:add('config_write', path, 'malformed config preserved')
			return false
		end

		local tmp = temppath(path)
		if not ctx.store:write(tmp, raw) then return false end
		local function discard()
			ctx.store:remove(tmp)
			return false
		end
		local candidate = rawvalid(tmp)
		if not candidate then return discard() end
		if olddata then
			if not ctx.store:write(backupfile, oldraw) then return discard() end
			local checked = rawvalid(backupfile)
			if not checked then return discard() end
			backup, backupraw = olddata, oldraw
		end
		if not ctx.store:write(path, raw) then return discard() end
		local final = rawvalid(path)
		if not final then
			if backup and backupraw then ctx.store:write(path, backupraw) end
			return discard()
		end
		ctx.store:remove(tmp)
		self.bad[path] = nil
		return true
	end

	function config:save(force)
		if self.restoring then return true, false end
		self.ticket = self.ticket + 1
		local all = true
		local wrote = false
		for _, scope in ipairs(scopes) do
			local data, ok = self:collect(scope)
			if not ok then
				all = false
			else
				local useful = next(data.modules) ~= nil or next(data.patches) ~= nil
					or self.layers[scope] ~= nil or ctx.store:read(self.paths[scope]) ~= nil
				if useful then
					self.layers[scope] = data
					if ctx.store.fs.write then
						local saved = self:atomic(self.paths[scope], data)
						all = saved and all
						wrote = saved or wrote
					end
				end
			end
		end
		self.memory[ctx.profile.dir] = clean(self.layers) or {}
		if force and not self:index() then all = false end
		return all, wrote
	end

	function config:schedule()
		if self.restoring or ctx.state ~= 'loaded' then return end
		self.ticket = self.ticket + 1
		if self.scheduled then return end
		self.scheduled = true
		task.spawn(function()
			local ticket
			repeat
				ticket = self.ticket
				task.wait(ctx.cfg.debounce)
			until ticket == self.ticket or ctx.state ~= 'loaded'
			self.scheduled = false
			if ctx.state == 'loaded' then self:save(false) end
		end)
	end

	function config:load()
		self.layers = {}
		local memory = self.memory[ctx.profile.dir]
		for _, scope in ipairs(scopes) do
			local data = memory and clean(memory[scope]) or self:read(self.paths[scope])
			if not data and self.legacy[scope] then
				data = self:read(self.legacy[scope])
				if data and ctx.store.fs.write then self:atomic(self.paths[scope], data) end
			end
			if data then self.layers[scope] = data end
		end
		self.data = clean(self.baseline) or {modules = {}, patches = {}}
		self.data.modules = self.data.modules or {}
		self.data.patches = self.data.patches or {}
		for _, scope in ipairs(scopes) do
			if self.layers[scope] then merge(self.data, self.layers[scope]) end
		end
		return self.data
	end

	local function loadoptions(mod, saved, allowed)
		if type(saved) ~= 'table' or type(mod.Options) ~= 'table' then return true end
		local complete = true
		for name, val in pairs(saved) do
			local opt = mod.Options[name]
			if opt and type(opt.Load) == 'function' and (not allowed or allowed[opt]) then
				local ok, result = pcall(opt.Load, opt, clean(val))
				if not ok or result == false then
					complete = false
					ctx.log:add('config_restore', name, ok and 'option load returned false' or result)
				end
			end
		end
		return complete
	end

	function config:restore()
		local previous = self.restoring
		self.restoring = true
		local complete = true
		local function fail(name, msg)
			complete = false
			ctx.log:add('config_restore', name, msg)
		end
		local ok, msg = xpcall(function()
			for _, item in ipairs(ctx.modorder) do
				if item.obj.Enabled and type(item.obj.Toggle) == 'function' then
					local toggled, err = pcall(item.obj.Toggle, item.obj, true)
					if not toggled or item.obj.Enabled then fail(item.name, toggled and 'module stayed enabled' or err) end
				end
			end
			for _, patch in ipairs(ctx.patchsys.order) do
				if patch.enabled and not patch:setenabled(false, true) then fail(patch.id, 'patch could not be disabled') end
			end
			for name, saved in pairs(self.data.modules or {}) do
				local item = ctx.mods[name]
				if item and not loadoptions(item.obj, saved.options) then complete = false end
			end
			for _, patch in ipairs(ctx.patchsys.order) do
				local saved = self.data.patches and self.data.patches[patch.id]
				if saved then
					local allowed = {}
					for _, entry in ipairs(patch.options) do allowed[entry.obj] = true end
					if not loadoptions(patch.mod, saved.options, allowed) then complete = false end
				end
			end
			for name, saved in pairs(self.data.modules or {}) do
				local item = ctx.mods[name]
				if item and type(saved.visible) == 'boolean' and type(ctx.vapeapi.setvisible) == 'function' then
					local shown, result = pcall(ctx.vapeapi.setvisible, ctx.vapeapi, item.obj, saved.visible)
					if not shown or result == false then fail(name, shown and 'visibility restore returned false' or result) end
				end
				if item and saved.bind ~= nil then
					local bound, result = pcall(ctx.vapeapi.setbind, ctx.vapeapi, item.obj, clean(saved.bind))
					if not bound or result == false then fail(name, bound and 'bind restore returned false' or result) end
				end
			end
			for _, patch in ipairs(ctx.patchsys.order) do
				local saved = self.data.patches and self.data.patches[patch.id]
				local enabled = saved and saved.enabled == true
				if patch.enabled ~= enabled and not patch:setenabled(enabled, true) then
					fail(patch.id, 'patch state could not be restored')
				end
			end
			for name, saved in pairs(self.data.modules or {}) do
				local item = ctx.mods[name]
				if item and type(saved.enabled) == 'boolean' then
					local enabled = saved.enabled == true and item.autostart ~= false
					if item.obj.Enabled ~= enabled and type(item.obj.Toggle) == 'function' then
						local toggled, err = pcall(item.obj.Toggle, item.obj, true)
						if not toggled or item.obj.Enabled ~= enabled then
							fail(name, toggled and 'module state did not change' or err)
						end
					end
				end
			end
		end, function(err) return tostring(err) end)
		self.restoring = previous
		if not ok then fail(nil, msg) end
		return ok and complete
	end

	local function watchmethod(obj, key, after)
		if type(obj) ~= 'table' or type(obj[key]) ~= 'function' then return end
		config.watched[obj] = config.watched[obj] or {}
		local item = config.watched[obj][key]
		if item then return config:rewatch(obj, key) end
		item = {obj = obj, key = key, old = obj[key]}
		item.wrap = function(self, ...)
			local out = table.pack(item.old(self, ...))
			if after then after(out[1]) end
			config:schedule()
			return table.unpack(out, 1, out.n)
		end
		config.watched[obj][key] = item
		obj[key] = item.wrap
		config.watchers[#config.watchers + 1] = item
	end

	function config:unwrapped(obj, key, val)
		local item = self.watched[obj] and self.watched[obj][key]
		if item and val == item.wrap then return item.old end
		return val
	end

	function config:rewatch(obj, key)
		local item = self.watched[obj] and self.watched[obj][key]
		if not item then return false end
		if obj[key] ~= item.wrap then
			item.old = obj[key]
			obj[key] = item.wrap
		end
		return true
	end

	function config:watchoption(opt)
		if type(opt) ~= 'table' then return end
		for _, key in ipairs({'Toggle', 'SetValue', 'SetBind', 'ChangeValue', 'Change'}) do
			watchmethod(opt, key)
		end
		for _, key in ipairs({'Players', 'NPCs', 'Invisible', 'Walls'}) do
			if type(opt[key]) == 'table' then watchmethod(opt[key], 'Toggle') end
		end
	end

	function config:watchmodule(item)
		watchmethod(item.obj, 'Toggle')
		watchmethod(item.obj, 'SetBind')
		watchmethod(item.obj, 'SetVisible')
		if type(item.obj.Bind) == 'table' then
			local bind = item.obj.Bind
			watchmethod(bind, 'SetBind')
			watchmethod(bind, 'CreateMobileButton')
			watchmethod(bind, 'DestroyMobileButton')
			if typeof and typeof(bind.Object) == 'Instance' and bind.Object.MouseButton1Click then
				ctx:clean(bind.Object.MouseButton1Click:Connect(function()
					task.defer(function() config:schedule() end)
				end))
			end
		end
		for _, opt in pairs(item.obj.Options or {}) do self:watchoption(opt) end
		for _, method in pairs({
			'CreateToggle', 'CreateSlider', 'CreateTwoSlider', 'CreateDropdown', 'CreateMultiDropdown',
			'CreateTextBox', 'CreateTextList', 'CreateBind', 'CreateColorSlider', 'CreateFont', 'CreateTargets'
		}) do
			watchmethod(item.obj, method, function(opt)
				self:watchoption(opt)
				for _, option in pairs(item.obj.Options or {}) do self:watchoption(option) end
			end)
		end
	end

	function config:watch()
		for _, item in ipairs(ctx.modorder) do self:watchmodule(item) end
		for _, entry in ipairs(ctx.patchopts) do self:watchoption(entry.obj) end
	end

	function config:unwatch()
		for i = #self.watchers, 1, -1 do
			local item = self.watchers[i]
			if item.obj[item.key] == item.wrap then item.obj[item.key] = item.old end
			self.watchers[i] = nil
		end
		table.clear(self.watched)
	end

	function config:forgetobj(obj)
		for i = #self.watchers, 1, -1 do
			local item = self.watchers[i]
			if item.obj == obj then
				if item.obj[item.key] == item.wrap then item.obj[item.key] = item.old end
				table.remove(self.watchers, i)
			end
		end
		self.watched[obj] = nil
	end

	function config:forgetmodule(mod)
		self:forgetobj(mod)
		for _, opt in pairs(mod.Options or {}) do self:forgetobj(opt) end
	end

	local function nativeentry(entry)
		if not entry.persist then return nil, true end
		local val, ok = ctx.vapeapi:snapshotoption(entry.obj)
		if not ok then
			ctx.log:add('config_serialize', entry.name, val)
			return nil, false
		end
		return clean(val), true
	end

	function config:capture()
		local baseline = {version = self.version, modules = {}, patches = {}}
		local complete = true
		for name, item in pairs(ctx.mods) do
			local data, ok = moduledata(item)
			if not ok then return false end
			baseline.modules[name] = data
		end
		for _, patch in ipairs(ctx.patchsys.order) do
			local data, ok = patchdata(patch)
			if not ok then return false end
			baseline.patches[patch.id] = data
		end
		for _, entry in ipairs(ctx.patchopts) do
			if not entry.created and entry.persist and not entry.nativeknown then
				local data, ok = nativeentry(entry)
				if ok then
					entry.native = data
					entry.nativeknown = true
				else
					entry.native = nil
					entry.nativeknown = false
					complete = false
				end
			end
		end
		self.baseline = baseline
		return complete
	end

	function config:nativeloaded()
		local complete = true
		for _, entry in ipairs(ctx.patchopts) do
			if not entry.created and entry.persist then
				local data, ok = nativeentry(entry)
				if ok then
					entry.native = data
					entry.nativeknown = true
					if not ctx.patchsys:valuepatched(entry.obj) then
						for patch in pairs(entry.owners) do
							local saved = self.baseline and self.baseline.patches[patch.id]
							if saved then
								saved.options = saved.options or {}
								saved.options[entry.name] = clean(data)
							end
						end
					end
				else
					entry.native = nil
					entry.nativeknown = false
					complete = false
				end
			end
		end
		return complete
	end

	local function nativevalues()
		local live = {}
		local complete = true
		for _, entry in ipairs(ctx.patchopts) do
			if not entry.created and entry.persist then
				local data, ok = nativeentry(entry)
				if ok then live[#live + 1] = {entry = entry, data = data} else complete = false end
			end
		end
		return live, complete
	end

	local function loadnative(live)
		for _, item in ipairs(live) do
			local entry = item.entry
			if not entry.nativeknown then return false end
			if entry.native ~= nil and not ctx.vapeapi:loadoption(entry.obj, entry.native) then return false end
		end
		return true
	end

	local function restorelive(live)
		local complete = true
		for _, item in ipairs(live) do
			if item.data ~= nil and not ctx.vapeapi:loadoption(item.entry.obj, item.data) then complete = false end
		end
		return complete
	end

	function config:nativesave(fn, ...)
		local previous = self.restoring
		self.restoring = true
		local live, ready = nativevalues()
		local suspended = false
		local touched = false
		if ready and ctx.patchsys then
			suspended = true
			ready = ctx.patchsys:suspend()
		end
		if ready then touched = true ready = loadnative(live) end
		local out = ready and table.pack(pcall(fn, ...)) or table.pack(false, 'native save isolation failed')
		local restored = not touched or restorelive(live)
		if suspended and not ctx.patchsys:resume(false) then restored = false end
		self.restoring = previous
		if not ready or not restored then ctx.log:add('profile', nil, 'native save isolation was incomplete') end
		if not out[1] then error(out[2], 0) end
		if not restored then error('native save state could not be restored', 0) end
		return table.unpack(out, 2, out.n)
	end

	function config:nativeload(fn, ...)
		local previous = self.restoring
		self.restoring = true
		local live, ready = nativevalues()
		local suspended = false
		local touched = false
		if ready and ctx.patchsys then
			suspended = true
			ready = ctx.patchsys:suspend()
		end
		if ready then touched = true ready = loadnative(live) end
		local out = ready and table.pack(pcall(fn, ...)) or table.pack(false, 'native load isolation failed')
		local captured = out[1] and self:nativeloaded()
		local restored = true
		if out[1] then
			if suspended and not ctx.patchsys:resume(true) then restored = false end
		else
			restored = not touched or restorelive(live)
			if suspended and not ctx.patchsys:resume(false) then restored = false end
		end
		self.restoring = previous
		if not ready or not captured or not restored then ctx.log:add('profile', nil, 'native load isolation was incomplete') end
		if not out[1] then error(out[2], 0) end
		if not captured then error('native option state could not be captured', 0) end
		if not restored then error('native load state could not be restored', 0) end
		return table.unpack(out, 2, out.n)
	end

	function config:index()
		if not ctx.store.fs.write then return true end
		return self:atomic('configs/index.json', {
			version = self.version,
			profile = ctx.profile.name,
			directory = ctx.profile.dir,
			target = clean(ctx.target),
			updated = os.time and os.time() or 0
		})
	end

	function config:check()
		local cyclic = {}
		cyclic.self = cyclic
		local cleaned = clean({value = 1, bad = function() end, cycle = cyclic})
		return type(cleaned) == 'table' and cleaned.value == 1 and cleaned.bad == nil
	end

	config:setpaths()
	ctx.config = config
end
]==]
sources['core/frontlines-magic.lua'] = [==[
return function(ctx)
	local frontlines = ctx.frontlines
	local mod, targets, mode, method, range, chance, part, wall, circle, color, alpha, fill
	local draw, original, shootFunction, silent, resume, reported
	local rng = Random.new()
	local input = game:GetService('UserInputService')
	local run = game:GetService('RunService')
	local info = ctx.vape.Libraries.targetinfo
	local function finite(v)
		return typeof(v) == 'Vector3' and v.X == v.X and v.Y == v.Y and v.Z == v.Z
			and math.abs(v.X) < 1e8 and math.abs(v.Y) < 1e8 and math.abs(v.Z) < 1e8
	end
	local function mouse()
		local cam = workspace.CurrentCamera
		return input.TouchEnabled and cam and cam.ViewportSize / 2 or input:GetMouseLocation()
	end
	local function paint()
		if not draw then return end
		draw.Visible = mod.Enabled and circle.Enabled and mode.Value == 'Mouse'
		draw.Position = mouse()
		draw.Radius = range.Value
		draw.Filled = fill and fill.Enabled == true
		draw.Color = Color3.fromHSV(color and color.Hue or 0, color and color.Sat or 0, color and color.Value or 1)
		draw.Transparency = 1 - (alpha and alpha.Value or 0.5)
	end
	local function erase()
		if draw then pcall(function() draw.Visible = false draw:Remove() end) draw = nil end
	end
	local function physicalPart(ent, target)
		local hash = frontlines.Main.globals.soldier_hitbox_hash
		local nearest, distance = nil, math.huge
		for obj, id in pairs(hash or {}) do
			if typeof(obj) == 'Instance' and obj:IsA('BasePart') and obj.Parent then
				local weld = obj:FindFirstChild('Weld')
				if id == ent.Id or weld and weld.Part0 == ent.RootPart then
					local delta = (obj.Position - target).Magnitude
					if delta < distance then nearest, distance = obj, delta end
				end
			end
		end
		return nearest or ent.RootPart
	end
	local function adjust(pos, dir)
		if not finite(pos) or not finite(dir) or dir.Magnitude <= 0.001 then return pos, dir end
		if rng:NextNumber(0, 100) >= chance.Value then return pos, dir end
		local selected = part.Value
		if selected == 'RootPart' then selected = 'Body' end
		if selected == 'Random' then selected = ({'Head', 'Body', 'Torso'})[rng:NextInteger(1, 3)] end
		local ent, target = frontlines.SelectAimTarget(pos, selected, {
			Mode = mode.Value, Range = range.Value,
			Walls = targets.Walls.Enabled and not wall.Enabled,
			Players = targets.Players.Enabled, NPCs = targets.NPCs.Enabled
		})
		if not ent or not finite(target) then return pos, dir end
		local hit = physicalPart(ent, target)
		local moved
		if method.Value == 'Origin Scan' then
			moved = ctx.origin:scan(pos, target, nil, hit)
			-- The scan can return an offset endpoint. Validate the actual aim bone.
			if moved and ctx.vape.Libraries.entity.Wallcheck(moved, target) then moved = nil end
		else
			moved = ctx.origin:line(target, dir, hit)
		end
		if not finite(moved) then return pos, dir end
		local delta = target - moved
		if delta.Magnitude <= 0.001 then return pos, dir end
		if info and info.Targets then info.Targets[ent] = tick() + 1 end
		return moved, delta.Unit * dir.Magnitude
	end
	local function stop()
		if original and shootFunction and frontlines.Functions and frontlines.Functions[shootFunction] == original then
			hookfunction(shootFunction, original)
			frontlines.Functions[shootFunction] = nil
		end
		original, shootFunction = nil, nil
		local shouldResume = resume
		resume = false
		if shouldResume and ctx.state ~= 'unloading' and ctx.state ~= 'unloaded' and ctx.vape.Loaded ~= nil
			and silent and not silent.Enabled then silent:Toggle() end
	end
	local function start()
		silent = ctx:find('SilentAim', 'combat')
		resume = silent and silent.Enabled == true
		if resume then silent:Toggle() end
		shootFunction = frontlines.ShootFunction
		local base
		base = hookfunction(shootFunction, function(shootid, fire, pos, dir, ...)
			local main = frontlines.Main
			local globals = main and main.globals
			local state = globals and globals.cli_state
			local modulus = globals and globals.cli_id_alloc and globals.cli_id_alloc.m
			if mod.Enabled and state and type(shootid) == 'number' and modulus and modulus ~= 0
				and state.state == main.cli_state_t.COMBAT and shootid % modulus == state.id then
				local ok, newpos, newdir = pcall(adjust, pos, dir)
				if ok then pos, dir = newpos, newdir
				elseif not reported then
					reported = true
					ctx.log:add('module', 'MagicBullet', newpos)
					task.defer(ctx.vape.CreateNotification, ctx.vape, 'MagicBullet', tostring(newpos), 6, 'alert')
				end
			end
			return base(shootid, fire, pos, dir, ...)
		end)
		original = base
		frontlines.Functions[shootFunction] = base
		-- If SilentAim is enabled manually, stop MagicBullet synchronously first.
		-- This avoids competing owners of spawn_bullet during rapid toggles.
		if silent then
			local oldToggle = silent.Toggle
			local wrapper
			wrapper = function(obj, ...)
				if not obj.Enabled and mod.Enabled then resume = false mod:Toggle() end
				return oldToggle(obj, ...)
			end
			silent.Toggle = wrapper
			mod:Clean(function() if silent.Toggle == wrapper then silent.Toggle = oldToggle end end)
		end
		mod:Clean(stop)
	end
	mod = ctx:module('combat', {
		name = 'MagicBullet', autostart = false,
		tooltip = 'Moves local Frontlines bullet origins using the native spawn_bullet hook.',
		extratext = function() return method and method.Value or 'Near Target' end,
		func = function(enabled)
			if enabled then
				reported = false
				local ok, err = pcall(start)
				if not ok then
					stop()
					ctx.log:add('module', 'MagicBullet', err)
					ctx.vape:CreateNotification('MagicBullet', tostring(err), 6, 'alert')
					task.defer(function() if mod.Enabled then mod:Toggle() end end)
				end
			else stop() end
			paint()
		end
	})
	targets = mod:CreateTargets({Players = true})
	mode = mod:CreateDropdown({Name = 'Target Mode', List = {'Mouse', 'Position'}, Default = 'Mouse', Function = paint})
	method = mod:CreateDropdown({Name = 'Method', List = {'Near Target', 'Origin Scan'}, Default = 'Near Target'})
	wall = mod:CreateToggle({Name = 'Wallbang'})
	range = mod:CreateSlider({Name = 'Range', Min = 1, Max = 1000, Default = 150,
		Suffix = function(v) return mode and mode.Value == 'Mouse' and 'px' or v == 1 and 'stud' or 'studs' end, Function = paint})
	chance = mod:CreateSlider({Name = 'Hit Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
	part = mod:CreateDropdown({Name = 'Part', List = {'Head', 'Body', 'Torso', 'Random'}, Default = 'Head'})
	circle = mod:CreateToggle({Name = 'Range Circle', Function = function(enabled)
		erase()
		if enabled then draw = Drawing.new('Circle') draw.NumSides = 100 draw.Thickness = 1 end
		paint()
		for _, obj in ipairs({color, alpha, fill}) do if obj then ctx.vapeapi:setvisible(obj, enabled) end end
	end})
	color = mod:CreateColorSlider({Name = 'Circle Color', Darker = true, Visible = false, Function = paint})
	alpha = mod:CreateSlider({Name = 'Transparency', Min = 0, Max = 1, Default = 0.5, Decimal = 10, Darker = true, Visible = false, Function = paint})
	fill = mod:CreateToggle({Name = 'Circle Filled', Darker = true, Visible = false, Function = paint})
	ctx:clean(run.RenderStepped:Connect(paint))
	ctx:clean(erase)
	ctx:clean(stop)
end
]==]
sources['core/layers.lua'] = [==[
return function(ctx)
	local http = game:GetService('HttpService')
	local seen = {}
	local tree
	local disabledgames = {
		['8444591321'] = 'BedWars layer intentionally disabled',
		['8560631822'] = 'BedWars layer intentionally disabled'
	}

	local function clean(path)
		return tostring(path or '')
			:gsub('\\', '/')
			:gsub('/+', '/')
			:gsub('^/+', '')
			:gsub('/+$', '')
			:lower()
	end

	local function fail(kind, path, msg, fatal)
		ctx.log:add(kind, path, msg, fatal)
		if fatal then error(msg, 0) end
	end

	local function trace(msg)
		if ctx.cfg.debug and debug and type(debug.traceback) == 'function' then
			return debug.traceback(tostring(msg), 2)
		end
		return tostring(msg)
	end

	local function run(path, data)
		path = clean(path)
		if seen[path] then return false end
		seen[path] = true
		local mark = ctx:_mark()
		local old = ctx.loading
		ctx.loading = {
			layer = data.layer,
			scope = data.scope,
			category = data.category,
			kind = data.kind,
			path = path,
			required = data.required == true
		}
		local ok, msg = xpcall(function()
			local init = ctx.loader:run(path)
			if type(init) ~= 'function' then error(path..' must return a function', 0) end
			init(ctx)
		end, trace)
		ctx.loading = old
		if ok then return true end
		if not ctx:_rollback(mark) then error('incomplete rollback for '..path, 0) end
		fail(data.kind, path, msg, ctx.cfg.strict or data.required == true)
		return false
	end

	local function cats(data, path)
		if data.categories == nil then return table.clone(ctx.cats.order) end
		if type(data.categories) ~= 'table' then error(path..' categories must be a table', 0) end
		local out = {}
		local seen2 = {}
		for key, val in pairs(data.categories) do
			local cat = type(key) == 'number' and val or val and key or nil
			if cat then
				cat = tostring(cat):lower()
				if not ctx.cats.names[cat] then error(path..' has unsupported category '..cat, 0) end
				if not seen2[cat] then
					seen2[cat] = true
					out[#out + 1] = cat
				end
			end
		end
		table.sort(out, function(a, b)
			return table.find(ctx.cats.order, a) < table.find(ctx.cats.order, b)
		end)
		return out
	end

	local function catload(root, cat, kind, layer, scope)
		local path = root..'/'..cat..'/manifest.lua'
		local ok, data, state = ctx.loader:try(path)
		if not ok then
			if state ~= 'missing' then fail(kind, path, data, ctx.cfg.strict) end
			return 0
		end
		if type(data) ~= 'table' then
			fail(kind, path, path..' must return a table', ctx.cfg.strict)
			return 0
		end
		local count = 0
		for _, item in ipairs(data.files or data[kind] or data) do
			local file = type(item) == 'string' and item or type(item) == 'table' and (item.path or item.file)
			if file and (type(item) ~= 'table' or item.enabled ~= false) then
				if run(root..'/'..cat..'/'..file, {
					layer = layer,
					scope = scope,
					category = cat,
					kind = kind,
					required = type(item) == 'table' and item.required == true
				}) then count += 1 end
			end
		end
		return count
	end

	local function rootload(root, kind, layer, scope, required)
		local path = root..'/manifest.lua'
		local ok, data, state = ctx.loader:try(path)
		if not ok then
			if required or state ~= 'missing' then fail('layer', path, data or 'missing manifest', required or ctx.cfg.strict) end
			return 0
		end
		if type(data) ~= 'table' then
			fail('layer', path, path..' must return a table', required or ctx.cfg.strict)
			return 0
		end
		local count = 0
		if data.init and run(root..'/'..data.init, {
			layer = layer,
			scope = scope,
			kind = kind,
			required = true
		}) then count += 1 end
		for _, cat in ipairs(cats(data, path)) do
			count += catload(root, cat, kind, layer, scope)
		end
		ctx.layers[#ctx.layers + 1] = {
			name = layer,
			kind = kind,
			root = root,
			files = count
		}
		return count
	end

	local function repo()
		local base = tostring(ctx.loader.base or ctx.loader.requestbase or '')
		return base:match('^https://raw%.githubusercontent%.com/([^/]+)/([^/]+)/([^/]+)')
	end

	local function scan()
		if tree ~= nil then return tree end
		tree = false
		local owner, name, ref = repo()
		if not owner or not name or not ref then return false end
		local url = 'https://api.github.com/repos/'..owner..'/'..name..'/git/trees/'..ref..'?recursive=1&vt='..tostring(os.clock())
		local ok, raw = pcall(game.HttpGet, game, url, true)
		if not ok or type(raw) ~= 'string' then return false end
		local ok2, data = pcall(http.JSONDecode, http, raw)
		if not ok2 or type(data) ~= 'table' or type(data.tree) ~= 'table' then return false end
		local out = {}
		for _, item in ipairs(data.tree) do
			if item.type == 'blob' and type(item.path) == 'string' then
				local path = clean(item.path)
				if path:sub(-4) == '.lua' then out[#out + 1] = path end
			end
		end
		table.sort(out)
		tree = out
		return out
	end

	local function gameload()
		if ctx.loader.games == false then
			ctx.supportedgame = false
			ctx.gamefolder = nil
			return 0
		end
		local list = scan()
		local id = tostring(ctx.target.placeid or game.PlaceId)
		local root = 'src/games/'..id
		if disabledgames[id] then
			ctx.log:add('game', root, disabledgames[id])
			ctx.supportedgame = false
			ctx.gamefolder = nil
			return 0
		end
		local prefix = root..'/'
		local files = {}
		if type(list) == 'table' then
			for _, path in ipairs(list) do
				if path:sub(1, #prefix) == prefix then
					local rel = path:sub(#prefix + 1)
					if not rel:find('/', 1, true) and rel ~= 'native.lua' then files[#files + 1] = path end
				end
			end
		end

		-- The GitHub tree API is rate-limited in some executors. Probe the
		-- conventional entrypoints so supported layers still load without it.
		if #files == 0 then
			local candidates = {
				root..'/init.lua',
				'src/games/'..id..'.lua'
			}
			local gameid = tostring(ctx.target.gameid or '')
			if gameid ~= '' and gameid ~= id then
				candidates[#candidates + 1] = 'src/games/'..gameid..'/init.lua'
				candidates[#candidates + 1] = 'src/games/'..gameid..'.lua'
			end
			for _, path in ipairs(candidates) do
				local ok, value = ctx.loader:try(path)
				if ok and type(value) == 'function' then files[#files + 1] = path end
			end
		end
		table.sort(files)
		local count = 0
		local native = ctx.target.native == true and #files > 0
		if native then
			ctx.log:add('game', root, 'using the game layer already loaded by Vape')
		else
			for _, path in ipairs(files) do
				if run(path, {
					layer = 'place:'..id,
					scope = 'place',
					kind = 'game'
				}) then count += 1 end
			end
		end
		local supported = native or count > 0
		ctx.supportedgame = supported
		ctx.gamefolder = supported and root or nil
		if supported then
			ctx.layers[#ctx.layers + 1] = {
				name = 'place:'..id,
				kind = 'game',
				root = root,
				files = count,
				native = native
			}
		end
		return native and 1 or count
	end

	function ctx:loadlayers()
		rootload('src/modules', 'modules', 'universal:modules', 'universal', true)
		rootload('src/patches', 'patches', 'universal:patches', 'universal', true)
		gameload()
	end
end
]==]
sources['core/log.lua'] = [==[
return function(ctx)
	local log = {history = {}, limit = 200}

	local function trim(msg)
		msg = tostring(msg or '')
		if #msg > 1200 and not ctx.cfg.debug then return msg:sub(1, 1200) end
		return msg
	end

	function log:add(kind, path, msg, fatal)
		local item = {
			time = os.clock(),
			kind = tostring(kind or 'runtime'),
			path = path and tostring(path) or nil,
			message = trim(msg),
			fatal = fatal == true
		}
		self.history[#self.history + 1] = item
		if #self.history > self.limit then table.remove(self.history, 1) end
		return item
	end

	function log:list(kind)
		if not kind then return table.clone(self.history) end
		local out = {}
		for _, item in ipairs(self.history) do
			if item.kind == kind then out[#out + 1] = item end
		end
		return out
	end

	ctx.log = log
end
]==]
sources['core/network.lua'] = [==[
return function(ctx)
	local network = {}
	function network:claim(name, stop)
		local previous = self.owner
		if previous and previous.name ~= name then
			self.owner = nil
			previous.stop()
			local mod = ctx:find(previous.name)
			if mod and mod.Enabled then mod:Toggle() end
		end
		self.owner = {name = name, stop = stop}
	end
	function network:release(name)
		if self.owner and self.owner.name == name then self.owner = nil end
	end
	ctx.network = network
end
]==]
sources['core/origin.lua'] = [==[
return function(ctx)
	local api = {}
	local ray = RaycastParams.new()
	local over = OverlapParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	over.FilterType = Enum.RaycastFilterType.Exclude
	pcall(function() ray.RespectCanCollide = true end)
	pcall(function() over.RespectCanCollide = true end)
	local pos = {
		Vector3.new(0, 1, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, -0.5, -0.5),
		Vector3.new(-0.1, -0.8, -0.8),
		Vector3.new(-0.8, -0.5, -0.5),
		Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0.4, 0.4),
		Vector3.new(0, 0.7, 0.7),
		Vector3.new(0.7, 0.5, 0.5),
		Vector3.new(0.7, 0, -0.8),
		Vector3.new(-0.1, 0, -1),
		Vector3.new(-0.8, 0, -0.8),
		Vector3.new(-0.8, 0, 0.7),
		Vector3.new(0, 0, 1),
		Vector3.new(0.7, 0, 0.7),
		Vector3.new(0.7, 0.4, -0.5),
		Vector3.new(-0.1, 0.7, -0.8),
		Vector3.new(-0.8, 0.4, -0.5),
		Vector3.new(-1, -0.1, 0),
		Vector3.new(-0.8, -0.5, 0.4),
		Vector3.new(0, -0.8, 0.7),
		Vector3.new(0.7, -0.6, 0.5),
		Vector3.new(0, -1, 0)
	}

	local function list(extra)
		local out = {}
		local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
		local plr = game:GetService('Players').LocalPlayer
		if plr and plr.Character then out[#out + 1] = plr.Character end
		local cam = workspace.CurrentCamera
		if cam then out[#out + 1] = cam end
		if type(lib) == 'table' and type(lib.List) == 'table' then
			for _, ent in lib.List do
				if ent.Character then out[#out + 1] = ent.Character end
			end
		end
		if typeof(extra) == 'Instance' then out[#out + 1] = extra end
		return out
	end

	local function free(point)
		local ok, out = pcall(workspace.GetPartBoundsInRadius, workspace, point, 0.05, over)
		if not ok or type(out) ~= 'table' then return true end
		for _, part in out do
			if part.CanCollide then
				local localPoint = part.CFrame:PointToObjectSpace(point)
				local half = part.Size * 0.5
				if math.abs(localPoint.X) < half.X + 0.001
					and math.abs(localPoint.Y) < half.Y + 0.001
					and math.abs(localPoint.Z) < half.Z + 0.001 then return false end
			end
		end
		return true
	end

	local function prep(extra)
		local out = list(extra)
		ray.FilterDescendantsInstances = out
		over.FilterDescendantsInstances = out
	end

	function api:scan(origin, target, extra, part)
		if typeof(origin) ~= 'Vector3' or typeof(target) ~= 'Vector3' then return end
		prep(part)
		local dist = (origin - target).Magnitude
		local size = math.clamp(dist * 0.02, 4, 14)
		local scan = {origin}
		local hits = {}
		if typeof(extra) == 'Vector3' and (origin - extra).Magnitude < size and free(extra) then return extra end
		if free(target) then hits[#hits + 1] = target end
		local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
		local dir = flat.Magnitude > 0.001 and flat.Unit or Vector3.zAxis
		for _, side in Enum.NormalId:GetEnumItems() do
			local off = Vector3.fromNormalId(side)
			local flat2 = Vector3.new(off.X, 0, off.Z)
			if flat2:Dot(-dir) > -0.5 then
				local point = target + off * size
				if free(point) then hits[#hits + 1] = point end
			end
		end
		for _, off in pos do
			local flat2 = Vector3.new(off.X, 0, off.Z)
			if flat2:Dot(dir) > -0.5 then
				local point = origin + off * size
				if free(point) then scan[#scan + 1] = point end
			end
		end
		for _, hit in hits do
			for _, point in scan do
				local ok, out = pcall(workspace.Raycast, workspace, hit, point - hit, ray)
				if ok and not out then return point, hit end
			end
		end
	end

	function api:line(target, dir, part)
		if typeof(target) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or dir.Magnitude <= 0.0001 then return end
		prep(part)
		local unit = dir.Unit
		local base = 0.05
		if typeof(part) == 'Instance' and part:IsA('BasePart') then
			local vec = part.CFrame:VectorToObjectSpace(unit)
			local half = part.Size * 0.5
			base += math.abs(vec.X) * half.X + math.abs(vec.Y) * half.Y + math.abs(vec.Z) * half.Z
		end
		for _, add in {0, 0.5, 1, 2, 4, 6, 8, 12, 16} do
			local point = target - unit * (base + add)
			if free(point) then
				local ok, out = pcall(workspace.Raycast, workspace, target, point - target, ray)
				if ok and not out then return point end
			end
		end
	end

	ctx.origin = api
end
]==]
sources['core/patch.lua'] = [==[
return function(ctx)
	local sys = {
		states = setmetatable({}, {__mode = 'k'}),
		map = {},
		order = {}
	}

	local function statefor(obj, prop)
		local props = sys.states[obj]
		if not props then
			props = {}
			sys.states[obj] = props
		end
		if props[prop] then return props[prop] end
		local ok, original = ctx.vapeapi:getprop(obj, prop)
		if not ok then return nil end
		if ctx.config and type(ctx.config.unwrapped) == 'function' then
			original = ctx.config:unwrapped(obj, prop, original)
		end
		local state = {obj = obj, prop = prop, original = original, value = original, ops = {}}
		props[prop] = state
		return state
	end

	local function recompute(state)
		local val = state.original
		for _, op in ipairs(state.ops) do
			if op.patch.enabled then
				if op.kind == 'set' then
					val = op.value
				else
					local old = val
					val = function(...)
						return op.value(old, ...)
					end
				end
			end
		end
		state.value = val
		if sys.suspended then return true end
		if not ctx.vapeapi:setprop(state.obj, state.prop, val) then return false end
		if ctx.config and type(ctx.config.rewatch) == 'function' then ctx.config:rewatch(state.obj, state.prop) end
		return true
	end

	local function optionrecord(obj)
		for _, data in ipairs(ctx.patchopts) do
			if data.obj == obj then return data end
		end
	end

	local function managed(patch, obj, name, created, previous, snapshot)
		local found = optionrecord(obj)
		if found then
			local data = found
				if not data.owners[patch] then
					data.owners[patch] = true
					patch.options[#patch.options + 1] = data
				end
				return data
		end
		local data = {
			patch = patch,
			mod = patch.mod,
			name = name,
			obj = obj,
			created = created == true,
			previous = previous,
			persist = type(obj.Save) == 'function' and type(obj.Load) == 'function',
			owners = {[patch] = true}
		}
		if not data.created and data.persist and type(ctx.vapeapi.snapshotoption) == 'function' then
			local val, ok
			if snapshot then val, ok = snapshot.value, true else val, ok = ctx.vapeapi:snapshotoption(obj) end
			if not ok then return nil end
			data.native = val
			data.nativeknown = true
		end
		ctx.patchopts[#ctx.patchopts + 1] = data
		patch.options[#patch.options + 1] = data
		return data
	end

	local function optionname(mod, obj, wanted)
		if type(mod.Options) ~= 'table' then return nil end
		if wanted and mod.Options[wanted] == obj then return wanted end
		for name, val in pairs(mod.Options) do
			if val == obj then return name end
		end
	end

	local patchmeta = {}
	patchmeta.__index = patchmeta

	function patchmeta:_touch(obj, prop, kind, val)
		obj = obj or self.mod
		local name = obj ~= self.mod and optionname(self.mod, obj)
		local snapshot
		if name and not optionrecord(obj) and type(obj.Save) == 'function' and type(obj.Load) == 'function' then
			local native, ok = ctx.vapeapi:snapshotoption(obj)
			if not ok then return false end
			snapshot = {value = native}
		end
		local state = statefor(obj, prop)
		if not state then return false end
		if kind == 'wrap' and type(state.value) ~= 'function' then
			if #state.ops == 0 then
				local props = sys.states[obj]
				if props then
					props[prop] = nil
					if next(props) == nil then sys.states[obj] = nil end
				end
			end
			return false
		end
		local op = {patch = self, kind = kind, value = val}
		state.ops[#state.ops + 1] = op
		self.ops[#self.ops + 1] = {state = state, op = op}
		if not recompute(state) then
			table.remove(state.ops)
			table.remove(self.ops)
			if #state.ops == 0 then
				state.value = state.original
				local props = sys.states[obj]
				if props then
					props[prop] = nil
					if next(props) == nil then sys.states[obj] = nil end
				end
			else
				recompute(state)
			end
			return false
		end
		if name and not managed(self, obj, name, false, nil, snapshot) then
			for i = #state.ops, 1, -1 do
				if state.ops[i] == op then table.remove(state.ops, i) break end
			end
			table.remove(self.ops)
			recompute(state)
			return false
		end

		return true
	end

	function patchmeta:set(prop, val, obj)
		if type(prop) ~= 'string' or prop == '' then return false end
		return self:_touch(obj, prop, 'set', val)
	end

	function patchmeta:wrap(prop, fn, obj)
		if type(prop) ~= 'string' or type(fn) ~= 'function' then return false end
		return self:_touch(obj, prop, 'wrap', fn)
	end

	function patchmeta:observe(fn)
		if type(fn) ~= 'function' then return false end
		return self:wrap('Toggle', function(old, mod, ...)
			local before = mod.Enabled
			local out = table.pack(old(mod, ...))
			fn(mod.Enabled, before, mod)
			return table.unpack(out, 1, out.n)
		end)
	end

	function patchmeta:manage(opt, name)
		name = optionname(self.mod, opt, name)
		if not name then return nil end
		if not managed(self, opt, name, false) then return nil end
		if ctx.config and ctx.state == 'loaded' and type(ctx.config.watchoption) == 'function' then
			ctx.config:watchoption(opt)
		end
		return opt
	end

	function patchmeta:value(opt, data)
		if type(opt) ~= 'table' or type(data) ~= 'table' then return false end
		local name = optionname(self.mod, opt)
		if not name then return false end
		return self:_touch(opt, '@value', 'set', data)
	end

	function patchmeta:list(opt, data)
		if type(opt) ~= 'table' or type(data) ~= 'table' then return false end
		return self:_touch(opt, '@list', 'set', data)
	end

	function patchmeta:visible(opt, val)
		if type(opt) ~= 'table' then return false end
		return self:_touch(opt, '@visible', 'set', val == true)
	end

	function patchmeta:bind(obj, data)
		if type(obj) ~= 'table' then return false end
		return self:_touch(obj, '@bind', 'set', data)
	end

	function patchmeta:callback(fn, obj)
		if type(fn) ~= 'function' then return false end
		return self:_touch(obj, 'Function', 'set', fn)
	end

	function patchmeta:option(kind, def)
		if type(def) ~= 'table' or type(def.name) ~= 'string' or def.name == '' then return nil end
		if type(self.mod.Options) ~= 'table' then return nil end
		local keys = type(ctx.vapeapi.optionkeys) == 'function' and ctx.vapeapi:optionkeys(kind, def) or {def.name}
		for _, name in ipairs(keys) do
			if self.mod.Options[name] ~= nil then return nil end
		end

		local before = {}
		for name, obj in pairs(self.mod.Options) do before[name] = obj end
		local out = table.pack(pcall(ctx.vapeapi.createoption, ctx.vapeapi, self.mod, kind, def))
		local opt, msg = out[2], out[3]
		for name, obj in pairs(self.mod.Options) do
			if before[name] ~= obj then managed(self, obj, name, true, before[name]) end
		end
		if not out[1] then error(out[2], 0) end
		if opt == nil and msg then
			ctx.log:add('patch', self.path, msg)
			return nil
		end
		if ctx.config and ctx.state == 'loaded' and type(ctx.config.watchoption) == 'function' then
			for _, data in ipairs(self.options) do ctx.config:watchoption(data.obj) end
		end
		return opt or self.mod.Options[keys[1]]
	end

	function patchmeta:setenabled(on, quiet)
		on = on == true
		if self.enabled == on then return false end
		local previous = self.enabled
		self.enabled = on
		local seen = {}
		local ok = true
		for _, data in ipairs(self.ops) do
			if not seen[data.state] then
				seen[data.state] = true
				if not recompute(data.state) then ok = false break end
			end
		end
		if not ok then
			self.enabled = previous
			for state in pairs(seen) do recompute(state) end
			ctx.log:add('patch', self.path, 'patch state change could not be applied')
			return false
		end
		if not quiet and ctx.config then ctx.config:schedule() end
		return true
	end

	function patchmeta:enable()
		return self:setenabled(true)
	end

	function patchmeta:disable()
		return self:setenabled(false)
	end

	local function removepatch(patch)
		patch.enabled = false
		local ok = true
		local touched = {}
		for i = #patch.ops, 1, -1 do
			local data = patch.ops[i]
			for n = #data.state.ops, 1, -1 do
				if data.state.ops[n] == data.op then
					table.remove(data.state.ops, n)
					break
				end
			end
			touched[data.state] = true
		end
		for state in pairs(touched) do
			if not recompute(state) then
				ok = false
				ctx.log:add('patch_cleanup', patch.path, 'failed to restore '..tostring(state.prop))
			end
		end
		for i = #patch.options, 1, -1 do
			local data = patch.options[i]
			data.owners[patch] = nil
			if next(data.owners) == nil then
				local removed = true
				if data.created then
					removed = ctx.vapeapi:removeoption(data.mod, data.name, data.obj)
					if removed and data.previous ~= nil and data.mod.Options[data.name] == nil then
						data.mod.Options[data.name] = data.previous
					end
				elseif data.native ~= nil then
					removed = ctx.vapeapi:loadoption(data.obj, data.native)
				end
				ok = removed and ok
				if removed then
					local owner = ctx.mods[data.mod.Name]
					if ctx.config and type(ctx.config.forgetobj) == 'function'
						and (data.created or not owner or owner.obj ~= data.mod) then
						ctx.config:forgetobj(data.obj)
					end
					for n = #ctx.patchopts, 1, -1 do
						if ctx.patchopts[n] == data then table.remove(ctx.patchopts, n) end
					end
				end
			end
		end
		if ok then
			sys.map[patch.id] = nil
			for i = #sys.order, 1, -1 do
				if sys.order[i] == patch then table.remove(sys.order, i) end
			end
		else
			patch.cleanup = false
		end
		return ok
	end

	function sys:rollback(mark)
		local ok = true
		for i = #self.order, mark + 1, -1 do ok = removepatch(self.order[i]) and ok end
		return ok
	end

	function sys:dropmod(mod)
		local ok = true
		for i = #self.order, 1, -1 do
			if self.order[i].mod == mod then ok = removepatch(self.order[i]) and ok end
		end
		return ok
	end

	function sys:restore()
		local ok = true
		for i = #self.order, 1, -1 do ok = removepatch(self.order[i]) and ok end
		for _, props in pairs(self.states) do
			for _, state in pairs(props) do
				if not ctx.vapeapi:setprop(state.obj, state.prop, state.original) then ok = false end
			end
		end
		if ok then table.clear(self.states) end
		return ok
	end

	function sys:suspend()
		self.suspenddepth = (self.suspenddepth or 0) + 1
		if self.suspenddepth > 1 then return self.suspendok ~= false end
		local ok = true
		for _, props in pairs(self.states) do
			for _, state in pairs(props) do
				if not ctx.vapeapi:setprop(state.obj, state.prop, state.original) then ok = false end
				if ctx.config and type(ctx.config.rewatch) == 'function' then ctx.config:rewatch(state.obj, state.prop) end
			end
		end
		self.suspended = true
		self.suspendok = ok
		return ok
	end

	function sys:resume(rebase)
		if not self.suspended then return true end
		self.rebase = self.rebase or rebase == true
		self.suspenddepth = math.max((self.suspenddepth or 1) - 1, 0)
		if self.suspenddepth > 0 then return true end
		rebase = self.rebase
		self.rebase = nil
		self.suspended = false
		self.suspendok = nil
		local ok = true
		for _, props in pairs(self.states) do
			for _, state in pairs(props) do
				if rebase then
					local got, val = ctx.vapeapi:getprop(state.obj, state.prop)
					if got then
						if ctx.config and type(ctx.config.unwrapped) == 'function' then
							val = ctx.config:unwrapped(state.obj, state.prop, val)
						end
						state.original = val
					else ok = false end
				end
				if not recompute(state) then ok = false end
			end
		end
		return ok
	end

	function sys:valuepatched(obj)
		local props = self.states[obj]
		if not props then return false end
		for prop, state in pairs(props) do
			if prop == '@value' then
				for _, op in ipairs(state.ops) do
					if op.patch.enabled then return true end
				end
			end
		end
		return false
	end

	function sys:original(obj, prop, val)
		local state = self.states[obj] and self.states[obj][prop]
		if state and (val == state.value or val == state.original) then return state.original end
		return val
	end

	function ctx:patch(name, id, cat)
		if type(name) ~= 'string' or name == '' or type(id) ~= 'string' or id == '' then return nil end
		if sys.map[id] then
			local first = sys.map[id].path or 'runtime'
			error('duplicate patch id '..id..' (first declared by '..first..')', 0)
		end
		local mod = self.vapeapi:find(name, cat)
		if not mod then
			if self.loading and self.loading.required then error('required patch target missing: '..name, 0) end
			return nil
		end
		local load = self.loading or {}
		local patch = setmetatable({
			id = id,
			name = name,
			category = cat,
			mod = mod,
			enabled = true,
			ops = {},
			options = {},
			layer = load.layer or 'runtime',
			scope = load.scope or 'universal',
			path = load.path
		}, patchmeta)
		sys.map[id] = patch
		sys.order[#sys.order + 1] = patch
		return patch
	end

	ctx.patchsys = sys
end
]==]
sources['core/profile.lua'] = [==[
return function(ctx)
	local prof = {name = 'default', dir = 'default'}

	local function canonical(name)
		if type(name) ~= 'string' then return nil end
		name = name:gsub('^%s+', ''):gsub('%s+$', '')
		if name == '' or name == '.' or name == '..' or #name > 64
			or name:find('[/\\:%z\1-\31]') then return nil end
		return name
	end

	local function clean(name)
		local out = name:gsub('[^%w%._ %-]', '_')
		if name == 'default' then return name end
		local hash = 0
		for i = 1, #name do hash = (hash * 33 + name:byte(i)) % 4294967296 end
		return out:sub(1, 54)..'-'..string.format('%08x', hash)
	end

	function prof:set(name)
		self.name = canonical(name) or 'default'
		self.dir = clean(self.name)
		ctx.store:mkdir('configs/profiles/'..self.dir)
		if ctx.config then ctx.config:setpaths() end
		return self.name
	end

	function prof:switch(name, saved)
		name = canonical(name)
		if not name then return false end
		if name == self.name then return true end
		if ctx.config and not saved and not ctx.config:save(true) then return false end
		local oldname, olddir = self.name, self.dir
		self:set(name)
		if ctx.config then
			ctx.config:load()
			if not ctx.config:restore() or not ctx.config:index() then
				self.name, self.dir = oldname, olddir
				ctx.config:setpaths()
				ctx.config:load()
				if not ctx.config:restore() then ctx.log:add('profile', oldname, 'profile rollback failed') end
				ctx.config:index()
				return false
			end
		end
		return true
	end

	function prof:select(name)
		name = canonical(name)
		if not name then return false end
		local vape = ctx.vape
		if ctx.vapeapi.realprofile and type(vape.Save) == 'function' and type(vape.Load) == 'function' then
			local ok, msg = pcall(function()
				vape:Save(name)
				vape:Load(true)
			end)
			if not ok then
				ctx.log:add('profile', name, msg)
				return false
			end
			return self.name == name
		end
		return self:switch(name)
	end

	prof:set(ctx.vapeapi:profile())
	ctx.profile = prof
	function ctx:setprofile(name)
		return self.profile:select(name)
	end
end
]==]
sources['core/runtime.lua'] = [==[
return function(ctx)
	local function category(cat)
		if type(cat) ~= 'string' then return nil end
		cat = cat:lower()
		if ctx.cats.names[cat] then return cat end
		for low, real in pairs(ctx.cats.names) do
			if real:lower() == cat then return low end
		end
	end

	function ctx:find(name, cat)
		return self.vapeapi:find(name, cat)
	end

	function ctx:drop(name)
		local data = self.mods[name]
		if not data then return false end
		if not self.patchsys:dropmod(data.obj) then return false end
		if not self.vapeapi:remove(name, data.obj) then return false end
		if self.config and type(self.config.forgetmodule) == 'function' then self.config:forgetmodule(data.obj) end
		self.mods[name] = nil
		for i = #self.modorder, 1, -1 do
			if self.modorder[i] == data then
				table.remove(self.modorder, i)
				break
			end
		end
		return true
	end

	function ctx:module(cat, def)
		cat = category(cat)
		if not cat then error('unsupported Vape category', 0) end
		if type(def) ~= 'table' then error('module definition must be a table', 0) end
		local name = def.name or def.Name
		if type(name) ~= 'string' or name == '' then error('module name is required', 0) end
		local load = self.loading or {}
		if load.category and load.category ~= cat then
			error('module category does not match its manifest', 0)
		end

		self.vapeapi:reindex()
		local live, _, kind = self.vapeapi:liveslot(name)
		if kind == 'category' then error('module name collides with a Vape category: '..name, 0) end
		local old = self.vapeapi:find(name)
		if live ~= nil and not old then error('Vape registry name is already in use: '..name, 0) end
		if old then
			if def.replace ~= true then error('Vape module already exists: '..name, 0) end
			if old.Enabled then error('an enabled Vape module cannot be replaced safely: '..name, 0) end
			local id = 'replace:'..tostring(load.path or 'runtime')..':'..name
			local patch = self:patch(name, id, cat)
			if not patch then error('module replacement could not start: '..name, 0) end
			local func = def.func or def.Function
			if func and not patch:set('Function', func) then
				error('Vape callback is unavailable for replacement: '..name, 0)
			end
			local tooltip = def.tooltip or def.Tooltip
			if tooltip ~= nil and not patch:set('Tooltip', tooltip) then
				error('Vape tooltip is unavailable for replacement: '..name, 0)
			end
			local extra = def.extratext or def.ExtraText
			if extra ~= nil then patch:set('ExtraText', extra) end
			return old
		end

		local spec = self.vapeapi:spec(def)
		spec.Name = name
		local func = def.func or def.Function or function() end
		spec.Function = function(on)
			if self.config then self.config:schedule() end
			return func(on)
		end
		local mod = self.vapeapi:create(cat, spec)
		local data = {
			name = name,
			category = cat,
			obj = mod,
			layer = load.layer or 'runtime',
			scope = load.scope or 'universal',
			path = load.path,
			autostart = def.autostart ~= false
		}
		self.mods[name] = data
		self.modorder[#self.modorder + 1] = data
		if self.config and self.state == 'loaded' then self.config:watchmodule(data) end
		return mod
	end

	function ctx:_mark()
		return {mods = #self.modorder, patches = #self.patchsys.order, clean = self.bin:mark()}
	end

	function ctx:_rollback(mark)
		local ok = self.patchsys:rollback(mark.patches)
		for i = #self.modorder, mark.mods + 1, -1 do
			local data = self.modorder[i]
			if self.vapeapi:remove(data.name, data.obj) then
				self.mods[data.name] = nil
				table.remove(self.modorder, i)
			else
				ok = false
				self.log:add('module_cleanup', data.path, 'failed to roll back '..data.name)
			end
		end
		ok = self.bin:rollback(mark.clean) and ok
		return ok
	end

	function ctx:modules()
		local out = {}
		for _, data in ipairs(self.modorder) do
			out[#out + 1] = {
				name = data.name,
				category = data.category,
				layer = data.layer,
				scope = data.scope,
				path = data.path,
				enabled = data.obj.Enabled == true
			}
		end
		return out
	end

	function ctx:patches()
		local out = {}
		for _, data in ipairs(self.patchsys.order) do
			out[#out + 1] = {
				id = data.id,
				name = data.name,
				category = data.category,
				layer = data.layer,
				scope = data.scope,
				path = data.path,
				enabled = data.enabled,
				operations = #data.ops,
				options = #data.options
			}
		end
		return out
	end

	function ctx:errors(kind)
		local out = self.log:list(kind)
		for _, item in ipairs(self.loader.errors or {}) do
			if not kind or item.kind == kind then out[#out + 1] = table.clone(item) end
		end
		return out
	end

	function ctx:status()
		return {
			name = self.name,
			version = self.version,
			build = self.loader.build,
			state = self.state,
			started = self.started,
			target = self.target and table.clone(self.target) or nil,
			layers = table.clone(self.layers),
			profile = self.profile and self.profile.name or 'default',
			config = self.config and self.config.paths and table.clone(self.config.paths) or {},
			cache = type(self.loader.cachestatus) == 'function'
				and self.loader:cachestatus() or table.clone(self.loader.stats),
			modules = #self.modorder,
			patches = #self.patchsys.order,
			errors = #self.log.history + #(self.loader.errors or {})
		}
	end

	function ctx:selfcheck()
		local cats = {}
		for _, cat in ipairs(self.cats.order) do
			cats[cat] = self.vapeapi:category(cat) ~= nil
		end
		return {
			vape = self.vape == self.vapeapi.object and self.vape.Loaded ~= nil,
			readiness = self.vapeapi.readiness,
			adapter = type(self.vapeapi.capabilities) == 'function' and self.vapeapi:capabilities() or {},
			categories = cats,
			filesystem = table.clone(self.store.fs),
			profile = self.profile and self.profile.name or 'default',
			registry = type(self.vape.Modules) == 'table',
			patch_restore = type(self.patchsys.restore) == 'function',
			config = self.config and self.config:check() or false
		}
	end

	function ctx:unload(reason)
		if self.state == 'unloading' or self.state == 'unloaded' then return false end
		local previous = self.state
		self.state = 'unloading'
		local complete = true
		local function stage(kind, fn)
			local ok, val = pcall(fn)
			if not ok or val == false then
				complete = false
				self.log:add(kind, nil, ok and 'cleanup returned false' or val)
			end
		end
		if self.config and previous == 'loaded' then
			local ok, saved = pcall(self.config.save, self.config, true)
			if not ok or saved == false then
				self.savefailed = true
				self.log:add('config_write', nil, ok and 'cleanup save returned false' or saved)
			end
		end
		stage('cleanup', function() self.vapeapi:unhook() return true end)
		stage('patch_cleanup', function() return self.patchsys:restore() end)
		if self.config and self.config.unwatch then stage('cleanup', function() self.config:unwatch() return true end) end
		for i = #self.modorder, 1, -1 do
			local data = self.modorder[i]
			local ok, removed = pcall(self.vapeapi.remove, self.vapeapi, data.name, data.obj)
			if ok and removed then
				self.mods[data.name] = nil
				table.remove(self.modorder, i)
			else
				complete = false
				self.log:add('module_cleanup', data.path, ok and 'cleanup returned false' or removed)
			end
		end
		stage('cleanup', function() return self.bin:run() end)
		table.clear(self.events)
		self.reason = reason
		self.state = complete and 'unloaded' or 'unload_failed'
		local env = (getgenv and getgenv()) or _G
		if env.VapeTweaker == self and (complete or reason == 'reload' or reason == 'startup failure') then
			env.VapeTweaker = nil
		end
		return complete
	end
end
]==]
sources['core/storage.lua'] = [==[
return function(ctx)
	local http = game:GetService('HttpService')
	local store = {root = ctx.loader.root, dirs = {}}

	local function norm(path)
		path = tostring(path or ''):gsub('\\', '/'):gsub('/+', '/')
		path = path:gsub('^%./', ''):gsub('^/+', ''):gsub('/+$', '')
		if path:find('[%z\1-\31:]') then return nil end
		local parts = {}
		for part in path:gmatch('[^/]+') do
			if part == '..' then return nil end
			if part ~= '.' then parts[#parts + 1] = part end
		end
		return table.concat(parts, '/')
	end


	local function variant(path, tag)
		path = norm(path)
		if not path then return nil end
		local stem, ext = path:match('^(.*)(%.[^/%.]+)$')
		return stem and stem..'.'..tag..ext or path..'.'..tag
	end

	function store:path(path)
		path = norm(path)
		if not path then return nil end
		return path == '' and self.root or self.root..'/'..path
	end

	function store:mkdir(path)
		path = self:path(path)
		if not path or type(makefolder) ~= 'function' then return false end
		local out = ''
		for part in path:gmatch('[^/]+') do
			out = out == '' and part or out..'/'..part
			if not self.dirs[out] then
				local present = false
				if type(isfolder) == 'function' then
					local ok, val = pcall(isfolder, out)
					present = ok and val == true
				end
				if not present then
					local ok, msg = pcall(makefolder, out)
					if not ok and type(isfolder) == 'function' then
						local checked, val = pcall(isfolder, out)
						if checked and val then ok = true end
					end
					if not ok and type(isfolder) == 'function' then
						ctx.log:add('storage', out, msg)
						return false
					end
				end
				self.dirs[out] = true
			end
		end
		return true
	end

	function store:read(path)
		path = self:path(path)
		if not path or type(readfile) ~= 'function' then return nil end
		if type(isfile) == 'function' then
			local ok, val = pcall(isfile, path)
			if ok and not val then return nil end
		end
		local ok, data = pcall(readfile, path)
		if ok and type(data) == 'string' then return data end
		if not ok then ctx.log:add('storage', path, data) end
	end

	function store:variant(path, tag)
		return variant(path, tostring(tag or 'tmp'))
	end

	function store:temp(path, token)
		local tag = token and tostring(token)..'.tmp' or 'tmp'
		return variant(path, tag)
	end

	function store:backup(path)
		return variant(path, 'bak')
	end

	function store:write(path, data)
		path = norm(path)
		local full = path and self:path(path)
		if not full or type(writefile) ~= 'function' then return false end
		local dir = path:match('^(.*)/[^/]+$')
		if dir and not self:mkdir(dir) then return false end
		local ok, msg = pcall(writefile, full, tostring(data))
		if not ok or msg == false then
			ctx.log:add('storage', full, ok and 'writefile returned false' or msg)
			return false
		end
		return true
	end

	function store:remove(path)
		local full = self:path(path)
		if not full or type(delfile) ~= 'function' then return false end
		if type(isfile) == 'function' then
			local checked, present = pcall(isfile, full)
			if checked and not present then return true end
		end
		local ok, msg = pcall(delfile, full)
		if not ok or msg == false then
			ctx.log:add('storage', full, ok and 'delfile returned false' or msg)
			return false
		end
		return true
	end

	function store:decode(raw, path)
		local ok, data = pcall(http.JSONDecode, http, raw)
		if ok then return data end
		ctx.log:add('config_parse', path, data)
	end

	function store:encode(data, path)
		local ok, raw = pcall(http.JSONEncode, http, data)
		if ok then return raw end
		ctx.log:add('config_write', path, raw)
	end

	function store:json(path)
		local raw = self:read(path)
		if not raw then return nil end
		return self:decode(raw, path)
	end

	function store:has(path)
		return self:read(path) ~= nil
	end

	store.fs = {
		read = type(readfile) == 'function',
		write = type(writefile) == 'function',
		folders = type(makefolder) == 'function',
		delete = type(delfile) == 'function'
	}

	ctx.store = store
end
]==]
sources['core/target.lua'] = [==[
return function(ctx)
	local function file(path)
		if type(isfile) ~= 'function' then return nil end
		local ok, val = pcall(isfile, path)
		if not ok then return nil end
		return val == true
	end

	function ctx:resolvetarget()
		local vape = self.vape
		local gameid = game.GameId
		local placeid = game.PlaceId
		local buildid = vape.Place or placeid
		local nativefile = file('newvape/games/'..tostring(placeid)..'.lua')
		local independent = type(shared) == 'table' and shared.VapeIndependent == true
		local native = not independent and (buildid ~= placeid or nativefile == true)
		local mode = independent and 'independent' or native and 'game' or 'universal'

		self.target = {
			mode = mode,
			gameid = gameid,
			placeid = placeid,
			buildid = buildid,
			native = native,
			native_known = buildid ~= placeid or nativefile ~= nil,
			gui = self.vapeapi.flavor or 'unknown',
			version = vape.Version,
			readiness = self.vapeapi.readiness
		}
		return self.target
	end
end
]==]
sources['core/vapeapi.lua'] = [==[
return function(ctx)
	local vape = ctx.vape
	local api = {object = vape, flavor = 'new', readiness = 'native modules initialized', realprofile = true}
	local specs = setmetatable({}, {__mode = 'k'})
	local propertyMap = {name='Name', func='Function', tooltip='Tooltip', extratext='ExtraText', default='Default',
		list='List', min='Min', max='Max', decimal='Decimal', suffix='Suffix', darker='Darker', visible='Visible'}
	local methods = {toggle='CreateToggle', slider='CreateSlider', twoslider='CreateTwoSlider', dropdown='CreateDropdown',
		multidropdown='CreateMultiDropdown', textbox='CreateTextBox', textlist='CreateTextList', bind='CreateBind',
		colorslider='CreateColorSlider', font='CreateFont', targets='CreateTargets'}
	local function props(obj)
		if specs[obj] then return specs[obj] end
		local getter = debug and debug.getupvalues or getupvalues
		if type(getter) == 'function' and type(obj.Toggle) == 'function' then
			local ok, values = pcall(getter, obj.Toggle)
			if ok and type(values) == 'table' then
				for _, val in pairs(values) do
					if type(val) == 'table' and val.Name == obj.Name and type(val.Function) == 'function' then
						specs[obj] = val
						return val
					end
				end
			end
		end
	end
	function api:spec(def)
		local out = {}
		for key, val in pairs(def) do
			if propertyMap[key] then out[propertyMap[key]] = val
			elseif type(key) == 'string' and key:match('^%u') then out[key] = val end
		end
		return out
	end
	function api:category(cat) return vape.Categories[ctx.cats.names[tostring(cat):lower()] or cat] end
	function api:reindex() return true end
	function api:liveslot(name)
		local obj = vape.Modules[name]
		if obj then return obj, obj.Category, 'module' end
		obj = vape.Categories[name]
		if obj then return obj, name, 'category' end
	end
	function api:find(name, cat)
		local obj = vape.Modules[name]
		if not obj and vape.Legit and vape.Legit.Modules then obj = vape.Legit.Modules[name] end
		if obj and cat and tostring(obj.Category):lower() ~= tostring(ctx.cats.names[tostring(cat):lower()] or cat):lower() then return end
		return obj
	end
	function api:create(cat, spec)
		local category = assert(self:category(cat), 'Vape category unavailable: '..tostring(cat))
		local obj = category:CreateModule(spec)
		specs[obj] = spec
		local nativeLoad = obj.Load
		if type(nativeLoad) == 'function' then
			obj.Load = function(self, data)
				local entry = ctx.mods[spec.Name]
				if entry and entry.autostart == false and data.Enabled then
					data = table.clone(data)
					data.Enabled = false
				end
				return nativeLoad(self, data)
			end
		end
		return obj
	end
	function api:remove(name, expected)
		if self:find(name) ~= expected then return false end
		if expected.Enabled then expected:Toggle() end
		vape:Remove(name)
		return self:find(name) == nil
	end
	function api:profile() return vape.Profile or 'default' end
	function api:savebind(obj)
		local bind = obj.Bind or obj
		if type(bind.Save) ~= 'function' then return {} end
		local saved = {}
		bind:Save(saved)
		return saved.Bind or select(2, next(saved)) or {}
	end
	function api:setbind(obj, data)
		local bind = obj.Bind or obj
		if type(bind.Load) == 'function' and type(data) == 'table' then bind:Load(data) return true end
		if type(bind.SetBind) == 'function' then bind:SetBind(type(data) == 'table' and (data.Keys or data) or {data}) return true end
		return false
	end
	function api:getvisible(obj)
		if type(obj.Visible) == 'boolean' then return obj.Visible end
		if obj.Object then return obj.Object.Visible end
	end
	function api:setvisible(obj, value)
		if type(obj.SetVisible) == 'function' then obj:SetVisible(value, true) return true end
		if obj.Object then obj.Object.Visible = value return true end
		return false
	end
	function api:snapshotoption(obj)
		if type(obj.Save) ~= 'function' then return nil, false end
		local saved = {}
		local ok, err = pcall(obj.Save, obj, saved)
		if not ok then return err, false end
		local _, value = next(saved)
		return value, true
	end
	function api:loadoption(obj, data)
		if type(obj.Load) ~= 'function' then return false end
		local ok, result = pcall(obj.Load, obj, data)
		return ok and result ~= false
	end
	function api:optionkeys(_, def) return {def.name} end
	function api:createoption(mod, kind, def)
		local method = methods[tostring(kind):lower()]
		if not method or type(mod[method]) ~= 'function' then return nil, 'Unsupported option type: '..tostring(kind) end
		return mod[method](mod, self:spec(def))
	end
	function api:removeoption(mod, name, expected)
		if mod.Options[name] ~= expected then return false end
		if expected.Enabled and expected.Toggle then expected:Toggle() end
		if expected.Destroy then expected:Destroy() elseif expected.Object then expected.Object:Destroy() end
		mod.Options[name] = nil
		return true
	end
	function api:getprop(obj, key)
		if key == '@visible' then return true, self:getvisible(obj) end
		if key == '@bind' then return true, self:savebind(obj) end
		if key == '@list' then return true, obj.List end
		if key == '@value' then local value, ok = self:snapshotoption(obj) return ok, value end
		local spec = (key == 'Function' or key == 'Tooltip' or key == 'ExtraText') and props(obj)
		return true, spec and spec[key] or obj[key]
	end
	function api:setprop(obj, key, value)
		if key == '@visible' then return self:setvisible(obj, value) end
		if key == '@bind' then return self:setbind(obj, value) end
		if key == '@value' then return self:loadoption(obj, value) end
		if key == '@list' then
			if type(obj.Change) ~= 'function' then return false end
			obj:Change(value)
			return true
		end
		local spec = (key == 'Function' or key == 'Tooltip' or key == 'ExtraText') and props(obj)
		if spec then spec[key] = value else obj[key] = value end
		return true
	end
	function api:capabilities() return {native = true, profiles = true, options = true, patches = true} end
	function api:hook()
		local save, load = vape.Save, vape.Load
		self.oldSave, self.oldLoad = save, load
		self.saveWrap = function(obj, ...)
			local out = table.pack(ctx.config:nativesave(save, obj, ...))
			if ctx.state == 'loaded' and not ctx.config.restoring then ctx.config:save(true) end
			return table.unpack(out, 1, out.n)
		end
		self.loadWrap = function(obj, ...)
			local out = table.pack(ctx.config:nativeload(load, obj, ...))
			ctx.profile:set(self:profile())
			ctx.config:capture()
			ctx.config:load()
			assert(ctx.config:restore(), 'Additional module profile restore failed')
			ctx.state = 'loaded'
			return table.unpack(out, 1, out.n)
		end
		vape.Save, vape.Load = self.saveWrap, self.loadWrap
	end
	function api:unhook()
		if vape.Save == self.saveWrap then vape.Save = self.oldSave end
		if vape.Load == self.loadWrap then vape.Load = self.oldLoad end
	end
	ctx.vapeapi = api
end
]==]
sources['core/weapon.lua'] = [==[
return function(ctx)
	local api = {}

	function api:known()
		return false
	end

	function api:resolve()
		return 'generic'
	end

	ctx.weapon = api
end
]==]
sources['src/modules/blatant/fakelag.lua'] = [==[
return function(ctx)
	local mod
	local meth
	local ping
	local old
	local net
	local hook
	local busy = false
	local seq = 0
	local rng = Random.new()
	local q = {}
	local head = 1
	local tail = 0
	local bad = {}
	local goal = 0
	local cur = 0
	local last = 0
	local next = 0

	local function get()
		if type(settings) ~= 'function' then return nil end
		local ok, val = pcall(settings)
		if not ok then return nil end
		local kind = type(val)
		if kind ~= 'userdata' and kind ~= 'table' then return nil end
		local ok2, out = pcall(function() return val.Network end)
		return ok2 and out or nil
	end

	local function set(val)
		net = net or get()
		if not net then return false end
		return pcall(function() net.IncomingReplicationLag = val end)
	end

	local function api()
		return type(raknet) == 'table'
			and type(raknet.add_send_hook) == 'function'
			and type(raknet.remove_send_hook) == 'function'
			and type(raknet.send) == 'function'
			and type(raknet.is_enabled) == 'function'
	end

	local function ready()
		if not api() then return false end
		local ok, val = pcall(raknet.is_enabled)
		return ok and val == true
	end

	local function notice()
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'FakeLag', 'The selected method requires an executor with Raknet support.', 10, 'warning')
		end
	end

	local function bounds()
		local low = tonumber(ping and (ping.ValueMin or ping.MinValue or ping.LowValue)) or 200
		local high = tonumber(ping and (ping.ValueMax or ping.MaxValue or ping.HighValue)) or 300
		if high < low then low, high = high, low end
		return math.max(low, 0), math.max(high, 0)
	end

	local function pick()
		local low, high = bounds()
		if high <= low then return low end
		return rng:NextNumber(low, high)
	end

	local function copy(val)
		local kind = typeof(val)
		if type(val) == 'string' then return val end
		if kind == 'buffer' then
			if type(buffer) ~= 'table' or type(buffer.len) ~= 'function' or type(buffer.create) ~= 'function' or type(buffer.copy) ~= 'function' then return val end
			local ok, out = pcall(function()
				local n = buffer.len(val)
				local b = buffer.create(n)
				buffer.copy(b, 0, val, 0, n)
				return b
			end)
			return ok and out or val
		end
		if type(val) == 'table' then
			local out = table.create(#val)
			for i, v in ipairs(val) do out[i] = v end
			return out
		end
	end

	local function read(pkt)
		local data
		local ok, val = pcall(function() return pkt.AsString end)
		if ok and type(val) == 'string' and #val > 0 then data = val end
		if data == nil then
			ok, val = pcall(function() return pkt.AsBuffer end)
			if ok and typeof(val) == 'buffer' then data = copy(val) end
		end
		if data == nil then
			ok, val = pcall(function() return pkt.AsArray end)
			if ok and type(val) == 'table' and #val > 0 then data = copy(val) end
		end
		if data == nil then return nil end
		local meta, id, pri, rel, chan, size = pcall(function()
			return pkt.PacketId, pkt.Priority, pkt.Reliability, pkt.OrderingChannel, pkt.Size
		end)
		if not meta then return nil end
		if type(pri) ~= 'number' or pri < 0 or pri > 3 then return nil end
		if type(rel) ~= 'number' or rel < 0 or rel > 7 then return nil end
		if type(chan) ~= 'number' or chan < 0 or chan > 31 then return nil end
		return {d = data, i = id, p = pri, r = rel, c = chan, s = size}
	end

	local function send(pkt)
		if not pkt or not ready() then return false end
		busy = true
		local ok = pcall(raknet.send, pkt.d, pkt.p, pkt.r, pkt.c)
		busy = false
		if not ok and pkt.i ~= nil then bad[pkt.i] = true end
		return ok
	end

	local function push(pkt)
		tail += 1
		q[tail] = pkt
	end

	local function pop()
		if head > tail then return nil end
		local pkt = q[head]
		q[head] = nil
		head += 1
		if head > tail then
			table.clear(q)
			head = 1
			tail = 0
			last = 0
		end
		return pkt
	end

	local function flush()
		while head <= tail do
			local pkt = pop()
			if pkt then send(pkt) end
		end
		table.clear(q)
		head = 1
		tail = 0
		last = 0
	end

	local function unhook()
		if hook and api() then pcall(raknet.remove_send_hook, hook) end
		hook = nil
	end

	local function stop()
		ctx.network:release('FakeLag')
		seq += 1
		unhook()
		flush()
		busy = false
		table.clear(bad)
		if old ~= nil then set(old) end
		old = nil
		net = nil
		last = 0
	end

	local function flow(id, normal)
		local low, high = bounds()
		goal = math.clamp(cur > 0 and cur or pick(), low, high)
		cur = goal
		next = os.clock() + rng:NextNumber(0.8, 1.4)
		local mark = os.clock()
		task.spawn(function()
			while mod.Enabled and id == seq and (normal and meth.Value == 'Normal' or not normal and meth.Value == 'Raknet') do
				local now = os.clock()
				local dt = math.min(now - mark, 0.1)
				mark = now
				low, high = bounds()
				if now >= next then
					goal = high > low and rng:NextNumber(low, high) or low
					next = now + rng:NextNumber(0.8, 1.4)
				end
				goal = math.clamp(goal, low, high)
				local rate = math.min(dt * 3.5, 1)
				cur = math.clamp(cur + (goal - cur) * rate, low, high)
				if normal then
					set(cur / 1000)
				end
				task.wait(0.03)
			end
		end)
	end

	local function normal()
		net = get()
		if not net then return false end
		local ok, val = pcall(function() return net.IncomingReplicationLag end)
		old = ok and val or 0
		seq += 1
		local id = seq
		cur = pick()
		flow(id, true)
		return set(cur / 1000)
	end

	local function rak()
		if not ready() then return false end
		seq += 1
		local id = seq
		cur = pick()
		flow(id, false)
		hook = function(pkt)
			if busy or not mod.Enabled or meth.Value ~= 'Raknet' or id ~= seq then return end
			local data = read(pkt)
			if not data or bad[data.i] then return end
			if tail - head + 1 >= 8192 then
				local pending = pop()
				if pending then send(pending) end
			end
			local ok = pcall(function() pkt:Block() end)
			if not ok then return end
			local now = os.clock()
			local at = now + cur / 1000
			if at <= last then at = last + 0.000001 end
			last = at
			data.t = at
			push(data)
		end
		local ok = pcall(raknet.add_send_hook, hook)
		if not ok then
			hook = nil
			table.clear(q)
			head = 1
			tail = 0
			return false
		end
		task.spawn(function()
			while mod.Enabled and meth.Value == 'Raknet' and id == seq do
				local now = os.clock()
				while q[head] and q[head].t <= now do
					local pkt = pop()
					if pkt then send(pkt) end
				end
				task.wait()
			end
		end)
		return true
	end

	local function start()
		ctx.network:claim('FakeLag', stop)
		if meth.Value == 'Raknet' then return rak() end
		return normal()
	end

	local function fail()
		stop()
		if meth.Value == 'Raknet' then notice() else
			ctx.vape:CreateNotification('FakeLag', 'Local replication lag is unavailable on this executor.', 6, 'alert')
		end
		task.defer(function()
			if mod.Enabled then mod:Toggle() end
		end)
	end

	mod = ctx:module('blatant', {
		name = 'FakeLag',
		tooltip = 'Simulates fluctuating network delay using local replication or Raknet packets.',
		extratext = function()
			return meth and meth.Value or 'Normal'
		end,
		func = function(on)
			if on then
				if meth.Value == 'Raknet' and not ready() then
					fail()
					return
				end
				if not start() then fail() end
			else
				stop()
			end
		end
	})

	meth = mod:CreateDropdown({
		Name = 'Method',
		List = {'Normal', 'Raknet'},
		Default = 'Normal',
		Function = function(val)
			if val == 'Raknet' and not ready() then
				notice()
				if mod.Enabled then task.defer(function() if mod.Enabled then mod:Toggle() end end) end
				return
			end
			if not mod.Enabled then return end
			stop()
			if not start() then fail() end
		end
	})

	ping = mod:CreateTwoSlider({
		Name = 'Ping',
		Min = 0,
		Max = 500,
		DefaultMin = 200,
		DefaultMax = 300
	})

	ctx:clean(stop)
end
]==]
sources['src/modules/blatant/lagswitch.lua'] = [==[
return function(ctx)
	local mod
	local meth
	local mode
	local time
	local hook
	local net
	local old
	local busy = false
	local seq = 0
	local q = {}
	local head = 1
	local tail = 0

	local function get()
		if type(settings) ~= 'function' then return nil end
		local ok, val = pcall(settings)
		if not ok then return nil end
		local kind = type(val)
		if kind ~= 'userdata' and kind ~= 'table' then return nil end
		local ok2, out = pcall(function() return val.Network end)
		return ok2 and out or nil
	end

	local function set(val)
		net = net or get()
		if not net then return false end
		return pcall(function() net.IncomingReplicationLag = val end)
	end

	local function api()
		return type(raknet) == 'table'
			and type(raknet.add_send_hook) == 'function'
			and type(raknet.remove_send_hook) == 'function'
			and type(raknet.send) == 'function'
			and type(raknet.is_enabled) == 'function'
	end

	local function ready()
		if not api() then return false end
		local ok, val = pcall(raknet.is_enabled)
		return ok and val == true
	end

	local function notice()
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'LagSwitch', 'The selected method requires an executor with Raknet support.', 10, 'warning')
		end
	end

	local function copy(val)
		local kind = typeof(val)
		if type(val) == 'string' then return val end
		if kind == 'buffer' then
			if type(buffer) ~= 'table' or type(buffer.len) ~= 'function' or type(buffer.create) ~= 'function' or type(buffer.copy) ~= 'function' then return val end
			local ok, out = pcall(function()
				local n = buffer.len(val)
				local b = buffer.create(n)
				buffer.copy(b, 0, val, 0, n)
				return b
			end)
			return ok and out or val
		end
		if type(val) == 'table' then
			local out = table.create(#val)
			for i, v in ipairs(val) do out[i] = v end
			return out
		end
	end

	local function read(pkt)
		local data
		local ok, val = pcall(function() return pkt.AsString end)
		if ok and type(val) == 'string' and #val > 0 then data = val end
		if data == nil then
			ok, val = pcall(function() return pkt.AsBuffer end)
			if ok and typeof(val) == 'buffer' then data = copy(val) end
		end
		if data == nil then
			ok, val = pcall(function() return pkt.AsArray end)
			if ok and type(val) == 'table' and #val > 0 then data = copy(val) end
		end
		if data == nil then return nil end
		local meta, pri, rel, chan = pcall(function()
			return pkt.Priority, pkt.Reliability, pkt.OrderingChannel
		end)
		if not meta then return nil end
		if type(pri) ~= 'number' or pri < 0 or pri > 3 then return nil end
		if type(rel) ~= 'number' or rel < 0 or rel > 7 then return nil end
		if type(chan) ~= 'number' or chan < 0 or chan > 31 then return nil end
		return {d = data, p = pri, r = rel, c = chan}
	end

	local function send(pkt)
		if not pkt or not api() then return false end
		local ok = pcall(raknet.send, pkt.d, pkt.p, pkt.r, pkt.c)
		return ok
	end

	local function push(pkt)
		tail += 1
		q[tail] = pkt
	end

	local function pop()
		if head > tail then return nil end
		local pkt = q[head]
		q[head] = nil
		head += 1
		if head > tail then
			table.clear(q)
			head = 1
			tail = 0
		end
		return pkt
	end

	local function count()
		return tail >= head and tail - head + 1 or 0
	end

	local function unhook()
		if hook and api() then pcall(raknet.remove_send_hook, hook) end
		hook = nil
	end

	local function flush()
		busy = true
		while head <= tail do
			local pkt = pop()
			if pkt then send(pkt) end
		end
		busy = false
		table.clear(q)
		head = 1
		tail = 0
	end

	local function stop()
		ctx.network:release('LagSwitch')
		seq += 1
		unhook()
		flush()
		busy = false
		if old ~= nil then set(old) end
		old = nil
		net = nil
	end

	local function rak()
		if not ready() then return false end
		seq += 1
		local id = seq
		table.clear(q)
		head = 1
		tail = 0
		hook = function(pkt)
			if busy or not mod.Enabled or meth.Value ~= 'Raknet' or id ~= seq then return end
			local data = read(pkt)
			if not data then return end
			if count() >= 8192 then
				busy = true
				local out = pop()
				if out then send(out) end
				busy = false
			end
			local ok = pcall(function() pkt:Block() end)
			if not ok then return end
			push(data)
		end
		local ok = pcall(raknet.add_send_hook, hook)
		if not ok then
			hook = nil
			table.clear(q)
			head = 1
			tail = 0
			return false
		end
		if mode.Value == 'OneShot' then
			task.delay(math.max(tonumber(time.Value) or 1, 0), function()
				if id ~= seq or not mod.Enabled or meth.Value ~= 'Raknet' or mode.Value ~= 'OneShot' then return end
				if mod.Enabled then mod:Toggle() end
			end)
		end
		return true
	end

	local function rep()
		net = get()
		if not net then return false end
		local ok, val = pcall(function() return net.IncomingReplicationLag end)
		old = ok and val or 0
		seq += 1
		local id = seq
		local dur = math.max(tonumber(time.Value) or 1, 0)
		local lag = mode.Value == 'Toggle' and 1000000 or dur
		if not set(lag) then
			old = nil
			net = nil
			return false
		end
		if mode.Value == 'OneShot' then
			task.delay(dur, function()
				if id ~= seq or not mod.Enabled or meth.Value ~= 'Replication' or mode.Value ~= 'OneShot' then return end
				if mod.Enabled then mod:Toggle() end
			end)
		end
		return true
	end

	local function start()
		ctx.network:claim('LagSwitch', stop)
		if meth.Value == 'Replication' then return rep() end
		return rak()
	end

	local function fail()
		stop()
		if meth.Value == 'Raknet' then notice() else
			ctx.vape:CreateNotification('LagSwitch', 'Local replication lag is unavailable on this executor.', 6, 'alert')
		end
		task.defer(function()
			if mod.Enabled then mod:Toggle() end
		end)
	end

	mod = ctx:module('blatant', {
		name = 'LagSwitch',
		tooltip = 'Temporarily stalls network traffic using Raknet or local replication lag.',
		extratext = function()
			if meth then return meth.Value end
			return 'Raknet'
		end,
		func = function(on)
			if on then
				if meth.Value == 'Raknet' and not ready() then
					fail()
					return
				end
				if not start() then fail() end
			else
				stop()
			end
		end
	})

	meth = mod:CreateDropdown({
		Name = 'Method',
		List = {'Raknet', 'Replication'},
		Default = 'Raknet',
		Function = function(val)
			if not mod.Enabled then
				
				return
			end
			stop()
			if val == 'Raknet' and not ready() then
				fail()
				return
			end
			if not start() then fail() end
		end
	})

	mode = mod:CreateDropdown({
		Name = 'Mode',
		List = {'OneShot', 'Toggle'},
		Default = 'OneShot',
		Function = function(val)
			if time then ctx.vapeapi:setvisible(time, val == 'OneShot') end
			if not mod.Enabled then return end
			stop()
			if meth.Value == 'Raknet' and not ready() then
				fail()
				return
			end
			if not start() then fail() end
		end
	})

	time = mod:CreateSlider({
		Name = 'Time',
		Min = 0.1,
		Max = 10,
		Default = 1,
		Decimal = 10,
		Suffix = 's'
	})

	ctx.vapeapi:setvisible(time, mode.Value == 'OneShot')

	ctx:clean(stop)
end
]==]
sources['src/modules/blatant/manifest.lua'] = [==[
return {
	files = {
		'fakelag.lua',
		'lagswitch.lua'
	}
}
]==]
sources['src/modules/combat/magicbullet.lua'] = [==[
return function(ctx)
	if ctx.frontlines then return ctx.loader:run('core/frontlines-magic.lua')(ctx) end
	local mod
	local targets
	local mode
	local method
	local hook
	local ignored
	local range
	local chance
	local part
	local fix
	local wall
	local circle
	local color
	local alpha
	local fill
	local draw
	local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local info = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local rng = Random.new()
	local input = game:GetService('UserInputService')
	local run = game:GetService('RunService')
	local players = game:GetService('Players')
	local white = RaycastParams.new()
	white.FilterType = Enum.RaycastFilterType.Include
	local silent
	local resume = false
	local active
	local err
	local last
	local stamp = 0
	local sig
	local clock = 0
	local lock = 0
	local funcs = {}
	local temp = Instance.new('Camera')
	local cameras = {
		basecamera = true,
		camerainput = true,
		cameramodule = true,
		camerascript = true,
		camerascriptnew = true,
		cameratogglestatecontroller = true,
		camerautils = true,
		classiccamera = true,
		clicktomovecontroller = true,
		controlmodule = true,
		controlscript = true,
		invisicam = true,
		legacycamera = true,
		mouselockcontroller = true,
		orbitalcamera = true,
		popper = true,
		poppercam = true,
		shiftlockcontroller = true,
		shouldercamera = true,
		transparencycontroller = true,
		vehiclecamera = true,
		vrcamera = true,
		zoomcontroller = true
	}
	local tokens = {
		'camera',
		'camcontroller',
		'clicktomove',
		'controlmodule',
		'controlscript',
		'firstperson',
		'invisicam',
		'mouselock',
		'occlusion',
		'popper',
		'shiftlock',
		'shouldercam',
		'spectat',
		'thirdperson',
		'transparencycontroller',
		'viewcontroller',
		'zoomcontroller'
	}

	local function get(obj, key)
		if obj == nil then return end
		local ok, val = pcall(function() return obj[key] end)
		if ok and type(val) == 'function' then return val end
	end

	local new = get(Ray, 'new')
	local rc = get(workspace, 'Raycast')
	local fr = get(workspace, 'FindPartOnRay')
	local fi = get(workspace, 'FindPartOnRayWithIgnoreList')
	local fw = get(workspace, 'FindPartOnRayWithWhitelist')
	local sr = get(temp, 'ScreenPointToRay')
	local vr = get(temp, 'ViewportPointToRay')

	local function mouse()
		local cam = workspace.CurrentCamera
		if input.TouchEnabled and cam then return cam.ViewportSize / 2 end
		return input:GetMouseLocation()
	end

	local function erase()
		if not draw then return end
		pcall(function() draw.Visible = false end)
		pcall(function() draw:Remove() end)
		draw = nil
	end

	local function paint()
		if not draw then return end
		local show = mod and mod.Enabled and circle and circle.Enabled and mode and mode.Value == 'Mouse'
		pcall(function()
			draw.Visible = show == true
			draw.Position = mouse()
			draw.Radius = range and range.Value or 150
			draw.Filled = fill and fill.Enabled == true or false
			draw.Color = Color3.fromHSV(color and color.Hue or 0, color and color.Sat or 0, color and color.Value or 1)
			draw.Transparency = 1 - (alpha and alpha.Value or 0.5)
		end)
	end

	local function build()
		erase()
		if not circle or not circle.Enabled or not Drawing or type(Drawing.new) ~= 'function' then return end
		local ok, obj = pcall(Drawing.new, 'Circle')
		if not ok or not obj then return end
		draw = obj
		pcall(function()
			obj.NumSides = 100
			obj.Thickness = 1
		end)
		paint()
	end

	local function caller()
		if type(getcallingscript) ~= 'function' then return end
		local ok, val = pcall(getcallingscript)
		return ok and val or nil
	end

	local function camera(obj)
		if typeof(obj) ~= 'Instance' then return false end
		local cur = obj
		for _ = 1, 20 do
			if not cur or cur == game then break end
			local text = tostring(cur.Name or ''):lower()
			if cameras[text] then return true end
			for _, token in ipairs(tokens) do
				if text:find(token, 1, true) then return true end
			end
			cur = cur.Parent
		end
		return false
	end

	local function near(a, b, dist)
		return typeof(a) == 'Vector3' and typeof(b) == 'Vector3' and (a - b).Magnitude <= dist
	end

	local function close(origin)
		if typeof(origin) ~= 'Vector3' then return false end
		local cam = workspace.CurrentCamera
		if cam and near(origin, cam.CFrame.Position, 96) then return true end
		local plr = players.LocalPlayer
		local char = plr and plr.Character
		if not char then return false end
		local root = char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
		local head = char:FindFirstChild('Head')
		if root and root:IsA('BasePart') and near(origin, root.Position, 96) then return true end
		if head and head:IsA('BasePart') and near(origin, head.Position, 96) then return true end
		local tool = char:FindFirstChildWhichIsA('Tool')
		local handle = tool and tool:FindFirstChild('Handle', true)
		return handle and handle:IsA('BasePart') and near(origin, handle.Position, 96) or false
	end

	local function subject(cam)
		if not cam then return end
		local sub = cam.CameraSubject
		if typeof(sub) ~= 'Instance' then return end
		local ok, pos = pcall(function() return sub.Position end)
		if ok and typeof(pos) == 'Vector3' then return pos end
		local root
		ok, root = pcall(function() return sub.RootPart end)
		if ok and typeof(root) == 'Instance' then
			ok, pos = pcall(function() return root.Position end)
			if ok and typeof(pos) == 'Vector3' then return pos end
		end
		ok, root = pcall(function() return sub.PrimaryPart end)
		if ok and typeof(root) == 'Instance' then
			ok, pos = pcall(function() return root.Position end)
			if ok and typeof(pos) == 'Vector3' then return pos end
		end
	end

	local function guard(origin, dir)
		if not fix or fix.Enabled ~= true then return false end
		if camera(caller()) then return true end
		if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return false end
		local len = dir.Magnitude
		if len <= 0.001 then return true end
		local cam = workspace.CurrentCamera
		if not cam then return false end
		local unit = dir / len
		local pos = cam.CFrame.Position
		local focus = cam.Focus.Position
		local sub = subject(cam)
		local char = type(lib) == 'table' and lib.character
		local root = type(char) == 'table' and (char.RootPart or char.HumanoidRootPart)
		local head = type(char) == 'table' and char.Head
		local rpos = typeof(root) == 'Instance' and root:IsA('BasePart') and root.Position or nil
		local hpos = typeof(head) == 'Instance' and head:IsA('BasePart') and head.Position or nil
		local tail = origin + dir
		local zoom = math.max((pos - focus).Magnitude, sub and (pos - sub).Magnitude or 0, rpos and (pos - rpos).Magnitude or 0)
		local tight = math.clamp((zoom * 0.4) + 1.5, 2.5, 14)
		local short = math.clamp((zoom * 4) + 12, 16, 96)
		if len > short then return false end
		local function pair(a, b)
			if typeof(a) ~= 'Vector3' or typeof(b) ~= 'Vector3' or near(a, b, tight) then return false end
			return near(origin, a, tight) and near(tail, b, tight)
		end
		if pair(focus, pos) or pair(pos, focus) then return true end
		if sub and (pair(sub, pos) or pair(pos, sub) or pair(sub, focus) or pair(focus, sub)) then return true end
		if rpos and (pair(rpos, pos) or pair(pos, rpos) or pair(rpos, focus) or pair(focus, rpos)) then return true end
		local rig = math.max(rpos and hpos and (hpos - rpos).Magnitude + 2 or 0, 4)
		local body = rpos and near(origin, rpos, rig) or hpos and near(origin, hpos, 3)
		if body then
			local to = pos - origin
			if to.Magnitude > 0.25 and unit:Dot(to.Unit) > 0.45 then return true end
			if unit:Dot(-cam.CFrame.LookVector) > 0.7 then return true end
		end
		local anchor = sub or rpos or focus
		if anchor and near(origin, anchor, tight) then
			local to = pos - origin
			if to.Magnitude > 0.25 and unit:Dot(to.Unit) > 0.6 then return true end
		end
		return false
	end

	local function valid(origin, dir, unit)
		if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return false end
		local len = dir.Magnitude
		if len <= 0.001 then return false end
		if not unit and len < 8 then return false end
		if not close(origin) then return false end
		return not guard(origin, dir)
	end

	local function skip()
		if lock > 0 then return true end
		if type(checkcaller) == 'function' then
			local ok, val = pcall(checkcaller)
			if ok and val then return true end
		end
		local obj = caller()
		return obj and ignored and type(ignored.ListEnabled) == 'table' and table.find(ignored.ListEnabled, tostring(obj)) ~= nil or false
	end

	local function piece(ent, name)
		if type(ent) ~= 'table' then return end
		local hit = ent[name]
		if typeof(hit) == 'Instance' and hit:IsA('BasePart') then return hit end
		if name == 'RootPart' then
			hit = ent.HumanoidRootPart
			if typeof(hit) == 'Instance' and hit:IsA('BasePart') then return hit end
		end
		local char = ent.Character
		if typeof(char) ~= 'Instance' then return end
		local real = name == 'RootPart' and 'HumanoidRootPart' or name
		hit = char:FindFirstChild(real) or char:FindFirstChild('Head') or char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
		if typeof(hit) == 'Instance' and hit:IsA('BasePart') then return hit end
		return char:FindFirstChildWhichIsA('BasePart')
	end

	local function target(origin, walls)
		if type(lib) ~= 'table' or lib.isAlive == false or typeof(origin) ~= 'Vector3' then return end
		if rng:NextNumber(0, 100) > (chance and chance.Value or 100) then return end
		local name = part and part.Value or 'Head'
		local fn = lib['Entity'..(mode and mode.Value or 'Mouse')]
		if type(fn) ~= 'function' then return end
		lock += 1
		local ok, ent = pcall(fn, {
			Range = range and range.Value or 150,
			Wallcheck = targets and targets.Walls and targets.Walls.Enabled and (walls or true) or nil,
			Part = name,
			Origin = origin,
			Players = not targets or not targets.Players or targets.Players.Enabled ~= false,
			NPCs = targets and targets.NPCs and targets.NPCs.Enabled == true
		})
		lock -= 1
		if not ok or type(ent) ~= 'table' then return end
		local hit = piece(ent, name)
		if not hit then return end
		if type(info) == 'table' and type(info.Targets) == 'table' then info.Targets[ent] = tick() + 1 end
		return ent, hit
	end

	local function spoof(hit, dir)
		if typeof(hit) ~= 'Instance' or not hit:IsA('BasePart') or typeof(dir) ~= 'Vector3' then return end
		local mag = dir.Magnitude
		if mag <= 0.0001 then return end
		local unit = dir / mag
		local ok, cf, size, pos = pcall(function() return hit.CFrame, hit.Size, hit.Position end)
		if not ok then return end
		local vec = cf:VectorToObjectSpace(unit)
		local half = size * 0.5
		local dist = math.abs(vec.X) * half.X + math.abs(vec.Y) * half.Y + math.abs(vec.Z) * half.Z
		return pos - unit * (dist + 0.05)
	end

	local function cast(origin, dir, scan)
		local ent, hit = target(origin)
		if not ent then return end
		local pos
		if scan and ctx.origin and type(ctx.origin.line) == 'function' then
			local ok, val = pcall(ctx.origin.line, ctx.origin, hit.Position, dir, hit)
			if ok then pos = val end
		end
		pos = pos or spoof(hit, dir)
		if not pos then return end
		return pos, hit
	end

	local hooks = {}
	local order = {'Raycast', 'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Ray'}

	local function raycast(args, scan)
		local origin, dir = args[1], args[2]
		if not valid(origin, dir) then return end
		local pos, hit = cast(origin, dir, scan)
		if not pos then return end
		args[1] = pos
		if wall and wall.Enabled and hit then
			white.FilterDescendantsInstances = {hit}
			pcall(function() white.CollisionGroup = hit.CollisionGroup end)
			args[3] = white
		end
		return true
	end

	local function legacy(args)
		local beam = args[1]
		if typeof(beam) ~= 'Ray' or not valid(beam.Origin, beam.Direction) then return end
		local pos, hit = cast(beam.Origin, beam.Direction)
		if not pos or not new then return end
		if wall and wall.Enabled and hit then
			local norm = beam.Origin - hit.Position
			norm = norm.Magnitude > 0.001 and norm.Unit or Vector3.yAxis
			return true, {hit, hit.Position, norm, hit.Material}
		end
		args[1] = new(pos, beam.Direction)
		return true
	end

	local function screen(beam)
		if typeof(beam) ~= 'Ray' or not valid(beam.Origin, beam.Direction, true) or not new then return end
		local pos = cast(beam.Origin, beam.Direction)
		if pos then return new(pos, beam.Direction) end
	end

	if rc then hooks.Raycast = {Hook = rc, Args = raycast, Meta = 'Raycast', Owner = workspace} end
	if fr and new then hooks.FindPartOnRay = {Hook = fr, Args = legacy, Meta = 'FindPartOnRay', Owner = workspace} end
	if fi and new then hooks.FindPartOnRayWithIgnoreList = {Hook = fi, Args = legacy, Meta = 'FindPartOnRayWithIgnoreList', Owner = workspace} end
	if fw and new then hooks.FindPartOnRayWithWhitelist = {Hook = fw, Args = legacy, Meta = 'FindPartOnRayWithWhitelist', Owner = workspace} end
	if sr and new then hooks.ScreenPointToRay = {Hook = sr, Result = screen, Meta = 'ScreenPointToRay', Class = 'Camera'} end
	if vr and new then hooks.ViewportPointToRay = {Hook = vr, Result = screen, Meta = 'ViewportPointToRay', Class = 'Camera'} end
	if new then
		hooks.Ray = {
			Hook = new,
			NoNamecall = true,
			NoSelf = true,
			Args = function(args)
				local origin, dir = args[1], args[2]
				if not valid(origin, dir) then return end
				local pos = cast(origin, dir)
				if pos then args[1] = pos return true end
			end
		}
	end
	if rc and ctx.origin and type(ctx.origin.line) == 'function' then
		hooks['Origin Scan'] = {Hook = rc, Args = function(args) return raycast(args, true) end, Meta = 'Raycast', Owner = workspace}
	end

	local function apply(data, args)
		if type(data.Args) ~= 'function' then return false end
		lock += 1
		local out = table.pack(pcall(data.Args, args))
		lock -= 1
		if not out[1] then return false end
		return out[2] == true, out[3]
	end

	local function result(data, val)
		if type(data.Result) ~= 'function' then return val, false end
		lock += 1
		local ok, out = pcall(data.Result, val)
		lock -= 1
		if ok and out ~= nil then return out, true end
		return val, false
	end

	local function base(fn, ...)
		lock += 1
		local out = table.pack(pcall(fn, ...))
		lock -= 1
		if not out[1] then error(out[2], 0) end
		return table.unpack(out, 2, out.n)
	end

	local function direct(name, data, use)
		if type(data) ~= 'table' or type(data.Hook) ~= 'function' then return false end
		local rec = {fn = data.Hook, oth = false}
		local function wrap(...)
			if not rec.old then return data.Hook(...) end
			if not mod.Enabled or skip() then return base(rec.old, ...) end
			if data.NoSelf then
				local args = table.pack(...)
				local changed, out = apply(data, args)
				if changed then
					active = name
					if type(out) == 'table' then return table.unpack(out) end
				end
				return base(rec.old, table.unpack(args, 1, args.n))
			end
			local self, args = ..., {select(2, ...)}
			if data.Result then
				local val = base(rec.old, self, table.unpack(args))
				local out, changed = result(data, val)
				if changed then active = name end
				return out
			end
			local changed, out = apply(data, args)
			if changed then
				active = name
				if type(out) == 'table' then return table.unpack(out) end
			end
			return base(rec.old, self, table.unpack(args))
		end
		if use and oth and type(oth.hook) == 'function' then
			local ok, old = pcall(oth.hook, rec.fn, wrap)
			if ok and type(old) == 'function' then
				rec.old = old
				rec.oth = true
				funcs[#funcs + 1] = rec
				return true
			end
		end
		if type(hookfunction) ~= 'function' then return false end
		local ok, old = pcall(hookfunction, rec.fn, wrap)
		if not ok or type(old) ~= 'function' then return false end
		rec.old = old
		funcs[#funcs + 1] = rec
		return true
	end

	local function meta(name, data)
		if type(data) ~= 'table' or type(data.Hook) ~= 'function' or data.NoNamecall then return false end
		if type(hookmetamethod) ~= 'function' or type(getnamecallmethod) ~= 'function' then return false end
		local mt = type(getrawmetatable) == 'function' and getrawmetatable(game) or nil
		local fn = type(mt) == 'table' and mt.__namecall or nil
		if type(fn) ~= 'function' then return false end
		local rec = {fn = fn, meta = true}
		local expect = data.Meta or name
		local old = fn
		local function wrap(self, ...)
			local call = getnamecallmethod()
			if call ~= expect then return old(self, ...) end
			if data.Owner and self ~= data.Owner then return old(self, ...) end
			if data.Class and (typeof(self) ~= 'Instance' or self.ClassName ~= data.Class) then return old(self, ...) end
			if not mod.Enabled or skip() then return base(data.Hook, self, ...) end
			local args = { ... }
			if data.Result then
				local val = base(data.Hook, self, table.unpack(args))
				local out, changed = result(data, val)
				if changed then active = name end
				return out
			end
			local changed, out = apply(data, args)
			if changed then
				active = name
				if type(out) == 'table' then return table.unpack(out) end
			end
			return base(data.Hook, self, table.unpack(args))
		end
		local cb = type(newcclosure) == 'function' and newcclosure(wrap) or wrap
		local ok, val = pcall(hookmetamethod, game, '__namecall', cb)
		if not ok or type(val) ~= 'function' then return false end
		old = val
		rec.old = val
		funcs[#funcs + 1] = rec
		return true
	end

	local function clear()
		for i = #funcs, 1, -1 do
			local rec = funcs[i]
			if rec.meta then
				if type(restorefunction) == 'function' then
					pcall(restorefunction, rec.fn)
				elseif type(hookmetamethod) == 'function' and type(rec.old) == 'function' then
					pcall(hookmetamethod, game, '__namecall', rec.old)
				end
			elseif rec.oth and oth and type(oth.unhook) == 'function' then
				pcall(oth.unhook, rec.fn)
			elseif type(hookfunction) == 'function' and type(rec.old) == 'function' then
				pcall(hookfunction, rec.fn, rec.old)
			elseif type(restorefunction) == 'function' then
				pcall(restorefunction, rec.fn)
			end
			funcs[i] = nil
		end
		if ctx.aim then ctx.aim:stop('magic') end
		active = nil
		lock = 0
		sig = nil
	end

	local function cfg()
		return {
			mode = mode and mode.Value or 'Mouse',
			range = range and range.Value or 150,
			chance = chance and chance.Value or 100,
			head = part and part.Value == 'Head' and 100 or 0,
			part = part and part.Value or 'Head',
			walls = true,
			players = not targets or not targets.Players or targets.Players.Enabled ~= false
		}
	end

	local function token()
		local data = cfg()
		return table.concat({
			method and method.Value or '',
			data.mode,
			tostring(data.range),
			tostring(data.chance),
			data.part,
			tostring(data.players)
		}, '|')
	end

	local function arsenal()
		if not ctx.aim then
			err = 'Actor support is unavailable.'
			return false
		end
		local ok, msg = ctx.aim:start('magic', 'magic', true, cfg())
		if not ok then err = msg return false end
		active = 'Arsenal'
		sig = token()
		return true
	end

	local function install()
		clear()
		err = nil
		local want = method and method.Value
		if want == 'Arsenal' then return arsenal() end
		local data = want and hooks[want]
		if not data then
			err = 'The selected method is unavailable.'
			active = 'Unavailable'
			return false
		end
		local kind = hook and hook.Value or 'Function hook'
		if kind == 'Hookmetamethod' and data.NoNamecall then
			err = 'Hookmetamethod cannot intercept this method.'
			active = 'Unavailable'
			return false
		end
		local ok
		if kind == 'Hookmetamethod' then
			ok = meta(want, data)
		else
			ok = direct(want, data, kind == 'Oth hook')
		end
		if not ok then
			clear()
			err = 'No compatible hook backend is available.'
			active = 'Unavailable'
			return false
		end
		active = want
		return true
	end

	ctx:clean(temp)

	local function notify(msg)
		msg = tostring(msg or 'MagicBullet is unavailable.')
		local now = os.clock()
		if msg == last and now - stamp < 30 then return end
		last = msg
		stamp = now
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'MagicBullet', msg, 6, 'warning')
		end
	end

	local function reload()
		if not mod or not mod.Enabled then return end
		if not install() then notify(err) end
	end

	mod = ctx:module('combat', {
		name = 'MagicBullet',
		autostart = false,
		tooltip = 'Spoofs weapon cast origins',
		extratext = function()
			return active or method and method.Value or ''
		end,
		func = function(on)
			if on then
				paint()
				silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
				resume = type(silent) == 'table' and silent.Enabled == true
				if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				if not install() then notify(err) end
			else
				paint()
				clear()
				if ctx.state ~= 'unloading' and ctx.vape.Loaded ~= nil and resume and type(silent) == 'table' and not silent.Enabled and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				resume = false
			end
		end
	})

	local function make(name, data)
		local fn = mod[name]
		if type(fn) ~= 'function' then return end
		local ok, val = pcall(fn, mod, data)
		if ok then return val end
		ctx.log:add('module', 'MagicBullet', val)
	end

	targets = make('CreateTargets', {Players = true})
	mode = make('CreateDropdown', {
		Name = 'Target Mode',
		List = {'Mouse', 'Position'},
		Default = 'Mouse',
		Function = paint
	})
	local methods = {}
	if ctx.aim and ctx.aim.ars then methods[#methods + 1] = 'Arsenal' end
	for _, name in ipairs(order) do
		if hooks[name] then methods[#methods + 1] = name end
	end
	if hooks['Origin Scan'] then methods[#methods + 1] = 'Origin Scan' end
	local default = ctx.aim and ctx.aim.ars and 'Arsenal' or hooks.Raycast and 'Raycast' or methods[1]
	method = make('CreateDropdown', {
		Name = 'Method',
		List = methods,
		Default = default,
		Function = reload
	})
	hook = make('CreateDropdown', {
		Name = 'Hook',
		List = {'Function hook', 'Hookmetamethod', 'Oth hook'},
		Default = 'Function hook',
		Function = reload
	})
	ignored = make('CreateTextList', {Name = 'Ignored Scripts', Default = {'CameraModule'}})
	fix = make('CreateToggle', {
		Name = 'RayCamFix',
		Default = true,
		Tooltip = 'Skips camera and obstruction casts.'
	})
	wall = make('CreateToggle', {Name = 'Wallbang'})
	range = make('CreateSlider', {
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Suffix = function(v) return mode and mode.Value == 'Mouse' and 'px' or v == 1 and 'stud' or 'studs' end,
		Function = paint
	})
	chance = make('CreateSlider', {Name = 'Hit Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
	part = make('CreateDropdown', {Name = 'Part', List = {'Head', 'RootPart'}, Default = 'Head'})
	circle = make('CreateToggle', {
		Name = 'Range Circle',
		Function = function(on)
			if on then build() else erase() end
			if color and color.Object then color.Object.Visible = on end
			if alpha and alpha.Object then alpha.Object.Visible = on end
			if fill and fill.Object then fill.Object.Visible = on end
		end
	})
	color = make('CreateColorSlider', {
		Name = 'Circle Color',
		Darker = true,
		Visible = false,
		Function = paint
	})
	alpha = make('CreateSlider', {
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Darker = true,
		Visible = false,
		Function = paint
	})
	fill = make('CreateToggle', {
		Name = 'Circle Filled',
		Darker = true,
		Visible = false,
		Function = paint
	})

	ctx:clean(run.RenderStepped:Connect(function()
		paint()
		if not mod.Enabled or not method or method.Value ~= 'Arsenal' then return end
		local now = os.clock()
		if now - clock < 0.25 then return end
		clock = now
		local val = token()
		if val ~= sig then
			sig = val
			arsenal()
		end
	end))
	ctx:clean(erase)
	ctx:clean(clear)
end
]==]
sources['src/modules/combat/manifest.lua'] = [==[
return {
	files = {
		'magicbullet.lua'
	}
}
]==]
sources['src/modules/manifest.lua'] = [==[
return {categories = {'combat', 'blatant'}}
]==]
sources['src/patches/manifest.lua'] = [==[
return {categories = {}}
]==]
return function(vape)
	local existing = vape.Libraries.additions
	if existing and existing.state ~= 'unloaded' then return existing end
	local ctx = {
		name = 'Vape Additions', version = '1.0', state = 'starting', started = os.clock(), vape = vape,
		cfg = {debug = false, strict = true, debounce = 0.35},
		mods = {}, modorder = {}, patchopts = {}, events = {}, layers = {},
		cats = {names = {combat='Combat', blatant='Blatant', render='Render', utility='Utility', world='World', legit='Legit'},
			order = {'combat', 'blatant', 'render', 'utility', 'world', 'legit'}},
		frontlines = vape.Libraries.frontlines,
		loader = {root = 'newvape/additions', games = false, build = 'embedded-1', errors = {}, stats = {compiled = 0}}
	}
	local cache = {}
	function ctx.loader:try(path)
		local source = sources[path]
		if not source then return false, 'No bundled file: '..tostring(path), 'missing' end
		if cache[path] == nil then
			local fn, err = loadstring(source, 'Vape additions/'..path)
			if not fn then return false, err, 'compile' end
			local ok, value = pcall(fn)
			if not ok then return false, value, 'runtime' end
			cache[path] = value
			self.stats.compiled = self.stats.compiled + 1
		end
		return true, cache[path]
	end
	function ctx.loader:run(path)
		local ok, value = self:try(path)
		if not ok then error(value, 0) end
		return value
	end
	local ok, err = pcall(function()
		for _, name in ipairs({'log', 'clean', 'vapeapi', 'storage', 'target', 'profile', 'patch', 'runtime', 'weapon', 'origin', 'aim', 'network'}) do
			ctx.loader:run('core/'..name..'.lua')(ctx)
		end
		ctx:resolvetarget()
		ctx.loader:run('core/config.lua')(ctx)
		ctx.loader:run('core/layers.lua')(ctx)
		ctx:loadlayers()
		assert(ctx.config:capture(), 'Could not capture additional module defaults')
		ctx.config:watch()
		ctx.vapeapi:hook()
		ctx.state = 'ready'
	end)
	if not ok then
		if ctx.unload then pcall(ctx.unload, ctx, 'startup failure') elseif ctx.bin then ctx.bin:run() end
		error(err, 0)
	end
	vape.Libraries.additions = ctx
	local env = (getgenv and getgenv()) or _G
	if env.VapeTweaker == nil then env.VapeTweaker = ctx end
	vape:Clean(function()
		ctx:unload('uninject')
		if vape.Libraries.additions == ctx then vape.Libraries.additions = nil end
	end)
	return ctx
end

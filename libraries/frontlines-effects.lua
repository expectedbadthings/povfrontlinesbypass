-- Asset-free Frontlines impact visuals. One animator, bounded overlap, local-only parts.
return function(vape)
 local runService = game:GetService('RunService')
 local debris = game:GetService('Debris')
 local effects = {}
 local api = {Modes = {'Astral Bloom', 'Supernova', 'Prism Break', 'Aurora', 'Starfall', 'Sakura', 'Love Burst', 'Kitty Pop'}}
 local supported = {}
 for _, name in api.Modes do supported[name] = true end
 local function new(class, props, parent)
  local object = Instance.new(class)
  for key, value in props do object[key] = value end
  object.Parent = parent
  return object
 end
 local function part(parent, color)
  return new('Part', {Size = Vector3.one * 0.05, Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false, Material = Enum.Material.Neon, Color = color}, parent)
 end
 local function shape(parent, x, y, w, h, color, rotation, radius)
  local f = new('Frame', {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = rotation or 0}, parent)
  if radius then new('UICorner', {CornerRadius = UDim.new(radius, 0)}, f) end
  return f
 end
 local function sprite(group, mode, color, size)
  local anchor = part(group, color)
  anchor.Transparency = 1
  local gui = new('BillboardGui', {Size = UDim2.fromScale(size, size), AlwaysOnTop = false, LightInfluence = 0, MaxDistance = 180, Adornee = anchor}, anchor)
  local root = new('Frame', {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, gui)
  if mode == 'Love Burst' then
   shape(root, 0.5, 0.56, 0.45, 0.45, color, 45, 0.1)
   shape(root, 0.34, 0.37, 0.43, 0.43, color, 0, 1)
   shape(root, 0.64, 0.37, 0.43, 0.43, color, 0, 1)
  elseif mode == 'Kitty Pop' then
   local ink = Color3.fromRGB(58, 42, 68)
   shape(root, 0.27, 0.27, 0.28, 0.28, color, 45, 0.08)
   shape(root, 0.73, 0.27, 0.28, 0.28, color, 45, 0.08)
   shape(root, 0.5, 0.53, 0.82, 0.63, color, 0, 0.4)
   shape(root, 0.34, 0.49, 0.055, 0.12, ink, 0, 1)
   shape(root, 0.66, 0.49, 0.055, 0.12, ink, 0, 1)
   shape(root, 0.5, 0.63, 0.07, 0.05, ink, 45, 0.1)
   local blush = Color3.fromRGB(255, 141, 183)
   shape(root, 0.24, 0.61, 0.13, 0.06, blush, 0, 1)
   shape(root, 0.76, 0.61, 0.13, 0.06, blush, 0, 1)
  elseif mode == 'Sakura' then
   shape(root, 0.5, 0.5, 0.42, 0.76, color, 35, 0.5)
   shape(root, 0.46, 0.44, 0.08, 0.32, Color3.new(1, 1, 1), 35, 0.5)
  else
   shape(root, 0.5, 0.5, 0.18, 0.88, color, 0, 0.1)
   shape(root, 0.5, 0.5, 0.88, 0.18, color, 0, 0.1)
   shape(root, 0.5, 0.5, 0.3, 0.3, Color3.new(1, 1, 1), 45, 0.1)
  end
  return anchor, root, root:GetDescendants()
 end
 local function remove(index)
  effects[index].Group:Destroy()
  table.remove(effects, index)
 end
 function api:Play(mode, folder, position, size, lifetime, a, b, quality, kill)
  if not supported[mode] then return false end
  while #effects >= 6 do remove(1) end
  local group = new('Folder', {Name = 'V7_'..mode}, folder)
  local life = math.clamp(lifetime, 0.18, 3)
  local radius = size * (kill and 4.5 or 1.35)
  local count = quality == 'Low' and 7 or quality == 'High' and 18 or 12
  if not kill then count = math.max(5, math.floor(count * 0.65)) end
  local cute = mode == 'Sakura' or mode == 'Love Burst' or mode == 'Kitty Pop'
  if cute then
   a = a:Lerp(Color3.fromRGB(255, 174, 216), 0.65)
   b = b:Lerp(Color3.fromRGB(213, 195, 255), 0.65)
  end
  local updates = {}
  local function animate(fn) table.insert(updates, fn) end
  -- A brief translucent core makes the impact readable without covering the target.
  local core = part(group, a)
  core.Shape = Enum.PartType.Ball
  animate(function(t)
   local p = math.min(t * 2.8, 1)
   core.CFrame = CFrame.new(position)
   core.Size = Vector3.one * math.max(0.03, radius * (0.15 + p * 0.55))
   core.Transparency = 0.68 + p * 0.32
  end)
  -- Ribbons use moving line segments; they rotate and expand rather than just fade.
  local segments = quality == 'Low' and 12 or quality == 'High' and 28 or 18
  local rings = cute and 1 or kill and 3 or 2
  for layer = 1, rings do
   for i = 1, segments do
    local beam = part(group, i % 2 == 0 and a or b)
    animate(function(t)
     local delayed = math.clamp((t - (layer - 1) * 0.08) / (1 - (layer - 1) * 0.08), 0, 1)
     local phase = i / segments * math.pi * 2 + delayed * (layer % 2 == 0 and -2.4 or 2.4)
     local r = radius * (0.1 + (1 - (1 - delayed)^3) * (0.7 + layer * 0.25))
     local tilt = mode == 'Aurora' and 0.9 or mode == 'Astral Bloom' and 0.55 or 0.12
     local function point(angle)
      return position + Vector3.new(math.cos(angle) * r, math.sin(angle + layer) * r * tilt + delayed * radius * 0.25, math.sin(angle) * r)
     end
     local p1, p2 = point(phase), point(phase + math.pi * 2 / segments * 0.88)
     beam.CFrame = CFrame.lookAt((p1 + p2) / 2, p2)
     beam.Size = Vector3.new(math.max(0.012, size * 0.04 * (1 - delayed)), math.max(0.012, size * 0.04), (p2 - p1).Magnitude)
     beam.Transparency = delayed == 0 and 1 or delayed^1.6
    end)
   end
  end
  for i = 1, count do
   local angle = i / count * math.pi * 2
   local color = i % 2 == 0 and a or b
   if mode == 'Prism Break' then color = Color3.fromHSV(i / count, 0.65, 1) end
   local symbolMode = cute and mode or 'Star'
   local anchor, root, faces = sprite(group, symbolMode, color, size * (cute and 0.85 or 0.4) * (kill and 1.4 or 0.8))
   local lift = radius * (0.7 + (i % 3) * 0.28)
   animate(function(t)
    local travel = 1 - (1 - t)^2
    local x = math.cos(angle + t * 0.8) * radius * travel
    local z = math.sin(angle + t * 0.8) * radius * travel
    local y = cute and (lift * t + math.sin(t * math.pi * 2 + i) * size * 0.18) or (lift * math.sin(t * math.pi) - radius * t * 0.2)
    if mode == 'Starfall' then y = radius * (1.6 - t * 2.1) end
    anchor.CFrame = CFrame.new(position + Vector3.new(x, y, z))
    root.Rotation = mode == 'Kitty Pop' and math.sin(t * 6 + i) * 12 or (i * 29 + t * 100)
    local fade = math.clamp((t - 0.45) / 0.55, 0, 1)
    for _, face in faces do if face:IsA('Frame') then face.BackgroundTransparency = fade end end
   end)
  end
  -- Run initial positions before Roblox renders any of the new parts.
  for _, update in updates do update(0) end
  table.insert(effects, {Group = group, Age = 0, Life = life, Updates = updates})
  debris:AddItem(group, life + 0.2)
  return true
 end
 vape:Clean(runService.RenderStepped:Connect(function(dt)
  for i = #effects, 1, -1 do
   local effect = effects[i]
   effect.Age += dt
   if not effect.Group.Parent or effect.Age >= effect.Life then remove(i)
   else for _, update in effect.Updates do update(effect.Age / effect.Life) end end
  end
 end))
 vape:Clean(function() for i = #effects, 1, -1 do remove(i) end end)
 return api
end

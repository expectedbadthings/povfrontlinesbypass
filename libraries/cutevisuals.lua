-- Luau port of the supplied CuteVisuals.java. Minecraft bed events are supplied by the game adapter.
return function(vape, adapter)
 local runService = game:GetService('RunService')
 local debris = game:GetService('Debris')
 local module
 local options = {}
 local folder = Instance.new('Folder')
 folder.Name = 'VapeCuteVisuals'
 folder.Parent = workspace
 local pools = {Hearts = {}, Dots = {}, Burst = {}, Rainbow = {}}
 local caps = {Hearts = 50, Dots = 100, Burst = 200, Rainbow = 5}
 local clock, lastHeart, lastDot, previous = 0, 0, 0, nil
 local unit = 2.5 -- Minecraft blocks to Roblox studs, retaining the source's proportions.
 local colors = {Color3.new(1,.4,.5), Color3.new(1,.6,.4), Color3.new(1,.9,.5), Color3.new(.5,1,.65), Color3.new(.5,.75,1), Color3.new(.6,.5,1), Color3.new(.85,.5,1)}
 local heartColors = {Color3.new(1,.5,.8), Color3.new(1,.3,.6), Color3.new(.9,.4,.9)}
 local dotColors = {Color3.new(1,.45,.7),Color3.new(1,.6,.85),Color3.new(1,.3,.55),Color3.new(1,.75,.95)}
 local function make(class, props, parent)
  local o = Instance.new(class)
  for key, value in props do o[key] = value end
  o.Parent = parent
  return o
 end
 local function clearPool(name)
  for _, particle in pools[name] do particle.Anchor:Destroy() end
  table.clear(pools[name])
 end
 local function clear()
  for name in pools do clearPool(name) end
  folder:ClearAllChildren()
  previous = nil
  clock, lastHeart, lastDot = 0, -1, -1
 end
 local function add(name, particle)
  local pool = pools[name]
  if #pool >= caps[name] then pool[1].Anchor:Destroy(); table.remove(pool, 1) end
  particle.Born = clock
  particle.Seed = math.random() * 100
  table.insert(pool, particle)
  return particle
 end
 local function anchor(position, size)
  local part = make('Part', {Size=Vector3.one*.01, CFrame=CFrame.new(position), Transparency=1, Anchored=true, CanCollide=false, CanTouch=false, CanQuery=false, CastShadow=false}, folder)
  local gui = make('BillboardGui', {Size=UDim2.fromScale(size,size), Adornee=part, AlwaysOnTop=false, LightInfluence=0, MaxDistance=160}, part)
  local root = make('Frame', {BackgroundTransparency=1, Size=UDim2.fromScale(1,1)}, gui)
  return part, gui, root
 end
 local function stroke(root, x1,y1,x2,y2,color,width,opacity)
  local dx,dy=x2-x1,y2-y1
  local line = make('Frame', {AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale((x1+x2)/2,(y1+y2)/2), Size=UDim2.new(math.sqrt(dx*dx+dy*dy),0,0,width), Rotation=math.deg(math.atan2(dy,dx)), BorderSizePixel=0, BackgroundColor3=color, BackgroundTransparency=1-opacity}, root)
  return {Object=line, Opacity=opacity}
 end
 local function geometry(kind)
  local points={}
  local n=kind=='Heart' and 30 or kind=='Star' and 8 or 4
  for i=0,n do
   local a=i/n*math.pi*2
   local x,y
   if kind=='Heart' then
    x=16*math.sin(a)^3
    y=13*math.cos(a)-5*math.cos(2*a)-2*math.cos(3*a)-math.cos(4*a)
   elseif kind=='Star' then
    local r=i%2==0 and 12 or 5
    x,y=math.cos(a-math.pi/2)*r,math.sin(a-math.pi/2)*r
   else x,y=math.sin(a)*8,math.cos(a)*14 end
   table.insert(points,Vector2.new(.5+x/36,.5-y/36))
  end
  return points
 end
 local shapes={Heart=geometry('Heart'),Star=geometry('Star'),Diamond=geometry('Diamond')}
 local function particle(kind,position,size,color)
  local part,gui,root=anchor(position,size*unit*2)
  local lines={}
  if kind=='Dot' then
   for layer=2,0,-1 do
    local o=make('Frame',{AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.55+layer*.16,.55+layer*.16),BackgroundColor3=color,BorderSizePixel=0},root)
    make('UICorner',{CornerRadius=UDim.new(1,0)},o)
    table.insert(lines,{Object=o,Opacity=layer==0 and .9 or .12})
   end
  else
   local points=shapes[kind]
   for i=1,#points-1 do
    local p,q=points[i],points[i+1]
    table.insert(lines,stroke(root,p.X,p.Y,q.X,q.Y,color,4,.12))
    table.insert(lines,stroke(root,p.X,p.Y,q.X,q.Y,color,1.5,.9))
   end
  end
  return {Anchor=part,Gui=gui,Root=root,Lines=lines,Position=position,Size=size*unit*2,Kind=kind}
 end
 local function rainbow(position)
  local part,gui,root=anchor(position,7*unit)
  local lines={}
  for band=1,7 do
   local radius=(3+(band-4)*.15)/7
   for segment=1,30 do
    local a,b=(segment-1)/30*math.pi,segment/30*math.pi
    local color=colors[8-band]
    local line=stroke(root,.5+math.cos(a)*radius,.94-math.sin(a)*radius,.5+math.cos(b)*radius,.94-math.sin(b)*radius,color,options.RainbowWidth.Value,.85)
    line.Segment=segment
    table.insert(lines,line)
    local glow=stroke(root,.5+math.cos(a)*radius,.94-math.sin(a)*radius,.5+math.cos(b)*radius,.94-math.sin(b)*radius,color,options.RainbowWidth.Value+3,.15)
    glow.Segment=segment
    table.insert(lines,glow)
   end
  end
  -- Sparkles at the ends of the rainbow.
  for _,x in {.08,.92} do
   table.insert(lines,stroke(root,x-.02,.94,x+.02,.94,Color3.new(1,1,.8),2,.7))
   table.insert(lines,stroke(root,x,.92,x,.96,Color3.new(1,1,.8),2,.7))
  end
  add('Rainbow',{Anchor=part,Gui=gui,Root=root,Lines=lines,Position=position})
 end
 local function burst(position)
  if not module.Enabled or not position then return end
  if options.Rainbow.Enabled then rainbow(position) end
  if options.Burst.Enabled then
   for i=1,options.BurstCount.Value do
    local angle,phi=math.random()*math.pi*2,math.random()*math.pi*.67-math.pi/6
    local speed=(.8+math.random()*1.2)*options.BurstSpeed.Value*unit
    local kinds={'Heart','Heart','Star','Dot','Diamond'}
    local p=particle(kinds[math.random(1,5)],position,options.BurstSize.Value*(.6+math.random()*.8),colors[(i-1)%7+1])
    p.Velocity=Vector3.new(math.cos(phi)*math.cos(angle)*speed,math.sin(phi)*speed+unit,math.cos(phi)*math.sin(angle)*speed)
    add('Burst',p)
   end
  end
  if options.Sound.Enabled and options.SoundAsset.Value~='' then
   local asset=options.SoundAsset.Value
   if asset:match('^%d+$') then asset='rbxassetid://'..asset end
   local sound=make('Sound',{SoundId=asset,Volume=.5,PlaybackSpeed=1.5},workspace.CurrentCamera)
   sound:Play(); debris:AddItem(sound,6)
  end
 end
 local function fade(t, start, finish)
  return math.clamp(math.min(t/start,(1-t)/(1-finish)),0,1)
 end
 local function update(dt)
  clock+=dt
  local position,moving=adapter.GetPosition()
  if position then
   if previous and (position-previous).Magnitude>40 then previous=nil end
   if not options.Moving.Enabled or moving then
    if options.Hearts.Enabled and clock-lastHeart>=options.HeartsRate.Value/1000 then
     lastHeart=clock
     local a,r=math.random()*math.pi*2,math.random()*1.5*unit
     add('Hearts',particle('Heart',position+Vector3.new(math.cos(a)*r,(.5+math.random()*.5)*unit,math.sin(a)*r),.15*(.6+math.random()*.8),heartColors[math.random(1,3)]))
    end
    if options.Dots.Enabled and previous and clock-lastDot>=options.DotsRate.Value/1000 then
     lastDot=clock
     local p=particle('Dot',previous+Vector3.new((math.random()-.5)*.9*unit,(.3+math.random()*1.2)*unit,(math.random()-.5)*.9*unit),.04*(.5+math.random()),dotColors[math.random(1,4)])
     p.Velocity=Vector3.new((math.random()-.5)*.3,(.3+math.random()*.7)*.3,(math.random()-.5)*.3)*unit
     add('Dots',p)
    end
   end
   previous=position
  else previous=nil end
  for name,pool in pools do
   local lifetime=options[name=='Hearts' and 'HeartsLife' or name=='Dots' and 'DotsLife' or name=='Rainbow' and 'RainbowLife' or 'BurstLife'].Value/1000
   for i=#pool,1,-1 do
    local p=pool[i]
    local age=clock-p.Born
    local t=age/lifetime
    if t>=1 then p.Anchor:Destroy();table.remove(pool,i)
    else
     local alpha=fade(t,name=='Rainbow' and .15 or .1,name=='Dots' and .5 or name=='Burst' and .7 or .6)*options.Opacity.Value/100
     local pos=p.Position
     if name=='Hearts' then
      pos+=Vector3.new(math.sin(age*2+p.Seed)*.1,1.5*t,math.cos(age*1.5+p.Seed)*.1)*unit
      p.Root.Rotation=math.sin(age*2+p.Seed)*15
     elseif name=='Dots' then
      pos+=p.Velocity*age+Vector3.new(math.sin(age*1.5+p.Seed)*.15,0,math.cos(age*1.2+p.Seed)*.15)*unit
      if options.Pulse.Enabled then alpha*=.5+.5*math.sin(age*30+p.Seed) end
     elseif name=='Burst' then
      pos+=p.Velocity*age-Vector3.new(0,1.5*age*age*unit,0)
      p.Root.Rotation=age*40+p.Seed*6
     end
     if p.Size then
      local scale=fade(t,.1,name=='Burst' and .7 or .8)
      p.Gui.Size=UDim2.fromScale(math.max(.001,p.Size*scale),math.max(.001,p.Size*scale))
     end
     p.Anchor.CFrame=CFrame.new(pos)
     for _,line in p.Lines do
      local visible=not line.Segment or line.Segment/30<=math.min((t/.2)^2,1)
      line.Object.BackgroundTransparency=1-(visible and alpha*line.Opacity or 0)
     end
    end
   end
  end
 end
 module=vape.Categories.Render:CreateModule({Name='CuteVisuals',Tooltip='Floating pink hearts, drifting dots, pastel bursts and rainbow celebrations. Ported from CuteVisuals.java.',Function=function(enabled)
  clear()
  if enabled then
   module:Clean(runService.RenderStepped:Connect(update))
   if adapter.ConnectBurst then adapter.ConnectBurst(module,burst) end
  end
 end})
 local function toggle(key,name,default,pool)
  options[key]=module:CreateToggle({Name=name,Default=default,Function=function(on)if not on and pool then clearPool(pool)end end})
 end
 local function slider(key,name,default,min,max,decimal,suffix)
  options[key]=module:CreateSlider({Name=name,Default=default,Min=min,Max=max,Decimal=decimal or 1,Suffix=suffix})
 end
 toggle('Hearts','Hearts',true,'Hearts')
 slider('HeartsRate','Hearts Spawn Rate',200,50,500,1,'ms')
 slider('HeartsLife','Hearts Lifetime',1500,500,4000,1,'ms')
 toggle('Dots','Dots',true,'Dots')
 slider('DotsRate','Dots Spawn Rate',100,20,200,1,'ms')
 slider('DotsLife','Dots Lifetime',1500,500,5000,1,'ms')
 toggle('Pulse','Pulse',false)
 toggle('Moving','Only While Moving',true)
 slider('Opacity','Opacity',85,0,100,1,'%')
 toggle('Burst','Kill Burst',true,'Burst')
 slider('BurstCount','Burst Count',20,5,40)
 slider('BurstSize','Burst Size',.2,.05,.6,100)
 slider('BurstSpeed','Burst Speed',2.5,.5,7,10)
 slider('BurstLife','Burst Lifetime',1500,500,3000,1,'ms')
 toggle('Rainbow','Rainbow',true,'Rainbow')
 slider('RainbowWidth','Rainbow Line Width',5,1,12)
 slider('RainbowLife','Rainbow Duration',3000,1000,6000,1,'ms')
 toggle('Sound','Burst Sound',false)
 options.SoundAsset=module:CreateTextBox({Name='Sound Asset',Placeholder='Roblox sound asset ID',Tooltip='Minecraft orb/level-up audio is not a Roblox asset; supply a sound ID.'})
 module:CreateButton({Name='Preview Burst',Function=function()if module.Enabled then local p=adapter.GetPosition();burst(p)end end})
 module.EmitBurst=burst
 vape:Clean(function()clear();folder:Destroy()end)
 return module
end

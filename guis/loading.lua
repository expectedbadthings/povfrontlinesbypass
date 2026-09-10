-- TenacityForRoblox startup experience.
-- Loader uses the shipped Tenacity splash art and icon glyph font.
local TweenService = game:GetService('TweenService')
local Players = game:GetService('Players')
local HttpService = game:GetService('HttpService')

local screen = {Value = 0, Tweens = {}, Started = os.clock(), StepThresholds = {0.08, 0.28, 0.62, 0.98}}

local function create(class, parent, props)
    local object = Instance.new(class)
    for key, value in props do object[key] = value end
    object.Parent = parent
    return object
end

local function asset(name)
    if not getcustomasset then return '' end
    local path = 'tenacity/assets/tenacity/'..name
    local runtime = shared.TenacityRuntime
    if runtime then
        local ok, value = pcall(runtime.Read, path, getcustomasset)
        if ok and value then return value end
    end
    local ok, value = pcall(function()
        if isfile and isfile(path) then return getcustomasset(path) end
        return ''
    end)
    return ok and value or ''
end

local function loadFont(assetName, familyName, weight)
    if not (getcustomasset and writefile) then return nil end
    local fontAsset = asset(assetName)
    if fontAsset == '' then return nil end
    local jsonPath = 'tenacity/assets/'..familyName..'.font.json'
    local ok = pcall(writefile, jsonPath, HttpService:JSONEncode({
        name = familyName,
        faces = {{name = 'Regular', weight = weight or 400, style = 'normal', assetId = fontAsset}}
    }))
    if not ok then return nil end
    local family = asset and getcustomasset(jsonPath) or ''
    if family == '' then return nil end
    local worked, result = pcall(function()
        return Font.new(family, weight == 700 and Enum.FontWeight.Bold or Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    end)
    return worked and result or nil
end

local function tween(owner, object, info, goal, key)
    if key and owner.Tweens[key] then owner.Tweens[key]:Cancel() end
    local motion = TweenService:Create(object, info, goal)
    if key then owner.Tweens[key] = motion else table.insert(owner.Tweens, motion) end
    motion:Play()
    return motion
end

function screen:SetTheme() end
function screen:WaitForMinimumDisplay() end

function screen:UpdateSteps()
    if not self.Steps then return end
    for index, step in self.Steps do
        local unlocked = self.Value >= (self.StepThresholds[index] or 1)
        step.Label.TextColor3 = unlocked and Color3.new(1, 1, 1) or Color3.fromRGB(148, 151, 164)
        step.Icon.TextColor3 = unlocked and Color3.new(1, 1, 1) or Color3.fromRGB(148, 151, 164)
        tween(self, step.Frame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            BackgroundTransparency = unlocked and 0.16 or 0.6
        }, 'Step'..index)
        tween(self, step.Stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Transparency = unlocked and 0.58 or 0.82
        }, 'StepStroke'..index)
    end
end

function screen:SetLoadingProgress(value, message)
    if not self.LoadingScreen then return end
    if type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge then
        self.Value = math.max(self.Value, math.clamp(value, 0, 1))
        tween(self, self.Progress, TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.fromScale(self.Value, 1)
        }, 'Progress')
        self.Percent.Text = string.format('%02d%%', math.floor(self.Value * 100 + 0.5))
        self.Stage.Text = self.Value < .24 and 'BOOTSTRAP' or self.Value < .55 and 'INTERFACE' or self.Value < .86 and 'MODULES' or 'READY'
        self:UpdateSteps()
    end
    if message then self.Status.Text = tostring(message) end
end

function screen:HideLoadingScreen(immediate)
    local gui = self.LoadingScreen
    if not gui then return end
    self.LoadingScreen = nil
    if shared.TenacityLoading == self then shared.TenacityLoading = nil end
    if immediate then gui:Destroy(); return end

    local group = self.Root
    tween(self, group, TweenInfo.new(.34, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        GroupTransparency = 1,
        Position = UDim2.fromOffset(0, -18)
    }, 'Exit')
    task.delay(.38, function() if gui.Parent then gui:Destroy() end end)
end

function screen:ShowLoadingScreen()
    self:HideLoadingScreen(true)
    local parent = Players.LocalPlayer:WaitForChild('PlayerGui')
    local old = parent:FindFirstChild('TenacityLoadingScreen')
    if old then old:Destroy() end

    self.TitleFont = loadFont('tenacity-bold.ttf', 'TenacityLoaderBold', 700) or Font.fromEnum(Enum.Font.GothamBold)
    self.BodyFont = loadFont('tenacity.ttf', 'TenacityLoaderRegular', 400) or Font.fromEnum(Enum.Font.Gotham)
    self.IconFont = loadFont('icon.ttf', 'TenacityLoaderIcon', 400)

    local gui = create('ScreenGui', parent, {
        Name = 'TenacityLoadingScreen', ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 1000000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })
    self.LoadingScreen = gui
    shared.TenacityLoading = self

    local root = create('CanvasGroup', gui, {
        Name = 'Experience', BackgroundColor3 = Color3.fromRGB(16, 17, 22), BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), GroupTransparency = 1
    })
    self.Root = root

    local splash = asset('splashscreen.png')
    if splash ~= '' then
        create('ImageLabel', root, {
            Name = 'Splash', BackgroundTransparency = 1, Image = splash, Size = UDim2.fromScale(1, 1),
            ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0
        })
    end

    create('Frame', root, {
        BackgroundColor3 = Color3.fromRGB(5, 7, 11), BackgroundTransparency = 0.34, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1)
    })
    local vignette = create('Frame', root, {
        BackgroundColor3 = Color3.fromRGB(9, 10, 15), BackgroundTransparency = 0.18, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1)
    })
    create('UIGradient', vignette, {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 16, 21)),
            ColorSequenceKeypoint.new(0.38, Color3.fromRGB(16, 17, 22)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 17, 23))
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.42),
            NumberSequenceKeypoint.new(0.42, 0.68),
            NumberSequenceKeypoint.new(1, 0.42)
        })
    })

    local card = create('Frame', root, {
        Name = 'LoaderDock', AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 52, 1, -48),
        Size = UDim2.fromOffset(590, 286), BackgroundColor3 = Color3.fromRGB(18, 20, 26),
        BackgroundTransparency = 0.22, BorderSizePixel = 0
    })
    create('UICorner', card, {CornerRadius = UDim.new(0, 20)})
    local cardStroke = create('UIStroke', card, {Color = Color3.new(1, 1, 1), Transparency = 0.78, Thickness = 1})
    create('UIGradient', cardStroke, {
        Rotation = 0,
        Color = ColorSequence.new(Color3.fromRGB(74, 177, 247), Color3.fromRGB(238, 59, 196))
    })

    local logoAsset = asset('modernlogobigger.png')
    if logoAsset ~= '' then
        create('ImageLabel', card, {
            BackgroundTransparency = 1, Image = logoAsset, Position = UDim2.fromOffset(22, 22),
            Size = UDim2.fromOffset(54, 54), ScaleType = Enum.ScaleType.Fit
        })
    end

    local title = create('TextLabel', card, {
        BackgroundTransparency = 1, Text = 'TENACITY', Position = UDim2.fromOffset(88, 20), Size = UDim2.fromOffset(320, 34),
        TextColor3 = Color3.new(1, 1, 1), TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = self.TitleFont
    })
    local subtitle = create('TextLabel', card, {
        BackgroundTransparency = 1, Text = 'FOR ROBLOX  /  expectedbadthings/TenacityForRoblox', Position = UDim2.fromOffset(90, 52), Size = UDim2.fromOffset(420, 18),
        TextColor3 = Color3.fromRGB(183, 187, 197), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = self.BodyFont
    })

    local topRule = create('Frame', card, {Position = UDim2.fromOffset(22, 88), Size = UDim2.fromOffset(546, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.88, BorderSizePixel = 0})

    local stage = create('TextLabel', card, {
        BackgroundTransparency = 1, Text = 'BOOTSTRAP', Position = UDim2.fromOffset(24, 104), Size = UDim2.fromOffset(160, 20),
        TextColor3 = Color3.fromRGB(126, 130, 143), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = self.TitleFont
    })
    self.Stage = stage
    local percent = create('TextLabel', card, {
        BackgroundTransparency = 1, Text = '00%', Position = UDim2.new(1, -82, 0, 100), Size = UDim2.fromOffset(56, 24),
        TextColor3 = Color3.new(1, 1, 1), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right,
        FontFace = self.TitleFont
    })
    self.Percent = percent

    local status = create('TextLabel', card, {
        BackgroundTransparency = 1, Text = 'Starting Tenacity', Position = UDim2.fromOffset(24, 128), Size = UDim2.fromOffset(542, 24),
        TextColor3 = Color3.fromRGB(233, 235, 240), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = self.BodyFont, TextTruncate = Enum.TextTruncate.AtEnd
    })
    self.Status = status

    local track = create('Frame', card, {Position = UDim2.fromOffset(24, 166), Size = UDim2.fromOffset(542, 8), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.88, BorderSizePixel = 0})
    create('UICorner', track, {CornerRadius = UDim.new(1, 0)})
    local progress = create('Frame', track, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0})
    create('UICorner', progress, {CornerRadius = UDim.new(1, 0)})
    local grad = create('UIGradient', progress, {Color = ColorSequence.new(Color3.fromRGB(74, 177, 247), Color3.fromRGB(238, 59, 196))})
    self.Progress = progress

    local steps = {
        {'h', 'BOOTSTRAP'},
        {'m', 'INTERFACE'},
        {'g', 'MODULES'},
        {'o', 'READY'}
    }
    self.Steps = {}
    for index, info in ipairs(steps) do
        local x = 24 + (index - 1) * 136
        local pill = create('Frame', card, {
            BackgroundColor3 = Color3.fromRGB(35, 38, 46), BackgroundTransparency = 0.6, BorderSizePixel = 0,
            Position = UDim2.fromOffset(x, 188), Size = UDim2.fromOffset(126, 34)
        })
        create('UICorner', pill, {CornerRadius = UDim.new(0, 10)})
        local stroke = create('UIStroke', pill, {Color = Color3.new(1, 1, 1), Transparency = 0.82, Thickness = 1})
        create('UIGradient', stroke, {Color = ColorSequence.new(Color3.fromRGB(74, 177, 247), Color3.fromRGB(238, 59, 196))})
        local icon = create('TextLabel', pill, {
            BackgroundTransparency = 1, Text = info[1], Position = UDim2.fromOffset(10, 5), Size = UDim2.fromOffset(24, 24),
            TextColor3 = Color3.fromRGB(148, 151, 164), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center,
            FontFace = self.IconFont or self.TitleFont
        })
        local caption = create('TextLabel', pill, {
            BackgroundTransparency = 1, Text = info[2], Position = UDim2.fromOffset(36, 0), Size = UDim2.fromOffset(82, 34),
            TextColor3 = Color3.fromRGB(148, 151, 164), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
            FontFace = self.TitleFont
        })
        self.Steps[index] = {Frame = pill, Stroke = stroke, Icon = icon, Label = caption}
    end

    local hintIcon = create('TextLabel', card, {
        BackgroundTransparency = 1, Text = 'B', Position = UDim2.new(1, -180, 1, -38), Size = UDim2.fromOffset(18, 18),
        TextColor3 = Color3.fromRGB(164, 168, 179), TextSize = 14, FontFace = self.IconFont or self.TitleFont
    })
    local hint = create('TextLabel', card, {
        BackgroundTransparency = 1, Text = 'Press RSHIFT to open the ClickGUI', Position = UDim2.new(1, -162, 1, -40), Size = UDim2.fromOffset(144, 20),
        TextColor3 = Color3.fromRGB(126, 126, 136), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = self.BodyFont
    })
    local repo = create('TextLabel', card, {
        BackgroundTransparency = 1, Text = 'Bootstrap cache: tenacity/', Position = UDim2.fromOffset(24, 246), Size = UDim2.fromOffset(220, 20),
        TextColor3 = Color3.fromRGB(126, 126, 136), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = self.BodyFont
    })

    task.spawn(function()
        local t = 0
        while gui.Parent and self.LoadingScreen == gui do
            t = (t + .004) % 1
            grad.Offset = Vector2.new(math.sin(t * math.pi * 2) * .25, 0)
            task.wait()
        end
    end)

    self:UpdateSteps()
    root.Position = UDim2.fromOffset(0, 12)
    tween(self, root, TweenInfo.new(.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)}, 'Enter')
    gui.Destroying:Connect(function()
        if self.LoadingScreen == gui then self.LoadingScreen = nil end
        if shared.TenacityLoading == self then shared.TenacityLoading = nil end
    end)
end

local ok, err = pcall(screen.ShowLoadingScreen, screen)
if not ok then
    screen:HideLoadingScreen(true)
    warn('[Tenacity] Loading UI unavailable: '..tostring(err))
end
return screen

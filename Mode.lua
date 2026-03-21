local ModeSelector = {}
ModeSelector.__index = ModeSelector

local Players = cloneref(game:GetService("Players"))
local TweenService = cloneref(game:GetService("TweenService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local HttpService = cloneref(game:GetService("HttpService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

local activeInstances = {}
local fontDataLoaded = false
local customFont = nil
local globalModeStorage = {} -- Global storage for modes by button ID

local function setupFont()
    if fontDataLoaded then return customFont end
    
    local fontData = {
        name = "Tahoma",
        url = "https://github.com/k0nkx/UI-Lib-Tuff/raw/refs/heads/main/Windows-XP-Tahoma.ttf"
    }
    
    if not isfile(fontData.name .. ".ttf") then
        writefile(fontData.name .. ".ttf", game:HttpGet(fontData.url))
    end
    
    if not isfile(fontData.name .. ".font") then
        local fontConfig = {
            name = fontData.name,
            faces = { { name = "Regular", weight = 400, style = "normal", assetId = getcustomasset(fontData.name .. ".ttf") } }
        }
        writefile(fontData.name .. ".font", HttpService:JSONEncode(fontConfig))
    end
    
    customFont = Font.new(getcustomasset(fontData.name .. ".font"), Enum.FontWeight.Regular)
    fontDataLoaded = true
    return customFont
end

local function getParent()
    if syn and syn.protect_gui then
        return CoreGui
    elseif gethui then
        return gethui()
    else
        return CoreGui
    end
end

function ModeSelector.new(options)
    local self = setmetatable({}, ModeSelector)
    
    self.options = options or {}
    self.modes = {"Always", "Toggle", "Hold"}
    self.currentButtonId = options.buttonId or 1
    
    if globalModeStorage[self.currentButtonId] then
        self.currentMode = globalModeStorage[self.currentButtonId]
    else
        self.currentMode = self.modes[1]
    end
    
    self.isOpen = false
    self.connections = {}
    self.objects = {}
    self.callbacks = {
        onModeChanged = self.options.onModeChanged or function() end,
        onOpen = self.options.onOpen or function() end,
        onClose = self.options.onClose or function() end
    }
    
    self:createUI()
    
    return self
end

function ModeSelector:createUI()
    setupFont()
    
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "ModeSelector_" .. HttpService:GenerateGUID(false):sub(1, 8)
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.Parent = getParent()
    
    if syn and syn.protect_gui then syn.protect_gui(self.ScreenGui) end
    table.insert(self.objects, self.ScreenGui)
    
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Size = UDim2.new(0, 90, 0, 115)
    self.MainFrame.BackgroundColor3 = Color3.fromRGB(33, 33, 33)
    self.MainFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
    self.MainFrame.BorderSizePixel = 1
    self.MainFrame.Parent = self.ScreenGui
    self.MainFrame.Visible = false
    
    self.TopBar = Instance.new("Frame")
    self.TopBar.Size = UDim2.new(1, 0, 0, 1)
    self.TopBar.BackgroundColor3 = Color3.fromRGB(45, 125, 220)
    self.TopBar.BorderSizePixel = 0
    self.TopBar.Parent = self.MainFrame
    
    self.Title = Instance.new("TextLabel")
    self.Title.Text = self.options.title or "Mode"
    self.Title.Size = UDim2.new(1, 0, 0, 22)
    self.Title.Position = UDim2.new(0, 4, 0, 1)
    self.Title.BackgroundTransparency = 1
    self.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.Title.TextXAlignment = Enum.TextXAlignment.Left
    self.Title.TextSize = 15
    self.Title.Font = Enum.Font.SourceSans
    self.Title.Parent = self.MainFrame
    
    self.Content = Instance.new("Frame")
    self.Content.Size = UDim2.new(0.92, 0, 0, 80)
    self.Content.Position = UDim2.new(0.04, 0, 0, 25)
    self.Content.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    self.Content.BorderColor3 = Color3.fromRGB(0, 0, 0)
    self.Content.BorderSizePixel = 1
    self.Content.Parent = self.MainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(55, 55, 55)
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.LineJoinMode = Enum.LineJoinMode.Miter
    stroke.Parent = self.Content
    
    self.BackgroundCatcher = Instance.new("Frame")
    self.BackgroundCatcher.Size = UDim2.new(1, 0, 1, 0)
    self.BackgroundCatcher.Position = UDim2.new(0, 0, 0, 0)
    self.BackgroundCatcher.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    self.BackgroundCatcher.BackgroundTransparency = 1
    self.BackgroundCatcher.Visible = false
    self.BackgroundCatcher.Parent = self.ScreenGui
    
    self.buttons = {}
    self.positions = {5, 30, 55}
    self.colors = {off = Color3.fromRGB(35, 35, 35), on = Color3.fromRGB(45, 55, 75)}
    self.tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    self:createButtons()
    self:setupDragging()
    self:setupClickOutside()
end

function ModeSelector:createButtons()
    local function tween(obj, props)
        TweenService:Create(obj, self.tweenInfo, props):Play()
    end
    
    local function updateColors()
        for i, btn in ipairs(self.buttons) do
            btn.BackgroundColor3 = i == 1 and self.colors.on or self.colors.off
        end
    end
    
    for i, modeName in ipairs(self.modes) do
        local btn = Instance.new("TextButton")
        btn.Text = ""
        btn.Size = UDim2.new(0.9, 0, 0, 20)
        btn.Position = UDim2.new(0.05, 0, 0, self.positions[i])
        btn.BackgroundColor3 = self.colors.off
        btn.BorderColor3 = Color3.fromRGB(50, 50, 50)
        btn.BorderSizePixel = 1
        btn.AutoButtonColor = false
        btn.Parent = self.Content
        
        local label = Instance.new("TextLabel")
        label.Text = modeName
        label.Size = UDim2.new(1, -20, 1, 0)
        label.Position = UDim2.new(0, 5, 0, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextSize = 12
        label.FontFace = customFont or Enum.Font.SourceSans
        label.Parent = btn
        
        local dash = Instance.new("TextLabel")
        dash.Text = "-"
        dash.Size = UDim2.new(0, 15, 1, 0)
        dash.Position = UDim2.new(1, -15, -0.05, 0)
        dash.BackgroundTransparency = 1
        dash.TextColor3 = Color3.fromRGB(180, 180, 180)
        dash.TextSize = 16
        dash.FontFace = customFont or Enum.Font.SourceSans
        dash.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            local clickedIndex = table.find(self.buttons, btn)
            if not clickedIndex or clickedIndex == 1 then return end
            local topBtn = self.buttons[1]
            tween(btn, {Position = UDim2.new(0.05, 0, 0, self.positions[1])})
            tween(topBtn, {Position = UDim2.new(0.05, 0, 0, self.positions[clickedIndex])})
            self.buttons[1], self.buttons[clickedIndex] = self.buttons[clickedIndex], self.buttons[1]
            updateColors()
            
            self.currentMode = self.buttons[1].TextLabel.Text
            globalModeStorage[self.currentButtonId] = self.currentMode
            self.callbacks.onModeChanged(self.currentMode)
        end)
        
        table.insert(self.buttons, btn)
    end
    
    if self.currentMode ~= self.modes[1] then
        local targetIndex = table.find(self.modes, self.currentMode)
        if targetIndex then
            local targetBtn = self.buttons[targetIndex]
            local topBtn = self.buttons[1]
            
            self.buttons[1], self.buttons[targetIndex] = targetBtn, topBtn
            
            targetBtn.Position = UDim2.new(0.05, 0, 0, self.positions[1])
            topBtn.Position = UDim2.new(0.05, 0, 0, self.positions[targetIndex])
        end
    end
    
    updateColors()
end

function ModeSelector:setupDragging()
    local dragging, dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        self.MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
    
    self.Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    self.Title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

function ModeSelector:setupClickOutside()
    local function onInputBegan(input, gameProcessed)
        if gameProcessed then return end
        if not self.isOpen then return end
        
        local mousePos = UserInputService:GetMouseLocation()
        local absolutePos = self.MainFrame.AbsolutePosition
        local absoluteSize = self.MainFrame.AbsoluteSize
        
        local isInside = mousePos.X >= absolutePos.X and mousePos.X <= absolutePos.X + absoluteSize.X and
                         mousePos.Y >= absolutePos.Y and mousePos.Y <= absolutePos.Y + absoluteSize.Y
        
        if not isInside then
            self:Close()
        end
    end
    
    table.insert(self.connections, UserInputService.InputBegan:Connect(onInputBegan))
end

function ModeSelector:Open()
    if self.isOpen then return end
    self.isOpen = true
    
    local mousePos = UserInputService:GetMouseLocation()
    self.MainFrame.Position = UDim2.new(0, mousePos.X - -30, 0, mousePos.Y + 45)
    
    self.MainFrame.Visible = true
    self.BackgroundCatcher.Visible = true
    self.callbacks.onOpen()
end

function ModeSelector:Close()
    if not self.isOpen then return end
    self.isOpen = false
    self.MainFrame.Visible = false
    self.BackgroundCatcher.Visible = false
    self.callbacks.onClose()
end

function ModeSelector:Toggle()
    if self.isOpen then
        self:Close()
    else
        self:Open()
    end
end

function ModeSelector:GetCurrentMode()
    return self.currentMode
end

function ModeSelector:SetMode(mode)
    local modeIndex = table.find(self.modes, mode)
    if not modeIndex then return false end
    
    local targetButton = nil
    local targetPos = nil
    for i, btn in ipairs(self.buttons) do
        if btn.TextLabel.Text == mode then
            targetButton = btn
            targetPos = i
            break
        end
    end
    
    if not targetButton or targetPos == 1 then return false end
    
    local topBtn = self.buttons[1]
    local tween = function(obj, props)
        TweenService:Create(obj, self.tweenInfo, props):Play()
    end
    
    tween(targetButton, {Position = UDim2.new(0.05, 0, 0, self.positions[1])})
    tween(topBtn, {Position = UDim2.new(0.05, 0, 0, self.positions[targetPos])})
    self.buttons[1], self.buttons[targetPos] = self.buttons[targetPos], self.buttons[1]
    
    for i, btn in ipairs(self.buttons) do
        tween(btn, {BackgroundColor3 = i == 1 and self.colors.on or self.colors.off})
    end
    
    self.currentMode = mode
    globalModeStorage[self.currentButtonId] = mode
    self.callbacks.onModeChanged(mode)
    return true
end

function ModeSelector:SetPosition(position)
    self.MainFrame.Position = position
end

function ModeSelector:GetSavedMode()
    return globalModeStorage[self.currentButtonId] or self.currentMode
end

function ModeSelector:Destroy()
    for _, conn in ipairs(self.connections) do
        pcall(function() conn:Disconnect() end)
    end
    
    for _, obj in ipairs(self.objects) do
        pcall(function() obj:Destroy() end)
    end
    
    self.connections = {}
    self.objects = {}
    self.buttons = {}
    
    for i, instance in ipairs(activeInstances) do
        if instance == self then
            table.remove(activeInstances, i)
            break
        end
    end
end

function ModeSelector.CleanupAll()
    for _, instance in ipairs(activeInstances) do
        pcall(function() instance:Destroy() end)
    end
    activeInstances = {}
end

return ModeSelector

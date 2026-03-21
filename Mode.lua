-- ModeController.lua
local ModeController = {}
ModeController.__index = ModeController

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local Modes = {
    ALWAYS = 1,
    TOGGLE = 2,
    HOLD = 3
}

local ModeNames = {
    [Modes.ALWAYS] = "Always",
    [Modes.TOGGLE] = "Toggle",
    [Modes.HOLD] = "Hold"
}

local DEFAULT_SETTINGS = {
    size = UDim2.new(0, 90, 0, 115),
    colors = {
        off = Color3.fromRGB(35, 35, 35),
        on = Color3.fromRGB(45, 55, 75),
        topBar = Color3.fromRGB(45, 125, 220),
        background = Color3.fromRGB(33, 33, 33),
        content = Color3.fromRGB(28, 28, 28),
        border = Color3.fromRGB(55, 55, 55),
        text = Color3.fromRGB(255, 255, 255),
        dash = Color3.fromRGB(180, 180, 180)
    },
    font = {
        name = "Tahoma",
        url = "https://github.com/k0nkx/UI-Lib-Tuff/raw/refs/heads/main/Windows-XP-Tahoma.ttf"
    },
    tweenTime = 0.25,
    offsetFromCursor = Vector2.new(15, 15)
}

local activeInstances = {}

function ModeController.new(identifier, settings)
    if activeInstances[identifier] then
        return activeInstances[identifier]
    end
    
    local self = setmetatable({}, ModeController)
    
    self.identifier = identifier
    self.settings = {}
    for key, value in pairs(DEFAULT_SETTINGS) do
        self.settings[key] = settings and settings[key] or value
    end
    
    self.currentMode = Modes.ALWAYS
    self.connections = {}
    self.objects = {}
    self.buttons = {}
    self.isDragging = false
    self.dragInput = nil
    self.dragStart = nil
    self.startPos = nil
    self.isVisible = false
    self.cursorConnection = nil
    self.modeCallbacks = {}
    
    self.callbacks = {
        onModeChanged = nil
    }
    
    self:loadFont()
    self:setupUI()
    self:setupDragging()
    
    activeInstances[identifier] = self
    
    return self
end

function ModeController:loadFont()
    local fontData = self.settings.font
    
    if not isfile(fontData.name .. ".ttf") then
        writefile(fontData.name .. ".ttf", game:HttpGet(fontData.url))
    end
    
    if not isfile(fontData.name .. ".font") then
        local fontConfig = {
            name = fontData.name,
            faces = { { 
                name = "Regular", 
                weight = 400, 
                style = "normal", 
                assetId = getcustomasset(fontData.name .. ".ttf") 
            } }
        }
        writefile(fontData.name .. ".font", HttpService:JSONEncode(fontConfig))
    end
    
    self.customFont = Font.new(getcustomasset(fontData.name .. ".font"), Enum.FontWeight.Regular)
end

function ModeController:getParent()
    if syn and syn.protect_gui then
        return CoreGui
    elseif gethui then
        return gethui()
    else
        return CoreGui
    end
end

function ModeController:cleanupExisting()
    for _, gui in ipairs(self:getParent():GetChildren()) do
        if gui.Name == "ModeController_" .. self.identifier then
            gui:Destroy()
        end
    end
end

function ModeController:setupUI()
    self:cleanupExisting()
    
    self.screenGui = Instance.new("ScreenGui")
    self.screenGui.Name = "ModeController_" .. self.identifier
    self.screenGui.ResetOnSpawn = false
    self.screenGui.Parent = self:getParent()
    self.screenGui.Enabled = false
    
    if syn and syn.protect_gui then 
        syn.protect_gui(self.screenGui) 
    end
    
    table.insert(self.objects, self.screenGui)
    
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Size = self.settings.size
    self.mainFrame.BackgroundColor3 = self.settings.colors.background
    self.mainFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
    self.mainFrame.BorderSizePixel = 1
    self.mainFrame.Parent = self.screenGui
    
    self.topBar = Instance.new("Frame")
    self.topBar.Size = UDim2.new(1, 0, 0, 1)
    self.topBar.BackgroundColor3 = self.settings.colors.topBar
    self.topBar.BorderSizePixel = 0
    self.topBar.Parent = self.mainFrame
    
    self.title = Instance.new("TextLabel")
    self.title.Text = "Mode"
    self.title.Size = UDim2.new(1, 0, 0, 22)
    self.title.Position = UDim2.new(0, 4, 0, 1)
    self.title.BackgroundTransparency = 1
    self.title.TextColor3 = self.settings.colors.text
    self.title.TextXAlignment = Enum.TextXAlignment.Left
    self.title.TextSize = 15
    self.title.Font = Enum.Font.SourceSans
    self.title.Parent = self.mainFrame
    
    self.content = Instance.new("Frame")
    self.content.Size = UDim2.new(0.92, 0, 0, 80)
    self.content.Position = UDim2.new(0.04, 0, 0, 25)
    self.content.BackgroundColor3 = self.settings.colors.content
    self.content.BorderColor3 = Color3.fromRGB(0, 0, 0)
    self.content.BorderSizePixel = 1
    self.content.Parent = self.mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = self.settings.colors.border
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.LineJoinMode = Enum.LineJoinMode.Miter
    stroke.Parent = self.content
    
    self:createButtons()
end

function ModeController:createButtons()
    local positions = {5, 30, 55}
    local tweenInfo = TweenInfo.new(self.settings.tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    local function tween(obj, props)
        TweenService:Create(obj, tweenInfo, props):Play()
    end
    
    local function updateColors()
        for i, btn in ipairs(self.buttons) do
            local color = (i == 1) and self.settings.colors.on or self.settings.colors.off
            tween(btn.button, {BackgroundColor3 = color})
        end
    end
    
    for i, mode in ipairs({Modes.ALWAYS, Modes.TOGGLE, Modes.HOLD}) do
        local btnFrame = Instance.new("TextButton")
        btnFrame.Text = ""
        btnFrame.Size = UDim2.new(0.9, 0, 0, 20)
        btnFrame.Position = UDim2.new(0.05, 0, 0, positions[i])
        btnFrame.BackgroundColor3 = self.settings.colors.off
        btnFrame.BorderColor3 = Color3.fromRGB(50, 50, 50)
        btnFrame.BorderSizePixel = 1
        btnFrame.AutoButtonColor = false
        btnFrame.Parent = self.content
        
        local label = Instance.new("TextLabel")
        label.Text = ModeNames[mode]
        label.Size = UDim2.new(1, -20, 1, 0)
        label.Position = UDim2.new(0, 5, 0, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = self.settings.colors.text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextSize = 12
        label.FontFace = self.customFont
        label.Parent = btnFrame
        
        local dash = Instance.new("TextLabel")
        dash.Text = "-"
        dash.Size = UDim2.new(0, 15, 1, 0)
        dash.Position = UDim2.new(1, -15, -0.05, 0)
        dash.BackgroundTransparency = 1
        dash.TextColor3 = self.settings.colors.dash
        dash.TextSize = 16
        dash.FontFace = self.customFont
        dash.Parent = btnFrame
        
        local buttonData = {
            button = btnFrame,
            label = label,
            dash = dash,
            mode = mode
        }
        
        local connection = btnFrame.MouseButton1Click:Connect(function()
            local currentIndex = table.find(self.buttons, buttonData)
            if not currentIndex or currentIndex == 1 then return end
            
            local topButton = self.buttons[1]
            
            tween(btnFrame, {Position = UDim2.new(0.05, 0, 0, positions[1])})
            tween(topButton.button, {Position = UDim2.new(0.05, 0, 0, positions[currentIndex])})
            
            self.buttons[1], self.buttons[currentIndex] = self.buttons[currentIndex], self.buttons[1]
            
            updateColors()
            self.currentMode = self.buttons[1].mode
            
            if self.callbacks.onModeChanged then
                self.callbacks.onModeChanged(self.currentMode, ModeNames[self.currentMode])
            end
            
            for _, callback in ipairs(self.modeCallbacks) do
                pcall(callback, self.currentMode, ModeNames[self.currentMode])
            end
        end)
        
        table.insert(self.connections, connection)
        table.insert(self.buttons, buttonData)
        table.insert(self.objects, btnFrame)
    end
    
    updateColors()
end

function ModeController:setupDragging()
    local function update(input)
        local delta = input.Position - self.dragStart
        self.mainFrame.Position = UDim2.new(
            self.startPos.X.Scale,
            self.startPos.X.Offset + delta.X,
            self.startPos.Y.Scale,
            self.startPos.Y.Offset + delta.Y
        )
    end
    
    local beganConnection = self.title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            self.isDragging = true
            self.dragStart = input.Position
            self.startPos = self.mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    self.isDragging = false
                end
            end)
        end
    end)
    
    local changedConnection = self.title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            self.dragInput = input
        end
    end)
    
    local inputChangedConnection = UserInputService.InputChanged:Connect(function(input)
        if input == self.dragInput and self.isDragging then
            update(input)
        end
    end)
    
    table.insert(self.connections, beganConnection)
    table.insert(self.connections, changedConnection)
    table.insert(self.connections, inputChangedConnection)
end

function ModeController:ShowM()
    if self.isVisible then return end
    
    self.isVisible = true
    self.screenGui.Enabled = true
    
    local mousePos = UserInputService:GetMouseLocation()
    local offset = self.settings.offsetFromCursor
    
    local viewportSize = self:getParent().AbsoluteSize
    local frameSize = self.mainFrame.AbsoluteSize
    
    local x = mousePos.X + offset.X
    local y = mousePos.Y + offset.Y
    
    if x + frameSize.X > viewportSize.X then
        x = mousePos.X - frameSize.X - offset.X
    end
    
    if y + frameSize.Y > viewportSize.Y then
        y = mousePos.Y - frameSize.Y - offset.Y
    end
    
    self.mainFrame.Position = UDim2.new(0, x, 0, y)
    
    self.cursorConnection = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if self.isVisible and not self.isDragging then
                local newMousePos = UserInputService:GetMouseLocation()
                local newX = newMousePos.X + offset.X
                local newY = newMousePos.Y + offset.Y
                
                if newX + frameSize.X > viewportSize.X then
                    newX = newMousePos.X - frameSize.X - offset.X
                end
                
                if newY + frameSize.Y > viewportSize.Y then
                    newY = newMousePos.Y - frameSize.Y - offset.Y
                end
                
                self.mainFrame.Position = UDim2.new(0, newX, 0, newY)
            end
        end
    end)
    
    table.insert(self.connections, self.cursorConnection)
end

function ModeController:CloseM()
    if not self.isVisible then return end
    
    self.isVisible = false
    self.screenGui.Enabled = false
    
    if self.cursorConnection then
        self.cursorConnection:Disconnect()
        self.cursorConnection = nil
    end
end

function ModeController:getMode()
    return self.currentMode
end

function ModeController:getModeName()
    return ModeNames[self.currentMode]
end

function ModeController:isMode(mode)
    return self.currentMode == mode
end

function ModeController:isAlways()
    return self.currentMode == Modes.ALWAYS
end

function ModeController:isToggle()
    return self.currentMode == Modes.TOGGLE
end

function ModeController:isHold()
    return self.currentMode == Modes.HOLD
end

function ModeController:setMode(mode)
    if mode == self.currentMode then return end
    
    local targetIndex = nil
    for i, btnData in ipairs(self.buttons) do
        if btnData.mode == mode then
            targetIndex = i
            break
        end
    end
    
    if not targetIndex then return end
    
    local targetButton = self.buttons[targetIndex].button
    targetButton:Click()
end

function ModeController:onModeChanged(callback)
    table.insert(self.modeCallbacks, callback)
end

function ModeController:createControlledElement(elementType, settings)
    local controlled = {}
    local isActive = false
    local holdConnection = nil
    local holdTimer = nil
    
    local function cleanupHold()
        if holdConnection then
            holdConnection:Disconnect()
            holdConnection = nil
        end
        if holdTimer then
            holdTimer:Disconnect()
            holdTimer = nil
        end
    end
    
    local function updateBehavior()
        cleanupHold()
        
        if self:isAlways() then
            if settings.onAlways then
                settings.onAlways()
            end
            isActive = true
        elseif self:isToggle() then
            if settings.onToggleOn and isActive then
                settings.onToggleOn()
            elseif settings.onToggleOff and not isActive then
                settings.onToggleOff()
            end
        elseif self:isHold() then
            isActive = false
        end
    end
    
    controlled.element = settings.element or Instance.new("TextButton")
    
    local function onInputBegan(input)
        if self:isToggle() then
            isActive = not isActive
            if isActive and settings.onToggleOn then
                settings.onToggleOn()
            elseif not isActive and settings.onToggleOff then
                settings.onToggleOff()
            end
        elseif self:isHold() then
            holdTimer = task.delay(settings.holdDelay or 0.2, function()
                if settings.onHoldStart then
                    settings.onHoldStart()
                end
                isActive = true
                if settings.onHoldUpdate then
                    holdConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
                        settings.onHoldUpdate(dt)
                    end)
                end
            end)
        end
    end
    
    local function onInputEnded(input)
        if self:isHold() then
            cleanupHold()
            if isActive then
                if settings.onHoldEnd then
                    settings.onHoldEnd()
                end
                isActive = false
            end
        end
    end
    
    local inputBeganConn = controlled.element.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            onInputBegan(input)
        end
    end)
    
    local inputEndedConn = controlled.element.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            onInputEnded(input)
        end
    end)
    
    local modeChangedConn = self:onModeChanged(function(mode, modeName)
        updateBehavior()
    end)
    
    updateBehavior()
    
    controlled.destroy = function()
        inputBeganConn:Disconnect()
        inputEndedConn:Disconnect()
        modeChangedConn:Disconnect()
        cleanupHold()
    end
    
    return controlled
end

function ModeController:destroy()
    for _, conn in ipairs(self.connections) do
        pcall(function() conn:Disconnect() end)
    end
    
    for _, obj in ipairs(self.objects) do
        pcall(function() obj:Destroy() end)
    end
    
    self.connections = {}
    self.objects = {}
    self.buttons = {}
    self.modeCallbacks = {}
    
    activeInstances[self.identifier] = nil
end

ModeController.Modes = Modes
ModeController.ModeNames = ModeNames

return ModeController

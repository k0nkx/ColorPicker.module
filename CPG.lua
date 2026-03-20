local ColorPickerModule = {}

local UserInputService = cloneref and cloneref(game:GetService('UserInputService')) or game:GetService('UserInputService')
local Players = cloneref and cloneref(game:GetService('Players')) or game:GetService('Players')
local RunService = cloneref and cloneref(game:GetService('RunService')) or game:GetService('RunService')
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end

local activeInstance = nil

local function encodeColor(r, g, b, t)
    r = math.floor(r * 255 + 0.5)
    g = math.floor(g * 255 + 0.5)
    b = math.floor(b * 255 + 0.5)
    t = math.floor(t * 100 + 0.5)
    
    local chars = {}
    for i = 48, 57 do table.insert(chars, string.char(i)) end
    for i = 65, 90 do table.insert(chars, string.char(i)) end
    for i = 97, 122 do table.insert(chars, string.char(i)) end
    local special = {"!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "-", "_", "=", "+", "[", "]", "{", "}", "|", ";", ":", "'", "\"", ",", ".", "<", ">", "/", "?", "~", "`"}
    for i = 1, #special do table.insert(chars, special[i]) end
    
    local combined = (r * 65536) + (g * 256) + b
    combined = combined * 101 + t
    
    local base = #chars
    local result = ""
    local remaining = combined
    
    for i = 1, 5 do
        local remainder = (remaining % base) + 1
        result = chars[remainder] .. result
        remaining = math.floor(remaining / base)
    end
    
    return result
end

local function decodeColor(encoded)
    local chars = {}
    for i = 48, 57 do table.insert(chars, string.char(i)) end
    for i = 65, 90 do table.insert(chars, string.char(i)) end
    for i = 97, 122 do table.insert(chars, string.char(i)) end
    local special = {"!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "-", "_", "=", "+", "[", "]", "{", "}", "|", ";", ":", "'", "\"", ",", ".", "<", ">", "/", "?", "~", "`"}
    for i = 1, #special do table.insert(chars, special[i]) end
    
    local charMap = {}
    for i, c in ipairs(chars) do
        charMap[c] = i - 1
    end
    
    local base = #chars
    local combined = 0
    for i = 1, #encoded do
        combined = combined * base + charMap[encoded:sub(i, i)]
    end
    
    local t = combined % 101
    combined = math.floor(combined / 101)
    local b = combined % 256
    combined = math.floor(combined / 256)
    local g = combined % 256
    combined = math.floor(combined / 256)
    local r = combined % 256
    
    return Color3.fromRGB(r, g, b), t / 100
end

function ColorPickerModule.Show(callback, initialColor, initialTransparency)
    if activeInstance and activeInstance.ScreenGui then
        activeInstance.ScreenGui:Destroy()
        activeInstance = nil
    end
    
    local instance = {}
    activeInstance = instance
    
    local data = {
        currentColor = initialColor or Color3.fromRGB(255, 0, 0),
        currentTransparency = initialTransparency or 0,
        picking = false,
        callback = callback
    }
    
    data.currentHue, data.currentSat, data.currentVib = Color3.toHSV(data.currentColor)
    
    local gui = {}
    gui.ScreenGui = Instance.new('ScreenGui')
    gui.ScreenGui.Name = 'ColorPickerGUI_' .. tostring(math.random(1000, 9999))
    gui.ScreenGui.ResetOnSpawn = false
    gui.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.ScreenGui.Parent = (cloneref and cloneref(game:GetService('CoreGui')) or game:GetService('CoreGui')) or LocalPlayer:WaitForChild('PlayerGui')
    ProtectGui(gui.ScreenGui)
    instance.ScreenGui = gui.ScreenGui
    
    gui.MainFrame = Instance.new('Frame')
    gui.MainFrame.Size = UDim2.new(0, 192, 0, 192)
    gui.MainFrame.Position = UDim2.new(0.5, -210, 0.5, -110)
    gui.MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    gui.MainFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    gui.MainFrame.BorderMode = Enum.BorderMode.Inset
    gui.MainFrame.Active = true
    gui.MainFrame.Parent = gui.ScreenGui
    
    gui.PreviewFrame = Instance.new('Frame')
    gui.PreviewFrame.Size = UDim2.new(0, 50, 0, 50)
    gui.PreviewFrame.Position = UDim2.new(0.5, -14, 0.5, -110)
    gui.PreviewFrame.BackgroundColor3 = data.currentColor
    gui.PreviewFrame.BackgroundTransparency = data.currentTransparency
    gui.PreviewFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    gui.PreviewFrame.BorderMode = Enum.BorderMode.Inset
    gui.PreviewFrame.Parent = gui.ScreenGui
    
    gui.InfoFrame = Instance.new('Frame')
    gui.InfoFrame.Size = UDim2.new(0, 95, 0, 120)
    gui.InfoFrame.Position = UDim2.new(0.5, -14, 0.5, -55)
    gui.InfoFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    gui.InfoFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    gui.InfoFrame.BorderMode = Enum.BorderMode.Inset
    gui.InfoFrame.Active = true
    gui.InfoFrame.Parent = gui.ScreenGui
    
    local function createInfoLabel(parent, text, yPos)
        local label = Instance.new('TextLabel')
        label.Size = UDim2.new(1, -8, 0, 14)
        label.Position = UDim2.new(0, 4, 0, yPos)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.Text = text
        label.Font = Enum.Font.Code
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = parent
        return label
    end
    
    gui.RGBLabel = createInfoLabel(gui.InfoFrame, 'RGB: 255,0,0', 6)
    gui.HexLabel = createInfoLabel(gui.InfoFrame, 'HEX: #FF0000', 22)
    gui.HSVLabel = createInfoLabel(gui.InfoFrame, 'HSV: 0,100,100', 38)
    gui.OpacityLabel = createInfoLabel(gui.InfoFrame, 'Opacity: 100%', 54)
    gui.BrightnessLabel = createInfoLabel(gui.InfoFrame, 'Bright: 100%', 70)
    gui.SaturationLabel = createInfoLabel(gui.InfoFrame, 'Sat: 100%', 86)
    gui.EncodedLabel = createInfoLabel(gui.InfoFrame, 'Code: -----', 102)
    
    gui.PickerFrame = Instance.new('Frame')
    gui.PickerFrame.Size = UDim2.new(0, 160, 0, 160)
    gui.PickerFrame.Position = UDim2.new(0, 5, 0, 5)
    gui.PickerFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    gui.PickerFrame.BorderColor3 = Color3.fromRGB(55, 55, 55)
    gui.PickerFrame.BorderMode = Enum.BorderMode.Inset
    gui.PickerFrame.Parent = gui.MainFrame
    
    gui.PickerGradient = Instance.new('ImageLabel')
    gui.PickerGradient.Size = UDim2.new(1, -2, 1, -2)
    gui.PickerGradient.Position = UDim2.new(0, 1, 0, 1)
    gui.PickerGradient.BackgroundColor3 = Color3.fromHSV(data.currentHue, 1, 1)
    gui.PickerGradient.BorderSizePixel = 0
    gui.PickerGradient.Image = 'rbxassetid://4155801252'
    gui.PickerGradient.Parent = gui.PickerFrame
    
    gui.PickerCursor = Instance.new('Frame')
    gui.PickerCursor.Size = UDim2.new(0, 5, 0, 5)
    gui.PickerCursor.Position = UDim2.new(0, -2.5, 0, -2.5)
    gui.PickerCursor.BackgroundColor3 = Color3.new(0, 0, 0)
    gui.PickerCursor.BackgroundTransparency = 0
    gui.PickerCursor.BorderSizePixel = 0
    gui.PickerCursor.ZIndex = 10
    gui.PickerCursor.Parent = gui.PickerGradient
    
    local cursorCorner = Instance.new('UICorner')
    cursorCorner.CornerRadius = UDim.new(1, 0)
    cursorCorner.Parent = gui.PickerCursor
    
    local cursorStroke = Instance.new('UIStroke')
    cursorStroke.Color = Color3.new(1, 1, 1)
    cursorStroke.Thickness = 1
    cursorStroke.Parent = gui.PickerCursor
    
    gui.HueFrame = Instance.new('Frame')
    gui.HueFrame.Size = UDim2.new(0, 15, 0, 160)
    gui.HueFrame.Position = UDim2.new(0, 170, 0, 5)
    gui.HueFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    gui.HueFrame.BorderColor3 = Color3.fromRGB(55, 55, 55)
    gui.HueFrame.BorderMode = Enum.BorderMode.Inset
    gui.HueFrame.Parent = gui.MainFrame
    
    gui.HueGradient = Instance.new('Frame')
    gui.HueGradient.Size = UDim2.new(1, -2, 1, -2)
    gui.HueGradient.Position = UDim2.new(0, 1, 0, 1)
    gui.HueGradient.BackgroundColor3 = Color3.new(1, 1, 1)
    gui.HueGradient.BorderSizePixel = 0
    gui.HueGradient.Parent = gui.HueFrame
    
    local HueColors = {}
    for i = 0, 1, 0.1 do
        table.insert(HueColors, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
    end
    gui.HueGradientObj = Instance.new('UIGradient')
    gui.HueGradientObj.Color = ColorSequence.new(HueColors)
    gui.HueGradientObj.Rotation = 90
    gui.HueGradientObj.Parent = gui.HueGradient
    
    gui.HueCursor = Instance.new('Frame')
    gui.HueCursor.Size = UDim2.new(1, 0, 0, 1)
    gui.HueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    gui.HueCursor.BorderColor3 = Color3.new(0, 0, 0)
    gui.HueCursor.Parent = gui.HueGradient
    
    gui.TransparencyFrame = Instance.new('Frame')
    gui.TransparencyFrame.Size = UDim2.new(0, 180, 0, 15)
    gui.TransparencyFrame.Position = UDim2.new(0, 5, 0, 170)
    gui.TransparencyFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    gui.TransparencyFrame.BorderColor3 = Color3.fromRGB(55, 55, 55)
    gui.TransparencyFrame.BorderMode = Enum.BorderMode.Inset
    gui.TransparencyFrame.Parent = gui.MainFrame
    
    gui.TransparencyInner = Instance.new('Frame')
    gui.TransparencyInner.Size = UDim2.new(1, -2, 1, -2)
    gui.TransparencyInner.Position = UDim2.new(0, 1, 0, 1)
    gui.TransparencyInner.BackgroundColor3 = data.currentColor
    gui.TransparencyInner.BorderSizePixel = 0
    gui.TransparencyInner.Parent = gui.TransparencyFrame
    
    gui.TransparencyChecker = Instance.new('ImageLabel')
    gui.TransparencyChecker.Size = UDim2.new(1, 0, 1, 0)
    gui.TransparencyChecker.BackgroundTransparency = 1
    gui.TransparencyChecker.Image = 'http://www.roblox.com/asset/?id=12978095818'
    gui.TransparencyChecker.Parent = gui.TransparencyInner
    
    gui.TransparencyCursor = Instance.new('Frame')
    gui.TransparencyCursor.Size = UDim2.new(0, 1, 1, 0)
    gui.TransparencyCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    gui.TransparencyCursor.BorderColor3 = Color3.new(0, 0, 0)
    gui.TransparencyCursor.Parent = gui.TransparencyInner
    
    local function UpdateDisplay()
        gui.PickerGradient.BackgroundColor3 = Color3.fromHSV(data.currentHue, 1, 1)
        gui.PickerCursor.Position = UDim2.new(0, data.currentSat * gui.PickerGradient.AbsoluteSize.X - 2.5, 0, (1 - data.currentVib) * gui.PickerGradient.AbsoluteSize.Y - 2.5)
        gui.HueCursor.Position = UDim2.new(0, 0, 0, data.currentHue * gui.HueGradient.AbsoluteSize.Y - 1)
        gui.TransparencyCursor.Position = UDim2.new(0, (1 - data.currentTransparency) * gui.TransparencyInner.AbsoluteSize.X - 1, 0, 0)
        
        gui.TransparencyInner.BackgroundColor3 = data.currentColor
        gui.PreviewFrame.BackgroundColor3 = data.currentColor
        gui.PreviewFrame.BackgroundTransparency = data.currentTransparency

        gui.RGBLabel.Text = string.format('RGB: %d,%d,%d', math.floor(data.currentColor.R*255+0.5), math.floor(data.currentColor.G*255+0.5), math.floor(data.currentColor.B*255+0.5))
        gui.HexLabel.Text = 'HEX: #' .. string.upper(data.currentColor:ToHex())
        gui.HSVLabel.Text = string.format('HSV: %d,%d,%d', math.floor(data.currentHue*360+0.5), math.floor(data.currentSat*100+0.5), math.floor(data.currentVib*100+0.5))
        gui.OpacityLabel.Text = string.format('Opacity: %d%%', math.floor((1 - data.currentTransparency)*100+0.5))
        gui.BrightnessLabel.Text = string.format('Bright: %d%%', math.floor(data.currentVib*100+0.5))
        gui.SaturationLabel.Text = string.format('Sat: %d%%', math.floor(data.currentSat*100+0.5))

        if data.callback then
            local encoded = encodeColor(data.currentColor.R, data.currentColor.G, data.currentColor.B, data.currentTransparency)
            gui.EncodedLabel.Text = 'Code: ' .. encoded
        end
    end
    
    local function handleInput(pos, began)
        if not activeInstance then return end
        
        if began then
            local targets = {gui.PickerGradient, gui.HueGradient, gui.TransparencyInner}
            for _, t in ipairs(targets) do
                if pos.X >= t.AbsolutePosition.X and pos.X <= t.AbsolutePosition.X + t.AbsoluteSize.X and
                   pos.Y >= t.AbsolutePosition.Y and pos.Y <= t.AbsolutePosition.Y + t.AbsoluteSize.Y then
                    activeInstance.picking = t
                    break
                end
            end
        end

        if activeInstance.picking then
            local t = activeInstance.picking
            local relX = math.clamp(pos.X - t.AbsolutePosition.X, 0, t.AbsoluteSize.X)
            local relY = math.clamp(pos.Y - t.AbsolutePosition.Y, 0, t.AbsoluteSize.Y)

            if t == gui.PickerGradient then
                data.currentSat = relX / t.AbsoluteSize.X
                data.currentVib = 1 - relY / t.AbsoluteSize.Y
            elseif t == gui.HueGradient then
                data.currentHue = relY / t.AbsoluteSize.Y
            elseif t == gui.TransparencyInner then
                data.currentTransparency = 1 - relX / t.AbsoluteSize.X
            end

            data.currentColor = Color3.fromHSV(data.currentHue, data.currentSat, data.currentVib)
            if data.callback then
                data.callback(data.currentColor, data.currentTransparency)
            end
            UpdateDisplay()
        end
    end
    
    UserInputService.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            handleInput(Vector2.new(i.Position and i.Position.X or Mouse.X, i.Position and i.Position.Y or Mouse.Y), true)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(i)
        if (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) and activeInstance and activeInstance.picking then
            handleInput(Vector2.new(i.Position and i.Position.X or Mouse.X, i.Position and i.Position.Y or Mouse.Y), false)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(i)
        if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and activeInstance and activeInstance.picking then
            activeInstance.picking = false
        end
    end)
    
    data.currentHue = 0
    data.currentSat = 1
    data.currentVib = 1
    data.currentColor = Color3.fromHSV(0, 1, 1)
    
    UpdateDisplay()
    if data.callback then
        data.callback(data.currentColor, data.currentTransparency)
    end
    
    return instance
end

function ColorPickerModule.Close()
    if activeInstance and activeInstance.ScreenGui then
        activeInstance.ScreenGui:Destroy()
        activeInstance = nil
    end
end

function ColorPickerModule.SetColor(color, transparency)
    if not activeInstance then return end
    
    local data = activeInstance.data or {}
    data.currentColor = color or Color3.fromRGB(255, 0, 0)
    data.currentTransparency = transparency or 0
    data.currentHue, data.currentSat, data.currentVib = Color3.toHSV(data.currentColor)
    
    if activeInstance.gui then
        local gui = activeInstance.gui
        gui.PreviewFrame.BackgroundColor3 = data.currentColor
        gui.PreviewFrame.BackgroundTransparency = data.currentTransparency
        gui.TransparencyInner.BackgroundColor3 = data.currentColor
        
        local function UpdateDisplay()
            gui.PickerGradient.BackgroundColor3 = Color3.fromHSV(data.currentHue, 1, 1)
            gui.PickerCursor.Position = UDim2.new(0, data.currentSat * gui.PickerGradient.AbsoluteSize.X - 2.5, 0, (1 - data.currentVib) * gui.PickerGradient.AbsoluteSize.Y - 2.5)
            gui.HueCursor.Position = UDim2.new(0, 0, 0, data.currentHue * gui.HueGradient.AbsoluteSize.Y - 1)
            gui.TransparencyCursor.Position = UDim2.new(0, (1 - data.currentTransparency) * gui.TransparencyInner.AbsoluteSize.X - 1, 0, 0)
            
            gui.RGBLabel.Text = string.format('RGB: %d,%d,%d', math.floor(data.currentColor.R*255+0.5), math.floor(data.currentColor.G*255+0.5), math.floor(data.currentColor.B*255+0.5))
            gui.HexLabel.Text = 'HEX: #' .. string.upper(data.currentColor:ToHex())
            gui.HSVLabel.Text = string.format('HSV: %d,%d,%d', math.floor(data.currentHue*360+0.5), math.floor(data.currentSat*100+0.5), math.floor(data.currentVib*100+0.5))
            gui.OpacityLabel.Text = string.format('Opacity: %d%%', math.floor((1 - data.currentTransparency)*100+0.5))
            gui.BrightnessLabel.Text = string.format('Bright: %d%%', math.floor(data.currentVib*100+0.5))
            gui.SaturationLabel.Text = string.format('Sat: %d%%', math.floor(data.currentSat*100+0.5))
        end
        
        UpdateDisplay()
    end
end

function ColorPickerModule.Encode(color, transparency)
    return encodeColor(color.R, color.G, color.B, transparency or 0)
end

function ColorPickerModule.Decode(code)
    return decodeColor(code)
end

return ColorPickerModule

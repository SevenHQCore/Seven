local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Load Linoria Library & Addons
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- Create Window
local Window = Library:CreateWindow({
    Title = 'Seven | Admin & Tools',
    Size = UDim2.fromOffset(680, 520),
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

-- Create Tabs
local Tabs = {
    Weapon = Window:AddTab('Weapon'),
    Movement = Window:AddTab('Movement'),
    ESP = Window:AddTab('ESP'),
    Aim = Window:AddTab('Aim Assist'),
    Theme = Window:AddTab('Theme'),
}

-- Groups & Left/Right Boxes for Tabs
local WeaponGroup = Tabs.Weapon:AddLeftGroupbox('Weapon Modifications')
local MovementGroup = Tabs.Movement:AddLeftGroupbox('Player Movement & Camera')
local ESPGroup = Tabs.ESP:AddLeftGroupbox('Visuals (ESP)')
local ESPConfigGroup = Tabs.ESP:AddRightGroupbox('ESP Configuration')
local AimGroup = Tabs.Aim:AddLeftGroupbox('Aim Assist & Combat')
local AimConfigGroup = Tabs.Aim:AddRightGroupbox('Aim Configuration')
local ThemeGroup = Tabs.Theme:AddLeftGroupbox('UI Theme Settings')

---------------------------------------------------------
-- GESTION DE LA TOUCHE INSERT (FERMER / OUVRIR)
---------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Insert then
        Library:Toggle()
    end
end)

---------------------------------------------------------
-- STATE VARIABLES
---------------------------------------------------------
local rapidFireEnabled = false
local fireRateMultiplier = 3

local spinEnabled = false
local spinSpeed = 50

local customFovEnabled = false
local targetFov = 70
local cameraZoomDistance = 12

local espEnabled = false
local selectedPlayerName = nil
local highlightColor = Color3.fromRGB(255, 0, 0)
local highlightFillTransparency = 0.5
local espObjects = {}

local skeletonEnabled = false
local skeletonColor = Color3.fromRGB(0, 255, 255)
local skeletonObjects = {}

local tracersEnabled = false
local tracerColor = Color3.fromRGB(255, 255, 255)
local tracerObjects = {}

local aimAssistEnabled = false
local autoShootEnabled = false  
local lastShootTime = 0
local shootDelay = 0.05         
local wallbangEnabled = false  
local aimStrength = 0.5        
local fovRadius = 150          
local targetPartName = "Head"  
local teamCheck = false

local showFovCircle = true
local fovColor = Color3.fromRGB(255, 255, 255)

local shootingStarsEnabled = false
local starObjects = {}
local starSpeed = 8

---------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------
local function getRootPart(character)
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character.PrimaryPart
end

---------------------------------------------------------
-- GLOBAL RAYCAST HOOK FOR WEAPON WALLBANG
---------------------------------------------------------
if hookmetamethod and getnamecallmethod then
    local oldIndex
    oldIndex = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if wallbangEnabled and (method == "Raycast" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay") then
            if typeof(args[3]) == "RaycastParams" then
                args[3].FilterType = Enum.RaycastFilterType.Exclude
                local ignoreList = args[3].FilterDescendantsInstances or {}
                if workspace:FindFirstChild("Map") then table.insert(ignoreList, workspace.Map) end
                if workspace:FindFirstChild("MapFolder") then table.insert(ignoreList, workspace.MapFolder) end
                if workspace:FindFirstChild("Walls") then table.insert(ignoreList, workspace.Walls) end
                args[3].FilterDescendantsInstances = ignoreList
            end
        end

        return oldIndex(self, ...)
    end)
end

---------------------------------------------------------
-- DRAWING FOV CIRCLE
---------------------------------------------------------
local FOVCircle = Drawing.new("Circle")
FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
FOVCircle.Radius = fovRadius
FOVCircle.Filled = false
FOVCircle.Color = fovColor
FOVCircle.Thickness = 1.5
FOVCircle.Transparency = 1
FOVCircle.Visible = false

---------------------------------------------------------
-- SHOOTING STARS SYSTEM
---------------------------------------------------------
local function spawnStar()
    local star = Drawing.new("Line")
    star.Thickness = 1.5
    star.Color = Color3.fromRGB(255, 255, 255)
    star.Transparency = 1

    local startX = math.random(0, Camera.ViewportSize.X)
    local startY = math.random(0, math.floor(Camera.ViewportSize.Y / 2))
    local length = math.random(20, 40)

    table.insert(starObjects, {
        Line = star,
        Pos = Vector2.new(startX, startY),
        Length = length,
        Alpha = 1
    })
end

local function updateStars()
    for i = #starObjects, 1, -1 do
        local starData = starObjects[i]
        starData.Pos = starData.Pos + Vector2.new(-starSpeed, starSpeed)
        starData.Alpha = starData.Alpha - 0.02

        if starData.Alpha <= 0 or starData.Pos.Y > Camera.ViewportSize.Y then
            starData.Line:Remove()
            table.remove(starObjects, i)
        else
            starData.Line.From = starData.Pos
            starData.Line.To = starData.Pos + Vector2.new(starData.Length, -starData.Length)
            starData.Line.Transparency = starData.Alpha
            starData.Line.Visible = shootingStarsEnabled
        end
    end
end

---------------------------------------------------------
-- TRACERS ESP FUNCTIONS
---------------------------------------------------------
local function createTracer(player)
    if tracerObjects[player] then return end
    local line = Drawing.new("Line")
    line.Thickness = 1.5
    line.Color = tracerColor
    line.Transparency = 1
    line.Visible = false
    tracerObjects[player] = line
end

local function removeTracer(player)
    if tracerObjects[player] then
        tracerObjects[player].Visible = false
        tracerObjects[player]:Remove()
        tracerObjects[player] = nil
    end
end

---------------------------------------------------------
-- SKELETON ESP DATA & FUNCTIONS
---------------------------------------------------------
local R15_BONES = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local R6_BONES = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local function createSkeleton(player)
    if skeletonObjects[player] then return end
    skeletonObjects[player] = {}
end

local function removeSkeleton(player)
    if skeletonObjects[player] then
        for _, line in pairs(skeletonObjects[player]) do
            line.Visible = false
            line:Remove()
        end
        skeletonObjects[player] = nil
    end
end

---------------------------------------------------------
-- BOX ESP, HIGHLIGHT & HEALTH BAR FUNCTIONS
---------------------------------------------------------
local function createESP(player)
    if player == LocalPlayer then return end

    local function setupBillboard(character)
        if not character then return end

        local hrp = getRootPart(character) or character:WaitForChild("HumanoidRootPart", 5)
        local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
        if not hrp or not humanoid then return end

        if espObjects[player] then
            espObjects[player]:Destroy()
            espObjects[player] = nil
        end

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "PIXHUB_ESP_" .. player.Name
        billboard.Adornee = hrp
        billboard.Size = UDim2.new(0, 200, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 3.5, 0)
        billboard.AlwaysOnTop = true

        local boxFrame = Instance.new("Frame")
        boxFrame.Name = "BoxBorder"
        boxFrame.Size = UDim2.new(0, 150, 0, 50)
        boxFrame.Position = UDim2.new(0.5, -75, 0.5, -25)
        boxFrame.BackgroundTransparency = 0.85
        boxFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        boxFrame.BorderSizePixel = 2
        boxFrame.BorderColor3 = highlightColor
        boxFrame.Parent = billboard

        local healthBarBackground = Instance.new("Frame")
        healthBarBackground.Name = "HealthBarBG"
        healthBarBackground.Size = UDim2.new(0, 4, 1, 0)
        healthBarBackground.Position = UDim2.new(0, -8, 0, 0)
        healthBarBackground.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        healthBarBackground.BorderSizePixel = 1
        healthBarBackground.BorderColor3 = Color3.fromRGB(0, 0, 0)
        healthBarBackground.Parent = boxFrame

        local healthBarFill = Instance.new("Frame")
        healthBarFill.Name = "HealthBarFill"
        healthBarFill.Size = UDim2.new(1, 0, 1, 0)
        healthBarFill.Position = UDim2.new(0, 0, 0, 0)
        healthBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        healthBarFill.BorderSizePixel = 0
        healthBarFill.Parent = healthBarBackground

        local infoLabel = Instance.new("TextLabel")
        infoLabel.Name = "InfoLabel"
        infoLabel.Size = UDim2.new(1, 0, 1, 0)
        infoLabel.BackgroundTransparency = 1
        infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        infoLabel.TextStrokeTransparency = 0
        infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        infoLabel.Font = Enum.Font.SourceSansBold
        infoLabel.TextSize = 14
        infoLabel.TextYAlignment = Enum.TextYAlignment.Center
        infoLabel.Parent = boxFrame

        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            billboard.Parent = playerGui
        else
            billboard.Parent = hrp
        end

        espObjects[player] = billboard
    end

    if player.Character then
        setupBillboard(player.Character)
    end
    player.CharacterAdded:Connect(setupBillboard)
end

local function removeESP(player)
    if espObjects[player] then
        espObjects[player]:Destroy()
        espObjects[player] = nil
    end
end

local function applyHighlight(player)
    if not player or not player.Character then return end
    local character = player.Character
    
    local existing = character:FindFirstChildOfClass("Highlight")
    if existing then existing:Destroy() end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "PIXHUB_Highlight"
    highlight.FillColor = highlightColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = highlightFillTransparency
    highlight.Adornee = character
    highlight.Parent = character
end

local function removeHighlight(player)
    if not player or not player.Character then return end
    local existing = player.Character:FindFirstChild("PIXHUB_Highlight")
    if existing then existing:Destroy() end
end

local function getPlayerNames()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    return names
end

---------------------------------------------------------
-- AIM ASSIST HELPER
---------------------------------------------------------
local function getClosestPlayerToCrosshair()
    local closestPlayer = nil
    local shortestDistance = fovRadius
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if teamCheck and player.Team == LocalPlayer.Team then
                continue
            end

            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local targetPart = player.Character:FindFirstChild(targetPartName)

            if humanoid and humanoid.Health > 0 and targetPart then
                local screenPosition, onScreen = Camera:WorldToViewportPoint(targetPart.Position)

                if onScreen then
                    local target2D = Vector2.new(screenPosition.X, screenPosition.Y)
                    local distanceToCenter = (target2D - viewportCenter).Magnitude

                    if distanceToCenter < shortestDistance then
                        if not wallbangEnabled then
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
                            
                            local rayResult = workspace:Raycast(
                                Camera.CFrame.Position, 
                                (targetPart.Position - Camera.CFrame.Position), 
                                rayParams
                            )

                            if rayResult and rayResult.Instance:IsDescendantOf(player.Character) then
                                shortestDistance = distanceToCenter
                                closestPlayer = player
                            end
                        else
                            shortestDistance = distanceToCenter
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end

    return closestPlayer
end

---------------------------------------------------------
-- LINORIA UI INTERFACE CONSTRUCTION
---------------------------------------------------------

-- 1. WEAPON MODS
WeaponGroup:AddToggle('RapidFireToggle', {
    Text = 'Enable Rapid Fire',
    Default = false,
    Callback = function(Value)
        rapidFireEnabled = Value
    end
})

WeaponGroup:AddSlider('RapidFireSpeed', {
    Text = 'Rapid Fire Multiplier',
    Default = 3,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Suffix = 'x',
    Callback = function(Value)
        fireRateMultiplier = Value
    end
})

-- 2. MOVEMENT & FUN
MovementGroup:AddToggle('CustomFovToggle', {
    Text = 'Enable Custom FOV & Distance',
    Default = false,
    Callback = function(Value)
        customFovEnabled = Value
        if not Value then
            Camera.FieldOfView = 70
            LocalPlayer.CameraMaxZoomDistance = 400
            LocalPlayer.CameraMinZoomDistance = 0.5
        end
    end
})

MovementGroup:AddSlider('CameraFovSlider', {
    Text = 'Camera FOV',
    Default = 70,
    Min = 30,
    Max = 120,
    Rounding = 0,
    Suffix = ' FOV',
    Callback = function(Value)
        targetFov = Value
    end
})

MovementGroup:AddSlider('CameraDistanceSlider', {
    Text = 'Camera Distance (Zoom)',
    Default = 12,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Suffix = ' Studs',
    Callback = function(Value)
        cameraZoomDistance = Value
    end
})

MovementGroup:AddToggle('SpinToggle', {
    Text = 'Enable Spin Player',
    Default = false,
    Callback = function(Value)
        spinEnabled = Value
    end
})

MovementGroup:AddSlider('SpinSpeedSlider', {
    Text = 'Spin Speed',
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Suffix = ' Speed',
    Callback = function(Value)
        spinSpeed = Value
    end
})

-- 3. ESP & HIGHLIGHT
ESPGroup:AddToggle('ESPToggle', {
    Text = 'Enable Box ESP, Info & HealthBar',
    Default = false,
    Callback = function(Value)
        espEnabled = Value
        if not Value then
            for plr, gui in pairs(espObjects) do gui:Destroy() end
            espObjects = {}
        else
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createESP(plr) end
            end
        end
    end
})

ESPGroup:AddToggle('TracersToggle', {
    Text = 'Enable Tracing Lines (Tracers)',
    Default = false,
    Callback = function(Value)
        tracersEnabled = Value
        if not Value then
            for plr in pairs(tracerObjects) do removeTracer(plr) end
        end
    end
})

ESPGroup:AddLabel('Tracers Color'):AddColorPicker('TracerColorPicker', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Tracers Color',
    Callback = function(Value)
        tracerColor = Value
        for _, line in pairs(tracerObjects) do line.Color = tracerColor end
    end
})

ESPGroup:AddToggle('SkeletonToggle', {
    Text = 'Enable Skeleton ESP',
    Default = false,
    Callback = function(Value)
        skeletonEnabled = Value
        if not Value then
            for plr in pairs(skeletonObjects) do removeSkeleton(plr) end
        else
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createSkeleton(plr) end
            end
        end
    end
})

ESPGroup:AddLabel('Skeleton Color'):AddColorPicker('SkeletonColorPicker', {
    Default = Color3.fromRGB(0, 255, 255),
    Title = 'Skeleton Color',
    Callback = function(Value)
        skeletonColor = Value
    end
})

ESPConfigGroup:AddDropdown('PlayerDropdown', {
    Values = getPlayerNames(),
    Default = 1,
    Text = 'Select Player',
    Callback = function(Value)
        selectedPlayerName = Value
    end
})

ESPConfigGroup:AddButton('Refresh Player List', function()
    Options.PlayerDropdown:SetValues(getPlayerNames())
end)

ESPConfigGroup:AddLabel('ESP Box & Highlight Color'):AddColorPicker('ColorPicker', {
    Default = Color3.fromRGB(255, 0, 0),
    Title = 'Highlight Color',
    Callback = function(Value)
        highlightColor = Value
        for _, billboard in pairs(espObjects) do
            local box = billboard:FindFirstChild("BoxBorder")
            if box then box.BorderColor3 = highlightColor end
        end
    end
})

ESPConfigGroup:AddButton('Highlight Selected Player', function()
    if selectedPlayerName then
        local plr = Players:FindFirstChild(selectedPlayerName)
        if plr then applyHighlight(plr) end
    end
end)

ESPConfigGroup:AddButton('Highlight ALL Players', function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then applyHighlight(plr) end
    end
end)

ESPConfigGroup:AddButton('Clear Highlights', function()
    for _, plr in ipairs(Players:GetPlayers()) do removeHighlight(plr) end
end)

-- 4. AIM ASSIST
AimGroup:AddToggle('AimAssistToggle', {
    Text = 'Enable Aim Assist',
    Default = false,
    Callback = function(Value)
        aimAssistEnabled = Value
    end
})

AimGroup:AddToggle('AutoShootToggle', {
    Text = 'Enable Auto Shoot',
    Default = false,
    Callback = function(Value)
        autoShootEnabled = Value
    end
})

AimGroup:AddToggle('WallbangToggle', {
    Text = 'Wallbang / Ignore Walls',
    Default = false,
    Callback = function(Value)
        wallbangEnabled = Value
    end
})

AimGroup:AddSlider('AimStrengthSlider', {
    Text = 'Aim Strength (Smoothness)',
    Default = 0.5,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        aimStrength = Value
    end
})

AimConfigGroup:AddSlider('FOVRadiusSlider', {
    Text = 'FOV Radius (Pixels)',
    Default = 150,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Suffix = ' px',
    Callback = function(Value)
        fovRadius = Value
        FOVCircle.Radius = fovRadius
    end
})

AimConfigGroup:AddToggle('ShowFOVCircleToggle', {
    Text = 'Show FOV Circle',
    Default = true,
    Callback = function(Value)
        showFovCircle = Value
    end
})

AimConfigGroup:AddLabel('FOV Circle Color'):AddColorPicker('FOVCircleColorPicker', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'FOV Color',
    Callback = function(Value)
        fovColor = Value
        FOVCircle.Color = fovColor
    end
})

AimConfigGroup:AddDropdown('TargetPartDropdown', {
    Values = {'Head', 'HumanoidRootPart'},
    Default = 1,
    Text = 'Target Body Part',
    Callback = function(Value)
        targetPartName = Value
    end
})

AimConfigGroup:AddToggle('TeamCheckToggle', {
    Text = 'Team Check (Ignore Teammates)',
    Default = false,
    Callback = function(Value)
        teamCheck = Value
    end
})

-- 5. THEME & STYLE
ThemeGroup:AddToggle('StarsToggle', {
    Text = 'Étoiles Filantes (FX)',
    Default = false,
    Callback = function(Value)
        shootingStarsEnabled = Value
        if not Value then
            for _, s in ipairs(starObjects) do s.Line:Remove() end
            starObjects = {}
        end
    end
})

-- Linoria Theme & Config Managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder('PIXHUB_Config')
SaveManager:SetFolder('PIXHUB_Config/settings')
ThemeManager:ApplyToTab(Tabs.Theme)
SaveManager:BuildConfigSection(Tabs.Theme)

---------------------------------------------------------
-- MAIN RENDER LOOP
---------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
    -- Custom FOV
    if customFovEnabled then
        Camera.FieldOfView = targetFov
        LocalPlayer.CameraMaxZoomDistance = cameraZoomDistance
        LocalPlayer.CameraMinZoomDistance = cameraZoomDistance
    end

    -- Rapid Fire
    if rapidFireEnabled then
        local char = LocalPlayer.Character
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    for _, desc in ipairs(tool:GetDescendants()) do
                        if desc:IsA("ModuleScript") or desc:IsA("LocalScript") then
                            pcall(function()
                                local env = getfenv(desc)
                                if env and env.fireRate then
                                    env.fireRate = env.fireRate / fireRateMultiplier
                                elseif env and env.Cooldown then
                                    env.Cooldown = env.Cooldown / fireRateMultiplier
                                end
                            end)
                        end
                    end
                end
            end
        end
    end

    -- Spin Player
    if spinEnabled then
        local char = LocalPlayer.Character
        if char then
            local hrp = getRootPart(char)
            if hrp then
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(spinSpeed * dt * 60), 0)
            end
        end
    end

    -- Stars FX
    if shootingStarsEnabled then
        if math.random(1, 10) == 1 then spawnStar() end
        updateStars()
    end

    -- Update FOV Circle
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Visible = aimAssistEnabled and showFovCircle

    -- Box ESP & Health Bar Update
    if espEnabled then
        local myChar = LocalPlayer.Character
        local myHRP = myChar and getRootPart(myChar)

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not espObjects[player] and player.Character then
                    createESP(player)
                end

                local billboard = espObjects[player]
                if player.Character and billboard then
                    local targetHRP = getRootPart(player.Character)
                    local targetHum = player.Character:FindFirstChildOfClass("Humanoid")

                    if targetHRP and targetHum and billboard:FindFirstChild("BoxBorder") then
                        local box = billboard.BoxBorder
                        local label = box:FindFirstChild("InfoLabel")
                        local healthBG = box:FindFirstChild("HealthBarBG")

                        if label then
                            local distance = myHRP and math.floor((myHRP.Position - targetHRP.Position).Magnitude) or 0
                            local health = math.floor(targetHum.Health)
                            local maxHealth = math.floor(targetHum.MaxHealth)

                            label.Text = string.format("%s\nHP: %d/%d\nDist: %d studs", player.Name, health, maxHealth, distance)

                            if healthBG and healthBG:FindFirstChild("HealthBarFill") then
                                local fill = healthBG.HealthBarFill
                                local healthPercent = math.clamp(health / maxHealth, 0, 1)

                                fill.Size = UDim2.new(1, 0, healthPercent, 0)
                                fill.Position = UDim2.new(0, 0, 1 - healthPercent, 0)

                                if healthPercent > 0.5 then
                                    fill.BackgroundColor3 = Color3.fromRGB(255, 255, 0):Lerp(Color3.fromRGB(0, 255, 0), (healthPercent - 0.5) * 2)
                                else
                                    fill.BackgroundColor3 = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(255, 255, 0), healthPercent * 2)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- TRACERS
    if tracersEnabled then
        local bottomScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local targetHRP = getRootPart(player.Character)
                local targetHum = player.Character:FindFirstChildOfClass("Humanoid")

                if targetHRP and targetHum and targetHum.Health > 0 then
                    if not tracerObjects[player] then
                        createTracer(player)
                    end

                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetHRP.Position)
                    local tracer = tracerObjects[player]

                    if onScreen and tracer then
                        tracer.From = bottomScreen
                        tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        tracer.Color = tracerColor
                        tracer.Visible = true
                    elseif tracer then
                        tracer.Visible = false
                    end
                else
                    removeTracer(player)
                end
            else
                removeTracer(player)
            end
        end
    end

    -- Skeleton ESP
    if skeletonEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local char = player.Character
                local hum = char:FindFirstChildOfClass("Humanoid")

                if hum and hum.Health > 0 then
                    if not skeletonObjects[player] then createSkeleton(player) end

                    local boneSet = (hum.RigType == Enum.HumanoidRigType.R15) and R15_BONES or R6_BONES
                    local lines = skeletonObjects[player]

                    for idx, bonePair in ipairs(boneSet) do
                        local partA = char:FindFirstChild(bonePair[1])
                        local partB = char:FindFirstChild(bonePair[2])

                        if partA and partB then
                            local posA, visA = Camera:WorldToViewportPoint(partA.Position)
                            local posB, visB = Camera:WorldToViewportPoint(partB.Position)

                            if visA or visB then
                                if not lines[idx] then
                                    lines[idx] = Drawing.new("Line")
                                    lines[idx].Thickness = 1.5
                                    lines[idx].Transparency = 1
                                end

                                local line = lines[idx]
                                line.From = Vector2.new(posA.X, posA.Y)
                                line.To = Vector2.new(posB.X, posB.Y)
                                line.Color = skeletonColor
                                line.Visible = true
                            else
                                if lines[idx] then lines[idx].Visible = false end
                            end
                        else
                            if lines[idx] then lines[idx].Visible = false end
                        end
                    end
                else
                    removeSkeleton(player)
                end
            end
        end
    end

    -- Aim Assist & Auto Shoot Logic
    local targetPlayer = getClosestPlayerToCrosshair()
    if targetPlayer and targetPlayer.Character then
        local targetPart = targetPlayer.Character:FindFirstChild(targetPartName) or getRootPart(targetPlayer.Character)
        
        if targetPart then
            if aimAssistEnabled then
                local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, aimStrength)
            end

            if autoShootEnabled and (tick() - lastShootTime) >= shootDelay then
                lastShootTime = tick()
                pcall(function()
                    if mouse1click then
                        mouse1click()
                    elseif mouse1press then
                        mouse1press()
                        task.wait(0.01)
                        mouse1release()
                    end
                end)
            end
        end
    end
end)

-- Player Join/Leave
Players.PlayerAdded:Connect(function(player)
    if espEnabled then createESP(player) end
    if skeletonEnabled then createSkeleton(player) end
    if tracersEnabled then createTracer(player) end
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    removeSkeleton(player)
    removeTracer(player)
end)

Library:Notify("Seven Loaded (LinoriaLib)")

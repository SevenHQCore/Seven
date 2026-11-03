local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Load Rayfield UI Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create Main Window
local Window = Rayfield:CreateWindow({
    Name = "NoFaceShop | Admin & Tools",
    LoadingTitle = "Dev by Seven System",
    LoadingSubtitle = "by Owner",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

-- Create Tabs
local WeaponTab = Window:CreateTab("Weapon Mods", 4483362458)
local MovementTab = Window:CreateTab("Movement & Fun", 4483362458)
local ESPTab = Window:CreateTab("ESP & Highlight", 4483362458)
local AimTab = Window:CreateTab("Aim Assist", 4483362458)
local ThemeTab = Window:CreateTab("Theme & Style", 4483362458)

---------------------------------------------------------
-- STATE VARIABLES
---------------------------------------------------------
-- Weapon Mods State
local rapidFireEnabled = false
local fireRateMultiplier = 3
local noRecoilEnabled = false

-- Spin Player State
local spinEnabled = false
local spinSpeed = 50

-- Custom FOV State
local customFovEnabled = false
local targetFov = 70
local cameraZoomDistance = 12

-- Box ESP & Highlight State
local espEnabled = false
local selectedPlayerName = nil
local highlightColor = Color3.fromRGB(255, 0, 0)
local highlightFillTransparency = 0.5
local espObjects = {}

-- Skeleton ESP State
local skeletonEnabled = false
local skeletonColor = Color3.fromRGB(0, 255, 255)
local skeletonObjects = {}

-- Tracer ESP State
local tracersEnabled = false
local tracerColor = Color3.fromRGB(255, 255, 255)
local tracerObjects = {}

-- Aim Assist State
local aimAssistEnabled = false
local wallbangEnabled = false  
local aimStrength = 0.5        
local fovRadius = 150          
local targetPartName = "Head"  
local teamCheck = false

-- FOV Circle Visual
local showFovCircle = true
local fovColor = Color3.fromRGB(255, 255, 255)

-- Custom FX State
local shootingStarsEnabled = false
local starObjects = {}
local starSpeed = 8

---------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------
local function getRootPart(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character.PrimaryPart
end

---------------------------------------------------------
-- GLOBAL HOOK FOR WALLBANG
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
-- RAYFIELD UI TABS
---------------------------------------------------------
WeaponTab:CreateToggle({
    Name = "Enable Rapid Fire",
    CurrentValue = false,
    Flag = "RapidFireToggle",
    Callback = function(Value) rapidFireEnabled = Value end,
})

WeaponTab:CreateSlider({
    Name = "Rapid Fire Multiplier (X Speed)",
    Range = {1, 10},
    Increment = 0.5,
    Suffix = "x",
    CurrentValue = 3,
    Flag = "RapidFireSpeed",
    Callback = function(Value) fireRateMultiplier = Value end,
})

WeaponTab:CreateToggle({
    Name = "Enable No Recoil",
    CurrentValue = false,
    Flag = "NoRecoilToggle",
    Callback = function(Value) noRecoilEnabled = Value end,
})

MovementTab:CreateToggle({
    Name = "Enable Custom FOV & Distance",
    CurrentValue = false,
    Flag = "CustomFovToggle",
    Callback = function(Value) 
        customFovEnabled = Value 
        if not Value then
            Camera.FieldOfView = 70
            LocalPlayer.CameraMaxZoomDistance = 400
            LocalPlayer.CameraMinZoomDistance = 0.5
        end
    end,
})

MovementTab:CreateSlider({
    Name = "Camera FOV",
    Range = {30, 120},
    Increment = 1,
    Suffix = "FOV",
    CurrentValue = 70,
    Flag = "CameraFovSlider",
    Callback = function(Value) targetFov = Value end,
})

MovementTab:CreateSlider({
    Name = "Camera Distance",
    Range = {10, 200},
    Increment = 5,
    Suffix = "Studs",
    CurrentValue = 12,
    Flag = "CameraDistanceSlider",
    Callback = function(Value) cameraZoomDistance = Value end,
})

MovementTab:CreateToggle({
    Name = "Enable Spin Player",
    CurrentValue = false,
    Flag = "SpinToggle",
    Callback = function(Value) spinEnabled = Value end,
})

MovementTab:CreateSlider({
    Name = "Spin Speed",
    Range = {10, 200},
    Increment = 5,
    Suffix = "Speed",
    CurrentValue = 50,
    Flag = "SpinSpeedSlider",
    Callback = function(Value) spinSpeed = Value end,
})

-- ESP TAB
ESPTab:CreateToggle({
    Name = "Enable Box ESP, Info & HealthBar",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(Value)
        espEnabled = Value
        if not Value then
            for plr, gui in pairs(espObjects) do if gui then gui:Destroy() end end
            espObjects = {}
        else
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createESP(plr) end
            end
        end
    end,
})

ESPTab:CreateToggle({
    Name = "Enable Tracing Lines (Tracers)",
    CurrentValue = false,
    Flag = "TracersToggle",
    Callback = function(Value)
        tracersEnabled = Value
        if not Value then
            for plr in pairs(tracerObjects) do removeTracer(plr) end
        end
    end,
})

ESPTab:CreateColorPicker({
    Name = "Tracers Color",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "TracerColorPicker",
    Callback = function(Value)
        tracerColor = Value
        for _, line in pairs(tracerObjects) do line.Color = tracerColor end
    end
})

ESPTab:CreateToggle({
    Name = "Enable Skeleton ESP",
    CurrentValue = false,
    Flag = "SkeletonToggle",
    Callback = function(Value)
        skeletonEnabled = Value
        if not Value then
            for plr in pairs(skeletonObjects) do removeSkeleton(plr) end
        else
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createSkeleton(plr) end
            end
        end
    end,
})

ESPTab:CreateColorPicker({
    Name = "Skeleton ESP Color",
    Color = Color3.fromRGB(0, 255, 255),
    Flag = "SkeletonColorPicker",
    Callback = function(Value) skeletonColor = Value end
})

local PlayerDropdown = ESPTab:CreateDropdown({
    Name = "Select Player",
    Options = getPlayerNames(),
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "PlayerDropdown",
    Callback = function(Option) selectedPlayerName = Option[1] end,
})

ESPTab:CreateButton({
    Name = "Refresh Player List",
    Callback = function() PlayerDropdown:Refresh(getPlayerNames()) end,
})

ESPTab:CreateColorPicker({
    Name = "ESP Box & Highlight Color",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "ColorPicker",
    Callback = function(Value)
        highlightColor = Value
        for _, billboard in pairs(espObjects) do
            local box = billboard:FindFirstChild("BoxBorder")
            if box then box.BorderColor3 = highlightColor end
        end
    end
})

ESPTab:CreateButton({
    Name = "Highlight Selected Player",
    Callback = function()
        if selectedPlayerName then
            local plr = Players:FindFirstChild(selectedPlayerName)
            if plr then applyHighlight(plr) end
        end
    end,
})

ESPTab:CreateButton({
    Name = "Highlight ALL Players",
    Callback = function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then applyHighlight(plr) end
        end
    end,
})

ESPTab:CreateButton({
    Name = "Clear Highlights",
    Callback = function()
        for _, plr in ipairs(Players:GetPlayers()) do removeHighlight(plr) end
    end,
})

-- AIM ASSIST TAB
AimTab:CreateToggle({
    Name = "Enable Aim Assist",
    CurrentValue = false,
    Flag = "AimAssistToggle",
    Callback = function(Value) aimAssistEnabled = Value end,
})

AimTab:CreateToggle({
    Name = "Wallbang / Ignore Walls",
    CurrentValue = false,
    Flag = "WallbangToggle",
    Callback = function(Value) wallbangEnabled = Value end,
})

AimTab:CreateSlider({
    Name = "Aim Strength (Smoothness)",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "Strength",
    CurrentValue = 0.5,
    Flag = "AimStrengthSlider",
    Callback = function(Value) aimStrength = Value end,
})

AimTab:CreateSlider({
    Name = "FOV Radius (Pixels)",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 150,
    Flag = "FOVRadiusSlider",
    Callback = function(Value)
        fovRadius = Value
        FOVCircle.Radius = fovRadius
    end,
})

AimTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = true,
    Flag = "ShowFOVCircleToggle",
    Callback = function(Value) showFovCircle = Value end,
})

AimTab:CreateColorPicker({
    Name = "FOV Circle Color",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "FOVCircleColorPicker",
    Callback = function(Value)
        fovColor = Value
        FOVCircle.Color = fovColor
    end,
})

AimTab:CreateDropdown({
    Name = "Target Body Part",
    Options = {"Head", "HumanoidRootPart"},
    CurrentOption = {"Head"},
    MultipleOptions = false,
    Flag = "TargetPartDropdown",
    Callback = function(Option) targetPartName = Option[1] end,
})

AimTab:CreateToggle({
    Name = "Team Check (Ignore Teammates)",
    CurrentValue = false,
    Flag = "TeamCheckToggle",
    Callback = function(Value) teamCheck = Value end,
})

ThemeTab:CreateToggle({
    Name = "Activer Étoiles Filantes (Background FX)",
    CurrentValue = false,
    Flag = "StarsToggle",
    Callback = function(Value)
        shootingStarsEnabled = Value
        if not Value then
            for _, s in ipairs(starObjects) do if s.Line then s.Line:Remove() end end
            starObjects = {}
        end
    end,
})

ThemeTab:CreateColorPicker({
    Name = "Changer la couleur d'accentuation UI",
    Color = Color3.fromRGB(44, 120, 224),
    Flag = "UIAccentColor",
    Callback = function(Value)
        pcall(function()
            if Window and Window.ModifyTheme then
                Window:ModifyTheme({ AccentColor = Value })
            end
        end)
    end,
})

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

    -- Rapid Fire & Direct Module No Recoil
    if rapidFireEnabled or noRecoilEnabled then
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                for _, tool in ipairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        for _, desc in ipairs(tool:GetDescendants()) do
                            if desc:IsA("ModuleScript") or desc:IsA("LocalScript") then
                                pcall(function()
                                    local env = getfenv(desc)
                                    if env then
                                        if rapidFireEnabled then
                                            if env.fireRate then env.fireRate = env.fireRate / fireRateMultiplier end
                                            if env.Cooldown then env.Cooldown = env.Cooldown / fireRateMultiplier end
                                        end
                                        if noRecoilEnabled then
                                            if env.Recoil then env.Recoil = 0 end
                                            if env.recoil then env.recoil = 0 end
                                            if env.RecoilControl then env.RecoilControl = 0 end
                                            if env.CameraShake then env.CameraShake = 0 end
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end)
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

                    if lines then
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
                                    if line then
                                        line.From = Vector2.new(posA.X, posA.Y)
                                        line.To = Vector2.new(posB.X, posB.Y)
                                        line.Color = skeletonColor
                                        line.Visible = true
                                    end
                                else
                                    if lines[idx] then lines[idx].Visible = false end
                                end
                            else
                                if lines[idx] then lines[idx].Visible = false end
                            end
                        end
                    end
                else
                    removeSkeleton(player)
                end
            end
        end
    end

    -- Aim Assist Logic
    if aimAssistEnabled then
        local targetPlayer = getClosestPlayerToCrosshair()
        if targetPlayer and targetPlayer.Character then
            local targetPart = targetPlayer.Character:FindFirstChild(targetPartName) or getRootPart(targetPlayer.Character)
            if targetPart then
                local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, aimStrength)
            end
        end
    end
end)

-- Player Join/Leave
Players.PlayerAdded:Connect(function(player)
    if espEnabled then createESP(player) end
    if skeletonEnabled then createSkeleton(player) end
    if tracersEnabled then createTracer(player) end
    pcall(function() PlayerDropdown:Refresh(getPlayerNames()) end)
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    removeSkeleton(player)
    removeTracer(player)
    pcall(function() PlayerDropdown:Refresh(getPlayerNames()) end)
end)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "Rayfield Example Window",
   Icon = 0,
   LoadingTitle = "Rayfield Interface Suite",
   LoadingSubtitle = "by Sirius",
   Theme = "Default",
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil,
      FileName = "Big Hub"
   },
   KeySystem = false,
   KeySettings = {
      Title = "Untitled",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided", 
      FileName = "Key",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = {"Hello"}
   }
})

local Main = Window:CreateTab("Main", "home")
local Section = Main:CreateSection("Options")

local FullBrightEnabled = false

local FullBrightToggle = Main:CreateToggle({
    Name = "Full Bright",
    CurrentValue = false,
    Flag = "FullBright",
    Callback = function(Value)
        FullBrightEnabled = Value
        if FullBrightEnabled then
            coroutine.wrap(function()
                while FullBrightEnabled do
                    game:GetService("Lighting").Ambient = Color3.new(1.65, 1.65, 1.65)
                    game:GetService("RunService").Heartbeat:Wait()
                end
            end)()
        else
            game:GetService("Lighting").Ambient = Color3.new(0, 0, 0)
        end
    end,
})

local NoclipEnabled = false

local NoclipToggle = Main:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "Noclip",
    Callback = function(Value)
        local character = game.Players.LocalPlayer.Character
        NoclipEnabled = Value
        if NoclipEnabled then
            coroutine.wrap(function()
                while NoclipEnabled do
                    if character and character.Parent then
                        for _, part in pairs(character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                    game:GetService("RunService").Heartbeat:Wait()
                end
            end)()
        else
            if character and character.Parent then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
			character:FindFirstChild("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end,
})

local currentBoostAmount = 0
local heartbeatConnection
local runningConnection

local SpeedBoostSlider = Main:CreateSlider({
    Name = "Speed",
    Range = {0, 5},
    Increment = 0.05,
    Suffix = "Boost",
    CurrentValue = 0,
    Flag = "SpeedBoostSlider",
    Callback = function(Value)
        currentBoostAmount = Value
        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end
        if runningConnection then
            runningConnection:Disconnect()
            runningConnection = nil
        end
        if currentBoostAmount > 0 and game.Players.LocalPlayer.Character then
            local character = game.Players.LocalPlayer.Character
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid and character.PrimaryPart then
                local boosting = false
                heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function()
                    if boosting and currentBoostAmount > 0 then
                        character:SetPrimaryPartCFrame(character.PrimaryPart.CFrame + humanoid.MoveDirection * currentBoostAmount)
                    end
                end)
                runningConnection = humanoid.Running:Connect(function(speed)
                    boosting = humanoid.MoveDirection.Magnitude > 0
                end)
            end
        end
    end,
})

local flying = false
local flyConnection
local flySpeed = 50

local FlyToggle = Main:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Flag = "FlyToggle",
    Callback = function(Value)
        flying = Value

        if flyConnection then
            flyConnection:Disconnect()
            flyConnection = nil
        end

        local character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")
        local humanoid = character:WaitForChild("Humanoid")

        if flying then
            humanoid.PlatformStand = true

            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.zero
            bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            bv.P = 1500
            bv.Parent = hrp

            local bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9) -- 🔧 Strong torque
            bg.P = 6000 -- 🔧 High power for quick rotation
            bg.CFrame = hrp.CFrame
            bg.Parent = hrp

            flyConnection = game:GetService("RunService").RenderStepped:Connect(function()
                local cam = workspace.CurrentCamera
                local move = Vector3.zero

                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then
                    move += cam.CFrame.LookVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then
                    move -= cam.CFrame.LookVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then
                    move -= cam.CFrame.RightVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then
                    move += cam.CFrame.RightVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then
                    move += cam.CFrame.UpVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftControl) then
                    move -= cam.CFrame.UpVector
                end

                if move.Magnitude > 0 then
                    bv.Velocity = move.Unit * flySpeed
                else
                    bv.Velocity = Vector3.zero
                end

                bg.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector)
            end)
        else
            humanoid.PlatformStand = false
            local bv = hrp:FindFirstChildOfClass("BodyVelocity")
            if bv then bv:Destroy() end
            local bg = hrp:FindFirstChildOfClass("BodyGyro")
            if bg then bg:Destroy() end
        end
    end,
})

Main:CreateSlider({
    Name = "Fly Speed",
    Range = {1, 1000},
    Increment = 1,
    Suffix = "Speed",
    CurrentValue = 50,
    Flag = "FlySpeedSlider",
    Callback = function(Value)
        flySpeed = Value
    end,
})

local Combat = Window:CreateTab("Combat", "home")
local Section = Combat:CreateSection("ESP")

local updatesPerSecond = 6.67 -- example default value
local intervalupd = 1 / updatesPerSecond

Combat:CreateSlider({
    Name = "Line Update Frequency",
    Range = {1, 120},  -- from 1 update per second to 100 updates per second
    Increment = 1,
    Suffix = "Times/sec",
    CurrentValue = 6.67,
    Flag = "FlySpeedSlider",
    Callback = function(Value)
        updatesPerSecond = Value
        intervalupd = 1 / updatesPerSecond
    end,
})


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local espBoxes = {}
local lineThickness = 3.4
local wallGap = 2
local connection = nil
local playerAddedConnection = nil
local playerRemovingConnection = nil

local Boxes = Combat:CreateToggle({
    Name = "Boxes",
    CurrentValue = false,
    Flag = "Toggle1",
    Callback = function(Value)
        if Value == true then
            -- Create ESP boxes for existing players
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and not espBoxes[player] then
                    local box1 = {
                        Top = Drawing.new("Line"),
                        Bottom = Drawing.new("Line"),
                        Left = Drawing.new("Line"),
                        Right = Drawing.new("Line")
                    }
                    local box2 = {
                        Top = Drawing.new("Line"),
                        Bottom = Drawing.new("Line"),
                        Left = Drawing.new("Line"),
                        Right = Drawing.new("Line")
                    }
                    for _, line in pairs(box1) do
                        line.Thickness = lineThickness
                        line.Transparency = 1
                        line.ZIndex = 1
                        line.Color = Color3.new(1, 1, 1)
                        line.Visible = false
                    end
                    for _, line in pairs(box2) do
                        line.Thickness = lineThickness
                        line.Transparency = 1
                        line.ZIndex = 1
                        line.Color = Color3.new(1, 1, 1)
                        line.Visible = false
                    end
                    espBoxes[player] = {front = box1, side = box2}
                end
            end

            playerAddedConnection = Players.PlayerAdded:Connect(function(player)
                if player ~= LocalPlayer and not espBoxes[player] then
                    local box1 = {
                        Top = Drawing.new("Line"),
                        Bottom = Drawing.new("Line"),
                        Left = Drawing.new("Line"),
                        Right = Drawing.new("Line")
                    }
                    local box2 = {
                        Top = Drawing.new("Line"),
                        Bottom = Drawing.new("Line"),
                        Left = Drawing.new("Line"),
                        Right = Drawing.new("Line")
                    }
                    for _, line in pairs(box1) do
                        line.Thickness = lineThickness
                        line.Transparency = 1
                        line.ZIndex = 1
                        line.Color = Color3.new(1, 1, 1)
                        line.Visible = false
                    end
                    for _, line in pairs(box2) do
                        line.Thickness = lineThickness
                        line.Transparency = 1
                        line.ZIndex = 1
                        line.Color = Color3.new(1, 1, 1)
                        line.Visible = false
                    end
                    espBoxes[player] = {front = box1, side = box2}
                end
            end)

            playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
                if espBoxes[player] then
                    for _, box in pairs(espBoxes[player]) do
                        for _, line in pairs(box) do
                            line:Remove()
                        end
                    end
                    espBoxes[player] = nil
                end
            end)

            local elapsed = 0

            connection = RunService.RenderStepped:Connect(function(dt)
                elapsed = elapsed + dt
                if elapsed < intervalupd then
                    return
                end
                elapsed = 0

                for player, boxes in pairs(espBoxes) do
                    local character = player.Character
                    local hrp = character and character:FindFirstChild("HumanoidRootPart")
                    if character and hrp then
                        local cf = hrp.CFrame
                        local boxWidth = 2
                        local boxHeight = 4

                        local halfWidth = boxWidth / 2
                        local halfHeight = boxHeight / 2

                        -- Front box (original orientation)
                        local front_topLeft3D = cf * Vector3.new(-halfWidth, halfHeight, 0)
                        local front_topRight3D = cf * Vector3.new(halfWidth, halfHeight, 0)
                        local front_bottomLeft3D = cf * Vector3.new(-halfWidth, -halfHeight, 0)
                        local front_bottomRight3D = cf * Vector3.new(halfWidth, -halfHeight, 0)

                        -- Side box (rotated 90 degrees)
                        local rotatedCF = cf * CFrame.Angles(0, math.rad(90), 0)
                        local side_topLeft3D = rotatedCF * Vector3.new(-halfWidth, halfHeight, 0)
                        local side_topRight3D = rotatedCF * Vector3.new(halfWidth, halfHeight, 0)
                        local side_bottomLeft3D = rotatedCF * Vector3.new(-halfWidth, -halfHeight, 0)
                        local side_bottomRight3D = rotatedCF * Vector3.new(halfWidth, -halfHeight, 0)

                        -- Update front box
                        local screenTL, onScreen1 = Camera:WorldToViewportPoint(front_topLeft3D)
                        local screenTR, onScreen2 = Camera:WorldToViewportPoint(front_topRight3D)
                        local screenBL, onScreen3 = Camera:WorldToViewportPoint(front_bottomLeft3D)
                        local screenBR, onScreen4 = Camera:WorldToViewportPoint(front_bottomRight3D)

                        if onScreen1 and onScreen2 and onScreen3 and onScreen4 then
                            boxes.front.Top.From = Vector2.new(screenTL.X + wallGap, screenTL.Y)
                            boxes.front.Top.To = Vector2.new(screenTR.X - wallGap, screenTR.Y)
                            boxes.front.Bottom.From = Vector2.new(screenBL.X + wallGap, screenBL.Y)
                            boxes.front.Bottom.To = Vector2.new(screenBR.X - wallGap, screenBR.Y)
                            boxes.front.Left.From = Vector2.new(screenTL.X, screenTL.Y)
                            boxes.front.Left.To = Vector2.new(screenBL.X, screenBL.Y)
                            boxes.front.Right.From = Vector2.new(screenTR.X, screenTR.Y)
                            boxes.front.Right.To = Vector2.new(screenBR.X, screenBR.Y)

                            local color = player.Team and player.Team.TeamColor.Color or Color3.new(1, 1, 1)
                            for _, line in pairs(boxes.front) do
                                line.Color = color
                                line.Visible = true
                            end
                        else
                            for _, line in pairs(boxes.front) do
                                line.Visible = false
                            end
                        end

                        -- Update side box
                        local screenTL2, onScreen21 = Camera:WorldToViewportPoint(side_topLeft3D)
                        local screenTR2, onScreen22 = Camera:WorldToViewportPoint(side_topRight3D)
                        local screenBL2, onScreen23 = Camera:WorldToViewportPoint(side_bottomLeft3D)
                        local screenBR2, onScreen24 = Camera:WorldToViewportPoint(side_bottomRight3D)

                        if onScreen21 and onScreen22 and onScreen23 and onScreen24 then
                            boxes.side.Top.From = Vector2.new(screenTL2.X + wallGap, screenTL2.Y)
                            boxes.side.Top.To = Vector2.new(screenTR2.X - wallGap, screenTR2.Y)
                            boxes.side.Bottom.From = Vector2.new(screenBL2.X + wallGap, screenBL2.Y)
                            boxes.side.Bottom.To = Vector2.new(screenBR2.X - wallGap, screenBR2.Y)
                            boxes.side.Left.From = Vector2.new(screenTL2.X, screenTL2.Y)
                            boxes.side.Left.To = Vector2.new(screenBL2.X, screenBL2.Y)
                            boxes.side.Right.From = Vector2.new(screenTR2.X, screenTR2.Y)
                            boxes.side.Right.To = Vector2.new(screenBR2.X, screenBR2.Y)

                            local color = player.Team and player.Team.TeamColor.Color or Color3.new(1, 1, 1)
                            for _, line in pairs(boxes.side) do
                                line.Color = color
                                line.Visible = true
                            end
                        else
                            for _, line in pairs(boxes.side) do
                                line.Visible = false
                            end
                        end

                    else
                        for _, box in pairs(boxes) do
                            for _, line in pairs(box) do
                                line.Visible = false
                            end
                        end
                    end
                end
            end)

        else
            -- Toggle OFF: disconnect everything and remove drawings
            if connection then
                connection:Disconnect()
                connection = nil
            end

            if playerAddedConnection then
                playerAddedConnection:Disconnect()
                playerAddedConnection = nil
            end

            if playerRemovingConnection then
                playerRemovingConnection:Disconnect()
                playerRemovingConnection = nil
            end

            -- Remove all drawings and clear espBoxes
            for player, boxes in pairs(espBoxes) do
                for _, box in pairs(boxes) do
                    for _, line in pairs(box) do
                        line.Visible = false
                        line:Remove()
                    end
                end
                espBoxes[player] = nil
            end
            espBoxes = {}
        end
    end,
})


local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer
local infJumpConnection
local infJumpDebounce = false

local InfiniteJumpToggle = Main:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "InfiniteJumpToggle",
    Callback = function(Value)
        if Value then
            if infJumpConnection then infJumpConnection:Disconnect() end
            infJumpDebounce = false

            infJumpConnection = UserInputService.JumpRequest:Connect(function()
                if not infJumpDebounce and player.Character then
                    local humanoid = player.Character:FindFirstChildWhichIsA("Humanoid")
                    if humanoid then
                        infJumpDebounce = true
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        task.wait()
                        infJumpDebounce = false
                    end
                end
            end)

        else
            if infJumpConnection then
                infJumpConnection:Disconnect()
                infJumpConnection = nil
            end
            infJumpDebounce = false
        end
    end,
})


local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local nameLabels = {}
local nameEspEnabled = false
local playerAddedConn
local charAddedConns = {}

local NameEspToggle = Combat:CreateToggle({
    Name = "Names",
    CurrentValue = false,
    Flag = "ToggleNameESP",
    Callback = function(value)
        nameEspEnabled = value
        if nameEspEnabled then
            for _, player in pairs(Players:GetPlayers()) do
                if player.Character and not nameLabels[player.Character] then
                    local head = player.Character:FindFirstChild("Head")
                    if head then
                        local billboard = Instance.new("BillboardGui")
                        billboard.Name = "NameESPBillboard"
                        billboard.Adornee = head
                        billboard.Size = UDim2.new(0, 200, 0, 40)
                        billboard.StudsOffset = Vector3.new(0, 2, 0)
                        billboard.AlwaysOnTop = true
                        billboard.Parent = game:GetService("CoreGui")

                        local textLabel = Instance.new("TextLabel", billboard)
                        textLabel.Size = UDim2.new(1, 0, 1, 0)
                        textLabel.BackgroundTransparency = 1
                        textLabel.TextColor3 = Color3.new(1, 1, 1)
                        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
                        textLabel.TextStrokeTransparency = 0
                        textLabel.Font = Enum.Font.SourceSansBold
                        textLabel.TextSize = 18
                        textLabel.TextScaled = false
                        textLabel.TextWrapped = false
                        textLabel.TextXAlignment = Enum.TextXAlignment.Center
                        textLabel.TextYAlignment = Enum.TextYAlignment.Center

                        nameLabels[player.Character] = billboard

                        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                        if humanoid then
						--[[
                            humanoid.Died:Connect(function()
                                if nameLabels[player.Character] then
                                    nameLabels[player.Character]:Destroy()
                                    nameLabels[player.Character] = nil
                                end
                            end)
							]]
                        end
                    end
                end
                charAddedConns[player] = player.CharacterAdded:Connect(function(character)
                    if nameEspEnabled then
                        local head = character:WaitForChild("Head", 5)
                        if head and not nameLabels[character] then
                            local billboard = Instance.new("BillboardGui")
                            billboard.Name = "NameESPBillboard"
                            billboard.Adornee = head
                            billboard.Size = UDim2.new(0, 200, 0, 40)
                            billboard.StudsOffset = Vector3.new(0, 2, 0)
                            billboard.AlwaysOnTop = true
                            billboard.Parent = game:GetService("CoreGui")

                            local textLabel = Instance.new("TextLabel", billboard)
                            textLabel.Size = UDim2.new(1, 0, 1, 0)
                            textLabel.BackgroundTransparency = 1
                            textLabel.TextColor3 = Color3.new(1, 1, 1)
                            textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
                            textLabel.TextStrokeTransparency = 0
                            textLabel.Font = Enum.Font.SourceSansBold
                            textLabel.TextSize = 18
                            textLabel.TextScaled = false
                            textLabel.TextWrapped = false
                            textLabel.TextXAlignment = Enum.TextXAlignment.Center
                            textLabel.TextYAlignment = Enum.TextYAlignment.Center

                            nameLabels[character] = billboard

                            local humanoid = character:FindFirstChildOfClass("Humanoid")
                            if humanoid then
							--[[
                                humanoid.Died:Connect(function()
                                    if nameLabels[character] then
                                        nameLabels[character]:Destroy()
                                        nameLabels[character] = nil
                                    end
                                end)
								 ]]
                            end
                        end
                    end
                end)
            end

            playerAddedConn = Players.PlayerAdded:Connect(function(player)
                if nameEspEnabled then
                    charAddedConns[player] = player.CharacterAdded:Connect(function(character)
                        if nameEspEnabled then
                            local head = character:WaitForChild("Head", 5)
                            if head and not nameLabels[character] then
                                local billboard = Instance.new("BillboardGui")
                                billboard.Name = "NameESPBillboard"
                                billboard.Adornee = head
                                billboard.Size = UDim2.new(0, 200, 0, 40)
                                billboard.StudsOffset = Vector3.new(0, 2, 0)
                                billboard.AlwaysOnTop = true
                                billboard.Parent = game:GetService("CoreGui")

                                local textLabel = Instance.new("TextLabel", billboard)
                                textLabel.Size = UDim2.new(1, 0, 1, 0)
                                textLabel.BackgroundTransparency = 1
                                textLabel.TextColor3 = Color3.new(1, 1, 1)
                                textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
                                textLabel.TextStrokeTransparency = 0
                                textLabel.Font = Enum.Font.SourceSansBold
                                textLabel.TextSize = 18
                                textLabel.TextScaled = false
                                textLabel.TextWrapped = false
                                textLabel.TextXAlignment = Enum.TextXAlignment.Center
                                textLabel.TextYAlignment = Enum.TextYAlignment.Center

                                nameLabels[character] = billboard

                                local humanoid = character:FindFirstChildOfClass("Humanoid")
                                if humanoid then
								--[[
                                    humanoid.Died:Connect(function()
                                        if nameLabels[character] then
                                            nameLabels[character]:Destroy()
                                            nameLabels[character] = nil
                                        end
                                    end)]]
                                end
                            end
                        end
                    end)
                end
            end)

            -- Update the distance every frame
            game:GetService("RunService").RenderStepped:Connect(function()
                if nameEspEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local localHRP = LocalPlayer.Character.HumanoidRootPart.Position
                    for player, billboard in pairs(nameLabels) do
                        if player and player.Parent and player:FindFirstChild("HumanoidRootPart") then
                            local dist = (player.HumanoidRootPart.Position - localHRP).Magnitude
                            local textLabel = billboard:FindFirstChildOfClass("TextLabel")
                            if textLabel then
                                -- Find the player object from the character
                                local playerObj = Players:GetPlayerFromCharacter(player)
                                if playerObj then
                                    textLabel.Text = playerObj.Name .. ", " .. math.floor(dist)
                                end
                            end
                        end
                    end
                end
            end)
        else
            for _, billboard in pairs(nameLabels) do
                billboard:Destroy()
            end
            nameLabels = {}

            if playerAddedConn then
                playerAddedConn:Disconnect()
                playerAddedConn = nil
            end
            for _, conn in pairs(charAddedConns) do
                conn:Disconnect()
            end
            charAddedConns = {}
        end
    end,
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local tracers = {}
local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
local lineThickness = 2.5
local tracerConnection = nil
local playerRemovingConnection = nil
local elapsed = 0

local Toggle = Combat:CreateToggle({ 
    Name = "Tracers",
    CurrentValue = false,
    Flag = "Toggle1",
    Callback = function(enabled)
        if enabled then
            -- Clear elapsed timer in case toggle was off for a while
            elapsed = 0

            -- Cleanup on player leaving
            playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
                if tracers[player] then
                    tracers[player]:Remove()
                    tracers[player] = nil
                end
            end)

            tracerConnection = RunService.RenderStepped:Connect(function(dt)
                elapsed = elapsed + dt
                if elapsed < intervalupd then
                    return
                end
                elapsed = 0

                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = player.Character.HumanoidRootPart
                        local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                        if onScreen then
                            if not tracers[player] then
                                local line = Drawing.new("Line")
                                line.Visible = false
                                line.Thickness = lineThickness
                                line.Transparency = 1
                                tracers[player] = line
                            end
                            local line = tracers[player]
                            local teamColor = (player.Team and player.Team.TeamColor) and player.Team.TeamColor.Color or Color3.new(1,1,1)
                            line.Color = teamColor
                            line.From = origin
                            line.To = Vector2.new(screenPos.X, screenPos.Y)
                            line.Visible = true
                        else
                            if tracers[player] then
                                tracers[player].Visible = false
                            end
                        end
                    else
                        if tracers[player] then
                            tracers[player]:Remove()
                            tracers[player] = nil
                        end
                    end
                end
            end)
        else
            if tracerConnection then
                tracerConnection:Disconnect()
                tracerConnection = nil
            end

            if playerRemovingConnection then
                playerRemovingConnection:Disconnect()
                playerRemovingConnection = nil
            end

            for player, line in pairs(tracers) do
                line.Visible = false
                line:Remove()
                tracers[player] = nil
            end
        end
    end,
})




local Section = Combat:CreateSection("Aimbot")
local playerss = game:GetService("Players")
local frameservc = game:GetService("RunService")
local inputservc = game:GetService("UserInputService")
local localplayerinstc = playerss.LocalPlayer
local currentcameradistance = workspace.CurrentCamera
local isrclickheld = false
local isaimbotenabled = false
local israycaston = false
local teamcheckenabled = false
local tfov = 40
local mouse = localplayerinstc:GetMouse()
local mouseWeight = 0.5
local selectedpart = "Head"

inputservc.InputBegan:Connect(function(inputEvent)
    if inputEvent.UserInputType == Enum.UserInputType.MouseButton2 then
        isrclickheld = true
    end
end)

inputservc.InputEnded:Connect(function(inputEvent)
    if inputEvent.UserInputType == Enum.UserInputType.MouseButton2 then
        isrclickheld = false
    end
end)

frameservc.RenderStepped:Connect(function()
    if isrclickheld and isaimbotenabled then
        local character = localplayerinstc.Character
        if character then
            local closestplayer = nil
            local bestscore = math.huge
            local cameradirc = currentcameradistance.CFrame.LookVector

            for _, player in pairs(playerss:GetPlayers()) do
                if player ~= localplayerinstc and player.Character and player.Character:FindFirstChild("Head") then
                    local localTeam = localplayerinstc.Team
                    local targetTeam = player.Team
                    if teamcheckenabled and localTeam and targetTeam and localTeam == targetTeam then
                        continue
                    end

                    local targetCharacter = player.Character
                    if targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") then
                        local humanoid = targetCharacter:FindFirstChild("Humanoid")
                        if humanoid and humanoid.Health > 0 then
                            local targetPart
                            if selectedpart == "Head" then
                                targetPart = targetCharacter:FindFirstChild("Head")
                            elseif selectedpart == "Torso" then
                                targetPart = targetCharacter:FindFirstChild("HumanoidRootPart")
                            end

                            if targetPart then
                                local directiontoplayer = (targetPart.Position - character.Head.Position).Unit
                                local distancetoplayer = (targetPart.Position - character.Head.Position).Magnitude
                                local angleBetween = math.acos(cameradirc:Dot(directiontoplayer))
                                local halfFOVRadians = math.rad(tfov / 2)
                                if angleBetween <= halfFOVRadians then
                                    local screenPoint = currentcameradistance:WorldToScreenPoint(targetPart.Position)
                                    local mouseDistance = (Vector2.new(screenPoint.X, screenPoint.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude
                                    local combinedScore = (distancetoplayer * (1 - mouseWeight)) + (mouseDistance * mouseWeight)
                                    if combinedScore < bestscore then
                                        bestscore = combinedScore
                                        closestplayer = player
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if closestplayer and closestplayer.Character then
                local canTarget = true
                if israycaston then
                    local targetPart = nil
                    if selectedpart == "Head" then
                        targetPart = closestplayer.Character:FindFirstChild("Head")
                    elseif selectedpart == "Torso" then
                        targetPart = closestplayer.Character:FindFirstChild("HumanoidRootPart")
                    end
                    if targetPart then
                        local partsObscuring = workspace.CurrentCamera:GetPartsObscuringTarget(
                            {character.Head.Position, targetPart.Position},
                            {character}
                        )
                        for _, part in ipairs(partsObscuring) do
                            local partIsPlayer = false
                            for _, playerCheck in ipairs(playerss:GetPlayers()) do
                                if playerCheck.Character and part:IsDescendantOf(playerCheck.Character) then
                                    partIsPlayer = true
                                    break
                                end
                            end
                            if not partIsPlayer then
                                canTarget = false
                                break
                            end
                        end
                    else
                        canTarget = false
                    end
                end

                if canTarget then
                    local targetPart = nil
                    if selectedpart == "Head" then
                        targetPart = closestplayer.Character:FindFirstChild("Head")
                    elseif selectedpart == "Torso" then
                        targetPart = closestplayer.Character:FindFirstChild("HumanoidRootPart")
                    end
                    if targetPart then
                        currentcameradistance.CFrame = CFrame.new(currentcameradistance.CFrame.Position, targetPart.Position)
                    end
                end
            end
        end
    end
end)

local AimbotToggle = Combat:CreateToggle({
    Name = "Aimbot",
    CurrentValue = false,
    Flag = "ToggleCameraLock",
    Callback = function(Value)
        isaimbotenabled = Value
    end,
})

local RaycastToggle = Combat:CreateToggle({
    Name = "Vibility Check",
    CurrentValue = false,
    Flag = "ToggleRaycast",
    Callback = function(Value)
        israycaston = Value
    end,
})

local TeamCheckToggle = Combat:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "ToggleTeamCheck",
    Callback = function(Value)
        teamcheckenabled = Value
    end,
})

local FOVSlider = Combat:CreateSlider({
    Name = "FOV",
    Range = {0, 80},
    Increment = 1,
    Suffix = " ",
    CurrentValue = 40,
    Flag = "Slider1",
    Callback = function(Value)
        tfov = Value
    end,
})

local FOVCircle

local FOVToggle = Combat:CreateToggle({
    Name = "Show FOV",
    CurrentValue = false,
    Flag = "ToggleFOVCircle",
    Callback = function(Value)
        if Value then
            FOVCircle = Drawing.new("Circle")
            FOVCircle.Thickness = 2
            FOVCircle.NumSides = 64
            FOVCircle.Color = Color3.new(1, 1, 1)
            FOVCircle.Transparency = 1
            FOVCircle.Filled = false
            FOVCircle.Position = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
            FOVCircle.Visible = true

            game:GetService("RunService").RenderStepped:Connect(function()
                if FOVCircle then
                    FOVCircle.Radius = tfov * 5
                end
            end)
        else
            if FOVCircle then
                FOVCircle:Remove()
                FOVCircle = nil
            end
        end
    end,
})
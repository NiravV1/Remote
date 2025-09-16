-- Config
getgenv().entaura = {
    Enabled = false, -- Start disabled
    TweenEnabled = false, -- New setting for tween toggle
    AttackRange = 35,
    AttackCooldown = 0.005,
    PrioritizeBosses = true,
    MultiTarget = true,
    ServerCooldown = 0.29,
    LastAttackTime = 0,
    MaxTargetsPerCycle = 10,
    FlyMode = true,
    FlySpeed = 50,
    UseBossSkills = true,
    LastBossSkillTime = 0,
    BossSkillCooldown = 2
}

-- Services
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local workspace = game:GetService("Workspace")
local client = players.LocalPlayer

-- Pre-cache the event for faster access
local combatEvent = replicatedStorage:WaitForChild("Event")

-- Connection management
local connections = {}

local function disconnectAll()
    for _, conn in ipairs(connections) do
        if conn then
            conn:Disconnect()
        end
    end
    connections = {}
end

-- Add tween toggle button to GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "IOwnItUI"
screenGui.Parent = game:GetService("CoreGui")
screenGui.ResetOnSpawn = false

local originalSize = UDim2.new(0, 220, 0, 350)
local frame = Instance.new("Frame")
frame.Size = originalSize
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Parent = screenGui
frame.BackgroundTransparency = 0.1
frame.Active = true
frame.Draggable = true

local contentContainer = Instance.new("Frame")
contentContainer.Size = UDim2.new(1, 0, 1, -40)
contentContainer.Position = UDim2.new(0, 0, 0, 40)
contentContainer.BackgroundTransparency = 1
contentContainer.Parent = frame

-- Create the toggle buttons
local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(0.9, 0, 0, 40)
toggle.Position = UDim2.new(0.05, 0, 0.05, 0)
toggle.Text = "Enable"
toggle.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
toggle.Font = Enum.Font.Gotham
toggle.TextSize = 14
toggle.Parent = contentContainer

local toggleCorner = Instance.new("UICorner", toggle)
toggleCorner.CornerRadius = UDim.new(0, 8)

local tweenToggle = Instance.new("TextButton")
tweenToggle.Size = UDim2.new(0.9, 0, 0, 30)
tweenToggle.Position = UDim2.new(0.05, 0, 0.28, 0)
tweenToggle.Text = "Tween: OFF"
tweenToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
tweenToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
tweenToggle.Font = Enum.Font.Gotham
tweenToggle.TextSize = 12
tweenToggle.Parent = contentContainer

local tweenToggleCorner = Instance.new("UICorner", tweenToggle)
tweenToggleCorner.CornerRadius = UDim.new(0, 8)

-- Movement functions
local function flyToTarget(hrp, targetPos, lookAtPos)
    if not getgenv().entaura.TweenEnabled then return end
    
    local humanoid = hrp.Parent:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end
    
    local speed = getgenv().entaura.FlySpeed
    local bodyPos = hrp:FindFirstChild("AuraFlight") or Instance.new("BodyPosition")
    bodyPos.Name = "AuraFlight"
    bodyPos.P = speed * 200
    bodyPos.D = speed * 10
    bodyPos.MaxForce = Vector3.new(50000, 50000, 50000)
    bodyPos.Position = targetPos
    bodyPos.Parent = hrp
    
    local bodyGyro = hrp:FindFirstChild("AuraGyro") or Instance.new("BodyGyro")
    bodyGyro.Name = "AuraGyro"
    bodyGyro.P = 20000
    bodyGyro.D = 1000
    bodyGyro.MaxTorque = Vector3.new(40000, 40000, 40000)
    bodyGyro.CFrame = CFrame.new(hrp.Position, lookAtPos)
    bodyGyro.Parent = hrp
end

local function walkToTarget(humanoid, targetPos)
    if not getgenv().entaura.TweenEnabled then
        humanoid:MoveTo(targetPos)
        return
    end
    
    local character = humanoid.Parent
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local bodyGyro = hrp:FindFirstChild("AuraLook")
    if bodyGyro then bodyGyro:Destroy() end
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "AuraLook"
    bodyGyro.P = 20000
    bodyGyro.D = 1000
    bodyGyro.MaxTorque = Vector3.new(0, 40000, 0)
    bodyGyro.CFrame = CFrame.new(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))
    bodyGyro.Parent = hrp
    
    humanoid:MoveTo(targetPos)
    
    task.delay(0.1, function()
        if bodyGyro and bodyGyro.Parent == hrp then
            bodyGyro:Destroy()
        end
    end)
end

-- Toggle functionality
toggle.MouseButton1Click:Connect(function()
    getgenv().entaura.Enabled = not getgenv().entaura.Enabled
    toggle.Text = getgenv().entaura.Enabled and "Disable" or "Enable"
    toggle.BackgroundColor3 = getgenv().entaura.Enabled and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(50, 200, 50)
    
    if getgenv().entaura.Enabled then
        startAttackLoop()
    else
        if connection then connection:Disconnect() end
        lastTarget = nil
        cleanupAuraInstances(client.Character)
    end
end)

tweenToggle.MouseButton1Click:Connect(function()
    getgenv().entaura.TweenEnabled = not getgenv().entaura.TweenEnabled
    tweenToggle.Text = "Tween: " .. (getgenv().entaura.TweenEnabled and "ON" or "OFF")
    tweenToggle.BackgroundColor3 = getgenv().entaura.TweenEnabled and Color3.fromRGB(50, 100, 200) or Color3.fromRGB(50, 50, 50)
end)

-- Initialize
toggle.Text = "Enable"
toggle.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
tweenToggle.Text = "Tween: OFF"
tweenToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
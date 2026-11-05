--!strict
--[[
    RngController.luau
    Client-side RNG animation, visual cutscenes, and visual aura attachments.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network") :: ModuleScript)

local RngController = {}
local localPlayer = Players.LocalPlayer

local activeAuraEffect: Instance? = nil

function RngController.Init()
    local auraRolled = Network.GetEvent(Network.Events.AuraRolled)
    local auraEquipped = Network.GetEvent(Network.Events.AuraEquipped)

    auraRolled.OnClientEvent:Connect(function(rolledAura: any, totalRolls: number, luck: number)
        RngController.PlayRollCutscene(rolledAura, totalRolls, luck)
    end)

    auraEquipped.OnClientEvent:Connect(function(targetPlayer: Player, auraDef: any)
        RngController.AttachAuraVFX(targetPlayer, auraDef)
    end)

    print("[RngController] Initialized with cinematic aura replication.")
end

function RngController.PlayRollCutscene(auraDef: any, totalRolls: number, luck: number)
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    local rollScreen = playerGui:FindFirstChild("RollCutsceneGui") :: ScreenGui?

    if not rollScreen then
        rollScreen = Instance.new("ScreenGui")
        rollScreen.Name = "RollCutsceneGui"
        rollScreen.ResetOnSpawn = false
        rollScreen.Parent = playerGui
    end

    rollScreen:ClearAllChildren()

    -- Dark cinematic overlay
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.Parent = rollScreen

    -- Aura title card
    local card = Instance.new("Frame")
    card.Size = UDim2.fromOffset(450, 180)
    card.Position = UDim2.fromScale(0.5, 0.45)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Parent = rollScreen

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = auraDef.Color or Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 3
    stroke.Parent = card

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = auraDef.Name:upper()
    nameLabel.TextColor3 = auraDef.Color or Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 32
    nameLabel.Parent = card

    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 0.35, 0)
    rarityLabel.Position = UDim2.new(0, 0, 0.5, 0)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Font = Enum.Font.GothamMedium
    rarityLabel.Text = string.format("1 in %s (%s)", tostring(auraDef.RarityChance), auraDef.Tier)
    rarityLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    rarityLabel.TextSize = 20
    rarityLabel.Parent = card

    -- Pop-in bounce animation
    card.Position = UDim2.fromScale(0.5, 0.6)
    card.Size = UDim2.fromOffset(200, 80)
    local tween = TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.fromScale(0.5, 0.45),
        Size = UDim2.fromOffset(450, 180),
    })
    tween:Play()

    -- Auto-dismiss after 1.8 seconds
    task.delay(1.8, function()
        if rollScreen then
            local fadeOut = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                BackgroundTransparency = 1,
            })
            fadeOut:Play()
            task.wait(0.3)
            rollScreen:ClearAllChildren()
        end
    end)
end

function RngController.AttachAuraVFX(targetPlayer: Player, auraDef: any)
    local char = targetPlayer.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    -- Clean up previous aura
    local existing = root:FindFirstChild("AuraVFXContainer")
    if existing then existing:Destroy() end

    local container = Instance.new("Attachment")
    container.Name = "AuraVFXContainer"
    container.Parent = root

    -- Particle system aura simulation
    local particles = Instance.new("ParticleEmitter")
    particles.Name = "AuraEmitter"
    particles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, auraDef.Color or Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, auraDef.SecondaryColor or Color3.fromRGB(200, 200, 200)),
    })
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.5, 1.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Rate = 28
    particles.Speed = NumberRange.new(2, 5)
    particles.Lifetime = NumberRange.new(0.8, 1.4)
    particles.SpreadAngle = Vector2.new(45, 45)
    particles.Parent = container

    -- Point light radiance
    local light = Instance.new("PointLight")
    light.Color = auraDef.Color or Color3.fromRGB(255, 255, 255)
    light.Brightness = 2.5
    light.Range = 14
    light.Parent = root
end

return RngController

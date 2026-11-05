--!strict
--[[
    CombatController.luau
    Client-side input predictor and combat visualizer.
    Captures MouseButton1 clicks and Ability keybinds (E, R, C), plays instant
    local prediction animations, and requests authoritative server validation.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network") :: ModuleScript)
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)

local CombatController = {}
local localPlayer = Players.LocalPlayer

local lastM1Time = 0
local comboIndex = 1

function CombatController.Init()
    local attackRequest = Network.GetEvent(Network.Events.AttackRequest)
    local abilityRequest = Network.GetEvent(Network.Events.AbilityRequest)

    -- M1 Punch Input Listener
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            CombatController.PerformM1(attackRequest)
        elseif input.KeyCode == Enum.KeyCode.E then
            abilityRequest:FireServer("Ability1")
        elseif input.KeyCode == Enum.KeyCode.R then
            abilityRequest:FireServer("Ability2")
        elseif input.KeyCode == Enum.KeyCode.C then
            abilityRequest:FireServer("Ultimate")
        end
    end)

    -- Replicated attack feedback from other players
    local attackReplicated = Network.GetEvent(Network.Events.AttackReplicated)
    attackReplicated.OnClientEvent:Connect(function(attacker: Player, combo: number, auraDef: any)
        if attacker ~= localPlayer then
            CombatController.PlayAttackVFX(attacker, combo, auraDef)
        end
    end)

    -- Hitstop & screen-shake listener
    local hitEvent = Network.GetEvent(Network.Events.HitRegistered)
    hitEvent.OnClientEvent:Connect(function(hitPos: Vector3, damage: number, isFinisher: boolean)
        CombatController.PlayImpactFeedback(hitPos, damage, isFinisher)
    end)

    print("[CombatController] Initialized with instant client input prediction.")
end

function CombatController.PerformM1(remote: RemoteEvent)
    local now = os.clock()
    if (now - lastM1Time) < Config.M1Cooldown then return end

    if (now - lastM1Time) > Config.ComboResetTime then
        comboIndex = 1
    else
        comboIndex = (comboIndex % Config.MaxCombo) + 1
    end
    lastM1Time = now

    -- Fire authoritative request to server
    remote:FireServer()

    -- Instant local visual feedback
    CombatController.PlayLocalSwing(comboIndex)
end

function CombatController.PlayLocalSwing(combo: number)
    local char = localPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- Visual swing punch arm animation simulation
    local arm = (combo % 2 == 1) and char:FindFirstChild("RightHand") or char:FindFirstChild("LeftHand")
    if arm and arm:IsA("BasePart") then
        local highlight = Instance.new("SelectionBox")
        highlight.Adornee = arm
        highlight.Color3 = Color3.fromRGB(255, 230, 100)
        highlight.LineThickness = 0.05
        highlight.Parent = arm
        game:GetService("Debris"):AddItem(highlight, 0.15)
    end
end

function CombatController.PlayAttackVFX(attacker: Player, combo: number, auraDef: any)
    local char = attacker.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    -- Visual slash/energy wave particle burst
    local part = Instance.new("Part")
    part.Size = Vector3.new(2, 0.2, 4)
    part.CFrame = root.CFrame * CFrame.new(0, 0, -2.5) * CFrame.Angles(0, math.rad((combo - 2) * 25), 0)
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = auraDef.Color or Color3.fromRGB(255, 255, 255)
    part.Transparency = 0.3
    part.Parent = workspace
    
    local tween = game:GetService("TweenService"):Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(4, 0.1, 7),
        Transparency = 1,
    })
    tween:Play()
    game:GetService("Debris"):AddItem(part, 0.22)
end

function CombatController.PlayImpactFeedback(hitPos: Vector3, damage: number, isFinisher: boolean)
    -- Camera punch shake if close to impact
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root and (root.Position - hitPos).Magnitude <= 35 then
        local cam = workspace.CurrentCamera
        if cam then
            local intensity = isFinisher and 0.8 or 0.3
            task.spawn(function()
                for _ = 1, 4 do
                    cam.CFrame = cam.CFrame * CFrame.Angles(
                        math.rad(math.random(-1, 1) * intensity),
                        math.rad(math.random(-1, 1) * intensity),
                        0
                    )
                    task.wait(0.02)
                end
            end)
        end
    end
end

return CombatController

--!strict
--[[
    CombatService.luau
    Authoritative server-side PvP combat engine.
    Validates M1 combo chains, spatial hitboxes, hitstun debuffs, knockback velocity,
    and applies aura-specific combat ability multipliers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local AurasModule = require(Shared:WaitForChild("Auras") :: ModuleScript)
local Network = require(Shared:WaitForChild("Network") :: ModuleScript)

local CombatService = {}
local DataService

-- Tracking player combat states
local comboIndex: { [number]: number } = {}
local lastAttackTime: { [number]: number } = {}
local isStunned: { [number]: boolean } = {}
local abilityCooldowns: { [number]: { [string]: number } } = {}

function CombatService.Init(dataServiceRef: any)
    DataService = dataServiceRef

    local attackEvent = Network.GetEvent(Network.Events.AttackRequest)
    attackEvent.OnServerEvent:Connect(function(player: Player)
        CombatService.HandleAttackRequest(player)
    end)

    local abilityEvent = Network.GetEvent(Network.Events.AbilityRequest)
    abilityEvent.OnServerEvent:Connect(function(player: Player, abilityKey: string)
        CombatService.HandleAbilityRequest(player, abilityKey)
    end)

    print("[CombatService] Initialized with authoritative hitbox validation.")
end

function CombatService.HandleAttackRequest(attacker: Player)
    local char = attacker.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end

    local userId = attacker.UserId

    -- Check if attacker is stunned
    if isStunned[userId] then return end

    local now = os.clock()
    local lastTime = lastAttackTime[userId] or 0

    if (now - lastTime) < Config.M1Cooldown then
        return -- Cooldown active
    end

    -- Combo progression logic
    local currentCombo = comboIndex[userId] or 1
    if (now - lastTime) > Config.ComboResetTime then
        currentCombo = 1
    else
        currentCombo = (currentCombo % Config.MaxCombo) + 1
    end

    comboIndex[userId] = currentCombo
    lastAttackTime[userId] = now

    -- Fetch equipped aura multipliers
    local profile = DataService.GetProfile(attacker)
    local auraId = profile and profile.EquippedAura or "Common"
    local auraDef = AurasModule.Auras[auraId] or AurasModule.Auras.Common

    -- Broadcast attack animation & sound to all nearby clients
    local attackReplicated = Network.GetEvent(Network.Events.AttackReplicated)
    attackReplicated:FireAllClients(attacker, currentCombo, auraDef)

    -- Authoritative Spatial Hitbox Query (Forward 7 studs, radius 5.5)
    local hitTargets = CombatService.QueryHitbox(root.Position, root.CFrame.LookVector * 4.5, 6.0, char)

    for _, targetChar in ipairs(hitTargets) do
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?

        if targetHum and targetRoot and targetHum.Health > 0 then
            -- Base damage scaling: 8 on M1-3, 14 on M1-4 finisher
            local baseDmg = (currentCombo == Config.MaxCombo) and 14 or 8
            local totalDamage = baseDmg * auraDef.CombatBoosts.DamageMultiplier

            targetHum:TakeDamage(totalDamage)

            -- Apply hitstun
            local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
            if targetPlayer then
                CombatService.ApplyStun(targetPlayer.UserId, Config.StunDuration)
            end

            -- Apply knockback on 4th hit combo finisher
            if currentCombo == Config.MaxCombo then
                local knockbackDir = (targetRoot.Position - root.Position).Unit + Vector3.new(0, 0.35, 0)
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Velocity = knockbackDir * 42
                bv.Parent = targetRoot
                Debris:AddItem(bv, 0.22)
            end

            -- Replicate impact VFX & damage popup
            local hitEvent = Network.GetEvent(Network.Events.HitRegistered)
            hitEvent:FireAllClients(targetRoot.Position, totalDamage, currentCombo == Config.MaxCombo)
        end
    end
end

function CombatService.HandleAbilityRequest(attacker: Player, abilityKey: string)
    local char = attacker.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end

    local userId = attacker.UserId
    if isStunned[userId] then return end

    local profile = DataService.GetProfile(attacker)
    local auraId = profile and profile.EquippedAura or "Common"
    local auraDef = AurasModule.Auras[auraId] or AurasModule.Auras.Common

    -- Cooldown verification (10s base, reduced by aura bonus)
    local baseCooldown = 10.0 * (1 - auraDef.CombatBoosts.CooldownReduction)
    abilityCooldowns[userId] = abilityCooldowns[userId] or {}
    local now = os.clock()
    local lastAbilityTime = abilityCooldowns[userId][abilityKey] or 0

    if (now - lastAbilityTime) < baseCooldown then
        return -- Ability on cooldown
    end

    abilityCooldowns[userId][abilityKey] = now

    -- Replicate ability VFX
    local abilityReplicated = Network.GetEvent(Network.Events.AbilityReplicated)
    abilityReplicated:FireAllClients(attacker, auraDef, abilityKey)

    -- Ability AoE Hitbox (Radius 18 studs)
    local targets = CombatService.QueryHitbox(root.Position, Vector3.zero, 18.0, char)
    local abilityDamage = 28 * auraDef.CombatBoosts.DamageMultiplier

    for _, targetChar in ipairs(targets) do
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?

        if targetHum and targetRoot and targetHum.Health > 0 then
            targetHum:TakeDamage(abilityDamage)

            local knockbackDir = (targetRoot.Position - root.Position).Unit + Vector3.new(0, 0.5, 0)
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = knockbackDir * 55
            bv.Parent = targetRoot
            Debris:AddItem(bv, 0.28)

            local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
            if targetPlayer then
                CombatService.ApplyStun(targetPlayer.UserId, 0.8)
            end

            local hitEvent = Network.GetEvent(Network.Events.HitRegistered)
            hitEvent:FireAllClients(targetRoot.Position, abilityDamage, true)
        end
    end
end

function CombatService.QueryHitbox(center: Vector3, offset: Vector3, radius: number, excludeChar: Model): { Model }
    local hitModels: { Model } = {}
    local origin = center + offset

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = { excludeChar }

    local parts = workspace:GetPartBoundsInRadius(origin, radius, overlapParams)
    local recorded = {}

    for _, part in ipairs(parts) do
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model ~= excludeChar and not recorded[model] then
            if model:FindFirstChildOfClass("Humanoid") then
                recorded[model] = true
                table.insert(hitModels, model)
            end
        end
    end

    return hitModels
end

function CombatService.ApplyStun(userId: number, duration: number)
    isStunned[userId] = true
    task.delay(duration, function()
        isStunned[userId] = false
    end)
end

return CombatService

--!strict
--[[
    RngService.luau
    Server-authoritative RNG rolling engine.
    Calculates dynamic luck multipliers, evaluates probabilities, updates inventories,
    and broadcasts global server announcements for rare pulls.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AurasModule = require(Shared:WaitForChild("Auras") :: ModuleScript)
local Network = require(Shared:WaitForChild("Network") :: ModuleScript)
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)

local RngService = {}
local DataService
local MonetizationService

local RNG = Random.new()
local lastRollTime: { [number]: number } = {}

function RngService.Init(dataServiceRef: any, monetizationServiceRef: any)
    DataService = dataServiceRef
    MonetizationService = monetizationServiceRef

    local rollEvent = Network.GetEvent(Network.Events.RollAura)
    rollEvent.OnServerEvent:Connect(function(player: Player)
        RngService.HandleRollRequest(player)
    end)

    local equipEvent = Network.GetEvent(Network.Events.EquipAura)
    equipEvent.OnServerEvent:Connect(function(player: Player, auraId: string)
        RngService.HandleEquipRequest(player, auraId)
    end)

    print("[RngService] Initialized with weighted probability evaluator.")
end

function RngService.HandleRollRequest(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local now = os.clock()
    local lastTime = lastRollTime[player.UserId] or 0

    -- Determine cooldown: 0.5s if FastRoll gamepass, else 2.0s
    local hasFastRoll = profile.Gamepasses and profile.Gamepasses.FastRoll
    local cooldown = hasFastRoll and Config.FastRollCooldown or Config.BaseRollCooldown

    -- Check if player has instant rolls consumable balance
    local hasInstantRoll = profile.InstantRolls and profile.InstantRolls > 0

    if not hasInstantRoll and (now - lastTime) < cooldown then
        return -- Too fast, ignore spam
    end

    if hasInstantRoll then
        profile.InstantRolls -= 1
    else
        lastRollTime[player.UserId] = now
    end

    profile.TotalRolls += 1

    -- Calculate total dynamic luck
    local totalLuck = MonetizationService.GetPlayerTotalLuck(player)

    -- Roll the aura
    local rolledAura = RngService.Roll(totalLuck)

    -- Update inventory
    profile.Auras[rolledAura.Id] = (profile.Auras[rolledAura.Id] or 0) + 1

    -- Replicate result to the client for cutscene / UI animation
    local auraRolledEvent = Network.GetEvent(Network.Events.AuraRolled)
    auraRolledEvent:FireClient(player, rolledAura, profile.TotalRolls, totalLuck)

    -- Global announcement for high-tier pulls (Legendary / Mythic / Divine)
    if rolledAura.RarityChance >= 2048 then
        local announceEvent = Network.GetEvent("ServerAnnouncement")
        local rarityText = string.format("1 in %s", RngService.FormatNumber(rolledAura.RarityChance))
        local msg = string.format("⚡ %s just rolled [%s] (%s)! ⚡", player.DisplayName, rolledAura.Name, rarityText)
        announceEvent:FireAllClients(msg, rolledAura.Tier)
        print(string.format("[RngService] High-tier pull: %s by %s", rolledAura.Name, player.Name))
    end

    DataService.SyncToClient(player)
end

function RngService.Roll(luckMultiplier: number): AurasModule.AuraDefinition
    local sorted = AurasModule.RaritySortedList

    for _, aura in ipairs(sorted) do
        -- Skip common in the weighted check; it acts as fallback
        if aura.Id == "Common" then continue end

        local effectiveChance = (1 / aura.RarityChance) * luckMultiplier
        local rollVal = RNG:NextNumber()

        if rollVal <= effectiveChance then
            return aura
        end
    end

    return AurasModule.Auras.Common
end

function RngService.HandleEquipRequest(player: Player, auraId: string)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local auraDef = AurasModule.Auras[auraId]
    if not auraDef then return end

    if (profile.Auras[auraId] or 0) <= 0 then
        warn(string.format("[RngService] Player %s does not own aura %s", player.Name, auraId))
        return
    end

    profile.EquippedAura = auraId
    print(string.format("[RngService] Player %s equipped %s", player.Name, auraDef.Name))

    -- Replicate aura attachment & combat boosts
    local auraEquippedEvent = Network.GetEvent(Network.Events.AuraEquipped)
    auraEquippedEvent:FireAllClients(player, auraDef)

    -- Apply character walkspeed boost
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = Config.BaseWalkSpeed + auraDef.CombatBoosts.WalkSpeedBonus
        end
    end

    DataService.SyncToClient(player)
end

function RngService.FormatNumber(n: number): string
    local formatted = tostring(n)
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

return RngService

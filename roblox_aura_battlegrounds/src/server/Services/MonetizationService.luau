--!strict
--[[
    MonetizationService.luau
    Authoritative handler for Robux monetization, Gamepasses, Developer Products,
    and bulletproof ProcessReceipt execution.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)

local MonetizationService = {}
local DataService -- Injected in Init to avoid circular requires
local RngService  -- Injected in Init to grant roll bonuses

-- Track processed receipts in memory during server lifetime
local processedReceipts = {}

-- Global server luck event state
MonetizationService.ServerLuckMultiplier = 1.0
MonetizationService.ServerLuckExpiry = 0

function MonetizationService.Init(dataServiceRef: any, rngServiceRef: any)
    DataService = dataServiceRef
    RngService = rngServiceRef

    -- Set up ProcessReceipt callback
    MarketplaceService.ProcessReceipt = function(receiptInfo: {
        PurchaseId: string,
        PlayerId: number,
        ProductId: number,
        CurrencySpent: number,
        PlaceIdWherePurchased: number,
    })
        return MonetizationService.HandleProcessReceipt(receiptInfo)
    end

    -- Listen for player joins to verify owned Gamepasses
    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            MonetizationService.CheckAllGamepasses(player)
        end)
    end)
    
    print("[MonetizationService] Initialized with bulletproof receipt processing.")
end

function MonetizationService.CheckAllGamepasses(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    for gamepassName, gamepassId in pairs(Config.GamepassIds) do
        local success, hasPass = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
        end)

        if success and hasPass then
            profile.Gamepasses[gamepassName] = true
            print(string.format("[Monetization] Verified Gamepass '%s' for %s", gamepassName, player.Name))
        end
    end
    DataService.SyncToClient(player)
end

function MonetizationService.HandleProcessReceipt(receiptInfo: {
    PurchaseId: string,
    PlayerId: number,
    ProductId: number,
    CurrencySpent: number,
    PlaceIdWherePurchased: number,
}): Enum.ProductPurchaseDecision
    local purchaseId = receiptInfo.PurchaseId
    local playerId = receiptInfo.PlayerId
    local productId = receiptInfo.ProductId

    -- 1. Idempotency check: Don't process twice if already awarded in this session
    if processedReceipts[purchaseId] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local player = Players:GetPlayerByUserId(playerId)
    if not player then
        -- Player left before receipt completed; return NotProcessed to retry when they rejoin
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local profile = DataService.GetProfile(player)
    if not profile then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- 2. Award product effects
    local grantSuccess = false

    if productId == Config.DevProductIds.Rolls_10x then
        profile.InstantRolls = (profile.InstantRolls or 0) + 10
        grantSuccess = true
        print(string.format("[Monetization] Granted 10x Instant Rolls to %s", player.Name))

    elseif productId == Config.DevProductIds.Rolls_50x then
        profile.InstantRolls = (profile.InstantRolls or 0) + 50
        grantSuccess = true
        print(string.format("[Monetization] Granted 50x Instant Rolls to %s", player.Name))

    elseif productId == Config.DevProductIds.LuckPotion_15m then
        local now = os.time()
        local currentExpiry = profile.LuckPotionExpiry or now
        profile.LuckPotionExpiry = math.max(currentExpiry, now) + (15 * 60)
        grantSuccess = true
        print(string.format("[Monetization] Granted 15m Luck Potion to %s", player.Name))

    elseif productId == Config.DevProductIds.ServerLuckBoost then
        local now = os.time()
        MonetizationService.ServerLuckMultiplier = 2.0
        MonetizationService.ServerLuckExpiry = math.max(MonetizationService.ServerLuckExpiry, now) + (20 * 60)
        grantSuccess = true
        
        -- Broadcast server-wide announcement
        local Network = require(Shared:WaitForChild("Network") :: ModuleScript)
        local announceEvent = Network.GetEvent("ServerAnnouncement")
        announceEvent:FireAllClients(string.format("🌟 %s activated a 2x SERVER LUCK BOOST for 20 minutes!", player.DisplayName))
        print(string.format("[Monetization] Server Luck Boost activated by %s", player.Name))
    end

    if grantSuccess then
        processedReceipts[purchaseId] = true
        DataService.SyncToClient(player)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
end

function MonetizationService.GetPlayerTotalLuck(player: Player): number
    local profile = DataService.GetProfile(player)
    if not profile then return 1.0 end

    local luck = 1.0

    -- Gamepass: Double Luck (2x)
    if profile.Gamepasses and profile.Gamepasses.DoubleLuck then
        luck = luck * 2.0
    end

    -- Gamepass: VIP (+20%)
    if profile.Gamepasses and profile.Gamepasses.VIP then
        luck = luck * 1.2
    end

    -- Consumable Potion (+100%)
    if profile.LuckPotionExpiry and profile.LuckPotionExpiry > os.time() then
        luck = luck * 2.0
    end

    -- Server Boost (2x)
    if MonetizationService.ServerLuckExpiry > os.time() then
        luck = luck * MonetizationService.ServerLuckMultiplier
    end

    return luck
end

return MonetizationService

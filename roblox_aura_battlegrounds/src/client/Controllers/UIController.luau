--!strict
--[[
    UIController.luau
    Generates the entire modern, mobile-responsive UI programmatically from Luau.
    Features Roll Bar, Auto-Roll toggle, Inventory Modal, and Robux Shop Modal.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network") :: ModuleScript)
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local AurasModule = require(Shared:WaitForChild("Auras") :: ModuleScript)

local UIController = {}
local localPlayer = Players.LocalPlayer

local isAutoRollActive = false
local currentProfileData: any = nil

function UIController.Init()
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    local mainGui = Instance.new("ScreenGui")
    mainGui.Name = "AuraBattlegroundsMainGui"
    mainGui.ResetOnSpawn = false
    mainGui.Parent = playerGui

    local dataSynced = Network.GetEvent(Network.Events.DataSynced)
    dataSynced.OnClientEvent:Connect(function(profile: any)
        currentProfileData = profile
        UIController.UpdateStatsHUD(mainGui)
    end)

    -- Build HUD Elements
    UIController.CreateTopStatsBar(mainGui)
    UIController.CreateBottomActionBar(mainGui)
    local shopModal = UIController.CreateShopModal(mainGui)
    local invModal = UIController.CreateInventoryModal(mainGui)

    -- Auto-Roll execution loop
    task.spawn(function()
        local rollEvent = Network.GetEvent(Network.Events.RollAura)
        while true do
            task.wait(0.5)
            if isAutoRollActive and currentProfileData then
                local hasAutoPass = currentProfileData.Gamepasses and currentProfileData.Gamepasses.AutoRoll
                if hasAutoPass then
                    rollEvent:FireServer()
                    task.wait(currentProfileData.Gamepasses.FastRoll and 0.5 or 2.0)
                else
                    isAutoRollActive = false
                    MarketplaceService:PromptGamePassPurchase(localPlayer, Config.GamepassIds.AutoRoll)
                end
            end
        end
    end)

    print("[UIController] Initialized with programmatic modern UI.")
end

function UIController.CreateTopStatsBar(parent: ScreenGui)
    local topFrame = Instance.new("Frame")
    topFrame.Name = "TopStatsBar"
    topFrame.Size = UDim2.new(0, 380, 0, 70)
    topFrame.Position = UDim2.new(0, 20, 0, 20)
    topFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    topFrame.BackgroundTransparency = 0.25
    topFrame.BorderSizePixel = 0
    topFrame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = topFrame

    local equippedLabel = Instance.new("TextLabel")
    equippedLabel.Name = "EquippedLabel"
    equippedLabel.Size = UDim2.new(1, -20, 0, 32)
    equippedLabel.Position = UDim2.new(0, 10, 0, 6)
    equippedLabel.BackgroundTransparency = 1
    equippedLabel.Font = Enum.Font.GothamBold
    equippedLabel.Text = "AURA: Loading..."
    equippedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    equippedLabel.TextSize = 18
    equippedLabel.TextXAlignment = Enum.TextXAlignment.Left
    equippedLabel.Parent = topFrame

    local rollsLabel = Instance.new("TextLabel")
    rollsLabel.Name = "RollsLabel"
    rollsLabel.Size = UDim2.new(1, -20, 0, 24)
    rollsLabel.Position = UDim2.new(0, 10, 0, 38)
    rollsLabel.BackgroundTransparency = 1
    rollsLabel.Font = Enum.Font.GothamMedium
    rollsLabel.Text = "TOTAL ROLLS: 0"
    rollsLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    rollsLabel.TextSize = 14
    rollsLabel.TextXAlignment = Enum.TextXAlignment.Left
    rollsLabel.Parent = topFrame
end

function UIController.UpdateStatsHUD(parent: ScreenGui)
    if not currentProfileData then return end

    local topFrame = parent:FindFirstChild("TopStatsBar")
    if topFrame then
        local equippedLabel = topFrame:FindFirstChild("EquippedLabel") :: TextLabel?
        local rollsLabel = topFrame:FindFirstChild("RollsLabel") :: TextLabel?

        if equippedLabel then
            local aura = AurasModule.Auras[currentProfileData.EquippedAura]
            local auraName = aura and aura.Name or currentProfileData.EquippedAura
            local auraColor = aura and aura.Color or Color3.fromRGB(255, 255, 255)
            equippedLabel.Text = "AURA: " .. auraName:upper()
            equippedLabel.TextColor3 = auraColor
        end

        if rollsLabel then
            rollsLabel.Text = string.format("TOTAL ROLLS: %d | COINS: %d", currentProfileData.TotalRolls, currentProfileData.Coins or 0)
        end
    end
end

function UIController.CreateBottomActionBar(parent: ScreenGui)
    local bar = Instance.new("Frame")
    bar.Name = "BottomActionBar"
    bar.Size = UDim2.new(0, 520, 0, 80)
    bar.Position = UDim2.new(0.5, 0, 1, -30)
    bar.AnchorPoint = Vector2.new(0.5, 1)
    bar.BackgroundTransparency = 1
    bar.Parent = parent

    -- Big Glowing ROLL Button
    local rollBtn = Instance.new("TextButton")
    rollBtn.Name = "RollButton"
    rollBtn.Size = UDim2.new(0, 180, 0, 65)
    rollBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
    rollBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    rollBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 240)
    rollBtn.Font = Enum.Font.GothamBlack
    rollBtn.Text = "ROLL"
    rollBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    rollBtn.TextSize = 28
    rollBtn.Parent = bar

    local rollCorner = Instance.new("UICorner")
    rollCorner.CornerRadius = UDim.new(0, 14)
    rollCorner.Parent = rollBtn

    local rollStroke = Instance.new("UIStroke")
    rollStroke.Color = Color3.fromRGB(150, 130, 255)
    rollStroke.Thickness = 3
    rollStroke.Parent = rollBtn

    rollBtn.MouseButton1Click:Connect(function()
        local rollEvent = Network.GetEvent(Network.Events.RollAura)
        rollEvent:FireServer()
    end)

    -- Auto-Roll Toggle Button
    local autoBtn = Instance.new("TextButton")
    autoBtn.Name = "AutoButton"
    autoBtn.Size = UDim2.new(0, 100, 0, 50)
    autoBtn.Position = UDim2.new(0.5, 150, 0.5, 0)
    autoBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    autoBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    autoBtn.Font = Enum.Font.GothamBold
    autoBtn.Text = "AUTO: OFF"
    autoBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    autoBtn.TextSize = 14
    autoBtn.Parent = bar

    local autoCorner = Instance.new("UICorner")
    autoCorner.CornerRadius = UDim.new(0, 10)
    autoCorner.Parent = autoBtn

    autoBtn.MouseButton1Click:Connect(function()
        isAutoRollActive = not isAutoRollActive
        autoBtn.Text = isAutoRollActive and "AUTO: ON" or "AUTO: OFF"
        autoBtn.TextColor3 = isAutoRollActive and Color3.fromRGB(60, 255, 120) or Color3.fromRGB(200, 200, 200)
    end)

    -- SHOP Button
    local shopBtn = Instance.new("TextButton")
    shopBtn.Name = "ShopButton"
    shopBtn.Size = UDim2.new(0, 100, 0, 50)
    shopBtn.Position = UDim2.new(0.5, -150, 0.5, 0)
    shopBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    shopBtn.BackgroundColor3 = Color3.fromRGB(240, 160, 30)
    shopBtn.Font = Enum.Font.GothamBlack
    shopBtn.Text = "SHOP 🛒"
    shopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    shopBtn.TextSize = 16
    shopBtn.Parent = bar

    local shopCorner = Instance.new("UICorner")
    shopCorner.CornerRadius = UDim.new(0, 10)
    shopCorner.Parent = shopBtn

    shopBtn.MouseButton1Click:Connect(function()
        local shopModal = parent:FindFirstChild("ShopModal") :: Frame?
        if shopModal then
            shopModal.Visible = not shopModal.Visible
        end
    end)
end

function UIController.CreateShopModal(parent: ScreenGui): Frame
    local modal = Instance.new("Frame")
    modal.Name = "ShopModal"
    modal.Size = UDim2.new(0, 500, 0, 380)
    modal.Position = UDim2.new(0.5, 0, 0.5, 0)
    modal.AnchorPoint = Vector2.new(0.5, 0.5)
    modal.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    modal.BorderSizePixel = 0
    modal.Visible = false
    modal.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = modal

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.Text = "ROBUX SHOP & GAMEPASSES"
    title.TextColor3 = Color3.fromRGB(255, 200, 50)
    title.TextSize = 22
    title.Parent = modal

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -45, 0, 8)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    closeBtn.TextSize = 20
    closeBtn.Parent = modal
    closeBtn.MouseButton1Click:Connect(function()
        modal.Visible = false
    end)

    -- Item grid container
    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, -30, 1, -70)
    list.Position = UDim2.new(0, 15, 0, 55)
    list.BackgroundTransparency = 1
    list.ScrollBarThickness = 6
    list.Parent = modal

    local uilist = Instance.new("UIListLayout")
    uilist.Padding = UDim.new(0, 10)
    uilist.Parent = list

    local shopItems = {
        { Name = "2x Permanent Luck", Price = "399 R$", Id = Config.GamepassIds.DoubleLuck, IsPass = true },
        { Name = "Fast Roll (0.5s Cooldown)", Price = "249 R$", Id = Config.GamepassIds.FastRoll, IsPass = true },
        { Name = "Auto-Roll", Price = "199 R$", Id = Config.GamepassIds.AutoRoll, IsPass = true },
        { Name = "VIP Chat & Gold Aura", Price = "299 R$", Id = Config.GamepassIds.VIP, IsPass = true },
        { Name = "10x Instant Rolls", Price = "49 R$", Id = Config.DevProductIds.Rolls_10x, IsPass = false },
        { Name = "50x Instant Rolls", Price = "199 R$", Id = Config.DevProductIds.Rolls_50x, IsPass = false },
        { Name = "15m Luck Potion (+100%)", Price = "99 R$", Id = Config.DevProductIds.LuckPotion_15m, IsPass = false },
        { Name = "2x Server Luck (20 Mins)", Price = "499 R$", Id = Config.DevProductIds.ServerLuckBoost, IsPass = false },
    }

    for _, item in ipairs(shopItems) do
        local itemCard = Instance.new("Frame")
        itemCard.Size = UDim2.new(1, -10, 0, 55)
        itemCard.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        itemCard.Parent = list

        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 8)
        itemCorner.Parent = itemCard

        local itemName = Instance.new("TextLabel")
        itemName.Size = UDim2.new(0.65, 0, 1, 0)
        itemName.Position = UDim2.new(0, 15, 0, 0)
        itemName.BackgroundTransparency = 1
        itemName.Font = Enum.Font.GothamBold
        itemName.Text = item.Name
        itemName.TextColor3 = Color3.fromRGB(240, 240, 240)
        itemName.TextSize = 15
        itemName.TextXAlignment = Enum.TextXAlignment.Left
        itemName.Parent = itemCard

        local buyBtn = Instance.new("TextButton")
        buyBtn.Size = UDim2.new(0, 110, 0, 38)
        buyBtn.Position = UDim2.new(1, -120, 0.5, 0)
        buyBtn.AnchorPoint = Vector2.new(0, 0.5)
        buyBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
        buyBtn.Font = Enum.Font.GothamBold
        buyBtn.Text = item.Price
        buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyBtn.TextSize = 14
        buyBtn.Parent = itemCard

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = buyBtn

        buyBtn.MouseButton1Click:Connect(function()
            if item.IsPass then
                MarketplaceService:PromptGamePassPurchase(localPlayer, item.Id)
            else
                MarketplaceService:PromptProductPurchase(localPlayer, item.Id)
            end
        end)
    end

    return modal
end

function UIController.CreateInventoryModal(parent: ScreenGui): Frame
    local modal = Instance.new("Frame")
    modal.Name = "InventoryModal"
    modal.Size = UDim2.new(0, 460, 0, 340)
    modal.Position = UDim2.new(0.5, 0, 0.5, 0)
    modal.AnchorPoint = Vector2.new(0.5, 0.5)
    modal.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    modal.BorderSizePixel = 0
    modal.Visible = false
    modal.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = modal

    return modal
end

return UIController

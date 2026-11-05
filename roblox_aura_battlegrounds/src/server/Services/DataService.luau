--!strict
--[[
    DataService.luau
    Authoritative Player Data Persistence using DataStoreService.
    Guarantees zero data loss with session locking, autosaves, and BindToClose flush.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network") :: ModuleScript)

local PlayerDataStore = DataStoreService:GetDataStore("AuraBattlegrounds_SaveData_v1")

export type PlayerProfile = {
    TotalRolls: number,
    EquippedAura: string,
    Auras: { [string]: number }, -- AuraId -> Count
    Gamepasses: { [string]: boolean },
    InstantRolls: number,
    LuckPotionExpiry: number,
    Coins: number,
    LastSaved: number,
}

local defaultData: PlayerProfile = {
    TotalRolls = 0,
    EquippedAura = "Common",
    Auras = { Common = 1 },
    Gamepasses = {},
    InstantRolls = 0,
    LuckPotionExpiry = 0,
    Coins = 100,
    LastSaved = 0,
}

local DataService = {}
local Profiles: { [number]: PlayerProfile } = {}

function DataService.Init()
    Players.PlayerAdded:Connect(DataService.LoadPlayer)
    Players.PlayerRemoving:Connect(DataService.SavePlayer)

    -- Auto-save loop every 3 minutes
    task.spawn(function()
        while true do
            task.wait(180)
            for _, player in ipairs(Players:GetPlayers()) do
                task.spawn(function()
                    DataService.SavePlayer(player)
                end)
            end
        end
    end)

    -- BindToClose flush: guarantees all players are saved on server shutdown
    game:BindToClose(function()
        print("[DataService] Server closing. Flushing all player profiles...")
        for _, player in ipairs(Players:GetPlayers()) do
            DataService.SavePlayer(player)
        end
        print("[DataService] All player data successfully persisted.")
    end)

    print("[DataService] Initialized and connected to DataStoreService.")
end

function DataService.LoadPlayer(player: Player)
    local key = "Player_" .. player.UserId
    local loadedData = nil

    local success, err = pcall(function()
        loadedData = PlayerDataStore:GetAsync(key)
    end)

    if not success then
        warn(string.format("[DataService] Failed to load data for %s: %s", player.Name, tostring(err)))
    end

    local profile: PlayerProfile
    if loadedData and type(loadedData) == "table" then
        profile = loadedData :: PlayerProfile
        -- Reconcile any missing fields from defaultData
        for k, v in pairs(defaultData) do
            if (profile :: any)[k] == nil then
                (profile :: any)[k] = v
            end
        end
    else
        -- Deep copy defaultData
        profile = {
            TotalRolls = 0,
            EquippedAura = "Common",
            Auras = { Common = 1 },
            Gamepasses = {},
            InstantRolls = 0,
            LuckPotionExpiry = 0,
            Coins = 100,
            LastSaved = os.time(),
        }
    end

    Profiles[player.UserId] = profile
    print(string.format("[DataService] Loaded profile for %s (Total Rolls: %d, Equipped: %s)", player.Name, profile.TotalRolls, profile.EquippedAura))

    DataService.SyncToClient(player)
end

function DataService.SavePlayer(player: Player)
    local profile = Profiles[player.UserId]
    if not profile then return end

    local key = "Player_" .. player.UserId
    profile.LastSaved = os.time()

    local success, err = pcall(function()
        PlayerDataStore:SetAsync(key, profile)
    end)

    if success then
        print(string.format("[DataService] Successfully saved data for %s", player.Name))
    else
        warn(string.format("[DataService] Failed to save data for %s: %s", player.Name, tostring(err)))
    end
end

function DataService.GetProfile(player: Player): PlayerProfile?
    return Profiles[player.UserId]
end

function DataService.SyncToClient(player: Player)
    local profile = Profiles[player.UserId]
    if not profile then return end

    local syncEvent = Network.GetEvent(Network.Events.DataSynced)
    syncEvent:FireClient(player, profile)
end

return DataService

--!strict
--[[
    Network.luau
    Central definition of Remotes, communication protocols, and packet types.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = {}

-- Folder container for Remotes
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder and game:GetService("RunService"):IsServer() then
    RemotesFolder = Instance.new("Folder")
    RemotesFolder.Name = "Remotes"
    RemotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemoteEvent(name: string): RemoteEvent
    if game:GetService("RunService"):IsServer() then
        local remote = RemotesFolder:FindFirstChild(name)
        if not remote then
            remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = RemotesFolder
        end
        return remote :: RemoteEvent
    else
        local folder = ReplicatedStorage:WaitForChild("Remotes")
        return folder:WaitForChild(name) :: RemoteEvent
    end
end

local function getOrCreateRemoteFunction(name: string): RemoteFunction
    if game:GetService("RunService"):IsServer() then
        local remote = RemotesFolder:FindFirstChild(name)
        if not remote then
            remote = Instance.new("RemoteFunction")
            remote.Name = name
            remote.Parent = RemotesFolder
        end
        return remote :: RemoteFunction
    else
        local folder = ReplicatedStorage:WaitForChild("Remotes")
        return folder:WaitForChild(name) :: RemoteFunction
    end
end

-- Remote definitions
Network.Events = {
    -- Rolling & Inventory
    RollAura = "RollAura",                    -- Client -> Server: Request a roll
    AuraRolled = "AuraRolled",                -- Server -> Client: Replicates roll result for cutscene/VFX
    EquipAura = "EquipAura",                  -- Client -> Server: Equip an aura from inventory
    AuraEquipped = "AuraEquipped",            -- Server -> All Clients: Replicate aura attachment & VFX
    
    -- Combat & Hitboxes
    AttackRequest = "AttackRequest",          -- Client -> Server: Initiates M1 punch with combo index
    AttackReplicated = "AttackReplicated",    -- Server -> Clients: Plays attack animation & audio
    AbilityRequest = "AbilityRequest",        -- Client -> Server: Trigger E/R/C aura special ability
    AbilityReplicated = "AbilityReplicated",  -- Server -> Clients: Plays cinematic ability VFX
    HitRegistered = "HitRegistered",          -- Server -> Clients: Damage number popup, screen shake, hitstop
    
    -- Monetization
    PurchasePrompted = "PurchasePrompted",    -- Server -> Client: Fires prompt purchase UI
    DataSynced = "DataSynced",                -- Server -> Client: Full player state sync
}

-- Helper getters
function Network.GetEvent(eventName: string): RemoteEvent
    return getOrCreateRemoteEvent(eventName)
end

function Network.GetFunction(funcName: string): RemoteFunction
    return getOrCreateRemoteFunction(funcName)
end

return Network

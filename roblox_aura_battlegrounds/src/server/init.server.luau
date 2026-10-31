--!strict
--[[
    init.server.luau
    Master Server Bootstrapper for Aura Battlegrounds.
    Initializes DataService, MonetizationService, RngService, and CombatService in strict order.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("==================================================")
print("🚀 BOOTING AURA BATTLEGROUNDS SERVER ENGINE")
print("==================================================")

-- Ensure Remotes folder is prepared
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network") :: ModuleScript)

-- Require Server Services
local ServicesFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local DataService = require(ServicesFolder:WaitForChild("DataService") :: ModuleScript)
local MonetizationService = require(ServicesFolder:WaitForChild("MonetizationService") :: ModuleScript)
local RngService = require(ServicesFolder:WaitForChild("RngService") :: ModuleScript)
local CombatService = require(ServicesFolder:WaitForChild("CombatService") :: ModuleScript)

-- 1. Initialize DataService (Sets up DataStore listeners)
DataService.Init()

-- 2. Initialize MonetizationService (Sets up ProcessReceipt & Gamepass checks)
MonetizationService.Init(DataService, RngService)

-- 3. Initialize RngService (Sets up Roll and Equip RemoteEvent listeners)
RngService.Init(DataService, MonetizationService)

-- 4. Initialize CombatService (Sets up Hitbox and Attack listeners)
CombatService.Init(DataService)

print("==================================================")
print("✅ AURA BATTLEGROUNDS SERVER IS 100% ONLINE")
print("==================================================")

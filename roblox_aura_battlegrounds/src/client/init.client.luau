--!strict
--[[
    init.client.luau
    Master Client Bootstrapper for Aura Battlegrounds.
    Initializes CombatController, RngController, and UIController upon player spawn.
]]

local Players = game:GetService("Players")

print("==================================================")
print("🎮 BOOTING AURA BATTLEGROUNDS CLIENT ENGINE")
print("==================================================")

local localPlayer = Players.LocalPlayer
local clientFolder = script.Parent

local Controllers = clientFolder:WaitForChild("Controllers")
local CombatController = require(Controllers:WaitForChild("CombatController") :: ModuleScript)
local RngController = require(Controllers:WaitForChild("RngController") :: ModuleScript)
local UIController = require(Controllers:WaitForChild("UIController") :: ModuleScript)

-- 1. Initialize RngController (Sets up Roll cutscenes & Aura VFX attachment)
RngController.Init()

-- 2. Initialize CombatController (Sets up M1 punch input & ability keybinds)
CombatController.Init()

-- 3. Initialize UIController (Builds modern HUD, Roll bar, Auto-Roll, & Shop modal)
UIController.Init()

print("==================================================")
print("✅ AURA BATTLEGROUNDS CLIENT INITIALIZED FOR " .. localPlayer.Name:upper())
print("==================================================")

--!strict
--[[
    Config.luau
    Central configuration for Aura Combat RNG.
    Manages monetization IDs, luck multipliers, combat constants, and roll parameters.
]]

local Config = {}

-- Monetization Gamepass IDs (Set to your Roblox Creator Dashboard Gamepass IDs)
Config.GamepassIds = {
    DoubleLuck = 100001,       -- 2x Permanent Luck (Price: 399 R$)
    FastRoll = 100002,         -- 0.5s Roll Cooldown instead of 2.0s (Price: 249 R$)
    AutoRoll = 100003,         -- Automated Background Rolling (Price: 199 R$)
    VIP = 100004,              -- +20% Luck + Gold Chat Tag + VIP Aura (Price: 299 R$)
    ExtraStorage = 100005,     -- +50 Aura Storage Slots (Price: 149 R$)
}

-- Developer Product IDs (Consumables / Repeated Purchases)
Config.DevProductIds = {
    Rolls_10x = 200001,        -- Instant 10x Batch Roll (Price: 49 R$)
    Rolls_50x = 200002,        -- Instant 50x Batch Roll (Price: 199 R$)
    LuckPotion_15m = 200003,   -- +100% Luck for 15 Minutes (Price: 99 R$)
    ServerLuckBoost = 200004,  -- 2x Luck for Entire Server for 20 Mins (Price: 499 R$)
}

-- Roll Timing & Limits
Config.BaseRollCooldown = 2.0 -- Seconds between rolls
Config.FastRollCooldown = 0.5 -- Seconds for FastRoll gamepass owners
Config.MaxInventorySlots = 20
Config.VIPBonusSlots = 30

-- Combat & PvP Balance
Config.BaseHealth = 100
Config.BaseWalkSpeed = 16
Config.ComboResetTime = 1.2    -- M1 combo resets if idle for 1.2s
Config.M1Cooldown = 0.35      -- Time between consecutive M1 punches
Config.MaxCombo = 4           -- 4-hit basic attack string
Config.StunDuration = 0.4     -- Hitstun duration per M1

return Config

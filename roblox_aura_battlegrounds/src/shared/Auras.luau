--!strict
--[[
    Auras.luau
    Definitions for all rollable auras, their rarity probabilities (1 in N),
    visual properties, and combat ability modifiers.
]]

export type AuraDefinition = {
    Id: string,
    Name: string,
    RarityChance: number,       -- 1 in RarityChance (e.g. 1000 means 1 in 1,000)
    Tier: "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Divine",
    Color: Color3,
    SecondaryColor: Color3,
    CombatBoosts: {
        DamageMultiplier: number,
        WalkSpeedBonus: number,
        CooldownReduction: number,
    },
    AbilityName: string,
    AbilityDescription: string,
}

local Auras: { [string]: AuraDefinition } = {
    Common = {
        Id = "Common",
        Name = "Common",
        RarityChance = 2, -- 1 in 2 (50%)
        Tier = "Common",
        Color = Color3.fromRGB(180, 180, 180),
        SecondaryColor = Color3.fromRGB(120, 120, 120),
        CombatBoosts = {
            DamageMultiplier = 1.0,
            WalkSpeedBonus = 0,
            CooldownReduction = 0,
        },
        AbilityName = "Sprint Surge",
        AbilityDescription = "A brief 20% burst of sprint speed for 2 seconds.",
    },

    Wind = {
        Id = "Wind",
        Name = "Gale Zephyr",
        RarityChance = 8, -- 1 in 8
        Tier = "Common",
        Color = Color3.fromRGB(120, 230, 160),
        SecondaryColor = Color3.fromRGB(80, 180, 120),
        CombatBoosts = {
            DamageMultiplier = 1.05,
            WalkSpeedBonus = 2,
            CooldownReduction = 0.05,
        },
        AbilityName = "Cyclone Dash",
        AbilityDescription = "Dash forward with wind vortex blades, dealing 15 damage and knocking opponents back.",
    },

    Ruby = {
        Id = "Ruby",
        Name = "Crimson Shard",
        RarityChance = 32, -- 1 in 32
        Tier = "Rare",
        Color = Color3.fromRGB(230, 40, 70),
        SecondaryColor = Color3.fromRGB(150, 20, 40),
        CombatBoosts = {
            DamageMultiplier = 1.15,
            WalkSpeedBonus = 1,
            CooldownReduction = 0.08,
        },
        AbilityName = "Blood Pierce",
        AbilityDescription = "Fires 3 crystalline ruby spikes that impale and inflict bleeding.",
    },

    Thunder = {
        Id = "Thunder",
        Name = "Volt Striker",
        RarityChance = 256, -- 1 in 256
        Tier = "Epic",
        Color = Color3.fromRGB(255, 230, 50),
        SecondaryColor = Color3.fromRGB(200, 160, 0),
        CombatBoosts = {
            DamageMultiplier = 1.25,
            WalkSpeedBonus = 4,
            CooldownReduction = 0.15,
        },
        AbilityName = "Thunderclap Slam",
        AbilityDescription = "Instantly flash-teleport 15 studs forward and strike the ground with a 35 damage electric AoE.",
    },

    Solar = {
        Id = "Solar",
        Name = "Solar Eclipse",
        RarityChance = 2048, -- 1 in 2,048
        Tier = "Legendary",
        Color = Color3.fromRGB(255, 120, 20),
        SecondaryColor = Color3.fromRGB(40, 20, 10),
        CombatBoosts = {
            DamageMultiplier = 1.45,
            WalkSpeedBonus = 5,
            CooldownReduction = 0.22,
        },
        AbilityName = "Corona Flare",
        AbilityDescription = "Unleash a massive expanding solar shockwave that blinds and incinerates targets in a 25 stud radius.",
    },

    Glitch = {
        Id = "Glitch",
        Name = "Matrix Disruption",
        RarityChance = 16384, -- 1 in 16,384
        Tier = "Mythic",
        Color = Color3.fromRGB(20, 255, 220),
        SecondaryColor = Color3.fromRGB(255, 0, 120),
        CombatBoosts = {
            DamageMultiplier = 1.70,
            WalkSpeedBonus = 7,
            CooldownReduction = 0.30,
        },
        AbilityName = "Null Void Tear",
        AbilityDescription = "Fractures spatial coordinates, reversing enemy inputs and dealing continuous damage over 3 seconds.",
    },

    Singularity = {
        Id = "Singularity",
        Name = "Infinite Singularity",
        RarityChance = 250000, -- 1 in 250,000
        Tier = "Divine",
        Color = Color3.fromRGB(160, 40, 255),
        SecondaryColor = Color3.fromRGB(10, 0, 30),
        CombatBoosts = {
            DamageMultiplier = 2.20,
            WalkSpeedBonus = 10,
            CooldownReduction = 0.45,
        },
        AbilityName = "Event Horizon Oblivion",
        AbilityDescription = "Summons a black hole that pulls all players in the server arena into a gravitational vortex with a cinematic screen-shatter execution.",
    },
}

-- Array sorted from rarest to least rare for efficient weighted rolling
local RaritySortedList: { AuraDefinition } = {}
for _, aura in pairs(Auras) do
    table.insert(RaritySortedList, aura)
end
table.sort(RaritySortedList, function(a, b)
    return a.RarityChance > b.RarityChance
end)

return {
    Auras = Auras,
    RaritySortedList = RaritySortedList,
}

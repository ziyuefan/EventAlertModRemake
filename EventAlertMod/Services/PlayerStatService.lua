--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/PlayerStatService
檔案: Services\PlayerStatService.lua

理念:
- 負責玩家主屬性、副屬性、移動速度、飛行速度與傷害/治療吸收護盾的資料採樣與狀態發布。
- 採用安全 API 讀取，並透過 FontString:SetFormattedText 提供 Retail 12.x / Midnight 的 C-Level 零 GC 分配與 Secret Values / Taint 容錯渲染。

責任:
- 監聽屬性、光環與吸收量相關事件。
- 支援 18 種核心屬性取值、單位格式化、小數點處理與閾值判定。
- 管理 playerStat 獨立告警框架生命週期與 UI 渲染。
]]
local _, EAM = ...

EAM.Services = EAM.Services or {}
EAM.UI = EAM.UI or {}

local api = EAM.API or {}
local Util = EAM.Util or {}
local Constants = EAM.Constants or {}

local PlayerStatService = {
    stats = {},
    lastKnownStats = {},
    frames = {},
    active = false,
    sampleThrottle = 0.1,
    lastSampleTime = 0,
}
EAM.Services.PlayerStatService = PlayerStatService

local canaccesstable = canaccesstable or function(t) return type(t) == "table" end
local canaccessvalue = canaccessvalue or function() return true end
local issecretvalue = issecretvalue or function() return false end

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown()
end

local function shouldUnitStatsBeSecret(unit)
    unit = unit or "player"
    if C_Secrets and type(C_Secrets.ShouldUnitStatsBeSecret) == "function" then
        local ok, isSecret = pcall(C_Secrets.ShouldUnitStatsBeSecret, unit)
        if ok and isSecret == true then
            return true
        end
    end
    if api.C_Secrets and type(api.C_Secrets.ShouldUnitStatsBeSecret) == "function" then
        local ok, isSecret = pcall(api.C_Secrets.ShouldUnitStatsBeSecret, unit)
        if ok and isSecret == true then
            return true
        end
    end
    return false
end

PlayerStatService.shouldUnitStatsBeSecret = shouldUnitStatsBeSecret

local function isSafeNumber(val)
    if val == nil then return false end
    if Util and Util.isSecretValue and Util.isSecretValue(val) then return false end
    if issecretvalue and issecretvalue(val) then return false end
    if Util and Util.isSafeNumber then return Util.isSafeNumber(val) end
    if type(val) ~= "number" then return false end
    return val == val and val ~= math.huge and val ~= -math.huge
end

PlayerStatService.isSafeNumber = isSafeNumber

local function isPlayerGliding()
    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
        local ok, isGliding = pcall(C_PlayerInfo.GetGlidingInfo)
        if ok and isGliding == true then
            return true
        end
    end
    return false
end

PlayerStatService.isPlayerGliding = isPlayerGliding

local function getHealPredictionCalculator()
    if PlayerStatService.healPredictionCalc then
        return PlayerStatService.healPredictionCalc
    end
    local createCalc = rawget(_G, "CreateUnitHealPredictionCalculator")
    if type(createCalc) == "function" then
        local ok, calc = pcall(createCalc)
        if ok and calc then
            PlayerStatService.healPredictionCalc = calc
            return calc
        end
    end
    return nil
end

PlayerStatService.getHealPredictionCalculator = getHealPredictionCalculator

-- 依職業獲取獨立的 playerStats 設定表 (Per-Class Profile Support)
function PlayerStatService.getPlayerStatsConfig()
    local db = EAM.db
    if not db then return {}, "GLOBAL" end
    local classToken = nil
    if EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.getActiveClassToken then
        classToken = EAM.Modules.SavedVariables.getActiveClassToken()
    end
    if not classToken and UnitClassBase then
        classToken = UnitClassBase("player")
    end
    if classToken and db.profiles and db.profiles.classes and db.profiles.classes[classToken] then
        local profile = db.profiles.classes[classToken]
        profile.playerStats = type(profile.playerStats) == "table" and profile.playerStats or {}
        return profile.playerStats, classToken
    end
    db.playerStats = type(db.playerStats) == "table" and db.playerStats or {}
    return db.playerStats, classToken or "GLOBAL"
end

-- 18 大支援屬性定義清單 (支援多重 API 容錯、戰鬥即時取值與最後已知有效值快取)
local STAT_DEFINITIONS = {
    -- 主屬性
    strength = {
        key = "strength",
        labelKey = "EAM_STAT_STRENGTH",
        defaultLabel = "力量",
        defaultIcon = 136085, -- Spell_Nature_Strength
        category = "primary",
        getRawValue = function()
            if UnitStat then
                local ok, stat, effectiveStat = pcall(UnitStat, "player", 1)
                if ok and (effectiveStat or stat) ~= nil then
                    return effectiveStat or stat
                end
            end
            return PlayerStatService.lastKnownStats["strength"] or 0
        end,
        getValue = function()
            if UnitStat then
                local ok, stat, effectiveStat = pcall(UnitStat, "player", 1)
                if ok then
                    local val = effectiveStat or stat
                    if isSafeNumber(val) and val > 0 then
                        PlayerStatService.lastKnownStats["strength"] = val
                        return val
                    end
                end
            end
            return PlayerStatService.lastKnownStats["strength"] or 0
        end,
        format = "number",
    },
    agility = {
        key = "agility",
        labelKey = "EAM_STAT_AGILITY",
        defaultLabel = "敏捷",
        defaultIcon = 132212, -- Ability_Agility
        category = "primary",
        getRawValue = function()
            if UnitStat then
                local ok, stat, effectiveStat = pcall(UnitStat, "player", 2)
                if ok and (effectiveStat or stat) ~= nil then
                    return effectiveStat or stat
                end
            end
            return PlayerStatService.lastKnownStats["agility"] or 0
        end,
        getValue = function()
            if UnitStat then
                local ok, stat, effectiveStat = pcall(UnitStat, "player", 2)
                if ok then
                    local val = effectiveStat or stat
                    if isSafeNumber(val) and val > 0 then
                        PlayerStatService.lastKnownStats["agility"] = val
                        return val
                    end
                end
            end
            return PlayerStatService.lastKnownStats["agility"] or 0
        end,
        format = "number",
    },
    stamina = {
        key = "stamina",
        labelKey = "EAM_STAT_STAMINA",
        defaultLabel = "耐力",
        defaultIcon = 136109, -- Spell_Nature_UnyeildingStamina
        category = "primary",
        getRawValue = function()
            if UnitStat then
                local ok, stat, effectiveStat = pcall(UnitStat, "player", 3)
                if ok and (effectiveStat or stat) ~= nil then
                    return effectiveStat or stat
                end
            end
            return PlayerStatService.lastKnownStats["stamina"] or 0
        end,
        getValue = function()
            if UnitStat then
                local ok, stat, effectiveStat = pcall(UnitStat, "player", 3)
                if ok then
                    local val = effectiveStat or stat
                    if isSafeNumber(val) and val > 0 then
                        PlayerStatService.lastKnownStats["stamina"] = val
                        return val
                    end
                end
            end
            return PlayerStatService.lastKnownStats["stamina"] or 0
        end,
        format = "number",
    },
    intellect = {
        key = "intellect",
        labelKey = "EAM_STAT_INTELLECT",
        defaultLabel = "智力",
        defaultIcon = 135932, -- Spell_Holy_MagicalSentry
        category = "primary",
        getRawValue = function()
            if UnitStat then
                local ok, stat, effectiveStat = pcall(UnitStat, "player", 4)
                if ok and (effectiveStat or stat) ~= nil then
                    return effectiveStat or stat
                end
            end
            return PlayerStatService.lastKnownStats["intellect"] or 0
        end,
        getValue = function()
            if UnitStat then
                local ok, stat, effectiveStat = pcall(UnitStat, "player", 4)
                if ok then
                    local val = effectiveStat or stat
                    if isSafeNumber(val) and val > 0 then
                        PlayerStatService.lastKnownStats["intellect"] = val
                        return val
                    end
                end
            end
            return PlayerStatService.lastKnownStats["intellect"] or 0
        end,
        format = "number",
    },
    -- 副屬性
    crit = {
        key = "crit",
        labelKey = "EAM_STAT_CRIT",
        defaultLabel = "致命",
        defaultIcon = 132223, -- Ability_CriticalStrike
        category = "secondary",
        getRawValue = function()
            if GetCritChance then
                local ok, val = pcall(GetCritChance)
                if ok and val ~= nil then return val end
            end
            if GetSpellCritChance then
                for school = 1, 7 do
                    local ok, val = pcall(GetSpellCritChance, school)
                    if ok and val ~= nil then return val end
                end
            end
            if GetRangedCritChance then
                local ok, val = pcall(GetRangedCritChance)
                if ok and val ~= nil then return val end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_CRIT_MELEE or 9
                if ok and val ~= nil then
                    return isSafeNumber(val) and (5.0 + val) or val
                end
            end
            return PlayerStatService.lastKnownStats["crit"] or 0
        end,
        getValue = function()
            if GetCritChance then
                local ok, val = pcall(GetCritChance)
                if ok and isSafeNumber(val) and val > 0 then
                    PlayerStatService.lastKnownStats["crit"] = val
                    return val
                end
            end
            if GetSpellCritChance then
                for school = 1, 7 do
                    local ok, val = pcall(GetSpellCritChance, school)
                    if ok and isSafeNumber(val) and val > 0 then
                        PlayerStatService.lastKnownStats["crit"] = val
                        return val
                    end
                end
            end
            if GetRangedCritChance then
                local ok, val = pcall(GetRangedCritChance)
                if ok and isSafeNumber(val) and val > 0 then
                    PlayerStatService.lastKnownStats["crit"] = val
                    return val
                end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_CRIT_MELEE or 9
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and isSafeNumber(val) and val > 0 then
                    local totalCrit = 5.0 + val
                    PlayerStatService.lastKnownStats["crit"] = totalCrit
                    return totalCrit
                end
            end
            return PlayerStatService.lastKnownStats["crit"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    haste = {
        key = "haste",
        labelKey = "EAM_STAT_HASTE",
        defaultLabel = "加速",
        defaultIcon = 132242, -- Ability_Hunter_RunningShot
        category = "secondary",
        getRawValue = function()
            local fn = GetHaste or UnitSpellHaste
            if fn then
                local ok, val = pcall(fn, "player")
                if ok and val ~= nil then return val end
            end
            if GetMeleeHaste then
                local ok, val = pcall(GetMeleeHaste)
                if ok and val ~= nil then return val end
            end
            if GetRangedHaste then
                local ok, val = pcall(GetRangedHaste)
                if ok and val ~= nil then return val end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_HASTE_MELEE or 18
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and val ~= nil then return val end
            end
            return PlayerStatService.lastKnownStats["haste"] or 0
        end,
        getValue = function()
            local fn = GetHaste or UnitSpellHaste
            if fn then
                local ok, val = pcall(fn, "player")
                if ok and isSafeNumber(val) and val > 0 then
                    PlayerStatService.lastKnownStats["haste"] = val
                    return val
                end
            end
            if GetMeleeHaste then
                local ok, val = pcall(GetMeleeHaste)
                if ok and isSafeNumber(val) and val > 0 then
                    PlayerStatService.lastKnownStats["haste"] = val
                    return val
                end
            end
            if GetRangedHaste then
                local ok, val = pcall(GetRangedHaste)
                if ok and isSafeNumber(val) and val > 0 then
                    PlayerStatService.lastKnownStats["haste"] = val
                    return val
                end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_HASTE_MELEE or 18
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and isSafeNumber(val) and val > 0 then
                    PlayerStatService.lastKnownStats["haste"] = val
                    return val
                end
            end
            return PlayerStatService.lastKnownStats["haste"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    mastery = {
        key = "mastery",
        labelKey = "EAM_STAT_MASTERY",
        defaultLabel = "精通",
        defaultIcon = 135907, -- Spell_Holy_GreaterBlessingofSanctuary
        category = "secondary",
        getRawValue = function()
            if GetMasteryEffect then
                local ok, val = pcall(GetMasteryEffect)
                if ok and val ~= nil then return val end
            end
            if GetMastery then
                local ok, val = pcall(GetMastery)
                if ok and val ~= nil then return val end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_MASTERY or 26
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and val ~= nil then return val end
            end
            return PlayerStatService.lastKnownStats["mastery"] or 0
        end,
        getValue = function()
            if GetMasteryEffect then
                local ok, val = pcall(GetMasteryEffect)
                if ok and isSafeNumber(val) and val > 0 then
                    PlayerStatService.lastKnownStats["mastery"] = val
                    return val
                end
            end
            if GetMastery then
                local ok, val = pcall(GetMastery)
                if ok and isSafeNumber(val) and val > 0 then
                    PlayerStatService.lastKnownStats["mastery"] = val
                    return val
                end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_MASTERY or 26
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and isSafeNumber(val) and val > 0 then
                    PlayerStatService.lastKnownStats["mastery"] = val
                    return val
                end
            end
            return PlayerStatService.lastKnownStats["mastery"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    versatility = {
        key = "versatility",
        labelKey = "EAM_STAT_VERSATILITY",
        defaultLabel = "臨機應變",
        defaultIcon = 132362, -- Ability_Warrior_ShieldReflection
        category = "secondary",
        getRawValue = function()
            local cr = _G.CR_VERSATILITY_DAMAGE_DONE or 29
            local bonus, vers = nil, nil
            if GetCombatRatingBonus then
                local ok, b = pcall(GetCombatRatingBonus, cr)
                if ok and b ~= nil then bonus = b end
            end
            if GetVersatilityBonus then
                local ok, v = pcall(GetVersatilityBonus, cr)
                if ok and v ~= nil then vers = v end
            end
            if isSafeNumber(bonus) and isSafeNumber(vers) then
                return bonus + vers
            end
            return bonus or vers or PlayerStatService.lastKnownStats["versatility"] or 0
        end,
        getValue = function()
            local cr = _G.CR_VERSATILITY_DAMAGE_DONE or 29
            local bonus, vers = 0, 0
            local hasReading = false
            if GetCombatRatingBonus then
                local ok, b = pcall(GetCombatRatingBonus, cr)
                if ok and isSafeNumber(b) then
                    bonus = b
                    hasReading = true
                end
            end
            if GetVersatilityBonus then
                local ok, v = pcall(GetVersatilityBonus, cr)
                if ok and isSafeNumber(v) then
                    vers = v
                    hasReading = true
                end
            end
            local total = bonus + vers
            if hasReading and total > 0 then
                PlayerStatService.lastKnownStats["versatility"] = total
                return total
            end
            return PlayerStatService.lastKnownStats["versatility"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    avoidance = {
        key = "avoidance",
        labelKey = "EAM_STAT_AVOIDANCE",
        defaultLabel = "閃避",
        defaultIcon = 136006, -- Spell_Magic_LesserInvisibilty
        category = "tertiary",
        getRawValue = function()
            if GetAvoidance then
                local ok, val = pcall(GetAvoidance)
                if ok and val ~= nil then return val end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_AVOIDANCE or 21
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and val ~= nil then return val end
            end
            return PlayerStatService.lastKnownStats["avoidance"] or 0
        end,
        getValue = function()
            if GetAvoidance then
                local ok, val = pcall(GetAvoidance)
                if ok and isSafeNumber(val) then
                    PlayerStatService.lastKnownStats["avoidance"] = val
                    return val
                end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_AVOIDANCE or 21
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and isSafeNumber(val) then
                    PlayerStatService.lastKnownStats["avoidance"] = val
                    return val
                end
            end
            return PlayerStatService.lastKnownStats["avoidance"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    leech = {
        key = "leech",
        labelKey = "EAM_STAT_LEECH",
        defaultLabel = "汲取",
        defaultIcon = 136169, -- Spell_Shadow_LifeDrain02
        category = "tertiary",
        getRawValue = function()
            if GetLifesteal then
                local ok, val = pcall(GetLifesteal)
                if ok and val ~= nil then return val end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_LIFESTEAL or 22
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and val ~= nil then return val end
            end
            return PlayerStatService.lastKnownStats["leech"] or 0
        end,
        getValue = function()
            if GetLifesteal then
                local ok, val = pcall(GetLifesteal)
                if ok and isSafeNumber(val) then
                    PlayerStatService.lastKnownStats["leech"] = val
                    return val
                end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_LIFESTEAL or 22
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and isSafeNumber(val) then
                    PlayerStatService.lastKnownStats["leech"] = val
                    return val
                end
            end
            return PlayerStatService.lastKnownStats["leech"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    speedRating = {
        key = "speedRating",
        labelKey = "EAM_STAT_SPEED_RATING",
        defaultLabel = "速度 (屬性)",
        defaultIcon = 132297, -- Ability_Rogue_Feint
        category = "tertiary",
        getRawValue = function()
            if GetSpeed then
                local ok, val = pcall(GetSpeed)
                if ok and val ~= nil then return val end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_SPEED or 23
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and val ~= nil then return val end
            end
            return PlayerStatService.lastKnownStats["speedRating"] or 0
        end,
        getValue = function()
            if GetSpeed then
                local ok, val = pcall(GetSpeed)
                if ok and isSafeNumber(val) then
                    PlayerStatService.lastKnownStats["speedRating"] = val
                    return val
                end
            end
            if GetCombatRatingBonus then
                local cr = _G.CR_SPEED or 23
                local ok, val = pcall(GetCombatRatingBonus, cr)
                if ok and isSafeNumber(val) then
                    PlayerStatService.lastKnownStats["speedRating"] = val
                    return val
                end
            end
            return PlayerStatService.lastKnownStats["speedRating"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    -- 速度相關：跑速、泳速、飛速、飛龍模式飛速
    runSpeed = {
        key = "runSpeed",
        labelKey = "EAM_STAT_RUN_SPEED",
        defaultLabel = "跑速",
        defaultIcon = 132307, -- Ability_Rogue_Sprint
        category = "speed",
        getRawValue = function()
            if GetUnitSpeed then
                local ok, currentSpeed, runSpeed = pcall(GetUnitSpeed, "player")
                if ok and (currentSpeed or runSpeed) ~= nil then
                    local isMoving = (currentSpeed and isSafeNumber(currentSpeed) and currentSpeed > 0)
                    local isOtherMode = false
                    if IsFlying and IsFlying() then isOtherMode = true end
                    if IsSwimming and IsSwimming() then isOtherMode = true end
                    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
                        local gOk, isGliding = pcall(C_PlayerInfo.GetGlidingInfo)
                        if gOk and isGliding then isOtherMode = true end
                    end
                    local speed = (isMoving and not isOtherMode) and currentSpeed or runSpeed
                    if speed then
                        if isSafeNumber(speed) then
                            if speed <= 1.05 and inCombat() then
                                return PlayerStatService.lastKnownStats["runSpeed"] or 100
                            end
                            return (speed / 7.0) * 100
                        end
                        return speed
                    end
                end
            end
            return PlayerStatService.lastKnownStats["runSpeed"] or 100
        end,
        getValue = function()
            if GetUnitSpeed then
                local ok, currentSpeed, runSpeed = pcall(GetUnitSpeed, "player")
                if ok and (isSafeNumber(currentSpeed) or isSafeNumber(runSpeed)) then
                    local isMoving = (currentSpeed and isSafeNumber(currentSpeed) and currentSpeed > 0)
                    local isOtherMode = false
                    if IsFlying and IsFlying() then isOtherMode = true end
                    if IsSwimming and IsSwimming() then isOtherMode = true end
                    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
                        local gOk, isGliding = pcall(C_PlayerInfo.GetGlidingInfo)
                        if gOk and isGliding then isOtherMode = true end
                    end
                    local speed = (isMoving and not isOtherMode) and currentSpeed or runSpeed
                    if not isSafeNumber(speed) or speed <= 0 then
                        speed = (runSpeed and isSafeNumber(runSpeed) and runSpeed > 0) and runSpeed or 7.0
                    end
                    if isSafeNumber(speed) and speed <= 1.05 and inCombat() then
                        return PlayerStatService.lastKnownStats["runSpeed"] or 100
                    end
                    local pct = (speed / 7.0) * 100
                    if not inCombat() or pct > 15 then
                        PlayerStatService.lastKnownStats["runSpeed"] = pct
                    end
                    return pct
                end
            end
            return PlayerStatService.lastKnownStats["runSpeed"] or 100
        end,
        format = "percent",
        suffix = "%",
    },
    swimSpeed = {
        key = "swimSpeed",
        labelKey = "EAM_STAT_SWIM_SPEED",
        defaultLabel = "泳速",
        defaultIcon = 132150, -- Ability_Suffocate
        category = "speed",
        getRawValue = function()
            if GetUnitSpeed then
                local ok, currentSpeed, _, _, swimSpeed = pcall(GetUnitSpeed, "player")
                if ok and (currentSpeed or swimSpeed) ~= nil then
                    local isSwimming = IsSwimming and IsSwimming()
                    local speed = (isSwimming and currentSpeed and isSafeNumber(currentSpeed) and currentSpeed > 0) and currentSpeed or swimSpeed
                    if speed then
                        if isSafeNumber(speed) then
                            if speed <= 1.05 and inCombat() then
                                return PlayerStatService.lastKnownStats["swimSpeed"] or 67
                            end
                            return (speed / 7.0) * 100
                        end
                        return speed
                    end
                end
            end
            return PlayerStatService.lastKnownStats["swimSpeed"] or 67
        end,
        getValue = function()
            if GetUnitSpeed then
                local ok, currentSpeed, _, _, swimSpeed = pcall(GetUnitSpeed, "player")
                if ok and (isSafeNumber(currentSpeed) or isSafeNumber(swimSpeed)) then
                    local isSwimming = IsSwimming and IsSwimming()
                    local speed = (isSwimming and currentSpeed and isSafeNumber(currentSpeed) and currentSpeed > 0) and currentSpeed or swimSpeed
                    if not isSafeNumber(speed) or speed <= 0 then
                        speed = (swimSpeed and isSafeNumber(swimSpeed) and swimSpeed > 0) and swimSpeed or 4.7
                    end
                    if isSafeNumber(speed) and speed <= 1.05 and inCombat() then
                        return PlayerStatService.lastKnownStats["swimSpeed"] or 67
                    end
                    local pct = (speed / 7.0) * 100
                    if not inCombat() or pct > 15 then
                        PlayerStatService.lastKnownStats["swimSpeed"] = pct
                    end
                    return pct
                end
            end
            return PlayerStatService.lastKnownStats["swimSpeed"] or 67
        end,
        format = "percent",
        suffix = "%",
    },
    flightSpeed = {
        key = "flightSpeed",
        labelKey = "EAM_STAT_FLIGHT_SPEED",
        defaultLabel = "飛速",
        defaultIcon = 237558, -- Ability_Mount_Drake_Proto
        category = "speed",
        getRawValue = function()
            if GetUnitSpeed then
                local ok, currentSpeed, _, flightSpeed = pcall(GetUnitSpeed, "player")
                if ok and (currentSpeed or flightSpeed) ~= nil then
                    local isFlying = IsFlying and IsFlying()
                    local isGliding = false
                    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
                        local gOk, gliding = pcall(C_PlayerInfo.GetGlidingInfo)
                        if gOk and gliding then isGliding = true end
                    end
                    local speed = (isFlying and not isGliding and currentSpeed and isSafeNumber(currentSpeed) and currentSpeed > 0) and currentSpeed or flightSpeed
                    if speed then
                        if isSafeNumber(speed) then
                            if speed <= 1.05 and inCombat() then
                                return PlayerStatService.lastKnownStats["flightSpeed"] or 100
                            end
                            return (speed / 7.0) * 100
                        end
                        return speed
                    end
                end
            end
            return PlayerStatService.lastKnownStats["flightSpeed"] or 100
        end,
        getValue = function()
            if GetUnitSpeed then
                local ok, currentSpeed, _, flightSpeed = pcall(GetUnitSpeed, "player")
                if ok and (isSafeNumber(currentSpeed) or isSafeNumber(flightSpeed)) then
                    local isFlying = IsFlying and IsFlying()
                    local isGliding = false
                    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
                        local gOk, gliding = pcall(C_PlayerInfo.GetGlidingInfo)
                        if gOk and gliding then isGliding = true end
                    end
                    local speed = (isFlying and not isGliding and currentSpeed and isSafeNumber(currentSpeed) and currentSpeed > 0) and currentSpeed or flightSpeed
                    if not isSafeNumber(speed) or speed <= 0 then
                        speed = (flightSpeed and isSafeNumber(flightSpeed) and flightSpeed > 0) and flightSpeed or 7.0
                    end
                    if isSafeNumber(speed) and speed <= 1.05 and inCombat() then
                        return PlayerStatService.lastKnownStats["flightSpeed"] or 100
                    end
                    local pct = (speed / 7.0) * 100
                    if not inCombat() or pct > 15 then
                        PlayerStatService.lastKnownStats["flightSpeed"] = pct
                    end
                    return pct
                end
            end
            return PlayerStatService.lastKnownStats["flightSpeed"] or 100
        end,
        format = "percent",
        suffix = "%",
    },
    skyridingSpeed = {
        key = "skyridingSpeed",
        labelKey = "EAM_STAT_SKYRIDING_SPEED",
        requiresRetail = true,
        defaultLabel = "飛龍模式飛速",
        defaultIcon = 4667307, -- ability_dragonriding_surgeforward01
        category = "speed",
        getRawValue = function()
            if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
                local ok, isGliding, canGlide, forwardSpeed = pcall(C_PlayerInfo.GetGlidingInfo)
                if ok and forwardSpeed ~= nil then
                    return isSafeNumber(forwardSpeed) and ((forwardSpeed / 7.0) * 100) or forwardSpeed
                end
            end
            if GetUnitSpeed then
                local ok, currentSpeed, _, flightSpeed = pcall(GetUnitSpeed, "player")
                if ok and (currentSpeed or flightSpeed) ~= nil then
                    local speed = (currentSpeed and isSafeNumber(currentSpeed) and currentSpeed > 0) and currentSpeed or flightSpeed
                    if speed then
                        return isSafeNumber(speed) and ((speed / 7.0) * 100) or speed
                    end
                end
            end
            return PlayerStatService.lastKnownStats["skyridingSpeed"] or 0
        end,
        getValue = function()
            if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
                local ok, isGliding, canGlide, forwardSpeed = pcall(C_PlayerInfo.GetGlidingInfo)
                if ok and isGliding and isSafeNumber(forwardSpeed) and forwardSpeed > 0 then
                    local pct = (forwardSpeed / 7.0) * 100
                    PlayerStatService.lastKnownStats["skyridingSpeed"] = pct
                    return pct
                end
            end
            if GetUnitSpeed then
                local ok, currentSpeed, _, flightSpeed = pcall(GetUnitSpeed, "player")
                if ok and (isSafeNumber(currentSpeed) or isSafeNumber(flightSpeed)) then
                    local isFlying = IsFlying and IsFlying()
                    local speed = (isFlying and currentSpeed and isSafeNumber(currentSpeed) and currentSpeed > 0) and currentSpeed or flightSpeed
                    if isSafeNumber(speed) and speed > 0 then
                        local pct = (speed / 7.0) * 100
                        PlayerStatService.lastKnownStats["skyridingSpeed"] = pct
                        return pct
                    end
                end
            end
            return PlayerStatService.lastKnownStats["skyridingSpeed"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    totalAbsorb = {
        key = "totalAbsorb",
        labelKey = "EAM_STAT_TOTAL_ABSORB",
        defaultLabel = "總吸收盾量",
        defaultIcon = 135940, -- Spell_Holy_PowerWordShield
        category = "survival",
        getRawValue = function()
            local calc = getHealPredictionCalculator()
            local getDetailed = rawget(_G, "UnitGetDetailedHealPrediction")
            if calc and type(getDetailed) == "function" then
                local ok = pcall(getDetailed, "player", nil, calc)
                if ok and type(calc.GetDamageAbsorbs) == "function" then
                    local okDmg, dmgAbsorb = pcall(calc.GetDamageAbsorbs, calc)
                    if okDmg and isSafeNumber(dmgAbsorb) then
                        return dmgAbsorb
                    end
                end
            end
            return UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("player") or 0
        end,
        getValue = function()
            local total = 0
            local calc = getHealPredictionCalculator()
            local getDetailed = rawget(_G, "UnitGetDetailedHealPrediction")
            if calc and type(getDetailed) == "function" then
                local ok = pcall(getDetailed, "player", nil, calc)
                if ok and type(calc.GetDamageAbsorbs) == "function" then
                    local okDmg, dmgAbsorb = pcall(calc.GetDamageAbsorbs, calc)
                    if okDmg and isSafeNumber(dmgAbsorb) then
                        PlayerStatService.lastKnownStats["totalAbsorb"] = dmgAbsorb
                        return dmgAbsorb
                    end
                end
            end
            if UnitGetTotalAbsorbs then
                local ok, val = pcall(UnitGetTotalAbsorbs, "player")
                if ok and isSafeNumber(val) and val > 0 then
                    total = val
                end
            end
            if total <= 0 and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                local i = 1
                while true do
                    local okAura, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
                    if not okAura or not aura then break end
                    if aura.points and type(aura.points) == "table" and canaccesstable(aura.points) then
                        for pIdx = 1, #aura.points do
                            local pt = aura.points[pIdx]
                            if pt and not issecretvalue(pt) and canaccessvalue(pt) and type(pt) == "number" and pt > 0 then
                                total = total + pt
                                break
                            end
                        end
                    end
                    i = i + 1
                    if i > 40 then break end
                end
            end
            return total
        end,
        format = "largeNumber",
    },
    healAbsorb = {
        key = "healAbsorb",
        labelKey = "EAM_STAT_HEAL_ABSORB",
        defaultLabel = "治療吸收量",
        defaultIcon = 136120, -- Spell_Shadow_AntiShadow
        category = "survival",
        getRawValue = function()
            local calc = getHealPredictionCalculator()
            local getDetailed = rawget(_G, "UnitGetDetailedHealPrediction")
            if calc and type(getDetailed) == "function" then
                local ok = pcall(getDetailed, "player", nil, calc)
                if ok and type(calc.GetHealAbsorbs) == "function" then
                    local okHeal, hAbsorb = pcall(calc.GetHealAbsorbs, calc)
                    if okHeal and isSafeNumber(hAbsorb) then
                        return hAbsorb
                    end
                end
            end
            return UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs("player") or 0
        end,
        getValue = function()
            local total = 0
            local calc = getHealPredictionCalculator()
            local getDetailed = rawget(_G, "UnitGetDetailedHealPrediction")
            if calc and type(getDetailed) == "function" then
                local ok = pcall(getDetailed, "player", nil, calc)
                if ok and type(calc.GetHealAbsorbs) == "function" then
                    local okHeal, hAbsorb = pcall(calc.GetHealAbsorbs, calc)
                    if okHeal and isSafeNumber(hAbsorb) then
                        PlayerStatService.lastKnownStats["healAbsorb"] = hAbsorb
                        return hAbsorb
                    end
                end
            end
            if UnitGetTotalHealAbsorbs then
                local ok, val = pcall(UnitGetTotalHealAbsorbs, "player")
                if ok and isSafeNumber(val) and val > 0 then
                    total = val
                end
            end
            if total <= 0 and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                local i = 1
                while true do
                    local okAura, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HARMFUL")
                    if not okAura or not aura then break end
                    if aura.points and type(aura.points) == "table" and canaccesstable(aura.points) then
                        for pIdx = 1, #aura.points do
                            local pt = aura.points[pIdx]
                            if pt and not issecretvalue(pt) and canaccessvalue(pt) and type(pt) == "number" and pt > 0 then
                                total = total + pt
                                break
                            end
                        end
                    end
                    i = i + 1
                    if i > 40 then break end
                end
            end
            return total
        end,
        format = "largeNumber",
    },
    armor = {
        key = "armor",
        labelKey = "EAM_STAT_ARMOR",
        defaultLabel = "護甲值",
        defaultIcon = 134951, -- INV_Shield_04
        category = "survival",
        getRawValue = function()
            if UnitArmor then
                local ok, base, effectiveArmor = pcall(UnitArmor, "player")
                if ok and (effectiveArmor or base) ~= nil then
                    return effectiveArmor or base
                end
            end
            return PlayerStatService.lastKnownStats["armor"] or 0
        end,
        getValue = function()
            if UnitArmor then
                local ok, base, effectiveArmor = pcall(UnitArmor, "player")
                if ok then
                    local val = effectiveArmor or base
                    if isSafeNumber(val) and val > 0 then
                        PlayerStatService.lastKnownStats["armor"] = val
                        return val
                    end
                end
            end
            return PlayerStatService.lastKnownStats["armor"] or 0
        end,
        format = "number",
    },
    -- Forever 1.60.1 專屬經典屬性
    spiritManaRegen = {
        key = "spiritManaRegen",
        labelKey = "EAM_STAT_SPIRIT_MANA_REGEN",
        defaultLabel = "精神回魔",
        defaultIcon = 135981, -- Spell_Holy_MagicalSentry
        category = "manaRegen",
        requiresForever = true,
        getRawValue = function()
            local fn = api.GetManaRegenFromSpirit or _G.GetManaRegenFromSpirit
            if fn then
                local ok, powerRegen, combatPowerRegen = pcall(fn)
                if ok and powerRegen ~= nil then
                    if isSafeNumber(powerRegen) then
                        return math.floor(powerRegen * 5 + 0.5)
                    end
                    return powerRegen
                end
            end
            return PlayerStatService.lastKnownStats["spiritManaRegen"] or 0
        end,
        getValue = function()
            local fn = api.GetManaRegenFromSpirit or _G.GetManaRegenFromSpirit
            if fn then
                local ok, powerRegen, combatPowerRegen = pcall(fn)
                if ok and isSafeNumber(powerRegen) and powerRegen > 0 then
                    local mp5 = math.floor(powerRegen * 5 + 0.5)
                    PlayerStatService.lastKnownStats["spiritManaRegen"] = mp5
                    return mp5
                end
            end
            return PlayerStatService.lastKnownStats["spiritManaRegen"] or 0
        end,
        format = "number",
        suffix = "/5s",
    },
    defenseSkill = {
        key = "defenseSkill",
        labelKey = "EAM_STAT_DEFENSE_SKILL",
        defaultLabel = "防禦技能",
        defaultIcon = 132341, -- Inv_Shield_06
        category = "defense",
        requiresForever = true,
        getRawValue = function()
            local fn = api.UnitDefenseSkill or _G.UnitDefenseSkill
            if fn then
                local ok, base, modifier = pcall(fn, "player")
                if ok and base ~= nil then
                    if isSafeNumber(base) then
                        return base + (isSafeNumber(modifier) and modifier or 0)
                    end
                    return base
                end
            end
            return PlayerStatService.lastKnownStats["defenseSkill"] or 0
        end,
        getValue = function()
            local fn = api.UnitDefenseSkill or _G.UnitDefenseSkill
            if fn then
                local ok, base, modifier = pcall(fn, "player")
                if ok and isSafeNumber(base) then
                    local total = base + (isSafeNumber(modifier) and modifier or 0)
                    if total > 0 then
                        PlayerStatService.lastKnownStats["defenseSkill"] = total
                        return total
                    end
                end
            end
            return PlayerStatService.lastKnownStats["defenseSkill"] or 0
        end,
        format = "number",
    },
    petHappiness = {
        key = "petHappiness",
        labelKey = "EAM_STAT_PET_HAPPINESS",
        defaultLabel = "寵物快樂度",
        defaultIcon = 132242, -- Ability_Hunter_BeastTraining
        category = "pet",
        requiresForever = true,
        classLimit = "HUNTER",
        getRawValue = function()
            local petInfo = api.C_PetInfo or _G.C_PetInfo
            if petInfo and petInfo.GetPetHappiness then
                local ok, happiness = pcall(petInfo.GetPetHappiness)
                if ok and happiness ~= nil then
                    return happiness
                end
            end
            local fn = _G.GetPetHappiness
            if fn then
                local ok, happiness = pcall(fn)
                if ok and happiness ~= nil then
                    return happiness
                end
            end
            return PlayerStatService.lastKnownStats["petHappiness"] or 0
        end,
        getValue = function()
            local petInfo = api.C_PetInfo or _G.C_PetInfo
            if petInfo and petInfo.GetPetHappiness then
                local ok, happiness = pcall(petInfo.GetPetHappiness)
                if ok and isSafeNumber(happiness) and happiness > 0 then
                    PlayerStatService.lastKnownStats["petHappiness"] = happiness
                    return happiness
                end
            end
            local fn = _G.GetPetHappiness
            if fn then
                local ok, happiness = pcall(fn)
                if ok and isSafeNumber(happiness) and happiness > 0 then
                    PlayerStatService.lastKnownStats["petHappiness"] = happiness
                    return happiness
                end
            end
            return PlayerStatService.lastKnownStats["petHappiness"] or 0
        end,
        format = "number",
    },
    ammoStatus = {
        key = "ammoStatus",
        labelKey = "EAM_STAT_AMMO_STATUS",
        defaultLabel = "彈藥存量",
        defaultIcon = 132381, -- Inv_Ammo_Arrow_02
        category = "ammo",
        requiresForever = true,
        classLimit = "HUNTER",
        getRawValue = function()
            local usesAmmo = api.UnitUsesAmmo or _G.UnitUsesAmmo
            if usesAmmo then
                local ok, needed = pcall(usesAmmo, "player")
                if ok and not needed then
                    return 0
                end
            end
            if _G.GetInventoryItemCount then
                local ok, count = pcall(_G.GetInventoryItemCount, "player", 0)
                if ok and count ~= nil then
                    return count
                end
            end
            return PlayerStatService.lastKnownStats["ammoStatus"] or 0
        end,
        getValue = function()
            local usesAmmo = api.UnitUsesAmmo or _G.UnitUsesAmmo
            if usesAmmo then
                local ok, needed = pcall(usesAmmo, "player")
                if ok and not needed then
                    return 0
                end
            end
            if _G.GetInventoryItemCount then
                local ok, count = pcall(_G.GetInventoryItemCount, "player", 0)
                if ok and isSafeNumber(count) then
                    PlayerStatService.lastKnownStats["ammoStatus"] = count
                    return count
                end
            end
            return PlayerStatService.lastKnownStats["ammoStatus"] or 0
        end,
        format = "number",
    },
    -- 五大抗性 (Forever 專屬)
    resistArcane = {
        key = "resistArcane",
        labelKey = "EAM_STAT_RESIST_ARCANE",
        defaultLabel = "秘法抗性",
        defaultIcon = 136096,
        category = "resistance",
        requiresForever = true,
        getRawValue = function()
            local getRes = api.UnitResistance or _G.UnitResistance
            if getRes then
                local dc = (Enum and Enum.Damageclass and Enum.Damageclass.Arcane) or 6
                local ok, baseRes, realRes, effectiveRes = pcall(getRes, "player", dc)
                if ok and effectiveRes ~= nil then
                    return effectiveRes
                end
            end
            return PlayerStatService.lastKnownStats["resistArcane"] or 0
        end,
        getValue = function()
            local getRes = api.UnitResistance or _G.UnitResistance
            if getRes then
                local dc = (Enum and Enum.Damageclass and Enum.Damageclass.Arcane) or 6
                local ok, baseRes, realRes, effectiveRes = pcall(getRes, "player", dc)
                if ok and isSafeNumber(effectiveRes) and effectiveRes >= 0 then
                    PlayerStatService.lastKnownStats["resistArcane"] = effectiveRes
                    return effectiveRes
                end
            end
            return PlayerStatService.lastKnownStats["resistArcane"] or 0
        end,
    },
    resistFire = {
        key = "resistFire",
        labelKey = "EAM_STAT_RESIST_FIRE",
        defaultLabel = "火焰抗性",
        defaultIcon = 135824,
        category = "resistance",
        requiresForever = true,
        getRawValue = function()
            local getRes = api.UnitResistance or _G.UnitResistance
            if getRes then
                local dc = (Enum and Enum.Damageclass and Enum.Damageclass.Fire) or 2
                local ok, baseRes, realRes, effectiveRes = pcall(getRes, "player", dc)
                if ok and effectiveRes ~= nil then
                    return effectiveRes
                end
            end
            return PlayerStatService.lastKnownStats["resistFire"] or 0
        end,
        getValue = function()
            local getRes = api.UnitResistance or _G.UnitResistance
            if getRes then
                local dc = (Enum and Enum.Damageclass and Enum.Damageclass.Fire) or 2
                local ok, baseRes, realRes, effectiveRes = pcall(getRes, "player", dc)
                if ok and isSafeNumber(effectiveRes) and effectiveRes >= 0 then
                    PlayerStatService.lastKnownStats["resistFire"] = effectiveRes
                    return effectiveRes
                end
            end
            return PlayerStatService.lastKnownStats["resistFire"] or 0
        end,
    },
    resistFrost = {
        key = "resistFrost",
        labelKey = "EAM_STAT_RESIST_FROST",
        defaultLabel = "冰霜抗性",
        defaultIcon = 135848,
        category = "resistance",
        requiresForever = true,
        getRawValue = function()
            local getRes = api.UnitResistance or _G.UnitResistance
            if getRes then
                local dc = (Enum and Enum.Damageclass and Enum.Damageclass.Frost) or 4
                local ok, baseRes, realRes, effectiveRes = pcall(getRes, "player", dc)
                if ok and effectiveRes ~= nil then
                    return effectiveRes
                end
            end
            return PlayerStatService.lastKnownStats["resistFrost"] or 0
        end,
        getValue = function()
            local getRes = api.UnitResistance or _G.UnitResistance
            if getRes then
                local dc = (Enum and Enum.Damageclass and Enum.Damageclass.Frost) or 4
                local ok, baseRes, realRes, effectiveRes = pcall(getRes, "player", dc)
                if ok and isSafeNumber(effectiveRes) and effectiveRes >= 0 then
                    PlayerStatService.lastKnownStats["resistFrost"] = effectiveRes
                    return effectiveRes
                end
            end
            return PlayerStatService.lastKnownStats["resistFrost"] or 0
        end,
    },
    resistNature = {
        key = "resistNature",
        labelKey = "EAM_STAT_RESIST_NATURE",
        defaultLabel = "自然抗性",
        defaultIcon = 136074,
        category = "resistance",
        requiresForever = true,
        getRawValue = function()
            local getRes = api.UnitResistance or _G.UnitResistance
            if getRes then
                local dc = (Enum and Enum.Damageclass and Enum.Damageclass.Nature) or 3
                local ok, baseRes, realRes, effectiveRes = pcall(getRes, "player", dc)
                if ok and effectiveRes ~= nil then
                    return effectiveRes
                end
            end
            return PlayerStatService.lastKnownStats["resistNature"] or 0
        end,
        getValue = function()
            local getRes = api.UnitResistance or _G.UnitResistance
            if getRes then
                local dc = (Enum and Enum.Damageclass and Enum.Damageclass.Nature) or 3
                local ok, baseRes, realRes, effectiveRes = pcall(getRes, "player", dc)
                if ok and isSafeNumber(effectiveRes) and effectiveRes >= 0 then
                    PlayerStatService.lastKnownStats["resistNature"] = effectiveRes
                    return effectiveRes
                end
            end
            return PlayerStatService.lastKnownStats["resistNature"] or 0
        end,
    },
    resistShadow = {
        key = "resistShadow",
        labelKey = "EAM_STAT_RESIST_SHADOW",
        defaultLabel = "暗影抗性",
        defaultIcon = 136192,
        category = "resistance",
        requiresForever = true,
        getRawValue = function()
            local getRes = api.UnitResistance or _G.UnitResistance
            if getRes then
                local dc = (Enum and Enum.Damageclass and Enum.Damageclass.Shadow) or 5
                local ok, baseRes, realRes, effectiveRes = pcall(getRes, "player", dc)
                if ok and effectiveRes ~= nil then
                    return effectiveRes
                end
            end
            return PlayerStatService.lastKnownStats["resistShadow"] or 0
        end,
        getValue = function()
            local getRes = api.UnitResistance or _G.UnitResistance
            if getRes then
                local dc = (Enum and Enum.Damageclass and Enum.Damageclass.Shadow) or 5
                local ok, baseRes, realRes, effectiveRes = pcall(getRes, "player", dc)
                if ok and isSafeNumber(effectiveRes) and effectiveRes >= 0 then
                    PlayerStatService.lastKnownStats["resistShadow"] = effectiveRes
                    return effectiveRes
                end
            end
            return PlayerStatService.lastKnownStats["resistShadow"] or 0
        end,
    },
    spirit = {
        key = "spirit",
        labelKey = "EAM_STAT_SPIRIT",
        defaultLabel = "精神",
        defaultIcon = 135981, -- Spell_Nature_Regenerate
        category = "primary",
        requiresForever = true,
        getRawValue = function()
            local getStat = api.UnitStat or _G.UnitStat
            if getStat then
                local ok, stat, effectiveStat = pcall(getStat, "player", 5)
                if ok and (effectiveStat ~= nil or stat ~= nil) then
                    return effectiveStat or stat
                end
            end
            return PlayerStatService.lastKnownStats["spirit"] or 0
        end,
        getValue = function()
            local getStat = api.UnitStat or _G.UnitStat
            if getStat then
                local ok, stat, effectiveStat = pcall(getStat, "player", 5)
                local val = effectiveStat or stat
                if ok and isSafeNumber(val) and val >= 0 then
                    PlayerStatService.lastKnownStats["spirit"] = val
                    return val
                end
            end
            return PlayerStatService.lastKnownStats["spirit"] or 0
        end,
        format = "number",
    },
    attackPower = {
        key = "attackPower",
        labelKey = "EAM_STAT_ATTACK_POWER",
        defaultLabel = "攻擊強度",
        defaultIcon = 132333, -- Ability_MeleeDamage
        category = "offense",
        getRawValue = function()
            local getAP = api.UnitAttackPower or _G.UnitAttackPower
            if getAP then
                local ok, base, posBuff, negBuff = pcall(getAP, "player")
                if ok and base ~= nil then
                    local total = (base or 0) + (posBuff or 0) + (negBuff or 0)
                    if total > 0 then return total end
                end
            end
            local getRAP = api.UnitRangedAttackPower or _G.UnitRangedAttackPower
            if getRAP then
                local ok, base, posBuff, negBuff = pcall(getRAP, "player")
                if ok and base ~= nil then
                    local total = (base or 0) + (posBuff or 0) + (negBuff or 0)
                    if total > 0 then return total end
                end
            end
            return PlayerStatService.lastKnownStats["attackPower"] or 0
        end,
        getValue = function()
            local getAP = api.UnitAttackPower or _G.UnitAttackPower
            if getAP then
                local ok, base, posBuff, negBuff = pcall(getAP, "player")
                if ok and isSafeNumber(base) then
                    local total = base + (isSafeNumber(posBuff) and posBuff or 0) + (isSafeNumber(negBuff) and negBuff or 0)
                    if total > 0 then
                        PlayerStatService.lastKnownStats["attackPower"] = total
                        return total
                    end
                end
            end
            local getRAP = api.UnitRangedAttackPower or _G.UnitRangedAttackPower
            if getRAP then
                local ok, base, posBuff, negBuff = pcall(getRAP, "player")
                if ok and isSafeNumber(base) then
                    local total = base + (isSafeNumber(posBuff) and posBuff or 0) + (isSafeNumber(negBuff) and negBuff or 0)
                    if total > 0 then
                        PlayerStatService.lastKnownStats["attackPower"] = total
                        return total
                    end
                end
            end
            return PlayerStatService.lastKnownStats["attackPower"] or 0
        end,
        format = "number",
    },
    dodge = {
        key = "dodge",
        labelKey = "EAM_STAT_DODGE",
        defaultLabel = "閃躲",
        defaultIcon = 132302, -- Ability_Rogue_Feint
        category = "defense",
        getRawValue = function()
            local fn = api.GetDodgeChance or _G.GetDodgeChance
            if fn then
                local ok, val = pcall(fn)
                if ok and val ~= nil then return val end
            end
            return PlayerStatService.lastKnownStats["dodge"] or 0
        end,
        getValue = function()
            local fn = api.GetDodgeChance or _G.GetDodgeChance
            if fn then
                local ok, val = pcall(fn)
                if ok and isSafeNumber(val) then
                    PlayerStatService.lastKnownStats["dodge"] = val
                    return val
                end
            end
            return PlayerStatService.lastKnownStats["dodge"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    parry = {
        key = "parry",
        labelKey = "EAM_STAT_PARRY",
        defaultLabel = "招架",
        defaultIcon = 132304, -- Ability_Parry
        category = "defense",
        getRawValue = function()
            local fn = api.GetParryChance or _G.GetParryChance
            if fn then
                local ok, val = pcall(fn)
                if ok and val ~= nil then return val end
            end
            return PlayerStatService.lastKnownStats["parry"] or 0
        end,
        getValue = function()
            local fn = api.GetParryChance or _G.GetParryChance
            if fn then
                local ok, val = pcall(fn)
                if ok and isSafeNumber(val) then
                    PlayerStatService.lastKnownStats["parry"] = val
                    return val
                end
            end
            return PlayerStatService.lastKnownStats["parry"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    block = {
        key = "block",
        labelKey = "EAM_STAT_BLOCK",
        defaultLabel = "格擋",
        defaultIcon = 132343, -- Ability_Warrior_ShieldBlock
        category = "defense",
        getRawValue = function()
            local fn = api.GetBlockChance or _G.GetBlockChance
            if fn then
                local ok, val = pcall(fn)
                if ok and val ~= nil then return val end
            end
            return PlayerStatService.lastKnownStats["block"] or 0
        end,
        getValue = function()
            local fn = api.GetBlockChance or _G.GetBlockChance
            if fn then
                local ok, val = pcall(fn)
                if ok and isSafeNumber(val) then
                    PlayerStatService.lastKnownStats["block"] = val
                    return val
                end
            end
            return PlayerStatService.lastKnownStats["block"] or 0
        end,
        format = "percent",
        suffix = "%",
    },
    mana = {
        key = "mana",
        labelKey = "EAM_STAT_MANA",
        defaultLabel = "法力",
        defaultIcon = 136096, -- Spell_Arcane_PortalIronForge / Arcane / Mana
        category = "resource",
        getRawValue = function()
            local getP = api.UnitPower or _G.UnitPower
            if getP then
                local ok, val = pcall(getP, "player", 0)
                if ok and val ~= nil then return val end
            end
            return PlayerStatService.lastKnownStats["mana"] or 0
        end,
        getValue = function()
            local getP = api.UnitPower or _G.UnitPower
            if getP then
                local ok, val = pcall(getP, "player", 0)
                if ok and isSafeNumber(val) and val >= 0 then
                    PlayerStatService.lastKnownStats["mana"] = val
                    return val
                end
            end
            return PlayerStatService.lastKnownStats["mana"] or 0
        end,
        format = "number",
    },
}
PlayerStatService.DEFINITIONS = STAT_DEFINITIONS

local RETAIL_ORDERED_KEYS = {
    "strength", "agility", "stamina", "intellect", "mana",
    "attackPower", "crit", "haste", "mastery", "versatility",
    "dodge", "parry", "block",
    "avoidance", "leech", "speedRating",
    "runSpeed", "swimSpeed", "flightSpeed", "skyridingSpeed",
    "totalAbsorb", "healAbsorb", "armor"
}

local FOREVER_ORDERED_KEYS = {
    "strength", "agility", "stamina", "intellect", "spirit", "mana",
    "attackPower", "crit", "haste", "spiritManaRegen", "defenseSkill",
    "dodge", "parry", "block",
    "armor", "resistArcane", "resistFire", "resistFrost", "resistNature", "resistShadow",
    "runSpeed", "swimSpeed",
    "petHappiness", "ammoStatus",
    "totalAbsorb", "healAbsorb"
}

local ORDERED_KEYS = RETAIL_ORDERED_KEYS
PlayerStatService.RETAIL_ORDERED_KEYS = RETAIL_ORDERED_KEYS
PlayerStatService.FOREVER_ORDERED_KEYS = FOREVER_ORDERED_KEYS
PlayerStatService.ORDERED_KEYS = ORDERED_KEYS

-- 取得當前屬性排列順序（優先讀取職業獨立/全域設定，支援使用者自選排序）

local spiritSnapshot = {
    isActive = false,
    isManaActive = false,
    isHealthActive = false,
    fiveSecRemaining = 0,
    justActivated = false,
    spiritVal = 0,
    spiritMP5 = 0,
    spiritHP5 = 0,
    hasManaPool = false,
    lastPopTime = 0,
}

PlayerStatService.spiritState = {
    manaSpendExpireTime = 0,
    lastSafeMana = nil,
    isSitting = false,
    wasActive = nil,
    justActivated = false,
    lastPopTime = 0,
    lastEvalTime = -1,
}

function PlayerStatService.resetSpiritRegenState()
    local state = PlayerStatService.spiritState
    state.manaSpendExpireTime = 0
    state.lastSafeMana = nil
    state.isSitting = false
    state.wasActive = nil
    state.justActivated = false
    state.lastPopTime = 0
    state.lastEvalTime = -1
    spiritSnapshot.isActive = false
    spiritSnapshot.isManaActive = false
    spiritSnapshot.isHealthActive = false
    spiritSnapshot.fiveSecRemaining = 0
    spiritSnapshot.justActivated = false
    spiritSnapshot.spiritVal = 0
    spiritSnapshot.spiritMP5 = 0
    spiritSnapshot.spiritHP5 = 0
    spiritSnapshot.hasManaPool = false
    spiritSnapshot.lastPopTime = 0
end

local function hasPlayerFreecastAura()
    local cUnitAuras = api.C_UnitAuras or _G.C_UnitAuras
    if cUnitAuras and cUnitAuras.GetPlayerAuraBySpellID then
        local FREECAST_SPELLS = { 12536, 16246, 16870 }
        for i = 1, #FREECAST_SPELLS do
            local ok, aura = pcall(cUnitAuras.GetPlayerAuraBySpellID, FREECAST_SPELLS[i])
            if ok and aura and (type(aura) == "table" or type(aura) == "userdata") then
                return true
            end
        end
    end
    return false
end

function PlayerStatService.onPlayerSpellCastSucceeded(spellID)
    if not isSafeNumber(spellID) or spellID <= 0 then return end
    if hasPlayerFreecastAura() then return end
    local now = (api.GetTime or _G.GetTime)()
    local cSpell = api.C_Spell or _G.C_Spell
    if cSpell and cSpell.GetSpellPowerCost then
        local ok, costs = pcall(cSpell.GetSpellPowerCost, spellID)
        if ok and type(costs) == "table" then
            local hasManaCost = false
            for i = 1, #costs do
                local entry = costs[i]
                if type(entry) == "table" then
                    local costType = Util.readStructuredField(entry, "type")
                    local cost = Util.readStructuredField(entry, "cost")
                    local minCost = Util.readStructuredField(entry, "minCost")
                    if costType == 0 or costType == (Enum and Enum.PowerType and Enum.PowerType.Mana) then
                        if (isSafeNumber(cost) and cost > 0) or (isSafeNumber(minCost) and minCost > 0) or Util.isSecretValue(cost) or Util.isSecretValue(minCost) then
                            hasManaCost = true
                            break
                        end
                    end
                end
            end
            if hasManaCost then
                PlayerStatService.spiritState.manaSpendExpireTime = now + 5.0
                return
            end
        end
    end
end

function PlayerStatService.onPlayerPowerUpdate()
    local getPower = api.UnitPower or _G.UnitPower
    if not getPower then return end
    local ok, curMana = pcall(getPower, "player", 0)
    if ok and isSafeNumber(curMana) then
        local last = PlayerStatService.spiritState.lastSafeMana
        if last and curMana < (last - 0.5) then
            local now = (api.GetTime or _G.GetTime)()
            PlayerStatService.spiritState.manaSpendExpireTime = now + 5.0
        end
        PlayerStatService.spiritState.lastSafeMana = curMana
    end
end

function PlayerStatService.getSpiritRegenState()
    local now = (api.GetTime or _G.GetTime)()
    local state = PlayerStatService.spiritState

    if state.lastEvalTime == now then
        return spiritSnapshot
    end

    local fnSpiritMP = api.GetManaRegenFromSpirit or _G.GetManaRegenFromSpirit
    local spiritMP5 = 0
    if fnSpiritMP then
        local ok, sRegen = pcall(fnSpiritMP)
        if ok and isSafeNumber(sRegen) and sRegen > 0 then
            spiritMP5 = math.floor(sRegen * 5 + 0.5)
        end
    end

    local fnSpiritHP = api.GetHealthRegenFromSpirit or _G.GetHealthRegenFromSpirit
    local spiritHP5 = 0
    if fnSpiritHP then
        local ok, sRegenHP = pcall(fnSpiritHP)
        if ok and isSafeNumber(sRegenHP) and sRegenHP > 0 then
            spiritHP5 = math.floor(sRegenHP * 0.75 * 5 + 0.5)
        end
    end

    local spiritVal = 0
    local getStat = api.UnitStat or _G.UnitStat
    if getStat then
        local ok, stat, effectiveStat = pcall(getStat, "player", 5)
        local val = effectiveStat or stat
        if ok and isSafeNumber(val) then
            spiritVal = val
        end
    end

    local hasManaPool = false
    local getPowerMax = api.UnitPowerMax or _G.UnitPowerMax
    if getPowerMax then
        local ok, maxP = pcall(getPowerMax, "player", 0)
        if ok and isSafeNumber(maxP) and maxP > 0 then
            hasManaPool = true
        end
    end
    if not hasManaPool and api.UnitClass then
        local ok, _, classToken = pcall(api.UnitClass, "player")
        if ok and classToken ~= "WARRIOR" and classToken ~= "ROGUE" then
            hasManaPool = true
        end
    end

    local fiveSecRemaining = math.max(0, state.manaSpendExpireTime - now)
    local isManaActive = hasManaPool and (fiveSecRemaining <= 0)
    local isHealthActive = not inCombat()

    local isActive = false
    if hasManaPool then
        isActive = isManaActive
    else
        isActive = isHealthActive
    end

    local justActivated = false
    if state.wasActive == false and isActive == true then
        justActivated = true
        state.lastPopTime = now
    end
    state.wasActive = isActive
    state.justActivated = justActivated
    state.lastEvalTime = now

    spiritSnapshot.isActive = isActive
    spiritSnapshot.isManaActive = isManaActive
    spiritSnapshot.isHealthActive = isHealthActive
    spiritSnapshot.fiveSecRemaining = fiveSecRemaining
    spiritSnapshot.justActivated = justActivated
    spiritSnapshot.spiritVal = spiritVal
    spiritSnapshot.spiritMP5 = spiritMP5
    spiritSnapshot.spiritHP5 = spiritHP5
    spiritSnapshot.hasManaPool = hasManaPool
    spiritSnapshot.lastPopTime = state.lastPopTime

    return spiritSnapshot
end

function PlayerStatService.formatSpiritDisplay(key, cfg)
    local rState = PlayerStatService.getSpiritRegenState()
    cfg = cfg or {}
    local dispMode = cfg.spiritDisplayMode or (key == "spirit" and "FULL" or (key == "mana" and "FULL" or "REGEN_ONLY"))
    local isZh = (api.GetLocale and api.GetLocale() or "zhTW"):sub(1, 2) == "zh"
    local manaPrefix = isZh and "魔+" or "M+"
    local hpPrefix = isZh and "血+" or "H+"
    local manaSuppress = isZh and "魔0/" or "M0/"

    if key == "mana" then
        local curM = (api.UnitPower and api.UnitPower("player", 0)) or (_G.UnitPower and _G.UnitPower("player", 0)) or 0
        local maxM = (api.UnitPowerMax and api.UnitPowerMax("player", 0)) or (_G.UnitPowerMax and _G.UnitPowerMax("player", 0)) or 0
        if dispMode == "FULL" then
            if rState.isActive then
                return string.format("%d/%d (%s%d)", curM, maxM, manaPrefix, rState.spiritMP5 or 0)
            elseif rState.fiveSecRemaining > 0 then
                return string.format("%d/%d (%.1fs)", curM, maxM, rState.fiveSecRemaining)
            else
                return string.format("%d/%d", curM, maxM)
            end
        elseif dispMode == "REGEN_ONLY" then
            if rState.isActive then
                return string.format("%d (%s%d)", curM, manaPrefix, rState.spiritMP5 or 0)
            elseif rState.fiveSecRemaining > 0 then
                return string.format("%d (%.1fs)", curM, rState.fiveSecRemaining)
            else
                return tostring(curM)
            end
        else -- "STAT_ONLY"
            return tostring(curM)
        end
    end

    if dispMode == "FULL" then
        if rState.isActive then
            return string.format("%d (%s%d/%s%d)", rState.spiritVal, manaPrefix, rState.spiritMP5, hpPrefix, rState.spiritHP5)
        elseif rState.fiveSecRemaining > 0 then
            return string.format("%d (%.1fs|%s%d)", rState.spiritVal, rState.fiveSecRemaining, hpPrefix, rState.spiritHP5)
        else
            return string.format("%d (%s%d|%s%d)", rState.spiritVal, manaSuppress, rState.spiritMP5, hpPrefix, rState.spiritHP5)
        end
    elseif dispMode == "REGEN_ONLY" then
        if rState.isActive then
            return string.format("%s%d / %s%d", manaPrefix, rState.spiritMP5, hpPrefix, rState.spiritHP5)
        elseif rState.fiveSecRemaining > 0 then
            return string.format("%.1fs (%s%d) / %s%d", rState.fiveSecRemaining, manaPrefix, rState.spiritMP5, hpPrefix, rState.spiritHP5)
        else
            return string.format("%s%d / %s%d", manaSuppress, rState.spiritMP5, hpPrefix, rState.spiritHP5)
        end
    else -- "STAT_ONLY"
        if key == "spirit" then
            return tostring(rState.spiritVal)
        else
            return tostring(rState.spiritMP5) .. "/5s"
        end
    end
end

function PlayerStatService.getOrder()
    local _, classToken = PlayerStatService.getPlayerStatsConfig()
    local db = EAM.db
    local profileOrder = nil
    if classToken and db and db.profiles and db.profiles.classes and db.profiles.classes[classToken] then
        profileOrder = db.profiles.classes[classToken].playerStatsOrder
    end
    local rawOrder = profileOrder or (db and db.playerStatsOrder)
    local activeBaseKeys = (EAM.isForever and FOREVER_ORDERED_KEYS) or RETAIL_ORDERED_KEYS

    local function isAllowedKey(k)
        local def = STAT_DEFINITIONS[k]
        if not def then
            return false
        end
        if def.requiresForever and not EAM.isForever then
            return false
        end
        if def.requiresRetail and EAM.isForever then
            return false
        end
        return true
    end

    if type(rawOrder) == "table" and #rawOrder > 0 then
        local seen = {}
        local order = {}
        for _, k in ipairs(rawOrder) do
            if isAllowedKey(k) and not seen[k] then
                seen[k] = true
                order[#order + 1] = k
            end
        end
        for _, k in ipairs(activeBaseKeys) do
            if isAllowedKey(k) and not seen[k] then
                seen[k] = true
                order[#order + 1] = k
            end
        end
        return order
    end

    local copy = {}
    local seen = {}
    for _, k in ipairs(activeBaseKeys) do
        if isAllowedKey(k) and not seen[k] then
            seen[k] = true
            copy[#copy + 1] = k
        end
    end
    return copy
end

-- 儲存使用者自選屬性排列順序
function PlayerStatService.setOrder(newOrder)
    local _, classToken = PlayerStatService.getPlayerStatsConfig()
    local db = EAM.db
    if classToken and db and db.profiles and db.profiles.classes and db.profiles.classes[classToken] then
        db.profiles.classes[classToken].playerStatsOrder = newOrder
    elseif db then
        db.playerStatsOrder = newOrder
    end
    if PlayerStatService.update then
        PlayerStatService.update()
    end
end

-- 透過 FontString:SetFormattedText 進行 C-Level 零 GC 分配與 Secret Values 容錯渲染
local function renderStatValueText(fontString, val, rawVal, formatType, decimals, shortNumber, suffix)
    if not fontString then return end
    decimals = decimals or 1
    local escapedSuffix = (suffix and suffix ~= "") and suffix:gsub("%%", "%%%%") or ""
    local isSecret = shouldUnitStatsBeSecret("player")
        or (Util and Util.isSecretValue and (Util.isSecretValue(rawVal) or Util.isSecretValue(val)))
        or (issecretvalue and (issecretvalue(rawVal) or issecretvalue(val)))

    if isSecret then
        local targetVal = rawVal or val
        if isSafeNumber(rawVal) and rawVal == 0 and val then
            targetVal = val
        end
        if formatType == "percent" then
            local fmt = "%." .. decimals .. "f" .. escapedSuffix
            local ok = pcall(fontString.SetFormattedText, fontString, fmt, targetVal)
            if not ok then pcall(fontString.SetText, fontString, "0.0" .. (suffix or "")) end
        elseif formatType == "number" or formatType == "largeNumber" then
            if decimals == 0 then
                local ok = pcall(fontString.SetFormattedText, fontString, "%d", targetVal)
                if not ok then pcall(fontString.SetText, fontString, "0") end
            else
                local fmt = "%." .. decimals .. "f"
                local ok = pcall(fontString.SetFormattedText, fontString, fmt, targetVal)
                if not ok then pcall(fontString.SetText, fontString, "0") end
            end
        else
            local ok = pcall(fontString.SetFormattedText, fontString, "%s", targetVal)
            if not ok then pcall(fontString.SetText, fontString, "") end
        end
        return
    end

    local numVal = isSafeNumber(val) and val or (isSafeNumber(rawVal) and rawVal or nil)
    if not numVal then
        if formatType == "percent" then
            local ok = pcall(fontString.SetFormattedText, fontString, "%." .. decimals .. "f" .. escapedSuffix, 0)
            if not ok then pcall(fontString.SetText, fontString, "0.0" .. (suffix or "")) end
        else
            pcall(fontString.SetFormattedText, fontString, "%d", 0)
        end
        return
    end

    if numVal == 0 and (formatType == "number" or formatType == "largeNumber") then
        pcall(fontString.SetFormattedText, fontString, "%d", 0)
        return
    end

    if shortNumber and (formatType == "largeNumber" or (numVal >= 10000 and formatType ~= "percent")) then
        if numVal >= 1000000 then
            local fmt = "%." .. decimals .. "fM"
            local ok = pcall(fontString.SetFormattedText, fontString, fmt, numVal / 1000000)
            if ok then return end
        elseif numVal >= 1000 then
            local fmt = "%." .. decimals .. "fk"
            local ok = pcall(fontString.SetFormattedText, fontString, fmt, numVal / 1000)
            if ok then return end
        end
    end

    if formatType == "percent" then
        local fmt = "%." .. decimals .. "f" .. escapedSuffix
        local ok = pcall(fontString.SetFormattedText, fontString, fmt, numVal)
        if not ok then
            pcall(fontString.SetText, fontString, string.format("%." .. decimals .. "f", numVal) .. (suffix or ""))
        end
    elseif formatType == "number" or formatType == "largeNumber" then
        if decimals == 0 then
            local ok = pcall(fontString.SetFormattedText, fontString, "%d", math.floor(numVal + 0.5))
            if not ok then pcall(fontString.SetText, fontString, tostring(math.floor(numVal + 0.5))) end
        else
            local fmt = "%." .. decimals .. "f"
            local ok = pcall(fontString.SetFormattedText, fontString, fmt, numVal)
            if not ok then pcall(fontString.SetText, fontString, string.format(fmt, numVal)) end
        end
    else
        pcall(fontString.SetFormattedText, fontString, "%s", tostring(numVal))
    end
end
PlayerStatService.renderStatValueText = renderStatValueText

local function formatStatNumber(val, formatType, decimals, shortNumber, suffix)
    decimals = decimals or 1
    if not isSafeNumber(val) then
        if formatType == "percent" then
            return suffix and ("0.0" .. suffix) or "0.0"
        end
        return "0"
    end

    if val == 0 and (formatType == "number" or formatType == "largeNumber") then
        return "0"
    end

    if shortNumber and (formatType == "largeNumber" or (val >= 10000 and formatType ~= "percent")) then
        if val >= 1000000 then
            return string.format("%." .. decimals .. "fM", val / 1000000)
        elseif val >= 1000 then
            return string.format("%." .. decimals .. "fk", val / 1000)
        end
    end

    if formatType == "percent" then
        local str = string.format("%." .. decimals .. "f", val)
        return suffix and (str .. suffix) or str
    elseif formatType == "number" or formatType == "largeNumber" then
        if decimals == 0 then
            return string.format("%d", math.floor(val + 0.5))
        else
            return string.format("%." .. decimals .. "f", val)
        end
    end
    return tostring(val)
end
PlayerStatService.formatStatNumber = formatStatNumber

-- 角色屬性知識 Tooltip 計算與截圖機制校準
function PlayerStatService.getStatTooltipInfo(key)
    local def = STAT_DEFINITIONS[key]
    if not def then return nil end

    local label = (EAM.L and def.labelKey and EAM.L[def.labelKey]) or def.defaultLabel or key
    local val = PlayerStatService.getStatValue(key)
    local lines = {}
    local title = label

    if key == "strength" then
        title = string.format("%s: %d", label, math.floor(val + 0.5))
        local ap = math.floor(val * 2)
        local blk = math.max(1, math.floor(val / 20))
        lines[#lines + 1] = { text = string.format("• 提高近戰攻擊強度 %d 點 (每 1 點力量 = 2 AP)", ap), r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = string.format("• 提高盾牌格擋值 %d 點", blk), r = 0.9, g = 0.9, b = 0.9 }
    elseif key == "stamina" then
        title = string.format("%s: %d", label, math.floor(val + 0.5))
        local hp = math.floor(val * 10)
        lines[#lines + 1] = { text = string.format("• 提高生命力上限 %d 點 (每 1 點耐力 = 10 生命力)", hp), r = 0.9, g = 0.9, b = 0.9 }
    elseif key == "agility" then
        title = string.format("%s: %d", label, math.floor(val + 0.5))
        local armor = math.floor(val * 2)
        lines[#lines + 1] = { text = string.format("• 提高護甲值 %d 點 (每 1 點敏捷 = 2 護甲)", armor), r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 提高物理近戰與遠程致命一擊機率", r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 提高閃躲攻擊機率", r = 0.9, g = 0.9, b = 0.9 }
    elseif key == "intellect" then
        title = string.format("%s: %d", label, math.floor(val + 0.5))
        local mana = math.floor(val * 15)
        lines[#lines + 1] = { text = string.format("• 提高法力上限 %d 點", mana), r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 提高法術與神聖法術致命一擊機率", r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 【關鍵機制】提高武器技能/熟練度提升機率 (智力影響升熟練度速度)", r = 0.2, g = 0.9, b = 1.0 }
    elseif key == "spirit" then
        title = string.format("%s: %d", label, math.floor(val + 0.5))
        local rState = PlayerStatService.getSpiritRegenState()
        lines[#lines + 1] = { text = string.format("• 非戰鬥狀態下每 5 秒生命力恢復 (HP5): +%d", rState.spiritHP5 or 0), r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = string.format("• 未施法狀態下每 5 秒法力恢復 (MP5): +%d", rState.spiritMP5 or 0), r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 消耗法力後 5 秒內精神不提供法力恢復 (5秒規則 5SR)", r = 1.0, g = 0.82, b = 0.2 }
        lines[#lines + 1] = { text = "• 【關鍵機制】坐下或躺下時，生命力恢復速度提高 33%", r = 0.3, g = 1.0, b = 0.4 }
    elseif key == "attackPower" then
        title = string.format("%s: %d", label, math.floor(val + 0.5))
        local dps = val / 14.0
        lines[#lines + 1] = { text = string.format("• 近戰與遠程武器傷害每秒提高 %.1f 點", dps), r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 【核心換算】每擁有 14 點攻擊強度，每秒提高 1 點傷害 (14 AP = 1 DPS)", r = 0.2, g = 0.9, b = 1.0 }
        lines[#lines + 1] = { text = "• 攻擊強度受力量與敏捷屬性加成", r = 0.8, g = 0.8, b = 0.8 }
    elseif key == "crit" then
        title = string.format("%s: %.2f%%", label, val)
        lines[#lines + 1] = { text = "• 近戰與遠程致命依敏捷提高，法術致命依智力提高", r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 近戰與遠程致命造成傷害提高 100% (造成 200% 傷害)", r = 1.0, g = 0.82, b = 0.2 }
        lines[#lines + 1] = { text = "• 法術和治療致命效果提高 50% (造成 150% 效果)", r = 1.0, g = 0.82, b = 0.2 }
        lines[#lines + 1] = { text = "• 【永恆特色】多數週期性持續傷害/治療 (DoT/HoT) 可造成致命一擊", r = 0.2, g = 0.9, b = 1.0 }
    elseif key == "defenseSkill" then
        title = string.format("%s: %d", label, math.floor(val + 0.5))
        lines[#lines + 1] = { text = "• 提高閃躲、格擋與招架機率，降低被敵人命中與致命機率", r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 來自生物與怪物的致命一擊造成 200% 傷害", r = 1.0, g = 0.5, b = 0.3 }
        lines[#lines + 1] = { text = "• 【首領機制】高 3 級以上生物造成 150% 碾壓傷害 (Crushing Blow)", r = 1.0, g = 0.3, b = 0.3 }
        lines[#lines + 1] = { text = "• 【免暴臨界】防禦達 440 點時，團隊副本首領無法造成致命一擊 (-5.60% 致命機率)", r = 0.2, g = 1.0, b = 0.4 }
    elseif key == "dodge" then
        title = string.format("%s: %.2f%%", label, val)
        lines[#lines + 1] = { text = "• 完全閃避即將承受的物理近戰與遠程攻擊", r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 敏捷與防禦技能可持續提升閃躲機率", r = 0.8, g = 0.8, b = 0.8 }
        lines[#lines + 1] = { text = "• 【核心機制】對玩家來說只有來自正面的近戰攻擊可閃躲；對生物來說來自任何方向均可閃躲", r = 0.2, g = 0.9, b = 1.0 }
    elseif key == "parry" then
        title = string.format("%s: %.2f%%", label, val)
        lines[#lines + 1] = { text = "• 招架敵方正面近戰攻擊，完全偏斜該次傷害", r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 成功招架時可重置並加速下一次武器揮擊 (Parry Haste 招架提速)", r = 1.0, g = 0.82, b = 0.2 }
        lines[#lines + 1] = { text = "• 防禦技能與裝備招架等級可提升招架機率 (需裝備近戰武器)", r = 0.8, g = 0.8, b = 0.8 }
    elseif key == "block" then
        local blkVal = 0
        local getSB = api.GetShieldBlock or _G.GetShieldBlock
        if getSB then
            local ok, b = pcall(getSB)
            if ok and isSafeNumber(b) then blkVal = b end
        end
        title = string.format("%s: %.2f%%", label, val)
        lines[#lines + 1] = { text = "• 裝備盾牌時有機率格擋來自正面的物理攻擊", r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = string.format("• 盾牌格擋值: %d (每次格擋成功減免之物理傷害)", blkVal), r = 1.0, g = 0.82, b = 0.2 }
        lines[#lines + 1] = { text = "• 格擋值受力量與盾牌/裝備加成提高", r = 0.8, g = 0.8, b = 0.8 }
    elseif key == "armor" then
        title = string.format("%s: %d", label, math.floor(val + 0.5))
        lines[#lines + 1] = { text = "• 顯著減免承受之物理攻擊傷害", r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 敏捷可提升護甲值 (每 1 點敏捷 = 2 護甲)", r = 0.8, g = 0.8, b = 0.8 }
        lines[#lines + 1] = { text = "• 【免傷上限】來自護甲的傷害減免不能超過 75.00%", r = 1.0, g = 0.3, b = 0.3 }
    elseif key == "spiritManaRegen" then
        local rState = PlayerStatService.getSpiritRegenState()
        title = string.format("%s: %d/5s", label, rState.spiritMP5 or 0)
        lines[#lines + 1] = { text = string.format("• 未施法狀態下每 5 秒法力恢復 (MP5): +%d", rState.spiritMP5 or 0), r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = string.format("• 非戰鬥狀態下每 5 秒生命力恢復 (HP5): +%d", rState.spiritHP5 or 0), r = 0.9, g = 0.9, b = 0.9 }
        lines[#lines + 1] = { text = "• 消耗法力後 5 秒內精神不提供法力恢復 (5秒規則 5SR)", r = 1.0, g = 0.82, b = 0.2 }
        lines[#lines + 1] = { text = "• 坐下或躺下時，生命力恢復速度提高 33%", r = 0.3, g = 1.0, b = 0.4 }
    elseif key == "mana" then
        local curM = math.floor(val + 0.5)
        local maxM = 0
        local getPM = api.UnitPowerMax or _G.UnitPowerMax
        if getPM then
            local ok, m = pcall(getPM, "player", 0)
            if ok and isSafeNumber(m) then maxM = math.floor(m + 0.5) end
        end
        local pct = maxM > 0 and (curM / maxM * 100) or 100
        title = string.format("%s: %d / %d (%.1f%%)", label, curM, maxM, pct)
        local rState = PlayerStatService.getSpiritRegenState()
        if rState.hasManaPool then
            if rState.isActive then
                lines[#lines + 1] = { text = string.format("• 【5秒精神回魔作用中】MP5: +%d (精神全速恢復中)", rState.spiritMP5 or 0), r = 0.2, g = 1.0, b = 0.4 }
            elseif rState.fiveSecRemaining > 0 then
                lines[#lines + 1] = { text = string.format("• 【5秒規則等待中】剩餘 %.1f 秒進入精神全速回魔", rState.fiveSecRemaining), r = 1.0, g = 0.82, b = 0.2 }
            else
                lines[#lines + 1] = { text = "• 【5秒規則懲罰中】施法消耗法力後 5 秒內精神不回魔", r = 0.9, g = 0.5, b = 0.3 }
            end
            lines[#lines + 1] = { text = string.format("• 精神回魔能力 (MP5): %d / 5秒", rState.spiritMP5 or 0), r = 0.8, g = 0.8, b = 0.8 }
            lines[#lines + 1] = { text = "• 坐下或躺下時，生命力恢復速度提高 33%", r = 0.3, g = 1.0, b = 0.4 }
        else
            lines[#lines + 1] = { text = "• 當前職業或專精未啟用傳統法力池", r = 0.6, g = 0.6, b = 0.6 }
        end
    else
        title = string.format("%s: %s", label, tostring(val))
        lines[#lines + 1] = { text = string.format("當前數值: %s", tostring(val)), r = 0.9, g = 0.9, b = 0.9 }
    end

    return { title = title, lines = lines }
end

function PlayerStatService.showStatTooltip(anchorFrame, statKey)
    local info = PlayerStatService.getStatTooltipInfo(statKey)
    if not info or not _G.GameTooltip then return end
    local tooltip = _G.GameTooltip
    tooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")
    tooltip:ClearLines()
    tooltip:AddLine(info.title or statKey, 1.0, 0.82, 0.0)
    if info.lines then
        for _, line in ipairs(info.lines) do
            if type(line) == "table" then
                tooltip:AddLine(line.text or "", line.r or 1, line.g or 1, line.b or 1, true)
            else
                tooltip:AddLine(tostring(line), 1, 1, 1, true)
            end
        end
    end
    tooltip:Show()
end

function PlayerStatService.prewarmStats()
    for _, key in ipairs(ORDERED_KEYS) do
        local def = STAT_DEFINITIONS[key]
        if def and def.getValue then
            pcall(def.getValue)
        end
    end
end

function PlayerStatService.getStatValue(statKey)
    local def = STAT_DEFINITIONS[statKey]
    if def and def.getValue then
        local ok, val = pcall(def.getValue)
        if ok and isSafeNumber(val) and (val > 0 or (statKey == "totalAbsorb" or statKey == "healAbsorb" or statKey == "skyridingSpeed")) then
            PlayerStatService.lastKnownStats[statKey] = val
            return val
        end
    end
    return PlayerStatService.lastKnownStats[statKey] or 0
end

function PlayerStatService.getRawStatValue(statKey)
    local def = STAT_DEFINITIONS[statKey]
    if def then
        if def.getRawValue then
            local ok, val = pcall(def.getRawValue)
            if ok and val ~= nil then return val end
        elseif def.getValue then
            local ok, val = pcall(def.getValue)
            if ok and val ~= nil then return val end
        end
    end
    return 0
end

function PlayerStatService.getStatIcon(statKey, customIcon)
    if customIcon and customIcon ~= "" then
        return tonumber(customIcon) or customIcon
    end
    local def = STAT_DEFINITIONS[statKey]
    if not def then return 134400 end
    if statKey == "skyridingSpeed" then
        if C_Spell and C_Spell.GetSpellTexture then
            local spellTex = C_Spell.GetSpellTexture(376777) or C_Spell.GetSpellTexture(361584) or C_Spell.GetSpellTexture(372610)
            if spellTex then return spellTex end
        elseif GetSpellTexture then
            local spellTex = GetSpellTexture(376777) or GetSpellTexture(361584)
            if spellTex then return spellTex end
        end
        return def.defaultIcon or 4667307
    end
    return def.defaultIcon or 134400
end

local parentFrame = nil
local statItemFrames = {}

-- 解析依附目標框架 (Attach Target Resolver)
local function resolveAnchorTarget(attachTo)
    if not attachTo or attachTo == "EAM_ANCHOR" then
        return parentFrame or UIParent
    end
    if attachTo == "UIParent" or attachTo == "Screen" then
        return UIParent
    end
    if attachTo == "PlayerFrame" then
        return _G.PlayerFrame or UIParent
    end
    if attachTo == "TargetFrame" then
        return _G.TargetFrame or UIParent
    end
    if attachTo == "FocusFrame" then
        return _G.FocusFrame or UIParent
    end
    if attachTo == "PetFrame" then
        return _G.PetFrame or UIParent
    end
    if _G[attachTo] then
        return _G[attachTo]
    end
    return parentFrame or UIParent
end
PlayerStatService.resolveAnchorTarget = resolveAnchorTarget

-- 進度條自選顏色與雙色漸層渲染 (SetGradient API / Fallback)
local function applyStatusBarColor(bar, cfg, def)
    if not bar then return end
    local tex = bar:GetStatusBarTexture()
    local c1 = cfg.barColor
    local r1, g1, b1, a1
    if c1 and type(c1) == "table" then
        r1, g1, b1, a1 = c1[1] or 0.2, c1[2] or 0.8, c1[3] or 1.0, c1[4] or 0.95
    else
        -- 依類別設定預設 StatusBar 顏色
        if def.key == "totalAbsorb" then
            r1, g1, b1, a1 = 0.1, 0.75, 1.0, 0.95
        elseif def.key == "healAbsorb" then
            r1, g1, b1, a1 = 0.85, 0.25, 0.85, 0.95
        elseif def.category == "speed" then
            r1, g1, b1, a1 = 0.2, 0.9, 0.8, 0.95
        elseif def.category == "secondary" then
            r1, g1, b1, a1 = 1.0, 0.82, 0.15, 0.95
        elseif def.category == "tertiary" then
            r1, g1, b1, a1 = 0.3, 0.9, 0.4, 0.95
        elseif def.category == "primary" then
            r1, g1, b1, a1 = 1.0, 0.5, 0.1, 0.95
        else
            r1, g1, b1, a1 = 0.4, 0.6, 0.8, 0.95
        end
    end

    if cfg.enableGradient and cfg.barColor2 and tex then
        local c2 = cfg.barColor2
        local r2 = (type(c2) == "table" and c2[1]) or 0.1
        local g2 = (type(c2) == "table" and c2[2]) or 0.5
        local b2 = (type(c2) == "table" and c2[3]) or 0.9
        local a2 = (type(c2) == "table" and c2[4]) or 0.95
        local dir = cfg.barGradientDir or "HORIZONTAL"

        local applied = false
        local createColor = _G.CreateColor or (api and api.CreateColor)
        if tex.SetGradient and createColor then
            local ok, col1 = pcall(createColor, r1, g1, b1, a1)
            local ok2, col2 = pcall(createColor, r2, g2, b2, a2)
            if ok and ok2 and col1 and col2 then
                local gOk = pcall(tex.SetGradient, tex, dir, col1, col2)
                if gOk then applied = true end
            end
        end

        if not applied and tex.SetGradientAlpha then
            local gOk = pcall(tex.SetGradientAlpha, tex, dir, r1, g1, b1, a1, r2, g2, b2, a2)
            if gOk then applied = true end
        end

        if applied then
            bar:SetStatusBarColor(1, 1, 1, 1)
            return
        end
    end

    bar:SetStatusBarColor(r1, g1, b1, a1)
end
PlayerStatService.applyStatusBarColor = applyStatusBarColor

local function ensureParentFrame()
    if parentFrame then return parentFrame end
    if api.InCombatLockdown and api.InCombatLockdown() then return nil end

    local frame = api.CreateFrame("Frame", "EAM_AlertFrame_playerStat", UIParent)
    local size = 40
    frame:SetSize(size, size)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
    frame.frameName = "playerStat"

    -- 註冊至 Renderer 框架定位
    if EAM.db and EAM.db.layout and EAM.db.layout.frames and EAM.db.layout.frames.playerStat then
        local cfg = EAM.db.layout.frames.playerStat
        frame:ClearAllPoints()
        local target = resolveAnchorTarget(cfg.attachTo)
        if target == frame then target = UIParent end
        frame:SetPoint(cfg.point or "CENTER", target, cfg.attachPoint or cfg.point or "CENTER", cfg.x or 0, cfg.y or -220)
    end

    parentFrame = frame
    return frame
end
PlayerStatService.ensureParentFrame = ensureParentFrame

local function getOrCreateStatItemFrame(statKey)
    if statItemFrames[statKey] then
        return statItemFrames[statKey]
    end
    ensureParentFrame()

    local parent = parentFrame or UIParent
    local item = api.CreateFrame("Frame", "EAM_AlertFrame_playerStat_" .. tostring(statKey), parent, "BackdropTemplate")
    item:SetSize(40, 40)
    item:SetFrameStrata("MEDIUM")
    item.statKey = statKey

    local icon = item:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", item, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    item.icon = icon

    local statusBar = api.CreateFrame("StatusBar", nil, item)
    statusBar:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 2, 2)
    statusBar:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -2, 2)
    statusBar:SetHeight(5)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetStatusBarColor(0.2, 0.8, 1.0, 0.95)
    statusBar:SetMinMaxValues(0, 100)
    statusBar:Hide()
    item.statusBar = statusBar

    local valText = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("BOTTOM", item, "TOP", 0, 2)
    valText:SetTextColor(1, 1, 1, 1)
    item.valText = valText

    local labelText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("TOP", item, "BOTTOM", 0, -2)
    labelText:SetTextColor(1, 0.9, 0.5, 1)
    item.labelText = labelText

    item:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    item:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
    item:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)

    item:EnableMouse(true)
    item:SetScript("OnEnter", function(self)
        if not PlayerStatService.isMoving then
            PlayerStatService.showStatTooltip(self, self.statKey)
        end
    end)
    item:SetScript("OnLeave", function(self)
        if _G.GameTooltip then
            _G.GameTooltip:Hide()
        end
    end)

    statItemFrames[statKey] = item
    return item
end

function PlayerStatService.update()
    local mc = EAM.Modules and EAM.Modules.ModuleController
    if mc and type(mc.isEnabled) == "function" and not mc.isEnabled("playerStat") then
        if parentFrame then parentFrame:Hide() end
        for _, item in pairs(statItemFrames) do
            item:Hide()
        end
        return
    end

    if not parentFrame and not ensureParentFrame() then return end

    local db = EAM.db
    local statsConfig = PlayerStatService.getPlayerStatsConfig()
    local globalConfig = db and db.config or {}

    local activeList = {}
    local anyGrouped = false
    local orderedKeys = PlayerStatService.getOrder()
    for _, key in ipairs(orderedKeys) do
        local cfg = statsConfig[key]
        if cfg and cfg.enabled then
            local shouldShow = true
            if key == "skyridingSpeed" and cfg.glideOnlyIcon then
                if not isPlayerGliding() and not PlayerStatService.isMoving then
                    shouldShow = false
                end
            end
            if shouldShow then
                activeList[#activeList + 1] = {
                    key = key,
                    cfg = cfg,
                    def = STAT_DEFINITIONS[key],
                    val = PlayerStatService.getStatValue(key),
                    rawVal = PlayerStatService.getRawStatValue(key),
                }
                if not cfg.useCustomPos then
                    anyGrouped = true
                end
            end
        end
    end

    if #activeList == 0 then
        parentFrame:Hide()
        for _, item in pairs(statItemFrames) do
            item:Hide()
        end
        return
    end

    -- 處於拖曳移動模式時，只即時更新數值文字與進度條，不重設框架位置與拖曳外框
    if PlayerStatService.isMoving then
        for _, data in ipairs(activeList) do
            local item = statItemFrames[data.key]
            if item and item:IsShown() then
                if EAM.isForever and (data.key == "spirit" or data.key == "spiritManaRegen") and PlayerStatService.formatSpiritDisplay then
                    item.valText:SetText(PlayerStatService.formatSpiritDisplay(data.key, data.cfg))
                else
                    renderStatValueText(item.valText, data.val, data.rawVal, data.def.format, data.cfg.decimals, data.cfg.shortNumber, data.def.suffix)
                end
            end
        end
        return
    end

    if anyGrouped then
        parentFrame:Show()
    else
        parentFrame:Hide()
    end

    local growDir = (db and db.layout and db.layout.frames and db.layout.frames.playerStat and db.layout.frames.playerStat.growDirection) or 1
    local spacing = (db and db.layout and db.layout.spacing) or globalConfig.iconSpacing or 6

    local activeKeySet = {}
    for _, data in ipairs(activeList) do
        activeKeySet[data.key] = true
    end
    for k, item in pairs(statItemFrames) do
        if not activeKeySet[k] then
            item:Hide()
        end
    end

    local groupedIdx = 0
    local accumulatedOffset = 0
    local prevDimension = 0

    for idx, data in ipairs(activeList) do
        local cfg = data.cfg
        local def = data.def
        local val = data.val
        local rawVal = data.rawVal
        local item = getOrCreateStatItemFrame(data.key)
        item:Show()

        local size = cfg.iconSize or globalConfig.iconSize or 40
        local itemW = size
        local itemH = size

        -- 當取消圖示時（預設），依數值相對方位自適應框架尺寸
        if cfg.showIcon ~= true then
            if EAM.isForever and (data.key == "spirit" or data.key == "spiritManaRegen" or data.key == "mana") and (cfg.spiritDisplayMode == "FULL" or cfg.spiritDisplayMode == "REGEN_ONLY" or (cfg.spiritDisplayMode == nil and (data.key == "spirit" or data.key == "mana"))) then
                itemW = math.max(size * 2.8, 128)
                itemH = math.max(size * 0.9, 36)
            else
                local placement = cfg.valuePlacement or "TOP"
                if placement == "LEFT" or placement == "RIGHT" then
                    itemW = math.max(size * 1.8, 80)
                    itemH = math.max(size * 0.7, 24)
                else
                    itemW = math.max(size * 1.2, 56)
                    itemH = math.max(size * 0.9, 36)
                end
            end
        end
        item:SetSize(itemW, itemH)

        item:ClearAllPoints()
        if cfg.useCustomPos then
            local target = resolveAnchorTarget(cfg.attachTo)
            if target == parentFrame or target == item then
                item:SetParent(parentFrame or UIParent)
                target = parentFrame or UIParent
            else
                item:SetParent(UIParent)
            end
            local pt = cfg.point or "CENTER"
            local apt = cfg.attachPoint or pt
            local ox = cfg.offsetX or 0
            local oy = cfg.offsetY or 0
            item:SetPoint(pt, target, apt, ox, oy)
        else
            item:SetParent(parentFrame)
            groupedIdx = groupedIdx + 1
            local curDimension = (growDir == 1 or growDir == 2) and itemW or itemH
            if groupedIdx == 1 then
                accumulatedOffset = 0
            else
                accumulatedOffset = accumulatedOffset + (prevDimension / 2) + spacing + (curDimension / 2)
            end
            prevDimension = curDimension

            local dx, dy = 0, 0
            if growDir == 1 then
                dx = accumulatedOffset
            elseif growDir == 2 then
                dx = -accumulatedOffset
            elseif growDir == 3 then
                dy = accumulatedOffset
            elseif growDir == 4 then
                dy = -accumulatedOffset
            end
            item:SetPoint("CENTER", parentFrame, "CENTER", dx, dy)
        end

        -- 判斷是否顯示圖示與數值排版 (預設 showIcon 為 false)
        item.valText:ClearAllPoints()
        item.labelText:ClearAllPoints()

        if cfg.showIcon == true then
            local iconTex = PlayerStatService.getStatIcon(data.key, cfg.customIcon)
            item.icon:SetTexture(iconTex)
            item.icon:Show()
            item.valText:SetJustifyH("CENTER")
            item.labelText:SetJustifyH("CENTER")
            item.valText:SetPoint("BOTTOM", item, "TOP", 0, 2)
            item.labelText:SetPoint("TOP", item, "BOTTOM", 0, -2)
            if not PlayerStatService.isMoving then
                item:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
                item:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
            end
        else
            item.icon:Hide()
            if not PlayerStatService.isMoving then
                item:SetBackdropColor(0, 0, 0, 0)
                item:SetBackdropBorderColor(0, 0, 0, 0)
            end
            local placement = cfg.valuePlacement or "TOP"
            if placement == "BOTTOM" then
                item.valText:SetJustifyH("CENTER")
                item.labelText:SetJustifyH("CENTER")
                item.labelText:SetPoint("BOTTOM", item, "CENTER", 0, 1)
                item.valText:SetPoint("TOP", item, "CENTER", 0, -1)
            elseif placement == "LEFT" then
                item.valText:SetJustifyH("RIGHT")
                item.labelText:SetJustifyH("LEFT")
                item.valText:SetPoint("RIGHT", item, "CENTER", -2, 0)
                item.labelText:SetPoint("LEFT", item, "CENTER", 2, 0)
            elseif placement == "RIGHT" then
                item.labelText:SetJustifyH("RIGHT")
                item.valText:SetJustifyH("LEFT")
                item.labelText:SetPoint("RIGHT", item, "CENTER", -2, 0)
                item.valText:SetPoint("LEFT", item, "CENTER", 2, 0)
            else -- "TOP" default
                item.valText:SetJustifyH("CENTER")
                item.labelText:SetJustifyH("CENTER")
                item.valText:SetPoint("BOTTOM", item, "CENTER", 0, 1)
                item.labelText:SetPoint("TOP", item, "CENTER", 0, -1)
            end
        end

        -- 數值文字 (透過 FontString:SetFormattedText 進行 C-Level 零 GC 分配與 Secret Values 容錯渲染)
        local isSpiritSpecial = false
        if EAM.isForever and (data.key == "spirit" or data.key == "spiritManaRegen" or data.key == "mana") then
            isSpiritSpecial = true
            local rState = PlayerStatService.getSpiritRegenState()
            local text = PlayerStatService.formatSpiritDisplay(data.key, cfg)
            item.valText:SetText(text)

            -- Active 醒目提醒 (圖示邊框發光 / 文字放大高亮)
            local doActiveAlert = cfg.spiritActiveAlert ~= false
            local LBG = _G.LibStub and _G.LibStub("LibButtonGlow-1.0", true)
            if doActiveAlert then
                if cfg.showIcon == true then
                    if rState.isActive then
                        if LBG and LBG.ShowOverlayGlow then
                            LBG.ShowOverlayGlow(item)
                        end
                        if not PlayerStatService.isMoving then
                            item:SetBackdropBorderColor(0.20, 0.82, 1.00, 1.0)
                        end
                    else
                        if LBG and LBG.HideOverlayGlow then
                            LBG.HideOverlayGlow(item)
                        end
                        if not PlayerStatService.isMoving then
                            if rState.fiveSecRemaining > 0 then
                                item:SetBackdropBorderColor(0.85, 0.45, 0.15, 0.85)
                            else
                                item:SetBackdropBorderColor(0.30, 0.35, 0.45, 0.85)
                            end
                        end
                    end
                else
                    if LBG and LBG.HideOverlayGlow then
                        LBG.HideOverlayGlow(item)
                    end
                    local baseFont = cfg.fontSizeValue or 12
                    local now = (api.GetTime or _G.GetTime)()
                    if rState.isActive then
                        local scale = 1.32
                        if (now - rState.lastPopTime) < 0.35 then
                            scale = 1.45
                        end
                        local targetFont = math.floor(baseFont * scale + 0.5)
                        if EAM.UI.TextPlacement and EAM.UI.TextPlacement.applyFont then
                            EAM.UI.TextPlacement.applyFont(item.valText, targetFont, globalConfig)
                        end
                        item.valText:SetTextColor(0.25, 0.88, 1.00, 1.0)
                    else
                        if EAM.UI.TextPlacement and EAM.UI.TextPlacement.applyFont then
                            EAM.UI.TextPlacement.applyFont(item.valText, baseFont, globalConfig)
                        end
                        if rState.fiveSecRemaining > 0 then
                            item.valText:SetTextColor(0.95, 0.65, 0.25, 0.95)
                        else
                            item.valText:SetTextColor(0.60, 0.66, 0.74, 0.88)
                        end
                    end
                end
            else
                if LBG and LBG.HideOverlayGlow then
                    LBG.HideOverlayGlow(item)
                end
            end

            -- 全螢幕藍色邊框動畫
            if cfg.spiritBlueScreenFlash == true and rState.justActivated then
                local CF = EAM.UI and EAM.UI.CombatFlash
                if CF and CF.triggerSpiritActive then
                    CF.triggerSpiritActive()
                end
            end
        else
            renderStatValueText(item.valText, val, rawVal, def.format, cfg.decimals, cfg.shortNumber, def.suffix)
        end
        if not isSpiritSpecial and cfg.fontSizeValue then
            if EAM.UI.TextPlacement and EAM.UI.TextPlacement.applyFont then
                EAM.UI.TextPlacement.applyFont(item.valText, cfg.fontSizeValue, globalConfig)
            end
        end
        if not isSpiritSpecial then
            if cfg.valueColor then
                item.valText:SetTextColor(cfg.valueColor[1] or 1, cfg.valueColor[2] or 1, cfg.valueColor[3] or 1, cfg.valueColor[4] or 1)
            else
                item.valText:SetTextColor(1, 1, 1, 1)
            end
        elseif cfg.showIcon == true then
            if cfg.valueColor then
                item.valText:SetTextColor(cfg.valueColor[1] or 1, cfg.valueColor[2] or 1, cfg.valueColor[3] or 1, cfg.valueColor[4] or 1)
            else
                local rState = PlayerStatService.getSpiritRegenState()
                if (cfg.spiritActiveAlert ~= false) and rState.isActive then
                    item.valText:SetTextColor(0.25, 0.88, 1.00, 1.0)
                elseif (cfg.spiritActiveAlert ~= false) and rState.fiveSecRemaining > 0 then
                    item.valText:SetTextColor(0.95, 0.65, 0.25, 0.95)
                else
                    item.valText:SetTextColor(1, 1, 1, 1)
                end
            end
        end

        -- 名稱標籤
        local labelStr = cfg.customLabel
        if not labelStr or labelStr == "" then
            labelStr = (EAM.L and def.labelKey and EAM.L[def.labelKey]) or def.defaultLabel
        end
        item.labelText:SetText(labelStr)
        if cfg.fontSizeLabel then
            if EAM.UI.TextPlacement and EAM.UI.TextPlacement.applyFont then
                EAM.UI.TextPlacement.applyFont(item.labelText, cfg.fontSizeLabel, globalConfig)
            end
        end
        if cfg.labelColor then
            item.labelText:SetTextColor(cfg.labelColor[1] or 1, cfg.labelColor[2] or 0.9, cfg.labelColor[3] or 0.5, cfg.labelColor[4] or 1)
        else
            item.labelText:SetTextColor(1, 0.9, 0.5, 1)
        end

        -- StatusBar 進度條自選顏色與雙色漸層渲染 (當為 Secret 數值或開啟進度條時)
        local isSecret = shouldUnitStatsBeSecret("player")
            or (Util and Util.isSecretValue and Util.isSecretValue(rawVal))
            or (issecretvalue and issecretvalue(rawVal))
        if cfg.showStatusBar ~= false or isSecret then
            item.statusBar:SetHeight(math.max(3, math.floor(itemH * 0.15)))
            item.statusBar:ClearAllPoints()
            if cfg.showIcon == true then
                item.statusBar:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 2, 2)
                item.statusBar:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -2, 2)
            else
                item.statusBar:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 4, 1)
                item.statusBar:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -4, 1)
            end

            local maxVal = 100
            if def.format == "percent" then
                maxVal = 100
            elseif data.key == "totalAbsorb" or data.key == "healAbsorb" then
                local ok, hm = pcall(UnitHealthMax, "player")
                maxVal = (ok and isSafeNumber(hm) and hm > 0) and hm or 100000
            elseif data.key == "mana" then
                local getPM = api.UnitPowerMax or _G.UnitPowerMax
                if getPM then
                    local ok, m = pcall(getPM, "player", 0)
                    if ok and isSafeNumber(m) and m > 0 then maxVal = m end
                end
            elseif def.category == "primary" then
                maxVal = 50000
            elseif data.key == "armor" then
                maxVal = 30000
            end

            applyStatusBarColor(item.statusBar, cfg, def)

            -- 5 秒精神回魔專屬 StatusBar 顏色覆蓋 (mana, spirit, spiritManaRegen)
            if EAM.isForever and (data.key == "mana" or data.key == "spirit" or data.key == "spiritManaRegen") then
                local rState = PlayerStatService.getSpiritRegenState()
                if rState.hasManaPool then
                    if rState.isActive then
                        -- 耀眼冰晶藍 (0.20, 0.85, 1.00, 1.00)
                        item.statusBar:SetStatusBarColor(0.20, 0.85, 1.00, 1.00)
                    elseif rState.fiveSecRemaining > 0 then
                        -- 5 秒懲罰期間變暗/琥珀色 (0.85, 0.45, 0.15, 0.95)
                        item.statusBar:SetStatusBarColor(0.85, 0.45, 0.15, 0.95)
                    else
                        item.statusBar:SetStatusBarColor(0.15, 0.50, 0.90, 0.95)
                    end
                end
            end

            pcall(item.statusBar.SetMinMaxValues, item.statusBar, 0, maxVal)
            pcall(item.statusBar.SetValue, item.statusBar, rawVal)
            item.statusBar:Show()
        else
            item.statusBar:Hide()
        end

        -- 閾值警戒高亮
        local isAlert = false
        if isSafeNumber(val) then
            if cfg.thresholdMin and isSafeNumber(cfg.thresholdMin) and val < cfg.thresholdMin then
                isAlert = true
            elseif cfg.thresholdMax and isSafeNumber(cfg.thresholdMax) and val > cfg.thresholdMax then
                isAlert = true
            end
        end

        if isAlert then
            if cfg.showIcon == true then
                item:SetBackdropBorderColor(1.0, 0.3, 0.3, 1.0)
            end
            item.valText:SetTextColor(1.0, 0.3, 0.3, 1.0)
        else
            local isSpiritManagedBorder = isSpiritSpecial and (cfg.spiritActiveAlert ~= false) and (cfg.showIcon == true)
            if not isSpiritManagedBorder then
                if cfg.showIcon == true and not PlayerStatService.isMoving then
                    item:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
                end
            end
        end

        item:Show()
    end

    -- 檢查全螢幕藍色常駐泛光 (Spirit Continuous Blue Glow)
    if EAM.isForever then
        local anyBlueGlowEnabled = false
        local statsCfg = PlayerStatService.getPlayerStatsConfig()
        if statsCfg then
            local checkKeys = { "mana", "spirit", "spiritManaRegen" }
            for _, k in ipairs(checkKeys) do
                local c = statsCfg[k]
                if c and c.enabled ~= false and c.spiritBlueScreenGlow == true then
                    anyBlueGlowEnabled = true
                    break
                end
            end
        end

        local CF = EAM.UI and EAM.UI.CombatFlash
        if CF and CF.setSpiritActiveGlow then
            if anyBlueGlowEnabled then
                local rState = PlayerStatService.getSpiritRegenState()
                CF.setSpiritActiveGlow(rState.isActive == true)
            else
                CF.setSpiritActiveGlow(false)
            end
        end
    end
end

-- 屬性框架特定/全部移動模式控制（主錨點拖曳連動所有非獨立屬性）
function PlayerStatService.setActiveAnchors(enable, targetKey)
    if inCombat() then return false, "combatDeferred" end
    PlayerStatService.isMoving = enable

    if enable then
        ensureParentFrame()
        local statsConfig = PlayerStatService.getPlayerStatsConfig()

        -- 當移動全部或主錨點時，亮起 parentFrame 主錨點供使用者直接拖曳
        if (targetKey == "all" or targetKey == nil or targetKey == "playerStat") and parentFrame then
            parentFrame:Show()
            parentFrame:SetSize(160, 42)
            parentFrame:SetMovable(true)
            parentFrame:EnableMouse(true)
            parentFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            parentFrame:SetClampedToScreen(true)
            parentFrame:RegisterForDrag("LeftButton")

            if not parentFrame.moverHUD then
                local hud = api.CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
                hud:SetSize(160, 42)
                hud:SetPoint("CENTER", parentFrame, "CENTER", 0, 0)
                hud:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 }
                })
                hud:SetBackdropColor(0.02, 0.28, 0.12, 0.55)
                hud:SetBackdropBorderColor(0.20, 1.00, 0.45, 0.95)

                local title = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                title:SetPoint("TOP", hud, "TOP", 0, -4)
                title:SetTextColor(0.3, 1.0, 0.5, 1.0)
                title:SetText("★ 角色屬性主錨點")

                local sub = hud:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                sub:SetPoint("BOTTOM", hud, "BOTTOM", 0, 4)
                sub:SetTextColor(0.8, 0.9, 0.8, 0.9)
                sub:SetText("[左鍵拖曳 / 右鍵完成]")

                parentFrame.moverHUD = hud
            end
            parentFrame.moverHUD:Show()

            parentFrame:SetScript("OnDragStart", parentFrame.StartMoving)
            parentFrame:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local point, _, _, x, y = self:GetPoint()
                local db = EAM.db
                if db and db.layout and db.layout.frames then
                    db.layout.frames.playerStat = db.layout.frames.playerStat or {}
                    db.layout.frames.playerStat.point = point or "CENTER"
                    db.layout.frames.playerStat.x = x or 0
                    db.layout.frames.playerStat.y = y or -220
                end
                print("|cff00ff96EAM|r " .. string.format((EAM.L and EAM.L.EAM_STAT_MAIN_ANCHOR_SAVED) or "角色屬性主錨點已儲存: X: %.1f, Y: %.1f", x or 0, y or -220))
            end)
            parentFrame:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and PlayerStatService.isMoving then
                    PlayerStatService.setActiveAnchors(false)
                    print("|cff00ff96EAM|r " .. ((EAM.L and EAM.L.EAM_MOVE_MODE_OFF) or "已關閉移動模式。"))
                end
            end)
        end

        for k, item in pairs(statItemFrames) do
            local cfg = statsConfig[k] or {}
            local def = STAT_DEFINITIONS[k]
            -- 獨立單項拖曳或全選中獨立位置的屬性
            if ((targetKey == k) or (targetKey == "all" and cfg.useCustomPos)) and cfg.enabled then
                item:Show()
                item:SetMovable(true)
                item:EnableMouse(true)
                item:SetFrameStrata("FULLSCREEN_DIALOG")
                item:SetClampedToScreen(true)
                item:RegisterForDrag("LeftButton")
                item:SetScript("OnDragStart", item.StartMoving)
                item:SetScript("OnDragStop", function(self)
                    self:StopMovingOrSizing()
                    local point, _, _, x, y = self:GetPoint()
                    cfg.useCustomPos = true
                    cfg.point = point or "CENTER"
                    cfg.offsetX = x or 0
                    cfg.offsetY = y or 0
                    if EAM.UI.PlayerStatPanel and EAM.UI.PlayerStatPanel.syncSliders then
                        EAM.UI.PlayerStatPanel.syncSliders(k, x, y)
                    end
                    local fLabel = (EAM.L and def and def.labelKey and EAM.L[def.labelKey]) or (def and def.defaultLabel) or k
                    print("|cff00ff96EAM|r " .. string.format((EAM.L and EAM.L.EAM_STAT_POS_SAVED) or "[%s] 獨立位置已儲存: X: %.1f, Y: %.1f", fLabel, x or 0, y or 0))
                end)
                if not item.dragHint then
                    local hint = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    hint:SetPoint("TOP", item, "BOTTOM", 0, -6)
                    hint:SetTextColor(0.4, 0.9, 1.0, 1.0)
                    item.dragHint = hint
                end
                local labelStr = (EAM.L and def and def.labelKey and EAM.L[def.labelKey]) or (def and def.defaultLabel) or k
                item.dragHint:SetText(labelStr .. " (拖曳)")
                item.dragHint:Show()
                item:SetBackdropColor(0.2, 0.35, 0.5, 0.9)
                item:SetBackdropBorderColor(0.4, 0.8, 1.0, 1)
            end
        end
    else
        if parentFrame then
            parentFrame:SetMovable(false)
            parentFrame:EnableMouse(false)
            parentFrame:SetFrameStrata("MEDIUM")
            if parentFrame.moverHUD then parentFrame.moverHUD:Hide() end
        end
        for _, item in pairs(statItemFrames) do
            item:SetMovable(false)
            item:EnableMouse(true)
            item:SetFrameStrata("MEDIUM")
            if item.dragHint then item.dragHint:Hide() end
        end
        PlayerStatService.update()
    end
    return true
end

-- 模組生命週期即時開關回呼 (ModuleController Toggle Hook)
function PlayerStatService.onModuleToggle(enabled, reason)
    if enabled == false then
        if parentFrame then
            parentFrame:Hide()
        end
        for _, item in pairs(statItemFrames) do
            item:Hide()
        end
        if PlayerStatService.isMoving then
            PlayerStatService.setActiveAnchors(false)
        end
        local CF = EAM.UI and EAM.UI.CombatFlash
        if CF and CF.setSpiritActiveGlow then
            CF.setSpiritActiveGlow(false)
        end
    else
        PlayerStatService.update()
    end
end

-- 定期更新計時器 (每 0.1 秒刷新一次，保障移動速度等即時數值流暢呈現)
local tickerFrame = nil
local function initTicker()
    if tickerFrame then return end
    tickerFrame = api.CreateFrame("Frame")
    local elapsed = 0
    tickerFrame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            elapsed = 0
            PlayerStatService.update()
        end
    end)
end

function PlayerStatService.initialize()
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and type(router.register) == "function" then
        local onEvent = function()
            PlayerStatService.update()
        end
        local onPrewarmEvent = function()
            PlayerStatService.prewarmStats()
            PlayerStatService.update()
        end
        router.register("UNIT_STATS", onEvent)
        router.register("UNIT_AURA", onEvent)
        router.register("UNIT_ABSORB_AMOUNT_CHANGED", onEvent)
        router.register("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", onEvent)
        router.register("UNIT_HEALTH", onEvent)
        router.register("UNIT_MAXHEALTH", onEvent)
        router.register("COMBAT_RATING_UPDATE", onEvent)
        router.register("SPEED_UPDATE", onEvent)
        router.register("UNIT_RESISTANCES", onEvent)
        router.register("UNIT_ATTACK_POWER", onEvent)
        router.register("UNIT_RANGED_ATTACK_POWER", onEvent)
        router.register("SKILL_LINES_CHANGED", onPrewarmEvent)
        if EAM.isForever then
            router.register("UNIT_SPELLCAST_SUCCEEDED", function(event, unit, castGUID, spellID)
                if unit == "player" and spellID then
                    PlayerStatService.onPlayerSpellCastSucceeded(spellID)
                end
            end)
            router.register("UNIT_POWER_FREQUENT", function(event, unit, powerToken)
                if unit == "player" and (powerToken == nil or powerToken == "MANA") then
                    PlayerStatService.onPlayerPowerUpdate()
                end
            end)
            router.register("UNIT_POWER_UPDATE", function(event, unit, powerToken)
                if unit == "player" and (powerToken == nil or powerToken == "MANA") then
                    PlayerStatService.onPlayerPowerUpdate()
                end
            end)
        end
        router.register("PLAYER_SPECIALIZATION_CHANGED", onPrewarmEvent)
        router.register("PLAYER_ENTERING_WORLD", onPrewarmEvent)
        router.register("PLAYER_LOGIN", onPrewarmEvent)
        router.register("PLAYER_REGEN_ENABLED", onPrewarmEvent)
        router.register("PLAYER_REGEN_DISABLED", onEvent)
        router.register("PLAYER_EQUIPMENT_CHANGED", onPrewarmEvent)
        router.register("TRAIT_CONFIG_UPDATED", onPrewarmEvent)
        router.register("ACTIVE_TALENT_GROUP_CHANGED", onPrewarmEvent)
        router.register("SPELLS_CHANGED", onPrewarmEvent)
        router.register("PLAYER_MOUNT_DISPLAY_CHANGED", onEvent)
    end
    PlayerStatService.prewarmStats()
    initTicker()
end

PlayerStatService.init = PlayerStatService.initialize
PlayerStatService.updateDisplay = PlayerStatService.update

-- 載入時立即啟動計時器與事件監聽防護
pcall(PlayerStatService.initialize)

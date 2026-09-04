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
            return UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("player") or 0
        end,
        getValue = function()
            local total = 0
            if UnitGetTotalAbsorbs then
                local ok, val = pcall(UnitGetTotalAbsorbs, "player")
                if ok and isSafeNumber(val) and val > 0 then
                    total = val
                end
            end
            if total <= 0 and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                local i = 1
                while true do
                    local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
                    if not aura then break end
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
            return UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs("player") or 0
        end,
        getValue = function()
            local total = 0
            if UnitGetTotalHealAbsorbs then
                local ok, val = pcall(UnitGetTotalHealAbsorbs, "player")
                if ok and isSafeNumber(val) and val > 0 then
                    total = val
                end
            end
            if total <= 0 and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                local i = 1
                while true do
                    local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HARMFUL")
                    if not aura then break end
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
}
PlayerStatService.DEFINITIONS = STAT_DEFINITIONS

local ORDERED_KEYS = {
    "strength", "agility", "stamina", "intellect",
    "crit", "haste", "mastery", "versatility",
    "avoidance", "leech", "speedRating",
    "runSpeed", "swimSpeed", "flightSpeed", "skyridingSpeed",
    "totalAbsorb", "healAbsorb", "armor"
}
PlayerStatService.ORDERED_KEYS = ORDERED_KEYS

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
        frame:SetPoint(cfg.point or "CENTER", UIParent, cfg.point or "CENTER", cfg.x or 0, cfg.y or -220)
    end

    parentFrame = frame
    return frame
end

local function getOrCreateStatItemFrame(statKey)
    if statItemFrames[statKey] then
        return statItemFrames[statKey]
    end

    local item = api.CreateFrame("Frame", "EAM_AlertFrame_playerStat_" .. tostring(statKey), UIParent, "BackdropTemplate")
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

    statItemFrames[statKey] = item
    return item
end

function PlayerStatService.update()
    if not parentFrame and not ensureParentFrame() then return end

    local db = EAM.db
    local statsConfig = PlayerStatService.getPlayerStatsConfig()
    local globalConfig = db and db.config or {}

    local activeList = {}
    local anyGrouped = false
    for _, key in ipairs(ORDERED_KEYS) do
        local cfg = statsConfig[key]
        if cfg and cfg.enabled then
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
                renderStatValueText(item.valText, data.val, data.rawVal, data.def.format, data.cfg.decimals, data.cfg.shortNumber, data.def.suffix)
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

        -- 當取消圖示時，依數值相對方位自適應框架尺寸
        if cfg.showIcon == false then
            local placement = cfg.valuePlacement or "TOP"
            if placement == "LEFT" or placement == "RIGHT" then
                itemW = math.max(size * 1.8, 80)
                itemH = math.max(size * 0.7, 24)
            else
                itemW = math.max(size * 1.2, 56)
                itemH = math.max(size * 0.9, 36)
            end
        end
        item:SetSize(itemW, itemH)

        item:ClearAllPoints()
        if cfg.useCustomPos then
            local pt = cfg.point or "CENTER"
            local ox = cfg.offsetX or 0
            local oy = cfg.offsetY or 0
            item:SetPoint(pt, UIParent, pt, ox, oy)
        else
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

        -- 判斷是否顯示圖示與數值排版
        item.valText:ClearAllPoints()
        item.labelText:ClearAllPoints()

        if cfg.showIcon ~= false then
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
        renderStatValueText(item.valText, val, rawVal, def.format, cfg.decimals, cfg.shortNumber, def.suffix)
        if cfg.fontSizeValue then
            if EAM.UI.TextPlacement and EAM.UI.TextPlacement.applyFont then
                EAM.UI.TextPlacement.applyFont(item.valText, cfg.fontSizeValue, globalConfig)
            end
        end
        if cfg.valueColor then
            item.valText:SetTextColor(cfg.valueColor[1] or 1, cfg.valueColor[2] or 1, cfg.valueColor[3] or 1, cfg.valueColor[4] or 1)
        else
            item.valText:SetTextColor(1, 1, 1, 1)
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

        -- StatusBar 進度條原生 Sink 支援 (當為 Secret 數值或開啟進度條時)
        local isSecret = shouldUnitStatsBeSecret("player")
            or (Util and Util.isSecretValue and Util.isSecretValue(rawVal))
            or (issecretvalue and issecretvalue(rawVal))
        if cfg.showStatusBar ~= false or isSecret then
            item.statusBar:SetHeight(math.max(3, math.floor(itemH * 0.15)))
            item.statusBar:ClearAllPoints()
            if cfg.showIcon ~= false then
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
            elseif def.category == "primary" then
                maxVal = 50000
            elseif data.key == "armor" then
                maxVal = 30000
            end

            -- 依類別設定 StatusBar 顏色
            if data.key == "totalAbsorb" then
                item.statusBar:SetStatusBarColor(0.1, 0.75, 1.0, 0.95)
            elseif data.key == "healAbsorb" then
                item.statusBar:SetStatusBarColor(0.85, 0.25, 0.85, 0.95)
            elseif def.category == "speed" then
                item.statusBar:SetStatusBarColor(0.2, 0.9, 0.8, 0.95)
            elseif def.category == "secondary" then
                item.statusBar:SetStatusBarColor(1.0, 0.82, 0.15, 0.95)
            elseif def.category == "tertiary" then
                item.statusBar:SetStatusBarColor(0.3, 0.9, 0.4, 0.95)
            elseif def.category == "primary" then
                item.statusBar:SetStatusBarColor(1.0, 0.5, 0.1, 0.95)
            else
                item.statusBar:SetStatusBarColor(0.4, 0.6, 0.8, 0.95)
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
            if cfg.showIcon ~= false then
                item:SetBackdropBorderColor(1.0, 0.3, 0.3, 1.0)
            end
            item.valText:SetTextColor(1.0, 0.3, 0.3, 1.0)
        else
            if cfg.showIcon ~= false and not PlayerStatService.isMoving then
                item:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
            end
        end

        item:Show()
    end
end

-- 屬性框架特定/全部移動模式控制
function PlayerStatService.setActiveAnchors(enable, targetKey)
    if inCombat() then return false, "combatDeferred" end
    PlayerStatService.isMoving = enable

    if enable then
        local statsConfig = PlayerStatService.getPlayerStatsConfig()
        for k, item in pairs(statItemFrames) do
            local cfg = statsConfig[k] or {}
            local def = STAT_DEFINITIONS[k]
            if (targetKey == "all" or targetKey == nil or targetKey == "playerStat" or targetKey == k) and cfg.enabled then
                item:Show()
                item:SetMovable(true)
                item:EnableMouse(true)
                item:SetFrameStrata("HIGH")
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
        for _, item in pairs(statItemFrames) do
            item:SetMovable(false)
            item:EnableMouse(false)
            if item.dragHint then item.dragHint:Hide() end
        end
        PlayerStatService.update()
    end
    return true
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

-- 載入時立即啟動計時器與事件監聽防護
pcall(PlayerStatService.initialize)

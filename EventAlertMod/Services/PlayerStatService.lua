--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/PlayerStatService
檔案: Services\PlayerStatService.lua

理念:
- 負責玩家主屬性、副屬性、移動速度、飛行速度與傷害/治療吸收護盾的資料採樣與狀態發布。
- 採用安全 API 讀取，不執行私有字串化或受保護資料讀回。

責任:
- 監聽屬性、光環與吸收量相關事件。
- 支援 16 種核心屬性取值、單位格式化、小數點處理與閾值判定。
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
    frames = {},
    active = false,
    sampleThrottle = 0.1,
    lastSampleTime = 0,
}
EAM.Services.PlayerStatService = PlayerStatService

local function isSafeNumber(val)
    if val == nil then return false end
    if Util and Util.isSecretValue and Util.isSecretValue(val) then return false end
    if Util and Util.isSafeNumber then return Util.isSafeNumber(val) end
    if type(val) ~= "number" then return false end
    return val == val and val ~= math.huge and val ~= -math.huge
end

PlayerStatService.isSafeNumber = isSafeNumber

-- 16 大支援屬性定義清單
local STAT_DEFINITIONS = {
    -- 主屬性
    strength = {
        key = "strength",
        labelKey = "EAM_STAT_STRENGTH",
        defaultLabel = "力量",
        defaultIcon = 136085, -- Spell_Nature_Strength
        category = "primary",
        getValue = function()
            if not UnitStat then return 0 end
            local ok, stat, effectiveStat = pcall(UnitStat, "player", 1)
            if not ok then return 0 end
            local val = effectiveStat or stat
            if not isSafeNumber(val) then return 0 end
            return val
        end,
        format = "number",
    },
    agility = {
        key = "agility",
        labelKey = "EAM_STAT_AGILITY",
        defaultLabel = "敏捷",
        defaultIcon = 132212, -- Ability_Agility
        category = "primary",
        getValue = function()
            if not UnitStat then return 0 end
            local ok, stat, effectiveStat = pcall(UnitStat, "player", 2)
            if not ok then return 0 end
            local val = effectiveStat or stat
            if not isSafeNumber(val) then return 0 end
            return val
        end,
        format = "number",
    },
    stamina = {
        key = "stamina",
        labelKey = "EAM_STAT_STAMINA",
        defaultLabel = "耐力",
        defaultIcon = 136109, -- Spell_Nature_UnyeildingStamina
        category = "primary",
        getValue = function()
            if not UnitStat then return 0 end
            local ok, stat, effectiveStat = pcall(UnitStat, "player", 3)
            if not ok then return 0 end
            local val = effectiveStat or stat
            if not isSafeNumber(val) then return 0 end
            return val
        end,
        format = "number",
    },
    intellect = {
        key = "intellect",
        labelKey = "EAM_STAT_INTELLECT",
        defaultLabel = "智力",
        defaultIcon = 135932, -- Spell_Holy_MagicalSentry
        category = "primary",
        getValue = function()
            if not UnitStat then return 0 end
            local ok, stat, effectiveStat = pcall(UnitStat, "player", 4)
            if not ok then return 0 end
            local val = effectiveStat or stat
            if not isSafeNumber(val) then return 0 end
            return val
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
        getValue = function()
            if not GetCritChance then return 0 end
            local ok, val = pcall(GetCritChance)
            if not ok or not isSafeNumber(val) then return 0 end
            return val
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
        getValue = function()
            local fn = GetHaste or UnitSpellHaste
            if not fn then return 0 end
            local ok, val = pcall(fn, "player")
            if not ok or not isSafeNumber(val) then return 0 end
            return val
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
        getValue = function()
            if not GetMasteryEffect then return 0 end
            local ok, val = pcall(GetMasteryEffect)
            if not ok or not isSafeNumber(val) then return 0 end
            return val
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
        getValue = function()
            local cr = _G.CR_VERSATILITY_DAMAGE_DONE or 29
            local bonus, vers = 0, 0
            if GetCombatRatingBonus then
                local ok, b = pcall(GetCombatRatingBonus, cr)
                if ok and isSafeNumber(b) then bonus = b end
            end
            if GetVersatilityBonus then
                local ok, v = pcall(GetVersatilityBonus, cr)
                if ok and isSafeNumber(v) then vers = v end
            end
            return bonus + vers
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
        getValue = function()
            if not GetAvoidance then return 0 end
            local ok, val = pcall(GetAvoidance)
            if not ok or not isSafeNumber(val) then return 0 end
            return val
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
        getValue = function()
            if not GetLifesteal then return 0 end
            local ok, val = pcall(GetLifesteal)
            if not ok or not isSafeNumber(val) then return 0 end
            return val
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
        getValue = function()
            if not GetSpeed then return 0 end
            local ok, val = pcall(GetSpeed)
            if not ok or not isSafeNumber(val) then return 0 end
            return val
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
        getValue = function()
            if not GetUnitSpeed then return 100 end
            local ok, currentSpeed, runSpeed = pcall(GetUnitSpeed, "player")
            if not ok then return 100 end
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
            return (speed / 7.0) * 100
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
        getValue = function()
            if not GetUnitSpeed then return 67 end
            local ok, currentSpeed, _, _, swimSpeed = pcall(GetUnitSpeed, "player")
            if not ok then return 67 end
            local isSwimming = IsSwimming and IsSwimming()
            local speed = (isSwimming and currentSpeed and isSafeNumber(currentSpeed) and currentSpeed > 0) and currentSpeed or swimSpeed
            if not isSafeNumber(speed) or speed <= 0 then
                speed = (swimSpeed and isSafeNumber(swimSpeed) and swimSpeed > 0) and swimSpeed or 4.7
            end
            return (speed / 7.0) * 100
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
        getValue = function()
            if not GetUnitSpeed then return 100 end
            local ok, currentSpeed, _, flightSpeed = pcall(GetUnitSpeed, "player")
            if not ok then return 100 end
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
            return (speed / 7.0) * 100
        end,
        format = "percent",
        suffix = "%",
    },
    skyridingSpeed = {
        key = "skyridingSpeed",
        labelKey = "EAM_STAT_SKYRIDING_SPEED",
        defaultLabel = "飛龍模式飛速",
        defaultIcon = 4661640, -- inv_dragonriding_glyph
        category = "speed",
        getValue = function()
            if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
                local ok, isGliding, canGlide, forwardSpeed = pcall(C_PlayerInfo.GetGlidingInfo)
                if ok and isGliding and isSafeNumber(forwardSpeed) and forwardSpeed > 0 then
                    return (forwardSpeed / 7.0) * 100
                end
            end
            if not GetUnitSpeed then return 0 end
            local ok, currentSpeed, _, flightSpeed = pcall(GetUnitSpeed, "player")
            if not ok then return 0 end
            local isFlying = IsFlying and IsFlying()
            local speed = (isFlying and currentSpeed and isSafeNumber(currentSpeed) and currentSpeed > 0) and currentSpeed or flightSpeed
            if not isSafeNumber(speed) or speed <= 0 then
                speed = 0
            end
            return (speed / 7.0) * 100
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
            if not UnitGetTotalAbsorbs then return 0 end
            local ok, val = pcall(UnitGetTotalAbsorbs, "player")
            if not ok or not isSafeNumber(val) then return 0 end
            return val
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
            if not UnitGetTotalHealAbsorbs then return 0 end
            local ok, val = pcall(UnitGetTotalHealAbsorbs, "player")
            if not ok or not isSafeNumber(val) then return 0 end
            return val
        end,
        format = "largeNumber",
    },
    armor = {
        key = "armor",
        labelKey = "EAM_STAT_ARMOR",
        defaultLabel = "護甲值",
        defaultIcon = 134951, -- INV_Shield_04
        category = "survival",
        getValue = function()
            if not UnitArmor then return 0 end
            local ok, base, effectiveArmor = pcall(UnitArmor, "player")
            if not ok then return 0 end
            local val = effectiveArmor or base
            if not isSafeNumber(val) then return 0 end
            return val
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

local function formatStatNumber(val, formatType, decimals, shortNumber, suffix)
    decimals = decimals or 1
    if not isSafeNumber(val) then
        if formatType == "percent" then
            return suffix and ("0.0" .. suffix) or "0.0"
        end
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

function PlayerStatService.getStatValue(statKey)
    local def = STAT_DEFINITIONS[statKey]
    if def and def.getValue then
        local ok, val = pcall(def.getValue)
        if ok and isSafeNumber(val) then
            return val
        end
    end
    return 0
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

local function getOrCreateStatItemFrame(parent, index)
    if statItemFrames[index] then
        return statItemFrames[index]
    end

    local item = api.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    item:SetSize(40, 40)
    item:SetFrameStrata("MEDIUM")

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

    statItemFrames[index] = item
    return item
end

function PlayerStatService.update()
    if not parentFrame and not ensureParentFrame() then return end

    local db = EAM.db
    local statsConfig = db and db.playerStats or {}
    local globalConfig = db and db.config or {}

    local activeList = {}
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
        end
    end

    if #activeList == 0 then
        parentFrame:Hide()
        for _, item in ipairs(statItemFrames) do
            item:Hide()
        end
        return
    end

    parentFrame:Show()
    local growDir = (db and db.layout and db.layout.frames and db.layout.frames.playerStat and db.layout.frames.playerStat.growDirection) or 1
    local spacing = (db and db.layout and db.layout.spacing) or globalConfig.iconSpacing or 6

    for idx, data in ipairs(activeList) do
        local cfg = data.cfg
        local def = data.def
        local val = data.val
        local rawVal = data.rawVal
        local item = getOrCreateStatItemFrame(parentFrame, idx)

        local size = cfg.iconSize or globalConfig.iconSize or 40
        item:SetSize(size, size)

        local dx = 0
        local dy = 0
        local step = idx - 1
        if growDir == 1 then
            dx = step * (size + spacing)
        elseif growDir == 2 then
            dx = -step * (size + spacing)
        elseif growDir == 3 then
            dy = step * (size + spacing)
        elseif growDir == 4 then
            dy = -step * (size + spacing)
        end

        item:ClearAllPoints()
        item:SetPoint("CENTER", parentFrame, "CENTER", dx, dy)

        -- 圖示
        if cfg.showIcon ~= false then
            local iconTex = cfg.customIcon
            if iconTex and iconTex ~= "" then
                iconTex = tonumber(iconTex) or iconTex
            else
                iconTex = def.defaultIcon
            end
            item.icon:SetTexture(iconTex)
            item.icon:Show()
        else
            item.icon:Hide()
        end

        -- 數值文字
        local valStr = formatStatNumber(val, def.format, cfg.decimals, cfg.shortNumber, def.suffix)
        item.valText:SetText(valStr)
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
        local isSecret = Util and Util.isSecretValue and Util.isSecretValue(rawVal)
        if cfg.showStatusBar ~= false or isSecret then
            item.statusBar:SetHeight(math.max(4, math.floor(size * 0.15)))
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

            if isSecret then
                item.valText:SetText("")
            end
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
            item:SetBackdropBorderColor(1.0, 0.3, 0.3, 1.0)
            item.valText:SetTextColor(1.0, 0.3, 0.3, 1.0)
        else
            item:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
        end

        item:Show()
    end

    for idx = #activeList + 1, #statItemFrames do
        statItemFrames[idx]:Hide()
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
        router.register("UNIT_STATS", onEvent)
        router.register("UNIT_AURA", onEvent)
        router.register("UNIT_ABSORB_AMOUNT_CHANGED", onEvent)
        router.register("COMBAT_RATING_UPDATE", onEvent)
        router.register("SPEED_UPDATE", onEvent)
        router.register("PLAYER_ENTERING_WORLD", onEvent)
        router.register("PLAYER_MOUNT_DISPLAY_CHANGED", onEvent)
    end
    initTicker()
end

PlayerStatService.init = PlayerStatService.initialize

-- 載入時立即啟動計時器與事件監聽防護
pcall(PlayerStatService.initialize)

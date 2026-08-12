--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/LegacyDiscoveryService
檔案: Services\LegacyDiscoveryService.lua

理念:
- 安全恢復經典 EAM 的 showcast、list 與 lookup 使用習慣。
- 只搜尋目前職業的有限候選，不掃描整個 SpellID 空間。

責任:
- 記錄本次登入後玩家成功施放且可安全讀取的 SpellID。
- 彙整目前職業設定、內建候選與 session cast，提供有限查詢。

資料所有權:
- 僅擁有本次登入 session 的施法候選；不寫 SavedVariables。

邊界:
- 不呼叫 UnitAura，不自動新增監控，不序列化 Secret Value。
- UNIT_SPELLCAST_SUCCEEDED 參數必須通過安全值檢查後才可作 table key。

效能注意:
- 事件永久只註冊一次，capture 關閉時立即返回。
- lookup 僅由使用者命令觸發，且候選與結果均有上限。

Retail API 注意:
- 12.1 戰鬥中事件參數可能受 Secret 限制；未通過檢查即丟棄。
]]
local _, EAM = ...

local Util = EAM.Util
local LegacyDiscoveryService = {
    initialized = false,
    castCaptureEnabled = false,
    castSpellIDs = { count = 0 },
    castSpellIDSet = {},
}

EAM.Services.LegacyDiscoveryService = LegacyDiscoveryService

local MAX_CAST_IDS = 64
local MAX_LOOKUP_RESULTS = 40

local function addCandidate(candidateIDs, candidateSet, spellID)
    if not Util.isSafePositiveNumber(spellID) then
        return false
    end
    spellID = math.floor(spellID)
    if candidateSet[spellID] then
        return false
    end
    candidateSet[spellID] = true
    candidateIDs[#candidateIDs + 1] = spellID
    return true
end

local function collectAlertList(candidateIDs, candidateSet, list)
    if not Util.isReadableTable(list) then
        return
    end
    for index = 1, #list do
        local alert = list[index]
        if Util.isReadableTable(alert) then
            local spellID = Util.readSafeScalar(alert.spellID)
            addCandidate(candidateIDs, candidateSet, spellID)
        end
    end
end

local function collectStaticList(candidateIDs, candidateSet, list)
    if type(list) ~= "table" then
        return
    end
    for index = 1, #list do
        local entry = list[index]
        if type(entry) == "table" then
            addCandidate(candidateIDs, candidateSet, entry.id)
        end
    end
end

local function collectCandidates()
    local candidateIDs = {}
    local candidateSet = {}
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    if saved and saved.getAlertList then
        collectAlertList(candidateIDs, candidateSet, saved.getAlertList("aura", "player"))
        collectAlertList(candidateIDs, candidateSet, saved.getAlertList("aura", "target"))
        collectAlertList(candidateIDs, candidateSet, saved.getAlertList("cooldown"))
        collectAlertList(candidateIDs, candidateSet, saved.getAlertList("groundEffect"))
    end

    local classToken = saved and saved.getActiveClassToken and saved.getActiveClassToken()
    local classData = classToken and EAM.Data and EAM.Data.SpellArray and EAM.Data.SpellArray[classToken]
    if type(classData) == "table" then
        collectStaticList(candidateIDs, candidateSet, classData.general)
        for specIndex = 1, 4 do
            collectStaticList(candidateIDs, candidateSet, classData[specIndex])
        end
    end

    local castSpellIDs = LegacyDiscoveryService.castSpellIDs
    for index = 1, castSpellIDs.count do
        addCandidate(candidateIDs, candidateSet, castSpellIDs[index])
    end
    return candidateIDs
end

local function onSpellcastSucceeded(_, unitToken, _, spellID)
    if not LegacyDiscoveryService.castCaptureEnabled then
        return
    end
    if not Util.isSafeString(unitToken) or unitToken ~= "player" then
        return
    end
    if not Util.isSafePositiveNumber(spellID) then
        return
    end

    spellID = math.floor(spellID)
    local set = LegacyDiscoveryService.castSpellIDSet
    if set[spellID] or LegacyDiscoveryService.castSpellIDs.count >= MAX_CAST_IDS then
        return
    end
    set[spellID] = true
    local spellIDs = LegacyDiscoveryService.castSpellIDs
    local count = spellIDs.count + 1
    spellIDs[count] = spellID
    spellIDs.count = count
end

function LegacyDiscoveryService.initialize()
    if LegacyDiscoveryService.initialized then
        return
    end
    LegacyDiscoveryService.initialized = true
    if EAM.Modules.EventRouter then
        EAM.Modules.EventRouter.register("UNIT_SPELLCAST_SUCCEEDED", onSpellcastSucceeded)
    end
end

function LegacyDiscoveryService.setCastCaptureEnabled(enabled)
    if type(enabled) ~= "boolean" then
        return false, "invalidValue"
    end
    LegacyDiscoveryService.castCaptureEnabled = enabled
    return true, enabled and "enabled" or "disabled"
end

function LegacyDiscoveryService.isCastCaptureEnabled()
    return LegacyDiscoveryService.castCaptureEnabled == true
end

function LegacyDiscoveryService.forEachCastSpell(callback)
    if type(callback) ~= "function" then
        return 0
    end
    local spellIDs = LegacyDiscoveryService.castSpellIDs
    for index = 1, spellIDs.count do
        callback(spellIDs[index])
    end
    return spellIDs.count
end

function LegacyDiscoveryService.forEachCandidate(callback)
    if type(callback) ~= "function" then
        return 0
    end
    local candidates = collectCandidates()
    for index = 1, #candidates do
        callback(candidates[index])
    end
    return #candidates
end

function LegacyDiscoveryService.lookup(query, exact, callback, resultLimit)
    if not Util.isSafeString(query) or query == "" or type(callback) ~= "function" then
        return 0, "invalidQuery"
    end
    local normalizedQuery = string.lower(query)
    local limit = tonumber(resultLimit) or MAX_LOOKUP_RESULTS
    if limit < 1 then
        return 0, "invalidLimit"
    end
    if limit > MAX_LOOKUP_RESULTS then
        limit = MAX_LOOKUP_RESULTS
    end

    local candidates = collectCandidates()
    local spellInfoService = EAM.Services and EAM.Services.SpellInfoService
    local resultCount = 0
    for index = 1, #candidates do
        local spellID = candidates[index]
        local info = spellInfoService and spellInfoService.getSpellInfo(spellID)
        local name = info and info.factsSafe and info.name or nil
        if Util.isSafeString(name) then
            local normalizedName = string.lower(name)
            local matched = exact and normalizedName == normalizedQuery
                or (not exact and string.find(normalizedName, normalizedQuery, 1, true) ~= nil)
            if matched then
                resultCount = resultCount + 1
                callback(spellID, name)
                if resultCount >= limit then
                    break
                end
            end
        end
    end
    return resultCount, resultCount > 0 and "matched" or "notFound"
end
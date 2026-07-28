--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/ShadowHostService
檔案: Services\ShadowHostService.lua

理念:
- 作為 EAM 的「影子載體 (Shadow Host)」服務，負責 Hook 官方 CooldownViewer 框架的 Pool。
- 在戰鬥外，將官方的 CooldownViewer 框架設為完全透明（Alpha = 0）並降低層級，使其不可見。
- 監測官方動態 Acquire 與 Release 的圖示 Frame，並提供 SpellID 到官方 Icon 實體的 O(1) 快速查找映射。
- 遵循 100% 安全原則：戰鬥中只讀、防 Taint 傳播，僅操作非保護的自訂元件，安全 Hook 不破壞 secure chain。

責任:
- 監聽與 Hook 官方 CooldownViewer 的 FramePool (`Acquire`/`Release`)。
- 在脫戰與加載時，透明化 `EssentialCooldownViewer` 與 `UtilityCooldownViewer` 框架。
- 維護 active shadow icons 映射表，提供 Renderer 快速查詢與寄生掛載。
]]

local _, EAM = ...
local api = EAM.API

local ShadowHostService = {
    activeHosts = {}, -- spellID -> hostIconFrame
    activeNameHosts = {}, -- spellName -> hostIconFrame (二級名稱比對表)
    activeIconHosts = {}, -- iconID -> hostIconFrame (三級圖示比對表)
    monitoredPools = {},
}

EAM.Services.ShadowHostService = ShadowHostService

-- 本地快取以提升效能，消滅 Hot Path GC
local activeHosts = ShadowHostService.activeHosts
local activeNameHosts = ShadowHostService.activeNameHosts
local activeIconHosts = ShadowHostService.activeIconHosts

-- 安全地從官方 Icon 提取 SpellID
local function getSpellIDFromHostIcon(icon)
    if not icon then return nil end
    
    -- 使用 pcall 隔離防護，防範官方 Frame 在戰鬥中屬性突變
    local success, spellID = pcall(function()
        return icon.spellID or (icon.data and icon.data.spellID) or icon.spellId
    end)
    
    if success and spellID and not api.issecretvalue(spellID) then
        return spellID
    end
    return nil
end

-- 安全地從官方 Icon 提取法術名稱，用於二級比對
local function getSpellNameFromHostIcon(icon)
    if not icon then return nil end
    
    local success, spellName = pcall(function()
        return icon.spellName or (icon.data and (icon.data.name or icon.data.spellName)) or (icon.Name and icon.Name.GetText and icon.Name:GetText())
    end)
    
    if success and spellName and type(spellName) == "string" and not api.issecretvalue(spellName) and spellName ~= "" then
        return spellName
    end
    return nil
end

-- 安全地從官方 Icon 提取圖示 ID (Texture ID / FileDataID)，用於三級比對
local function getIconIDFromHostIcon(icon)
    if not icon then return nil end
    
    local success, iconID = pcall(function()
        local tex = icon.Icon or icon.icon or icon.texture
        if tex and tex.GetTexture then
            return tex:GetTexture()
        end
        return icon.iconID or (icon.data and icon.data.iconID) or icon.iconId
    end)
    
    if success and iconID and not api.issecretvalue(iconID) then
        return iconID
    end
    return nil
end


-- 掃描指定 Pool 的所有 Active Objects，捕獲新增的圖示
local function scanPoolActiveObjects(pool)
    if not pool or not pool.EnumerateActive then return end
    
    for icon in pool:EnumerateActive() do
        local spellID = getSpellIDFromHostIcon(icon)
        if spellID then
            if not activeHosts[spellID] then
                activeHosts[spellID] = icon
            end
        end
        
        local spellName = getSpellNameFromHostIcon(icon)
        if spellName then
            if not activeNameHosts[spellName] then
                activeNameHosts[spellName] = icon
            end
        end

        local iconID = getIconIDFromHostIcon(icon)
        if iconID then
            if not activeIconHosts[iconID] then
                activeIconHosts[iconID] = icon
            end
        end
    end
end

-- 官方 Pool Acquire 的安全 Hook 回呼
local function onHostIconAcquired(pool)
    -- Acquire 後，新的 Icon 已被標記為 active，立刻進行掃描捕獲
    scanPoolActiveObjects(pool)
end

-- 官方 Pool Release 的安全 Hook 回呼
local function onHostIconReleased(pool, icon)
    if not icon then return end
    
    local spellID = getSpellIDFromHostIcon(icon)
    if spellID and activeHosts[spellID] == icon then
        activeHosts[spellID] = nil
    end
    
    local spellName = getSpellNameFromHostIcon(icon)
    if spellName and activeNameHosts[spellName] == icon then
        activeNameHosts[spellName] = nil
    end

    local iconID = getIconIDFromHostIcon(icon)
    if iconID and activeIconHosts[iconID] == icon then
        activeIconHosts[iconID] = nil
    end
end

-- 掃描所有受監控 Pool 的 Active Objects，重整所有映射
local function scanAll()
    for viewer, monitored in pairs(ShadowHostService.monitoredPools) do
        if monitored and viewer.cooldownPool then
            scanPoolActiveObjects(viewer.cooldownPool)
        end
    end
end

-- 對官方 CooldownViewer 進行透明化與降層處理
local function makeHostInvisible(hostFrame)
    if not hostFrame or (api.InCombatLockdown and api.InCombatLockdown()) then 
        return 
    end
    
    -- 將框架設為完全透明，但不 Hide，保留其子節點的 Layout 計算與生命週期事件
    hostFrame:SetAlpha(0)
    
    -- 降至背景最底層，防止鼠標事件阻擋
    hostFrame:SetFrameStrata("BACKGROUND")
    hostFrame:SetFrameLevel(0)
end

-- 執行官方 Viewer 框架的透明化與 Pool Hook
local function hookCooldownViewer(viewer)
    if not viewer or ShadowHostService.monitoredPools[viewer] then return end
    
    local pool = viewer.cooldownPool
    if not pool then return end
    
    -- 標記為已監控，防止重複 Hook
    ShadowHostService.monitoredPools[viewer] = true
    
    -- 安全 Hook pool 的 Acquire 和 Release
    hooksecurefunc(pool, "Acquire", function()
        onHostIconAcquired(pool)
    end)
    
    hooksecurefunc(pool, "Release", function(_, icon)
        onHostIconReleased(pool, icon)
    end)
    
    -- 戰鬥外立即執行透明化
    makeHostInvisible(viewer)
    
    -- 先行掃描一次當前已存在的 active objects
    scanPoolActiveObjects(pool)
end

-- 初始化與事件加載
local function initShadowHost()
    -- 1. 嘗試直接綁定（如果官方 AddOn 早已加載）
    if EssentialCooldownViewer then
        hookCooldownViewer(EssentialCooldownViewer)
    end
    if UtilityCooldownViewer then
        hookCooldownViewer(UtilityCooldownViewer)
    end
    
    -- 2. 註冊事件以處理延遲加載與脫戰重置
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    frame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Blizzard_CooldownViewer" then
            if EssentialCooldownViewer then
                hookCooldownViewer(EssentialCooldownViewer)
            end
            if UtilityCooldownViewer then
                hookCooldownViewer(UtilityCooldownViewer)
            end
        elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
            -- 脫戰或進入世界時，確保影子載體隱形
            if EssentialCooldownViewer then
                makeHostInvisible(EssentialCooldownViewer)
                scanPoolActiveObjects(EssentialCooldownViewer.cooldownPool)
            end
            if UtilityCooldownViewer then
                makeHostInvisible(UtilityCooldownViewer)
                scanPoolActiveObjects(UtilityCooldownViewer.cooldownPool)
            end
        end
    end)
end

-- 外部接口：查詢當前是否有官方影子 Icon 可供寄生 (暫時停用，直接返回 nil)
function ShadowHostService.GetHostIcon(spellID, spellName, iconID)
    -- 放棄與 CDM 掛勾，直接返回 nil
    return nil
end

-- 執行初始化 (暫時停用，不掛勾官方 CDM 框架，不隱藏官方冷卻 UI)
-- initShadowHost()

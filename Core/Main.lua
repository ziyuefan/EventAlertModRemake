--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/Main
檔案: Core\Main.lua

理念:
- 作為新架構的唯一啟動器，取代舊 XML OnLoad 工作流。
- 初始化順序固定為 SavedVariables -> UI -> Services -> 初次刷新。

責任:
- 監聽 PLAYER_LOGIN，啟動資料遷移、Renderer 與各 service。
- 提供第一輪 Retail-only rewrite 的載入錨點。

資料所有權:
- 不擁有業務資料；只協調各模組公開 initialize/refresh API。

可變狀態:
- 只設定 EAM.initialized 與啟動狀態。

邊界:
- 不直接查 aura/cooldown/item API。
- 不建立 alert facts，不直接 mutate UI icon state。

效能注意:
- 啟動流程只執行一次；初次 refresh 應保持低頻且可延後擴充。

Retail API 注意:
- 以 PLAYER_LOGIN 作為 SavedVariables、UnitClass 與 UIParent 均可用後的啟動點。
]]
local _, EAM = ...

local Main = {
    initialized = false,
}

EAM.Modules.Main = Main

local function initializeModule(module, name)
    if module and module.initialize then
        local ok, err = pcall(module.initialize)
        if not ok then
            print("|cffff0000EAM Init Error|r on [" .. tostring(name) .. "]: " .. tostring(err))
        end
    end
end

function Main.initialize()
    if Main.initialized then
        return
    end
    Main.initialized = true

    if EAM.Modules.SavedVariables then
        local ok, err = pcall(EAM.Modules.SavedVariables.initialize)
        if not ok then
            print("|cffff0000EAM SavedVariables Init Error|r: " .. tostring(err))
        end
    end

    initializeModule(EAM.Services.AuraCapabilityService, "AuraCapabilityService")
    initializeModule(EAM.UI.Renderer, "Renderer")
    initializeModule(EAM.UI.TooltipMonitorMenu, "TooltipMonitorMenu")
    initializeModule(EAM.Services.TooltipMonitorService, "TooltipMonitorService")
    initializeModule(EAM.Managers.AlertManager, "AlertManager")
    initializeModule(EAM.Services.SpellInfoService, "SpellInfoService")
    initializeModule(EAM.Services.AuraService, "AuraService")
    initializeModule(EAM.Services.CooldownService, "CooldownService")
    initializeModule(EAM.Services.ItemCooldownService, "ItemCooldownService")
    initializeModule(EAM.Services.ClassPowerService, "ClassPowerService")
    initializeModule(EAM.Services.GroundEffectService, "GroundEffectService")
    initializeModule(EAM.Services.TotemService, "TotemService")
    initializeModule(EAM.Services.AuraContainerService, "AuraContainerService")

    -- 啟動初始刷新，採用 pcall 故障隔離，防範單一服務崩潰卡死全盤
    if EAM.Services.AuraService then
        pcall(EAM.Services.AuraService.refreshUnit, "player", "PLAYER_LOGIN")
        pcall(EAM.Services.AuraService.refreshUnit, "target", "PLAYER_LOGIN")
    end
    if EAM.Services.CooldownService then
        pcall(EAM.Services.CooldownService.refreshAll, "PLAYER_LOGIN")
    end
    if EAM.Services.ItemCooldownService then
        pcall(EAM.Services.ItemCooldownService.refreshAll, "PLAYER_LOGIN")
    end
    if EAM.Services.ClassPowerService then
        pcall(EAM.Services.ClassPowerService.updatePower)
    end
    if EAM.Services.TotemService then
        pcall(EAM.Services.TotemService.scanAll)
    end
end

local function onLogin()
    Main.initialize()
end

-- 🛡️ 登入保護與加載期邊界防禦：防範重載 UI (ReloadUI) 或是動態加載時 PLAYER_LOGIN 事件不再觸發的 Bug
if IsLoggedIn and IsLoggedIn() then
    Main.initialize()
elseif EAM.Modules.EventRouter then
    EAM.Modules.EventRouter.register("PLAYER_LOGIN", onLogin)
end

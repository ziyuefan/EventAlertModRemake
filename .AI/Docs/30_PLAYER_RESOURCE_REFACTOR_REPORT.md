<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# Retail 12.1 玩家職業資源獨立模組重構報告

- 日期：2026-08-21
- 目標通道：Retail／PTR 12.1；XPTR 12.0.7 使用隔離的 numeric legacy adapter
- 證據層級：程式與測試結論為 offline-mock／static contract；尚未宣稱任何 WoW 客戶端視覺簽收。

## A. 現況架構

玩家資源已從 Aura、Spell Cooldown 與 Item Cooldown 資料路徑拆出，責任邊界如下：

1. `Data/PlayerResourceCatalog.lua`：17 種資源定義、token、powerType、13 職業／40 組專精候選拓撲。
2. `Services/PlayerResourceCapability.lua`：依 client adapter 與每項資源分流 `NUMERIC`、`SECRET_DISPLAY`、`UNAVAILABLE`。
3. `Services/PlayerResourceService.lua`：唯一 runtime registry、事件路由、topology、effective config、背景 sampler。
4. `Debug/PlayerResourceProbe.lua`：玩家手動啟動的逐資源事件／sink 能力報告；不讀 raw power。
5. `UI/PowerRenderer.lua`：EAM 自有 StatusBar／圖示／文字與 Secret write-only sink。
6. `UI/PlayerResourcePanel.lua`：每資源設定、anchor／position、尺寸與外觀控制。
7. `Services/ClassPowerService.lua`：只保留舊入口 facade，不建立第二條資源 pipeline。

## B. /reload 症狀與根因

舊流程把 SavedVariables 寫入與初始化 frame 建立混在一起，設定變更只有重新載入才可見。現行契約分開兩種情況：

- 非戰鬥：`SavedVariables.updatePlayerResourceConfig` 發出 `EAM_PLAYER_RESOURCE_CONFIG_CHANGED`，服務立即重建並套用，不應要求 `/reload`。
- 戰鬥：設定先保存 desired state，結構性變更標記 `combatRebuildDeferred`；`PLAYER_REGEN_ENABLED` 合併重建一次。
- 模組停用：停止背景 sampler、清理 frame、解除 PlayerResourceService 與 PlayerResourceProbe 的事件註冊；重新啟用才重新註冊。

若實機仍需 `/reload`，需回報 resource key、client channel、patch/build/interface、戰鬥狀態、service status、Lua error、taint 或 blocked action。

## C. N-resource topology 與 Druid flow

採用一個專精對 N 個候選資源。候選 topology 不因 `enabled=false` 被刪除；capability、foreground/background 與 renderer 狀態分開。德魯伊依變形流程保留 Mana、Rage、Energy、ComboPoints、LunarPower 候選，透過 `UNIT_DISPLAYPOWER`／`UPDATE_SHAPESHIFT_FORM` 重新判定前景與可用性，不把 Energy 或 ComboPoints 強制塞到第一格。

## D. Config hierarchy、anchor 與 position

有效設定依 `globalDefaults -> classDefaults -> spec overrides` 合併。每項資源可獨立保存 `enabled`、display mode、foreground/background、value／percent、font、size、orientation、threshold、alpha、寬高、圖示大小、間距、order、`anchor` 與 `position`。anchor 是父框架錨點，position 是資源框架自身定位點；兩者均由白名單循環選擇並帶 offset／scale。未覆寫欄位由 class／global 繼承，不能製造跨職業污染。

## E. Capability、12.0.7 adapter 與 Secret source/sink

`PlayerResourceCapability` 以 client adapter 分流：Retail／PTR 12.1 可採 NUMERIC 或 Secret display；XPTR 12.0.7 使用隔離的 numeric legacy adapter，不能呼叫 12.1 Native Aura／Secret sink。Secret 資源只將安全邊界允許的 percent 直接寫入 StatusBar／radial sink，不保存、比較、數學運算、tostring、序列化、當 table key 或讀回 getter。所有報告只輸出安全 metadata，不輸出 current、max、percent 原值。

## F. ResourceProbe、事件與背景 sampler

`PlayerResourceProbe` 只在玩家手動啟動期間註冊事件，逐項記錄 tracked／available／foreground／background／capability／sinkAvailable／eventObserved；停止時解除註冊。`eventObserved` 僅表示事件由實機流程觸發，不代表視覺或數值正確。

背景資源只有在 probe 明確確認相關事件缺失後，才啟用單一 probe-gated、0.5 秒 demand-driven sampler；它不是預設輪詢，也不在戰鬥中執行結構變更。若事件被觀測，該 resource 立即退出 sampler。Sampler fixture／contract 已通過離線驗證；仍不可把 sampler 啟用或 setter accepted 冒充實機通過。

## G. Renderer ownership

`PowerRenderer` 預熱固定資源 frame 與 StatusBar，使用直接 source-to-sink 更新；Secret frame 由 resource key 獨立擁有。Renderer 不讀回 widget 值、不以 OnUpdate 輪詢、不建立 ShadowHost 或第二條 Aura／Cooldown pipeline。

## H. Performance boundary

事件路由以 token／powerType registry O(1) 導向；所有資源 frame 預建，避免事件熱路徑反覆建立 frame。`NUMERIC`／`SECRET_DISPLAY` 的更新策略在 capability 分類後於冷路徑綁定；NUMERIC 每次事件只執行一次防護讀取 pair，文字改以 `FontString:SetFormattedText()` 更新，避免每事件 `string.format` 或字串串接；Secret 只執行 write-only sink。背景 sampler 為單一、probe-gated、demand-driven 排程，停止時清空節點與 generation。Sampler fixture／contract 已通過離線驗證；剩餘缺口是 WoW runtime 視覺、事件與 taint 簽收。

## I. Legacy 12.0.7

`getClientAdapter()` 以 interface／client profile 判定 XPTR 12.0.7 numeric legacy adapter，並由 Flow `unitpower.legacy_120007_adapter` 驗證不進入 12.1 Secret sink。這是相容能力分類與降級契約，不是 XPTR 實機視覺證據；Classic／MoP 不在本專案範圍。

## J. 離線驗證

本輪最新 artifact：

- Lua syntax（62 AddOn + 2 offline tests）：`64/64`。
- Flow all：`75/75`，`EAM_FlowValidation_all_20260821_094159.json`。
- Flow boundary：`54/54`，`EAM_FlowValidation_boundary_20260821_094201.json`。
- Validation Contracts：`436/436`，已以最新 Flow artifact 重跑通過。
- 已涵蓋 ResourceProbe schema、12.0.7 adapter、Druid topology／form、module event unregister、anchor／position、冷路徑策略綁定、source／sink 邊界、config immediate／combat deferred 與 `unitpower.background_sampler_gate`。
- 背景 sampler fixture／contract 已通過；上述離線結果不能代替 WoW 實機 visual、taint 或 blocked-action 簽收。

## K. 實機簽收門檻

標記為 `REQUIRES_WOW_12_1_RUNTIME` 或 `REQUIRES_XPTR_12_0_7_RUNTIME` 的項目：

1. 法師 Mana、戰士 Rage、野性德魯伊 Energy＋ComboPoints、暗影牧師 Insanity、死亡騎士 Runes＋RunicPower 的脫戰／戰鬥產生、消耗、歸零。
2. 其餘職業／專精所有 `UnitHasPowerType` 可用資源，逐項記錄 ResourceProbe 的 `eventObserved` 與 visualObservation。
3. 德魯伊 Caster／Cat／Bear／Moonkin 變形與前景／背景資源切換，不得強制 1079 或其他法術首格。
4. 非戰鬥改設定不得 `/reload` 才更新；戰鬥修改需離戰後只重建一次；停用／重啟需確認事件註冊與 frame 清理。
5. anchor／position、尺寸、文字、threshold、Secret StatusBar 視覺、Druid Flow 與 XPTR numeric fallback。
6. Lua error、taint、blocked action、Forbidden access 與報告 privacy。

真人報告必須標示 PTR、XPTR 或 Retail、patch、build、interface、戰鬥狀態、是否手動 `/reload` 與 visualObservation。API accepted、offline pass、ResourceProbe eventObserved 或 sampler output 都不能直接升格為 visual pass。
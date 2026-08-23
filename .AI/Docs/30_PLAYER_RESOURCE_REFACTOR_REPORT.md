<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# Retail 12.1 玩家職業資源獨立模組重構報告

- 日期：2026-08-23
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

背景資源只有在玩家／Probe 明確確認相關事件缺失後，才可請求單一 probe-gated、demand-driven sampler；目前離線 fixture 使用 0.5 秒間隔僅是測試時鐘，不是 Retail 12.1 的實機頻率結論。它不是預設輪詢，也不在戰鬥中執行結構變更。若事件被觀測，該 resource 立即退出 sampler。Sampler fixture／contract 已通過離線驗證；仍不可把 sampler 啟用或 setter accepted 冒充實機通過。

## G. Renderer ownership

`PowerRenderer` 預熱固定資源 frame 與 StatusBar，使用直接 source-to-sink 更新；Secret frame 由 resource key 獨立擁有。Renderer 不讀回 widget 值、不以 OnUpdate 輪詢、不建立 ShadowHost 或第二條 Aura／Cooldown pipeline。

## H. Performance boundary

事件路由以 token／powerType registry O(1) 導向；所有資源 frame 預建，避免事件熱路徑反覆建立 frame。`NUMERIC`／`SECRET_DISPLAY` 的更新策略在 capability 分類後於冷路徑綁定；NUMERIC 每次事件只執行一次防護讀取 pair，文字改以 `FontString:SetFormattedText()` 更新，避免每事件 `string.format` 或字串串接；Secret 只執行 write-only sink。背景 sampler 為單一、probe-gated、demand-driven 排程，停止時清空節點與 generation。Sampler fixture／contract 已通過離線驗證；剩餘缺口是 WoW runtime 視覺、事件與 taint 簽收。

## I. Legacy 12.0.7

`getClientAdapter()` 以 interface／client profile 判定 XPTR 12.0.7 numeric legacy adapter，並由 Flow `unitpower.legacy_120007_adapter` 驗證不進入 12.1 Secret sink。這是相容能力分類與降級契約，不是 XPTR 實機視覺證據；Classic／MoP 不在本專案範圍。

## J. 離線驗證

本輪最新 artifact：

- Lua syntax（62 AddOn + 2 offline tests）：62/62。
- Flow all：77/77，.AI/TestResults/EAM_FlowValidation_all_20260823_063557.json。
- Flow boundary：56/56，.AI/TestResults/EAM_FlowValidation_boundary_20260823_063609.json。
- Validation Contracts：459/459，已以最新 Flow artifact 重跑通過；並同步通過部署契約與連續性追蹤。
- 已涵蓋 ResourceProbe schema、12.0.7 adapter、Druid Bear／Cat／Caster／Moonkin／回 Bear topology、Energy→ComboPoints renderer ownership、module event unregister、anchor／position、font／orientation、冷路徑策略綁定、source／sink 邊界、config immediate／combat deferred 與 unitpower.background_sampler_gate。
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

## L. Acceptance matrix

| 項目 | 離線／靜態證據 | WoW 12.1 實機狀態 |
| --- | --- | --- |
| Catalog、17 資源、40 組 class/spec topology | PASS | REQUIRES_WOW_12_1_RUNTIME |
| NUMERIC／SECRET_DISPLAY／UNAVAILABLE capability 分流 | PASS | REQUIRES_WOW_12_1_RUNTIME |
| UNIT_DISPLAYPOWER 只刷新 foreground、背景節點保留 | PASS | REQUIRES_WOW_12_1_RUNTIME |
| Druid 五資源與 Bear／Cat／Caster／Moonkin／回 Bear flow | PASS | REQUIRES_WOW_12_1_RUNTIME |
| Energy 更新不隱藏 ComboPoints、每資源 frame ownership | PASS | REQUIRES_WOW_12_1_RUNTIME |
| 非戰鬥設定即時套用、戰鬥中離戰一次重建 | PASS | REQUIRES_WOW_12_1_RUNTIME |
| Probe metadata、手動背景 sampler gate、模組停用清理 | PASS | REQUIRES_WOW_12_1_RUNTIME |
| Retail／PTR 12.1 與 XPTR 12.0.7 全職業／專精視覺、事件、taint | 未由離線測試證明 | REQUIRES_WOW_12_1_RUNTIME／REQUIRES_XPTR_12_0_7_RUNTIME |

離線 PASS 僅表示程式、strict mock、Flow 與契約一致；任何 StatusBar setter accepted、eventObserved 或 sampler tick 都不能升格為玩家視覺通過。
## M. Alpha 7 final offline correction

本節取代前段舊 artifact 數字，作為目前玩家資源離線證據索引。

- PlayerResourceProbe 新增一次性 missing-event check：Probe start 後由 Scheduler 延遲檢查背景資源，執行一次後產生安全 metadata；stop、generation invalidation 或 module disable 都會取消。
- UNIT_DISPLAYPOWER、UPDATE_SHAPESHIFT_FORM 與 PLAYER_REGEN_ENABLED 僅刷新 foreground metadata，不批量重讀或刪除背景資源；SavedVariables Catalog map 保持唯讀，避免 frozen table 寫入。
- Options 在 SavedVariables API 未完成時返回 savedVariablesMethodUnavailable，不再把初始化錯誤級聯成 nil method。
- 最終離線 gate：Lua 62/62、Flow all 77/77、Flow boundary 56/56、Validation Contracts 461/461。最新 artifact：.AI/TestResults/EAM_FlowValidation_all_20260823_081553.json、.AI/TestResults/EAM_FlowValidation_boundary_20260823_081542.json。
- 以上仍是 offline-mock／static contract；法力、怒氣、能量、連擊點、瘋狂值、符文、Secret sink、全職業／專精與 taint 必須在玩家部署後分 Retail／PTR／XPTR 簽收。

## N. 464/464 final offline gate 與公開 README

- 最新 Lua syntax：62/62。
- 最新 Flow：all 77/77、boundary 56/56；artifact 分別為 EAM_FlowValidation_all_20260823_083630.json 與 EAM_FlowValidation_boundary_20260823_083631.json。
- 最新 Validation Contracts：464/464；新增 gate 包含 Probe restart／一次性 missing-event check、Frozen Catalog read-only、Options fail-closed、README／changelog package synchronization 與 privacy contract。
- 根 README 與插件副本已同步，包含 Alpha 7 狀態、實際 /eam command line 用法、執行時機、部署選單與 WTF backup／restore 說明；兩份 SHA-256 為 635C545E7B535B85730AA28D24176E291299A86F47D5036682C1FE5877935AB3。
- 以上仍是 offline/static evidence；Secret sink、全職業／專精視覺、taint、blocked action、戰鬥／脫戰與三通道 runtime 必須由玩家部署後簽收。

## 2026-08-23 DK Rune 六槽事件路徑

- 問題：RUNES powerType 不能視為 Runic Power 類型的連續聚合條；泛用 UnitPower 路徑無法反映每顆 Rune 可用／冷卻狀態。
- 實作：`GetRuneCount(1..6)` 初始化每槽 ready boolean；若 API 缺失或安全值不可得，再嘗試 `GetRuneCooldown(index)` 的 `isRuneReady`。任何不安全結果都 fail-closed，不讀 start／duration。
- 熱路徑：`RUNE_POWER_UPDATE(runeIndex, added)` 只更新一槽與 0..6 ready count，明確保存 `added=false`。事件本身不呼叫 UnitPower／UnitPowerMax／UnitPowerPercent，也不配置新的 frame。
- 渲染：沿用預先建立的 RUNES POINTS StatusBar 與五條 separator，safe count 轉為 count/6 百分比。這是六段 ready-count 彙總，不是六顆各自的 recharge sweep；個別 recharge 動畫若要加入，須另行驗證每槽 DurationObject／widget 能力與 Secret 邊界。
- 診斷：`getStatus()` 只輸出 `runeSlotAPIAvailable`、`runeStateInitialized`、`runeReadyCount`、`runeEventCount`、`lastRuneResult` 等 safe metadata。
- 離線驗證：`unitpower.runes_event_driven_segments` 驗證 6/6→5/6→6/6、Rune event 期間泛用 UnitPower 讀取 0、Secret operation 0；仍需玩家部署後確認 Retail 12.1 血／冰／邪專精視覺。

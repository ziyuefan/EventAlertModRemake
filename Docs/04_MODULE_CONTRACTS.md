<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 模組合約

## 所有權規則

- `SavedVariables` 擁有持久配置表和遷移。
- 服務擁有運行時事實。
- `Renderer` 擁有渲染的 UI 狀態。
- `IconPool` 擁有框架物件。
- `Scheduler` 擁有應有的工作。
- `DebugState` 擁有 debug/session 快照。
- 靜態常數可能會被凍結。運行時狀態和 SavedVariables 絕不能
  被凍結。
- 每個主動載入的來源檔案必須以模組註解區塊開頭
  記錄目的、設計理念、所有權、變更邊界，以及
  保養注意事項。當模組合約發生變化時，請保持此評論最新。
  請參閱“Docs/12_CODE_COMMENTARY_GUIDE.md”。

## Core/Env

輸入：

- 外掛名稱和命名空間
- 正式服建置/flavor API

輸出：

- 外掛程式命名空間
- 本地 API 別名表
- 僅限正式服的防護結果

狀態變更：
- 可以初始化外掛名稱空間一次
- 不得改變 SavedVariables

## Core/Util

輸入：

- 原始 Lua/WoW 表 API

輸出：

- `CreateTable`、`FreezeTable`、`IsFrozen`、泳池助手、安全擦除/release、
  穩定的枚舉助手，除錯斷言
- Secret/protected 值安全讀取助手：
  - `readSafeField`
  - `readSafeScalar`
  - `markBoundary`
  - `appendBoundaryWarning`
  - `clearTimer`

狀態變更：

- 僅擁有輔助本地池

## Core/Constants

輸入：

- 模組載入後無

輸出：

- 凍結枚舉表、模組名稱、事件名稱、狀態常數、模式
  版本、哨兵常數，例如 `UNKNOWN` 和 `EMPTY`

狀態變更：

- 凍結後沒有

## Core/EventRouter

輸入：

- 模組事件註冊
- 暴雪事件

輸出：
- 透過參數化 `pcall` 錯誤隔離來分派對已註冊模組處理程序的調用，確保一個模組處理程序中的故障不會阻止其他註冊者

狀態變更：

- 擁有事件框架與事件註冊表
- 每個活動報名沒有關閉分配

## Core/Scheduler

輸入：

- 模組請求的到期作業

輸出：

- 在保護性 `pcall` 隔離下進行回呼度調度，確保捕獲作業運行時故障並且不會破壞全域程式碼框架
- 無論回呼成功與否，安全佇列清理和任務記錄回收

狀態變更：

- 擁有一個 OnUpdate 框架、到期佇列、可重複使用作業記錄和任務池
- 沒有每個圖示的調度表

## Core/SavedVariables

輸入：

- 舊版全域變數：`EA_Config`、`EA_Position`、`EA_Items`、`EA_AltItems`、
  `EA_TarItems`、`EA_ScdItems`、`EA_GrpItems`、`EA_Pos`
輸出：

- 版本化的活動設定文件
- 遷移報告
- 驗證警告
- 使用者觸發的警報添加/remove光環、法術冷卻和物品冷卻的API

狀態變更：

- 在載入/migration/config變更期間可能會改變SavedVariables
- 不得寫入高頻運轉時狀態
- 不得結凍 SavedVariables
- 在使用者觸發的配置變更後增加 `EAM_DB.revision`

## Core/Performance

輸入：

- `GetFramerate`，戰鬥鎖定狀態，選用`debugprofilestop`

輸出：

- 節流決策、分析樣本、共享表池

狀態變更：

- 僅擁有分析/session 計數器

## Services/AuraService

輸入：

- 設定玩家/target光環警報
- `UNIT_AURA`、`PLAYER_TARGET_CHANGED`、登入/world 事件

輸出：

- `EAM_AURA_STATE_CHANGED` 事件透過參數化狀態和 frameName 觸發到 EventRouter
- 從 `AuraStatePool` 分配的標準化 `AuraState` 和 `AlertState`
- 邊界警告
- 由單位和 `auraInstanceID` 鍵入的增量感知光環緩存
- 配置修訂感知警報索引，按單元鍵入並配置 spellID
- 完整更新回退掃描每個追蹤單元/filter一次，重建單元光環緩存，並將不匹配的配置警報標記為非活動狀態

狀態變更：

- 僅擁有 aura 運行時快取和 `AuraStatePool`
- 不得創建 UI 框架
- 不得寫入 SavedVariables
- 當 SavedVariables 版本變更時可能會重建警報索引

## Managers/AlertManager

輸入：

- 來自 EventRouter 的 `EAM_AURA_STATE_CHANGED`、`EAM_COOLDOWN_STATE_CHANGED`、`EAM_ITEM_COOLDOWN_STATE_CHANGED`、`EAM_GROUND_EFFECT_STATE_CHANGED` 和 `EAM_TOTEM_STATE_CHANGED` 事件
- 配置警報列表

輸出：
-batch/throttled 呼叫包裝在佈局批次控制中的 `Renderer.render` (`Renderer.BeginBatch` / `Renderer.EndBatch`)
- 在 UI 隱藏渲染完成後，透過 `state.releaseFunc(state)` 回收多類型狀態表以回收非活動狀態（Aura、Cooldown、Item、GroundEffect、Totem）

狀態變更：

- 擁有掛起的更新佇列和節流調度程序狀態
- 不擁有 AlertState、SavedVariables 或 UI 圖標

## Services/CooldownService

輸入：

- 配置法術冷卻時間警報
- 與冷卻相關的事件和調度程序後備刻度

輸出：

- 標準化 `CooldownState` 和 `AlertState`
- 髒警報 ID

狀態變更：

- 僅擁有法術冷卻緩存

## LegacyReference/Services/ShadowHostService（封存參考，不載入）

狀態：

- 不列入 `EventAlertMod.toc`，不屬於正式執行期模組。
- 原始研究碼保留於 `LegacyReference/Services/ShadowHostService.lua`，只供 CDM／FramePool 歷史決策追溯。
- 正式包排除整個 `LegacyReference/`；Renderer 不查找或吸附 ShadowHost。

封存原因：

- 12.1 Native AuraContainer 架構不需要以 CooldownViewer 作為影子載體。
- Hook 官方 frame pool、變更官方框架透明度與層級會擴大 taint、Forbidden 與版本漂移風險。
- 流程驗證以 `EAM.Services.ShadowHostService == nil` 作為零載入契約。

## Services/ItemCooldownService

輸入：

- 設定 itemID 警報
- 物品冷卻事件
- 可選的顯式快取建置命令

輸出：

- 標準化 `ItemCooldownState` 和 `AlertState`
- 快取狀態

狀態變更：

- 擁有物品冷卻運轉時緩存
- 任何物品-法術映射快取都必須是增量且可中斷的

## Services/SpellInfoService

輸入：

- spellID/itemID 尋找請求

輸出：

- 安全名稱/icon/link 可用事實
- 有界查找緩存，僅儲存安全欄位和邊界警告

狀態變更：

- 擁有查找緩存
- 必須避免激烈的戰鬥查詢循環
## Services/ClassPowerService

輸入：

- 配置類別資源選項
- 玩家電源事件（UNIT_POWER_UPDATE、UNIT_MAXPOWER、PLAYER_TALENT_UPDATE）

輸出：

- 當前等級功率類型的動態中央堆疊編號和 AlertState，在功率更新期間受到 `pcall` 隔離和 `issecretvalue` 檢查的保護，以繞過戰鬥中的限制值 /table 運行時異常
- 直接佈局渲染到 classPower 框架

狀態變更：

- 除了調度事件狀態更新和防禦邊界記錄之外，沒有其他操作

## Services/GroundEffectService

輸入：

- 配置的地面效果（動態/manual模式）
- 未過濾的戰鬥日誌事件（SPELL_CAST_SUCCESS）
- 施法成功期間低頻 C_TooltipInfo.GetSpellByID 查找

輸出：

- `EAM_GROUND_EFFECT_STATE_CHANGED` 事件觸發到 EventRouter 並帶有狀態和 frameName
- 從 `GroundEffectStatePool` 分配的標準化 `GroundEffectState` 和 `AlertState`
- 透過 Scheduler.after 安排發布計時器

狀態變更：

- 僅擁有地面效應活動計時器表、activeStates 快取和 `GroundEffectStatePool`

## Services/TotemService

輸入：

- 薩滿圖騰事件 (PLAYER_TOTEM_UPDATE)
- 本機 C_Totems.GetTotemInfo API 更新

輸出：

- `EAM_TOTEM_STATE_CHANGED` 事件觸發到 EventRouter 並帶有狀態和 frameName
- 從 `TotemStatePool` 分配的標準化 `TotemState` 和 `AlertState`

狀態變更：

- 僅擁有 activeStates 快取和 `TotemStatePool`

## UI/IconPool

輸入：

- 所需的圖示數量/class

輸出：

- 取得/released圖示框記錄
- 預熱非活動圖示以避免創建戰鬥中框架

狀態變更：

- 擁有框架、紋理、冷卻區域、FontStrings
- 框架創建應該在初始化期間或僅在受控增長期間發生
- 當池為空時，不得在戰鬥中創建新的圖標框架

## UI/Renderer

輸入：

- `IconRenderState`

輸出：

- 可見的UI狀態
- 佈局批次控制端點 (`Renderer.BeginBatch` / `Renderer.EndBatch`) 以延遲昂貴的 X/Y 佈局計算

狀態變更：

- 僅改變 UI 框架
- 從不取得aura/cooldown數據
- 控制所有昂貴的 UI 寫入
- 推遲戰鬥中的結構佈局變化和首次圖標獲取

## UI/Options

輸入：

- 活躍的個人資料
- 類別標記到類別 ID 映射表 (`CLASS_TOKEN_TO_ID`)

輸出：

- 透過 `SavedVariables` 配置變更
- 使用本機「GetSpecializationInfoForClassID(classID, specIndex)」和強大的靜態後備表進行動態、本地化專業化下拉過濾，確保 100% 本地化類別 /spec UI 文本，無需硬編碼
- 用於明確 add/remove 操作的最小遊戲內面板：
  - 玩家光環spellID
  - 目標光環spellID
  - 法術冷卻時間spellID
  - 物品冷卻時間itemID
- 用戶觸發變更成功後立即刷新服務

狀態變更：

- 僅 UI 小部件和明確配置值
- 如果正式服阻止或面臨受保護的 UI 變更的風險，則必須在戰鬥中延遲首次框架創建

## UI/Slash

輸入：

- `/eam` 指令文本

輸出：

- 設定操作、狀態文字、偵錯匯出請求
- 針對玩家光環、目標光環、法術冷卻時間和物品冷卻時間的簡單“/eam添加”和“/eam刪除”命令

狀態變更：
- 可呼叫模組API；不得直接編輯服務內部
- 僅透過「Core/SavedVariables」寫入持久警報配置

## Debug/DebugState

輸入：

- 模組狀態快照

輸出：

- 緊湊的`DebugSnapshot`
- 來自服務狀態的聚合邊界警告

狀態變更：

- 僅擁有瞬時除錯記錄

## Debug/PromptExport

輸入：

- `DebugSnapshot`
- 匯出模式：`debug-min`、`analysis-full`、`github-issue`

輸出：

- 類似 JSON 的緊湊文本

狀態變更：

- 除了瞬態字串產生器緩衝區之外沒有任何其他
## Debug/FlowTestRunner

輸入：

- 使用者或 Offline Harness 指定的 `quick/core/boundary/all` suite。
- EventRouter、Scheduler、SavedVariables、RuntimeProbe 公開 API。

輸出：

- 同步與非同步案例結果。
- `EAM_FLOW_VALIDATION_REPORT` schema 1 JSON。
- 最後一次 summary 與獨立 SavedVariable `EAM_FLOW_TEST_REPORT_JSON`。

狀態變更：

- 只擁有瞬時 test session 與最近報告。
- 離線案例可暫時替換 `EAM.db`／`EAM_DB`，但必須以 `pcall` 保證還原；不得寫入真實 SavedVariables。
- 不在背景或戰鬥中自動執行。

## Debug/FlowTestPanel

輸入：

- 使用者按鈕或 `/eam test`。
- FlowTestRunner report callback。

輸出：

- Quick／Core／Boundary／All 按鈕。
- 可複製 JSON 與本地化摘要。

狀態變更：

- 只擁有 lazy UI 與 pendingOpen。
- 戰鬥中不得首次建立；延後至 `PLAYER_REGEN_ENABLED`。

## Tests/FlowValidationHarness

輸入：

- Lua 5.1、suite 與輸出路徑。

輸出：

- 直接載入正式模組後的離線 JSON 報告與 exit code。

邊界：

- 不列入 TOC 或正式發布包。
- Mock 通過不得標記為 Retail／PTR 實機通過。

## 2026-07-26：Native Aura 模組契約

| 模組 | 輸入 | 輸出 | 禁止 |
| --- | --- | --- | --- |
| `AuraCapabilityService` | build/API surface | backend snapshot | 只看 TOC 判定 |
| `AuraRuleCompiler` | 純設定 DB | stable runtime plan | AuraData/UI |
| `AuraContainerService` | plan/revision | player/target containers | 戰鬥結構修改 |
| `NativeAuraRenderer` | AuraButton callback | 綁定 Regions | Aura 狀態推導 |
| `AuraSoundService` | sound rules | registration IDs | 讀 AuraData |

Native 模式與 `AlertManager`／一般 `Renderer` 的契約是「零 Aura state 事件」。

## 2026-07-27：Tooltip 監控 Popup 模組契約

| 模組 | 輸入 | 輸出 | 禁止 |
| --- | --- | --- | --- |
| `Services/TooltipMonitorService` | `GameTooltip` post-call、`MODIFIER_STATE_CHANGED`、EAM Popup action | 安全 ID 顯示、脫戰五秒 scalar candidate、action 白名單、SavedVariables 公開 API 呼叫、匿名狀態計數 | 儲存 TooltipData/AuraData/Frame、保留戰鬥候選、讀 UnitAura payload、Hook Blizzard 點擊、模擬右鍵 |
| `UI/TooltipMonitorMenu` | 服務提供的純 scalar candidate | 游標旁 EAM 自有視窗、監控類型按鈕、Aura／未解析 Macro 手動 ID | 直接寫 EAM_DB、secure action attribute、戰鬥中建立或顯示、保存 Blizzard frame |

Tooltip callback 的責任只到「追加文字與更新 candidate」，不可直接開啟 UI；戰鬥中只可追加安全文字，不可更新 candidate。儲存路由固定如下：Spell → spell cooldown；Item → item cooldown；Aura → 使用者選 player／target；Macro → 只提供已安全解析的 spell/item，未解析時由使用者輸入 ID 並選類型。EAM 自有按鈕透過其 `OnClick` script 提交；只有 `added`／`updated` 由正式 `Options.notifyConfigChanged()` 統一刷新五個下游，`unchanged` 不刷新。

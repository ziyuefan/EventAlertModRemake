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

## Locale/Common

輸入：

- `GetLocale()`、已載入的 `EAM_DB.config.language`、各 locale loader。

輸出：

- `EAM.Locale` catalog、固定英文 `Auto Detect` 選項、fallback/current 或手動語系合併後的 `EAM.L`。

狀態變更：

- 載入期、明確呼叫 `Locale.setSelection()` 或收到 `EAM_LANGUAGE_CHANGED` 時，原地清除／合併穩定 identity 的 `EAM.L`，再刷新已註冊文字；Locale 本身不寫 SavedVariables。
- `Locale.LanguageOptions` 是靜態選項表，可 freeze；catalog、`EAM.L`、widget binding registry 與 refresh callback registry 不得 freeze。
- `Locale.bindText()` 只註冊長生命週期 EAM 自有 widget；池化／釋放型 widget 必須在回收時呼叫 `Locale.unbindText()`，避免保留過期引用。

## UI/Options 語系選擇

- 下拉清單透過 `SavedVariables.updateLanguage()` 保存 `EAM_DB.config.language`，由自訂事件同步套用至目前載入中的 Locale。
- 主視窗、About、Module、Tooltip popup、Prompt export、Flow／Live、UnitPower 與 SVG 面板的固定文字使用 binding；下拉標籤、環境摘要與案例狀態等複合文字使用低頻 refresh callback 重算。
- 選擇後立即刷新 EAM 自有 UI，不呼叫 `ReloadUI()`。`Auto Detect` 在 zhTW 客戶端仍會選回繁體中文，這是預期行為；第一次換入含此功能的新程式仍需玩家自行 `/reload` 載入檔案。

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
- `EAM_DB.schemaVersion = 3`；`config.textLayout` 持有 timer／applications 的白名單位置與 8–32 字級。
- `updateTextLayout()` 對 no-op 回傳 `unchanged` 且不提高 revision；真實變更只提高一次。
- 遇到較新的未知 schema 時不得修改原始 `_G.EAM_DB`；只建立目前版本的 transient runtime defaults 並回報 `futureSchemaPreserved`，防止舊版覆寫新格式。

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

## UI/TextPlacement

輸入：

- `Data/TextPlacementContract.json` 對應的 21 個固定 placement ID。
- `EAM_DB.config.textLayout.timer/applications` 與字級。

輸出：

- 經白名單解析的 `point/relativePoint/x/y`。
- 僅對 EAM 自建 FontString 執行 `ClearAllPoints`、`SetPoint` 與 `SetFont`。

狀態變更：

- 不持有 runtime 狀態，不讀 AuraData／倒數文字／applications 原值。
- 執行期 Lua 映射必須與 `Data/TextPlacementContract.json` 由 `Tools/Test-ValidationContracts.ps1` 交叉驗證。

## UI/NativeAuraRenderer

- 只在 12.1 AuraButton `initializeFrame` 期間建立並完成 EAM 的 icon／cooldown／timer／applications／name 子元件；回呼結束後不追蹤、不重排也不修改已限制的按鈕。
- 不讀取 Native AuraButton 的受限文字或 Aura payload；文字位置／字級改變直接重套 EAM 自建 Region，戰鬥中只設 pending，於 `PLAYER_REGEN_ENABLED` 後回放，不重建 AuraContainer。
- 文字字級滑桿拖曳期間預覽一般 Renderer；`OnMouseUp`／`OnHide` 只提交一次 Native container rebuild。icon size／spacing、swipe alpha 與雙倒數診斷同樣每次手勢最多要求一次 rebuild。
- 12.0.7 通用 Renderer 與 12.1 Native renderer 共用 `UI/TextPlacement`，不得各自維護位置分支。

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
- `applyTextLayout()` 必須立即重套現有 EAM icon 的 timer／applications 位置與字級及 name 字級；戰鬥中只設 pending，於 `PLAYER_REGEN_ENABLED` 後回放。
- `layout()`、`requestLayout()`、render 內文字定位與移動模式遇戰鬥都不得執行 `SetPoint`／`SetSize`／`SetFont`，只能保留 dirty／blocked／pending 狀態。

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
- timer／applications 位置變更一次更新 SavedVariables，立即重套一般 icon 與脫戰 Native Region，不要求 container rebuild；字級 slider 拖曳則分為即時預覽與結束拖曳單次 Native reapply。
- icon size／spacing slider 拖曳期間只更新一般 layout，結束手勢才要求一次 Native 結構重建。

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

- 使用者或 Offline Harness 指定的 `quick/core/boundary/aura121/all` suite。
- EventRouter、Scheduler、SavedVariables、RuntimeProbe 公開 API。

輸出：

- 同步與非同步案例結果。
- `EAM_FLOW_VALIDATION_REPORT` schema 2 JSON，明列 `purpose`、`matrixVersion`、`executionSource` 與 client identity。
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
- 提供「真人實機簽收」入口，但不自動執行任何遊戲輸入。

狀態變更：

- 只擁有 lazy UI 與 pendingOpen。
- 戰鬥中不得首次建立；延後至 `PLAYER_REGEN_ENABLED`。

## Debug/ValidationEnvironment

- 將玩家宣告的 `_ptr_`、`_xptr_`、`_retail_` 與 `GetBuildInfo`、Interface 及三個原始 test-build 旗標交叉核對；報告同時保留 aggregate 與 `buildFlags`，不可只保留合併結果。
- 來源只能標記為 `ptr-live-manual`、`xptr-live-manual`、`retail-live-manual` 或 `offline-mock`；不由路徑猜測客戶端。
- mismatch／unconfirmed 必須寫入 `boundaryWarnings`，不得產生 pass。

## Debug/LiveTestSession 與 Debug/LiveTestPanel

- 依 `Data/LiveValidationMatrix.json` 管理 37 案玩家人工觀察、500 字元備註、`/reload` checkpoint 與 schema 1 JSON。
- 不施法、不使用物品、不執行巨集、不切換目標、不合成輸入、不呼叫 `ReloadUI`。
- start、案例狀態／備註、checkpoint、reload 恢復與 complete 的 session 寫入在戰鬥中一律回傳 `combatDeferred`。
- checkpoint 保存本次載入專屬 boot token；同次載入呼叫 resume 必須回傳 `sameLoadRejected`，只有玩家自行 `/reload` 後重建的 table identity 才能恢復。
- session 必須跨一次玩家自行執行的 `/reload`，37 案全 pass、test-build 身分已知且環境無警告，才可從 `active` 進入 `complete`；`active` phase 即使其餘條件齊全也只能輸出 `incomplete`。
- 備註中的絕對路徑、UNC、SavedVariables、WTF 與 Account 片段必須在 producer 先遮蔽；`Data/LiveValidationMatrix.json` 固定 `personalDataAllowed=false`。
- 離線 fixture 永遠維持 `incomplete`；匯入器另行重算摘要、矩陣與客戶端身分。

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
| `AuraContainerService` | plan／結構 fingerprint | player/target containers、pending／reloadRequired 狀態 | 戰鬥結構修改、單次載入建立超過 18 個容器 |
| `NativeAuraRenderer` | AuraButton callback | 綁定 Regions | Aura 狀態推導 |
| `AuraSoundService` | sound rules | registration IDs | 讀 AuraData |

Native 模式與 `AlertManager`／一般 `Renderer` 的契約是「零 Aura state 事件」。

## 2026-07-27：Tooltip 監控 Popup 模組契約

| 模組 | 輸入 | 輸出 | 禁止 |
| --- | --- | --- | --- |
| `Services/TooltipMonitorService` | `GameTooltip` post-call、`MODIFIER_STATE_CHANGED`、EAM Popup action | 安全 ID 顯示、脫戰五秒 scalar candidate、action 白名單、SavedVariables 公開 API 呼叫、匿名狀態計數 | 儲存 TooltipData/AuraData/Frame、保留戰鬥候選、讀 UnitAura payload、Hook Blizzard 點擊、模擬右鍵 |
| `UI/TooltipMonitorMenu` | 服務提供的純 scalar candidate | 游標旁 EAM 自有視窗、監控類型按鈕、Aura／未解析 Macro 手動 ID | 直接寫 EAM_DB、secure action attribute、戰鬥中建立或顯示、保存 Blizzard frame |

Tooltip callback 的責任只到「追加文字與更新 candidate」，不可直接開啟 UI；戰鬥中只可追加安全文字，不可更新 candidate。儲存路由固定如下：Spell → spell cooldown；Item → item cooldown；Aura → 使用者選 player／target；Macro → 只提供已安全解析的 spell/item，未解析時由使用者輸入 ID 並選類型。EAM 自有按鈕透過其 `OnClick` script 提交；只有 `added`／`updated` 由正式 `Options.notifyConfigChanged()` 統一刷新五個下游，`unchanged` 不刷新。

## 2026-08-09：About、監控 Tooltip 與分類邊框契約

| 模組 | 輸入 | 輸出 | 禁止 |
| --- | --- | --- | --- |
| `UI/AlertBorderStyles` | EAM 自有 alert type、靜態 `unit`、靜態 `auraFilter` | 七種固定 style key／RGBA；`classPower`、`totem` 回傳 nil | 讀取 UnitAura／AuraData、以 Secret 值作 table key、冒充 Blizzard dispel border |
| `UI/IconPool` | Renderer 提供的 alert state | 一般圖示分類邊框；脫戰 Spell／Item Tooltip | 把 `powerType`／totem slot 當 spellID、戰鬥中打開 Tooltip、鉤 Blizzard frame |
| `UI/NativeAuraRenderer` | compiler snapshot 的 `unit` 與 `filterString` | AuraButton 初始化期建立分類邊框；Tooltip 仍由 Blizzard AuraButton 管理 | `initializeFrame` 後新增或重排 Region |
| `UI/AboutPanel` | TOC metadata、GetBuildInfo、ValidationEnvironment 安全快照、Constants | EAM 版本、實際客戶端、API baseline、作者與專案 URL | 把靜態 API baseline 冒充目前客戶端 build、戰鬥中首次建立 frame |

固定分類為：自身 BUFF 青色、自身 DEBUFF 紅色、目標 BUFF 藍色、目標 DEBUFF 橘色、技能黃色、物品綠色、地面效果紫色。Aura 顏色只使用 SavedVariables／compiler 已知的 `unit` 與 `auraFilter`，不讀實際 Aura payload；`classPower` 與 `totem` 保留原有外觀。一般 Renderer 的監控 Tooltip 只在非戰鬥中顯示，Native AuraButton 則沿用 Blizzard Tooltip 與戰鬥隱藏契約。

## 2026-08-09：SVG 探針與 3px 邊框契約

| 模組 | 輸入 | 輸出 | 禁止 |
| --- | --- | --- | --- |
| UI/AlertBorderStyles | EAM 自有圖示 owner 與固定 3px padding | TOPLEFT -3/+3、BOTTOMRIGHT +3/-3 的完整外框 | 再使用含透明留白素材推估可見厚度 |
| Debug/SVGCapabilityProbe | 玩家宣告 client、固定內建 SVG、兩案目視結果 | VectorGraphics／Texture A/B 生命週期與分類 JSON | 自動操作遊戲、輸出 raw file ID、把離線 mock 當 PTR pass |
| Tools/Import-EAMFlowReport.ps1 | 明確提供的 JSON 或遊戲持久化報告 | schema、client identity、兩案 ID、interfaceRequired 與 status 重算 | 列舉私人目錄、信任報告自稱的 pass |

VectorGraphics 是 Region 能力，不等同 Texture；Texture 的 texcoord、rotation、mask 或 blend 能力不可直接假定在 VectorGraphics 存在。主法術／物品／Aura 圖示仍是動態 FileDataID，不改為 SVG。第一優先候選是 Pandemic 靜態提示區；Dispel CustomAsset／PreserveAsset 必須先補完整 asset map 或預載契約，不能把空 Texture 當已完成。

## 2026-08-12：小地圖 SVG 與 Theme 模組契約

| 模組 | 輸入 | 輸出 | 禁止 |
| --- | --- | --- | --- |
| UI/Theme | 靜態 palette、EAM 自有 frame／FontString／button registry、SavedVariables 的 theme | 十一套主題 palette、combat-deferred 套用結果、EAM 按鈕四態中性底圖與 2px 主題邊框 | 讀取 Secret Value、修改 Blizzard secure frame、覆蓋 AlertBorderStyles 語意色 |
| `UI/Options` minimap helper | EAM 自有小地圖 Texture、專案 SVG | `svg` 或 `fallback` 結果；保留原按鈕互動 | 使用聲音 FileDataID 當貼圖、依賴外部 wowtools 素材、戰鬥中改安全互動 |

Theme registry 只保存 EAM 自有 UI 物件的 weak-key reference；戰鬥中 `setSelection` 不立即改 frame，而是保存 pending 值，於 `PLAYER_REGEN_ENABLED` 後一次套用。小地圖 SVG 只作視覺素材降級，不參與 Aura、Cooldown、UnitPower 或 Secret 邏輯。

## 2026-08-13：AuraSound 細部設定與註冊契約

| 模組 | 輸入 | 輸出 | 禁止 |
| --- | --- | --- | --- |
| `Core/SavedVariables` | player／target Aura alert、三 trigger 純資料 | 正規化 sound、no-op revision、`EAM_AURA_SOUND_CHANGED` | 保存 registration ID、任意 trigger／非純資料 |
| `UI/Options` | Aura 細部設定、共用素材、三個 trigger checkbox | per-alert sound draft、素材試聽 | 在 12.0.7 呼叫 12.1 API、把試聽冒充 Aura 事件 |
| `Managers/AuraRuleCompiler` | 普通 unit／SpellID、全域 master、alert sound | `containerFingerprint`、`soundFingerprint`、sound rules | 讀 AuraData、讓 custom sound 繞過 master off |
| `Services/AuraContainerService` | container／sound fingerprint | 結構重建或純 sound sync | 純音效變更建立新容器、戰鬥中改結構 |
| `Services/AuraSoundService` | capability、靜態 sound rules | 交易式 active registry、retired removal retry | 讀 AuraData、序列化 ID、以 Remove 冒充停止已播放聲音 |

- Container fingerprint 只描述 AuraContainer 結構；Sound fingerprint 只描述 unit、SpellID、trigger、asset 與 channel。兩者分離是 18 容器配額的必要條件。
- 註冊先建立 candidate registry；任一 Add 失敗就清理 candidate 並保留舊 active registry。Remove 舊 ID 失敗時保留於 retired registry，之後重試或要求 `/reload`。
- PTR 12.1 的 `UnitAuraSoundInfo` 沒有 caster／auraFilter；`fromPlayer` 或 HELPFUL／HARMFUL 不能被 Native sound 精確表達，compiler 必須留下 limitation。
- C API 參數只取自 EAM 已正規化的普通 SavedVariables；禁止混入 AuraData、Secret value、frame、DurationObject 或 registration ID。
- 12.0.7 沒有一般 Aura 的三 trigger native backend；細部控制顯示 unsupported，保留設定且零 12.1 呼叫。

## 2026-08-13 Alpha 4：模組與 profile 邊界

| 模組 | 正式入口 | 保存資料 | 禁止 |
| --- | --- | --- | --- |
| Core/ModuleController | UI/ModulePanel、SavedVariables.updateModuleToggle | 八個 moduleToggles | 反覆註冊事件、讀取 Secret、戰鬥中重建 Native 結構 |
| Core/SavedVariables profile resolver | getActiveClassToken、getClassProfile、getAlertList | profiles.classes 與 v4 migration backup | 以 SpellArray 猜測歷史全域資料的職業歸屬 |
| Services/LegacyDiscoveryService | /eam list、lookup、lookupfull、showcast | 僅本次登入 cast candidates | 全域 SpellID 掃描、自動加入監控、序列化 Secret |
| UI/ModulePanel | 主設定的「功能模組」按鈕 | 不直接擁有設定 | 戰鬥中建立或重排 UIParent 結構 |

模組停用採 handler gate 加上既有狀態清理；事件仍只註冊一次。Native Aura、Ground duration scrape、ClassPower re-detect 與尚未建立的面板在戰鬥中延後至脫戰。JSON／Base64 profile codec 目前尚未納入正式服務契約，不能把 LegacyReference 匯入器當作新版 API。

## 2026-08-14 Alpha 5：Profile codec、字型與動態語系契約

| 模組 | 正式入口 | 輸出／保存 | 禁止 |
| --- | --- | --- | --- |
| Core/ProfileCodec | ProfileCodec.export、previewImport、applyImport | EAMAP1 canonical JSON／Base64、preview plan、bounded import backup | loadstring、任意 Lua、Secret 序列化、未知 schema／module、戰鬥中 apply |
| UI/ProfileCodecPanel | Options 的 Profile 匯入／匯出按鈕 | 手動 Ctrl+C 的 export／preview／merge／replace UI | 直接把 EditBox 內容當 Lua、未 preview 直接 replace |
| Core/SavedVariables font | 字型下拉與 updateFontFamily | config.fontFamily 四值白名單、no-op revision | 直接 mutate config、修改 Blizzard FontString |
| Locale／UI/Options | EAM_LANGUAGE_CHANGED registry | EAM 自有按鈕、下拉、條件、spec menu 即時刷新 | 快取未綁定的長生命週期文字、改寫 Blizzard 或案例固定繁中程序 |

Profile codec 的 checksum 只用於剪貼損壞偵測，不是安全簽章；apply 前必須重新檢查 plan fingerprint。字型與語系刷新只作用於 EAM 自有 UI，Native AuraButton 結構與戰鬥限制不因此放寬。

## 2026-08-14：Aura catalog、批次輸入與候選資料邊界

| 模組 | 輸入 | 輸出 | 禁止 |
| --- | --- | --- | --- |
| `UI/Options` Aura catalog | 玩家單筆或換行／分號批次 SpellID、目前職業 | `SELF`／`CROSS_CLASS` 路由、預設 `fromPlayer`、可複製目前清單 | 顯示不存在法術、把非本職候選偽裝成本職、逐筆增加 revision |
| `Core/SavedVariables` | 已驗證的 alert draft 與 deferred batch | active class profile、單次 revision/event | 寫根層 mirror、凍結使用者資料、接受未知 scope |
| `UI/ProfileCodecPanel` | EAMAP1 文字 | ScrollFrame viewport、固定 footer、preview/apply | 讓長文字覆蓋按鈕、自動剪貼簿、戰鬥中套用 |
| `Tools/fetch_wowhead_spells.py` | Wowhead 離線網頁候選 | `Data/wow_spells_and_auras.json` | 寫入 Docs、成為 TOC/runtime 依賴、把網頁資料冒充 live verified |
| `Tools/Test-WowheadCandidateData.ps1` | 唯一 Data JSON 與抓取腳本 | schema／totals／class14／路徑／runtime isolation gate | 自動批准錯置、PvP、被動或 Aura effect ID |

`catalogScope` 是資料治理標記，不改 Blizzard Secret／protected 邊界。Spellbook 不含所有 Aura effect ID，因此「不屬本職」只能作保守分類，不能由網頁候選自動刪除或升格為正式預設。

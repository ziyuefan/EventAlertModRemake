<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 正式服測試計劃

此文件通行證未執行任何即時正式服驗證。

## 固定驗證流水線

每次功能或架構變更依序執行：

1. Secret／taint／熱路徑／TOC 靜態限制掃描。
2. `Tools/CheckLuaSyntax.ps1`：Lua 5.1 語法。
3. `Tools/Run-FlowValidation.ps1 -Suite all`：離線 Mock 流程。
4. Retail／PTR 使用 `/eam test all` 或 Options「流程測試」按鈕。
5. `Tools/Import-EAMFlowReport.ps1`：將 JSON 或 WTF 報告回灌開發環境。

證據狀態必須分為靜態、語法、Mock、PTR、Retail。離線流程通過不能取代實機。

### 離線流程案例

- Main 初始化。
- EventRouter 自訂事件 round-trip 與 handler 清理。
- Scheduler 下一幀 callback 與 queue 歸零。
- SavedVariables schema／API 契約。
- Secret-safe scalar 普通值路徑。
- RuntimeProbe schema。
- JSON report round-trip。

詳細規格見 `Docs/26_FLOW_VALIDATION_FRAMEWORK.md`。

## 靜態檢查

- 確認僅正式服 TOC 處於活動狀態以進行重寫。
- 當針對 Retail 12.0.7 時，確認 TOC 介面為 `120007`。
- 確認未載入 Classic/MOP/Cata/Wrath/TBC 來源根。
- 搜尋意外的全域變數。
- 搜尋 `C_Timer.After(function`.
- 搜尋每幀/per-icon `SetScript("OnUpdate")`。
- 搜尋大型物品 ID 掃描循環。
- 搜尋應用於 SavedVariables 或運行時狀態的 `table.freeze`。
- 搜尋舊版 `UnitAura` 解包路徑。
- 搜尋舊的全域 `GetSpellCooldown` 解包假設。
- 在秘密檢查之前搜尋不安全光環`spellID`比較。
- 搜尋用作事實的 Cooldown 小部件 getter 讀回。
- 搜尋戰鬥中框架創建或佈局變更。
## 登入 / ReloadUI

- 在 Retail 12.x 中載入插件。
- 確認登入時沒有 Lua 錯誤。
- 確認SavedVariables遷移一次並保持可寫入。
- 確認「/reload」保留設定檔和位置。
- 確認已停用的警報保持停用狀態。

## 斜線指令

- `/eam opt` 開啟選項。
- 在影格存在之前在戰鬥中呼叫的「/eam opt」不應建立受保護的操作或污染錯誤。
- `/eam help` 列印指令摘要。
- `/eam add <spellID>` 新增玩家光環警報。
- `/eam add target <spellID>` 新增目標光環警報。
- `/eam add cd <spellID>` 新增法術冷卻時間警報。
- `/eam add item <itemID>` 新增物品冷卻警報。
- `/eam remove <spellID>` 刪除玩家光環警報。
- `/eam 刪除目標 <spellID>` 刪除目標光環警報。
- `/eam remove cd <spellID>` 刪除法術冷卻時間警報。
- `/eam 刪除物品 <itemID>` 刪除物品冷卻警報。
- `/eam export` 列印緊湊的提示/debug export。
- `/eam show` 切換自我光環 spellID 偵測。
- `/eam showt` 切換目標光環 spellID 偵測。
- `/eam showc` 切換強制轉換 spellID 偵測。
- `/eam showa` 是可選的並且顯然是可停止的。
- `/eam MiniMap` 切換小地圖選項按鈕。
- `/eam MiniMap Reset` 重設小地圖位置。
- `/eam SCDRemoveWhenCooldown`
- `/eam SCDNocombatStillKeep`
- `/eam SCDGlowWhenUsable`
- `/eam IconAppenSpellTip`
- `/eam ShowRunesBar`
- name/timer/stack 文字的字體大小指令。
- 新的除錯導出命令僅根據需要產生緊湊的輸出。

## 選項 UI 測試

- 使用「/eam opt」開啟脫離戰鬥的選項面板。
- 確認數字 ID 編輯框僅接受數字。
- 從面板中新增/remove玩家光環、目標光環、法術冷卻時間和物品冷卻時間條目。
- 確認每個成功的按鈕操作都會增加 SavedVariables 修訂版並刷新符合的服務。
- 確認無效或空 ID 顯示簡短的狀態訊息，而不會引發 Lua 錯誤。
- 確認關閉並重新開啟面板不會重複重新建立小工具。
- 在建立面板之前在戰鬥中打開“/eam opt”，並確認EAM列印一條延遲訊息而不是建構幀。
- 在面板已經存在後，在戰鬥中開啟“/eam opt”，並確認 show/hide 不會污染安全 UI 路徑。

## 玩家光環測試

- 透過 spellID 新增玩家增益並出現確認圖示。
- 透過「/eam add <spellID>」、「/reload」加入玩家增益，並確認其持續存在。
- 透過`/eam刪除<spellID>`刪除該buff並確認圖示隱藏。
- 透過 spellID 新增玩家減益並出現確認圖示。
- 確認堆疊計數更新。
- 確認計時器文字僅在安全時出現。
- 當duration/expiration不可用時，確認圖示保持穩定。
- 確認player/pet符合行為符合設定。
- 確認空閒時沒有高頻全掃描。
- 確認 `UNIT_AURA` 增量更新過程 `addedAuras`、`updatedAuraInstanceIDs` 和 `removedAuraInstanceIDs`。
- 當 `updateInfo` 為零或標記為完全更新時，確認完全更新回退仍然有效。
- 確認完整更新回退會針對每個相關過濾器掃描一次設備，並且不會針對每個配置的警報掃描一次。
- 確認完整掃描中未配置的光環警報被標記為非活動狀態。

## 目標光環測試

- 透過 spellID 新增目標 buff/debuff。
- 透過`/eam新增目標<spellID>`和`/eam刪除目標<spellID>`新增/remove目標光環。
- 快速改變目標。
- 明確的目標。
- 確認目標清除將所有配置的目標光環警報標記為非活動狀態。
- 進入/leave戰鬥並啟動目標警報。
- 確認陳舊的目標圖示已被刪除或標記為非活動狀態。
- 確認自身減益過濾有效。

## 法術冷卻測試

- 透過 spellID 加入法術冷卻時間。
- 施展法術並確認冷卻圖示/timer。
- 確認基於衝鋒的法術的衝鋒更新。
- 確認 GCD-only 冷卻時間不會錯誤地顯示為真實冷卻時間。
- 確認安全時可用的發光符合 `C_Spell.IsSpellUsable`。
- 確認沒有按法術計時器攪拌。

## 物品冷卻測試

- 增加直接 itemID 冷卻時間。
- 如果支持，請使用裝備的物品和庫存物品。
- 確認物品冷卻事件刷新。
- 確認預設未建置物品法術快取。
- 在戰鬥之外開始可選的快取建置。
- 確認快取在戰鬥中和低 FPS 下暫停。
## 戰鬥測試

- 使用主動 self/target/cooldown 警報進入戰鬥。
- 確認沒有受保護的操作錯誤。
- 確認 EAM 訊框更新不會產生污染/阻止操作錯誤。
- 確認不安全的資料會降級而不是崩潰。
- 確認如果池在戰鬥中耗盡，則首次圖示創建將被推遲。
- 確認延遲版面配置在 `PLAYER_REGEN_ENABLED` 之後刷新。
- 確認戰鬥中沒有開始大量緩存建置。
- 確認戰鬥結束後運行非戰鬥刷新。

## 正式服 12.0.7/午夜 API 測試

- 確認 `C_DurationUtil.CreateDurationTextBinding` 存在並確定它是否有利於 EAM 計時器標籤。
- 2026-05-29 PTR 注意：使用者確認最小 `C_DurationUtil.CreateDurationTextBinding` 範例在 12.0.7 PTR 用戶端中正常顯示。
- 確認`C_DurationUtil.CreateManualClock`存在且不需要不安全的Lua倒數使用。
- 確認 EAM 不會呼叫已刪除的 `C_DurationUtil.GetCurrentTime`。
- 確認 `GetEventCPUUsage`、`GetFunctionCPUUsage` 和 `GetScriptCPUUsage` 僅適用於 debug/profiling 指令，不適用於執行時間熱路徑。
- 確認靜態表上的 `table.freeze` / `table.isfrozen` 行為，並驗證 SavedVariables/runtime 狀態沒有被凍結。
- 確認「冷卻：SetCooldownFromDurationObject()」適用於 EAM 僅顯示計時器狀態。
- 確認 `FontString:ClearText()` 清除文本，沒有污染或過時的秘密文本問題。
- 確認未來的 EAM `DurationTextBinding` 適配器保留綁定引用，在回收圖示時停用 /releases 它，並在 API 不可用時安全回退。

## 本地化測試

- enUS 載入。
- zhTW 僅載入並包含繁體中文字串。
- zhCN/koKR/ruRU 舊字串如果保留，將保持隔離。
- 遺失的語言環境字串安全回退。

## 偵錯匯出測試

- `debug-min` 輸出包括環境、事實、衍生計數和警告。
- `analysis-full` 輸出包含緊湊的每個警報狀態。
- `github-issue` 輸出排除大量日誌和敏感的僅限本地的混亂。
- 導出不會自動運作。
- `/eam 匯出` 包含資料庫修訂、aura 快取計數、渲染器可見/deferred 計數和邊界警告計數。

## 2026-07-26：12.1 Aura 驗證矩陣

- 離線入口：`Tools/Run-FlowValidation.ps1 -Suite aura121`；全回歸使用 `-Suite all`。
- 嚴格 mock 會拒絕未知 AuraContainer/AuraButton 方法，並計數 legacy getter、Slot/Group mutation 與 Sound ID。
- 遊戲內入口：`/eam test aura121` 或流程面板「12.1 Aura」。
- 必須在 `_ptr_` 實測 player Slot、target Slot、多 Aura Group、原生倒數、Tooltip、三種 Sound trigger、戰鬥 pending、taint/forbidden action。
- 離線 pass 不得替代 RQA PTR 簽收；詳細清單見 `Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`。

## 2026-07-27：Tooltip ID／Popup 流程驗證矩陣

- 離線入口沿用 `Tools/Run-FlowValidation.ps1 -Suite boundary`；全回歸使用 `-Suite all`，不新增獨立測試按鈕。遊戲內沿用流程面板「邊界流程」與 JSON 報告回灌。
- `tooltip_monitor.capability`：四種 post-call 各只註冊一次；重複 initialize 不得增加 callback；必須載入真正的 Popup frame，且按鈕必須綁定 `OnClick`；12.1 必須成功啟用 `tooltipShowAuraSpellIDs`。
- `tooltip_monitor.offline_spell_item_routes`：真 Popup 顯示精確 ID／action，透過 `button:Click()` 分派 `OnClick` 後寫入隔離 DB；`added` 必須走正式 `Options.notifyConfigChanged()` 的 AuraContainer／Aura／Cooldown／ItemCooldown／Renderer 五個下游，第二次 `unchanged` 不增加 revision 或刷新。
- `tooltip_monitor.offline_macro_resolution`：`TooltipData.id` 放入錯誤值，安全 `GetAction` 路徑須解析並實際提交 spell/item；非 `GetAction` 來源須以手動 ID 分別提交 spell/item。
- `tooltip_monitor.offline_aura_manual_route`：Secret TooltipData 欄位讀取次數必須為零；真 Popup 以普通數字分別提交 player／target Aura；CVar 能力關閉時 Tooltip 與 Popup 必須使用手動已知 ID 提示。
- `tooltip_monitor.offline_fail_closed`：callback 當下、戰鬥開窗、戰鬥中 hover 後出戰重播、EditBox 焦點、Tooltip 類型變更、Tooltip 隱藏、五秒逾時、額外 Shift／Meta、缺 Ctrl／Alt 均不得開啟；同類型連續候選必須取最後一筆。
- `tooltip_monitor.offline_secret_scalars`：Secret spell、macro、manual 與 action 必須零算術、零字串化、零 table-key 操作、零 SavedVariables 寫入；受監控 table proxy 必須先自證能攔截 Secret key。
- `tooltip_monitor.offline_db_isolation`：隔離 DB 與五下游 spy 在 callback 成功及刻意拋錯兩路都必須還原原 reference。
- `runtime_probe.schema`：建立已知候選後序列化完整 snapshot 並建立人類可讀 lines，兩種輸出都不得出現候選 ID，狀態只能含匿名計數。
- 每個寫入案例以獨立 DB 執行並在 `pcall` 後還原 `EAM.db`／`EAM_DB`，不可用 remove 動作污染 revision 來清理測試。
- 2026-07-28 最終離線結果：`boundary` 10/10（`TestResults/EAM_FlowValidation_boundary_20260728_120708.json`）；`all` 24/24（`TestResults/EAM_FlowValidation_all_20260728_120708.json`）。第一次真 Popup 測試因未重新產生已消耗的 candidate 而 7/9，失敗報告 `TestResults/EAM_FlowValidation_boundary_20260727_042850.json` 保留追溯；中間通過報告亦保留。
- `_ptr_` 實機：分別懸停 Spellbook、Action Bar Macro、Bag Item、player/target Aura；核對 ID 行、Ctrl+Alt Popup 位置、ESC／取消、added／unchanged、ReloadUI 後 CVar 重設、戰鬥拒絕、無 blocked action／taint／Forbidden 錯誤。
- `_xptr_` 12.0.7 實機：Spell／Item／Macro 路由仍須工作；Aura 官方 CVar 若不存在，Tooltip／Popup 必須明示手動已知 ID，不得回退讀 AuraData。
- 明確驗證原 Blizzard 行為未被攔截：一般左／右鍵操作與未按修飾鍵時應完全維持客戶端原行為。
- 補測同型 Tooltip 快速切換的 generation／owner、初始化時 Tooltip API 暫缺、`/reload`／LoD，以及 Popup 開啟後立即進戰；離線 mock 不得替代這些 PTR 時序與 taint 證據。

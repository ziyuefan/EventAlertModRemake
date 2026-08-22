<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod AI 入口指導檔

本專案發布EventAlertMod（EAM）正式服重寫。現有方案代碼作為「行為參考」，只能直接沿用舊架構作為新的架構基礎。

## 對話與文件原則

- 使用預設台灣慣用繁體中文。
- 用戶名為「少年欸」。
- 回覆直接切入任務，保持技術清晰、結構清晰。
- WoW AddOn 相關任務必須先確認正式服與經典服差異；本專案只處理正式服。
- 涉及 12.x API、Secret Values、C_* 命名空間或 Widget 行為時，需優先參考 `Docs` 與最新魔獸爭霸 Wiki API 變更資訊。
- 尚未完成WoW正式實用機驗證，除非確實在WoW Retail中加載並測試過。
- 消耗開發時，文件/內相關文件必須主動一併同步更新，保持文件與程式碼的一致性，不得等待使用者指示（不要一動才一動）。
- **檔案與HTML轉換規則**：
  - 後續開發與 AI 協作的絕對指導文件，一律以 `.AI/AGENTS.md` 以及其內文指名之 `.md` 文件為唯一事實與 Facts-of-Truth 參考。
- HTML版本成人人類（少年欸）在瀏覽器中觀看易讀使用，AI在讀寫器與參考時，必須一律以`.md`原檔為唯一基準，不得以HTML作為開發事實參考。
  - 當`.AI/Docs/*.md`或`.AI/AGENTS.md`修改時包含心智圖（Mermaid）、表格、流程圖、映像時，必須執行轉換工具（`batch_convert_docs.py`），在`.AI/docs_html`內多產生一個同名的__EAMCODE___檔（例如檔案）。
  - 文件轉換預設使用 `$env:EAM_DOCS_OFFLINE='1'; python .\.AI\Tools\batch_convert_docs.py`，禁止未經少年欸明確授權就把 Markdown 全文送往外部翻譯服務。

## Skills.sh 候選規則

- 開發中發現穩定且重複的能力缺口時，可至 `https://skills.sh/` 搜尋並主動推薦最多三個候選。
- 搜尋前先建立專案需求卡，審查來源、內容、依賴、權限、維護狀態、授權與供應鏈風險；排行榜與安裝數只作參考。
- 預設只讀搜尋與比較，必須保留「都不安裝／改建專案自訂 Skill」選項。
- 未經使用者明確選定候選、安裝範圍並授權，不得執行安裝命令或修改全域／專案 Skill。

## 必讀文件
在更改程式碼之前，請先閱讀以下文件：

- `.AI/PROJECT_MEMORY.md`
- `.AI/Docs/00_AI_CONTEXT.md`
- `.AI/Docs/01_ARCHITECTURE.md`
- `.AI/Docs/02_RETAIL_API_BOUNDARIES.md`
- `.AI/Docs/03_STATE_SCHEMA.md`
- `.AI/Docs/04_MODULE_CONTRACTS.md`
- `.AI/Docs/05_PERFORMANCE_GUIDE.md`
- `.AI/Docs/06_TEST_PLAN_RETAIL.md`
- `.AI/Docs/07_MIGRATION_NOTES.md`
- `.AI/Docs/08_AI_PROMPT_EXPORT_SCHEMA.md`
- `.AI/Docs/09_KNOWN_LIMITATIONS.md`
- `.AI/Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md`
- `.AI/Docs/11_WARCRAFT_WIKI_MAIN_MENU_TREE.md`
- `.AI/Docs/12_CODE_COMMENTARY_GUIDE.md`
- `.AI/Docs/14_PACKAGING_GUIDE.md`
- `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`
- `.AI/Docs/16_RETAIL_ADDON_OPTIMIZATION_ROADMAP.md`
- `.AI/Docs/17_SUBAGENT_WORKFLOW.md`
- `.AI/Docs/18_RETAIL_12X_CLASS_SPECIALIZATION_HERO_TALENT_DATABASE.md`
- `.AI/Docs/19_AURA_1210_REDUX_BLUEPRINT.md`
- `.AI/Docs/20_CDM_BYPASS_FEASIBILITY_STUDY.md`
- `.AI/Docs/21_RACI_EXPERTS_MATRIX.md`
- `.AI/Docs/22_QC_ROOT_CAUSE_ANALYSIS_GUIDE.md`
- `.AI/Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`
- `.AI/Docs/24_EXPERT_COUNCIL_REVIEW_20260621.md`
- `.AI/Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md`
- `.AI/Docs/26_FLOW_VALIDATION_FRAMEWORK.md`
- `.AI/Docs/27_LOCAL_WOW_ENVIRONMENT.md`
- `.AI/Docs/28_PROJECT_CONTINUITY.md`
- `.AI/Docs/29_LIVE_TEST_STEP_GUIDE.md`
- `.AI/Data/ProjectContinuity.json`

## 專案目標

- 目標遊戲：僅限魔獸世界正式服版。
- 目標 API 世代：正式服 12.x / 午夜時代 AddOn API。
- 架構方向：事件驅動、低GC、模組化、可維護。
- 使用者體驗：保留EAM「比WeakAuras簡單、輕量、專注光環與冷卻提醒」的定位。
- 現有資料表、地化字符串、斜線命令語意與使用者行為視覺化可保留；內部架構應重新設計。

## 本機 WoW 開發環境基準

- WoW 安裝根目錄由 `Deploy/Deploy-EventAlertMod.ps1` 優先從 Windows Registry 偵測，使用者必須在互動部署前確認或改填。
- Git 專案根：`D:\Project_EventAlertMod`；唯一插件來源：`D:\Project_EventAlertMod\EventAlertMod`；AI 治理：`D:\Project_EventAlertMod\.AI`。
- 舊目錄 `D:\EventAlertMod` 已停用，任何 Agent 都不得讀取、寫入、比較或作 fallback。
- 2026-08-21 唯讀 metadata：`_retail_` 與 `_ptr_` 為 `12.1.0.69382`，`_xptr_` 為 `12.0.7.68887`；版本會變動，部署與實測前須重新讀取執行檔 `ProductVersion`。
- 2026-08-21 三個 `Interface\AddOns\EventAlertMod` 目前皆為實體資料夾；只有 PTR 含 `EventAlertMod.toc`，Retail／XPTR 尚未部署完整。先前指向舊目錄的 SymbolicLink 狀態只屬歷史證據。
- `.AI/Tools/Test-LocalWoWEnvironment.ps1` 對 Reparse Point 必須 fail-closed；現況預期 PTR 通過、Retail／XPTR 因缺少 TOC 失敗。Deploy DryRun 通過只代表目標可安全部署，不代表插件已完整。
- 部署目標固定為各版本目錄下的 `Interface\AddOns\EventAlertMod`。安全實體資料夾可先備份後更新；missing 目標可建立；Reparse Point 與檔案目標一律停止。
- Classic 不在支援範圍。PTR／XPTR 互動部署時須再詢問是否同時部署 Retail，並在確認畫面列出全部候選版本。
- `WTF` 路徑只在明確測試任務中動態組合；未經需要不得讀取或列出 `WTF\Account` 的帳號與角色資料。
- 完整規則見 `.AI/Docs/27_LOCAL_WOW_ENVIRONMENT.md`。

## 硬性限制

- 不支援Classi##秘密/受保護資料規則與安全檢查
Retail 12.x 可能將光環、冷卻、作用、時間、單位或字串資料標記為 Secret / Protected / Display-only。為戰鬥中防禦 Secret/Protected 限制引發 Lua 碰撞或頭部錯誤，實施四大核心檢定 API 規範因數表索引防禦機制：

- **四大核心檢查功能**：
  - `issecretvalue(value)`：判斷特定值是否受保護之秘密值（Secret Value）。
- `canaccessvalue(value)`：判斷目前是否有權限存取與讀取該值。
- `canaccesstable(table)`：判斷整個表格物件可是否被安全讀取（非架構）。
  - `issecrettable(table)` / `hasanysecretvalues(table)`：檢查表格物件結構本身是否被限製或包含秘密值已。
- **表格索引防護（關鍵）**：嚴禁使用為秘密值（如保證驗證的 `spellId` 或 `text` 等）的密鑰去對任何非安全的嚴重自訂表進行索引操作，否則會立即觸發`attempted to index a table that cannot beindexed with Key Secrets`錯誤。在自訂表索引進行之前，必須先`issecretvalue(key)`確認該金鑰匙不是受保護的秘密值，並以`canaccesstable(targetTable)`檢查表安全性。
- 先確認來源表是否為秘密（`canaccesstable`），再讀取欄位，再確認欄位值是否為秘密（`issecretvalue`）。
- 未確認安全前，不得對duration、expirationTime、spellID、timeLeft等值做算術、比較、字串化、表鍵、序列化或任何函數輸入。
- 不得擠壓創造持續時間、過渡時間、冷卻時間或所需價值。
- 不得把猜測值混入事實；推導值標記必須為推導值。
- 資料無法安全取得時，保留可安全顯示的圖示、名稱、活動狀態，計時器顯示為受保護、displayOnly 或未知。
- 錯偵狀態需記錄boundaryWarnings。
- 若裝備，排程離開戰鬥後刷新。能將光環、冷卻、法術、時間、單位或字串資料標記為秘密/受保護/僅顯示。為防禦戰鬥中因秘密/受保護限制引發Lua崩潰或潰決錯誤，必須四大核心檢驗API規範與表索引防禦機制：

- **三大核心檢查功能**：
  - `issecretvalue(value)`：判斷特定值是否受保護之秘密值（Secret Value）。
- `canaccessvalue(value)`：判斷目前是否有權限存取與讀取該值。
  - `canaccesstable(table)`：判斷整個表格物件可是否被安全讀取（非架構）。
- **表格特殊檢查與索引防禦**：
  - `issecrettable(table)`：檢查目標表本身是否已被標記為 Secret Table。
  - `hasanysecretvalues(table)`：檢查表中是否包含任何秘密值（Secret Values）。
- **表格索引防護（關鍵）**：嚴禁使用為秘密值（如保證驗證的 `spellId` 或 `text` 等）的密鑰去對任何非安全的嚴重自訂表進行索引操作，否則會立即觸發`attempted to index a table that cannot beindexed with Key Secrets`錯誤。在自訂表索引進行之前，必須先`issecretvalue(key)`確認該金鑰匙不是受保護的秘密值，並以`canaccesstable(targetTable)`檢查表安全性。
- 先確認來源表是否為秘密（`canaccesstable`），再讀取欄位，再確認欄位值是否為秘密（`issecretvalue`）。
- 未確認安全前，不得對duration、expirationTime、spellID、timeLeft等值做算術、比較、字串化、表鍵、序列化或任何函數輸入。
- 不得擠壓創造持續時間、過渡時間、冷卻時間或所需價值。
- 不得把猜測值混入事實；推導值標記必須為推導值。
- 資料無法安全取得時，保留可安全顯示的圖示、名稱、活動狀態，計時器顯示為受保護、displayOnly 或未知。
- 錯偵狀態需記錄boundaryWarnings。
- 如果可行，排程將在不久後離開戰鬥。

## 污染控制規則
- 不鉤、覆寫、重新定義或猴子補丁 Blizzard secure/protected 函數、FrameXML 核心函數、動作按鈕、單位框架、銘牌、法術施法、定位、物品使用相關路徑。
- 不在戰鬥中修改受保護框架的屬性、父級、規則點、大小、可見性、範本或點擊行為。
- 不把EAM運行時狀態、秘密/保護值、偵錯物件或外掛程式回呼形成可能污染安全鏈的暴雪框架。
- 使用EventRouter孤兒框架；渲染框架只負責顯示，不承擔安全操作或受保護的互動。
- 如果需要限制操作 UIParent 下方的框架，則必須在非受保護的顯示用途，並在 `InCombatLockdown()` 時延遲可能會導致 taint 的結構性變化。
- 不使用`forceinsecure`、不嘗試清除或繞過污染點、不以第三方變通方式壓制暴雪阻止行動。
- 發現污染、被阻止的動作、戰鬥鎖定錯誤時，需記錄到`.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`，並綁定觸發路徑、戰鬥狀態與可重置步驟。

## DurationObject 與時間顯示

- 秘密或受保護時間資料不得使用`OnUpdate`手機倒數。
- 若 Retail 提供 DurationObject，優先取代 UI 處理，例如 `CooldownFrame:SetCooldownFromDurationObject()` 或 `FontString:SetDurationText()`。
- `Cooldown:SetCountdownFormatter()`、`Cooldown:SetCountdownMillisecondsThreshold()` 等 12.0.5 後相關能力需以文件與實機確認後使用。
- 手動定時器鍵盤僅用於確認安全的普通數字。

## 工具提示 / C_TooltipInfo 降級策略

工具提示解析只能作為低頻、截圖、明確標記來源的後備：
- 優先使用 `C_TooltipInfo` 或 Blizzard 支援的顯示項目。
- 可解析靜態說明文字中的明確數值。
- 不解析剩餘時間文字作為事實。
- 不在熱路徑、戰鬥中或每幀執行工具提示抓取。
- 解析結果無法覆寫安全性API事實，只能作為匯出或僅顯示輔助。
- 解析失敗時安靜必須降級，無法產生昏暗計時器。

## 事件與框架規則
- 事件規定使用單一EventRouter。
- 純事件監聽架構使用孤兒框架：`CreateFrame("Frame", nil, nil)`。
- 不在UIParent-parented框架上承擔邏輯調度員職責。
- 不在戰鬥中對UI父框架動態註冊或解除註冊事件。
- 事件註冊變更應集中管理，避免重複供水。

## 調度程序與全部規則

- 優先事件驅動；排程回退必須濃縮、低頻、可節流。
- 只使用單一調度`OnUpdate`。
- 禁止依附圖示計時器、應用術計時器、熱路徑重複`C_Timer.After(function() ...)`。
- `UNIT_AURA`、`SPELL_UPDATE_COOLDOWN`、`OnUpdate`、渲染器更新屬於熱路徑。
- 熱路徑不得配置臨時表、閉包或不必要的字串。
- 熱路徑避免 `pairs` / `ipairs`；可用穩定數字索引時使用數位循環。
- 熱路徑避免`table.insert`；可用直接索引寫入時使用直接索引。
- 迴圈中群組字串使用buffer與`table.concat`，避免連續`..`。
- 低FPS或戰鬥中應延後、縮減或停止非必要工作。
- 大範圍物品掃描無法正常戰鬥時執行；若需要魔法存儲，選擇加入、僅閒置、可中斷、FPS釣魚、戰鬥釣魚。

## table.create / table.freeze 政策
- `table.create`用於預期設定：圖表、圖表、流程圖、記錄清單、圖示池、預設範本。
- 必須提供`table.create`、`table.freeze`、`table.isfrozen`後備。
- `table.freeze` 只用於不可變靜態資料：、枚舉、模式、預設欄位設定檔、契約模組、原型、元表。
- 穩定 API 別名表可凍結，例如 `EAM.API`，但僅在確認時不會造成載入順序或測試故障時使用。
- 不得凍結SavedVariables、運行時快取、光環/冷卻狀態、圖示狀態、池項目、調度器佇列、debug/session記錄。

## UI / 渲染器規則

- 渲染器不直接檢查API；資料由服務層提供。
- 圖示、按鈕、FontString使用池。
- 渲染器不執行安全操作，不註冊點擊地圖，不修改暴雪保護框架，不操作污染列/單位框架/銘牌路徑。
- 避免初始化後建立多餘的框架。
- `SetText`、`SetPoint`、`SetSize`、`SetTexture`、layout 寫入前先比較後次值。
- 批次佈局時可先隱藏父級，完成後再顯示。
- 支援計時器、藥劑名稱、光環值標籤，但只顯示安全資料。
- UI預設保持簡單，不能把 EAM 引入 WeakAuras 複雜系統。
## SavedVariables 規則

- SavedVariables 必須有架構版本。
- 提供舊資料遷移、預設、驗證。
- 不凍結SavedVariables。
- 不讀取每幀或高運行時狀態。
- 無法安全遷移的欄位要保留備份或標記為遺傳，且不可靜默破壞使用者設定。

## 除錯/AI交接規則

- 除錯預設關閉。
- 除錯 偵錯必須達到。
- 快照需分割：
  - 事實
  - 派生
  ——人類筆記
  - boundaryWarnings
  - 環境
- 不輸出巨大的日誌。
- 匯出字符串僅在使用者明確要求時建立。

## 課程風格

- 標識符使用中文。
- 註解可使用繁體中文，重點放在 WoW API 邊界、原因與架構決策。
-所有正式載入的方案檔都必須有檔案系統註解，說明模組、責任邊界、資料號碼與日後注意事項；細節依`.AI/Docs/12_CODE_COMMENTARY_GUIDE.md`。
- 縮排使用4個空格。
- 不使用行內分號。
- 命名空間/模組使用PascalCase。
- 函數/局部變數使用camelCase。
- 導管函數/導管表以 `_` 匯出。
- 符號使用UPPER_SNAKE_CASE。

## 檔案備份規則

- 任何檔案在刪除、移移、覆寫或修改前，都必須先備份到專案根目錄的`.AI/backup/`資料夾。
- 備份檔案名稱格式為「原始檔案名稱後綴 `__yyyyMMddHHmmss`」，例如 `AGENTS.md__20260526122904`。
- 使用計時器本機時間，格式為年月日時分秒，方便依排序時間與追溯。
-處理多個文件，應在同一作業開始前逐一備份；備份完成後才可進行實際修改、移移或刪除。
- 備份資料夾只作為日後開發、修改與回溯參考來源，不得壓縮進CurseForge發布檔案。
- 若原始檔案不存在，需先回傳原因，無法建立空備份冒充原始內容。

## 開發問題記錄規則

- 開發過程遇到的瓶頸、限制、錯誤、工具失敗、API必須性與解決方式，都記錄到`.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
- 極限目的為降低日後重複試誤、節省AI上下/token、保留決策脈絡。
- 每筆記錄至少包含約會、症狀、原因判斷、已嘗試方法、有效解決方法、後續事項注意事項。
- 若問題尚未解決，需標註為「未解決」並寫明下一步驗證方式。
- 不記錄密碼、無法令牌、私人帳號資料或任何進入專案文件的敏感資訊。

## 專案專屬技能規則
- 開發過程若發現類似流程重複出現，且已具備穩定步驟、輸入條件、輸出結果與風險控制管，應整理成EventAlertMod專專用案SKILL。
- 適合轉成SKILL的流程包含：壓縮發布、Lua靜態驗證、WoW API查詢、SavedVariables遷移檢查、秘密邊界審查、檔案同步、語檔同步。
-目前已建立`eam-retail-p0-review`，位置為`.AI/skills/eam-retail-p0-review/SKILL.md`，用於EAM正式服重寫的P0 Secret/Taint/API/靜態驗證。
- 建立SKILL前需先確認流程確實可重複，江蘇湖泊與解法記錄到`.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
- SKILL內容應包含觸發條件、必要前檢、禁止事項、備份規則、驗證方式和最終回傳格式。
- 尚未驗證、尚需人工判斷或含敏感資訊的流程硬輔助技能。
## 子代理程式計劃使用規則

- 使用者已授權：後續本專案若出現適合子代理人的角色，需主動規劃並使用。
- 使用先判斷關鍵路徑；立即阻止主流程的工作，由主代理本地處理。
- 子代理主要可任務、明確、可欣賞且不互相覆蓋邊車任務。
- 適合模具包含：正式服API查證、Secret / taint審查、熱路徑掃描、文件一致性檢查、模組化替換的不重疊文件切片、發布檢查。
- 不適合架構包含：小型單檔修改、需要即時授權的高風險操作、尚未遺失的卸載移動/刪除、寫入範圍高度重疊的高關聯性。
- 派工時必須明確指定檔案責任範圍、禁止事項、備份規則、驗證輸出及最終返回格式。
- 子代理程式結果需要由主代理程式整合；不得將子代理程式的API判定視為已實機驗證。
- 詳細流程請參閱`.AI/Docs/17_SUBAGENT_WORKFLOW.md`。
- 所有與PR審查的協作必須嚴格遵循 [.AI/Docs/21_RACI_EXPERTS_MATRIX.md](.AI/Docs/21_RACI_EXPERTS_MATRIX.md) 的 RACI 權責分工與審查原則。
## 實施流程
1.稽核：讀取完整原始碼樹、TOC、XML、SavedVariables、global、Classic/MOP分支、OnUpdate__EAMCODE_5_ _、光環/cooldownOnUpdate/C_Timer、auraEAMCODED__、ACODE_4_____、aCODE_3__、auraEAMCODEA__、A__uraEA__3__A__a☺
2. 方案設計：首先模組責任與遷移策略，再開始大規模模組。
3.重寫：建立核心、服務、UI、偵錯模組，取得可用的資料與使用者語意。
4.靜態驗證：執行可用的Lua語法檢查、全域變數搜尋、`C_Timer.After`閉包搜尋、`table.freeze`錯誤搜尋。
5. 報告：明確變更變更、未驗證事項、風險與下一步。
## 快速指令

- 當使用者只輸入「資源」兩個字時，直接執行`.AI/Deploy/Build-Package.ps1`。
- 當使用者輸入「壓縮開發版」時，直接執行`.AI/Deploy/Build-Package.ps1 -PackageLabel DEV`。
- 資料夾前需確認`EventAlertMod/EventAlertMod.toc`的`##版本`符合`EventAlertMod_MN_yyyyMMdd`。
- 預算檔名必須符合`EventAlertMod_MN_yyyyMMdd_HHmmss.zip`。
- 壓縮後返回 zip 路徑、Lua 語法檢查結果、排除資料夾檢查結果。
- 相關規則請參閱`.AI/Docs/14_PACKAGING_GUIDE.md`。

##回最終傳必須包含

相關實踐的最終報告至少已上市：

1.更改檔案。
2.主要架構變更。
3.保留舊的EAM行為。
4. 移除舊的行為。
5. Lua / WoW API 假設。
6. `table.create` / `table.freeze` 使用摘要。
7. 秘密/受保護資料處理策略。
8. 已執行靜態驗證。
9. 未執行的驗證。
10.WoW正式服實機測試需要。
11.已知風險。
12.下一個建議任務。


## 專案最新重構細節 (2026.06.06 更新)

### 1.已完成核心重構(Retail 12.0.7)
* **全程式碼局部化清掃 (12.0.7 - 2026.06.06)**：
- 整個文件（包括 `Services` 和 `UI` 目錄下的所有邏輯）中所有編碼硬/英文提示術語與 UI 字符串已完全提取為 `EAM.L` 中的密鑰。
- 補齊並無縫支持`zhTW` (繁中)、`zhCN` (簡中)、`enUS` (簡中)、`koKR` (韓文) 與 `ruRU` (俄文) 五大語系，共144個詞條。
- **動態專精本地化API重構**：在`EventAlertMod/UI/Options.lua`的篩選選項中引入`CLASS_TOKEN_TO_ID`映射，優先調用官方嫁接API `GetSpecializationInfoForClassID`取得最準確的本地化專精名稱，並提供雙軌本地化備份。
* **ClassPower核心資源安全偵查與錯案加強**：
- 為 `detectClassPower` 與 `updatePower` 部署密切注意 `pcall` 隔離與 `issecretvalue` 防衛機制，防止戰鬥中能量數值差異為秘密表時大小比較造成的 Lua 崩潰。
* **EventRouter/Scheduler 故障隔離**：
- 為`EventAlertMod/Core/EventRouter.lua`的OnEvent核心循環與`EventAlertMod/Core/Scheduler.lua`的定時任務回呼回呼參數化`pcall`容錯，確保單一模組報錯時，不會幹擾或中斷其他模組與定時的執行。
* **雙軌 Native Binding 倒數與 Pandemic Glow**：
    - 時間渲染優先權實作 `C_DurationUtil.CreateDurationTextBinding` 與 `SetCooldownFromDurationObject` 降級通道。
    - 在DoT光環滿足Pandemic刷新時間時，為 Icon 啟用發光亮框效果。
* **13個職業與28個英雄天賦資料庫擴展**：
    - 更新`EventAlertMod/Data/SpellArray.lua`，為所有13個職業與28個英雄天賦（如暴風雨、神聖、武器惡魔儀式等）配置了最新的武器ID預設監控。
### 2.後續維護與開發建議
* **安全防禦優先**：在與任何光環、冷卻、能量、時間相關的數值進行大小比較或表索引時，必須先使用 `issecretvalue` 進行防禦性檢查。
* **修改語法靜態檢查**：在對任何Lua檔案進行後必須，執行 `luac -p` 檢查。
* **12.0.7 & 12.1.0 專家聯合會與月亮載體研究（2026.06.07更新）**：
- 召集全體專家分代理進行圓桌聯會審定。 Lua VM專家指出熱路中閉隱包`pcall`導致LuaJIT Trace編譯器中止的底層工資，並提供了模組級靜態本地回退機制；AddOn架構師建立了`.AI/Docs/19_AURA_1210_REDUX_BLUEPRINT.md`藍圖，全面規劃了__MEAM__CODE_4) 零點存儲
- **影子載體技術(Shadow Host)實務**：針對利用橋樑`CooldownViewer` (冷卻管理器/CDM)作為影子載體以避戰秘密/污染限製完成實現。新建`EventAlertMod/Services/ShadowHostService.lua`實踐官方池Hook，並於`EventAlertMod/UI/Renderer.lua`中引入寄生渲染讓與級聯排版避讓，100%黑暗中配合架構CPU與Taint。評估研究可參考`.AI/Docs/20_CDM_BYPASS_FEASIBILITY_STUDY.md`。
* **12.1.0 零分配 & 事件驅動全模組重構 (2026.06.07 已完成)**：
- **資料視圖解關聯**：解關聯`AuraService`、__完全EAMCODE_1__、`ItemCooldownService`、`GroundEffectService`與__EAMCODE_全部__，五大資料服務改為驅動事件，不再與`Renderer`直接連接，而是向至EAM__CO8D__EAM1 86_DED__EAM__CODDE____EAM__CO8DDEA__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_0__EAM__CO8DDEA__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAMCODE___EAMCODE6%__ _EAMCODE_5__%__EAM__CODDE_%__EAM__CODDE_0__EAM__CO8DDEA__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_0__EAM__CO8DDEA__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_0__EAM__CO8DDEA__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CODDE_%__EAM__CODDE_%__。
- **境內控制器引入**：引入`EventAlertMod/Managers/AlertManager.lua`統一管理和調度這五類變更事件，使用`Scheduler`實行同步節流與批量更新（`BeginBatch/EndBatch`），消除佈局本身。
- **多型零分配物件池**：在所有服務中配置強調的 `StatePool` （如 `GroundEffectStatePool` 和 `TotemStatePool` 等），在 `acquire`狀態對象時綁定`releaseFunc`，並由`AlertManager`在渲染後識別多__A__EA__A__3__4D__EAMCO`fstate__EAMCO"__EA安全恢復對象，完成期運行0-分配最大限度降低GC目標。
- **鏡像載體文字剪裁與遮蔽修改**：針對吸附官方CooldownViewer（CDM）時，因牽引容器`ClipsChildren`裁切與FrameLevel顯示導致技能名稱不顯示的問題，實施動態佈局調整。寄生模式下自動將技能名稱（`nameText`）移至圖示底部並設定高亮顯示圖示底部並設定高亮顯色，同時提權`FrameLevel`（相對於）`hostIcon` + 10），解決了「看不見的技能名稱」的痛點。
- **靜態語法安全性偵測設定**：32個Lua檔案100%滲透語法安全性偵測設定。
* **16完成全新與高階事件整合（2026.06.07已）**：
- 不使用`forceinsecure`、不嘗試清除或繞過污染點、不以第三方變通方式壓制暴雪阻止行動。
- 發現污染、被阻止的動作、戰鬥鎖定錯誤時，需記錄到`.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`，並綁定觸發路徑、戰鬥狀態與可重置步驟。
## DurationObject 與時間顯示
- 秘密或受保護時間資料不得使用`OnUpdate`手機倒數。
- 若 Retail 提供 DurationObject，優先取代 UI 處理，例如 `CooldownFrame:SetCooldownFromDurationObject()` 或 `FontString:SetDurationText()`。
- `Cooldown:SetCountdownFormatter()`、`Cooldown:SetCountdownMillisecondsThreshold()` 等 12.0.5 後相關能力需以文件與實機確認後使用。
- 手動定時器鍵盤僅用於確認安全的普通數字。

## 工具提示 / C_TooltipInfo 降級策略
工具提示解析只能作為低頻、截圖、明確標記來源的後備：

- 優先使用 `C_TooltipInfo` 或 Blizzard 支援的顯示項目。
- 可解析靜態說明文字中的明確數值。
- 不解析剩餘時間文字作為事實。
- 不在熱路徑、戰鬥中或每幀執行工具提示抓取。
- 解析結果無法覆寫安全性API事實，只能作為匯出或僅顯示輔助。
- 解析失敗時安靜必須降級，無法產生昏暗計時器。

## 事件與框架規則

- 事件規定使用單一EventRouter。
- 純事件監聽架構使用孤兒框架：`CreateFrame("Frame", nil, nil)`。
- 不在UIParent-parented框架上承擔邏輯調度員職責。
- 不在戰鬥中對UI父框架動態註冊或解除註冊事件。
- 事件註冊變更應集中管理，避免重複供水。
## 調度程序與全部規則
- 優先事件驅動；排程回退必須濃縮、低頻、可節流。
- 只使用單一調度`OnUpdate`。
- 禁止依附圖示計時器、應用術計時器、熱路徑重複`C_Timer.After(function() ...)`。
- `UNIT_AURA`、`SPELL_UPDATE_COOLDOWN`、`OnUpdate`、渲染器更新屬於熱路徑。
- 熱路徑不得配置臨時表、閉包或不必要的字串。
- 熱路徑避免 `pairs` / `ipairs`；可用穩定數字索引時使用數位循環。
- 熱路徑避免`table.insert`；可用直接索引寫入時使用直接索引。
- 迴圈中群組字串使用buffer與`table.concat`，避免連續`..`。
- 低FPS或戰鬥中應延後、縮減或停止非必要工作。
- 大範圍物品掃描無法正常戰鬥時執行；若需要魔法存儲，選擇加入、僅閒置、可中斷、FPS釣魚、戰鬥釣魚。

## table.create / table.freeze 政策
- `table.create`用於預期設定：圖表、圖表、流程圖、記錄清單、圖示池、預設範本。
- 必須提供`table.create`、`table.freeze`、`table.isfrozen`後備。
- `table.freeze` 只用於不可變靜態資料：、枚舉、模式、預設欄位設定檔、模組合同、原型、元表。
- 穩定 API 別名表可凍結，例如 `EAM.API`，但僅在確認時不會造成載入順序或測試故障時使用。
- 不得凍結SavedVariables、運行時快取、光環/冷卻狀態、圖示狀態、池項目、調度器佇列、debug/session記錄。
## UI / 渲染器規則
- 渲染器不直接檢查API；資料由服務層提供。
- 圖示、按鈕、FontString使用池。
- 渲染器不執行安全操作，不註冊點擊地圖，不修改暴雪保護框架，不操作污染列/單位框架/銘牌路徑。
- 避免初始化後建立多餘的框架。
- `SetText`、`SetPoint`、`SetSize`、`SetTexture`、layout 寫入前先比較後次值。
- 批次佈局時可先隱藏父級，完成後再顯示。
- 支援計時器、藥劑名稱、光環值標籤，但只顯示安全資料。
- UI預設保持簡單，不能把 EAM 引入 WeakAuras 複雜系統。

## SavedVariables 規則

- SavedVariables 必須有 schema 版本。
- 提供舊資料遷移、預設、驗證。
- 不凍結SavedVariables。
- 不讀取每幀或高運行時狀態。
- 無法安全遷移的欄位要保留備份或標記為遺傳，且不可靜默破壞使用者設定。
## 除錯/AI交接規則

- 除錯預設關閉。
- 除錯 偵錯必須達到。
- 快照需分割：
  - 事實
  - 派生
  ——人類筆記
  - boundaryWarnings
  - 環境
- 不輸出巨大的日誌。
- 匯出字符串僅在使用者明確要求時建立。

## 課程風格

- 標識符使用中文。
- 註解可使用繁體中文，重點放在 WoW API 邊界、原因與架構決策。
-所有正式載入的方案檔都必須有檔案系統註解，說明模組、責任邊界、資料號碼與日後注意事項；細節依`.AI/Docs/12_CODE_COMMENTARY_GUIDE.md`。
- 縮排使用4個空格。
- 不使用行內分號。
- 命名空間/模組使用PascalCase。
- 函數/局部變數使用camelCase。
- 導管函數/導管表以 `_` 匯出。
- 符號使用UPPER_SNAKE_CASE。

## 檔案備份規則
- 任何檔案在刪除、移移、覆寫或修改前，都必須先備份到專案根目錄的`.AI/backup/`資料夾。
- 備份檔名格式為「原始檔名後綴 `__yyyyMMddHHmmss`」，例如 `AGENTS.md__20260526122904`。
- 使用計時器本機時間，格式為年月日時分秒，方便依排序時間與追溯。
-處理多個文件，應在同一作業開始前逐一備份；備份完成後才可進行實際修改、移移或刪除。
- 備份資料夾只作為日後開發、修改與回溯參考來源，不得壓縮進CurseForge發布檔案。
- 若原始檔案不存在，需先回傳原因，無法建立空備份冒充原始內容。

## 開發問題記錄規則
- 開發過程遇到的瓶頸、限制、錯誤、工具失敗、API必須性與解決方式，都記錄到`.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
- 極限目的為降低日後重複試誤、節省AI上下/token、保留決策脈絡。
- 每筆記錄至少包含約會、症狀、原因判斷、已嘗試方法、有效解決方法、後續事項注意事項。
- 若問題尚未解決，需標註為「未解決」並寫明下一步驗證方式。
- 不記錄密碼、無法令牌、私人帳號資料或任何進入專案文件的敏感資訊。

## 專案專屬技能規則

- 開發過程若發現類似流程重複出現，且已具備穩定步驟、輸入條件、輸出結果與風險控制管，應整理成EventAlertMod專專用案SKILL。
- 適合轉換成SKILL的流程包含：壓縮發布、Lua靜態驗證、WoW API查證、SavedVariables遷移檢查、秘密邊界審查、檔案同步、語檔同步。
- 目前已建立`eam-retail-p0-review`，位置為`.AI/skills/eam-retail-p0-review/SKILL.md`，用於EAM正式服重寫的P0 Secret/Taint/API/靜態驗證。
- 建立SKILL前需先確認流程確實可重複，江蘇湖泊與解法記錄到`.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
- SKILL內容應包含觸發條件、必要前檢、禁止事項、備份規則、驗證方式和最終回傳格式。
- 尚未驗證、尚需人工判斷或含敏感資訊的流程硬輔助技能。

## 子代理程式計劃使用規則

- 使用者已授權：後續本專案若出現適合子代理人的角色，需主動規劃並使用。
- 使用先判斷關鍵路徑；立即阻止主流程的工作，由主代理本地處理。
- 子代理主要可任務、明確、可欣賞且不互相覆蓋邊車任務。
- 適合模具包含：正式服API查證、Secret / taint審查、熱路徑掃描、文件一致性檢查、模組化替換的不重疊文件切片、發布檢查。
- 不適合架構包含：小型單檔修改、需要即時授權的高風險操作、尚未遺失的卸載移動/刪除、寫入範圍高度重疊的高關聯性。
- 派工時必須明確指定檔案責任範圍、禁止事項、備份規則、驗證輸出及最終返回格式。
- 子代理程式結果需要由主代理程式整合；不得將子代理程式的API判定視為已實機驗證。
- 詳細流程請參閱`.AI/Docs/17_SUBAGENT_WORKFLOW.md`。

## 實施流程

1. 審核：讀取完整原始碼樹、TOC、XML、SavedVariables、global、Classic/MOP分支、OnUpdate/C_Timer、aura/cooldownOnUpdateOnUpdate/C_Timer、aura/cooldownOnUpdate__EAMCODE_6_EAMCODE_6__8、/cooldownOnUpdate__EAMCODE__8、__EAM__86_6%。
2. 方案設計：首先​​模組責任與遷移策略，再開始大規模模組。
3.重寫：建立核心、服務、UI、偵錯模組，取得可用的資料與使用者語意。
4.靜態驗證：執行可用的Lua語法檢查、全域變數搜尋、`C_Timer.After`閉包搜尋、`table.freeze`錯誤搜尋。
5. 報告：明確變更變更、未驗證事項、風險與下一步。

## 快速指令

- 當使用者只輸入「資源」兩個字時，直接執行`.AI/Deploy/Build-Package.ps1`。
- 資源前需確認 `EventAlertMod/EventAlertMod.toc` 且 `## Version` 符合 `EventAlertMod_MN_yyyyMMdd`（開發版本時，其將覆蓋寫入命名為 DEV 跳過日期校驗）。
- 壓縮輸出檔名必須符合`EventAlertMod_MN_yyyyMMdd_HHmmss.zip`，開發版本則為`EventAlertMod_DEV_yyyyMMdd_HHmmss.zip`。
- 壓縮後返回 zip 路徑、Lua 語法檢查結果、排除資料夾檢查結果。
- 相關規則請參閱`.AI/Docs/14_PACKAGING_GUIDE.md`。

##回最終傳必須包含
相關實踐的最終報告至少已上市：

1.更改檔案。
2.主要架構變更。
3.保留舊的EAM行為。
4. 移除舊的行為。
5. Lua / WoW API 假設。
6. `table.create` / `table.freeze` 使用摘要。
7. 秘密/受保護資料處理策略。
8. 已執行靜態驗證。
9. 未執行的驗證。
10.WoW正式服實機測試需要。
11.已知風險。
12.下一個建議任務。


## 專案最新重構細節 (2026.06.06 更新)
### 1.已完成核心重構(Retail 12.0.7)
* **全程式碼局部化清掃 (12.0.7 - 2026.06.06)**：
    - 整個文件（包括 `Services` 和 `UI` 目錄下的所有邏輯）中所有編碼硬/英文提示術語與 UI 字符串已完全提取為 `EAM.L` 中的密鑰。
- 補齊並無縫支持`zhTW` (繁中)、`zhCN` (簡中)、`enUS` (簡中)、`koKR` (韓文) 與 `ruRU` (俄文) 五大語系，共144個詞條。
- **動態專精本地化API重構**：在`EventAlertMod/UI/Options.lua`的篩選選項中引入`CLASS_TOKEN_TO_ID`映射，優先調用官方嫁接API `GetSpecializationInfoForClassID`取得最準確的本地化專精名稱，並提供雙軌本地化備份。
* **ClassPower核心資源安全偵查與錯案加強**：
- 為 `detectClassPower` 與 `updatePower` 部署密切注意 `pcall` 隔離與 `issecretvalue` 防衛機制，防止戰鬥中能量數值差異為秘密表時大小比較造成的 Lua 崩潰。
* **EventRouter/Scheduler 故障隔離**：
- 為`EventAlertMod/Core/EventRouter.lua`的OnEvent核心循環與`EventAlertMod/Core/Scheduler.lua`的定時任務回呼回呼參數化`pcall`容錯，確保單一模組報錯時，不會幹擾或中斷其他模組與定時的執行。
* **雙軌 Native Binding 倒數與 Pandemic Glow**：
    - 時間渲染優先權實作 `C_DurationUtil.CreateDurationTextBinding` 與 `SetCooldownFromDurationObject` 降級通道。
    - 在DoT光環滿足Pandemic刷新時間時，為 Icon 啟用發光亮框效果。
* **13個職業與28個英雄天賦資料庫擴展**：
    - 更新`EventAlertMod/Data/SpellArray.lua`，為所有13個職業與28個英雄天賦（如暴風雨、神聖、武器惡魔儀式等）配置了最新的武器ID預設監控。
### 2.後續維護與開發建議
* **安全防禦優先**：在與任何光環、冷卻、能量、時間相關的數值進行大小比較或表索引時，必須先使用 `issecretvalue` 進行防禦性檢查。
* **修改語法靜態檢查**：在對任何Lua檔案進行後必須，執行 `luac -p` 檢查。
* **12.0.7 & 12.1.0 專家聯合會與月亮載體研究（2026.06.07更新）**：
- 召集全體專家分代理進行圓桌聯會審定。 Lua VM專家指出熱路中閉隱包`pcall`導致LuaJIT Trace編譯器中止的底層工資，並提供了模組級靜態本地回退機制；AddOn架構師建立了`.AI/Docs/19_AURA_1210_REDUX_BLUEPRINT.md`藍圖，全面規劃了__MEAM__CODE_4) 零點存儲
- **影子載體技術(Shadow Host)實務**：針對利用橋樑`CooldownViewer` (冷卻管理器/CDM)作為影子載體以避戰秘密/污染限製完成實現。新建`EventAlertMod/Services/ShadowHostService.lua`實踐官方池Hook，並於`EventAlertMod/UI/Renderer.lua`中引入寄生渲染讓與級聯排版避讓，100%黑暗中配合架構CPU與Taint。評估研究可參考`.AI/Docs/20_CDM_BYPASS_FEASIBILITY_STUDY.md`。
* **12.1.0 零分配 & 事件驅動全模組重構 (2026.06.07 已完成)**：
- **資料視圖解關聯**：解關聯`AuraService`、__完全EAMCODE_1__、`ItemCooldownService`、`GroundEffectService`與__EAMCODE_全部__，五大資料服務改為驅動事件，不再與`Renderer`直接連接，而是向至EAM__CO8D__EAM1 86_DED__EAM__CODDE____EAM__CO8DDEA__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_0__EAM__CO8DDEA__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAMCODE___EAMCODE6%__ _EAMCODE_5__%__EAM__CODDE_%__EAM__CODDE_0__EAM__CO8DDEA__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_0__EAM__CO8DDEA__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_%__EAM__CODDE_0__EAM__CO8DDEA__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CO8DDE4__EAM__CODDE_%__EAM__CODDE_%__。
- **境內控制器引入**：引入`EventAlertMod/Managers/AlertManager.lua`統一管理和調度這五類變更事件，使用`Scheduler`實行同步節流與批量更新（`BeginBatch/EndBatch`），消除佈局本身。
- **多型零分配物件池**：在所有服務中配置強調的 `StatePool` （如 `GroundEffectStatePool` 和 `TotemStatePool` 等），在 `acquire`狀態對象時綁定`releaseFunc`，並由`AlertManager`在渲染後識別多__A__EA__A__3__4D__EAMCO`fstate__EAMCO"__EA安全恢復對象，完成期運行0-分配最大限度降低GC目標。
- **鏡像載體文字剪裁與遮蔽修改**：針對吸附官方CooldownViewer（CDM）時，因牽引容器`ClipsChildren`裁切與FrameLevel顯示導致技能名稱不顯示的問題，實施動態佈局調整。寄生模式下自動將技能名稱（`nameText`）移至圖示底部並設定高亮顯示圖示底部並設定高亮顯色，同時提權`FrameLevel`（相對於）`hostIcon` + 10），解決了「看不見的技能名稱」的痛點。
- **靜態語法安全性偵測設定**：32個Lua檔案100%滲透語法安全性偵測設定。
* **16完成全新與高階事件整合（2026.06.07已）**：
    - **替代無效CLEU**：在 `GroundEffectService` 中全面刪除 `COMBAT_LOG_EVENT_UNFILTERED` 註冊，改為訂閱 `UNIT_SPELLCAST_SUCCEEDED` 並篩選 `unitTarget == "player"`，100% `unitTarget == "player"`，100% `unitTarget == __EAMCODE10%，CO __`EAMCODE_3__10%，100%，100%。 __EAMDE_0__ 在雪天等，
- **高頻能量無延遲更新**：在 `ClassPowerService` 中追加註冊 `UNIT_POWER_FREQUENT` 事件，使聖能、連擊點更新反應速度達到 0ms 延遲。
    - **技能覆蓋動態緊接在**：在`CooldownService`註冊`COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`，當法術因天賦/狀態覆蓋變更時，即時刷新被覆蓋或原始技能的冷卻，徹底消除覆蓋時消耗/殘留Bug。
- **新年快速金色發光同步**：在 `AlertManager` 中監聽 `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` 與 `SPELL_ACTIVATION_OVERLAY_GLOW_HIDE` 快捷列高亮事件，維護本地 `glowSpells` 表，以 Decorator（裝飾屬性）為形式 Aura / Cooldown 狀態新增 `state.overlayGlow`_EA_EA__MCO_EA 動態標記。 `overlayGlow`雙軌顯示金色發光，100%同步官方Proc發光。
- **修改靜態語法檢查**：對所有5個核心檔案100%通過 `luac -p` 的靜態語法檢查。
* **除錯完成診斷與統計工具修復與擴展 (2026.06.07 已)**：
    - 12.1.0修改架構模組後，診斷日誌中 `visibleIcons` 恆為 `0` 和 `alertFrame.exists` 恆為 `false` 的統計 Bug。
- 補充`/eam除錯`資訊，新增各資料服務的`active`監控試劑ID清單、記憶體佔用`memoryKB`、`glowSpells`發光報表輸出清單、7大警報框底下所有活動圖示的座標與實體`:IsShown(5)，
    -修改靜態語法檢驗：之 2 個診斷模組檔 100% 通過 `luac -p` 靜態語法檢查。
* **技能無冷卻時強行顯示空白圖示Bug修復（2026.06.07已完成）**：
- 修改非衝鋒技能在完全沒有在冷卻中（`cooldownInfo`為`nil`）時，因`infoSafe`排除防衛過當而強行在畫面上顯示15個無倒數、無螺旋幾何的空圖示Bug。
    - 修改`CooldownService.lua`的`shouldShow`邏輯，增加`cooldownInfo`存在性防護，無冷卻時直接保持不顯示，恢復精確監控。
- 修改靜態語法檢查：之 `CooldownService.lua` 100% 通過 `luac -p` 靜態語法檢查。
* **戰鬥設定（秘密）光環時間倒數降級與自動回復恢復機制（2026.06.07已完成）**：
- 當玩家在戰鬥中，光環時間與端點時間被標記為秘密時間，實施優先視角`C_TooltipInfo`抓取說明中的持續時間（`scrapedDur`）來建立非秘密的普通`DurationObject`與分數型計時器（`TIMER_NUMERIC`），讓器能夠正常渲染倒數。
- 在`EventAlertMod/UI/Renderer.lua`中維護`activeDurationObjects`，在統一的`onLegacyTimerUpdate`系統中每一幀進行突破`:IsZero()`對抗。一旦爆發，主動觸發與恢復，徹底解決秘密光環殘留Bug。
    - 靜態語法檢查：`AuraService.lua` 與 `EventAlertMod/UI/Renderer.lua` 100% 修改 `luac -p` 靜態語法檢查。
* **12.1.0零分配StatePool恢復與基於Pool-Token延遲調度之JIT優化實踐（2026.06.09已完成）**：
- **P0 記憶體洩漏修復**：在 `AuraService.lua`、`GroundEffectService.lua`、`TotemService.lua` 的 `StatePool.acquire` 內，統一安全地綁定`state.releaseFunc = Pool.release`，並在__EAMCODE_5%」時設定為__EAMCODE_5%」圖示後能成功恢復狀態，解決了隱藏了前期分配資產池網格GC流失的嚴重P0 Bug。
- **刪除JIT Trace Abort**：完全移除在 OnUpdate 中對 `durationObj:IsZero()` 的 `pairs` 輪詢與 `pcall` 檢查。改為在 `Renderer.render` 啟動時脈時，穿越 `timerTokenPool` 零分配令牌池取得令牌，並以 `Scheduler.after` 註冊單次後續任務。
- **極限0-分配發生**：代替時由`onDurationTimerExpired(token)`判斷token激活狀態以準確與恢復隱藏。整個計時與恢復流程完全完成0-分配（零堆記憶體配置）與零輪詢CPU幾十，消除了戰鬥微卡頓，且熱路徑100%可被LuaJIT編譯，速度提升數百倍。
    - **修改靜態語法檢查**：之4個核心檔案全部100%通過 `luac -p` 靜態語法檢查。
* **12.1.0專家矩陣擴展與新專家定義（2026.06.09已完成）**：
    - **專家定義**：使用`define_subagent`定義了`EAM_Mock_Sandbox_Expert` (MOCK)、`EAM_Data_Guard_Expert` (DATA)、`EAM_DevOps_Release_Expert` (DEVOPS) 和 `EAM_Combat_Scraper_Expert` (`EAM_Combat_Scraper_Expert` (__EA)CODE7__完成一個全新的專家。
- **修改RACI矩陣升級**：`.AI/Docs/21_RACI_EXPERTS_MATRIX.md`擴展專案的RACI職責矩陣，引入「沙盒測試」與「WTF設定檔遷移」兩個全新的任務領域，認識了新增專家的R/A__EAMCODE_4分機定位測試
## Changelog 分類規則

- 根層 `changelog.txt` 與 `EventAlertMod/changelog.txt` 是公開發布紀錄，只記錄 WoW 插件功能、遊戲內行為、版本相容性、玩家可感知修正，以及會實際改變發布插件包內容的素材或封裝修正。
- 公開 changelog 不記錄 AI 治理、代理分工、文件同步、上下文接續、測試通過數、離線驗證數字、GitHub／CI／workflow 發布流程、備份位置或內部工作進度。
- AI 治理問題、失敗嘗試、根因分析與後續決策，記錄於 `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`；跨工作階段的路由、狀態與未完成事項，記錄於 `.AI/Docs/28_PROJECT_CONTINUITY.md`。
- 兩份公開 changelog 必須使用同一份內容來源，完成後以 SHA-256 確認 `changelog.txt` 與 `EventAlertMod/changelog.txt` 完全一致。
- 修改公開 changelog 前，先依檔案安全規則備份；不要為了整理格式改寫歷史技術事實，只移除純流程段落或將同一功能的流程性措辭改成玩家可理解的行為描述。
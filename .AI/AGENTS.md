<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod AI 入口指導檔

本專案為 EventAlertMod（EAM）正式服現代化重構。既有舊架構代碼僅作為「業務行為參考」，嚴禁直接沿用舊架構代碼作為新系統基礎。

## 對話與文件原則

- 預設使用台灣慣用繁體中文（zh-TW）。
- 稱呼使用者為「少年欸」。
- 回覆直接切入任務，保持技術精確、架構清晰。
- WoW AddOn 相關任務必須先確認正式服與經典服差異；本專案唯一支援目標為正式服（Retail 12.x / 午夜 Midnight），不支援經典服（Classic）。
- 涉及 12.x API、Secret Values、C_* 命名空間或 Widget 行為時，需優先參考 `Docs` 與最新 Warcraft Wiki API 變更資訊。
- 尚未在 WoW Retail 中實際加載並測試過的功能，嚴禁宣稱已完成實機驗證。
- 進行開發時，程式碼與相關文檔必須主動同步更新，保持文檔與代碼一致性（主動出擊，不得被動等待指示）。
- **檔案與 HTML 轉換規則**：
  - 後續開發與 AI 協作的絕對指導文件，一律以 `.AI/AGENTS.md` 以及其內文指名之 `.md` 原始檔為唯一事實與 Facts-of-Truth 參考。
  - HTML 版本供人類（少年欸）在瀏覽器中觀看易讀使用，AI 在讀取、檢索與參考時，必須一律以 `.md` 原始檔為唯一基準，嚴禁以 HTML 作為開發事實參考。
  - 當 `.AI/Docs/*.md` 或 `.AI/AGENTS.md` 修改包含心智圖（Mermaid）、表格、流程圖、圖片時，必須執行轉換工具（`batch_convert_docs.py`），在 `.AI/docs_html/` 內產出同名的 HTML 檔。
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
- `.AI/Docs/30_PLAYER_RESOURCE_REFACTOR_REPORT.md`
- `.AI/Docs/31_TAKEOVER_UNDERSTANDING_BASELINE_20260823_200615.md`
- `.AI/Docs/32_EAM_SKILL_ECOSYSTEM_AND_PHILOSOPHY.md`
- `.AI/Docs/33_AI_GOVERNANCE_DIRECTIVE.md`
- `.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml`
- `.AI/Data/ProjectContinuity.json`

## 專案目標

- 目標遊戲：僅限魔獸世界正式服（World of Warcraft Retail）。
- 目標 API 世代：正式服 12.x / 午夜時代（Midnight）AddOn API。
- 架構方向：事件驅動、極限零分配（Zero-Allocation）、低 GC、模組化、高可維護性。
- 使用者體驗：保留 EAM「比 WeakAuras 簡單輕量、專注光環與冷卻提醒」的核心定位。
- 既有資料表、在地化字串、斜線命令語意與直覺視覺化予以保留；內部系統架構徹底現代化重構。

## 本機 WoW 開發環境基準

- WoW 安裝根目錄由 `Deploy/Deploy-EventAlertMod.ps1` 優先從 Windows Registry 偵測，使用者必須在互動部署前確認或改填。
- Git 專案根：`D:\Project_EventAlertMod`；唯一插件來源：`D:\Project_EventAlertMod\EventAlertMod`；AI 治理：`D:\Project_EventAlertMod\.AI`。
- 舊目錄 `D:\EventAlertMod` 已停用，任何 Agent 都不得讀取、寫入、比較或作 fallback。
- 2026-08-21 唯讀 metadata：`_retail_` 與 `_ptr_` 為 `12.1.0.69382`，`_xptr_` 為 `12.0.7.68887`；版本會變動，部署與實測前須重新讀取執行檔 `ProductVersion`。
- 部署目標固定為各版本目錄下的 `Interface\AddOns\EventAlertMod`。安全實體資料夾可先備份後更新；missing 目標可建立；Reparse Point 與檔案目標一律停止。
- WoW 各客戶端的 `Interface\AddOns\EventAlertMod` 若為 SymbolicLink／Junction／Reparse Point，任何部署或清理都必須立即停止；不得追蹤、覆蓋、刪除或重建連結（fail-closed 防禦）。
- Classic 不在支援範圍。PTR／XPTR 互動部署時須再詢問是否同時部署 Retail，並在確認畫面列出全部候選版本。
- `WTF` 路徑只在明確測試任務中動態組合；未經授權不得讀取或列出 `WTF\Account` 的帳號與角色資料。
- 🚨 部署腳本異動通報義務：若因應需求修改 `Deploy/` 目錄下任何腳本，必須主動明確向少年欸報告具體改動內容。
- 完整規則見 `.AI/Docs/27_LOCAL_WOW_ENVIRONMENT.md`。

## 硬性限制與邊界

- 不支援 Classic 經典服。
- 嚴禁直接繼承或複製舊 EAM 的架構邏輯。

## 秘密/受保護資料規則與安全檢查 (Secret & Protected Values)

Retail 12.x 可能將光環、冷卻、作用、時間、單位或字串資料標記為 Secret / Protected / Display-only。為防禦戰鬥中因 Secret/Protected 限制引發 Lua 報錯或崩潰（Fatal Error / Crash），必須落實四大核心檢驗 API 規範與表索引防禦機制：

- **四大核心檢查函式**：
  - `issecretvalue(value)`：判斷特定數值是否為受保護之秘密值（Secret Value）。
  - `canaccessvalue(value)`：判斷當前環境是否有權限存取與讀取該值。
  - `canaccesstable(table)`：判斷整個 Table 物件是否可被安全讀取（非受保護架構）。
  - `issecrettable(table)` / `hasanysecretvalues(table)`：檢查 Table 物件結構本身是否受限或包含秘密值。
- **表格索引防護（關鍵）**：嚴禁使用可能為秘密值（如未經驗證的 `spellId` 或 `text` 等）作為 Key 去對任何非安全自訂表進行索引操作，否則會立即觸發 `attempted to index a table that cannot be indexed with Key Secrets` 致命錯誤。在自訂表索引操作前，必須先以 `issecretvalue(key)` 確認該 Key 不是秘密值，並以 `canaccesstable(targetTable)` 確保目標表安全性。
- 先確認來源表是否安全（`canaccesstable`），再讀取欄位，最後確認欄位值是否安全（`issecretvalue`）。
- 未確認安全前，不得對 duration、expirationTime、spellID、timeLeft 等數值進行算術運算、比較大小、字串串接、表鍵索引、序列化或傳入外部未防護函式。
- 嚴禁捏造或臆測（fabricate/invent）持續時間、過渡時間、冷卻時間或關鍵數值。
- 不得把猜測值混入事實；推導值必須明確標記為推導值（Derived）。
- 資料無法安全取得時，保留可安全顯示的圖示、名稱、活動狀態，計時器顯示為受保護（protected）、displayOnly 或未知。
- 邊界受限狀態需記錄於 `boundaryWarnings`。
- 若可行，排程離開戰鬥（`PLAYER_REGEN_ENABLED`）後重新刷新。

## 污染控制規則 (Taint Control)

- 嚴禁 Hook、覆寫、重新定義或 Monkey Patch Blizzard secure/protected 函式、FrameXML 核心函式、動作按鈕（Action Buttons）、單位框架（Unit Frames）、姓名板（Nameplates）、法術施法、目標選取、物品使用等關鍵安全路徑。
- 嚴禁在戰鬥中（`InCombatLockdown()`）修改受保護框架的屬性、Parent、錨點、尺寸、可見性、模板或點擊行為。
- 嚴禁把 EAM 運行時狀態、Secret/Protected 值、偵錯物件或插件回呼傳遞給可能污染安全鏈的暴雪框架。
- 事件監聽使用孤立框架（Orphan Frame：`CreateFrame("Frame", nil, nil)`）；渲染框架僅負責視覺呈現，不承擔安全操作或受保護互動。
- 若需要於 UIParent 下方建立框架，僅限於非受保護的純顯示用途；並在 `InCombatLockdown()` 為 true 時延遲所有會造成結構性變更的 UI 操作。
- 嚴禁使用 `forceinsecure`、不嘗試清除或繞過污染點、不以非正規變通方式壓制暴雪阻擋動作（Action Blocked）。
- 發現 Taint 污染、被阻擋動作或戰鬥鎖定錯誤時，即刻記錄到 `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`，並標明觸發路徑、戰鬥狀態與可復現步驟。

## DurationObject 與時間顯示

- 秘密或受保護時間資料不得使用 `OnUpdate` 手動倒數 (Manual Countdown)。
- 若 Retail 提供 DurationObject，優先交由原生 UI 元件處理，例如 `CooldownFrame:SetCooldownFromDurationObject()` 或 `FontString:SetDurationText()`。
- `Cooldown:SetCountdownFormatter()`、`Cooldown:SetCountdownMillisecondsThreshold()` 等 12.0.5 後相關能力需以官方文件與實機確認後使用。
- 手動計時器備用方案 (Manual Timer Fallback) 僅用於已確認安全的普通數值。

## 工具提示 / C_TooltipInfo 降級策略

工具提示解析只能作為低頻、明確標記來源的後備機制：
- 優先使用 `C_TooltipInfo` 官方結構化支援。
- 僅解析靜態說明文字中的明確數值。
- 嚴禁解析剩餘時間文字作為事實依據。
- 嚴禁在熱路徑、戰鬥中或每幀執行工具提示抓取。
- 解析結果無法覆寫安全 API 事實，僅能作為僅顯示輔助。
- 解析失敗時必須靜默降級，嚴禁產生盲目猜測的虛擬計時器 (Blind Timer)。

## 事件與框架規則

- 事件派發統一規定使用單一 `EventRouter`。
- 純事件監聽框架一律使用孤立框架：`CreateFrame("Frame", nil, nil)`。
- 不在 UIParent-parented 框架上承擔邏輯調度員職責。
- 不在戰鬥中對 UI 父框架動態註冊或解除註冊事件。
- 事件註冊變更應集中管理，避免重複建立底層管道 (Redundant Plumbing)。

## 調度程序與效能規則 (Performance & Scheduler)

- 優先採用事件驅動；排程回退機制必須精簡、低頻且具備節流保護。
- 全域僅使用單一調度核心 `OnUpdate`。
- 嚴禁在各別圖示、法術計時器或熱路徑中重複建立 `C_Timer.After(function() ...)` 閉包。
- `UNIT_AURA`、`SPELL_UPDATE_COOLDOWN`、`OnUpdate`、渲染更新均屬熱路徑。
- 熱路徑內嚴禁配置臨時 Table、閉包或無謂字串。
- 熱路徑避免使用 `pairs` / `ipairs`；具備穩定數值索引時使用數值循環。
- 熱路徑避免使用 `table.insert`；具備直接索引時使用直接索引寫入。
- 迴圈中字串拼接使用緩衝區配合 `table.concat`，避免連續 `..`。
- 低 FPS 或戰鬥中應主動延後、縮減或暫停非必要工作。
- 大範圍物品掃描不得在戰鬥中執行；若需要法術快取存儲 (Spell Cache/Storage)，必須採用選擇性載入 (Opt-in)、僅在閒置時執行 (Idle-only)、支援中斷 (Cancellable)、並依 FPS 與戰鬥狀態進行動態節流 (FPS & Combat Throttling)。

## table.create / table.freeze 政策

- `table.create` 用於預分配固定容量的表結構：圖示池、記錄清單、預設範本等。
- 必須提供 `table.create`、`table.freeze`、`table.isfrozen` 的安全 Fallback 實作。
- `table.freeze` 只用於不可變靜態資料：列舉（Enums）、常數模式、預設欄位設定檔、模組契約、元表原型。
- 穩定 API 別名表可凍結（例如 `EAM.API`），但僅在確認不會造成載入順序或測試故障時使用。
- 嚴禁凍結 SavedVariables、運行時快取、光環/冷卻即時狀態、物件池項目、調度器佇列或 debug/session 記錄。

## UI / 渲染器規則

- 渲染器不直接查詢底層 API；資料統一由 Service 服務層提供。
- 圖示、按鈕、FontString 實施物件池化管理。
- 渲染器不執行安全操作、不註冊點擊行為、不修改暴雪受保護框架、不操作姓名板或單位框架路徑。
- 避免初始化後動態建立多餘框架。
- 呼叫 `SetText`、`SetPoint`、`SetSize`、`SetTexture` 或佈局變更前，先比對新舊值以避免冗餘重繪。
- 批次佈局時可先隱藏父級框架，排版完成後再行顯示。
- 支援計時器、法術名稱、光環數值標籤，但僅顯示安全資料。
- UI 預設保持簡單直覺，嚴禁將 EAM 引入 WeakAuras 般的過度複雜系統。

## SavedVariables 規則

- SavedVariables 必須具備 Schema 版本號。
- 提供舊資料遷移、預設值填充與結構校驗。
- 嚴禁凍結 SavedVariables。
- 嚴禁高頻每幀讀寫 SavedVariables。
- 無法安全遷移的欄位要保留備份或標記為 Legacy，嚴禁靜默覆蓋破壞使用者設定。

## 除錯與交接規則

- 除錯模式預設關閉。
- 快照輸出必須明確劃分：
  - 事實（Facts）
  - 推導（Derived）
  - 人類筆記（Notes）
  - boundaryWarnings
  - 環境（Environment）
- 嚴禁在一般運行時輸出大量垃圾日誌。
- 設定字串匯出僅在使用者明確要求時建立。

## 程式碼風格 (Code Style)

- 變數與識別碼採用具語意的英文。
- 註解採用繁體中文，重點放在 WoW API 邊界、架構決策與設計脈絡。
- 所有正式載入的模組檔案都必須具備頂部註解，說明模組責任邊界、相依關係與維護注意事項（依據 `.AI/Docs/12_CODE_COMMENTARY_GUIDE.md`）。
- 縮排統一使用 4 個空格，不使用行內分號。
- 命名空間與模組使用 PascalCase。
- 函式與區域變數使用 camelCase。
- 內部管道函式/表以 `_` 前綴匯出。
- 常數與列舉符號使用 UPPER_SNAKE_CASE。

## 檔案備份規則

- 任何檔案在刪除、移動、覆寫或修改前，都必須先備份到專案根目錄的 `.AI/backup/` 資料夾。
- 備份檔案名稱格式為「原始檔案名稱後綴 `__yyyyMMddHHmmss`」，例如 `AGENTS.md__20260913094654`。
- 使用本機時間，格式為年月日時分秒，方便依時間排序與歷史追溯。
- 處理多個檔案時，應在同一作業開始前逐一備份；備份完成後才可進行實際修改、移動或刪除。
- 備份資料夾只作為內部開發與回溯參考，嚴禁壓縮進發布檔案。
- 若原始檔案不存在，需先確認原因，嚴禁建立空備份冒充原始內容。

## 開發問題記錄規則

- 開發過程遇到的瓶頸、限制、錯誤、工具失敗、API 行為與解決方式，一律記錄到 `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
- 目的為降低日後重複試誤、節省 AI 上下文 token、完整保留技術決策脈絡。
- 每筆記錄至少包含：日期、症狀、原因判斷、已嘗試方法、有效解決方法、後續注意事項。
- 若問題尚未解決，需標註為「未解決」並寫明下一步驗證方向。
- 嚴禁記錄密碼、Token、私人帳號資料或任何敏感機密。

## 專案專屬技能規則 (Skills)

- 開發過程若發現類似流程重複出現，且具備穩定步驟、輸入條件、輸出結果與風險控制時，應整理成 EventAlertMod 專用 SKILL。
- 適合轉成 SKILL 的流程包含：發布封裝、Lua 靜態驗證、WoW API 查證、SavedVariables 遷移檢查、Secret 邊界審查、文檔同步、語系同步等。
- 建立 SKILL 前需先確認流程確實可重複，潛在陷阱（Pitfalls）與解法應先記錄於 `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
- SKILL 內容應包含觸發條件、必要前檢、禁止事項、備份規則、驗證方式和回傳格式。
- 尚未驗證、尚需人工判斷或含敏感資訊的流程，嚴禁硬性封裝成自動化 Skill。

## 子代理程式協作規則 (Subagents)

- 使用者已授權：後續專案若出現適合子代理人的任務，主動規劃並使用。
- 派工前先判斷關鍵路徑；阻擋主流程的關鍵工作由主代理本機處理。
- 子代理主要負責低耦合、明確、獨立且不互相覆蓋的邊車任務（Sidecar tasks）。
- 適合範疇包含：正式服 API 查證、Secret / Taint 靜態審查、熱路徑掃描、文件一致性檢查、無衝突之模組切片等。
- 不適合範疇包含：小型單檔修改、需要即時授權的高風險操作、寫入範圍高度重疊的任務。
- 派工時必須明確指定檔案責任範圍、禁止事項、備份規則、驗證輸出及最終回傳格式。
- 子代理的查證結果必須由主代理整合核實；嚴禁將子代理的 API 判定直接視為已實機驗證。
- 所有協作與 PR 審查必須遵循 `.AI/Docs/21_RACI_EXPERTS_MATRIX.md` 的權責分工與審查原則。

## 機密憑證與 Token 安全防護規範 (Secret & Token Security Governance)

為防止創作者 API Token、私鑰與敏感金鑰意外洩漏，實施以下絕對安全與隔離邊界：

- **100% 本機隔離原則**：
  - 任何平台發布 Token（包括 CurseForge API Token、WoWInterface Token、個人 Access Token 等）**永遠只留存在本機**。
  - 絕對禁止將任何 Token 寫入程式碼、註解、測試檔案、Git 提交歷史或公開對話中。
  - 絕對禁止將含有 Token 的檔案納入任何發布 ZIP 壓縮包（無論是 AddOn 插件包還是 Source 原始碼包）。
- **本機雙重加密防護 (Windows DPAPI)**：
  - 本機 Token 統一透過微軟 Windows DPAPI (Data Protection API) 加密成二進位密文保存於 `.AI/API_TOKEN.SEC`。
  - 該密文嚴格綁定當前 Windows 使用者登入帳號與本機硬體金鑰，即使檔案外流他人也無法解密。
  - 專案 `.gitignore` 與 `Build-Package.ps1` 必須強制排除 `*.SEC`、`*.sec`、`API_TOKEN.SEC`、`*secret*`、`*token*`、`.env*`。
- **CurseForge 發布邊界**：
  - 本機發布統一調用 `Deploy/Upload-CurseForge.ps1` 工具，支援 CLI 傳參與對話式詢問模式，並提供 `-DryRun` 模擬模式供發布前全真驗證。
  - 執行上傳時，腳本僅在記憶體中瞬時解密 Token，並在終端機顯示時自動遮蔽（Masking），執行完畢即自記憶體釋放。
  - GitHub Actions 自動發布目前維持停用狀態 (`if: false`)，未經少年欸授權不得建立或啟用任何包含 Token 的雲端發布腳本。

## 快速指令

- 當使用者只輸入「資源」兩個字時，直接執行 `pwsh -NoProfile -File .\Deploy\Build-Package.ps1`。
- 當使用者輸入「壓縮開發版」時，直接執行 `pwsh -NoProfile -File .\Deploy\Build-Package.ps1 -PackageLabel DEV`。
- 當使用者需要「發布至 CurseForge」時，執行 `pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1`。
- 當使用者需要「模擬發布」時，執行 `pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1 -DryRun`。
- 封裝檔名必須符合 `EventAlertMod_MN_yyyyMMdd_HHmmss.zip`。
- 壓縮後返回 zip 路徑、Lua 語法檢查結果、排除資料夾檢查結果。
- 相關規則請參閱 `.AI/Docs/14_PACKAGING_GUIDE.md`。
- **原始碼包（SRC）規範**：自 2026-09-04 起，GitHub Release 發布時 GitHub 會自動為該 Tag 打包完整的 Source code (zip / tar.gz)；本機不再打包或生成專案 SRC 原始碼版本，上傳 GitHub Release 亦不再上傳 SRC 額外附件，徹底避免產物重複。

## 最終回報必須包含

相關實踐的最終報告至少包含：
1. 變更檔案清單。
2. 主要架構變更點。
3. 保留的舊 EAM 業務行為。
4. 移除或重構的舊行為。
5. Lua / WoW API 邊界假設。
6. `table.create` / `table.freeze` 使用摘要。
7. 秘密/受保護資料處理策略。
8. 已執行的離線靜態驗證與契約測試結果。
9. 尚未執行的實機驗證項目。
10. WoW 正式服實機測試需求與步驟。
11. 已知限制與潛在風險。
12. 下一步建議任務。

## 專案歷史里程碑與核心重構摘要

### 1. 已完成之核心重構 (Retail 12.0.7 / 12.1.0)
- **全程式碼語系清理 (Full Codebase Localization Pass)**：
  - 核心與 UI 邏輯中所有硬編碼字串與提示術語已完全抽離為 `EAM.L` 鍵值。
  - 完整支援 `zhTW` (繁中)、`zhCN` (簡中)、`enUS` (英文)、`koKR` (韓文) 與 `ruRU` (俄文) 五大語系，維持各語系詞條數量嚴格一致。
  - 專精名稱優先透過 `GetSpecializationInfoForClassID` 取得官方最新在地化名稱，並提供可靠雙軌 Fallback。
- **ClassPower 核心資源安全偵測**：
  - 針對 `detectClassPower` 與 `updatePower` 部署 `pcall` 隔離與 `issecretvalue` 防衛機制，防止戰鬥中能量數值為 Secret 時進行比較造成崩潰。
- **EventRouter / Scheduler 故障隔離**：
  - 為核心事件循環與定時回呼加入 `pcall` 容錯，確保單一模組異常時不影響其他服務。
- **雙軌 Native Binding 倒數與 Pandemic Glow**：
  - 時間渲染優先實作 `C_DurationUtil.CreateDurationTextBinding` 與 `SetCooldownFromDurationObject` 降級通道。
  - 在 DoT 光環滿足 Pandemic 刷新時間時，為圖示啟用動態發光亮框效果。
- **全職業與英雄天賦資料庫擴展**：
  - 更新 `EventAlertMod/Data/SpellArray.lua`，為 13 個職業與各專精英雄天賦配置預設監控法術 ID。
- **影子載體技術 (Shadow Host)**：
  - 針對利用官方 `CooldownViewer` (CDM) 作為影子載體以避開戰鬥 Secret / Taint 限制完成落地。於 `EventAlertMod/Services/ShadowHostService.lua` 實作官方池 Hook，並於 `EventAlertMod/UI/Renderer.lua` 引入寄生渲染讓位與級聯排版避讓。
- **零分配 (Zero-Allocation) 與事件驅動架構重構**：
  - 五大資料服務（AuraService、CooldownService、ItemCooldownService、GroundEffectService、TotemService）改為事件驅動，不再直接耦合 Renderer。
  - 引入 `AlertManager.lua` 統一排程事件變更，配合 `Scheduler` 實施同步節流與批量更新（`BeginBatch` / `EndBatch`）。
  - 在各服務配置多型零分配物件池（`StatePool`），於 `acquire` 時綁定 `releaseFunc`，渲染後由 `AlertManager` 安全回收，達成執行期 0-Heap-Allocation，大幅減輕 GC 負擔。
  - 解決 CDM 宿主容器 `ClipsChildren` 裁切與 FrameLevel 遮擋問題，寄生模式下自動調整文字排版並提權 `FrameLevel`（相對於 `hostIcon` + 10）。
- **進階事件整合**：
  - 地面法術監控捨棄高負載的 `COMBAT_LOG_EVENT_UNFILTERED` (CLEU)，改以訂閱 `UNIT_SPELLCAST_SUCCEEDED` 精確比對 `unitTarget == "player"`。
  - 能量更新追加 `UNIT_POWER_FREQUENT` 事件，連擊點與聖能反應速度達到零延遲。
  - 冷卻服務監聽 `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`，當法術因天賦或狀態動態覆蓋時即時刷新，解決覆蓋技能殘留問題。
  - 監聽 `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` / `HIDE` 快捷列發光事件，以 Decorator 模式為狀態注入 `state.overlayGlow`，100% 同步暴雪官方 Proc 金色發光。
- **Pool-Token 延遲調度優化**：
  - 徹底移除在 `OnUpdate` 中對 `durationObj:IsZero()` 的 `pairs` 輪詢與 `pcall` 檢查。改為在啟動計時器時由 `timerTokenPool` 取得 Token，並透過 `Scheduler.after` 註冊單次延遲調度，消除戰鬥微卡頓，使熱路徑 100% 能被 LuaJIT 編譯優化。

## Changelog 分類規則

- 根層 `changelog.txt` 與 `EventAlertMod/changelog.txt` 是公開發布紀錄，只記錄 WoW 插件功能、遊戲內行為、版本相容性、玩家可感知修正，以及會實際改變發布插件包內容的素材或封裝修正。
- 公開 changelog 不記錄 AI 治理、代理分工、文件同步、上下文接續、測試通過數、離線驗證數字、GitHub／CI／workflow 發布流程、備份位置或內部工作進度。
- AI 治理問題、失敗嘗試、根因分析與後續決策，記錄於 `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`；跨工作階段的路由、狀態與未完成事項，記錄於 `.AI/Docs/28_PROJECT_CONTINUITY.md`。
- 兩份公開 changelog 必須使用同一份內容來源，完成後以 SHA-256 確認 `changelog.txt` 與 `EventAlertMod/changelog.txt` 完全一致。
- 修改公開 changelog 前，先依檔案安全規則備份；不要為了整理格式改寫歷史技術事實，只移除純流程段落或將同一功能的流程性措辭改成玩家可理解的行為描述。

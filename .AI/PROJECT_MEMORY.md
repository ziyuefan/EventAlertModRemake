<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod 專案接續記憶

> 最後更新：2026-09-13（Asia/Taipei）
> 用途：提供 Codex／AI Agent 在對話中斷、內容壓縮或工作轉交後的最短接續路徑。
> 證據界線：本檔只做索引與工作狀態摘要，不可取代程式碼、測試報告、實機報告或結構化事實檔。

## 每次接續必讀順序

1. 根目錄 `AGENTS.md`。
2. `.AI/AGENTS.md` 完整規則。
3. 本檔 `.AI/PROJECT_MEMORY.md`。
4. `.AI/Docs/28_PROJECT_CONTINUITY.md` 與 `.AI/Data/ProjectContinuity.json`。
5. 與目前任務直接相關的架構、API、測試或發布文件。

## 固定路徑與禁止事項

- Git／專案根目錄：`D:\Project_EventAlertMod`。
- 唯一 AddOn 原始碼：`D:\Project_EventAlertMod\EventAlertMod`。
- AI 治理、測試、文件、爬蟲資料：`D:\Project_EventAlertMod\.AI`。
- 部署工具：`D:\Project_EventAlertMod\Deploy`。
- 本機套件輸出：`D:\Project_EventAlertMod\Dist`，不得提交 Git。
- WoW 主目錄候選：`D:\World of Warcraft`；每次部署前仍須由登錄檔與使用者確認。
- 舊專案 `D:\EventAlertMod` 已停用，禁止讀取、寫入、比較、同步或作 fallback。
- 任一部署目標若是 SymbolicLink、Junction 或其他 Reparse Point，必須 fail-closed；不得追蹤、覆蓋、刪除或重建。
- 未經使用者要求，不讀取 `WTF\Account` 內帳號或角色資料。
- 🚨 部署腳本異動通報義務：若因應需求修改 `Deploy/` 目錄下任何腳本（如 `Deploy-EventAlertMod.ps1`、`Build-Package.ps1`、`Upload-CurseForge.ps1` 等），必須主動明確向少年欸報告具體改動內容。
- 🚨 每輪任務結束必做建議：每輪任務完成時，必須主動向少年欸推薦當前情境可使用的 Antigravity 內建斜線指令（如 `/goal`, `/plan`, `/boost`, `/learn` 等）或適用之 Agent SKILL。

## 目前目錄契約

- `EventAlertMod/`：唯一可打包的插件目錄，必須包含 TOC、Core、Data、Debug、Locale、Managers、Media、Services、UI、README 與 changelog。
- `Deploy/`：部署與插件包封裝工具（GitHub Release 原生自動打包 Source，本機與發布已停用專案 SRC 打包）。
- `Dist/`：僅存放本機生成的 ZIP／摘要；不再保留 `Dist/EventAlertMod` 中介副本。
- `.AI/`：AGENTS、PROJECT_MEMORY、Docs、Tools、Tests、Schemas、TestResults、候選資料、歷史參考、備份與專案 Skills（唯一定義真理來源）。
- `.agents/`：Antigravity 工作區擴充入口，僅存放 `skills.json` 轉址導向 `.AI/skills/`，杜絕技能雙重維護。
- `scratch/`：專案根目錄禁止放置草稿/暫存夾，臨時腳本一律集中於 `.AI/scratch/`。
- 根目錄與 `EventAlertMod/` 的 `README.md`、`changelog.txt` 必須保持同步。
- `changelog.txt` 結構化分類規範：必須依「【✨ 新增功能】、【⚡ 體驗優化】、【🐛 缺陷修復】、【🌐 在地化支援】」四大標準分類組織；正文永遠以魔獸插件本體為核心；若有 AI 治理或工程細節，在 GitHub Release 必須使用 `<details><summary>` 獨立收合，CurseForge 公開發布則維持 100% 玩家純度。發布日誌與歷史清單全面導入 `<details>` 折疊能力，杜絕頁面落落長。
- 版本斷點與自動遞增：往後版本斷點以發佈到 GitHub Release 及 CurseForge 為斷點；正式發布後的新開發週期自動將版次遞增 0.1（例如 Alpha 8.5 發布後，後續所有新增功能、異動、修正等均以 Alpha 8.6 紀錄，不含 Alpha 8.5 歷史內容）。

## 目前主要工作

1. 新根目錄、`EventAlertMod/` 唯一插件來源、`.AI/` 治理、`Deploy/` 工具與 `Dist/` ignored 契約已完成。
2. 2026-09-13 完成技能庫倉庫雙軌制（skills.sh + lobehub.com）確立與 20 套 WoW Patch 12.0.0 官方技能手冊安裝與治理三端同步（Global、.agents、.AI）。
3. 2026-09-13 升級 `.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml`（v1.1）與說明手冊，建立事實階梯與 XML 機器抗記憶漂移硬性備援機制。
4. 2026-09-14 實裝 **Retail 12.1.0 Alpha 8.6** 四大核心功能：
   - **技能名稱自訂排版**：預設全面改為置於圖示下方（`OUTSIDE_BOTTOM`），提供 21 種錨點位置下拉選單，所調即所見。
   - **角色屬性預覽即時更新**：修復切換屬性、調整尺寸、字級、小數點、替代圖示與警戒門檻時未即時反映之問題；統一門檻欄位命名相容（`thresholdMin` / `minThreshold`），紅框即時亮起。
   - **職業資源縮放與可捲動字型清單**：改建為 10 行可捲動下拉選單（`ScrollableDropdown`），相容 LSM 與內建字型；補齊資源縮放（`scale`）於預覽視窗之即時等比縮放連動。
   - **獨立效果預覽連動加固**：修復預覽視窗與主設定面板連動中斷缺陷，增設透明度滑桿、安全呼叫守衛（`safeCall`）。
5. 最新離線證據：Lua syntax 78/78 通過、Flow all 87/87 通過、Validation Contracts 499/499 通過、Build-Package DryRun 通過。
6. 本輪文件、Continuity JSON 與 `.AI/docs_html/` 同步。依規範嚴格限制零自動部署（鐵律 R1）。

## 已完成的結構工作

- AddOn 執行期檔案已集中到 `EventAlertMod/`；治理資料已集中到 `.AI/`。
- 不必要的 `Dist/EventAlertMod` 中介目錄已移入時間戳封存區，不再作來源。
- `EventAlertMod.code-workspace` 已封存；保留 `.vscode/settings.json` 供 Lua 5.1／WoW API 開發設定。
- `Dist/` 已加入 `.gitignore`；GitHub Release 負責發布二進位插件 ZIP。
- 根目錄與 AddOn 內 changelog 已同步，並限定只記玩家可感知的 WoW 插件／API／相容性／套件內容變更。
- Wowhead 候選資料唯一位置為 `.AI/Data/wow_spells_and_auras.json`；不得由 AddOn TOC 或執行期 Lua 載入。
- 根目錄 `AGENTS.md` 已改為精簡探索入口，完整規則保留於 `.AI/AGENTS.md`。

## 最近離線證據

- PowerShell AST：`.AI/Tools` 與 `Deploy` 合計 13/13。
- Python：三個檔案 `py_compile` 通過；文件轉換測試 4/4；41 份 HTML 離線編譯完成。
- Lua syntax：78/78（包含所有 AddOn 與離線測試檔案）；Flow all 86/86；Validation Contracts 499/499。這些是 offline/static evidence，不是三客戶端實機簽收。
- `.AI/Tools/Test-WowheadCandidateData.ps1`：23 pass、0 fail、4 warnings；warnings 是候選資料風險，不是實機簽收。
- AddOn 包：Dist/EventAlertMod_MN_20260821_20260821_050105.zip，93 個檔案（ZIP 中另有目錄 entry），SHA-256 c4cd66f91563e608049a2af73f559390808dba2e1299106103a987d4e66be1e5，Managers 與排除清單獨立稽核通過。
- Source 包是包含本檔的衍生產物，為避免自我參照，不在 PROJECT_MEMORY 內固定自身檔名或 SHA-256；每次以 `Deploy/Build-SourcePackage.ps1` 最後輸出的 Dist `.inventory.json` 與 `.sha256` 為權威，且必須通過 Dist／Git metadata／backup／TestResults 排除稽核。
- Deploy Status 與 Retail／PTR／XPTR 非互動 DryRun 均通過；本機常見 Registry key 未提供可用安裝根，因此使用 `DeploymentTargets.json` fallback。
- `.AI/Tools/Test-LocalWoWEnvironment.ps1`：1/3；PTR 完整，Retail／XPTR 因缺少 `EventAlertMod.toc` 失敗。
- Markdown→HTML 以 `EAM_DOCS_OFFLINE=1` 完成 37 個檔案，未使用外部翻譯服務。

## 已知阻擋與風險

- 目前版本為 Retail／PTR `12.1.0.69382`、XPTR `12.0.7.68887`；版本會漂移，每次部署與實測仍須即時重讀。
- 三個 AddOn 目標目前皆為實體資料夾，但只有 PTR 含 TOC；Retail／XPTR 尚未實際部署完整，不能宣稱三通道 ready。
- Registry 偵測能力已有靜態契約，但本機未找到正向 InstallPath 證據；目前實測是 JSON fallback。
- 玩家資源正式路徑已完成 17 種資源／40 組職業專精拓撲的離線選型與 Secret write-only sink；法力、能量、連擊點、瘋狂值、怒氣、符文／符能及所有職業專精仍需玩家逐項實機視覺簽收。
- Wowhead JSON 是 `webCandidate`，不是正式預設、PTR/Retail 證據或可直接匯入的信任資料。
- 新根不在桌面工具原始 writable root；標準 `apply_patch` 可能失敗。修改只能使用先備份、可審查且先驗證的精確 patch 流程，禁止以舊根繞過。

## 發布與 Git 邊界

- `Dist/` 不提交 Git；插件 ZIP 與專案 source ZIP由 GitHub Release assets 承載。
- source ZIP 必須排除 `Dist`、`.git`、`.AI/backup`、`.AI/.trash_*`、`.AI/TestResults`、本機附件、快取、log 與既有 ZIP。
- CurseForge 自動發布流程目前維持停用；不得因 workflow 名稱或舊腳本自行恢復。
- 未經本輪明確要求，不執行 commit、push、tag、GitHub Release 或實際部署。

## Skills.sh 授權邊界

- 可依專案重複流程主動搜尋 `skills.sh`，最多提出三個經來源、權限、依賴與供應鏈審查的候選。
- 提供「都不安裝／建立專案自訂 Skill」選項；未經使用者選定與授權不得安裝。
- EAM 專屬 Skill 一律存放於 `.AI/skills/`。


## 2026-08-23 Target Aura 接續記憶

- TooltipMonitorService 的 Target Aura callback 只產生安全匿名 metadata：callback／candidate 時間、過期計數、最後 try reason、modifier key/down、CVar read/set 結果；不輸出 raw Secret、AuraData、Frame 或猜測 ID。
- Ctrl+Alt 仍受非戰鬥、無鍵盤焦點、精確修飾鍵與新鮮候選 gate。不可 hook TargetFrame/AuraButton，也不可依賴 GetChildren／GetMouseFocus。
- 使用者可輸入 /eam add target 開啟既有手動 Aura popup，輸入已知 Spell ID 後按目標按鈕；帶 ID 的 /eam add target <spellID> 維持直接新增。/eam doctor 用於回報安全 diagnostics。
- 最新離線證據：Lua 64/64、Flow all 75/75、Flow boundary 54/54、Validation Contracts 441/441；仍不能取代 PTR／XPTR／Retail 實機 visual／taint 簽收。
## 2026-08-23 玩家職業資源提示語完成快照

- 目前程式已採 ResourceCatalog → capability／config compiler → runtime registry → PowerRenderer 的獨立資料流；UNIT_POWER_FREQUENT／UNIT_POWER_UPDATE 走 token O(1) 更新，UNIT_DISPLAYPOWER 只更新 foreground metadata。
- PAIN 使用獨立 powerPain legacy key；SavedVariables 不再維護第二份 resource definition table。Energy、ComboPoints、Mana、Rage、LunarPower 等背景資源保留在 tracked topology，不能因 foreground 改變而被 hide/release。
- Probe 的正式入口是玩家明確執行 /eam unitpower background RESOURCE_KEY 進行事件缺失診斷；sampler 只有有需求、frame 可見、事件不足時才排程，離線 0.5 秒不是實機頻率。
- 本輪新增 Druid 全形態、Energy→ComboPoints renderer ownership、Probe stop 與 font／orientation controls 的 Flow／Contracts；驗證數字以最新報告為準。
- 尚未做 PTR、XPTR、Retail 部署或視覺簽收；不得把 setter accepted、eventObserved、sampler tick 或 offline pass 寫成實機 pass。
- 下一佇列：部署工具移除 Wow-running 阻擋，加入按通道／版本選擇的 WTF EventAlertMod 備份與原路徑還原；此工作需另行測試，不與資源 runtime 證據混合。
## 接續檢查清單

1. 執行 `git status --short --branch`，只辨識變更，不還原未知修改。
2. 確認工作目錄是 `D:\Project_EventAlertMod`，且命令與文件沒有把舊根目錄當來源。
3. 讀取部署工具目前版本與尚未完成的驗證，不重做已完成的搬移。
4. 修改前依 `.AI/AGENTS.md` 備份；不存在的新檔不可建立空備份冒充原件。
5. 完成後更新本檔的「目前主要工作／最近離線證據／阻擋與風險」，並同步詳細 Continuity 文件與 JSON。
6. 離線通過不得冒充 Retail／PTR／XPTR 實機通過。

## 2026-08-21 職業資源設定生命週期補充

- 非戰鬥的玩家資源設定由 `SavedVariables.updatePlayerResourceConfig` 寫入後同步派送 `EAM_PLAYER_RESOURCE_CONFIG_CHANGED`，`PlayerResourceService` 立即重建 topology；不應要求 `/reload`。
- 戰鬥中只保存 desired config 並標記 `combatRebuildDeferred`，由 `PLAYER_REGEN_ENABLED` 合併重建一次。若 live 仍需 `/reload`，先回報 resource key、client channel/build/interface、combat 狀態、service `lastConfigResult` 與 Lua error/taint。
- 2026-08-21 修正設定欄位流失：`showPercent`、`fullGlow`、`fontFamily`、`fontSize`、`orientation`、`threshold` 現在由有效設定傳到 `PowerRenderer`；Secret 資源不顯示 raw 數字，仍採原生 write-only sink。

## 2026-08-21 職業資源設定生命週期修正

- 根因：非戰鬥設定 mutation 沒有立即觸發 resource topology／renderer；/reload 只是重新走初始化流程。
- 修正：非戰鬥 EAM_PLAYER_RESOURCE_CONFIG_CHANGED 立即重建；戰鬥中保存 desired config，PLAYER_REGEN_ENABLED 時合併一次；foreground metadata 不再暗示只有一項資源。
- 新增 threshold 設定控制與 migration fixture 覆寫語意修正；未覆寫的 class/spec settings 不會被測試要求預先複製。
- 最新離線證據：Lua 64/64、Flow all 75/75、Boundary 54/54、Validation Contracts 436/436。ResourceProbe、12.0.7 adapter、Druid form、anchor／position、module unregister、冷路徑策略綁定與 probe-gated sampler 已有程式契約；Retail／PTR／XPTR 視覺仍需玩家實機簽收。

## 2026-08-21 玩家資源 completion audit

- `Debug/PlayerResourceProbe.lua` 只產生逐資源安全 metadata，停止時解除事件；`eventObserved` 不是 visual pass。
- `PlayerResourceCapability.getClientAdapter()` 將 XPTR 12.0.7 導向 numeric legacy adapter，與 12.1 Secret sink 隔離；Classic／MoP 不在支援範圍。
- Druid Caster／Cat／Bear／Moonkin flow、anchor／position、模組事件 unregister 與 source-to-sink 已納入核心契約。
- background sampler 只有在 probe 確認事件缺失時才啟用，採單一 demand-driven 路徑；`unitpower.background_sampler_gate` 與靜態 contract 已離線通過，涵蓋單 task、事件恢復停止、模組停用、戰鬥延後與 stale generation。
- 最新離線證據為 Lua 64/64、Flow all 75/75、Boundary 54/54、Validation Contracts 436/436；NUMERIC／SECRET_DISPLAY 更新策略已在冷路徑綁定，NUMERIC 文字使用 `SetFormattedText()`，Secret 仍不讀回或字串化。任何通道的實機 visual／taint／blocked action 仍待玩家回報。

## 2026-08-23 技能冷卻啟動與 tri-state 記憶

- 冷卻服務的「在清單」不等於「已啟動」；只有玩家本人 UNIT_SPELLCAST_SUCCEEDED 且精確命中清單 spellID 才可建立 activatedAlerts。
- refreshAll、PLAYER_REGEN_ENABLED、形態事件、設定刷新與非清單治療法術只允許刷新既有啟動狀態，禁止批量 render；模組停用／刪除才清除啟動狀態。
- cooldownRemoveAura、showSCDOutsideCombat、glowSCDWhenUsable 是 nil 全域繼承、boolean 單技能覆寫；任何保存、Profile 匯入或 Options 回寫都必須以明確 type check 保留 false。
- Renderer 的到期回呼必須回問 CooldownService；Secret 時間／spell 值不讀回、不比較、不字串化。可用高亮只合併安全的 service state。
- 目前離線證據：Lua 64/64、Flow all 76/76、Boundary 55/55、Validation Contracts 447/447；實機仍須依 .AI/Docs/29_LIVE_TEST_STEP_GUIDE.md 分 Retail／PTR／XPTR 回報。
## 最新部署工具證據

- Deploy/Deploy-EventAlertMod.ps1 不再阻擋執行中的 WoW；部署仍由來源／目標 Reparse Point 與版本通道驗證保護。
- [W]／[U] 與 CLI Backup／Restore 依通道與版本處理 EventAlertMod 遊戲存檔；manifest 保留原始相對路徑與 SHA-256，還原前建立 rollback。
- 暫存 fixture 備份／修改／還原通過；未寫入真實 WoW 目錄。最新離線證據為 Lua 62/62、Flow all 77/77、Flow boundary 56/56、Validation Contracts 459/459。
## 2026-08-23.6 最新接續記憶

- canonical root 仍為 D:\Project_EventAlertMod；只可修改 EventAlertMod、.AI、Deploy 與必要公開文件，不得回到 D:\EventAlertMod。
- Alpha 7 玩家資源離線 gate 已固定為 Lua 62/62、Flow all 77/77、boundary 56/56、Validation Contracts 461/461；最新 artifact 是 EAM_FlowValidation_all_20260823_081553.json 與 EAM_FlowValidation_boundary_20260823_081542.json。
- PlayerResourceProbe 的 missing-event check 由 Scheduler 延遲一次執行，且 Flow 明確驗證 restart；service 對 UNIT_DISPLAYPOWER、形態與脫戰只刷新 foreground metadata。
- SavedVariables 不可寫入 frozen Catalog map；Options 對初始化未完成的 SavedVariables method 需 fail-closed。
- 根 README 與 EventAlertMod/README.md 已同步，SHA-256 7EB8752ACA994769356757AED7E1FB4483497930E4A0CB9C567403D14D161509；部署器的 README mismatch 阻擋已排除。
- 本輪仍未部署 WoW、未讀寫 WTF、未執行 GitHub push／release；需要實機時先部署再通知玩家輸入 /reload。

## 2026-08-23.7 最終接續記憶

- canonical root 仍為 D:\Project_EventAlertMod；本輪沒有回到舊根、沒有部署、沒有 GitHub push／release。
- 最新離線 gate：Lua 62/62、Flow all 77/77、boundary 56/56、Validation Contracts 464/464；artifact 為 EAM_FlowValidation_all_20260823_083630.json 與 EAM_FlowValidation_boundary_20260823_083631.json。
- ProjectContinuity.json snapshot 為 2026-08-23.7，privacy contract 通過；公開 fact 只保留程式／文件相對路徑。
- 根 README 與 EventAlertMod/README.md 完全同步，SHA-256 為 635C545E7B535B85730AA28D24176E291299A86F47D5036682C1FE5877935AB3；README 已包含現行 Alpha 7 /eam 命令、使用時機、離線驗證、部署與通道備份／還原說明。
- 下一次接續先讀本節、.AI/Docs/28_PROJECT_CONTINUITY.md 的 .7 快照及 .AI/Docs/29_LIVE_TEST_STEP_GUIDE.md，再等待玩家部署後的 Retail／PTR／XPTR 實機報告。

## 2026-08-23.8 最新接續記憶

- canonical root 是 D:\Project_EventAlertMod；本輪未讀寫舊根、WoW 或 WTF，未執行 GitHub push/release。
- 充能技能已有安全 current/max 顯示；無 timer 時 CooldownFrame 清理 edge／bling；Glow 預設使用 .AI 治理的內嵌 LibButtonGlow-1.0，自訂顏色或戰鬥首次建框走 EAM fallback。
- wow-addon-dev Skill 位於 .AI/skills/wow-addon-dev，TOC validator 通過；TOC 載入順序為 LibStub、LibButtonGlow，再進入 Core。
- 最新離線 gate：Lua 62/62、Flow all 78/78、boundary 57/57、Validation Contracts 472/472；runtime 視覺、Secret sink、taint 與 blocked action 仍待玩家部署。
- 實機通知協議：部署前一定先告知通道／版本／build／Interface、來源／目標、覆蓋與 /reload 或完整重啟要求；收到玩家部署完成回報後才判讀遊戲結果。

## 2026-08-23.10 充能次數與環形版面接續記憶

- canonical root 仍為 `D:\Project_EventAlertMod`；本輪只修改新根，未部署 WoW、未讀寫舊根或遊戲資料，未執行 GitHub push／release。
- 充能首次啟動只接受玩家 `UNIT_SPELLCAST_SUCCEEDED`，但匹配儲存 spellID、base ID 與目前 override ID；其他 cooldown／charge／regen／形態事件不得開啟未施放技能。
- `SpellChargeInfo` 必須逐欄判讀。安全 `maxCharges`／`isActive` 可保存；`currentCharges` 可為 Secret，只能最後直送 `StatusBar:SetValue`，不可比較、字串化、序列化、存入自訂表或讀回。
- 充能 StatusBar 的 fill／段數只代表 current/max，不再由 `GetSpellChargeDuration` 或恢復時間驅動。恢復 `DurationObject` 只供技能 cooldown swipe／倒數。
- 版面支援 TOP／BOTTOM／LEFT／RIGHT／RING；預設 150% 圖示長度／直徑、8px 厚度，最多 20 段安全分隔線。12.1 環形採 Radial render mode；能力不足回退 BOTTOM。
- `cooldownRemoveAura` 對充能技能只在回到最大次數時移除；明確 false 以 if 保存，不使用 `and/or` 三元 fallback。
- 冷卻細部視窗不顯示 Aura 專用 fromPlayer checkbox；三項冷卻行為維持 nil／true／false per-spell override。
- 最新離線 gate：Lua 64/64、Flow all 79/79、boundary 58/58、Validation Contracts 483/483。部署後先 `/reload`，再依 `.AI/Docs/29_LIVE_TEST_STEP_GUIDE.md` 的 Alpha 7.3 充能段落真人簽收。

## 2026-08-23.11 Alpha 7.4 接續記憶

- canonical root 仍是 `D:\Project_EventAlertMod`；不得回舊根。插件來源是 `EventAlertMod/`，Dist 不進 Git；尚未部署到任何 WoW 通道，也未讀寫 WTF。
- Alpha 7.4 核心：充能 spent→full 完成 latch 與 TGA ring grid；DK Runes 六槽 `GetRuneCount`／`GetRuneCooldown` + `RUNE_POWER_UPDATE(index, added)`；GroundEffect Base／Override／SpellInfo family cold compile、exact-ID 優先與 Secret fail-closed。
- Rune Flow 曾顯示核心 6/6→5/6→6/6 正確但多一次 slot read，根因是 `Util.isSafeBoolean(added) and added or nil` 吃掉 false；改為明確 if 後 boundary 收斂。
- 最新離線 gate：Lua 64/64、Flow all 82/82、boundary 61/61、Validation Contracts 493/493。最新 artifacts：`EAM_FlowValidation_all_20260823_180735.json`、`EAM_FlowValidation_boundary_20260823_180735.json`。
- ProjectContinuity snapshot 為 `2026-08-23.11`；下一步是 docs_html、package/source ZIP、Git diff／commit／push 與人工 `gh release` 建立 `alpha-7.4` prerelease，不啟用 Release Action／CurseForge。
- 玩家部署後優先測：DK 符文與符能並存、符文消耗／恢復、死亡凋零／褻瀆、反魔法立場、冰霜之球、充能 RING／滿充完成。回報通道、build、Interface、剛部署與 `/reload` 狀態。
- Alpha 7.4 首份 source ZIP 稽核發現巢狀 `.AI/.AI/TestResults`，提交前亦發現 `.AI/skills/wow-addon-dev/.git` 上游 metadata；後者已移入 ignored trash。發布只能使用修正 leaf 排除器後重新產生且 inventory 證明無任意深度 `.git`／backup／TestResults／patch-temp 的新 ZIP。

## 2026-09-13 社群技能庫擴充與 15 套 WoW API 技能導入

- **技能倉庫雙軌確立**：正式收錄 **LobeHub Skills 市集**（`https://lobehub.com/zh-TW/skills`）與既有 **skills.sh**（`https://skills.sh/`）並列為 Antigravity 全專案雙軌官方社群技能庫。
  - 新增並部署雙軌技能發現工具：`lobehub-skills-discover` 與更新後的 `skills-sh-discover`。
  - 檢索與候選規則已固化於 `.AI/AGENTS.md`：發現能力缺口時主動推薦最多 3 個候選，建立需求卡審查依賴、授權與安全性；經少年欸授權後同步部署至全域與專案。
- **19 套 Patch 12.0.0 官方 WoW API 技能完整落地**：
  - 首批導入 15 套：`wow-lua-api`、`wow-api-spells-abilities`、`wow-api-combat`、`wow-api-encounters`、`wow-api-quests`、`wow-api-achievements`、`wow-api-calendar-events`、`wow-api-group-lfg`、`wow-api-map-navigation`、`wow-api-misc-systems`、`wow-api-pvp`、`wow-api-reputation`、`wow-api-settings-system`、`wow-api-social-chat`、`wow-api-transmog`。
  - 追加收錄 4 套核心底層技能：
    1. `wow-api-events`（全遊戲事件監聽手冊，含 5 份分類事件清單與參數解析）
    2. `wow-api-unit-player`（玩家與單位狀態/屬性核心，含 6 份生命、能量、光環與戰鬥狀態文件）
    3. `wow-api-widget`（UI 框架組件指南，含 10 份控制項、動畫、字型、模型與腳本回呼手冊）
    4. `wow-api-items-inventory`（物品、背包、銀行與戰利品系統，Patch 12.x 完整 API）
  - 全數通過 YAML frontmatter 語法清洗（去除外層代碼塊防護）與實體檔案三端同步部署（`~/.gemini/config/skills/`、`.agents/skills/` 與 `.AI/skills/`）。
- **時效性與衝突裁決最高原則（API Change Precedence）**：
  - 確立外部技能僅為 12.0.0 靜態基線參考；一旦與暴雪後續 12.0.7 / 12.1.0 變更產生衝突，**100% 依據專案 `.AI/Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md`、`eam-api-change-intel` 與最新實機矩陣為最高事實仲裁（Level 0/1 Strict Precedence）**。
  - 涉及 Secret Values、AuraContainer 重構或 Taint 阻斷者，強制通過 `eam-secret-taint-sentinel` 審查與專案防禦性封裝（Fallback Wrappers / Capability Gate），杜絕盲從外部靜態手冊。
- **XML 結構化抗記憶漂移備援體系升級（v1.1）**：
  - 遵循少年欸指示，升級 `.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml`（v1.1）與說明手冊（`33_AI_GOVERNANCE_DIRECTIVE.md`）。
  - 將「雙軌社群技能庫生態（`<skills_warehouse_ecosystem>`）」、「最高事實裁決階梯（`<fact_of_truth_hierarchy>`）」與「抗記憶漂移備援協議（`<anti_memory_drift_protocol>`）」正式固化為 XML 結構化標籤。
  - 確立法規邊界：當大語言模型遭遇對話截斷、上下文壓縮或跨模型交接產生語意漂移時，本 XML 為專案最高確定性抗漂移備援保險箱，優先於自然語言推論。




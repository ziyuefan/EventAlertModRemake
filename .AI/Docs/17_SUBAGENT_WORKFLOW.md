<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 子代理程式工作流程規劃

本文件定義 EventAlertMod 開發時規劃並使用子代理程式。目標是讓大型工作可額外、可延期、可控制風險；不是把任務全部外包，也不是所有不必要的協調成本增加。

## 基本原則

- 只有在使用者已授權子代理、且任務可拆除時才能使用明確的邊界。
- 主代理先判斷關鍵路徑（關鍵路徑）：下一步立即停止的工作必須由主代理自己處理。
- 子代理程式處理 sidecar 任務（旁路任務）：可完成、具體、可驗收、不停止主代理下一步。
- 不重複派工；同一問題存在子代理結果時，除非有新證據或不同角度，不再派第二個做同樣分析。
- 程式修改型子代理程式必須有明確的書寫範圍，避免多個代理程式改同一個檔案。
- 所有分代理結果均需由主代理整合與最終判斷，不直接視為已驗證事實。

## 適合使用子代理人的姿勢

- 大型重寫頻道中，可精密互不重疊模組：
  - `Services/AuraService.lua`
  - `Services/CooldownService.lua`
  - `UI/Renderer.lua`
  - `Debug/PromptExport.lua`
- API 查詢與文件整理可和本地實作家具，例如：
- 12.x API 更改來源複核。
  - 秘密價值/污染討論整理。
  - DurationObject / DurationTextBinding 實踐方式比較。
- 驗證與掃描可與修復零件，例如：
  - 搜尋舊API直接呼叫。
  - 檢查`table.freeze`錯誤用。
  - 檢查 `C_Timer.After(function() ...)` 熱路徑。
  - 對 Docs 與 AGENTS 進行一致性檢查。
- 大量文件中文化、術語統一、測試清單補齊。
- Package / CurseForge 發布流程的旁路檢查，例如排除清單、TOC 版本、zip 命名規則。

## 不適合使用子代理人的姿勢

- 小型單檔修改，主代理可直接完成。
- 下一步完全依賴該結果，等待子代理改為拖慢關鍵路徑。
- 需要立即判斷使用者意圖、風險或授權的操作。
- 涉及刪除、搬遷、覆寫大量檔案，而尚未備份與範圍確認。
- 高修改連接，例如同時改變 `SavedVariables` schema、migration、Options UI、Slash command 且尚未開始開始範圍。
- 尚無明確的探索性問題。

## 角色使用建議

- explorer：用於特定問題的複雜調查，例如「尋找活動 Lua 中所有冷卻時間 API 通話」。
-worker：用於可分割的實作，例如「只修改UI/Options.lua，新增某個設定欄位，不碰SavedVariables」。
除非任務有明確理由，子代理程式使用預設繼承模型；不指定較昂貴或不同模型。

## 派工模板
```text
你是 EventAlertMod Retail rewrite 的 subagent。

範圍：
- 只能處理：<檔案或問題範圍>
- 不得修改：<明確排除範圍>

必要規則：
- Retail only。
- 不支援 Classic / MOP / Cata / Wrath / Era。
- 不繞過 Secret / Protected Data。
- 避免 taint；不 hook secure/protected chain。
- 修改任何既有檔案前需先備份到 backup/。
- 不還原他人變更。

輸出：
- 完成事項。
- 修改檔案。
- 驗證方式與結果。
- 未驗證事項。
- 風險與建議。
```
## 主代理整合規則

- 分代理完成後，主代理需快速審查結果與文件差異。
- 若子代理程式修改方案代碼，主代理程式仍需執行專案靜態驗證。
- 若子代理提供 API 資訊，主代理人需標明來源系統：
  - 官方文件或魔獸爭霸Wiki。
  - 用戶提供。
  - 搜尋索引。
  - 實機驗證。
- 若子代理程式遇到工具限制、API不確定性或錯誤，需追加至`Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
- **Markdown 絕對事實與 HTML 轉換守則**：
  - 本專案與子代理程式開發協作的絕對指導文件，一律以 `AGENTS.md` 及其內文指名之 `.md` 檔案為唯一事實與 Facts-of-Truth 參考。
  - HTML 版本人類好讀與預覽使用。子代理執行開發、唯讀分析與回寫時，必須一律以 `.md` 原檔為唯一事實基準，不得以 HTML 文件作為事實參考。
- 任務若修改了文件下的 `.md` 檔案或 `AGENTS.md`，必須於修改後執行轉換工具，更新 `docs_html/` 下對應的 `.html` 檔案以確保一致性。

## RACI 專家分工與PR審查原則

為了讓 24 位 AI 專家在不同開發任務中的定位明確，專案實施 RACI（Responsible、Accountable、Consulted、Informed）分工。

完整名冊、縮寫與 RACI 矩陣以 [Docs/21_RACI_EXPERTS_MATRIX.md](21_RACI_EXPERTS_MATRIX.md) 為唯一基準。
後續所有子代理派工時需注意：
1. **R (Responsible)**：派工時，應指定被屬於該任務領域 **R** 的專家作為子代理的角色與職能（例如修改 Class DB 時指派 `EAM_Class_Expert`）。
2. **A (Accountable)**：子代理提交 PR 或結果後，主代理必須遷移到該任務領域 **A** 的專家進行審查與批准。
3. **C（諮詢）**：子代理在開發中遇到疑難問題時，必須主動向該任務領域被來自 **C** 的專家諮詢。

## 專案品質管制與要因分析原則

為確保程式碼品質與開發的嚴謹性，本專案導入5 Whys (WHY-WHY要因分析)、魚骨圖、對策評估矩陣與PDPC異常防禦機制。

詳細QC規格與指引請見：[Docs/22_QC_ROOT_CAUSE_ANALYSIS_GUIDE.md](22_QC_ROOT_CAUSE_ANALYSIS_GUIDE.md)。
後續開發遵循要求：
1. **Bug診斷**：遇到任何運行時崩潰或邏輯Bug，必須先執行**5個為什麼分析**與**魚骨圖要因分析**，追查根本原因，並讀取問題記錄中。
2. **對策擬定**：設計複雜方案時，必須在 `implementation_plan.md` 提出至少兩個候選方案，並以對策矩陣從效果、吸力、感覺、安全等維度進行量化評分。
3. **相依排程**：`task.md` 任務必須標示依賴（關係甘特圖精神），確保任務開發不會發生衝突。

## EAM 專案優先使用案例

1. Retail API 變更覆核與 Docs 回寫。
2. Secret / taint 風險審查。
3. AuraService 12.1.0 重構前置調查。
4. 渲染器 / DurationObject / DurationTextBinding 實作比較。
5. SavedVariables 遷移測試案例整理。
6. 預算與 CurseForge 發布檢查。

---

## 預定義子代理專家目錄（24 位）

本節提供派工時的角色摘要；完整縮寫、責任邊界及唯一問責者以 `Docs/21_RACI_EXPERTS_MATRIX.md` 為準。

### 證據等級與能力邊界

- `文件已查證`：具有官方公告、官方 UI 原始碼或 Warcraft Wiki 修訂來源。
- `靜態通過`：只代表語法或靜態掃描通過。
- `Mock 通過`：只代表模擬環境通過。
- `PTR 實機通過`：需記錄 PTR build、操作步驟與結果。
- `Retail 實機通過`：需記錄正式服 build、角色／場景、taint 與 Lua error 證據。
- 子代理角色只是派工規格，不代表常駐代理、遊戲客戶端或實機能力已存在。沒有 WoW 客戶端與人類操作證據時，不得宣稱實機通過。

### 1. 核心、API 與渲染（6 位）

- `EAM_Addon_Architect`：核心架構、模組邊界、載入順序與安全鏈設計。
- `EAM_API_Security_Expert`：Retail API、Secret／Protected Data 與 taint 安全決策。
- `EAM_Performance_Expert`：CPU、GC、事件頻率與框架池效能預算。
- `EAM_UI_Renderer_Expert`：Renderer、IconPool、DurationObject 與設定介面。
- `EAM_Lua_VM_Expert`：Lua 語義、資料結構、閉包與局部熱路徑最佳化。
- `EAM_Security_Auditor`：獨立檢查污染、繞過與 protected chain 風險，不參與自行核准其稽核對象。

### 2. 玩家體驗與職業監控（10 位）

- `EAM_UX_Gameplay_Expert`：資訊層級、視覺負擔與戰鬥可用性。
- `EAM_Class_Expert`：職業、專精、英雄天賦與 spellID 資料負責人。
- `EAM_Class_Tanks`、`EAM_Class_Healers`、`EAM_Class_Melee`、`EAM_Class_Ranged`：四類專精智庫。
- `EAM_Tank_Pro`、`EAM_Healer_Pro`、`EAM_Melee_DPS_Pro`、`EAM_Ranged_DPS_Pro`：玩家實戰諮詢席，不可取代 API 或實機證據。

### 3. 測試、資料、發布與治理（8 位）

- `EAM_Mock_Sandbox_Expert`：Mock、單元與整合測試；不得把模擬結果稱為實機結果。
- `EAM_Data_Guard_Expert`：SavedVariables schema、WTF 遷移與設定相容性。
- `EAM_DevOps_Release_Expert`：TOC、靜態驗證、封裝、CI 與發布門檻。
- `EAM_Combat_Scraper_Expert`：戰鬥資料候選蒐集；輸出必須再經 SPEC／SEC 驗證。
- `EAM_API_Change_Intelligence_Expert`（`APICHG`）：從 12.0.0 起追蹤 API change summaries、TOC／revision、官方公告與 UI source diff，產出版本差異、遷移窗口與架構預警。
- `EAM_Aura_121_Migration_Expert`（`AURA121`）：12.1 AuraContainer／AuraButton、Forbidden Aspects、UnitAura 退場條件與行為遷移。
- `EAM_Retail_Client_QA_Expert`（`RQA`）：Retail／PTR 實機案例、taint log、Lua error、CPU／GC 證據與驗證簽收。無遊戲環境時只能設計與判讀測試。
- `EAM_Documentation_Governance_Expert`（`DOC`）：Facts-of-Truth、來源日期、驗證狀態、Markdown→HTML 單向同步與 `EAMCODE placeholder` 污染門檻。

### 新增角色禁止事項

- `APICHG` 不得取代 `SEC` 的安全終審，不得把 Wiki revision time 當成 patch 發布日期，也不得宣稱未執行的 PTR／Retail 實機結果。
- `AURA121` 不得設計 Secret／Forbidden Aspect 繞過；通用安全終審仍由 `SEC` 負責。
- `RQA` 不得自行宣稱未執行的客戶端測試通過，也不得由被測模組作者自行取代。
- `DOC` 不得裁決 API 技術真偽；API 事實由 `SEC/AURA121` 提供，文件角色負責來源與狀態一致性。

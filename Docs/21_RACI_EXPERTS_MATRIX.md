<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod 專家角色 RACI 矩陣

本文件是 EventAlertMod 專家名冊、縮寫與問責關係的唯一基準。所有子代理派工、審查、文件簽收與發布決策均需遵循本矩陣。

## 1. RACI 定義與硬性規則

- `R`（Responsible）：負責執行與產出證據。
- `A`（Accountable）：對該任務領域做最終核准或否決；每列必須恰有一個 `A`。
- `C`（Consulted）：提供專業諮詢，不負最終核准責任。
- `I`（Informed）：接收結果與風險通知。
- 同一角色可以是 `A/R`，但同一任務領域不得出現第二個 `A`。
- 角色定義是派工規格，不代表常駐代理、工具、遊戲客戶端或實機能力已存在。
- 靜態、Mock、PTR 與 Retail 實機證據必須分開標記。

## 2. Canonical 專家名冊（24 位）

| 縮寫 | 專家角色 | 核心職能 |
| --- | --- | --- |
| `ARCH` | `EAM_Addon_Architect` | 核心架構、載入順序、模組邊界與安全鏈設計 |
| `SEC` | `EAM_API_Security_Expert` | Retail API、Secret／Protected Data 與 taint 安全決策 |
| `PERF` | `EAM_Performance_Expert` | CPU、GC、事件頻率、排程與框架池效能預算 |
| `UI` | `EAM_UI_Renderer_Expert` | Renderer、IconPool、DurationObject 與設定介面 |
| `LUA` | `EAM_Lua_VM_Expert` | Lua 語義、資料結構、閉包與局部最佳化 |
| `AUD` | `EAM_Security_Auditor` | 獨立污染、繞過與 protected chain 稽核 |
| `UX` | `EAM_UX_Gameplay_Expert` | 戰鬥資訊層級、視覺負擔與玩家可用性 |
| `SPEC` | `EAM_Class_Expert` | 職業、專精、英雄天賦與 spellID 資料問責 |
| `TANK_P` | `EAM_Class_Tanks` | 坦克專精監控諮詢 |
| `HEAL_P` | `EAM_Class_Healers` | 治療專精監控諮詢 |
| `MEL_P` | `EAM_Class_Melee` | 近戰專精監控諮詢 |
| `RNG_P` | `EAM_Class_Ranged` | 遠程專精監控諮詢 |
| `PRO_T` | `EAM_Tank_Pro` | 坦克玩家實戰諮詢 |
| `PRO_H` | `EAM_Healer_Pro` | 治療玩家實戰諮詢 |
| `PRO_M` | `EAM_Melee_DPS_Pro` | 近戰玩家實戰諮詢 |
| `PRO_R` | `EAM_Ranged_DPS_Pro` | 遠程玩家實戰諮詢 |
| `MOCK` | `EAM_Mock_Sandbox_Expert` | Mock、單元、整合與離線流程測試 |
| `DATA` | `EAM_Data_Guard_Expert` | SavedVariables schema、WTF 遷移與設定相容性 |
| `DEVOPS` | `EAM_DevOps_Release_Expert` | TOC、靜態驗證、封裝、CI 與發布門檻 |
| `SCRAPER` | `EAM_Combat_Scraper_Expert` | 戰鬥資料候選蒐集，不直接核定事實 |
| `APICHG` | `EAM_API_Change_Intelligence_Expert` | Retail API 版本差異、遷移窗口與架構預警 |
| `AURA121` | `EAM_Aura_121_Migration_Expert` | 12.1 AuraContainer／AuraButton、Forbidden Aspects 與 Aura 遷移 |
| `RQA` | `EAM_Retail_Client_QA_Expert` | Retail／PTR 實機測試、taint／錯誤／效能證據簽收 |
| `DOC` | `EAM_Documentation_Governance_Expert` | Facts-of-Truth、來源與驗證狀態、Markdown／HTML 一致性 |

## 3. 任務領域 RACI

為保持表格可驗證，職業智庫與玩家代表不另列欄位；Class DB 與 UI／UX 相關任務預設將其列為 `C`。

| 任務領域 | ARCH | SEC | PERF | UI | LUA | AUD | UX | SPEC | MOCK | DATA | DEVOPS | SCRAPER | APICHG | AURA121 | RQA | DOC |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1. Core 路由與排程 | A | C | C | I | R | I | I | I | C | I | I | I | C | I | C | I |
| 2. Services 資料層 | A | C | C | I | R | I | I | C | C | C | I | I | C | C | C | I |
| 3. UI／Renderer | C | C | C | A/R | C | C | C | I | C | I | I | I | C | C | C | I |
| 4. Secret／Taint 安全 | C | A | C | C | C | R | I | I | C | I | I | I | C | C | C | I |
| 5. Config／Options | C | C | I | R | I | I | C | I | C | A | I | I | I | I | C | C |
| 6. Class DB | I | C | I | I | I | I | C | A | C | C | I | R | I | C | C | C |
| 7. 封裝與發布 | C | C | C | I | I | C | I | I | C | I | A/R | I | C | C | C | C |
| 8. Mock／自動／流程測試 | C | C | C | C | C | I | I | I | A/R | C | C | I | C | C | C | I |
| 9. SavedVariables／WTF 遷移 | C | C | I | C | C | I | I | I | C | A/R | I | I | C | I | C | C |
| 10. 文件與 Facts-of-Truth | C | C | I | I | I | I | I | I | I | I | C | I | C | C | C | A/R |
| 11. Retail／PTR 實機驗證 | C | C | C | C | I | C | C | C | C | C | C | I | C | C | A/R | C |
| 12. Retail 12.1 Aura 遷移 | C | C | C | C | C | I | C | C | C | I | I | I | C | A/R | C | C |
| 13. Retail API change intelligence | C | C | I | I | I | I | I | I | C | I | C | I | A/R | C | C | C |

## 4. 新增角色責任邊界

### APICHG：Retail API change intelligence

- 從 12.0.0 起維護 API 版本、TOC、Wiki revision、官方公告與 UI 原始碼差異矩陣。
- 將新增、移除、棄用、Secret／Forbidden predicate 與 Widget 行為變更轉成 EAM 的 P0／P1／P2 影響、遷移窗口與退場條件。
- 提前建立 capability gate、adapter 與相容策略；不得在 PTR 尚未穩定時移除正式版路徑。
- 不負責 Secret／taint 最終核准，不得把 Wiki 修訂時間當成 patch 發布日期，也不得宣稱未執行的 PTR／Retail 實機結果。
- 版本基準與工作流程分別以 `Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md` 及 `skills/eam-retail-api-change-intelligence/SKILL.md` 為準。

### AURA121：Retail 12.1 Aura 遷移

- 維護 12.0.7／12.1 Aura API build matrix。
- 追蹤 Blizzard 公告、官方 UI 原始碼差異與 Warcraft Wiki 修訂。
- 定義 AuraContainer／AuraButton、Forbidden Partition／Aspect 與舊 UnitAura 掃描的退場條件。
- 明確記錄無法合法保留的逐 spellID、stack、Pandemic 或來源判斷行為。
- 不得設計 Secret／Forbidden Aspect 繞過；安全終審仍由 `SEC` 負責。

### RQA：Retail Client QA

- 管理 Retail／PTR build、角色、專精、戰鬥情境與重現步驟。
- 收集 taint log、Lua error、事件、CPU、記憶體、GC、畫面或影片證據。
- 人類測試者是外部操作與證據來源；沒有客戶端證據時，`RQA` 只能產出測試設計或判讀結果。
- P0 未關閉、Shadow Host 未經安全與實機雙重簽核時，必須否決發布或啟用。

### DOC：文件事實治理

- 維護事實來源、日期、build 與驗證狀態。
- 確保 Markdown 是唯一來源，HTML 僅能單向生成。
- 轉換後必須掃描 `EAMCODE placeholder`、壞連結、表格欄位與專家數量一致性。
- 不裁決 API 技術真偽；版本事實由 `APICHG` 彙整，安全結論由 `SEC` 核定，Aura 遷移結論由 `AURA121` 提供。

## 5. 角色去重規則

- `ARCH` 管架構邊界；`APICHG` 管版本變更情報與遷移提前量；`SEC` 管 API／Secret 安全決策；`AUD` 做獨立對抗稽核。
- `AURA121` 負責 Aura 契約遷移，不取代 `APICHG` 的跨版本情報，也不取代 `SEC` 的安全終審。
- `PERF` 管量測與預算；`LUA` 管語言語義與局部最佳化。
- `UI` 管技術實作；`UX` 與玩家代表提供使用性諮詢。
- `SPEC` 是 Class DB 唯一問責者；`SCRAPER` 只提供待驗證候選資料。
- `MOCK` 負責離線流程案例與 Mock 證據，不取代 `RQA`；靜態、語法或模擬通過不得標記為 Retail 實機通過。
- `DEVOPS` 是發布唯一問責者；`ARCH/SEC/APICHG/RQA/DOC` 提供 gate 意見。

## 6. 派工與簽收檢查

1. 派工前確認任務領域及唯一 `A`。
2. 指定 `R` 的檔案／問題範圍、禁止事項與證據輸出。
3. API 結論標示來源、日期、build、revision 與不確定性。
4. 實作、靜態、Mock、PTR、Retail 狀態不得混用。
5. 修改 Markdown 後依規範同步 HTML，並掃描 `EAMCODE placeholder` 污染。
6. 合併或發布前由該領域唯一 `A` 簽收；P0 未關閉不得發布。
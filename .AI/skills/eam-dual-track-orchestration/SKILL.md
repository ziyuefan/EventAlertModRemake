---
name: eam-dual-track-orchestration
description: >-
  EventAlertModRemake 雙軌動態模型調度、四階思考強度自檢、EAM 反漂移鐵律與 Level 3 閉合 XML 派工契約治理技能。涵蓋 Track A (Argon High) 與 Track B (Hydrogen XHigh) 切換規則、首行狀態標籤規定、Index-First 探勘紀律、Forever 1.60.1 vs Classic Era 邊界與冷面漂移審查 (Cold-Context Drift Audit)。
---

# EAM Dual-Track Orchestration & Level 3 Closed XML Governance

本技能為 EventAlertModRemake (`EventAlertMod`) 之最高協作調度 SOP，對齊 `.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml` v1.4。

---

## 1. 雙軌主副架構（Track A / Track B）

| 軌道 | 狀態（2026-11-13） | 首席架構師與冷面仲裁者 | 執行與驗證子群 | 切換條件 |
| :--- | :--- | :--- | :--- | :--- |
| **Track A** | `STANDBY`（待機） | `Gemini 4 Argon (High)` | `Gemini 4 Hydrogen` 動態 (`LOW / MEDIUM / HIGH / XHIGH`) | Argon 額度充足且獲使用者明確指示切換 |
| **Track B** | **`ACTIVE`（現行）** | **`Gemini 4 Hydrogen (XHigh)`** | **`Gemini 4 Hydrogen` 動態 (`LOW / MEDIUM / HIGH / XHIGH`)** | Argon 額度受限（如目前 `1%`），無須等待即由 Hydrogen (XHigh) 擔任最高仲裁 |

- **切換紀律**：切換軌道時必須同步更新 `.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml` (`active_track` 屬性)、`.AI/AGENTS.md`、`.AI/PROJECT_MEMORY.md`、`.AI/Docs/28_PROJECT_CONTINUITY.md` 與 `.AI/Docs/17_SUBAGENT_WORKFLOW.md`。

---

## 2. 強制首行回覆狀態標籤與四階調度

每次正式回覆使用者時，**第一行**必須輸出狀態標籤：
`【任務階段：＜階段名稱＞｜建議模型與檔位：Hydrogen (LOW / MEDIUM / HIGH / EXTRA) 或 Argon｜治理模式：輕量 / L1+L2 / 完整 XML】`

1. **`[TIER: LOW]`（`Hydrogen - Low` / 輕量）**：更新 `FOLDER_INDEX.html`、提取函式簽章、清洗外部法術/靜態表（`EventAlertMod/Data/`）、重複文件中繼。若發現高檔位執行此類任務，主動建議降檔。
2. **`[TIER: MEDIUM]`（`Hydrogen - Medium` / L1+L2）**：依既有黃金樣板（Golden Reference）執行多檔 API 替換、UI 微調與註解補齊，嚴禁順手重排縮排。
3. **`[TIER: HIGH]`（`Hydrogen - High` / L1+L2）**：單／跨模組開發（光環、冷卻、武器附魔、人物屬性、資源拓樸）、邊界破壞測試與 CLI 驗證（`test_native_apis.py` / `CheckLuaSyntax.ps1`）。
4. **`[TIER: EXTRA / Argon]`（Track B：`Hydrogen - XHigh`｜Track A：`Argon - High` / 完整 XML）**：底層事件排程重寫、跨 3+ 核心模組重構、多版本相容層定錨（Retail `12.1.5` vs Forever `1.60.1`）與新對話冷面漂移審查（`Cold-Context Drift Audit`）。

> 💡 **派遣差異**：`swarm add` 可依上述四階為 worker 顯式指定 `model`；`invoke_subagent` 採 `Model: "inherit"` 繼承主代理設定。

---

## 3. EAM 反漂移鐵律（Anti-Drift Guardrails）

1. **Index-First Context**：探勘階段先讀 `.AI/PROJECT_MEMORY.md`、`.AI/Docs/00_INDEX.md`、`FOLDER_INDEX.html` 與 `EventAlertMod/EventAlertMod.toc`，精準鎖定目標後再局部載入，禁止全文盲讀 `.lua` 塞爆 1M Context。
2. **不可破壞不變量（Immutable Invariants）**：
   - **唯讀保護**：嚴禁繞過或解除 `table.freeze()`（如 `Data/PlayerResourceCatalog.lua`、`Data/Forever/ForeverCatalog.lua`）。
   - **靜態資料隔離**：法術靜態目錄隔離於 `EventAlertMod/Data/`（`SpellArray.lua`、`SpellItem.lua`、`SpellHeuristics.lua`、`Forever/ForeverCatalog.lua`），禁止在 `Core/`、`Services/`、`UI/` 硬編碼大型法術清單。
   - **零全域污染**：內部狀態須為 `local` 或收斂於 `EAM` 命名空間。
   - **版本邊界明確**：明確區分 **Retail `12.1.5`**（Secret Value 四大檢查 `issecretvalue`/`canaccessvalue` 與原生 C-Level Sink）與 **Forever `1.60.1`**（繁中「永恆」／簡中「无限」，Interface `16001`），**嚴禁將 Forever 混同不支援之 `Classic Era`**。
3. **Zero Unrelated Diff & Rule R5 Backup**：修改任何既有檔案前必須先備份至 `.AI/backup/<filename>__yyyyMMddHHmmss`；禁止重排無關縮排或更動範圍外 `.toc` / FrameXML。

---

## 4. Level 3 閉合 XML 派工契約標準範本（Completed）

動及底層事件引擎或跨 3+ 核心模組時，先於唯讀規劃期輸出本閉合契約，經少年欸確認後方可動手：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<argon_ticket id="EAM-TICKET-YYYYMMDD-01" status="PENDING">
  <meta>
    <project_name>EventAlertModRemake</project_name>
    <active_track>TRACK_B</active_track>
    <target_model tier="hydrogen-4-high" reviewer_tier="hydrogen-4-xhigh" execution_mode="surgical" />
    <objective>本次修改之核心目標</objective>
  </meta>
  <scope>
    <allowed_files>
      <file path="EventAlertMod/Services/TargetFile.lua" action="MODIFY" notes="限修改目標函式" />
    </allowed_files>
    <immutable_files>
      <file path="EventAlertMod/EventAlertMod.toc" reason="未授權修改載入順序" />
      <file path="EventAlertMod/Data/SpellArray.lua" reason="靜態資料與邏輯分離" />
      <file path="EventAlertMod/Data/PlayerResourceCatalog.lua" reason="受 table.freeze 保護" />
      <file path="EventAlertMod/Data/Forever/ForeverCatalog.lua" reason="永恆服靜態資料隔離" />
    </immutable_files>
  </scope>
  <invariants>
    <invariant id="INV-1">不可解除 table.freeze() 保護結構</invariant>
    <invariant id="INV-2">不可新增未掛載於 EAM 命名空間的全域變數</invariant>
    <invariant id="INV-3">Retail Secret Value 僅能經 issecretvalue/canaccessvalue 或原生 Sink 傳遞</invariant>
    <invariant id="INV-4">Forever 1.60.1（永恆／无限）與 Retail 12.1.5 分支嚴格區隔，禁混 Classic Era</invariant>
    <invariant id="INV-5">Zero Unrelated Diff 與強制前置 .AI/backup/ 備份</invariant>
  </invariants>
  <execution_plan>
    <step id="1" owner="worker-impl" model_tier="HIGH">依 scope 實施核心修改與單元測試</step>
    <step id="2" owner="worker-qa" model_tier="LOW">執行離線語法與合約驗證</step>
  </execution_plan>
  <verification>
    <command>powershell -NoProfile -File .\.AI\Tools\CheckLuaSyntax.ps1 -AddonOnly</command>
    <command>python .\.AI\Tests\test_native_apis.py</command>
    <command>powershell -NoProfile -File .\.AI\Tools\Test-ValidationContracts.ps1</command>
    <command>powershell -NoProfile -File .\.AI\Tools\Run-FlowValidation.ps1</command>
  </verification>
  <cold_context_review required="true" audit_mode="clean_session">
    <reviewer_track_a>Gemini 4 Argon (High)</reviewer_track_a>
    <reviewer_track_b>Gemini 4 Hydrogen (XHigh)</reviewer_track_b>
    <checklist>
      <item>git diff --name-only 100% 落於 allowed_files 且未觸及 immutable_files</item>
      <item>無未授權全域變數、無 Secret Value 越界比較或索引污染</item>
      <item>無任何無關縮排變動或殘留除錯輸出</item>
      <item>最終編輯後全數測試指令實測通過</item>
    </checklist>
    <verdict>PENDING | APPROVED | REJECTED</verdict>
  </cold_context_review>
</argon_ticket>
```

<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod AI 代理人專用結構化 XML 治理指引手冊 (AI Governance Directive Manual)

> 🤖 **專供 AI 代理人 (Agentic AI / Subagents) 讀取、錨定與任務注入之最高權威 XML 結構化治理體系**

---

## 🧭 1. 核心定義與技術定位 (Core Definition & Positioning)

本檔案所規範之 **.xml 治理文件**，與魔獸世界插件前端所使用的 FrameXML（如 UI 佈局 XML）具有本質上的區別：

- ❌ **非插件運行時 XML (Not AddOn FrameXML)**：不參與遊戲內 UI 繪製、不載入於 `EventAlertMod.toc`。
- ✅ **AI 代理人治理專用 XML (Agentic AI Governance XML)**：作為大型語言模型（LLMs，如 Claude、Gemini Pro、Codex）與子代理集群（Subagents）的高保真度（High-Fidelity）、零歧義結構化指導檔。實體 XML 儲存於 [`.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml`](file:///d:/Project_EventAlertMod_AGY/.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml)。

```
                       EAM 雙軌治理體系 (Dual Governance Tracks)
                                          │
                 ┌────────────────────────┴────────────────────────┐
                 ▼                                                 ▼
     【人類人類讀取軌 (Human Track)】                   【AI 代理人結構化軌 (AI Agent Track)】
     - 格式：Markdown (.md) / HTML                     - 格式：結構化 XML (.xml)
     - 用途：瀏覽器閱讀、圖文導覽、架構討論            - 用途：System Prompt 注入、精確約束、零暖機錨定
     - 核心：00_INDEX, 01_ARCHITECTURE 等             - 核心：AI_GOVERNANCE_DIRECTIVE.xml
```

---

## 💡 2. 為什麼採用結構化 XML 作為 AI 指導檔？(Why Structured XML?)

在多代理人（Multi-Agent）與跨對話（Cross-Session）協作中，傳統純文字或純 Markdown 面臨嚴重挑戰：**注意力稀釋（Lost-in-the-Middle）、模型換代失憶、以及對否定約束（Negative Constraints）遵循度下降**。

結構化 XML 帶來三大質變優勢：

1. **嚴格標籤閉合與樹狀階層（Hierarchical Scoping）**：
   - LLM 內部具備極高的 XML 標籤解析專注度。透過 `<iron_rules>`、`<secret_values_sentinel>` 等語意標籤，模型能精確識別約束範圍，杜絕語意混淆。
2. **子代理零負擔動態切片注入（Subagent Subtree Injection）**：
   - 當調用 `invoke_subagent` 派發任務時，主代理無需將上百頁文檔全部發送，只需抽取 XML 中對應的 `<section>`（如派發審查任務時僅提取 `<secret_values_sentinel>` 與 `<hot_path_rules>`），極致節約 Token 且達成 100% 約束力。
3. **模型換代與上下文截斷的「零暖機錨點」（Zero Cold-Start Anchor）**：
   - 當使用者更換底層模型（例如由 Pro 切換至 Flash、或交接給其他 Agent）時，新 Agent 首要讀取 `AI_GOVERNANCE_DIRECTIVE.xml` 即可在毫秒級瞬間完全恢復記憶，確保架構絕不漂移。

---

## ⚖️ 3. 何時該增設與加載 AI 治理 XML？(Decisional Matrix & Triggers)

本專案將增設與加載 AI 治理 XML 的權責賦予技術架構師，明確建立以下**四大觸發門檻**：

| 觸發條件代碼 | 觸發場景 | 執行動作與加載策略 |
| :--- | :--- | :--- |
| **C1_CROSS_MODEL_CONTINUITY** | **模型版本更換 / 對話歷程截斷** | **強制必讀**。當 Agent 遭遇記憶中斷或模型切換時，第一步必須讀取 `AI_GOVERNANCE_DIRECTIVE.xml` 錨定 5 大鐵律與防禦規範。 |
| **C2_SUBAGENT_PROMPT_INJECTION** | **子代理派工與背景任務** | **動態提取注入**。主代理調用 `invoke_subagent` 時，根據子代理角色自 XML 切割對應標籤注入其 Prompt。 |
| **C3_COMPLEX_MODULE_REFACTOR** | **核心模組重大重構** | **結構化擴充**。當重構光環、冷卻、資源或屬性模組時，於 XML 的 `<architecture_contracts>` 追加狀態機邊界。 |
| **C4_PROTECTED_API_INCIDENT** | **暴雪版本更新引發 Taint 事故** | **即時封鎖**。當 Retail 12.1+ 出現新 Secret 報錯時，立即在 XML 的 `<secret_values_sentinel>` 登錄禁止操作黑名單。 |

---

## 🛡️ 4. 核心治理節點架構一覽 (XML Directives Overview)

實體 XML 檔案包含 8 大核心模組節點：

```xml
<eam_ai_governance version="1.0" last_updated="2026-09-04">
    <!-- 1. 元資料與受眾：界定專案路徑、台灣繁中與「少年欸」稱呼習慣 -->
    <metadata> ... </metadata>

    <!-- 2. 生命週期與何時增設決策：定義四大觸發場景 (C1~C4) -->
    <lifecycle_and_triggers> ... </lifecycle_and_triggers>

    <!-- 3. 五大絕對鐵律：禁止自動部署、正式服限定、舊目錄廢棄、TokenDPAPI加密、修改前備份 -->
    <iron_rules> ... </iron_rules>

    <!-- 4. Secret Values 與 Taint 哨兵：五大檢定 API、禁止四則運算/比對、原生 C-Level Sink -->
    <secret_values_sentinel> ... </secret_values_sentinel>

    <!-- 5. 系統架構契約：Core, Services, UI, Managers 四層邊界職責 -->
    <architecture_contracts> ... </architecture_contracts>

    <!-- 6. 極限效能與熱路徑鐵律：零匿名閉包、零臨時 Table、數字循環、物件池規範 -->
    <hot_path_guidelines> ... </hot_path_guidelines>

    <!-- 7. 驗證門禁體系：語法 76/76、Flow 84/84、契約 496/496、Deploy DryRun -->
    <verification_gates> ... </verification_gates>

    <!-- 8. 對話協同指引：主動同步文檔、問題記錄、嚴格事實查核 -->
    <agent_behavior_protocol> ... </agent_behavior_protocol>
</eam_ai_governance>
```

---

## 📌 5. 權威實體檔案位置 (Physical File Reference)

- **AI 治理專用 XML 實體檔**：[`.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml`](file:///d:/Project_EventAlertMod_AGY/.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml)
- **語法合規驗證**：已通過 Python `xml.etree.ElementTree` 完整語法與結構檢定（8 大核心子節點完整就位）。

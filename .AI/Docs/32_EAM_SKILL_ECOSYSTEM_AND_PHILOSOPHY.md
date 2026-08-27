<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod 21 大核心技能體系與 Agentic AI 治理哲學 (EAM Skill Ecosystem & Philosophy)

> 🚀 **以技能為核心（Skill-Driven）、漸進式揭露（Progressive Disclosure）、確定性交付（Deterministic Execution）的現代化魔獸插件 AI 協同體系**

---

## 🧭 1. 核心治理哲學與架構理念 (Core Philosophy)

在過去大型軟體專案與 AI 協同開發中，最常面臨的致命瓶頸包含：**上下文窗口爆炸（Context Window Explosion）、注意力稀釋（Lost in the Middle）、對話截斷失憶（Context Truncation）、以及更換 Agent 後的架構漂移與破壞（Architecture Drift）**。

為徹底根除上述痛點，EventAlertMod (EAM) 引入了業界領先的 **「全面技能化（Everything as a Skill）」** 架構：

```
                           EAM Agentic AI 治理架構
  ┌────────────────────────────────────────────────────────────────────────┐
  │                    使用者意圖 / 宣告式指令 (User Intent)                 │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │
                                      ▼
  ┌────────────────────────────────────────────────────────────────────────┐
  │         Antigravity / Master Agent (大腦協調器 & 意圖路由器)             │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │ (動態漸進式加載 Progressive Loading)
                                      ▼
  ┌────────────────────────────────────────────────────────────────────────┐
  │                     21 大專案標準化 SKILL 體系 (SOP 規範)                │
  │  ┌──────────────────┐ ┌──────────────────┐ ┌─────────────────────────┐  │
  │  │ 12.x 核心引擎與   │ │ 遊戲資料與監控   │ │ 介面互動與視覺系統      │  │
  │  │ API 防禦體系      │ │ 服務體系         │ │ (UI/UX & Interactivity) │  │
  │  └──────────────────┘ └──────────────────┘ └─────────────────────────┘  │
  │  ┌──────────────────┐ ┌──────────────────────────────────────────────┐  │
  │  │ 測試驗證與除錯   │ │ DevOps、發布自動化與本機資安治理             │  │
  │  │ 門禁體系 (QC)    │ │ (Release, Security & Continuity)             │  │
  │  └──────────────────┘ └──────────────────────────────────────────────┘  │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │ (確定性執行 Deterministic Execution)
                                      ▼
  ┌────────────────────────────────────────────────────────────────────────┐
  │  Subagents (子代理集群) / 腳本工具鏈 / 493+ 靜態契約驗證 / 84+ Flow 沙盒  │
  └────────────────────────────────────────────────────────────────────────┘
```

### 💡 技能化帶來的五大質變效益：

1. **漸進式揭露（Progressive Disclosure）與極致 Token 節約**：
   - 不再一次性將數萬行技術文檔全部塞入 Prompt。
   - 平時僅在記憶體保留 21 個技能的精簡元資料（Name + Description，耗費極低 Token）。
   - 只有當觸發特定任務時，系統才動態將該技能的專屬 `SKILL.md` 注入上下文，以最高專注度完成任務。

2. **「零暖機」跨 Session 與跨 Agent 永續續接（Zero Cold-Start Continuity）**：
   - 對話歷程是暫時的（Ephemeral），但落盤的 SKILL 是永久的（Permanent）。
   - 當新對話建立、或切換至不同模型（如 Flash / Claude / Codex）時，新 Agent 查閱對應 SKILL 即可在數毫秒內掌握最權威的作業程序。

3. **固化除錯結晶，杜絕歷史錯誤重現（Anti-Regression）**：
   - 將專案歷經數月攻克的難題（如 12.x Secret Value Table Key 報錯、CurseForge Cloudflare WAF 穿透、LSM 雙軌資料源去重、OnUpdate 閉包引發 JIT Abort 等）固化為嚴格的「違規禁令（Violations）」與「標準範式（Best Practices）」。
   - 任何 Agent 在撰寫代碼前均受 SKILL 約束，永遠不會重蹈覆轍。

4. **抹平模型能力差距（Capability Equalization）**：
   - 為各項任務提供 Step-by-Step 的明確操作指令與驗證標準。
   - 即使是輕量級子代理人（Subagents），只要依照 SKILL 的 SOP 執行，也能產出與高階旗艦模型 100% 一致的精確成果。

5. **AI Native 智慧代碼庫（Agent-Ready Smart Repository）**：
   - 專案不僅包含魔獸插件源碼，更隨附了自我維護、自我修復、自動測試與安全發布的智慧資產，具備極高的長期可維護性。

---

## 🏛️ 2. 五大領域 21 項 SKILL 全景目錄 (The 21 SKILLs Catalog)

### 領域一：核心架構與 WoW 12.x 現代 API 治理 (Core Engine & 12.x API)

1. **`eam-secret-taint-sentinel` (12.x Secret 數值防禦與 Taint 隔離防護)**
   - **定位**：暴雪 12.0/12.1+ 受保護資料與受污染環境的防禦性編程最高準則。
   - **核心規範**：`issecretvalue` 四大檢查、嚴禁用 Secret 作為 Table Key、嚴禁 Lua 算術/格式化、原生 `StatusBar:SetValue` / `DurationObject` 單向 Sink 直通、零讀回原則。

2. **`eam-zero-alloc-statepool` (零分配狀態物件池與 LuaJIT 效能優化)**
   - **定位**：實現戰鬥中 0-GC（零記憶體分配）與 LuaJIT Zero Trace Abort。
   - **核心規範**：多型 `StatePool` 復用、`Scheduler.after` 延遲調度令牌池替代 OnUpdate 輪詢、`AlertManager.BeginBatch` 批量節流。

3. **`eam-native-aura-compiler` (12.1 Native Aura 容器與規則編譯架構)**
   - **定位**：Retail 12.1 原生光環容器規則指紋編譯架構。
   - **核心規範**：`buildLayoutFingerprint` 佈局指紋、固定槽位 (Fixed Slots) 與動態流動群組 (Flow Groups) 分離、視覺與音效指紋解耦、戰鬥中遞延套用。

4. **`eam-cdm-shadow-host` (CooldownViewer CDM 影子載體寄生技術)**
   - **定位**：利用官方冷卻管理器作為影子載體以避開戰鬥鎖定。
   - **核心規範**：官方池 Hook 攔截、`ClipsChildren` 裁切避讓、名稱重定位與 `FrameLevel` 提權排版。

5. **`eam-api-change-intel` (WoW 最新 API 變更與情報調研技能)**
   - **定位**：跨版本（Retail 12.1 / PTR 12.1 / XPTR 12.0.7）API 演進調查與相容性封裝。
   - **核心規範**：五大權威資料源（暴雪開源 UI 庫、Wago.tools Diffs、Townlong-Yak）、API 變更三步評估法、標準向下相容降級封裝（Polyfill Wrappers）。

---

### 領域二：遊戲資料、職業資源與冷卻服務 (Game Services & Data)

6. **`eam-player-resource-catalog` (17 大全職業/專精資源拓撲與平滑渲染)**
   - **定位**：全職業 40 種專精多資源拓撲動態偵測與渲染。
   - **核心規範**：德魯伊 5 形態 0ms 資源切換、DK 3 專精動態圖示 + 6 格微型充能冷卻條、需求導向背景取樣器 (`probe-gated sampler`)。

7. **`eam-cooldown-activation-guard` (精確施法過濾與法術覆蓋狀態機)**
   - **定位**：冷卻技能精確啟動與天賦形態覆蓋同步。
   - **核心規範**：`UNIT_SPELLCAST_SUCCEEDED` 精確玩家判定、`COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` 動態覆蓋同步、三態設定繼承模型。

8. **`eam-target-aura-anonymous-probe` (目標光環匿名偵測與無污染採集)**
   - **定位**：在 12.x 目標光環私有化限制下，實現零污染的安全採集。
   - **核心規範**：`TooltipMonitorService` 匿名回呼、Ctrl+Alt 修飾鍵判定、非戰鬥安全閘門、嚴禁遍歷 Frame 與 GetMouseFocus。

9. **`eam-player-stat-monitor` (18 大人物屬性與動能滑翔移速即時監控)**
   - **定位**：18 種人物屬性監控、動能滑翔速度計算與視覺化。
   - **核心規範**：四合一速度淬鍊（含 `C_PlayerInfo.GetGlidingInfo` 830%~1400% 飛龍速度）、原生進度條色彩分流、自訂警戒值紅框。

---

### 領域三：介面互動與視覺系統 (UI/UX & Interactivity)

10. **`eam-ui-interactive-suite` (無縫側窗吸附、聯動拖曳錨點與自適應選單)**
    - **定位**：現代化魔獸風格設定介面之佈局與操作反饋標準。
    - **核心規範**：APPEND 模式無縫側窗吸附、跨視窗同步平滑拖曳、側窗互斥機制、奶牛頭排版預覽、螢幕鎖定與全介面懸停提示 (`EAM.UI.setTooltip`)。

11. **`eam-sharedmedia-integration` (LibSharedMedia 素材動態探測與全域字型熱套用)**
    - **定位**：接入 `LibSharedMedia-3.0` (LSM) 素材生態。
    - **核心規範**：`ensureLSM()` 雙軌去重查詢、`EAM_FONT_FAMILY_CHANGED` 事件全域熱套用、SavedVariables 白名單防禦解除、長清單自適應捲動選單 (`buildScrollableDropdownMenu`)。

12. **`eam-profile-codec-manager` (8 大分類字串編解碼、設定分享與 WTF 遷移)**
    - **定位**：設定檔（Profile）模組化分享、字串壓縮與版本向後相容。
    - **核心規範**：8 大分類獨立自選匯出/匯入、校驗碼分析、WTF 存檔 Schema 自動無損升級。

13. **`eam-glow-pandemic-visuals` (Proc 金色發光、DoT Pandemic 亮框與戰鬥紅框)**
    - **定位**：戰鬥視覺反饋與高亮系統。
    - **核心規範**：快捷列 Proc 發光同步、DoT Pandemic 窗口亮框、雙層 Glow 降級策略（LibButtonGlow 優先，戰鬥回退自有動畫邊框）、全螢幕進入戰鬥紅框閃爍 (`CombatFlash`)。

---

### 領域四：測試驗證與除錯體系 (QC & Validation)

14. **`eam-flow-validation-harness` (離線 Flow 狀態機沙盒自動化驗證)**
    - **定位**：離線環境下自動化運行 84+ 項業務狀態機測試。
    - **核心指令**：`pwsh -NoProfile -File .\.AI\Tools\Run-FlowValidation.ps1`。
    - **核心規範**：模擬戰鬥進出、形態切換、光環過期、能量更新與 Secret 注入。

15. **`eam-validation-contracts` (493+ 項全專案代碼契約斷言與 AST 掃描)**
    - **定位**：專案發布與變更前的最高門禁（Gatekeeper）。
    - **核心指令**：`pwsh -NoProfile -File .\.AI\Tools\Test-ValidationContracts.ps1`。
    - **核心規範**：全專案 71 個 Lua 語法 100% 通過、TOC 載入鏈驗證、5 大語系 144 詞條鏡像對齊、打包排除契約。

16. **`eam-live-matrix-inspector` (PTR / XPTR / Retail 真人實機測試矩陣指南)**
    - **定位**：跨版本實機測試規範與回報協議。
    - **核心規範**：維護 `Data/LiveValidationMatrix.json` 與 `Docs/29_LIVE_TEST_STEP_GUIDE.md`，規範實機回報標準欄位。

---

### 領域五：DevOps、發布自動化與本機資安治理 (DevOps, Security & Continuity)

17. **`eam-curseforge-publisher` (CurseForge 安全發布與版本管理)**
    - **定位**：發布插件至 CurseForge 的標準化全流程。
    - **核心指令**：`pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1`（支援 `-DryRun` 模擬）。
    - **核心規範**：Cloudflare WAF 穿透標頭、MIME 嚴格宣告、版本代碼對齊（12.1.0 = `16519`）、DPAPI 記憶體解密。

18. **`eam-secret-vault-manager` (Windows DPAPI 本機機密雙重加密與防外流)**
    - **定位**：創作者 API Token 與機密憑證的 100% 本機隔離與加密。
    - **核心指令**：`pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1 -SetToken`。
    - **核心規範**：作業系統級 DPAPI 二進位加密（`API_TOKEN.SEC`）、Git 與打包排除 100% 審查、記憶體瞬時解密。

19. **`eam-local-wow-deployer` (WoW 本機多客戶端安全部署與存檔備份還原)**
    - **定位**：本機多客戶端自動化安全部署與 WTF 備份。
    - **核心指令**：`pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1`。
    - **核心規範**：Registry 智慧偵測、Reparse Point fail-closed 絕對防禦、自動時間戳備份與一鍵 Rollback。

20. **`eam-docs-site-builder` (GitHub Pages 文件網站自動建置與多語系導覽)**
    - **定位**：Markdown 文檔與更新日誌自動轉換為現代化說明網站。
    - **核心指令**：`$env:EAM_DOCS_OFFLINE="1"; python .\.AI\Tools\batch_convert_docs.py`。
    - **核心規範**：頂部 Navbar 注入、Changelog 語意化 HTML 渲染、離線純淨轉換。

21. **`eam-project-continuity-governor` (專案記憶、連續性與上下文交接治理)**
    - **定位**：跨 Session 與多 Agent 協同的單一事實來源維護。
    - **核心規範**：維護 `ProjectContinuity.json`、`28_PROJECT_CONTINUITY.md` 與 `15_DEVELOPMENT_ISSUE_LOG.md`。

---

## 🛠️ 3. 技能部署架構與調用方式 (Deployment & Usage)

專案中所有 21 項技能皆採用雙軌實體部署，確保版本控制與全域可達性：
- **專案內部版本控制（VCS Tracked）**：
  - `D:\Project_EventAlertMod_AGY\.agents\skills\<skill-name>\SKILL.md`
  - `D:\Project_EventAlertMod_AGY\.AI\skills\<skill-name>\SKILL.md`
- **本機 Antigravity 全域目錄（Global Discovery）**：
  - `C:\Users\ZYF\.gemini\config\skills\<skill-name>\SKILL.md`

### 💬 自然語言與意圖調用範例：

```markdown
使用者輸入：「幫我發布目前的開發版至 CurseForge」
➔ Agent 自動觸發：[eam-curseforge-publisher] + [eam-secret-vault-manager]

使用者輸入：「12.1.0 戰鬥中這個能量 API 報錯了，請排查 Secret」
➔ Agent 自動觸發：[eam-secret-taint-sentinel] + [eam-player-resource-catalog]

使用者輸入：「幫我把更新日誌與文檔站重新編譯並推送到 GitHub Pages」
➔ Agent 自動觸發：[eam-docs-site-builder] + [eam-validation-contracts]

使用者輸入：「調查最新暴雪 PTR Build 關於技能冷卻覆蓋的 API 變更」
➔ Agent 自動觸發：[eam-api-change-intel] + [eam-cooldown-activation-guard]
```

---

## 🏁 4. 結語 (Conclusion)

EventAlertMod 透過這 21 項高度專業化、模組化且相互協同的 SKILL 體系，將龐大的魔獸插件重構工程轉化為**高度結構化、可確定性重複執行、且完全免除 AI 失憶與幻覺風險的現代化軟體資產**。這不僅是 WoW 插件開發的標竿，更是現代 Agentic AI 協同治理的典範實踐。

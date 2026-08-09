<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod 正式服裝重寫：AI 上下文

## 優先續接路由

重新進入專案、發生上下文壓縮或需要確認目前進度時，先讀 `Docs/28_PROJECT_CONTINUITY.md`，再讀 `Data/ProjectContinuity.json`。前者提供人類可讀決策與實機待辦；後者以嚴格 Schema 分離 facts、inferences、work items、trials 與 unverified。詳細試錯只追到 `Docs/15_DEVELOPMENT_ISSUE_LOG.md` 的穩定 issue ID，不以本文件或舊對話摘要猜測目前狀態。

目前續接快照為 `2026-08-08.1`；離線通過不得取代 PTR、XPTR 或 Retail 真人簽收。

## 專案概要

EventAlertMod (EAM) 是一個用於輕量級光環的魔獸世界插件，
冷卻的時間和物品冷卻。冷卻的身份很簡單：顯示很重要
屬性和物品狀態為關鍵圖標，而不會成為 WeakAuras 克隆。

此重寫僅針對魔獸世界正式服版，正式服版 12.x /
午夜時代的 API 是預期的衍生性商品。現有經典、熊貓之謎經典服、
Cata Classic、Wrath Classic、TBC、Era 和特定地區的經典分店是
僅歷史行為，不得加工新架構。

## 重寫方向

目前的原始碼樹保留了許多行為，但混合了相容性
分支、UI建置、光環掃描、冷卻專案、緩存產生、
特殊資源、斜線指令、全域變數、本地化和框架佈局
相同的運行時表面。重寫應保留有用的數據並提供給用戶
影像，同時以顯式模組取代內部結構。

所需的目標模組：

- `Core/Env.lua`
- `Core/Util.lua`
- `Core/Constants.lua`
- `Core/EventRouter.lua`
- `Core/Scheduler.lua`
- `Core/SavedVariables.lua`
- `Core/Performance.lua`
- `Services/AuraService.lua`
- `Services/CooldownService.lua`
- `Services/ItemCooldownService.lua`
- `Services/SpellInfoService.lua`
- `UI/IconPool.lua`
- `UI/Renderer.lua`
- `UI/Options.lua`
- `UI/Slash.lua`
- `Debug/DebugState.lua`
- `Debug/PromptExport.lua`

## 不可協商的界限

- 沒有秘密值可以繞過。
- 沒有受到保護的資料繞過。
- 沒有戰鬥自動化。
- 沒有外部依賴。
- 沒有複雜的使用者腳本引擎。
- 密集的持續掃描。
- 沒有每個圖示計時器、每個示波器計時器或每個專案計時器硬體。
## 簡單原則
EAM 對於一般使用者來說應該簡單保留：新增文字 ID、啟用警報，請參閱
圖標，調整小組顯示選項，並匯出緊湊的除錯狀態
僅提供。

## 現有討論主播

之前的ChatGPT討論上下文位於：

- `DevDocument/ChatGPT/EventAlertMod_ChatGPT_Discussion_Context.md`

該文件中的重要歷史要點：

- EAM 不基於 Ace3。
-目前目錄使用 `RequiredDeps: !Lib_ZYF`，但重寫目標並不是新的
  外部依賴。
- `/eam opt` 是記錄的設定指令。
- 現有行為包括自身光環、目標光環、角色冷卻時間、物品
  冷卻時間、工具提示符號/物品ID、在地化和選擇性的除錯助手。
- 較早的工作已經超過“Main/EventAlert_EAFun.lua”作為相容性
門面。未來的代理人一定不能把文件想像成最終的架構。

## 首次通過審核結果
`Docs/01_ARCHITECTURE.md` 包含目前檔案對映和模組
`Docs/03_STATE_SCHEMA.md` 包含 SavedVariables 和全域變量
`Docs/05_PERFORMANCE_GUIDE.md` 包含候選熱路徑，
OnUpdate/C_Timer的使用和分配風險。 `文件/07_MIGRATION_NOTES.md`
包含行為遷移註釋。

## 2026-08-09 實機步驟與 Alpha 3 候選入口

- 目前機器可讀快照為 `Data/ProjectContinuity.json` 的 `2026-08-09.2`；人類交接見 `Docs/28_PROJECT_CONTINUITY.md`。
- 34 案 PTR／XPTR／Retail 的前置條件、逐步操作與通過證據見 `Docs/29_LIVE_TEST_STEP_GUIDE.md`。
- Alpha 3 候選包含 Target Aura hover+Ctrl+Alt、Macro spell/item ID、手動 Ctrl+C 報告交接、About、監控 Tooltip 與七色分類邊框；目前只有離線 gate，不代表三個客戶端已實機簽收。

## 2026-08-09 SVG A/B 與 3px 邊框續接

- 分類邊框已捨棄含透明留白的 ActionButton border，Legacy 與 Native 都改用 WHITE8X8 實色 Texture，位於 BORDER 層並四邊固定外擴 3px。
- Flow 面板新增玩家操作的 SVG 能力測試；VectorGraphics 與 Texture 各自驗證 SetSVG、HasSVG、GetSVGFileID 分類、ClearSVG 與 reload。
- SVG 報告型別為 EAM_SVG_CAPABILITY_REPORT，rawFileIDsCollected 固定 false；可由 JSON 或遊戲內持久化檔案以 ReportType SVG 匯入。
- 最新離線 gate 為 Lua 50/50、Flow 54/54、Validation Contracts 247/247。3px 邊框與 SVG 圖樣仍待 PTR 玩家目視，不得標記實機通過。

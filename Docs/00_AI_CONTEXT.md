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

<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod 正式服裝重寫：AI 上下文

## 優先續接路由

重新進入專案、發生上下文壓縮或需要確認目前進度時，先讀 `Docs/28_PROJECT_CONTINUITY.md`，再讀 `Data/ProjectContinuity.json`。前者提供人類可讀決策與實機待辦；後者以嚴格 Schema 分離 facts、inferences、work items、trials 與 unverified。詳細試錯只追到 `Docs/15_DEVELOPMENT_ISSUE_LOG.md` 的穩定 issue ID，不以本文件或舊對話摘要猜測目前狀態。

目前續接快照為 `2026-08-13.1`；離線通過不得取代 PTR、XPTR 或 Retail 真人簽收。

## 專案概要


EventAlertMod (EAM) 是一個用於輕量級光環的魔獸世界插件，
冷卻的時間和物品冷卻。冷卻的身份很簡單：顯示很重要
屬性和物品狀態為關鍵圖標，而不會成為 WeakAuras 克隆。

此重寫僅針對魔獸世界正式服版，正式服版 12.x /
午夜時代的 API 是預期的衍生性商品。現有經典、熊貓之謎經典服、
Cata Classic、Wrath Classic、TBC、Era 和特定地區的經典分店是
僅歷史行為，不得加工新架構。

## 語系與語言選擇契約

- `Locale/Common.lua` 建立固定 catalog：`enUS`、`zhTW`、`zhCN`、`koKR`、`ruRU`。
- `ruRU.lua` 必須與 `enUS.lua` 的 `L.*` key 完整對齊；其他語系缺少的 key 由 enUS fallback 補底。
- `Auto Detect` 是唯一固定英文名稱，且 `EAM_DB.config.language` 的預設值為 `auto`；其餘選項以原生語系名稱顯示。
- 選擇器只寫入設定並提示玩家自行輸入 `/reload`，不由 EAM 自動呼叫 `ReloadUI`，以避免載入期 UI 半套用。

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

- 目前機器可讀快照為 `Data/ProjectContinuity.json` 的 `2026-08-09.3`；人類交接見 `Docs/28_PROJECT_CONTINUITY.md`。
- 37 案 PTR／XPTR／Retail 的前置條件、逐步操作與通過證據見 `Docs/29_LIVE_TEST_STEP_GUIDE.md`。
- Alpha 3 候選包含 Target Aura hover+Ctrl+Alt、Macro spell/item ID、手動 Ctrl+C 報告交接、About、監控 Tooltip 與七色分類邊框；目前只有離線 gate，不代表三個客戶端已實機簽收。

## 2026-08-09 SVG A/B 與 3px 邊框續接

- 分類邊框已捨棄含透明留白的 ActionButton border，Legacy 與 Native 都改用 WHITE8X8 實色 Texture，位於 BORDER 層並四邊固定外擴 3px。
- Flow 面板新增玩家操作的 SVG 能力測試；VectorGraphics 與 Texture 各自驗證 SetSVG、HasSVG、GetSVGFileID 分類、ClearSVG 與 reload。
- SVG 報告型別為 EAM_SVG_CAPABILITY_REPORT，rawFileIDsCollected 固定 false；可由 JSON 或遊戲內持久化檔案以 ReportType SVG 匯入。
- 最新離線 gate 為 Lua 50/50、Flow 54/54、Validation Contracts 264/264。PTR 69189 已確認兩條 SVG 圖樣可顯示，但修正版 Texture clear/reload 與 3px 邊框仍待玩家重測，不得標記完整實機通過。

## 2026-08-12 小地圖 SVG 與 EAM 主題選擇

- 小地圖按鈕不再把聲音 FileDataID 當作貼圖；`UI/Options.lua` 先嘗試載入專案自有 `Media/SVG/eam-minimap.svg`，`Texture:SetSVG` 不可用或失敗時回退 `INV_Misc_QuestionMark`。按鈕的左鍵、右鍵與拖曳行為不變。
- `UI/Theme.lua` 集中管理 EAM 自有視窗與按鈕的 palette，提供 `EAM`、`FF7`、`Windows XP`、`Borland C++ IDE`、`DOS CRT` 與 `macOS Aqua` 六個選項；SavedVariables 只保存 `config.theme` 的 `eam|ff7|winxp|borland|doscrt|aqua`，非法值回退 `eam` 並留下 migration warning。
- 主題切換只影響 EAM 自有 Options／About／Tooltip popup、位置／清單／條件視窗與 Flow／Live／Prompt／SVG／UnitPower 除錯面板，不改 AlertBorderStyles 的七種內容語意顏色，也不鉤 Blizzard secure/protected frame。
- 戰鬥中選擇主題只保存 pending selection，於 `PLAYER_REGEN_ENABLED` 後套用；小地圖 SVG 載入與主題 palette 均不讀取或寫入 Secret Value。
- `wowtools.work` 僅作為唯讀資料瀏覽參考，專案不依賴外部 FileDataID 或遠端素材。
- 本輪離線 gate：Lua 51/51、Flow 54/54、Validation Contracts 328/328；仍不代表 PTR／XPTR／Retail 真人簽收。

## 2026-08-13 AuraSound 細部設定續接

- PTR 12.1 build 69273 的固定生成文件確認 `C_UnitAuras.AddAuraSound` 支援 Added、ApplicationsIncreased、Removed；結構只包含 unit、SpellID、音檔名稱／FileDataID 與 output channel，沒有 soundKitID、caster 或 auraFilter。
- Aura 細部設定可選共用音效素材，並獨立勾選新增、層數增加、移除；三項皆未勾選時沿用全域音效。12.0.7 控制項為 capability 降級且不得呼叫 12.1 API。
- 全域 `showSound` 是 master gate；純音效變更只同步 C-side registration，不建立新 AuraContainer。註冊失敗保留舊 registry，移除失敗的 ID 留待後續重試。
- Flow 已增加 SavedVariables round-trip、container／sound fingerprint 分離、純音效零容器重建、三 trigger payload 與失敗回滾；真人矩陣升為 `2026-08-13.1` 共 37 案。
- Native AuraSound 只能依 unit+SpellID 觸發，不能精確表達 `fromPlayer` 或 Aura 極性；這是公開 API 限制，必須由 PTR 真人觀察 over-fire，不得以離線結果宣稱實播通過。
- 本輪離線 gate：Lua `54/54`、Flow `all 61/61`、Validation Contracts `355/355`；Flow artifact 為 `TestResults/EAM_FlowValidation_all_20260813_013945.json`。

## 2026-08-13 Alpha 4 發布交接

- Alpha 4 將現有八個功能模組開關與職業 profile 隔離列入發布範圍；模組面板從主設定視窗的「功能模組」按鈕開啟。
- moduleToggles 的預設值全部為啟用；停用只讓事件入口短路、清理既有提醒，避免反覆註冊事件或在戰鬥中重建受保護結構。
- active class profile 由 UnitClass 白名單決定；v4 全域清單不能可靠拆分時保留 migration backup 或 unassignedLegacy，不以 SpellArray 猜測其他職業資料。
- /eam list、lookup、lookupfull 與 showcast 只操作目前職業的安全候選；不掃描整個 SpellID 空間，也不自動寫入監控清單。
- JSON／Base64 profile 分享尚未成為正式 runtime API；正式程式不使用 LegacyReference 的 loadstring 匯入路徑。下一輪若實作，必須先完成嚴格 parser、checksum、preview/apply 與戰鬥延後契約。
- 本輪離線 gate 維持 Lua 54/54、Flow all 61/61、Validation Contracts 355/355；Alpha 4 Release 仍不代表 PTR、XPTR 或 Retail 真人簽收。

## 2026-08-14 Alpha 5 發布交接

- Alpha 5 將 Core/ProfileCodec.lua 與 UI/ProfileCodecPanel.lua 納入正式 runtime；分享字串格式為 EAMAP1:<base64(canonical JSON)>，只處理目前 active class 的允許 module scope。
- codec 使用嚴格 JSON／Base64 parser、Adler-32 checksum、大小／深度／節點上限與 preview fingerprint；merge／replace 只在非戰鬥套用，拒絕外部 Lua、Secret 值、未知 schema、重複 ID 與不合法 class/module。
- 新增四種 EAM 自有字型選擇；SavedVariables.updateFontFamily 做白名單正規化與 no-op revision，TextPlacement 只改 EAM 自建 FontString。
- Locale registry 會在 EAM_LANGUAGE_CHANGED 後重新套用 EAM 自有按鈕、下拉、條件與 spec menu；Auto Detect 固定英文，無需 /reload 才能看到動態切換。
- 本輪離線 gate 為 Lua 56/56、Flow all 66/66、Validation Contracts 360/360；Flow artifact 以本輪 TestResults 產物為準。PTR／XPTR／Retail 仍需玩家自行實測，不可升格為真人 pass。

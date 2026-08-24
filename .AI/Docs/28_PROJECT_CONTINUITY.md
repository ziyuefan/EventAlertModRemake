<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod 專案續接與試錯索引

## 1. 用途與權責

本文件是上下文壓縮、代理交接或長時間中斷後的第一個人類可讀續接點。機器可讀的當前狀態以 `Data/ProjectContinuity.json` 為準；詳細試錯時間線保留在 `Docs/15_DEVELOPMENT_ISSUE_LOG.md`；真人實機案例定義保留在 `Data/LiveValidationMatrix.json`。三者不得互相複製整段內容。

目前快照版本：2026-08-24.15 (Alpha 7.9)。

## 2026-08-24 Alpha 7.9 全介面懸停提示、主視窗一鍵置中重置與圖文導覽快照（現行）

- current-of-truth：專案進入 Alpha 7.9 發布階段；全介面 10 大視窗已完整配置 Hover Tooltips、主視窗螢幕邊界鎖定與一鍵居中重置命令 (`/eam reset`)、官方 README 加入 14 張高畫質介面圖文導覽，完成 68/68 語法、84/84 Flow 驗證與 493/493 契約測試。
- 全介面控制項懸停提示 (Comprehensive UI Hover Tooltips)：
  1. 在全部按鈕、核取方塊、滑桿、下拉選單、輸入編輯框與清單操作列加入直觀的懸停說明提示 (Hover Tooltips)，清晰標註控制項用途、設定範圍與操作指引。
  2. 實作通用工具函式 `EAM.UI.setTooltip`，支援純文字、多語系字串與表格綁定，徹底消除介面操作門檻。
  3. 覆蓋主設定面板、告警框架排版、法術清單、條件設定、批次輸入、角色屬性、職業資源、功能模組、Profile 分享與除錯中心共 10 大視窗。
- 角色屬性與吸收量監控（全新模組）：
  1. 支援 18 種核心屬性取值監控（力量、敏捷、耐力、智力、致命、加速、精通、臨機應變、閃避、汲取、速度屬性評級、跑速、泳速、飛速、飛龍模式飛速、總吸收盾量、治療吸收量、護甲值）。
  2. 速度類別淬鍊為 4 大項：跑速 (`GetUnitSpeed` 地面)、泳速 (水下)、飛速 (傳統懸浮飛行 310%~420%)、飛龍模式飛速 (調用 `C_PlayerInfo.GetGlidingInfo` 取得 830%~1400% 動能滑翔速度)，並以 0.1s 高頻計時器即時平滑刷新。
  3. 繁體中文術語嚴格對齊台灣官方用語（致命、加速、臨機應變）。
  4. 獨立二級設定面板 (`UI/PlayerStatPanel.lua`)：無縫吸附主視窗右側並支援同步平滑拖曳，支援單項開關、替代圖示/代碼、圖示大小、數值/名稱字型大小、替代文字、小數位數 (0~2)、簡寫 (k/M)、警戒值上下限紅框、進度條開關與獨立框架排版。
- Secret Value 防護與原生 StatusBar Sink 整合：
  1. 針對 Retail 12.0+ / 12.1+ 部分 Unit API（如吸收量、移速等）在戰鬥/受污染環境下回傳受保護之 Secret Number，全面加入安全數值檢查，防止 Lua 層運算或格式化報錯。
  2. 為屬性框架預建原生 C-Level `StatusBar`，遭遇 Secret 數值時直接將原始數值單向傳入 `StatusBar:SetValue` 展現視覺進度比例，Lua 不進行字串轉換與數值讀回。
  3. 支援依屬性類別專屬著色（吸收盾天藍、治療吸收紫紅、移速青綠、副屬性金黃、主屬性橙紅、護甲鋼藍）。
- 全模組自訂替代圖示支援 (Custom Icon Override Across All Modules)：
  1. 在自身光環、目標光環、技能冷卻、物品冷卻、地面效果等所有模組細部設定中，新增「自訂替代圖示（代碼或材質路徑）」輸入框、即時動態預覽方塊與 Wago.tools 查詢網址框。
  2. 服務層發布告警狀態時優先採用自訂圖示覆蓋原生預設圖示。
- 經典奶牛頭位置預覽 (Classic Cow Head Anchor Preview)：
  1. 拖曳排版位置時改用經典奶牛頭圖示 (`Interface\Icons\Spell_Nature_Polymorph_Cow`) 作為畫面預覽，並支援 8 大告警框架即時標籤名稱與紅/綠框高亮區分。
- 全方位即時熱預覽 (Live Real-time Config Preview)：
  1. 調整圖示尺寸、水平/垂直間距、透明度、扇形倒數轉圈動畫、轉圈透明度、自身/目標減益色度、法術/倒數/堆疊字型大小、成長方向時，畫面上告警框架與圖示即時 60fps 熱更新響應，無需重啟。
- 進入戰鬥全螢幕紅框閃爍 (In-Combat Fullscreen Red Edge Flash)：
  1. 實作 `UI/CombatFlash.lua` 全螢幕低血/戰鬥紅框閃爍動畫，監聽 `PLAYER_REGEN_DISABLED` 事件觸發戰鬥進入警示，並在主選單提供即時測試按鈕。
- 主題樣式與主視窗螢幕邊界防護：
  1. EAM 預設主題改回經典魔獸紅色選單按鈕與仿石框邊緣。
  2. 修正關閉主視窗時在 `closeAllSidePanels` 缺少 `close()` 引發的 nil call 錯誤，實作防禦性 `safeClosePanel` 機制。
  3. 主視窗增加 `SetClampedToScreen` 螢幕邊界鎖定，防止拖出畫面無法找回。
  4. 新增 `/eam reset` (或 `/eam center` / `resetpos`) 斜線命令、小地圖按鈕中鍵點擊與 Shift+點擊，一鍵將主視窗拉回螢幕正中央。

## 2026-08-24 Alpha 7.7 聯動移動錨點、側窗互斥與雙軌日誌快照

- current-of-truth：專案進入 Alpha 7.7 發布階段；完成 65/65 語法、84/84 Flow 驗證與 493/493 契約測試。
- 介面與互動升級：
  1. 子視窗聯動移動錨點：點擊各類別監控子視窗時，自動在畫面上亮起該模組專屬半透明移動錨點框（標記「按住左鍵拖曳」），方便玩家直觀拖曳調整在畫面上的定位；關閉子視窗時自動隱藏所有錨點並套用排版。
  2. 排版位置全開模式：開啟「告警框架位置與排版」視窗時自動亮起全部 7 大框架移動錨點。
  3. 全二級附屬側窗互斥：開啟職業資源、除錯中心、Profile 匯入/匯出、功能模組、關於或清單子視窗時，自動關閉其他側邊面板，徹底消除多側窗重疊。
  4. 除錯中心修復：修正流程測試運行非同步回傳布林值導致的 index error，補全格式化輸出；修正系統診斷報告匯出按鈕調用。
- 雙軌日誌與 Release 命名：
  1. 專案根目錄建立 `changelog.md` 承載完整工程與治理細節，`changelog.txt` 維持純粹魔獸插件更新。
  2. GitHub Release 產物命名標準化為 `EventAlertMod_MN_yyyyMMdd_HHmmss-<Tag>_AGY.zip`（後續發布預設帶 `_AGY` 後綴）。

## 2026-08-23 Alpha 7.5 發布與 UI/Profile/DK 符文重構快照

- current-of-truth：專案進入 Alpha 7.5 發布階段；完成 65/65 語法、84/84 Flow 驗證與 493/493 契約測試。
- 介面與交互：
  1. 所有視窗右上角實作原生 `UIPanelCloseButton` (`[X]`) 快速關閉按鈕。
  2. 視窗階層採用 APPEND 側邊無縫吸附（主選單 ➔ 清單/排版/職業資源 ➔ 細部條件/批次輸入），並支援跨視窗同步連動拖曳。
  3. 主選單分類提升：「★ 玩家職業資源設定」提升至第 7 項目；除錯類功能統整至 4-Tab「除錯與測試診斷中心」。
- Profile 模組升級：
  1. 支援 8 大分類自選匯出／匯入（自身光環、目標光環、技能CD、物品CD、地面效果、框架排版位置、職業資源設定、一般偏好設定）。
  2. 提供 `[全選]`、`[僅告警清單]`、`[僅排版設定]` 快速勾選按鈕與預覽區塊分析。
- 職業資源與 DK 符文：
  1. 職業資源設定支援滑桿即時熱預覽與自動儲存。
  2. 死亡騎士符文支援 3 大專精動態圖示、6 格微型充能冷卻條（0%..100% 平滑動畫）與 `/eam rune` 槽位診斷視窗。

## 2026-08-21 新根與部署治理交接快照（現行）

- current-of-truth：專案根為 `D:\Project_EventAlertMod`；插件唯一來源為 `EventAlertMod/`；AI 治理為 `.AI/`；部署工具為 `Deploy/`；`Dist/` 為 ignored 本機產物。
- 本機唯讀 Status：Retail/PTR `12.1.0.69382`、XPTR `12.0.7.68887`；三個 EventAlertMod 目標目前均為 physical，但只有 PTR 含 `EventAlertMod.toc`，Retail/XPTR 尚缺該檔；`Test-LocalWoWEnvironment` 為 1/3，Deploy Status/DryRun 三通道 pass 只代表安全部署前檢，不能宣稱三通道 ready。此前 Retail/XPTR link blocked、PTR physical 的結果只屬歷史證據，仍須每次執行前重新檢查。
- 部署治理：Registry 優先、`Deploy/DeploymentTargets.json` JSON fallback；使用者可確認候選根或指定 `-WowRoot`；Status 列三通道 ProductVersion；PTR/XPTR 僅互動詢問是否包含 Retail；noninteractive 不暗加；任何 Reparse Point fail-closed。
- 封裝治理：插件 ZIP 只取 `EventAlertMod/` exact tree；原始碼 ZIP 排除 `Dist/.git/.codex-remote-attachments/attachments/backup/trash/TestResults/cache/log/zip` 等本機衍生物，但保留 `.vscode/`、`.codex/`、`.AI/` 與 `.AI/docs_html/`。
- 本次只更新 `.AI` 治理文件、連續性 JSON、兩份玩家可見 changelog 與離線 `docs_html`；未執行 Deploy、未寫入 WoW 目錄、未使用外部翻譯服務。
- 機器可讀續接資料以 `Data/ProjectContinuity.json` 的 schema 1 結構為準；本快照用新 fact/work/trial ID 追加現況，不刪除歷史證據。

## 2026-08-21 玩家多資源交接快照（現行補充）

- 正式玩家資源路徑已拆成 Catalog、Capability、Service、PowerRenderer 與設定 Panel；`ClassPowerService` 只保留相容 facade。
- Catalog 為 17 種資源、13 職業／40 組專精拓撲；同一專精可同時追蹤多種目前可用資源。德魯伊拓撲包含 Mana、Rage、Energy、ComboPoints、LunarPower。
- schema v6／resource schema 3 提供 global defaults、class defaults、spec overrides、獨立顯示欄位、reset 與 no-op revision；非戰鬥設定事件立即重建，戰鬥中只延後結構變更至 `PLAYER_REGEN_ENABLED`。
- Secret 值只可由 `UnitPowerPercent(..., CurveConstants.ZeroToOne)` 單向送入專用 StatusBar，不保存、不比較、不字串化、不序列化、不讀回；開發報告只輸出安全 metadata。
- 最新離線結果：Lua syntax 62/62（62 AddOn）；Flow all 77/77、boundary 56/56、Validation Contracts 459/459；最新 artifact 為 .AI/TestResults/EAM_FlowValidation_all_20260823_063557.json 與 .AI/TestResults/EAM_FlowValidation_boundary_20260823_063609.json；Retail／PTR／XPTR 全職業全專精實機簽收仍為 pending。

## 2026-08-23 Target Aura diagnostics 交接補充（現行）

- TooltipMonitorService 只輸出匿名 callback／candidate 時間、過期計數、Ctrl+Alt modifier 狀態、CVar read/set 結果與最後嘗試原因；不保存或序列化 Secret、AuraData、Frame 或猜測 ID。
- tryOpenMenu 仍要求非戰鬥、無鍵盤焦點、精確 Ctrl+Alt、目前 tooltip／heartbeat 與新鮮候選；Target Aura 不使用 GetMouseFocus、GetChildren、TargetFrame/AuraButton hook。
- 明確手動路徑為 /eam add target 開啟既有 Aura popup；/eam add target <spellID> 仍為直接寫入。offline harness 未載入 Slash UI 時由靜態 Contract 覆蓋 slash 可達性，不能宣稱真人 UI 通過。
- 最新離線 artifact：.AI/TestResults/EAM_FlowValidation_all_20260823_033310.json、.AI/TestResults/EAM_FlowValidation_boundary_20260823_033311.json；Lua 64/64、Flow all 75/75、boundary 54/54、Validation Contracts 441/441。仍需 PTR／XPTR／Retail 玩家實機驗證。
## 2026-08-23 技能冷卻啟動與行為設定交接（現行）

- CooldownService 只在 UNIT_SPELLCAST_SUCCEEDED 的 unit 精確為 player 且安全 base／override spell family 命中技能冷卻清單後，才建立 activatedAlerts 與可渲染狀態；refreshAll、PLAYER_REGEN_ENABLED、形態事件、設定刷新與非清單治療法術不得批量開啟。
- cooldownRemoveAura、showSCDOutsideCombat、glowSCDWhenUsable 採三態欄位：nil 繼承全域、true 或 false 代表單技能覆寫；SavedVariables、ProfileCodec 與 Options 均保留明確 false。
- 冷卻視覺計時到期後由 CooldownService 決定是否隱藏；Renderer 不再無條件移除。可用高亮與既有 Pandemic／overlay glow 合併，不讀取或字串化 Secret 值。
- cooldown.combat_heal_regen_no_bulk_render fixture 覆蓋：非清單治療法術、脫戰、錯誤 unit、形態刷新不得開門；精確玩家施放只開啟對應技能，模組停用才清除啟動狀態。
- 最新離線證據：Lua 64/64、Flow all 76/76、Flow boundary 55/55、Validation Contracts 447/447；artifact 為 .AI/TestResults/EAM_FlowValidation_all_20260823_042614.json 與 .AI/TestResults/EAM_FlowValidation_boundary_20260823_042834.json。以上仍不是 PTR／XPTR／Retail 實機簽收。
- 實機簽收須分別在 Retail／PTR 12.1 與 XPTR 12.0.7 測試 exact cast、非清單治療法術、戰鬥轉換、形態事件、三項行為設定、模組停用／再啟用與 /reload 持久化。
## 2026-08-23 玩家職業資源最終提示語交接快照

- 本輪完成 ResourceCatalog 唯一來源、PAIN 專用 legacy key、UNIT_DISPLAYPOWER foreground-only、Druid Bear／Cat／Caster／Moonkin／回 Bear Flow、Energy→ComboPoints renderer ownership regression、Probe 停止生命週期、font／orientation／numeric text controls 與非戰鬥即時設定。
- /eam unitpower background <RESOURCE_KEY> 是玩家明確標記「背景事件缺失」的診斷入口；它不代表已證明事件真的缺失，也不會自動把所有背景資源加入 sampler。
- 背景 sampler 仍是單一、demand-driven、probe-gated 排程；離線 0.5 秒只是 fixture 時鐘，Retail／PTR／XPTR 的事件頻率與視覺效果仍需玩家實機回報。
- 最新離線證據：Lua 62/62、Flow all 77/77、boundary 56/56、Validation Contracts 459/459；所有 runtime visual、Secret sink、全職業／專精、taint 與 blocked-action 仍標記 REQUIRES_WOW_12_1_RUNTIME 或 REQUIRES_XPTR_12_0_7_RUNTIME。
- 本輪未對實際 WoW 目錄執行部署，也未讀寫真實遊戲存檔；部署工具僅以暫存 fixture 完成備份／還原驗證，未執行 Git commit／push／release。修改前備份位於 .AI/backup/20260823052637_resource-module、.AI/backup/20260823061137_resource-docs 與 .AI/backup/20260823070959_final-continuity-sync。
## 2026-08-23 部署工具遊戲存檔備份／還原交接補充

- Deploy/Deploy-EventAlertMod.ps1 已移除 WoW 程序執行中檢查；部署仍維持來源／目標 Reparse Point fail-closed，只有明確的備份或還原動作才會讀寫遊戲存檔。
- 互動選單新增 [W] 備份與 [U] 還原；可依 Retail、PTR、XPTR 通道選擇，備份保留版本根目錄下的相對 WTF/... 路徑、manifest 與 SHA-256，還原前自動建立 rollback。
- CLI 可用 -Action Backup -Channel PTR -DryRun 先預覽，也可用 -Action Restore -Channel PTR -WtfBackupPath <package> 指定單一備份；還原驗證失敗時 fail-closed 並嘗試 rollback。
- 暫存 fixture 的 2 個相關檔案備份、修改後還原、SHA-256 驗證均通過；最新 Validation Contracts 為 459/459；這不是實際 WoW/WTF 寫入證據。玩家要取得最新實機狀態時，請先用部署工具部署，再依 .AI/Docs/29_LIVE_TEST_STEP_GUIDE.md 回報通道、版本、build、combat、/reload 與畫面結果。

## 2026-08-23.8 充能、Glow 與部署通知交接快照

- 冷卻服務的充能技能現在在安全取得 C_Spell.GetSpellCharges 時保留 current/max；Renderer 優先顯示充能文字，並沿用原生 DurationObject 倒數，不把 Secret 值讀回或做 Lua 算術。
- 無倒數時清除並隱藏 CooldownFrame，並以 SetDrawEdge(false)、SetDrawBling(false) 等可用方法關閉白色邊緣／bling，避免空白技能框殘留。
- Glow Border 採兩層策略：預設條件優先使用內嵌 LibButtonGlow-1.0；自訂顏色、第三方 overlay 不可用或戰鬥中首次建框時回退 EAM 自有動畫邊框。內嵌檔案只保留 EventAlertMod/Lib/LibStub.lua 與 EventAlertMod/Lib/LibButtonGlow-1.0.lua，其餘測試／文件不進插件包。
- 專案 Skill wow-addon-dev 已安裝於 .AI/skills/wow-addon-dev，本輪用於 TOC 順序、12.x Secret／taint 與 library packaging 靜態檢查；TOC validator 已通過。
- 本輪離線 gate：Lua 62/62、Flow all 78/78、Flow boundary 57/57、Validation Contracts 472/472；這些結果仍不是 Retail／PTR／XPTR 實機視覺或 taint 簽收。
- 實機部署協議：需要玩家驗證時，主代理必須先通知通道／patch／build／Interface、來源與目標、是否覆蓋、需要 /reload 或完整重啟，以及預期回報欄位；等待玩家明確完成部署後才開始解讀 runtime 報告。本輪未部署、未讀寫真實 WTF、未執行 GitHub release。
## 2. 重新進入專案的閱讀順序

1. `AGENTS.md`
2. 本文件
3. `Data/ProjectContinuity.json`
4. `Docs/02_RETAIL_API_BOUNDARIES.md`
5. `Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`
6. `Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md`
7. `Docs/26_FLOW_VALIDATION_FRAMEWORK.md`
8. `Docs/29_LIVE_TEST_STEP_GUIDE.md`
9. 與目前 work item 對應的 `Docs/15_DEVELOPMENT_ISSUE_LOG.md` 穩定 issue ID

不得以 `docs_html` 取代 Markdown 原檔，也不得以舊對話摘要覆寫本快照。

## 3. 當前目標

完成 Retail 12.1 玩家職業資源獨立模組最終重構提示語的程式、測試與證據同步；部署工具已移除 Wow-running check，並完成按通道／版本的 EventAlertMod 遊戲存檔備份／還原與相對路徑 manifest。離線通過不得冒充 Retail／PTR／XPTR 實機簽收；實際部署與 WoW runtime 仍待玩家操作。


## 4. 已確認事實

- 12.1 PTR 使用者實測曾出現兩套高度同步的 Aura 倒數。
- 兩套數字由同一個 Native Aura DurationObject 同時驅動，因此可作人工 A/B 顯示同步觀察，但不是兩個獨立資料來源。
- 正常模式只顯示 EAM 可定位的一套倒數；雙倒數只能由測試面板明確啟用，完成後關閉。
- Native AuraButton 與其子元件只能在 `initializeFrame` 內完成尺寸、錨點、字型、倒數與邊框設定；初始化後不得直接重排。
- `AddDispelTypeTexture` 是官方驅散／靜態 Aura 邊框能力，不能取代 Pandemic、Proc 或任意條件 Glow。
- 玩家資源依每項 capability 分流：普通安全數字可顯示文字；Secret 百分比只能直接送入專用 StatusBar，不得保存、讀回、比較、字串化或序列化。
- 本輪最新離線 gate 為 Lua syntax 62/62（62 AddOn）、Flow all 77/77、Flow boundary 56/56、Validation Contracts 459/459；真人矩陣為 37 案，PTR、XPTR 與 Retail 均仍待玩家簽收。
- 若從磁碟匯入遊戲內報告，玩家必須先完成 `/reload` 或正常登出，否則可能仍是舊快照。玩家資源設定在非戰鬥中不應要求 `/reload`；若仍需 `/reload`，應回報 `EAM_PLAYER_RESOURCE_CONFIG_CHANGED` 未接收、戰鬥延後未清除或 Lua error。
- 2026-08-08 唯讀環境斷言：Retail `12.0.7.68974`、PTR `12.1.0.69189`、XPTR `12.0.7.68887`；三個 AddOns SymbolicLink 均指向 `D:\EventAlertMod`。
- 語系 catalog 已包含 `enUS`、`zhTW`、`zhCN`、`koKR`、`ruRU`；ruRU 與 enUS 的 `L.*` key 完整對齊，`Auto Detect` 固定英文且預設為 `auto`。新版以穩定 `EAM.L` identity 與 widget binding／refresh registry 即時套用。

## 5. 目前決策

| 主題 | 決策 | 不可誤解事項 |
| --- | --- | --- |
| Aura 倒數 | 正常單倒數；測試面板可切換雙倒數診斷 | 同步不等於兩個獨立事實來源 |
| Native 樣式 | 變更後脫戰重建容器 | 不得初始化後直接 `SetPoint`／`SetFont` |
| 冷卻時間 | 正確使用無參數 Duration factory，再設定時間與 binding | 不得使用猜測的建構參數或不存在的 `Unbind` |
| 地面效果 | 法術說明、Tooltip SpellDescription、手動 fallback | 不解析剩餘時間文字，不在熱路徑抓 Tooltip |
| 玩家資源 | 17 種 Catalog；每項依 Numeric／Secret／Unavailable 分流並可多資源同時顯示 | Secret 只走 write-only sink；報告不輸出 current／max／percent 原值 |
| 實機操作 | 玩家自行施法、用物品、切專精、進出戰鬥與 `/reload` | EAM 與 Codex 不自動操作遊戲 |
| 語系設定 | 保存 `EAM_DB.config.language`；`auto` 為預設，俄文可手動選擇 | 新程式載入後立即刷新 EAM 自有 UI；不自動 `ReloadUI()`，`/reload` 只驗證載入與保存 |

## 6. 驗證狀態

- 離線：Lua syntax `64/64`（62 AddOn + 2 offline tests）、Flow all `75/75`、Flow boundary `54/54`、Validation Contracts `437/437`；五語系、十一主題、Profile、AuraSound、Aura catalog、Retail 12.1 Native gate、小地圖圈內幾何與玩家多資源契約均通過。最新 Flow artifact 為 `.AI/TestResults/EAM_FlowValidation_all_20260823_033310.json`；離線結果不取代 PTR、XPTR 或 Retail 真人簽收。
- PTR 12.1：Alpha 2 Native gate 已離線修正，但玩家尚未 `/reload` 簽收 Aura 顯示；不得沿用 Alpha 1 或修正前觀察。
- XPTR 12.0.7：尚未簽收。
- Retail 12.1：現行 client gate 與離線契約已更新，真人簽收尚未完成。
- 真人報告：使用 `matrixVersion=2026-08-14.1` 的 37 案工作台。
- UnitPower 報告：另回傳 `EAM_UNIT_POWER_CAPABILITY_REPORT`；PTR 69273 最新報告兩個 sink 呼叫均 accepted，但 primary 與 selected 視覺均 pending，仍非 PTR pass。

## 7. 下一輪玩家實測

1. 確認客戶端與專案連結前置斷言通過。
2. 非戰鬥中開啟 `/eam test`，確認「雙倒數診斷」預設關閉。
3. 執行 `all` 並複製 Flow JSON；它是能力證據，不是 37 案真人簽收。
4. 開啟「真人實機回報」，選正確的 `_ptr_`、`_xptr_` 或 `_retail_`，逐案操作。
5. Aura 雙倒數案例只在 PTR 12.1 暫時啟用，觀察開始、中段、最後三秒後立即關閉。
6. 先在正式玩家資源面板逐項測法力、怒氣、能量＋連擊點、瘋狂值、符文＋符能及目前專精所有可用資源；再另啟動 UnitPower 能力探針標記診斷 sink，兩者結果不可互相冒充。
7. 建立 reload checkpoint，由玩家自行 `/reload`，回來後完成報告。
8. 若從磁碟匯入，完成報告後再由玩家保存一次；直接複製面板 JSON 則不需要額外保存。
9. 開啟語系下拉清單，依序選 `Русский`、`Auto Detect`，不重新載入即確認目前已開啟的主視窗、About、功能模組與測試面板同步切換；最後再以一次玩家手動 `/reload` 驗證設定保存。
10. 對照其他標準小地圖按鈕，確認 EAM 齒輪完整位於金色圈內；以玩家常用 UI Scale 截圖，不能只回報按鈕可點。

## 8. 禁止重複的試法

- 不再使用 `C_DurationUtil.CreateDuration(duration)` 或把 duration/fontString 當作 binding factory 參數。
- 不再對已完成 `initializeFrame` 的 AuraButton／FontString／Cooldown 做結構 mutation。
- 不讀回 Secret FontString、StatusBar 或 radial percent 作自動比較。
- 不把官方 dispel border 宣稱為任意條件 Glow。
- 不以離線 mock、合成 Live pass 或舊版磁碟報告冒充 PTR／XPTR 實機通過。
- 不用 Windows PowerShell 5.1 執行含 `#requires -Version 7.0` 的契約腳本；使用 `pwsh`。
- 不假設跨檔補丁失敗時一定全數回滾；失敗後逐檔核對，重要文件採單檔小補丁。
- 不再以 `IsPublicTestClient AND IsTestBuild` 判定 PTR；raw flags 必須個別保留，通道 aggregate 採 OR，Native 方法仍逐項 capability gate。

## 9. 漂移檢查

`.AI/Tools/Test-ValidationContracts.ps1` 必須確認：

- 本文件與 JSON 的 `snapshotVersion` 一致。
- `AGENTS.md` 與 `Docs/00_AI_CONTEXT.md` 均指向本續接路由。
- fact、inference、work item 與 issue ID 唯一且引用可解析。
- Live matrix、Live runtime、Schema 與 fixture 均為同一版本及 37 案。
- PTR／XPTR／Retail 若標為 pass，必須有對應真人證據索引；離線證據不得升格。
- Continuity JSON 不得包含私人絕對路徑、帳號、角色或遊戲資料快照。


## 2026-08-08 PTR8／UnitPower 交接快照

- Live matrix 已升版 `2026-08-08.1`，目前共 34 案；三個客戶端仍為待玩家簽收。
- PTR8 Pandemic Region、Dispel options、停用容器清除與 UnitPower combatDeferred 已加入程式、strict mock、JSON schema 與人工矩陣。
- 官方 PTR 12.1.0.69189 文件未證實 `StatusBar:SetUnit`、`SetPowerTextFontString`、`SetOnUpdateMode`；目前只把 `UnitPowerPercent` 單向送入 `SetValue`／`SetRadialProgressBarPercent` 視為已知可行方向。
- 本輪不執行 WoW、不卡玩家輸入、不觸碰 `_ptr_`／`_xptr_`／`_retail_` AddOns symbolic link；實機需玩家自行 `/reload` 後回傳報告。
## 2026-08-09 Alpha 2 Native Aura／UnitPower 交接快照

- 玩家觀察：Alpha 1 可顯示 Aura，Alpha 2 完全不顯示。
- P0 根因：`AuraCapabilityService` 將 public-test 與 test-build 寫成 AND；PTR 69189 的 test-build 實為 false，導致 `nativeRuntimeAllowed=false` 並在容器建立前停止。
- 程式修正：三個測試通道 raw flags 安全讀取後採 OR；mock 固定重現 public-test=true、test-build=false、beta=false；mock-only Flow 在 client 改為 skip；Native capability 失敗訊息補足完整欄位。
- 當時離線證據：Lua `47/47`、Flow `54/54`，artifact `TestResults/EAM_FlowValidation_all_20260809_185047.json`；Validation Contracts `217/217`。其後本輪最新 gate 已更新為 50／54／264。
- PTR 下一步：玩家先 `/reload`，執行 `/eam doctor` 與 `/eam test aura121`，確認 capability pass、player／target Aura 顯示，再續跑 34 案真人矩陣。
- UnitPower：primary Secret 與 selected safe-number 均已被兩種 sink 接受，但人工視覺分別為 pending／blocked；需玩家產生、消耗、歸零資源並明確按 pass／fail。

## 2026-08-09 Alpha 3 候選功能交接快照

- TargetFrame／BuffFrame AuraButton 的 hover+Ctrl+Alt 不再依賴右鍵；非 GameTooltip 路徑只保存匿名 0.75 秒心跳，Aura ID 與 player／target 路由仍由玩家在 EAM Popup 確認。
- Action Bar Macro 優先解析安全 resolved action subtype／ID，再降級 `GetMacroSpell`／`GetMacroItem`；無安全結果才手動輸入。
- Flow／Live／Prompt 面板不再呼叫不存在的 `EditBox:Copy()`，改為全選並請玩家按 Ctrl+C。
- EAM 主視窗新增 About；顯示 TOC 版本、實際 client、固定 API baseline `12.1.0 PTR 8 (69189)`、作者 `ziyuefan死鬥` 與 repo／Pages。
- 一般監控圖示新增脫戰 Tooltip；七色分類邊框為自身 BUFF 青、自己 DEBUFF 紅、目標 BUFF 藍、目標 DEBUFF 橘、技能黃、地面紫、物品綠，classPower／totem 保留原樣。
- `Docs/29_LIVE_TEST_STEP_GUIDE.md` 提供 34 案逐步條件與通過證據；WTF 報告只在玩家完成 `/reload` 或正常登出後視為最新。
- 最新離線證據：Lua `50/50`、Flow `54/54`、Validation Contracts `264/264`。PTR、XPTR、Retail 仍沒有完整真人簽收。

## 2026-08-09 SVG／3px 邊框交接快照

- ActionButton border 放大方案已由實機截圖否決；最終改為 WHITE8X8、BORDER layer、四邊外擴 3px，Legacy／Native 共用 AlertBorderStyles.anchorTexture。
- PTR 69189 已實機確認 VectorGraphics 與 Texture 的 Alpha 3 SVG 圖樣都能顯示；兩案 SetSVG accepted、visualObservation=pass。VectorGraphics 的 HasSVG=true、fileIDClass=zero、clearReload=pass 亦成立。
- Alpha 3 探針錯把 Texture 當成具 HasSVG／GetSVGFileID，導致合法 unavailable 被標警告且沒有執行 Texture clear/reload。修正版已改為 Vector 四方法、Texture Set/Clear 的非對稱契約，原始報告保留為回歸 fixture。
- [UIOBJECT_VectorGraphics](https://warcraft.wiki.gg/wiki/UIOBJECT_VectorGraphics) 已列為持續更新知識庫；本輪可重現基線仍是 Gethe `a520b6c...` 的 12.1.0.69189 生成文件。
- 專案層級 JSON 已升到 snapshot 2026-08-09.3；WORK-20260809-002、WORK-20260809-003、TRIAL-20260809-003 與 issue EAM-20260809-PTR69189-SVG-ASYMMETRY 可互相追溯。
- 最新離線 gate 為 Lua 50/50、Flow boundary 37/37、Flow all 54/54、Validation Contracts 264/264。PTR 還需用修正版重跑 Texture clear/reload 與 3px 邊框目視；XPTR／Retail 12.0.7 維持 unsupported。

## 2026-08-12 語系交接快照

- `Locale/Common.lua` 以 catalog 合併 enUS fallback 與目前／指定語系；`Locale.LanguageOptions` 第一項是固定英文 `Auto Detect`。
- `EAM.L` table identity 在執行期保持不變；切換時原地清除／合併 catalog，刷新已綁定 widget 與低頻複合文字 callback。
- `Core/SavedVariables.lua` 將選擇正規化至六個允許值；`SavedVariables.updateLanguage()` 只在實際變更時增加 revision，但 updated／unchanged 都發出 `EAM_LANGUAGE_CHANGED`。
- `Core/Main.lua` 在 SavedVariables 初始化後套用保存值，避免 locale 檔先以 client zhTW 建表後忽略手動選擇。
- 主視窗、About、功能模組、Tooltip popup、Prompt、Flow／Live、UnitPower 與 SVG 面板已接上動態 binding／refresh；不自動呼叫 `ReloadUI()`。
- `ruRU.lua` 已補齊與 enUS 相同的 `L.*` key 集合；zhCN／koKR 缺少的歷史 Live key 仍由 enUS fallback 補底。
- 實機尚待玩家在 PTR／XPTR／Retail 逐一選取 `Русский` 與 `Auto Detect`，先驗證不 reload 的即時切換，再用一次玩家手動 `/reload` 驗證保存。

## 2026-08-12 小地圖 SVG／EAM 主題交接快照

- `UI/Options.lua` 的小地圖 Texture 固定使用 Blizzard 內建 `Trade_Engineering` 齒輪；暫停不可靠的 Texture SVG 路徑，未改動左鍵、右鍵、拖曳語意。
- UI/Theme.lua 現提供十一套 palette：EAM、FF7、Windows XP、Windows 7、Windows 10、Windows 3.1、Borland C++ IDE、DOS CRT、倚天中文、Red Alert、macOS Aqua；config.theme 只接受對應白名單值，非法值回退 EAM。
- Theme 只註冊 EAM 自有視窗；戰鬥中切換只保存 pending，`PLAYER_REGEN_ENABLED` 後再套用。AlertBorderStyles 七色內容語意維持獨立。
- `wowtools.work` 僅作唯讀資料參考，不是執行期依賴；不收集或保存外部 raw FileDataID。
- 本輪沒有 Codex 自動操作 WoW；PTR／XPTR／Retail 仍需玩家自行 `/reload` 後目視與互動簽收。

## 2026-08-12 PTR 69273／排序／主題按鈕／Druid Energy 交接快照

- 玩家提供 PTR 12.1 build 69273 的 UnitPower capability report：primary native percent 是 Secret，selected 是 safe-number，StatusBar／radial sink 均 accepted；兩案 visualObservation 都是 pending，status=incomplete，仍需玩家目視標記。
- 同 build 的完整 Flow report summary 是 54 案中 17 passed、1 failed、36 skipped；唯一失敗為 boundary.safe_scalar，訊息指出 Secret、manual-copy、About 或 SVG boundary helpers unavailable。這是 helper 可用性問題，不能當成 UnitPower pass 或直接推定 API 根因。
- PTR 存檔中 target Aura 1079 的 priority=20；編譯器原先忽略 priority，導致 SpellID tie-break 使 1079 看似被硬排第一。現已改為 priority 1..20、數字越大越前；若要移動 1079，請在條件設定調低它的 priority，/reload 後重建 Native Aura 結構。
- UI/Theme.lua 新增按鈕 palette 與 registerButton；Options、About、Tooltip popup、Flow、Live、SVG、UnitPower、Prompt 的 EAM 自有按鈕均接入，AlertBorderStyles 七種內容語意不受主題色覆蓋。
- ClassPowerService 的 Druid 候選改為 Energy、Combo Points、Lunar Power；Feral 在 UnitPower value predicate 明確安全時應先顯示 Energy，若 PTR current 是 Secret 則先安全 fallback，不能冒充已完成 native sink。
- 本輪驗證：受影響 Lua 檔案語法通過，本輪 Validation Contracts 已完整執行為 `328/328`，包含 Aura priority、Druid Energy 與 EAM 按鈕主題契約。未有 Codex 自動操作 WoW，PTR／XPTR／Retail 實機仍由玩家自行簽收。
- Theme 按鈕 getter 首次在 strict mock 觸發未知方法錯誤，已改為 pcall capability guard；修正後離線 Flow artifact 為 `54/54`，尚不代表三客戶端真人簽收。
- 續接路由：先讀 Data/ProjectContinuity.json 的 FACT／WORK／UNVERIFIED，再依 Docs/29_LIVE_TEST_STEP_GUIDE.md 的十一套主題追加步驟執行；磁碟 SavedVariables 仍須 /reload 或正常登出後才是最新。

## 2026-08-13 AuraSound 交接快照

- 固定 API 證據：PTR 12.1.0.69273 commit `6e348870ed8f93d95f0cd16d299b51dbce500296`；三 trigger 是 Added、ApplicationsIncreased、Removed，sound info 沒有 soundKitID、caster 或 auraFilter。
- Aura 細部設定新增共用素材與三 trigger 開關；三項皆未選時沿用全域音效，全域 `showSound=false` 可關閉所有 custom sound。
- SavedVariables 只存純資料；`updateAuraSound` 提供白名單、no-op revision 與事件。registration ID 只存在 runtime registry。
- Compiler 拆分 container／sound fingerprint；純音效變更零容器建立。Sound service 採 candidate 完整成功後交換，Add 失敗回滾、Remove 失敗保留 retired ID。
- 12.0.7 一般 Aura 三 trigger 控制為 unsupported 且零 12.1 API 呼叫；不以 private-aura 舊 API 合成。
- Live matrix 升為 `2026-08-13.1` 共 37 案；新增三項 AuraSound 人工聽覺案例。PTR 仍需測實播、戰鬥延後、`/reload` 與 caster/filter over-fire。
- 詳細試錯見 issue `EAM-20260813-AURASOUND-DETAILS`；機器可讀 work item、trial 與 unverified 位於 `Data/ProjectContinuity.json`。

## 2026-08-13 Alpha 4 發布快照

- Alpha 4 發布範圍：Core/ModuleController、UI/ModulePanel、schema v5 class profiles、LegacyDiscoveryService，以及前一輪已完成的 AuraSound、主題、語系、SVG、UnitPower 與 37 案測試契約。
- 八個 module key 預設全部啟用；停用採單次事件註冊加入口 gate，Native 結構與戰鬥中狀態變更延後至脫戰。
- 監控清單以 active class profile 隔離；v4 混合全域清單保留 migration backup 或 unassignedLegacy，不自動猜測其他職業。
- /eam list、lookup、lookupfull、showcast 已恢復為目前職業的有限安全候選查詢；不會自動將結果加入監控。
- JSON／Base64 profile 分享仍是下一輪規劃，正式程式沒有可套用的 codec；Release 不包含 LegacyReference、Tools、Tests、TestResults、backup 或本機 deploy。
- 發布前離線 gate：Lua 54/54、Flow all 61/61、Validation Contracts 355/355；PTR／XPTR／Retail 仍需玩家依追加步驟簽收。

## 2026-08-14 Alpha 5 發布快照

- Alpha 5 發布範圍：Core/ProfileCodec.lua、UI/ProfileCodecPanel.lua、四種 EAM 字型選擇、Locale 動態按鈕／spec menu 刷新，以及前一輪 AuraSound、模組開關、職業 profile、主題、SVG、UnitPower 能力。
- EAMAP1 僅接受 canonical JSON／Base64 與白名單 module scope；preview 零副作用，merge／replace 需 fingerprint 未變且非戰鬥，任何外部 Lua、Secret、未知 schema／duplicate／過大 payload 均拒絕。
- config.fontFamily 預設 STANDARD；語系切換後 EAM 自有按鈕與下拉立即刷新，Auto Detect 固定英文；Blizzard UI、歷史聊天與 Live case 固定繁中程序不改寫。
- Alpha 5 release package 由 GitHub Release 提供，排除本機 deploy、Tests、TestResults、Tools、backup、LegacyReference 與工作區雜項；AddOns symlink 不曾被修改。
- 發布前離線 gate：Lua 56/56、Flow all 66/66、Validation Contracts 360/360；PTR／XPTR／Retail 尚待玩家真人簽收。

### EAM-20260814-ALPHA5-PROFILE-FONT-LOCALE

- 狀態：已完成離線實作，待三客戶端真人簽收。
- 症狀：Alpha4 文件仍將 profile 分享標為未完成；新增字型後需確認所有 EAM 長生命週期按鈕與專精選單吃到 EAM.L。
- 解法：建立嚴格 EAMAP1 codec／Profile panel，新增 fontFamily mutation 與 TextPlacement 套用，讓 Locale registry 在語系事件後重建 spec menu 並刷新已綁定文字。
- 驗證：Lua 56/56、Flow 66/66、Contracts 360/360；無 Codex 自動操作 WoW。
- 後續：玩家在 PTR、XPTR、Retail 各做 profile export／preview／merge／replace、四字型與五語系／Auto Detect 目視測試，回報 build、Interface、reload 與 boundaryWarnings。

## 2026-08-14 Retail 12.1／Aura catalog follow-up 交接

- 2026-08-14 當時通道：Retail／PTR 12.1.0.69299、XPTR 12.0.7.68887；當時本機環境與 SymbolicLink 3/3 通過，但未啟動 WoW。此行是歷史快照，不代表 2026-08-21 現況。
- Aura 清單以 `catalogScope=SELF|CROSS_CLASS` 管理；SELF player 與 target 預設 `fromPlayer=true`，跨職業預設 false。批次輸入接受 Enter、`;`、`；`，不存在 SpellID 不顯示、不寫入。
- dropdown row 補齊 normal／pushed／highlight 與 FrameLevel；語系列直接使用 LanguageOptions.label，避免 nil labelKey 造成空白；Profile 面板有 ScrollFrame、固定 footer 與 Options 入口；小地圖正式 fallback 為內建齒輪。
- Wowhead 匯出只保留 Data 唯一檔，抓取腳本固定輸出專案 Data；候選 validator 23 pass／0 fail／4 warning，warning 不可當成實機錯誤或預設核准。
- 最新離線結果：Lua 56/56、Flow 68/68、Validation Contracts 387/387；真人矩陣 `2026-08-14.1` 的 37 案仍為 Retail／PTR／XPTR pending。
- 續接順序：先看 `Data/ProjectContinuity.json` 的 `WORK-20260814-002` 與 `UNVERIFIED-20260814-001`，再依 `Docs/29_LIVE_TEST_STEP_GUIDE.md` 的本輪追加步驟由玩家實測。

## 2026-08-14 主題 chrome／語系列 follow-up 交接

- 語系列空白不是字型或 reload 問題；LanguageOptions 沒有 labelKey，現改為直接顯示各 option.label，Auto Detect 仍固定英文。
- EAM 文字按鈕不再強制紅色；Theme.registerButton 會建立 WHITE8X8 normal／highlight／pushed／disabled 底圖及四條 2px 主題邊框。Debug/PromptExport 的紅色覆寫亦已移除。
- 主題 catalog 擴為十一套：EAM、FF7、Windows XP、Windows 7、Windows 10、Windows 3.1、Borland C++ IDE、DOS CRT、倚天中文、Red Alert、macOS Aqua。Borland 為亮藍底亮黃字；DOS CRT 為黑底綠字。
- AlertBorderStyles 的自身／目標 Aura、技能、物品與地面效果七種語意邊框保持獨立，不隨設定視窗主題改色。
- 離線結果為 Lua 56/56、Flow 68/68、Validation Contracts 387/387；Retail／PTR／XPTR 實機仍需玩家 /reload 後目視簽收。

## 2026-08-14 Alpha 6 發布快照

- Alpha 6 發布範圍包含 Retail 12.1 Native capability 修正、Aura SELF／CROSS_CLASS 與批次輸入、EAMAP1 Profile、五語系動態刷新、十一主題按鈕 chrome、AuraSound 及小地圖圈內對齊。
- 小地圖 `Trade_Engineering` 齒輪使用 17px ARTWORK、5% TexCoord 裁邊與 `TOPLEFT +7,-6`；20px 背景使用 `TOPLEFT +7,-5`；53px `MiniMap-TrackingBorder` 固定按鈕 TOPLEFT。此幾何只改 EAM 自有按鈕。
- `.github/workflows/release.yml` 維持完全停用；GitHub Alpha 6 使用本機正式 ZIP 與 `gh release create --prerelease`，不發布到 CurseForge／WoWInterface。
- 離線 gate：Lua 56/56、Flow 68/68、Validation Contracts 394/394。Retail／PTR／XPTR 的小地圖像素、十一主題、語系、AuraSound 與完整 37 案仍由玩家簽收。
- 續接索引：`WORK-20260814-004`、`UNVERIFIED-20260814-003`、issue `EAM-20260814-ALPHA6-MINIMAP-RING`。

## 2026-08-21 玩家資源設定生命週期修正

- 根因：設定 mutation 原先沒有同步驅動 PlayerResourceService 的 topology／renderer；/reload 重新初始化後才看見變更。
- 現況：非戰鬥 EAM_PLAYER_RESOURCE_CONFIG_CHANGED 立即套用；戰鬥標記 combatRebuildDeferred，離戰由 PLAYER_REGEN_ENABLED 合併一次。
- 本輪測試：Lua 64/64、Flow all 75/75、Flow boundary 54/54、Validation Contracts 441/441；`unitpower.config_immediate_lifecycle` 與 sampler gate 均已離線通過。
- 實機仍需玩家在 Retail／PTR 12.1 與 XPTR 12.0.7 分別驗證；不得把 /reload 後看見畫面當成非戰鬥即時套用通過。

## 2026-08-21 玩家資源 completion audit（現行補充）

- 目前程式已具備 `PlayerResourceProbe`、XPTR 12.0.7 numeric legacy adapter、Druid Caster／Cat／Bear／Moonkin form flow、每資源 `anchor`／`position` 與 PlayerResourceService／Probe 的事件 unregister。
- 背景 sampler 僅在 probe 明確確認事件缺失時啟用，為單一 demand-driven sampler；`unitpower.background_sampler_gate` 與靜態 contract 已離線通過，涵蓋單 task、事件恢復停止、模組停用、戰鬥延後與 stale generation。它仍是 runtime-only 待實機驗證能力。
- 最新離線證據：Lua `64/64`、Flow all `75/75`、Flow boundary `54/54`、Validation Contracts `437/437`。Artifact：`.AI/TestResults/EAM_FlowValidation_all_20260823_033310.json` 與 `.AI/TestResults/EAM_FlowValidation_boundary_20260823_033311.json`。
- 實機未完成：Retail／PTR 12.1 與 XPTR 12.0.7 的全職業／專精資源、Druid 變形、Secret／numeric 視覺、sampler gate、戰鬥延後、設定不 reload 即時套用與 taint／blocked action。
## 2026-08-23.6 玩家資源與公開文件同步快照

- continuity snapshot 已升至 2026-08-23.6；機器可讀 JSON 已通過解析。
- 最新離線 gate：Lua 62/62、Flow all 77/77、boundary 56/56、Validation Contracts 461/461。Flow artifact 為 .AI/TestResults/EAM_FlowValidation_all_20260823_081553.json 與 .AI/TestResults/EAM_FlowValidation_boundary_20260823_081542.json。
- PlayerResourceProbe 的自動缺事件檢查只執行一次並納入 restart gate；Frozen Catalog 不再被 SavedVariables 寫入，Options 對缺失 SavedVariables API fail-closed。
- 根 README 已重整為 Alpha 7 現行使用說明，根目錄與 EventAlertMod/README.md SHA-256 均為 7EB8752ACA994769356757AED7E1FB4483497930E4A0CB9C567403D14D161509。
- 本輪未部署 WoW、未讀寫真實 WTF、未執行 GitHub push／release；Retail／PTR／XPTR runtime 仍待玩家操作。

## 2026-08-23.7 最終 gate 與 GitHub README 使用說明同步

- continuity snapshot 已升至 2026-08-23.7；Data/ProjectContinuity.json 解析通過，並新增 FACT-20260823-008。
- 最新離線 gate：Lua 62/62、Flow all 77/77、Flow boundary 56/56、Validation Contracts 464/464。最新 artifact 為 .AI/TestResults/EAM_FlowValidation_all_20260823_083630.json 與 .AI/TestResults/EAM_FlowValidation_boundary_20260823_083631.json。
- README 已以 LF 正規化，根目錄與 EventAlertMod/README.md SHA-256 均為 635C545E7B535B85730AA28D24176E291299A86F47D5036682C1FE5877935AB3；GitHub 根頁面現在包含 Alpha 7 版本範圍、完整 /eam 命令、離線驗證、部署與備份／還原時機。
- ProjectContinuity 的 privacy contract 重新通過；連續性證據只保留公開程式／文件路徑，不記錄私人遊戲資料詞彙或帳號路徑。
- 本輪未部署至 Retail／PTR／XPTR，未讀寫真實遊戲存檔，未執行 GitHub push／release；玩家仍須部署後以 /reload 進行三通道實機簽收。

## 2026-08-23.10 充能次數 StatusBar 與五種版面快照

- continuity snapshot 已升至 `2026-08-23.10`；既有 `FACT-20260823-010`、`WORK-20260823-003` 與 `UNVERIFIED-20260823-001` 已同步為 current/max 次數語意。
- 冷卻首次啟動仍只接受玩家 `UNIT_SPELLCAST_SUCCEEDED`，並安全對齊儲存 ID、base ID 與目前 override ID；`SPELL_UPDATE_COOLDOWN`／`SPELL_UPDATE_CHARGES`／regen／形態事件只刷新已啟動技能。
- 充能列不再使用 `DurationObject` 或恢復秒數。安全 `maxCharges` 設定 StatusBar 範圍，原始 `currentCharges` 最後直送 `SetValue`；Secret current 不進入 Lua 比較、算術、文字、表索引或序列化。
- 顯示支援 TOP／BOTTOM／LEFT／RIGHT／RING；預設長度／環直徑為圖示 150%、厚度 8px，可即時設定。maxCharges 在 2 至 20 時顯示安全分隔線；超過上限時不畫誤導性分隔線。
- 環形使用 12.1 `StatusBarRenderMode.Radial` 與 `Media/Images/eam-charge-ring.tga` ring grid；能力不可用時回退 BOTTOM 線性條。這仍需玩家實機確認材質、方向、厚度與遮擋。
- 充能技能只有回到最大次數才算冷卻完成；`cooldownRemoveAura` 的移除語意因此是「滿充才移除」。安全 current/max 直接判定，Secret current 使用安全 `isActive` 判定。
- 冷卻細部設定維持隱藏 Aura 專用「僅監控自己施放」，三項 per-spell nil／true／false 行為不受影響。
- 最新離線 gate：Lua 64/64、Flow all 79/79、boundary 58/58、Validation Contracts 483/483。artifact 為 `.AI/TestResults/EAM_FlowValidation_all_20260823_162316.json` 與 `.AI/TestResults/EAM_FlowValidation_boundary_20260823_162320.json`。
- 本輪未部署 WoW、未讀寫真實遊戲資料、未執行 GitHub push／release；Retail／PTR／XPTR runtime 視覺、taint 與 blocked action 仍待玩家操作。

## 2026-08-23.11 Alpha 7.4 Rune／Ground family 交接快照

- continuity snapshot 已升至 `2026-08-23.11`；新增 `FACT-20260823-011`、`WORK-20260823-004`、`UNVERIFIED-20260823-002` 與 `UNVERIFIED-20260823-003`。current offline summary 為 Flow all `82/82`；真人矩陣仍為 Retail／PTR／XPTR pending。
- DK Runes 不再讀泛用 UnitPower 聚合值；拓樸建立時以 `GetRuneCount`，必要時以 `GetRuneCooldown` readiness fallback，同步六槽。`RUNE_POWER_UPDATE(runeIndex, added)` 直接更新 0..6 ready count；`added=false` 必須用明確 if 保存，不可寫成 Lua `and/or`。
- 目前 Rune 視覺是六段 ready-count 彙總，不是六顆各自的 recharge timer。Runic Power 仍維持另一個獨立資源節點；實機必須確認兩者同時存在且符文消耗／恢復會變動。
- GroundEffect 在非戰鬥 cold path 編譯設定 spellID 的 Base／Override／GetSpellInfo spellID family；`UNIT_SPELLCAST_SUCCEEDED` hot path 只接受安全正整數並做 O(1) 查表，exact configured ID 優先。collision、unknown 或 Secret activation spellID 皆 fail-closed。
- 死亡凋零／褻瀆可藉 spell family 對齊；反魔法立場自動說明解析失敗時走該監控項 manual fallback。若反魔法立場因吸收上限提前消失，EAM 的施放時間計時不會自行證明提前結束，屬待實機確認限制。
- 最終核心離線證據：Lua `64/64`、Flow all `82/82`（`.AI/TestResults/EAM_FlowValidation_all_20260823_174946.json`）、boundary `61/61`（`.AI/TestResults/EAM_FlowValidation_boundary_20260823_174739.json`）、Validation Contracts `493/493`。
- 本輪修改前備份位於 `.AI/backup/20260823173540` 與 `.AI/backup/20260823175220`。尚未部署、未讀寫 WoW/WTF、未做真人操作；玩家部署後依 Docs/29 的 Alpha 7.4 段落回報。

<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 架構

## 2026-08-21 新根目錄與責任邊界（現行）

- `D:\Project_EventAlertMod` 是 Git／專案根；`EventAlertMod/` 是唯一插件 runtime source；`.AI/` 是 AI 治理、文件、工具與資料；`Deploy/` 是本機選單部署與封裝工具；`Dist/` 是被 ignore 的本機產物區。
- 插件載入邊界只包含 `EventAlertMod/EventAlertMod.toc` 指向的 `Core/`、`Data/` runtime Lua、`Debug/`、`Locale/`、`Managers/`、`Media/`、`Services/`、`UI/` 與插件內公開說明。`.AI/Docs`、`.AI/Tools`、`.AI/Data` 不得由 TOC 載入。
- 插件 ZIP 必須是 `EventAlertMod/` 的 exact tree；治理資料、部署工具、Dist、測試結果不由插件封裝器拼入。原始碼 ZIP 才可保留 `.vscode/`、`.codex/`、`.AI/`（含 `.AI/docs_html/`），但排除本機產物與暫存。
- 部署工具可寫入 WoW 目錄前，必須完成三通道版本／目標／Reparse 前檢並取得明確確認；任何連結、junction 或其他 Reparse Point fail-closed，不能刪除或跟隨修復。

> 本節是新根的 current-of-truth；下方舊架構與舊路徑只保留歷史設計證據。

目前##文件映射

根：

- `EventAlertMod_Mainline.toc`：正式服裝/主線目錄，目前接口
  `120000`，版本`TWW_11.2.5_20251111`。
- `EventAlertMod_Cata.toc`、`EventAlertMod_Mists.toc`、
  `EventAlertMod_TBC.toc`、`EventAlertMod_Wrath.toc`：不支援的舊版目錄。
- `embeds.xml`：裝載捆庫。
- `README.md`、`changelog.txt`：歷史行為和命令上下文。
- `libs/`：捆`LibCustomGlow-1.0`、`LibDebug`、`LibStub`。
- `locale/`: `本地化.comm.lua`, `.en.lua`, `.tw.lua`, `.cn.lua`,
  `.kr.lua`、`.ru.lua`。
- `Images/`、`Sounds/`：媒體資產。
- `DevDocument/`：參考 URL 和先前的 ChatGPT 上下文。
- `Classic/`、`TBC/`、`Wrath/`：不支援繼承來源。
- `Main/`：目前主線實作。

目前主線負載設備：
- `Main/EventAlertMod.xml`：載入主線Lua模組並建立
  `EA_Main_Frame` / `EA_Version_Frame`。
- XML 選項面板：
  - `Main/EventAlert_Options.xml`
  - `Main/EventAlert_IconOptions.xml`
  - `Main/EventAlert_ClassAlerts.xml`
  - `Main/EventAlert_OtherAlerts.xml`
  - `Main/EventAlert_TargetAlerts.xml`
  - `Main/EventAlert_SCDAlerts.xml`
  - `Main/EventAlert_GroupAlerts.xml`
目前主線Lua模組：

- `EventAlert_LoadDefault.lua`：預設的`EA_Config2`值。
- `EventAlert_InitVar.lua`：初始化`EA_Config`、`EA_Position`、命名空間
  運行時表、偵錯標誌、類別/規範全域變數。
- `EventAlert_InitVar_DK.lua`：死亡騎士符文/紋理。
- `EventAlert_SpellItem.lua`：大型武器/物品資料表。
- `EventAlert_CreateFrames.lua`：建立圖示、輔助點、捲動清單、
  小地圖按鈕、群組框架和特殊資源框架。
- `EventAlert_SpellArray.lua`：類別/預設座標系和資料載入。
- `EventAlert_Animation.lua`：視覺動畫/背景助手。
- `EventAlert_Util.lua`：印刷助理、工具提示助手、光環查找、
  增益清單缺陷、發光助手、法術/天賦檢查。
- `EventAlert_EAFun.lua`：滾動/除錯、遷移的兼容性外觀，
  工具提示、條件、計時器文字、分組結果、版面配置和提示綁定。
- `EventAlert_SlashCommand.lua`：`/eam` 指令處理。
- `EventAlert_GroupEvent.lua`：使用者定義的條件/群組警報檢查。
- `EventAlert_Core.lua`：插件加載，事件註冊/調度，大多數
  頂級事件處理程序、查找、版本檢查、更新循環。
- `EventAlert_ItemSpellCache.lua`：物品到法術快取瀏覽器與大型物品
  掃描。
- `EventAlert_Aura_Core.lua`：完整/增量光環緩存助手。
- `EventAlert_Aura_Self.lua`：玩家/寵物光環警報和自我圖示佈局。
- `EventAlert_Aura_Target.lua`：目標光環警報和目標圖示佈局。
- `EventAlert_Cooldown.lua`：資產/物品冷卻和SCD佈局。
- `EventAlert_SpecialPower.lua`：符文、組合點、類別資源、
  生命綻放、活力和其他特殊力量框架。
- `EventAlert_API.lua`：API別名層，目前不在XML載入清單中。
- `EventAlert_Options.lua`：選項UI邏輯與群組事件編輯器。
- `EventAlert_IconOptions.lua`：圖示選項UI、按鈕點移動、字體/位置
設定。
- `EventAlert_ImportExport.lua`：匯入/匯出原型，目前已註釋
  以XML形式輸出。

目前## XML/UI 範本使用情況

靜態 XML 面板使用這些範本系列：

- `UIPanelButtonTemplate`
- `UICheckButtonTemplate`
- `OptionsSliderTemplate`
- `UIDropDownMenuTemplate`
- `UIPanelScrollFrameTemplate`
- `InputBoxTemplate`
- `BackdropTemplate`
- `GameFontNormal`
- `GameFontHighlight`
- `EA_SpellEditTextTemplate`

動態Lua框架搭建使用：

- `CreateFrame("Frame", ...)` 用於警報圖示、條目、清單容器、群組
框架和小地圖按鈕。
- `CreateFrame("Cooldown", ..., "CooldownFrameTemplate")` 用於冷卻滑動
  一幀。
- `CreateFrame("ScrollFrame", ..., "UIPanelScrollFrameTemplate")` 用於法術
  列表和導入/導出面板。
- `CreateFrame("EditBox", ..., "InputBoxTemplate")` 和 XML 編輯框
  符碼ID和匯入/匯出文字的範本。
- `CreateFrame("Button", ..., "UIPanelButtonTemplate")` 和 XML 選項
  按鈕。
- `CreateFontString(..., "GameFontNormal")` 和相關遊戲字體。
- 穿透 `Lib_ZYF:SetBackdrop` 和直接 `BackdropTemplate` 呼叫背景
在初始化導入/導出程式碼中的使用。

重寫規則：UI範本屬於 `UI/IconPool`、`UI/Renderer` 和
`用戶界面/選項`。服務無法直接建立框架或改變框架佈局。

目前##的職責

目前的課程編號職責是混合的：

- `Core.lua` 擁有載入順序、事件註冊、事件路由、功能
  處理程序、尋找掃描、版本檢查和回退更新計畫。
- Aura 服務分為“Aura_Core”、“Aura_Self”和“Aura_Target”，
  但仍然是直接渲染和調度。
- 冷卻服務執行冷卻查詢、冷卻物品查詢、
  渲染延遲，以及一個模組中的延遲更新。
- 幀建立和渲染器行為分佈在「CreateFrames」中，
  `EAFun`、`Aura_*`、`Cooldown`、`SpecialPower` 和選項模組。
- SavedVariables直接在全域表中初始化，消耗模式
  版本控製或驗證邊界。
- 本地化使用全域字符串並混合到 UI 設定中。

## 目標模組映射

核心：

- `Env`：外掛模式命名空間、本地 API 別名、構建/風味保護、僅限正式服
  守衛。
- `Util`：貢獻助手、池、後備表API、枚舉助手、
  斷言。
- `預設`：列出枚舉、事件名稱、狀態代碼、模式版本。
- `EventRouter`：一幀，一個`OnEvent`，事件到模組的調度表。
-`Scheduler`：一個`OnUpdate`，不一致佇列，低頻回退，無
  每個圖示計時器。
- `SavedVariables`：預設值、遷移、驗證、版本化模式。
- `性能`：FPS/戰鬥節流、任選分析、共享池。

服務：

- `AuraService`：安全玩家/目標光環支架和緩存業主。
- `CooldownService`：自動冷卻冷卻和標準化冷卻狀態。
- `ItemCooldownService`：物品冷卻佇列和選擇性的增量緩存。
- `SpellInfoService`：法術名稱/圖示/連結緩存。
- `ClassPowerService`：玩家職業特殊能量（聖能、靈魂碎片、連擊點、真氣、奧術充能）與中央狀態管理。
- `GroundEffectService`：地面效果感應 (SPELL_CAST_SUCCESS) 具有雙重持續時間（動態工具提示抓取與手動輸入）計時器追蹤。
- `TotemService`：薩滿圖騰插槽使用C_Totems.GetTotemInfo進行監控。

使用者簡介：

- `IconPool`：擷取按鈕、紋理、冷卻區域和FontStrings。
- `Renderer`：僅消耗標準化渲染狀態；未取得資料。
- `選項`：簡單的配置面板。
- `Slash`：`/eam`指令解析器並偵查錯匯出指令。

錯偵：
- `DebugState`：簡潔的執行階段快照分割事實、衍生狀態、
人類筆記、邊界警戒和環境。
- `PromptExport`：連續連續的類似 JSON 的輸出。

## 資料流

1.暴雪事件進入`EventRouter`。
2. 路由器向某個或設定服務進行調度。
3.服務讀取安全的正式服API並更新擁有的執行時間狀態。
4. 服務發布或標記「AlertState」記錄。
5. `Renderer`接收接收警報狀態並更新池圖示。
6.「調度程序」僅處理刷新、回退採樣和除錯突發。
7. __​​EAMCODE_0__ 在載入時讀取/遷移，並且僅更改配置讀取。

## 事件流程

主要事件應僅包括必要的正式服事件，例如：

- `PLAYER_LOGIN`
- `PLAYER_ENTERING_WORLD`
- `PLAYER_REGEN_ENABLED`
- `PLAYER_REGEN_DISABLED`
- `PLAYER_TARGET_CHANGED`
- `UNIT_AURA`
- `SPELL_UPDATE_COOLDOWN`
- `SPELL_UPDATE_CHARGES`
- `BAG_UPDATE_COOLDOWN`
- `UNIT_SPELLCAST_SUCCEEDED`
- 只有在啟用特殊資源UI時才發生能量/資源事件（Power/Resource）

沒有“RegisterAllEvents”。

## UI 渲染流程

渲染器輸入是“IconRenderState”，而不是原始光環/冷卻API資料。渲染器：

- 從「IconPool」取得圖示；
- 只需寫入後更改紋理的名稱、時間、計時器、冷卻時間、發光和阿爾法；
- 批次更改佈局並隱藏父級，然後顯示一次；
- 避免`ClearAllPoints`和`SetPoint`不用佈局鍵改變；
- 從不查詢C_* API。

## 排程規劃流程

一個調度程序框架按數位時間追蹤作業。工作是可重複使用的記錄，
不封配置點。後備輪詢必須是低頻的並且
在戰鬥/低FPS或失效節流，除非它可以保護正確性。

## 限正式服改計劃
1.在`Core/`、`Services/`下匯入新的模組元件並載入順序，
   “UI/”和“除錯/”。
2. 建立新表時僅保留舊的“Main/”表作為遷移/參考
   架構。
3. 將 SavedVariables 遷移到版本化設定檔和警報清單模型。
4. 將本地化字符串移植到獨立的本地化模組中。
5. 在移植服務前實施`EventRouter`和`Scheduler`。
6.移植玩家光環、目標光環、角色冷卻、冷卻服務功能。
7.實施池化渲染器放置影格建立移出服務模組。
8.針對新服務重建斜線指令並除錯導出器。
9. 從活動負載中刪除舊版 TOC 和 Classic/MOP 相容性分支。
10.執行靜態檢查，然後立即進行正式服裝驗證。

## 2026-07-26：12.1 Native Aura 分流

- 12.1：`EAM_DB -> AuraCapabilityService -> AuraRuleCompiler -> AuraContainerService -> AuraSlot/AuraGroup -> Blizzard AuraButton`。
- 12.0.7：保留 `AuraService -> AlertManager -> Renderer -> IconPool` Legacy 路徑。
- Native Aura 不建立 AuraState、不送 `EAM_AURA_STATE_CHANGED`、不使用 Renderer Scheduler token。
- 12.1 capability 缺失時為 `UNSUPPORTED`，不得回退到 Secret AuraData 掃描。
- 完整生命週期見 `Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`。

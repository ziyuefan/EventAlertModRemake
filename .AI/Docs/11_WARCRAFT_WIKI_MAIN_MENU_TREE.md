<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 魔獸爭霸 Wiki 主選單 三層遍歷筆記

本文件補足 `API_change_summaries` 頁面左側 `Main Menu` 的樹狀瀏覽。

目標不是複製整站內容，而是建立EAM正式服重寫所需的導覽索引：

- 第一層：`Main Menu` 入口。
- 第二層：入口頁面的主要分類或索引方向。
- 第三層：代表API /檔案頁。
- 第四層：與 EAM rewrite 的實踐結論。

## 來源入口

- https://EAMCODE_3__.wiki.gg/wiki/WoW_API
- https://EAMCODE_3__.wiki.gg/wiki/Lua_functions
- https://EAMCODE_0__.wiki.gg/wiki/FrameXML_functions
- https://EAMCODE_0__.wiki.gg/wiki/Widget_API
- https://EAMCODE_0__.wiki.gg/wiki/Widget_script_handlers
- https://EAMCODE_0__.wiki.gg/wiki/XML_schema
- https://EAMCODE_0__.wiki.gg/wiki/Events
- https://EAMCODE_0__.wiki.gg/wiki/Console_variables
- https://EAMCODE_0__.wiki.gg/wiki/Macro_commands
- https://EAMCODE_0__.wiki.gg/wiki/Combat_Log
- https://EAMCODE_0__.wiki.gg/wiki/COMBAT_LOG_EVENT_UNFILTERED
- https://EAMCODE_0__.wiki.gg/wiki/UI_escape_sequences
- https://EAMCODE_0__.wiki.gg/wiki/Hyperlinks
- https://EAMCODE_0__.wiki.gg/wiki/API_change_summaries
- https://EAMCODE_0__.wiki.gg/wiki/HOWTOs

## 樹概述
```text
Warcraft Wiki Main Menu
├─ WoW API
│  ├─ API systems
│  │  ├─ C_UnitAuras
│  │  ├─ C_Spell
│  │  ├─ C_Item / C_CVar / C_TooltipInfo
│  │  └─ C_Secrets
│  ├─ API categories
│  │  ├─ API functions
│  │  ├─ API events
│  │  ├─ API types
│  │  └─ API systems
│  └─ EAM relevance
│     ├─ AuraService
│     ├─ CooldownService
│     ├─ ItemCooldownService
│     └─ Debug boundary checks
├─ Lua API
│  ├─ Lua 5.1 subset
│  │  ├─ basic functions
│  │  ├─ string
│  │  ├─ table
│  │  └─ coroutine
│  ├─ WoW custom Lua helpers
│  │  ├─ table.create
│  │  ├─ table.wipe
│  │  ├─ table.freeze
│  │  └─ table.isfrozen
│  └─ EAM relevance
│     ├─ low-GC policy
│     ├─ no secret tostring/string.match
│     └─ no hot-path transient tables
├─ FrameXML API
│  ├─ UIParent / panel helpers
│  ├─ Mixins and pools
│  │  ├─ CreateFramePool
│  │  ├─ CreateTexturePool
│  │  └─ CreateFontStringPool
│  ├─ SharedXML utilities
│  │  ├─ EventUtil
│  │  ├─ FrameUtil
│  │  ├─ TooltipUtil
│  │  └─ LinkUtil
│  └─ EAM relevance
│     ├─ IconPool
│     ├─ EventRouter
│     └─ Tooltip fallback isolation
├─ Widget API
│  ├─ Widget objects
│  │  ├─ Frame
│  │  ├─ Button
│  │  ├─ Cooldown
│  │  ├─ FontString
│  │  └─ Texture
│  ├─ Widget methods
│  │  ├─ ScriptObject:SetScript
│  │  ├─ Frame:RegisterEvent
│  │  ├─ Frame:RegisterAllEvents
│  │  ├─ Cooldown:SetCooldownFromDurationObject
│  │  └─ FontString:ClearText
│  └─ EAM relevance
│     ├─ Renderer
│     ├─ no RegisterAllEvents
│     ├─ no per-icon OnUpdate
│     └─ DurationObject display
├─ Widget scripts
│  ├─ Frame scripts
│  │  ├─ OnEvent
│  │  ├─ OnUpdate
│  │  ├─ OnShow / OnHide
│  │  └─ OnDragStart / OnDragStop
│  ├─ Button scripts
│  │  ├─ OnClick
│  │  ├─ PreClick
│  │  └─ PostClick
│  └─ EAM relevance
│     ├─ single EventRouter OnEvent
│     ├─ single Scheduler OnUpdate
│     └─ Options drag handling only outside hot path
├─ XML schema
│  ├─ Ui
│  │  ├─ Include
│  │  └─ Script
│  ├─ LayoutFrame
│  │  ├─ Size
│  │  ├─ Anchors
│  │  └─ Animations
│  ├─ Frame
│  │  ├─ Layers
│  │  ├─ Frames
│  │  └─ Scripts
│  └─ EAM relevance
│     ├─ reduce large XML option surface
│     ├─ avoid XML OnUpdate
│     └─ keep UI templates isolated
├─ Events
│  ├─ API events category
│  │  ├─ UNIT_AURA
│  │  ├─ SPELL_UPDATE_COOLDOWN
│  │  ├─ BAG_UPDATE_COOLDOWN
│  │  └─ PLAYER_REGEN_ENABLED
│  ├─ Event docs
│  │  ├─ payload tables
│  │  ├─ predicates
│  │  └─ restrictions
│  └─ EAM relevance
│     ├─ event-driven first
│     ├─ incremental aura handling
│     └─ out-of-combat refresh
├─ CVars
│  ├─ Console variables
│  │  ├─ GetCVar / SetCVar
│  │  ├─ C_CVar.GetCVarInfo
│  │  └─ C_CVar.RegisterCVar
│  ├─ Console commands
│  │  ├─ cvar_default
│  │  ├─ cvar_reset
│  │  └─ cvarlist
│  └─ EAM relevance
│     ├─ do not depend on user CVars for core logic
│     ├─ secret forced CVars only for live validation
│     └─ avoid protected CVar mutation in combat
├─ Macro commands
│  ├─ Character commands
│  ├─ Combat commands
│  │  ├─ cast / use
│  │  ├─ cancelaura
│  │  └─ startattack / stopattack
│  └─ EAM relevance
│     ├─ no combat automation
│     └─ slash commands are config/debug only
├─ Combat Log
│  ├─ Combat Log page
│  │  ├─ chat combat log
│  │  └─ file logging
│  ├─ COMBAT_LOG_EVENT / CLEU
│  │  ├─ payload
│  │  ├─ prefixes
│  │  └─ suffixes
│  └─ EAM relevance
│     ├─ do not use CLEU as primary 12.x data source
│     ├─ avoid blind combat parsing
│     └─ prefer UNIT_AURA / cooldown events
├─ Escape sequences
│  ├─ UI text sequences
│  │  ├─ color
│  │  ├─ texture
│  │  └─ reset
│  └─ EAM relevance
│     ├─ debug export escaping
│     ├─ tooltip text safety
│     └─ no secret string formatting
├─ Hyperlinks
│  ├─ link format
│  │  ├─ color
│  │  ├─ type:payload
│  │  └─ display text
│  ├─ inspecting
│  │  ├─ SetItemRef
│  │  └─ ExtractHyperlinkString
│  └─ EAM relevance
│     ├─ spell/item ID tooltip debug
│     ├─ import/export text safety
│     └─ no unsafe parsing of secret-derived text
├─ API changes
│  ├─ API change summaries
│  │  ├─ 12.0.0
│  │  ├─ 12.0.1
│  │  ├─ 12.0.5
│  │  └─ 12.0.7
│  └─ EAM relevance
│     ├─ target TOC/API generation
│     ├─ removed API cleanup
│     └─ live validation list
├─ HOWTOs
│  ├─ Getting Started
│  │  ├─ Introduction to Lua
│  │  └─ Create a WoW AddOn
│  ├─ UI HOWTOs
│  │  ├─ Making draggable frames
│  │  └─ frame examples
│  └─ EAM relevance
│     ├─ options UI behavior reference
│     ├─ draggable anchor handling
│     └─ avoid copying example closures into hot paths
└─ wowuidev
   ├─ historical / community API discussion entry
   ├─ related API docs / /api command references
   └─ EAM relevance
      ├─ useful as background only
      └─ not an authoritative Retail 12.x runtime contract
```
## EAM 實施導向摘要

### WoW API

`WoW API` 是主要運行時 API 入口。 EAM rewrite 應優先從 API 系統找到對應的命名空間，而不是保留舊的全域包裝器。

重要三層：
```text
WoW API
├─ API systems
│  ├─ C_UnitAuras
│  │  └─ AuraService
│  ├─ C_Spell
│  │  └─ CooldownService / SpellInfoService
│  ├─ C_Item
│  │  └─ ItemCooldownService
│  ├─ C_TooltipInfo
│  │  └─ low-frequency fallback only
│  └─ C_Secrets
│     └─ boundary checks
```
結論：

- 12.x 只用於正式服 `C_*` 命名空間。
- `C_Secrets`應集中封裝，不要散去每個UI功能。
- `C_TooltipInfo` 是後備資料來源，而非熱路徑事實來源。

### Lua API

`Lua API` 說明 WoW 使用 Lua 5.1 子集，且缺少作業系統/檔案 I/O 函式庫。

重要三層：
```text
Lua API
├─ basic functions
│  ├─ pcall / xpcall
│  └─ type / select
├─ string
│  ├─ string.match / gsub / format
│  └─ WoW custom string helpers
├─ table
│  ├─ table.create
│  ├─ table.wipe
│  ├─ table.freeze
│  └─ table.isfrozen
```
結論：

- `string.match` 在未確認安全性的秘密衍生性工具提示文字時不可用。
- 熱路徑避免瞬態表、`table.insert`、大量`pairs`。
- `table.freeze` 只用於不可變常數。

### FrameXML API

`FrameXML 函數` 包含 UI helper、pool、EventUtil、TooltipUtil、LinkUtil 等。

重要三層：
```text
FrameXML API
├─ Mixins / pools
│  ├─ CreateFramePool
│  ├─ CreateTexturePool
│  └─ CreateFontStringPool
├─ SharedXML
│  ├─ EventUtil
│  ├─ FrameUtil
│  └─ TooltipUtil
└─ UIParent / panels
   ├─ ShowUIPanel
   └─ Toggle*Frame
```
結論：

- EAM 的 `UI/IconPool.lua` 可以參考暴雪礦池模式。
- 請勿在戰鬥中呼叫會切換受保護面板的函數。
- TooltipUtil 可作參考，但工具提示解析必須低頻且秘密安全。

### 小工具 API / 小工具腳本

`Widget API` 和 `Widget script handlers` 是 EAM 渲染器、EventRouter、調度器的基礎。

重要三層：
```text
Widget API
├─ Frame
│  ├─ RegisterEvent
│  ├─ RegisterAllEvents
│  └─ SetScript
├─ Cooldown
│  ├─ SetCooldownFromDurationObject
│  ├─ SetCountdownFormatter
│  └─ SetCountdownMillisecondsThreshold
└─ FontString
   ├─ SetText
   └─ ClearText
```

```text
Widget scripts
├─ Frame
│  ├─ OnEvent
│  └─ OnUpdate
├─ Button
│  ├─ OnClick
│  └─ PreClick / PostClick
└─ EditBox
   ├─ OnTextChanged
   └─ OnEnterPressed / OnEscapePressed
```
結論：

- `RegisterAllEvents` 只適合 debug/datamining，不適合 EAM 運行時。
- EAM 只應有一個 EventRouter `OnEvent`。
- EAM 只應有一個排程器 `OnUpdate`。
- `Cooldown`應承接`DurationObject`，不要讓Lua每幀算秒。

### XML 架構

`XML schema` 說明 XML 可以建立 UI，但 Lua Widget API 也可以做大部分事情。

重要三層：
```text
XML schema
├─ Ui
│  ├─ Include
│  └─ Script
├─ LayoutFrame
│  ├─ Size
│  ├─ Anchors
│  └─ Animations
└─ Frame
   ├─ Layers
   ├─ Frames
   └─ Scripts
```
結論：

- 新架構可保留簡單的 XML 載入程序，但執行時間圖示應破解 `IconPool`。
- 避免在XML內建立大量全域框架名稱。
- 避免XML `OnUpdate`。

### 活動

`Events` / `Category:API events` 是 EventRouter 的事件來源。

重要三層：
```text
Events
├─ UNIT_AURA
│  ├─ unitTarget
│  ├─ updateInfo.addedAuras
│  ├─ updateInfo.updatedAuraInstanceIDs
│  └─ updateInfo.removedAuraInstanceIDs
├─ cooldown events
│  ├─ SPELL_UPDATE_COOLDOWN
│  ├─ SPELL_UPDATE_CHARGES
│  └─ BAG_UPDATE_COOLDOWN
└─ combat boundary
   ├─ PLAYER_REGEN_DISABLED
   └─ PLAYER_REGEN_ENABLED
```
結論：

- `UNIT_AURA`增量資料是AuraService核心入口。
- 刪除了光環實例ID無法再查出完整的光環，服務要先快取安全摘要。
- 脫戰刷新是邊界限制狀態的安排點。

### CVar

`控制台變數` 說明 CVar 可以用 `GetCVar` / `SetCVar` / `/console` 管理，部分安全 CVar 不能在戰鬥中修改。

重要三層：
```text
CVars
├─ query
│  ├─ GetCVar
│  ├─ GetCVarDefault
│  └─ C_CVar.GetCVarInfo
├─ mutation
│  ├─ SetCVar
│  └─ /console
└─ reset
   ├─ cvar_default
   └─ cvar_reset
```
結論：

- EAM 無法依賴改 CVar 完成功能。
- 秘密強制CVars只應放即時驗證清單。
-不在戰鬥中修改安全CVar。

### 巨集命令

`巨集指令`分為字元、戰鬥等指令。

重要三層：
```text
Macro commands
├─ character commands
├─ combat commands
│  ├─ cast / use
│  ├─ cancelaura
│  └─ startattack / stopattack
└─ addon slash commands
   ├─ /eam opt
   ├─ /eam debug
   └─ /eam export
```
結論：

- EAM 斜線指令只能進行設定、探測、偵錯、匯出。
- 不增加戰鬥自動化。
- 不產生cast/use/cancelaura類行為。

### 戰鬥日誌

`Combat Log` / `COMBAT_LOG_EVENT_UNFILTERED` 是歷史上常見的 AddOn 資料來源，但 12.x 目標與 EAM 重寫無法依賴盲掃。

重要三層：
```text
Combat Log
├─ Combat Log window / file
├─ COMBAT_LOG_EVENT_UNFILTERED
│  ├─ source
│  ├─ destination
│  ├─ prefix
│  └─ suffix
└─ EAM boundary
   ├─ not primary source
   ├─ no heavy parsing
   └─ use event services instead
```
結論：

- 12.x 的 EAM 不以 CLEU 作為光環/cooldown 主要來源。
- 僅在必要時除錯或非熱路徑檢查時參考。
- 未建立類似WeakAura的戰鬥解析器。

### 轉義序列/超鏈接

`UI escape strings` 和 `Hyperlinks` 是偵錯文字、工具提示、匯入/export 的風險區。

重要三層：
```text
Escape sequences
├─ color
├─ texture
└─ reset
```

```text
Hyperlinks
├─ link format
│  ├─ color prefix
│  ├─ type:payload
│  └─ display text
├─ inspection
│  ├─ SetItemRef
│  └─ ExtractHyperlinkString
└─ EAM use
   ├─ spell link display
   ├─ item link display
   └─ debug-safe export
```
結論：

- import/export 不宜解析秘密匯出的超連結文字。
- 工具提示 spellID/itemID 顯示可以保留，但必須和執行時間事實分開。
- 偵錯匯出要轉義管道/超連結類文字。

### API 更改

`API變更摘要`是版本追蹤入口。

重要三層：
```text
API changes
├─ Retail
│  ├─ 12.0.0
│  ├─ 12.0.1
│  ├─ 12.0.5
│  └─ 12.0.7
├─ change categories
│  ├─ Global API
│  ├─ ScriptObjects
│  ├─ Widgets
│  ├─ Events
│  └─ Structures
└─ EAM use
   ├─ removed API cleanup
   ├─ C_* migration
   └─ live validation targets
```
結論：

- 正式服補丁要重新檢查 12.x API 變更。
- 12.0.7 API 摘要已發佈；仍需以實機驗證確認 EAM 行為。
- 12.0.5 的 formatter/duration/table.freeze 已寫入 `Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md`。

### 操作指南

`HOWTOs` 是教學頁面索引，適合作為 UI 操作參考，但不是 Retail 12.x API 合約。

重要三層：
```text
HOWTOs
├─ Getting Started
│  ├─ Introduction to Lua
│  └─ Create a WoW AddOn
├─ UI examples
│  ├─ Making draggable frames
│  └─ frame examples
└─ EAM use
   ├─ options UI reference
   ├─ anchor movement
   └─ avoid example-grade hot path code
```
結論：

- 可參考拖曳框實作。
- 不要直接複製閉包重的範例到運行時熱路徑。
- 選項 UI 可以保留簡單，避免 WeakAura 之類的系統。

## 對 EAM Docs 的後續建議

- `Docs/01_ARCHITECTURE.md`可加入本文件作為API導覽。
- `Docs/02_RETAIL_API_BOUNDARIES.md`應引用`WoW API`、`C_Secrets`、`Events`、`Widget API`。
- `Docs/05_PERFORMANCE_GUIDE.md`應引用`Widget腳本`、`Lua API`、`Frame:RegisterAllEvents`。
- `Docs/06_TEST_PLAN_RETAIL.md`應加入`CVar`強制保密測試與`API變更`版本追蹤。
## 遍歷限制

- 本次是靜態文件瀏覽，不是全站鏡像。
- `wowuidev` 在主選單中以入口出現，但本查詢未找到獨立、可作為 Retail 12.x 執行時間合約的新版頁面；只保留為背景入口。
- `12.0.7/API_changes` 已找到；本文件僅作導覽索引，不取代 `Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md` 的詳細整理。
# EventAlertMod Remake：Retail 12.1 Native Aura 改造提示語

> 目標儲存庫：<https://github.com/ziyuefan/EventAlertMod_Remake>  
> 目前基準：Retail 12.0.7，`Interface: 120007`  
> 目標世代：Retail 12.1.0 / Midnight AddOn API  
> 預設語言：台灣繁體中文  
> 任務性質：既有架構增量改造，不推倒重寫

---

## 0. 你的角色

你是負責 World of Warcraft Retail AddOn 架構、Lua 5.1 效能、Secret Value／Forbidden Aspect、FrameXML 與 UI Taint 邊界的資深工程師。

你必須在既有 EventAlertMod Remake 架構上完成 12.1 Native Aura 遷移，優先保留：

- 現有 SavedVariables 與使用者設定語意。
- `EventRouter → Services → Managers → UI` 的分層。
- `Scheduler`、`AlertManager`、`IconPool`、Cooldown／Item／ClassPower／GroundEffect／Totem 等既有模組。
- 低 GC、事件驅動、UI 寫入前比對、集中排程與物件池策略。
- EAM「比 WeakAuras 更簡單、輕量、專注光環與冷卻提醒」的產品定位。

不要把工作誤解成重新製作一套全新插件。

---

## 1. 執行前必讀與事實來源

先閱讀並整理以下檔案，再修改任何程式碼：

1. `AGENTS.md`
2. `Docs/00_AI_CONTEXT.md`
3. `Docs/01_ARCHITECTURE.md`
4. `Docs/02_RETAIL_API_BOUNDARIES.md`
5. `Docs/03_STATE_SCHEMA.md`
6. `Docs/04_MODULE_CONTRACTS.md`
7. `Docs/05_PERFORMANCE_GUIDE.md`
8. `Docs/06_TEST_PLAN_RETAIL.md`
9. `Docs/07_MIGRATION_NOTES.md`
10. `Docs/09_KNOWN_LIMITATIONS.md`
11. `Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md`
12. `Docs/15_DEVELOPMENT_ISSUE_LOG.md`
13. `Docs/16_RETAIL_ADDON_OPTIMIZATION_ROADMAP.md`
14. `Docs/19_AURA_1210_REDUX_BLUEPRINT.md`
15. `Docs/20_CDM_BYPASS_FEASIBILITY_STUDY.md`
16. `Services/AuraService.lua`
17. `Services/CooldownService.lua`
18. `Services/ShadowHostService.lua`
19. `Managers/AlertManager.lua`
20. `UI/IconPool.lua`
21. `UI/Renderer.lua`
22. `Core/Env.lua`
23. `Core/Util.lua`
24. `EventAlertMod.toc`

### API 事實優先序

遇到文件衝突時，依下列優先序判定：

1. 目前 12.1 PTR／正式客戶端內的 Generated API Documentation。
2. 當前版本 Blizzard FrameXML。
3. Warcraft Wiki 的 `Patch 12.1.0/API changes` 與個別 API 頁面。
4. 本專案 `Docs/`。
5. 舊版註解、歷史 PoC 與推測性 workaround。

參考入口：

- <https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes>
- <https://warcraft.wiki.gg/wiki/API_C_UnitAuras.AddAuraSound>
- <https://github.com/ziyuefan/EventAlertMod_Remake>

12.1 PTR API 仍可能變動。實作前必須核對實際函式名稱、參數與 XML Template；若文件與客戶端不一致，以客戶端為準，並更新專案文件。

---

## 2. 已知現況與核心判斷

目前 Remake 已完成可保留的現代化骨架：

```text
WoW Event
  → EventRouter
  → Services
  → AlertManager
  → Renderer
  → IconPool
```

同時已具備：

- 集中式 Scheduler。
- AlertManager 批次合併更新。
- AuraStatePool／CooldownStatePool。
- DurationObject 與 `SetCooldownFromDurationObject()`。
- `C_DurationUtil.CreateDurationTextBinding()`。
- UI 寫入快取與部分戰鬥鎖定守衛。
- ShadowHost PoC，但目前已實際停用。

現有主要缺口是：`AuraService.lua` 仍以 12.0.7 資料流為主，包括：

- `UNIT_AURA` 增量 payload。
- `C_UnitAuras.GetAuraDataByIndex()`。
- `C_UnitAuras.GetAuraDataByAuraInstanceID()`。
- 依 Aura Instance ID 查 Tooltip。
- 自建 AuraState、Diff、Cache 與 Renderer 更新。

12.1 在 Aura 為 Secret 的戰鬥情境中，依 index、slot、instance ID 取得 AuraData 的 API 不可作為插件主路徑，`UNIT_AURA` payload 與 AuraData 也可能完整 Secret。

因此本次正確方向是：

```text
舊模式：
AuraData → AuraState → AlertManager → Renderer → IconPool

12.1 Native 模式：
EAM 使用者設定
  → AuraRuleCompiler
  → AuraContainer
  → AuraSlot / AuraGroup
  → Blizzard 原生建立、過濾、排序、倒數與更新 AuraButton
```

Native Aura 不應再經過 Lua AuraState、Aura diff、AlertManager 或一般 Renderer 熱路徑。

---

## 3. 最終目標

完成一套可維護的雙後端 Aura 架構：

```text
EAM Aura 設定
  → Capability Detection
  → AuraRuleCompiler
      ├─ NATIVE_SLOT
      ├─ NATIVE_GROUP
      ├─ READABLE_LEGACY
      └─ DISPLAY_UNSUPPORTED
```

### 目標功能

優先恢復：

- 玩家自身 Buff／Debuff 固定位置圖示。
- 目標 Buff／Debuff 固定位置圖示。
- AuraGroup 動態排列。
- 圖示、原生倒數、Cooldown Swipe、層數、驅散類型與 Tooltip。
- 自訂尺寸、字型、位置與成長方向。
- Aura 新增、層數增加、移除聲音。
- 技能冷卻、物品冷卻、職業資源、地面效果與圖騰功能保持正常。
- 舊設定自動遷移與能力降級提示。

### 不承諾恢復的邏輯

下列功能若受 Secret Value 限制，不得假造或繞過：

- Aura 不存在時提醒。
- `剩餘時間 < N` 的 Lua 條件。
- `層數 >= N` 的 Lua 條件。
- Aura A 與 Aura B 的 Lua AND／OR。
- Aura 與技能冷卻的跨資料複合判斷。
- 依 Secret 值修改顏色、位置、尺寸或其他框架狀態。
- 將 Secret 值字串化、序列化、比較、算術或用作自訂 table key。

這些設定應保留，但標示為降級或不支援，不得靜默刪除。

---

## 4. 硬性禁止事項

### 4.1 禁止以舊 Aura 查詢作為 12.1 主後端

Native Aura 模式下，不得依賴：

- `C_UnitAuras.GetAuraDataByIndex`
- `C_UnitAuras.GetAuraDataByAuraInstanceID`
- `C_UnitAuras.GetAuraSlots` 後自行遍歷 Secret Aura
- `UNIT_AURA.addedAuras`
- `UNIT_AURA.updatedAuraInstanceIDs`
- `UNIT_AURA.removedAuraInstanceIDs`
- `AuraUtil.FindAuraByName`
- Aura Instance ID Tooltip Scraping

可以保留舊路徑作為：

- 非 Secret Aura。
- 非戰鬥診斷。
- API fallback。
- 測試與設定預覽。

但必須由 Capability 層明確分流。

### 4.2 禁止將 ShadowHost 當正式主解法

不要重新啟用以下策略作為 12.1 正式 Aura／Cooldown 主後端：

- 將 `EssentialCooldownViewer` 或 `UtilityCooldownViewer` 設為 Alpha 0。
- Hook Blizzard 私有 Pool 取得內部 Icon。
- 把 EAM 圖示 `SetParent()` 到 Blizzard CooldownViewer Icon。
- 依未公開欄位、FramePool 內部結構或名稱映射維持功能。

`ShadowHostService.lua` 可以保留為停用的研究性 PoC，並在文件中標示「非正式依賴」。

### 4.3 禁止偽造 Aura 時間

不得把 Tooltip 顯示的基礎持續時間直接轉換成：

```lua
startTime = GetTime()
expirationTime = GetTime() + baseDuration
```

這會錯誤處理已經過時間、Pandemic、Haste、天賦、裝備、PvP modifier 與動態 Boss Aura。

Tooltip duration 只能用於：

- 設定介面說明。
- 非戰鬥估計。
- Debug metadata。

不得作為戰鬥中的真實倒數。

### 4.4 禁止 Secret Value 洩漏與索引

任何可能為 Secret 的值，必須在：

- 比較。
- 算術。
- `tostring()`。
- 字串拼接。
- table index。
- 序列化。
- `Scheduler.after()`。
- UI 分支判斷。

之前完成安全檢查。

特別禁止：

```lua
customTable[secretSpellID]
duration > 0
expirationTime - GetTime()
tostring(secretValue)
```

---

## 5. 建議新增模組

原則上新增以下模組；若既有命名規範要求不同，可調整名稱，但責任邊界必須保持。

```text
Services/
├── AuraCapabilityService.lua
├── AuraContainerService.lua
├── AuraSoundService.lua
├── AuraService.lua                 # 降為 Legacy／Diagnostic Backend
└── ShadowHostService.lua           # 保持停用 PoC

Managers/
├── AlertManager.lua
└── AuraRuleCompiler.lua

UI/
├── Renderer.lua
├── NativeAuraRenderer.lua
└── IconPool.lua
```

### 5.1 `AuraCapabilityService.lua`

責任：

- 只在初始化或版本／環境變更時偵測 API。
- 快取 Capability，不在熱路徑重複查函式存在性。
- 匯出不可變能力表。
- 區分 12.1 Native Aura、Readable Legacy、Unsupported。

建議能力欄位：

```lua
{
    hasAuraContainer = false,
    hasAuraGroup = false,
    hasAuraSlot = false,
    hasAuraSound = false,
    hasDurationObject = false,
    canUseSpellIDCandidateFilter = false,
    supportsPrivateAuras = false,
    backend = "LEGACY",
}
```

不要只用 Interface 版號判定，必須搭配 API feature detection。

### 5.2 `AuraRuleCompiler.lua`

責任：

- 將 EAM SavedVariables 內的 Aura Alert 編譯為穩定的 Runtime Rule。
- 不讀取即時 AuraData。
- 不操作 UI。
- 不在戰鬥中修改容器結構。
- 產出 `NATIVE_SLOT`、`NATIVE_GROUP`、`READABLE_LEGACY` 或 `DISPLAY_UNSUPPORTED`。

建議輸出：

```lua
{
    alertID = "...",
    backend = "NATIVE_SLOT",
    unit = "player",
    slotKey = "EAM_SLOT_<stable-id>",
    filterString = "HELPFUL|PLAYER",
    candidateFilters = {
        includeSpellIDs = {
            [12345] = true,
        },
        isFromPlayerOrPlayerPet = true,
    },
    layout = {...},
    style = {...},
    sound = {...},
    limitations = {},
}
```

注意：

- `slotKey`／`groupKey` 必須由設定資料生成穩定字串，不能使用 Secret runtime 值。
- `includeSpellIDs` 僅可使用玩家設定中的普通 Spell ID。
- 若目前 12.1 API 對 Secret Aura Spell ID filter 有限制，編譯器必須回傳能力限制，不可假設所有單位與所有 Aura 都可用。
- 不支援條件要寫入 `limitations`，供設定 UI 顯示。

### 5.3 `AuraContainerService.lua`

責任：

- 在脫戰時建立與維護 player／target AuraContainer。
- 呼叫目前 12.1 實際存在的 `AddAuraSlot()`／`AddAuraGroup()`。
- 設定 Unit、Filter、Candidate Filters、Sorting、Layout 與初始化 callback。
- 管理規則 revision。
- 設定變更時採用「重建或差異套用」，但所有結構修改只在非戰鬥進行。
- 戰鬥中只讓 Blizzard 原生更新 AuraButton。

必要原則：

```text
Native Aura 熱路徑：
0 次 UNIT_AURA Lua 解析
0 次 AuraData Diff
0 次 AuraState 分配
0 次 AlertManager Queue
0 次 Renderer.render
0 次 Lua 倒數 OnUpdate
```

建立 AuraContainer 時：

- `CreateFrame("AuraContainer", ...)` 必須在非戰鬥。
- 必須核對目前 12.1 的 Template 名稱。
- 不得由插件自行 Create AuraButton；由 AuraContainer 建立。
- 使用 `initializeFrame` 一次完成外觀 Region 綁定。
- 不得利用 AuraButton `OnShow`／`OnHide`／`IsShown()` 推導 Aura 狀態。
- 不得 Hook AuraButton mixin 或註冊事件偷取狀態。
- 不得依顯示與否觸發其他 Lua 邏輯。

### 5.4 `NativeAuraRenderer.lua`

責任：

- 只負責 AuraContainer／AuraButton 的初始外觀、錨點與非即時設定。
- 不讀 AuraData。
- 不做 Aura 狀態判斷。
- 不建立每圖示 OnUpdate。
- 不將 Native AuraButton 包裝成一般 `AlertState`。

`initializeFrame(auraButton)` 應：

- 建立或取得 Icon Texture。
- 建立 Duration FontString。
- 建立 Stack FontString。
- 指定 CooldownFrame／DurationText。
- 套用 EAM 字型、大小、遮罩、邊框與位置。
- 僅做一次結構性初始化。
- 後續設定變更若涉及 protected／forbidden 物件，延後至脫戰重建容器。

### 5.5 `AuraSoundService.lua`

使用目前有效的：

```lua
C_UnitAuras.AddAuraSound(trigger, soundInfo)
C_UnitAuras.RemoveAuraSound(soundID)
```

支援：

- `Enum.UnitAuraSoundTrigger.Added`
- `Enum.UnitAuraSoundTrigger.ApplicationsIncreased`
- `Enum.UnitAuraSoundTrigger.Removed`

責任：

- 依 alertID 保存註冊 ID。
- 專精切換、設定變更、刪除 Alert、登出前適當解除。
- 禁止重複註冊造成同一 Aura 多次播放。
- 若 API 不存在，自動降級並記錄 capability limitation。
- SoundFileID 與 SoundFileName 至少擇一，輸出頻道依現有 EAM 設定。
- API 可能有 untainted／restricted 要求，註冊動作只在安全生命週期執行。

---

## 6. 現有模組修改要求

### 6.1 `Services/AuraService.lua`

將它定位為：

```text
Legacy / Non-secret / Diagnostic Aura Backend
```

要求：

- 12.1 Native Backend 啟用時，不註冊 `UNIT_AURA` 作為主要顯示管線。
- 不再掃描 1～80 個 Aura 作為 12.1 主流程。
- 移除或停用戰鬥中 Tooltip Instance ID duration scraping。
- `AddBlockedAura()`／`ClearBlockedAuras()` 不得作為 EAM 自訂白名單的效能捷徑，除非目前正式文件明確證明該用途合法且穩定。
- 既有 AuraStatePool 可保留給 Legacy／Diagnostic。
- 修正所有 `auraInstanceID` table key 前的 Secret 防禦。
- 任何 `type(secretTable)`、`#secretVector`、`pairs(secretTable)` 也要視為可能不安全，依目前 API 行為防禦。

### 6.2 `Managers/AlertManager.lua`

保留給：

- Cooldown。
- ItemCooldown。
- GroundEffect。
- Totem。
- ClassPower。
- Legacy Aura。

Native AuraContainer 不應送出：

```text
EAM_AURA_STATE_CHANGED
```

新增設定層事件，例如：

```text
EAM_AURA_RULES_CHANGED
EAM_AURA_LAYOUT_CHANGED
EAM_AURA_STYLE_CHANGED
EAM_AURA_SOUND_CHANGED
```

這些事件只觸發脫戰重編譯／重建，不能變成戰鬥 Aura 熱路徑。

### 6.3 `UI/Renderer.lua`

保留一般 State-based Renderer，但修正 Secret duration 風險。

現有類似邏輯：

```lua
local duration = timer and timer.duration
if duration and duration > 0 then
    Scheduler.after(duration, ...)
end
```

必須改成共用安全函式，例如：

```lua
if Util.isSafePositiveNumber(timer and timer.duration) then
    Scheduler.after(timer.duration, ...)
end
```

要求：

- Native DurationObject 不以 Lua Scheduler 推導到期。
- Native AuraContainer 完全不使用 Renderer 的自動隱藏 token。
- `SetText()`、`SetPoint()`、`SetSize()`、`SetTexture()` 先比對快取。
- `pcall()` 不得放在高頻 UI 熱路徑；只留在真正不可控的 API 邊界。
- `legacyTimerFrame` 僅供確定為普通 number 的 fallback。
- 任何 timer 進入 OnUpdate 前都必須通過安全數字驗證。

### 6.4 `Services/CooldownService.lua`

目前 DurationObject 方向正確，保留並審計：

- `C_Spell.GetSpellCooldownDuration(spellID, true)`。
- `C_Spell.GetSpellChargeDuration(spellID)`。
- Secret cooldown 只交由原生 DurationObject 顯示。
- 不以 Secret startTime／duration 決定任意 Lua 分支。
- 若 cooldownInfo 存在但內容不可安全讀取，不得以「存在 table」直接推定一定應顯示；需要使用官方可顯示通道或明確能力狀態。
- 避免同一事件重複建立 DurationObject。
- 維持 revision-based alert array 與低 GC 策略。

### 6.5 `Services/ShadowHostService.lua`

保持停用：

```lua
GetHostIcon() → nil
initShadowHost() 不呼叫
```

在檔案註解與 `Docs/09_KNOWN_LIMITATIONS.md` 清楚說明：

- 這是歷史 PoC。
- 不屬於正式 12.1 Backend。
- 不得因 Native Aura 開發卡關而自行恢復。

---

## 7. SavedVariables 與能力降級

不得破壞現有：

- `EAM_DB`
- `EA_Config`
- `EA_Position`
- `EA_Items`
- `EA_AltItems`
- `EA_TarItems`
- `EA_ScdItems`
- `EA_GrpItems`
- `EA_Pos`

增加 schema version 與 migration：

```lua
EAM_DB.schemaVersion = <new version>
```

每條 Aura Alert 增加可重建的 runtime capability；不要將 Frame、DurationObject、AuraContainer 或其他 ScriptObject 寫入 SavedVariables。

建議 UI 顯示：

```text
原生固定槽位
原生動態群組
僅非 Secret Aura 可用
12.1 戰鬥中降級
目前 API 不支援
等待脫戰套用
```

舊設定轉換失敗時：

- 保留原資料。
- 記錄 migration warning。
- 不得直接刪除 alert。
- 提供 `/eam debug` 或 PromptExport 可讀狀態。

---

## 8. 效能與 GC 驗收要求

### Native Aura 熱路徑

必須達到：

- 不註冊或不解析 `UNIT_AURA`。
- 不建立 Lua AuraState。
- 不建立臨時 table。
- 不呼叫 `pairs()`／`ipairs()` 遍歷 AuraData。
- 不使用每圖示 OnUpdate。
- 不反覆 `CreateFrame()`。
- 不反覆建立 closure。
- 不在事件中做字串格式化與大量 debug log。
- 不呼叫 Tooltip API。
- 不重複執行 capability detection。

### 設定／重建冷路徑

允許：

- 以 revision 判定是否重編譯。
- 批次建立 AuraSlot／AuraGroup。
- 使用穩定 table 與物件池。
- 在脫戰後一次性套用所有 pending changes。
- 將同類規則合併成 AuraGroup，避免不必要容器數量。

### UI 寫入

沿用原則：

```text
先比對，再 SetText
先比對，再 SetPoint
先比對，再 SetSize
先比對，再 SetTexture
只在 layout dirty 時重排
```

### 除錯與 Profiling

- Debug log 預設關閉。
- `GetEventCPUUsage`、`GetFunctionCPUUsage`、`GetScriptCPUUsage` 只能按需使用。
- 不將 profiling API 放入正式熱路徑。
- RuntimeProbe 必須能列出目前 Aura Backend、規則數、Slot／Group 數、pending rebuild 與 limitation count。

---

## 9. 戰鬥鎖定、Forbidden Aspect 與 Taint

必須遵守：

- AuraContainer、AuraGroup、AuraSlot 的結構建立與修改只在非戰鬥。
- 戰鬥中設定變更寫入 pending revision，於 `PLAYER_REGEN_ENABLED` 批次套用。
- 不 Hook、Monkey Patch 或取代 Blizzard protected function。
- 不修改 Blizzard UnitFrame、Nameplate、ActionButton、CooldownViewer 私有結構。
- 不在戰鬥中修改 protected frame 的 parent、anchor、attribute、template、size 或 click behavior。
- AuraButton 僅作顯示；不得藉 `IsShown()`、`OnShow`、`OnHide`、child script 或事件註冊推導 Aura 是否存在。
- 不讓 EAM runtime table、Secret 值或 callback 污染 Blizzard secure chain。
- 發生 blocked action／taint／forbidden 錯誤時，記錄觸發步驟、戰鬥狀態與堆疊到 `Docs/15_DEVELOPMENT_ISSUE_LOG.md`。

---

## 10. 實作階段

### Phase 0：基線審計

1. 建立新分支，例如：`codex/eam-12.1-native-aura`。
2. 不提交、不推送、不開 PR，除非使用者明確要求。
3. 列出目前主分支 SHA、TOC 版本與工作樹狀態。
4. 掃描所有 Aura、DurationObject、ShadowHost、UNIT_AURA、Tooltip Instance ID 使用點。
5. 列出 12.1 API 實際名稱與 Template。
6. 產出「保留／修改／淘汰」矩陣。
7. 先更新 implementation plan，再開始改程式碼。

### Phase 1：安全止血

1. 新增 `AuraCapabilityService`。
2. 修正 Renderer Secret duration 比較。
3. Native backend 可用時，阻止舊 AuraService 成為主要戰鬥路徑。
4. 停用戰鬥 Tooltip duration scraping。
5. 保證 12.1 載入時不因 Secret Aura 查詢直接 Lua error。
6. 保證 12.0.7 fallback 仍可載入。

### Phase 2：Rule Compiler

1. 建立穩定 Runtime Rule schema。
2. 將現有 player／target Aura 設定分類。
3. 實作 `NATIVE_SLOT`。
4. 實作 `NATIVE_GROUP`。
5. 實作 `READABLE_LEGACY`。
6. 實作 `DISPLAY_UNSUPPORTED` 與 limitation reason。
7. 加入 SavedVariables migration。

### Phase 3：Native Aura Backend

1. 建立 player AuraContainer。
2. 建立 target AuraContainer。
3. 加入 AuraSlot。
4. 加入 AuraGroup。
5. 套用 candidate filters。
6. 套用 sorting／layout。
7. 在 `initializeFrame` 建立 EAM 外觀。
8. 確認戰鬥中沒有 Aura Lua 熱路徑。
9. 確認容器建立失敗時可安全降級，不可半初始化。

### Phase 4：Aura Sound

1. 實作 Added。
2. 實作 ApplicationsIncreased。
3. 實作 Removed。
4. 防止重複註冊。
5. 設定、專精、刪除 Alert 時正確解除。
6. API 不存在時顯示 capability limitation。

### Phase 5：設定 UI 與相容性

1. 顯示每條規則 backend。
2. 顯示 limitation。
3. 顯示 pending combat rebuild。
4. 保留舊設定。
5. ShadowHost 明確標示為停用 PoC。
6. 12.0.7／12.1 後端能清楚區分。

### Phase 6：測試、文件與打包

1. Lua 語法檢查。
2. TOC 載入順序檢查。
3. SavedVariables migration 測試。
4. 模擬 capability 缺失測試。
5. 戰鬥鎖定 pending rebuild 測試。
6. Native 與 Legacy backend 切換測試。
7. Sound registration lifecycle 測試。
8. 所有文件同步更新。
9. 執行文件轉 HTML 工具。
10. 執行專案既有打包腳本，但不要發布。

---

## 11. 驗收標準

### 必須通過

- AddOn 能在 12.1 載入，不因 Aura Secret API 直接報錯。
- Native Aura 模式不以 `UNIT_AURA` 驅動 EAM 圖示。
- Native Aura 模式不建立 Lua AuraState。
- Player 與 Target 至少各有一個可用 AuraSlot PoC。
- 至少有一個 AuraGroup PoC。
- Native AuraButton 顯示圖示與原生倒數。
- Aura Sound Added／ApplicationsIncreased／Removed 可註冊與解除。
- 戰鬥中修改設定不改容器結構，只標記 pending。
- 脫戰後只進行一次批次重建。
- 既有 Cooldown、ItemCooldown、ClassPower、GroundEffect、Totem 不因 Aura 改造失效。
- 既有 SavedVariables 不遺失。
- ShadowHost 仍停用。
- Tooltip duration 不作戰鬥真實倒數。
- 所有 Secret 值在比較、算術、字串化與 table index 前均有邊界防禦。
- 文件與程式碼一致。

### 效能標準

- Native Aura 戰鬥熱路徑零 Lua Aura 掃描。
- Native Aura 戰鬥熱路徑零臨時 table allocation。
- Native Aura 戰鬥熱路徑零每圖示 OnUpdate。
- Renderer 不對 Native Aura 註冊 Scheduler expiration token。
- 設定未變更時不重建 AuraContainer。
- Debug 關閉時不做事件字串拼接。
- 所有 UI 寫入有 change gating。

### 不可宣稱

若沒有在 WoW Retail 12.1 PTR／正式服實機測試，報告中必須寫：

```text
已完成靜態檢查與模擬測試，尚未完成 WoW 12.1 客戶端實機驗證。
```

不得宣稱「完全相容」、「100% 可用」或「已通過實機測試」。

---

## 12. 建議測試情境

至少建立以下測試矩陣：

| 情境 | 預期 |
|---|---|
| 登入時 API 完整 | 選擇 Native Backend |
| AuraContainer API 缺失 | 選擇 Legacy／Unsupported |
| 戰鬥中變更設定 | 只標記 pending |
| 脫戰 | 一次性重建 |
| Player Buff Slot | Blizzard 原生顯示／隱藏 |
| Target Debuff Slot | Blizzard 原生顯示／隱藏 |
| AuraGroup 多 Aura | 原生排序與排列 |
| Secret Aura | 不查 AuraData、不做 Lua 條件 |
| Non-secret Aura | 可選擇 Legacy Readable |
| Aura Sound Added | 只播放一次 |
| Aura Sound Stack Increase | 層數增加時播放 |
| Aura Sound Removed | 移除時播放 |
| 刪除 Alert | 移除 Slot／Sound 註冊 |
| 切換專精 | 重編譯並解除舊註冊 |
| Reload UI | SavedVariables 正常遷移 |
| 12.0.7 API | 不執行 12.1-only API |
| ShadowHost | 保持停用 |
| Debug off | 熱路徑無 log 字串成本 |

---

## 13. 文件更新要求

同步更新：

- `AGENTS.md`
- `Docs/01_ARCHITECTURE.md`
- `Docs/02_RETAIL_API_BOUNDARIES.md`
- `Docs/03_STATE_SCHEMA.md`
- `Docs/04_MODULE_CONTRACTS.md`
- `Docs/05_PERFORMANCE_GUIDE.md`
- `Docs/06_TEST_PLAN_RETAIL.md`
- `Docs/07_MIGRATION_NOTES.md`
- `Docs/09_KNOWN_LIMITATIONS.md`
- `Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md`
- `Docs/15_DEVELOPMENT_ISSUE_LOG.md`
- `Docs/16_RETAIL_ADDON_OPTIMIZATION_ROADMAP.md`
- `Docs/19_AURA_1210_REDUX_BLUEPRINT.md`
- `Docs/20_CDM_BYPASS_FEASIBILITY_STUDY.md`
- 新增 `Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`

文件內必須清楚區分：

```text
12.0.7 已實作
12.1 已實作
12.1 設計中
PTR 未實機驗證
已知 API 變動風險
```

完成後執行專案既有 Markdown → HTML 轉換工具，避免 `Docs/` 與 `docs_html/` 不同步。

---

## 14. 每個階段的回報格式

每完成一個 Phase，輸出：

```markdown
## Phase N 回報

### 已完成
- ...

### 變更檔案
- `path/file.lua`：...

### 架構決策
- ...

### API 與安全邊界
- ...

### 效能影響
- Lua allocation：
- Event frequency：
- UI writes：
- OnUpdate：
- GC 風險：

### 驗證
- Lua syntax：
- Mock test：
- Static scan：
- WoW 實機：

### 未完成與風險
- ...

### 下一步
- ...
```

---

## 15. 最終交付內容

最終必須提供：

1. 變更摘要。
2. 新架構圖。
3. Native／Legacy Backend 分流說明。
4. 新增與修改檔案清單。
5. SavedVariables migration 說明。
6. Secret Value／Forbidden Aspect／Taint 審計結果。
7. 效能與 GC 影響。
8. 測試結果。
9. 未完成的實機驗證。
10. 已知限制。
11. 建議後續 PTR 驗證清單。
12. 未經要求不得 Push、發布或建立正式 Release。

---

## 16. 立即開始

依以下順序執行：

1. 讀取必讀文件。
2. 檢查 Git 狀態與目前 SHA。
3. 核對 12.1 最新 API。
4. 掃描現有 Aura 熱路徑與 Secret 風險。
5. 先提出具體檔案級改造計畫。
6. 接著直接完成 Phase 1 與 Phase 2。
7. 若目前 API 文件足夠，繼續完成 Native AuraContainer PoC。
8. 不要因局部不確定而推倒既有架構；以 capability detection、隔離模組與可回退設計處理。
9. 任何無法實機驗證的部分明確標記，不得猜測成功。

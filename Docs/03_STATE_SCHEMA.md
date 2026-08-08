<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 狀態模式

## SavedVariables 審核

當前 TOC 聲明的重寫版 SavedVariables：
```lua
EAM_DB
EAM_FLOW_TEST_REPORT_JSON
EAM_VALIDATION_PROFILE
EAM_LIVE_TEST_SESSION
EAM_LIVE_TEST_REPORT_JSON
```

舊版相容與遷移來源仍包含：
```lua
EA_Config
EA_Position
EA_Items
EA_AltItems
EA_TarItems
EA_ScdItems
EA_GrpItems
EA_Pos
```

## Schema v3：Native Aura 與文字版面設定

- `EAM_DB.schemaVersion = 3`；v1 Aura alert 與 v2 文字版面來源都會保存可序列化遷移備份。
- Alert 可保存 `nativeBackend`、`auraFilter`、`showStacks`、`showName`、`showCountdown` 與純資料 `sound`。
- `Frame`、`ScriptObject`、`DurationObject`、`AuraContainer` 與 AuraButton 不得寫入 SavedVariables。
- Runtime plan、fingerprint、pending revision 與 sound registration ID 只存在記憶體。
- 相同設定再次送入回傳 `unchanged`，revision 不變。

文字顯示設定使用單一正規化結構：

```lua
EAM_DB.config.textLayout = {
    schema = 1,
    timer = {
        placement = "OUTSIDE_TOP",
        fontSize = 14,
    },
    applications = {
        placement = "INSIDE_BOTTOM_RIGHT",
        fontSize = 12,
    },
}
```

- `placement` 只接受 `Data/TextPlacementContract.json` 定義的 21 個 ID：框內中央加八方向、框外八個角邊位置與四個正面位置。
- `fontSize` 固定正規化為 8–32；timer 預設 14，applications 預設 12。
- `fontSizeTimeVal`、`fontSizeStack` 只作舊欄位相容鏡像；新程式以 `textLayout` 為事實來源。
- `SavedVariables.updateTextLayout()` 只有在值實際改變時增加一次 revision；重複設定不增加 revision。文字位置／字級改變由 Renderer 直接重套 EAM 自建 FontString，不作為 AuraContainer 結構重建條件。
- v2 升 v3 時在 `migrationBackups.textLayoutV2` 保存舊版位置／字級來源，不靜默丟棄使用者設定。
- 若磁碟中的 `schemaVersion` 高於目前程式可理解版本，初始化不得補預設、正規化或改寫原始 `EAM_DB`。執行期改用目前 defaults 的獨立複本，標記 `futureSchemaPreserved` 與 `futureSchemaSourceVersion`；這是降版保護，不代表新版本資料已成功遷移。

驗證狀態與報告不混入 `EAM_DB`：

- `EAM_VALIDATION_PROFILE`：玩家宣告 `_ptr_`、`_xptr_` 或 `_retail_`，並由客戶端 build／Interface 與 `IsPublicTestClient`／`IsTestBuild`／`IsBetaBuild` 原始旗標交叉驗證；匯入器必須由三個 raw flags 重算 known／aggregate，不信任報告自填彙總。
- `EAM_LIVE_TEST_SESSION`：34 案真人觀察狀態與 `/reload` checkpoint。checkpoint 內的 boot token 只用來比較 Lua table identity，不輸出至 JSON；同一次載入直接 resume 必須回傳 `sameLoadRejected`。
- `EAM_LIVE_TEST_REPORT_JSON`：schema 1 真人簽收報告；phase 尚為 `active`、沒有跨過玩家自行執行的 `/reload`、沒有已知 test-build 身分、34 案未全數通過或仍有 warning 時均不得為 `pass`。
- 備註若含磁碟絕對路徑、WTF 或 Account 片段，執行期以 `[privacy-redacted]` 取代並加入 `privacyNoteRedacted`；匯入器再做第二層拒絕，不得包含帳號、角色、伺服器或 WTF 絕對路徑。
- `EAM_FLOW_TEST_REPORT_JSON`：schema 2 能力／離線契約報告；`offline-mock` 不得升格為實機證據。
觀察到 default/runtime 同伴：
```lua
EA_Config2
EA_ShowScrollSpells
EA_ShowScrollSpell_YPos
```
`EA_Config` 目前儲存顯示和行為切換，例如框架
可見性、名稱/timer/flash 顯示、聲音、字體大小、備用警報、
目標自身減益過濾、冷卻行為、符文顯示和光環值
閾值。

`EA_Position` 儲存錨點、偏移、debuff 顏色設定、目標
佈局標誌、SCD 偏移量、執行圖示設定、boss 級邏輯，以及
冷卻顯示設定。

`EA_Items`、`EA_AltItems`、`EA_TarItems`、`EA_ScdItems` 與 `EA_GrpItems`
儲存配置的警報法術/item/group條目。他們目前的確切領域
shape 是遺留的，應該由版本管理器遷移，而不是凍結。

`EA_Pos` 透過 `G.Pos` 儲存每個類別的共用位置資料。

## 目前全球國家審計

命名空間：
```lua
_G.EventAlertMod
G -- addon namespace from ...
```
主要命名空間運行時表：
```lua
G.Pos
G.SPELLINFO_SELF
G.SPELLINFO_TARGET
G.SPELLINFO_SCD
G.ClassAltSpellName
G.GC_IndexOfGroupFrame
G.EA_CurrentBuffs
G.EA_TarCurrentBuffs
G.EA_ScdCurrentBuffs
G.EA_ShowScrollSpells
G.SpecFrame_LifeBloom
G.iconTextures
G.runeTextures
G.runeSetTexCoord
G.runeEnergizeTextures
G.runeColors
G.runeTypeText
G.RUNE_MAPPING
G.Auras
```
全球家庭：
```lua
EA_CLASS*
EA_SPELL_POWER*
EA_X*
EA_TTIP*
EX_XCLSALERT*
SLASH_EVENTALERTMOD1
SLASH_EVENTALERTMOD2
```
主要 XML/UI 全域變數：
```lua
EA_Main_Frame
EA_Version_Frame
EA_Options_Frame
EA_Icon_Options_Frame
EA_Class_Events_Frame
EA_Other_Events_Frame
EA_Target_Events_Frame
EA_SCD_Events_Frame
EA_Group_Events_Frame
EA_SpellCondition_Frame
EA_GroupEventSetting_Frame
EA_Anchor_Frame*
EA_MinimapOption
```
透過作業掃描發現的值得注意的意外全域候選者：
```lua
auraData, eaf, eaf2, EAEXF, EAItems, EASCDFrame, EA_icon, EA_rank,
EA_timeLeft, currentBuffs, startTime, duration, expirationTime, timeLeft,
usable, spellId, spellName, icon, frame, importButton, exportButton,
importFrame, exportFrame, MyAddonFrame, tempFunc
```
重寫應將它們移至模組擁有的本地狀態或顯式
命名空間欄位。

## AlertState
```js
AlertState = {
  id: "string",
  kind: "aura|spellCooldown|itemCooldown",
  spellID: "number?",
  itemID: "number?",
  unit: "player|pet|target?",
  icon: "number|string?",
  name: "string?",
  stacks: "number?",
  timer: TimerState?,
  flags: AlertFlags,
  source: SourceState,
  boundaryWarnings: "array<string>?"
}
```
## TimerState
```js
TimerState = {
  mode: "none|numeric|displayOnly|protected|unknown",
  startTime: "number?",
  duration: "number?",
  expirationTime: "number?",
  timeLeft: "number?",
  displayText: "string?"
}
```
## AuraState
```js
AuraState = {
  alertID: "string",
  unit: "player|pet|target",
  auraInstanceID: "number?",
  spellID: "number?",
  name: "string?",
  icon: "number|string?",
  applications: "number?",
  fromPlayer: "boolean?",
  timer: TimerState,
  factsSafe: "boolean",
  boundaryWarnings: "array<string>?"
}
```
## CooldownState
```js
CooldownState = {
  alertID: "string",
  spellID: "number",
  name: "string?",
  icon: "number|string?",
  usable: "boolean?",
  charges: "number?",
  maxCharges: "number?",
  timer: TimerState,
  factsSafe: "boolean",
  boundaryWarnings: "array<string>?"
}
```
## ItemCooldownState
```js
ItemCooldownState = {
  alertID: "string",
  itemID: "number",
  linkedSpellID: "number?",
  name: "string?",
  icon: "number|string?",
  timer: TimerState,
  cacheStatus: "none|direct|pending|ready|throttled|combatBlocked",
  boundaryWarnings: "array<string>?"
}
```
## IconRenderState
```js
IconRenderState = {
  alertID: "string",
  visible: "boolean",
  texture: "number|string?",
  stackText: "string?",
  timerText: "string?",
  nameText: "string?",
  cooldown: { start: "number?", duration: "number?", enabled: "boolean?" },
  glow: "none|active|usable|warning",
  alpha: "number?",
  layoutKey: "string"
}
```
## DebugSnapshot
```js
DebugSnapshot = {
  schema: 1,
  addon: { name: "EventAlertMod", version: "string?", build: "number?" },
  environment: { retailOnly: true, inCombat: "boolean", fps: "number?" },
  facts: { alerts: "array<AlertState>" },
  derived: { icons: "array<IconRenderState>", dirtyQueues: "object" },
  boundaryWarnings: "array<object>",
  humanNotes: "array<string>"
}
```

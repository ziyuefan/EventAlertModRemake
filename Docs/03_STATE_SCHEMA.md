<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 狀態模式

## SavedVariables 審核

當前 TOC 聲明這些 SavedVariables：
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

## Schema v2：Native Aura 設定

- `EAM_DB.schemaVersion = 2`，v1 Aura alert 會保存可序列化遷移備份。
- Alert 可保存 `nativeBackend`、`auraFilter`、`showStacks`、`showName`、`showCountdown` 與純資料 `sound`。
- `Frame`、`ScriptObject`、`DurationObject`、`AuraContainer` 與 AuraButton 不得寫入 SavedVariables。
- Runtime plan、fingerprint、pending revision 與 sound registration ID 只存在記憶體。
- 相同設定再次送入回傳 `unchanged`，revision 不變。
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

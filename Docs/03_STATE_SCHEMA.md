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

### 語系設定

`EAM_DB.config.language` 是可遷移的純字串設定，接受 `auto`、`enUS`、`zhTW`、`zhCN`、`koKR`、`ruRU`；預設為 `auto`。`auto` 依客戶端 `GetLocale()` 選擇 catalog，缺少的 key 由 enUS fallback 補底。`SavedVariables.updateLanguage()` 只有在值改變時增加 revision，但 updated／unchanged 都會同步發出 `EAM_LANGUAGE_CHANGED`，讓記憶體狀態與已載入 UI 對齊。`Locale.apply()` 保持 `EAM.L` table identity，原地清除並合併 enUS fallback 與選定 catalog，再刷新已註冊的 EAM 自有 FontString、按鈕與複合文字。新版程式載入後，選擇語系立即生效，不需為套用語系執行 `/reload`；`/reload` 只用於驗證設定保存、載入磁碟上的新程式，或將最新 SavedVariables 寫回磁碟。

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
- `EAM_LIVE_TEST_SESSION`：37 案真人觀察狀態與 `/reload` checkpoint。checkpoint 內的 boot token 只用來比較 Lua table identity，不輸出至 JSON；同一次載入直接 resume 必須回傳 `sameLoadRejected`。
- `EAM_LIVE_TEST_REPORT_JSON`：schema 1 真人簽收報告；phase 尚為 `active`、沒有跨過玩家自行執行的 `/reload`、沒有已知 test-build 身分、37 案未全數通過或仍有 warning 時均不得為 `pass`。
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

## 2026-08-12 Theme 設定

`EAM_DB.config.theme` 是可持久化的 EAM 自有 UI 主題選擇，允許值與預設如下：

```js
config.theme = "eam" // "eam|ff7|winxp|borland|doscrt|aqua"
```

- `eam` 為既有棕金視覺，亦是缺值或非法值的安全回退。
- `ff7` 為深靛、皇家藍、亮青與金色 palette；`winxp` 為 Luna 藍、淺灰、亮藍／綠 palette；`borland` 為電光藍／青色 IDE；`doscrt` 為黑綠磷光 CRT；`aqua` 為 macOS Aqua 藍灰／亮藍。
- `SavedVariables.updateTheme()` 只在實際值改變時寫入並增加 revision；重複選擇不得製造 revision。
- 啟動時非法值會正規化為 `eam`，並在 migration warnings 留下 `invalidThemeDefaulted`；不覆蓋其他 SavedVariables。
- 戰鬥中只保存 pending theme，待 `PLAYER_REGEN_ENABLED` 後由 `EAM.Theme.flushPending()` 套用。
- 主題色只屬於 EAM 自有視窗 chrome；AlertBorderStyles 的自身／目標 Aura、技能、物品、地面效果語意色不由主題覆蓋。

## 2026-08-13 AuraSound 純資料契約

Aura alert 可保存以下 additive 純資料，不增加目前 SavedVariables schema 版本：

```lua
alert.sound = {
    added = { soundFileID = 566564, outputChannel = "Master" },
    applicationsIncreased = nil,
    removed = { soundFileName = "Interface\\AddOns\\EventAlertMod\\Media\\example.ogg" },
}
```

- trigger 白名單固定為 `added`、`applicationsIncreased`、`removed`。
- 每個 trigger 必須提供正整數 `soundFileID` 或非空白 `soundFileName`；若兩者同時存在，正規化只保留 `soundFileID`。`outputChannel` 若存在必須是非空白字串。
- `nil` 或正規化後的空表代表未覆寫，編譯器沿用全域音效；全域 `config.showSound=false` 是 master off，custom 設定不得繞過。
- `SavedVariables.updateAuraSound(unit, spellID, sound)` 是唯一公開 mutation：非法輸入拒絕；相同設定不增加 revision；真變更只增加一次並發送 `EAM_AURA_SOUND_CHANGED`。
- `auraSoundID` 只屬本次 Lua session 的 runtime registry，絕不可寫入 SavedVariables、JSON、報告或 table key。
- 初始化只對現有 class profile 的 Aura sound 做白名單正規化；無法保留的值加入 `invalidAuraSoundNormalized` warning，不凍結使用者資料。
- 真人 session 與報告的現行矩陣為 `2026-08-13.1` 共 37 案；必須 37/37、跨玩家自行執行的 `/reload`、已知 build identity 且零 warning 才可能完成。

## 2026-08-13 Alpha 4：功能模組與職業 profile 純資料契約

schemaVersion 5 的 EAM_DB 目前包含兩個互相獨立的設定面：

- config.moduleToggles：playerAura、targetAura、spellCooldown、itemCooldown、groundEffect、classPower、totem、tooltipMonitor；缺值預設 true，寫入必須經 SavedVariables.updateModuleToggle。
- profiles.classes[CLASS_TOKEN]：目前職業的 playerAuras、targetAuras、spellCooldowns、itemCooldowns、groundEffects。正式服務透過 getActiveClassToken／getAlertList 讀取，不保留根層 alerts mirror。
- v4 根層全域清單遷移時先保存 migrationBackups.globalAlertsV4；無法取得合法職業 token 時保存 profiles.unassignedLegacy，禁止猜測歸屬。
- /eam list、lookup、lookupfull 與 showcast 使用 active class profile；清空後不因 reload 重新灌入預設，defaultsSeeded 與 legacyImportVersion 共同維持冪等性。
- 目前正式程式沒有 JSON／Base64 profile 分享 codec；Debug export 也不是可套用的設定匯入格式。任何未來分享格式都必須拒絕外部 Lua、Secret 值、未知 schema、重複 ID 與過大輸入。

## 2026-08-14 Alpha 5：Profile 分享與字型設定

Core/ProfileCodec.lua 定義正式分享格式 EAMAP1:<base64(JSON envelope)>。JSON 是 canonical UTF-8 純資料，不能包含 function、userdata、metatable、Secret 值或執行字串。

- envelope 必須是 type=EAM_ALERT_PROFILE、schema=1、addonSchema=5，並帶 scope.classToken、允許的 scope.modules、payload.modules、payloadBytes 與 checksum={algorithm="adler32",value="8hex"}。
- Base64 僅接受嚴格 alphabet／padding；encoded 上限 262144 bytes、decoded 上限 196608 bytes、JSON depth 8、nodes 16384、總 alerts 4096、每 module 1024。
- import 先做 parse、schema、checksum、scope、欄位白名單與 ID 重算，再產生 preview；preview 不增加 revision、不發事件。merge 只 upsert scope 內項目，replace 只替換指定 class／module 並保留 bounded backup。
- 戰鬥中拒絕結構性 apply；EAMAP1 不是加密，也不宣稱來源可信。任何 malformed／future schema／duplicate key／duplicate derived ID 都 fail-closed。
- config.fontFamily 允許 STANDARD、ARIALN、MORPHEUS、SKURRI，預設 STANDARD；變更由 SavedVariables.updateFontFamily 正規化、no-op 保持 revision，並由 TextPlacement 套用於 EAM 自有 FontString。

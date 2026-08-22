<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 魔獸爭霸 Wiki 12.x API 變更筆記

本文件整理自 Warcraft Wiki 的 `API 更改摘要` 與 Retail 12.x
相關頁面，作為 EventAlertMod / EAM 正式服重寫的實作參考。

這不是完整的 API 檔案備份；這份筆記只保留與 EAM 的 aura、cooldown、
專案冷卻、UI渲染器、偵錯匯出、SavedVariables遷移直接
相關的重點。

## 來源

- https://EAMCODE_4__.wiki.gg/wiki/API_change_summaries
- https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
- https://warcraft.wiki.gg/wiki/Patch_12.0.1/API_changes
- https://warcraft.wiki.gg/wiki/Patch_12.0.5/API_changes
- https://warcraft.wiki.gg/wiki/Patch_12.0.7/API_changes
- https://EAMCODE_4__.wiki.gg/wiki/Patch_12.0.5
- https://EAMCODE_0__.wiki.gg/wiki/Patch_12.0.7
- https://EAMCODE_0__.wiki.gg/wiki/Public_client_builds
- https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes
- https://EAMCODE_0__.wiki.gg/wiki/API_Cooldown_SetCooldownFromDurationObject
- https://EAMCODE_0__.wiki.gg/wiki/API_FontString_ClearText
- https://EAMCODE_0__.wiki.gg/wiki/Secret_Values
- https://EAMCODE_0__.wiki.gg/wiki/ScriptObject_DurationObject
- https://EAMCODE_0__.wiki.gg/wiki/API_C_Spell.GetSpellCooldown
- https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellCharges
- https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByAuraInstanceID
- https://warcraft.wiki.gg/wiki/API_C_TooltipInfo.GetUnitBuffByAuraInstanceID
- https://warcraft.wiki.gg/wiki/API_C_TooltipInfo.GetUnitDebuffByAuraInstanceID
- https://EAMCODE_0__.wiki.gg/wiki/Category:API_systems/TooltipInfo
- https://EAMCODE_0__.wiki.gg/wiki/Category:API_systems/UnitAuras
- https://EAMCODE_0__.wiki.gg/wiki/API_Cooldown_SetCooldown
- https://EAMCODE_0__.wiki.gg/wiki/API_Cooldown_SetCooldownDuration
- https://EAMCODE_0__.wiki.gg/wiki/API_Cooldown_GetCooldownDisplayDuration
## 2026-05-26 複查摘要

這次重新檢索魔獸爭霸Wiki後，與EAM直接相關的結論如下：

- `API 變更摘要` 與搜尋索引目前可找到 `12.0.0`、`12.0.1`、`12.0.5`、`12.0.7` API 變更摘要。
- `補丁 12.0.0/API 變更`是 Secret Values 與 AddOn 安全限制的核心起點。
- `Patch 12.0.1/API Changes` 是午夜啟動補丁；對 EAM 的直接影響低於 12.0.0/12.0.5，但仍需追蹤添加光環過濾器和 tooltip/filter 行為。
- `Patch 12.0.5/API 更改` 明確新增 `table.freeze`、`table.isfrozen`、API 謂詞檔案、冷卻倒數格式化程式、FontString 平滑縮放，並補強秘密/安全相關訊息。
- 12.x引入了強大的C語言底層Blocked Aura引擎`C_UnitAuras.AddBlockedAura(unit, auraInstanceID)`與時間黑盒`C_UnitAuras.GetAuraDuration(unit, auraInstanceID)`，提供0-GC和100%安全的防污染執行鏈。
- 12.x 引進了資料驅動型 Tooltip 系統，以 `C_TooltipInfo.GetUnitBuffByAuraInstanceID(unit, auraInstanceID)` 與 `GetUnitDebuffByAuraInstanceID` 取代了舊式的 `SetUnitBuff` 模擬渲染，將資料與 UI 徹底分離，並取代了舊式的 `SetUnitBuff` 模擬渲染，將資料與 UI 徹底分離，並完美接了一個橋接橋。
- `Secret_Values`、`ScriptObject_DurationObject`、`C_Spell.GetSpellCooldown`、`C_TooltipInfo.GetUnitBuffByAuraInstanceID` 這些單頁檔案已論證支撐 EAM 的架構決策：資料來源層必須處理秘密邊界，渲染器應盡量遷移暴雪小工具顯示持續時間。
- 12.0.7 的公開 API 變更摘要目前未顯示直接影響 EAM aura/cooldown/item Cooldown 核心邏輯的大型 API 變更，但新增 __EAM__CODE_4__6、EA DurationObject / 定時器顯示追蹤事項。

注意：以上是文件與索引索引交叉整理，尚未在 WoW Retail 12.x 用戶端內實機驗證。

## 2026-05-29 使用者提供的 12.0.7 PTR / RC 備查摘要
本節來源為使用者貼上的 12.0.7 PTR / RC 變更內容。此輪公開網路搜尋尚未找到可直接引用的回覆頁面，因此以下先作為「待公開來源複核、待 WoW Retail/PTR 實機驗證」的工作依據點；不得將其視為已驗證事實。

### 2026-05-29 PTR實測更新：DurationTextBinding

- 使用者已於 WoW 12.0.7 PTR client 執行 `C_DurationUtil.CreateDurationTextBinding` 最小測試範例。
- 結果：FontString 可正常顯示由 `DurationTextBinding` 驅動的倒數文字。
- 驗證範圍：僅確認最小範例可顯示；尚未代表 EAM Renderer 已完成整合。
- 尚未驗證：戰鬥中行為、污染日誌、圖示重用後文字清除、區域設定顯示、過渡文字、零持續時間、與主要 `Cooldown:SetCooldownFromDurationObject()` 的整合策略。
- EAM 實施規則：可將 `DurationTextBinding` 視為 12.0.7 PTR 已可用候選路徑，但正式整合仍需特徵偵測與回退。

### 與 EAM 直接相關

- 工具提示金錢：新增`GameTooltip_AddMoneyLine`，改用atlas / `MoneyFormatter`顯示金錢；建議AddOn避免舊式`SetTooltipMoney`，以降低工具提示秘密值問題。
- 單位識別：局部限制單位代幣的 API，例如 `UnitGUID`、`UnitAura`、health/power 類別 API，遇到不支援代幣時改為回傳 `nil` 或預設值，不再直接遇到不支援代幣時改為回傳 `nil` 或預設值，不再直接遺失。 EAM 仍不得依賴錯誤作為控制流程。
- 檔案資源：新增`C_UIFileAsset`，可用`GetFileID`、`IsKnownFile`、`IsLooseFile`在使用字體與材質前驗證資源是否存在。 EAM可在Options/Renderer初始化時低頻使用，不得放熱路徑。
- Profiling：`GetEventCPUUsage`、`GetFunctionCPUUsage`、`GetScriptCPUUsage`重新開放給AddOn。 EAM只可用於按需debug/profiling，進入不可常態運行時。
- 除錯秘鑰：`debugstack` 與 `debuglocals` 若目前函式或呼叫某個曾接觸過的秘鑰值，可能回傳秘鑰值。 EAM 偵錯導出不得把 stack/local 設為安全文字直接輸出。
- ScrollBox secret：官方修改secret出現在滾動框區域時造成的問題。 EAM若未來做設定列表，仍需避免把secret/protected原始值放入可捲動UI。
- 聊天增益事件：貨幣、榮譽、戰利品、金錢、聲望、XP增益聊天事件不再秘密。 EAM目前尚未以聊天事件作核心資料來源，僅包含後續debug/通知參考。
- TOC 每個指令條件：TOC 支援每個指令條件，例如`## Dep: Addon_X [AllowLoadGameType classic]`。 EAM 仍維持正式服，不因這有能力重新引入經典分支。
- `SetFont`：確定無效字體標誌時錯誤訊息更明確。 EAM 選項應避免讓使用者輸入未驗證標誌。
- 持續時間文字：新增`DurationTextBinding`腳本對象，可把`DurationObject`直接綁定到`FontString`，由臨時系統更新文字。 EAM定時器標籤後續應優先評估路徑，而非Lua OnUpdate自行倒數。
- AuraData：`isFromPlayerOrPlayerPet` 會在玩家控制的載具施放的光環上設為 true。 EAM 的「玩家或玩家寵物來源」判斷需將載具納入實機測試。
- 私有光環聲音：非戰鬥中，主動M+期間可呼叫`C_UnitAuras.AddPrivateAuraAppliedSound`。 EAM暫時不把私有光環聲音納入核心功能。
- Aura 重構時間軸：官方目標把 aura 暴露重構放在 12.1.0。 EAM 的 AuraService 應保持適配器邊界清晰，避免把 12.0.x aura 表結構寫死到 UI/Renderer。

### 與 EAM 關聯較低但需注意

- `ENCOUNTER_END` 新增boss `EncounterUnitStatus`列表，包含`creatureID`、`creatureName`、`remainingHealthPercent`，且註明為非秘密。 EAM目前不做遇到boss時間軸。
- `C_EncounterEvents` 顏色 API 支援文字警告、時間軸事件、5秒剩餘事件與 alpha 值。 EAM 遇到事件時間軸暫時不整合。
- SimulateMouse API 不再攜帶污染，但目前只能在滑鼠焦點都不是被禁止、鎖定、腳本無法存取或受保護框架時，且仍限制遊戲手把操作使用。 EAM 不應將其新增操作模型。
- `C_ScenarioInfo.GetUnitCriteriaProgressValues` 第二回傳值改為 `[0, 1]`。 EAM 不使用此 API。
- Battle.net：`BNInviteFriend`遷移到`C_BattleNet.InviteFriend`。 EAM不使用。
- Mythic Plus 運行歷史/最佳 API 回傳 `CalendarTime` struct。 EAM 不使用。
- `GROUP_FORMED` 修改追隨者地下城 / 深入單人進入時的事件發送。 EAM 目前不依赖。
- `raidtarget` 安全性操作新增 `"set-unmarked"`；EAM 不操作安全性 raid 目標操作。

### 经典PTR 资讯处理原则
用戶提供的內容也包含即將推出的經典 PTR 版本，但本專案僅正式服。經典的秘密文件、raid 目標、巨集聊天、小地圖 ping 等變更僅作為「不可引回 EAM 架構」的，不進入活動代碼、TOC 或模組合約。

## 版本定位

- Retail 12.0.0 的 TOC 是 `120000`。
- Retail 12.0.1 的 TOC 是 `120001`。
- Retail PTR 12.0.5 在「公共客戶端建置」中顯示介面 `120005`。
- Retail 12.0.7 的 API 變更摘要標記 TOC 是 `120007`。
- EAM 正式服重寫應以 12.x / Midnight-era API 為目標。
- Classic、MOP Classic、Cata Classic、Wrath Classic、TBC、Era 都不宜進入新架構。

## 12.0.5 API 變更重點

12.0.5 的 API 變更頁對 EAM 影響最大的是 Lua formatter、DurationObject、aura 欄位保密、`table.freeze`、以及冷卻計時器顯示 API。

### API 謂詞文件

12.0.5 Lua API 文件中新增謂詞表，用來描述每個 API 的限制條件。

EAM實施規則：

- 實作前先看API謂詞，不只看函式名稱與回傳型別。
- 若標記 `SecretWhen...`、`AllowedWhenUntainted`、`SecretArguments`、`SecretReturnsForAspect`，此 API 必須經過服務層或渲染器隔離層。
- 偵錯匯出不宜輸出謂詞判定後仍不安全的原始值。
- 文件未上市或搜尋索引不完整時，不可推論「安全」；只能標示待實機驗證。

### Lua 格式化程式與 DurationObject

12.0.5 新增 Lua 數位格式化類型：
```lua
AbbreviatedNumberFormatter
NumericRuleFormatter
SecondsFormatter
```
文件指出這些格式化程式可穿透持續時間物件的 `Format` 函數接收秘密數字，並提供冷卻訊框使用。

新增冷卻時間API：
```lua
Cooldown:SetCountdownFormatter(formatter)
Cooldown:SetCountdownMillisecondsThreshold(seconds)
```
EAM 渲染器規則：

- 定時器文字不要自己在Lua熱路徑法術符串。
- 有 `DurationObject` 時，優先讓 `Cooldown` 使用格式化程式。
- 少於少數幾個/小數顯示交換 `SetCountdownMillisecondsThreshold`。
- 秒數文字格式化程式必須即時正式服實測，不可假設所有語言環境都一致。

### 充能持續時間與零跨度持續時間

12.0.5 指出以下充能持續時間API在已達到最大充能時，會回傳零跨度持續時間：
```lua
C_SpellBook.GetSpellBookItemChargeDuration
C_Spell.GetSpellChargeDuration
C_ActionBar.GetActionChargeDuration
```
而零跨度持續時間的物件會被視為完全消失。

EAM CooldownService 規則：

- 基於費用的法術不要只用舊式 `charges == maxCharges` 判斷計時器。
- 需支援零跨距`DurationObject`。
- `IconRenderState.timer.mode` 可保留 `displayOnly`，由渲染器變更冷卻小工具。
- 若需要判斷「已完成」，必須確認持續時間物件是否可安全判斷或由小工具顯示結果。

### ignoreGCD 參數

12.0.5 新增冷卻持續時間建構 API 的 `ignoreGCD` 參數。

EAM 規則：
- 法術冷卻警報預設忽略 GCD 類別冷卻。
- 若 API 提供 `ignoreGCD`，優先使用官方參數，不要再靠 61304 差值推測。
- 仍需保留GCD虛擬法術`61304`作為測試/相容觀察點，但不適合作為唯一架構。

### AuraData 欄位不再秘密

12.0.5指出以下`AuraData`欄位不再秘密：
```lua
isHelpful
isHarmful
isRaid
isNameplateOnly
isFromPlayerOrPlayerPet
```
EAM AuraService 規則：

- 這些位元欄可作為分類/過濾優先候選，但仍需檢查目標建置行為。
- `isFromPlayerOrPlayerPet` 可取代部分舊式 `unitCaster == "player"` 邏輯。
- 不代表整個`AuraData` 安全性；期限、有效期限、spellID、名稱、圖示仍需單獨檢查。

### Aura實例ID重新隨機

12.0.5 指定光環實例ID會在進入遭遇、Mythic+、PvP時重新隨機。

EAM AuraService 規則：
- `auraInstanceID` 可作為單一會話/單次限制區間內的安全錨點。
- 不可跨際相遇 / M+ / PvP 長期保存。
- 進入限制場景或接收目標/world/combat狀態變更時，應清理光環快取。
- SavedVariables 介面可保存`auraInstanceID`。

### 單位 API 與身份

12.0.5 加強單位身分限制：

- `UnitName` 不再接受秘密單位代幣。
- `UnitSpellTargetName` 只回傳玩家單位名稱。
- `UnitTokenFromGUID` 在身分秘密時不回傳競技場、銘牌、boss、隊伍、raid、目標目標令牌。
- `UnitIsUnit` 對 `targettarget` / `focustarget` 可能回傳秘密，禁止比較時回傳 nil。

EAM 規則：

- 不要使用 `targettarget` / `focustarget` 作為核心警報匹配。
- 目標光環警報只追蹤`target`，不要自動延伸到目標目標。
- 除錯導出不宜嘗試把秘密單位身分轉成名字/GUID。
- UI標籤若單位名稱不安全，顯示空白或安全後備。

### 表.freeze / 表.isfrozen

12.0.5新增：
```lua
table.freeze(tbl)
table.isfrozen(tbl)
```
EAM 規則：

- 可用來`Core/Constants.lua`的枚舉、模式、模組名稱、狀態常數。
- 不可用於SavedVariables。
- 不可用於運行時aura/cooldown/icon狀態。
- 不可用於調度程序佇列或池物件。
- 需要後備，因為開發環境或舊版本可能沒有這些 API。

### Secret字串清理限制

12.0.5 指出字串格式 API 不再對秘密字串套用字段寬度修飾符，例如 `"%.5s"` 不中斷秘密字串。

EAM 規則：

- 不要靠斷斷絕秘密衍生的文字。
- `C_TooltipInfo`解析前仍要先檢查文字是否秘密。
- 除錯導出不要把秘密字串透過 `format` 硬轉出來。
-timer/name text的長度控制應在安全字串上做。

### 玩家統計與 Aura Secret 關聯

12.0.5指出回傳玩家統計資料的API在光環秘密時也可能回傳秘密。

EAM 規則：

- 特殊能力/資源UI不能想像玩家統計數據永遠安全。
- `SpecialPower` 重寫應走同一個邊界策略。
- 若 power/resource 不安全，僅渲染圖示或修改暴風雪支援的顯示。

### 字體平滑縮放
12.0.5新增：
```lua
FontString:GetSmoothScaling()
FontString:SetSmoothScaling(smooth)
```
EAM 渲染器可在即時正式服驗證後，用於定時器/name/stack 標籤視覺品質，但不宜放入熱路徑重複設定。

### 冷卻小部件秘密方面

`Cooldown:SetCooldown` 和 `Cooldown:SetCooldownDuration` 允許在污染路徑接收特定秘密參數，但會加入 `Enum.SecretAspect.Cooldown`。 `Cooldown:GetCooldownDisplayDuration` 則可能依存於 Cooldown 秘密方面回傳秘密。

EAM 渲染器規則：

- 可以把安全的數字冷卻時間`SetCooldown(start, period, modRate)`。
- 若來源是 `DurationObject`，優先使用 `SetCooldownFromDurationObject(duration, clearIfZero)`。
- 不在渲染器中讀取`GetCooldownDisplayDuration()`作為事實資料。
- 任何可能被秘密方面標記的冷卻幀，都只用於顯示；不要把 getter 回傳值送回服務狀態。

## 12.0.7 API 變更重點

2026-05-26複查，魔獸爭霸Wiki已有`Patch 12.0.7/API_changes`，標註TOC為`120007`，誤差區間為`12.0.5 (67602) -> PTR 176767676767676767205% (21767)。

與EAM直接相關或需要追蹤的項目：

- 新增`C_DurationUtil.CreateDurationTextBinding`。
- 新增`C_DurationUtil.CreateManualClock`。
- 刪除 `C_DurationUtil.GetCurrentTime`。
- 新增分析/CPU使用類別API：`GetEventCPUUsage`、`GetFunctionCPUUsage`、`GetScriptCPUUsage`。
- 大多數其他新增物品偏向Delves、Housing、Merchant、PartyInfo、UIFileAsset等系統，暫時不作為EAM核心依賴。

EAM 文件規則：

- `EventAlertMod.toc` 目前已固定 `120007`；發布前仍需確認 CurseForge 遊戲版本 ID 與 WoW Retail/PTR 實機載入狀態。
- DurationObject / 定時器顯示層需評估 `CreateDurationTextBinding` 與 `CreateManualClock` 是否可取代手寫倒數字字串。
- 不使用已移除的 `C_DurationUtil.GetCurrentTime`。
- 新增 CPU 用法 API 只能作為 debug/profiling 按需工具，不可放入熱路徑。
- 12.0.7 仍需live Retail/PTR 實測，不得只靠文件剩下完全相容。

## 12.0 AddOn 安全核心變化

12.0.0 引入 AddOn 安全更改，目標是限制 AddOn 使用戰鬥資訊做複雜決策，但仍允許 UI 外觀調整。

核心概念是「秘密價值」：

- 秘密值是黑盒值。
- 受污染的外掛程式碼可以收到秘密，也可以把秘密傳給部分允許的API。
- 受污染的外掛程式碼無法讀取秘密內部值。
- 不可對秘密做一般Lua算術、比較、轉字符串、`tonumber`、`string.match`、table key等操作。
- 若API文件註明會回傳秘密，EAM必須將該資料視為不安全，不能把它混入事實。

## 秘密相關 API
12.0.0 新增多個秘密檢查/處理API。 EAM重寫應集中包裝在`Core/Env.lua`或`Core/Util.lua`，不要讓各服務直接散落呼叫。

重要全域API：
```lua
issecretvalue
issecrettable
hasanysecretvalues
canaccesstable
canaccessvalue
canaccessallvalues
canaccesssecrets
scrubsecretvalues
dropsecretaccess
mapvalues
secretwrap
```
重要`C_Secrets` API：
```lua
C_Secrets.HasSecretRestrictions
C_Secrets.ShouldAurasBeSecret
C_Secrets.ShouldCooldownsBeSecret
C_Secrets.ShouldSpellAuraBeSecret
C_Secrets.ShouldSpellCooldownBeSecret
C_Secrets.ShouldSpellBookItemCooldownBeSecret
C_Secrets.ShouldUnitAuraIndexBeSecret
C_Secrets.ShouldUnitAuraInstanceBeSecret
C_Secrets.ShouldUnitAuraSlotBeSecret
C_Secrets.ShouldUnitPowerBeSecret
C_Secrets.ShouldUnitPowerMaxBeSecret
C_Secrets.ShouldUnitSpellCastBeSecret
C_Secrets.ShouldUnitSpellCastingBeSecret
C_Secrets.GetSpellAuraSecrecy
C_Secrets.GetSpellCooldownSecrecy
C_Secrets.GetSpellCastSecrecy
C_Secrets.GetPowerTypeSecrecy
```
實行規則：

- 讀表前先檢查表本身的必然性。
- 讀取值後再檢查值是否為秘密。
- 只有確認安全的值才能進入`facts`。
- unsafe值只能形成 `boundaryWarnings` 或 `timer.mode = "protected" / "unknown" / "displayOnly"`。
- 不要把秘密值寫入SavedVariables。

###秘密價值觀單頁補充
Warcraft Wiki `Secret_Values` 將 Secret 描述為 Patch 12.0.0 引入的新機制；受 taint 的插件程式碼通常只能保存秘密或傳給允許的 API，無法檢視內容。

EAM 判斷規則：

- `if value then` 只能用來區分是否為 nil；不能表示 value 可比較、可刪除或可序列化。
- 不可把秘密字串丟進 `string.match`、`string.format` 或工具提示解析器。
- 不可將秘密數字用於定時器侵犯、排序、差值、表鍵。
- 若API單頁出現`ConditionalSecret`或`SecretWhen...`，即使測試環境暫時回傳普通值，也保留邊界處理。

## 秘密方面與 UI 對象

Secret不僅影響Lua值，基因組複製腳本物件的面向。

重要風險：

- 將秘密傳進部分widget放入API，可以讓該widget的相關getter在回傳秘密之後。
- 秘密主播可能沿著錨鏈往下傳播。
- 佈局訊框不應直接接收秘密饋送的資料。
- 渲染器應隔離「承接秘密顯示物件」與「負責佈局錨點」的框架。

EAM UI實務建議：

- `IconPool` 建立穩定的框架結構。
- `Renderer` 只接收歸一化的 `IconRenderState`。
- 任何可能秘密的紋理、alpha、顯示、文字、持續時間顯示，都要限制在最小的 UI 節點。
- 若框架需要重複使用，應研究並實測`SetToDefaults`是否能安全清除秘密面向。

## Aura API 變更重點

12.x對aura訪問有秘密限制。規劃筆記指出：
- 光環的獲取在限制狀態下會變成秘密。
- `GetUnitAuras` / `UNIT_AURA` 的向量容器可能不是秘密，但內容值可能是秘密。
- `AuraInstanceID` 不是秘密。
- 依spellID/name直接查單一aura的API，在aura存取秘密時可能不可呼叫。

EAM `AuraService` 實施規則：

- 優先使用`UNIT_AURA`增量資訊。
- 使用`auraInstanceID`作為安全識別錨點。
- 不假設spellID查找在戰鬥中一定可用。
- 才寫入 `AuraState.factsSafe = true`。
- 不强制时保留安全图标/name，计时器设为`protected` 或`unknown`。
- 脱战`PLAYER_REGEN_ENABLED`后做一次安全重扫，清掉残影与边界限制状态。

相關API：
```lua
C_UnitAuras.GetAuraDuration
C_UnitAuras.GetAuraBaseDuration
C_UnitAuras.DoesAuraHaveExpirationTime
C_UnitAuras.GetAuraApplicationDisplayCount
C_UnitAuras.GetUnitAuraInstanceIDs
C_TooltipInfo.GetUnitAuraByAuraInstanceID
```
### C_UnitAuras.GetAuraDataByAuraInstanceID

`C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)` 的 `auraInstanceID` 參數標記為 `NeverSecret`，但回傳的 `UnitAuraInfo` 可能是 `SecretWhenUnitAuraRestricted`。

EAM實施規則：

- `auraInstanceID` 可作為運行時錨點，但不可儲存至 SavedVariables。
- 四大核心安全檢查防禦：
  - `canaccesstable(table)`：必須在存取任何回傳表欄位前進行安全判定。
  - `canaccessvalue(value)`：在讀取欄位內容前進行存取許可判定。
- `issecretvalue(value)`：確認欄位（如 `spellId` 或 `duration`）是否已加密為機密值。
  - `issecrettable(table)` / `hasanysecretvalues(table)`：檢查表格結構本身是否已被限製或包含秘密。
- **表格索引防護規範（關鍵）**：
  - 嚴禁直接以可能為秘密值（如受限狀態下的 `spellId`）的鍵對任何自修改 Lua 表（如 `EAM.SavedVariables`、`EAM.db`）進行 `tbl[spellId]` 查詢表。
- 此操作將引發致命錯誤：「嘗試索引無法使用密鑰索引的表」。
  - 在查表前，必須以 `if not issecretvalue(key) and canaccesstable(tbl) then ... end` 的本地就地模式進行預防性檢查，拒絕使用金鑰。
- 可安全讀取的欄位才進`facts`；其餘只進`boundaryWarnings`。
- 光環配對不可只依賴不安全`spellID`；必要時用設定、事件、安全錨與顯示降級共同處理。

## 冷卻 API 變更重點
12.0 刪除或淘汰許多舊的全域法術 API。 EAM 不應再保留 Classic/ 舊版解壓縮返回層。

舊 global API 應改用 `C_Spell`：
```lua
GetSpellInfo       -> C_Spell.GetSpellInfo
GetSpellCooldown   -> C_Spell.GetSpellCooldown
GetSpellTexture    -> C_Spell.GetSpellTexture
GetSpellCharges    -> C_Spell.GetSpellCharges
IsUsableSpell      -> C_Spell.IsSpellUsable
```
12.0 相關`C_Spell` 重點：
```lua
C_Spell.GetSpellCooldownDuration
C_Spell.GetSpellChargeDuration
C_Spell.GetSpellDisplayCount
C_Spell.GetSpellMaxCumulativeAuraApplications
C_Spell.IsPriorityAura
C_Spell.IsSelfBuff
```
`SpellCooldownInfo` 在 12.x 中有新的欄位，例如：
```lua
timeUntilEndOfStartRecovery
isOnGCD
```
魔獸爭霸維基單頁指出 `C_Spell.GetSpellCooldown` 是補丁 11.0.0 加入取代舊 `GetSpellCooldown` 的 API；它可能回傳 nil，且在法術冷卻受限時可能回傳秘密。 `isOnGCD` 欄位為 `NeverSecret`，但檔案提醒除非正在回應 `SPELL_UPDATE_COOLDOWN`，否則不要信任此欄位。

EAM `CooldownService` 實施規則：

- 優先使用結構化的`C_Spell`返回。
- 不再依賴舊的 `start,uration,enabled = GetSpellCooldown(id)` unpack。
- 使用 `C_Secrets.ShouldSpellCooldownBeSecret(spellID)` 或保密 API 判斷。
- 冷卻時間不安全時，請勿自行猜測start/duration。
- GCD 判斷應使用安全欄位，例如`isOnGCD`，並以即時正式服驗證。
- `isOnGCD` 只在 `SPELL_UPDATE_COOLDOWN` 事件脈絡下作為可信的判斷候選。
- `C_Spell.GetSpellCharges`同樣可能受到冷卻限制影響；衝鋒欄位不可在未檢查直接前裝甲。
- 舊 `GetSpellCooldown` 頁面已明確標示 11.0.0 起移除/取代，新架構不得將其當核心回退。

## DurationObject 與 C_CurveUtil 系統
12.0.0 新增 `DurationObject`，12.0.1 加入 `DurationObject:GetClockTime`，在 12.0.7 則補強了邊框文字與曲線綁定。

### 🔑 DurationObject 核心內建方法與安全陷阱
- **`durationObj:IsZero()`**：
  - *用途*：檢測持續時間是否已為0（已過期）。
- *致命陷阱*：在戰鬥或受限（設定）狀態下，此方法會回傳 **`SecretBoolean`**。若在 Lua 中直接執行 `if durationObj:IsZero() then`，會立即引發致命崩潰：`attempt to Perform boolean test on a Secret value`！
  - *安全防禦*：必須使用 `issecretvalue(val)` 或 `pcall` 進行預防性保護，或完全取代 C++ 的 `clearIfZero` 參數（例如在 `SetCooldownFromDurationObject` 中設定）。
- **`durationObj:GetRemainingDuration()`**：
- *用途*：取得剩餘秒數。
  - *限制*：在限制（戰鬥限制）狀態下，會回傳被加密的**`SecretValue`**。直接對其進行Lua算術攻擊（如`+ - * / < > ==`）會直接致命觸發紅字錯誤。
- **`durationObj:GetClockTime()`**：
  - *用途*：用於初步的時脈同步，杜絕與 UI 產生的污染。但在戰鬥中這也是 `SecretValue`。
### 🎨 C_CurveUtil (曲線化工具) 戰鬥防污染機制
為了解決在戰鬥中無法直接解決「如果剩餘 < 5 那麼」的時間比以改變圖標顏色或引發（因為會觸發 `SecretValue` 比較崩潰）的問題，暴雪引入了 **`C_CurveUtil`**：
* **機制**：AddOn可使用`C_CurveUtil.CreateCurve()`建立非線性的顏色或輪廓曲線映射，例如定義「在剩餘時間小於20%時變紅（流行病判定）」。
* **綁定**：橢圓曲線與 `DurationObject` 一併綁定至 Status/Progress Bar 或 Cooldown 控制項（例如 `statusBar:SetColorCurve(curve, durationObject)`）。
* **優勢**：所有的數學比較與顏色轉換都發生在 C++ 語法層，**100% 避免了 Lua 完全恢復了的 Taint，且免去了每幀 OnUpdate 垃圾恢復壓力**！

### 12.0.7 FontString 與 Cooldown 顯示綁定

* **`C_DurationUtil.CreateDurationTextBinding()`**：
  - Factory 不接受 `DurationObject` 或 `FontString` 參數。先無參數建立 binding，再依序呼叫 `SetFontString()`、`SetDuration()`、`SetFormatter()`，最後使用 `SetEnabled(true)` 或 `Enable()`。
  - 倒數文字由原生端更新，不需要為每個圖示建立 Lua `OnUpdate`。
  - 公開契約不保證存在 `Unbind()`。釋放時應先 `Disable()` 或 `SetEnabled(false)`，再於能力存在時呼叫 `SetToDefaults()`；不得呼叫猜測的方法。
* **`C_DurationUtil.CreateDuration()`**：
  - Factory 不接受 start／duration 參數。只有已確認安全的普通數字，才可在建立後呼叫 `DurationObject:SetTimeFromStart(startTime, duration)`。
  - API 提供的 Secret `DurationObject` 只可原樣交給 Blizzard 支援的 widget／binding，不讀回、不比較、不序列化。
* **`Cooldown:SetCooldownFromDurationObject(durationObject [, clearIfZero])`**：
  - Cooldown swipe 專用的原生綁定；零區間可由 `clearIfZero = true` 交給原生端處理。

`DurationObject` 用來讓原生端處理可能為 Secret 的時間資料。它可由 `C_DurationUtil.CreateDuration()` 建立，也可能由光環、施法或冷卻 API 提供，並可傳給 `Cooldown:SetCooldownFromDurationObject()` 或其他明確接受 DurationObject 的 widget。
12.x規劃方向是刪除剩餘時間API，改用duration物件：
```lua
C_ActionBar.GetActionCooldownRemaining
C_ActionBar.GetActionCooldownRemainingPercent
C_Spell.GetSpellCooldownRemaining
C_Spell.GetSpellCooldownRemainingPercent
C_UnitAuras.GetAuraDurationRemaining
C_UnitAuras.GetAuraDurationRemainingPercent
```
由此 API 應避免成為新的架構依賴。

重要小工具API：
```lua
Cooldown:SetCooldownFromDurationObject(duration [, clearIfZero])
Cooldown:SetCooldownFromExpirationTime(expirationTime, duration [, modRate])
Cooldown:SetPaused(paused)
Cooldown:GetCountdownFontString()
```
EAM `Renderer` 实作规则：

- 若有安全性 `DurationObject`，優先排序 `Cooldown:SetCooldownFromDurationObject()`。
- 不在Lua熱路徑自己每幀計算剩餘秒數。
- 計時器文字若無法安全達到，就不要顯示假秒數。
- `IconRenderState.timer.mode` 若要明確標示：`numeric`、`displayOnly`、`protected`、`unknown`。
- 不把`DurationObject`序列化，不寫入SavedVariables，不放入除錯事實。
-按鈕顯示持續時間，渲染器僅負責將物件傳遞給支援的小部件；服務狀態只標記來源和模式。

## FontString 與文字秘密方面

12.0.1新增：
```lua
FontString:ClearText()
```
其用途是將文字設為​​空字符串，並刪除文字秘密方面。

EAM 渲染器建議：

- 清空可能接觸過密文的FontString時，優先實測`ClearText()`。
- 若`ClearText()`可用，清除timer/name/stack標籤時使用它。
- 不要用秘密派生字串做 `SetText` 後再回讀。
- `SetText` 必須做值門控，避免重複 UI 寫入與 GC。

## 工具提示 / C_TooltipInfo 持續時間解析

`C_TooltipInfo` 可以作為低頻回退，但不能是熱路徑。
在 12.x / Midnight 貿易中，應特化使用 **`C_TooltipInfo.GetUnitBuffByAuraInstanceID(unitToken, auraInstanceID [, filter])`** 與 **`GetUnitDebuffByAuraInstanceID(unitToken, auraInstanceID [, filter]**。這兩個 API 完美接橋了 `NeverSecret` 的`AuraInstanceID`，實現了資料與UI的資料驅動解耦合，提供極低的GC開銷且遠比舊式`SetUnitBuff`模擬渲染安全。

### 🚨關鍵避坑點1：嚴禁呼叫`TooltipUtil.SurfaceArgs`
在 Patch 10.1.0 之後，`C_TooltipInfo` 的資料返回 Lua 時就已經由淺水自動“Surfaced”，此 SharedXML 庫輔助函數已經被暴雪**徹底移除 (nil)**。
* 任何對 `TooltipUtil.SurfaceArgs` 的呼叫觸發直接觸發 `attempt to call field 'SurfaceArgs' (a nil value)` 都會導致 AddOn 崩潰。
* 12.x 開發應用程式直接存取 `TooltipDataLine.leftText`。

### 🚨 關鍵避坑點2：直接存取 `line.leftText` 的屬性讀取崩潰與自訂函數傳參雙重
> [!WARNING]
> **少年欸最頂尖的實戰發現（超關鍵）**：
> 1.試著將一個組成/標記 Secret Aspect 的 Table 包進自修改的 Lua 函數（例如 `GetSafeLeftText(line)`）中處理，**在「包裝表作為參數傳給自訂 Lua 函數」這一步，就會因為沙盒安全防禦直接丟出參數錯誤而崩潰！ **
> 2.因為這是設定的 Secret/Protected 物件是禁止交付給非受信任的自訂 Lua 函數的。
>
> 因此，**「包進自訂FUNCTION傳參」這條路在戰鬥中是絕對不可行的！ **

#### 🛡️ 100%絕對可行且安全的「本地內聯pcall閉匿名包」防禦方案：
為了在不呼叫自訂函數傳參的前提下，安全地讀取表屬性，我們必須使用系統內建、具有底層C++執行休眠權與錯誤捕獲權的**`pcall`**，在**同一個本地作用域（Scope）內進行本地內聯匿名閉包讀取**：
```lua
-- ====================================================================
-- 本地 Inline pcall 屬性盾範例 (在業務代碼中直接原地 inline 呼叫)
-- ====================================================================
local data = C_TooltipInfo.GetUnitBuffByAuraInstanceID("player", instanceID)

-- 1. 用 pcall 在本地安全讀取 lines 表，防止 data 被限制時直接讀屬性崩潰
local dataOk, lines
if data then
    dataOk, lines = pcall(function() return data.lines end)
end

if dataOk and lines then
    for i = 1, #lines do
        local line = lines[i]
        
        -- 2. 用 pcall 本地匿名閉包讀取 leftText，絕不將 line 作為參數傳出！
        local lineOk, text
        if line then
            lineOk, text = pcall(function() return line.leftText end)
        end
        
        -- 3. 確保讀取成功，且最終獲取的字串值不是 Secret Value，此時 text 100% 安全
        if lineOk and text and not issecretvalue(text) then
            -- 在此安全地進行任何 string.find 等 Lua 運算！
            if string.find(text, "恢復") then
                -- 處理邏輯
            end
        end
    end
end
```
EAM `AuraService` 與其他分析模組在存取任何可能受到限制的 C_TooltipInfo 傳回值時，**一律嚴格遵循此本地內聯 pcall 匿名閉包模式**，杜絕任何裸讀查表與自訂函數傳參。

`C_TooltipInfo.GetUnitAuraByAuraInstanceID` 在 12.0.0 加入，謂詞包含 `MayReturnNothing` 和 `SecretWhenInCombat`，且 `SecretArguments` 只允許未污染的使用。其過濾器在 12.0.1 新增 `CROWD_CONTROL`、`RAID_IN_COMBAT`、`RAID_PLAYER_DISPELLABLE`、`BIG_DEFENSIVE`、`IMPORTANT`。

可考慮解析：
- 靜態“持續 X 秒”描述。
- 靜態「恢復時間」描述。
- 靜態最大冷卻時間描述。

必須注意：

- 動態倒數字文字。
- 包含「尚有」的文字。
- 包含 `Remaining` 的文字。
- 任意`issecretvalue(text)`檢查行文字。

原因：

- 12.x中由秘密值產生的動態文字可能本身就是秘密使用者資料。
- 對秘密文字做 `string.match` 可能直接錯誤。
- Tooltip解析會產生字符串與表格解析成本，且不可放在`OnUpdate`。

EAM實施規則：

- 工具提示解析只能在事件觸發、快取未命中、設定變更、或低頻空閒回退時執行。
- 不可在 `Renderer` 執行。
- 不可在每個圖示計時器執行。
- 解析前先檢查文字安全性。
- 若工具提示API在戰鬥中回傳秘密或nil，直接降級，不重試熱迴圈。
- 新增過濾器只能縮小工具提示來源的提示，不可作為安全性保證。
- 黑名單關鍵字優先於模式匹配。
- 解析結果若不是原始事實 API，應標示為 `derived` 或 `fallback`，不可冒充原始事實。

## 物品冷卻與物品-法術映射

Warcraft Wiki 12.x 變更重點不支援 EAM 繼續做大範圍 itemID 掃描。

EAM `ItemCooldownService` 規則：

- 直接itemID冷卻監控優先。
- 物品-法術映射快取只能選擇加入。
- 快取建置必須只空閒、非戰鬥、FPS-aware、可中斷。
- 不可在戰鬥中掃除大規模物品。
- 不可將快取建構器放置登錄熱路徑。

## 事件與架構

12.x 不適合讓 EAM 繼續依賴戰鬥日誌盲掃。

建議活動：
```lua
PLAYER_LOGIN
PLAYER_ENTERING_WORLD
PLAYER_REGEN_ENABLED
PLAYER_REGEN_DISABLED
PLAYER_TARGET_CHANGED
UNIT_AURA
SPELL_UPDATE_COOLDOWN
SPELL_UPDATE_CHARGES
BAG_UPDATE_COOLDOWN
UNIT_SPELLCAST_SUCCEEDED
ADDON_RESTRICTION_STATE_CHANGED
```
實行規則：

- 使用單一的`EventRouter`框架。
- 事件框架可用`CreateFrame("Frame", nil, nil)`形成孤兒框架，降低UI污染風險。
- 不使用`RegisterAllEvents`。
- 不在事件處理程序內建立關閉。
- 事件只標記髒狀態，實際 UI 更改渲染器批次。

## SavedVariables 規則

12.x規劃/指出文件秘密不宜進入SavedVariables；秘密序列化可能被替換成nil。

EAM 規則：

- SavedVariables 只存使用者配置。
- 不存在aura運行時狀態。
- 不存在冷卻運轉時狀態。
- 不存在`DurationObject`。
- 不存在秘密值。
- 不存在偵錯快照中的不安全原始值。

## 偵錯匯出規則

除錯導出必須分層：
```js
{
  facts: {},
  derived: {},
  boundaryWarnings: [],
  humanNotes: [],
  environment: {}
}
```
規則：

- 只有安全事實才能進`facts`。
- 工具提示解析結果進 `derived` 或標記 `fallback`。
- 秘密/protected/unavailable 狀態進 `boundaryWarnings`。
- 不輸出巨大的日誌。
- 不自動導出。
- 不要把秘密值轉字符串。

## 直播正式服 12.x 必測事項

以下都不能只靠文件假設：

- `issecretvalue`、`canaccesstable`、`canaccessvalue` 實際名稱與行為。
- `C_Secrets.Should*` 系列是否在目標建置中全部存在。
- `C_Secrets.GetSpellAuraSecrecy`、`GetSpellCooldownSecrecy` 回傳 enum 內容。
- `C_UnitAuras.GetAuraDuration` 回傳的 `DurationObject` 行為。
- `Cooldown:SetCooldownFromDurationObject()` 是否可接秘密安全持續時間。
- `FontString:ClearText()` 是否能安全清 文字秘密方面。
- `Cooldown:SetCountdownFormatter()` 與 `SecondsFormatter` 是否能安全接收秘密持續時間。
- `Cooldown:SetCountdownMillisecondsThreshold()` 小數顯示在 zhTW/enUS 語言環境的實際效果。
- `C_Spell.GetSpellChargeDuration()` 在最大費用時是否回傳零跨度持續時間。
- 零跨距 `DurationObject` 的完全過去行為是否符合 EAM 冷卻完成判定。
- Cooldown-duration API 的 `ignoreGCD` 參數實際名稱、預設值與適用的 API 清單。
- `AuraData.isHelpful`、`isHarmful`、`isRaid`、`isNameplateOnly`、`isFromPlayerOrPlayerPet` 是否處於限制狀態下穩定非秘密。
- 遇到/M+/PvP開始時`auraInstanceID`是否如文件所述重新隨機。
- `table.freeze` 與 `table.isfrozen` 是否存在於目標客戶端，且對 SavedVariables/runtime 狀態的誤用是否會造成錯誤。
- `SPELL_UPDATE_COOLDOWN` 是否有spellID 或可縮小更新範圍。
- `SpellCooldownInfo.isOnGCD` 是否可靠。
- `C_TooltipInfo.GetUnitAuraByAuraInstanceID`對秘密光環的限制。
- 動態工具提示行是否可能是秘密使用者資料。
- 秘密限制強制CVars的名稱和可用性。
- 12.0.7 的 `C_DurationUtil.CreateDurationTextBinding`、`CreateManualClock` 與刪除 `GetCurrentTime` 對 EAM 計時器顯示層的實際影響。

## 對 EAM Rewrite 的結論

EAM 12.x 架構應用採用：

- 僅限正式服。
- 事件驅動優先。
- 單一調度程序。
- 每個圖示沒有計時器。
- 每個法術沒有計時器。
- 預設不掃描大件物品。
- 事實/derived/boundaryWarnings分離。
- DurationObject 優先於Lua秒數侵犯。
- 工具提示解析只作低頻後備。
- 渲染器不查API。
- SavedVariables 永遠不儲存執行時間/secret 狀態。

## 12.1.0 build 68914 實作核對（2026-07-26）

- `CustomAuraContainerTemplate`、`CustomAuraButtonTemplate`、`SetUnit`、`AddAuraSlot`、`AddAuraGroup`、`SetAuraGroupLayout` 已納入 feature detection。
- 排序型別來自 FrameXML 全域 `AuraContainerSortMethod`／`AuraContainerSortDirection`，不是 `Enum.UnitAuraSortRule`。
- 公開 API 沒有 Remove Slot/Group；EAM 使用成功後換代、停用舊容器。
- AuraButton 公開綁定使用 `SetIcon`、`SetDurationCooldown`、`SetDurationText`、`SetApplicationCount`、`SetSpellName`。
- `C_UnitAuras.AddAuraSound`／`RemoveAuraSound` 與三種 trigger 已實作 ID 生命週期；實際播放待 PTR。
- 固定證據版本與完整限制見 `Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`、`Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md`。


## 2026-08-08 PTR8／UnitPower 追加筆記

- PTR8 的 Pandemic 狀態必須用 `AuraButton:AddPandemicRegion`，不讀 Region 的 `Shown` Secret aspect，也不以 EAM OnUpdate 重造 Blizzard Pandemic window。
- Dispel 邊框必須用 `AddDispelTypeTexture(texture, options)`；`showAlways` 覆蓋其他條件，不能把 `stealable=true` 或舊 AuraBorder alias 當成替代品。
- 停用 AuraContainer 會清除所屬 AuraButton／ItemEnchantment 顯示資料，但不代表框架被銷毀。
- UnitPower 的公開生成文件未證實 `StatusBar:SetUnit`、`SetPowerTextFontString`、`SetOnUpdateMode`。已確認的 12.1 Secret sink 是 StatusBar `SetValue` 與 Texture `SetRadialProgressBarPercent` 的單向輸入。
- EAM 不在戰鬥中呼叫 `UnitPower`、`UnitPowerMax` 或 `UnitPowerPercent`；`ClassPowerService` 與能力探針在戰鬥中回報 `combatDeferred`，離戰後由事件恢復。

官方 PTR 12.1.0.69189 生成 API：

- [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [SimpleStatusBarAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua)

## 2026-08-13 PTR 69273 AuraSound 固定契約

固定證據為 Gethe `ptr` commit `6e348870ed8f93d95f0cd16d299b51dbce500296`（12.1.0.69273）：

- `C_UnitAuras.AddAuraSound(trigger, sound)` 回傳可為 nil 的 registration ID；`RemoveAuraSound(id)` 取消註冊。
- `Enum.UnitAuraSoundTrigger`：Added=0、ApplicationsIncreased=1、Removed=2。
- `UnitAuraSoundInfo` 必填 `unitToken`、`spellID`；可選 `soundFileName`、`soundFileID`、`outputChannel`。沒有 `soundKitID`、caster 或 auraFilter。
- Add／Remove 標示 restricted 且 SecretArguments 為 AllowedWhenUntainted；EAM 只從已正規化的普通 SavedVariables 建立參數，不把 AuraData 或 Secret value 傳入。
- registration ID 是 session runtime state，不是播放 handle；不得保存，也不能傳給 `StopSound`。
- 12.0.7 只有 private aura applied 舊 API，不足以實作一般 Aura 三 trigger，故採 capability 降級。

固定來源：

- [UnitAuraDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/6e348870ed8f93d95f0cd16d299b51dbce500296/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
- [UnitAuraConstantsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/6e348870ed8f93d95f0cd16d299b51dbce500296/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraConstantsDocumentation.lua)
- [UnitConstantsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/6e348870ed8f93d95f0cd16d299b51dbce500296/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitConstantsDocumentation.lua)

# EventAlertMod Retail 12.1
# Player Resource Module 最終重構規格

你現在要修改 **EventAlertMod / EventAlertModRemake** 的玩家職業資源系統。

本任務不是單純修復 `UnitPower()`，而是將玩家資源重新整理成一個：

> **獨立、可設定、多資源並存、Secret-aware、低 CPU / 低 GC 的 Player Resource Module。**

---

# 0. 基本執行原則

不要假設目前 Repository 是哪個：

- Alpha
- Beta
- Commit
- Branch
- Release
- 本機版本
- GitHub 版本

也不要假設一定存在：

```text
ClassPowerService
activePowerType
activePowerToken
UnitPowerCapabilityProbe
ResourceRenderer
StatusBarRenderer
IconPool
```

第一步必須：

> **先掃描目前 Repository，建立現行架構與 Data Flow，再決定修改方式。**

若目前程式已經完成部分需求：

1. 保留正確部分。
2. 找出缺口。
3. 修正 regression。
4. 避免重寫已存在且正確的能力。
5. 不為符合本文件名稱而進行無意義 rename 或 rewrite。
6. 優先 incremental refactor。

---

# 1. 修改前必須查證最新 WoW Retail 12.1 API

先查證最新：

- Blizzard generated API documentation
- Gethe/wow-ui-source
- Warcraft Wiki 12.1 API changes
- Secret Values 文件

至少確認：

```text
UnitPower
UnitPowerMax
UnitPowerPercent
UnitPowerType

C_Secrets.ShouldUnitPowerBeSecret
C_Secrets.ShouldUnitPowerMaxBeSecret
C_Secrets.GetPowerTypeSecrecy

UNIT_POWER_FREQUENT
UNIT_POWER_UPDATE
UNIT_MAXPOWER
UNIT_DISPLAYPOWER

FontString:SetText
FontString:SetFormattedText
FontString:ClearText

StatusBar:SetValue
StatusBar:SetMinMaxValues
```

不得依賴舊版 API 記憶直接修改。

---

# 2. 核心功能定位

EAM 的職業資源系統不是 Blizzard 原生 Player Power Bar 的複製品。

它的主要價值是：

> **持續監控該職業／專精所有具有戰術價值的資源，包括目前形態未正在使用的背景資源。**

例如 Druid 處於 Bear Form 時，使用者仍可能希望同時知道：

```text
Rage
Energy recovery
ComboPoints remaining
Mana
LunarPower
```

其目的可能是：

```text
現在處於熊型態
        ↓
準備切貓
        ↓
希望事先知道 Energy 已恢復多少
        ↓
希望知道 ComboPoints 是否仍保留
```

因此：

> `UnitPowerType("player")` 只能代表目前 foreground / displayed primary power。

禁止使用 `UnitPowerType()` 決定：

```text
其他 Resource 是否存在
其他 Resource 是否停止追蹤
其他 Resource 是否被 Hide
其他 Resource 是否被 Release
```

---

# 3. 建立獨立 Player Resource Module

玩家職業資源必須成為 EAM 的獨立功能模組。

概念：

```text
EAM
├─ Aura
├─ Cooldown
├─ Pandemic
├─ Group Alert
├─ ...
└─ Player Resource Module
```

獨立模組的主要目的有兩個：

## A. Business Logic 隔離

Secret Value、UnitPower、專精、形態與 Resource topology 不污染：

```text
Aura
Cooldown
Pandemic
General Alert
```

## B. 每個 Resource 可以獨立設定

像其他 EAM 模組一樣，玩家可以針對：

```text
Mana
Energy
Rage
Focus
ComboPoints
Runes
RunicPower
SoulShards
LunarPower
HolyPower
Maelstrom
Chi
Insanity
ArcaneCharges
Fury
Pain
Essence
...
```

分別調整：

```text
Enable
Display Mode
Position
Size
Scale
Alpha
Foreground Visibility
Background Visibility
Text
Percent
Bar
Point display
Glow
Threshold
Ordering
Spacing
```

---

# 4. 模組責任

Player Resource Module 應唯一負責：

```text
Player Class
Player Spec
PowerType
Power Token
Spec Resource Set
Runtime Resource Registry
Resource Capability
UnitPower
UnitPowerMax
UnitPowerPercent
UnitPowerType
Secret Value
Foreground / Background state
Resource events
Resource frames
Resource renderer
Resource config
Background sampling
```

其他 EAM 模組不得自行複製職業資源邏輯。

---

# 5. 建議責任分層

檔案名稱可以依現有架構調整，但責任應接近：

```text
PlayerResource/
│
├─ PlayerResourceModule
├─ ResourceCatalog
├─ SpecResourceMap
├─ CapabilityResolver
├─ RuntimeResourceRegistry
├─ ResourceEventRouter
├─ ResourceRenderer
├─ ResourceFramePool
├─ ResourceConfig
└─ ResourceProbe
```

不要為拆檔而拆檔。

目標是：

> **責任清楚、Hot Path 短、容易針對 Resource 擴充。**

---

# 6. 禁止單一 Active Power 模型

如果目前仍存在：

```lua
activePowerType
activePowerToken
```

它們不能再代表：

> 玩家目前唯一值得監控的資源。

因為玩家可以同時有多種 Resource。

例如：

```text
Rogue
├─ Energy
└─ ComboPoints
```

```text
Arcane Mage
├─ Mana
└─ ArcaneCharges
```

```text
Paladin
├─ Mana
└─ HolyPower
```

```text
Death Knight
├─ RunicPower
└─ Runes
```

而 Druid 可能同時需要：

```text
Mana
Rage
Energy
ComboPoints
LunarPower
```

因此核心模型必須是：

```text
1 Spec
→ N Resources
```

而不是：

```text
1 Spec
→ 1 Active Power
```

---

# 7. Resource 應視為獨立節點

不要把：

```text
Primary
Secondary
Alternate
```

作為核心資料結構限制。

這些可以是 metadata。

核心應該是：

> **Resource = 一個獨立可追蹤、可設定、可 render 的節點。**

概念：

```lua
resource = {
    definition = {},
    config = {},
    runtime = {},
}
```

---

# 8. Resource Definition / Config / Runtime 分離

## definition

靜態資訊：

```text
key
PowerType
Token
DisplayName
DefaultIcon
DefaultRenderer
ResourceRole
```

例如：

```lua
definition = {
    key = "ENERGY",
    powerType = Enum.PowerType.Energy,
    token = "ENERGY",
    defaultRenderer = "statusbar",
}
```

---

## config

SavedVariables / 玩家設定：

```text
enabled
displayMode
showForeground
showBackground
position
anchor
offsetX
offsetY
size
scale
alpha
backgroundAlpha
font
fontSize
showValue
showPercent
barWidth
barHeight
orientation
spacing
ordering
threshold
fullGlow
```

---

## runtime

只存在記憶體：

```text
tracked
available
foreground
capability
frame
update function
renderer strategy
```

禁止把 Secret raw value 放入 runtime cache。

---

# 9. ResourceCatalog

所有 Power Type 應集中定義。

概念：

```lua
ResourceCatalog = {
    ENERGY = {
        powerType = Enum.PowerType.Energy,
        token = "ENERGY",
        defaultRenderer = "statusbar",
    },

    COMBO_POINTS = {
        powerType = Enum.PowerType.ComboPoints,
        token = "COMBO_POINTS",
        defaultRenderer = "points",
    },
}
```

避免：

```text
Power ID
Token
Icon
名稱
Renderer
```

散落在大量 if / elseif。

---

# 10. SpecResourceMap

保留早期 EAM 的核心設計思想：

```text
Class
 ↓
Spec
 ↓
Resource Candidate Set
```

例如：

```text
ROGUE / Assassination
→ Energy
→ ComboPoints
```

但：

> SpecResourceMap 只是 Candidate Resource Topology。

不得視為唯一真相。

仍需 Runtime Validation。

---

# 11. 為什麼需要 Runtime Validation

避免以下情況破壞 hard-coded topology：

```text
天賦變化
英雄天賦
Blizzard PowerType 調整
特殊形態
車輛
特殊戰鬥狀態
未來專精重製
```

正確流程：

```text
SpecResourceMap
      ↓
Candidate Resources
      ↓
Runtime Validation
      ↓
Tracked Resources
```

---

# 12. Resource Runtime 狀態

至少區分：

```text
Tracked
Available
Foreground
Background
Unavailable
```

---

# 13. Tracked

表示：

> 此專精希望 EAM 長期監控這個 Resource。

例如 Druid：

```text
Mana
Rage
Energy
ComboPoints
LunarPower
```

可以同時是 tracked candidates。

---

# 14. Foreground

表示：

> 目前形態主要正在使用的 Resource。

可參考：

```lua
UnitPowerType("player")
```

但：

```text
foreground = false
```

絕對不代表：

```text
tracked = false
```

---

# 15. Background

表示：

> 目前不是主要 Power，但仍持續追蹤。

例如 Bear Form：

```text
Rage          Foreground
Energy        Background
ComboPoints   Background
Mana          Background
```

Cat Form：

```text
Energy        Foreground
ComboPoints   Foreground/Class Resource
Rage          Background
Mana          Background
```

切換形態時：

> 不得銷毀完整 Resource topology。

---

# 16. UNIT_DISPLAYPOWER

`UNIT_DISPLAYPOWER` 主要職責：

```text
更新 foreground Resource
```

例如：

```text
Bear
→ Rage foreground
```

```text
Cat
→ Energy foreground
```

禁止：

```text
UNIT_DISPLAYPOWER
 ↓
Destroy all resources
 ↓
Rebuild frames
```

---

# 17. Capability 模型

每一個 Resource 必須獨立 resolve capability。

至少：

```text
NUMERIC
SECRET_DISPLAY
UNAVAILABLE
```

---

# 18. NUMERIC Resource

表示 Lua 可以取得普通 number。

允許：

```text
comparison
threshold
Glow
zero detection
max detection
Lua arithmetic
numeric text
sorting
```

可能包括部分 NeverSecret Resource，例如：

```text
ComboPoints
Runes
SoulShards
HolyPower
Chi
ArcaneCharges
Essence
```

但禁止單靠 hard-code。

仍應依：

```text
C_Secrets
最新 API
runtime capability
```

判斷。

---

# 19. SECRET_DISPLAY Resource

可能包括：

```text
Mana
Energy
Rage
Focus
RunicPower
LunarPower
Maelstrom
Insanity
Fury
Pain
...
```

若目前 API 回傳 Secret Value：

允許：

```text
Secret Value
   ↓
Blizzard-approved UI sink
```

例如經文件確認可使用：

```lua
StatusBar:SetValue(secretValue)
```

或：

```lua
FontString:SetFormattedText(...)
```

---

# 20. Secret Value 禁止操作

禁止：

```lua
if power > 50 then
```

禁止：

```lua
power / maxPower
```

禁止：

```lua
math.floor(power)
```

禁止：

```lua
tostring(power)
```

禁止：

```lua
state.power = power
```

若 state 後續可能被 Lua 解讀。

禁止：

```lua
SavedVariables.power = power
```

禁止：

```lua
DebugLog(power)
```

---

# 21. Secret 不等於 Unavailable

禁止：

```text
Secret
 ↓
Hide Resource
```

正確：

```text
Secret
 ↓
SECRET_DISPLAY
 ↓
UI Sink
```

只有：

```text
Unavailable
```

才停止顯示。

---

# 22. Secret Data Flow 必須短

理想：

```text
UnitPower / UnitPowerPercent
           ↓
       Secret Value
           ↓
       Native UI
           ↓
       discard ref
```

不要：

```text
Secret
 ↓
General State
 ↓
Cache
 ↓
Shared Renderer
 ↓
UI
```

Player Resource Module 應成為 EAM 內部 Secret Power 的安全邊界。

---

# 23. Secret Text

先查最新 API。

若：

```text
FontString:SetText
FontString:SetFormattedText
```

允許 Secret argument：

優先直接：

```lua
fontString:SetFormattedText("%d", secretPower)
```

避免：

```lua
local text = string.format(...)
```

原因：

```text
減少 Lua allocation
減少 GC
縮短 Secret flow
```

如果 Runtime Probe 證明不安全：

退回 StatusBar / visual-only。

---

# 24. Secret Aspect Cleanup

若 FontString 接受過 Secret Text：

Frame release 時必須確認：

```lua
fontString:ClearText()
```

至少檢查：

```text
stackText
powerText
valueText
percentText
timerText
```

---

# 25. Secret Frame Pool

如果 StatusBar / FontString 曾持有 Secret Aspect：

優先：

```text
Resource Secret Frame
→ Resource Pool only
```

不要 release 後交給：

```text
Aura
Cooldown
General Alert
```

以避免 Secret Aspect lifecycle 污染其他模組。

---

# 26. 每個 Resource 都必須獨立設定

這是 Player Resource Module 的主要需求。

例如：

```text
Energy
├─ Enable
├─ Renderer
├─ Show Foreground
├─ Show Background
├─ Position
├─ Scale
├─ Alpha
├─ Background Alpha
├─ Text
└─ Percent
```

ComboPoints：

```text
ComboPoints
├─ Enable
├─ Points / Icon
├─ Show Foreground
├─ Show Background
├─ Size
├─ Spacing
├─ Value
├─ Full Glow
└─ Threshold
```

---

# 27. Global Default + Per-Resource Override

可以提供：

```text
Player Resource Global Settings
```

例如：

```text
Default Scale
Default Font
Default Alpha
Default Spacing
Default Anchor
```

但每個 Resource 必須可 Override。

概念：

```text
Global Default
      ↓
Resource Override
      ↓
Effective Runtime Config
```

---

# 28. 每個 Resource 可獨立 Enable / Disable

例如 Druid：

```text
Mana          OFF
Rage          ON
Energy        ON
ComboPoints   ON
LunarPower    OFF
```

Resource 是否存在與玩家是否要顯示是兩件事：

```text
resource exists
≠
resource enabled by user
```

---

# 29. Foreground / Background 也要獨立設定

例如：

```text
Energy
showForeground = true
showBackground = true
```

讓 Bear Form 仍看到 Energy recovery。

ComboPoints：

```text
showForeground = true
showBackground = true
```

熊型態仍顯示 Combo Points。

Mana：

```text
showForeground = true
showBackground = false
```

使用者可自行關閉背景法力。

---

# 30. Capability-aware Options UI

Options 必須知道：

```text
NUMERIC
SECRET_DISPLAY
UNAVAILABLE
```

NUMERIC 可以提供：

```text
Threshold
Full Resource Glow
Numeric Conditions
```

SECRET_DISPLAY 不得提供需要 Lua 比較 Secret Value 的設定。

例如：

```text
Energy >= 80 Glow
Rage >= 50 Alert
Insanity >= 90 Warning
```

如果 Blizzard 不允許：

```text
Disable
Hide
或顯示 Unsupported
```

不要提供假設定。

---

# 31. Resource Renderer 可以不同

例如：

```text
Energy
→ StatusBar

Rage
→ StatusBar

Mana
→ StatusBar

ComboPoints
→ Point Renderer

ArcaneCharges
→ Point Renderer

Runes
→ Rune Renderer
```

不要強迫所有 Power 共用單一視覺格式。

---

# 32. 每個 Resource 有自己的 Renderer Ownership

禁止單一：

```text
lastRenderedID
```

控制所有 Player Resource。

應使用：

```lua
framesByResource[resourceID]
```

或：

```lua
resource.frame
```

不得：

```text
Energy update
 ↓
hide ComboPoints
```

也不得：

```text
ComboPoints update
 ↓
release Energy bar
```

---

# 33. 已知 Regression 必須列為高優先 Acceptance Test

曾經出現：

```text
Energy / Rage / Insanity StatusBar 修復
             ↓
ComboPoints 消失
```

必須找出真正 root cause。

優先檢查：

```text
single activePower slot
UnitPowerType overriding class resource
activePowerToken filter
single renderer owner
hideRenderedState
primary selection early return
shared frame
```

不得直接猜測。

---

# 34. Power Event Router

Topology 建立後建立：

```lua
resourcesByToken = {
    ENERGY = energyResource,
    COMBO_POINTS = comboResource,
    MANA = manaResource,
}
```

Hot Path 目標：

```lua
if unit ~= "player" then
    return
end

local resource = resourcesByToken[powerToken]
if not resource then
    return
end

resource.update(resource)
```

目標複雜度：

```text
O(1)
```

---

# 35. 如果一個 Token 對應多個 consumer

才使用預建立 compact array：

```lua
resourcesByToken[token] = {
    resourceA,
    resourceB,
}
```

不要每個 event 動態建立 table。

---

# 36. Global Event Router 不應知道職業邏輯

Global Event Router 最多：

```text
UNIT_POWER_FREQUENT
        ↓
PlayerResourceModule:onPowerEvent(...)
```

禁止：

```text
EventRouter
 ↓
if Rogue
if Druid
if Energy
if Combo
```

職業與 Resource logic 留在 Player Resource Module。

---

# 37. Event Subscription 集中

不要一個 Resource 一個 Event Frame。

優先：

```text
1 PlayerResource Module Frame
           ↓
     token dispatch
```

降低：

```text
Frame Count
Callback Count
RegisterEvent Count
```

---

# 38. UNIT_MAXPOWER

用途：

```text
Max changed
Availability changed
Resource state changed
```

優先局部 invalidation。

不要每次完整 rebuild 所有 topology。

---

# 39. Capability Resolver 必須是 Cold Path

不要在每次：

```text
UNIT_POWER_FREQUENT
```

重新做：

```lua
C_Secrets.ShouldUnitPowerBeSecret(...)
```

應在：

```text
initialize
PLAYER_ENTERING_WORLD
PLAYER_SPECIALIZATION_CHANGED
PLAYER_TALENT_UPDATE
TRAIT_CONFIG_UPDATED
UNIT_DISPLAYPOWER
UNIT_MAXPOWER
relevant restriction change
```

解析並 cache。

---

# 40. Config 也應 Cold Path 編譯

不要每個 Power event：

```lua
if config.enabled then
    if config.displayMode == ...
```

應在：

```text
initialize
profile change
options change
spec change
topology rebuild
```

把 Config + Capability 編譯成：

```lua
resource.update = updateSecretStatusBar
```

或：

```lua
resource.update = updateNumericComboPoints
```

Hot Path 直接執行。

---

# 41. InCombatLockdown 不得全域阻斷 Power

如果目前：

```lua
if InCombatLockdown() then
    return
end
```

包住整個 Power subsystem：

重新評估。

戰鬥中仍應允許：

```text
UNIT_POWER_FREQUENT processing
NeverSecret numeric update
Secret StatusBar update
```

`InCombatLockdown()` 主要用於：

```text
CreateFrame
Frame Pool grow
Protected structure/layout operations
```

---

# 42. Frame Pool 必須 Prewarm

Player Resource Module 初始化時：

```text
prewarm expected frames
```

避免戰鬥中 CreateFrame。

Druid 是最大壓力案例，可依：

```text
最大同時 tracked resource 數
```

預熱合理 frame 數。

---

# 43. Background Resource Tracking

必須在 WoW 12.1 實機驗證：

例如 Bear Form：

```lua
UnitPower("player", Enum.PowerType.Energy)
```

是否持續變動。

以及：

```text
UNIT_POWER_FREQUENT
UNIT_POWER_UPDATE
```

是否仍對 background Energy 發事件。

---

# 44. 如果 Background Resource 有事件

保持：

```text
Event Driven
```

不要增加 ticker。

---

# 45. 如果 Background Resource 沒事件

才加入：

```text
Shared Background Sampler
```

禁止：

```text
1 resource = 1 OnUpdate
```

---

# 46. Background Sampler 必須共用

最多：

```text
one shared sampler
```

概念：

```text
backgroundResources
       ↓
shared ticker
       ↓
only update required resources
```

頻率由實測決定。

可能：

```text
0.25 ~ 0.75 sec
```

但不要硬編為規格。

---

# 47. Sampler Demand-driven

只有：

```text
有需要 Background Tracking
+
對應 Frame 正在顯示
+
Event 不足
```

才啟動。

沒有需求：

```text
Stop ticker
```

---

# 48. Hot Path 禁止 allocation

避免：

```text
new table
table.insert
closure
string.format
tostring
string concatenation
temporary array
pairs/ipairs over all resources
full resource scan
```

---

# 49. 不要在 Hot Path 使用大量 pcall

`pcall` 可以用於：

```text
Capability Probe
Compatibility Probe
Cold Path detection
```

完成 capability cache 後：

```text
UNIT_POWER_FREQUENT
→ direct API
```

除非特定 API 已確認可能 runtime throw。

---

# 50. Secret Resource 不得做 Lua dedup

對普通 Resource 可以：

```text
newValue == oldValue
→ skip Set*
```

但 Secret Value：

禁止：

```lua
oldSecret == newSecret
```

因此 Secret Resource：

```text
event arrives
→ direct UI update
```

或依原生 Widget 機制處理。

---

# 51. 不讀回 Secret UI State

如果：

```lua
statusBar:SetValue(secret)
```

不得之後：

```lua
statusBar:GetValue()
```

再做判斷。

同理：

```text
FontString:GetText
StatusBar width
pixel measurement
alpha
animation
```

不得作為 Secret side channel。

---

# 52. Classic / MoP 版本隔離

若 EAM 支援：

```text
Retail
MoP Classic
Classic
```

必須隔離：

```text
Retail Secret-aware Adapter
Classic Numeric Adapter
```

不要讓：

```text
C_Secrets
Secret Value guards
```

污染 Classic Hot Path。

---

# 53. ResourceCatalog 可以共用

例如：

```text
Energy
ComboPoints
Mana
```

定義可共用。

但 capability strategy 必須由 Client Adapter 決定。

---

# 54. Druid 是主要 Architecture Stress Test

至少測：

```text
Bear
Cat
Caster
Moonkin / Balance state
```

Candidate Resources 至少考慮：

```text
Mana
Rage
Energy
ComboPoints
LunarPower
```

實際 availability 由 Runtime 決定。

---

# 55. Druid Acceptance

Bear Form：

```text
Rage          Foreground
Energy        Tracked Background
ComboPoints   Tracked Background
Mana          Tracked Background
```

如果 API 可用。

Cat Form：

```text
Energy        Foreground
ComboPoints   Foreground/Class Resource
Rage          Background
Mana          Background
```

Form switch：

```text
Bear
→ Cat
→ Caster
→ Bear
```

不得：

```text
lose Resource
duplicate Resource
duplicate Frame
duplicate Event
grow Frame Pool indefinitely
stale renderer state
```

---

# 56. Rogue Acceptance

必須同時存在：

```text
Energy
ComboPoints
```

Energy Secret StatusBar 修復：

不得造成 ComboPoints 消失。

---

# 57. Arcane Mage Acceptance

```text
Mana
ArcaneCharges
```

同時存在。

---

# 58. Paladin Acceptance

```text
Mana
HolyPower
```

---

# 59. Warlock Acceptance

```text
Mana
SoulShards
```

---

# 60. Death Knight Acceptance

```text
RunicPower
Runes
```

---

# 61. Priest Acceptance

依目前 12.1 專精確認：

```text
Mana
Insanity
```

---

# 62. Warrior

驗證：

```text
Rage
```

Secret Display path。

---

# 63. Hunter

驗證：

```text
Focus
```

---

# 64. Demon Hunter

驗證目前專精的：

```text
Fury
Pain
```

及 12.1 實際 Resource topology。

---

# 65. Resource Options Acceptance

Druid 必須能個別設定：

```text
Rage
  Enable = true
  DisplayMode = StatusBar
  Foreground = true
  Background = false

Energy
  Enable = true
  DisplayMode = StatusBar
  Foreground = true
  Background = true

ComboPoints
  Enable = true
  DisplayMode = Points
  Foreground = true
  Background = true
  FullGlow = true

Mana
  Enable = false

LunarPower
  Enable = true
  Independent Position / Style
```

一個 Resource 設定變更：

> 不得改變其他 Resource。

---

# 66. Module Disable

Disable Player Resource Module：

```text
Unregister resource-specific events
Stop background sampler
Hide/release resource frames
Clear secret aspects
Clear runtime registry
```

不得影響：

```text
Aura
Cooldown
Pandemic
其他模組
```

---

# 67. Module Enable

Enable：

```text
Build topology
Resolve capability
Compile config
Acquire frames
Register events
Render resources
```

不應要求 `/reload`，除非 WoW API 明確限制。

---

# 68. Public Contract

其他模組只能取得安全 metadata。

例如：

```lua
PlayerResourceModule:IsTracked(powerType)
PlayerResourceModule:IsForeground(powerType)
PlayerResourceModule:GetCapability(powerType)
```

禁止：

```lua
GetCurrentEnergy()
```

如果可能暴露 Secret raw value。

---

# 69. SavedVariables

只保存：

```text
Player preferences
Layout
Visibility
Style
DisplayMode
```

不得保存：

```text
runtime Power
Secret Value
Capability temporary state
event state
```

---

# 70. 不要過度 OOP

模組化：

不等於：

```text
每個 Resource 一個 class
inheritance
factory
metatable hierarchy
```

如果：

```text
Catalog
+
Runtime table
+
Function strategy
```

已足夠：

優先簡單資料導向設計。

---

# 71. Runtime Registry

建議概念：

```lua
trackedResources = {}
resourcesByToken = {}
resourcesByPowerType = {}
```

Topology rebuild 屬於 Cold Path：

允許必要 table 操作。

Hot Path 不建立新 table。

---

# 72. Renderer 不與 Aura 共用 business state

可以共用：

```text
Shared layout helper
Shared textures
Shared font helper
Shared frame primitive
```

但不得共用：

```text
Aura lastRenderedID
Aura state ownership
Aura lifecycle
```

職業資源必須有自己的 renderer ownership。

---

# 73. Debug Probe

保留或建立：

```text
ResourceProbe
```

Probe 可以記錄：

```text
powerType
token
tracked
available
foreground
background
capability
predicate classification
StatusBar sink accepted/rejected
FontString sink accepted/rejected
event observed
```

---

# 74. Secret Debug

禁止輸出 actual Secret Value。

只能：

```text
safe-number
secret
unavailable
accepted
rejected
```

---

# 75. Runtime Probe 要驗證 Background Event

特別測：

```text
Druid Bear Form
Energy recovering
```

觀察：

```text
是否有 UNIT_POWER_FREQUENT ENERGY
是否有 UNIT_POWER_UPDATE ENERGY
```

同時測 ComboPoints。

---

# 76. Repository Audit

修改前搜尋：

```text
UnitPower
UnitPowerMax
UnitPowerPercent
UnitPowerType
UNIT_POWER
UNIT_DISPLAYPOWER
UNIT_MAXPOWER
C_Secrets
PowerType
ClassPower
Resource
InCombatLockdown
StatusBar
SetValue
SetText
SetFormattedText
lastRenderedID
FramePool
```

---

# 77. 建立現有 Data Flow

畫出：

```text
Event
 ↓
Service
 ↓
State
 ↓
Renderer
 ↓
Frame
```

並標出：

```text
Power selection
Capability
Token filtering
Frame ownership
Hide path
Combat defer
Config path
```

---

# 78. Root Cause Phase

先確認目前實際 regression 是否仍存在：

```text
Energy / Rage / Insanity StatusBar works
ComboPoints missing
```

如果存在：

先找 root cause。

不要先 rewrite。

---

# 79. Design Phase

修改前產生簡短設計：

```text
Current Architecture
Problems
Target Architecture
Migration Plan
Risk
```

---

# 80. Implementation Phase

優先：

```text
Extract
Isolate
Redirect
Validate
Remove obsolete path
```

避免一次 rewrite 整個 EAM。

---

# 81. 不可同時存在兩套正式 Resource Pipeline

Probe 可以共存。

但 Production 不可同時：

```text
Legacy ClassPower
+
New PlayerResource
```

處理相同 Power event。

避免：

```text
duplicate UnitPower call
duplicate render
race
show/hide oscillation
```

---

# 82. Dead Code Cleanup

完成後搜尋：

```text
legacy activePower
duplicate UnitPower
obsolete secret guard
obsolete combat defer
unused power tables
old renderer state
```

只刪真正 dead code。

---

# 83. Performance Review

修改後檢查：

```text
UNIT_POWER_FREQUENT CPU
calls/sec
temporary allocations
GC
frame count
ticker count
event registrations
```

---

# 84. GC Review

Hot Path 不應產生：

```text
temporary table
temporary string
closure
iterator
copied arrays
formatted strings
```

Secret direct UI sink 尤其避免 Lua intermediate object。

---

# 85. Frame Count Review

反覆：

```text
Bear
Cat
Caster
Bear
Cat
```

Frame count 必須穩定。

---

# 86. Event Review

Topology rebuild 後：

```text
Event registration count
```

不得持續增加。

---

# 87. Scheduler Review

Resource system 最多：

```text
one shared background sampler
```

不得：

```text
one ticker per resource
```

---

# 88. Tests

至少建立或更新：

```text
Topology Tests
Capability Tests
Event Routing Tests
Renderer Ownership Tests
Config Isolation Tests
Lifecycle Tests
Secret Tests
Numeric Tests
Regression Tests
```

---

# 89. Topology Test

驗證：

```text
1 Spec → N Resources
```

---

# 90. Event Routing Test

例如：

```text
UNIT_POWER_FREQUENT("player", "COMBO_POINTS")
```

只更新 ComboPoints。

---

# 91. Renderer Ownership Test

Energy update 不得：

```text
hide/release ComboPoints
```

---

# 92. Config Isolation Test

Disable Energy：

不得 Disable ComboPoints。

修改 Rage position：

不得移動 Mana。

---

# 93. Lifecycle Test

```text
Enable
Disable
Enable
Spec Switch
Form Switch
Profile Switch
```

不得：

```text
Duplicate Frames
Duplicate Events
Stale References
```

---

# 94. Secret Test

SECRET_DISPLAY Resource：

```text
UI sink works
```

但：

```text
No compare
No cache
No raw log
No SavedVariables
```

---

# 95. Numeric Test

NUMERIC Resource：

```text
comparison allowed
threshold allowed
full glow allowed
```

---

# 96. Runtime-only 驗證

所有離線無法確認：

標示：

```text
REQUIRES_WOW_12_1_RUNTIME
```

不得假裝已完成驗證。

---

# 97. 最終 Architecture

完成後應接近：

```text
                     PlayerResourceModule
                             │
          ┌──────────────────┼───────────────────┐
          │                  │                   │
   ResourceCatalog     SpecResourceMap    CapabilityResolver
          │                  │                   │
          └──────────────────┼───────────────────┘
                             ▼
                    RuntimeResourceRegistry
                             │
                   resourcesByToken[token]
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
       NUMERIC         SECRET_DISPLAY      UNAVAILABLE
          │                  │
   Lua + Renderer       Native UI Sink
```

Config：

```text
Global Defaults
      ↓
Per Resource Override
      ↓
Compiled Runtime Strategy
```

Event：

```text
UNIT_POWER_FREQUENT
      ↓
O(1) Token Lookup
      ↓
One Resource Update
```

---

# 98. 最終回報格式

完成後請提供：

## A. Current Architecture

修改前 Player Resource 如何運作。

## B. Root Cause

說明目前 regression 原因。

尤其：

```text
Primary Power 修復
→ Class Resource 消失
```

如果存在，明確指出真正原因。

## C. Independent Module

說明 Player Resource 如何獨立於：

```text
Aura
Cooldown
其他 Alert
```

## D. N-Resource Topology

說明：

```text
1 Spec
→ N Resources
```

如何實作。

## E. Per-Resource Configuration

說明每個 Resource：

```text
Enable
Display
Layout
Foreground
Background
Renderer
```

如何獨立設定。

## F. Capability

說明：

```text
NUMERIC
SECRET_DISPLAY
UNAVAILABLE
```

## G. Secret Handling

列出：

```text
Allowed
Forbidden
```

## H. Event Architecture

列：

```text
Cold Path
Hot Path
Background Sampling
```

## I. Renderer Ownership

說明如何避免不同 Resource 互相 Hide / Release。

## J. Performance

提供：

```text
CPU
GC
Frames
Events
Ticker
```

分析。

## K. Test Matrix

逐項標記：

```text
PASS
FAIL
UNTESTED
REQUIRES_WOW_12_1_RUNTIME
```

---

# 99. 核心 Acceptance Criteria

必須全部成立：

```text
PlayerResourceModule
│
├─ 獨立於 Aura/Cooldown business logic
├─ 1 Spec → N Resources
├─ 每 Resource 可獨立設定
├─ 每 Resource 可獨立 Enable / Disable
├─ 每 Resource 擁有自己的 Renderer ownership
├─ Foreground ≠ Tracked
├─ Background Resource 可以持續監控
├─ Secret ≠ Unavailable
├─ Secret Value → Blizzard approved UI sink
├─ NUMERIC Value → Lua + UI
├─ UnitPowerType 不決定完整 Resource topology
├─ UNIT_DISPLAYPOWER 只更新 foreground
├─ O(1) Power event dispatch
├─ Capability 在 Cold Path resolve
├─ Config 在 Cold Path compile
├─ 無每 Resource OnUpdate
├─ 最多一個 demand-driven Background Sampler
├─ 無 Secret raw cache
├─ 無跨 Resource hide/release
└─ Retail 12.1 與 Classic/MoP 正確隔離
```

---

# 100. 最終設計原則

整個重構必須遵守以下原則：

> **EventAlertMod 的玩家職業資源必須成為獨立 Player Resource Module。此模組提供共同的 Resource Engine，但 Mana、Energy、Rage、ComboPoints、ArcaneCharges 等每一個 Resource 都必須是獨立可設定、可啟用、可佈局、可選 Renderer、可設定 Foreground / Background 行為的功能單元。**

> **專精決定 EAM 應監控的 Resource Set；形態只決定哪些 Resource 目前位於 Foreground。Background Resource 仍可以持續追蹤，因此不得使用 UnitPowerType() 作為完整 Resource topology 的唯一依據。**

> **Player Resource 必須採用 N-Resource Model。任何一個 Resource 的啟用、更新、Renderer 或設定，都不得造成其他有效 Resource 被覆蓋、停止監控、Hide 或 Release。**

> **WoW Retail 12.1 下，每個 Resource 都必須獨立經 Capability Resolver 分類。NeverSecret / NUMERIC Resource 可以進行 Lua 數值邏輯；Secret Resource 只能直接流向 Blizzard 官方允許的 Secret-aware UI Sink。Secret 不等於 unavailable，也不得嘗試以 side channel 還原 Secret Value。**

> **Resource topology、專精判斷、Capability、Config compilation、Frame setup 都屬於 Cold Path；UNIT_POWER_FREQUENT 屬於 Hot Path，應維持接近 O(1) token lookup + single resource update，不得在高頻事件中重新掃描專精、所有 Power、Capability 或產生不必要 GC。**

> **德魯伊必須作為 Player Resource architecture 的主要壓力測試：熊型態仍可依使用者設定追蹤 Energy、ComboPoints、Mana 等背景資源；形態切換只改變 Foreground / Background 狀態，不能摧毀完整 Resource topology。**

> **任何對 Mana、Energy、Rage、Insanity 等 Secret Resource 的修復，都不得再造成 ComboPoints、ArcaneCharges、HolyPower、SoulShards、Runes 等其他並存 Resource 消失。**
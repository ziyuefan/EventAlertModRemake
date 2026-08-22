# EventAlertMod_Remake：WoW 12.1 PTR 8 API 深入稽核與 PTR 專用修正提示

## 0. 任務定位與目前環境

你目前仍在處理 `EventAlertMod_Remake` 的既有任務，並保有先前對 WoW 12.1 PTR 1～7、AuraContainer、AuraButton、Secret／Forbidden 安全模型與 EAM Native Aura Backend 的工作進度。

本提示屬於：

```text
PTR 8 增量校正
＋
相關 API 詳細文件與 FrameXML 深入稽核
＋
PTR 專用實作／驗證
```

不是重新開始專案，也不是要求目前正式服立即使用 12.1 Native Aura。

### 目前版本前提

```text
目前正式服：WoW 12.0.7
目前測試環境：WoW 12.1 PTR
預定正式服切換窗口：2026-08-13（台灣時間）
```

在正式服實際更新到 12.1 前：

```text
12.1 Native AuraContainer 路徑
→ 只允許在 PTR 啟用與驗證

正式服 12.0.7
→ 維持既有 12.0.7／Legacy Backend
```

**不得只依日期自動解除版本閘門。**

2026-08-13 或之後，仍必須先由實際客戶端資訊確認：

```lua
local version, build, buildDate, interfaceVersion = GetBuildInfo()
```

只有在正式服實際符合下列條件後，才可評估啟用正式服 12.1 Native Backend：

```text
interfaceVersion >= 120100
且
必要的 AuraContainer／AuraButton API 實際存在
且
正式服實機 smoke test 通過
```

如果日期已到，但正式服仍回報 12.0.7／`120007`：

```text
不得啟用 12.1 Native Backend
不得以日期覆蓋 runtime version gate
```

---

# 1. 工作原則

請遵守：

- 保留目前工作樹、未提交修改、既有架構與測試成果。
- 先辨識哪些問題已經處理，不要重複重構。
- 不得撤銷與 PTR 8 無關的正確修改。
- 只做有 PTR 公告、Generated API Documentation 或 FrameXML 證據支持的修改。
- 無法由 Mock 證明的行為，必須標記為 PTR 實機待驗證。
- 正式服 12.0.7 不得被 PTR-only API probe 污染。
- 優先採取最小、可驗證、可回退的變更。
- Classic／Legacy Backend 必須與 Retail 12.1 Native Backend 解耦。
- 不得把 PTR 通過描述成正式服通過。

專案：

```text
https://github.com/ziyuefan/EventAlertMod_Remake
```

權威來源：

```text
https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes
https://github.com/Gethe/wow-ui-source
```

曾檢查的 PTR UI Source 基準：

```text
12.1.0.69111
```

執行時仍須重新檢查：

```text
Gethe/wow-ui-source ptr/version.txt
```

並記錄：

```text
WoW build
Interface version
wow-ui-source commit SHA
稽核日期
涉及的 FrameXML 路徑
涉及的 Generated Documentation 路徑
PTR 實機測試日期
```

---

# 2. 不可只讀 Patch Notes 摘要

本次稽核必須建立三層證據鏈：

```text
PTR 1～8 公告演進
→ Generated API Documentation
→ Blizzard FrameXML 實際實作
```

每個與 EAM 有關的條目都必須確認：

1. PTR 公告使用的描述名稱。
2. 最新公開方法名稱。
3. 方法簽名與參數型別。
4. options table 的實際欄位名稱。
5. Enum 的正式名稱與值域。
6. Nilable／Default 行為。
7. SecretArguments、Predicate 或 Access Constraint。
8. 實際呼叫順序。
9. Dirty flag 與更新階段。
10. Region／Frame 的所有權與生命週期。
11. 是否會建立或啟用 OnUpdate。
12. 是否屬於引擎行為／Bug Fix，而不是可探測 API。
13. EAM 應修改程式、文件、測試，或只列入 PTR 驗證。

不得只根據 Wiki 條目的自然語言名稱直接生成 Lua 程式碼。

例如 PTR 8 公告中的「stealable option」目前實際落成：

```lua
stealableFilter =
    Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable
```

不是：

```lua
stealable = true
```

---

# 3. 開始前先盤點既有進度

優先檢查：

```text
Services/AuraCapabilityService.lua
Services/AuraContainerService.lua
Services/AuraSoundService.lua
Managers/AuraRuleCompiler.lua
UI/NativeAuraRenderer.lua
Tests/Mocks/WoW121AuraMock.lua
Tests/FlowValidationHarness.lua
Docs/02_RETAIL_API_BOUNDARIES.md
Docs/09_KNOWN_LIMITATIONS.md
Docs/19_AURA_1210_REDUX_BLUEPRINT.md
Docs/23_AURA_CONTAINER_IMPLEMENTATION.md
CHANGELOG.md
```

開始修改前先輸出：

```text
已由既有工作完整處理
已部分處理
PTR 8 新增需求
既有判斷需要校正
目前不影響 EAM
只需 PTR 實機驗證
正式服 12.0.7 必須保持不變
```

同時檢查：

```text
git status
最近與 AuraContainer 有關的 commits
尚未提交的修改
目前測試狀態
文件是否落後於程式碼
```

---

# 4. 建立硬性版本閘門

## 4.1 Backend 選擇不得只看 API 存在

Backend 選擇至少要同時考慮：

```text
產品分支
Interface version
必要 API 契約
PTR／正式服環境
```

建議概念：

```lua
local _, _, _, interfaceVersion = GetBuildInfo()

local isRetail121OrLater =
    WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
    and type(interfaceVersion) == "number"
    and interfaceVersion >= 120100

local hasRequiredNativeAuraContract =
    -- 只檢查必要契約，不把可選視覺 API 當必要條件
    false
```

### PTR 階段

```text
Retail PTR 12.1
＋ interfaceVersion >= 120100
＋必要契約存在
→ 允許 Native Aura Backend
```

### 正式服 12.0.7

```text
interfaceVersion == 120007
→ 強制 Legacy／12.0.7 Backend
→ 不建立 CustomAuraContainer
→ 不執行 PTR-only destructive probe
```

### 正式服切換後

```text
正式服 interfaceVersion >= 120100
＋必要契約存在
＋正式服 smoke test 通過
→ 才正式啟用 Native Aura Backend
```

## 4.2 日期只能作為發布作業提示

```text
2026-08-13
```

只能作為：

```text
重新檢查正式服 build
執行 release smoke test
評估解除 PTR-only gate
```

不能作為：

```text
直接啟用 12.1 Native Backend 的唯一條件
```

---

# 5. PTR 8 累積變更

更新演進矩陣：

```text
12.0.7
→ PTR 1
→ PTR 2
→ PTR 3
→ PTR 4
→ PTR 5
→ PTR 6
→ PTR 7
→ PTR 8
```

PTR 8 AddOn-facing 變更：

1. AuraButton 新增 Pandemic 狀態 Region API。
2. Dispel／Border 顯示 options 新增 `showAlways` 與 stealable 過濾能力。
3. AuraButton Tooltip 改為每 200 ms 節流更新。
4. AuraContainer 停用時會清除其 AuraButton 與 ItemEnchantment assignment。
5. `UnitIsPossessed`、`UnitIsCharmed` 對 `player`、`pet`、`vehicle` 不再回傳 Secret。
6. 修正 AddOn 無法使用 SVG／VectorGraphics。
7. 修正 AuraButton Duration Text 偶爾顯示 0。
8. 修正 `PingableUnitFrameTemplate` Ping 敵對單位時的 Lua Error。
9. 封堵透過 `OnSizeChanged` 追蹤 AuraContainer Aura 數量的漏洞。

不得只寫 PTR 8 最終狀態，仍須保留 PTR 1～8 的變化脈絡。

---

# 6. Pandemic API：使用實際名稱與生命週期

## 6.1 已確認的 API

最新 `Blizzard_CustomAuraButton.lua` 使用：

```lua
auraButton:AddPandemicRegion(region)
auraButton:RemovePandemicRegion(index)
auraButton:ClearPandemicRegions()
```

注意：

- 參數型別是 `Region`，不限於 Texture。
- `AddPandemicRegion` 回傳索引。
- Region 必須通過 inbound script object 驗證。
- Region 必須是 AuraButton descendant。
- 綁定後 Region 取得：

```lua
Enum.SecretAspect.Shown
```

- AddOn 不得讀取其 Shown 狀態反推 Aura。
- 綁定後不得 reparent。

## 6.2 Blizzard 內部計算

FrameXML 會使用：

```lua
C_UnitAuras.GetRefreshExtendedDuration(unitToken, auraInstanceID)
C_UnitAuras.GetAuraBaseDuration(unitToken, auraInstanceID)
```

推算 Pandemic Window，再由 Blizzard 私有邏輯控制 Region。

EAM 不得自行：

```text
讀取 AuraData
讀取 expirationTime
讀取 duration
假定固定 30%
建立 Pandemic Ticker
建立 Pandemic Scheduler 任務
使用 UNIT_AURA Secret payload
透過 Region Show／Hide 建立 AuraState
```

## 6.3 OnUpdate 成本

`CustomAuraButtonPrivateMixin` 只有在以下條件同時成立時才啟用自身 OnUpdate：

```text
至少配置一個 Pandemic Region
且
當前 Aura 存在有效 Pandemic Window
```

因此不要替所有 AuraButton 無條件加入 Pandemic Region。

建議：

```text
規則明確啟用 Pandemic
→ 才在 initializeFrame 綁定

規則未啟用
→ 不建立、不綁定 Pandemic Region
```

優先限制於：

```text
重要 Slot
少量高優先 Group
使用者明確啟用的規則
```

避免大量 AuraButton 同時進入 Blizzard 私有 OnUpdate。

## 6.4 Capability 命名

不要使用：

```lua
hasPandemicTexture
```

改為：

```lua
hasPandemicRegionAPI
```

探測契約：

```lua
type(auraButton.AddPandemicRegion) == "function"
and type(auraButton.RemovePandemicRegion) == "function"
and type(auraButton.ClearPandemicRegions) == "function"
```

探測應在允許的 `initializeFrame` 階段進行並快取，不得為探測反覆建立 Container。

---

# 7. Dispel Texture／Border：使用最新 API

## 7.1 最新方法

優先使用：

```lua
auraButton:AddDispelTypeTexture(texture, options)
auraButton:RemoveDispelTypeTexture(index)
auraButton:ClearDispelTypeTextures()
auraButton:GetDispelTypeTextureCount()
auraButton:GetDispelTypeTexture(index)
```

舊 PTR 名稱：

```lua
GetAuraBorder
SetAuraBorder
ClearAuraBorder
```

目前只是 Deprecated alias，預計於 12.1 之後移除。

新程式碼不得依賴 AuraBorder alias。

## 7.2 Options 實際結構

目前 `CustomAuraButtonDispelTypeTextureOptions` 至少包含：

```lua
{
    showAlways = false,
    showWhenHarmful = true,
    showWhenHelpful = false,
    showWithoutDispelType = false,

    stealableFilter =
        Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable,
        -- 或 NotStealable

    style =
        Enum.CustomAuraButtonDispelTypeTextureStyle.BorderWithIcon,

    customDispelAssetMap = nil,
    customDispelColorMap = nil,
    customDispelColorCurve = nil,
}
```

Enum：

```lua
Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable
Enum.CustomAuraButtonDispelTypeStealableFilter.NotStealable
```

Style：

```lua
Enum.CustomAuraButtonDispelTypeTextureStyle.Border
Enum.CustomAuraButtonDispelTypeTextureStyle.BorderWithIcon
Enum.CustomAuraButtonDispelTypeTextureStyle.Icon
Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset
```

## 7.3 `showAlways` 優先權

目前 FrameXML 判斷順序：

```text
無 Aura
→ 不顯示

showAlways == true
→ 立即顯示，略過其他條件

否則
→ harmful／helpful
→ 有無 dispel type
→ stealableFilter
```

因此 `showAlways = true` 會蓋過：

```text
showWhenHarmful
showWhenHelpful
showWithoutDispelType
stealableFilter
```

EAM 設定編譯器不得把這些欄位理解成可任意 AND 疊加的獨立條件。

## 7.4 建議設定模式

可將 EAM 視覺設定編譯為：

```text
Always
HarmfulDispel
HelpfulDispel
StealableOnly
NotStealableOnly
AnyDispel
NoDispelType
CustomAsset
PreserveAssetColorized
```

若 `showAlways = true`，不要輸出沒有作用的 `stealableFilter`。

---

# 8. Capability 分類必須修正

不要把 PTR 8 所有變更都寫成 `hasXXX`。

## 8.1 可呼叫 API Capability

```lua
hasPandemicRegionAPI
hasMultipleDispelTypeTextures
hasDispelTypeTextAPI
hasApplicationBarAPI
hasDurationBarAPI
hasTooltipAnchorAPI
hasHideTooltipInCombatAPI
hasAuraGroupFilterSetter
hasAuraGroupCandidateFilterSetter
hasAuraGroupSortSetter
hasAuraGroupLayoutSetter
hasColumnLayout
```

## 8.2 Options／Enum Schema Capability

```lua
hasDispelShowAlways
hasDispelStealableFilter
hasDispelTextureStyle
hasCustomDispelAssetMap
hasCustomDispelColorMap
hasCustomDispelColorCurve
```

優先依：

```text
Interface version
WoW build
Enum 是否存在
Generated Documentation
受控 options probe
```

判斷。

不要在戰鬥中或 AuraButton 已禁止重新配置時做破壞性 probe。

## 8.3 Build Behavior／Engine Fix

以下不是 callable capability：

```text
Tooltip 每 200 ms 節流
Duration Text 0 Bug 修正
SetEnabled(false) 清除 Aura assignment
SVG Bug 修正
PingableUnitFrameTemplate Bug 修正
OnSizeChanged exploit fix
```

不要建立：

```lua
hasTooltipThrottle200ms
hasContainerDisableClear
hasDurationZeroFix
```

改放入：

```text
buildBehavior
engineFixMatrix
knownPTRBehavior
PTRVerificationChecklist
```

## 8.4 Security Contract

以下不是功能開關，而是必須遵守的契約：

```text
SecretAspect
ForbiddenAspect
Inbound descendant requirement
ChangeParent 禁止
AuraButton reparent 禁止
Child Region reparent 禁止
UntrustedScriptExecution
UntrustedLayoutScriptExecution
EventRegistrations
OnSizeChanged 防洩漏
initializeFrame 配置時機
PLAYER_LOGIN 前後限制
```

---

# 9. Tooltip 200 ms 節流

AuraButton Tooltip 仍有 OnUpdate，但會先經過：

```lua
GameTooltip_IsUpdateNeeded(self, elapsedTime)
```

PTR 8 更新門檻為每 200 ms，最高約 5 次／秒。

此行為：

```text
由 Blizzard Tooltip Mixin 管理
不是 EAM Scheduler
不是 runtime Aura capability
不需要 EAM 模擬
```

搜尋 EAM 是否存在：

```text
Aura Tooltip 自製 OnUpdate
每幀刷新 Tooltip
Hook AuraButton UpdateTooltip
滑鼠停留時重掃 AuraData
重複 PopulateTooltip
額外 C_Timer Tooltip ticker
```

Native Aura 路徑應優先交給 Blizzard Tooltip。

現有：

```lua
auraButton:SetHideTooltipInCombat(true)
```

若 API 存在且 PTR 實機正常，可保留。

---

# 10. AuraContainer 停用的實際呼叫鏈

## 10.1 Shared Mixin

```lua
container:SetEnabled(false)
```

觸發：

```text
UpdateEventRegistrations()
UpdateAllAuras()
```

停用或隱藏後，動態事件會解除：

```text
UNIT_AURA
Private Aura callback
WEAPON_ENCHANT_CHANGED
WEAPON_SLOT_CHANGED
```

## 10.2 ManagedAuraContainer

`UpdateAllAuras()` 會：

```text
MarkDirty(FullAuraRebuild)
```

停用時：

```text
ClearActiveItemEnchantments()
```

Parse 階段先：

```text
清 Aura cache
清 AuraGroup candidates
清 AuraSlot candidates
```

然後因 disabled 返回，不再解析新 Aura。

後續 dirty pipeline 完成 AuraButton assignment 清除與顯示刷新。

## 10.3 正確結論

PTR 8 後不得再聲稱：

```text
停用 Container 仍保留舊 Aura assignment
```

但必須保留：

```text
Aura assignment 被清除
≠
Frame／Region／FrameProvider 被銷毀
```

以下物件仍可能存在：

```text
AuraContainer
AuraButton
Texture
FontString
Cooldown
StatusBar
DurationTextBinding
FrameProvider
initializeFrame closure
Group 預配置批次
```

---

# 11. Container 重建與 GC／Frame 累積

PTR 8 改善停用清理，但 WoW Frame 不會因此由 Lua GC 銷毀。

優先使用原地更新：

```text
Sound-only
→ 只更新 AuraSoundService

位置變更
→ 移動既有 Container

FilterString
→ SetAuraGroupFilterString

CandidateFilters
→ SetAuraGroupCandidateFilters

Sort
→ SetAuraGroupSortMethod

MaxFrameCount
→ SetAuraGroupMaxFrameCount

Layout
→ SetAuraGroupLayout／FlowLayout setters

只有無法由公開 API 修改的結構變更
→ 才建立新 Container 世代
```

壓力測試：

```text
連續變更設定 100 次
Sound-only 100 次
Layout-only 100 次
Style-only 100 次
Enable／Disable 100 次
```

統計：

```text
containerCreateCount
containerRetireCount
auraButtonInitializeCount
regionCreateCount
activeOnUpdateCount
soundRegistrationCount
eventRegistrationCount
```

目標：

```text
Sound-only：0 個新 Container
Layout-only：0 個新 Container
位置變更：0 個新 Container
Enable／Disable：0 個新 Container
```

---

# 12. Duration Text 0 Bug

PTR 8 修正 AuraButton Duration Text 偶爾顯示 0。

最新 FrameXML 使用穩定的：

```lua
C_DurationUtil.CreateDurationTextBinding()
```

並在更新時：

```text
SetDuration(auraDuration)
SetEnabled(not auraDuration:IsZero())
```

搜尋舊 workaround：

```text
每幀倒數 OnUpdate
0 秒時重建 Container
反覆 SetDurationText
自行讀 expirationTime
延遲 timer 重綁
C_Timer workaround
額外 duration cache
```

若只為舊 Bug：

```text
PTR 8 Native 路徑移除
或
依舊 Build 隔離
```

正式服 12.0.7 Legacy 路徑不得因 PTR 8 稽核被誤刪必要邏輯。

---

# 13. OnSizeChanged exploit 封堵

全面搜尋：

```text
OnSizeChanged
ResizeToBoundsRect
GetSize
GetWidth
GetHeight
GetRect
GetBoundsRect
SetSize hook
SetPoint hook
anchored frame movement
children bounds
layout size polling
```

確認這些資訊未被用於：

```text
判斷 Aura 出現
判斷 Aura 消失
計算 Aura 數量
觸發提示
觸發音效
建立 AuraState
更新 SavedVariables
回流 AlertManager
```

禁止：

```text
AuraContainer 尺寸
→ OnSizeChanged
→ 推導 Aura 數量

AuraContainer 排版
→ 錨定 Frame 位移
→ EAM OnUpdate 比對位置
→ 推導 Aura 狀態

AuraButton children bounds
→ ResizeToBoundsRect
→ 推導顯示數
```

FlowLayout 輸出只能作為視覺結果，不得成為 EAM 邏輯輸入。

---

# 14. SVG／VectorGraphics

PTR 8 修正 AddOn 無法使用新的 SVG 技術。

此功能不是 Native Aura Backend 必要條件。

暫時不要全面遷移，先建立獨立 PTR 實驗，評估：

```text
建立成本
記憶體
縮放品質
UI Scale
旋轉支援
Mask 支援
TexCoord 支援
Forbidden／Secret 相容性
AuraButton descendant 限制
```

SVG／VectorGraphics 失敗只能停用對應視覺，不得使 Native Aura Backend 降級。

正式服 12.0.7 不得載入 PTR-only SVG 實驗模組。

---

# 15. UnitIsPossessed／UnitIsCharmed

PTR 8 後：

```lua
UnitIsPossessed("player")
UnitIsPossessed("pet")
UnitIsPossessed("vehicle")

UnitIsCharmed("player")
UnitIsCharmed("pet")
UnitIsCharmed("vehicle")
```

不再因這些 token 回傳 Secret。

僅限以上 token。

其他 unit token：

```text
不可假設解除 Secret
不可用 compound token 擴張
不可影響 Aura Backend 選擇
```

EAM 未使用時標記：

```text
No Direct Impact
```

---

# 16. PingableUnitFrameTemplate

搜尋：

```text
PingableUnitFrameTemplate
```

未使用：

```text
No Impact
```

有使用：

- 移除只針對舊 PTR 敵對 Ping Error 的 workaround。
- 保留 Build 隔離。
- PTR 測試 friendly／hostile／player／target。
- 不得混入 AuraContainer 核心。

---

# 17. NativeAuraRenderer 設計要求

`UI/NativeAuraRenderer.lua` 必須維持：

```text
只在 initializeFrame 建立 Region
只設定靜態材質、字型、尺寸與錨點
使用 AuraButton 原生 display binding
不讀 AuraData
不註冊 UNIT_AURA
不建立 EAM Aura OnUpdate
不使用 OnShow／OnHide 推導狀態
不讀 Region Shown secret
不 reparent 綁定後的 children
不將 Native Aura 回流 Legacy AlertManager 熱路徑
```

可選 PTR 8 擴充：

```text
Pandemic Region
Multiple Dispel Type Textures
Stealable Filter
ShowAlways
Custom Dispel Asset Map
Custom Dispel Color Map
Custom Dispel Color Curve
```

每個可選功能：

```text
獨立安全降級
不使整個 Native Backend 失效
不因功能缺失建立新 Container
```

---

# 18. Style 編譯與 FrameProvider 分組

EAM 可能將：

```lua
showStacks
showName
showCountdown
showPandemic
showDispel
```

放在個別 rule style。

但 `initializeFrame` 是 FrameProvider 建立 AuraButton 時呼叫，未必具有每次 Aura assignment 的 rule context。

請確認：

```text
不同 style signature 是否共用同一 AuraGroup
initializeFrame closure 是否安全承載 style
是否需要依 style signature 分組
是否需要不同額外 XML Template
```

建議 style signature：

```text
unit
filterString
candidateFilters
sort
showStacks
showName
showCountdown
showPandemic
dispelMode
tooltipMode
buttonSize
```

相同 signature 才共用 FrameProvider／AuraGroup。

不要為每條 Spell ID 規則無條件建立獨立 Container。

---

# 19. 保留先前 P0 問題

PTR 8 不會自動解決以下既有風險，請保留稽核：

## 19.1 Identity Candidate Filter 退化

檢查：

```text
player + HARMFUL
assistable unit + HARMFUL
hostile target + HELPFUL
```

當 identity candidate filter 不允許時，Blizzard 可能略過 `includeSpellIDs`，而不是拒絕整條 candidate。

不得只標記：

```text
secretIdentityFilterMayBeRejected
```

應判斷是否可能：

```text
identityFilterIgnored
possibleUnrelatedAuraDisplay
unsupportedSecretAuraIdentity
```

## 19.2 重複 Template

確認 FrameProvider 是否已自動加入：

```text
CustomAuraButtonTemplate
```

若已自動加入，EAM 不得在 `templateNames` 重複指定。

## 19.3 重複 Layout Dirty

若 `AddAuraGroup(options.layout)` 已設定 layout，不要立刻再呼叫相同的 `SetAuraGroupLayout`。

## 19.4 固定 SetSize

避免固定十欄兩列與 Container auto FlowLayout 衝突。

---

# 20. PTR 專用測試矩陣

## 20.1 正式服 12.0.7 回歸

正式服目前只測：

```text
Legacy Backend 正常載入
12.1 模組不載入或安全短路
不建立 CustomAuraContainer
不呼叫 PTR-only API
不產生 Lua Error
Classic／Legacy 功能不退化
SavedVariables 相容
```

不得在正式服 12.0.7 執行 12.1 Native Aura 功能驗證。

## 20.2 PTR 12.1 靜態檢查

搜尋：

```text
OnSizeChanged
SetScript("OnUpdate"
SetScript("OnShow"
SetScript("OnHide"
hooksecurefunc
GetWidth
GetHeight
GetSize
GetRect
expirationTime
UNIT_AURA
GetAuraDataBy
CustomAuraButtonTemplate
SetParent
SetAuraBorder
GetAuraBorder
ClearAuraBorder
```

## 20.3 PTR 12.1 Mock／流程測試

```text
Backend version gate
12.0.7 強制 Legacy
12.1 PTR 選擇 Native
必要 API 缺失時安全降級
可選 PTR 8 API 缺失不影響 Native 核心
SetEnabled(false) 清除 AuraButton
SetEnabled(false) 清除 ItemEnchantment
SetEnabled(false) 不等於 Frame 銷毀
Sound-only 不重建 Container
Layout-only 不重建 Container
Enable／Disable 不重建 Container
Pandemic API 缺失安全降級
Dispel options 缺失安全降級
showAlways 優先權
Stealable／NotStealable Enum
Tooltip 無 EAM 每幀更新
Duration Text 0 不觸發 workaround
OnSizeChanged 不參與 Aura 狀態判斷
```

## 20.4 PTR 實機驗證

```text
AddPandemicRegion 實際顯示
Pandemic Window 切換
Pandemic Region SecretAspect.Shown
大量 Pandemic AuraButton 的 CPU 成本
AddDispelTypeTexture
多個 Dispel Texture
showAlways
Stealable
NotStealable
CustomAsset
Tooltip 200 ms 節流
SetEnabled(false) 清除 assignment
Duration Text 不再錯誤顯示 0
OnSizeChanged 無法洩漏 Aura 數量
SVG／VectorGraphics
戰鬥中建立與設定限制
PLAYER_LOGIN 前後差異
Forbidden／taint log
```

Mock 通過不得描述成 PTR 實機通過。

---

# 21. 2026-08-13 正式服切換程序

到達預定改版窗口後，不要直接合併「日期開關」。

依序執行：

## Phase A：確認正式服版本

```lua
GetBuildInfo()
```

記錄：

```text
version
build
buildDate
interfaceVersion
WOW_PROJECT_ID
```

只有：

```text
WOW_PROJECT_MAINLINE
且 interfaceVersion >= 120100
```

才進入下一階段。

## Phase B：確認正式服 API 契約

最少確認：

```text
CustomAuraContainerTemplate
SetUnit
SetEnabled
AddAuraGroup
AddAuraSlot
必要 Group setter
AuraButton initializeFrame callback
必要 display binding
```

可選 PTR 8 視覺能力缺失，不得阻止 Native 核心啟用。

## Phase C：正式服 smoke test

```text
登入
重載 UI
切換目標
進出戰鬥
玩家 Buff
玩家 Debuff
目標 Buff
目標 Debuff
Enable／Disable
設定變更
音效
Tooltip
taint log
Lua Error
```

## Phase D：解除 PTR-only 標記

只有正式服 smoke test 通過後，才：

```text
更新文件為正式服已驗證
解除 PTR-only feature flag
發布正式服 12.1 相容版本
```

---

# 22. 優先順序

## P0：版本隔離與安全正確性

1. 正式服 12.0.7 強制 Legacy。
2. PTR 12.1 才啟用 Native。
3. 移除任何 OnSizeChanged Aura 推導。
4. 不讀 Secret AuraData。
5. 修正 identity candidate filter 退化風險。
6. 不把 PTR 測試冒充正式服驗證。

## P1：資源與效能

1. Sound-only 不重建。
2. Layout-only 不重建。
3. Enable／Disable 不重建。
4. 控制 retired Container。
5. Pandemic Region 按需配置。
6. 避免大量 AuraButton 私有 OnUpdate。

## P2：PTR 8 視覺功能

1. Pandemic Region。
2. Multiple Dispel Type Texture。
3. `stealableFilter`。
4. `showAlways`。
5. Custom Asset／Color。
6. SVG 實驗。

## P3：低關聯項目

1. `UnitIsPossessed`／`UnitIsCharmed`。
2. `PingableUnitFrameTemplate`。
3. 文件矩陣。

---

# 23. 交付內容

完成後回報：

## 23.1 現有進度整合

```text
原任務已完成內容
原任務進行中內容
PTR 8 新增內容
既有判斷校正
重複項目
未修改項目
```

## 23.2 版本矩陣

至少包含：

```text
環境
Interface version
Backend
允許的功能
禁止的功能
測試狀態
```

必要列：

```text
正式服 12.0.7
PTR 12.1
正式服 12.1 尚未驗證
正式服 12.1 已驗證
```

## 23.3 PTR 8 API 稽核表

```text
公告描述
Generated API 名稱
FrameXML 方法
Options／Enum
Secret／Forbidden 行為
EAM 使用位置
是否修改
是否需 PTR 驗證
```

## 23.4 修改檔案

逐檔說明：

```text
修改原因
行為差異
版本影響
效能影響
回退方式
```

## 23.5 資源統計

```text
Container rebuild 次數
AuraButton 初始化數
Pandemic Region 數
啟用 OnUpdate 的 AuraButton 數
retired Container 數
事件註冊數
Sound-only Frame 建立數
Layout-only Frame 建立數
```

## 23.6 驗證狀態

嚴格區分：

```text
程式碼稽核完成
靜態測試通過
Mock 通過
PTR 實機通過
正式服 12.0.7 回歸通過
正式服 12.1 尚未驗證
```

---

# 24. 禁止事項

- 不得因 PTR 8 重置原任務。
- 不得只讀 PTR 公告摘要。
- 不得猜測 API 名稱。
- 不得使用 `stealable = true` 代替 `stealableFilter`。
- 不得把 Pandemic 限定誤寫成 Texture-only API。
- 不得為所有 AuraButton 無條件配置 Pandemic Region。
- 不得自製 Pandemic OnUpdate。
- 不得以 OnSizeChanged、尺寸、位置、顯示狀態推導 Aura。
- 不得重新導入 UNIT_AURA Secret payload。
- 不得為 Tooltip建立每幀更新。
- 不得為 Duration Text 建立新的 Native Aura OnUpdate。
- 不得把 `SetEnabled(false)` 誤認為 Frame 已釋放。
- 不得讓可選 PTR 8 視覺能力缺失導致整個 Native Backend 降級。
- 不得讓正式服 12.0.7 呼叫 PTR-only AuraContainer API。
- 不得只依 2026-08-13 日期啟用 12.1。
- 不得把 PTR 通過寫成正式服通過。
- 不得破壞 Classic／Legacy Backend。
- 不得改動與本稽核無關且已正常運作的模組。

請以 **PTR 專用驗證、正式服 12.0.7 嚴格隔離、API 文件與 FrameXML 雙重證據、最小可回退修正** 為執行準則。

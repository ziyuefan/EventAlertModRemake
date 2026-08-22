<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 正式服 API 邊界

## 正式服 12.x 假設

本重寫目標為 Retail 12.x / Midnight-era API。除非已在 WoW Retail 實機載入測試，否則本文件所有 API 筆記都視為文件假設。

優先使用命名空間：

- `C_AddOns`
- `C_Spell`
- `C_Item`
- `C_UnitAuras`
- `C_TooltipInfo`
- `AuraUtil`
- `C_Timer` 僅透過中央調度程序或明確非熱設定

除非有明確、嚴格且已文件化的正式服安全後備，不保留舊式解壓縮返回相內容層。

## 污染控制政策
Warcraft Wiki 的安全執行 / taint 文件指出，AddOn 與 `/script` 屬於不受信任來源；一旦 taint 進入 protected/secure 路徑，戰鬥中可能會導致 Blizzard UI 動作被匱乏。 EAM 必須把避免污染修改視為架構邊界，而不只視為 bug。

實行規則：

- 不鉤、覆寫、重新定義或猴子補丁 Blizzard secure/protected 函數、FrameXML 核心函數、動作按鈕、單位框架、銘牌、法術施法、瞄準、物品使用相關路徑。
- 不在戰鬥中修改受保護框架的屬性、父級、錨點、大小、可見性、模板或點擊行為。
- 不把secret/protected值、運行時快取、偵錯物件或addon回呼確定可能污染安全鏈的暴雪框架。
- EventRouter 使用孤兒框架；渲染框架僅作顯示，不承擔安全操作或受保護的互動。
- 需要 UIParent 訊框時，限定為非 protected 顯示用途；若 `InCombatLockdown()` 為 true，延後結構性 UI 變更。
- 不使用`forceinsecure`，不嘗試繞過污染，也不加入壓制暴雪阻止行動的解決方法。
- 發現污染、被阻止的動作、戰鬥鎖定錯誤時，需記錄到`Docs/15_DEVELOPMENT_ISSUE_LOG.md`。

## Aura API 世代邊界

下列 API 僅作 12.0.7 舊路徑與遷移稽核參考，不得直接帶入 12.1 Native backend：

- `C_UnitAuras.GetBuffDataByIndex`
- `C_UnitAuras.GetDebuffDataByIndex`
- `C_UnitAuras.GetAuraDataByIndex`
- `C_UnitAuras.GetAuraDataByAuraInstanceID`
- `C_UnitAuras.GetAuraDuration`
- `C_UnitAuras.GetAuraBaseDuration`
- `C_UnitAuras.GetRefreshExtendedDuration`
- `C_UnitAuras.GetUnitAuraInstanceIDs`
- `C_UnitAuras.AddBlockedAura` / `C_UnitAuras.ClearBlockedAuras`
- `C_TooltipInfo.GetUnitBuffByAuraInstanceID`
- `C_TooltipInfo.GetUnitDebuffByAuraInstanceID`
- `AuraUtil.ForEachAura`
- `AuraUtil.FindAuraByName`
- `GameTooltip:SetUnitAura`
- 舊版 `UnitAura` / `select(10, UnitAura(...))` 後備路徑

12.1 Native backend 規則：

- 不把 AuraInstanceID 視為 `NeverSecret` 穩定錨點，不呼叫 index／slot／instance-ID Aura getter，也不保存 AuraData。
- Aura 追蹤與顯示交由 `AuraContainer`／`AuraButton` 原生契約；EAM 只在 `initializeFrame` 綁定官方允許的顯示 Region。
- 不對 `GetRefreshExtendedDuration`、`GetAuraBaseDuration`、duration、expirationTime 或 timeLeft 做 Lua 算術／比較來推導 Pandemic；無安全普通數字事實時必須降級。
- 不在 Native backend 呼叫 `AddBlockedAura`／`ClearBlockedAuras`；若未來另案採用，必須先取得 12.1 文件與 PTR taint 證據。
- 任何 Secret／protected／display-only 值不得字串化、比較、運算、序列化、作為 table key 或傳入自訂不安全鏈。
- 12.0.7 舊資料抽取只能保留在明確隔離的相容路徑，不能回流 12.1 Native runtime。

## 当前冷却时间 API 使用情况审核

目前主線參考：

- `C_Spell.GetSpellCooldown`
- `C_Spell.GetSpellBaseCooldown`
- `C_Spell.GetSpellCharges`
- `C_Spell.GetSpellInfo`
- `C_Spell.GetSpellTexture`
- `C_Spell.GetSpellLink`
- `C_Spell.IsSpellUsable`
- `C_Spell.DoesSpellExist`
- 旧版全域 `GetSpellCooldown`、`GetSpellInfo`、`GetSpellTexture`、
  `GetSpellLink`、`GetSpellCharges`、`IsUsableSpell`
- `C_Secrets.ShouldSpellCooldownBeSecret`
- GCD 法術 ID `61304`

重寫規則：

- 偏好結構化的 `C_Spell` 回報。
- 當秘密/protected時，將冷卻事實視為不可用。
- 請勿偽造冷卻時間開始、持續時間或到期時間。
- 避免每幀重複的冷卻時間查詢。

## 目前物品冷卻 API 使用審核

目前主線參考：

- `C_Item.GetItemCooldown`
- `C_Item.GetItemSpell`
- `C_Item.DoesItemExistByID`
- `C_Container.GetItemCooldown` 作為一個別名層的後備
- 舊版全域 `GetItemCooldown`、`GetItemSpell`
- `GetInventoryItemCooldown`
- `GetInventoryItemID`
- 可選 `HeroDBC.DBC.ItemSpell`
- `EventAlert_ItemSpellCache.lua` 中的大物品範圍掃描

重寫規則：

- 首先支援直接itemID冷卻時間監控。
- 請勿在正常運作時掃描大範圍的項目。
- 任何物品-法術關係快取必須是選擇加入的、僅空閒的、可中斷的、
  FPS 意識和戰鬥意識。
## 目前專業化和在地化 API 審核

目前主線參考：

- `GetSpecializationInfoForClassID`
- `GetClassInfo`
- `GetSpecializationInfo`

重寫規則：

- **動態本地化**：使用本機 API 來查詢與客戶端當前語言設定動態對齊的匹配字串，而不是在配置 UI 中對本地化專業化或類別名稱進行硬編碼。
- **規範下拉過濾**：將類別標記映射到類別 ID（使用靜態枚舉映射，例如 `CLASS_TOKEN_TO_ID` 匹配 WoW 類別 ID）。透過 `GetSpecializationInfoForClassID(classID, specIndex)` 動態檢索規範名稱（其中 `classID` 是 1 到 13 之間的數字，`specIndex` 是 1 到 4 之間的數字）。
- **雙路徑回退**：當本機本地化 API 傳回 `nil` 或空值時，使用靜態本地化表 (`EAM.L`) 實作可靠的回退映射，以確保 UI 元件始終具有可讀的名稱。

## 秘密/受保護價值政策

當數據不安全或不可用時：

- **四個安全性檢查 API**：
  - `issecretvalue(value)`：檢查某個值是否被分類為秘密。
  - `canaccessvalue(value)`：確定目前上下文是否有權讀取某個值。
  - `canaccesstable(table)`：評估表的鍵和值是否可讀。
  - `issecrettable(table)` / `hasanysecretvalues(table)`：檢查表格結構是否受限或包含機密。
- **表格索引保護（嚴重）**：
- AddOns 絕對不能使用可能是「秘密值」的未經驗證的鍵來索引標準 Lua 表（例如，在戰鬥限制期間傳回 `spellId` 或 `text`）。
  - 嘗試使用金鑰對資料表進行索引會產生致命錯誤：「嘗試對無法使用金鑰進行索引的表進行索引」。
  - 總是使用「if not issecretvalue(key) and canaccesstable(tbl) then ... end」來保護表格查找。
- **資料驅動的工具提示與保密防禦**：
  - 戰鬥返回結構 `TooltipData` 中的直接 `C_TooltipInfo` 查詢 (`GetUnitBuffByAuraInstanceID`) 可能被標記為「秘密表」。
  - 從 `line.leftText` 解析靜態值時，請務必使用「if text and not issecretvalue(text) and canaccessvalue(text) then ... end」來防止秘密傳播。
- **無 `TooltipUtil.SurfaceArgs`**：在 12.x / Midnight 中，工具提示表是原生顯示的。 `TooltipUtil.SurfaceArgs` 幫助器被**完全刪除**；嘗試呼叫它會拋出致命的「nil value」Lua 錯誤。
- 繼續渲染安全狀態，例如 icon/name（如果可用）。
- 使用計時器模式 `protected`、`displayOnly` 或 `unknown`。
- 為偵錯狀態新增邊界警告。
- 僅在安全的情況下才安排非戰鬥刷新。
- 切勿將猜測值與事實混為一談。
- 切勿將不安全的值傳遞到 secure/protected UI 鏈中。

## 有意避免的 API/模式

- 經典 API 分支。
- MOP/Cata/Wrath/TBC API 傳回映射。
- `RegisterAllEvents`。
- 工具提示掃描作為普通資料來源（僅將其用於低頻靜態持續時間抓取回退）。
- `TooltipUtil.SurfaceArgs` 用法（始終讓本機引擎顯示參數）。
- 登入期間掃描大量物品 ID/combat。
- 每個圖示`SetScript("OnUpdate")`。
- 熱路徑中重複的`C_Timer.After(function() ...)`鏈。
- 配置的外部框架相依性。
- `forceinsecure` 或任何 taint 繞過、抑制被阻止操作的解決方法。

## 2026-07-26：12.1 AuraContainer 邊界

- Native 模式不註冊或解析 `UNIT_AURA`，也不呼叫 index/slot/instance-ID Aura getter。
- `initializeFrame` 只綁定 Icon、DurationCooldown、DurationText、ApplicationCount 與 SpellName Region；不讀 AuraData。
- AuraButton 不以 `OnShow`、`OnHide`、`IsShown`、Hook 或事件推導狀態。
- Secret identity filter 只保證友方 helpful 或敵方 harmful；反向極性必須標 limitation。
- 68914 允許戰鬥建立容器，但 EAM 仍採脫戰結構修改政策。

## 2026-07-27：GameTooltip ID 與 EAM 自有 Popup 邊界

- `TooltipDataProcessor.AddTooltipPostCall` 依 TooltipDataType 全域註冊；callback 立即以 `tooltip == GameTooltip` 排除其他 Tooltip。初始化必須冪等，因 FrameXML 沒有對應的解除註冊 API。
- post-call callback 只可追加 Tooltip 顯示文字與更新純 scalar candidate，不得在 callback 內建立、顯示或操作 Popup UI；Popup 只能由後續 `MODIFIER_STATE_CHANGED` 事件開啟。
- Spell／Item 僅在整個 `TooltipData` 與 `data.id` 通過 Secret/access/正整數檢查後顯示與暫存；候選只保留五秒且只含普通 scalar。
- Macro 不使用 `TooltipData.id`。`GameTooltip:GetProcessingTooltipInfo()` 與 getter metadata 是 PTR 68914 FrameXML 的實務來源，不是穩定 Generated API 契約；只有安全且來源為 `GetAction` 時，才以 action slot 呼叫 `GetActionInfo`，再由 `GetMacroSpell`／`GetMacroItem` 解析。任何 API、來源或值不可用時，一律降級為手動輸入法術／物品 ID。
- UnitAura callback 絕不讀取 `TooltipData`、AuraData、AuraButton、Aura index／slot／instance ID，也不解析剩餘時間或 Tooltip 文字。12.1 優先由官方 session CVar `tooltipShowAuraSpellIDs=1` 顯示 Aura ID；CVar 不存在、設定失敗或回讀失敗時，Tooltip／Popup 必須明示「官方 ID 顯示不可用」，只接受使用者輸入已知 ID。
- 不使用 Ctrl+Alt+右鍵：`GLOBAL_MOUSE_DOWN` 只能觀察，不能抑制物品使用、裝備或 Blizzard action；12.1 AuraButton 又具 Forbidden Aspects。安全互動改為游標停留後按下精確 `Ctrl+Alt`，開啟 EAM 自有 Popup，再點擊 EAM 按鈕確認。
- Popup 不 Hook／覆寫 Blizzard `OnClick`、`OnMouseDown`、`OnMouseUp`，不註冊 secure action attribute，不模擬滑鼠事件。戰鬥、鍵盤焦點、Secret／不可讀值、缺少必要檢查 API、Tooltip 已隱藏、Tooltip 類型改變或候選逾時時一律 fail-closed；戰鬥中可追加安全顯示文字，但不得建立可於出戰後重播的 candidate。
- 寫入只經 `SavedVariables.add*Alert()`；`action` 必須先通過安全字串與四種 EAM action 白名單。只有 `added`／`updated` 通知服務刷新，`unchanged` 不增加 revision，也不觸發不必要刷新。
- 同型 Tooltip 的 generation／owner identity 沒有可安全依賴的公開契約；目前以最新 post-call 覆寫、五秒 TTL、shown 與 tooltip type 共同約束，仍須 PTR 快速切換實測。初始化採單次冪等，若載入當下 API 能力暫缺不會重試，以避免無解除 API 的 PostCall 重複註冊。


## 2026-08-08：UnitPower 與 PTR8 邊界補充

- `UnitPower`、`UnitPowerMax`、`UnitPowerPercent` 在戰鬥／Secret context 不得由 Lua 讀取並做算術、比較、字串化或 table key；EAM 只在 predicate 明確允許的非戰鬥安全數字路徑讀取。
- 使用者提供的 `StatusBar:SetUnit`、`SetPowerTextFontString`、`SetOnUpdateMode` 尚未在 PTR 12.1.0.69189 公開生成文件中證實；在新 build 未提供官方文件前不得硬編碼。
- 主要資源 Secret 顯示採單向 C-level sink：`StatusBar:SetValue` 或 `Texture:SetRadialProgressBarPercent`；不讀回 widget 值。
- PTR8 Pandemic／Dispel APIs 僅於 initializeFrame 建立 Region／texture；不讀 `Shown`、不建立自製 ticker，停用容器清除由 Blizzard 管理。

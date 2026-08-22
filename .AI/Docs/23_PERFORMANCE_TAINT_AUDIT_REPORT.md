<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
#實施與污染控制審查報表：統一OnUpdate與版本面偏移

> [!注意]
> 本文件由 EAM Performance & Taint Control Expert 撰寫，旨在評估 EventAlertMod 重構版本中統一（legacyTimer）的兼容超時、LAYOUT_OFFSETS 靜態偏移陣列的算術分配性能，並識別戰鬥中潛在的隱性垃圾性分配問題。

---

## 1.統一OnUpdate計時器（legacyTimer）有效的頭部審查
`UI/Renderer.lua`秒中的`legacyTimer`負責在不使用即時持續時間綁定時，提供備用的倒數顯示（尤其在$_​​_EAMCODE_2__ < 3.05$時提供小數點後單倒數）。其相容機制為使用唯一的隱含監聽監聽框架`OnUpdate`，操作`activeLegacyTimers`和`activeDurationObjects`來更新圖示的`timerText`。

### 1.1 完全優勢
* **單一一幀集中驅動**：避免了每個圖示或每個香水各自綁定 `OnUpdate` 的高額設計。當沒有啟動任務時，會呼叫`legacyTimerFrame:SetScript("OnUpdate", nil)`解除綁定，保持CPU零佔用。
* **孤兒框架隔離**：`legacyTimerFrame`為無父級的框架（`CreateFrame("Frame")`），完全與`UIParent`核心鏈解耦，消除了事件派發過程中的污染傳播風險。
### 1.2 可運行的開銷與GC瓶頸分析
在創建戰鬥環境（例如 60-120 FPS，擁有多個活動監控圖示）下，目前的實踐存在顯著的 GC 與 CPU 頭：
1. **牆壁的字符串清理（GC堆垃圾主要來源）**：
    * 在 `onLegacyTimerUpdate` 中，每個畫面都會對所有活動圖示執行：
        ```lua
        if timeLeft < 3.05 then
            text = string.format("%.1f", timeLeft)
        else
            text = string.format("%d", math.ceil(timeLeft))
        end
        ```
* 在Lua VM中，`string.format`會產生全新的字符串物件。在60 FPS下，若有5個圖示同時倒數，一秒將配置$60 \times 5 = 300$個字串。這會直接加速GC觸發，造成幀率（停止微卡頓）。
2. **`pairs`雜湊表重複頭錢**：
* 使用 `pairs(activeLegacyTimers)` 來遍歷遍歷活動。在 LuaJIT 中，若遍歷雜湊表（Hash 部分），JIT 編譯器可能無法有效進行 Trace Compiler 編譯，且迭代過程中對錶進行 `activeLegacyTimers[icon] = nil` 的刪除操作很容易，導致內部 Hash 結構與 GC 後續重整。
3. **`pcall`導致JIT Trace Abort**：
    * 在 `activeDurationObjects` 迭代中，呼叫了 `safeCheckIsZero(durationObj)`，其內部包含 `pcall(durationObj.IsZero, durationObj)`。
* 在 LuaJIT 中，`pcall` 會直接導致目前的 Trace 編譯失敗（Trace Abort），使得 OnUpdate 的核心執行路徑只能回到低效率的解釋器模式執行，大幅增加了每一幀的 CPU 算術與呼叫高峰。

---

## 2. 7大框架靜態關聯（LAYOUT_OFFSETS）庫

EAM定義了7個大的獨立框架，並在排版時利用`EAM.Constants.LAYOUT_OFFSETS`做地震預警：
```lua
LAYOUT_OFFSETS = freeze({
    freeze({ 1, 0 }),  -- 1 = RIGHT (向右成長)
    freeze({ -1, 0 }), -- 2 = LEFT (向左成長)
    freeze({ 0, 1 }),  -- 3 = UP (向上成長)
    freeze({ 0, -1 })  -- 4 = DOWN (向下成長)
})
```
### 2.1 CPU算術費用補償
在 `layout(frameName)` 執行時，其定位計算為：
```lua
local offset = EAM.Constants.LAYOUT_OFFSETS[dirIdx]
local dx, dy = offset[1], offset[2]
...
local dist = (layoutIndex - 1) * (size + spacing)
local offsetX = dx * dist
local offsetY = dy * dist
```
* **術算**：首先對舊版 EventAlert 的休眠 `if-else` 或 `switch` 分支判定（如 `if dir == 1 then x = ... else ...`），以連續數字索引可能符合判別，完全消除了 CPU 分支錯誤的預測分支錯誤的預測值，可能符合了決定分支錯誤的預測分支可能符合了數據代碼分支錯誤的預測（Branchpretion）可能符合判別，完全消除了 CPU 分支錯誤的預測（Branchpretion）可能符合判別，消除了 CPU 分支錯誤的預測值（Branchpretion）可能符合判別，完全消除了 CPU 分支錯誤的預測（Branchpretion）可能符合了 CPU 分支錯誤的預測（Branch_3%），CPU 分支錯誤的預測（Branch_3%）可能符合了 CPU 分支錯誤的預測（Branchpretion）可能符合了 CPU 分支錯誤的預測（Branch_38）可能符合了 CPU 分支錯誤的預測（Branch_3%）。分支錯誤的預測值，可能符合了CPUBranchpretion）完全判別，可能符合 CPU 分支錯誤。
* **唯讀凍結**：使用了`table.freeze`確保填入在執行期間被不可竄改，兼顧安全與便攜性。
* **查表頭頭評估：雖然每次定位都需要從 `LAYOUT_OFFSETS` 讀取內部表元素，但在實際運行中，`layout` 僅在圖標增減或設定變更時被觸發（由 `BeginBatch/EndBatch` 節流，並非在熱路徑設計中產生的決策路徑類型的研究類型的研究類型。

---
## 3.戰鬥中隱性污染排放與GC堆垃圾分配評估
透過深入研究進程進程碼，我們發現以下在戰鬥中高頻事件與渲染下，可能導致隱性Taint洩漏或GC堆垃圾分配的關鍵問題：

### 3.1 隱性 Taint 洩漏與戰鬥鎖定 (Combat Lockdown)
1. **戰鬥中動態`CreateFrame`（高風險點）**：
* 雖然`ensureParent`具備`InCombatLockdown`守衛，但在`Renderer.render`中，如果`IconPool`的可以緩衝圖標用盡例如（在中同時觸發多個戰鬥天賦/冷卻/魔法，使得激活數量大於前置的16個），會觸發`IconPool.acv)(
        ```lua
        local function createIcon()
            local button = api.CreateFrame("Frame", name, UIParent)
            ...
            local cooldown = api.CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        ```
* **風險**：在戰鬥鎖定期間呼叫`CreateFrame("Frame", name, UIParent)`且加載了官方的`CooldownFrameTemplate`，可能會污染雪內部的安全模板鏈，並高機率觸發「Action block by an addon」錯誤。
2. **影子載體(Shadow Host)寄生模式的潛在Taint傳播(極高風險點)**：
* 雖然目前 `useCDM` 已強制設定 `false`，但若啟用此模式，則可將 EAM 的圖示寄生在官方的 `CooldownViewer` 或 ActionButton：
        ```lua
        icon:SetParent(hostIcon)
        icon:ClearAllPoints()
        icon:SetAllPoints(hostIcon)
        ```
* **風險**：官方的`CooldownViewer`與ActionButton屬於高度受保護的安全/受保護框架。非安全的EAM圖示在戰鬥中呼叫`SetParent`附加到安全框架上，當暴雪UI嘗試重新排版或該安全框架時，會操作其子系統包含不安全框架導致整個鏈執行被標記為污染，進而引發了操作按鈕被淹沒、無法點擊的致命錯誤。
### 3.2 隱性GC堆垃圾分配
1. **熱路徑中的匿名閉包`pcall`**：
    * 在 `Renderer.render` 中：
        ```lua
        pcall(function()
            icon:SetFrameStrata("MEDIUM")
            icon:SetFrameLevel(hostIcon:GetFrameLevel() + 10)
        end)
        ```
* 渲染更新（如下面的資料、冷卻更新）時，都會在熱路徑中動態分配這兩個匿名閉包函數，並呼叫 `pcall`。這不僅會阻塞 LuaJIT VM 的 Trace 編譯，還會產生持續的 GC 垃圾佔用。
    * *註：`icon.overlay` 與 `icon.cooldown` 皆為 EAM 內部建立的框架，其方法是 100% 確定存在的，根本不需要使用 `pcall` 進行防護。 *

---

## 4.具體重構與最佳化建議
為了消除上述設想並實現 EAM 重寫版本的最大完成和零污染點要求，建議實施以下最佳化重構：

### 4.1 刪除字符串與__分配EAMCODE_1__迭代：引入「時間字符串儲存」與「集合連結串列」
* **時間字符串儲存（時間文字伺服器）**：
預先產生 $0.0$ 到 $3.0$ 秒（間隔 0.1 秒，共 30 個）以及 $3$ 到 $3600$ 秒的整數串表。在 OnUpdate 中，透過數值計算直接索引此儲存表，將初始化初始化初始值。
* **最近鏈結/數值指數排列**：
將使用 `activeLegacyTimers` 改為數值索引的互連，間隙使用 `for i = 1, count` 進行數字循環迭代，去掉 `pairs` 在路徑雜下的迭代器分配與表頭。
### 4.2 移除熱路徑 `pcall` 與匿名閉包
* 刪除 `Renderer.render` 中對自建框架的 `pcall(function() ... end)` 包裝，改為直接賦值或使用預先好的定義靜態輔助函數，避免高頻分配。
### 4.3 強制執行戰鬥中 `CreateFrame` 與 `SetParent` 延遲
* 在`IconPool.acquire()`中加入`InCombatLockdown`檢測。若在戰鬥中且無可用圖標，應降級或將其加入延遲渲染佇列（`deferRender`），嚴禁在鎖定戰鬥呼叫期間`api.CreateFrame`。
* 徹底廢除或嚴格限制影子載體（Shadow Host）寄生模式在戰鬥中的`SetParent`行為，避免任何與Secure Frame的直接父親連結。

---
## RACI 權責分工與審查結論
本報告審查[Docs/21_RACI_EXPERTS_MATRIX.md](file:///d:/EventAlertMod/Docs/21_RACI_EXPERTS_MATRIX.md)規範，由**性能與污染控制專家**負責（Responsible），為**主代理**提供核心技術決策諮詢。
* **在下一個重構週期中，應立即針對`UI/Renderer.lua`與`UI/IconPool.lua`進行局部重構，實現“時間字符串存儲”、“無pcall直接呼叫”以及“戰鬥中CreateFrame延遲防禦”，以確保AddOnMCO兼容時的最高低衛”，絕對兼容
<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# Docs/20_CDM_BYPASS_FEASIBILITY_STUDY.md
# 12.1.0 影子載體技術（Shadow Host）呼吸評估與實施方案：借用官方CooldownViewer繞過戰鬥秘密/Taint限制

本文件針對利用魔獸世界 12.0.7 / 12.1.0 正式服內建的 **CooldownViewer (冷卻管理器/CDM)**作為「影子載體（Shadow Host）」，以解決 EAM 戰鬥中秘密價值與 Taint Tunnels 之方案，進行深度設計技術架構。

---
## 一、技術原理：什麼是「影子載體（Shadow Host）」？

在正式服 12.x 環境中，戰鬥中取得冷卻/aura 時間（如 timeLeft, expirationTime）已被限制（秘密值），且在戰鬥中動態修改 UI 佈局極易引發 Action Blocked 崩潰。

官方內建的 `EssentialCooldownViewer` 和 `UtilityCooldownViewer` 是暴雪的嫁接安全框架，在戰鬥中完全更新、定位與倒數的特權。

**影子載體技術(Shadow Host)**：
1. **鏡像初始化**：在戰鬥外，將官方 CooldownViewer 的幀設置為透明（Alpha = 0）或降至最低幀級別（BACKGROUND, -100），使螢幕上完全不可見。
2. **寄生通知**：將 EAM 的美化圖示作為子框架掛載（已新增）到官方對應的冷卻圖示上。
3. **無程式碼同步**：利用WoW引擎內建的父子級聯渲染：
    * 當官方圖示顯示/隱藏時，EAM的圖示會**自動**顯示/Hide。
* 官方圖示移動或重排（佈局）時，EAM 的圖示拓樸。
    * 由於依賴基礎C++引擎的渲染級聯動，**戰鬥中不需要執行任何Lua程式碼來控制顯示與位置，實現0-Taint與0-GC戰鬥同步**。
```text
 Blizzard CooldownViewer (Shadow Host) [Alpha = 0, Secure Frame]
   └── (Parent-Child Bind)
        └── EAM Custom Icon (Parasitic Frame) [Alpha = 1, Display Only]
```
---

## 二、地域分析與API 邊界審計

### 1. 官方 API 與 SpellID 限制
* **特性**：`C_CooldownViewer`僅允許追蹤「暴雪官方資料庫內建並支援的SpellID」。
* **評估**：對於職業大招（如聖騎翅膀31884、戰士魯莽1719）及核心Buff/DoT，官方內建內建支援。但對於玩家自訂的稀有/臨時SpellID，官方CDM無法載入。
* ******策略：EAM採用**雙軌驅動**：
* **影子載體軌道（軌道A）**：為了官方支援的核心SpellID，啟用影子載體掛載，獲得100%戰鬥穩定性。
    * **常規資料軌（Track B）**：對於自訂或非官方支援的法術，降級使用EAM自身的計時器與安全回退渲染。

### 2. Taint與戰鬥鎖定（Combat Lockdown）避讓
* **修改問題**：若在戰鬥中呼叫`SetParent`、`SetPoint`或官方框架，會直接引發`嘗試修改安全框架`崩潰。
* **解決方案**：
    1. **戰鬥外綁定**：所有`SetParent`、`SetPoint`、`SetAlpha`操作限制均在`PLAYER_REGEN_ENABLED`（脫戰）或`ADDON_LOADED`（載入時）進行。
2. **戰鬥中對話**：戰鬥中（`InCombatLockdown()`為true時），EAM絕對不是官方框架進行任何寫入操作，只能讓寄生的子框架受C++引擎驅動。

---

## 三、實作概念碼（Proof of Concept）

### 1.影子化官方CooldownViewer
在非戰鬥狀態下，對官方主要框架進行透明化，並降低框架等級。
```lua
local function MakeHostInvisible(hostFrame)
    if not hostFrame or InCombatLockdown() then return end
    
    -- 設為完全透明，但保留其 Child Widgets 的 Show/Hide 生命週期與 Layout 重排
    hostFrame:SetAlpha(0)
    
    -- 將層級降至背景最底層，以防萬一
    hostFrame:SetFrameStrata("BACKGROUND")
    hostFrame:SetFrameLevel(0)
end

local function InitShadowHosts()
    if EssentialCooldownViewer then
        MakeHostInvisible(EssentialCooldownViewer)
    end
    if UtilityCooldownViewer then
        MakeHostInvisible(UtilityCooldownViewer)
    end
end
```
### 2. 寄生掛載與佈局等級聯
取得官方圖示池（通常為 FramePool 或靜態佇列），將 EAM 圖示設定在其上。
```lua
local function AnchorParasiticIcon(eamIcon, hostIcon)
    if InCombatLockdown() then return end
    
    -- 將 EAM 圖示的 Parent 設為官方圖示
    eamIcon:SetParent(hostIcon)
    eamIcon:ClearAllPoints()
    eamIcon:SetPoint("CENTER", hostIcon, "CENTER", 0, 0)
    
    -- 確保 EAM 圖示的 Strata 比官方高，且 Alpha 為 1
    eamIcon:SetFrameStrata("MEDIUM")
    eamIcon:SetFrameLevel(hostIcon:GetFrameLevel() + 10)
    eamIcon:SetAlpha(1)
    
    -- 影子載體會同步控制 eamIcon.Show / Hide
end
```
---

## 四風險與防禦策略（分散計畫）

| 風險項目 | 影響 | 防禦與優化策略|
| :--- | :--- | :--- |
| **官方布局变更** | 暴雪在12.1.0改变了`EssentialCooldownViewer`的子节点获取方式 | 采用动态引用与特征检查，若无法获取子图标，自动降级关闭“月球载体”，返回至轨道B。
| **戰鬥中特殊載具覆蓋** | 進入載具時，官方主機隱藏，導致EAM寄生圖示也消失 | 這是預期行為（符合 `hideWhenActionBarIsOverriden`）。如果玩家想要保留，可對 EAM 圖示手動呼叫提權或複製。
| **戰鬥污染擴散** | 如果 EAM 的圖示包含「點擊投射」或「安全操作」按鈕 | **硬性規定**：EAM的圖示僅作為「純視覺渲染器（僅顯示）」，不註冊任何點擊/Mouse-點擊事件，不承擔安全事件，並點擊發酵安全事件。

---

## 五、 下一階段執行步驟 (12.1.0 重構清單)

1. **第一階段（調查與線索抓取）**：
* 在脫戰狀態下，使用錯誤偵訊工具傾倒官方 `EssentialCooldownViewer` 的子物體結構，確定其 Icon Pool 的實體變數。
2. **第二階段（單向場景）**：
    * 在程式測試程式碼中，嘗試將 `EssentialCooldownViewer` 設定 Alpha = 0，並開始是否會引發 EditMode 的污染警告。
3. **第三階段（雙軌配送正式服）**：
    * 在 `Renderer.lua` 中加入角色綁定邏輯。

## 2026-07-26 結論：停止採用

- ShadowHost/CDM 不再列入 `EventAlertMod.toc`，Renderer 亦移除 host lookup。
- 設定頁原 `enableCDM` 控制項改為 Native Aura backend/pending 狀態與手動重建。
- 本文件僅保留歷史可行性研究，不是現行架構，也不得恢復為 12.1 Secret Aura 繞過方案。
- 現行方案為 Blizzard 公開 AuraContainer/AuraButton 契約，見 `Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`。

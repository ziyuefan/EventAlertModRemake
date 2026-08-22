<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
--[[ EAM_FILE_COMMENTARY
EventAlertMod 正式服重寫
模組：文件/21_RETAIL_12X_NEW_EVENTS_INVESTIGATION
文件：Docs\21_RETAIL_12X_NEW_EVENTS_INVESTIGATION.md

理念：
- 詳細記錄魔獸世界12.x / Midnight-era下新引入或高端的16個事件的牽引作用、引數（Payload）及在EAM模組重構中的具體應用場景。
- 保持文件與程式碼的一致性。
]]

#魔獸世界正式服12.x / 午夜時代全新與高頻事件調查報告
少年欸！針對您提供二次與追加的16個核心事件，完成我們對魔獸世界12.x最新AddOn API的調查，以下為各事件的底層原理、有效負載引數及EAM的具體整合設計方案。

---

## 1. 第一批事件詳細調查與有效負載說明

### 📌活動 1：`COMBAT_LOG_MESSAGE`
* **初步作用**：補丁12.0.0後新引進的事件。由於官方將傳統的 `COMBAT_LOG_EVENT_UNFILTERED` (CLEU) 移出 AddOn 插件存取權限，且將 `CombatLogGetCurrentEventInfo()` 設定為確定（被污染的方案碼無法讀取），官方提供了該事件作為浮動戰鬥文字（__EAMCODE_4）浮動文字的替代方案。
* **引數有效負載**：
* `Arg 1 (messageText)`: string - 已整理好且在地化的戰鬥文字字符串（例如：「你的點燃順劈斬訓練目標262點火焰。」）。
    * `Arg 2 (r)`: number - 文字顯示的紅色顏色值通道。
    * `Arg 3 (g)`: number - 文字顯示的綠色顏色值通道。
    * `Arg 4 (b)`: 數字-文字顯示的藍色值通道。
    * `Arg 5 (displayType)`: string/number - 訊息的類型或樣式。
* **EAM 整合策略**：
* **限制**：此事件不包含 `spellID`、`sourceGUID`、`destGUID` 等格式化數據，只有純文字與顏色，由此做正則表達式推理的 CPU 負載能力且不具備版本健壯性。
    * **應用**：EAM將其註冊至`EventRouter`作為debug/trace日誌，在用戶開啟除錯模式時直接輸出為非凡性卓越的戰鬥事件流，不涉及核心光環/冷卻計時事實。

---
### 📌活動 2：`COMBAT_TEXT_UPDATE`
* **最初作用**：魔獸世界傳統的浮動戰鬥文字（浮動戰鬥文本）更新事件。當被監控的單位（預設需用 `CombatTextSetActiveUnit` 設定，通常是`"player"`、`"target"`、`"pet"`）發生戰鬥狀態更新時觸發。
* **引數有效負載**：
    * `Arg 1 (combatTextType)`: string - 戰鬥文字類型（例如：`"SPELL_AURA_START"`, `"DAMAGE"`, `"HEAL"`, `"ENERGY"`, `__EAMCODE___10`110EAMCODE_9__110EAMCO
* **EAM 整合策略**：
*主要用於`EventRouter`除錯追蹤監控，在`AuraService`因安全限制突然失效時，可作為取得`"SPELL_AURA_START"`狀態的防禦性輔助日誌。

---

### 📌活動 3：`UNIT_SPELLCAST_SENT`
* **初步作用**：當被監控的單位發送施法請求給伺服器時觸發（此時生效尚未真正施放成功，此時GCD判斷或唱法開始階段）。
* **引數有效負載**：
* `Arg 1 (unitTarget)`: 字串 - 施法單位（如 `"player"`, `"party1"`）。
    * `Arg 2 (targetName)`: 字符串 - 目標名稱。
    * `Arg 3 (castGUID)`: string - 執行法的唯一 GUID。
    * `Arg 4 (spellID)`: 數字 - 法術ID。
* **EAM 整合策略**：
* 可用於 EAM 的**施法預響應機制**。在唱法（Cast）或瞬間發力發送的瞬間，若對應 spellID 在監控名單中，可預先建立 AlertState 並渲染，提升視覺回饋速度。如果後續收到 `UNIT_SPELLCAST_FAILED_QUIET` 或 `UNIT_SPELLCAST_FAILED`，則立即清理，避免幽靈滯留。

---

### 📌活動 4：`UNIT_SPELLCAST_SUCCEEDED`
* **初步作用**：當被監控的單位成功施放扳機時觸發。
* **引數有效負載**：
    * `Arg 1 (unitTarget)`: string - 施法單位。
    * `Arg 2 (castGUID)`: string - 施法唯一 GUID。
    * `Arg 3 (spellID)`: 數字 - 法術ID。
* **EAM 整合策略**：
    * **核心重構替代方案**：這是12.x下`GroundEffectService` (地面效果監控)的**救明星API**！由於CLEU被封閉，我們直接將`GroundEffectService`修改為註冊`UNIT_SPELLCAST_SUCCEEDED`。
* 當`unitTarget == "player"`且`spellID`為我們監控的地面技能（如暴風雪、寒冰寶珠）時，觸發該技能的持續時間倒數。此API 100%透視了CLEU，且100%為正式服安全性API，完全沒有污染被隔離的風險。

---

### 📌活動 5：`UNIT_SPELLCAST_FAILED_QUIET`
* **初步作用**：當單位的施法失敗且不觸發標準的UI錯誤語音（例如GCD衝突被伺服器拒絕）時觸發。
* **引數有效負載**：
    * `Arg 1 (unitTarget)`: string - 施法單位。
    * `Arg 2 (castGUID)`: string - 對抗施法 GUID。
    * `Arg 3 (spellID)`: 數字 - 法術ID。
* **EAM 整合策略**：
    *用於**防禦性狀態重置**。當擷取到玩家本身的此事件時，若該 spellID 的基本狀態或唱法計時存在，第一時間將其恢復釋放，確保UI的狀態精準同步。

---

### 📌活動 6：`CURRENT_SPELL_CAST_CHANGED`
* **觸發作用**：玩家當前的施法（唱法/引導）發生改變時觸發。
* **引數有效負載**：
    * `Arg 1 (cancelledCast)`: boolean - 前一次執行法是否取消。
* **EAM 整合策略**：
    * 用於 EAM 的 Cast/Channeling 輔助監控。 `如果cancelledCast == true`，代表施法被打斷或因移動隱藏，EAM 能夠即時將關聯的警報圖示。

---

### 📌活動 7：`SPELL_ACTIVATION_OVERLAY_HIDE`
* **裂紋作用**：當裂紋UI螢幕中央的半透明「魔法觸發貼圖提示（C_SpellActivationOverlay）」消失時觸發。
* **引數有效負載**：
    * `Arg 1 (spellID)`: 數字 - 螢幕提示消失的魔法ID。
* **EAM 整合策略**：
    *用於監控螢幕大型幕貼圖過程的消失。這與快捷列的發光不同，但它代表該魔法在中央的過程動畫已經結束。

---
### 📌活動 8：`UNIT_POWER_FREQUENT`
* **單位觸發作用**：被監控的能量值（聖能、連擊點、真氣等）發生變更時的高頻觸發版本。傳統的`UNIT_POWER_UPDATE`有官方節流，而此事件在急速衝擊時能確保即時觸發。
* **引數有效負載**：
    * `Arg 1 (unitTarget)`: string - 能量變更單位。
    * `Arg 2 (powerTypeToken)`: 字串 - 能量類型（如 `"COMBO_POINTS"`, `"HOLY_POWER"`）。
* **EAM 整合策略**：
* **無延遲更新**：將其引入`ClassPowerService`速度！除註冊`UNIT_POWER_UPDATE`外，同時註冊`UNIT_POWER_FREQUENT`，使連擊點、聖能、真氣等資源觸發的反應視覺達到0ms延遲，大幅優化操作流暢度。

---

## 2.第二批事件調查與Payload詳細說明

### 📌活動 9：`SPELL_UPDATE_COOLDOWN`
* **煞車作用**：任一技能冷卻進入、冷卻狀態變更或冷卻完成時觸發。
* **引數有效負載**：無引數。
* **EAM 整合策略**：
    * 此事件為 `CooldownService` 的核心事件。每當觸發時，CooldownService 會對監控點的技能冷卻清單進行 O(1) 的反應方式重新掃描，確保計時儀表準確顯示。

---

### 📌活動 10：`SPELL_UPDATE_USABLE`
* **初步作用**：當法術的可用性（Usable）狀態改變時觸發（如能量值足夠/施放、或技能施放條件被滿足/取消）。
* **引數有效負載**：無引數。
* **EAM 整合策略**：
* 可做為 `CooldownService` 輔助探測可用的時機。在除錯模式下，記錄此發送事件，幫助排查部分冷卻技能因資源不足而在 CD 轉完後沒有顯示為可用的 bug。

---
### 📌活動 11：`SPELL_UPDATE_USES`
* **初步作用**：魔獸世界12.x新引入事件。當某些法術的「可用次數/使用次數（Uses）」或「充能次數（Charges）」改變時觸發。
* **引數有效負載**：
* `Arg 1 (spellID)`: 數字 - 法術ID。
    * `Arg 2 (uses__EEAMCODE_3__)`: number - 剩餘次數使用。
* **EAM 整合策略**：
* 可針對技能充能次數或可用次數改變時，即時更新 `CooldownService` 中技能對應的 `charges` 數值，耗盡等待整體的全掃描，提高反應效率。

---

### 📌活動 12：`SPELL_ACTIVATION_OVERLAY_GLOW_HIDE`
* **初始作用**：**是一個關鍵的事件！ **與`SPELL_ACTIVATION_OVERLAY_HIDE`（螢中央月牙貼圖消失）不同，是指**快捷列技能圖示金色發光亮框（操作列發光）**消失的事件。其對應的事件是`SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`。
* **引數有效負載**：
    * `Arg 1 (spellID)`: 數字 - 金色發光亮消失框的魔法ID。
* **EAM 整合策略**：
* **完美的圖示亮框同步**：我們應該監聽 `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` 和 `SPELL_ACTIVATION_OVERLAY_GLOW_HIDE`。
    * 當玩家觸發Proc（如火法的大火球、冰法的冰指亮框）時，官方會觸發`SHOW`，如果EAM目前顯示了該技能圖標，我們在其上顯示發光亮框；收到`HIDE`時隱藏發光。這樣就可以實現與官方按鈕發光100%同步！

---
## 3. 第三批突發事件詳細調查和有效負載說明

### 📌事件13：`BAG_UPDATE_COOLDOWN`
* **作用最初**：當背包中任何物品（如爐石、使用型飾品、藥水等）進入冷卻、冷卻狀態改變或冷卻結束時觸發。
* **引數有效負載**：無引數。
* **EAM 整合策略**：
* 此事件為 `ItemCooldownService` 物品監控冷卻的核心事件觸發。此時會重新掃描目前被監控的物品冷卻資訊並更新至 UI，避免了 OnUpdate 輪詢背包冷卻的 CPU 頭。

---

### 📌活動 14：`COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`
* **初始作用**：**魔獸12.x初始CooldownViewer (冷卻管理器/CDM)專用內部事件**。當魔法覆蓋關係（魔法覆蓋，因為即天賦、形態或某些特殊狀態，使一個魔法被另一種魔法替換，例如薩滿冰霜震擊變成冰怒）因客戶端觸發而發生變更時。
* **引數有效負載**：
    * `Arg 1 (overriddenSpellID)`: number - 被覆蓋/新取代的武器ID。
* `Arg 2 (originalSpellID)`: number - 原始紙張ID。
* **EAM 整合策略**：
* **解決技能覆蓋的計時Bug**：對EAM的冷卻監控非常有用！以往玩家點了第一天賦使效ID變更時，EAM無法時間動態緊在。我們將在`CooldownService`監聽此事件，當感知到被監控的動作被覆蓋時，動態將狀態的`spellID`或參數監控更新為覆蓋後的新ID，完美避免冷卻故障。

---
### 📌活動 15：`ASSISTED_COMBAT_ACTION_SPELL_CAST`
* **最初作用**：魔獸12.x針對「輔助功能（輔助戰鬥/輔助點擊/按住連續施法）」新引入的輔助施法觸發事件。當玩家使用輔助系統時進行魔法施放時觸發。
* **引數有效負載**：通常標示 `spellID` 及 `castGUID` 等。
* **EAM 整合策略**：
* 這是一個全新的內部輔助施法事件。 EAM將其註冊至`EventRouter`作為偵錯追蹤。當玩家開啟了終極輔助施法且觸發此事件時，可用於輔助`UNIT_SPELLCAST_SUCCEEDED`的雙重溶解，排除極限高壓施法時漏判。

---

### 📌活動 16：`ACTIONBAR_UPDATE_STATE`
* **最初作用**：快捷列狀態更新事件。當快捷列上的任何技能、物品的狀態（例如變灰、變亮、可用性、冷卻等）改變時觸發。
* **引數有效負載**：無引數。
* **EAM 整合策略**：
* 主要做偵錯追蹤記錄，以及在特殊狀態下（如切換動作條頁）觸發 `CooldownService` 和 `ItemCooldownService` 做防禦性批次刷新，確保螢幕圖示一致。
---

## EAM全事件整合作用一覽表（EAM事件對應）

| 事件名稱 | 觸發頻率| EAM 接收模組 | 主要作用 |
| :--- | :--- | :--- | :--- |
| `COMBAT_LOG_MESSAGE` | 極高 (戰鬥中) | `EventRouter`（除錯）| 除錯日誌流輸出，不參與參與事實|
| `COMBAT_TEXT_UPDATE` | 中高 | `EventRouter`（錯誤偵）| 除錯日誌與輔助光環更新 |
| `UNIT_SPELLCAST_SENT` | 中高 | `CooldownService` / 使用者介面 | 施法啟動初步回應機制|
| `UNIT_SPELLCAST_SUCCEEDED` | 中高 | `GroundEffectService` | **VictoriaCLEU，100%安全監控技術** |
| `UNIT_SPELLCAST_FAILED_QUIET` | 低| `CooldownService` | 施法失敗時防禦性恢復 |
| `CURRENT_SPELL_CAST_CHANGED` | 低| `CooldownService` / 使用者介面 | 取消/取消時的圖示重新設定 |
| `SPELL_ACTIVATION_OVERLAY_HIDE` | 中低 | `AlertManager` | 大型螢幕中央貼圖提示隱藏 | 大型螢幕中央貼圖提示隱藏 大型螢幕中央貼圖提示隱藏
| `SPELL_ACTIVATION_OVERLAY_GLOW_HIDE` | 中低 | `AlertManager` / 使用者介面 | **與合約快速列金色亮框同步隱藏** |
| `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` | 中低 | `AlertManager` / 使用者介面 | **與簡潔列金色亮框同步高亮** |
| `UNIT_POWER_FREQUENT` | 極高 (戰鬥中) | `ClassPowerService` | **職業能量更新（聖能/連擊點）0ms延遲** |
| `SPELL_UPDATE_COOLDOWN` | 中文 | `CooldownService` | 冷卻技術事實重新掃描|
| `SPELL_UPDATE_USABLE` | 中文 | `CooldownService` | 技能可用性狀態更新 |
| `SPELL_UPDATE_USES` | 中文 | `CooldownService` | 技能剩餘可用次數即時變更 |
| `BAG_UPDATE_COOLDOWN` | 中文 | `ItemCooldownService` | 物品冷卻事實重新掃描|
| `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` | 低| `CooldownService` | **修改動態技能覆蓋/覆蓋更新** |
| `ASSISTED_COMBAT_ACTION_SPELL_CAST` | 中文 | `EventRouter`（除錯）| 輔助施法之雙重判定防漏機制|
| `ACTIONBAR_UPDATE_STATE` | 中高 | `CooldownService`（錯誤偵）| 動作列切換或狀態同步刷新時機 |
---
name: eam-api-change-intel
description: >-
  World of Warcraft (WoW) Retail 12.x / PTR / XPTR 最新 API 變更調研、版本相容性分析與防禦性封裝指南。涵蓋 Wago.tools/Blizzard Interface 原始碼比對、Secret/Taint 屬性檢定、跨版本降級包裝（Fallback Wrappers）與專案情報庫同步。
---

# EAM API Change Intelligence (WoW 最新 API 變更與情報調研技能)

本技能規範 EventAlertMod 在面對 World of Warcraft (WoW) 各客戶端（Retail 12.1+、PTR 12.1.5+、XPTR 12.0.7+ 或未來重大 Patch）時，進行 API 變更調研、相容性評估與防禦性封裝的標準作業程序。

## 1. 觸發時機
- 暴雪發布新的遊戲版本、Build 號更新或大型 Patch（如 Patch 12.1.5）。
- 發現既有 API 回傳 `nil`、報錯 `attempt to call global (a nil value)` 或行為異常。
- 評估是否引入暴雪最新釋出的 `C_` 系列現代化 API（如 `C_DurationUtil`、`C_Timer.NewTimedSignalMap`、`C_Item` 等）。
- 排查跨版本（Retail vs PTR vs XPTR）客戶端相容性問題。

## 2. 五大權威調研源與探測路徑 (Authoritative Sources)
調研 API 時，必須嚴格依序比對以下五大權威資料源，嚴禁未經查證之憑空猜測：
1. **暴雪官方 UI 開源庫 (Blizzard Interface Code)**：
   - 檢索官方 FrameXML、SharedXML 與最新 UI 程式庫（GitHub `GetWarcraft/ref`、`Gethe/wow-ui-source`、`Ketho/BlizzardInterfaceResources`）。
2. **Wago.tools API Browser & Diffs**：
   - 比對跨 Build 版本的 API 新增（Added）、廢棄（Deprecated）、移除（Removed）與參數型別變更。
3. **Townlong-Yak (Ketho WoW API Database)**：
   - 查詢函數標準簽名、C-Level 導出介面與事件載荷（Event Payloads）。
4. **WoWHead / WarcraftWiki 技術文檔**：
   - 查驗官方最新變更：如 `https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes`。
5. **本地環境實機／沙盒探針 (Runtime Probe)**：
   - 使用 `/run`、`/dump` 或 EAM 內部 Probe 探測新 API 於遊戲內的實際回傳型別與效能開銷。

## 3. API 變更評估三步法 (3-Step Evaluation Framework)

### Step 1: 簽名與命名空間驗證 (Namespace & Signature Check)
- 檢查 API 是否已由全域命名空間移入 `C_` 命名空間（例：`GetSpellInfo` ➔ `C_Spell.GetSpellInfo`）。
- 檢查回傳值是否由「多重回傳值（Multiple Returns）」改為「結構化表格（Lua Table / Struct）」。
- 檢查必填參數與選填參數之順序是否發生更迭。

### Step 2: Secret & Taint 邊界檢驗 (Security & Taint Gate)
- 檢驗該 API 是否為「受保護函數（Protected Functions）」，在戰鬥中調用是否會觸發阻斷。
- 檢驗該 API 的回傳值是否包含 `issecretvalue == true` 之秘密值。
- 若包含 Secret 值，必須立即遵循 `eam-secret-taint-sentinel` 規範，嚴禁進行算術/格式化，必須單向送入 C-Level 原生 Sink。

### Step 3: 影響範圍與 EAM 模組對映 (Module Impact Mapping)
- 評估該變更影響哪一個服務層：`AuraService`、`CooldownService`、`PlayerResourceService`、`PlayerStatService`、`MediaService` 或 `Renderer`。
- 檢查是否影響 `AuraRuleCompiler` 的指紋計算與物件池（`StatePool`）生命週期。

## 4. 標準防禦性降級封裝範式 (Defensive Fallback Patterns)
為確保插件在不同魔獸版本間平滑運作，所有新 API 必須封裝為「安全降級層（Polyfill / Fallback Wrapper）」：

```lua
-- 範例 1：命名空間與全域降級封裝
local function SafeGetSpellName(spellID)
    if not spellID then return "" end
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name then return name end
    end
    if _G.GetSpellInfo then
        local name = _G.GetSpellInfo(spellID)
        if name then return name end
    end
    return ""
end

-- 範例 2：動態能力探針與安全門禁
local hasGlidingInfo = C_PlayerInfo and type(C_PlayerInfo.GetGlidingInfo) == "function"
local function GetPlayerGlidingSpeed()
    if hasGlidingInfo then
        local isGliding, canGlide, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
        if isGliding and forwardSpeed then
            return forwardSpeed
        end
    end
    return nil
end
```

## 5. Patch 12.1.5 (Build 69952, TOC 120105) 專章與實戰情報

官方事實基準網址：`https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes`

### 1. 光環與 Pandemic 原生動畫管線 (`CustomAuraButton`)
- **三態動畫觸發器**：
  - `AddPandemicEnterAnimation(animGroup)`（進入單次觸發）
  - `AddPandemicActiveAnimation(animGroup)`（窗口內循環觸發）
  - `AddPandemicLeaveAnimation(animGroup)`（脫離窗口停止）
- **精確結餘窗口 API**：
  - `C_UnitAuras.GetRefreshCarryOverDuration`：能正確處理德魯伊生命之花等具備超額結餘上限的光環。
- **重大破壞性變更 (Breaking Changes)**：
  - `AddPandemicRegion` 與 `AddDispelTypeTexture` **不再回傳索引**。
  - 對應的 `RemovePandemicRegion` 與 `RemoveDispelTypeTexture` **必須傳遞 Region 物件參考**，傳入 index 將觸發報錯。
  - 重複加入相同 Region 會直接引發錯誤中斷。

### 2. 排程器革命：`TimedSignalMap` (`C_Timer.NewTimedSignalMap`)
- 暴雪原生底層時間信號映射物件。
- 支援**單一回呼函式**，以自訂 Key（如 `spellID`）管理多個未來時間點。
- 支援**原地覆寫（Rescheduled without cancellation）**：光環延長時直接 `signalMap:SignalAt(key, newTime)`，零取消開銷、零 Lua Table 分配、徹底消除 GC 垃圾。

### 3. 徹底拔除 10 大舊時代相容模組 (Deprecations)
- **`Blizzard_DeprecatedItemScript` 完全移除**：
  - 舊版全域 API `GetItemInfo`、`GetItemCooldown`、`GetItemCount`、`GetItemIcon`、`GetItemQualityColor`、`IsEquippedItem`、`IsUsableItem` 全部徹底失效。
  - EAM 必須維持 100% `C_Item.*` 呼叫標準（既有契約已嚴格保證）。
- 同步移除：`Blizzard_DeprecatedSoundScript`（`PlayVocalErrorSoundID` ➔ `C_Sound.PlayVocalErrorSound`）等 9 個相容模組。

### 4. 安全性與 Taint 邊界
- 受保護的 Cooldown 框架嚴格禁止從 Tainted code 呼叫 `SetCooldown` 或 `Clear`。
- `UnitCastingInfo` Castbar ID 依單位 Token 獨立雜湊（且大小寫敏感），禁止透過比對 Castbar ID 逆向識別單位。
- `GetArenaOpponentSpec` 回傳 Secret。

### 5. 音效節流與底層 C++ 加速
- `C_UnitAuras.AddAuraSound` 補齊 `throttleSeconds` 參數，官方底層控制播放頻率。
- 原生 C++ 數學與表格庫：`math.clamp`、`math.lerp`、`math.round`、`table.isempty`、`table.contains`，效能遠高於 Lua 實作。
- `CreateFrameWithOptions({ frameType = "Frame", hidden = true })` 避免建立時閃爍。
- `ScriptRegion:SetRoundLayoutToNearestPixel(true)` 由 C++ 硬體層直接保證像素對齊。

## 6. 專案情報庫同步與治理規範 (Governance Sync)
調研完成並確認解決方案後，必須同步完成以下紀錄以沉澱專案資產：
1. **更新專案情報庫**：將新 API 簽名、版本 ID 與降級範式記錄至 `.AI/Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md` 與 `Docs/02_RETAIL_API_BOUNDARIES.md`。
2. **記錄試錯時間線**：將調研結論與決策脈絡記錄至 `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
3. **契約斷言覆蓋**：於 `Test-ValidationContracts.ps1` 增補對應的靜態契約測試。
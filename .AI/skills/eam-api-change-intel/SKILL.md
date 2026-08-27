---
name: eam-api-change-intel
description: >-
  World of Warcraft (WoW) Retail 12.x / PTR / XPTR 最新 API 變更調研、版本相容性分析與防禦性封裝指南。涵蓋 Wago.tools/Blizzard Interface 原始碼比對、Secret/Taint 屬性檢定、跨版本降級包裝（Fallback Wrappers）與專案情報庫同步。
---

# EAM API Change Intelligence (WoW 最新 API 變更與情報調研技能)

本技能規範 EventAlertMod 在面對 World of Warcraft (WoW) 各客戶端（Retail 12.1+、PTR 12.1+、XPTR 12.0.7+ 或未來重大 Patch）時，進行 API 變更調研、相容性評估與防禦性封裝的標準作業程序。

## 1. 觸發時機
- 暴雪發布新的遊戲版本、Build 號更新或大型 Patch。
- 發現既有 API 回傳 `nil`、報錯 `attempt to call global (a nil value)` 或行為異常。
- 評估是否引入暴雪最新釋出的 `C_` 系列現代化 API（如 `C_DurationUtil`、`C_PlayerInfo`、`C_Spell` 等）。
- 排查跨版本（Retail vs PTR vs XPTR）客戶端相容性問題。

## 2. 五大權威調研源與探測路徑 (Authoritative Sources)
調研 API 時，必須嚴格依序比對以下五大權威資料源，嚴禁未經查證之憑空猜測：
1. **暴雪官方 UI 開源庫 (Blizzard Interface Code)**：
   - 檢索官方 FrameXML、SharedXML 與最新 UI 程式庫（GitHub `GetWarcraft/ref`、`Ketho/Blizzard_InterfaceExport`）。
2. **Wago.tools API Browser & Diffs**：
   - 比對跨 Build 版本的 API 新增（Added）、廢棄（Deprecated）、移除（Removed）與參數型別變更。
3. **Townlong-Yak (Ketho WoW API Database)**：
   - 查詢函數標準簽名、C-Level 導出介面與事件載荷（Event Payloads）。
4. **WoWHead / WarcraftWiki 技術文檔**：
   - 查驗社群回報的特殊行為、返回值邊界與已知 Bug。
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

## 5. 專案情報庫同步與治理規範 (Governance Sync)
調研完成並確認解決方案後，必須同步完成以下紀錄以沉澱專案資產：
1. **更新專案情報庫**：將新 API 簽名、版本 ID 與降級範式記錄至 `.AI/Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md` 與 `Docs/02_RETAIL_API_BOUNDARIES.md`。
2. **記錄試錯時間線**：將調研結論與決策脈絡記錄至 `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
3. **契約斷言覆蓋**：若引發架構變更，於 `Test-ValidationContracts.ps1` 增補對應的靜態契約測試。
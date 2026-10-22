---
name: eam-api-change-intel
description: >-
  World of Warcraft (WoW) Retail 12.x / PTR / XPTR 最新 API 變更調研、版本相容性分析與防禦性封裝指南。涵蓋 Wago.tools/Blizzard Interface 原始碼比對、Secret/Taint 屬性檢定、跨版本降級包裝（Fallback Wrappers）與專案情報庫同步。
---

# EAM API Change Intelligence (WoW 最新 API 變更與情報調研技能)

本技能規範 EventAlertMod 在面對 World of Warcraft (WoW) 各客戶端（Retail 12.1+、PTR 12.1.5+、XPTR 12.0.7+ 或未來重大 Patch）時，進行 API 變更調研、相容性評估與防禦性封裝的標準作業程序。

## 1. 觸發時機
- 暴雪發布新的遊戲版本、Build 號更新或大型 Patch（如 Patch 12.1.5）。
- **每輪開發需求與派工子代理前必查**：強制探訪 `https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes` 檢視最新 PTR Build 演進。
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
   - 查驗官方最新變更：如 `https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes`（當前基準：PTR 3 Build 69952）。
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

## 5. Patch 12.1.5 (Build 69594 ~ 70077, TOC 120105) 專章與實戰情報

官方事實基準網址：
- 官方變更總表：`https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes`
- 官方開發注意事項：`https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes/notes`

### 📅 PTR 1 (2026-09-03, Build 69594)
- **原生 Pandemic 動畫管線 (`CustomAuraButton`)**：
  - `AddPandemicEnterAnimation(animGroup)`（進入補 DoT 窗口單次觸發）、`AddPandemicActiveAnimation(animGroup)`（循環發光/脈動）、`AddPandemicLeaveAnimation(animGroup)`（脫離窗口停止）。
  - 新增受限切面：`QueryAnimationProgress`（禁止查詢動畫進度或運行狀態）與 `AddAnimations`（禁止動態追加或重設 Parent）。動畫物件自帶 `ChangeAnimationTarget` 切面。
- **Region 傳參與破壞性變更**：
  - `AddPandemicRegion` 與 `AddDispelTypeTexture` 不再返回 index，重複加入同一 Region 會拋出 Fatal Error。
  - `RemovePandemicRegion(region)` 與 `RemoveDispelTypeTexture(region)` 改傳 Region 物件參考。
  - `CustomAuraButton:SetCasterName(fontString)`：原生字串綁定施法者名稱。
  - CVar：`tooltipShowAuraCasterNames`（顯示光環施法者名稱並依陣營/職業著色）。
  - `CustomAuraContainer` 控制：`SetAuraGroupEnabled`、`SetAuraSlotEnabled`、`SetItemEnchantmentEnabled`、`SetEditModePreviewEnabled`、`minApplications`。
- **安全防禦與受保護冷卻框架**：
  - 受保護 Cooldown 框架（Protected Cooldown Frames）禁止從 Tainted 程式碼調用 `SetCooldown` 與 `Clear`。
  - Castbar ID 改為依 unit token 大小寫唯一化（例如 `"PLAYER"` vs `"player"`），事件統一採用小寫 unit token。
- **C++ 排程器革命 (`TimedSignalMap`)**：
  - `C_Timer.NewTimedSignalMap(callback)`：單一回呼支援數千 key 原位 `SignalAt` 重設，零 GC 壓力。
  - `TimerUtil.CreateTimedSignalCallbackMap()`：官方 FrameXML 封裝工具。
- **底層原生 C++ 工具與佈局**：
  - `CreateFrameWithOptions({ frameType = "Frame", hidden = true })` 避免閃爍。
  - `ScriptRegion:SetRoundLayoutToNearestPixel(true)` 像素對齊，取代 Lua `PixelUtil`。
  - 暴雪底層 C++ 加速函式：`math.clamp`、`math.saturate`、`math.round`、`math.lerp`、`math.normalize`、`math.sign`、`math.remap`、`math.wrap`、`math.isfinite`、`math.isnan`、`math.isinf`；`string.contains`、`string.ltrim`、`string.rtrim`、`string.startswith`、`string.endswith`；`table.isempty`、`table.contains`、`table.indexof`、`table.removeunordered`、`table.removevalue`、`table.keys`、`table.values`。
- **拔除 10 大舊時代相容模組**：
  - `Blizzard_DeprecatedCurrencyScript`、`Blizzard_DeprecatedGlue`、`Blizzard_DeprecatedItemScript`、`Blizzard_DeprecatedItemSocketInfo`、`Blizzard_DeprecatedLFG`、`Blizzard_DeprecatedPetInfo`、`Blizzard_DeprecatedPvpScript`、`Blizzard_DeprecatedSoundScript`、`Blizzard_DeprecatedTradeInfo`、`Blizzard_DeprecatedWorldElapsedTimerTypes` 徹底移除。
- **全新命名空間**：`C_Weather` (`GetCurrentWeather`, 事件 `WEATHER_CHANGED`) 與 `C_Intl`（Unicode / 國際化庫）。

### 📅 PTR 2 (2026-09-16, Build 69848)
- **`CustomAuraButton` 完整生命週期動畫**：
  - `AddAuraShownAnimation(animGroup)`（初次顯示時觸發，隱藏時停止）。
  - `AddAuraAssignedAnimation(animGroup)`（指派新光環時觸發，不論是否可見）。
- **Secret Aspects 擴展**：
  - `Enum.SecretAspect.VertexColor` 與 `Enum.SecretAspect.TexCoords` 納入受限切面，避免透過頂點著色或 UV 逆向刺探戰鬥秘密。
- **安全防護與單位框架工具庫 (`UnitFrameUtil`)**：
  - Damage Meter 的 `sourceGUID` 當身分受保護時變為 Secret。
  - 引入 `UnitFrameUtil` 官方函式庫，提供 `UpdateUnitPvPIndicator` 等安全渲染通道。
  - `C_Intl` 支援 Tainted 秘密字串（但禁止 `Null`/`Remove` 轉譯），索引改為 1-based。
  - Enemy Nameplate 獲得額外 1 幀命中框調整窗口 (`UNIT_CLASSIFICATION_CHANGED`)。
- **音效節流保護**：
  - `C_UnitAuras.AddAuraSound` 支援選填 `throttleSeconds`。
- **雜項優化**：
  - Chat tab 移除 `UIFrameFlash` 以降低全域 Taint。
  - `C_ClassColor.GetClassColor` 支援可選 tint。
  - `GetPlayerInfoByGUID` 額外回傳等級。
  - 恢復 CVars：`nameplateMotionSpeed`、`nameplateBottomInset`、`nameplateTopInset`。

### 📅 PTR 3 (2026-09-22, Build 69952)
- **競技場敵方專精 Secret 化**：
  - `GetArenaOpponentSpec` 回傳 Secret；須透過 `UnitFrameUtil.GetArenaOpponentSpecDisplayInfo`、`UpdateArenaOpponentSpecDisplay`、`UpdateArenaOpponentSpecDisplayName` 安全顯示。
- **角色職責圖示安全通道**：
  - `UnitFrameUtil.GetUnitRoleIconDisplayInfo` 與 `UpdateUnitFrameRoleIcon`（皆支援 `textureMap` 自訂貼圖）。
- **`C_UnitAuras.GetRefreshCarryOverDuration` 精準結餘**：
  - 官方提供精準 Pandemic Carry-Over 計算（如生命之花 + 寧靜超額延長），解決自製 30% 臨界值計算偏差。

### 📅 PTR 4 (2026-09-29, Build 70077, 官方最終 PTR 基準)
- **`C_UnitAuras.AddAuraSound` 安全防禦限縮**：
  - 播放的音效檔案長度強制限制最長 5 秒。
  - `throttleSeconds` 參數若大於 5 秒將直接拒絕（Reject）。EAM 預設傳入 `0.3s`，完全處於合規安全區。
- **`C_Intl.GetSortKey` 容錯加固**：
  - 修復傳入空字串與 `Enum.CollationStrength.Primary` 時回傳 `nil` 之異常。

### 📊 12.1.5 Consolidated Changes 統計與 EAM 設計對齊
- **Global API**: 新增 82 個（含 `C_ActionBar.IsMacroActionWithShowTooltip`、`C_Timer.NewTimedSignalMap`、`C_UnitAuras.GetRefreshCarryOverDuration`、`C_Weather.GetCurrentWeather`、C++ 原生 utility 庫等），移除 4 個（舊 Training Grounds 與 TableUtil 冗餘 API）。
- **FrameXML**: 新增 29 個（`ChatFrameUtil.*`、`UnitFrameUtil.*`、`TimerUtil.*`、`MarchingAnts_*` 等），移除 15 個（舊版全域 Lua 實現遷移至 C++ 庫）。
- **ScriptObjects**: 新增 30 個（`TimedSignalMap` 8 個方法、`LocaleContext` 22 個方法）。
- **Widgets**: 新增 2 個（`ScriptRegion:GetRoundLayoutToNearestPixel` / `SetRoundLayoutToNearestPixel`）。
- **Events**: 新增 1 個（`WEATHER_CHANGED`）。
- **CVars**: 新增 12 個（`dumpSmallAlloc`、`tooltipShowAuraCasterNames`、`minimapShowPlayerCoords`、`coordsByTenths`、`CAAPulsePlayerHealthPercent`、`CAAPulsePlayerHealthVolume`、`nameplateMotionSpeed` 等）。

## 6. 專案情報庫同步與治理規範 (Governance Sync)
調研完成並確認解決方案後，必須同步完成以下紀錄以沉澱專案資產：
1. **更新專案情報庫**：將新 API 簽名、版本 ID 與降級範式記錄至 `.AI/Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md` 與 `Docs/02_RETAIL_API_BOUNDARIES.md`。
2. **記錄試錯時間線**：將調研結論與決策脈絡記錄至 `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
3. **契約斷言覆蓋**：於 `Test-ValidationContracts.ps1` 增補對應的靜態契約測試。
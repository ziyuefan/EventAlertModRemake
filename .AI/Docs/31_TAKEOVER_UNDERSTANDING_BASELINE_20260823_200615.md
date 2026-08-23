<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 31. Antigravity 接手理解基準檔 (Baseline Assessment)

- **文檔編號**：`31_TAKEOVER_UNDERSTANDING_BASELINE_20260823_200615.md`
- **基準時間**：2026-08-23 20:06:15 (+08:00)
- **維護代理**：Antigravity (Lead Developer + WoW AddOn Engineer + Lua Performance Engineer)
- **工作分支**：`agy/main`
- **專案根目錄**：`D:\Project_EventAlertMod_AGY`
- **當前驗證狀態**：OFFLINE VERIFIED (Syntax 64/64, Flow 82/82, Contracts 493/493)

---

## 1. 專案背景與定位

本專案為 **EventAlertMod (EAM) 的 Retail 12.x (Midnight-era) 完整現代化重構版本**。
核心工程目標順序：

$$\text{正確性} > \text{WoW API 相容性} > \text{Runtime 穩定性} > \text{事件效率} > \text{GC 控制} > \text{CPU Latency} > \text{可維護性} > \text{功能擴充}$$

---

## 2. AI 治理體系與硬性邊界 (AI Governance & Boundaries)

```text
.AI/
├── AGENTS.md                   # 唯一最高指導原則 (禁止在根目錄重複建立第二套規範)
├── PROJECT_MEMORY.md           # 專案事實、連續性與未驗證項目追蹤
├── Data/
│   ├── ProjectContinuity.json  # 機器可讀連續性狀態
│   ├── LiveValidationMatrix.json# 37 案實機簽收矩陣 (嚴禁離線 Mock 冒充實機通過)
│   └── wow_spells_and_auras.json# 外部爬蟲候選資料 (嚴格隔離，禁止 TOC/Lua 載入)
├── Docs/                       # 36 份架構、API、效能、變更情報與除錯歷史文件
└── Tools/                      # 語法檢查、Flow 測試、靜態契約檢驗腳本
```

### 硬性邊界守則：
1. **單一有效工作目錄**：唯一有效根目錄為 `D:\Project_EventAlertMod_AGY`；舊目錄 `D:\EventAlertMod` 徹底廢棄，嚴禁讀取、寫入、比對或作為 fallback。
2. **Reparse Point 絕對保護**：部署工具在探索 `D:\World of Warcraft` 之各版本客戶端目錄時，若目標或其父層為 SymbolicLink / Junction / Reparse Point，必須立即 **Fail-Closed** 中止操作，嚴禁刪除、覆蓋或重建連結。
3. **雙軌證據鏈隔離**：
   - **離線全綠 (Offline Verified)**：代表 Lua AST、Flow 狀態機、靜態契約通過。
   - **實機驗證 (Requires WoW 12.1 Runtime)**：涉及畫面呈現、Taint、安全框架動作時，一律列入 `LiveValidationMatrix.json` 待玩家實機簽收。
4. **外部候選資料隔離**：`wow_spells_and_auras.json` 標記為 `webCandidate`，由 `Test-WowheadCandidateData.ps1` 獨立檢驗，嚴禁被 TOC 引用或進入執行期。
5. **隱私脫敏與 WTF 備份**：
   - 任何路徑或日誌中包含 WTF、Account、磁碟絕對路徑者，執行期自動替換為 `[privacy-redacted]`。
   - 部署與還原工具內建 WTF 備份清單（Manifest），支援一秒完整還原。

---

## 3. WoW Retail 12.x / Midnight 底層防禦與效能規範

### 3.1 Secret Values 零洩漏防禦
- **不可讀原則**：戰鬥中的保護值（如 `UnitPowerPercent`、Aura 持續時間、冷卻時間）屬於 Secret/Protected。
- **操作禁忌**：嚴禁在 Lua 中對 Secret 值進行 `> 0` 比較、`string.format` 格式化、`..` 字串拼接、算術運算、序列化或作為 Table Key。
- **Write-Only Sink 通道**：
  - 資源百分比：直接透過 `pcall(StatusBar.SetValue, bar, percent)` 注入 Blizzard 原生 C 層控制項。
  - 充能資訊：以 `readChargeField` 進行欄位級安全檢查，安全保留 `isActive` / `maxCharges`，受保護的目前充能數直送 StatusBar。
  - 持續時間：透過 `Core/DurationAdapter.lua` 建立原生 `DurationObject` 與 `DurationTextBinding`，由 C 層驅動計時文字與 Swipe 動畫。

### 3.2 Taint (污染) 物理隔離
- **無安全操作**：EAM 框架僅作視覺呈現，絕不承擔 secure/protected 點擊或巨集執行。
- **單一孤兒 Frame 接收事件**：`Core/EventRouter.lua` 採用無父級孤兒 Frame，禁止將自訂 callback 掛入 Blizzard 原生安全鏈。
- **戰鬥中鎖定防護**：`InCombatLockdown()` 為 true 時，嚴禁修改 Frame 父級、錨點、尺寸、層級或執行結構性 Layout 重排，所有變更自動標記 `combatRebuildDeferred` 於脫戰合併執行。

### 3.3 零 OnUpdate 與極致 GC 控制
- **0 Frame OnUpdate**：全插件杜絕任何分散式的 `SetScript("OnUpdate")` 或 per-icon ticker，統一由 `Core/Scheduler.lua` 中央低頻排程。
- **預分配物件池 (Object Pooling)**：
  - `AuraService.AuraStatePool`：預先分配 80 個狀態物件，戰鬥中零 Table 建立。
  - `Renderer.timerTokenPool`：重用計時 Token，杜絕閉包 (Closure) 建立。
  - `Util.warningStringCache`：快取邊界警報字串，杜絕動態字串拼接垃圾。
- **Table Freeze 策略**：所有列舉、靜態契約、別名表（`EAM.API`）、字體樣式表、預設值在載入完成後一律使用 `table.freeze` 固化，防止意外污染並提升 JIT 執行效率。

---

## 4. 模組架構與資料流解耦

```mermaid
flowchart TD
    subgraph Event_Layer [事件接收層]
        E[WoW Events] --> ER[Core/EventRouter.lua<br/>Numeric Array O(1) 分派 / pcall 容錯]
    end

    subgraph Service_Layer [事實服務層]
        ER --> AS[Services/AuraService.lua<br/>增量 UNIT_AURA 處理 / 80-Item Pool]
        ER --> CS[Services/CooldownService.lua<br/>UNIT_SPELLCAST_SUCCEEDED 精確施法門禁]
        ER --> PRS[Services/PlayerResourceService.lua<br/>17 資源 / 40 專精 / DK 6 符文獨立槽位]
        ER --> GES[Services/GroundEffectService.lua<br/>Base-Override 族群編譯]
        ER --> OTS[Other Services<br/>Item, Totem, Tooltip, Sound]
    end

    subgraph Management_Layer [決策協調層]
        AS & CS & GES --> AM[Managers/AlertManager.lua<br/>BeginBatch / EndBatch 單幀合併節流]
        AS --> ARC[Managers/AuraRuleCompiler.lua<br/>優先級 1..20 正規化 / 雙指紋比對]
    end

    subgraph View_Layer [視圖渲染層]
        AM --> R[UI/Renderer.lua<br/>7 大獨立告警框架 / IconPool / LibButtonGlow]
        PRS --> PR[UI/PowerRenderer.lua<br/>17 預建資源框架 / C 層 StatusBar 寫入]
        AS -.-> NAR[UI/NativeAuraRenderer.lua<br/>12.1 Native AuraContainer]
    end
```

### 4.1 核心亮點機制
1. **DK 6 符文槽位防護 (`Services/PlayerResourceService.lua`)**：
   - 監聽 `RUNE_POWER_UPDATE(runeIndex, added)`，只刷新單一變動槽位。
   - 使用 `if Util.isSafeBoolean(added) then ready = added end` 嚴格保留 `false`，徹底避免三元運算式 `added and ... or ...` 把 `false` 吞掉的經典 Bug。
2. **三態冷卻行為覆寫 (`Services/CooldownService.lua`)**：
   - `cooldownRemoveAura`、`showSCDOutsideCombat`、`glowSCDWhenUsable` 支援 `nil`（繼承全域）、`true` 或 `false`（單法術覆寫），明確保留 `false`。
3. **單幀批次排版 (`Managers/AlertManager.lua`)**：
   - 觸發告警更新時，透過 `Renderer.BeginBatch()` 凍結排版，遍歷所有變動後再由 `Renderer.EndBatch()` 一次性完成重排，防止同一畫面多個技能觸發時 CPU 頻繁重算幾何坐標。
4. **多語系即時切換 (`Locale/Common.lua` & `UI/Options.lua`)**：
   - 保持 `EAM.L` Table Identity，原地清除並合併 Fallback，透過註冊之 `bindText` 動態更新 UI 文字，**無需 `/reload` 立即生效**。

---

## 5. 版本發布與 GitHub 自動化體系 (AGY Track)

為了徹底區隔 Codex 治理版本並節省 Token，建立專屬發布流程：

### 5.1 產物命名規範 (嚴格保留原格式 + `_AGY` 後綴)
- **AddOn 插件包**：`EventAlertMod_MN_<TOC_DATE>_<TIMESTAMP>_AGY.zip`
- **AddOn 校驗檔**：`EventAlertMod_MN_<TOC_DATE>_<TIMESTAMP>_AGY.zip.sha256`
- **Source 源碼包**：`Project_EventAlertMod_SRC_<TIMESTAMP>_AGY.zip`
- **Source 校驗檔**：`Project_EventAlertMod_SRC_<TIMESTAMP>_AGY.zip.sha256`
- **GitHub Release Tag**：`alpha-7.4-AGY.<DATE>`

### 5.2 自動化指令
- **一鍵發布器**：`pwsh -NoProfile -File .\Deploy\Publish-GitHubRelease.ps1`
  - 自動執行離線門禁檢驗 (Syntax + Flow + Contracts)。
  - 自動產生帶 `_AGY` 後綴之 AddOn / Source 雙套件及 SHA-256。
  - 自動組裝結構化 Release Notes (附帶離線成績單、責任歸屬與一鍵回退 Codex 指引)。
  - 自動呼叫 `gh release create --prerelease` 完成發布。
- **一鍵分支同步與 PR**：`pwsh -NoProfile -File .\Deploy\Sync-GitHubBranch.ps1 [-CreatePR]`

---

## 6. 當前驗證基準點與簽收現況

| 檢驗項目 | 範圍 / 數量 | 結果 | 判定屬性 |
| :--- | :--- | :--- | :--- |
| **Lua 語法檢查** | 64 個 Lua 檔案 | `64/64 PASS` | OFFLINE VERIFIED |
| **Flow 流程測試** | 82 組能力案例 | `82/82 PASS` | OFFLINE VERIFIED |
| **Validation Contracts** | 493 項靜態契約 | `493/493 PASS` | OFFLINE VERIFIED |
| **候選資料隔離性** | `wow_spells_and_auras.json` | `23/23 PASS` | OFFLINE VERIFIED |
| **本地 WoW 環境探測** | Retail, PTR, XPTR | `3/3 PASS` | READY |
| **實機驗證矩陣** | 37 案真人實機觀察 | `37 案待實機回報` | REQUIRES_WOW_12_1_RUNTIME |

---

**本基準文檔由 Antigravity 於 2026-08-23 20:06:15 簽署並歸檔至 `.AI/Docs/`。**

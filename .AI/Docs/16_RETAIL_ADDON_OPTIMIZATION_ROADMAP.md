<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 正式服 AddOn 研究與 EventAlertMod 最佳化路線

本文件整理 2026-05-26 對魔獸爭霸 Wiki、暴雪論壇、WoWInterface、CurseForge 與 Reddit AddOn 討論的研究結果，規劃 EventAlertMod 正式服重寫的優化事項與目標。

本文件不是實機驗證報告。所有 Retail 12.x 行為仍需在 WoW Retail / PTR client 中載入測試。

## 調查來源

- 魔獸爭霸維基：`API_change_summaries`、`Patch_12.0.0/API_changes`、`Patch_12.0.5/API_changes`、`Patch_12.0.7/API_changes`10EAMCODE_9__。
- 暴風雪論壇：UI and Macro、Bug Report 中關於 Secret Values、UnitHealth、移動速度、PvP 記分板、blocked action / taint 的討論。
- WoWInterface：細胞、TweaksUI：冷卻時間、威脅板、ViksUI、物品升級品質圖示等午夜更新日誌。
- CurseForge：Midnight Sensei、MidnightSimpleAuras、Cooldown Cursor Manager、Cooldown Manager Loader、MidnightCD、Enhance QoL 等專案頁與變更記錄檔。
- Reddit：r/wow、r/WowUI、r/wowaddons、r/CompetitiveWoW 中關於 12.0 / 12.0.5 / Midnight AddOn API 的網絡與作者回饋。

## 最新API結論

- 12.0.0 是 Secret Values 與 AddOn 對抗 API 限制的核心起點。
- 12.0.5對EAM最重要：API謂詞、`table.freeze`、`table.isfrozen`、格式化程式、DurationObject、光環欄位保密調整、冷卻時間`ignoreGCD`。
- 12.0.7 API 摘要已，TOC 為 `120007`；目前對 EAM 的直接核心影響較小，但新增 `C_DurationUtil.CreateDurationTextBinding` 存在、`C_DurationUtil.CreateManualClock`，並刪除 `C_DurationUtil.GetCurrentTime`。
- `GetEventCPUUsage`、`GetFunctionCPUUsage`、`GetScriptCPUUsage` 可作按需分析候选，不可放入热路径。
- Secret Values 不是單一欄位問題，而是受污染的執行路徑下的普遍限制；不能靠 `pcall`、比較失敗回退或工具提示抓取繞過。

## 社群與外掛趨勢

- 作者普遍從「閱讀光環/cooldown數值後自行判斷」轉向「讓暴雪小工具 / DurationObject 顯示」。
- 多個插件改為逐值 `issecretvalue` 檢查，不再只根據上下文標誌判斷是否受限。
- 一些光環正常運行時間類插件放棄戰鬥光環spellID比較，改用cast事件與安全窗口提示，但必須標記為派生，不可冒充光環事實。
- Cooldown類外掛明顯往Blizzard Cooldown Manager整合、DurationObject、cursor/HUD顯示與CDM設定檔輔助發展。
- 姓名板（Nameplate）、單位框架、PvP計分板、單位名稱 / GUID / UnitIsUnit、移動速度、生命值/power類資料在午夜中風險高，EAM 不應將它們納入核心警報匹配。
- 工具提示文字也可能包含秘密值；工具提示解析必須低頻、逐行檢查、失敗安靜降級。
- 污染/受阻動作仍然是常見的痛點；避免污染受保護的框架比事後壓制錯誤更重要。

## EAM 最佳化總目標

1. 保持EAM的輕量定位：簡單、spellID導向、比WeakAuras容易。
2. 將資料層改寫為「安全事實/衍生/displayOnly / boundaryWarnings」明確分離。
3. 渲染器以Blizzard widget / DurationObject 為優先，避免Lua 自行倒數與字串清理。
4.對Secret Values採逐值安全檢查，不依賴單一上下文保護。
5.盡量支援Blizzard Cooldown Manager生態，但不硬依賴外部插件。
6. 降低污染風險：不接安全動作、不修改保護框架、不掛鉤暴雪保護鏈。
7.所有debug/profiling/export都採按需，不進熱路徑。

## 優先權 P0：安全與相容底線
- TOC目前已固定`120007`；發布前需同步確認備份工具、CurseForge遊戲版本ID與實機驗證。
- 對AuraService、CooldownService、ItemCooldownService建立統一保密安全讀取適配器，避免各服務散落判斷。
- 禁止aura `spellID` 直接比較前未檢查秘密；若不安全，狀態轉為`boundaryLimited`。
- 禁止工具提示列未檢查就`string.match`。
- 渲染器不讀回冷卻幀獲取器作為事實。
- 戰鬥鎖定下延後任何可能影響框架結構的佈局變更。
## 優先權 P1：核心功能穩定化

- 玩家光環：首先支援安全絕對的自身buff/debuff；不安全時顯示圖示/name或受保護的計時器。
- 目標光環：只追蹤`target`，避免目標目標/焦點目標/姓名板延伸。
- 法術冷卻：使用`C_Spell`結構化回報；優先`DurationObject`；支持`ignoreGCD`。
- 物品冷卻：直接itemID監控；不做大規模物品掃描。
- 狀態模型：每個警報都明確標示`factsSafe`、`timer.mode`、`source.api`、`boundaryWarnings`。
- 偵錯快照：輸出事實/匯出/boundaryWarnings/環境，不輸出不安全的原始值。

## 優先權 P2：完全與低GC

- 將排程器任務表加入池，避免重複排程配置。
- AuraService 掃描改為“delta 優先 + 完整更新單位單次掃描”，避免每個警報重複掃描相同單位。
- 渲染器對`SetText`、`SetTexture`、`SetCooldown`、`SetPoint`全面值門控。
- 將圖示狀態與服務狀態物件重複使用，每次避免渲染建置新表。
- 按需分析可研究 12.0.7 CPU 用法 API，但預設為關閉。

## 優先 P3：使用者體驗

- 保留`/eam新增spellID`、`/eam刪除spellID`、`/eam偵錯`這樣簡單的語意。
- 選項只做必要功能：玩家光環、目標光環、法術冷卻、物品冷卻的新增/刪除與啟用切換。
- 加入「資料受保護」的簡單 UI 狀態，不向一般使用者顯示錯誤。
- 可選擇提供CDM相關輔助：開啟暴雪冷卻檢視器、提示使用者由CDM管理不適合EAM讀取的冷卻。

## 優先 P4：文件、測試與發布

- 更新`Docs/06_TEST_PLAN_RETAIL.md`：新增12.0.7、DurationObject、秘密工具提示、污染日誌、戰鬥鎖定測試。
- 建立專案專用 SKILL 候選：
  - EAM 資料夾與版本同步。
  - EAM WoW API 驗證與檔案回寫。
  - EAM Secret / Taint 審查。
  - EAM Lua靜態驗證與熱路徑掃描。
- 遇到工具限製或 API 陷阱，追加到 `Docs/15_DEVELOPMENT_ISSUE_LOG.md`。

## 不納入目標

- 不做戰鬥自動化。
- 不做WeakAura腳本引擎。
- 不做 PvP 敵人可點選框架。
- 不相信戰鬥日誌重建秘密事實。
- 不在戰鬥中重建受保護的佈局。
- 不要把工具提示抓取當成核心資料來源。
- 不支援Classic / MOP Classic / Cata / Wrath / Era。

## 下一步建議

1. 已完成P0安全讀取、渲染戰鬥延遲、調度任務池。
2. 已完成 P1/P2 初版：SavedVariables add/remove API、Slash add/remove、AuraService `UNIT_AURA`快照增補感知快取、除錯除錯。
3.已完成P2後半：AuraService全面更新單位系統單次掃描、選項最小可新增/remove面板。
4. P3已有實測結果：用戶於12.0.7 PTR客戶端確認`C_DurationUtil.CreateDurationTextBinding`最小樣本可正常顯示。
5.下一步應繼續實機驗證`UNIT_AURA` delta/full有效負載、DurationObject / DurationTextBinding整合、戰鬥佈局延遲、選項模板污染日誌。
6. 實機確認後再補舊 EAM group/special power 行為、Options 啟用切換與 CurseForge `120007` 遊戲版本 ID。

## 2026-07-26 路線狀態

- Phase 1/2：能力層、規則編譯、schema v2、Legacy 隔離與安全 scalar/key 防護已完成。
- Phase 3：player/target AuraContainer、Slot/Group、initializeFrame、脫戰 batch rebuild、Aura Sound 已完成 68914 契約 PoC。
- Phase 4：嚴格離線流程與遊戲內報告入口完成；本輪 `all` suite 為 17/17。
- 尚未完成：`_ptr_` 實機 RQA、taint/Forbidden、實際 sound、Reload UI 與效能簽收。

## 優先權 P5：組語視角底層極限最佳化（ASM-Inspired Optimization）

> **⚠️ 核心防禦鐵律（Zero-Side-Effects & Non-Regression Iron Rule）：**
> 所有底層效能優化僅限於「代碼執行效率、記憶體佈局與 JIT 快取親和性」，**絕對禁止改變任何既有業務邏輯、禁止引發任何副作用、禁止造成任何功能缺失或運行錯誤**。每一次底層調整必須 100% 通過 499+ 項合約與回歸驗證。

1. **虛擬暫存器釘定（Local Register Pinning）**：
   - 將熱路徑（Hot Path）中所有高頻呼叫的暴雪 API、全域輔助函式（如 `math.min`, `math.max`, `pcall`, `C_UnitAuras`）於模組頂部提升為 `local` 變數。
   - 使其在 Lua 虛擬機器中直接映射至虛擬暫存器（Virtual Registers），在 LuaJIT 編譯為直接 CPU 暫存器呼叫，徹底消除 `_G` 全域雜湊表尋址與記憶體解引用開銷。

2. **熱路徑暫存器壓力控制（Register Pressure & Spilling Guard）**：
   - 審查高頻事件處理常式（如 `onUnitAura`、`onTargetChanged`、`AlertManager.flushUpdates`、渲染器迴圈），將單一函式活躍的 `local` 變數數量精簡至 8~10 個以內。
   - 避免超過 x86_64 實體暫存器上限（16 個通用暫存器）而引發 Register Spilling（暫存器溢出至 Stack 記憶體）的額外 `mov [rsp], reg` 懲罰。

3. **深層指針鏈提升（Pointer Chasing Hoisting）**：
   - 消除熱迴圈內部的多層巢狀結構存取（如 `EAM.db.config.iconSize` 或 `icon.rendered.layoutX`）。
   - 在進入迴圈或高頻函式前將其提升為單層區域指標，保護 CPU L1/L2 Data Cache 預讀器（Hardware Prefetcher），消除跨堆（Heap）記憶體跳躍。

4. **連續整數陣列空間局部性（Array Part Spatial Locality）**：
   - 所有批次掃描、優先順序清單與池化容器，一律優先使用 `table.create(N, 0)` 建立連續整數陣列（`1..N`）。
   - 存取時直接對齊 C 語言連續記憶體指標偏移 `[R_base + R_index * 16]`，完全利用 CPU 64-Byte Cache Line 批次載入 4 個 `TValue`，杜絕雜湊桶離散分佈帶來的 Cache Thrashing。

5. **熱路徑零閉包（Zero Hot-Path Closures）**：
   - 徹底杜絕在熱路徑（`OnUpdate`、事件回呼、排程迴圈）中宣告匿名閉包函式 `function() ... end`，防止 Lua 每次動態 `malloc` 建立 Closure 物件與 Upvalue 表。
   - 一律採用靜態具名函式，上下文由參數（`self`, `data`）傳遞，使底層保持為純粹的函式跳躍（`call` 指令）。

6. **單一型態保護（Monomorphic Types & JIT Guard Stabilization）**：
   - 保持所有狀態物件欄位與函式回傳值型態絕對一致（Monomorphic），數值欄位預設給 `0` 或特定 Sentinel，不隨意在 `number`、`nil`、`boolean` 間震盪。
   - 防止 LuaJIT Trace Compiler 的型態守衛失敗（Guard Failure）引發 Trace Abort，使高頻代碼 100% 穩定常駐於 JIT 本機機器碼模式。


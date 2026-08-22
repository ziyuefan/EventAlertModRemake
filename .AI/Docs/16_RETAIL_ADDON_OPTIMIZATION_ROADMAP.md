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
- 銘牌、單位框架、PvP計分板、單位名稱 / GUID / UnitIsUnit、移動速度、生命值/power類資料在午夜中風險高，EAM 不應將它們納入核心警報匹配。
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
- 目標光環：只追蹤`target`，避免目標目標/焦點目標/銘牌延伸。
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

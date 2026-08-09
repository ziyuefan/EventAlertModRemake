<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod Retail 實機測試逐步指南

## 目的與邊界

本文件把 `Data/LiveValidationMatrix.json` 的 34 案轉成玩家可直接操作的條件、步驟與通過標準。它只適用 WoW Retail 系列：

- `_ptr_`：12.1 PTR。
- `_xptr_`：12.0.7 XPTR。
- `_retail_`：12.0.7 正式服。

所有遊戲輸入都由玩家親自完成。EAM 與 Codex 不施法、不使用物品、不執行巨集、不切換目標、不自動輸入 `/reload`，也不修改限制型 CVar。離線 mock、Lua 語法與契約測試不能取代本文件的實機觀察。

## 開始前共同條件

1. 關閉 WoW 後執行 `Tools/Test-LocalWoWEnvironment.ps1`，確認版本與 `Interface\AddOns\EventAlertMod` Reparse Point 仍指向 `D:\EventAlertMod`。不要對 AddOns 連結做部署、刪除或重建。
2. 開啟要測的客戶端，在角色選擇畫面確認 EAM 已啟用且沒有載入錯誤。
3. 進入遊戲後輸入 `/eam test live`，選擇目前實際執行的 PTR、XPTR 或 Retail。不要用 PTR 身分記錄 XPTR，也不要只依資料夾名稱猜測 Build。
4. 面板上每案先讀「測試條件／步驟」。結果只能選：`pass`、`fail`、`blocked`、`pending`。看不見、無法重現或缺少測試技能時用 `blocked`，不要猜成 `pass`。
5. 備註只寫觀察結果、Build、戰鬥狀態、觸發條件與錯誤類型。不要貼 WTF 絕對路徑、帳號、角色、伺服器或 Secret 原值。
6. 開啟 Lua 錯誤顯示。若出現 Lua error、taint、blocked action 或 Forbidden access，立即記錄當時案例、戰鬥狀態與重現步驟。
7. 完成前必須在面板建立 reload checkpoint，再由玩家親自輸入 `/reload`。同一次載入直接按續接不算跨 reload 證據。

## 面板操作方式

- `上一案／下一案`：切換案例，不改結果。
- `通過／失敗／受阻／待測`：只記錄目前案例。
- `備註`：最多 500 個字元；戰鬥中不寫入。
- `完成並產生 JSON`：只有 34 案全通過、環境身分一致、已有真正 `/reload`、零 boundary warning 才能完成。
- `全選實機 JSON`：只會聚焦並全選文字。WoW 沒有可用的 `EditBox:Copy()` API，仍須由玩家按 `Ctrl+C`。

## 逐案條件與步驟

### 1. `live.environment.identity`

- 條件：已選擇實際客戶端。
- 步驟：比對面板的 patch、Build、Interface、test-build 判定與登入畫面／實際安裝版本。
- 通過：PTR 顯示 PTR 身分，XPTR／Retail 顯示各自身分，沒有 mismatch warning。
- 回報：只需 patch、Build、Interface 與通道，不貼本機路徑。

### 2. `live.tooltip.spellbook`

- 條件：非戰鬥，技能書有可辨識法術。
- 步驟：滑鼠停在技能圖示，確認 Tooltip 顯示 Spell ID；保持滑鼠停留並按下 Ctrl+Alt，不需點右鍵；選「加入技能冷卻監控」。
- 通過：小視窗出現、ID 正確、加入後清單位置為技能冷卻；取消不寫入。

### 3. `live.tooltip.actionbar_macro`

- 條件：建立一個施法巨集與一個使用物品巨集，放到動作列。
- 步驟：分別停留圖示並按 Ctrl+Alt；觀察 EAM 是否取得動作列解析後的 spellID／itemID。含條件分支或無法唯一解析者可降級手動輸入。
- 通過：施法巨集不把 resolved spellID 誤當巨集索引；物品巨集能取得 itemID；無法解析時明示「尚未解析」，不填猜測值。

### 4. `live.tooltip.bag_item`

- 條件：非戰鬥，背包有具冷卻或可使用物品。
- 步驟：停留物品，確認 Item ID；按 Ctrl+Alt，選加入物品冷卻監控。
- 通過：寫入物品冷卻清單，ID 與物品一致；監控圖示滑鼠停留時能顯示物品 Tooltip。

### 5. `live.tooltip.player_aura`

- 條件：玩家身上同時準備一個 BUFF 與一個 DEBUFF。
- 步驟：停留右上 BuffFrame 的光環並按 Ctrl+Alt，分別加入玩家光環監控。
- 通過：12.1 可由官方 Aura Tooltip 流程取得候選；12.0.7 無能力時可手動輸入。EAM 圖示的玩家 BUFF 邊框為青色，玩家 DEBUFF 為紅色。

### 6. `live.tooltip.target_aura`

- 條件：選定可產生 BUFF／DEBUFF 的目標，非戰鬥。
- 步驟：停留 `TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras` 內的 AuraButton，看到官方 Tooltip 後按 Ctrl+Alt；選玩家或目標儲存位置。
- 通過：不讀取 forbidden AuraButtonTooltip 欄位仍可開啟小視窗；加入目標清單。目標 BUFF 邊框為藍色，目標 DEBUFF 為橙色。

### 7. `live.tooltip.out_of_combat`

- 條件：確定 `InCombatLockdown()` 為 false。
- 步驟：依序測技能、巨集、物品、玩家 Aura、目標 Aura。
- 通過：Ctrl+Alt 候選只對目前滑鼠停留來源出現，EAM 自有監控圖示可顯示對應 spell/item Tooltip。

### 8. `live.tooltip.in_combat_rejected`

- 條件：先清除候選，再由玩家進入戰鬥。
- 步驟：停留上述來源並按 Ctrl+Alt；再停留 EAM 監控圖示。
- 通過：不開加入視窗、不顯示 EAM 自有 Tooltip、不建立延後寫入；脫戰後不重播戰鬥中的候選。

### 9. `live.popup.escape_cancel`

- 條件：非戰鬥開啟 EAM 加入視窗。
- 步驟：分別按 ESC、取消與視窗關閉。
- 通過：三種方式都不增加 revision、不新增清單項目。

### 10. `live.popup.commit_added_unchanged`

- 條件：準備一個未監控 ID。
- 步驟：第一次加入，再用相同類型與 ID 重複加入。
- 通過：第一次回報 `added`，第二次回報 `unchanged`；revision 只在真正變更時增加。

### 11. `live.tooltip.reload_resume`

- 條件：至少完成一個加入操作與一個案例結果。
- 步驟：建立 checkpoint，由玩家輸入 `/reload`，回到遊戲後開面板。
- 通過：session 與監控清單保存，reloadSequence 增加，沒有把同次載入冒充 reload。

### 12. `live.blizzard_input_unchanged`

- 條件：EAM 已啟用。
- 步驟：對技能、動作列、物品與目標框 Aura 執行原本的左鍵、右鍵與無修飾鍵操作。
- 通過：Blizzard 原始行為不變；EAM 不 Hook 點擊、不攔截右鍵、不產生 secure action taint。

### 13. `live.popup.combat_transition`

- 條件：非戰鬥先開啟加入視窗。
- 步驟：不要按加入，由玩家進入戰鬥。
- 通過：視窗安全關閉或拒絕提交；脫戰後不自動寫入。

### 14. `live.tooltip.generation_switch`

- 條件：準備兩個不同來源。
- 步驟：快速從技能切到物品或從玩家 Aura 切到目標 Aura，再按 Ctrl+Alt。
- 通過：只開最新來源，不重播五秒前或 0.75 秒 Aura heartbeat 期限外的候選。

### 15. `live.api.load_order`

- 條件：全新登入與 `/reload` 各測一次。
- 步驟：立即開 Tooltip 流程與 Options，再等待 Blizzard LoD 模組載入後重測。
- 通過：PostCall、事件與按鍵監聽只註冊一次；無 nil API、重複加入或重複提示。

### 16. `live.errors.none_observed`

- 條件：整輪保持 Lua error 顯示。
- 步驟：回顧錯誤視窗與 taint/blocked action 訊息。
- 通過：沒有 Lua error、taint、blocked action、Forbidden access。若曾出現，即使功能看似正常也標 fail。

### 17. `live.layout.timer_anchor_size`

- 條件：準備一個有安全倒數的 Legacy 圖示與 PTR Native Aura。
- 步驟：至少測框內、框外、字級 8、14、32；每次提交 Native 設定後按套用／重建。
- 通過：倒數位置確實移動，不再一律留在框內；不出界、不被名稱遮住。

### 18. `live.layout.applications_anchor_size`

- 條件：準備可堆疊 Aura。
- 步驟：測框內八方向、框外八角與四面，字級 8、12、32。
- 通過：applications/stack 位置與大小依設定更新，單層／無層數時不顯示偽造數字。

### 19. `live.aura.single_countdown`

- 條件：關閉雙倒數診斷並重建 Native 容器。
- 步驟：觀察一個有限時間 Aura 從開始到最後 3 秒。
- 通過：正常模式只有一套倒數；12.0.7 Legacy 也只有一套。

### 20. `live.aura.dual_countdown_diagnostic`

- 條件：僅在測試面板開啟診斷模式。
- 步驟：觀察開始、中段與最後 3 秒兩套倒數。
- 通過：兩者同步且共用同一 DurationObject；這只是顯示交叉驗證，不是第二資料源。完成後必須關閉。

### 21. `live.cooldown.spell_countdown`

- 條件：監控一個非 GCD 技能與一個充能技能。
- 步驟：玩家施放，充能技能再消耗一層。
- 通過：圖示、swipe、倒數同時出現；技能邊框固定黃色；停留 EAM 圖示可顯示 Spell Tooltip。

### 22. `live.cooldown.item_trigger`

- 條件：監控一個可用背包物品。
- 步驟：由玩家使用，觀察 BAG_UPDATE_COOLDOWN／12.1 對應事件。
- 通過：正確 itemID 觸發，其他物品不誤觸；邊框固定綠色；停留可顯示 Item Tooltip。

### 23. `live.ground.duration_auto`

- 條件：非戰鬥加入說明文字含明確秒數的地面技能。
- 步驟：先執行一鍵擷取，再由玩家施放。
- 通過：來源為 `spellDescription` 或 `tooltipDescription`，倒數符合靜態說明，邊框固定紫色。

### 24. `live.ground.duration_manual_fallback`

- 條件：選擇無法解析秒數的地面技能並設定手動秒數。
- 步驟：擷取應明確失敗，再由玩家施放。
- 通過：來源為 `manualFallback`、使用手動秒數、報告含 `groundDurationManualFallback`，不偽造 Tooltip 秒數；邊框仍為紫色。

### 25. `live.visual.swipe_alpha`

- 條件：準備技能、物品、地面效果與 PTR Native Aura。
- 步驟：分別設 0、0.5、1；Native Aura 每次提交後重建。
- 通過：四類 swipe 透明度符合設定，文字與固定色邊框不跟著消失。
- 色框附加簽收：自身 BUFF 青、自身 DEBUFF 紅、目標 BUFF 藍、目標 DEBUFF 橙、技能黃、物品綠、地面效果紫；classPower 與 totem 維持既有外觀。

### 26. `live.aura.target_transition`

- 條件：PTR 12.1，準備有限／永久、單層／多層、不同施法者的目標 Aura。
- 步驟：切換目標、進出戰鬥並讓各狀態轉換。
- 通過：圖示、官方顯示型倒數與 applications 正常更新；若「有圖示但文字空白」，記錄是哪種轉換，不讀回 FontString。

### 27. `live.aura.native_border_capability`

- 條件：PTR 12.1。
- 步驟：查看 capability 報告與官方驅散材質。
- 通過：只把 `AddDispelTypeTexture` 稱為官方驅散／靜態 border 能力；不得宣稱能任意取代 Pandemic 或 Proc Glow。EAM 七色類型邊框是獨立的靜態 Texture。

### 28. `live.aura.native_pandemic_region`

- 條件：PTR 12.1，監控可進入 Pandemic Window 的 Aura。
- 步驟：啟用一個 Pandemic Region，由玩家觀察顯示與消失。
- 通過：Blizzard 管理更新，EAM 不讀 `SecretAspect.Shown`、不建立自己的每圖示 OnUpdate；12.0.7 安靜降級。

### 29. `live.aura.native_dispel_options`

- 條件：PTR 12.1，準備 Helpful/Harmful 與可偷取 Aura。
- 步驟：測 `showAlways`、Helpful/Harmful、Stealable/NotStealable。
- 通過：`showAlways` 不再同時輸出無效 stealableFilter；不使用舊 AuraBorder alias。

### 30. `live.aura.container_disable_clear`

- 條件：PTR 12.1，Native Aura 已顯示。
- 步驟：停用 AuraContainer，再重新啟用。
- 通過：AuraButton 與 ItemEnchantment 顯示資料被清除，框架本體可重用，不重複建立、不用 OnSizeChanged 推測 Aura 數量。

### 31. `live.unitpower.secondary_numeric`

- 條件：使用能產生次要資源的專精。
- 步驟：玩家產生、消耗、歸零 HolyPower、ComboPoints、SoulShards、Chi 或 ArcaneCharges。
- 通過：EAM 選到正確次要資源，數值 1 不被當 false。生命之花等單一法術堆疊不屬 UnitPower，應由 Aura 模組測試。

### 32. `live.unitpower.primary_native_sink`

- 條件：先在 Live panel 選對客戶端，再開 UnitPower 能力探針。
- 步驟：玩家自行產生／消耗主要資源；觀察 StatusBar 與 radial sink，再標記人工視覺結果。
- 通過：PTR 12.1 Secret 值只單向送入允許的 C-level sink，不做 Lua 比較、字串化或匯出；法師只有法力時仍可測主要 mana 視覺，但不會得到可讀 Lua 數字。

### 33. `live.unitpower.combat_deferred`

- 條件：PTR／XPTR，探針或模組已在戰前建立。
- 步驟：玩家進戰並改變資源，然後脫戰。
- 通過：戰鬥中不以 Lua 讀取／比較 UnitPower 值；允許的原生 sink 可顯示；需要結構變更者排到脫戰且只重播一次。

### 34. `live.aura.duration_zero_regression`

- 條件：PTR 12.1 PTR8，準備永久、零時間或瞬間結束 Aura。
- 步驟：觀察官方 duration text 與 EAM 圖示。
- 通過：有效 duration 不再錯顯示 0；無安全 duration 時只保留官方允許的圖示／顯示狀態，不自行補數字。

## 本輪附加 Smoke Test

這些項目不增加 34 案數，但本輪發布前至少各看一次：

1. 主視窗右上「關於」按鈕可開啟小視窗。
2. 關於視窗顯示插件版本、作者 `ziyuefan死鬥`、API 基準 `12.1.0 PTR 8 (Build 69189)`、12.0.7 相容軌、目前客戶端 Build、GitHub 與 Pages URL。
3. 戰鬥中不開啟關於視窗。
4. 開發報告、實機 JSON、診斷資訊按鈕只全選文字；玩家按 Ctrl+C 後沒有 `attempt to call a nil value`。
5. EAM 監控的 Aura／技能／物品圖示在非戰鬥顯示 Tooltip，戰鬥中拒絕；classPower 與 totem 不把 powerType／slot 誤當 spellID。

## 從 SavedVariables 取得報告

WoW 只有在玩家輸入 `/reload` 或正常登出後，才會把最新 SavedVariables 寫到磁碟。畫面上剛產生 JSON 但尚未 reload 時，磁碟檔仍可能是上一版。

由玩家完成 `/reload` 後，可在開發端唯讀匯入：

```powershell
pwsh -NoProfile -File .\Tools\Import-EAMFlowReport.ps1 `
  -Path '<該客戶端 WTF\...\SavedVariables\EventAlertMod.lua>' `
  -ReportType Flow
```

需要其他報告時把 `Flow` 改成 `Live` 或 `UnitPower`。匯入器會重算摘要、驗證 client identity、schema、privacy 與 raw flag；它不會修改 WTF。不要把含帳號路徑的完整命令或 SavedVariables 原檔提交到 Git。

## 回報格式

回報至少包含：

- client：PTR／XPTR／Retail。
- patch、Build、Interface。
- case ID。
- 戰鬥內或戰鬥外。
- 操作前置條件與實際步驟。
- 預期與實際差異。
- 是否有 Lua error、taint、blocked action、Forbidden access。
- JSON 報告；若用 WTF 匯入，註明已在產生報告後執行 `/reload`。

## SVG 能力測試（PTR 12.1 優先）

1. 玩家自行 /reload，非戰鬥中輸入 /eam test。
2. 在測試面板選擇正確 client；PTR 12.1 選 _ptr_。
3. 點 SVG 能力。左格是 VectorGraphics，右格是 Texture。
4. 確認兩格是否都出現相同青色外框與黃紫三角。每格分別按通過、失敗或受阻，不可只看 accepted。
5. 點完成並產生報告，回傳完整 EAM_SVG_CAPABILITY_REPORT JSON。報告應有 patch、build、Interface、兩案 clearReload 與 visualObservation，且 rawFileIDsCollected=false。
6. 若要從磁碟回灌，完成報告後再由玩家自行 /reload；匯入時使用 ReportType SVG。
7. 12.0.7 回報 unsupported 是預期能力降級；PTR 12.1 若 unsupported、set rejected、clearReload fail 或圖樣缺失，才需列為 PTR 問題。

同一輪另確認分類邊框：自身 BUFF／DEBUFF、目標 BUFF／DEBUFF、技能、物品、地面效果的四邊應完整連續，外緣各比圖示多 3px。請附 client、UI scale、圖示大小與截圖。

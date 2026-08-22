<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod Retail 實機測試逐步指南

## 目的與邊界

本文件把 `Data/LiveValidationMatrix.json` 的 37 案轉成玩家可直接操作的條件、步驟與通過標準。它只適用 WoW Retail 系列：

- `_ptr_`：12.1 PTR。
- `_xptr_`：12.0.7 XPTR。
- `_retail_`：12.1 正式服。

所有遊戲輸入都由玩家親自完成。EAM 與 Codex 不施法、不使用物品、不執行巨集、不切換目標、不自動輸入 `/reload`，也不修改限制型 CVar。離線 mock、Lua 語法與契約測試不能取代本文件的實機觀察。

## 開始前共同條件

1. 關閉 WoW 後執行 `.AI/Tools/Test-LocalWoWEnvironment.ps1`；本次要測的客戶端必須回報 `status=pass` 且實體目錄含 `EventAlertMod.toc`。Reparse Point 一律停止；實體目錄缺 TOC 代表尚未部署完整，不可開始實機簽收。
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
- `完成並產生 JSON`：只有 37 案全通過、環境身分一致、已有真正 `/reload`、零 boundary warning 才能完成。
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

### 6. live.tooltip.target_aura

- 條件：選定可產生 BUFF／DEBUFF 的目標，非戰鬥；不要右鍵，也不要檢查或 hook TargetFrame/AuraButton。
- 步驟：將滑鼠移入 TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras 的 AuraButton，在官方 Tooltip／heartbeat 仍新鮮時按 Ctrl+Alt；選玩家或目標儲存位置。
- 若沒有彈窗：執行 /eam doctor，只回報 auraCallbackCount、lastAuraCallbackAt、lastAuraCandidateAt、auraCandidateExpiredCount、lastTryOpenReason、lastModifierKey/down 與 CVar read/set 結果；不要貼出 raw AuraData、Secret、Frame 或猜測 ID。
- 明確手動 fallback：輸入 /eam add target 開啟 EAM 目標光環手動視窗，貼入已知 Spell ID 後按「加入目標光環監控」；/eam add target <spellID> 仍保留直接新增路徑。
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

### 35. `live.aura.sound_added`

- 條件：PTR 12.1，選一個可反覆取得的 player 或 target Aura；全域音效啟用，細部設定只勾「光環新增」，素材可清楚辨識。
- 步驟：玩家自行取得 Aura，保持期間做一般更新，再讓它移除後重新取得。不要用測試按鈕代替真實 Aura 事件。
- 通過：每次從不存在變為存在只播放一次；一般更新、層數變化與移除不誤播。報告包含 build、unit 與人工聽覺結果。
- 12.0.7：控制不可用但設定保留，且不得呼叫 `AddAuraSound`。

### 36. `live.aura.sound_applications_increased`

- 條件：PTR 12.1，使用能安全重複疊層的 Aura；細部設定只勾「層數增加」。
- 步驟：玩家先取得一層，再逐次增加、維持相同層數、降低層數與完全移除。
- 通過：初次新增不播放；每次實際增加 applications 各播放一次；相同、降低與移除不播放。不得由 EAM Lua 讀回或比較 Secret applications。
- 12.0.7：維持 capability 降級，不合成層數事件。

### 37. `live.aura.sound_removed`

- 條件：PTR 12.1，細部設定只勾「光環移除」。
- 步驟：分別測自然到期與玩家實際驅散／解除；另測停用模組、改設定、重建容器與 `/reload`。
- 通過：每次真實 Aura 移除只播放一次；停用、設定同步、容器清除與 `/reload` 不得冒充移除。若 API 對驅散與到期行為不同，記錄為實機事實。
- 另測 `fromPlayer`／極性較窄的規則：同 unit+SpellID 其他來源若 over-fire，記錄 `UnitAuraSoundInfo` 無 caster／auraFilter 的限制，不以 Lua 繞過。
- 12.0.7：控制不可用且零 12.1 API 呼叫。

## PTR 69273 追加回報步驟

### A. UnitPower 能力報告

1. 在 PTR 12.1 build 69273、非戰鬥狀態開啟流程面板，確認環境列為 PTR、patch 12.1.0、Interface 120100，再啟動 UnitPower 能力。
2. 在 primary native percent 案，玩家自行改變主要資源；法師可用法力，施放或消耗任一會改變法力的技能即可。只看 StatusBar／radial 是否跟著變化，不讀數值、不複製 Secret 值。
3. 在 selected safe or native 案，依面板提示選定資源並自行產生、消耗、歸零；同樣只觀察原生 widget。
4. 每一案都要按顯示正常、顯示異常或無法測試。報告若仍是 visualObservation=pending 或 status=incomplete，代表尚未完成簽收，不是 pass。
5. 停止探針後再複製 JSON；若要由開發端讀取磁碟 SavedVariables，先 /reload 或正常登出，否則可能仍是舊報告。

### B. 1079 首格排序

1. 在目標 Aura 清單開啟 1079 撕扯的條件設定，確認 priority；數字越大代表越優先、會進入較前的 native slot。
2. 若不希望 1079 第一格，把 1079 priority 調低並把另一個目標 Aura 調高，儲存後 /reload。
3. 回到目標框架確認順序；priority 相同時以 SpellID 作穩定次排序。回報時附 priority 值與 client/build，不要只回報圖示位置。

### C. 主題按鈕

1. 脫戰開啟主視窗，依序選 EAM、FF7、Windows XP、Windows 7、Windows 10、Windows 3.1、Borland C++ IDE、DOS CRT、倚天中文、Red Alert、macOS Aqua。
2. 每一主題檢查主視窗、About、Tooltip popup、Flow、Live、SVG、UnitPower、Prompt 的按鈕 normal、滑入 highlight、按下 pushed、disabled、文字、底色及四邊 2px 邊框；Borland 應為亮藍底亮黃字，DOS CRT 應為黑底綠字，其餘新增主題也須可辨識。
3. 進戰鬥時嘗試切換，確認只保存 pending；脫戰後才套用。完成 /reload 後再確認設定仍保留。
4. 不需要檢查暴雪 Action Bar 或其他插件按鈕；主題範圍只包含 EAM 自有 UI。

### D. 語系即時切換

1. 玩家更新到含本功能的程式後先自行 `/reload` 一次，確保本次載入已包含新的 Locale binding；Codex 與 EAM 都不自動輸入指令。
2. 非戰鬥中同時開啟主視窗、About、功能模組、Flow／Live、UnitPower／SVG 與 Prompt 面板；可在 Tooltip 有安全 candidate 時一併開啟 EAM popup。
3. 選擇 `Русский`，不要 `/reload`。目前已開啟面板的固定標題、按鈕、下拉標籤、環境摘要與案例狀態應立即改成俄文；已輸出的聊天紀錄不會倒回改寫，後續 EAM 訊息才應使用俄文。
4. 選擇固定英文的 `Auto Detect`，不要 `/reload`。在 zhTW 客戶端應立即回到繁體中文；Blizzard UI、其他插件及客戶端回傳的法術／物品名稱不受 EAM catalog 控制。
5. 再選 `Русский`，由玩家自行 `/reload`，重新開啟主視窗確認仍為俄文；這一步只驗證 `EAM_DB.config.language` 保存，不是動態套用的前提。
6. 回報 clientChannel、patch、build、Interface、兩次即時切換結果與 reload 保存結果；截圖不得包含帳號、角色或 WTF 絕對路徑。

### E. 玩家多資源正式路徑

1. 更新插件後由玩家脫戰執行 `/reload`，開啟 EAM 主設定的「圖示位置與能量設定」，再進入玩家資源面板。
2. 先測最小代表集：法師 Mana、戰士 Rage、野性德魯伊 Energy＋ComboPoints、暗影牧師 Insanity、死亡騎士 Runes＋RunicPower；其後逐職業／專精檢查面板列出的所有 `UnitHasPowerType` 可用資源。
3. 每項資源分別產生、消耗與歸零；確認多資源同時出現時各有獨立 frame、排序與幾何，不會互相覆蓋或只留下第一項。
4. 逐項切換前景、背景、數值文字，並調整位置、縮放、alpha、前景／背景透明度、寬高、圖示大小、間距與 order。普通數字可顯示文字；Secret 值只要求狀態列正確變化，不應由 Lua 顯示或匯出 raw 數字。
5. 修改專精覆寫後按重設，確認回到職業預設且其他專精不受影響；切換專精、德魯伊變形、登入／進出世界後重新檢查。
6. 在戰鬥中重複資源變化，確認既有狀態列持續更新；戰鬥中切換專精／結構設定時只延後重建，脫戰後套用一次，不得出現 Lua error、taint、blocked action 或 Forbidden access。
7. 關閉玩家資源模組後確認所有資源立即隱藏且不再讀取；重新啟用後於安全時機恢復。
8. 複製開發報告，確認只含 key、powerType、token、capability、顯示設定與計數，不含 current、max、percent 或可反推 Secret 的原值。
9. UnitPower capability probe 另行測試；`statusBarSink=accepted` 只代表 setter 未拒絕，不得替代正式玩家資源面板的 visual pass。

## 本輪附加 Smoke Test## 本輪附加 Smoke Test

這些項目不增加 37 案數，但本輪發布前至少各看一次：

1. 主視窗右上「關於」按鈕可開啟小視窗。
2. 關於視窗顯示插件版本、作者 `ziyuefan死鬥`、API 基準 `12.1.0 PTR 8 (Build 69189)`、12.0.7 相容軌、目前客戶端 Build、GitHub 與 Pages URL。
3. 戰鬥中不開啟關於視窗。
4. 開發報告、實機 JSON、診斷資訊按鈕只全選文字；玩家按 Ctrl+C 後沒有 `attempt to call a nil value`。
5. EAM 監控的 Aura／技能／物品圖示在非戰鬥顯示 Tooltip，戰鬥中拒絕；classPower 與 totem 不把 powerType／slot 誤當 spellID。

## 從 SavedVariables 取得報告

WoW 只有在玩家輸入 `/reload` 或正常登出後，才會把最新 SavedVariables 寫到磁碟。畫面上剛產生 JSON 但尚未 reload 時，磁碟檔仍可能是上一版。

由玩家完成 `/reload` 後，可在開發端唯讀匯入：

```powershell
pwsh -NoProfile -File .\.AI\Tools\Import-EAMFlowReport.ps1 `
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

1. 玩家自行 `/reload`，確認已載入修正版後，在非戰鬥中輸入 `/eam test`。
2. 在測試面板選擇正確 client；PTR 12.1 選 `_ptr_`。
3. 點「SVG 能力」。左格是 VectorGraphics，右格是 Texture；兩格都應出現青色外框與黃紫三角。
4. 逐格按「顯示正常／顯示異常／無法測試」。`SetSVG=accepted` 只證明呼叫被接受，不能取代目視。
5. 點「完成並產生報告」，回傳完整 `EAM_SVG_CAPABILITY_REPORT` JSON；報告必須含 patch、build、Interface、兩案 clearReload、visualObservation，且 `rawFileIDsCollected=false`。
6. PTR 12.1 正常欄位：
   - VectorGraphics：`setResult=accepted`、`hasSVG=true`、`fileIDClass=positive-number|zero|negative-number`、`clearReload=pass`、`visualObservation=pass`。
   - Texture：`setResult=accepted`、`hasSVG=unavailable`、`fileIDClass=unavailable`、`clearReload=pass`、`visualObservation=pass`。
7. VectorGraphics 的 `fileIDClass=zero` 不需單獨判失敗；Texture 沒有 HasSVG／GetSVGFileID 也不需判失敗。若 Texture `clearReload=unavailable`，表示仍是 Alpha 3 舊探針，必須更新並 `/reload` 後重跑。
8. Texture 沒有 introspection，因此 `clearReload=pass` 表示 ClearSVG 與重新 SetSVG 呼叫成功，最終 reload 圖樣由人工目視確認；報告不能宣稱 Lua 已讀回清除瞬間的像素。
9. 若要從磁碟回灌，產生報告後再由玩家自行 `/reload`；匯入時使用 `ReportType SVG`。12.0.7 回報 unsupported 是預期能力降級。

同一輪另確認分類邊框：自身 BUFF／DEBUFF、目標 BUFF／DEBUFF、技能、物品、地面效果的四邊應完整連續，外緣各比圖示多 3px。請附 client、UI scale、圖示大小與截圖。

## 2026-08-13 Alpha 4：模組與職業 profile 實機追加步驟

這是 37 案以外的 Alpha 4 發布後追加檢查，不改變真人矩陣的案例編號：

1. 開啟 EAM 主設定，按「功能模組」，確認八個模組預設為啟用。
2. 逐一停用一個模組；確認該模組既有提醒消失、其他模組仍正常，重新啟用後只在允許的脫戰時機恢復。
3. 在戰鬥中嘗試切換模組，確認設定保存但結構性 Native 變更延後至 PLAYER_REGEN_ENABLED，沒有 taint 或 blocked action。
4. 以至少兩個不同職業登入，執行 /eam list、/eam lookup <名稱>、/eam lookupfull <完整名稱> 與 /eam showcast；確認列出的清單只屬目前職業。
5. 清空一個職業的清單後 /reload，確認不會重新灌入內建預設；切換回另一職業，確認其設定未被污染。
6. Alpha 5 可使用主設定的 Profile 匯出；只接受以 EAMAP1: 開頭的正式字串，不要貼入 Debug JSON，也不要執行任何外部 Lua。
7. 每個客戶端均記錄 client channel、build、Interface、/reload、Lua error、taint 與 blocked action；離線通過不得改寫成實機 pass。

## 2026-08-14 Alpha 5：Profile、字型與動態語系追加步驟

這些步驟不改變 37 案矩陣總數，須在 PTR 12.1、XPTR 12.0.7、Retail 12.1 各自執行：

1. 非戰鬥中開啟 Profile 面板，匯出目前職業一個 module，確認字串以 EAMAP1: 開頭；玩家自行 Ctrl+C，不把帳號、角色或絕對路徑貼入報告。
2. 先按 Preview，確認 add／update／unchanged／conflict 計數；以 Merge 套用後檢查 revision 只增加一次，再以另一份 scope 做 Replace，確認只改指定 class／module。
3. 在戰鬥中嘗試 Apply，應拒絕或顯示待脫戰，不得重建 Native 結構或產生 taint；脫戰後重新 Preview／Apply。
4. 逐一選 STANDARD、ARIALN、MORPHEUS、SKURRI，確認計時、堆疊與名稱文字的字形／大小仍在圖示預期位置；/reload 後確認設定保存。
5. 切換 zhTW、zhCN、enUS、koKR、ruRU 與固定英文 Auto Detect，確認 EAM 主視窗、按鈕、下拉、條件與專精選單即時刷新；不要以 Blizzard UI 或歷史聊天文字判定 EAM 失敗。
6. 回報必須附 client channel、build、Interface、是否 /reload、Lua error／taint／blocked action、codec preview／apply 結果與語系／字型目視觀察。Codex 不自動操作 WoW。

## 2026-08-14 Retail 12.1／Aura catalog／Profile UI 追加步驟

這些項目不增加 37 案數；Retail／PTR 12.1 與 XPTR 12.0.7 都要由玩家操作並附 build／Interface。

1. 開啟語系、字型、主題、音效、方向、文字位置、專精與 AuraSound 下拉選單；每列在未 hover 時須可見，hover／按下／disabled 狀態與目前主題一致。
2. 從主設定按「Profile 匯入／匯出」。匯出長字串後以滾輪、捲軸 thumb、上下箭頭、Home／End／PageUp／PageDown移動；文字不可越過 viewport，狀態與六顆 footer 按鈕固定。
3. 確認小地圖的 `Trade_Engineering` 齒輪完整位於金色追蹤圈內，不得是左上空圈加右下齒輪；再測左鍵開關、右鍵診斷、拖曳與 `/reload` 保存。若仍錯位、綠塊、問號或聲音圖示，回傳截圖、client、build 與 UI scale。
4. 在自身 Aura 清單新增一個目前職業可用 Aura，打開齒輪確認「僅玩家施放」已勾選；在目標 Aura 重複一次，也應預設勾選。
5. 將可安全解析但非目前職業的 Aura 加入自身清單，確認它出現在跨職業增減益且「僅玩家施放」預設未勾選；不可因此刪除原有使用者資料。
6. 在批次視窗貼入 `有效ID1;有效ID2；有效ID3` 並混入換行、重複 ID、文字與不存在正整數；按一鍵加入後只出現有效唯一 ID，沒有空白項或 Lua error。
7. 按「載入目前 ID」與「全選複製」，由玩家按 Ctrl+C；編輯文字後 pending preview 應失效，不可套用舊 plan。
8. Retail／PTR 12.1 觀察 player／target Native Aura；XPTR 12.0.7 觀察 Legacy。三者都測戰鬥內外與 `/reload`，記錄 taint、blocked action、Forbidden access 與 boundaryWarnings。
9. Wowhead candidate JSON 不在遊戲中載入，也不會自動新增預設；任何新增預設仍須另有客戶端法術／Aura ID 實機證據。

## 2026-08-14 Alpha 6：小地圖圈內對齊與發布後冒煙測試

這些步驟不增加 37 案數，Release 安裝後由玩家在 Retail／PTR 12.1 與 XPTR 12.0.7 執行：

1. 確認安裝的是 GitHub `alpha-6` 資產，完成 `/reload` 後再開 EAM；不得用仍載入記憶體的 Alpha 5 畫面簽收。
2. 對照同一小地圖上的標準圓形按鈕，確認 EAM 齒輪位於金色圈中心且未超出；金圈不得偏到左上、齒輪不得落在右下圈外。
3. 以 64%、100% 與玩家常用 UI Scale 截圖；同時確認左鍵、右鍵、拖曳、滑入高亮與 `/reload` 位置保存。
4. 打開語系與十一主題下拉，確認未 hover 文字與按鈕四態／2px 邊框仍正常，避免小地圖插入修正造成 UI 回歸。
5. 回報 client channel、patch、build、Interface、UI Scale、Lua error／taint／blocked action與畫面結果；離線 394/394 不能取代此目視簽收。

## 2026-08-21 玩家資源設定回報補充

- 新版程式載入後先由玩家手動 /reload 一次，確保測試的是本輪程式；這不是每次改設定的必要步驟。
- 非戰鬥設定：修改 enabled、showPercent、fontFamily、orientation 或 threshold 後，直接觀察畫面，不要 /reload。預期 EAM_PLAYER_RESOURCE_CONFIG_CHANGED -> topology rebuild -> renderer 套用。
- 戰鬥設定：先改一次或連續改多次，確認不在戰鬥中做結構性重建；離開戰鬥後只套用一次。回報 service lastConfigResult 是否為 combatRebuildDeferred，再回報 visualObservation。
- 若非戰鬥仍需 /reload，請提供 resource key、PTR／XPTR／Retail、patch、build、Interface、戰鬥狀態、Lua error／taint／blocked action、以及改設定前後的畫面差異。
- 這些條件標記為 REQUIRES_WOW_12_1_RUNTIME；offline Flow 的 topologyReady 與 sink accepted 不能取代玩家視覺簽收。

## 2026-08-21 玩家資源 ResourceProbe／sampler 補充

1. 玩家更新插件後先手動 `/reload`，確認測試面板顯示目前 PTR、XPTR 或 Retail 的 patch、build、Interface；這次 `/reload` 只代表載入新程式，不是設定變更的必要條件。
2. 啟動 PlayerResourceProbe，先測正常事件：法師 Mana、戰士 Rage、野性德魯伊 Caster／Cat／Bear／Moonkin、暗影牧師 Insanity、死亡騎士 Runes／RunicPower，再擴展到面板列出的所有職業／專精資源。每項記錄 `tracked`、`available`、`foreground`、`background`、`capability`、`sinkAvailable`、`eventObserved`，不讀或複製 raw power。
3. 正常事件被觀測後，確認該資源沒有啟動 background sampler。只有在測試流程明確標記背景事件缺失時，才啟用單一 demand-driven sampler；記錄 sampler 啟動／停止、0.5 秒節流、戰鬥中延後與事件恢復後退出。
4. 測試德魯伊四種形態與專精切換，確認前景／背景資源切換、Energy／ComboPoints 不被強制放到第一格，且既有資源不被整批拆除。
5. 脫戰修改 enabled、font、size、orientation、anchor、position、threshold；不得 `/reload` 才生效。戰鬥中修改只於 `PLAYER_REGEN_ENABLED` 合併一次；停用模組後確認 frame 與所有 PlayerResourceService／Probe 事件均解除註冊。
6. XPTR 12.0.7 另行確認 numeric legacy adapter 與 StatusBar fallback；不得把 12.1 Secret sink 能力或 offline adapter result 冒充 XPTR 視覺通過。
7. 回報必附 client channel、patch、build、Interface、combat、是否手動 `/reload`、ResourceProbe JSON、sampler 狀態、visualObservation、Lua error／taint／blocked action。`unitpower.background_sampler_gate` 與靜態 contract 已離線通過；真人報告仍需人工判讀，不能由 fixture 代填。
 
## 2026-08-23 技能冷卻 exact-cast／非批量顯示回歸測試

本節是新增的實機回歸步驟，不把離線 cooldown.combat_heal_regen_no_bulk_render 當成客戶端通過。Retail／PTR 12.1 與 XPTR 12.0.7 各做一次；測試前先確認目前載入的是本輪插件，開發版只需手動 /reload 一次。

1. 在「技能冷卻監控」清單建立兩個可實際施放的技能 A、B；另準備一個不在清單內的治療技能 H。記錄 client channel（Retail／PTR／XPTR）、patch、build、Interface、combat 狀態。
2. /reload 後先不施放 A 或 B，觀察冷卻區；預期不因初始化、refreshAll 或清單存在而出現任何已啟動圖示。
3. 戰鬥中施放不在清單內的 H，接著離開戰鬥觸發 PLAYER_REGEN_ENABLED；預期 A、B 都不會因治療、脫戰或刷新批量出現。
4. 只由玩家本人成功施放 A（不是寵物、目標、他人或僅開始施法）；預期只有 A 進入 render，B 維持未啟動。若 A 沒有成功施放，不應以 SPELL_UPDATE_COOLDOWN 或 /reload 補開。
5. A 已啟動後切換戰鬥內／外、變身或觸發形態事件；預期 A 的啟動狀態保留，B 不被打開。只有停用冷卻模組或刪除 A 時才允許清除 A 的啟動狀態。
6. 在全域設定與 A 的齒輪設定逐一測試三項行為，記錄每次結果：
   - cooldownRemoveAura：關閉時冷卻完成不應被 service 無條件移除；開啟時完成後依設定移除。
   - showSCDOutsideCombat：關閉時脫戰隱藏、戰鬥中顯示；開啟時脫戰仍可顯示。
   - glowSCDWhenUsable：冷卻完成且技能可用時顯示可用高亮；不可用時不得只因計時到期強制高亮。
7. 對 A 逐一選擇 nil（全域）、true（單技能開）、false（單技能關），確認畫面與齒輪摘要正確；特別確認 false 在 /reload 後仍保留，不被 Lua and/or 預設語意吃掉。
8. 停用冷卻模組，確認 A 的啟動狀態與圖示清除；再啟用模組但不施放 A，預期不會自動恢復 A。重新施放 A 後才可再次 render。
9. 回報需附 A／B／H 是否在清單、實際施放者、戰鬥轉換、變身事件、三項設定值、是否 /reload、Lua error／taint／blocked action、畫面截圖與 visualObservation。任何離線 pass 只能標為 offline evidence。

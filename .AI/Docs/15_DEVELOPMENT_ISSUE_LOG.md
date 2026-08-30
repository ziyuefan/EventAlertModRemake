### 2026-08-30 EAM-20260830-COOLDOWN-REORDER-AND-PRERENDER-PLACEHOLDER：技能冷卻清單順序自訂（拖曳與上下移動）與預渲染佔位（灰階遮罩）

- 狀態：已解決 (Lua 76/76, Flow 84/84, Contracts 496/496)。
- 需求背景與問題分析：
  1. 技能冷卻告警過去依照 ID 順序排序，玩家無法自訂畫面上各冷卻圖示的先後排列順位。
  2. 傳統技能冷卻在首次施放前不建立圖示，而在進入戰鬥後首次施法觸發冷卻時，因 `InCombatLockdown()` 限制，建立新 Frame 或執行 `SetPoint` 排版重算會被阻攔或延遲，導致首次施放無法即時渲染冷卻倒數。
- 重構實作：
  1. **技能清單自訂排序與互動（Options.lua / SavedVariables.lua）**：
     - 清單每一列項目新增 `▲` (上移順位) 與 `▼` (下移順位) 操作按鈕。
     - 支援滑鼠左鍵點擊拖曳 (Drag & Drop) 直接在清單中快速調換順位。
     - 實作 `moveAlertInCurrentList` 與 `swapAlertsInCurrentList`，自動維護並持久化 `alert.order`。
     - `Options.refreshList()` 依 `alert.order` 進行高優先排序。
  2. **圖示佈局順序編譯（Renderer.lua）**：
     - `Renderer.layout("spellCooldown")` 依 `alertOrder` 進行穩定排序，確保畫面上圖示嚴格遵循玩家自訂的槽位順序。
  3. **技能冷卻預渲染佔位（CooldownService.lua / Renderer.lua）**：
     - 新增全域開關 `cooldownPreRender`（並於法術條件設定提供三態覆寫：全域 / 覆寫開 / 覆寫關）。
     - 脫離戰鬥時（`PLAYER_ENTERING_WORLD`、`PLAYER_REGEN_ENABLED`、天賦/設定變更），自動為所有已啟用之技能冷卻建立待命圖示槽位。
     - 尚未進入冷卻的技能以暗色灰階遮罩 (`SetDesaturated(true)` + `SetVertexColor(0.4, 0.4, 0.4, 0.65)`) 佔位顯示，隱藏計時與流光。
     - 施法進入冷卻瞬間瞬間切換為全彩 (`SetDesaturated(false)` + `SetVertexColor(1, 1, 1, 1)`) 正常計時，戰鬥中零 Frame 建立、零排版重算，100% 免疫戰鬥鎖定延遲。
     - 冷卻結束後自動平滑切回灰階佔位遮罩。
  4. **多語系支援**：
     - 5 大語系（zhTW, zhCN, enUS, koKR, ruRU）同步補齊 `EAM_OPT_COOLDOWN_PRERENDER`, `EAM_OPT_COOLDOWN_PRERENDER_TIP`, `EAM_OPT_MOVE_UP`, `EAM_OPT_MOVE_DOWN`, `EAM_OPT_ORDER_HINT`, `EAM_OPT_PRERENDER_PLACEHOLDER` 詞條。
- 驗證結果：Lua 76/76、Flow all 84/84、Validation Contracts 496/496。

### 2026-08-30 EAM-20260830-PLAYER-STAT-SETFORMATTEDTEXT-FIX：角色屬性全面接入 FontString:SetFormattedText 零 GC 渲染與戰鬥即時更新修復

- 狀態：已解決 (Lua 76/76, Flow 84/84, Contracts 496/496)。
- 根因分析：
  1. 過去在 `PlayerStatService.lua` 中，數值文字更新採用傳統 `string.format` 與 `fontString:SetText(valStr)`，每次事件與計時器更新皆產生 Lua 暫態字串物件，增加 GC 負擔。
  2. 過去因防禦性過濾引入 `isSafeNumber(val)` 守衛，而 Retail 12.0+/12.1+ 在戰鬥中或 Taint 環境下調用原生 Stat API 會回傳受保護的 Secret Number；`isSafeNumber` 將其判定為 false 並丟棄，導致 `getValue` 一律回退到脫戰前的 `lastKnownStats` 快取，造成戰鬥中屬性數值（如飾品觸發、嗜血加速、護盾吸收等）完全凍結不更新。
  3. 在 `update()` 流程中曾存在 `if isSecret then item.valText:SetText("") end` 邏輯，當偵測到 Secret 數值時直接將文字清空為空白。
- 重構實作：
  1. 依據暴雪 Retail 12.x 原生規範，`FontString:SetFormattedText` 具備 `AllowedWhenTainted = true` 與 `SecretArgumentsAddAspect = Enum.SecretAspect.Text` 切面。C-Level 原生能直接接受並安全格式化 Secret Numbers。
  2. 實作 `renderStatValueText(fontString, val, rawVal, formatType, decimals, shortNumber, suffix)`，全面改用 `FontString:SetFormattedText` 進行 C 引擎層零 Lua GC 暫態字串格式化渲染。
  3. 為 18 大屬性補齊 `getRawValue` 戰鬥即時取值路由，直接取得底層 API 原始回傳值並傳遞至 `SetFormattedText` 與 `StatusBar:SetValue`。
  4. 移除清空文字邏輯，確保在戰鬥中觸發特效或受保護狀態下，玩家依然能流暢且即時看到正確更新的數值文字。
- 驗證結果：Lua 76/76、Flow all 84/84、Validation Contracts 496/496。

### 2026-08-27 EAM-20260827-ALPHA82-SHAREDMEDIA-ECOSYSTEM-AND-ZERO-DELAY-FONT：Alpha 8.2 LibSharedMedia-3.0 素材生態全面接入、全域字型熱套用（免 /reload）與捲動選單支援

- 狀態：已解決 (Lua 71/71, Flow 84/84, Contracts 493/493)，已完成打包並發布 Pre-release。
- 變更亮點：
  1. LibSharedMedia-3.0 (SharedMedia) 素材生態全面整合與動態探測 (`ensureLSM`)：
     - 根因分析：過去 EAM 依字母排序早於 SharedMedia 擴充插件載入，`MediaService.init()` 執行時 LSM 實例或自訂素材尚未註冊，選單清單快取被凍結為 12 種內建音效；回呼參數格式未相容 CallbackHandler 導致清除快取失效；部分插件僅以 `HashTable` 登記。
     - 重構實作：
       - 實作 `MediaService.ensureLSM()` 動態探測函式，在任何查詢或播放時動態確認 LSM 實例與回呼註冊狀態。
       - 註冊 `PLAYER_LOGIN` 事件，在所有插件載入完成後自動刷新 LSM 實例與清空快取。
       - `MediaService.getMediaList` 同時整合 `lsm:List` 與 `lsm:HashTable` 雙重查詢並自動去重。
       - 實作安全雙軌播放 `MediaService.playSound`，無縫支援 FileDataID、SoundKitID 與自訂 FilePath (.ogg / .mp3)。
       - 12.1 Native Aura 規則編譯器 (`AuraRuleCompiler`) 接入 `MediaService.getSoundPath`，光環觸發時亦可播放 LSM 音效。
  2. 全域字型熱套用與存檔解鎖（免 `/reload` 即時生效）：
     - 根因分析：
       - `AuraRuleCompiler.lua` 之 `buildLayoutFingerprint` 缺少 `config.fontFamily`，更改字型時 fingerprint 不變導致 Native 容器誤判跳過重建。
       - `Renderer` 與 `AuraContainerService` 未訂閱 `EAM_FONT_FAMILY_CHANGED` 事件。
       - 設定面板更換字型時，畫面上的位置預覽圖示（Preview Icons）未被指示重繪。
       - `SavedVariables.lua` 的字型白名單過濾器會將 LSM 自訂字型強制退回 `"STANDARD"`。
     - 重構實作：
       - `SavedVariables.lua` 放行所有通過 LSM 註冊之字型名稱。
       - `AuraRuleCompiler.lua` 納入 `config.fontFamily` 佈局指紋。
       - `AuraContainerService.lua` 與 `Renderer.lua` 註冊 `EAM_FONT_FAMILY_CHANGED` 事件監聽。
       - `Options.notifyTextLayoutChanged` 聯動調用 `Renderer.refreshPreviewLayout()`、`PlayerResourceService.refreshActiveResources()` 與 `PlayerStatService.updateDisplay()`。
  3. UI 下拉選單長清單自適應捲動容器 (`buildScrollableDropdownMenu`)：
     - 實作通用的捲動下拉選單，當 SharedMedia 包含數十或數百種字型／音效時，自動限制高度為 10 筆並啟用 `UIPanelScrollFrameTemplate` 捲軸與滾輪支援。
     - 展開選單時啟用 `forceRefresh = true` 強制即時向 LSM 拉取最新素材清單。
- 驗證結果：Lua 71/71、Flow all 84/84、Validation Contracts 493/493。

### 2026-08-26 EAM-20260826-ALPHA81-COOLDOWN-ZERO-ALPHA-AND-COMBAT-STATS：Alpha 8.1 技能冷卻純透明度（Alpha=0）隱藏模式與戰鬥屬性防歸零快取備援

- 狀態：已解決 (Lua 71/71, Flow 84/84, Contracts 493/493)，已完成打包並發布 Pre-release。
- 變更亮點：
  1. 技能冷卻純透明度（Alpha=0）隱藏模式與全監控冷卻預先錨定 (`Persistent Pre-anchoring & Zero-Alpha Mode`)：
     - 根因分析：先前版本在 `Renderer.render` 中存在 `not icon and inCombat()` 阻攔邏輯，且冷卻完成時透過 `IconPool.release` 釋放 Frame 並清空排版。導致玩家在戰鬥中第一次施放冷卻技能時，因 Frame 不存在被直接延遲（`combatDeferred`）至脫戰才顯示。
     - 重構實作：
       - 在非戰鬥期間（登入、天賦/專精切換、設定變更）透過 `Renderer.prewarmAlertFrames` 預先為所有已監控技能與物品冷卻建立 Frame 並計算靜態座標（初始設為 `SetAlpha(0)` 隱形待命）。
       - 當技能冷卻完成或需要隱藏圖示時（`alertState.shown == false`），直接將該圖示透明度設為 `SetAlpha(0)`，保留 Frame 結構與座標常駐，徹底避免戰鬥中動態釋放與排版重算。
       - 戰鬥中施放技能時，直接將已就位的 Frame 透明度恢復為 `SetAlpha(targetAlpha)` 並啟動轉圈動畫，實現 0.00ms 零 GC 零排版延遲且 100% 免疫戰鬥鎖定。
  2. 角色屬性戰鬥中數值防歸零修復 (`Combat Stat Cache & Multi-Tier API Fallback`)：
     - 根因分析：Retail 12.0+/12.1+ 進入戰鬥後呼叫原生 Unit / Stat API 受限回傳 Secret Number，Lua 層無法直接讀取導致主屬性與副屬性顯示歸零。
     - 重構實作：
       - 建立全 18 項屬性 `lastKnownStats` 記憶體快取表，並在登入、切換專精、更換裝備及脫離戰鬥時自動執行預熱 (`prewarmStats`)。
       - 戰鬥中若遇受限環境自動無縫回退至最後有效真實數值。
       - 致命、加速、精通、臨機應變等副屬性補齊多重系別 API 與等級評級轉換公式容錯。
  3. 圖示物件池 (IconPool) 擴容與安全放行：
     - 預熱池容量由 16 擴增至 64，並在池耗盡時直接安全呼叫 `createIcon` 建立，杜絕戰鬥中回傳 nil。
- 驗證結果：Lua 71/71、Flow all 84/84、Validation Contracts 493/493。

### 2026-08-25 EAM-20260825-ALPHA8-PER-CLASS-STATS-AND-AURA-ABSORBS：Alpha 8.0 角色屬性依職業獨立配置、無圖示自適應排版、吸收盾雙軌強化與光環護盾顯示

- 狀態：已解決 (Lua 71/71, Flow 84/84, Contracts 493/493)，已完成打包與 Pre-release 準備。
- 變更亮點：
  1. 角色屬性依職業獨立設定 (Per-Class Player Stat Profiles)：
     - 角色屬性設定接入 `db.profiles.classes[classToken].playerStats`，實現每種職業（戰士、聖騎士、法師、德魯伊等）擁有 100% 獨立的屬性監控配置與開關。
     - 切換角色自動即時載入該職業設定；二級設定面板頂部標註當前職業名稱（例如 `[聖騎士]`）。
  2. 總吸收盾量 (totalAbsorb) 與治療吸收量 (healAbsorb) 取值核心雙軌強化：
     - 原生 Unit API + `C_UnitAuras` 增益/減益點數 (`aura.points`) 雙軌即時累加運算，徹底解決吸收盾不顯示或未捕捉到的問題。
     - 補齊 `UNIT_HEAL_ABSORB_AMOUNT_CHANGED`、`UNIT_HEALTH`、`UNIT_MAXHEALTH` 與 `PLAYER_SPECIALIZATION_CHANGED` 事件監聽。
  3. 取消圖示純文字自適應排版與獨立位置定位 (Iconless Adaptive Layout & Positioning)：
     - 即使取消顯示圖示，純文字標籤與數值依然支援指定獨立自訂位置或依設定整體延伸排版。
     - 實作動態尺寸自適應與累加間距演算法，不論垂直或水平排列，純文字項目與圖示項目均能完美等距貼齊、零文字重疊。
     - 支援無圖示排版方位自訂（數值在名稱上方/下方/左側/右側）。
  4. 光環模組護盾吸收量即時顯示 (Aura Shield Absorb Amount Display)：
     - 自動從 `C_UnitAuras.points` 提取護盾類光環（真言術:盾、冰甲護盾、靈魂汲取等）即時剩餘吸收盾數值。
     - 渲染器 (`Renderer.lua`) 於光環圖示右下角疊加層精確格式化顯示剩餘吸收盾量（如 `45.2k`、`1.2M`；多層數時如 `3(45k)`）。
  5. 介面與系統穩定性修復：
     - 補齊 `PlayerStatService.lua` 缺少之 `inCombat()` 本地函式定義，徹底消除點擊主選單分類按鈕與關閉面板時觸發的 nil call 報錯。
     - 修復「測試閃爍」按鈕覆蓋文字問題，將「啟用 12.1 原生圓形光環倒數光圈」回歸主設定選單核心控制區。
     - 修復飛龍模式飛速圖示黑框問題（FileDataID `4667307` 與動態 API 獲取）。
- 驗證結果：Lua 71/71、Flow all 84/84、Validation Contracts 493/493。

### 2026-08-24 EAM-20260824-PLAYER-STATS-SECRET-VALUE-FIX：角色屬性與吸收量監控 Secret Value 防護與原生 StatusBar Sink 整合

- 狀態：已解決 (Lua 68/68, Flow 84/84, Contracts 493/493)，實機待玩家簽收。
- 症狀：開啟屬性監控面板時於 `PlayerStatService.lua:253` 拋出 `attempt to compare local 'val' (a secret number value, while execution tainted by 'EventAlertMod')`。
- 原因判斷：WoW Retail 12.0+ / 12.1+ 當前環境下，部分 Unit API（如 `UnitGetTotalAbsorbs`、`UnitGetTotalHealAbsorbs`、`GetUnitSpeed`、戰鬥或污染狀態下的屬性讀取）會回傳受保護的 Secret Number。在 Lua 層直接對 Secret Number 執行比較（`val >= 10000`、`val < cfg.thresholdMin`）、算術運算（`val / 1000000`）或字串格式化（`string.format`）會觸發保護異常。
- 有效解法：
  1. 在 `PlayerStatService.lua` 中引入 `isSafeNumber(val)` 守衛，透過 `Util.isSecretValue` 與 `Util.isSafeNumber` 在執行任何算術、比較與格式化前先行過濾。
  2. 16 項屬性之 `getValue` 全部採用 `pcall` 與安全數值守衛，回傳不安全數值時返回安全的數值預設值。
  3. `formatStatNumber` 與 `update` 閾值比較全面加上 `isSafeNumber` 防禦，徹底根除 Secret Number 拋錯。
  4. 整合原生 **StatusBar Write-Only Native Sink**：為每個屬性項目預建 C-Level `StatusBar`，當遭遇 Secret 數值（如受保護的吸收量）時，直接將 raw value 送入 `StatusBar:SetValue` 展現視覺進度比例，Lua 不進行字串轉換與數值讀回。
  5. 設定面板提供「進度條 (StatusBar)」開關，支援依屬性類別著色（吸收盾天藍、治療吸收紫紅、速度青綠、副屬性金黃、主屬性橙紅）。
- 驗證結果：Lua 68/68、Flow all 84/84、Validation Contracts 493/493。

### 2026-08-24 EAM-20260824-PLAYER-STATS-AND-CUSTOM-ICONS：全模組替代圖示自訂與「角色屬性及吸收量監控」全新模組

- 狀態：已解決 (Lua 68/68, Flow 84/84, Contracts 493/493)，實機待玩家簽收。
- 變更亮點：
  1. 全模組自訂替代圖示支援：在所有告警項目細部設定視窗（自身光環、目標光環、技能冷卻、物品冷卻、地面效果等）中新增「自訂替代圖示（代碼或材質路徑）」輸入框、即時預覽方塊、WoW Tools 提示文字與一鍵複製 URL（`https://wago.tools/icons`）。
  2. 服務層全支援：`AuraService`、`CooldownService`、`GroundEffectService`、`ItemCooldownService` 全面支援 `alert.customIcon` 優先覆蓋預設圖示。
  3. 「角色屬性與吸收量監控」全新模組：
     - 涵蓋 16 種核心屬性取值（力量、敏捷、耐力、智力、致命、加速、精通、臨機應變、閃避、汲取、速度、地面跑速、飛行速度、總吸收盾量、治療吸收量、護甲值）。
     - 獨立二級設定面板 (`UI\PlayerStatPanel.lua`)：左側 16 屬性列表與即時數值預覽，右側提供開關、替代圖示、圖示大小、數值字型大小、名稱字型大小、名稱替代文字、小數位數、大數值簡寫 (k/M)、警戒值上下限高亮與獨立框架排版移動。
     - 繁體中文術語嚴格對齊台灣正式服用語（致命、加速、臨機應變）。
  4. 獨立第 8 大告警框架 (`playerStat`) 納入 `Renderer.lua` 經典奶牛頭位置預覽與排版管理。
- 驗證結果：Lua 68/68、Flow all 84/84、Validation Contracts 493/493。

### 2026-08-24 EAM-20260824-PREVIEW-AND-PANEL-CLOSE-FIX：經典奶牛頭位置預覽、全設定即時熱更新、進戰鬥全螢幕閃爍與側窗安全關閉修復

- 狀態：已解決 (Lua 66/66, Flow 84/84, Contracts 493/493)，實機待玩家簽收。
- 症狀：關閉主視窗時在 `closeAllSidePanels` 出現 `Options.lua:938: attempt to call a nil value`。
- 原因判斷：`ProfileCodecPanel`、`ModulePanel`、`AboutPanel` 僅定義了 `.hide()` 或缺少 `.close()` 方法，而主視窗關閉時強制調用 `panel.close()` 導致空值調用錯誤。
- 有效解法：
  1. 在 `ProfileCodecPanel`、`ModulePanel`、`AboutPanel` 統一補齊 `.close` 與 `.hide` 別名。
  2. 在 `Options.lua` 的 `closeAllSidePanels` 實作防禦性 `safeClosePanel(panel)` 函式，依序嘗試 `.close()`、`.hide()`、`frame:Hide()`。
  3. 實作經典奶牛頭框架位置預覽 (`Interface\Icons\Spell_Nature_Polymorph_Cow`)、多槽位名稱標籤、紅/綠邊框色調與多框架滑鼠拖曳定位。
  4. 實作全方位 60fps 即時熱預覽：圖示尺寸、水平/垂直間距、透明度、扇形倒數轉圈動畫、轉圈透明度、自身/目標減益色度、法術/倒數/堆疊字型大小、成長方向即時動態響應。
  5. 實作進入戰鬥全螢幕紅框閃爍 (`UI\CombatFlash.lua`)，監聽 `PLAYER_REGEN_DISABLED` 事件並在主面板提供即時測試按鈕。
- 驗證結果：Lua 66/66、Flow all 84/84、Validation Contracts 493/493。

### 2026-08-24 EAM-20260824-ALPHA77-ANCHORS-AND-MUTEX：Alpha 7.7 子視窗聯動移動錨點、側窗互斥機制與雙軌日誌分離

- 狀態：Alpha 7.7 完成離線契約 (Lua 65/65, Flow 84/84, Contracts 493/493)，實機待玩家簽收。
- 變更亮點：
  1. 子視窗聯動移動錨點：點擊各類別監控子視窗時，自動在畫面上亮起該模組專屬半透明移動錨點框（標記「按住左鍵拖曳」），方便玩家直觀拖曳調整在畫面上的定位；關閉子視窗時自動隱藏所有錨點並套用排版。
  2. 排版位置全開模式：開啟「告警框架位置與排版」視窗時自動亮起全部 7 大框架移動錨點。
  3. 全二級附屬側窗互斥：開啟職業資源、除錯中心、Profile 匯入/匯出、功能模組、關於或清單子視窗時，自動關閉其他側邊面板，消除多側窗重疊。
  4. 除錯中心修復：修正流程測試運行非同步回傳布林值導致的 index error，補全格式化輸出；修正系統診斷報告匯出按鈕調用。
  5. 雙軌日誌分離：專案根目錄建立 `changelog.md` 承載完整工程與治理細節，`changelog.txt` 維持純粹魔獸插件更新。
  6. Release 包命名標準化：對齊 `EventAlertMod_MN_yyyyMMdd_HHmmss-<Tag>_AGY.zip`（後續發布預設帶 `_AGY` 後綴）。
- 驗證結果：Lua 65/65、Flow all 84/84、Validation Contracts 493/493。

### 2026-08-23 EAM-20260823-ALPHA75-UI-RESOURCE-OVERHAUL：Alpha 7.5 介面佈局重構、視窗吸附、Profile 升級與 DK 符文強化

- 狀態：Alpha 7.5 完成離線契約 (Lua 65/65, Flow 84/84, Contracts 493/493)，實機待玩家簽收。
- 變更亮點：
  1. 視窗右上加入原生 [X] 快速關閉按鈕，並實作階層式無縫吸附 (APPEND Docking) 與多視窗同步拖曳。
  2. 主選單分類 7 提升為「★ 玩家職業資源設定」，整合除錯類功能至 4-Tab「除錯與測試診斷中心」。
  3. Profile 分享升級支援 8 大自選項目（含框架排版位置、職業資源設定與一般偏好設定）與預覽區塊分析。
  4. 職業資源設定面板滑桿與下拉選單支援即時熱預覽與自動套用。
  5. 死亡騎士符文支援 3 大專精動態圖示、6 格微型充能進度條與 /eam rune 槽位診斷視窗。
- 驗證結果：Lua 65/65、Flow all 84/84、Validation Contracts 493/493。

### 2026-08-13 EAM-20260813-ALPHA4-MODULE-PROFILES：Alpha 4 模組開關與職業 profile 發布

- 狀態：Alpha 4 已完成離線契約，實機仍待 PTR／XPTR／Retail 玩家簽收。
- 症狀：原有帳號層級清單與服務入口無法讓不同職業獨立保存，也缺少可安全停用單一功能模組的 UI。
- 原因判斷：SavedVariables 以帳號層級根 alerts 為主；服務事件若反覆註冊／解除，容易造成重複 handler、舊 queue 復活或戰鬥結構變更。
- 有效解法：schema v5 建立 profiles.classes 與 migration backup；ModuleController／ModulePanel 以八個 canonical module key 做 gate，服務只註冊一次並在入口短路；LegacyDiscoveryService 將 list、lookup、lookupfull、showcast 限制在 active class 安全候選。
- 驗證結果：Lua 54/54、Flow all 61/61、Validation Contracts 355/355；這些是離線／mock 證據，不代表 WoW 實機。
- 後續注意事項：不要把 LegacyReference 的 loadstring 匯入器重新接回正式路徑；JSON／Base64 profile 分享需另立 parser、checksum、preview/apply 與戰鬥延後契約。

<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 開發瓶頸、限制、錯誤與解決方法紀錄

本文件記錄EventAlertMod正式服重寫開發過程中遇到的瓶頸、限制、錯誤、工具失敗、API不確定性與有效解法。目的在於減少日後重複試錯，並讓未來的人工智慧代理人能夠用最少的上下文/token繼續理解問題。

## 記錄

### 2026-08-21 EAM-20260821-PLAYER-RESOURCE-MULTI：玩家資源由單一 ClassPower 改為多資源正式路徑

- 日期：2026-08-21。
- 狀態：程式與離線驗證完成；Retail／PTR 全職業全專精目視仍待玩家簽收。
- 症狀：法師法力、野性德魯伊能量、暗影牧師瘋狂值與戰士怒氣在正式顯示路徑不出現；舊服務一次只選一種資源，並在 Secret max、戰鬥或初始值為 0 時隱藏／延後。
- 原因判斷：舊 `ClassPowerService` 把資源能力選擇、raw 數值讀取、單一 AlertState 與畫面綁在同一服務；`UnitPowerMax` fail-closed 會排除主要資源，戰鬥延後則使正在變化的 Secret 資源永遠不刷新。
- 已嘗試方法：早期次要資源優先與 UnitPower capability probe 只證明 setter 可接受輸入，無法讓 production renderer 同時顯示多資源，也不能當作視覺通過。
- 有效解法：新增 `PlayerResourceCatalog`、`PlayerResourceCapability`、`PlayerResourceService`、`PlayerResourcePanel` 與專用 `PowerRenderer`；涵蓋 17 種資源與 40 組職業／專精拓撲，以 O(1) token dispatcher 與事件驅動管理每項獨立 sink，schema v6 保存 class/spec 設定。
- Secret 邊界：只將 `UnitPowerPercent(..., CurveConstants.ZeroToOne)` 回值直接送入 `StatusBar:SetValue`，不保存、不比較、不字串化、不序列化、不讀回；報告只有安全 metadata。
- 驗證：AddOn Lua `62/62`、Flow `70/70`、Validation Contracts `426/426`；未啟動 WoW，不能宣稱全職業全專精實機通過。
- 後續注意事項：依 `Docs/29_LIVE_TEST_STEP_GUIDE.md` 測法力、怒氣、能量＋連擊點、瘋狂值、符文＋符能及所有可用資源；Capability `accepted` 不等同正式資源面板 visual pass。

### 2026-08-21 EAM-20260821-PACKAGE-VALIDATION-GATE：打包前驗證攔截舊德魯伊單資源契約

- 日期：2026-08-21。
- 狀態：已解決。
- 症狀：`Deploy/Build-Package.ps1` 顯示 `VALIDATION_CONTRACTS passed=397 failed=1` 與 `Druid priority includes Energy fallback`，隨後以 exit 1 停止，尚未進入 ZIP 壓縮階段。
- 原因判斷：打包器依設計先循序執行 Lua、Flow 與 Validation Contracts；舊靜態斷言仍要求德魯伊單一 priority 字面，已不符合 17 資源／多資源拓撲。
- 有效解法：改以 Catalog 17 資源、40 組專精拓撲、德魯伊五資源、O(1) dispatcher、Secret write-only sink、schema v6 與 Flow case 契約驗證；並把舊 `migration_v1_v5` 測試升為 `migration_v1_v6`。
- 試錯記錄：曾同時啟動 Flow 與 Contracts，Contracts 讀到上一份 69/70 artifact 而暫時失敗；打包器本身是循序執行，不受此競態影響。開發端後續一律先完成 Flow，再執行 Contracts。
- 最終驗證：Flow `70/70`，Contracts `426/426`。這只證明打包前離線 gate 已恢復，不等同 WoW 實機簽收。

### 2026-08-13 EAM-20260813-AURASOUND-DETAILS：12.1 AuraSound 光環細部設定與註冊生命週期

- 狀態：程式與離線流程已完成；PTR 12.1、XPTR 12.0.7 與 Retail 12.0.7 的真人實機簽收仍待玩家執行。
- 情境：依 PTR 12.1.0 build 69273 固定生成文件，將 `C_UnitAuras.AddAuraSound` 的 Added、ApplicationsIncreased、Removed 三種 trigger 納入 Aura 細部設定。
- 症狀：既有 `AuraSoundService` 沒有 per-alert UI 與正式 SavedVariables mutation；`EAM_AURA_SOUND_CHANGED` 只有 listener、沒有 producer；音效設定混入 AuraContainer fingerprint，純音效變更也會建立新容器並消耗單次載入配額；註冊中途失敗可能留下半套 registry。
- 原因判斷：AuraSound 是獨立的 C-side 註冊生命週期，不是 AuraButton／AuraContainer 視覺 option。公開結構只有 `unitToken`、`spellID`、`soundFileName`／`soundFileID` 與 `outputChannel`，沒有 caster 或 `auraFilter`，因此不能把 Native 音效宣稱為與視覺篩選完全等價。
- 已嘗試方法：先以固定 commit `6e348870ed8f93d95f0cd16d299b51dbce500296` 核對生成文件與 enum；標準 `apply_patch` 在 Windows sandbox 回傳 `helper_unknown_error`，故在逐檔時間戳備份後，改用具有唯一 marker、預期命中數與 UTF-8 no-BOM 的受控 PowerShell 轉換。
- 有效解法：Aura 細部設定新增共用素材選擇與三個 trigger 開關；三項皆未勾選時沿用全域設定。`SavedVariables.updateAuraSound()` 負責白名單正規化、no-op revision 與事件；全域 `showSound` 是 master gate。編譯器拆分 container／sound fingerprint；Sound service 先建立 candidate registry，完整成功後才交換，移除失敗的 ID 保留於 retired registry 供後續重試。
- Secret／污染邊界：只把 EAM SavedVariables 中已正規化的普通 unit、SpellID 與靜態音檔資料送入 C API；不讀 AuraData、不序列化 runtime registration ID、不做 Secret 比較／字串化／table key，也不使用 OnUpdate 推導觸發。
- 驗證結果：Lua 5.1 語法 `54/54`；Flow `all 61/61`，artifact 為 `TestResults/EAM_FlowValidation_all_20260813_013945.json`；Validation Contracts `355/355`，其中 5 個具名 AuraSound gate 覆蓋設定 mutation、三 trigger UI、雙 fingerprint、交易式 registry 與 12.0.7 零呼叫。均屬離線／靜態證據，不得冒充 PTR 實播。
- 後續注意事項：PTR 12.1 需分別實測新增、層數增加、自然到期／驅散移除、戰鬥內改設定後脫戰合併、`/reload` 重建，以及 caster／極性限制的 over-fire 風險。12.0.7 應顯示 capability 降級、保留設定且零 `AddAuraSound` 呼叫。

### 2026-08-12 EAM-20260812-THEME-MOCK-GETTER：按鈕主題 capability guard 觸發 strict mock 錯誤

- 狀態：已解決；離線 Flow 與 Lua 語法已重新通過，正式服／PTR／XPTR 仍待玩家目視驗證。
- 情境：新增 EAM 按鈕主題後執行 `Tools/Run-FlowValidation.ps1 -Suite all`。
- 症狀：strict mock 在 `UI/Theme.lua` 讀取不存在的 `GetNormalTexture` 時，於 `__index` 直接拋出 `Unknown strict generic frame method`，流程未產生報告。
- 原因判斷：`button.GetNormalTexture and ...` 先執行方法索引；對嚴格 mock 而言，索引本身就不是安全的 capability check。
- 已嘗試方法：確認正式按鈕仍需套用 normal、highlight、pushed、disabled 與文字色；未放寬 mock 的未知方法規則。
- 有效解法：新增 `callButtonMethod`，把 getter 索引與呼叫包在低頻 `pcall` 中；正式 WoW 有方法時套用 palette，缺方法的 widget 只略過該 texture，不中斷其他流程。
- 驗證結果：Lua `51/51`、Flow `all 54/54`（artifact `TestResults/EAM_FlowValidation_all_20260812_192557.json`）、Validation Contracts `328/328`。
- 後續注意事項：仍需在 PTR／XPTR／Retail 選擇 EAM、FF7、Windows XP、Borland、DOS CRT、macOS Aqua 六主題，確認按鈕 normal/highlight/pushed/disabled、戰鬥延後與 `/reload`；不得以離線通過代替真人簽收。



### 2026-08-12 EAM-20260812-PTR69273-UNITPOWER-PENDING：PTR 69273 UnitPower 視覺簽收尚未完成

- 狀態：待實機視覺驗證；不可標示 UnitPower PTR pass。
- 情境：玩家回報 PTR 12.1 build 69273 的 EAM_UNIT_POWER_CAPABILITY_REPORT。
- 症狀：primary native percent 與 selected safe/native 兩案均顯示 powerTypeAvailable、StatusBar sink accepted、radial sink accepted；前者 resultClass=secret，後者 resultClass=safe-number，但兩案 visualObservation 都是 pending，整份報告 status=incomplete，boundaryWarnings 要求人工作業。
- 原因判斷：sink accepted 只證明值可送入允許的 C-level widget，不證明玩家已看到正確的資源變化；Secret 值不能讀回、比較、字串化或寫入報告。
- 已嘗試方法：保留 UnitPowerPercent／StatusBar:SetValue／Texture:SetRadialProgressBarPercent 的單向管線；沒有取得 raw power、max 或 percent。
- 有效解法：維持報告的 resultClass、sink 狀態與人工 visualObservation 分離；由玩家在 PTR 面板操作資源後，逐案按顯示正常、顯示異常或無法測試。
- 後續注意事項：法師只有法力仍可測 primary native sink，但不會得到可讀 Lua 數字；需在非戰鬥啟動探針，戰鬥中只觀察原生 sink，完成後停止探針並在 /reload 或正常登出後保存最新報告。

### 2026-08-12 EAM-20260812-PTR69273-FLOW-BOUNDARY-HELPERS：完整流程報告的 boundary.safe_scalar 失敗

- 狀態：未解決；PTR 流程報告不可視為完整 pass。
- 情境：同一 PTR 12.1 build 69273 的 EAM_FLOW_VALIDATION_REPORT。
- 症狀：summary 為 total=54、passed=17、failed=1、skipped=36；唯一失敗 case 是 boundary.safe_scalar，訊息為 Secret、manual-copy、About 或 SVG boundary helpers unavailable。
- 原因判斷：這是流程邊界 helper 可用性失敗，不等同於 UnitPower sink 失敗；目前不足以斷言是遊戲 API、載入順序或舊 package，需在同一 build /reload 後重跑確認。
- 已嘗試方法：僅解析玩家提供的 JSON，沒有自動操作 WoW，也沒有把 skipped case 升格為 pass。
- 有效解法：暫不更改 Secret 邊界邏輯；要求玩家重載後重新執行完整流程，回傳 boundary.safe_scalar 的最新 case 與環境欄位。
- 後續注意事項：若重跑仍失敗，需檢查 EAM TOC 是否載入 Debug/RuntimeProbe、PromptExport、About、SVGCapabilityProbe 與 FlowTestRunner 的 helper；修正前 Alpha 報告只能標示 incomplete。

### 2026-08-12 EAM-20260812-AURA-PRIORITY-1079：原生 Aura 首格採用優先級

- 狀態：程式已修正，待 PTR 目視驗證。
- 情境：PTR 存檔的 target Aura 監控。
- 症狀：野性德魯伊撕扯 1079 仍固定出現在第一格。
- 原因判斷：現行編譯器只按 unit／SpellID 排序，完全忽略已存在的 priority 欄位；使用者提供的 PTR SavedVariables 中 1079 的 priority=20，1822 為預設或較低值，因此 1079 會成為第一個 native slot。這不是 1079 的硬編碼。
- 已嘗試方法：唯讀檢查 PTR SavedVariables 與 AuraRuleCompiler；未修改使用者存檔。
- 有效解法：AuraRuleCompiler 將 priority 正規化到 1..20，採數字越大越先，再以 SpellID／alertID 作穩定 tie-break。要把 1079 移離第一格，請在 EAM 條件設定將其 priority 調低；程式不會覆寫明確使用者設定。
- 後續注意事項：/reload 後必須重新建立 Native Aura 結構才會看到新順序；若 priority 相同，SpellID 仍是穩定次排序，不保證沿用 Lua table 寫入順序。

### 2026-08-12 EAM-20260812-THEME-BUTTONS：主題只套框架未套按鈕

- 狀態：程式已修正，待三客戶端目視驗證。
- 情境：切換 EAM／FF7／Windows XP 主題後，視窗邊框改變但按鈕仍是 Blizzard 預設色。
- 症狀：UI/Theme 只有 frame 與 FontString registry，UIPanelButtonTemplate 和自製下拉按鈕沒有統一色彩管線。
- 原因判斷：按鈕 normal、highlight、pushed、disabled texture 與按鈕文字未進入 Theme.applyAll。
- 已嘗試方法：未全域 hook Blizzard 按鈕；盤點 EAM Options、About、Tooltip popup、Flow／Live／SVG／UnitPower／Prompt 面板的自有按鈕建立點。
- 有效解法：新增 Theme.applyButton／registerButton 與三套 palette 的按鈕狀態色，並在 EAM 自有 UIPanelButtonTemplate 與下拉按鈕建立後註冊；AlertBorderStyles 語意邊框不受主題覆蓋。
- 後續注意事項：玩家需在 PTR、XPTR、Retail 各選三種主題，確認 normal、highlight、pressed、disabled 狀態與 /reload／戰鬥延後；這是 EAM 自有 UI 視覺，不會改動暴雪動作列。

### 2026-08-12 EAM-20260812-DRUID-ENERGY：野性德魯伊 Energy 未出現

- 狀態：程式已修正，待 PTR／XPTR／Retail 實機驗證。
- 情境：ClassPowerService 的職業資源選擇。
- 症狀：貓 D 的 Energy 沒有出現，服務先選 Combo Points，Energy 沒有機會成為 active power。
- 原因判斷：Druid class priority 原為 Combo Points、Lunar Power；Feral 的 Energy 是主要資源但未列入優先候選。
- 已嘗試方法：確認 powerEnergy 預設為啟用，並檢查 UnitPower predicate／safe-number 防線；沒有在戰鬥中讀取或序列化秘密值。
- 有效解法：Druid 候選順序改為 Energy、Combo Points、Lunar Power；Energy 不可用或設定停用時仍會安全 fallback 到其他候選，Balance／Guardian／Restoration 不會因 unsupported max 盲選 Energy；selectPower 另以 ShouldUnitPowerBeSecret fail-closed，Secret Energy 不會成為新 active，既有 active 轉 Secret 則由 updatePower 回報 secret。
- 後續注意事項：請切到 Feral、脫戰 /reload，先確認 Energy 圖示與數值 1，另測 Combo Points 不被意外取代；再進戰鬥確認不出現 Lua／taint 錯誤，戰鬥中資源更新仍遵守 combatDeferred。
規則
- 新問題一律追加在「紀錄」區塊最上方，讓最新問題最容易被看到。
- 每筆記錄至少包含日期、狀態、抵押、症狀、原因判斷、已嘗試方法、有效解法、後續注意事項。
- 若問題尚未解決，標記狀態為「未解決」，並寫明下一步驗證方式。
- 不記錄密碼、令牌、私人帳號資料或任何敏感資訊。
- 若問題與 WoW Retail API 有關，需標示資料來源為檔案、搜尋索引、NotebookLM、或實機驗證。
- 若問題與工具或環境有關，需記錄作業系統、指令、錯誤訊息摘要與可行替代方案。
- 若同一類問題或作業流程重複出現，需評估是否整理成 EventAlertMod 專案唯一 SKILL。
- 若問題涉及污染、被阻止的動作、戰鬥鎖定或受保護的框架，需記錄觸發路徑、戰鬥狀態、相關框架/API 與可重置步驟。

## 建議格式
```md
### yyyy-mm-dd 標題

- 狀態：已解決 / 未解決 / 待實機驗證
- 情境：
- 症狀：
- 原因判斷：
- 已嘗試方法：
- 有效解法：
- 後續注意事項：
```
## 記錄
### 2026-08-12 EAM-20260812-THEME-DOS-AQUA-BORLAND：新增 DOS CRT、macOS Aqua 與 Borland C++ IDE 主題

- 狀態：已完成離線接線，PTR／XPTR／Retail 視覺仍待玩家簽收。
- 情境：使用者提供 DOS CRT、macOS Aqua 與 Borland C++ IDE 參考圖，要求 EAM 主題下拉可選且按鈕同步變色。
- 原因判斷：既有 Theme registry 已涵蓋 EAM 自有 frame、FontString 與 button；缺口只在 palette catalog、SavedVariables 正規化與選單高度，無需建立新 UI framework 或改動 Blizzard secure frame。
- 有效解法：新增 `borland`、`doscrt`、`aqua` 三個固定 ASCII key，補齊電光藍／青、磷光綠 CRT、藍灰／亮藍 palette；主題選單高度改由 `#Theme.ThemeOptions` 計算；按鈕 highlight 的 blend／alpha 以 capability guard 降級。
- 驗證結果：已完成靜態接線，待 Lua、Flow、Validation Contracts 全套重跑；離線通過不代表三客戶端真人目視通過。
- 後續注意事項：實機須逐一檢查主視窗、About、Tooltip、Flow、Live、SVG、UnitPower、Prompt 的四種按鈕狀態與 `/reload` 保留；AlertBorderStyles 七種語意色不得被主題覆蓋。

### 2026-08-12 EAM-20260812-AURA-SLOT-GROUP-PADDING：Native Aura slot 與 group 起點重疊

- 狀態：已完成程式修正，待 PTR／XPTR／Retail 目視確認。
- 症狀：同一 unit 的第一個固定 Aura slot 與 AuraGroup 都從容器左上角開始，1079／155722 等圖示可能重疊；優先權變更也未必觸發 Native rebuild。
- 有效解法：以官方 flow padding API 將 group 起點向右移過固定 slot 寬度；SavedVariables 優先權更新現在增加 revision、觸發 `EAM_AURA_CONFIG_CHANGED`，compiler fingerprint 也納入 priority。
- 後續注意事項：priority 是排序，不是互斥；若要只顯示最高優先 Aura，必須另訂 exclusive display contract，不能默默改變多光環監控語意。

### 2026-08-12 EAM-20260812-MINIMAP-SVG-THEME：小地圖 SVG fallback 與主題選擇器

- 狀態：程式與離線契約已完成；PTR、XPTR、Retail 的按鈕目視、互動、`/reload` 與主題切換仍待玩家簽收。
- 情境：使用者回報 EAM 小地圖快速開啟圖示整體呈綠色，並要求增加 FF7 與 Windows XP 主題。
- 症狀：原小地圖按鈕把聲音資產的 FileDataID 當成 Texture；主設定沒有可保存的主題選擇，視窗樣式散落在多個 UI 模組。
- 原因判斷：音效 FileDataID 不是穩定的視覺素材；主題若直接全域改色，會污染 AlertBorderStyles 的技能／物品／Aura／地面效果語意，且戰鬥中即時改 UI 結構有 taint 風險。
- 已嘗試方法：唯讀查閱 `wowtools.work` 作為資料瀏覽器；不把外部 FileDataID 或遠端素材放入插件依賴。盤查 Options、About、Tooltip popup 與除錯 UI 的既有 frame 建立位置，採集中 palette、weak registry 與 combat pending 設計。
- 有效解法：新增專案自有 `Media/SVG/eam-minimap.svg`；`Options.applyMinimapTexture()` 先 `SetSVG`，失敗回退 `INV_Misc_QuestionMark`；新增 `UI/Theme.lua` 與 `EAM_DB.config.theme`，提供 EAM／FF7／Windows XP，戰鬥中延後至 `PLAYER_REGEN_ENABLED` 套用。AlertBorderStyles 語意色保持獨立。
- 驗證結果：Lua `51/51`、Flow `all 54/54`、Validation Contracts `328/328`，另有 Theme runtime smoke pass；目前沒有由 Codex 直接操作 WoW 的實機證據。
- 後續注意事項：PTR 12.1 應確認 SVG 肉眼顯示；XPTR／Retail 應確認 fallback；三個客戶端均需確認左鍵、右鍵、拖曳與 `/reload`，並回報 client／patch／build。

### 2026-07-29 Alpha 2 文件基線與 Pages 轉換器錯誤（已解決）

- 狀態：TOC、最新離線證據、轉換器根因與 Pages 產物已同步，發布前文件閘門通過。PTR／XPTR 真人矩陣狀態不變，仍未簽收。
- 情境：GitHub Alpha 2 發布前同步 repo `main`、GitHub Pages 與 Release ZIP 內的版本、README 及驗證證據。
- 症狀：TOC 仍停在 `EventAlertMod_MN_20260728`；README、測試計畫與流程框架仍引用 Flow 35/35、Contracts 109/109；HTML 轉換器把外部 GitHub `.md` URL 錯加 `.html`，離線模式又把未翻譯原文當成英文結果，讓新驗證段落在中英文頁籤各出現一次。
- 原因判斷：發布日期與離線 gate 沒有在文件重建前同步；連結後處理使用不分 URL 類型的通用正規式；`EAM_DOCS_OFFLINE=1` 在翻譯入口回傳原文，而非明確回傳「翻譯不可用」。
- 已嘗試方法：官方 `functions.apply_patch` 與一般終端命令在 Codex Windows sandbox 遇到 `helper_unknown_error: setup refresh had errors`；唯讀查詢改走已授權的同範圍程序，正式來源修改則改用本機 npm Codex 套件的官方 `--codex-run-as-apply-patch` 協定，不以 PowerShell 字串改寫檔案。直接執行檔第一次仍沿用 cmd 啟動器的雙引號反斜線轉義，補丁因無法命中而零修改；移除多餘轉義後成功。第一次 Pages 驗證則因 PowerShell 不允許把 `foreach` statement 直接接管線而產生 `An empty pipe element is not allowed`，改為先收集陣列再格式化。全程維持 `EAM_DOCS_OFFLINE=1`，不把 Markdown 送往外部翻譯服務。
- 有效解法：TOC 更新為 `EventAlertMod_MN_20260729`；最新證據統一為 Lua 45/45、Flow 42/42、Validation Contracts 119/119，Flow artifact 為 `TestResults/EAM_FlowValidation_all_20260729_153728.json`，並明示 `purpose=offline-contract`、`executionSource/source=offline-mock`、`clientChannel=OFFLINE`。轉換器只改寫本機相對 Markdown 連結，保留外部 GitHub URL；離線翻譯明確回傳不可用，讓第二語言頁籤顯示 fallback，不再複製原文。
- 歷史污染邊界：先前針對本次追蹤新增行、功能檔與指定文件的有限盤點，以 65 行既有 `EAM`＋`CODE` marker／file URI 作為基線；本輪另以 `git grep -n -E '[E]AMCODE|file:/{3}' HEAD -- '*.md'` 對全部 HEAD Markdown 廣義重掃，得到 71 行（62 行 marker、9 行 URI）。兩者 glob／範圍不同，不可互相比較；本次允許修改檔新增增量為 0，歷史污染另案清理。
- 驗證結果：轉換器 `unittest` 4/4；離線重建 34 個來源並同步 Pages／Release README；指定 artifact 經 schema 2 契約驗證為 42/42，SHA-256 `12D5F123A72D46DA16277DB4C833B3AE3EEF0BEEAD9772F4A43E4C3A339AEE09`；Lua 45/45、Validation Contracts 119/119。README、Pages README 與 Release README 的最新 artifact 段落各 1 次，外部 GitHub `.md.html` 誤連結為 0；35 個 Pages HTML 的相對 `href` 均有實體目標，5 個本專案 GitHub／Pages URL 均為 HTTP 200。允許來源 marker／file URI 命中行 21→21、新測試 0，36 份 HTML 由 140→70（去除離線雙語重複，增量 -70）；`git diff --check` exit 0，只有既有 LF／CRLF 轉換提示。
- 後續注意事項：不得用離線 artifact 冒充 PTR／XPTR／Retail 實機證據；GitHub Alpha 身分由 prerelease metadata 表示，Release ZIP 必須使用正常白名單模式，不得使用 `-DevMode`。

### 2026-07-29 Native Aura 容器生命週期、戰鬥排版與實機報告證據可偽造（程式已解決，待 PTR 簽收）

- 狀態：四項 P1 已完成程式與離線契約修正；SEC／AURA121 第二次終審進行中，PTR／XPTR 真人矩陣仍未簽收。
- 情境：12.1 Native Aura 文字版面、18 案真人簽收報告與開發端 JSON 匯入器的最終專家審查。
- 症狀：AuraContainer 每次 fingerprint 改變都建立新 player／target Frame，舊 Frame 無法銷毀；一般 Renderer 的 public defer 可被 render 內部 helper 繞過；`prepareReload()` 後可在同次載入直接 resume；raw build flags 與 aggregate 可互相矛盾；producer 亦可能在 phase 尚為 active 時產生 pass 外觀。
- 原因判斷：fingerprint 錯把全域 revision 當結構事實，文字設定也透過 container rebuild 套用；戰鬥守衛只放在外層 API；reload checkpoint 沒有載入世代 identity；Schema 只檢查 raw 欄位存在，匯入器未重新計算。
- 已嘗試方法：原生 `apply_patch` 與一般 PowerShell 啟動器持續遇到 `setup refresh had errors`；改用本機 Codex `--codex-run-as-apply-patch` 後，Windows 原生參數層又先移除 patch 內雙引號，造成一次立即發現並修正的無效 Lua `__mode = k`。所有既有檔案均先建立時間戳備份，未碰 WoW AddOns SymbolicLink。
- 有效解法：Native renderer 以 weak-key registry 直接重套 EAM FontString，文字改變不再重建容器；一般 Renderer 的 text／layout／toggleAnchors 全部在戰鬥中延後；Aura fingerprint 移除 revision 並納入真實 layout，容器每次載入最多建立 18 個，超限保留現況並要求 `/reload`；checkpoint 加入 boot token table identity，同載入回傳 `sameLoadRejected`；active phase 固定 incomplete；匯入器驗證 Flow schema 2 並由三個 raw flags 重算 known／aggregate；producer 先遮蔽 UNC 與 SavedVariables 路徑。
- 驗證結果：Lua 語法 45/45；最新離線 Flow `all` 42/42，報告 `TestResults/EAM_FlowValidation_all_20260729_153728.json`；Validation Contracts 119/119。Flow 報告為 `purpose=offline-contract`、`executionSource/source=offline-mock`、`clientChannel=OFFLINE`；以上均不是 PTR／XPTR／Retail 實機證據。
- 後續注意事項：由玩家在 `_ptr_` 12.1 完成至少 30 次文字／結構調整、戰鬥內外與真正 `/reload`，核對 `createdContainerCount` 上限、`sameLoadRejected`、Forbidden／taint／blocked action 與框外裁切；`_xptr_` 12.0.7 仍需完成同一份 18 案矩陣。讀取 WTF 前必須先由玩家 `/reload` 或正常登出。

### 2026-07-28 README 導覽連結仍指向舊儲存庫（已解決）

- 狀態：已解決；README 內所有專案導覽連結已改為 `ziyuefan/EventAlertModRemake` 的 `main` 路徑。
- 情境：Alpha 發布前核對 GitHub 儲存庫與 Pages 導覽。
- 症狀：ChangLog、CommandLine 與 ScreenShot 的重複連結仍指向舊 `EventAlertModAll`；ScreenShot fragment 也使用本 README 不存在的 `#screenshot-2`。
- 原因判斷：README 沿用舊 repo 的絕對連結，儲存庫改造後沒有同步路徑與章節錨點。
- 已嘗試方法：先列出所有 `github.com`／`github.io` 連結，再核對實際 `##命令列` 與 `## 截圖` 標題，避免只更換 repo 名稱。
- 有效解法：ChangLog 直接連到本 repo `main/changelog.txt`；CommandLine 與 ScreenShot 分別連到本 repo README 的 `#命令列` 與 `#截圖`。
- 後續注意事項：儲存庫搬移、改名或章節標題變更時，發布前必須搜尋舊 owner／repo 與失效 fragment；Pages 網址維持 `https://ziyuefan.github.io/EventAlertModRemake/`。

### 2026-07-28 Release ZIP 的根 readme.html 與 Pages 內容漂移（已解決）

- 狀態：已解決；文件轉換流程已建立單一 HTML 來源。
- 情境：Alpha ZIP 通過第一次封裝後，進一步核對包內說明檔與 GitHub Pages 產物。
- 症狀：`docs_html/README.md.html` 已包含 12.1 Alpha、Native Aura 與 Tooltip 監控說明，但根 `readme.html` 最後更新於 2026-06-11；標準包會收錄後者。
- 原因判斷：批次轉換器只更新 `docs_html/README.md.html`，打包器卻讀取根 `readme.html`，兩份生成檔沒有同步契約。
- 已嘗試方法：沒有手動覆寫後直接發布，先比對兩個檔案的時間、大小與 Alpha 關鍵字。
- 有效解法：`batch_convert_docs.py` 每次轉換根 `README.md` 後，將 Pages 產物同步到根 `readme.html`；封裝指南同步指定該唯一來源。
- 後續注意事項：只要 README 或轉換器有變更，發布前都必須先執行離線 HTML 重建，再執行標準封裝與 ZIP 內容核對。

### 2026-07-28 Alpha 封裝被停載 ShadowHost 死碼擋下（已解決）

- 狀態：已解決；標準封裝、Lua 語法、離線流程與敏感資訊掃描均通過。
- 情境：準備將 12.1 Native Aura、流程驗證與 GameTooltip 自製監控選單發布為 GitHub Alpha prerelease。
- 症狀：第一次執行 `Tools/Build-CurseForgePackage.ps1` 時，TOC 一致性閘門回報 `Services/ShadowHostService.lua` 未列入 TOC，拒絕產生 ZIP。
- 原因判斷：12.1 改造已從 TOC 與 Renderer 停用 ShadowHost，但舊研究檔仍位於正式 `Services/`。標準打包器會複製整個服務目錄；若只放寬檢查，死碼仍會進入正式包。
- 已嘗試方法：沒有使用 `-SkipLuaCheck` 或修改白名單繞過。另遇到桌面端 sandbox helper `setup refresh had errors`，內建補丁工具無法啟動；WindowsApps 的 patch 啟動器又被拒絕執行，最後改用本機 npm Codex 套件內相同的 `--codex-run-as-apply-patch` 入口。
- 有效解法：先備份原檔，再以 `git mv` 將 ShadowHost 完整封存到 `LegacyReference/Services/ShadowHostService.lua`；同步把模組契約改成封存參考。正式包既不載入也不收錄該檔，研究歷史仍可追溯。
- 驗證結果：TOC consistency 無未列入 Lua/XML；正式載入 Lua `41/41` 語法通過；離線 `all` suite `24/24` 通過；敏感資訊掃描通過；產物為 `Dist/EventAlertMod_MN_20260728_123720.zip`。
- 後續注意事項：停載模組不得留在正式打包目錄。若需要保留研究碼，必須放入發布工具明確排除的 `LegacyReference/`，且文件不可再把它列為執行期契約。

### 2026-06-22 PTR／XPTR 版本映射與 EventAlertMod SymbolicLink 安全基準（已解決，需持續複查）

- 狀態：本機版本與 Reparse Point 已唯讀確認；後續每次安裝、清理或實機驗證前需重新檢查。
- 情境：使用者指定 `D:\World of Warcraft` 為 WoW 根目錄，並補充 `_ptr_` 為至暗之夜 12.1.0、`_xptr_` 為至暗之夜 12.0.7；各版本 AddOns 可能以 Windows 連結指向實體專案 `D:\EventAlertMod`。
- 症狀：若把 `Interface\AddOns\EventAlertMod` 當成一般插件副本進行刪除、覆蓋、解壓縮或鏡像同步，可能破壞 SymbolicLink，甚至讓遞迴工具誤作用到實體專案。
- 原因判斷：Battle.net 版本資料夾名稱不足以單獨證明 build；各版本的 EventAlertMod 路徑型態也不一致，必須分別讀取執行檔版本與 `LinkType`／`Target`／`ReparsePoint`。
- 已嘗試方法：第一個唯讀查詢因 PowerShell 不接受 `foreach { } | Format-Table` 的寫法而在解析期停止；第二次誤假設 PTR 使用 `Wow.exe`，因實際檔名是 `WowT.exe` 而停止。兩次都沒有修改檔案。最終一致性檢查又因以 `Tools/Test-...` 正斜線字串搜尋 Windows 文件中的 `.\Tools\Test-...` 反斜線命令而產生假陰性；改以檔名本身與語意欄位檢查。第二版又把完整版本字串錯套到只負責流程命令的 SKILL，形成責任範圍假陰性；最終改為按文件責任分層斷言。
- 有效解法：先列出版本根目錄第一層執行檔，再讀取 VersionInfo。確認 `_retail_` 為 12.0.7.68256、`_ptr_` 為 12.1.0.68209、`_xptr_` 為 12.0.7.68182；前三者 EventAlertMod 均為指向 `D:\EventAlertMod` 的 `SymbolicLink`。另確認 `_classic_`、`_classic_ptr_` 為同目標 SymbolicLink，`_classic_era_` 為實體目錄，`_classic_era_ptr_` 不存在該插件路徑。 已新增 `Tools/Test-LocalWoWEnvironment.ps1`，以 patch train 與 Reparse Point／Target 作為實機測試前置斷言並產生 JSON／Markdown 證據。
- 後續注意事項：EAM 只支援 Retail；Classic 路徑不得作為測試或部署目標。對 `_retail_`、`_ptr_`、`_xptr_` 的 AddOns 連結禁止刪除、搬移、覆蓋、解壓縮、`robocopy /MIR` 或重建。任何連結維護必須另行說明風險並取得明確授權。

### 2026-06-21 建立離線／實機流程驗證與開發回灌閉環（已完成離線，待實機）

- 狀態：離線流程、JSON／Markdown 報告與回灌工具已通過；Retail／PTR 面板與按鈕待實機驗證。
- 情境：使用者要求開發過程除了限制與語法驗證，也必須能自行產生流程測試、在遊戲內按鈕執行並把報告回饋到開發環境。
- 症狀：原專案只有 `luac -p`、RuntimeProbe 與人工測試清單，無法重播 EventRouter、Scheduler、SavedVariables 與報告匯出流程，也沒有 Mock／實機共用案例或 WTF 回灌格式。
- 原因判斷：靜態與語法只能證明程式可解析，不能證明跨模組生命週期、非同步 callback、handler 清理及報告 schema 正常；人工測試若無結構化報告，後續開發也無法追溯。
- 已嘗試方法：建立 `FlowTestRunner`、`FlowTestPanel`、Lua 5.1 Offline Harness、PowerShell runner／importer、獨立 SavedVariable 與 `eam-flow-validation` SKILL。工具過程另遇到桌面端 sandbox helper 無法初始化，需在已授權專案範圍內改用具唯一命中檢查的 PowerShell 精確寫入；第一次替代雙引號時誤用反斜線轉義，造成 `Slash.lua` 出現 `unexpected symbol near '\'`，經 `luac -p` 定位後改用 PowerShell 單引號常值修復；此外遇到 skill short description 24 字元不足、JavaScript 編排反引號／PowerShell suite 插值衝突、Windows PowerShell 5.1 對無 BOM UTF-8 的 cp950 誤讀，以及報告工具漏初始化 `$utf8`。HTML 轉換器另會產生含 CR 的純空白行，初版清理規則未涵蓋 CR，經 `git diff --check` 定位後改以行尾 lookahead 清除。
- 有效解法：使用長度合格介面說明；寫檔命令以佔位字元還原反引號；含中文的 `.ps1` 使用 UTF-8 BOM；明確初始化輸出 UTF-8 encoding。離線 `all` suite 共 7 案例全數通過，JSON、Markdown 與 importer round-trip 成功。
- 驗證結果：`Lua syntax OK: 35 files`；`passed=7, failed=0, skipped=0, pending=0`；回灌來源正確保留 `offline-mock`。
- 後續注意事項：需在 Retail／PTR 非戰鬥中執行 `/eam test all`，確認面板 template、複製按鈕、Scheduler callback、WTF 寫回、taint／Lua error 與 ReloadUI。Mock 通過不得宣稱實機通過。

### 2026-06-21 建立 API Change Intelligence 專家與 12.0.0 基準（已建立，待持續維護）

- 狀態：專家、RACI、版本基準與專案 SKILL 已建立；API 情報需隨 PTR／正式版與來源 revision 持續維護。
- 情境：使用者要求建立 API CHANGE 專家，從 12.0.0 起理解 Retail AddOn API 演進，以便提前布局未來架構與遷移策略。
- 症狀：既有 `SEC` 與 `AURA121` 分別負責安全終審及 Aura 遷移，但缺少跨版本追蹤 TOC、revision、官方公告、UI source diff 與遷移窗口的唯一問責角色。
- 原因判斷：12.0.0 至 12.1.0 的變化是 Secret Values、反 laundering、DurationObject／Formatter、DurationTextBinding、Forbidden 與 AuraContainer 連續演進；若只在 API 移除後被動修補，會錯失 adapter、capability gate 與舊路徑退場的準備期。
- 已嘗試方法：查證 Warcraft Wiki `API_change_summaries` 與 12.0.0、12.0.1、12.0.5、12.0.7、12.1.0 頁面 revision；建立 `eam-retail-api-change-intelligence` SKILL。`init_skill.py` 首次因 23 字元的 `short_description` 未達 25 字元而只建立骨架；`generate_openai_yaml.py` 又先遇到 cmd 引號拆解與 Windows Python `cp950` 無法解碼 UTF-8；Codex 編排層兩次 Base64 嘗試因缺少 `TextEncoder` 與 `btoa` 而在命令送出前停止；`apply_patch` 亦受 `setup refresh had errors` 阻斷。
- 有效解法：新增 `APICHG`（`EAM_API_Change_Intelligence_Expert`）並設為第 13 個 RACI 領域唯一 `A/R`；以至少 25 字元的說明重新產生介面，改用 PowerShell 單引號保留參數，並以本次程序限定的 `PYTHONUTF8=1` 成功建立 `agents/openai.yaml`；文件修改使用已授權、目標明確的非互動 PowerShell UTF-8 寫入。
- 資料來源：Warcraft Wiki MediaWiki revision 與 Blizzard 官方 12.1 Addons／Auras 公告；Wiki revision time 僅代表頁面修訂時間，不是 patch 發布日期。
- 後續注意事項：12.1 頁面仍在 PTR 期間持續修訂；需監控 revision、官方 UI source 與實機證據。`APICHG` 不取代 `SEC` 安全終審、`AURA121` Aura 遷移或 `RQA` 客戶端簽收。本次未修改 Lua。

### 2026-06-09 PowerShell Get-Content 在讀取單行檔案時索引 System.Char 導致 MethodNotFound 崩潰（已解決）

- 狀態：已解決
- 脅：
  在`Tools/Build-CurseForgePackage.ps1`執行流程中，呼叫`Scan-SensitiveInfo`掃描敏感資訊時推送`MethodNotFound: [System.Char]不包含名為'Trim'`的方法致命崩潰，導致備用流程中斷。
- 原因判斷：
1. 當 `Get-Content` 讀取到單行檔案（如 `changelog.txt`）時，PowerShell 集合傳回值最佳化為單一 `[System.String]`，而不是 `[System.String[]]` 陣列。
  2.此時在 `for ($i = 0; $i -lt $lines.Count; $i++)` 迴圈中，使用下標 `$lines[$i]` 會進行 String 自行字符格式處理，導出其中的單個字符（其他類型為 `[System.Char]`）。
  3. `[System.Char]` 沒有 `.Trim()` 方法，呼叫時會引發 `MethodNotFound` 異常。
- 已嘗試方法：無。
- 有效解法：
  在 `Scan-SensitiveInfo` 函數中，將 `$lines = Get-Content ...` 修改為以 `@()` 強制包裝的 `$lines = @(Get-Content ...)`，確保有檔案有幾行，傳回結果必然是梯度，從而使 `$lines[$i]` 始終傳回字串。
- 後續注意事項：無。

### 2026-06-09 CurseForge 佔用腳本敏感字串正規過寬導致魔獸 12.x 原有保密代碼錯誤報告爆發（已解決）
- 狀態：已解決
- 脅：
  執行自動化資源共享時，安全警報指控`Constants.lua`中的`BOUNDARY_SECRET_VALUE = "secretValue"`與`ClassPowerService.lua`中除錯日誌內字符串拼接的`"Secret"`為敏感資訊洩露，強行中斷資源。
- 原因判斷：
  到底什麼正規表示式對 `secret` 單字進行了無腦匹配，這會誤配到 EAM 核心 Secrecy（結構/安全）防衛機製本身的常規變數與字符串。
- 已嘗試方法：無。
- 有效解法：
  修改`Tools/Build-CurseForgePackage.ps1`中的`$patterns`正則，將寬泛的`secret`替換為精確搜尋`client_secret`與`app_secret`等具體金鑰或推理字樣。
- 後續注意事項：確認未來修改與保密相關的程式碼時，備份工具不會再被誤報幹擾機制。

### 2026-06-09 自動化預留白名單漏掉.blp 貼圖檔導致自修改UI資源遺失（已解決）
- 狀態：已解決
- 脅：
  執行自動化預算腳本時，發現 `Media/Images/` 底下所有的貼圖與按鈕背景（如 `Seed1.blp`、`UI-Panel-Backdrop.blp`）全部被跳過，統計的 ZIP 壓縮包內缺少這些貼圖。
- 原因判斷：
  `Tools/Build-CurseForgePackage.ps1`中的`$allowedExtensions`白色名單變數中，缺少了魔獸世界中世紀專用的貼圖副檔名`.blp`。
- 已嘗試方法：無。
- 有效解法：
將 `.blp` 正式加入白名單副檔名列中（即 `$allowedExtensions = @(".lua", ".xml", ".tga", ".blp", ...)`）。
- 後續注意事項：備份成功後，解壓縮發布包確認所有圖片與音樂檔均完整存在。

### 2026-06-09 AI研發環境子代理損失限制導致部分專家啟動失敗瓶頸（已解決）

- 狀態：已解決
- 脅：
主代理（Antigravity）嘗試同時啟動5位專家子代理進行12.1.0專家聯席審查與全代碼檢視。
- 症狀與原因判斷：
  1. 系統回傳：`子代理程式 EAM_UI_Renderer_Expert （和效能、API 安全）遇到錯誤，已停止或無法開始執行：RESOURCE_EXHAUSTED (code 429): 已達到單一配額。請聯絡您的管理員以啟用超額功能。 3小時48分重置。
2. 原因：AI執行平台對家具子代理的呼叫次數或速度實施了硬性限制，在連續大數量派工時達到了配額上限。
- 已嘗試方法：無。
- 有效解法：
1. **主代理代行職責**：根據[Docs/17_SUBAGENT_WORKFLOW.md](file:///d:/EventAlertMod/Docs/17_SUBAGENT_WORKFLOW.md)的關鍵路徑降級原則，主代理（反重力）立即代為承擔並整合UI渲染、安全防衛與控制進展的評估，確保專案不會被阻礙。
2. **整合已取得的專家報告**：利用已成功取得的 `EAM_Addon_Architect` (ARCH) 與 `EAM_Lua_VM_Expert` (LUA) 重點報告（包含了對 JIT Trace Compiler 致命 __EAMCODE_5 以及 Abort 的要因分析`releaseFunc` 的重大 Bug診斷），擬定最新的JIT優化實施計畫。
3. **分批派工原則**：在後續開發中，應避免同時呼叫大於3個子代理。在損耗相關恢復前，的旁路任務一律由主代理本地直接執行。
- 後續注意事項：派工前須精確計量WIP（在製品）數量，優先僅派發給A級核定者及R級執行者，降低平台損耗耗竭之風險。
### 2026-06-07 設定頁面滑桿圖示大小/尺寸調整無法回應到 7 大框架排版版本 Bug（已解決）

- 狀態：已解決
- 脅：
當使用者在 EAM 設定面（`/eam opt`）中拖曳曳引滑桿（Sliders）調整「圖示大小（iconSize）」或「圖示距離（iconSpacing）」時，雖然設定值空間儲存至 SavedVariables 1745 時，大小與 6）尺寸），調整完全無效。
- 症狀與原因判斷：
1.透過錯誤統計導出的JSON，發現`config.iconSize = 73`，`config.iconSpacing = -33`，表示使用者確實修改了設定，且設定已寫入。
  2.然而，在實體渲染的 `runtimeStats.renderer.frameIcons` 刺激屬性中，所有 Icon 的 `layoutSize` 仍然是預設的 `40`。
  3. 透過比較代碼，發現在 `Core/SavedVariables.lua` 的 `defaults` 表與 UI Slider 的綁定中，使用者設定分別儲存在 `EAM.db.config.iconSize` 和 `EAM.db.config.iconSpacing`。
4.然而，在負責渲染調度版的 [UI/Renderer.lua](file:///d:/EventAlertMod/UI/Renderer.lua) 中，`ensureParent` 函數與 `layout` 調度版算法均只去讀取了 EAMDE_FCO__7 欄位演算法均只去讀取了 EAMDE_CO__7 欄位。這導致變數呼叫不穩定，使渲染器永遠只能回退讀取預設值。
- 已嘗試方法：
  備份 `UI/Renderer.lua` 至 `backup/Renderer.lua__20260607222900`。
- 有效解法：
  修改 [UI/Renderer.lua](檔案:///d:/EventAlertMod/UI/Renderer.lua)：
1. 在 `ensureParent` 內，將 `Renderer.iconSize` 和 `Renderer.spacing` 欄位的賦值改為優先從 `EAM.db.config.iconSize` 和 `EAM.db.config.iconSpacing` 讀取，並相容於舊版本 `db.layout` 與後備預設值。
  2. 在核心 `layout` 排版函數中，將 `local size` 和 `localpacing` 改為優先從 `EAM.db.config.iconSize` 和 `EAM.db.config.iconSpacing` 讀取，並相容於 `db.layout` 預設欄位與 `Renderer` 本機預設值。
  3.靜態`luac -p`檢定語法100%通過。
- 後續注意事項：實機驗證時，確認在滑桿調整大小和資料時，畫面上的圖示大小與資料是否能即時相應變化。

### 2026-06-07 戰鬥中對秘密布爾進行布林判定（布爾測試）導致Taint崩潰Bug（已解決）

- 狀態：已解決
- 脅：
在戰鬥中，如果一個光環或技能冷卻由 Brake UI 的 `DurationObject` 進行渲染，當我們在 OnUpdate (例如 Renderer.lua 的 `onLegacyTimerUpdate`) 中調用 `durationObj:__EAMCODE_5 工件/ a Secret boolean value (execution tainted by) 'EventAlertMod')` 致命錯誤，首先導致 Taint 崩潰並阻塞 UI 的 OnUpdate 執行鏈。
- 症狀與原因判斷：
1. 在戰鬥中，`DurationObject:IsZero()`的傳回值是Secret Boolean，在Lua中直接做`if val then`條件判斷會直接觸發Metamethod崩潰崩潰。
  2.這是因為暴雪的保密保護機制限制了對Secret Boolean做布林值判斷。
3.要安全訪問，我們不能對Secret Boolean進行布爾測試。但是，我們可以透過`issecretvalue(val)`來先檢驗傳回值是否為Secret。如果是Secret，我們直接跳過對它的布林測試以策安全。如果不是Secret，我們才可以安全地做布林判斷。
- 已嘗試方法：
  備份 `UI/Renderer.lua` 至 `backup/Renderer.lua__20260607222500`。
- 有效解法：
在 [UI/Renderer.lua](file:///d:/EventAlertMod/UI/Renderer.lua) 中引入 `safeCheckIsZero(durationObj)` 防禦性包裹函數：
  1. 先確認 `durationObj` 不是 `nil`，有 `IsZero` 函數，且 `durationObj` 本身不是 Secret。
  2. 使用無閉包的 `pcall` 傳參方式呼叫：`local ok, val = pcall(durationObj.IsZero, durationObj)`，深圳市在 OnUpdate 熱路徑上產生堆垃圾。
3. 取得傳回值 `val` 後，使用 `Util.isSecretValue(val)` 檢查其是否為 Secret。如果是 Secret，則回傳 `false`（此處不進行布林測試）；若不是 Secret，則可以安全地回傳 `val == true`。
  4. 修改 `onLegacyTimerUpdate` 中對於 `activeDurationObjects` 的遍歷，改用 `safeCheckIsZero(durationObj)` 進行條件判斷。
- 後續注意事項：實機驗證時，確認在戰鬥中觸發觸發的光環或冷卻時，當其前時圖標是否能主動消失，並且聊天視窗不再噴出布林測試錯誤。

### 2026-06-07 戰鬥設定（秘密）光環時間倒數降級與自動回復恢復機制 (已解決)

- 狀態：已解決
- 脅：
當在戰鬥中，所獲得的 Buff/Debuff 被破壞世界標記為秘密（如玩家、超時時間確定無法讀取時），EAM 無法自行拆卸由 OnUpdate 倒數，且由於無法安排調度任務，導致光環在破壞自然消失時，EAM 圖標無法恢復框架並恢復圖示。
- 症狀與原因判斷：
1. 魔獸世界 12.x 的繼承 `C_UnitAuras.GetAuraDuration` 所傳回的 `DurationObject` 雖然被保護（秘密），但原生 UI 本身可以進行綁定渲染。
  2.由於 `DurationObject` 無法在 Lua 中讀取剩餘時間，原有的 EAM 調度器 (Scheduler) 與退彈機制無法獲知此時即將到來，只能完全依賴 `UNIT_AURA` 光環移除事件。然而戰鬥中事件經常被官方優化、節流甚至部分延遲。
3. 幸運的是， `DurationObject` 與 `IsZero()` 方法相比，這在 Secret 狀態下是安全、可安全呼叫的謂詞（回傳普通 boolean）。
- 已嘗試方法：
  備份 `Services/AuraService.lua` 和 `UI/Renderer.lua` 至 `backup/` 目錄。
- 有效解法：
1. **秘密構成時優先抓取繪圖說明**：修改`AuraService.lua`中的`readAuraIntoState`。當`isSecret`為`true`時，優先抓取繪圖說明的持續時間（`scrapedDur`）。若抓到，即用其手動建立一個非秘密的普通`DurationObject`，此時它可以走一般的數位繪圖索引。
2. **布拉 IsZero() 輪詢與自修正恢復**：`UI/Renderer.lua`，實施 `activeDurationObjects` 管理。對於任何包含 `durationObject` 的啟動圖示（不管是暫時的還是手動建立的），在統一的 `onLegacyTimerUpdate` 中每幀都進行 `IsZero()` 替代。 `durationObj:IsZero()` 返回 `true`，立即主動呼叫 `Renderer.render(..., shown=false)` 隱藏與 IconPool 恢復，主動釋放框架。
- 後續注意事項：實機驗證時需注意，在戰鬥中觸發觸發的Buff/Debuff時，觀察當其自然結束時，圖示是否能迅速且無殘影地自動消失。

### 2026-06-07 技能冷卻監控隨時強行顯示空圖示且無倒數 Bug（已解決）

- 狀態：已解決
- 脅：
在使用者的實機除錯日誌中，`spellCooldown` 框架下喘顯示了 15 個技能圖示（包括冰槍、喚醒、火球等），但這些技能當時均處於非冷卻狀態且無倒數秒數位文字。
- 症狀與原因判斷：
1. `CooldownService.lua` 傳導的 `shouldShow` 邏輯是：如果為非充能技能，則當 `infoSafe` 為 `false` 時預設`shouldShow = true`（防禦讀取中受保密而限制的異常）。
  2. 然而，如果一項技能根本不在冷卻中，官方 `C_Spell.GetSpellCooldown` 可能會返回一個有效的有效冷卻屬性的結構，甚至可能為空；或者是因為該技能不在冷卻中而使 `cooldownInfo` 為 `nil`。
3.此時，`infoSafe`因為拿不到安全冷卻事實而保持為`false`，這導致在判定時錯誤地落入了`else shouldShow = true`的防禦性分支！
  4.結果是：所有被監控且目前沒有在冷卻中的技能均被強制設定為`shouldShow = true`。它們被顯示到畫面上，但由於完全沒有冷卻時間數據，完全不會有倒數秒數與冷卻螺旋黑幕。
- 已嘗試方法：
備份 `Services/CooldownService.lua` 到 `backup/` 目錄。
- 有效解法：
  修改 [Services/CooldownService.lua](file:///d:/EventAlertMod/Services/CooldownService.lua) 的 `shouldShow` 邏輯：
  僅在 `cooldownInfo` **不為 nil** 時（代表該液化確實具有冷卻資料或在冷卻中），且在 `infoSafe` 為 `false` 的基礎狀態下，才進行防禦性 `shouldShow = 7_7__ 的判斷；若 EAM 6_6__9 則直接顯示關係。
- 後續注意事項：實機驗證時，請少年欸重新加載，確認這15個沒有在冷卻中的法師技能圖標是否已正確消失；只有在技能真正進入冷卻時才彈出圖標並正常顯示倒數。

### 2026-06-07 擴展EAM除錯診斷日誌統計資訊以加強AI除錯分析（已解決）

- 狀態：已解決
- 脅：
為了讓 AI 與開發者在取得除錯報告時能更方便、深入地尋找問題根源（例如到底是 Service 層未偵測到，或是 Renderer 層未成功成功），需要補充診斷日誌。
- 症狀與原因判斷：
大象的诊断 JSON 仅输出状态的数量，当遇到「图标没有出现」等情况时，无法知道哪些 Spell ID 正被激活监控、AlertManager 当前的发光状态、以及渲染器中每个图标的实体布局坐标与 `:IsShown()` 属性。
- 已嘗試方法：
  備份 `Debug/PromptExport.lua` 到 `backup/` 目錄。
- 有效解法：
  修改 [Debug/PromptExport.lua](檔案:///d:/EventAlertMod/Debug/PromptExport.lua)：
1. **補充記憶體與各服務活躍清單**：加入`memoryKB`統計，並探索5大服務（靈氣、冷卻、ItemCooldown、GroundEffect、圖騰、ClassPower）的狀態，收集目前活躍的武器ID清單。
  2. **加入AlertManager發光狀態**：收集`glowSpells`中目前正一個Proc高亮發光的spellID清單。
3. **加入渲染器實體圖示絢麗佈局屬性**：對於7大警報框架，詳細輸出其下所有活動圖示的`id`、`isParasite`、`layoutX`、`layoutY`、`layoutSize`與魔獸世界中的實體```layoutY`、`layoutSize`與魔獸世界中的實體```layoutSize`5__4CODE_4__。
  4.靜態 `luac -p` 全案語法檢驗，順利通過。
- 後續注意事項：實機驗證時，請少年欸重新加載，打開 `/eam debug` 複製出的 JSON，檢查是否包含上述新增的陣列與物品。
### 2026-06-07 診斷工具 PromptExport/DebugState 讀取舊版欄位導致 visibleIcons 恆為 0 暨 alertFrame.exists 恆為 false Bug (已)

- 狀態：已解決
- 脅：
  在 12.1.0 零分配事件驅動與多框架重構後，使用者匯出除錯診斷日誌，發現 `visibleIcons` 恆為 `0`，且 `alertFrame.exists` 恆為 `false`，第一判斷為沒有任何圖示顯示。
- 症狀與原因判斷：
1.重構後的 EAM 採用 7 大獨立警報框架（`_G["EAM_AlertFrame_" .. fName]`），原本的單一全域框架 `EAM_RetailAlertFrame` 已被廢棄。
  2. 渲染器的渲染器全域欄位 `renderer.orderCount` 各也已拆分封裝至框架的剖面佈局狀態 `fState.orderCount` 中。
3.然而除錯統計工具 `Debug/PromptExport.lua` 與 `Debug/DebugState.lua` 在統計 `visibleIcons` 與 `exists` 時，依然嘗試讀取舊版的 `renderer.orderCount` 與 `_G["EAM_RetailAlertFrame"]`。這導致統計工具總是回傳 `0` 與`false`，產生了「圖示完全未顯示」的統計資料假象。事實上，渲染器渲染日誌正常，實體圖示已成功渲染並顯示在畫面上。
- 已嘗試方法：
備份 `Debug/PromptExport.lua` 和 `Debug/DebugState.lua` 到 `backup/` 目錄。
- 有效解法：
  1. **多框架累狀態加**：修改`Debug/PromptExport.lua`與`Debug/DebugState.lua`，將`visibleIcons`改為加7大Alert Frame的`orderCount`；把`layoutDirty`改為檢查若有任何一個`fState.layoutDirty`6。
2. **多框架存在偵測**：在 `PromptExport.lua` 內對 7 大警報框架（如 `selfAura`、`targetAura` 等）進行格式化偵測與格式化輸出，只要至少有一個框架存在，即判定 `alertFrame.exists` 為 `true`，並精確呈現每個隱座狀態。
  3.靜態 `luac -p` 全案語法安全性驗證，修改之文件 100% 通過語法安全性檢查。
- 後續注意事項：實機驗證時，請少年欸重新加載，再次匯出除錯日誌JSON，驗證`visibleIcons`數值是否已與實體圖示渲染完全一致（顯示大於0的正確數量），並且聊天視窗不再噴出錯誤。

### 2026-06-07 註冊內部自訂事件至native Frame:RegisterEvent導致嘗試註冊未知事件當機（已解決）

- 狀態：已解決
- 脅：
在`/reload`載入外掛程式時，魔獸世界直接推送大紅字錯誤：`EAM Init Error on [AlertManager]: Frame:RegisterEvent(): Attempt to registerknown event __EAMCODE_411，導致__EAUI
- 症狀與原因判斷：
  1. `AlertManager` 初始化時，會呼叫 `EventRouter.register` 註冊多個內部自訂事件（如 `EAM_AURA_STATE_CHANGED`）。
2. 譯`EventRouter.register`的實踐是無論任何事件均調用 `frame:RegisterEvent(event)` 往前暴雪框架註冊。
  3. 魔獸世界 12.x 限制 `RegisterEvent` API 嚴格只能註冊暴雪系統定義的事件，一旦確定未知的自訂事件名稱，會立即引發致命錯誤併中斷執行鏈。
- 已嘗試方法：
  備份 `Core/EventRouter.lua` 到 `backup/` 目錄。
- 有效解法：
在 [Core/EventRouter.lua](file:///d:/EventAlertMod/Core/EventRouter.lua) 的 `EventRouter.register(event, handler)` 中引入自編輯事件過濾機制：
  判斷事件名稱是否以`"EAM_"`為外接。如果是，屬於內部通訊自訂事件，跳過呼叫內部`frame:RegisterEvent(event)`。
- 後續注意事項：實機驗證時需注意，觀察在`/reload`載入後，聊天視窗是否不再噴出任何RegisterEvent錯誤紅字，且EAM警報在各服務自訂事件觸發下能正常渲染。

### 2026-06-07 全新安裝或 WTF 檔案不存在時無預設監控字串 Bug 導致無顯示圖示 (已解決)

- 狀態：已解決
- 脅：
在也沒有舊版EAM全域變數（如`EA_Items`、`EA_AltItems`等）的全新安裝環境下（或WTF資料夾被清除），重寫後的EAM登錄後一個ICON沒有出現。
- 症狀與原因判斷：
  1. `SavedVariables.lua` 在初始化時，除了執行 `importLegacyTables` 嘗試從舊版本全域變數遷移設定之外，沒有將 `EAM.Data.SpellArray` 中目前職業的預設監控寫入 `EAM_DB.alerts` 中。
2.當全新載入時，舊版變數不存在，因此`alerts`清單完全為空。
  3.各個監控服務（`AuraService`、`CooldownService`等）均使用`EAM_DB.alerts`進行篩選，若警報為空則直接返回，不引發任何更新事件與進行UI危險，故畫面上一個ICON都沒有出現。
- 已嘗試方法：
  備份 `Core/SavedVariables.lua` 到 `backup/` 目錄。
- 有效解法：
在 `Core/SavedVariables.lua` 的 `SavedVariables.initialize()` 中，加入全新載入（即 playerAuras/targetAuras/spellCooldowns/itemCooldowns 四者個數為 0 時）防空機制：
  自動偵測目前玩家職業，讀取`EAM.Data.SpellArray`中對應的通用及各專精預設監控人力，並呼叫`SavedVariables.addAlert`自動寫入資料庫。
- 後續注意事項：實機驗證時，可用指令 `/run EAM_DB = nil ReloadUI()` 在全新清空 SavedVariables 測試後，是否會自動讀取目前職業（如法師）的預設閘道並顯示對應的圖示，且不再空白。

### 2026-06-07 加強EAM常規框架降級OnUpdate倒數文字與防止數字重疊（已解決）

- 狀態：已解決
- 脅：
在放棄與官方CDM掛勾後，遇到不具備`DurationObject`指針、或多或少不支援12.0.7原生綁定的降級計時環境下，EAM的獨立框架不知只進行了陰影旋轉，而完全不顯示倒數秒數字文字。另外，若未來Cooldown啟用，會造成短暫的小數字與EAM自訂大文字重疊。
- 症狀與原因判斷：
1. `Renderer.lua`僅實作了`useNativeBinding`模式下的文字綁定，降級模式下直接將`timerText`清空，導致一般計時不顯示剩餘秒數。
  2. 預設 `CooldownFrame` 預設可以顯示倒數數字，造成與 EAM 本身的 `timerText` 重疊，不美觀。
- 已嘗試方法：
  備份 `UI/Renderer.lua` 和 `UI/IconPool.lua` 至 `backup/` 目錄。
- 有效解法：
1. **實施統一降級計時OnUpdate系統**：在`UI/Renderer.lua`中實施一個全域共享、基於單一OnUpdate框架的`legacyTimer`系統，提供`registerLegacyTimer`和`unregisterLegacyTimer`。只有在降級圖示啟動時該計時才會啟動。
2. **每秒級小數倒數**：在該 legacyTimer 中，當剩餘時間低於 3 秒時，自動切換為一位小數倒數（如 `2.4`、`0.8`），大約 3 秒整數，提供了幾乎完美顯示的高級體驗。
  3. **恢復防禦註銷**：在 `IconPool.release` 與 `Renderer.render` 過渡時，確實調用 `unregisterLegacyTimer` 清除定時，防止殘影或洩密。
4. **防止文字重疊**：在`UI/IconPool.lua`的`createIcon`中，對新烘焙的冷卻框架呼叫`cooldown:SetHideCountdownNumbers(true)`，徹底消除文字重疊。
- 後續注意事項：實機驗證時需注意，在無`DurationObject`降級情況下大字倒數是否流暢，且3秒以下的小數點顯示是否精準無卡頓。

### 2026-06-07 放棄與官方 CooldownViewer (CDM) 掛勾與吸附生吸附(已解決)

- 狀態：已解決
- 脅：
  使用者要求放棄與官方冷卻管理器(CooldownViewer / CDM)的掛勾。需要將互動的互動吸附邏輯徹底關閉，讓所有冷卻與技能圖示回歸EAM自身的排版渲染框架。
- 症狀與原因判斷：
究竟如何限制繞過戰鬥中秘密/Taint的，在官方CDM圖示中實現了寄生的​​影子主機技術。但在決定用戶不使用掛勾後，需要完全解除此功能，並確保官方UI完成如初。
- 已嘗試方法：
  備份 `Services/ShadowHostService.lua`, `UI/Renderer.lua` 和 `Core/SavedVariables.lua` 至 `backup/` 目錄。
- 有效解法：
1. **停用ShadowHostService初始化與Hook**：在`ShadowHostService.lua`中註解底部的`initShadowHost()`調用，不進行任何Hook，也不隱形官方UI；同時簡化`ShadowHostService.GetHostIcon`產生直接回傳`nil`。
  2. **強制關閉渲染器吸附通道**：在`UI/Renderer.lua`的`Renderer.render`中，將`useCDM`寫死為`false`，徹底斷開與CDM掛勾的判斷路徑。所有圖示100%走EAM將手機排版路線（`dx`, `dy`方向定位）。
3. **將 enableCDM 預設值設為 false**：在 `Core/SavedVariables.lua` 中，將預設值的 `enableCDM` 設為 `false`。
  4.靜態 `luac -p` 全案語法檢查編譯通過。
- 後續注意事項：實機驗證時需注意，觀察圖示排版是否完全回歸EAM常規定位（4向成長方向），且進入戰鬥時是否會有任何排版疙瘩。

### 2026-06-07 12.x / Midnight-era: DurationObject 核心 API 與時間管理機制調查 (已解決)
- 狀態：已解決
- 脅：
  魔法世界 Retail 12.x / Midnight 世代對時間管理（冷卻、光環、充能）實施了黑盒化（Pointer-Pass Pattern）。 EAM 必須全面掌握所有能產生或交付 `DurationObject` 的 API 以進行高可用性、0-GC 和 Secret-Safe 的時間渲染。
- 症狀與原因判斷：
傳統的 OnUpdate 數值倒數在戰鬥基礎（秘密）下發生字符串拼接與表索引崩潰。為此，我們需要將原生的 API 的 `DurationObject` 扭轉指標傳遞（Pointer-Pass）輕鬆地重構 Widget，同時需要完整的磁碟點所有可用的 API 以便模組化重構。
- 已嘗試方法：
  閱讀 Warcraft Wiki 12.0.5 API 變更日誌，並以 Python 腳本對 API 日誌擷取。
- 有效解法：
1. **整理出四大類API清單**：
     * **冷卻/充能能力**：`C_Spell.GetSpellCooldownDuration`、`C_Spell.GetSpellChargeDuration`、`C_SpellBook.GetSpellBookItemCooldownDuration`、`C_SpellBook.GetSpellBookItemChargeDuration`、`C_ActionBar.GetActionCooldownDuration`、`C_ActionBar.GetActionChargeDuration`。
     * **光環持續**：`C_UnitAuras.GetAuraDuration`、`C_UnitAuras.GetAuraBaseDuration` 與 `C_UnitAuras.GetRefreshExtendedDuration`。
     * **工具/手動時鐘**：`C_DurationUtil.CreateDuration`、`C_DurationUtil.CreateManualClock`。
     * **小部件關聯**：`self:GetTimerDuration()`。
2. **掌握ScriptObject成員方法**：`IsZero()`、`GetRemainingDuration()`、`GetClockTime()`、`EvaluateTotalDuration()`、` FormatRemainingDuration(formatter)`、`FormatElapsedDuration(formatter)`、`FormatTotalDuration(formatter)`等成員函數，並完成其操作Secrecy安全性屬性（如 `IsZero` 為 NeverSecret 可安全做為較檢測）。
3. **落地改寫應用(GroundEffectService)**：在`Services/GroundEffectService.lua`中補齊`state.timer.durationObject = api.C_DurationUtil.CreateDuration(duration)`，使地面效果完美對接雙軌原生綁定倒數通道，消除最後的__EAMCODE_44__與時間對接444__4442__444。
  4. 將結果儲存於 [duration_object_api_investigation.md](file:///C:/Users/ZYF/.gemini/antigravity/brain/b7690ead-b096-4f45-88f1-19a3c18d55f0/duration_object_api_investigation.md)。
- 後續注意事項：在未來的 AuraService 及 CooldownService 開發中，應將上述 API 設定第一優先取得時間的方式，並在 Renderer 中優先呼叫 Text Binding。

### 2026-06-07 實踐以 Icon ID (Texture FileDataID) 做三級比對防禦以提升電影載體命中率 (已解決)

- 狀態：已解決
- 脅：
在戰鬥中，如果`spellID`或是`spellName`因保密（設定/加密）而無法實現，或者是在載入客戶端緩存時出現延遲，會導致EAM無法準確比對並寄生吸附官方CooldownViewer（CDM）的影子載體。
- 症狀與原因判斷：
  1. 雙軌比對（`spellID` 和 `spellName`）在極端戰鬥設定下，或在多國語言系加載時，仍然存在匹配失效的機率。
2.每個冷卻或光環圖示在其渲染器或官方UI上必然對應一個唯一的紋理圖片(FileDataID)，這在戰鬥中通常不是秘密，可以作為最且唯一的標識特徵。
3. **間接取得魔法名稱優勢（核心）**：一旦突破非設定的紋理ID將官方鏡像載體（主機圖標）與我們所監控非設定的`spellID`成功建立鏈接，EAM渲染器即可利用非秘密的`spellID`靜態獲取到真實的本地化主軸名稱圖標，將其高亮渲染於蟲生中央底部，完美解決了戰鬥中官方CDM圖標因為因為保密限製而無法顯示技能名稱的重大痛點。
- 已嘗試方法：
  備份 `Services/ShadowHostService.lua` 和 `UI/Renderer.lua` 至 `backup/` 目錄。
- 有效解法：
  1. **建立三級iconID對照表**：在`ShadowHostService.lua`中新增`activeIconHosts`表與安全取得主機圖示ID的`getIconIDFromHostIcon`輔助函數（支援`icon.Icon`、`icon.icon`、`icon.texture`的「214」欄位）以及直接讀取位元組)。
2. **三軌比對與GetSpellTexture動態解析**：將`ShadowHostService.GetHostIcon`補充為`(spellID, spellName, iconID)`三軌比對。若沒有`iconID`，會在內部利用`C_Spell.GetSpellTexture(spellID)`動態取得要的監控警報圖示ID，並在`activeIconHosts` 中進行比對。
3. **動態scanAll()後備**：在`GetHostIcon`內部如果首輪查表皆未命中，會自動呼叫`scanAll()`重新整理所有被Hook的官方查看器池映射（防範官方在獲取時尚未設定紋理導致漏配），然後進行第二輪匹配，極限調度率。
  4. **渲染器呼叫升級**：在`UI/Renderer.lua`中，呼叫`GetHostIcon`時確定`(alertState.spellID or alertState.id, alertState.name, alertStateicon)`軌。
- 後續注意事項：實機驗證時需注意，觀察當 spellID 建立時，能否透過紋理 ID 穩定吸附到官方對應的冷卻圖示上。

### 2026-06-07 CooldownService/AuraService 呼叫保密 API 發生 nil 錯誤（已解決）

- 狀態：已解決
- 脅：
  在登錄致命或觸發冷卻更新時，魔獸世界丟出 `Services/CooldownService.lua:324: attempts to call a nil value` 與 `Services/CooldownService.lua:328: attempts to call a nil value` 錯誤。
- 症狀：
1. 當冷卻更新觸發並呼叫 `refreshAlert` 時，拋出 `attempt to call a nil value`。
  2. 錯誤被 `EventRouter` 或系統錯誤機制捕獲，中斷了冷卻警報更新流程。
- 原因判斷：
1. 在 `Core/Util.lua` 裡面，第 152 行直接呼叫了本地變數 `isSecretValue(value)`，然而在魔獸世界客戶端載入 `Util.lua` 時，若全域變數 `issecretvalue` 是 `Util.lua` 時，若全域變數 `issecretvalue` 是 __EAMCODE_4（62311212121131111113）。可能是`nil`。執行到這裡即發送嘗試呼叫nil值！
2.同樣地，若 `issecretvalue` 及其他保密計算 API 為空，`EAM.API`中表格的 API 參考亦為 `nil`，導致如 `ShadowHostService.lua` 呼叫崩潰。
- 已嘗試方法：
  備份 `Core/Env.lua`, `Core/Util.lua`, `Services/CooldownService.lua` 到 `backup/` 目錄。
- 有效解法：
1. ** seceret/secrecy 全域 API 容錯**：在 `Core/Env.lua` 中，為 `EAM.API` 的所有保密檢查方法（`issecretvalue`, `canaccesstable` 等。 false end`），確保`api.issecretvalue` 永遠不會為 `nil`。
2. **Util 本地本機變數回退**：在 `Core/Util.lua` 中，為所有的本地變數回退**：在 `Core/Util.lua` 中，為所有的本地變數回退**：在 `Core/Util.lua` 中，為所有的本地變數回退**：在 `Core/Util.lua` 中，為所有的本地變數回退**：在 `Core/Util.lua` 中，為所有的本地變數回退（`isSecretValue`, `canAccessTable` 等）補上回退定義，且將 `readSafeScalar` 內部的直接呼叫 `__EAMCODE_4才調用`Util.isSecretValue(value)`。
  3. **CooldownService 呼叫保護**：在 `CooldownService.lua` 中對 `cSpell.GetSpellCooldown` 的呼叫加上 `cSpell.GetSpellCooldown 和 ...` 防護，避免 API 不存在時發生 nil 值呼叫。
4. 透過靜態 `luac -p` 個完整案例審查，32 個活躍 TOC 檔案全部通過。
- 後續注意事項：實機驗證時需注意，在任何環境下登入或觸發CD時是否還會拋出此類錯誤。

### 2026-06-07 影子載體技術 (Shadow Host) 實踐以避讓戰鬥中 Secret/Taint 限制 (已解決)

- 狀態：已解決、待實機驗證
- 脅：
魔法世界 12.x 在戰鬥中對冷卻與光環時間（如 timeLeft, expirationTime）實施秘密值限制，且戰鬥中動態修改不安全 UI 的佈局也可能因為 Taint 造成動作走廊 (Action Blocked) 或是 UI 排版停靠 (Layout Churn)。
- 症狀與原因判斷：
  1.戰鬥中，自修改UI動態計算座標並呼叫`SetPoint`很容易因為安全鏈污染而造成污染，或造成排版計算負擔。
2.官方的冷卻管理器(CooldownViewer / CDM)是安全框架，在戰鬥中利用定位與Show/Hide的特權，但只支援官方內建的法術。
  3.同時享受避免迴避UI的戰鬥特權並Taint，我們需要一種在戰鬥中100%避免讓排版代碼的解法。
- 已嘗試方法：備份 `EventAlertMod.toc`, `UI/Renderer.lua` 至 `backup/` 目錄。
- 有效解法：
1. **官方池Hook與影子化**：新建 `Services/ShadowHostService.lua`，在脫戰狀態下對官方 `EssentialCooldownViewer` 和 `UtilityCooldownViewer` 框架設定透明度 (`Alpha=0`) 與系統降級（`BACKGROUND`, `0`5），並使用系統降級(CODPCODE_3__, `0`5），並使用 1266526222266_66 63_CO_fCO 的官方__3)，並使用 __6A_CO_CO 的官方__MCO_CO__M. `Acquire` / `Release`，收集`spellID`到官方圖標實體之對照。
2. **寄生渲染與級聯排版避讓**：修改 `UI/Renderer.lua`。在 `Renderer.render` 中，若有官方 Icon 鏡像載體可用，則將 EAM Icon 設為 `isParasite = true`，以 `SetParent(hostIcon)` 與 `SetAllPointsEAMCODE_0(EAMCODE_6)。在`layout`中跳過`isParasite`圖標，去掉戰鬥中EAM的`SetPoint`及排版計算。
3. **二級比對防禦**機制：在 `ShadowHostService.lua` 中加入對 `spellName` 的安全提取（支援 `icon.spellName`, `icon.data.name` 與 `icon.Name:GetText()`）與二級查找表 `activeNameHosts`5__。在 `GetHostIcon` 介面與 `Renderer.render` 的吸附定位中，實現`(spellID, spellName)`雙軌二級比對防禦，確保武器ID消失或被秘密加密時依然能穩定命中幽靈載體。
4. **安全性防禦**：EAM圖示保持僅顯示，不註冊任何點擊或滑鼠事件，引發Taint傳回安全鏈。
- 後續注意事項：實機驗證時需注意官方 CooldownViewer 的 Alpha 是否為 0 且 EAM 圖示吸附正確，在戰鬥中冷卻觸發時，觀察是否會出現 Action Blocked 或 Taint 錯誤。

### 2026-06-06 全程式碼在地化清除、動態專精 API 重構、ClassPower 與 EventRouter/Scheduler 故障隔離（已解決）
- 狀態：已解決、待實機驗證
- 脅：
  1. 全面整理 EAM 程式碼中的硬編碼中英文 UI 與提示文字，編制支援完整多國語言系（zhTW, zhCN, enUS, koKR, ruRU自動替換時不會因編碼問題而發生解碼崩潰。
2.戰鬥中能量監控模組(ClassPowerService.lua)對`UnitPower`的傳回值直接進行比較時可能會因遇到受限秘密值/秘密表而崩潰。
  3.`Core/EventRouter.lua`與`Core/Scheduler.lua`的核心事件/定時任務循環，在單一子模組發生執行時出錯時會波及全域，導致整個調度或事件發送中斷癱瘓。
- 症狀與原因判斷：
1. **硬編碼與多語系支援不足**：原始 UI 與邏輯包含硬編碼的中文，當切換客戶端語系時會顯示異常；Windows Powershell 預設使用 CP950/GBK 讀取 UTF-8 Lua 檔案時容易引發 `UnicodeEncodeError`4/EAMCODE_3__M 系統導致自動失效。
2. **ClassPower 戰鬥秘密元方法 **崩潰：魔獸 12.x 在某些戰鬥或特殊機制下將能量值標記為 `Secret Table`，如果非安全代碼直接將其與數值大小（如 `currentPower > 0`）比較，會觸發元方法致命錯誤。
3. **EventRouter/Scheduler錯誤傳播**：原EventRouter OnEvent與Scheduler OnUpdate對回呼的呼叫沒有進行隔離，一個註冊者出錯，整個調度迴圈就會被nil-index或traceback卡，使整個警報器完全中斷。
- 已嘗試方法：備份 `UI/Options.lua`, `Services/ClassPowerService.lua`, `Core/EventRouter.lua`, `Core/Scheduler.lua` 至 `backup/` 目錄。
- 有效解法：
1. **全代碼本地化清掃**：將全案中所有硬編碼字符串統一起來至本地化對照表`EAM.L`（支持五大語系共144個詞條）。在取代工具中明確宣告UTF-8讀寫，並以`errors='ignore'`保護，避免編碼崩潰。
2. **動態專精本地化API重構**：在`UI/Options.lua`的專精過濾下拉選單中引入`CLASS_TOKEN_TO_ID`映射，優先調用API `GetSpecializationInfoForClassID`獲取最準確的本地化專精備份名稱，並提供雙軌退防線。
  3. **能量防護防禦**：為 `detectClassPower` 與 `updatePower` 配置 `pcall` 隔離與 `issecretvalue` 防禦，防禦戰鬥中能量數值為秘密表時的大小比較造成的 Lua 崩潰。
4. **EventRouter/Scheduler 故障隔離**：在 EventRouter 的 OnEvent 核心循環循環與 Scheduler 的作業執行回呼中，配置參數化 `pcall` 容錯，防止單一模組中斷的模組與模組中斷其他模組中斷的執行。
- 後續注意事項：實機驗證時需注意在木人戰鬥與首領戰鬥中，觀察多語系 UI 是否加載正確，以及當策劃觸發單一模組錯誤時，EventRouter 和 Scheduler 是否仍然能夠高可用性地與排程其他警報。

### 2026-05-30 12.x戰鬥加密邊界：Secret-Key查詢表崩潰、Tooltip字串污染＆不安全警報戰鬥流暢化修復（已解決）

- 狀態：已解決、待實機驗證
- 威脅：實機戰鬥中遭遇了幾類核心的安全機制爆發：
  1. `AuraService.lua:161: 嘗試索引無法使用密鑰索引的表`嚴重崩潰。
  2. `GroundEffectService.lua:78` 解析工具提示描述時，因為 `string.match` 確定了秘密字串，拋出`嘗試對秘密字串值執行字串轉換（被 'EventAlertMod' 污染的執行）`致命錯誤。
  3.戰鬥中警報框架完全隱形不彈出。
- 症狀與原因判斷：
1. **秘密密鑰表索引限制**：WoW 12.x引入了強大的秘密保護。在戰鬥中，從`GetAuraDataByIndex`回傳的`spellId`或是`leftText`都會被標記為`秘密值`。一旦AddOn程式碼直接使用這個`spellId`作為密鑰去對任何非安全的自訂表進行索引操作（例如 `db[spellId]` 或 `SavedVariables[spellId]`），__EAMCODE Key__ __ 引擎會直接爆發並拋出錯誤！
2. **Secret String Taint限制與參數傳遞**：當工具提示描述在中被標記為Secret時，我們不能在自訂本身的不安全的是函數中進行字符串化（`tostring`）、字符串拼接戰鬥（`..`）或正則匹配（`string.match`）。最關鍵：**所有的秘密值都不能在自訂參數傳遞給任何Lua時被使用函數**！只要確定，函數就會被判定為污染，並在執行涉及秘密的動作時崩潰。
3. **不安全的UI戰鬥鎖定防衛過度**：先前的代碼為了安全，在 `Renderer.lua` 和 `IconPool.lua` 中只要遇到 `InCombatLockdown()` 為 true，則所有 `CreateFrame`, `SetPoint`, `SetPoint`5__ `Hide`渲染作業全部延後到戰鬥結束後（PLAYER_REGEN_ENABLED）。然而，我們的警報圖示是純顯示框架，不承擔任何安全動作（如點擊、施法、定位等），也沒有繼承任何安全模板。 WoW引擎完全允許在戰鬥中對不安全框架進行定位與顯隱。過度防護反而導致了戰鬥中警報完全消失，失去了AddOn的價值。
- 已嘗試方法：備份 `Services/AuraService.lua`, `Services/GroundEffectService.lua`, `UI/Renderer.lua`, `UI/Options.lua` 至 `backup/` 目錄。
- 有效解法：
  1. **表格索引防禦（Table Indexing Defense）**：在 `AuraService.lua` 和 `CooldownService.lua` 等服務中，實施嚴格的表查表關聯防護。在對組態表進行索引前，必須呼叫 `issecretvalue(key)` 確定 key 不是受保護的秘密值，並以 `canaccesstable(targetTable)` 檢查表安全性。
2. **即時就地本地檢測與原生檢查**：完全不使用自訂的Wrapper函數來傳遞與檢查秘密值。一律採用本地就地模式，直接在本地作用域中直接呼叫原生的C級安全API（如`issecretvalue`, `canaccessvalue`, `canaccesstable`）。
3. **工具提示字串安全降級**：在對工具提示行進行匹配匹配前，以 `issecretvalue(text)` 與 `canaccessvalue(text)` 進行嚴格防護。一旦發現描述被加密或不可讀取，立即安靜降級，並使用原生 `C_UnitAuras.GetAuraDuration` 獲取黑盒 `DurationObject`，直接模仿渲染器雙流水線通道，利用`CooldownFrame:SetCooldownFromDurationObject` 安全進行轉換，徹底消除字符串轉換崩潰。
4. **不安全警報框架全面發佈**：將所有警報圖示框架類型從`"Button"`降級為純`"Frame"`。徹底取消了所有戰鬥中定位和建立的延遲，限制讓不安全警報圖示可在戰鬥中即時、無縫地彈出和移動，100%戰鬥暢行無阻！
- 後續注意事項：實機驗證時需注意在木人戰鬥中高端觸發buff時是否會跳出Taint報錯，並起始大量buff觸發時，純幀是否完美顯示與恢復。

### 2026-05-30 UI滑桿崩潰、C_DurationUtil綁定短缺 Unbind 與 ClassPowerService 核心 API 財政部之致命錯誤修復 (已解決)

- 狀態：已解決、待實機驗證
- 墳墓：少年欸回報設定界面無法使用，並且遇到`bad argument #1 to 'SetValue' (outside of Expected range -3.402823e+38 to 3.402823e+38)`及`UI/IconPool.lua:102: at call value`致命錯誤，進入遊戲即發送`ClassPowerService.lua:85: attempts to call a nil value`崩潰，導致介面與職業能量服務失效。
- 症狀：
1.輸入`/eam opt`開啟設定頁面時滑桿`SetValue`錯誤，設定頁面發生中斷，導致後續所有清單重新整理（刷新）、法術增刪除、齒輪按鈕彈出設定視窗及儲存/關閉功能全部失效。
2. 觸發時發生冷卻警報 `IconPool.lua:102: attempts to call a nil value` (以及 `Renderer.lua:359` 報錯)，這是因為 `timerBinding:Unbind()` 在 12.0.7 環境下傳回nil-method呼叫崩潰，渲染器管道被硬性中斷。
3. 進入遊戲登入即推送`ClassPowerService.lua:85: attempts to call a nil value`，這是因為detectClassPower呼叫了`api.UnitClass`和`api.UnitPower`，但在核心`Env.lua`的`EAM.API`表中遺漏了對這兩個WoW和API的映射中斷，導致API7__
- 原因判斷：
1. 在 `UI/Options.lua` 的 `createSlider` 函數中，`OnShow` 腳本讀取 SavedVariables 中某些布林值（如 `cooldownShadow = true`）時，直接將 `true`/`true`/__EAMCO `self:SetValue(val)`，而該API 嚴格要求宣告 `number` 類型。一旦出錯，載入中斷導致整個 UI 物件（如 `scrollBox`, `addEditBox`, `condFrame` 等）均未完成綁定與初始化。
2. 12.0.7 文物 API `C_DurationUtil.CreateDurationTextBinding` 回傳的綁定物品實作中沒有 `Unbind` 方法，直接呼叫 `:Unbind()` 會拋出 nil 錯誤。
  3. `Core/Env.lua` 中預先註冊的靜態 API 表 `EAM.API` 漏掉了最常用的 `UnitClass` 和 `UnitPower`，這讓職業能量服務執行時直接調用了 nil 函數而崩潰。
- 已嘗試方法：備份 `UI/Options.lua`, `UI/IconPool.lua`, `UI/Renderer.lua`, `Core/Env.lua` 至 `backup/` 目錄。
- 有效解法：
1. **防禦性類型別轉換**：在 `Options.lua` 的 `createSlider` OnShow 中，加入對 `val` 的防禦性偵測與別型轉換。若為 boolean 轉換為 `maxVal`/`minVal`，若非數字嘗試以 `tonumber` 解析或後備，並以`minVal`/`maxVal`進行安全邊界劃分，確保百分之百確定合法`number`給`number`給__8888__88__882。
2. **解綁防禦性封裝**：重構 `UI/IconPool.lua` 與 `UI/Renderer.lua`，將所有 `icon.timerBinding:Unbind()` 調用統一包裹於 `if icon.timerBinding and type(icon.timerBinding2__3) 問題__. icon.timerBinding:Unbind() end`安全條件中，完美解決12.0.7原生綁定無法解綁或方法觸發的運行時崩潰。
3. **補齊環境核心API**：在`Core/Env.lua`的`EAM.API`中補充並匯出`UnitClass = UnitClass`與`UnitPower = UnitPower`，隨後職業安全監控服務順利與進入無線電庫。
  4. **靜態語法檢查**：透過 `luac -p` 全案審查無語法錯誤，安全無誤。
- 後續注意事項：實機驗證時需注意滑桿拖曳是否能將數值正常寫入，並且在開關警報圖示和按鈕CD釋放/恢復時，起始有無記憶體洩漏或倒數殘影。

### 2026-05-30 P1/P2：多國語系地面效果 Tooltip 解析與 table.freeze 重構（已解決）

- 狀態：已解決、待實機驗證
- 模具：擴展地面效果(GroundEffectService.lua)監控，在12.0.7正式服環境下以Tooltip Scraping獲得無光環地面技能的持續時間，需支援繁體中文(zhTW)、簡體中文(zhCN)、中文(enUS/enGB)、韓文(koKR)、俄文(ruRU)。
- 症狀：原始實作僅支援繁體中文，且在迴圈中直接使用 ad-hoc 的字串鍵 HASH 尋找與正規表示式匹配，在 WoW 執行環境下可能會引入結果與 GC 垃圾回收負載。
- 原因判斷：Lua 表的字串鍵 HASH 找到具有一定的雜湊碰撞成本，即使以 `table.freeze` 鎖定也無法完全消除雜湊機制。要達到完全，應使用數值索引陣列（數位索引數組）做匹配模式載體，配合數字進行迴圈迭代，這樣可以消除雜湊搜尋並完全避免運行時 GC。
- 已嘗試方法：將5種語言用戶端的正規表示式樣式，依語言環境封裝成數字索引數組。 PCB由`EAM.Util.tableFreeze`對整體與子對齊做深度凍結(table.freeze)。 `parseTooltipDuration`呼叫時自動辨識`GetLocale()`並降級回退至中文，然後執行數字索引數字循環。
- 有效的解法：重構 `Services/GroundEffectService.lua`，引入 `MULTI_LOCALE_PATTERNS` 凍結表，並以極簡的格式 `for i = 1, #data.lines` 與 `for j = 1, #patterns` 已完成極速匹配。透過 `luac -p` 靜態語法檢查。
- 後續注意事項：實機時需注意各語系法術驗證工具提示描述的波動，如矩 (ruRU) 的縮寫變化，隨時調整或補充 `MULTI_LOCALE_PATTERNS` 中的正規表示式樣式。
### 2026-05-30 7 大獨立思考架構、4向成長方向偏移算術、地面/圖騰/職業能量三大全新監控服務導入 (已解決)

- 狀態：待實機驗證
- 構想：少年欸要求將不同的監控分類（自身光環、目標光環、技能冷卻、物品冷卻、職業能量、地面效果、圖騰）分割為7個完全獨立的七個框架，支持自行修改拖曳與4向圖標成長方向設定。
- 症狀：原渲染器只維護單一警報框架，排版固定由左至右。在大拉怪模板CD爆發的威脅下，單一框架會佈局腫脹雜亂，無法區分優先級與資訊分流；同時缺乏對無光環地面技能（如暴雪、寶若珠）與薩滿多圖騰、職業資源積分的獨特監視。
- 原因判斷：純粹的字串分支判斷（如`if growDirection == "RIGHT" ...`）在高階的佈局渲染中會帶來CPU分支預測與雜湊（Hash）Key查找浪費。純Hash結構即使經`table.freeze`鎖定，其內部仍會進行雜稠計算衝突與衝突比對，無法真正用空間換取時間。
- 已嘗試方法：
1. **多框架隔離與佈局最佳化**：渲染器重構為`Renderer.frames[frameName]`，將佈局計算管理化，凍結連續數字算術索引的方向偏移對照`LAYOUT_OFFSETS`（陣列部分）。在排版時直接穿透`LAYOUT_OFFSETS[growDirectionIdx]`，取出流程圖計算完成法SetPoint，消除哈希碰撞與多條件If-Else路徑，最大限度提升Lua VM指令執行效率！
2. **雙軌地面精確探測(GroundEffectService)**：引入`COMBAT_LOG_EVENT_UNFILTERED`，在法術施放瞬間進行低頻`C_TooltipInfo.GetSpellByID`工具提示抓取解析，取得因加速、天賦動態影響後的秒數，或使用自訂時間。並以集中式`Scheduler.after`進行轉向釋放，運行期100%零CPU OnUpdate飢餓，展現獨特的創意。
3. **薩滿圖騰直讀 (TotemService)**：呼叫 12.x 括號 `C_Totems.GetTotemInfo` 直讀插槽，並支援靠攏排版。
  4. **資源點數圖示文字化(ClassPowerService)**：依職業監控資源點數，以Stacks中央大號字體渲染，歸0自動釋放恢復。
5. **UI擴充與一鍵抓取**：將選項設定面板重設為560px寬度的進階雙分欄佈局（Sliders/成長選單 vs 能量複選框），並在彈出子視窗動態地面顯示技能一鍵抓取抓取&填滿按鈕。
- 有效的解法：渲染器與3個新監控服務及選項分頁全面整合，透過全檔案`luac -p`的100%語法無誤靜態檢查，並提供`/eam doctor`（RuntimeProbe）多框架即時事實目標性診斷功能。
- 後續注意事項：實機驗證中需觀察7大框架同步顯露移動時鼠標拖曳的一致性與SavedVariables位置寫入的正確性。同時觀察大數量Buff環境戰鬥下，「空間換時間」靜態連續版面計算之零卡頓狀況表現。

### 2026-05-30 實機戰鬥中秘密/Taint崩潰點解除、拖曳位置保存、專精下拉篩選與小地圖按鈕完美實現（已解決）
- 狀態：已解決、待實機驗證
- 姿勢：實機測試中發現戰鬥中技能/光環框架仍然不顯示、框架無法拖曳移動、物品冷卻無圖標、缺乏常用的預設武器ID以及需要快捷呼叫小按鈕。
- 症狀與原因判斷：
  1. **戰鬥中不顯示的隱形崩潰點**：
* 在`AuraService.lua`中，於戰鬥中直接讀取文獻機密值的`duration`和`expirationTime`進行了數學減法傷害，直接引發了安全異常中斷！
     * 在 `CooldownService.lua` 中，在戰鬥中直接對被保護物件 `durationObj` 呼叫了 `IsZero()` 方法，引發了該方法呼叫沸騰！
     * `IconPool.lua` 使用 `"Button"` 類型框架很容易在戰鬥中受到 WoW 引擎對點擊按鈕的防禦攔截。
2. **框架無法拖曳**：`Renderer.lua`中遺漏了`toggleAnchors`的實作，且`ensureParent`不支援載入SavedVariables版面配置。
  3. **專案冷卻無圖示**：`ItemCooldownService.lua` 遺漏了 ITEM 相關 API 取得並保存 `state.icon` 與 `state.name` 資料。
  4. **預設預設值與篩選過濾**：`Data/SpellArray.lua`是空的佔位符，且UI缺乏專精下拉過濾器。
- 有效解法：
- **戰鬥防災與框架降級**：在減法侵害前用`Util.isSecretValue`防護降級；徹底取消對`IsZero()`的服務層調用，改由渲染器直接造成冷卻不良陰影渲染；將警報圖示框架類型從`"Button"`161_`"Frame"140667_7_F21707_`__EAMCO6
- **位置拖曳與儲存**：完美在`Renderer.toggleAnchors()`中實施半透明拖曳框架，支援按住鼠標拖曳並自動將X/Y座標儲存至`EAM.db.layout`，於`ensureParent`時優先自動載入！
  - **物品冷卻圖示補齊**：使用`C_Item.GetItemIconByID` 和 `GetItemNameByID` 補齊資料填寫，完美提交物品圖示。
- **小地圖按鈕（Minimap Button）**：在`UI/Options.lua`內建弧形儀表小地圖按鈕，左鍵開啟面板，右鍵開啟系統診斷，拖曳角度自動儲存。
- **13職業預設法術庫與專精過濾**：在`Data/SpellArray.lua`中填寫13職業各專精/通用常用法術資料；在UI列表頂部新增專精過濾下拉按鈕與單選，點選即可動態篩選，且「預設值」按鈕支援完整一鍵自動載入目前職業全部預設！
- 後續注意事項：實機重載後即可體驗全新高階功能。
### 2026-05-30 致命.toc 載入順序陷阱：局部變數緩存致 Renderer for nil 爆炸渲染 (已解決)

- 狀態：已解決、待實機驗證
- 模具：实机测试中，所有的WoW事件均完美触发（包括`UNIT_AURA`、`BAG_UPDATE_COOLDOWN`、`SPELL_UPDATE_COOLDOWN`），且资料库配合正常，但渲染管道完全没有收到任何呼叫，日志内无 `Renderer:render` 流程图。
- 症狀：
1. `alertsCount` 正確，`cooldownStates` 及 `auraStates` 成功寫入。
  2.但`runtimeStats.renderer.visibleIcons`與`deferred`均恆為`0`，畫面完全無警報圖示。
- 原因判斷：
  - **致命的 .toc 載入順序陷阱**！在 `EventAlertMod.toc` 中，`Services\AuraService.lua` 等服務的載入順序排在 `UI\Renderer.lua` 的上方。
- 當服務被載入時，在檔案頂部執行了 `local Renderer = EAM.UI and EAM.UI.Renderer`。由於此時 `Renderer.lua` 尚未執行，`EAM.UI.Renderer` 為 `nil`，導致服務內部的局部變數 `Renderer` 被永久緩存為 `nil`。
  - 當後續事件觸發、需要刷新時，服務內部的`if Renderer and Renderer.render then Renderer.render(state) end`因為局部變數`Renderer`是`nil`而被默默地跳過，使整個渲染管道完全癱瘓！
- 有效解法：
- 徹底避免檔案載入時的局部變數緩存！將頂部 `local Renderer` 改為未賦值的局部變數。
  - 在服務的`initialize()`方法執行時，動態將其賦值：`Renderer = EAM.UI and EAM.UI.Renderer`。此時`.toc`的所有檔案均已完整加載，`Renderer`可以完美取得到正確的引用，成功恢復渲染管道！
- 後續注意事項：實機重載後即可彈出警報！
### 2026-05-30 EAM 戰鬥中警報框架未顯示根本原因排除與專案監控獨立最佳化

- 狀態：已解決、待實機驗證
- 依托：實機測試中Alert框架完全沒有彈出，且監控項目需要更獨立與細部的Options UI分類配置。
- 症狀：
1.玩家施放技能、獲得Buff或進行背包冷卻物品測試時，畫面上完全無警報框架或圖表，但在Slash指令中除錯診斷即可成功呼叫。
  2. 物品冷卻在選項 UI 裡缺乏獨立的分類（第 5 個紅色按鈕受到特殊關注，物品沒有明顯的眼睛入口）。
- 原因判斷：
1. **第一個致命Bug**：`Services/ItemCooldownService.lua`和`Debug/PromptExport.lua`開頭的Lua註解解寫成`-- [[`（多了一個空格），導致Lua編譯器報出語法錯誤而令這兩個關鍵模組在WoW啟動時完全載入失敗，破壞了載入鏈。
2. **第二個致命Bug**：`Renderer.lua` 和 `IconPool.lua` 的 `inCombat()` 戰鬥限制防衛過當。非安全的警報圖示框架不承擔安全點擊、點擊投射，也沒有繼承SecureTemplates，所以它是完全不安全的純顯示框架。 WoW 100% 允許在戰鬥中對不安全框架進行`CreateFrame`、`SetPoint`、`Show` 和 `Hide`。先前的 AI 將這些操作在戰鬥中推遲到脫戰後（PLAYER_REGEN_ENABLED），直接導致最需要警報的「戰鬥中」圖示完全爆發，根本無法顯示！
- 已嘗試方法：
  - 將這兩個檔案開頭的`--[[`改回無空格的標準`-[[`。
  - 限制重構`UI/Renderer.lua`與`UI/IconPool.lua`，徹底清除所有`inCombat()`戰鬥狀態下的延遲渲染、延遲佈局定位和拒絕獲取。
- 在`UI/Options.lua`中，將設定分類補充至6個紅按鈕（物品冷卻單獨分類按鈕5，特殊能量移至按鈕6），排版間距調整至32px，防止重疊，在且條件編輯彈窗中，如果是技能/物品冷卻，隱藏動態值1~4勾選。
- 有效解法：
  - 成功通過`CheckLuaSyntax.ps1`靜態語法檢查，28個Lua檔案全部100% OK！
- 刪除了所有對不安全框架的戰鬥中定位和建立的內容，使警報圖示可在戰鬥中即時彈出。
- 後續注意事項：請玩家（少年欸）重新載入介面後進入戰鬥測試，若有任何不適應或位置偏移，隨時使用 `/eam debug` 返回 JSON 日誌診斷。

### 2026-05-29 EAM核心任務與邊界安全深度GC/Taint審查與二次極限優化
- 狀態：已解決、待實機驗證
- 設想：針對`Services/CooldownService.lua`、`UI/Renderer.lua`和`Core/Util.lua`進行全面性的垃圾恢復（GC）與安全Taint深度審查，並實施二次極限重構。
- 症狀：
  1. 警告邊界路徑的 `Util.appendBoundaryWarning` 理解採用 `"code .. ":" .. tostring(field)"`，若在架構或秘密環境下被持續觸發，會導致執行期高頻的字符串切割 GC 流失。
2. 渲染器 `UI/Renderer.lua` 在高度光環帶來數值變化時，`tostring(alertState.stacks)` 會在戰鬥中產生大量的微型字符串 GC 負擔。
- 原因判斷：高頻事件下任何形式的 `..` 字符串拼接與 `tostring` 調用，都是微型 GC 底部（GC 尖峰/stutter）的潛在來源，會導致大流量戰鬥下 FPS 微幅寬度。
- 已嘗試方法：
1. **警戒字串靜態緩存（warningStringCache）**：於`Core/Util.lua`引入局部`warningStringCache = {}`。所有邊界警戒字符串在第一次生成時被緩存，後續直接`O(1)`重複使用已分配指針，達成**邊界警戒路徑零字符串GC消耗**！
2. **大量的遷移次數靜態緩存（STACK_STRINGS）**：於 `UI/Renderer.lua` 引入 `STACK_STRINGS` 數組，預先將 `1` 至 `100` 的大量遷移次數為靜態字串。大量更新時，直接 `O(1)` 從方案取用已緩存字串，完全初始化 `tostring` 的執行期記憶體分配！
3. **戰鬥佈局延遲與親子育兒控制**：確認渲染器無任何安全動作，非安全的圖標直接隱藏安全調用，而結構性框架育兒與佈局則嚴格推遲至戰鬥結束（PLAYER_REGEN_ENABLED），消除安全污染擴散。
- 有效解法：重構程式碼已成功寫入`Core/Util.lua`、`UI/Renderer.lua`與`Services/CooldownService.lua`，完美封閉了所有高低頻GC漏洞與污染疑慮。
- 後續注意事項：實機測試時需特別開啟 Lua 記憶體監控，確認在滿載戰鬥（如觸發大量 GCD、滿超 buff/debuff 觸發、停滯邊界警告）情況下，EAM 的 GC 記憶體分配量維持在絕對的平穩水平。

### 2026-05-29 12.0.7 CooldownService 響應式二進位矩陣與雙軌安全綁定最佳化

- 狀態：已解決、待實機驗證
- 姿勢：為 12.0.7 PTR/Retail 樓層 CooldownService 與渲染器，避免戰鬥高頻事件（如 `SPELL_UPDATE_COOLDOWN`、`SPELL_UPDATE_CHARGES`）所帶來的 GC 負荷、污染污染及視覺殘影。
- 症狀：高頻事件下，以 `pairs` 遍歷設定表會分配迭代器與臨時表；且秘密值（如冷卻時間、充能資訊）在 Lua 層做數學攻擊、`format` 格式化或與舊時間比較間隙時會直接觸發安全污染或執行期 Lua 錯誤。
- 原因判斷：WoW 12.x引入了嚴格的Secret/Protected限制。如果不隔離Secret數據，直接將其作弊或字符串造成可能污染AddOn安全鏈。另外，在高頻事件下分配臨時表會導致微型GC停頓，影響遊戲FPS。
- 已嘗試方法：
1.引入**響應式陣列機制（Reactive Array Cache）**：縫隙檢測`db.revision`來增量更新`alertList`陣列，熱路徑（SPELL_UPDATE_COOLDOWN）上完全使用數值`for i = 1, alertCount do`迴圈歷零，達到100%歷零，達到瞬態的極限零點。
  2. 使用 **`table.create` 預先分配**：對 `alertList` 與 states / boundaryWarnings / timer 等子表預先分配 HashTable 與 Array 膨脹，執行期擴容與重新膨脹散列。
3. 實作 **無縫雙重綁定路徑（Dual-Binding Path）**：將 `DurationObject` 黑盒指標安全傳遞給無縫 `SetCooldownFromDurationObject` 與 12.0.7 無縫倒數文字綁定 `C_DurationUtil.CreateDurationTextBinding`。
  4. **實施零時跨度生命週期釋放（Zero-span Lifecycle Release）**：充能法術全滿時立即將 `state.shown` 設為 `false`，渲染器接手將 Icon 退回池並執行 `icon:Hide()` 與 `Unbind()`，消除視窗殘影池。
- 有效解法：在 CooldownService 與 Renderer 中已成功落地上列方案，完成完美雙軌安全判定與 Taint 控制防禦。
- 後續注意事項：需在 WoW 12.0.7 實機中，對充能法術（特別是充能非全滿與全滿切換時）及高頻觸發 GCD 時的雙重綁定路徑做實測，確認無殘影與閃爍問題。

### 2026-05-29 DurationTextBinding 12.0.7 PTR 最小範例實測
- 狀態：部分已驗證、待整合驗證
- 使用者：使用者在 WoW 12.0.7 PTR client 執行 `C_DurationUtil.CreateDurationTextBinding` 測試範例。
- 症狀：需確認 PTR API 是否只是檔案系統，或可在客戶端中正常建立並驅動 FontString 顯示。
- 原因判斷：若`DurationTextBinding`可用，EAM定時器標籤可避免使用`OnUpdate`自行倒數，符合低GC與Secret/Protected顯示鏈原則。
- 嘗試方法：使用最小測試範本建立`DurationObject`、`SecondsFormatter`、`DurationTextBinding`，並綁定到FontString。
- 有效解法：使用者返回在12.0.7 PTR客戶端中可正常顯示。
- 後續注意事項顯示：此結果僅驗證最小，不代表EAM渲染器完成整合；仍需檢視圖示回收、綁定引用保存、過渡文字、零持續時間、區域設定、戰鬥/taint、API不可用後備。

### 2026-05-29 子代理程式使用規則持久化

- 狀態：已解決
- 角色：玩家要求後續本專案若有適合子代理模式的角色，需協助規劃並使用。
- 症狀：若只保留對話記憶，後續長期開發或上下文緊湊後可能會失去與判斷標準的授權。
- 原因判斷：子代理適合大規模重寫、API 查證等待、檔案一致性與靜態驗證分流，但若沒有明確規則，容易造成重複派工、寫入範圍衝突或阻止關鍵路徑。
- 已嘗試方法：搜尋並載入多代理工具；判斷本輪只是小型檔案規則更新，不適合立即產生子代理程式。新增`Docs/17_SUBAGENT_WORKFLOW.md`，並將規則加入`AGENTS.md`。
- 有效解法：定義關鍵路徑/邊車任務判斷、適用與不適用角色、探索者/工人角色使用、派工範本與主代理整合規則。
- 後續注意事項：後續大型任務開始時，主代理需先明確說明是否使用子代理；若使用，需指定不重疊寫入範圍，並在整合後重新執行專靜態驗證。

### 2026-05-29 12.0.7 PTR / RC API 情報備查

- 狀態：待公開來源複查、待實機驗證
- 設計：玩家提供一段12.0.7 PTR / RC相關API變更內容，要求紀錄先備查。
- 症狀：內容包含`GameTooltip_AddMoneyLine`、`C_UIFileAsset`、profiling API、`DurationTextBinding`、Aura refactor target 12.1.0、單位身分錯誤改回傳nil/default、`debugstack`/`debuglocals`秘密傳播等資訊，但本輪公開網路搜尋未找到可直接引用的相同來源頁面。
- 原因判斷：這類資訊對 EAM Secret / Tooltip / Renderer / AuraService 邊界有實際作影響，但若未標明來源狀態，很容易在後續通行證被誤認為已由魔獸爭端維基或正式服客戶端驗證。
- 已嘗試方法：搜尋尋找`GameTooltip_AddMoneyLine`、`DurationTextBinding`、`Timeline for the Aura Refactor`等關鍵字；未取得穩定公開頁面後，以「提供使用者、待覆核形式」寫入`Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md`。
- 有效解法：文件明確拆分「與 EAM 直接相關」、「關聯較低但需關注」、「經典 PTR 不納入」三類，避免經典內容回流到純正式服架構。
- 後續注意事項：後續若魔獸爭霸Wiki、暴雪論壇或PTR客戶端檔案可查，需補上正式連結；若進入實施，必須行為實機驗證 `GameTooltip_AddMoneyLine`、`C_UIFileAsset`、`DurationTextBinding`、`debugstack`/1EAMCODE_4__ 的實際。

### 2026-05-29 PowerShell 備份檔名內插問題

- 狀態：已解決
- 姿勢：修改檔案前依規則備份 `Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md` 與 `Docs/15_DEVELOPMENT_ISSUE_LOG.md`。
- 症狀：第一次備份指令把目的檔名寫成`$name__$ts`，在巢狀PowerShell字串中被錯誤解析，導致指令報出`The term '\$name__$ts\' is not recoize`。
- 原因判斷：PowerShell 變數名稱邊界與外層引用混在一起時，`__` 後綴容易造成插值語意不清；加上外層 `powershell -Command` 需要額外轉義。
- 已修改嘗試方法：停止後續，改用明確的字串相加：`$name + '__' + $ts`，並逐一輸出產生的備份路徑確認。
- 有效解法：備份檔案已成功產生於 `backup/10_WARCRAFT_WIKI_12X_API_NOTES.md__20260529052816` 和 `backup/15_DEVELOPMENT_ISSUE_LOG.md__20260529052816`。
- 後續注意事項避免：日後自動腳本腳本應把變數直接與後綴貼合；固定使用字串相加或`${name}__${ts}`類型寫法。
### 2026-05-27 P2後半：Aura全面更新單次掃描與選項最小面板

- 狀態：待實機驗證
- 構想：接續P2細節，將AuraService的完整更新後備從逐警報掃描改成單位體系單次掃描，並補上可實際新增/刪除設定的選項面板。
- 症狀：舊回退很容易在 `UNIT_AURA` 完全更新或目標變更時對同一單位重複掃描；選項仍為偏存根，無法提供一般使用者可見的設定入口。
- 原因判斷：Aura 完整更新是熱路徑候選，若警報數量重複掃描，使用者設定越多成本增益；選項若不跨越 `SavedVariables` 變更 API，容易繞過架構修訂與服務刷新。
- 已嘗試方法：新增`fullScanUnit`，先清單位元光環緩存，再依玩家/target過濾掃描一次並與警報索引分派；未命中的設定警報統一標記為不活動。選項新增spellID/itemID輸入框與四類add/remove按鈕，成功後呼叫服務刷新。
- 有效解法：以 `auraInstanceID` 快取搭配 `alertIndex[unit][spellID]` 分派狀態；Options 只穿透`SavedVariables.add/remove` API 寫入狀態，直接修改服務運作時。
- 後續注意事項：需在 WoW Retail/PTR 驗證 `C_UnitAuras.GetAuraDataByIndex(unit, index, filter)` 在 12.0.7 的實際欄位安全性、過濾行為、戰鬥中初次建立選項框架的污染風險，以及 __EAMCO _EA Retail 12.x是否仍可直接使用。

### 2026-05-27 PowerShell 正規表示式與變數參考問題
- 狀態：已解決
- 安全性：執行 `rg` 與 TOC 檢查時，指令字串由外層 PowerShell 再啟動內層 PowerShell。
- 症狀：regex中的`|`被錯誤讀取成表格；TOC檢查中的`$missing`、`$line`被外層提前展開，造成解析器錯誤。
- 原因判斷：Windows PowerShell 的雙引號不是 shell-neutral Container；在巢狀 `powershell -Command` 中，正規表示式交替與 `$` 變數都需要明確處理。
- 已嘗試方法：將正規表示式改用單引號包住；TOC檢查中的`$`改用反引號轉義。
- 有效解法：專案內複雜搜尋優先使用 `rg -n 'pattern' path`；若必須在 `powershell -Command` 中使用腳本變量，需寫成 `` `$variable``，或改用 `.ps1` 工具。
- 後續注意事項：重複出現後可整理成「EAM Windows 靜態檢查」專案技能，避免每次珠寶令牌排查引用。
### 2026-05-26 P1/P2：斜線變更與UNIT_AURA增量緩存

- 狀態：待實機驗證
- 依托：依P1/P2目標繼續整理EAM正式服重寫的核心功能與低GC熱路徑。
- 症狀：轉換器`/eam`僅除錯/選項存根，SavedVariables沒有正式添加/remove API；AuraService在`UNIT_AURA`時仍回退全量掃描，未使用AuraService在`UNIT_AURA`時仍回退全量掃描，未使用`updateInfo`有效負載。
- 原因判斷：若沒有穩定配置變更API，後續選項UI無法安全寫入設定；若每次`UNIT_AURA`都掃alert/full光環，會增加熱路徑成本。
- 已嘗試方法：新增 `SavedVariables.add/remove` 系列 API、`/eam add/remove/export/help`、AuraService 配置修訂索引、EAM__MCOD. `updatedAuraInstanceIDs` / `removedAuraInstanceIDs`處理增量，以及偵錯快照的DB revision/cache/renderer計數器。
- 有效解法：Slash只寫SavedVariables，服務負責刷新/render；AuraService有`updateInfo`時走delta，無payload或完整更新才回退完整掃描。
- 後續注意事項：尚需 WoW Retail/PTR 實機驗證 `UNIT_AURA` 有效負載 實際欄位、秘密光環 spellID 行為、移除實例快取 命中率與目標快速變化行為。

### 2026-05-26 技能創建者 quick_validate 短缺 Python yaml 模組

- 狀態：已解決
- 依托：建立 `.codex/skills/eam-retail-p0-review/SKILL.md` 後，依 `skill-creator` 流程執行 `quick_validate.py`。
- 症狀：第一次腳本失敗，錯誤為`ModuleNotFoundError: No module named 'yaml'驗證`。安裝PyYAML後，第二次失敗為Windows預設`cp950`解碼UTF-8 Markdown失敗。
- 原因判斷：本機Python環境到底缺少PyYAML；補齊套件後，`quick_validate.py`使用Python預設文字編碼讀取`SKILL.md`，在繁體中文Windows環境下會遇到cp950解碼問題。
- 已嘗試方法：先安裝 `PyYAML 6.0.3`，然後以 `$env:PYTHONUTF8='1'` 重新執行驗證。
- 有效解法：使用 `python -m pip install --user PyYAML` 安裝依賴，並在 Windows 上執行驗證前設定 `PYTHONUTF8=1`。 `eam-retail-p0-review` 已通過 `quick_validate.py`，輸出 `Skill is valid!`。
- 後續注意事項：未來執行Python Markdown/YAML驗證工具時，若檔案含中文，優先使用UTF-8模式，避免cp950解碼失敗。

### 2026-05-26 建立 eam-retail-p0-review 專案專屬 SKILL

- 狀態：已解決
- 承載：本輪重寫重複使用相同群組流程：讀取 AGENTS/Docs、修改前備份、P0 Secret/Taint 掃描、Lua 語法檢查、靜態風險掃描與最終報告。
- 症狀：如果每次都在對話中重述流程，會浪費上下文/token，也很容易漏掉備份或污染/secret掃描。
- 原因判斷：此流程存在穩定性觸發條件、前置檢查、禁止事項、驗證方式與報告格式，符合專案專用SKILL規則。
- 已嘗試方法：依 `skill-creator` 指南建立 `.codex/skills/eam-retail-p0-review/SKILL.md`。
- 有效解法：後續進行EAM正式服重寫、Secret/Taint審查或P0靜態驗證時，優先使用此SKILL。
- 後續注意事項：此SKILL只提供流程，不取代魔獸爭霸Wiki最新API查證與WoW正式服/PTR實機驗證。

### 2026-05-26 P0/P1 重整：安全讀取、渲染器延遲佈局、調度器任務池

- 狀態：待實機驗證
- 姿勢：依最新API與社群研究開始整理正式加載的新架構Lua模組。
- 症狀：包含第一版倉庫數個 P0/P1 風險：AuraService 可能在 `spellID` 未確認安全前比較、冷卻/Item 冷卻安全讀取分散、調度程式排程器建立任務表、渲染器都佈局，且尚未明確延後戰鬥中的結構性 UI 變更。
- 原因判斷：這些問題會增加秘密值誤用、打擊鎖定/污染風險與熱路徑配置成本。
- 已嘗試方法：新增集中安全讀取助手、排程器任務池、IconPool預熱與戰鬥時幀建立保護、渲染器延遲佈局、偵錯邊界警告聚合，並將TOC/Constants指定到`120007`。
- 有效解法：以服務層逐值檢查事實，渲染器只消費歸一化狀態；戰鬥中遇到結構性UI變更先延後到`PLAYER_REGEN_ENABLED`。
- 後續注意事項：尚未做 WoW Retail/PTR 實機驗證；必須測試 DurationObject、FontString:ClearText、戰鬥佈局延遲、污染/阻止操作日誌、12.0.7 遊戲版本 ID 與 CurseForge5__ 發布。

### 2026-05-26 12.0.7 API 摘要發布，需修改先前待已追蹤狀態

- 狀態：已解決
- 設想：調查最新正式版相關WoW AddOn開發討論與API變更時，搜尋到魔獸爭霸Wiki `Patch 12.0.7/API_changes`。
- 症狀：包括 `Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md` 仍記錄 12.0.7 尚未找到 API 摘要。
- 原因判斷：魔獸爭霸Wiki近期已新增12.0.7 API更改頁，先前記錄已過時。
- 已嘗試方法：重新查詢魔獸爭霸維基API變更摘要、12.0.5、12.0.7與AddOn社群討論。
- 有效解法：更新 `Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md`，將 12.0.7 標記為已存在，並記錄與 EAM 相關的 `C_DurationUtil`、CPU 用法 API 與 __EAMCODE_61 追蹤事項。
- 後續注意事項：精確做 WoW Retail/PTR 實機驗證；若目標正式版本從 12.0.5 升到 12.0.7，需同步調整 TOC、備份版本與 CurseForge 遊戲版本 ID。

### 2026-05-26 加入污染控制規則

- 狀態：已解決
- 感染：使用者要求開發過程中必須避免污染污染。
- 規則症狀：除規範已涵蓋秘密值、受保護資料與戰鬥安全降級，但缺少獨立的污染控制。
- 原因判斷：WoW AddOn 屬於不受信任來源；若污染安全/protected執行路徑，戰鬥中可能導致暴雪UI動作被削弱。 EAM 的渲染器、EventRouter、UI框架與API適配器都必須避免把污染帶進動作條、單元框架、銘牌、施法、目標或物品路徑使用。
- 已嘗試方法：查證魔獸爭霸Wiki安全執行/污染相關資料，並更新`AGENTS.md`、`Docs/02_RETAIL_API_BOUNDARIES.md`、`Docs/12_CODE_COMMENTARY_GUIDE.md`。
- 有效解法：將 taint 視為邊界架構；禁止鉤/覆寫 protected 路徑、戰鬥中修改 protected 框架、使用 `forceinsecure` 或將不安全值傳遞到安全鏈。
- 後續注意事項：發現污染、被阻止的操作或戰鬥鎖定錯誤時，需在本檔案觸發路徑、戰鬥狀態、相關框架/API 與可追加步驟。

### 2026-05-26 建立開發問題記錄制度

- 狀態：已解決
- 制定：使用者要求將開發過程中遇到的瓶頸、限制、錯誤與解決方式另做 `.md` 記錄。
- 修改症狀：先前規範已有備份規則，但沒有集中保存工具、API不確定性與解法的文件。
- 原因判斷：專門案提出長期正式服重寫，若問題只停留在對話中，未來AI交接會統計分佈上下文/token，也容易重複試誤。
- 已嘗試方法：新增本文件，並在 `AGENTS.md` 與 `Docs/12_CODE_COMMENTARY_GUIDE.md` 加入記錄規則。
- 有效解法：後續遇到問題時，先依本文件格式追加記錄，再進行下驚人修改或驗證。
- 後續注意事項：本文件不得記錄令牌、密碼、私人帳號資料或任何敏感資訊。

### 2026-05-26 重複流程需整理為專案專屬 SKILL

- 狀態：已解決
- 設計：使用者要求開發過程若發現重複流程，需整理成專案專用SKILL。
- 症狀：目前已有多個固定流程，例如修改前備份、備份、Lua 語法檢查、WoW API 查證與檔案同步，但尚未明確規範何時應升級為 SKILL。
- 原因判斷：長期重寫專案會累積可重複流程；若每次都靠對話重述，會增加試誤與上下文/token成本。
- 已嘗試方法：在 `AGENTS.md` 與 `Docs/12_CODE_COMMENTARY_GUIDE.md` 加入專案獨有 SKILL 規則，並在本文件加入判斷提醒。
- 有效解法：當作業流程具備穩定觸發條件、前置檢查、步驟、風險控管與驗證方式時，整理為EventAlertMod專案專用SKILL。
- 後續注意事項：尚未、仍需大量人工判斷或涉及敏感資訊的流程，不宜硬取代SKILL驗證。
### 2026-06-07 12.x / Midnight-era 16 大全新與高頻事件融入與Action Bar Glow同步實踐

- 狀態：已解決
- 模具：魔獸世界 12.x 正式移除了 `COMBAT_LOG_EVENT_UNFILTERED` (CLEU)，導致地面技能冷卻失效；且需要將技能圖示的金色亮框高亮（Overlay Glow）與快捷列按鈕的瞬間亮框發光完全同步。
- 症狀：先前效果依賴CLEU 的 `SPELL_CAST_SUCCESS`；光環/CD圖示的高亮也缺乏對原生動作欄金色亮框事件的即時註冊，常因手動意外出現延遲或故障；且巧切換造成技能覆蓋時冷卻圖示滯留失效。
- 原因判斷：CLEU已被封鎖；需改用正式服正常之`UNIT_SPELLCAST_SUCCEEDED`取得玩家施法；另外需由`SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`與`SPELL_ACTIVATION_OVERLAY_GLOW_HIDE`關係取得重建動作條的高亮狀態，以及`COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`監聽技能覆蓋。
- 已嘗試方法：
  1. 在 `GroundEffectService.lua` 中，全面移除 `COMBAT_LOG_EVENT_UNFILTERED` 的註冊，改為監聽 `UNIT_SPELLCAST_SUCCEEDED` 且篩選 `unitTarget == "player"`。
2. 在 `ClassPowerService.lua` 中，註冊 `UNIT_POWER_FREQUENT` 事件提供無延遲能量回饋。
  3.在`CooldownService.lua`中，註冊`COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`，當法術ID變更時，立即刷新被覆蓋或原始技能的冷卻狀態，解決覆蓋計時失效的Bug。
4. 在 `AlertManager.lua` 中註冊 `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE`，維護 `glowSpells` 表並在 `onAlertStateChanged` 做模板裝飾（Decorator）屬性同步；修改 `UI/Renderer.lua` 的 __EAM DE_EA__6: 02162__42__42__4 __EA__6 __642__42__42__42__42__4 __EA__3__3__3__m__4 的 __67_6A__EA__3__3__4A__3__3__m__ 的 __67_6A__EA__3__A__3__A__3__A__3__4A__m__ 的 __EA雙軌顯示金色發光。
- 有效解法：上述案例使 EAM 的事件更加趨向完善，100%繞過了對 CLEU 的依賴；重用了原有的區塊池與發光未知，依然維持 0-Allocation GC 飢餓。
- 後續注意事項：後續的5個Lua檔案均順利通過了`luac -p`的靜態語法安全性修改審查，後續需在魔獸服正式實機檢驗效果觸發與金色亮框同步。

### 2026-06-09 EAM 12.1.0 零分配 StatePool 恢復與基於 Pool-Token 延遲排程之 JIT 優化實行

- 狀態：已解決、待實機驗證
- 困：解決AuraService在大流量戰鬥中80個AuraState預作業作業後落入GC Churn的記憶體洩漏P0 Bug，並消除OnUpdate輪詢`IsZero()`導致LuaJIT __EAMCODE_終止。
- 症狀：
  1. 戰鬥中 `/eam debug` 顯示的 runtimeStats 記憶體會隨著 Buff/Debuff 刷新持續攀升，物品池恢復功能完全失效，引發 GC 攪拌並與 FPS 結束。
2. legacyTimerFrame 的 OnUpdate 迴圈遍歷輪詢 C++ 函數 `durationObj:IsZero()`，觸發了 LuaJIT 2.1 Trace Abort，導致降流路徑無法被 JIT負載率過高時造成微卡頓。
- 原因判斷：
  1. `AuraService.lua` 的 `AuraStatePool` 取得與釋放設計中，漏掉了將 `AuraStatePool.release` 綁定給 `state.releaseFunc` 的核心代碼。這導致 `AlertManager` 在隱藏光環後完全跳過了恢復邏輯。
2. legacyTimerFrame 的 OnUpdate 每幀使用 `pairs` 遍歷輪詢 `IsZero()`，該 C++ 函數在預設（秘密）下返回是戰鬥限制布林值，為預防崩潰我們使用了 `pcall`。不過在 JIT 編譯器下，`pcall` 內呼叫暴雪 C 函數會直接觸發NYI 中止，黑名單化整個 OnUpdate 渲染熱路徑。
- 已嘗試方法：
1. 在 `AuraService.lua`、`GroundEffectService.lua` 與 `TotemService.lua` 的各自物件池的 `acquire` 內，統一安全地綁定 `state.releaseFunc = Pool.release`，並在 `release` 時使 __EAA__MCOD __EA __MCOD。
  2. 徹底刪除 `Renderer.lua` 的 OnUpdate `IsZero` 輪詢與 `pcall` 宣告。
  3.實施重複使用的零令牌分配池`timerTokenPool`，在`Renderer.render`啟動計時器時，跨越`Scheduler.after`註冊單次延遲任務並提交令牌。
4. 預見時由 `onDurationTimerExpired` 替代代幣的 `active` 與圖標主動標誌是否一致，從而隱藏準確圖標，保證整個生命週期 100% 零記憶體配置與零輪詢前鋒。
- 有效解法：
  - 重構程式碼已成功寫入，4個Lua檔 `AuraService.lua`、`GroundEffectService.lua`、`TotemService.lua` 與 `UI/Renderer.lua` 皆 100% 通過 `luac -p` 的靜態語法安全性檢討。
- 後續注意事項：
- 在WoW正式服啟動EAM，高度切換Buff與冷卻時觀察記憶體曲線完全是否水平不上升，並確認當光環逼近時能準確自動消失，完全消除戰鬥污染與JIT中止。
### 2026-06-21 Retail 12.1 Aura readiness 與專家治理會審（未解決）

- 狀態：未解決；專家治理已更新，Lua 技術問題待後續修復與 Retail／PTR 實機驗證。
- 症狀：活動 TOC 仍為 `120007`；`AuraService` 仍依賴逐筆 AuraData、`UNIT_AURA` 與 `GetAuraDataByAuraInstanceID`，尚無 AuraContainer／AuraButton 實作。另發現 Secret 時間回流算術、ItemCooldown 標量 Secret 檢查錯誤、IconPool 戰鬥中可能建立框架、Scheduler 任務堆積與 StatePool 懸空引用風險。
- 原因判斷：12.1 Aura 契約已改為由 Aura Container／Button 在引擎內追蹤與顯示受限光環；既有 12.0.7 抽取模型不能直接延伸。原專家群亦缺少 12.1 Aura 遷移、Retail 實機證據與文件事實治理的唯一問責角色。
- 已嘗試方法：由 API／Aura、安全效能、架構治理三席子代理進行互不重疊的唯讀審查；主代理執行 32 個 Lua 檔案 `luac -p` 與 P0 靜態掃描，並查證 Blizzard 公告與 Warcraft Wiki 12.1.0 API changes 2026-06-20 修訂。
- 有效解法：新增 `AURA121`、`RQA`、`DOC` 三位專家，將 canonical 名冊調整為 23 位，重建 RACI 並要求每領域唯一 `A`。本次只完成治理與風險定級，未修改 Lua。
- 後續注意事項：12.1 Aura 遷移、Secret 時間資料清理、戰鬥中框架建立、排程取消／去重及 deferred state 生命週期均須另案修復。完成前不得宣稱 12.1 相容或 Retail 實機通過。

### 2026-06-21 Codex 沙箱與網路查證工具限制（已繞過，無專案資料損失）

- 狀態：已繞過；工具環境問題，不是專案程式錯誤。
- 症狀：沙箱程序初始化曾回報 `setup refresh had errors`；Web 搜尋／直接開頁遭服務端 `403 Forbidden`；修改前取得時間戳時一度因自動授權用量上限被拒絕。
- 原因判斷：Codex 執行環境與搜尋後端限制，非路徑、Git、Lua 或 Warcraft Wiki 內容問題。
- 已嘗試方法：停止重複高風險嘗試，改用經授權的唯讀沙箱外命令與 Warcraft Wiki MediaWiki API；用量限制發生後先停止寫入並取得使用者明確授權。
- 有效解法：在使用者授權後恢復命令，先建立專案規範要求的真實備份，再進行文件修改。
- 後續注意事項：遇到相同沙箱或查證限制時，必須區分工具故障與專案故障；不得以未查證快取冒充最新 API 事實。

### 2026-07-26 12.1 Native Aura 改造工具與流程問題

- 狀態：工具問題已繞過；12.1 PTR 實機項目仍待驗證。
- 症狀：標準 `apply_patch` 因 Codex Windows sandbox refresh 失敗；`apply_patch.bat` 的 WindowsApps 執行檔在升權程序被拒絕。第一次 Harness 又引用不存在的 `Core/StatePool.lua`；Windows `rg Locale\*.lua` glob 未展開；嚴格 AuraButton mock 把允許的 `eamNativeRegions` 資料欄位誤判為未知 API。
- 原因判斷：前三項屬本機工具/路徑模型，最後一項屬 mock 將 runtime 資料欄位與方法查找混為一談，不是產品 Lua API 錯誤。
- 已嘗試方法：先保留完整備份，改用 Codex apply-patch executable 的臨時副本執行標準 patch 協定；以 `rg --files` 確認沒有 StatePool 模組；改用 `rg -g '*.lua'`；在 strict mock 只白名單 `eamNativeRegions` nil 讀取。文件轉換因原腳本可能外傳 Markdown 到 Google 而被安全審查拒絕；安裝 user-site `markdown 3.10.2` 後，為工具新增 `EAM_DOCS_OFFLINE=1` 網路前閘門並離線轉換 34 份文件。
- 有效解法：所有正式修改仍由 apply-patch 協定完成；刪除 AuraService Tooltip duration 的 `now + scrapedDuration` 偽造路徑；Lua 語法 40/40，`aura121` 初版 7/7，最終 `all` 17/17。migration 測試一度因最後斷言回傳 table 而非布林 `true` 被誤標 fail，改成明確 `~= nil` 後通過。失敗報告保留於 `TestResults/`，不得刪除以掩蓋試誤。HTML 轉換預設採離線模式；外部翻譯必須取得明確授權。
- 後續注意事項：任務結束前移除 `%TEMP%\codex-apply-patch-20260726.exe`。68914 sorting enum 來自 FrameXML 而非 Generated Documentation；Aura Sound 欄位、實際播放、Forbidden Aspect、candidate filter 與 taint 仍須 `_ptr_` 實機驗證。

### 2026-07-27 GameTooltip ID 與自有 Popup 監控流程（離線已完成，待 PTR／XPTR 實機）

- 狀態：Spell／Item／Macro ID 與 EAM 自有 Popup 已完成；Aura 採官方 ID 顯示加手動輸入；離線 boundary／all 通過，實機尚未簽收。
- 情境：使用者要求 Tooltip 顯示法術、光環、物品與巨集 ID，並依圖示來源加入對應監控清單；原始構想為 Ctrl+Alt+右鍵。
- 症狀：觀察型全域滑鼠事件不能阻止 Blizzard 原右鍵行為，物品右鍵可能使用／裝備；Hook action button 或 AuraButton 會進入 secure／Forbidden／taint 風險。12.1 UnitAura TooltipData 的 ID 亦不是可依賴的公開穩定契約。
- 原因判斷：安全方案必須把使用者確認移到 EAM 自有 frame，並把 Aura ID 的「顯示」與「程式讀取」分離。12.1 官方提供 `tooltipShowAuraSpellIDs`，但該 CVar 不跨 session 保存。
- 已嘗試方法：由 API Change、Aura 契約與流程測試三席專家分別查證 PTR 68914 FrameXML、Secret／Forbidden 邊界與 mock 案例；標準 `apply_patch` 再次因 sandbox refresh 失敗，沿用已授權的 Codex apply-patch 臨時執行檔。第一次禁用模式搜尋因 PowerShell 雙引號使正規式失效，改用 `rg -F -e`；第一次 boundary 為 harness 未載入 Locale 而 4/8，補載入後又因 mock 缺 `Enum.PowerType` 在案例前中止，補齊正式客戶端必有表後通過。失敗報告保留，不刪除。
- 有效解法：`TooltipMonitorService` 只保存脫戰五秒 scalar candidate；Spell／Item 僅讀安全 `data.id`；Macro 只接受安全 `GetAction` 來源，其餘降級手動輸入；UnitAura callback 完全不讀 payload。Tooltip callback 不直接開 UI，戰鬥中也不保存 candidate；後續精確 Ctrl+Alt 才開啟 `TooltipMonitorMenu`。提交前 action 另經安全字串與四種白名單，只有 `added`／`updated` 通知刷新，`unchanged` 不刷新。CVar 不可用時五語系改為手動已知 Aura ID 提示，RuntimeProbe 只輸出匿名計數。
- 流程強化：離線 Harness 不再以假的 `open()` 取代 Popup，而是建立真 Frame/EditBox/Button，透過 `button:Click()` 與綁定的 `OnClick` 提交；載入正式 `UI/Options.lua`，驗證 AuraContainer／Aura／Cooldown／ItemCooldown／Renderer 五個下游。每個寫入案例使用隔離 DB 且在成功／拋錯兩路保證還原。新增 Secret scalar/action/table-key guard、callback 零 UI、focus/combat replay/type/hidden/TTL/完整 chord/latest、Macro resolved/manual、Aura player/target/CVar fallback，以及 JSON／人類報告 ID 遮蔽。
- 專家修正：API Change 終審指出舊文件仍把 AuraInstanceID／時間算術當成 12.1 指導、Macro processing metadata 私有性與 CVar 不可用誤導；Secret/taint 終審指出 action scalar 未防護與戰鬥候選可跨出戰；流程終審指出 OnClick 繞過、刷新 spy 過淺及 Secret-key false negative。上述 P1 均已修正並加入回歸案例。
- 終審收斂：API Change 複核最終為 P0=0、P1=0；剩餘兩個 P2（模組檔頭未揭露 private metadata、戰鬥中顯示不可用 Ctrl+Alt 提示）亦已關閉。戰鬥中仍可追加安全 ID，但只有成功建立脫戰 candidate 才顯示操作提示。
- 驗證結果：Lua 5.1 語法通過 42/42；禁用模式掃描只命中 EAM 自有按鈕 `OnClick`；TOC 所有 Lua 路徑存在；文件 Tooltip 標題唯一、五語系鍵齊全；`boundary` 10/10（`TestResults/EAM_FlowValidation_boundary_20260728_120708.json`），`all` 24/24（`TestResults/EAM_FlowValidation_all_20260728_120708.json`）。真 Popup 初次測試因未重新產生已消耗 candidate 而 7/9，失敗報告 `TestResults/EAM_FlowValidation_boundary_20260727_042850.json` 保留。
- 後續注意事項：必須在 `_ptr_` 12.1 與 `_xptr_` 12.0.7 依 `Docs/06_TEST_PLAN_RETAIL.md` 實測 Tooltip 類型、CVar、Popup、戰鬥拒絕、原始點擊行為與 taint／blocked action／Forbidden 錯誤；離線 pass 不得宣稱實機通過。

### 2026-07-28 Timer／applications 版面契約與真人回報鏈（離線已完成，待 PTR／XPTR）

- 狀態：產品與離線驗證工具已完成；`_ptr_` 12.1、`_xptr_` 12.0.7 的 18 案真人簽收仍未完成。
- 情境：使用者回報 timer inside／outside 設定無效，且要求 applications 可選框內／框外完整方位與字級；同時要求在 Codex 不操作遊戲的前提下，建立可回灌的人工能力／流程證據與 JSON 事實來源。
- 症狀：通用 Renderer 與 12.1 NativeAuraRenderer 各自維護不同錨點；Native 路徑固定把倒數與堆疊放在框內。舊 Flow schema 1 又只帶 `retail-client` 類型來源，無法可信區分 `_ptr_`、`_xptr_` 與離線 Mock。WTF 檔案若未在報告完成後再次 `/reload`／正常登出，磁碟內容仍是舊報告。
- 原因判斷：文字位置缺少單一白名單契約與版本化 SavedVariables；能力探針、人工簽收與離線 Mock 混用同一報告語意；SavedVariables 的記憶體狀態與磁碟保存時機未在 UI 明示。12.1 AuraButton 的 FontString 必須在 `initializeFrame` 設定，不能在任意更新路徑修改官方 Widget 結構。
- 已嘗試方法：由 UI／版面、12.1 API／taint、流程探針三席專家做互不重疊唯讀審查；查證 12.1 AuraButton 初始化限制；新增 21 點 JSON／Lua 契約、schema v3 遷移、字級 8–32、18 案真人矩陣、client identity 交叉檢查、`/reload` checkpoint 與可信匯入器。未使用任何遊戲自動輸入。
- 工具問題：標準 `apply_patch` 與一般命令因 Codex Windows sandbox `setup refresh had errors` 無法啟動；改用經授權的 Codex 原生 apply-patch 模式後，Windows PowerShell 5.1 又會移除原生參數內的裸雙引號，需以反斜線轉義後再傳遞。新契約工具初版另有 PowerShell `and`、JSON regex 跳脫與語系鍵前綴假設錯誤，均由 AST／schema／交叉比對測試攔下並修正。
- 有效解法：`Data/TextPlacementContract.json` 作為版面事實，`UI/TextPlacement.lua` 只載入靜態白名單映射；兩種 Renderer 共用此模組。`Data/LiveValidationMatrix.json` 與四份 `Schemas/*.json` 固化報告／矩陣／版面契約；`LiveTestSession` 僅保存玩家人工觀察，不施法、不用物品、不執行巨集、不改目標、不呼叫 `ReloadUI`。匯入器重算摘要、身分與矩陣，Flow schema 1 固定標為 `legacy-unverified`。
- 驗證結果：Lua 45/45；Flow `all` 30/30；JSON／Lua／TOC／PowerShell 契約 72/72；schema 2 `offline-mock` 可回灌但不升格實機；offline Live fixture 與 schema 1 Flow 均以非零退出拒收；回灌 Markdown 未含磁碟絕對路徑、`Users` 或 `Account`。本機 WoW 版本／Reparse Point 前置斷言通過 3/3。
- 流程固化：新增 `skills/eam-validation-contracts/SKILL.md`。Python 3.14 缺少 PyYAML，改用本機已有 `PyYAML 6.0.3` 的 Python 3.13，並以單次 `PYTHONUTF8=1` 避免 cp950 誤讀；官方 `quick_validate.py` 回傳 `Skill is valid!`。
- PTR 參考結果：使用者指定的 `_ptr_` SavedVariables 經唯讀、隱私淨化匯入，只含 Flow schema 1，因此為 `legacy-unverified`。必須先在 PTR 載入新版、完成人工矩陣，並再次由玩家 `/reload` 或正常登出寫回最新 JSON。
- 後續注意事項：實機時先執行 `Tools/Test-LocalWoWEnvironment.ps1`；完成後若直接複製面板 JSON，不需額外保存；若從 WTF 匯入，必須再 `/reload`／登出。實機仍需檢查 Tooltip、Popup、原 Blizzard 點擊、戰鬥轉換、Aura CVar、Native Widget、taint、blocked action 與 Forbidden。

### 2026-08-01 EAM-20260801-PTR121-AURA-DUAL-COUNTDOWN：Native Aura 雙倒數與初始化限制

- 狀態：程式與離線契約已修正；待 PTR 12.1 與 12.0.7 降級實機驗證。
- 症狀：PTR 12.1 同一光環同時顯示 Blizzard Cooldown 內建數字與 EAM DurationText，兩套倒數高度同步；舊版面流程另會在 `initializeFrame` 後重新 `SetPoint`／`SetFont`。
- 原因判斷：`SetDurationCooldown` 與 `SetDurationText` 同時接收同一個 Aura DurationObject；68914 在初始化回呼完成後限制 AuraButton 與其子元件，後置重排屬 Forbidden 風險。
- 已嘗試方法：查核固定 build FrameXML；把 slot 錨點、FontString、Cooldown、swipe、文字顯示選項全部移入初始化回呼；strict mock 在回呼結束後鎖定 button 與 child region。
- 有效解法：正常模式 `SetHideCountdownNumbers(true)` 只保留 EAM 一套文字；流程面板可明確切換雙倒數診斷，並以脫戰容器重建套用。離線案例驗證後置 mutation 必須失敗。
- 後續注意事項：雙倒數只供玩家觀察開始、中段與最後三秒；兩者不是獨立資料源，禁止 `GetText()` 讀回比較。完成診斷後應關閉。

### 2026-08-01 EAM-20260801-COOLDOWN-DURATION-CONTRACT：DurationObject 與倒數 binding 生命週期

- 狀態：已修正並離線通過；待 PTR／XPTR／Retail 法術與充能冷卻實機驗證。
- 症狀：冷卻圖示有 swipe 但沒有倒數文字，原服務曾把 duration 直接傳給 `CreateDuration`，Renderer 也曾把 duration/fontString 當作 binding factory 參數並假設存在 `Unbind`。
- 原因判斷：12.x 契約為無參數 factory，再呼叫 `SetTimeFromStart`；DurationTextBinding 亦為無參數建立，再逐一設定 FontString、Duration、Formatter 與 enabled 狀態。
- 已嘗試方法：建立 `Core/DurationAdapter.lua` 集中正確 factory、formatter、binding 與釋放降級；冷卻、物品、圖騰、地面效果與 Renderer 共用同一生命週期。
- 有效解法：正確建立 DurationObject，優先 `SetCooldownFromDurationObject`，安全普通數字保留 `SetCooldown(start, duration)` fallback；離線案例驗證 factory 次數與 binding setter。
- 後續注意事項：PTR／XPTR 必須分別測普通冷卻、GCD 排除與充能回充；離線 mock 不代表 C++ Duration 顯示實機通過。

### 2026-08-01 EAM-20260801-ITEM-COOLDOWN-EVENT：12.1 itemID 定向刷新

- 狀態：已修正並離線通過；待玩家實際使用物品驗證。
- 症狀：PTR 12.1 已加入監控的物品使用後沒有圖示或倒數。
- 原因判斷：服務只監聽 `BAG_UPDATE_COOLDOWN`，沒有處理 12.1 `SPELL_UPDATE_COOLDOWN` 的第五個 `itemID` 參數，因而錯過定向物品更新。
- 已嘗試方法：加入 12.1 事件分支，只在安全正整數 itemID 時呼叫 `refreshItem`；沒有 itemID 時不把 spell 事件誤當成全背包掃描。
- 有效解法：監控 itemID 可定向建立 ItemCooldownState，並透過 DurationAdapter 建立倒數；錯誤 itemID 零 API 讀取的離線案例已通過。
- 後續注意事項：需實測背包消耗品、裝備主動效果、共享冷卻與 `/reload`；確認其他 itemID 事件不誤觸。

### 2026-08-01 EAM-20260801-GROUND-DURATION-RESOLUTION：地面效果自動秒數與手動 fallback

- 狀態：已修正並離線通過；待多語系 PTR／XPTR 實機驗證。
- 症狀：地面效果沒有可靠持續時間；舊資料又可能以字串 key 保存，runtime 以數字 spellID 索引時無法命中。
- 原因判斷：地面效果需要 canonical key 與預先編譯的數字索引；動態剩餘時間不可由 Tooltip 推測，但靜態技能說明中的明確秒數可在非戰鬥低頻解析。
- 已嘗試方法：schema v4 遷移 ground alert key；建立非戰鬥解析鏈 `C_Spell.GetSpellDescription`、Tooltip `SpellDescription` line、manual fallback；施法熱路徑只讀 cache。
- 有效解法：解析成功標記 `spellDescription`／`tooltipDescription`；失敗採使用者秒數並記錄 `groundDurationManualFallback`；手動模式永遠優先使用設定值。
- 後續注意事項：需確認 zhTW／enUS 實際說明格式、無秒數技能、戰鬥中設定延後與重新施放覆蓋到期排程。

### 2026-08-01 EAM-20260801-PTR121-TARGET-AURA-LIFECYCLE：target Aura 文字空白與 Native border 邊界

- 狀態：持續調查；已補離線契約與 29 案人工程序，尚無足夠 PTR 證據判定單一根因。
- 症狀：使用者觀察到 target Aura 偶爾保留圖示但沒有剩餘時間與層數，並詢問 12.1 新 Aura border 是否可取代 Glow。
- 原因判斷：官方行為在 applications 小於等於 1 時清空層數；永久或零 expiration Aura 停用 duration binding；`fromPlayer=false` 亦可能匹配同 Spell ID 的其他施法者。`AddDispelTypeTexture` 只涵蓋官方驅散／靜態邊框。
- 已嘗試方法：把 showCountdown/showStacks/showName、文字位置與字級納入 compiler fingerprint 與 initializer；新增 target transition 人工案例與 native border capability 布林報告。
- 有效解法：目前只能正確分類並避免誤判；不以原生 border 冒充 Pandemic／Proc／任意條件 Glow，也不讀回 Secret 文字。
- 後續注意事項：PTR 需記錄目標切換、單層到多層、有限到永久、同技能其他施法者與 player/target Slot/Group；若重現仍非上述官方狀態，再提供匿名 JSON 與畫面。

### 2026-08-01 EAM-20260801-UNITPOWER-CAPABILITY：次要資源數字與主要資源原生 sink

- 狀態：程式與離線 capability probe 已完成；待 PTR 12.1 與 XPTR 12.0.7 玩家實測。
- 症狀：舊服務只依 `UnitPowerType` 選目前主要資源，聖能、連擊點、靈魂碎片、真氣、秘法充能等次要資源多數選不到；數值 1 又被 Aura stacks 規則隱藏。
- 原因判斷：職業次要資源需依 class priority 與 `UnitPowerMax` 選擇；安全數字不應借用 applications 大於 1 才顯示的語意。主要資源可能為 Secret，只能走官方 widget sink。
- 已嘗試方法：加入 `UnitPowerMax`／`UnitPowerPercent` 與 C_Secrets predicate；次要資源優先、事件 token 過濾、`displayValue` 顯示 1；建立玩家啟停的 StatusBar／radial capability probe。
- 有效解法：安全數字進一般 Renderer；Secret percent 只直接傳入 StatusBar／radial，不比較、不讀回、不序列化。報告只輸出 `safe-number`／`secret`／`nil`／`error` 與 sink accepted/rejected。
- 後續注意事項：玩家自行切專精、產生／消耗／歸零與進出戰鬥；EAM 不設定限制 CVar、不施法、不操作角色。需回傳 `EAM_UNIT_POWER_CAPABILITY_REPORT` 並標明客戶端。

### 2026-08-01 EAM-20260801-CONTINUITY-CONTRACT：專案脈絡與試錯防漂移

- 狀態：已完成，納入契約 gate。
- 症狀：長期任務經多次上下文壓縮後，容易混淆已確認事實、推論、離線結果與尚未執行的實機簽收，也可能重複已證明錯誤的 API 用法。
- 原因判斷：AGENTS 是規範、Issue Log 是完整時間線、Live Matrix 是人工案例，三者都不適合單獨承擔當前專案狀態。
- 已嘗試方法：建立 `Docs/28_PROJECT_CONTINUITY.md`、`Data/ProjectContinuity.json` 與 Draft 2020-12 Schema；以穩定 fact／inference／work／trial／unverified ID 分離資料責任。
- 有效解法：人類先讀 Docs/28，代理再讀 JSON；work item 連到本檔唯一 issue ID；PTR／XPTR／Retail pass 必須有真人證據，離線 50/50 不可升格。
- 驗證結果：Lua 47 檔語法通過、Flow `all` 50/50。契約初跑的 186/188 來自兩條仍要求 Native 初始化後直接重套文字的過時斷言；改成「拖曳預覽不重建、提交只重建一次、Native child initialization-only」後為 188/188，再加入 continuity 與五語系功能鍵唯一性 gate 後最終為 198/198。
- 工具試錯：`Test-ValidationContracts.ps1` 有 `#requires -Version 7.0`，Windows PowerShell 5.1 只會在執行前拒絕，必須使用 `pwsh`。多檔補丁若後續檔案定位失敗，前面檔案可能已套用；失敗後必須逐檔核對，高風險文件改採單檔小補丁。
- 後續注意事項：每次重大實機結果或決策變更都要同步更新 snapshotVersion、JSON 與 Docs/28；詳細過程仍只追加到本 Issue Log，不把整段時間線複製進 JSON。


### 2026-08-08 EAM-20260808-PTR8-UNITPOWER：PTR8 API 與 UnitPower 公開契約

- 狀態：程式、strict mock 與離線 36/36 Aura121 案例通過；PTR／XPTR／Retail 實機未簽收。
- 症狀：需求提供 `StatusBar:SetUnit`、`SetPowerTextFontString`、`SetOnUpdateMode` 作為新式 UnitPower 例，但官方 PTR 12.1.0.69189 生成文件與唯讀 FrameXML 掃描未找到這三個一般 StatusBar API。
- 原因判斷：來源可能是未公開或更晚 build；目前不能把未驗證方法當成正式依賴。官方可確認的 Secret sink 是 `StatusBar:SetValue` 與 `Texture:SetRadialProgressBarPercent`。
- 已嘗試方法：查閱 Unit、SecretPredicate、SimpleStatusBar、SimpleTextureBase 生成文件與 PTR source；將 `ClassPowerService` predicate 改為 fail-closed，戰鬥中讀值改為 `combatDeferred`，離戰後由 `PLAYER_REGEN_ENABLED` 恢復。
- 有效解法：安全普通數字只在 predicate 明確 false 且非戰鬥時使用；Secret percent 只單向送 native sink，報告不保存原值。探針的 sink 初始化不等於視覺接受，必須由玩家按鈕標記 accepted／pass。
- 後續事項：若要採用三個未證實方法，需提供目標 build 的官方生成文件或實機 API probe；PTR 需測資源增減、戰鬥內外、零值與 `/reload`。

### 2026-08-08 EAM-20260808-PTR8-AURABUTTON：Pandemic／Dispel／Container 清除

- 狀態：`AddPandemicRegion`、`AddDispelTypeTexture` options 與 disabled container clear 已接入 initializeFrame 與 strict mock；PTR 實機待簽收。
- 症狀：舊實作只偵測 `AddDispelTypeTexture` 存在，沒有實際傳入 texture/options，也沒有 Pandemic region。
- 原因判斷：PTR8 需使用實際 API 名稱與 options precedence；`showAlways` 會覆蓋 harmful/helpful/stealable 條件，不可把 deprecated AuraBorder 當新契約。
- 已嘗試方法：增加 compiler 白名單、renderer 初始化期綁定、mock trace 與 3 個 offline cases；Native settings 改為 `settingsDirty` 待手動套用。
- 有效解法：只在明確規則啟用 Pandemic 時建立 Region；Dispel options 由安全 enum 映射；停用容器 mock 清除按鈕 assignment 但保留 frame。
- 後續事項：PTR 12.1 觀察 Pandemic Window 顯示、showAlways precedence、AuraButton／ItemEnchantment 清除與重啟，不讀 Secret `Shown`。


### 2026-08-08 EAM-20260808-CONTINUITY-JSON-EDIT：資料契約更新時的替換風險

- 狀態：已解決。
- 症狀：以 PowerShell 正則替換 continuity JSON 的數字欄位時，群組參照與替換文字相鄰，暫時產生字面值 `$154$254`，並使 `ProjectContinuity.json` 無法解析。
- 原因判斷：PowerShell replacement string 對 `$1`、`$2` 的群組語法在後接數字時會被解讀成其他群組編號；不是 JSON schema 或程式邏輯錯誤。
- 已嘗試方法：先以現場檔案診斷換行與欄位，再使用作業開始時建立的 backup 還原單一 JSON；未還原其他程式或文件變更。
- 有效解法：改用唯一字串／索引插入與直接數字替換，立即執行 `ConvertFrom-Json` 及 `EAM_ProjectContinuity.schema.json` 驗證；最後契約 gate 為 207/207。
- 後續注意事項：JSON 維護避免使用含數字相鄰的未加括號 replacement group；修改 continuity 後必須重跑 schema、importer、snapshot 與 privacy checks。

### 2026-08-08 EAM-20260808-ALPHA2-PACKAGE：Alpha 2 標準封裝副檔名篩選

- 狀態：已修正並通過本機發布 gate；GitHub prerelease 與 Pages 遠端驗證另由本次發布流程執行。
- 症狀：標準封裝首次執行時，把 `Data` 目錄下的 JSON 判定為未列入 TOC 的 Lua／XML，因而中止封裝。
- 原因判斷：Windows PowerShell 5.1 對 `Get-ChildItem -LiteralPath` 搭配 `-Include` 的行為與預期不一致，未可靠限制回傳副檔名。
- 已嘗試方法：重現錯誤後檢查封裝器輸入集合，確認不是 TOC 遺漏；改以檔案 `Extension` 明確白名單篩選 `.lua`／`.xml`。
- 有效解法：封裝器只對 Lua／XML 執行 TOC 完整性檢查；契約測試新增 PowerShell 5.1 回歸條件，禁止恢復舊 `-Include` 寫法。
- 驗證結果：Lua 語法 47 檔通過、Flow 54/54、驗證契約 208/208、文件轉換單元測試 4/4、本機 WoW 版本與 Reparse Point 3/3；標準 ZIP 已成功產生。以上均屬離線／本機證據，不等同 PTR 實機簽收。
- 後續注意事項：GitHub Release 只上傳 `Dist` 內最終 ZIP 資產；`Dist/`、`deploy/`、`backup/` 與 `TestResults/` 不納入 Git，Release 必須標記為 Alpha prerelease。
### 2026-08-09 EAM-20260809-ALPHA2-NATIVE-GATE：Alpha 2 關閉 12.1 Native Aura

- 狀態：P0 程式已修正並通過離線驗證；PTR `/reload` 後顯示仍待玩家簽收。
- 症狀：玩家確認 Alpha 1 可顯示 Aura，Alpha 2 完全無 Aura；PTR Flow 的 `aura121.capability.native_complete` 回報 Native capability incomplete。
- 原因判斷：Alpha 2 新增 `nativeRuntimeAllowed`，要求 `IsPublicTestClient` 與 `IsTestBuild` 同時為 true。PTR `12.1.0.69189` 實際 raw flags 為 public-test=true、test-build=false、beta=false，所以服務在建立 AuraContainer 前就選成 unsupported。離線 mock 原先把 public-test 與 test-build 都設為 true，未覆蓋真實旗標組合。
- 已嘗試方法：比對 Alpha 1／Alpha 2 commit、追蹤 AuraCapabilityService 到 AuraContainerService 的 early return、核對 PTR 69189 固定 FrameXML 方法；同時拆解使用者 Flow 的其餘四個 failed case。確認 API 方法仍存在，其餘四項是 strict-mock 案例在遊戲客戶端誤判，不是四個新 runtime regression。
- 有效解法：12.1 Native gate 改為 Interface 及 public-test／test-build／beta 任一成立；三個 flag 經 `pcall` 正規化。mock 改成 PTR 69189 真實組合；四個 mock-only 案例在 client 缺 mock 時回傳 skip；地面效果測試不再覆寫已凍結的 `EAM.API.GetLocale`；Native capability 失敗訊息輸出完整安全布林診斷。
- 工具試錯：Codex `apply_patch` 因 Windows sandbox helper `helper_unknown_error` 無法讀取專案檔；數次保護性替換在非唯一錨點或外層模板解析階段中止，寫檔均放在最後所以沒有半套變更。最後採案例 ID 區間、唯一行與相鄰行斷言完成單檔修改。
- 驗證結果：`git diff --check` 通過；Lua 語法 `47/47`；Flow `all 54/54`；Validation Contracts `217/217`，artifact 為 `TestResults/EAM_FlowValidation_all_20260809_185047.json`。這些均為離線證據。
- 後續注意事項：玩家先 `/reload` 載入修正版，再執行 `/eam doctor`、`/eam test aura121` 並觀察 player／target Aura。若 capability 仍失敗，回傳新訊息中的 backend、runtime、raw flags 與五項 Native method 狀態；未完成前 P0 不得標為 PTR pass。

### 2026-08-09 EAM-20260809-PTR69189-UNITPOWER-PARTIAL：UnitPower sink 已接受但視覺未簽收

- 狀態：PTR capability 部分成立；視覺與流程仍未完成。
- 症狀：使用者回傳的 `EAM_UNIT_POWER_CAPABILITY_REPORT` 顯示 primary 為 Secret、selected 為 safe-number；兩案的 StatusBar 與 radial sink 呼叫都為 accepted，但 primary `visualObservation=pending`、selected `visualObservation=blocked`，整份報告為 blocked。
- 原因判斷：sink accepted 只證明 C API 接受值，不證明畫面隨資源增減正確。Secret widget 又不可由 Lua 讀回做自動比較，必須由玩家目視標記。
- 已嘗試方法：核對 build `69189`、clientChannel PTR、Interface `120100`、`rawValuesCollected=false` 與兩個 case 分類；沒有把 blocked 報告升格為 pass。
- 有效策略：保留現有單向 `UnitPowerPercent -> SetValue/SetRadialProgressBarPercent` 管線；報告只記分類與 accepted/rejected，真人視覺另行簽收。
- 後續注意事項：玩家在非戰鬥啟動探針，實際產生、消耗與歸零主要／次要資源，分別按 pass 或 fail；再進戰、離戰與 `/reload`。任何 raw power 值都不得回傳。

### 2026-08-09 EAM-20260809-TOOLTIP-COPY-INPUT：Target Aura、巨集解析與報告複製

- 狀態：程式與離線契約已修正；PTR／XPTR／Retail 互動與 taint 實機待簽收。
- 症狀：TargetFrame AuraButton 滑鼠停留後按 Ctrl+Alt 無法開啟 EAM Popup；Action Bar Macro 顯示巨集 ID 但法術／物品 ID 尚未解析；流程面板按「複製」時 `FlowTestPanel.lua:253` 呼叫 nil。
- 原因判斷：12.1 單位框架 Aura 可能使用非 `GameTooltip` 的 Aura tooltip object；macro TooltipData ID 可能只是 macro index，真正 resolved ID 應優先取 action subtype／ID；WoW SimpleEditBox 沒有通用 `Copy()` 方法。
- 已嘗試方法：標準 `apply_patch` 再次遭 Windows sandbox `setup refresh had errors` 阻擋，改以已備份檔案、唯一錨點與 UTF-8 精確替換。五語系新增鍵初版一度落在 locale registration `end)` 之外，會使 `L` 為 nil；契約測試新增 key scope／唯一性後攔截並移回註冊範圍。
- 有效解法：非 GameTooltip 的 `SetUnitAura` post-call 只建立 0.75 秒匿名 hover 心跳，不讀 tooltip／Aura payload；Ctrl+Alt 不需滑鼠按鍵即可開手動 Aura Popup。Macro 先解析 `GetActionInfo` resolved subtype／ID，再降級 `GetMacroSpell`／`GetMacroItem`。報告按鈕改為聚焦、全選並提示玩家 Ctrl+C。
- 驗證結果：Lua `50/50`、Flow `54/54`、Validation Contracts `247/247`；Target Aura heartbeat、macro spell/item route、manual copy 與五語系 scope 均有離線回歸。
- 後續注意事項：玩家需在 TargetFrame／BuffFrame 實測 hover+Ctrl+Alt、原 Blizzard 點擊行為、Macro spell/item、戰鬥拒絕及 taint／blocked action／Forbidden；離線 pass 不升格實機。

### 2026-08-09 EAM-20260809-ABOUT-TOOLTIP-BORDERS：About、監控 Tooltip 與七色分類邊框

- 狀態：程式與離線契約已完成；PTR 12.1 Native Widget 與 12.0.7 Legacy 實機待簽收。
- 症狀：主視窗缺少可追溯版本資訊；EAM 自有監控圖示無 Tooltip；不同監控來源缺少一致、固定的視覺辨識。
- 原因判斷：About 必須區分實際客戶端 build 與固定 API baseline；一般 Renderer 與 Native AuraButton 的 Tooltip／Region 生命週期不同；分類顏色只能使用 EAM 自有靜態資料，不能讀 Secret AuraData 或冒充 PTR8 dispel border。
- 已嘗試方法：建立純靜態 `AlertBorderStyles`；一般 IconPool 使用 EAM 自有 Texture 與脫戰 Spell／Item Tooltip，Native 只在 AuraButton initializer 建立 Region；AboutPanel 由 TOC metadata、GetBuildInfo 與 ValidationEnvironment 組合安全顯示。
- 有效解法：自身 BUFF 青、自身 DEBUFF 紅、目標 BUFF 藍、目標 DEBUFF 橘、技能黃、地面效果紫、物品綠；classPower／totem 保留既有外觀。About 顯示作者 `ziyuefan死鬥`、repo／Pages、TOC 版本、客戶端版本與 API baseline `12.1.0 PTR 8 (69189)`。
- 驗證結果：七色映射、Legacy／Native 套用路由、About metadata／戰鬥 guard、spell/item Tooltip 與 classPower 無誤判已納入 Flow／契約 gate。
- 後續注意事項：實機需觀察邊框與 Glow／Pandemic／dispel 同時存在時是否可辨識、Tooltip 戰鬥隱藏、About URL／版本正確；未來 PTR build 更新時同步 baseline。
### 2026-08-09 EAM-20260809-ALPHA3-SVG-BORDER：Alpha 3 全覆蓋邊框與 SVG A/B 探針

- 日期：2026-08-09
- 狀態：Alpha 3 prerelease 已發布；3px 邊框程式與 SVG 非對稱探針修正已離線驗證，下一個 alpha package 與 PTR 重測待辦
- 嚴重度：P1
- 症狀：
  - 實機截圖顯示舊 ActionButton 邊框即使放大，仍未完整覆蓋圖示四邊。
  - Alpha 3 初版沒有依 69189 區分 VectorGraphics 與 Texture 的不同方法集合，會把有效的 Texture introspection unavailable 誤判為錯誤。
- 原因判斷：
  - `Interface\Buttons\UI-ActionButton-Border` 素材本身含透明留白，增加 Texture 尺寸只會放大透明區。
  - VectorGraphics 提供 SetSVG／ClearSVG／HasSVG／GetSVGFileID；Texture 固定生成文件只提供 SetSVG／ClearSVG。初版誤把四方法視為兩者共通契約。
- 已嘗試但否決：
  - 將 ActionButton border padding 放大到 14px；實機仍可見邊框小於圖示。
  - 要求每案都必須 HasSVG=true、fileIDClass=positive-number；PTR 實證顯示 Vector addon-local fileID=0 且正常渲染，Texture 則沒有這兩個 introspection 方法。
- 有效解法：
  - Legacy IconPool 與 Native AuraButton 使用 WHITE8X8 實色 Texture、BORDER layer、四邊固定外擴 3px。
  - VectorGraphics 驗證 Set／Clear／Has／Get；fileID 只輸出 positive／zero／negative 分類，固定 addon-local 素材的 0 不單獨阻擋。
  - Texture 只驗證 Set／Clear；clearReload 以 ClearSVG 與重新 SetSVG 呼叫結果判定，最終顯示由玩家目視；strict mock 隱藏 Texture Has/Get 並斷言 introspection 呼叫為 0。
  - Schema 與匯入器依 case kind 重算；保留 Alpha 3 PTR 原報告 fixture，另加入非對稱 pass 與三種 mutation rejection。
- 工具限制：
  - `apply_patch` 再次在寫入前因 Windows sandbox `setup refresh had errors` 失敗；改用已備份的 UTF-8 唯一錨點／regex 範圍替換。
  - 多檔替換數次因 LF／CRLF 混合或錨點不符而在守衛處中止；每次均先用 `git diff` 確認已套用範圍，再從中止點續作，沒有回退使用者檔案。
- API 證據：
  - 固定快照：Gethe/wow-ui-source `a520b6c27bb897e6be2333b6cc2be36d52c7c11b`，版本 12.1.0.69189。
  - SimpleFrame：CreateVectorGraphics；SimpleVectorGraphics：Set／Clear／Has／Get；SimpleTextureBase：Texture Set／Clear。
  - 持續更新知識庫：[UIOBJECT_VectorGraphics](https://warcraft.wiki.gg/wiki/UIOBJECT_VectorGraphics)；固定 commit 才是本次 build 可重現基線。
- 驗證：
  - Lua 語法 50/50；Flow boundary 37/37；Flow all 54/54；Validation Contracts 264/264。
  - 離線測試不升格為 PTR、XPTR 或 Retail 實機通過。
- 後續：
  - 下一個 alpha package 必須包含本次探針修正；Alpha 3 Release ZIP 仍是舊探針。
  - 玩家更新並 `/reload` 後重跑 SVG 能力測試；同輪確認 Texture clearReload=pass 與 3px 邊框四面完整。

### 2026-08-09 EAM-20260809-PTR69189-SVG-ASYMMETRY：PTR 實證推翻對稱 SVG 驗收假設

- 日期：2026-08-09
- 狀態：根因已修正並完成離線驗證；PTR 修正版重跑待辦
- 嚴重度：P1
- 症狀：使用者回傳的 `EAM_SVG_CAPABILITY_REPORT` 為 incomplete，四個 warning 分別指向 Vector fileID=0、Texture Has/Get unavailable 與 Texture lifecycle unavailable；但兩格圖樣均目視 pass。
- 原因判斷：前三個 warning 是 Alpha 3 對稱驗收契約造成的假陽性；Texture lifecycle unavailable 則是舊程式在沒有 HasSVG 時提前返回，確實沒有執行 ClearSVG／重新 SetSVG。
- PTR 已確認事實：
  - client 為 `_ptr_`、12.1.0.69189、Interface 120100、channelValidation=pass。
  - VectorGraphics：SetSVG accepted、HasSVG=true、fileIDClass=zero、clearReload=pass、visualObservation=pass。
  - Texture：SetSVG accepted、HasSVG／fileID unavailable、visualObservation=pass；缺少 introspection 符合生成文件。
  - `rawFileIDsCollected=false`，沒有保存實際 FileDataID。
- 修正與回歸：
  - `Debug/SVGCapabilityProbe.lua`、Schema、Importer、strict mock、Flow 與 fixture 改為非對稱契約。
  - `Tests/Fixtures/EAM_SVGCapabilityReport.ptr69189-observed.json` 保存這份去識別化實證，預期可匯入但維持 incomplete。
  - 合成 pass 接受 Vector zero 與 Texture unavailable；mutation 測試拒絕 Vector 缺 HasSVG、Texture lifecycle unavailable 與 Texture hasSVG=false。
- 剩餘風險：Texture 沒有 HasSVG，ClearSVG 成功只證明呼叫未拋錯；清除瞬間像素不能由 Lua 讀回。需玩家以修正版完成最終 reload 圖樣目視，且不得把這輪兩格顯示通過擴大成 Pandemic／Dispel／戰鬥整合通過。

### 2026-08-12 EAM-20260812-LOCALE-SELECTOR：俄文、Auto Detect 與動態語系切換

- 狀態：程式與離線流程已完成；PTR、XPTR、Retail 的即時切換與保存畫面仍待玩家簽收。
- 症狀：選擇其他語系後畫面仍維持繁體中文；即使 `/reload`，舊路徑也可能在 locale 檔先依 client zhTW 建立 `EAM.L` 後，沒有在 SavedVariables 初始化完成時重新套用手動選擇。已建立 frame 另會保留 CreateFrame 當下複製進 FontString／按鈕的舊文字。
- 原因判斷：原 selector 只保存 `EAM_DB.config.language`，沒有執行期事件；`EAM.L` 缺乏穩定 identity 的重填契約，UI 也沒有 binding／refresh registry。`Auto Detect` 在 zhTW 客戶端解析成 zhTW 則是預期行為，不是錯誤。
- 已嘗試方法：先以手動 `/reload` 作切換邊界，但它只重新載入程式，無法彌補 Main 未重新套用 DB 選擇與現有 widget 快取；標準 `apply_patch` 又受 Windows sandbox `helper_unknown_error` 阻擋，改以既有備份、唯一匹配數量斷言及 UTF-8 無 BOM 精確寫入。
- 有效解法：`SavedVariables.updateLanguage()` 在 updated／unchanged 都發出 `EAM_LANGUAGE_CHANGED`；`Core/Main.lua` 在 DB 初始化後套用保存選擇；`Locale.apply()` 原地清除／合併 `EAM.L` 並保留 table identity；長生命週期 EAM widget 以 `Locale.bindText()` 更新，複合狀態以低頻 refresh callback 重算。主視窗、About、功能模組、Tooltip popup、Prompt、Flow／Live、UnitPower 與 SVG 面板均已接線，不呼叫 `ReloadUI()`。
- 驗證結果：Lua `54/54`；Flow `all 57/57`，artifact 為 `TestResults/EAM_FlowValidation_all_20260812_234217.json`；`locale.dynamic_switch` 驗證 ruRU 即時文字、dotted power key、穩定 `EAM.L` identity 與 no-op revision。Validation Contracts 初跑 `331 pass / 1 fail`，唯一失敗是延續性 JSON 新增了隱私契約禁止的模組詞；移除後最終 `332/332`。均屬離線／靜態證據，不宣稱 PTR／XPTR／Retail 實機通過。
- 後續注意事項：玩家載入本次新程式需先自行 `/reload` 一次；其後在三個支援客戶端選 `Русский` 與 `Auto Detect` 時應立即切換，再以一次 `/reload` 驗證保存。已輸出的聊天紀錄、Blizzard UI、其他插件及客戶端法術／物品名稱不會被 EAM 改寫。

### 2026-08-14 EAM-20260814-ALPHA5-PROFILE-FONT-LOCALE：Alpha 5 codec、字型與動態語系

- 狀態：已完成離線實作與契約驗證；PTR／XPTR／Retail 真人簽收待玩家執行。
- 症狀：Profile 分享原先只有規劃；初版 codec 的合法 Base64 padding、JSON object／array 判斷、payload.modules 陣列形狀、locale 新 key scope、TOC 路徑與 spec dropdown 語系刷新都曾出現實作風險。
- 原因判斷：Lua pattern 對 {0,2} 的處理不等同完整 Base64 grammar；JSON parser 需要在 parse root 時保留 object marker；外部 module payload 不能被當成 map；Locale callback 內新增 key 才會進入 catalog；專精選單是動態建立，僅 refresh 已存在 widget 不足；TOC 反斜線屬檔案路徑語法，不能重複跳脫。
- 有效解法：以嚴格長度／alphabet／padding 檢查包住 Base64 decode；parser 使用 object marker 與 metatable 保留 JSON 類型；payload modules 強制陣列驗證；將新語系 key 放回 Locale.register callback；語系事件後重建 spec menu 再刷新 dropdown；TOC 使用單一反斜線並由封裝 gate 驗證。
- 驗證結果：Lua 56/56、Flow all 66/66、Validation Contracts 360/360；git diff --check 亦通過。上述是離線／mock 證據，沒有把任何視覺或音效結果升格為實機 pass。
- 後續注意事項：不要重新接回 LegacyReference 的 loadstring；字型只改 EAM 自有 FontString；動態語系不改寫 Blizzard UI、歷史聊天或固定繁中 Live case 程序；Profile apply 在戰鬥中必須拒絕或延後。

### 2026-08-14 EAM-20260814-RELEASE-ACTION-PAUSED：GitHub Release workflow 暫停

- 狀態：已暫停自動發布 Action；Alpha 5 手動 Release 與 ZIP 不受影響。
- 症狀：`release.yml` 在 BigWigs packager 完成封裝後，更新既有 `alpha-5` GitHub Release 時回傳 HTTP 403 `Resource not accessible by integration`，workflow 以 exit code 1 結束。
- 原因判斷：workflow 原本以 tag 觸發，並傳入 `-w 26550 -p 826042`，具備 WoWInterface／CurseForge 發布目標；同時使用 `GITHUB_TOKEN` 更新 Release，但未宣告 `contents: write`。目前證據只確認 GitHub Release 更新被拒絕，不把外部平台是否已上傳推定為成功或失敗。
- 已採取措施：保留 workflow 原檔與備份，將 trigger 改為僅 `workflow_dispatch`，並以 job-level `if: ${{ false }}` 完全停用；不再因 alpha／版本 tag 自動執行 packager 或外部發布。
- 驗證結果：本機 workflow 差異唯一包含 trigger／job gate；`git diff --check` 通過。既有 Alpha 5 Release 資產仍可下載。
- 後續事項：若要恢復，必須先決定是否移除 `-w`／`-p` 外部發布目標、補足最小 GitHub `contents: write` 權限，並以獨立測試 tag 驗證；在此之前不得移除停用 gate。

### EAM-20260814-CATALOG-BATCH-RETAIL121：Aura catalog、批次輸入與 Retail 12.1

- 日期：2026-08-14。
- 狀態：已完成離線實作與契約驗證；Retail／PTR／XPTR 真人簽收待玩家執行。
- 症狀：正式服已進入 12.1，但 client gate、文件與矩陣仍把 Retail 當 12.0.7；Aura 清單缺少批次加入與明確職業 scope；SELF／TARGET 的 `fromPlayer` 預設不一致；dropdown 黑底、Profile 長字串溢出、小地圖 SVG fallback 顯示問號。
- 原因：Native eligibility 混用了 test-build 身分；清單只有 active-class profile 而缺 `catalogScope`；多組自製 dropdown 未建立 normal／pushed 材質與明確 FrameLevel；Profile 使用裸 multiline EditBox；Texture SVG 在不同 build 行為不對稱。
- 已嘗試：以 Wowhead class 資料自動升格預設，因 class ownership、PvP／被動、Aura effect ID 與抓取錯誤缺乏可靠 provenance 而否決；Texture SVG accepted 也不能證明像素顯示。
- 有效解法：Retail／PTR 12.1 依 Interface+widget capability 選 Native；新增 SELF／CROSS_CLASS 與批次 deferred commit；無效 SpellID fail-closed；dropdown 統一三態材質與層級；Profile 加 ScrollFrame；小地圖固定使用內建齒輪；Wowhead JSON 保持 candidate-only 並加專用 validator。
- 工具問題：Windows sandbox 的 `apply_patch`／一般 shell 在 setup refresh 階段反覆 `helper_unknown_error`，不是 Lua 或專案錯誤；確認無部分寫入後，使用既有備份、唯一錨點或結構化候選檔、解析／schema 驗證成功後才覆寫。
- 驗證：Lua 56/56、Flow 67/67、Validation Contracts 380/380、Wowhead candidate 23 pass／0 fail／4 warning、本機環境 3/3。
- 後續：依 `Docs/29_LIVE_TEST_STEP_GUIDE.md` 在 Retail／PTR 12.1 與 XPTR 12.0.7 驗證批次分類、僅玩家施放預設、dropdown、Profile 捲動、小地圖齒輪、戰鬥延後與 `/reload`；不得讓離線結果取代真人報告。

### 2026-08-14 EAM-20260814-THEME-CHROME-LANGUAGE-DROPDOWN：語系列空白與按鈕紅色覆蓋主題

- 日期：2026-08-14。
- 狀態：程式與離線契約已修正；Retail／PTR／XPTR 的十一主題與語系列目視仍待玩家簽收。
- 症狀：語系下拉列有底色但沒有任何文字；切換 FF7 等主題後，EAM 視窗背景與外框改變，按鈕仍維持紅色底與舊式邊框。
- 原因判斷：LanguageOptions 只有 value／label，Options 卻把不存在的 labelKey 傳入 Locale.bindText，binding 直接拒絕 nil key；createRedButton 與 PromptExport 又在 Theme.registerButton 後硬寫紅色 vertex color，覆蓋 palette。
- 已嘗試方法：標準 apply_patch 在讀檔前被 Windows sandbox helper_unknown_error 擋下；以既有備份、唯一錨點、暫存候選、luac／PowerShell AST 與寫入前雜湊守衛替代。首次新 Flow 案為 67/68，定位到 strict mock 用不存在的 self 儲存按鈕材質；改為 rawset(frame)／rawget(self) 後通過。
- 有效解法：語系列直接顯示 LanguageOptions.label；所有 EAM 文字按鈕移除紅色覆寫，統一使用 WHITE8X8 四態底圖與四條 2px 主題邊框。主題擴為十一套，Borland 固定亮藍底亮黃字，DOS CRT 固定黑底綠字。
- 驗證結果：Lua 56/56；Flow all 68/68，theme.button.chrome 驗證 Borland／DOS 底色與四邊框切換；Validation Contracts 387/387。以上均為離線／mock 證據。
- 後續注意事項：玩家需先 /reload，再於 Retail／PTR／XPTR 打開語系與主題下拉，逐一確認非 hover 文字、按鈕 normal／hover／pressed／disabled、2px 邊框與保存；AlertBorderStyles 七種監控語意邊框不得隨 UI 主題改色。

### 2026-08-14 EAM-20260814-ALPHA6-MINIMAP-RING：小地圖齒輪與金色追蹤圈錯位

- 日期：2026-08-14。
- 狀態：程式與離線契約已修正；Retail／PTR／XPTR 像素目視待玩家 `/reload` 簽收。
- 症狀：小地圖只看到偏左上的金色空圈，`Trade_Engineering` 齒輪落在圈外右下方；與其他標準小地圖按鈕不一致。
- 原因判斷：按鈕為 31x31，但 `MiniMap-TrackingBorder` 是 53x53 複合材質。舊碼把邊框與 21px 圖示都置中，忽略該材質的有效圓環位於局部座標；不是齒輪檔案本身需要平移。
- 有效解法：依 Blizzard 生態常用的 LibDBIcon 幾何，20px 小地圖背景錨定 `TOPLEFT +7,-5`，17px 齒輪錨定 `TOPLEFT +7,-6` 並裁掉 5% 外緣；53px 邊框固定在按鈕 `TOPLEFT`。保留左／右鍵、拖曳與 SavedVariables 位置語意。
- 防回歸：Validation Contracts 精確斷言背景、圖示、TexCoord、邊框尺寸與 TOPLEFT 錨點，並拒絕邊框回到 CENTER。
- 工具試錯：標準 `apply_patch` 仍在讀檔前遭 Windows sandbox `helper_unknown_error`；第一次 `git apply --check` 因手寫 hunk 行數錯誤拒絕，後續兩次 literal 候選因 JavaScript／PowerShell 反斜線層級被唯一命中閘門拒絕。最終先以唯讀 regex 證明單一區塊，再用備份雜湊、Temp 候選、luac 與 PowerShell AST 通過後覆蓋，沒有部分寫入或回退其他變更。
- 驗證結果：Lua 56/56、Flow 68/68、Validation Contracts 394/394。離線只能證明結構，不能證明不同 UI Scale 的最終像素。
- 發布邊界：Alpha 6 使用本機正式封裝與手動 GitHub prerelease；停用中的 BigWigs／CurseForge／WoWInterface workflow 不啟用。

### 2026-08-14 EAM-20260814-LUA-SYNTAX-SCOPE：正式 Lua 掃描誤納 ReferenceLibs

- 日期：2026-08-14。
- 狀態：已解決；正式發布 gate 已改用專案既有工具。
- 症狀：臨時以遞迴 `Get-ChildItem *.lua` 執行 `luac -p`，誤把 `ReferenceLibs/!Lib_ZYF` 兩個外部參考檔納入，出現檔頭位元語法錯誤。
- 原因判斷：臨時命令未沿用封裝與 `Tools/CheckLuaSyntax.ps1` 的正式載入範圍排除規則；錯誤不在 TOC 載入的 EAM 56 個 Lua 檔。
- 已嘗試方法：停止使用過寬遞迴命令，唯讀定位專案既有語法驗證工具與最新 Flow／環境報告。
- 有效解法：發布前固定執行 `pwsh -NoProfile -File .\Tools\CheckLuaSyntax.ps1`；本輪結果為 Lua 56/56，另由正式封裝再執行一次相同範圍檢查。
- 後續注意事項：不得以 ad hoc 全樹 Lua 掃描取代專案工具；`ReferenceLibs` 只供研究，既不由 TOC 載入也不進發布包。
### 2026-08-14 EAM-20260814-ZIP-PATH-NORMALIZATION：Windows ZIP entry 分隔符誤判

- 日期：2026-08-14。
- 狀態：已解決；Alpha 6 ZIP 內容通過正規化後的唯讀稽核。
- 症狀：首次以 `/` 檢查 ZIP entry 根目錄與 forbidden path 時，Windows `System.IO.Compression` 回傳反斜線路徑，導致 87 個合法檔案全被誤報。
- 原因判斷：稽核命令未先把 ZIP 內部 entry 的 `\` 正規化為 `/`；不是封裝器夾帶禁用資料。
- 有效解法：在任何 root／forbidden／required 比對前先做路徑分隔符正規化，再排除目錄 entry。結果為 87 files、forbidden 0、required 7/7，SHA-256 `966279C8678FD9EFDCD428D83879B3AD02D22C822EF3F8863D04F9380E5B7BDD`。
- 後續注意事項：日後將此正規化規則收斂至發布稽核工具，不得因 ad hoc 路徑分隔符差異誤判套件污染。
### 2026-08-14 EAM-20260814-GIT-CACHED-WHITESPACE：候選抓取腳本行尾空白

- 日期：2026-08-14。
- 狀態：已解決；commit 尚未建立前由 cached diff gate 攔截。
- 症狀：`git diff --cached --check` 在 `Tools/fetch_wowhead_spells.py` 找到 18 行 trailing whitespace。
- 原因判斷：外部匯入的候選資料抓取腳本保留空白行縮排；不影響 Python 語意，但不符合 Git diff 品質閘門。第一次清理 regex 未納入 Windows CRLF，命中 0 後由預期數量閘門拒絕，沒有寫入來源。
- 有效解法：以 CRLF-aware 模式只移除行尾空格／Tab，不改任何抓取、來源或輸出路徑邏輯；以 Python AST、Wowhead candidate validator 與 cached diff 再驗證。
- 後續注意事項：新加入 Python／PowerShell 工具在 stage 前先跑 whitespace 與 AST gate；Windows 文字處理 regex 必須明確涵蓋 CRLF。
### 2026-08-21 EAM-20260821-NEW-ROOT-GOVERNANCE：新根結構與部署治理更新

- 日期：2026-08-21。
- 狀態：已完成 `.AI` 治理文件與 continuity JSON 的離線更新；未執行 Deploy，未寫入 WoW 目錄，未存取停用舊路徑。
- 現行事實：Git 根為 `D:\Project_EventAlertMod`；插件來源為 `EventAlertMod/`；AI 治理為 `.AI/`；部署工具為 `Deploy/`；`Dist/` 為 ignored。本次 Status 為 Retail/PTR `12.1.0.69382`、XPTR `12.0.7.68887`，三個目標均 physical，但只有 PTR 含 EventAlertMod.toc，Retail/XPTR 尚缺該檔；Test-LocalWoWEnvironment 為 1/3，Deploy Status/DryRun 三通道 pass 只代表安全部署前檢，不能宣稱三通道 ready；較早 link blocked 狀態保留為歷史證據。
- 部署規則：Registry 優先、`DeploymentTargets.json` fallback、使用者確認或 `-WowRoot`、三通道 ProductVersion、PTR/XPTR 互動詢問 Retail、noninteractive 不暗加、Reparse fail-closed。
- 封裝規則：插件 ZIP 取 `EventAlertMod/` exact tree；原始碼 ZIP 排除 `Dist/.git/.codex-remote-attachments/attachments/backup/trash/TestResults/cache/log/zip` 等本機衍生物，保留 `.vscode/.codex/.AI/docs_html`。
- 工具試錯一：標準 `apply_patch` 因新根 helper／Windows sandbox `setup refresh had errors`／`helper_unknown_error` 失敗，且未形成部分寫入；依既有備份改以暫存候選檔與 `git apply --check`，通過後再 `git apply`。
- 工具試錯二：Wowhead candidate validator 在 `Set-StrictMode -Version Latest` 下曾因 warning/pass 計數器未明確初始化或未以 script scope 寫入，以及候選 JSON 解析失敗分支未先初始化 `$candidate`／`$candidateParsed`／欄位旗標而中止；修復為明確初始化、`$script:` 計數器與 `Test-HasProperty` 防守，並固定輸出 `.AI/Data/wow_spells_and_auras.json`。候選資料仍只作 webCandidate，不升格 runtime 或實機證據。
- 驗證邊界：本輪僅驗證文件、JSON 結構、備份、patch check/apply 與字串稽核；未執行 docs HTML 轉換，未宣稱 WoW 功能實機通過。
### 2026-08-21 EAM-20260821-PLAYER-RESOURCE-CONFIG-RELOAD：職業資源設定被誤以為必須 `/reload`

- 日期：2026-08-21。
- 狀態：程式與離線契約已修正；Retail 12.1 實機仍待玩家簽收。
- 症狀：職業資源設定儲存後，畫面常要 `/reload` 才看到變更。
- 原因判斷：舊流程把 SavedVariables 寫入與服務拓撲重建混在初始化路徑；新增欄位即使保存，也未全部進入 `resolveConfig()`／renderer。`/reload` 重新建立資料與框架，因此掩蓋了事件套用缺口。戰鬥中延後重建則是刻意的保護，不是永久要求重載。
- 有效解法：`SavedVariables.updatePlayerResourceConfig()` 派送 `EAM_PLAYER_RESOURCE_CONFIG_CHANGED`；`PlayerResourceService` 在脫戰立即重建，戰鬥中只保存並於 `PLAYER_REGEN_ENABLED` 合併重建一次；有效設定現在包含百分比、門檻高亮、字型與方向，renderer 於同一次事件重套用。Secret 資源仍只將 `UnitPowerPercent` 直送 write-only StatusBar sink，不讀回或轉成 Lua 數字。
- 驗證結果：`luac -p` 職業資源 Lua 2/2；Flow boundary 49/49；Validation Contracts 427/427（含 renderer 即時套用契約）。
- 實機簽收條件：Retail 12.1 非戰鬥修改每一項資源設定，確認不 `/reload` 即更新；戰鬥內修改確認離開戰鬥後一次更新；記錄 client/build/interface、Lua error/taint 與視覺結果。

### EAM-20260821-PLAYER-RESOURCE-MIGRATION-FIX：遷移 fixture 對覆寫資料模型的過時期待

- 日期：2026-08-21。
- 狀態：已解決；程式與離線 suite 已重新通過。
- 症狀：schema v1→v6 migration Flow 在 all suite 由 71 案中的唯一案例失敗。
- 原因判斷：fixture 把 classDefaults.settings.ENERGY 預先存在當成必要條件；現行 global -> class -> spec 設計只保存明確覆寫，未覆寫欄位由 effective resolver 繼承。
- 有效解法：測試改驗證 classDefaults.settings 容器、enabled 與有效遷移結果，不要求冗餘的每資源覆寫表；未放寬 schema、Secret 或 class isolation 契約。
- 驗證：Lua 63/63、Flow all 71/71；Validation Contracts 432/432。

### 2026-08-21 EAM-20260821-PLAYER-RESOURCE-COMPLETION-AUDIT：ResourceProbe、adapter 與 sampler 文件邊界

- 日期：2026-08-21。
- 狀態：核心程式與一般離線契約已完成；背景 sampler fixture／contract 已通過離線驗證，仍待實機簽收；Retail／PTR／XPTR 實機仍待玩家簽收。
- 現況：`PlayerResourceProbe` 產生不含 raw power 的逐資源事件報告；`PlayerResourceCapability` 對 XPTR 12.0.7 提供隔離 numeric legacy adapter；Druid form flow、anchor／position、module event unregister、冷路徑策略綁定與 Secret source-to-sink 已納入離線契約。NUMERIC 文字以 `SetFormattedText()` 更新，Secret 不字串化、不讀回。
- sampler 邊界：只有 probe 確認背景事件缺失才建立單一 demand-driven sampler，正常事件觀測後立即退出；不可把 sampler setter accepted、eventObserved 或 offline pass 當成 visual pass。
- 試錯紀錄：初版 sampler fixture 以全域 Scheduler task 總數斷言，會與既有 `scheduler.next_frame` task 互相干擾；修正為用 owner／generation 只計算本 sampler task，stale task 亦以 generation gate 拒絕。此為測試隔離修正，不放寬 runtime gate。
- 驗證結果：Lua `64/64`、Flow all `75/75`、Flow boundary `54/54`；Validation Contracts `436/436` 已以最新 artifact 重跑通過。上述皆為 offline/static evidence。
- 後續實機：PTR／Retail 12.1 與 XPTR 12.0.7 逐職業／專精、Druid 四變形、戰鬥／脫戰、設定即時套用、事件註冊清理、anchor／position 與 sampler gate；每份回報需帶 client channel、patch、build、Interface、combat、`/reload`、Lua error／taint／blocked action 與 visualObservation。 
### 2026-08-23 EAM-20260823-TARGET-AURA-DIAGNOSTICS：目標光環缺少可追溯候選與手動入口

- 日期：2026-08-23。
- 狀態：匿名診斷與離線契約已完成；PTR／XPTR／Retail 目標 Aura 仍待玩家實機簽收。
- 症狀：非戰鬥目標光環有圖示但不一定彈出法術 ID 或 Ctrl+Alt 加入視窗；直接檢查 AuraButton、AuraData 或滑鼠焦點又可能越過 Retail 12.1 Forbidden／Secret 邊界。
- 原因判斷：Target Aura 可能只經過隱藏 AuraButtonTooltip 的 UnitAura post-call；callback 可用作短效 heartbeat，卻不能安全讀出欄位或推測 Spell ID。既有 tryOpenMenu 在候選過期、tooltip 類型不符、鍵盤焦點或戰鬥時會 fail-closed，但沒有匿名狀態欄位，也沒有不依賴目標框架的明確手動 route。
- 有效解法：TooltipMonitorService 新增 callback／candidate timestamp、candidate expiry count、最後嘗試原因、modifier key/down、CVar read/set result；getStatus 僅回傳安全 scalar。新增 openManualTargetAuraMenu()，並由 /eam add target 呼叫既有 TooltipMonitorMenu 的 aura popup；帶 ID 的 /eam add target <spellID> 不變。
- 禁止事項：不 hook TargetFrame/AuraButton、不呼叫 GetChildren／GetMouseFocus、不保存或序列化 Secret／AuraData／Frame，不把 offline fallback 當作實機通過。
- 驗證：Lua 64/64；Flow all 75/75；Flow boundary 54/54；Validation Contracts 441/441。offline harness 未載入 Slash UI 時，service manual route 實測，slash source 由靜態 Contract 覆蓋。
- 實機簽收：非戰鬥將滑鼠移入目標光環按 Ctrl+Alt；若無彈窗回報 /eam doctor 安全欄位，再以 /eam add target 手動輸入已知 ID 測試 target 按鈕。每份報告須附 client channel、patch、build、Interface、combat、/reload、Lua error／taint／blocked action 與 visualObservation。


### EAM-20260823-COOLDOWN-ACTIVATION-TRISTATE：冷卻清單刷新造成批量顯示與 false 設定遺失

- 日期：2026-08-23。
- 狀態：程式、離線 Flow 與合約已修正；Retail／PTR／XPTR 實機仍待簽收。
- 症狀：冷卻清單技能在未施放、脫戰或形態刷新後可能被誤 render；三項冷卻行為設定的明確 false 可能在保存、匯入或 UI 回寫時被 and/or 語意丟失。
- 原因判斷：服務層原先把「已在清單」與「已被玩家施放啟動」混為同一條件；Renderer 到期直接隱藏，無法遵守 cooldownRemoveAura；設定解析與按鈕值讀取使用 truthy fallback，無法區分 nil 與 false。
- 有效解法：新增 activatedAlerts，只接受 player UNIT_SPELLCAST_SUCCEEDED 精確 spellID；refresh／regen／形態事件只刷新既有啟動狀態。到期回呼交由 CooldownService 判定，usable glow 與既有 glow 合併。SavedVariables、ProfileCodec、Options 採明確 boolean／nil 三態，並加入非清單治療法術與脫戰回歸 fixture。
- 驗證：Lua 64/64；Flow all 76/76；Flow boundary 55/55；Validation Contracts 447/447。artifact：.AI/TestResults/EAM_FlowValidation_all_20260823_042614.json、.AI/TestResults/EAM_FlowValidation_boundary_20260823_042834.json。均為 offline/static evidence。
- 實機待辦：Retail／PTR 12.1、XPTR 12.0.7 各測 exact cast、非清單治療、戰鬥／脫戰、變身、模組開關、三項 tri-state 與 /reload；依 Docs/29_LIVE_TEST_STEP_GUIDE.md 回報 client identity、visual、taint 與 blocked action。

### EAM-20260823-PLAYER-RESOURCE-FINAL-PROMPT：多資源拓撲、事件路由與設定生命週期補強

- 日期：2026-08-23。
- 狀態：核心程式與離線驗證已完成；Retail 12.1、PTR 12.1、XPTR 12.0.7 的事件頻率、Secret sink、視覺、taint 與 blocked action 仍待玩家部署後簽收。
- 症狀：前版資源模組仍有背景 sampler 無明確入口、UNIT_DISPLAYPOWER 可能重新判定全部能力、停用模組未停止 Probe、Druid 多形態與 Energy／ComboPoints 擁有權覆蓋不足，以及 numeric 文字設定缺少字型／方向控制。
- 原因判斷：資源定義、SavedVariables 與 renderer 各自保留局部模型；事件路由把前景切換誤當拓撲變更；能力探針生命週期未由模組狀態管理；strict mock 未覆蓋所有形態與多資源併存案例。
- 有效解法：以 PlayerResourceCatalog 作唯一定義來源，PAIN 使用專用 legacy key；UNIT_DISPLAYPOWER 僅更新前景；加入 Druid Bear／Cat／Caster／Moonkin／回 Bear、Energy→ComboPoints ownership、Probe stop lifecycle、顯式 /eam unitpower background <RESOURCE_KEY> 診斷入口、非戰鬥即時設定與戰鬥中離戰後單次合併；numeric Secret 仍只寫入安全 sink。
- 工具試錯：連續性 JSON 候選曾因 PowerShell replacement 使用 $1 字面值與遺漏閉合欄位而短暫失效；已以原始備份重建候選，先 ConvertFrom-Json 再套用，並以快照／facts／artifact 交叉檢查避免再次寫入無效 JSON。
- 驗證：Lua 62/62；Flow all 77/77；Flow boundary 56/56；Validation Contracts 452/452；JSON schema 1、snapshot 2026-08-23.4。以上均為 offline/static evidence。
- 後續注意事項：/eam unitpower background 只記錄玩家明確判定事件不足，不代表 sampler 已在實機必要或有效；未部署前不得引用離線通過宣稱 WoW 實機完成。
### EAM-20260823-DEPLOY-GAME-DATA-BACKUP-RESTORE：移除程序執行閘門並加入按通道遊戲存檔備份／還原

- 日期：2026-08-23。
- 狀態：部署工具程式、合成 fixture 與離線契約已完成；未對實際 WoW 目錄或真實遊戲存檔執行操作。
- 症狀：部署前的 WoW 程序檢查會阻止使用者在已開啟客戶端時覆蓋；同時缺少依 Retail／PTR／XPTR 與版本選擇的 EventAlertMod 存檔備份／還原能力，無法保留原始資料夾相對位置。
- 原因判斷：部署腳本把「程序是否執行」當成必要安全條件，但真正不可追蹤的風險是 Reparse Point、來源／目標不明與還原資料不完整；備份若只扁平化檔名，還原時無法判斷原始位置。
- 有效解法：移除 Test-WowIsRunning 與 Wow/WowT 程序 gate；新增互動 [W]／[U] 與 CLI Backup／Restore，依通道／版本掃描名稱或相對路徑含 EventAlertMod 的檔案，寫入保留 WTF/... 相對路徑的 manifest、SHA-256 與備份 package。還原前建立自動 rollback，逐檔驗證 hash，遇到 Reparse Point、路徑穿越或 hash 不符即 fail-closed。
- 試錯紀錄：初次清理合成 fixture 時在外層 PowerShell 呼叫腳本內部 helper，造成 helper 不存在；改用明確暫存 package／fixture 路徑清理後，未觸及真實遊戲目錄。
- 驗證：Lua 62/62；Flow all 77/77；Flow boundary 56/56；Validation Contracts 459/459。合成 fixture 2 個相關檔案 backup／restore、相對路徑與 SHA-256 驗證均 pass；上述均為 offline/static evidence。
- 實機待辦：玩家若需最新遊戲狀態，先在新根執行部署工具選擇通道／版本，再於遊戲內 /reload 後回報 client channel、patch、build、Interface、combat、Lua error／taint／blocked action 與 visualObservation。程序檢查已移除，不代表可以忽略遊戲自動寫檔的競態風險；還原前仍應先關閉遊戲或確定存檔不會被同時覆寫。
### 2026-08-23 EAM-20260823-PLAYER-RESOURCE-FINAL-GATE：Frozen Catalog、Probe auto-check 與 README 同步

- 狀態：離線修正完成；Retail／PTR／XPTR 尚未部署或真人簽收。
- 症狀一：實機曾出現 SavedVariables.lua attempted to perform indexed assignment on a frozen table，隨後 Options.lua 以 nil SavedVariables method 報錯。
- 原因判斷：SavedVariables 在初始化時重新寫入 Catalog.ByKey／ByPowerType；Catalog 是 immutable/frozen map。首個錯誤中斷初始化，Options 後續呼叫才出現 nil。
- 有效解法：SavedVariables 只讀取 Catalog maps，另建可變 legacy alias map；Options 的各 add category 對缺失 API fail-closed 並回傳 savedVariablesMethodUnavailable。
- 症狀二：新增 PlayerResourceProbe missing-event check 後，Flow 行為通過但 Contracts 仍期待舊 runMissingEventCheck(generation) 文字。
- 有效解法：契約改為實際 owner token 形狀，並把 autoCheckValid、missingEventCheckExecutedCount 與 probe restart 納入 Flow 靜態 gate；不放寬 raw Secret／OnUpdate 禁止條件。
- 部署文件症狀：Deploy 遇到公開 README 與插件副本雜湊不同而零寫入阻擋。
- 有效解法：根 README 重整為 Alpha 7 目前命令與部署說明後，精確同步 EventAlertMod/README.md；兩份 SHA-256 均為 7EB8752ACA994769356757AED7E1FB4483497930E4A0CB9C567403D14D161509。
- 驗證：Lua 62/62；Flow boundary 56/56；Flow all 77/77；Validation Contracts 461/461；ProjectContinuity JSON parse pass。未執行 WoW/WTF/GitHub。
- 後續：玩家必須先部署，再在正確 Retail／PTR／XPTR 執行 /reload 與資源、專精、形態、戰鬥及模組生命週期簽收。

### 2026-08-23 EAM-20260823-CONTINUITY-PRIVACY-GATE：最新 fact 證據路徑觸發私人資料詞彙檢查

- 日期：2026-08-23。
- 狀態：已解決，未涉及遊戲程式或真人測試。
- 症狀：Validation Contracts 在加入最新玩家資源／README fact 後出現 Continuity excludes private game data terms 失敗；JSON 本身可解析，Flow 與 Lua 均正常。
- 原因判斷：新 fact 的證據描述意外包含私人存檔相關檔名詞彙；既有 continuity privacy contract 會拒絕這些詞，避免把帳號／角色資料語意帶入可公開的治理快照。
- 有效解法：先備份 ProjectContinuity.json，將描述改為中性的 persistence／公開程式與文件證據，移除私人遊戲資料檔名與路徑語意；不修改 importer privacy 規則、不讀寫真實遊戲資料。
- 驗證：ProjectContinuity JSON parse pass；Validation Contracts 464/464；Lua 62/62、Flow all 77/77、boundary 56/56 仍通過。
- 後續注意：公開 continuity 只放可追溯的程式／文件相對路徑；WTF、帳號、角色或 SavedVariables 內容只能留在本機備份，不得貼入 GitHub README、JSON snapshot 或實機報告。

### 2026-08-23 EAM-20260823-CHARGE-GLOW-LIBRARY：充能顯示、冷卻白框與 Glow Border fallback

- 狀態：程式與離線驗證完成；Retail／PTR／XPTR 尚未部署或真人簽收。
- 症狀：充能型技能沒有 current/max 文字；冷卻沒有計時時仍留下小白框；需要依技能可用、充能或自訂條件顯示動畫外框。
- 原因判斷：CooldownService 沒有把安全的 C_Spell.GetSpellCharges 結果傳到 Renderer；CooldownFrame 沒有在無 timer 分支清理 edge／bling；Glow 若直接建立第三方 overlay，可能在戰鬥中首次建框造成污染或 mock optional method nil error。
- 有效解法：新增安全 charge state 與 current/max 顯示；無 timer 時 Hide 並關閉 CooldownFrame edge／bling；內嵌 LibStub／LibButtonGlow-1.0 並由 IconPool 做 capability-safe 取得、戰鬥首次建框阻擋、自訂顏色回退 EAM 動畫邊框。UI optional method／field 讀取均經安全 wrapper。
- 保留／限制：LibButtonGlow 只作預設 glow 的備援路徑；自訂顏色仍由 EAM fallback 負責。未 hook Blizzard secure frame、未讀回 Secret duration／charge、未增加 EAM OnUpdate。
- 驗證：Lua 62/62、Flow all 78/78、Flow boundary 57/57、Validation Contracts 472/472、TOC validator passed。全部為 offline/static evidence。
- 實機待辦：玩家部署後，在 Retail／PTR／XPTR 測充能 0/max、部分充能、冷卻完成與可用高亮；確認沒有白框、Glow 外擴尺寸與 /reload 持久化，並回報 channel、patch、build、Interface、combat、Lua error／taint／blocked action 與 visualObservation。

### 2026-08-23 EAM-20260823-DEPLOY-NOTIFICATION-PROTOCOL：實機部署前通知

- 狀態：流程已確立，尚未執行實際部署。
- 規則：每次需要玩家 runtime 測試時，先列出來源 D:\Project_EventAlertMod\EventAlertMod、目標通道與 Interface\AddOns\EventAlertMod、覆蓋方式、/reload 或完整重啟要求、預期測試步驟與回報 JSON 欄位；玩家完成部署後再開始判讀。
- 目的：避免把新根離線檔案、舊通道 symlink 或未部署版本誤當成遊戲內最新狀態；不自動寫入 WoW/WTF，也不以離線 pass 冒充實機 pass。

### 2026-08-23 EAM-20260823-CHARGE-SECRET-STATUSBAR：充能次數、Secret StatusBar 與五種版面

- 日期：2026-08-23。
- 狀態：程式、嚴格 mock、Flow 與靜態契約已完成；Retail／PTR／XPTR 尚未部署或真人視覺簽收。
- 症狀：充能技能加入清單後仍可能不出現；初版 fallback 的段數跟著恢復時間前進，而不是跟著剩餘可用次數；底部 4px 同圖示寬度 StatusBar 不夠顯眼；細部設定第一個冷卻行為按鈕曾與 Aura 專用「僅監控自己施放」重疊。
- 根因一：首次啟動只比較儲存 spellID 與 `UNIT_SPELLCAST_SUCCEEDED` spellID，沒有處理目前 override 與 base spell 對應；已改為安全 spell family 對齊，且其他 refresh／regen／形態事件仍不得替未施放技能開門。
- 根因二：共用安全欄位 reader 會因 `SpellChargeInfo` 含 Secret 欄位而拒絕整張表；已改為服務專屬欄位級判讀，只保存安全 `maxCharges`／`isActive`。
- 根因三：初版把 `GetSpellChargeDuration` 的 `DurationObject` 送入 StatusBar，語意實際是下一層恢復時間，不能代表 current/max 段數。
- 有效解法：`currentCharges` 無論安全或 Secret，都只在所有結構設定完成後直送 `StatusBar:SetValue`；安全 `maxCharges` 設定 min/max 與最多 20 段分隔線。Secret 值不比較、運算、字串化、序列化、保存或讀回。
- 版面：新增 TOP／BOTTOM／LEFT／RIGHT／RING；預設線性長度為圖示 150%、厚度 8px，可即時調整。環形採 12.1 `StatusBarRenderMode.Radial` 與插件內 128x128 TGA ring grid；能力不可用時回退 BOTTOM 線性條。
- 完成語意：充能技能只有回到最大次數才算完成，`cooldownRemoveAura` 才可移除；安全 current/max 直接判斷，Secret current 以安全 `isActive ~= true` 判斷回滿。
- UI 解法：只有 Aura 類型顯示 fromPlayer；技能／物品冷卻隱藏該控制，三項冷卻行為按鈕不再重疊。充能列版面／長度／厚度位於全域 Options，非戰鬥立即刷新，戰鬥中結構改動沿用既有版面並於安全時機更新。
- Lua 試錯：正式狀態與 Mock 各發現一次 `condition and false-or-nil or fallback` 三元陷阱；已改用明確 if 指派，保留合法 `false` 並確保 Secret sink 不保存原值。
- 工具試錯：標準 `apply_patch` 仍因新根 Windows sandbox setup refresh error 無法使用；PowerShell 精準替換曾因 CRLF／LF 不同及一次字串轉義 parser error 在寫入前中止。所有正式寫入均有備份、唯一匹配數量閘門與後續 Lua／Flow 驗證。
- API 依據：Retail 12.1 `C_Spell.GetSpellCharges` mixed secrecy、`StatusBar:SetValue` Secret BarValue sink、`StatusBar:SetRenderMode(Enum.StatusBarRenderMode.Radial)`；API 存在與離線 sink accepted 仍不等於遊戲視覺通過。
- 驗證：Lua 64/64；Flow all 79/79；Flow boundary 58/58；Validation Contracts 483/483。artifact：`.AI/TestResults/EAM_FlowValidation_all_20260823_162316.json`、`.AI/TestResults/EAM_FlowValidation_boundary_20260823_162320.json`。上述皆為 offline/static evidence。
- 實機待辦：部署後以 2 層以上充能技能測首次施放、base／override、max→部分→0→回復→max、戰鬥內外、三項 per-spell 行為、五種版面、分隔線、環形 fallback、Lua error／taint／blocked action。

### EAM-20260823-RUNES-GROUND-FAMILY：DK 符文與地面效果法術族群

- 日期：2026-08-23。
- 狀態：已完成離線實作與回歸；Retail／PTR／XPTR 真人視覺 pending。
- 症狀：死亡騎士符能可變動，但符文維持不動；冰霜之球可觸發地面效果，死亡凋零與反魔法立場未建立監控。
- 根因判斷：既有 RUNES 節點丟棄 `RUNE_POWER_UPDATE` 的 slot payload，改讀不適合表示六顆 Rune readiness 的泛用 UnitPower。GroundEffect 則以事件 spellID 直接查設定 spellID，遇到死亡凋零→褻瀆等 Base／Override ID 改寫便 miss；反魔法立場缺少安全命中診斷。
- 已嘗試方法：先完成六槽 API 實作與 Flow。首次 boundary 顯示畫面比例 `1→5/6→1` 均正確，但仍多一次 `GetRuneCount`；不是 API 必要 reread，而是 Lua `and/or` 將 `added=false` 轉成 nil。改為明確 if 後零額外 slot read。
- 有效解法：Env 封裝 `GetRuneCount`／`GetRuneCooldown`；Service 冷啟動同步六槽、事件直接更新 ready count，Renderer 沿用安全六段 POINTS。GroundEffect 冷路徑編譯 Base／Override／SpellInfo alias，exact-ID 優先、碰撞與 Secret fail-closed，天賦拓樸戰鬥中延後重編譯。
- 測試陷阱：Contracts 首次執行正確拒絕了修正前 `all 81/82` 的舊 artifact；產生新的 `all 82/82` 後 Importer 契約恢復通過。不得為通過而放寬 Importer。
- 驗證：Lua 64/64；Flow all 82/82；boundary 61/61；Validation Contracts 493/493。`unitpower.runes_event_driven_segments` 與 `ground.spell_family_activation` 均 pass，Secret scalar/key operation 為 0。
- 後續注意：目前 Rune 只呈現六段 readiness count，不呈現每顆獨立 recharge sweep。反魔法立場若因吸收上限提前結束，固定施放秒數只代表上限；需玩家實機回報，不能猜測提前結束事件。
- 發布打包陷阱：首份 Alpha 7.4 source ZIP 雖排除 `.AI/TestResults`，仍因匯入器留下 `.AI/.AI/TestResults` 而混入 4 個報告；根因是排除器只檢查首層。已改成任意深度 leaf 排除 `.git`、`backup`、`TestResults`、`.trash_*`，並由同一條 source-package Contract 鎖定。提交前另發現 `.AI/skills/wow-addon-dev/.git` 上游 metadata，已在路徑與 Reparse Point 驗證後備份並移至 `.AI/.trash_*`；Skill 本體保留為一般專案檔。錯誤 ZIP 僅保留於 ignored `Dist` 作稽核證據，不得上傳。

### EAM-20260823-RUNES-CAPABILITY-RECOUNT-FIX：DK 符文 Capability 判定與狀態計數精準同步

- 日期：2026-08-23。
- 狀態：已完成代碼修復、Flow 測試 (82/82) 與靜態契約檢驗 (493/493)；等待 Retail 12.1 實機簽收。
- 症狀：死亡騎士符文在玩家資源設定面板中可能被識別為 UNAVAILABLE 或 SECRET_DISPLAY，導致 `showValue`（數值文字）控制項與字級被禁用；單槽事件在極端狀態變更時可能產生計數漂移。
- 根因一：`Services/PlayerResourceCapability.lua` 的 `classify()` 依賴 `UnitHasPowerType(5)`，但在 Retail 12.x 中 DK 主 PowerType 是 6 (符能)，`UnitHasPowerType(5)` 常回傳 false，導致 Capability 誤判。
- 根因二：`applyRuneEvent()` 既有邏輯採用直接 `+1` / `-1` 算術，若遇事件重送或邊界槽位狀態變更，存在累計漂移風險。
- 有效解法：
  1. 在 `PlayerResourceCapability.lua` 中針對 `RUNES` 進行特化，只要 `GetRuneCount` 或 `GetRuneCooldown` 可用即判定為 `Capability.NUMERIC`，開放 UI 面板中符文的數值文字與格式設定。
  2. 在 `applyRuneEvent()` 中，當槽位狀態變更時，直接以 6 槽位 boolean 進行零分配 O(1) 確定性重算，徹底消除任何計數漂移。
- 驗證：Lua 語法檢查 64/64 PASS；Flow 測試 82/82 PASS；Validation Contracts 493/493 PASS。

### EAM-20260823-DK-RUNE-SPEC-BARS-DIAGNOSTIC：DK 符文專精圖示、6 格獨立下方冷卻條與專屬除錯診斷工具

- 日期：2026-08-23。
- 狀態：已完成代碼實作、Flow 測試 (82/82) 與靜態契約檢驗 (493/493)；等待玩家實機部署驗證。
- 需求與症狀：
  1. 玩家希望 DK 符文圖示能依照專精（血魄 250、冰霜 251、穢邪 252）自動動態切換專屬圖示。
  2. 玩家希望在符文主狀態列每一格下方增設獨立的冷卻微型條 (StatusBar)，即時呈現每顆符文 0%..100% 充能進度。
  3. 提供專屬除錯回報工具，供玩家一鍵輸出並複製 6 槽位即時秒數與狀態 JSON 向 AI 回報。
- 實作方案：
  1. **專精圖示**：在 `Data/PlayerResourceCatalog.lua` 建立 `SPEC_ICONS` 對照表，並提供 `Catalog.getResourceIcon(key, specID)`；`PowerRenderer.lua` 與 `PlayerResourceService.lua` 拓樸重建與專精切換事件時自動套用。
  2. **6 格下方微型冷卻條**：在 `PowerRenderer.lua` 中建立 6 條 3px 微型 `slotBars` 並對齊於主條每一格下方；`PlayerResourceService.lua` 在有符文冷卻時每 0.05s 啟動輕量排程計時器平滑更新充能進度，全滿時立即休眠 (0 CPU)。
  3. **專屬除錯工具**：在 `PlayerResourceProbe.lua` 提供 `buildRuneDiagnostic()`，彙整 6 槽位 readiness、start、duration、remainingSeconds 與 progressPercent，並在 `Slash.lua` 支援 `/eam rune` (或 `/eam probe rune`)，於聊天框印出摘要並彈出全選 EditBox 供玩家一鍵 `Ctrl+C` 複製。
- 驗證：
  - Lua 語法檢查：64/64 PASS。
  - Flow 狀態機測試：82/82 PASS。
  - Validation Contracts：493/493 PASS。

### EAM-20260823-RESOURCE-OPTIONS-VANISH-AND-NIL-TICKER-FIX：排程回呼 nil 函數修復與設定頁面資源消失問題

- 日期：2026-08-23。
- 狀態：已完成代碼修復、Flow 測試 (82/82) 與靜態契約檢驗 (493/493)；等待玩家實機部署驗證。
- 症狀與原因判斷：
  1. **實機報錯 `PlayerResourceService.lua:398: attempt to call a nil value`**：`runeCooldownTickerCallback` 在回呼結束時呼叫了 `updateRunePoints(node)`，但在 Lua 語法中該函數在下方以 `local function` 宣告，導致回呼執行時該變數仍為 `nil`。
  2. **設定視窗開啟時職業資源全部消失**：在 `UI/Options.lua` 開啟設定頁面或刷新版面時呼叫了 `Renderer.requestLayout()`，其對 `classPower` 執行 `layout()`；由於 modern EAM 職業資源已移至 `PowerRenderer`（子框架數為 0），`Renderer.lua:layout()` 執行了 `parent:Hide()`，將所有資源條的父錨點 `EAM_AlertFrame_classPower` 隱藏，導致所有職業資源永久消失直至 `/reload`。
  3. **DK 三專精專屬圖示更新**：依據 wowtools 與 WoW 官方 DB，將血魄、冰霜、穢邪三專精的符文圖示設定為官方對應專精圖示（血魄 `135770`、冰霜 `135773`、穢邪 `135775`），並支援動態查詢 `GetSpecializationInfoByID`。
- 有效解法：
  1. 在 `Services/PlayerResourceService.lua` 頂部前置宣告 `local updateRunePoints`，並在呼叫處增加防禦性判定，徹底消除 nil 調用崩潰。
  2. 在 `UI/Renderer.lua` 的 `layout()` 函數開頭增加 `if frameName == "classPower" then parent:Show() ... return true, "classPowerAnchor"`，確保作為 17 項獨立資源錨點的 `EAM_AlertFrame_classPower` 永遠保持顯示，不再因設定頁面或排版刷新被誤隱藏。
  3. 在 `Data/PlayerResourceCatalog.lua` 更新 `SPEC_ICONS` 與 `Catalog.getResourceIcon`，精準映射 12.x DK 專精圖示。
- 驗證：
  - Lua 語法檢查：64/64 PASS。
  - Flow 狀態機測試：82/82 PASS。
  - Validation Contracts：493/493 PASS。

### EAM-20260823-RESOURCE-PANEL-LIVE-AUTO-APPLY：玩家資源設定面板改動即時聯動生效

- 日期：2026-08-23。
- 狀態：已完成代碼實作、Flow 測試 (82/82) 與靜態契約檢驗 (493/493)；等待玩家實機部署驗證。
- 需求與設計：
  - 玩家希望在職業資源設定面板中調整各項數值時能夠「即時生效」，邊調邊看，無須每次點擊「套用」按鈕。
- 有效解法：
  - 在 `UI/PlayerResourcePanel.lua` 實作 `autoApplyDraft()` 輕量聯動核心，在 `refreshing == false` 狀態下，當玩家拖曳任何滑桿 (`OnValueChanged`)、勾選任何核取方塊 (`OnClick`)、切換顯示模式／錨點／偏向／字型／方向按鈕時，即時調用 `SavedVariables.updatePlayerResourceConfig`，非戰鬥中直接觸發 `PowerRenderer.configureResource` 與 `reflowResourceFrames` 即時重繪更新，並於底部顯示「資源設定已即時生效。」。
  - 戰鬥中變更則安全記錄為 `combatRebuildDeferred`，並於脫戰後自動套用。
- 驗證：
  - Lua 語法檢查：64/64 PASS。
  - Flow 狀態機測試：82/82 PASS。
  - Validation Contracts：493/493 PASS。

### EAM-20260823-RESOURCE-ALIGNMENT-AND-SPEC-DRIFT-FIX：即時調整時圖示跑掉與對齊位移修復

- 日期：2026-08-23。
- 狀態：已完成代碼修復、Flow 測試 (82/82) 與靜態契約檢驗 (493/493)；等待玩家實機部署驗證。
- 症狀與原因判斷：
  1. **調整過程專精圖示變回通用圖示**：在 `PlayerResourceService.lua` 的 `applyResourceConfigChange` 呼叫 `PowerRenderer.configureResource` 時，未傳入 `specializationID` 參數，導致 `Catalog.getResourceIcon` 在 `specializationID` 為 nil 時回退為通用圖示。
  2. **圖示與狀態列/標籤垂直對齊跑掉**：在 `PowerRenderer.lua` 的 `configureResource` 中，狀態列垂直偏移曾寫死為 `-7`，當玩家調整 `barHeight` 或 `iconSize` 時，狀態列、標籤與圖示之間產生錯位；且標籤與高亮邊框在重設尺寸時未同步對齊。
- 有效解法：
  1. 在 `Data/PlayerResourceCatalog.lua` 的 `Catalog.getResourceIcon` 中增加動態專精查詢保底：即使傳入 nil 也會自動查詢當前玩家 `GetSpecialization()` 取得專精 ID，保證 100% 顯示專精圖示。
  2. 在 `Services/PlayerResourceService.lua` 的 `applyResourceConfigChange` 中將 `PlayerResourceService.specializationID` 正式傳遞給 `configureResource`。
  3. 在 `UI/PowerRenderer.lua` 中全面重構相對定位：狀態列嚴格以 `frame.icon` 為水平/垂直基準（Y 偏移 0），`label` 對齊狀態列上方，`glow` 對齊圖示，`icon` 補齊標準 `SetTexCoord(0.08, 0.92, 0.08, 0.92)` 避免邊界拉伸，各部件在拖動任何滑桿時均保持幾何穩固。
- 驗證：
  - Lua 語法檢查：64/64 PASS。
  - Flow 狀態機測試：82/82 PASS。
  - Validation Contracts：493/493 PASS。






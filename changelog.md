# EventAlertMod 開發與治理完整變更日誌 (Development & Governance Changelog)

本檔案維護於專案根目錄，記載 EventAlertMod 的完整研發歷程、架構演進、AI 代理治理、離線驗證契約與版本發布紀錄。  
（註：WoW 插件發布專用的玩家可感知更新日誌僅維護於 `changelog.txt`，不含 AI 治理內容。）

---

## 📅 版本紀錄 (Version History)

### [Retail 12.1.5 & Forever 1.60.1 Alpha 8.9] - 2026.11.08
- **雙版本無縫統一架構 (Multi-Flavor Unified Architecture)**：
  - 採用單一插件目錄與單一 TOC 內聯條件載入技術 (`[AllowLoadGameType camelot, forever]`)，同時支援《至暗之夜》正式服 (Retail 12.1.5) 與《永恆之樹》經典永恆服 (Forever 1.60.1)。
  - 執行期自動偵測遊戲環境 (`EAM.detectGameFlavor`)，零效能耗損隔離各版本專屬資料層與業務邏輯。
  - 零分配記憶體架構：跨版本核心引擎、原生 C++ 倒數排程器 (`TimedSignalMap`) 與狀態物件池 (`StatePool`) 100% 共通共享。
- **[Forever 1.60.1 永恆服專屬] 全鏈路法術技能等級 (Spell Rank) 整合與暴雪原生容器相容**：
  - 新增 `SpellRankService` 與靜態多等級法術家族目錄 `ForeverCatalog.FOREVER_SPELL_RANK_FAMILIES`，動態展開原生光環容器 `candidateFilters.includeSpellIDs`，實現單一槽位無重複圖示無縫匹配全部等級（支援降階施法 Downranking 與隊友 Buff）。
  - 地面效果 `GroundEffectService` 與選項介面 `Options.lua` 支援法術等級 subtext (如 `[等級 4]`) 顯示。
- **[Forever 1.60.1 永恆服專屬] 經典五大魔法抗性 (Five Magic Resistances) 監控**：
  - 於人物屬性面板支援秘法、火焰、冰霜、自然、暗影五大抗性，整合 `UnitResistance("player", damageClass)` 以 `effectiveRes` 為核心顯示，支援自訂達標警戒紅框與進度條。
- **[Forever 1.60.1 永恆服專屬] 精神 (Spirit) 5 秒回魔規則偵測、MP5/HP5 雙恢復數值提醒與 Active 視覺動畫**：
  - 精準偵測施放法力消耗技能後的 5 秒不回魔規則 (5-Second Rule: 5SR)，整合 `GetManaRegenFromSpirit` (x5 MP5) 與 `GetHealthRegenFromSpirit` (x0.75x5 HP5)；
  - 支援 `FULL` (精神+5秒回魔/回血)、`REGEN_ONLY` (僅回魔/回血) 與 `STAT_ONLY` 三種數值顯示模式；
  - 提供 Active 醒目提醒（圖示發光邊框 / 無圖示文字 1.32x 放大與 1.45x 脈衝彈跳 + 冰晶藍亮色），並可選啟用全螢幕藍色邊框閃爍 (`CombatFlash.triggerSpiritActive()`)。
- **[Forever 1.60.1 永恆服專屬] 經典 60 級職業資源拓樸 (Classic 60-Level Player Resource Topology)**：
  - 完美支援經典 60 級 9 大職業經典能量機制：獵人法力與寵物集中值 (Mana / Focus)、術士法力與靈魂碎片 (Mana / Soul Shards)、德魯伊四形態切換 (法力 / 怒氣 / 能量 / 連擊點數)、盜賊能量與連擊點數、戰士怒氣、聖騎士/牧師/薩滿/法師純法力體系。
- **[Forever 1.60.1 永恆服專屬] 經典人物屬性與狀態即時監控 (Classic Character Stats & State Monitor)**：
  - 精神回魔五秒規則 (`SPIRIT_MANA_REGEN`)：整合 `GetManaRegenFromSpirit` 與 `GetHealthRegen`，精準提供施法中與脫離 5 秒規則後的高低回魔數值監控。
  - 防禦技能監控 (`DEFENSE_SKILL`)：整合 `UnitDefenseSkill`，防禦性判定回傳數值安全性，即時反映當前防禦技能與免爆門檻。
  - 獵人寵物快樂度與忠誠度 (`PET_HAPPINESS`)：整合 `C_PetInfo`，即時監控寵物心情狀態 (不快 / 高興 / 快樂) 與忠誠度階段。
  - 遠程彈藥剩餘需求 (`AMMO_STATUS`)：整合 `UnitUsesAmmo` 與 `C_PaperDollInfo`，於箭矢或子彈存量不足時即時提供視覺警報。
  - 護甲穿透與偏斜打擊率 (`ARMOR_PENETRATION` & `GLANCING_BLOW`)：精確計算經典 60 級物理輸出核心參數。
- **[Forever 1.60.1 永恆服專屬] 經典核心法術預設警報與啟發規則 (Forever Default Alerts & Spell Heuristics)**：
  - 內建 9 大職業經典 60 核心觸發預設監控（法師節能施法/秘法強化、戰士壓制/斬殺/狂怒/亂擊、盜賊還擊/無情打擊、獵人強化雄鷹守護等）與熱門飾品附魔。
  - 啟發式規則深度支援法術等級 (`SpellInfoService.isSpellBookItemLowRank`) 與經典觸發條件（閃躲後壓制、招架後還擊、目標 20% 血量斬殺）。
- **[Retail 12.1.5 專屬] 原生光環層數與持續時間雙條支援 (Native Aura Application & Duration Bars)**：
  - 深度實裝 12.1.5 `CustomAuraButton:SetApplicationBar` 與 `SetDurationBar` 原生條狀計量管線。
  - 採用頂底互斥排版（層數條錨定於頂部、持續時間條錨定於底部），文字倒數與計量圖形互不干擾。
  - 支援層數自訂上限 (`applicationBarMax: 1~20`) 與原生門檻過濾 (`applicationBarMin / minApplications`)，並具備舊版文字疊層自動降級。
  - 原生平滑緩動：精確支援 `Enum.StatusBarInterpolation.ExponentialEaseOut`，疊層增減絲滑無比。
- **[Retail 12.1.5 專屬] 原生光環 Pandemic 三態呼吸微動動畫與進場光暈 (Native Aura 3-Stage Pandemic & Lifecycle Animations)**：
  - 深度適配 12.1.5 Native Aura 容器之 `AddPandemicEnterAnimation` (One-shot Pop 放大)、`AddPandemicActiveAnimation` (窗口期循環心跳呼吸 Breathing Loop) 與 `AddPandemicLeaveAnimation` (平滑淡出還原) 原生動畫 API。
  - 導入 `AddAuraShownAnimation` 與 `AddAuraAssignedAnimation` 大招與重要 Proc 進場動感光暈，帶來視網膜級流暢視覺。
  - 嚴格 Secret Aspect 隔離：封印 `GetProgress` 查詢與戰鬥中換親，徹底防範 Taint 污染。
- **[Retail 12.1.5 專屬] 12.1.5 原生 Pandemic 結餘窗口精確判斷 (12.1.5 Native Pandemic Carry-Over Duration Precision)**：
  - 採用 `C_UnitAuras.GetRefreshCarryOverDuration` 精準結餘時間計算，嚴格於結餘小於等於 30% 基礎持續時間時觸發 Pandemic 傳染補 Dot 提醒，避免提前補 Dot 浪費剩餘時間。
  - 舊版客戶端平滑降級至 `C_UnitAuras.GetRefreshExtendedDuration` 擴展時長評估，確保全版本 DoT 補法時機精準無誤。
- **[Retail 12.1.5 專屬] 玩家職業資源動態格數分割、雙色漸層與條件式警戒系統 (Dynamic/Custom StatusBar Segments, Custom Gradient Colors & Conditional Alerts)**：
  - 點數型資源自動對齊角色上限與自訂分割格數：連擊點數 (5/6/7)、真氣 (5/6)、喚能師龍能/精華 (5/6)、聖能 (5)、靈魂裂片 (5)、秘法充能 (4)、符文 (6) 現已自動依據角色實際上限 (`UnitPowerMax`) 即時分割 StatusBar 格線與底部子格，並於「條形與尺寸」新增「自訂分割格數 (0=自動, 1~20)」滑桿。
  - 自訂條形單色與雙色漸層：於「條形與尺寸」新增「條形色彩模式」（預設職業動態色、自訂單色、自訂雙色漸層）及起點／終點調色盤，支援水平與垂直漸層渲染。
  - StatusBar 條件式警戒擴充：於「顯示與模式」新增「條件判定」（`>=` 高於或等於門檻 / `<=` 低於或等於門檻）、「條件達成時變色」（含警戒顏色調色盤）及「條件達成時播放音效」（邊緣觸發防洗頻提示音）。
- **[Retail 12.1.5 專屬] 喚能師專用資源「龍能」五語系官方術語校準 (Evoker Essence 5-Locale Blizzard Terminology Calibration)**：
  - 全面校準喚能師專用資源於全語系之暴雪官方術語命名（繁體中文「龍能」、簡體中文「精华」、英文「Essence」、韓文「정수」、俄文「Сущность」），確保介面選單、狀態條標籤與提示訊息 100% 精準對齊各語系官方客戶端。
- **[雙版本共通] 零 GC 原生排程器深度擴展 (Zero-Alloc TimedSignalMap Scheduler Engine)**：
  - 深度整合 12.1.5 `C_Timer.NewTimedSignalMap`、`TimerUtil.CreateTimedSignalCallbackMap` 與 `C_Timer.CreateTimedSignalCallbackMap` 原生鍵值排程機制，在支援的客戶端上由暴雪 C++ 引擎直接託管圖示倒數與定時信號。
  - 實現重複定時重設零記憶體配置 (Zero-Alloc Key Rescheduling)，大幅降低垃圾回收 (GC) 開銷。
  - 內建優雅降級代理，非 12.1.5 環境平滑 fallback 至自主維護狀態機。
- **[雙版本共通] 智慧音訊防洪閘門 (Intelligent Audio Floodgate)**：
  - 於 `C_UnitAuras.AddAuraSound` 與 `MediaService.playSound` 雙向注入 `audioThrottle` 節流防護（預設 0.3s，範圍 0.05s~5.0s），杜絕多目標 DoT 頻繁刷新或層數暴漲時引發連續音效轟炸的現象。
- **[雙版本共通] 4K 視網膜級物理像素對齊 (Retina Pixel Snapping & Zero-Flicker Frame Initialization)**：
  - 於 NativeAuraRenderer 與 PowerRenderer（資源條與 20 格分割點）全面實裝 `SetRoundLayoutToNearestPixel` 原生像素捨入，消除 1px 線條發虛或粗細不均。
  - 引入 `CreateFrameWithOptions` 隱藏預建立機制，徹底消除圖示首次生成時的瞬間畫面閃爍。
- **[雙版本共通] 暴雪 12.1.5 原生 C++ 數學、字串與表格加速庫整合 (Native C++ Math, String & Table Acceleration)**：
  - 實裝針對 Retail 12.1.5 暴雪原生底層 C++ 最佳化工具函數庫：
    - 數學加速：`math.clamp`、`math.saturate`、`math.round`、`math.lerp`、`math.normalize`、`math.sign`、`math.remap`、`math.wrap`、`math.isfinite`、`math.isnan`、`math.isinf`。
    - 字串加速：`string.contains`、`string.ltrim`、`string.rtrim`、`string.startswith`、`string.endswith`。
    - 表格加速：`table.isempty`、`table.contains`、`table.indexof`、`table.removeunordered`、`table.removevalue`、`table.keys`、`table.values`。
  - 防禦性向下相容 (Defensive Polyfills)：在舊版客戶端中自動啟用高效率 Lua 降級實作，兼具極致效能與跨版本無損相容性。
- **[雙版本共通] 暴雪 12.1+ 原生 C_EncodingUtil 與 Deflate 壓縮設定檔字串整合 (ProfileCodec EAMAP2: Native Encoding & Compression)**：
  - 支援以全新「EAMAP2:」格式匯出分享字串，全面整合暴雪 12.1+ 原生 `C_EncodingUtil` 序列化與 Deflate 壓縮，大幅縮減字串長度達 60%~75%，並完美向下相容舊版「EAMAP1:」純文字 Base64 字串匯入。
- **[雙版本共通] 原生布林色彩安全轉換與無污染渲染 (C_CurveUtil EvaluateColorFromBoolean Integration)**：
  - 採用 `C_CurveUtil.EvaluateColorValueFromBoolean` 與 `EvaluateColorFromBoolean` 處理秘密布林值 (Secret Booleans)，消除 Lua 分支比對造成的潛在 Taint 污染，確保技能可用性與超出射程透明度/灰階平滑渲染。
- **[雙版本共通] 原生引擎效能遙測模組 (C_AddOnProfiler Native Engine Profiling Telemetry)**：
  - 整合暴雪 12.1+ `C_AddOnProfiler` 原生分析器，提供即時近期平均耗時 (`RecentAverageTime`)、峰值耗時 (`PeakTime`) 與超限統計 (`CountTimeOver1Ms`)，可透過 `/eam metrics` 檢視插件健康度。
- **[雙版本共通] 暴雪 12.1+ C_CombatAudioAlert 戰鬥語音 TTS 整合 (MediaService TTS Alerting)**：
  - 整合 `C_CombatAudioAlert.SpeakText` 與 `C_VoiceChat` 雙軌語音合成 (TTS)，支援自訂提醒文字之語音朗讀與防重疊機制。
- **[雙版本共通] 原生斷法鎖系與失控冷卻偵測 (Loss of Control Cooldown Duration Integration)**：
  - 整合 `C_Spell.GetSpellLossOfControlCooldownDuration` 與 `LOSS_OF_CONTROL_UPDATE` 事件，精確偵測被斷法或特定系別受控時的原生冷卻時長與 DurationObject 倒數。
- **[雙版本共通] 原生治療與吸收量預測計算機整合 (Native Heal & Absorb Prediction Calculator Integration)**：
  - 整合 `CreateUnitHealPredictionCalculator` 與 `UnitGetDetailedHealPrediction` 原生預測計算機，提供高精度傷害吸收盾量 (`GetDamageAbsorbs`) 與治療吸收量 (`GetHealAbsorbs`) 即時統計。
- **[雙版本共通] 部署工具 `Deploy-EventAlertMod.ps1` 智慧多版本相容**：
  - 自動偵測 WowClassic.exe / Wow.exe，動態顯示 [1]~[4] 通道選單支援 Forever WTF 獨立備份與還原。
- **[除錯與診斷] 診斷中心、提示詞匯出、執行期探針全面適配 Forever 1.60.1**。
- **問題修復 (Bug Fixes)**：
  - 永恆服失控冷卻秘密數值比較崩潰修復 (`CooldownService.lua:963` Secret Number `locDur > 0` comparison fix)。
  - 永恆服光環全量更新秘密布林值崩潰修復 (`AuraService.lua:939` Secret Boolean `isFullUpdate` test fix)。
  - 戰鬥紅框與發光外框秘密數值比較加固 (`CombatFlash.lua` & `LibButtonGlow-1.0.lua` Secret Number protection)。
  - 玩家職業資源設定範圍切換錯誤修復 (`PlayerResourcePanel.lua:672` forward declaration nil call fix)。
  - 原生 `TimedSignalMap` C++ 物件唯讀保護與代理封裝 (`TimedSignalMap Proxy Wrapper Fix`)。
  - 表格工具值刪除傳回一致性修復 (`tableRemoveValue` boolean return consistency)。

---

### [Retail 12.1.5 Alpha 8.8] - 2026.10.23
- **魔獸世界 12.1.5 正式服全面適配 (Retail 12.1.5 Patch Compatibility)**：
  - TOC 介面版本支援正式升級：全面適配魔獸世界正式服 12.1.5 版本號（Interface: 120105），並持續無縫向下相容 12.1.0 及 12.0.7 客戶端。
- **地面效果多組時間解析與自選組別 (Ground Effect Multi-Duration Candidate Dropdown & Selection)**：
  - 智慧全文多時間組別解析：針對技能說明中包含多組秒數（如地面持續時間 vs 減速持續時間 vs 引導時間，例如暴風雪「8 秒內造成傷害...減速 50%，持續 3 秒」）的複雜技能，自動依在說明文字中的出現位置順序完整解析出所有時間候選（第 1 組、第 2 組等）。
  - 條件設定視窗自選下拉清單：在地面效果設定介面新增「時間組別選取」下拉選單，使用者可自由挑選欲使用的時間組別，點選後即時同步帶入「手動設定時間」輸入框。
  - 一鍵擷取聯動更新：點擊「一鍵擷取」時，即時重整並更新下拉選單候選列表，自動選中目標組別秒數並帶入編輯框，省去手動比對與輸入的繁瑣流程。
- **模組圖示外框色彩自訂與無邊框模式 (Customizable Alert Border Colors & Borderless Mode)**：
  - 8 大模組外框獨立選色：自身增益、自身減益、目標增益、目標減益、技能冷卻、物品冷卻、地面效果、寵物警示支援獨立調色盤與透明度調節。
  - 無邊框極簡模式支援：提供「啟用圖示類型外框」全域總開關與各模組獨立勾選開關，方便喜愛無邊框風格的玩家完全關閉外框線條。
  - 一鍵還原經典預設：提供「重設邊框色彩」按鈕，快速復原為各模組經典識別色彩（綠/紅/紫/黃等）。
  - 即時動態熱套用：修改外框色彩或開關後，畫面當前已顯示之所有圖示即時動態重繪，無須手動重載介面 (/reload)。
- **玩家職業資源獨立拖曳定位與常見框架九宮格依附 (Per-Resource Independent Dragging & 9-Point Frame Attachment)**：
  - 每項資源獨立位置與自由拖曳：於「玩家職業資源 -> 位置與錨點」新增「啟用此項獨立位置」開關與「移動此單項資源」／「移動全部/主錨點」／「歸零偏移 (0, 0)」操作按鈕，支援個別資源脫離群組堆疊並以滑鼠左鍵直接拖曳定位、右鍵點擊完成並自動同步滑桿數值。
  - 常見框架九宮格方向依附：新增「依附目標框架」選單（支援 EAM 資源主錨點、螢幕中央 UIParent、玩家頭像 PlayerFrame、目標頭像 TargetFrame、焦點頭像 FocusFrame、寵物頭像 PetFrame、個人資源條 PersonalResourceDisplay），搭配中文直覺化九宮格方位（左上、正上、右上、正左、中央、正右、左下、正下、右下）自由對齊。
- **第三方素材庫 LibSharedMedia-3.0 升級至 r156 (LibSharedMedia-3.0 Update to r156)**：
  - 升級至 r156 (支援 12.0.1+ / Interface 12000103)，擴充字型與材質素材庫，提升素材動態載入相容性與記憶體管理效率。
- **核心問題修復與加固 (Core Bug Fixes & Hardenings)**：
  - 戰鬥按鍵動作受阻錯誤排除 (`RightManagedFrameContainer Taint Remediation`)。
  - 冷卻排程器畫面凍結與未渲染修復 (`Cooldown Scheduler Frame Activation Fix`)。
  - 秘密值安全校驗前置防護 (`Secret Value Evaluation Order Safeguard`)。
  - 冷卻設定介面文字校準 (`Cooldown Options UI Text Correction`)。
  - 地面效果說明秒數擷取格式化錯誤修復 (`Ground Effect Duration Scrape Format Fix`)。
  - 戰鬥中多圖示重疊堆疊修復 (`Combat Multi-Icon Grid Positioning Fix`)。
  - 技能冷卻圖示亮黃方塊與動作條按鍵污染修復 (`Action Button Taint & Missing-Texture Yellow Box Fix`)。
  - 地面效果紫色外框顯示穩定性修復 (`Ground Effect Purple Border Restoration`)。
  - 模組邊框色彩即時熱更新防護 (`Alert Border Color Hot-Refresh Fix`)。
  - 原生光環無邊框設定即時隱藏與暴雪驅散外框防護 (`Native Aura Border Toggle & Dispel Texture Suppression Fix`)。
  - 技能天賦覆蓋冷卻倒數精準度與時有時無問題修復 (`Talent Override Cooldown Detection & Countdown Reliability Fix`)。
  - 原生排程器代理調用簽章校準 (`TimedSignalMap Proxy Call Signature Fix`)。
  - 天賦覆蓋技能動態切換冷卻補償檢定 (`Talent Override Transition Cooldown Compensation`)。
  - 秘密值 (Secret Values) 安全性防護與原生接收槽邊界檢定 (`Secret Value Table-Key Guard & Native Sink Binding`)。
  - 預熱圖示排版槽位初始化防重疊隔離機制 (`Prewarm Alert Slot Layout Isolation`)。
  - 高亮發光層級與外框分離防遮蔽修復 (`Proc Glow & Alert Border Visual Hierarchy Separation`)。
  - 公共冷卻 (GCD) 期間真實技能冷卻與減CD即時更新修復 (`Real Cooldown & Cooldown Reduction on GCD Fix`)。
  - 連續多次施法與進出戰鬥冷卻重置異常修復 (`Continuous Multi-Cast & Combat Re-entry Cooldown Activation Fix`)。
  - 引導技能戰鬥中冷卻激活與天賦減CD即時動態同步 (`Channeled Spell Cooldown Activation & Talent Passive CDR Live Sync`)。
  - 零CD天賦覆蓋觸發技冷卻保留修復 (`Zero-CD Talent Override Proc Cooldown Protection`)。
  - 活躍冷卻自適應動態採樣器 (`Continuous Active CDR Live Sampler`)。
  - 冷卻與法術覆蓋飛行記錄器與即時偵錯視窗 (`Cooldown & Spell Override Flight Recorder / Trace UI`)。
  - 技能啟發式先驗冷卻字典與延遲補償修復 (`Spell Heuristics & GCD Delay Compensation Fix`)。
  - 多次施法新冷卻重啟與覆蓋結餘鎖死修復 (`Subsequent Cast Renewal & Cooldown Residue Override Fix`)。
  - 單次技能充能判定校準與零CD觸發技完全隔離 (`Spell Charges Detection & Zero-CD Proc Isolation`)。

---

### [Retail 12.1.0 Alpha 8.7] - 2026.09.27
- **角色屬性與吸收量監控全面升級 (Player Stat & Absorb Monitor Upgrade)**：
  - 模組即時開關與生命週期修復：切換開關即時隱藏框架並停止輪詢；底層 Native Aura 結構變更時提供醒目 /reload 警示與一鍵重載按鈕。
  - 移動所有屬性與主錨點 GPU 樹狀零延遲同步聯動：拖曳主錨點時，全組屬性框架即時同步跟隨移動。
  - 依附目標框架多選：支援 EAM 主錨點、UIParent、玩家頭像、目標頭像、焦點頭像、寵物頭像與 9 大方位錨點。
  - 預設停用圖示：無圖示時自適應緊湊收縮，僅呈現數值文字、名稱標籤與進度條。
  - 進度條雙色漸層渲染 (`SetGradient API`)：支援水平與垂直雙色漸層混色渲染，並相容經典降級。
  - 全項自選色彩：進度條主色、次色、數值文字、名稱標籤均提供自選調色盤。
  - 屬性堆疊自選排序：清單新增上移、下移、重設控制，即時更新畫面堆疊順序。
- **全模組自訂技能與法術名稱功能實裝 (Custom Display Names Across All Modules)**：
  - 全新支援自訂圖示顯示名稱 (簡稱)：滿足在圖示間距密集、緊湊排版時避免名稱過長互相遮擋的需求（例如可將「聖盾術」簡稱為「盾」、「斬殺」簡稱為「斬」）。
  - 條件設定視窗 (`EAM_SpellConditionsFrame`) 佈局全面升級：新增「自訂顯示名稱 (簡稱)」專屬輸入框，並將視窗高度擴展至 680px。
  - 清單列表即時標記：若該項目有設定自訂簡稱，設定清單將即時以「法術名稱 (|cff00ff96簡稱|r)」醒目標註。
  - 全模組服務層深度整合：涵蓋自身 Buff、自身 Debuff、目標 Debuff、技能冷卻、物品冷卻（含裝備欄位）與地面效果全流程。
- **全語系 CLI 命令列擴充 (Slash Commands Expansion)**：
  - 補齊 `/eam preview`、`/eam rune`、`/eam add ground` 與 `/eam lang` 即時語系切換指令。
- **高頻熱路徑追蹤與存檔持久化 (Hot Path Frequency Profiler & SavedVariables Metrics)**：
  - 依照效能調優指引，於 Core/Performance 模組實裝零開銷（Zero-Alloc）高頻路徑追蹤器，精確統計運行期間各事件分發、服務掃描、渲染繪製與排程器之實際呼叫次數與每秒頻率 (CPS)。
  - 存檔深度整合：於 SavedVariables 自動記錄本次連線（lastSession）與跨連線累積（cumulative）呼叫數據及累積運行秒數。
- **高頻冷卻事件合併排程與警示更新零分配流水線 (Cooldown Event Coalescing & Zero-Allocation Alert Pipeline)**：
  - 警示排隊佇列零記憶體分配 (`Zero-Allocation Queue`)：AlertManager 採用持久化槽位（persistentSlots），消除高頻警示更新時每秒數千次的臨時 Table 堆疊分配。
  - 冷卻狀態髒檢查與無效重繪阻斷 (`Cooldown Dirty State Diffing & Render Suppression`)：CooldownService 與 ItemCooldownService 於狀態刷新前嚴格快照並比對顯示、啟用、佔位、灰階、發光、充能與時間數據。
  - 全域冷卻事件同幀合併排程 (`Frame-Level Cooldown Event Coalescing`)：針對高頻全域事件實裝同幀合併調度。
- **原生光環字型大小即時熱套用修復 (Native Aura Font Size Live Hot-Apply & Zero Reload)**：
  - 徹底修復 Retail 12.1.0 原生光環在設定介面調整字型大小後無法即時反應的重大缺陷。
  - 實裝 NativeAuraRenderer 弱引用按鈕註冊池與 `updateButtonFonts` 零配額熱套用機制。
- **目標光環切換目標即時刷新、殘留圖示清理與倒數鬼影根治 (Target Aura Target-Switching Live Refresh, Ghost Icon Purge & Countdown Ghost Elimination)**：
  - 實裝切換目標時的瞬間清理與精準光環重置，徹底根治目標死亡或換目標時的殘留鬼影。

---

### [Retail 12.1.0 Alpha 8.6] - 2026.09.14
- **全介面即時預覽與平滑熱渲染 (Live Real-Time Preview Overhaul)**：
  - 告警圖示、排版定位、外框色彩、扇形倒數在修改滑桿或核取方塊時 60fps 即時動態響應。
- **現代化自適應下拉選單 (Modern Adaptive Dropdown Components)**：
  - 重構全介面下拉選單組件，支援動態捲動、層級提權與滑鼠滾輪導航。
- **系統診斷與分析中心擴充 (System Diagnostics & Profiling Center)**：
  - 擴充除錯中心各項診斷指標與 PromptExport 匯出機能。

---

### [Retail 12.1.0 Alpha 8.5] - 2026.09.12
- **飛龍騎術動能滑翔專用速度監控 (Skyriding Gliding-Only Display)**：
  - 調用 `C_PlayerInfo.GetGlidingInfo` 專屬 API 取得 830%~1400% 動能滑翔速度。
- **扇形倒數色彩與透明度自訂 (Cooldown Swipe Color & Alpha Customization)**：
  - 支援冷卻扇形倒數自訂色彩與透明度調節，預設經典黑 (0, 0, 0, 0.8)。
- **11 大經典復古與現代主題調色盤深度重構 (11 Classic & Modern Themes Deep Visual Overhaul)**：
  - 重構 EAM 經典復刻、FF7 經典戰鬥視窗、Windows XP、Windows 7、Windows 10、Windows 3.1、Borland C++ IDE、DOS CRT、倚天中文、Red Alert、macOS Aqua 等 11 套主題。

---

### [Retail 12.1.0 Alpha 8.4] - 2026.09.04
- **二維網格佈局與行列擴展 (2D Grid Layout Across All Modules)**：
  - 支援水平/垂直方向指定每行最大圖示數量與自動折行排列。
- **戰鬥中冷卻能見度防護 (Cooldown Combat Visibility Guard)**：
  - 確保技能冷卻在進出戰鬥期間 100% 依設定呈現或隱藏。

---

### [Retail 12.1.0 Alpha 8.3] - 2026.08.28
- **新世代法術情報目錄與多維度群組管理 (Next-Gen Spell Catalog & Multidimensional Group Management)**。

---

### [Retail 12.1.0 Alpha 8.2] - 2026.08.27
- **LibSharedMedia 全生態字型熱套用 (LibSharedMedia Full Ecosystem & Zero-Delay Font Apply)**。

---

### [Retail 12.1.0 Alpha 8.1] - 2026.08.26
- **冷卻零透明度模式與戰鬥屬性記憶體回退 (Cooldown Zero-Alpha Mode & Combat Stat Memory Fallbacks)**。

---

### [Retail 12.1.0 Alpha 8.0] - 2026.08.25
- **獨立屬性定位排版與多框架自由錨定 (Independent Stat Positioning & Layout Control)**。

---

### [Retail 12.1.0 Alpha 7.9] - 2026.08.24
- **全介面控制項懸停提示 (Comprehensive UI Hover Tooltips)**。
- **主視窗螢幕邊界鎖定與一鍵居中重置 (ClampedToScreen & Center Reset Command)**。

---

### [Retail 12.1.0 Alpha 7.8] - 2026.08.24
- **「★ 角色屬性與吸收量監控」全新模組 (Player Stats & Absorbs Monitor Module)**。
- **Secret Value 防護與原生 StatusBar Sink 整合 (Secret Values Safeguard & Native StatusBar Sink)**。

---

### [Retail 12.1.0 Alpha 7.7] - 2026.08.24
- **子視窗聯動移動錨點 (Sub-window Interactive Frame Anchors)**。
- **全二級附屬側窗互斥 (Side Panel Mutual Exclusion)**。

# EventAlertMod 開發與治理完整變更日誌 (Development & Governance Changelog)

本檔案維護於專案根目錄，記載 EventAlertMod 的完整研發歷程、架構演進、AI 代理治理、離線驗證契約與版本發布紀錄。
（註：WoW 插件發布專用的玩家可感知更新日誌僅維護於 `changelog.txt`，不含 AI 治理內容。）

---

## 📅 版本紀錄 (Version History)

### [Retail 12.1.0 Alpha 7.9] - 2026.08.24
- **全介面控制項懸停提示 (Comprehensive UI Hover Tooltips)**：
  - 在全部按鈕、核取方塊、滑桿、下拉選單、輸入編輯框與清單操作列加入直觀的懸停說明提示 (Hover Tooltips)，清晰標註控制項用途、設定範圍與操作指引。
  - 實作通用工具函式 `EAM.UI.setTooltip`，支援純文字、多語系字串與表格綁定，徹底消除介面操作門檻。
  - 覆蓋主設定面板、告警框架排版、法術清單、條件設定、批次輸入、角色屬性、職業資源、功能模組、Profile 分享與除錯中心共 10 大視窗。
- **主視窗螢幕邊界鎖定與一鍵居中重置 (ClampedToScreen & Center Reset Command)**：
  - 主視窗增加 `SetClampedToScreen` 螢幕邊界鎖定，防止拖出畫面無法找回。
  - 新增 `/eam reset` (或 `/eam center` / `resetpos`) 斜線命令、小地圖按鈕中鍵點擊與 Shift+點擊，一鍵將主視窗拉回螢幕正中央。
  - 修正關閉主視窗時在 `closeAllSidePanels` 缺少 `close()` 引發的 nil call 錯誤，實作防禦性 `safeClosePanel` 機制。
- **官方 README 圖文導覽與 GitHub 直連展示 (Visual Showcase)**：
  - 整理 14 張全功能高畫質介面截圖，分類涵蓋系統選單、法術條件與階層吸附、職業資源與屬性排版。
- **AI 治理與離線門禁 (AI Governance & Quality Gates)**：
  - 離線門禁：Lua 語法 68/68 通過、流程驗證 84/84 通過、靜態契約 493/493 通過。

---

### [Retail 12.1.0 Alpha 7.8] - 2026.08.24
- **「★ 角色屬性與吸收量監控」全新模組 (Player Stats & Absorbs Monitor Module)**：
  - 支援 18 種核心屬性取值監控（主屬性：力量、敏捷、耐力、智力；副屬性：致命、加速、精通、臨機應變；輔助與生存：閃避、汲取、速度屬性評級、跑速、泳速、飛速、飛龍模式飛速、總吸收盾量、治療吸收量、護甲值）。
  - 速度類別全面淬鍊：跑速 (`GetUnitSpeed` 地面即時與上限跑速)、泳速 (水下速度)、飛速 (傳統穩定飛行 310%~420%)、飛龍模式飛速 (調用 `C_PlayerInfo.GetGlidingInfo` 專屬 API 取得 830%~1400% 動能滑翔速度)，並以 0.1s 高頻計時器平滑刷新。
  - 繁體中文術語嚴格對齊台灣官方用語（致命、加速、臨機應變）。
  - 獨立二級設定面板 (`UI/PlayerStatPanel.lua`)：無縫依附主視窗右側並支援同步平滑拖曳；支援個別自訂開關、是否顯示圖示、替代圖示路徑/代碼、圖示大小、數值字型大小、代表名稱字型大小、名稱替代文字、小數位數 (0~2)、大數值簡寫 (k/M)、警戒值上下限紅框警示、進度條開關與獨立框架定位排版。
  - 框架納入第 8 大告警框架 (`playerStat`)，支援經典奶牛頭位置預覽與獨立拖曳移動。
- **Secret Value 防護與原生 StatusBar Sink 整合 (Secret Values Safeguard & Native StatusBar Sink)**：
  - 針對 Retail 12.0+ / 12.1+ 部分 Unit API（如吸收量、移速等）在戰鬥/受污染環境下回傳受保護之 Secret Number，全面加入安全數值檢查，防止 Lua 層運算或格式化報錯。
  - 為屬性框架預建原生 C-Level `StatusBar`，遭遇 Secret 數值時直接將原始數值單向傳入 `StatusBar:SetValue` 展現視覺進度比例，Lua 不進行字串轉換與數值讀回。
  - 支援依屬性類別專屬著色（吸收盾天藍、治療吸收紫紅、移速青綠、副屬性金黃、主屬性橙紅、護甲鋼藍）。
- **全模組自訂替代圖示支援 (Custom Icon Override Across All Modules)**：
  - 在自身光環、目標光環、技能冷卻、物品冷卻、地面效果等所有模組細部設定中，新增「自訂替代圖示（代碼或材質路徑）」輸入框、即時動態預覽方塊與 Wago.tools 查詢網址框。
  - 服務層發布告警狀態時優先採用自訂圖示覆蓋原生預設圖示。
- **經典奶牛頭位置預覽 (Classic Cow Head Anchor Preview)**：
  - 拖曳排版位置時改用經典奶牛頭圖示 (`Interface\Icons\Spell_Nature_Polymorph_Cow`) 作為畫面預覽，並支援 8 大告警框架即時標籤名稱與紅/綠框高亮區分。
- **全方位即時熱預覽 (Live Real-time Config Preview)**：
  - 調整圖示尺寸、水平/垂直間距、透明度、扇形倒數轉圈動畫、轉圈透明度、自身/目標減益色度、法術/倒數/堆疊字型大小、成長方向時，畫面上告警框架與圖示即時 60fps 熱更新響應，無需重啟。
- **進入戰鬥全螢幕紅框閃爍 (In-Combat Fullscreen Red Edge Flash)**：
  - 實作 `UI/CombatFlash.lua` 全螢幕低血/戰鬥紅框閃爍動畫，監聽 `PLAYER_REGEN_DISABLED` 事件觸發戰鬥進入警示，並在主選單提供即時測試按鈕。
- **主題樣式與預設回歸**：
  - EAM 預設主題改回經典魔獸紅色選單按鈕與仿石框邊緣。

---

### [Retail 12.1.0 Alpha 7.7] - 2026.08.24
- **子視窗聯動移動錨點 (Sub-window Interactive Frame Anchors)**：
  - 點擊各類別監控（自身增益、跨職業、目標增益、技能冷卻、物品冷卻、地面效果、玩家職業資源）子視窗時，自動在畫面上亮起該模組專屬半透明移動錨點框（標記「按住左鍵拖曳」），方便玩家直觀拖曳調整在畫面上的定位。
  - 開啟排版位置設定時亮起全部 7 大框架移動錨點，關閉子視窗或主選單時自動隱藏所有錨點並套用最新座標排版。
- **全二級附屬側窗互斥 (Side Panel Mutual Exclusion)**：
  - 建立全局二級視窗互斥管理機制 `Options.closeAllSidePanels(except)` / `EAM.UI.closeAllSidePanels(except)`。
  - 開啟職業資源、除錯中心、Profile 匯入/匯出、功能模組、關於或清單子視窗時，自動關閉其他側邊面板，徹底消除多個側窗堆疊重疊問題。
- **除錯中心與診斷匯出修復 (Debug Center Flow Runner & Prompt Export Fix)**：
  - 修正流程測試分頁運行非同步回傳布林值導致的 index error，補全 `displayFlowReport` 格式化輸出。
  - 修正第 4 分頁系統診斷報告匯出按鈕調用 `PromptExport.buildDetailed()`。
- **AI 治理與自動化 (AI Governance & Automation)**：
  - 統一 GitHub Release 產物命名規範：`EventAlertMod_MN_yyyyMMdd_HHmmss-alpha-7.7.zip`（與 Alpha 6 格式完全一致）。
  - 分離雙軌日誌：專案根目錄新增 `changelog.md` 承載完整工程與治理細節，`changelog.txt` 維持純粹魔獸插件變更。
  - 離線門禁：Lua 語法 65/65 通過、流程驗證 84/84 通過、靜態契約 493/493 通過。

---

### [Retail 12.1.0 Alpha 7.5] - 2026.08.23
- **介面佈局重構與視覺優化**：
  - 主選單第 7 項目提升為「★ 玩家職業資源設定」，排版位置微調為第 8 項目，除錯類功能統整至 4-Tab「除錯與測試診斷中心」。
  - 全視窗快速關閉：所有 10 個 UI 視窗右上角加入原生 `UIPanelCloseButton` 快速關閉按鈕。
  - 階層式無縫吸附 (APPEND Docking)：主選單 ➔ 清單/排版/資源 ➔ 細部條件/批次輸入 視窗依序向右緊密貼合，並支援多視窗同步平滑拖曳。
- **Profile 分享功能升級 (Selective Profile Import/Export)**：
  - 支援 8 大自選項目匯出／匯入（自身/目標光環、技能/物品冷卻、地面效果、框架排版位置、職業資源設定、一般偏好設定），並提供快捷選取按鈕與預覽區塊分析。
- **職業資源設定即時生效與 DK 符文強化**：
  - 設定滑桿與下拉選單數值變更時即時驅動原生渲染器更新，非戰鬥不需 `/reload`。
  - 死亡騎士符文依血魄 (250)、冰霜 (251)、穢邪 (252) 專精動態切換專屬圖示；下方增設 6 格微型充能冷卻條；提供 `/eam rune` 槽位診斷與複製視窗。
- **AI 治理規範**：
  - 清理重複的 `.AI\.AI` 巢狀目錄，集中測試資產至 `.AI\TestResults\`。

---

### [Retail 12.1.0 Alpha 7.4] - 2026.08.23
- **充能環形版面與冷卻移除優化**：
  - 充能環形版面改用封裝的透明 TGA ring grid。
  - 冷卻完成必須先觀測到已消耗充能，再於 `currentCharges` 回到 `maxCharges` 時成立，避免施放後的舊全滿快照提早移除。
- **死亡騎士符文與地面效果族群**：
  - 符文改由 `GetRuneCount`／`GetRuneCooldown` 六槽初始化與 `RUNE_POWER_UPDATE(index, added)` 即時驅動；消耗／恢復更新 0..6 分段。
  - 地面效果設定在非戰鬥中編譯 Base／Override／目前 SpellInfo 法術族群；死亡凋零／褻瀆等替換 ID 可命中同一監控項，設定 ID 完全相符時優先。

---

### [Retail 12.1.0 Alpha 7.1 ~ 7.3] - 2026.08.23
- **充能次數 StatusBar 與版面**：
  - 充能 StatusBar 改以目前可用次數／最大次數顯示，不再讓段數跟著單層恢復時間前進；Secret `currentCharges` 只直送 Blizzard C-level `SetValue` sink。
  - 新增框外 TOP／BOTTOM／LEFT／RIGHT 與環形 RING 版面；預設長度／環直徑為圖示 150%、厚度 8px，並依安全 `maxCharges` 顯示分隔線。
  - SpellChargeInfo 改採欄位級 Secret 判讀；安全 current/max 顯示文字，Secret `currentCharges` 則以圖示同寬 StatusBar 接收官方 DurationObject。
- **邊框發光與視覺修復**：
  - 無計時時清除並隱藏 CooldownFrame 的 edge／bling，避免技能圖示留下白色空框。
  - Glow Border 支援內嵌 LibButtonGlow-1.0；自訂顏色、戰鬥首次建框或 library 不可用時回退 EAM 動畫邊框。

---

### [Retail 12.1.0 Alpha 7.0] - 2026.08.23
- **玩家職業資源模組 (Player Resource Module)**：
  - 玩家職業資源改為 17 資源、13 職業／40 組專精候選拓撲；`UNIT_DISPLAYPOWER` 只更新前景，不再因形態切換拆除背景追蹤。
  - 補強 Druid Bear／Cat／Caster／Moonkin／回 Bear、Energy→ComboPoints renderer ownership、PAIN 專用 legacy key 與模組停用清理。
  - 每項資源新增／補齊字型、數字文字大小與位置、方向、尺寸、透明度、排序、前景／背景與數值能力設定；非戰鬥變更即時套用，戰鬥中離戰後合併一次。
- **目標光環診斷與精確冷卻激活**：
  - Target Aura 提供匿名 diagnostics 與明確 `/eam add target` 手動 popup route；不保存 Secret、AuraData、Frame 或猜測 ID。
  - 技能冷卻監控改為只在玩家精確成功施放清單技能後首次 render；新增 `cooldownRemoveAura`、`showSCDOutsideCombat`、`glowSCDWhenUsable` 三項 per-spell nil／true／false 覆寫。

---

### [Retail 12.1.0 Alpha 6.0] - 2026.08.14
- **12.1 Native Aura 與核心重構**：
  - Retail 12.1 Native Aura gate 與 37 案三通道驗證矩陣。
  - Aura 職業／跨職業清單、批次 SpellID 輸入與不存在法術拒絕。
  - EAMAP1 JSON／Base64 Profile 匯入匯出與可捲動編輯區。
  - 五語系即時切換、字型選擇、十一套主題與按鈕底色／四態／邊框。

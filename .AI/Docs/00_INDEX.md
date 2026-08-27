<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod Remake 說明文件導航中心 / Documentation Hub

[![GitHub](https://img.shields.io/badge/source-GitHub-181717)](https://github.com/ziyuefan/EventAlertModRemake)
[![Release](https://img.shields.io/badge/release-Alpha%208.2-orange)](https://github.com/ziyuefan/EventAlertModRemake/releases)
[![Retail](https://img.shields.io/badge/WoW-Retail%2012.1-blue)](https://github.com/ziyuefan/EventAlertModRemake)
[![Interface](https://img.shields.io/badge/Interface-120007%20%7C%20120100-brightgreen)](https://github.com/ziyuefan/EventAlertModRemake)

> 🚀 **專為《魔獸世界：正式服 (Retail 12.1.0 / 12.0+)》打造的超輕量、零污染、純事件驅動法術監控與戰鬥告警插件！**

歡迎使用 EventAlertMod (EAM) 正式服重構版本說明文件中心。本中心為**插件使用者 (Players & Users)** 以及**代理開發者 (AI & Human Developers)** 提供完整的資訊導覽與架構參考。

---

## 🌟 現代版 EventAlertMod (EAM) 四大核心優勢

| 傳統法術監控 / 複雜大型插件 | 現代重構版 EventAlertMod (EAM) |
| :--- | :--- |
| ⚠️ **沉重且佔用資源**：大量背景 OnUpdate 輪詢、吃記憶體、引發戰鬥掉幀。 | ⚡ **極致輕量與零負擔**：純事件驅動架構，全面引入物件池技術（State Pools），消滅 GC 記憶體垃圾。 |
| ❌ **容易受污染報錯**：12.0+ 暴雪引入 Secret Values 後，常常在戰鬥中報錯噴黃字或引發 UI 異常。 | 🛡️ **暴雪 12.0+ 終極安全防護**：獨家採用原生 C-Level `StatusBar:SetValue` 直通渲染技術，絕不觸發 Taint 污染。 |
| 🔄 **設定繁瑣、需匯入字串**：需手動到網站翻找 WA 字串或手寫 Lua 條件判斷。 | 🎯 **直覺易用、秒加監控**：滑鼠停在任何技能、光環或物品上按 **`Ctrl + Alt`** 一秒加入，無需查 ID。 |
| 🐢 **速度顯示不準確**：傳統插件無法偵測 10.0+ / 11.0+ / 12.0+ 飛龍騎術的真實衝刺速度。 | 🏃 **業界唯一：四合一速度淬鍊**：專屬對接 `C_PlayerInfo.GetGlidingInfo()`，完美支援 **830%~1400%** 動態極速！ |

---

## ✨ 八大獨立告警模組 (8 Independent Alert Modules)

EAM 擁有 8 個完全解耦、獨立排版、自由拖曳的專業監控模組：

1. 🔮 **自身光環 (Player Buff / Debuff)**：監控自身增益與減益，支援堆疊層數、剩餘吸收盾量與高精度倒數。
2. 🎯 **目標光環 (Target Buff / Debuff)**：精確監控當前目標之光環、控制與 Debuff 狀態。
3. ⚔️ **跨職業光環 (Cross-Class / Target Cast)**：監控敵方關鍵爆發或隊友重要增益。
4. ⏳ **技能冷卻 (Spell Cooldown)**：純透明度（Alpha=0）常駐預載模式，0.00ms 零排版延遲；支援圓形環狀進度條 (`Radial Mode`) 與框外線性條 (`TOP/BOTTOM/LEFT/RIGHT`)。
5. 🎒 **物品冷卻 (Item Cooldown)**：飾品、主動使用裝備與消耗品冷卻監控。
6. 🌋 **地面效果 (Ground Effect)**：監控玩家施放的無光環地面範圍技能（如死亡凋零、褻瀆、冰霜之球、反魔法立場），支援天賦法術族群智能對齊。
7. ⚡ **玩家職業資源 (Player Resource)**：支援全 13 職業、40 組專精、17 種資源獨立節點（法力、怒氣、能量、連擊點、真氣、狂亂、符能、奧術充能、靈魂裂片、神聖能量、精華等）。
8. 📊 **角色屬性與吸收量 (Player Stats & Absorbs)**：依職業獨立配置，全方位即時監控 18 種角色數值（主屬性、副屬性、四合一速度、護甲值、總吸收盾量與治療吸收量）。

---

## 🔥 近期版本重大里程碑 (Recent Release Milestones)

- 🌟 **[Retail 12.1.0 Alpha 8.2] - 2026.08.27**
  - **LibSharedMedia-3.0 (SharedMedia) 素材生態全面整合**：實作 `ensureLSM` 動態探測與 `PLAYER_LOGIN` 延遲同步，支援第三方音效/字型包，支援安全雙軌音效播放 (`MediaService.playSound`) 與 12.1 Native Aura 音效接入。
  - **全域字型熱套用（免 `/reload` 即時生效）**：解鎖存檔白名單，預覽圖示、一般圖示、職業資源與人物屬性文字即時重繪。
  - **UI 下拉選單長清單自適應捲動容器**：支援數十至數百項素材之捲軸與滑鼠滾輪平滑捲動。
- 🌟 **[Retail 12.1.0 Alpha 8.1] - 2026.08.26**
  - **技能冷卻純透明度（Alpha=0）隱藏模式與全監控冷卻預先錨定**：非戰鬥狀態預先建立 Frame 與計算座標，冷卻完成透過 `SetAlpha(0)` 隱藏，實現 0.00ms 零 GC 零排版延遲且 100% 免疫戰鬥鎖定。
  - **角色屬性與副屬性戰鬥中防歸零快取備援**：建立 18 項屬性 `lastKnownStats` 記憶體快取，戰鬥受限自動無縫回退真實數值。
- 🌟 **[Retail 12.1.0 Alpha 8.0] - 2026.08.25**
  - **角色屬性依職業獨立設定 (Per-Class Player Stat Profiles)**：每種職業擁有 100% 獨立的屬性監控配置、閾值與獨立位置座標。
  - **吸收盾與治療吸收量雙軌偵測強化**：原生 Unit API + `C_UnitAuras` 點數雙軌即時累加運算。
  - **取消圖示純文字自適應排版與指定位置 (Iconless Adaptive Layout)**：純文字與圖示項目均能完美等距貼齊、零文字重疊。
  - **光環模組支援護盾吸收量即時顯示 (Aura Shield Absorb Amount Display)**：光環圖示右下角疊加層精確格式化顯示剩餘吸收盾量（如 `45.2k`、`1.2M`、`3(45k)`）。
- 🌟 **[Retail 12.1.0 Alpha 7.9] - 2026.08.24**
  - **全介面 10 大視窗控制項懸停提示 (Comprehensive UI Hover Tooltips)**：所有按鈕、核取方塊、滑桿、選單附帶直觀操作指引。
  - **主視窗螢幕邊界鎖定與一鍵居中重置 (`/eam reset`)**：支援螢幕邊界鎖定與 `/eam reset` 一鍵居中重置命令。
  - **官方 README 14 張高畫質介面圖文導覽 (Showcase)**。
- 🌟 **[Retail 12.1.0 Alpha 7.8] - 2026.08.24**
  - **「★ 角色屬性與吸收量監控」全新模組**：18 種核心屬性取值監控，四合一速度（地面、水下、懸浮飛行、飛龍滑翔 830%~1400%）。
  - **全模組自訂替代圖示支援 (Custom Icon Override)**：所有模組均可輸入官方 FileID 或材質路徑取代預設圖示。
  - **經典奶牛頭位置預覽 (Classic Cow Head Preview)**：以經典奶牛頭圖示清晰標記 8 大告警框架排版定位。
- 🌟 **[Retail 12.1.0 Alpha 7.5 ~ 7.7] - 2026.08.23**
  - **子視窗聯動移動錨點與多框架排版全開模式**。
  - **階層式無縫吸附 (APPEND Docking)** 與全二級側窗互斥機制。
  - **Profile 設定檔跨角色分享 (EAMAP1 JSON / Base64)**。
  - **死亡騎士符文儀表板**：依專精動態切換圖示，內建 6 格微型充能冷卻條與 `/eam rune` 診斷視窗。
- 🌟 **[Retail 12.1.0 Alpha 7.1 ~ 7.4] - 2026.08.23**
  - **充能技能 Secret 邊界防護與環形進度條 (`Radial Ring Mode`)**。
  - **地面效果 Base / Override 法術族群智能對齊**。
- 🌟 **[Retail 12.1.0 Alpha 5 ~ 7.0] - 2026.08.14 ~ 2026.08.23**
  - **17 種玩家職業資源獨立監控節點**。
  - **11 套精美主題風格與 5 大語言本地化 (zhTW, zhCN, enUS, koKR, ruRU)**。
- 🌟 **[Retail 12.1.0 Alpha 1 ~ 4] - 2026.07 ~ 2026.08**
  - **Retail 12.1 Native Aura (`CustomAuraContainer`) 重構首發**。
  - **零分配狀態緩衝池 (Zero-Allocation State Pools)**。
  - **Tooltip `Ctrl + Alt` 一秒快捷加入監控通道**。

---

## 🎮 插件使用者 / 玩家專區 (Players & Users)

如果您是使用此插件的玩家，請造訪以下檔案了解如何安裝、使用插件以及查看完整的更新歷史：

*   📖 **[快速使用指南 (README)](README.md.html)**
    *   插件安裝指引、命令列指令大全、圖文介面導覽、自訂圖示與 8 大模組特色功能詳解。
*   📜 **[版本更新日誌 (Changelog)](changelog.txt.html)**
    *   查看自重構以來所有 Alpha 版本的完整更新條目與修正細節。

---

## 🤖 代理開發與技術文檔專區 (AI & Human Developers)

如果您是參與本專案的 AI 編碼助理或是人類協作者，請詳細閱讀以下專案架構、開發規範與技術報告：

### 🛠️ 開發核心指導與規範 (Core Guidelines)
*   🔑 **[AI 開發入口與硬性限制 (AGENTS)](AGENTS.md.html)**
    *   **開發 Fact-of-Truth 最核心導引**。包含戰鬥中 Secret 檢查機制、Taint 防禦防禦規則、OnUpdate 控制、以及開發版打包快捷指令。
*   🔄 **[子代理派工與協作工作流 (Subagent Workflow)](17_SUBAGENT_WORKFLOW.md.html)**
    *   多 AI 專家（子代理）協作開發流程、RACI 矩陣（權責劃分）及 QC 根因分析的工程實施準則。
*   🧭 **[專家角色 RACI 矩陣 (Expert RACI)](21_RACI_EXPERTS_MATRIX.md.html)**
    *   24 位 canonical 專家名冊、唯一問責者、證據分級與派工簽收規則。
*   🔎 **[2026-06-21 專家會審報告](24_EXPERT_COUNCIL_REVIEW_20260621.md.html)**
    *   Retail 12.1 Aura readiness、Secret／Taint、效能與文件治理的分級檢討結果。
*   🚀 **[Antigravity 接手理解基準檔 (Baseline Assessment)](31_TAKEOVER_UNDERSTANDING_BASELINE_20260823_200615.md.html)**
    *   AI 治理、WoW Retail 12.x API 邊界、零 GC 效能架構、多職業資源與發布體系之權威理解基準點。

### 🏗️ 系統架構與 API 邊界 (Architecture & API)
*   📐 **[整體重構系統架構 (Architecture)](01_ARCHITECTURE.md.html)**
    *   數據層與渲染層（Renderer）完全解耦、EventRouter 事件驅動模型、以及 AlertManager 批次節流的系統級設計。
*   🛡️ **[正式服 12.x API 安全防線 (Retail API Boundaries)](02_RETAIL_API_BOUNDARIES.md.html)**
    *   四大核心 Secret 檢查 API、Table 索引安全防禦、與 C++ DurationObject 渲染通道。
*   📡 **[Retail API Change Intelligence：12.0.0 起始基線](25_RETAIL_API_CHANGE_INTELLIGENCE.md.html)**
    *   APICHG 版本情報、TOC／revision 矩陣、12.0.0～12.1.0 演進與 EAM 遷移窗口。
*   🧩 **[Retail 12.1 AuraContainer Native Backend](23_AURA_CONTAINER_IMPLEMENTATION.md.html)**
    *   68914 API 契約、Native/Legacy 分流、Slot/Group、Aura Sound、SavedVariables v2 與 PTR RQA 清單。
*   ⚡ **[玩家職業資源重構報告 (Player Resource Refactor)](30_PLAYER_RESOURCE_REFACTOR_REPORT.md.html)**
    *   17 種資源、13 職業／40 專精候選拓撲、德魯伊形態切換、DK 六槽符文與 Secret 資源寫入槽架構。
*   💾 **[數據狀態 Schema 規範 (State Schema)](03_STATE_SCHEMA.md.html)**
    *   零配置池（AuraStatePool）的數據格式定義、計時器狀態、以及回收邏輯。
*   📜 **[模組內部契約規範 (Module Contracts)](04_MODULE_CONTRACTS.md.html)**
    *   五大數據服務與 Renderer/AlertManager 之間的接口契約定義。

### ⚡ 效能優化與質量控管 (Performance & QA)
*   🏎️ **[極限效能與 JIT 編譯優化指南 (Performance Guide)](05_PERFORMANCE_GUIDE.md.html)**
    *   戰鬥熱路徑中 anonymous closures 產生的垃圾避讓、`pcall` 故障隔離、及 0-AllocationStatePool 的 JIT 優化實作。
*   📋 **[正式服實機測試計畫 (Test Plan)](06_TEST_PLAN_RETAIL.md.html)**
    *   冒煙測試案例、實機戰鬥 taint 檢驗、以及開發版打包安裝驗證方案。
*   🧪 **[流程驗證與開發回灌框架 (Flow Validation)](26_FLOW_VALIDATION_FRAMEWORK.md.html)**
    *   共用離線／實機案例、遊戲內測試按鈕、JSON／Markdown 報告與 WTF 回灌流程。
*   🖥️ **[本機 WoW 開發環境基準 (Local WoW Environment)](27_LOCAL_WOW_ENVIRONMENT.md.html)**
    *   `D:\World of Warcraft` 的 12.0.7／12.1.0 版本映射、WTF 路徑推導，以及指向 `D:\EventAlertMod` 的 Windows SymbolicLink 保護規則。
*   📓 **[開發瓶頸與避坑日誌 (Development Issue Log)](15_DEVELOPMENT_ISSUE_LOG.md.html)**
    *   記錄所有已解決的 JIT Abort、Blizzard protected frames 限制、與 frame clipsChildren 等邊界問題。
*   🔄 **[專案續接與試錯索引 (Project Continuity)](28_PROJECT_CONTINUITY.md.html)**
    *   上下文壓縮、代理交接或長時間中斷後的第一個人類可讀續接點。
*   🎮 **[真人實機驗證操作指南 (Live Test Step Guide)](29_LIVE_TEST_STEP_GUIDE.md.html)**
    *   37 個真實遊戲客戶端操作案例的執行步驟與簽收手冊。

<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod Remake 說明文件導航中心 / Documentation Hub

歡迎使用 EventAlertMod (EAM) 正式服重構版本說明文件中心。本中心為**插件使用者 (Players & Users)** 以及**代理開發者 (AI & Human Developers)** 提供了專屬的資訊入口。

---

## 🎮 插件使用者 / 玩家專區 (Players & Users)

如果您是使用此插件的玩家，請造訪以下檔案了解如何安裝、使用插件以及查看最近的更新日誌：

*   📖 **[快速使用指南 (README)](README.md.html)**
    *   插件安裝方法、命令列指令、主畫面調整、以及特色功能介紹（Pandemic 刷新提示、英雄天賦支援）。
*   📜 **[版本更新日誌 (Changelog)](changelog.txt.html)**
    *   查看 12.0.7 與 12.1.0 版本的完整重構更新細節，包含零分配垃圾回收與影子載體 (Shadow Host) 渲染避讓技術的部署歷史。

---

## 🤖 代理開發與協作者專區 (AI & Human Developers)

如果您是參與本專案的 AI 編碼助理或是人類協作者，請詳細閱讀以下專案架構與開發規範：

### 🛠️ 開發核心指導與規範 (Core Guidelines)
*   🔑 **[AI 開發入口與硬性限制 (AGENTS)](AGENTS.md.html)**
    *   **開發 Fact-of-Truth 最核心導引**。包含戰鬥中 Secret 檢查機制、Taint 防禦防禦規則、 OnUpdate 控制、以及開發版打包快捷指令。
*   🔄 **[子代理派工與協作工作流 (Subagent Workflow)](17_SUBAGENT_WORKFLOW.md.html)**
    *   多 AI 專家（子代理）協作開發流程、RACI 矩陣（權責劃分）及 QC 根因分析的工程實施準則。
*   🧭 **[專家角色 RACI 矩陣 (Expert RACI)](21_RACI_EXPERTS_MATRIX.md.html)**
    *   24 位 canonical 專家名冊、唯一問責者、證據分級與派工簽收規則。
*   🔎 **[2026-06-21 專家會審報告](24_EXPERT_COUNCIL_REVIEW_20260621.md.html)**
    *   Retail 12.1 Aura readiness、Secret／Taint、效能與文件治理的分級檢討結果。
*   🚀 **[Antigravity 接手理解基準檔 (Baseline Assessment)](31_TAKEOVER_UNDERSTANDING_BASELINE_20260823_200615.md.html)**
    *   2026-08-23 接手時之 AI 治理、WoW Retail 12.x API 邊界、零 GC 效能架構、多職業資源與發布體系之權威理解基準點。

### 🏗️ 系統架構與 API 邊界 (Architecture & API)
*   📐 **[整體重構系統架構 (Architecture)](01_ARCHITECTURE.md.html)**
    *   數據層與渲染層（Renderer）完全解耦、EventRouter 事件驅動模型、以及 AlertManager 批次節流的系統級設計。
*   🛡️ **[正式服 12.x API 安全防線 (Retail API Boundaries)](02_RETAIL_API_BOUNDARIES.md.html)**
    *   四大核心 Secret 檢查 API、Table 索引安全防禦、與 C++ DurationObject 渲染通道。
*   📡 **[Retail API Change Intelligence：12.0.0 起始基線](25_RETAIL_API_CHANGE_INTELLIGENCE.md.html)**
    *   APICHG 版本情報、TOC／revision 矩陣、12.0.0～12.1.0 演進與 EAM 遷移窗口。
*   🧩 **[Retail 12.1 AuraContainer Native Backend](23_AURA_CONTAINER_IMPLEMENTATION.md.html)**
    *   68914 API 契約、Native/Legacy 分流、Slot/Group、Aura Sound、SavedVariables v2 與 PTR RQA 清單。
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

---
name: eam-release-changelog-curator
description: >-
  版本日誌美化與多管道發布策展技能。嚴格執行「零 AI 治理內容」過濾防線，將開發日誌轉化為玩家感知之高質感 Markdown 排版，適配 CurseForge API 與 GitHub GFM 雙平台規範。
---

# EAM Release Changelog Curator (版本日誌美化與多管道策展)

本技能負責將 EventAlertMod 的開發歷程（`changelog.txt` / Issue Log / Git 提交）轉化為面向廣大魔獸世界玩家的高質感版本說明，並嚴格把關公開發布內容的純淨度。

## 1. 核心鐵律：零 AI 治理內容防線 (Zero AI-Governance Guard)

> [!IMPORTANT]
> **在 CurseForge 與 GitHub Release 的公開 CHANGELOG 中，絕對禁止出現任何 AI 治理描述！**

### ❌ 嚴禁包含的內容（黑名單）：
- 任何關於 AI 治理、Agent 分工、Codex / Antigravity 提示詞等文字。
- 測試合約數量（例如「499 條契約通過」、「Flow 86 案通過」、「PASS」等內部測試數據）。
- 內部工程腳本名稱（例如 `CheckLuaSyntax.ps1`、`Test-ValidationContracts.ps1`、`Run-FlowValidation.ps1`）。
- 內部治理文件或目錄索引（例如 `15_DEVELOPMENT_ISSUE_LOG.md`、`28_PROJECT_CONTINUITY.md`、`FOLDER_INDEX.html`）。

### ✔️ 應當著重闡述的內容（白名單）：
- **玩家可感知的新功能**（例如「獨立即時效果預覽視窗」、「飛龍速度僅滑翔顯示」、「冷卻扇形倒數色彩自訂」）。
- **使用者介面與操作優化**（例如「屬性面板 4-Tab 模組化防遮擋」、「滑桿間距拉開」、「選單高亮跟隨」）。
- **遊戲 API 與版本相容性**（例如「Retail 12.0+ / Midnight C-Level 曲線系統適配」、「戰鬥跑速 14.3% 限制修復」）。
- **玩家回報與實機問題修復 (Bug Fixes)**（例如「垂直狀態條生長修復」、「ESC 鍵純透明度無損隱藏」）。
- **清晰明確的安裝與使用指引**（例如解壓縮路徑、`/eam` 指令）。

## 2. CHANGELOG 結構化分類與雙領域邊界 (Categorized & Boundary Standards)

### A. 四大標準分類體系：
日誌與發布說明必須嚴格依據下列分類進行組織，禁止無序羅列：
- **✨ 【新增功能】(Features / Additions)**：全新模組、新功能、新命令、新設定選項。
- **⚡ 【體驗優化】(Improvements / Optimizations)**：操作體驗提升、效能提升、排版升級、記憶體降低。
- **🐛 【缺陷修復】(Bug Fixes)**：問題修復、幾何坐標回正、死鎖排除、API 報錯攔截。
- **🌐 【在地化支援】(Localization)**：5 大語系詞條同步、在地化翻譯更新。

### B. 涇渭分明：魔獸插件本體 vs. AI 治理工程 (Dual-Domain Boundary Separation)：
- **魔獸世界插件本體 (WoW AddOn - Player Visible)**：
  - 永遠作為發布正文的核心主體，100% 聚焦於遊戲性、UI、視覺與玩家操作。
  - `changelog.txt` 僅記載此部分。
- **AI 治理與工程架構 (AI Governance & Engineering Framework - Developer Only)**：
  - 在 GitHub Release 中，**必須使用 `<details><summary>🤖 AI 治理與工程架構 (點擊展開 / Click to Expand)</summary>...</details>` 完全獨立折疊**，嚴禁與玩家插件功能混寫在一起！
  - CurseForge 公開發布則維持 100% 玩家純度（不包含 AI 治理區塊，符合 CurseForge 審核標準）。

## 3. 雙平台收合展開能力 (Collapsible / Expandable Accordions)

為避免版本日誌「捲到落落長」，全面導入各平台的原生收合展開機制：

1. **GitHub Release (原生 GFM `<details><summary>`)**：
   - 詳細修復清單或長篇子項目以 `<details open><summary><b>📋 點擊展開/收合詳細變更清單</b></summary>...</details>` 封裝。
   - 歷史版本更新紀錄與 AI 治理技術細節以 `<details><summary>...</summary></details>` 預設折疊。
   - 讓訪客首屏保持乾淨俐落，僅見核心高光 (Highlights) 與下載按鈕。
2. **CurseForge Description (CF 專案首頁劇透收合標籤)**：
   - 採用 CurseForge 官方原生支援之 Spoiler 格式：
     ```markdown
     *** 劇透內容或標題
     <div class="spoiler"> <p> 收合內容 </p> </div>
     ```
   - 嚴禁在 CurseForge Description 中使用 HTML5 `<details><summary>`（CF 解析器會剝離或無法展開）；使用官方標準 Spoiler 結構確保網頁版與 App 客戶端完美渲染為折疊區塊。

## 4. 發布雙物料分離治理 (Dual Deliverables Separation)

在每一次版本發布或整理時，必須明確區分並產出以下兩種不同維度的物料：

| 物料分類 | 目標檔案路徑 | 用途與發布管道 | 內容範疇與排版特色 |
| :--- | :--- | :--- | :--- |
| **物料 A：單版本更新日誌**<br>(Single-Version Release Notes) | `Dist/RELEASE_NOTES_*.md`<br>`Dist/GITHUB_RELEASE_NOTES_*.md` | 1. GitHub Release 內文<br>2. CurseForge API 上傳 (`Upload-CurseForge.ps1 -ReleaseNotesPath`) | 僅專注於**本次版本**之新增功能、介面優化、Bug 修復與安裝指引。<br>支援 `<details>` 折疊區塊，杜絕全專案介紹以保持日誌緊湊。 |
| **物料 B：全專案首頁說明**<br>(Full Project Description) | `Deploy/CURSEFORGE-DESCRIPTION.md` | 供少年欸複製貼上至 **CurseForge 專案後台首頁 Description**（CF 無首頁更新 API） | **以 `README.md` 為基準之全方位專案介紹**。<br>包含徽章、四大優勢對比表、八大模組、現代化特性、14 張 CurseForge CDN 截圖展示、常用斜線命令表（含 `/eam preview`）、完整歷史日誌折疊區塊。<br>每次發布必須主動向少年欸回報檔案絕對路徑。 |



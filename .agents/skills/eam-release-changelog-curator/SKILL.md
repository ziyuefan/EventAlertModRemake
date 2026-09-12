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

## 2. 雙平台 Markdown 美化排版標準

1. **語意化 Emoji 視覺引導**：
   - 🪟 視窗/預覽面板、📐 排版/版面配置、🐉 飛龍/坐騎/速度、🎨 外觀/色彩/主題、🛡️ 戰鬥防護/確認框、🌲 資源條/狀態條、📈 曲線/數值系統、🌐 語系/在地化。
2. **層級分明與重點加粗**：
   - 一級大標題 (`# Title`) ➜ 二級分類 (`## Release Highlights`) ➜ 三級功能亮點 (`### Emoji 序號. 功能名稱 (英文名稱)`)。
   - 關鍵模組名稱、控制項名稱與 API 採用代碼標籤（`PreviewPanel`、`glideOnlyIcon`、`isGliding`）。
3. **適配 CurseForge API Markdown 解析器**：
   - CurseForge API 支援完整 Markdown（`changelogType = "markdown"`）。
   - 標題前後保留空行、列表符號使用 `-` 並保持 2 空格標準縮排，杜絕舊式生硬的 `--` Lua 註解符號。
4. **雙語對照標準**：
   - 大小標題一律採「中文名稱 (English Name)」雙語結構。
   - 繁體中文說明精確專業，若有英文 README / Changelog 需求則對等翻譯。

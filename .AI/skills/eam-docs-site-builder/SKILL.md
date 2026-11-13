---
name: eam-docs-site-builder
description: >-
  GitHub Pages 文件網站自動建置與多語系導覽技能。涵蓋 batch_convert_docs.py 離線執行、頂部 Navbar 注入、Changelog 語意化 HTML 渲染與跨文件連結驗證。
---

# EAM Docs Site Builder (GitHub Pages 文件站自動建置)

本技能規範將專案 Markdown 文檔與更新日誌自動建置為現代化靜態網站的流程。

## 1. 建置指令
```powershell
$env:EAM_DOCS_OFFLINE = "1"
python .\.AI\Tools\batch_convert_docs.py
```

## 2. 建置標準與導航同步
- **文件導航中心 (`00_INDEX`) 雙語同步**：增刪核心模組、里程碑、治理準則或技能時，須同步更新 `.AI/Docs/00_INDEX.md` 與 `.AI/Docs/00_INDEX_en.md`，並維持根目錄與 `EventAlertMod/` 之 `README.md`、`README_en.md` 與 `changelog.txt` 內容一致，以確保離線轉檔之 `index.html` 與雙語頁面零誤差。
- **頂部導覽列注入**：自動為 `index.html`、`README.md.html`、`changelog.txt.html`、`AGENTS.md.html` 注入響應式 Navbar。
- **Changelog 結構化排版**：將純文字 `changelog.txt` 轉為語意化版本區塊與變更標籤。
- **離線純淨轉換**：嚴禁未經授權將內部 Markdown 送往外部翻譯 API；必須在 `EAM_DOCS_OFFLINE="1"` 下產出至 `.AI/docs_html/` 供 GitHub Pages (`.github/workflows/deploy-pages.yml`) 部署。
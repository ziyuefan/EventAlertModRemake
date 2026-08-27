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

## 2. 建置標準
- **頂部導覽列注入**：自動為 `index.html`、`README.md.html`、`changelog.txt.html`、`AGENTS.md.html` 注入響應式 Navbar。
- **Changelog 結構化排版**：將純文字 `changelog.txt` 轉為語意化版本區塊與變更標籤。
- **離線純淨轉換**：嚴禁未經授權將內部 Markdown 送往外部翻譯 API。
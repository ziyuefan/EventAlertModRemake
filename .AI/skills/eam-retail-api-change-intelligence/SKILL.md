---
name: eam-retail-api-change-intelligence
description: 追蹤魔獸世界正式服 AddOn API 版本變更並轉化為 EventAlertMod 架構預警與遷移計畫。當任務涉及 API change summaries、新 PTR／RC／正式版、TOC 版本、Secret／Forbidden predicate、Aura／Cooldown／Tooltip／FrameXML 行為變更、API 新增移除棄用或版本相容性判斷時使用。
---

# EAM Retail API Change Intelligence

## 前置資料

1. 讀取專案根目錄 `AGENTS.md`。
2. 讀取 `Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md` 的版本基準。
3. 視影響範圍讀取 `Docs/02_RETAIL_API_BOUNDARIES.md`、`Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md`、`Docs/21_RACI_EXPERTS_MATRIX.md`。
4. 確認活動 TOC、目標 Retail build 與 Git 工作區狀態。

## 來源優先序

1. Blizzard 官方公告、PTR／RC development notes。
2. Blizzard UI 原始碼或可追溯的版本 diff。
3. Warcraft Wiki `API_change_summaries` 與指定 patch 的 API changes 頁；記錄 revision ID 與時間。
4. 專案 Markdown 與實際程式碼。
5. 搜尋摘要只能做線索，不能單獨成為結論。

## 工作流程

1. 從 `API_change_summaries` 找出目標版與前一穩定版。
2. 記錄 TOC、revision ID、revision time、官方連結與 PTR／正式狀態。
3. 按領域抽取變更：Secret／Forbidden、Aura、Cooldown／Duration、Tooltip、Frame／Widget、事件、SavedVariables、棄用／移除。
4. 使用 `rg` 對活動 TOC 與 Lua 做精確命中分析，不掃 `LegacyReference` 作為現況證據。
5. 建立 EAM 影響表：`P0 阻斷`、`P1 遷移`、`P2 觀察`、`無直接影響`。
6. 指定處置窗口：立即、PTR 期間、正式版前、後續觀察。
7. 將 API 事實、工程推論與實機結果分開；無客戶端證據時標示待 `RQA` 驗證。
8. 若形成新阻斷或解法，更新 `Docs/15_DEVELOPMENT_ISSUE_LOG.md`；版本基準改變時更新 `Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md`。

## 架構決策規則

- `APICHG` 負責變更情報與提前量；`SEC` 負責安全終審；`AURA121` 負責 Aura 遷移；`RQA` 負責實機證據。
- 優先建立 API adapter、capability gate 與明確降級，不把 patch 判斷散落在 Renderer。
- 新 API 尚在 PTR 時不得移除現行穩定路徑；先建立 feature detection 與退場條件。
- 不以 `pcall`、tooltip scraping、UI 可見性或官方框架寄生繞過 Secret／Forbidden 限制。
- 不把 Wiki revision time 誤寫成 patch 發布時間。
- Classic、MOP、Cata、Wrath、Era 不進入活動架構。

## 驗證

1. 查證每個來源 URL、revision ID、TOC 與 build 狀態。
2. 執行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\CheckLuaSyntax.ps1`。
3. 掃描新增／移除 API、舊全域 API、`OnUpdate`、`C_Timer`、Secret predicate、`SetParent` 與 `hooksecurefunc`。
4. 修改 Markdown 後同步限定 HTML，並掃描 EAMCODE placeholder、壞連結與表格欄位。
5. 明列未執行的 PTR／Retail 實機測試。

## 回傳格式

1. 查證版本、TOC、revision 與來源。
2. 版本差異摘要。
3. EAM 命中檔案與行號。
4. P0／P1／P2 影響。
5. 建議架構與遷移窗口。
6. 已執行與未執行驗證。
7. 文件／程式修改與剩餘風險。

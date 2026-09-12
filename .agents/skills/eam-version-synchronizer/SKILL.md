---
name: eam-version-synchronizer
description: >-
  EventAlertMod 全專案跨檔版本一致性同步與檢查技能。涵蓋 TOC、雙語 README、雙語 Changelog、SavedVariables 時間戳蓋章與 Git 分支同步規範。
---

# EAM Version Synchronizer (跨檔案版本一致性同步技能)

本技能負責在每一次發布或重大功能里程碑完成時，統一管理並核驗全專案所有版本號、時間戳與跨檔案文件一致性，杜絕版本脫節與漏更新。

## 1. 7 大核心版本檔案同步矩陣

在每次發布新版本（例如 `Alpha 8.5`）時，必須 100% 同步以下檔案矩陣：

| 序號 | 目標檔案路徑 | 責任與同步規範 |
| :---: | :--- | :--- |
| **1** | `EventAlertMod/EventAlertMod.toc` | 更新 `## Version: EventAlertMod_MN_YYYYMMDD`（如 `EventAlertMod_MN_20260912`）。宣告支援 Interface。 |
| **2** | `EventAlertMod/README.md` | 在歷史頂端新增 `### 🌟 [Retail 12.1.0 Alpha X.Y] - YYYY.MM.DD`，帶入繁體中文美化更新亮點。 |
| **3** | `README.md` (專案根目錄) | 必須與 `EventAlertMod/README.md` 維持 100% 完全相同內容。 |
| **4** | `EventAlertMod/README_en.md` | 在歷史頂端新增對應英文版 `### 🌟 [Retail 12.1.0 Alpha X.Y] - YYYY.MM.DD` 說明。 |
| **5** | `README_en.md` (專案根目錄) | 必須與 `EventAlertMod/README_en.md` 維持 100% 完全相同內容。 |
| **6** | `EventAlertMod/changelog.txt` | 記錄繁中更新日誌，頂端新增版本區塊，只記錄插件實機功能，不記內部治理。 |
| **7** | `changelog.txt` (專案根目錄) | 必須與 `EventAlertMod/changelog.txt` 維持 100% 完全相同內容。 |
| **8** | `EventAlertMod/changelog_en.txt` | 記錄英文更新日誌，頂端新增英文版本區塊。 |
| **9** | `changelog_en.txt` (專案根目錄) | 必須與 `EventAlertMod/changelog_en.txt` 維持 100% 完全相同內容。 |
| **10** | `Deploy/CURSEFORGE-DESCRIPTION.md` | 以 `README.md` 為來源基準，將截圖網址全數映射至 CurseForge CDN 附件空間（`https://media.forgecdn.net/attachments/...`），產出全專案首頁說明檔，每次發布主動向少年欸回報完整檔案路徑。 |

## 2. 存檔與資料庫版本蓋章 (SavedVariables Timestamping)

- **自動時間戳機制**：
  - `Core/SavedVariables.lua` 透過 `stampLastSaved()` 在 `PLAYER_LOGOUT`、`touchRevision` 與版本遷移時自動寫入：
    - `EAM_DB.meta.lastSavedAt`：ISO 8601 本地時間字串。
    - `EAM_DB.meta.lastSavedEpoch`：Unix 秒數時間戳。
    - `EAM_DB.meta.addonVersion`：對齊 TOC 之版本宣告。
- **遷移保護**：
  - 版本升級時僅補齊缺漏欄位（如新加入的 `glideOnlyIcon`、`columns`），絕對禁止覆蓋使用者的客製化設定。

## 3. Git 分支與發布前同步檢查

- 發布前必須先執行 `git status -s` 確認工作區乾淨。
- 檢查 `API_TOKEN.SEC` 絕對未出現在 Git 暫存區中（受 `.gitignore` 保護）。
- 推送至 GitHub：
  ```powershell
  git add .
  git commit -m "Release Retail 12.1.0 Alpha X.Y"
  git push origin main
  ```

---
name: eam-curseforge-publisher
description: >-
  CurseForge 安全發布與版本管理技能。涵蓋 Deploy/Upload-CurseForge.ps1、Markdown 版本日誌上傳、Cloudflare WAF 穿透、MIME 規範、Game Version ID 對齊、DPAPI 記憶體防護與 DryRun 模擬。
---

# EAM CurseForge Publisher (CurseForge 安全發布技能)

本技能封裝 EventAlertMod 發布至 CurseForge 官方 AddOn 平台的標準化全流程。

## 1. 核心發布指令

```powershell
# 1. 詢問模式 (對話式逐步確認發布)
pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1

# 2. Dry-Run 模擬驗證 (全真負載檢驗但不實際發送請求)
pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1 -DryRun -NonInteractive -ReleaseType alpha -DisplayName "EventAlertMod Retail 12.1.0 Alpha 8.5" -ZipPath "Dist\EventAlertMod_*.zip" -ReleaseNotesPath "Dist\RELEASE_NOTES_Alpha_8.5.md"

# 3. 非互動式自動化發布 (適用於 CI/CD 與腳本調用)
pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1 -NonInteractive -ReleaseType alpha -DisplayName "EventAlertMod Retail 12.1.0 Alpha 8.5" -ZipPath "Dist\EventAlertMod_*.zip" -ReleaseNotesPath "Dist\RELEASE_NOTES_Alpha_8.5.md"
```

## 2. 核心規範與安全防護

- **Markdown 版本說明支援 (`changelogType = "markdown"`)**：
  - API Payload 之 `changelogType` 必須為 `markdown`。
  - 版本說明內容由 `eam-release-changelog-curator` 策展，**嚴格 100% 排除任何 AI 治理描述**，專注於玩家實機功能與修復。
- **Cloudflare WAF 穿透**：
  - 強制帶上 `User-Agent: BigWigs/Packager` 標頭，並優先調用 Windows 原生 `curl.exe`。
- **MIME 規範**：
  - `metadata` 宣告為 `application/json`，`file` 宣告為 `application/zip`。
- **版本代碼對齊 (Game Version ID)**：
  - Retail 12.1.0 對應官方 ID `16519`。
- **Windows DPAPI 機密雙重防護**：
  - API Token 100% 保存在本地 `API_TOKEN.SEC` 二進位加密檔中，透過 Windows DPAPI 瞬時解密。
  - 終端機日誌自動遮蔽 Token 長度與字元，絕對禁止輸出至控制台、提交至 Git 或納入 ZIP 發布包。

## 3. CurseForge 專案首頁描述檔 (CURSEFORGE-DESCRIPTION.md) 規範

- **無首頁更新 API 之邊界**：CurseForge 官方 Upload API 僅支援發布檔案與 Release Notes Changelog 更新，不提供更新專案首頁 Description 的公開 REST API。
- **來源基準與排版標準**：
  - **嚴格以專案根目錄 `README.md` 為基準**：專案首頁描述必須是「全專案完整說明 (Full Addon Description)」，涵蓋頂部徽章、四大優勢對比表、八大模組介紹、現代化功能特性、14 張展示截圖、常用命令對照表（含 `/eam preview`）、Ctrl+Alt 操作指引、完整歷史更新日誌（含最新版折疊區塊）、系統支援邊界與外部連結；**嚴禁簡化為單一版本的 Changelog**。
  - **圖片路徑全面對齊 CurseForge CDN**：將 `README.md` 中所有指向 GitHub 的截圖網址（`raw.githubusercontent.com/...`），精準替換為 CurseForge 官方專用 CDN 附件空間網址（`https://media.forgecdn.net/attachments/...`），確保在 CurseForge 網頁呈現時不破圖、不觸發外連防盜鏈警告。
- **每次發布必產出與回報**：
  - 每次執行版本發布或版本整理時，必須同步產出或更新 `Deploy/CURSEFORGE-DESCRIPTION.md`。
  - 發布完成後，在對話中**必須第一時間主動提供該檔案的完整絕對路徑**（包含可點擊之 Markdown 檔案連結：[`Deploy/CURSEFORGE-DESCRIPTION.md`](file:///d:/Project_EventAlertMod_AGY/Deploy/CURSEFORGE-DESCRIPTION.md)），方便少年欸直接開啟複製並貼上至 CurseForge 專案首頁。
- **14 大展示圖片 CDN 映射表 (CurseForge Attachments CDN)**：
  - 主設定面板: `https://media.forgecdn.net/attachments/description/826042/description_04ac0707-5adb-4e9f-a51c-876fb3e1bc84.jpg`
  - 功能模組開關: `https://media.forgecdn.net/attachments/description/826042/description_e2998c73-1a7b-4cee-ada8-5a98d40888ac.jpg`
  - 關於插件資訊: `https://media.forgecdn.net/attachments/description/826042/description_2b46c72f-8515-493e-a3a2-5d5271fd2b90.jpg`
  - 主題樣式下拉選單: `https://media.forgecdn.net/attachments/description/826042/description_8fb2f296-64fd-4fdd-9881-876e63a748d9.jpg`
  - 提示音效下拉選單: `https://media.forgecdn.net/attachments/description/826042/description_4961ea26-688a-4c99-bc3c-404101ab6fe9.jpg`
  - 多國語系下拉選單: `https://media.forgecdn.net/attachments/description/826042/description_1a8c7c49-0ce4-4c0d-ae21-1aa64dc7f25b.jpg`
  - 自身光環細部條件: `https://media.forgecdn.net/attachments/1891/207/07_eaeoacae-aec-e-aeae-a_selfauraconditions-jpg.jpg`
  - 技能冷卻覆寫設定: `https://media.forgecdn.net/attachments/1891/208/08_aee12aacaeeecoea-e-a_spellcooldownoptions-jpg.jpg`
  - 物品冷卻監控設定: `https://media.forgecdn.net/attachments/1891/209/09_c-c-aaacaee-a_itemcooldownoptions-jpg.jpg`
  - 地面效果階層吸附: `https://media.forgecdn.net/attachments/1891/210/10_aeaeaecaeea-c-eaa-e_groundeffectdocking-jpg.jpg`
  - 玩家職業資源面板: `https://media.forgecdn.net/attachments/1891/211/11_c-c-aeaee3aeoe-aeae_playerresourcepanel-jpg.jpg`
  - 角色屬性監控面板: `https://media.forgecdn.net/attachments/1891/212/12_ee2aaeea-aeecaeeae_playerstatspanel-jpg.jpg`
  - 告警框架排版位置: `https://media.forgecdn.net/attachments/1891/213/13_aeaeaea12c12aeceae-aaeco_layoutpositionoptions.jpg`
  - 職業 Profile 分享: `https://media.forgecdn.net/attachments/1891/214/14_eaeprofileaaoea-aa-aoeae_profilecodecpanel-jpg.jpg`



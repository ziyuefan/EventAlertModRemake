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

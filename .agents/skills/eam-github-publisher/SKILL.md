---
name: eam-github-publisher
description: >-
  EventAlertMod GitHub Release 發布與管理技能。涵蓋 Deploy/Publish-GitHubRelease.ps1、gh CLI 互動、alpha-X.Y 標籤命名規範、預設 --prerelease 保護、附件打包 (ZIP + SHA-256) 與 GitHub 原生源碼打包規範。
---

# EAM GitHub Publisher (GitHub Release 發布管理技能)

本技能封裝 EventAlertMod 發布至 GitHub Release / Pre-release 的標準化全流程。

## 1. 核心發布指令

```powershell
# 1. 完整自動化發布 (預設自動建置插件包、執行品質門禁、產出 Release Notes 並發布 Pre-release)
pwsh -NoProfile -File .\Deploy\Publish-GitHubRelease.ps1 -Tag "alpha-8.5" -Title "EventAlertMod Retail 12.1.0 Alpha 8.5"

# 2. Dry-Run 模擬預覽 (不執行實際網路推送)
pwsh -NoProfile -File .\Deploy\Publish-GitHubRelease.ps1 -Tag "alpha-8.5" -Title "EventAlertMod Retail 12.1.0 Alpha 8.5" -DryRun

# 3. 使用 gh CLI 手動發布 (搭配美化 Release Notes)
gh release create "alpha-8.5" "Dist\EventAlertMod_MN_20260912-alpha-8.5_AGY.zip" "Dist\EventAlertMod_MN_20260912-alpha-8.5_AGY.zip.sha256" --title "EventAlertMod Retail 12.1.0 Alpha 8.5" --notes-file "Dist\GITHUB_RELEASE_NOTES_alpha-8.5.md" --prerelease
```

## 2. 核心規範與防護邊界

- **標籤與標題命名規範**：
  - Tag 採用小寫破折號格式：`alpha-8.5`、`beta-1.0`。
  - Title 採用正式版本名：`EventAlertMod Retail 12.1.0 Alpha 8.5`。
- **預設 Pre-release 保護**：
  - 開發階段與 Alpha/Beta 版本一律附帶 `--prerelease` 旗標，保護 `main` 穩定性。
- **原始碼打包規範**：
  - 嚴格遵守專案邊界：GitHub Release 由 GitHub 自動打包 Source 原始碼 (`Source code (zip)` 與 `Source code (tar.gz)`)。
  - 本機與 Release 附件**絕不重複打包或上傳 SRC 源碼包**，節省頻寬與儲存空間。
- **發布產物清單**：
  - 僅掛載遊戲 AddOn 插件安裝包（`EventAlertMod_MN_*.zip`）與對應之 SHA-256 校驗文字檔（`.sha256`）。
- **離線門禁 Fail-Closed**：
  - 發布前必須先通過 `CheckLuaSyntax.ps1`、`Run-FlowValidation.ps1 -Suite all` 與 `Test-ValidationContracts.ps1`。任一失敗立即終止發布。
- **Release Notes 零 AI 治理標準**：
  - 說明內容必須經由 `eam-release-changelog-curator` 策展，100% 杜絕任何 AI 治理、合約數量、測試框架等內部工程描述。

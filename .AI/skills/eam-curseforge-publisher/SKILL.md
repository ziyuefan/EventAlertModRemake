---
name: eam-curseforge-publisher
description: >-
  CurseForge 安全發布與版本管理技能。涵蓋 Deploy/Upload-CurseForge.ps1、Cloudflare WAF 穿透、MIME 規範、Game Version ID 對齊與 DryRun 模擬。
---

# EAM CurseForge Publisher (CurseForge 安全發布技能)

本技能封裝 EventAlertMod 發布至 CurseForge 的標準化全流程。

## 1. 發布指令
```powershell
# 詢問模式 (對話式確認)
pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1

# Dry-Run 模擬驗證
pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1 -DryRun
```

## 2. 核心規範與防護
- **Cloudflare WAF 穿透**：強制帶上 `User-Agent: BigWigs/Packager` 標頭與 `curl.exe` 優先引擎。
- **MIME 類型宣告**：`metadata` 指定 `application/json`，`file` 指定 `application/zip`。
- **版本代碼對齊**：Retail 12.1.0 對應官方 ID `16519`。
- **DPAPI 記憶體解密**：自動由 `.AI/API_TOKEN.SEC` 瞬時解密，終端機自動遮蔽。
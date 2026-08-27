---
name: eam-local-wow-deployer
description: >-
  WoW 本機多客戶端安全部署與存檔備份還原技能。涵蓋 Windows Registry 根目錄偵測、Reparse Point fail-closed 防禦與 WTF 存檔備份還原。
---

# EAM Local WoW Deployer (本機 WoW 安全部署與存檔備份)

本技能規範將開發中插件安全部署至本機魔獸世界客戶端的標準流程。

## 1. 部署與狀態指令
```powershell
# 檢查各通道狀態
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1 -Action Status

# 互動部署
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1

# WTF 存檔備份與還原
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1 -Action Backup -Channel Retail
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1 -Action Restore -Channel Retail
```

## 2. 邊界與安全守則
- **Reparse Point 絕對中斷**：若目標目錄為 SymbolicLink 或 Junction，立即停止，防止意外破壞真實資料夾。
- **備份優先**：覆寫前自動為舊版插件與 WTF 建立帶時間戳之打包備份。
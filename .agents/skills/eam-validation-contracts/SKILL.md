---
name: eam-validation-contracts
description: >-
  493+ 項全專案代碼契約斷言與 AST 靜態掃描技能。涵蓋 TOC 順序、5 語系 144 詞條對齊、Lua 語法檢查與連續性事實核驗。
---

# EAM Validation Contracts (全專案代碼契約驗證)

本技能規範專案發布與變更前的最高門禁（Gatekeeper）檢驗標準。

## 1. 契約測試運行指令
```powershell
pwsh -NoProfile -File .\.AI\Tools\Test-ValidationContracts.ps1
```

## 2. 核心檢查清單 (493+ 項斷言)
- **語法全覆蓋**：全專案 71 個 Lua 檔案 100% 通過 `luac -p` 靜態語法解析。
- **TOC 載入順序**：驗證庫檔案、主題、服務、UI、Managers 載入鏈。
- **多語系一致性**：`enUS`、`zhTW`、`zhCN`、`koKR`、`ruRU` 5 大語系 144 詞條 100% 鏡像對齊。
- **排除契約**：驗證封裝排除清單，防止本地產物、日誌或機密外流。
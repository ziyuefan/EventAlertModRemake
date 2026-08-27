---
name: eam-flow-validation-harness
description: >-
  離線 Flow 業務狀態機沙盒自動化驗證技能。涵蓋 84+ 項狀態機場景、戰鬥轉換模擬、Secret 數值注入與結構化測試報告輸出。
---

# EAM Flow Validation Harness (離線 Flow 狀態機驗證)

本技能指導如何在無 WoW 客戶端的離線環境下，透過 PowerShell + Lua 沙盒自動化運行 84+ 項業務狀態機測試。

## 1. 測試運行指令
```powershell
pwsh -NoProfile -File .\.AI\Tools\Run-FlowValidation.ps1
```

## 2. 測試涵蓋領域
- 光環生命週期（獲得、刷新、堆疊、移除、過期）。
- 技能冷卻精確施法過濾與覆蓋法術切換。
- 德魯伊 5 形態資源切換與 DK 符文冷卻狀態機。
- Secret 數值注入防護與 C-Level Sink 單向驗證。
- 多語系切換與主題即時套用。
---
name: eam-target-aura-anonymous-probe
description: >-
  目標光環匿名偵測與無污染採集技能。涵蓋 TooltipMonitorService 匿名回呼、Ctrl+Alt 修飾鍵判定、非戰鬥安全閘門與杜絕 Frame 遍歷。
---

# EAM Target Aura Anonymous Probe (目標光環無污染採集)

本技能規範在 12.x 目標光環資料受保護限制下，如何進行零污染的安全採集。

## 1. 匿名回呼與候選過期機制
- `TooltipMonitorService` 僅輸出匿名候選快照與過期計數。
- 嚴禁保存或序列化 Secret 物件、AuraData 實體或未經驗證之猜測 ID。

## 2. 嚴格觸發前檢條件 (Pre-condition Gates)
- 必須滿足：**非戰鬥中** + **無鍵盤輸入焦點** + **精確按住 Ctrl+Alt** + **Tooltip 處於有效懸停狀態**。
- 嚴禁 Hook 官方 `TargetFrame` / `AuraButton`，嚴禁使用 `GetMouseFocus()` 或遍歷子元件，防止傳播 Taint。
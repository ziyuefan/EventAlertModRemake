---
name: eam-live-matrix-inspector
description: >-
  PTR / XPTR / Retail 真人實機測試矩陣指南技能。涵蓋 Data/LiveValidationMatrix.json、跨版本實機回報協議與 Taint 排查標準流程。
---

# EAM Live Matrix Inspector (真人實機測試矩陣指南)

本技能規範真人玩家在魔獸世界實機客戶端中的測試與驗證回報流程。

## 1. 跨版本對齊矩陣
- **Retail (正式服 12.1+)**：驗證 Native Aura、Secret Sink、LSM 素材。
- **PTR (公開測試服 12.1+)**：驗證最新 API 變更與即時修復。
- **XPTR (舊世代 12.0.7+)**：驗證向下相容通道與降級表現。

## 2. 實機回報標準協議
請玩家依據 `.AI/Docs/29_LIVE_TEST_STEP_GUIDE.md` 回報：
- 測試通道與客戶端 Build 版本。
- 是否進入戰鬥（In-Combat / Out-of-Combat）。
- 是否執行過 `/reload`。
- 畫面視覺表現是否正常，有無 BugSack / BugGrabber 報錯紀錄。
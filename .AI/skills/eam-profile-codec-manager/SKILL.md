---
name: eam-profile-codec-manager
description: >-
  8 大分類字串編解碼、設定分享與 WTF 存檔遷移技能。涵蓋多類別獨立自選匯出/匯入、校驗碼分析與版本向後相容保護。
---

# EAM Profile Codec Manager (設定檔編解碼與存檔遷移)

本技能規範 EventAlertMod 設定檔（Profile）的字串分享、編解碼與遷移標準。

## 1. 8 大分類模組化匯出/匯入
- 支援細粒度自選：自身光環、目標光環、技能冷卻、物品冷卻、地面效果、框架排版、職業資源、全域偏好。
- 提供 `[全選]`、`[僅告警清單]`、`[僅排版設定]` 快速勾選與字串校驗分析。

## 2. WTF 存檔版本遷移 (Schema Migration)
- 每次載入 `EventAlertModDB` 時檢查 Schema Version。
- 針對舊版資料庫自動執行無損遷移升級，保留用戶既有自訂技能與座標。
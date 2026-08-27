---
name: eam-sharedmedia-integration
description: >-
  LibSharedMedia-3.0 (SharedMedia) 素材動態探測與全域字型熱套用技能。涵蓋 ensureLSM() 雙軌查詢、EAM_FONT_FAMILY_CHANGED 事件廣播、SavedVariables 白名單放行與自適應捲動選單。
---

# EAM SharedMedia Integration (LSM 素材動態探測與字型熱套用)

本技能規範整合 `LibSharedMedia-3.0` 素材庫的最佳實務標準。

## 1. 動態探測與延遲同步 (`ensureLSM`)
- 同時查詢 `lsm:List("sound")` 與 `lsm:HashTable("sound")` 雙軌資料源並自動去重，保證收錄所有第三方音效包與字型包。
- 註冊 `PLAYER_LOGIN` 延遲刷新，徹底解決 EAM 先於第三方 Media 插件載入時素材被截斷的問題。

## 2. 全域字型熱套用（免 `/reload` 即時生效）
- **存檔放行**：`SavedVariables.lua` 放行所有通過 LSM 註冊的字型名稱，防止重登被還原。
- **廣播聯動**：更換字型時發布 `EAM_FONT_FAMILY_CHANGED` 事件，同步即時重繪告警圖示、預覽圖示、能量條與人物屬性文字。

## 3. 長清單自適應捲動容器 (`buildScrollableDropdownMenu`)
- 當素材清單超過 10 筆時，自動限制選單高度並啟用 `UIPanelScrollFrameTemplate` 與滑鼠滾輪支援。
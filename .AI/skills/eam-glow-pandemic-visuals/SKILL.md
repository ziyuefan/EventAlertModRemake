---
name: eam-glow-pandemic-visuals
description: >-
  Proc 金色發光、DoT Pandemic 亮框與戰鬥紅框閃爍技能。涵蓋快捷列 Proc 發光同步、雙層 Glow 降級策略與全螢幕戰鬥警示 (CombatFlash)。
---

# EAM Glow & Pandemic Visuals (戰鬥視覺反饋系統)

本技能規範發光、高亮框與全螢幕警示之視覺呈現標準。

## 1. 快捷列 Proc 金色發光同步
- 監聽 `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE` 事件。
- 維護本地 `glowSpells` 清單，告警圖示 100% 同步官方技能發光效果。

## 2. DoT Pandemic 刷新亮框
- 當 DoT 剩餘時間小於基準持續時間的 30%（Pandemic 窗口）時，為圖示啟用動態亮框。

## 3. 雙層發光降級策略 (Two-tier Glow Fallback)
- Tier 1：優先調用內嵌 `LibButtonGlow-1.0`。
- Tier 2：戰鬥中初次建框或自訂顏色時，平滑降級至 EAM 自有動畫邊框，杜絕戰鬥報錯。

## 4. 戰鬥進入與低血全螢幕紅框 (`CombatFlash`)
- 監聽 `PLAYER_REGEN_DISABLED` 事件觸發邊界紅框漸變閃爍。
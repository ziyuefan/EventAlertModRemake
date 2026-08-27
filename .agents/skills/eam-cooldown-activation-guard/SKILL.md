---
name: eam-cooldown-activation-guard
description: >-
  技能冷卻精確施法過濾與法術覆蓋狀態機技能。涵蓋 UNIT_SPELLCAST_SUCCEEDED 精確玩家判定、COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED 法術覆蓋與三態設定繼承。
---

# EAM Cooldown Activation Guard (施法過濾與法術覆蓋狀態機)

本技能規範技能冷卻服務的精準觸發與狀態維護標準。

## 1. 精確施法過濾 (Exact Player Cast Gating)
- 監聽 `UNIT_SPELLCAST_SUCCEEDED` 時，必須強制驗證 `unitTarget == "player"`。
- 嚴禁在脫戰（`PLAYER_REGEN_ENABLED`）、形態刷新、非清單治療法術施放時批量開啟無關技能圖示。

## 2. 動態法術覆蓋切換 (Spell Override Updates)
- 監聽 `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` 事件。
- 當天賦或觸發效果改變法術 ID 時，自動同步原法術與覆蓋法術之冷卻狀態，徹底消除法術覆蓋導致的殘留或冷卻重置 Bug。

## 3. 三態設定繼承模型 (Tri-state Configuration)
- `cooldownRemoveAura`、`showSCDOutsideCombat`、`glowSCDWhenUsable` 等欄位支援三態：
  - `nil`：繼承全域預設設定。
  - `true` / `false`：針對該單一技能進行強制覆寫（保留明確 false）。
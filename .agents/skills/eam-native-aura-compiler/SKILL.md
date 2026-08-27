---
name: eam-native-aura-compiler
description: >-
  Retail 12.1 Native Aura 原生光環容器與規則編譯器架構技能。涵蓋 buildLayoutFingerprint 指紋計算、固定槽位與動態流動群組分離、視覺/音效分離與戰鬥遞延套用。
---

# EAM Native Aura Compiler (12.1 原生光環編譯器架構)

本技能規範 Retail 12.1 引入之 Native Aura 原生容器佈局與 `AuraRuleCompiler` 規則編譯標準。

## 1. 佈局指紋編譯 (`buildLayoutFingerprint`)
- 每次光環規則變更時計算雜湊指紋，包含：
  - `spellId`、優先級（Priority）、圖示尺寸、錨點座標。
  - `fontFamily`（字型設定，確保更換字型時立即觸發重建）。
  - 邊框樣式、倒數設定。
- 只有指紋變更時才觸發原生容器結構重建，避免無效銷毀與記憶體浪費。

## 2. 固定槽位與流動群組分離
- **Fixed Slots（固定槽位）**：指派給高優先級核心技能，位置固定不隨其他光環增減位移。
- **Flow Groups（動態流動群組）**：次要光環採用瀑布流動佈局，支援水平/垂直生長方向與平滑過渡。

## 3. 視覺與音效指紋解耦
- 視覺渲染與音效觸發（`AuraSound`）採用獨立指紋，選取或預覽音效時不強制重建視覺 Native Frame。
- 戰鬥中發生設定變更時，自動將非關鍵結構重建遞延至 `PLAYER_REGEN_ENABLED`（脫戰事件）。
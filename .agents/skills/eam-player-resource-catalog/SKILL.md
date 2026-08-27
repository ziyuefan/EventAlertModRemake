---
name: eam-player-resource-catalog
description: >-
  17 大全職業/專精資源拓撲與平滑渲染技能。涵蓋 13 職業 40 種專精動態拓撲偵測、德魯伊 5 形態切換、DK 6 格符文充能條與需求導向背景取樣器。
---

# EAM Player Resource Catalog (17 大職業資源拓撲與渲染)

本技能規範全職業資源管理架構（Catalog ➔ Capability ➔ Service ➔ PowerRenderer ➔ Panel）。

## 1. 全職業資源拓撲矩陣 (17 Resources & 40 Specs)
- 支援能量類型：法力、怒氣、能量、連擊點、聖能、靈魂裂片、星能、符文能量、狂亂、集中、惡魔之怒、真氣、精華等 17 種資源。
- 德魯伊 5 形態動態矩陣：人型/梟獸 (Mana/LunarPower) ➔ 熊形態 (Rage) ➔ 獵豹形態 (Energy + ComboPoints)，形態切換時 0ms 即時切換資源條。

## 2. 死亡騎士符文特化系統 (DK Runes)
- 3 大專精專屬動態圖示（血魄、冰霜、穢邪）。
- 6 格微型充能冷卻條：精確監聽 `RUNE_POWER_UPDATE`，提供 0%~100% 平滑漸變動畫。
- 槽位診斷命令：`/eam rune` 開啟槽位狀態監視窗。

## 3. 需求導向背景取樣器 (Probe-Gated Background Sampler)
- 針對部分專精背景資源事件缺失問題，實施需求導向排程取樣器，非必要不輪詢，嚴格守護 CPU 效能。
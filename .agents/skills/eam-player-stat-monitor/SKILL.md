---
name: eam-player-stat-monitor
description: >-
  18 大人物屬性與動能滑翔移速即時監控技能。涵蓋主副屬性、4 大速度維度 (含 C_PlayerInfo.GetGlidingInfo)、吸收盾量、警戒值紅框與原生進度條視覺化。
---

# EAM Player Stat Monitor (18 大人物屬性與滑翔監控)

本技能規範人物屬性與防護盾監控模組架構。

## 1. 18 種核心屬性監控
- 主屬性：力量、敏捷、智力、耐力、護甲。
- 副屬性：致命 (Critical)、加速 (Haste)、精通 (Mastery)、臨機應變 (Versatility)、閃避、汲取、速度評級。
- 防護盾量：總吸收盾量 (Total Absorb)、治療吸收量 (Heal Absorb)。
- 4 大速度維度：地面跑速 (`GetUnitSpeed`)、水下泳速、傳統懸浮飛速 (310%~420%)、**飛龍動能滑翔速度 (`C_PlayerInfo.GetGlidingInfo` 830%~1400%)**。

## 2. 原生進度條色彩分流與視覺化
- 屬性色彩規範：吸收盾天藍、治療吸收紫紅、移速青綠、副屬性金黃、主屬性橙紅、護甲鋼藍。
- 支援警戒值上下限設定、超限紅框閃爍與 0~2 位小數/簡寫 (k/M) 切換。
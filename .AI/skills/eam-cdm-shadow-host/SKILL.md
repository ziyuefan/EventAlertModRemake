---
name: eam-cdm-shadow-host
description: >-
  CooldownViewer (CDM) 影子載體寄生技術技能。涵蓋官方冷卻管理器池 Hook 攔截、寄生渲染讓位、文字裁切防護與 FrameLevel 提權排版。
---

# EAM CDM Shadow Host (冷卻管理器影子載體寄生技術)

本技能指導如何安全利用暴雪官方 `CooldownViewer` (CDM) 作為影子宿主，避開戰鬥中 Secret 與受污染限制。

## 1. 官方池 Hook 攔截
- 在 `ShadowHostService.lua` 中監聽官方冷卻管理器框架的生成與回收。
- 建立安全代理層，不直接修改官方 Frame 的內部結構，僅作為視覺對齊之影子載體（Host Frame）。

## 2. 寄生渲染排版與文字裁切修復
- **ClipsChildren 裁切避讓**：官方容器常具備 `ClipsChildren` 屬性，導致技能名稱文字被邊界截斷。
- **排版調整**：寄生模式下自動將技能名稱（`nameText`）重定位至圖示底部高亮區。
- **FrameLevel 提權**：主動設定 `FrameLevel = hostIcon:GetFrameLevel() + 10`，確保告警圖示與文字永遠浮於官方容器之上。
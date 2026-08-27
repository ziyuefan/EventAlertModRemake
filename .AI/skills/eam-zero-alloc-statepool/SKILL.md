---
name: eam-zero-alloc-statepool
description: >-
  EventAlertMod 零分配狀態物件池與 LuaJIT 效能極限優化技能。涵蓋多型 StatePool、消除 OnUpdate 閉包垃圾回收、Scheduler 延遲調度與 AlertManager 批量更新節流。
---

# EAM Zero-Alloc StatePool (零分配物件池與 LuaJIT 效能優化)

本技能規範 EventAlertMod 達到戰鬥中 0-GC（零記憶體分配）與 LuaJIT Trace 零中斷（Zero Trace Abort）的極限效能標準。

## 1. 多型零分配狀態池 (Polymorphic StatePool)
- 所有資料服務（`AuraService`、`GroundEffectService`、`TotemService` 等）統一實作物件池：
  ```lua
  local StatePool = {}
  function StatePool.acquire() ... end
  function StatePool.release(state) ... end
  ```
- 在 `acquire` 時安全綁定 `state.releaseFunc = Pool.release`，並由 `AlertManager` 在圖示隱藏或重置時統一調用回收，杜絕狀態物件記憶體洩漏。

## 2. 徹底消除 OnUpdate 閉包與 JIT Abort
- ❌ **禁止在 OnUpdate 中使用閉包 `pcall`**：閉包與 `pcall` 會直接導致 LuaJIT Trace 編譯器中斷（Trace Abort），大幅增加 CPU 耗損。
- ❌ **禁止每幀 `pairs` 輪詢倒數**：改用 `timerTokenPool` 零分配令牌池取得令牌，並透過 `Scheduler.after` 註冊單次定時喚醒。
- 到期時由 `onDurationTimerExpired(token)` 依據令牌啟用狀態精確隱藏，實現 100% 可被 LuaJIT 編譯的極速路徑。

## 3. AlertManager 批量更新節流 (Batching & Throttling)
- 透過 `BeginBatch()` 與 `EndBatch()` 機制，在同一幀或事件循環中將五大資料服務（光環、冷卻、物品、地面、圖騰）的變更合併為單次渲染傳遞，消除介面重繪抖動。
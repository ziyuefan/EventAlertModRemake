<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 效能指南

## 熱路徑候選者

目前主線熱路徑候選人：

- `Main/EventAlert_Core.lua`
  - 事件調度和處理程序
  - `COMBAT_LOG_EVENT_UNFILTERED`
  - `UNIT_AURA`
  - `BAG_UPDATE_COOLDOWN`
  - `SPELL_UPDATE_COOLDOWN`
  - `SPELL_UPDATE_CHARGES`
  - `SPELL_UPDATE_USABLE`
  - `ACTIONBAR_UPDATE_COOLDOWN`
  - 使用代碼/coroutine 進行查找掃描
- `Main/EventAlert_Aura_Self.lua`
  - `Buffs_Update`
  - `OnUpdate`
  - `PositionFrames`
- `Main/EventAlert_Aura_Target.lua`
  - `TarBuffs_Update`
  - `OnTarUpdate`
  - `TarPositionFrames`
- `Main/EventAlert_Cooldown.lua`
  - `OnSCDUpdate`
  - `ScdBuffs_Update`
  - `UpdateScdFrame`
  - `ScdPositionFrames`
- `Main/EventAlert_ItemSpellCache.lua`
  - 物品範圍掃描建構器
- `Main/EventAlert_SpecialPower.lua`
- 資源/power 更新
  - 符文 OnUpdate 腳本
- `Main/EventAlert_CreateFrames.lua`
  - 框架創建和滾動列表生成
- `Main/EventAlert_EAFun.lua`
  - 版面配置、工具提示、計時器文字、偵錯標籤助手

## 目前 OnUpdate / C_Timer 用法

觀察到的主線使用情況：

- `EventAlert_Core.lua`
  - 遞迴 `C_Timer.After(tempInterval, RecurringFrameUpdate)`
  - FPS-調整了位置 /special 幀更新的節奏
  - `C_Timer.NewTicker(1 / GetFramerate(), function() ...)` 用來查找
- `EventAlert_Aura_Self.lua`
  - `G:OnUpdate(spellId)` 用於光環計時器刷新
  - 在先前指派 `tempFunc = function() G.OnUpdate(spellId) end`
    `C_Timer.After(delay, tempFunc)`
- `EventAlert_Aura_Target.lua`
  - `C_Timer.After(delay, G.OnTarUpdate, G, spellId)`
- `EventAlert_Cooldown.lua`
- `C_Timer.After(nextInterval, G.OnSCDUpdate, G, sid)`
- `EventAlert_ItemSpellCache.lua`
  - `C_Timer.NewTicker(0.01, function() ...)`
  - `C_Timer.After(1, ProcessBatch)` 用於批次掃描繼續
- `EventAlert_SpecialPower.lua`
  - 每個符文 `SetScript("OnUpdate", function(self, elapsedTime) ...)`
  - `C_Timer.After` 用於生命綻放刷新
- `EventAlert_Util.lua`
  - 幀清理中呼叫 `Lib_ZYF:StopOnUpdate(eaf)`

重寫規則：

- 用一個中央調度程式取代它們。
- 調度程序回呼記錄應可重複使用，並由alert/service ID 鍵入。
- 重複刷新路徑中沒有每個圖示計時器和閉包分配。

## 分配政策

使用 `table.create` 用於：

- 配置警報陣列
- 活動狀態數組
- 骯髒的隊列
- 圖示池記錄
- 排程程式作業記錄
- 除錯環形緩衝區
- 預設設定檔模板
避免在熱路徑中：

- 每個光環的瞬態表
- `table.insert` 當直接數字索引分配就足夠了
- `pairs`/`ipairs` 其中確定性數字循環可用
- 臨時字串構建
- 匿名回呼函數

## 表.freeze 策略

僅凍結：

- 常數
- 列舉
- 狀態名稱
- 模式描述
- 不可變的預設欄位設定文件
- 靜態模組合約

切勿凍結：

- SavedVariables
- 運行時光環/cooldown狀態
- 圖示渲染狀態
- UI框架記錄
- 調度程序佇列
- 池對象
- 除錯快照

## UI 寫入策略

渲染器必須快取最後渲染的值並跳過無操作寫入：

- `SetText`
- `SetTexture`
- `SetAlpha`
- `SetCooldown`
- `SetPoint`
- `SetSize`
- `Show` / `Hide`

佈局應該是批量的：

1. 收集髒佈局鍵。
2. 隱藏父框架。
3. 僅套用變更的位置/sizes。
4. 顯示一次父框架。

## 戰鬥/低-FPS 節流

在以下情況下，繁重的工作必須被阻止、延遲或降級：

- `InCombatLockdown()` 為 true；
- FPS 低於配置的閾值；
- 工作需要大掃描；
- 達到受保護的/secret 邊界。

允許的降級行為：

- 僅顯示安全性圖示/name；
- 將計時器標記為 `unknown`、`protected` 或 `displayOnly`；
- 跳過可選項目快取進程；
- 安排非戰鬥刷新。

## 目前配置風險

首次透過審核發現了這些可能的來源：

- 重複光環掃描循環超過 1..40 個有用且有害的指數；
- `AuraUtil.ForEachAura` 回呼使用；
- 工具提示呼叫後掛鉤和工具提示解析路徑；
- aura 更新中的 `C_Timer.After(function() ...)` 閉包分配；
- 冷卻更新後備中的動態影格建立；
- 具有計時器回呼的物品範圍掃描；
- 除錯標籤和查找輸出中的字串格式；
- 全域意外變數導致生命週期和 GC 行為不明確。

## 2026-07-26：Native Aura 效能預算

- 戰鬥 Aura 更新由 Blizzard AuraContainer/AuraButton 處理；EAM 熱路徑配置、AuraState、OnUpdate 與 Scheduler token 皆為 0。
- 規則只在登入、專精/設定變更與脫戰 pending commit 時編譯。
- fingerprint 未變更時不建立新容器、不重註冊 sound。
- 相容規則合併為 AuraGroup；player/target 各保留第一條 Slot PoC。
- 舊容器停用後只保留計數，不保存每次重建的 Lua 配對表。

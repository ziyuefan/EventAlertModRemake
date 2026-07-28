<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 已知限制

## 即時驗證差距

這次審計是靜態的。沒有 WoW Retail 12.x 用戶端可用，因此 API 名稱，
傳回形狀、secret/protected 行為和 XML 運行時行為仍然需要
遊戲內驗證。

## 離線流程驗證限制

`Tests/FlowValidationHarness.lua` 可驗證 Lua 模組契約、事件 round-trip、Scheduler 與報告閉環，但無法重現 WoW C++ Secret／Forbidden／taint／protected frame 語意。

- Mock 通過不得標記為 PTR 或 Retail 實機通過。
- 測試面板不執行施法、物品使用、改目標或 secure action。
- 真實 AuraContainer、DurationObject、戰鬥鎖定與污染仍由 `RQA` 實機簽收。
- 報告不自動上傳；需由使用者複製 JSON 或提供 WTF SavedVariables。
## 秘密/受保護的值

正式服可能會返回秘密、受保護、僅供顯示或不可用的光環數據
和冷卻狀態。重寫必須安全降級：

- 僅圖示顯示；
- 僅已知安全名稱/icon/stacks；
- 定時模式 `protected`、`displayOnly` 或 `unknown`；
- 沒有捏造持續時間/expiration/cooldown事實；
- 僅當請求 debug/export 時偵錯邊界警告。

## 戰鬥限制

某些 UI 或資料更新可能不安全或在戰鬥中不可用。繁重的工作，
快取建置、佈局重建和類似遷移的操作必須延遲
或節流。
## 不支援的分支

重寫不支援：

- 經典
- 熊貓人之謎經典服
- 浩劫與重生經典服賽
- 巫妖王之怒經典服
- TBC 經典
- 時代
- 特定於區域的經典相容性分支

舊目錄可能保留在儲存庫中，僅供參考。

## 目前來源風險

首次透過審核發現以下風險：

- 主線中混合正式服和遺留相容性分支；
- 遺留的 TOC 仍然存在於根部；
- 目前 TOC 和許多運行時模組所需的 `Lib_ZYF` ；
- 大型法術/item資料表；
- `EventAlert_ItemSpellCache.lua` 中的物品範圍掃描；
- 遞迴計時器調度和每個資源 OnUpdate 腳本；
- 廣泛的全域變數使用和意外全域變數；
- 可能與受保護資料衝突的工具提示和光環 API 假設；
- `Main/` 下有重複的 /archived 文件，其名稱為亂碼，且
  `DevDocument/ChatGPT/`;
- `EventAlert_ImportExport.lua` 具有原型全域變數並被註解掉
  載入順序。

## 使用者介面限制

目前 XML 建立大型靜態選項面板和許多全域框架名稱。的
重寫應該更喜歡較小的選項表面和池化運行時圖標，但是
刪除之前必須先映射現有的 UI 行為。

## 需要正式服驗證的領域

- 準確的 `C_UnitAuras` 安全存取行為；
- 精確的 `C_Spell.GetSpellCooldown` 結構化回傳行為；
- 精確的 `C_Item.GetItemCooldown` 直接 itemID 行為；
- `C_Secrets` 可用性和退貨行為；
- 冷卻充能行為；
- 目標光環更新有效負載；
- 對所有計劃中的 UI 操作的戰鬥限制；
- 工具提示 API（如果保留工具提示顯示）；
- zhTW/enUS/koKR/zhCN 中的局部渲染；
- SavedVariables 遷移真實的舊用戶資料。

## 2026-07-26：12.1 尚待實機確認

- 68914 模板實際載入時機、AuraButton Forbidden Aspect 與條件式 access constraints。
- candidate Spell ID filter 對各種 Secret Aura/單位極性的真實接受範圍。
- `initializeFrame` 名稱、倒數、層數、Tooltip 的實際顯示與容器裁切。
- Added/ApplicationsIncreased/Removed 的實際播放次數、音效檔欄位與 output channel。
- 戰鬥 pending、脫戰重建、Reload UI migration、taint/blocked action 與 CPU/GC。
- `UNSUPPORTED` 只代表安全停用 Native Aura，不代表功能等同 Legacy。

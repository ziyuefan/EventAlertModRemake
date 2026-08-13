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

## 2026-08-09：互動、Tooltip、邊框與版本資訊限制

- TargetFrame／BuffFrame 的 12.1 AuraButton hover 探測只保存匿名「目前有 Aura Tooltip」心跳，不讀 TooltipData、AuraData、frame 名稱或 Aura ID；Ctrl+Alt 只開啟手動 Aura ID Popup。因此能安全支援目標框架，但不會自動解析受限 Aura ID。
- Action Bar Macro 只接受安全的 resolved action subtype／ID、`GetMacroSpell` 或 `GetMacroItem`；條件式、序列或客戶端無法安全解析的巨集仍須手動輸入。
- 一般 EAM spell／item Tooltip 僅在非戰鬥中顯示；`classPower` 與 `totem` 沒有可靠的 Spell／Item tooltip source，不做猜測。Native Aura 使用 Blizzard AuraButton Tooltip。
- 七色分類邊框是 EAM 自有靜態 Texture，與 PTR8 的 `AddDispelTypeTexture`、Pandemic Region、Proc Glow 不同；不能用顏色推論可驅散狀態。classPower／totem 保留既有視覺。
- About 的 API baseline 是本次開發固定證據 `12.1.0 PTR 8 (69189)`；實際客戶端版本另由 `GetBuildInfo` 顯示。未來 PTR build 更新時必須同步 Constants／API intelligence，不得把 baseline 當即時查詢。
- WoW EditBox 沒有通用 `Copy()` 契約；面板只能全選文字並請玩家按 Ctrl+C。這是手動資料交接，不是剪貼簿自動化。
- 法力等主要資源可能受 UnitPower Secret 規則限制；生命之花、Hot、DoT 等是 Aura，必須走 AuraButton／Aura 監控，不屬 UnitPower。

## 2026-08-09：SVG 與全覆蓋邊框限制

- 目前只建立能力探針與封裝管線，尚未把正式 Pandemic、Dispel 或 Glow 視覺換成 SVG。
- PTR 69189 固定契約是非對稱的：VectorGraphics 提供 SetSVG／ClearSVG／HasSVG／GetSVGFileID；Texture 只提供 SetSVG／ClearSVG。兩者的 Secret argument policy 也不同，不得共用 introspection 或安全假設。
- Alpha 3 實機報告已確認兩格 SetSVG accepted 且圖樣目視通過；VectorGraphics 的 addon-local `GetSVGFileID()` 回傳 0 不表示渲染失敗。Texture 缺少 HasSVG／GetSVGFileID 是預期能力，不是缺陷。
- Texture 的 `clearReload=pass` 只能證明 ClearSVG 與重新 SetSVG 呼叫成功，再由最終圖樣目視確認 reload；因沒有 HasSVG，清除瞬間的像素狀態仍不能由 Lua 自動讀回。
- 12.0.7 可安全回報 unsupported；不得為了相容而呼叫不存在的方法。
- 3px 實色邊框已具幾何離線斷言，但不同 UI scale、圖示尺寸與 PTR Native AuraButton 的最終目視仍待玩家截圖簽收。
- SVG ZIP 存在只證明素材被封裝；不證明戰鬥邊界、縮放品質或正式 Pandemic／Dispel 整合已通過。

## 2026-08-12：動態語系切換邊界

- 新程式載入後，已註冊的 EAM 自有固定文字與複合狀態會在選擇語系時立即刷新；不需為套用語系呼叫 `/reload`。剛更新磁碟上的 Lua 檔時仍需一次 `/reload` 載入新程式，之後的 `/reload` 只驗證保存或落盤。
- `Auto Detect` 強制以英文顯示，無法由翻譯檔改名；它代表客戶端 `GetLocale()`，因此 zhTW 客戶端選它後維持繁體中文是正確結果，不是切換失敗。
- Blizzard UI、其他插件、客戶端回傳的法術／物品／專精名稱，以及已經輸出的聊天／錯誤歷史不會被 EAM 改寫；後續 EAM 訊息才使用目前 `EAM.L`。
- 真人簽收的 37 案 `CASE_PROCEDURES` 是版本化繁中證據文本，不屬 UI locale；案例名稱、狀態與面板 chrome 會切換，但程序全文維持繁中，避免翻譯差異改變簽收條件。
- `ruRU` 已與 enUS key 對齊；zhCN／koKR 尚有歷史 Live case 字串以 enUS fallback 補底，這不表示俄文以外的翻譯完整度已達 100%。
- 語系 catalog 只處理 `L.*`。任何新建 EAM 長生命週期 widget 若仍直接快取靜態字串而未 bind／refresh，視為實作缺陷；池化 widget 則必須在回收時 unbind。

## 2026-08-13：AuraSound 限制

- PTR 12.1 `UnitAuraSoundInfo` 只有 unit+SpellID 與音檔資料，沒有 caster、`fromPlayer` 或 `auraFilter`；同 SpellID 的其他來源可能 over-fire，必須 PTR 人工觀察。
- `RemoveAuraSound` 可取消後續觸發，但生成文件沒有保證會停止已開始播放的聲音；EAM 不把 registration ID 傳給 `StopSound`。
- UI 目前以一個共用素材套用到勾選的三種 trigger，沒有逐 trigger channel 編輯；重新儲存會統一為目前素材。
- 正規化採 `soundFileID` 優先；兩音源同時提供時的遊戲原生優先權、無效音源回傳與所有合法 channel 仍需 PTR 驗證。
- 12.0.7 的 private-aura applied API 不能等價替代一般 Aura 三 trigger；本輪採 capability 降級。
- 離線 mock 只證明 payload、生命週期、回滾與零容器重建，不證明實際播放、音訊裝置、驅散或戰鬥行為。

## 2026-08-13 Alpha 4 限制與未完成項目

- 八個模組開關是 runtime gate，不是卸載機制；為避免重複註冊，服務事件仍可能存在，但停用後不得讀取其熱路徑 API，且要清理既有狀態。
- v4 舊根層清單可能混有多個職業，缺乏可靠 provenance；遷移只歸屬當時合法 active class，其他資料保留 backup／unassignedLegacy，不會自動拆分。
- 正式程式尚未提供 JSON／Base64 profile 分享與套用 codec；目前不可把 debug JSON 貼回遊戲，也不可使用 LegacyReference 的 loadstring。
- 模組面板目前管理八個功能模組；debug 面板、小地圖顯示與全域 showFrame 不是本輪新增的獨立 module toggle。
- Alpha 4 的模組與 profile 回歸仍是離線證據；PTR、XPTR、Retail 需由玩家實機確認戰鬥延後、/reload 持久化與跨職業隔離。

## 2026-08-14 Alpha 5 限制與待簽收項目

- EAMAP1 codec 已進入正式 runtime，但只支援目前定義的五種 alert module；ClassPower／Totem 沒有可匯出的 alert list，不得偽裝成 profile payload。
- Adler-32 只偵測剪貼內容損壞，不是防竄改或信任來源機制；匯入內容仍視為不可信資料。
- Profile apply 在戰鬥中拒絕，以避免 Native AuraContainer、Ground duration 或 ClassPower 結構變更；玩家需脫戰後重新預覽／套用。
- 字型只套用 EAM 自有 FontString；Blizzard AuraButton、Tooltip、Action Bar 與其他插件文字不會被改變，部分字型在不同客戶端的實際字形仍需玩家目視確認。
- 動態語系刷新已涵蓋 EAM 自有長生命週期按鈕、下拉、條件與 spec menu；客戶端／Blizzard／歷史聊天文字不會被回寫，Live case 程序本身固定繁中。
- 本輪離線 gate 為 Lua 56/56、Flow 66/66、Contracts 360/360；PTR／XPTR／Retail 尚未由 Codex 操作或簽收 EAMAP1、字型與語系視覺結果。

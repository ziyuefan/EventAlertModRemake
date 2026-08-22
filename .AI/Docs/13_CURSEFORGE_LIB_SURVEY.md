<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# CurseForge Lib 類別插件調查

本文件調查 CurseForge 上可查到、名稱或用途接近 `Lib*` 的 WoW 庫類插件，評估其是否適合 EventAlertMod 正式服重寫。

## 調查原則

- 未新增硬依賴。
- 不破壞 EAM 的輕量定位。
- 不引入 Classic/MOP 相內容層作為正式架構核心。
- 無需引入高精度掃描、檢查、查詢或大量配置的庫。
- 若採用，只能走 opt-in 或 soft dependency。
- 所有庫使用前仍需做Retail 12.x實機載入驗證。

##結論摘要

目前最值得保留觀察值的候選只有兩類：

- `LibSharedMedia-3.0`：可選，用於字體、音效、材質選單。適合選項階段再評估。
- `LibCustomGlow`：任選，用於圖示發光效果。專案已保留舊版參考庫，可優先搶先概念，不建議硬依賴。
其餘庫目前不建議納入 EAM 核心，原因多半是過重、用途不符、更新、依賴太鍊長，或與 EAM 自建的 EventRouter/Scheduler/SavedVariables 方向重疊。

## 候選評估

|圖書館 | CurseForge 狀態 | 可能用途| 評估| 建議|
|---|---|---|---|---|
|王牌3 | Retail 12.0.x，大量下載，完整AddOn框架|生命週期、SV、事件、配置、GUI | 功能完整但過重，與 EAM 自建 Core/EventRouter/Scheduler/SV 重疊 |
| CallbackHandler-1.0 |正式服，有 AceEvent 背景用途 |回呼註冊表| EAM 已有EventRouter，需求不足 |
| LibInit |正式服，包裝 Ace3 大部分元件 | 簡化 Ace3 設定 | 會硬帶 Ace3/LibStub/CallbackHandler/AceDB/AceGUI 等，過重 | 不採用 |
| LibSharedMedia-3.0 | Retail 12.0.5，處理字體/sound/texture | options 裡選字體、音效、材質 | 與 EAM UI 設定有關，可進行可選集成字體、音效、材質 |
| LibCustomGlow |正式服12.0.x，定制發光|圖標突出顯示/glow | 舊 EAM 已使用過類似依賴；新架構可自動簡化發光 | 參考概念，暫時不硬依賴 |
| LibDataBroker-1.1 | 老牌LDB，主要提供經紀商展示|小地圖/data 經紀人 | 需配展示生態系統，EAM 不需要經紀商 | 不採用 |
| LibDBIcon-1.0 |正式服12.0.x，需LibDataBroker |小地圖圖標| 可做小地圖圖標，但會引入 LDB/LibStub 依賴鏈 | 不採用，優先自建簡單按鈕 |
| LibQTip-1.0 | Retail 10.0.7，多列提示 |選項/debug 工具提示 | 用途偏除錯 UI，版本較舊，EAM 不需要複雜的工具提示 | 不採用 |
| LibRangeCheck-3.0 | Retail 12.0.x，範圍檢查 |目標範圍選通| EAM核心是aura/cooldown警報，不需要範圍引擎 | 不採用 |
| LibDeflate | Retail 8.x，壓縮/解壓縮 | import/export 壓縮 | 可用於大型匯入匯出，但目前不做WA式分享系統| 暫不採用 |
|庫：序列化 | 已標記廢棄，舊版 |連載| 且稅收用途不符| 不採用 |
| LibDualSpec-1.0 | Retail 12.0.x，AceDB 規格簡介 |特定規格設定檔 | 依賴AceDB思路，EAM SV自建架構 | 不採用 |
| LibGroupInSpecT | Retail 11.x，群組檢查/spec快取|群組警報/spec 條件 | 會引入inspect/communication/cache，偏重且非核心| 不採用 |
| LibWindow-1.1 | Retail 9.x，窗框幫手 |活動窗| 功能小但過舊，EAM UI 可自行處理 | 不採用 |

## 可採用候選選項

### LibSharedMedia-3.0

用途：

- 提供跨 AddOn 的媒體註冊表。
- 適合日後的`UI/Options.lua`字型、音效、材質選單。

優點：

- CurseForge 顯示支援 Retail 12.0.5。
- 與 EAM 的聲音/font/icon 紋理選項有自然交集。

限制：

- 不應成為 RequiredDeps。
- 不應讓渲染器熱路徑依賴它。
- 只應在選項開啟時查詢媒體清單。

建議整合方式：
```text
OptionalDeps: LibSharedMedia-3.0
if LibStub and LibStub("LibSharedMedia-3.0", true) then
    -- options-only integration
end
```
目前決策：保留候選，不立即加入。

### LibCustomGlow

用途：

- 圖示發光/像素發光/按鈕發光。

優點：

- 舊 EAM 已有 `LibCustomGlow-1.0` 參考資料。
- 可快速還原「冷卻可用時會高亮」的視覺語意。

限制：

- 目前專案已移除正式加載的外部依賴。
- 如果直接加入，會回到舊 `LibStub` 依賴鏈。
- 新的渲染器可有效提高材質或暴雪的臨時效果替代。

建議整合方式：
- 第一階段：僅參考 `ReferenceLibs/LegacyLibs/LibCustomGlow-1.0` 的概念。
- 第二階段：若自製成本過高，再討論軟依賴。

目前決策：參考概念，不硬依賴。

## 明確不採用原因

### Ace3 / LibInit

Ace3 是完整的框架，包含生命週期、SavedVariables、事件、配置、GUI、定時器等能力。這些能力與 EAM 正式服重寫的自建核心重疊，而且會增加載入成本。 LibInit 又是 Ace3 封裝層，會硬帶更多模組。
EAM 目前需要的是簡單、可控制、低GC的事件驅動架構，不需要框架化。

### LibDataBroker / LibDBIcon

小地圖圖示可以自建。引入 LDB/DBIcon 即可簡單功能變為 LibStub + LDB + DBIcon 依賴鏈，不符合目前「無硬依賴」方向。

### LibQTip

EAM 不需要多列工具提示。除錯導出要輸出緊湊的文本，不需要複雜的工具提示框架。

### LibRangeCheck / LibGroupInSpecT
這些庫有額外的查詢、檢查或快取行為。 EAM核心不是raid助手，也不需要群組spec/range引擎。

### LibDeflate / 序列化類

只有在將來建立大型 import/export 共享格式時才可能需要。 EAM 明確不做 WeakAura 之類的複雜共享系統，因此暫時不採用。

## 來源

- [Ace3 - CurseForge](https://www.curseforge.com/wow/addons/ace3)
- [CallbackHandler-1.0 - CurseForge](https://www.curseforge.com/wow/addons/callbackhandler/source)
- [LibInit - CurseForge](https://www.curseforge.com/wow/addons/libinit)
- [LibSharedMedia-3.0 - CurseForge](https://www.curseforge.com/wow/addons/libsharedmedia-3-0)
- [LibCustomGlow - CurseForge](https://www.curseforge.com/wow/addons/libcustomglow/files/2625790)
- [LibDataBroker-1.1 - CurseForge](https://www.curseforge.com/wow/addons/libdatabroker-1-1)
- [LibDBIcon-1.0 - CurseForge](https://www.curseforge.com/wow/addons/libdbicon-1-0)
- [LibQTip-1.0 - CurseForge](https://www.curseforge.com/wow/addons/libqtip-1-0)
- [LibRangeCheck-3.0 - CurseForge](https://www.curseforge.com/wow/addons/librangecheck-3-0)
- [LibDeflate - CurseForge](https://www.curseforge.com/wow/addons/libdeflate)
- [LibDualSpec-1.0 - CurseForge](https://www.curseforge.com/wow/addons/libdualspec-1-0/files/all)
- [LibGroupInSpecT - CurseForge](https://www.curseforge.com/wow/addons/libgroupinspect)
- [LibWindow-1.1 - CurseForge](https://www.curseforge.com/wow/addons/libwindow-1-1/files)

## 後續建議

短期：

- 不增加任何函式庫依賴。
- 渲染器發光先自製最小效果。
- 選項字體/音效清單先用內建媒體。

中：

- 若使用者強烈需要跨AddOn媒體選單，再評估`LibSharedMedia-3.0`軟依賴。
- 若自製的glow成本過高，再評估`LibCustomGlow`軟依賴。

長期：

- 所有第三方函式庫必須投入 `ReferenceLibs` 先審查。
-經過正式服實機驗證後，才可正式加入TOC。
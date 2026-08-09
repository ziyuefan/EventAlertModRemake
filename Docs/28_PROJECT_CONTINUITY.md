<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod 專案續接與試錯索引

## 1. 用途與權責

本文件是上下文壓縮、代理交接或長時間中斷後的第一個人類可讀續接點。機器可讀的當前狀態以 `Data/ProjectContinuity.json` 為準；詳細試錯時間線保留在 `Docs/15_DEVELOPMENT_ISSUE_LOG.md`；真人實機案例定義保留在 `Data/LiveValidationMatrix.json`。三者不得互相複製整段內容。

目前快照版本：`2026-08-09.2`。

## 2. 重新進入專案的閱讀順序

1. `AGENTS.md`
2. 本文件
3. `Data/ProjectContinuity.json`
4. `Docs/02_RETAIL_API_BOUNDARIES.md`
5. `Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`
6. `Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md`
7. `Docs/26_FLOW_VALIDATION_FRAMEWORK.md`
8. `Docs/29_LIVE_TEST_STEP_GUIDE.md`
9. 與目前 work item 對應的 `Docs/15_DEVELOPMENT_ISSUE_LOG.md` 穩定 issue ID

不得以 `docs_html` 取代 Markdown 原檔，也不得以舊對話摘要覆寫本快照。

## 3. 當前目標

完成 Alpha 3 候選：修正 Target Aura hover+Ctrl+Alt、Macro spell/item ID、報告手動複製，加入 About、監控 Tooltip 與七色分類邊框；PTR／XPTR／Retail 依 34 案指南由玩家簽收。發布定位仍為 alpha。

## 4. 已確認事實

- 12.1 PTR 使用者實測曾出現兩套高度同步的 Aura 倒數。
- 兩套數字由同一個 Native Aura DurationObject 同時驅動，因此可作人工 A/B 顯示同步觀察，但不是兩個獨立資料來源。
- 正常模式只顯示 EAM 可定位的一套倒數；雙倒數只能由測試面板明確啟用，完成後關閉。
- Native AuraButton 與其子元件只能在 `initializeFrame` 內完成尺寸、錨點、字型、倒數與邊框設定；初始化後不得直接重排。
- `AddDispelTypeTexture` 是官方驅散／靜態 Aura 邊框能力，不能取代 Pandemic、Proc 或任意條件 Glow。
- 次要職業資源可走安全普通數字；可能為 Secret 的主要資源百分比只能直接送入 StatusBar 或 12.1 radial widget，不得讀回、比較或序列化。
- 本輪靜態與離線 gate 為 Lua 50 檔、Flow 54/54、Validation Contracts 247/247；真人矩陣為 34 案，PTR、XPTR 與 Retail 均仍待玩家簽收。
- 若從磁碟匯入遊戲內報告，玩家必須先完成 `/reload` 或正常登出，否則可能仍是舊快照。
- 2026-08-08 唯讀環境斷言：Retail `12.0.7.68974`、PTR `12.1.0.69189`、XPTR `12.0.7.68887`；三個 AddOns SymbolicLink 均指向 `D:\EventAlertMod`。

## 5. 目前決策

| 主題 | 決策 | 不可誤解事項 |
| --- | --- | --- |
| Aura 倒數 | 正常單倒數；測試面板可切換雙倒數診斷 | 同步不等於兩個獨立事實來源 |
| Native 樣式 | 變更後脫戰重建容器 | 不得初始化後直接 `SetPoint`／`SetFont` |
| 冷卻時間 | 正確使用無參數 Duration factory，再設定時間與 binding | 不得使用猜測的建構參數或不存在的 `Unbind` |
| 地面效果 | 法術說明、Tooltip SpellDescription、手動 fallback | 不解析剩餘時間文字，不在熱路徑抓 Tooltip |
| UnitPower | 次要資源安全數字；主要資源原生 sink | 報告只輸出分類，不輸出 current／max／percent 原值 |
| 實機操作 | 玩家自行施法、用物品、切專精、進出戰鬥與 `/reload` | EAM 與 Codex 不自動操作遊戲 |

## 6. 驗證狀態

- 離線：Lua 50 檔語法、Flow `all` 54/54、Validation Contracts 247/247 通過。
- PTR 12.1：Alpha 2 Native gate 已離線修正，但玩家尚未 `/reload` 簽收 Aura 顯示；不得沿用 Alpha 1 或修正前觀察。
- XPTR 12.0.7：尚未簽收。
- Retail 12.0.7：尚未簽收。
- 真人報告：使用 `matrixVersion=2026-08-08.1` 的 34 案工作台。
- UnitPower 報告：另回傳 `EAM_UNIT_POWER_CAPABILITY_REPORT`；目前兩個 sink 呼叫均 accepted，但 primary 視覺 pending、selected blocked，仍非 PTR pass。

## 7. 下一輪玩家實測

1. 確認客戶端與專案連結前置斷言通過。
2. 非戰鬥中開啟 `/eam test`，確認「雙倒數診斷」預設關閉。
3. 執行 `all` 並複製 Flow JSON；它是能力證據，不是 34 案真人簽收。
4. 開啟「真人實機回報」，選正確的 `_ptr_`、`_xptr_` 或 `_retail_`，逐案操作。
5. Aura 雙倒數案例只在 PTR 12.1 暫時啟用，觀察開始、中段、最後三秒後立即關閉。
6. 啟動 UnitPower 能力探針，由玩家產生／消耗資源並標記兩個原生顯示結果。
7. 建立 reload checkpoint，由玩家自行 `/reload`，回來後完成報告。
8. 若從磁碟匯入，完成報告後再由玩家保存一次；直接複製面板 JSON 則不需要額外保存。

## 8. 禁止重複的試法

- 不再使用 `C_DurationUtil.CreateDuration(duration)` 或把 duration/fontString 當作 binding factory 參數。
- 不再對已完成 `initializeFrame` 的 AuraButton／FontString／Cooldown 做結構 mutation。
- 不讀回 Secret FontString、StatusBar 或 radial percent 作自動比較。
- 不把官方 dispel border 宣稱為任意條件 Glow。
- 不以離線 mock、合成 Live pass 或舊版磁碟報告冒充 PTR／XPTR 實機通過。
- 不用 Windows PowerShell 5.1 執行含 `#requires -Version 7.0` 的契約腳本；使用 `pwsh`。
- 不假設跨檔補丁失敗時一定全數回滾；失敗後逐檔核對，重要文件採單檔小補丁。
- 不再以 `IsPublicTestClient AND IsTestBuild` 判定 PTR；raw flags 必須個別保留，通道 aggregate 採 OR，Native 方法仍逐項 capability gate。

## 9. 漂移檢查

`Tools/Test-ValidationContracts.ps1` 必須確認：

- 本文件與 JSON 的 `snapshotVersion` 一致。
- `AGENTS.md` 與 `Docs/00_AI_CONTEXT.md` 均指向本續接路由。
- fact、inference、work item 與 issue ID 唯一且引用可解析。
- Live matrix、Live runtime、Schema 與 fixture 均為同一版本及 34 案。
- PTR／XPTR／Retail 若標為 pass，必須有對應真人證據索引；離線證據不得升格。
- Continuity JSON 不得包含私人絕對路徑、帳號、角色或遊戲資料快照。


## 2026-08-08 PTR8／UnitPower 交接快照

- Live matrix 已升版 `2026-08-08.1`，目前共 34 案；三個客戶端仍為待玩家簽收。
- PTR8 Pandemic Region、Dispel options、停用容器清除與 UnitPower combatDeferred 已加入程式、strict mock、JSON schema 與人工矩陣。
- 官方 PTR 12.1.0.69189 文件未證實 `StatusBar:SetUnit`、`SetPowerTextFontString`、`SetOnUpdateMode`；目前只把 `UnitPowerPercent` 單向送入 `SetValue`／`SetRadialProgressBarPercent` 視為已知可行方向。
- 本輪不執行 WoW、不卡玩家輸入、不觸碰 `_ptr_`／`_xptr_`／`_retail_` AddOns symbolic link；實機需玩家自行 `/reload` 後回傳報告。
## 2026-08-09 Alpha 2 Native Aura／UnitPower 交接快照

- 玩家觀察：Alpha 1 可顯示 Aura，Alpha 2 完全不顯示。
- P0 根因：`AuraCapabilityService` 將 public-test 與 test-build 寫成 AND；PTR 69189 的 test-build 實為 false，導致 `nativeRuntimeAllowed=false` 並在容器建立前停止。
- 程式修正：三個測試通道 raw flags 安全讀取後採 OR；mock 固定重現 public-test=true、test-build=false、beta=false；mock-only Flow 在 client 改為 skip；Native capability 失敗訊息補足完整欄位。
- 當時離線證據：Lua `47/47`、Flow `54/54`，artifact `TestResults/EAM_FlowValidation_all_20260809_185047.json`；Validation Contracts `217/217`。其後本輪最新 gate 已更新為 50／54／247。
- PTR 下一步：玩家先 `/reload`，執行 `/eam doctor` 與 `/eam test aura121`，確認 capability pass、player／target Aura 顯示，再續跑 34 案真人矩陣。
- UnitPower：primary Secret 與 selected safe-number 均已被兩種 sink 接受，但人工視覺分別為 pending／blocked；需玩家產生、消耗、歸零資源並明確按 pass／fail。

## 2026-08-09 Alpha 3 候選功能交接快照

- TargetFrame／BuffFrame AuraButton 的 hover+Ctrl+Alt 不再依賴右鍵；非 GameTooltip 路徑只保存匿名 0.75 秒心跳，Aura ID 與 player／target 路由仍由玩家在 EAM Popup 確認。
- Action Bar Macro 優先解析安全 resolved action subtype／ID，再降級 `GetMacroSpell`／`GetMacroItem`；無安全結果才手動輸入。
- Flow／Live／Prompt 面板不再呼叫不存在的 `EditBox:Copy()`，改為全選並請玩家按 Ctrl+C。
- EAM 主視窗新增 About；顯示 TOC 版本、實際 client、固定 API baseline `12.1.0 PTR 8 (69189)`、作者 `ziyuefan死鬥` 與 repo／Pages。
- 一般監控圖示新增脫戰 Tooltip；七色分類邊框為自身 BUFF 青、自己 DEBUFF 紅、目標 BUFF 藍、目標 DEBUFF 橘、技能黃、地面紫、物品綠，classPower／totem 保留原樣。
- `Docs/29_LIVE_TEST_STEP_GUIDE.md` 提供 34 案逐步條件與通過證據；WTF 報告只在玩家完成 `/reload` 或正常登出後視為最新。
- 最新離線證據：Lua `50/50`、Flow `54/54`、Validation Contracts `247/247`。PTR、XPTR、Retail 仍沒有完整真人簽收。

## 2026-08-09 SVG／3px 邊框交接快照

- ActionButton border 放大方案已由實機截圖否決；最終改為 WHITE8X8、BORDER layer、四邊外擴 3px，Legacy／Native 共用 AlertBorderStyles.anchorTexture。
- 新增 SVG VectorGraphics／Texture A/B 探針、schema、fixture、strict mock、五語系、SavedVariables、匯入器與 Release 白名單。
- 專案層級 JSON 已升到 snapshot 2026-08-09.2，WORK-20260809-002 與 issue EAM-20260809-ALPHA3-SVG-BORDER 可互相追溯。
- 最新離線 gate 為 Lua 50/50、Flow 54/54、Validation Contracts 247/247。PTR 12.1 的圖樣與邊框目視仍 pending；XPTR／Retail 12.0.7 可回報 unsupported。

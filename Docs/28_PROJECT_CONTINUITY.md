<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod 專案續接與試錯索引

## 1. 用途與權責

本文件是上下文壓縮、代理交接或長時間中斷後的第一個人類可讀續接點。機器可讀的當前狀態以 `Data/ProjectContinuity.json` 為準；詳細試錯時間線保留在 `Docs/15_DEVELOPMENT_ISSUE_LOG.md`；真人實機案例定義保留在 `Data/LiveValidationMatrix.json`。三者不得互相複製整段內容。

目前快照版本：`2026-08-08.1`。

## 2. 重新進入專案的閱讀順序

1. `AGENTS.md`
2. 本文件
3. `Data/ProjectContinuity.json`
4. `Docs/02_RETAIL_API_BOUNDARIES.md`
5. `Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`
6. `Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md`
7. `Docs/26_FLOW_VALIDATION_FRAMEWORK.md`
8. 與目前 work item 對應的 `Docs/15_DEVELOPMENT_ISSUE_LOG.md` 穩定 issue ID

不得以 `docs_html` 取代 Markdown 原檔，也不得以舊對話摘要覆寫本快照。

## 3. 當前目標

修正並簽收 Retail 12.1 PTR 回報的 Aura 雙倒數、法術／物品冷卻、地面效果時間、swipe 透明度與 target Aura 生命週期；同時確認 UnitPower 在 12.1 與 12.0.7 的安全可用範圍。發布定位仍為 alpha。

## 4. 已確認事實

- 12.1 PTR 使用者實測曾出現兩套高度同步的 Aura 倒數。
- 兩套數字由同一個 Native Aura DurationObject 同時驅動，因此可作人工 A/B 顯示同步觀察，但不是兩個獨立資料來源。
- 正常模式只顯示 EAM 可定位的一套倒數；雙倒數只能由測試面板明確啟用，完成後關閉。
- Native AuraButton 與其子元件只能在 `initializeFrame` 內完成尺寸、錨點、字型、倒數與邊框設定；初始化後不得直接重排。
- `AddDispelTypeTexture` 是官方驅散／靜態 Aura 邊框能力，不能取代 Pandemic、Proc 或任意條件 Glow。
- 次要職業資源可走安全普通數字；可能為 Secret 的主要資源百分比只能直接送入 StatusBar 或 12.1 radial widget，不得讀回、比較或序列化。
- 本輪靜態與離線 gate 為 Lua 47 檔、Flow 54/54、Validation Contracts 208/208；真人矩陣為 34 案，PTR、XPTR 與 Retail 均仍待玩家簽收。
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

- 離線：Lua 47 檔語法、Flow `all` 54/54、Validation Contracts 208/208 通過。
- PTR 12.1：本輪修正後尚未簽收；不得沿用修正前的觀察當完成證據。
- XPTR 12.0.7：尚未簽收。
- Retail 12.0.7：尚未簽收。
- 真人報告：使用 `matrixVersion=2026-08-08.1` 的 34 案工作台。
- UnitPower 報告：另回傳 `EAM_UNIT_POWER_CAPABILITY_REPORT`；只允許分類與人工 pass／fail／blocked。

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

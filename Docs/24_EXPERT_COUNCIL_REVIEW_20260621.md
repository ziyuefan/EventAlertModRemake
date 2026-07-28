<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod 專家會審檢討報告（2026-06-21）

## 1. 報告範圍

本次針對 EventAlertMod Retail rewrite 的專家治理、Retail 12.1 Aura API、Secret／Taint、熱路徑、物件池與文件事實一致性進行唯讀審查。未修改 Lua 功能碼，亦未在 WoW Retail 或 PTR 客戶端實機載入。

會審席次：

- API／Aura 安全席：檢查 12.1 AuraContainer／AuraButton 與 UnitAura 退場風險。
- Taint／效能席：檢查戰鬥中框架、Secret 算術、Scheduler 與 StatePool 生命週期。
- 架構／治理席：檢查專家名冊、RACI、Facts-of-Truth 與文件污染。
- 主代理：交叉驗證來源、執行靜態檢查並做最終定級。

## 2. 證據基準

- Blizzard 公告：[Addons and Auras in Curse of Ula'tek](https://us.forums.blizzard.com/en/wow/t/addons-and-auras-in-curse-of-ula%E2%80%99tek/2317456)
- Warcraft Wiki：[Patch 12.1.0/API changes](https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes)，本次查證修訂時間為 2026-06-20 05:57 UTC。
- 本機活動載入：`EventAlertMod.toc`、`Core/`、`Services/`、`Managers/`、`UI/`、`Debug/`。
- 靜態驗證：`Tools/CheckLuaSyntax.ps1` 與 P0 關鍵字掃描。

證據狀態：官方／Wiki 文件已查證、Lua 靜態通過；Retail／PTR 實機未執行。

## 3. 新增專家決策

| 縮寫 | 新增角色 | 新增原因 | 唯一問責領域 |
| --- | --- | --- | --- |
| `AURA121` | `EAM_Aura_121_Migration_Expert` | 既有 SEC／ARCH／UI 無人持續負責 12.1 Aura 契約與舊行為退場條件 | Retail 12.1 Aura 遷移 |
| `RQA` | `EAM_Retail_Client_QA_Expert` | Mock／靜態檢查不能取代真實客戶端、taint 與效能證據 | Retail／PTR 實機驗證 |
| `DOC` | `EAM_Documentation_Governance_Expert` | 名冊失同步、`EAMCODE placeholder` 污染與「已實作／已實機」混用缺少問責者 | 文件與 Facts-of-Truth |

原名冊實際為 20 位，`Docs/17` 卻宣稱 16 位。新增後 canonical 名冊為 23 位，完整定義以 `Docs/21_RACI_EXPERTS_MATRIX.md` 為準。

## 4. P0 阻斷項目

### P0-1：Retail 12.1 Aura 核心尚無合法遷移路徑

- `Services/AuraService.lua:575` 起仍使用逐筆 AuraData 掃描。
- `Services/AuraService.lua:661` 與 `:701` 仍依賴 `UNIT_AURA`／`GetAuraDataByAuraInstanceID`。
- 活動程式沒有 AuraContainer／AuraButton 實作。
- 12.1 受限情境下 UnitAura 類 API 可能回傳完整 secrets 或 `nil`，secret vector 無法計數或迭代。

影響：核心玩家／目標光環提醒在戰鬥、首領戰、M+ 或 PvP 可能整批失效。這是 12.1 readiness blocker，不是已完成實機重現。

### P0-2：Secret 時間可能重新進入 Lua 比較與排程

- `Services/AuraService.lua:392-400` 取得 DurationObject 後，仍保存已判定可能 Secret 的 `duration`／`expirationTime`。
- `UI/Renderer.lua:679-698` 對 `timer.duration` 做 `> 0` 並傳入 `Scheduler.after`。

影響：可能觸發 Secret 比較、算術或排程錯誤。Protected／display-only 路徑必須清除所有舊數字，而不是只改 timer mode。

### P0-3：ItemCooldown 對標量使用錯誤 Secret 檢查

- `Services/ItemCooldownService.lua:147-152` 對時間標量使用 `Util.isSecretTable`，而不是 `isSecretValue`／`canAccessValue`。
- 後續仍對值進行型別、大小比較與加法。

影響：受限 item cooldown 可能在 Lua 邊界發生錯誤。

### P0-4：Protected cooldown 可能殘留舊安全數字

- `Services/CooldownService.lua:283` 附近的 protected 分支只更新 mode／DurationObject，未清除舊 `startTime`、`duration`、`expirationTime`。

影響：Renderer 可能把前一次狀態誤當目前事實或繼續排程。

## 5. P1 主要問題

| 項目 | 證據 | 風險 |
| --- | --- | --- |
| Tooltip 巢狀 Secret table | `AuraService.lua:275-294` 對 `data.lines` 直接取長度與索引 | inaccessible table 可立即 Lua error |
| 靜態時長冒充剩餘時間 | `AuraService.lua:359-385`、`:415-435` 以 `now + scrapedDur` 並標 `factsSafe=true` | 顯示錯誤事實，違反推導值分離 |
| 完整掃描漏 HARMFUL | `AuraService.lua:596` 未帶 filter，宣告的 player／target filters 未使用 | target debuff 或 player debuff 完整刷新漏抓 |
| aura instance 移除作用域錯誤 | `AuraService.lua:249-258` 的 `count` 在區塊外回傳 | 最後一個 instance 移除時可能不即時隱藏 |
| 戰鬥中可能 CreateFrame | `IconPool.lua:93-104` 池耗盡後直接 `createIcon()` | 超過 16 圖示時可能污染或被阻擋 |
| 戰鬥中結構性 UI 操作 | `Renderer.lua:247-305` 仍執行 Hide／Show／SetPoint／SetSize | 與檔頭及專案 combat-lockdown 規則不一致 |
| Scheduler 任務堆積 | `Renderer.lua:678-698` 每次 render 新增到期任務；`Scheduler.lua:73-94` 每幀線性掃描 | 頻繁事件與長冷卻可能形成 O(N)/frame |
| StatePool 覆寫／懸空引用 | `AlertManager.lua:150`、`Renderer.lua:328-337` | hidden→shown 覆寫可能漏回收；deferred state 可能已被 wipe／重用 |
| 非單一 OnUpdate | Scheduler、Renderer、Options 各有 OnUpdate | 與硬性「單一調度 OnUpdate」不一致 |
| Shadow Host 休眠攻擊面 | 初始化與 GetHostIcon 已停用，但 hook／SetParent 程式仍在活動載入檔 | 不得直接重新啟用，需安全與實機雙重 gate |

## 6. P2 與文件治理問題

- `Docs/17` 的 16 位宣稱與 `Docs/21` 的 20 位實際名冊不一致。
- 舊 RACI 表被翻譯成「拱門／符合／澳幣／一個／右／我」，無法機械驗證唯一 `A`。
- `Docs/20` 把停用且未實機驗證的 Shadow Host 描述為 100% 穩定、0-Taint／0-GC。
- `Docs/23` 的部分 LuaJIT、`pairs` 與分支預測論述缺少 WoW runtime 量測。
- `AGENTS.md` 後半重複且含大量 `EAMCODE placeholder` 殘留；本輪未修改，應另案清理。
- `Docs/02`、`Docs/10`、`Docs/19` 尚未納入 12.1 Aura Container／Forbidden Aspect 的新事實模型。

## 7. 已執行驗證

- `git status --short --branch`：確認既有未追蹤檔案，未清理或覆蓋。
- `Tools/CheckLuaSyntax.ps1`：`Lua syntax OK: 32 files`。
- P0 靜態掃描：舊 API、`OnUpdate`、`CreateFrame`、`SetParent`、`hooksecurefunc`、Secret 與 `table.freeze` 路徑。
- Warcraft Wiki MediaWiki API：確認 12.1.0 TOC 為 `120100`，並取得 2026-06-20 修訂內容。

## 8. 未執行驗證

- WoW Retail 12.0.7／12.1.0 PTR 或正式服載入。
- M+、PvP、團本、載具、專精切換與 Edit Mode。
- taint log、Lua error、CPU、記憶體、GC 與幀時間量測。
- AuraContainer／AuraButton 最終 API 與 Forbidden Aspects 行為。
- 超過 16 個圖示、同 ID 單幀 hidden→shown、deferred state 回收與 Scheduler 壓力測試。

## 9. 發布與修復 Gate

1. P0 未關閉前，不得宣稱 Retail 12.1 相容或發布 12.1 套件。
2. Shadow Host 只能在隔離研究分支測試；未經 `SEC` 與 `RQA` 雙重證據不得啟用。
3. Aura 12.1 遷移由 `AURA121` 問責，`SEC/ARCH/UI/RQA` 必須參與諮詢或驗證。
4. 實機通過只能由 `RQA` 依 build、步驟、log 與結果簽收。
5. 文件結論由 `DOC` 檢查來源、日期與驗證狀態，禁止以「已完成」代替「已實作／待實機」。

## 10. 本輪實施摘要

1. 變更檔案：只修改專家治理與報告 Markdown／HTML，不修改 Lua。
2. 主要架構變更：無程式架構變更；新增三個治理角色與三個 RACI 領域。
3. 保留舊 EAM 行為：全部保留，本輪未改功能。
4. 移除舊行為：無；僅禁止把休眠 Shadow Host 視為可直接啟用。
5. Lua／WoW API 假設：12.0.7 活動 TOC；12.1 API 仍在變動，需能力偵測與實機確認。
6. `table.create`／`table.freeze`：本輪未修改使用方式。
7. Secret／Protected 策略：不繞過、不偽造時間、不讓舊數值流入 protected 狀態。
8. 已執行靜態驗證：32 個 Lua 檔案語法通過與 P0 掃描。
9. 未執行驗證：Retail／PTR 實機、taint、效能與壓力測試。
10. WoW 正式服實機需要：必須，由 `RQA` 建立可追溯證據。
11. 已知風險：見本報告 P0／P1／P2。
12. 下一個任務：先建立 12.1 Aura migration spike 與能力矩陣，再修 Secret 時間與戰鬥中框架 P0。

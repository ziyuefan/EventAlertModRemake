---
name: eam-flow-validation
description: 為 EventAlertMod 產生、執行與擴充離線及 Retail/PTR 實機流程驗證，並把 JSON／Markdown 報告回灌開發環境。當任務修改事件路由、排程、SavedVariables、Secret 邊界、UI 操作、除錯匯出、封裝 gate，或需要證明功能流程而不只是語法通過時使用。
---

# EAM Flow Validation

## 前置檢查

1. 讀取 `AGENTS.md`。
2. 讀取 `Docs/26_FLOW_VALIDATION_FRAMEWORK.md`、`Docs/27_LOCAL_WOW_ENVIRONMENT.md`、`Docs/06_TEST_PLAN_RETAIL.md` 與 `Docs/21_RACI_EXPERTS_MATRIX.md`。
3. 檢查 Git 狀態；不得還原或混入既有無關變更。
4. 修改任何既有檔案前依規範備份到 `backup/`。

## 驗證層級

依序執行，不得互相取代：

1. **靜態限制**：Secret／taint、熱路徑、TOC 與架構邊界掃描。
2. **Lua 語法**：執行 `Tools/CheckLuaSyntax.ps1`。
3. **離線流程**：執行 `Tools/Run-FlowValidation.ps1 -Suite all`。
4. **本機環境斷言**：執行 `Tools/Test-LocalWoWEnvironment.ps1`，確認 ProductVersion 與 AddOns Reparse Point。
5. **實機流程**：在 Retail／PTR 使用 `/eam test` 或 Options 的流程測試按鈕。
6. **回灌報告**：使用 `Tools/Import-EAMFlowReport.ps1 -Path <WTF 或 JSON>`。

Mock、PTR、Retail 結果必須分開標示。

## 案例擴充

新增或修改跨模組流程時：

1. 在 `Debug/FlowTestRunner.lua` 以 `registerCase` 新增穩定案例 ID。
2. 指定 `quick`、`core`、`boundary` suite；`all` 自動涵蓋全部案例。
3. 優先測試正式模組公開 API，不直接改服務內部表。
4. 非同步流程使用既有 `Scheduler` 與 `context.complete`。
5. 案例完成後不得留下 EventRouter handler、Scheduler task 或配置變更。
6. 同一案例必須能由 `Tests/FlowValidationHarness.lua` 與遊戲內 runner 執行。
7. 更新 `Docs/26_FLOW_VALIDATION_FRAMEWORK.md` 與測試計畫。

## 報告要求

報告至少包含：

- `schema`、`type`、suite、source 與 Interface。
- passed／failed／skipped／pending 計數。
- 案例 ID、狀態、耗時與安全訊息。
- Mock 或 Retail/PTR 證據層級。
- 未執行驗證與剩餘風險。

產生的 `TestResults/` 不提交 Git，除非使用者明確要求保存特定證據。

## 禁止事項

- 不把 Mock 通過寫成 Retail／PTR 實機通過。
- 不在戰鬥中首次建立測試 UI。
- 不注入假 Aura／Cooldown facts 到正式服務或 Renderer。
- 不序列化 Secret、Protected、完整 SavedVariables 或無界限日誌。
- 不建立第二個 OnUpdate、每案例 ticker 或重複 `C_Timer.After` 鏈。
- 不用測試按鈕呼叫 protected action、施法、物品使用或目標操作。
- 不因測試失敗而自動修改、刪除或重設玩家設定。
- 不刪除、搬移、覆蓋、解壓縮或重建 `_retail_`、`_ptr_`、`_xptr_` 的 `Interface\AddOns\EventAlertMod`；這些路徑是指向 `D:\EventAlertMod` 的 SymbolicLink。

## 固定命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\CheckLuaSyntax.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Run-FlowValidation.ps1 -Suite all
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Test-LocalWoWEnvironment.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Import-EAMFlowReport.ps1 -Path <report-or-savedvariables>
```

## 回傳格式

1. 修改檔案與新增案例。
2. 靜態、語法、離線、PTR、Retail 各層結果。
3. JSON／Markdown 報告路徑。
4. 未執行項目與證據限制。
5. 已知風險與下一個測試任務。
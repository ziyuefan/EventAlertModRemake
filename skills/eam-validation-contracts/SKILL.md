---
name: eam-validation-contracts
description: "驗證 EventAlertMod 的 JSON Schema、Lua 靜態契約、Flow 報告與 PTR／XPTR 真人回灌門檻。修改 Data、Schemas、TextPlacement、LiveTest、FlowTest、匯入器、測試矩陣或發布 gate 時使用。"
---

# EAM 驗證契約

## 前置檢查

1. 在 `D:\EventAlertMod` 執行，先讀取 `AGENTS.md`、`Docs/06_TEST_PLAN_RETAIL.md`、`Docs/26_FLOW_VALIDATION_FRAMEWORK.md` 與 `Docs/27_LOCAL_WOW_ENVIRONMENT.md`。
2. 修改前依專案規則備份既有檔案；新檔不存在時不得建立空白假備份。
3. 實機前執行 `Tools/Test-LocalWoWEnvironment.ps1`，確認版本與三個 AddOns Reparse Point。失敗即停止。
4. 使用 PowerShell 7 `pwsh`；`Tools/Test-ValidationContracts.ps1` 需要 `Test-Json -SchemaFile`。

## 禁止事項

- 不操作角色、Tooltip、按鈕、施法、物品、巨集或目標，不合成遊戲輸入，不呼叫 `ReloadUI`。
- 不修改、覆蓋、清理或重建 `_retail_`、`_ptr_`、`_xptr_` 的 AddOns SymbolicLink。
- 不列舉 WTF Account／角色目錄；只讀使用者明確提供的檔案。
- 不把帳號、角色、伺服器、絕對 WTF 路徑或 Secret／Protected 值寫入報告。
- 不把 `offline-mock`、fixture、schema 1 Flow 或 capability probe 宣稱為真人實機 pass。
- 不刪除失敗報告來掩蓋試誤。

## 固定驗證順序

1. 執行 Lua 語法：

```powershell
pwsh -NoProfile -File .\Tools\CheckLuaSyntax.ps1
```

2. 執行完整離線流程：

```powershell
pwsh -NoProfile -File .\Tools\Run-FlowValidation.ps1 -Suite all
```

3. 驗證 JSON Schema、21 點／29 案 Lua 同步、continuity drift、TOC 與 PowerShell AST：

```powershell
pwsh -NoProfile -File .\Tools\Test-ValidationContracts.ps1
```

4. 匯入最新 schema 2 Flow。接受 `offline-mock` 只代表契約可回灌，不代表實機：

```powershell
pwsh -NoProfile -File .\Tools\Import-EAMFlowReport.ps1 `
    -Path '<flow-report.json>' `
    -ReportType Flow
```

5. 執行負向門檻：offline Live fixture 與 schema 1 Flow 都必須非零退出；schema 1 只能保存為 `legacy-unverified`。

## 真人 PTR／XPTR 回灌

1. 由玩家在非戰鬥中輸入 `/eam test live`，選擇實際 `_ptr_`、`_xptr_` 或 `_retail_`。
2. 玩家手動完成 `Data/LiveValidationMatrix.json` 的 29 案；EAM 只記錄結果與最多 500 字元備註。
3. `/reload` 案先建立 checkpoint，再由玩家自行輸入 `/reload`。
4. 完成後直接複製面板 JSON時，該內容已是記憶體內最新報告。
5. 若從 WTF 匯入，玩家完成報告後必須再 `/reload` 或正常登出，讓最新 SavedVariables 寫回磁碟。
6. 只讀使用者明確提供的 `EventAlertMod.lua`：

```powershell
pwsh -NoProfile -File .\Tools\Import-EAMFlowReport.ps1 `
    -Path '<使用者明確提供的 EventAlertMod.lua>' `
    -ReportType Live
```

7. 只有 `executionSource=client`、來源與宣告 client 相符、29 案全 pass、跨 `/reload`、無 boundary warning，才可送 RQA 終審。

## 文件與回傳

- 修改 Markdown 後，先備份 `docs_html/*.html`、根目錄 `readme.html` 與 `Tools/.translation_cache.json`，再以 `EAM_DOCS_OFFLINE=1` 執行 `Tools/batch_convert_docs.py`。
- 回傳 Lua、Flow、契約、匯入正負門檻各自結果。
- 分開列出 `_ptr_`、`_xptr_`、`_retail_`；未收到真人報告一律標示待簽收。
- 列出仍需玩家完成的 Tooltip、Popup、戰鬥、`/reload`、taint、blocked action 與 Forbidden 案例。

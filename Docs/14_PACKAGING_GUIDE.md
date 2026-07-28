<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# CurseForge 預算指南

本文件定義 EventAlertMod Retail rewrite 的發佈資源規則。

## 快速指令

日後用戶只需輸入：
```text
打包
```
就執行：
```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Build-CurseForgePackage.ps1
```
或使用者只需輸入：
```text
打包開發版
```
就執行：
```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Build-CurseForgePackage.ps1 -DevMode
```
除非使用者附加指定參數，否則不需要再次詢問。

## 版本命名

TOC 版本名稱必須符合：
```text
EventAlertMod_資料片簡稱_打包年月日
```
目前資料片名稱固定為：
```text
MN
```
範例：
```text
## Version: EventAlertMod_MN_20260504
```
## 備用檔名

zip檔名必須符合：
```text
EventAlertMod_資料片簡稱_打包年月日_打包時分秒.zip
```
範例：
```text
EventAlertMod_MN_20260504_205216.zip
```
## 預設預設內容

- `EventAlertMod.toc`
- `README.md`
- `readme.html`
- `changelog.txt`
- `Core/`
- `Services/`
- `UI/`
- `Debug/`
- `Data/`
- `Locale/`
- `媒體/`

##預設排除內容

- `LegacyReference/`
- `ReferenceLibs/`
- `Tools/`
- `備份/`
- `.github/`
- `.vscode/`
- `文檔/`
- `Dist/_stage/`

## 可選參數

包含文件與 AGENTS：
```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Build-CurseForgePackage.ps1 -IncludeDocs
```
跳過Lua語法檢查：
```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Build-CurseForgePackage.ps1 -SkipLuaCheck
```
僅診斷工具環境問題時跳過離線流程驗證：
```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Build-CurseForgePackage.ps1 -SkipFlowValidation
```
開發版本壓縮（將整個專案資料壓縮，不過濾，排除 .git/ 和 Dist/）：
```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Build-CurseForgePackage.ps1 -DevMode
```
## 驗證要求

預算流程必須完成：

- TOC 路徑驗證。
- Lua 語法檢查，除非明確使用 `-SkipLuaCheck`。
- 離線 `all` 流程驗證，除非診斷性使用 `-SkipFlowValidation`；正式發布不得常態跳過。
- `TestResults/`、`Tests/` 與 `Tools/` 不進正式包。
- zip排除檢查，確認沒有legacy/reference/tools/backup/dev資料夾。

## HTML 說明檔案轉換

- 對於 `Docs/` 下或根目錄 `AGENTS.md` 涉及表格、圖像、心智圖與流程圖的 Markdown 文件，應執行 HTML 轉換工具，在 `docs_html/` 底下產生一個同名的 `.html` 文件（如 __10）。
- `Tools/batch_convert_docs.py` 會把 `docs_html/README.md.html` 同步成根目錄 `readme.html`；正式包的 HTML 說明以該 Pages 產物為唯一來源。發布前不得只改 `README.md` 而跳過轉換。
- 開發與AI自動協作時，一律以`.md`檔案為絕對的Facts-of-Truth參考。 `.html`版本供人類好讀與預覽使用，不可被自動化AI開發的配置或方案碼邏輯之引用。

## 注意事項

- 資源成功不代表WoW正式服實機驗證完成。
- 若 TOC `## Version` 與當日日期不一致，壓縮工具會停止。
- 發布前仍需依`Docs/06_TEST_PLAN_RETAIL.md`做正式服實機測試。

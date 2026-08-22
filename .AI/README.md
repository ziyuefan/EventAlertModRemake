# EventAlertMod AI 治理目錄

此目錄保存文件、測試、工具、資料契約、爬蟲候選資料、歷史參考與 AI Skills。
魔獸插件執行期的唯一來源是專案根目錄下的 `EventAlertMod/`，封裝與部署不得從 `.AI/` 取用執行期檔案。

## 固定路徑

- 專案根目錄：`D:\Project_EventAlertMod`
- 插件來源：`D:\Project_EventAlertMod\EventAlertMod`
- 部署工具：`D:\Project_EventAlertMod\Deploy`
- 打包輸出：`D:\Project_EventAlertMod\Dist`
- AI 治理：`D:\Project_EventAlertMod\.AI`

根目錄的 `AGENTS.md` 只是 Codex 探索入口；完整規範以 `.AI/AGENTS.md` 為準。


## 紀錄分流

- 公開的 `changelog.txt` 只記 WoW 插件與遊戲相關變更。
- AI 治理、代理進度、測試／文件流程記錄於 `Docs/15_DEVELOPMENT_ISSUE_LOG.md` 與 `Docs/28_PROJECT_CONTINUITY.md`。
- `Dist/` 不進 Git；Release 的插件包與專案 `src` 包由 `Deploy/` 工具建立。

<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod Agent 入口

本檔只負責讓 Git 專案根目錄可被 Codex 與其他 Agent 正確探索。開始任何工作前，必須完整閱讀並遵循 [`.AI/AGENTS.md`](.AI/AGENTS.md) 與 [`.AI/PROJECT_MEMORY.md`](.AI/PROJECT_MEMORY.md)；完整治理規範只維護在 `.AI`，禁止在此建立第二份規則全文。

## 固定邊界

- Git 專案根目錄：`D:\Project_EventAlertMod`
- WoW 插件唯一來源：`D:\Project_EventAlertMod\EventAlertMod`
- AI 治理與測試：`D:\Project_EventAlertMod\.AI`
- 部署工具：`D:\Project_EventAlertMod\Deploy`
- 本機發布產物：`D:\Project_EventAlertMod\Dist`
- 舊目錄 `D:\EventAlertMod` 已停用：不得讀取、寫入、比較、同步或當成 fallback。
- WoW 各客戶端的 `Interface\AddOns\EventAlertMod` 若為 SymbolicLink／Junction／Reparse Point，任何部署或清理都必須立即停止；不得追蹤、覆蓋、刪除或重建連結。

## 紀錄與發布

- 根目錄與插件內的 `README.md`、`changelog.txt` 必須維持同步。
- `changelog.txt` 只記 WoW 插件功能、玩家可感知修正、遊戲版本／API 相容性及實際套件內容變更。
- AI 治理、代理分工、文件同步、測試進度與 CI／GitHub 操作改記 `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md` 或 `.AI/Docs/28_PROJECT_CONTINUITY.md`。
- `Dist/` 不提交 Git；Release 使用 `Deploy/Build-Package.ps1` 建立插件包；GitHub Release 由 GitHub 自動打包 Source 原始碼（zip / tar.gz），本機與 Release 上傳皆無須且不再打包專案 `src` 包。
- 機密憑證與 Token（如 CurseForge API Token）100% 永久留存本機，透過 Windows DPAPI（`API_TOKEN.SEC`）雙重加密隔離；絕對禁止提交至 Git、禁止納入任何發布 ZIP 壓縮包。

## 快速命令

- 使用者只輸入「資源」：執行 `pwsh -NoProfile -File .\Deploy\Build-Package.ps1`。
- 「壓縮開發版」：執行 `pwsh -NoProfile -File .\Deploy\Build-Package.ps1 -PackageLabel DEV`。
- 「發布至 CurseForge」：執行 `pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1`。
- 「模擬發布」：執行 `pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1 -DryRun`。

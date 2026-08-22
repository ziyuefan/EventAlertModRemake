# EventAlertMod 本機部署與封裝工具

本目錄只保存本機打包與部署工具。插件執行期的唯一來源為：

```text
D:\Project_EventAlertMod\EventAlertMod
```

## WoW 根目錄偵測

`Deploy-EventAlertMod.ps1` 會依序嘗試：

1. Windows Registry 的 HKLM/HKCU、Registry64/Registry32 view，包含 Blizzard 與 Battle.net 常見安裝鍵。
2. `Deploy\DeploymentTargets.json` 的 `wowRoot` 後備值。
3. 使用者在互動選單輸入的自訂完整路徑。

互動模式會先顯示偵測來源與完整根路徑。按 Enter 接受；輸入 `C` 可改用其他主目錄。自訂路徑會正規化並重新執行版本、執行檔、AddOns 與 Reparse Point 前檢。

## 部署選單與命令

互動選單：

```powershell
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1
```

選單會顯示：

- `Retail（正式服）`
- `PTR（即時偵測的 ProductVersion）`
- `XPTR（即時偵測的 ProductVersion）`
- `All`
- `Status`
- `B`：建立插件 ZIP
- `S`：建立整個專案原始碼 ZIP

選取 PTR 或 XPTR 後，工具會詢問是否同時包含 Retail。只有明確輸入 `Y` 才會加入 Retail；非互動命令不會自動加入：

```powershell
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1 -Action PTR -WowRoot 'D:\World of Warcraft' -DryRun
```

實際部署前，確認畫面會列出本次全部通道、版本目錄、完整 `ProductVersion` 與 `Interface\AddOns\EventAlertMod` 目標；互動模式還要求輸入 `DEPLOY`。未輸入確認不會寫入遊戲目錄。

部署目標固定為所選客戶端的：

```text
Interface\AddOns\EventAlertMod
```

## Fail-closed 安全契約

- 來源只允許 `D:\Project_EventAlertMod\EventAlertMod`，且必須是實體資料夾。
- 來源與所有候選目標會在任何寫入前全數前檢；任一 Reparse Point、SymbolicLink、Junction、錯誤路徑、缺少執行檔或缺少 AddOns 都會整批停止，零寫入。
- 目標或其父層只要存在 Reparse Point，就拒絕跟隨、解除、覆蓋或替換。
- 來源必須包含 `EventAlertMod.toc`、`Managers\AlertManager.lua`、`Managers\AuraRuleCompiler.lua`、`README.md`、`changelog.txt`。
- 專案根目錄與插件內的 `README.md`、`changelog.txt` 必須存在且 SHA-256 完全一致。
- 實體目標部署前會以 `Move-Item` 搬入 `.AI\backup\deploy\` 保存，再以 staging 交換。部署後清單驗證失敗時，新目標會保留於 `EventAlertMod_failed`，舊目標以 `Move-Item` 還原。
- 執行中的 `Wow.exe` 或 `WowT.exe` 會阻擋實際部署；工具不會替使用者關閉遊戲。
- `-DryRun` 只做來源與全部候選前檢，不建立、搬移或覆蓋遊戲檔案。

目前三個本機目標若仍是指向停用舊路徑的 SymbolicLink，部署會被正確阻擋；不應由此工具刪除或重建連結。

## 插件封裝

```powershell
pwsh -NoProfile -File .\Deploy\Build-Package.ps1
pwsh -NoProfile -File .\Deploy\Build-Package.ps1 -DryRun
```

封裝器只封裝整個 `EventAlertMod` 資料夾，ZIP 內固定以 `EventAlertMod/` 為頂層，不用 Core、UI、Managers 等白名單拼包。輸出到 `Dist`，並產生：

- `*.zip`
- `*.zip.sha256`
- `*.zip.inventory.json`

封裝驗證會確認 Managers、README、changelog 均在 ZIP 中，且來源清單與 ZIP inventory 完全一致。

## 專案原始碼封裝

```powershell
pwsh -NoProfile -File .\Deploy\Build-SourcePackage.ps1
pwsh -NoProfile -File .\Deploy\Build-SourcePackage.ps1 -DryRun
```

原始碼包涵蓋整個 `D:\Project_EventAlertMod`，ZIP 根目錄固定為 `Project_EventAlertMod/`，輸出到 `Dist`，並產生 SHA-256 與 archive inventory。會排除：`Dist`、`.git`、`.codex-remote-attachments`、`.AI\backup`、`.AI\.trash_*`、`.AI\TestResults`、`cache`、`pyc`、`log`、`zip` 及其他本機衍生物。此功能只建立本機檔案，不執行 Git、GitHub、CurseForge 或 Release。

## 不在本工具範圍

- 不讀取 WTF。
- 不處理 Classic/MoP。
- 不自動建立、刪除或修復 SymbolicLink。
- 不啟動、關閉或操作 WoW。
- 不執行 Git commit、push、GitHub Release 或 CurseForge 上傳。
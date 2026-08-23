<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# CurseForge 預算指南

本文件定義 EventAlertMod Retail rewrite 的發佈資源規則。

## 2026-08-21 新根封裝與部署治理（現行）

### 插件 ZIP

- 唯一來源是 `D:\Project_EventAlertMod\EventAlertMod`，不得從根目錄散落的 `Core/`、`UI/` 或 `Dist` staging 拼包。
- ZIP 內必須是 `EventAlertMod/` exact tree，保留插件資料夾內的 `EventAlertMod.toc`、`Core/`、`Data/`、`Debug/`、`Locale/`、`Managers/`、`Media/`、`Services/`、`UI/` 及插件內公開說明；不納入 `.AI`、`Deploy`、`Dist`、測試、備份或本機 deploy。
- 產物寫入 `D:\Project_EventAlertMod\Dist`；`Dist` 為 ignored 本機產物區，不提交 Git，也不直接部署成 AddOn 來源。

### 原始碼 ZIP

- 來源是整個 `D:\Project_EventAlertMod`，頂層固定為 `Project_EventAlertMod/`。
- 排除 `Dist/`、`.codex-remote-attachments/`（及其他 attachments 暫存）、`.AI/patch-temp/`，以及任意深度的 `.git/`、backup/trash、`TestResults/`、cache、pyc、log、zip 與本機衍生物。
- 保留 `.vscode/`、`.codex/`、`.AI/`，以及 `.AI/docs_html/`；任何巢狀位置的 `backup`、`TestResults`、`.trash_*` 都排除，避免匯入器產生的 `.AI/.AI/TestResults` 漏入。原始碼包不是插件發布包。

### 部署選擇與安全前檢

- `Deploy/Deploy-EventAlertMod.ps1` 先查 Windows Registry，再以 `Deploy/DeploymentTargets.json` 的 `wowRoot` 作 JSON fallback；互動模式可由使用者確認候選根目錄或輸入 `-WowRoot` 改用明確根目錄。
- Status／確認畫面必須列出 Retail、PTR、XPTR 三通道的目錄與完整 `ProductVersion`。互動選 PTR 或 XPTR 時才詢問是否同時加入 Retail；noninteractive 命令不得暗中加入 Retail。
- 來源、目標與父層只要發現 SymbolicLink、Junction 或任何 Reparse Point，即 fail-closed，禁止追蹤、刪除、解除、覆蓋或自動重建。每次執行都要重新檢查，不得沿用舊快照。
- 2026-08-21 現況：Retail/PTR `12.1.0.69382`、XPTR `12.0.7.68887`，三個 EventAlertMod 目標均為 physical，但目前只有 PTR 含 EventAlertMod.toc，Retail/XPTR 尚缺該檔；Test-LocalWoWEnvironment 為 1/3，不能宣稱三通道 ready。Deploy Status/DryRun 三通道通過只代表可安全部署前檢，尚未實際部署；先前 Retail/XPTR link blocked 的結果保留於歷史紀錄，不能取代本次 Status。

本節覆蓋本文較早的舊根命令與內容描述；舊段落保留作歷史證據。本輪文件更新後已以 EAM_DOCS_OFFLINE=1 離線重建 docs_html，未使用外部翻譯服務。

## 快速指令

使用者輸入「打包」時執行：
```powershell
pwsh -NoProfile -File .\Deploy\Build-Package.ps1
```

使用者輸入「打包原始碼」時執行：
```powershell
pwsh -NoProfile -File .\Deploy\Build-SourcePackage.ps1
```

需要部署時先檢查狀態，再由互動選單確認版本與目標：
```powershell
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1 -Action Status
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1
```

封裝命令會修改 `Dist/`；部署選單只有在使用者最終確認且所有前檢通過後才會寫入 WoW。
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
## 插件包內容契約

- 唯一來源是專案根的完整 `EventAlertMod/` 實體目錄；ZIP 頂層固定為 `EventAlertMod/`。
- 封裝整棵來源樹，不維護可能漏掉 `Managers/` 或未來模組的手工白名單。
- 建立前強制檢查 TOC、TOC 引用檔、`Managers/AlertManager.lua`、`Managers/AuraRuleCompiler.lua`、README、changelog、SVG 與 Reparse Point 邊界。
- 根目錄與插件內的 README／changelog 必須各自 SHA-256 相同。
- `.AI/`、`Deploy/`、`Dist/` 與 Git metadata 不會進插件包，因為它們不在插件來源樹內。

## WTF 存檔備份／還原

Deploy-EventAlertMod.ps1 的 W／U 選單與 Backup／Restore 命令只處理選定版本通道的 WTF EventAlertMod 相關檔案。備份保留相對於版本根目錄的 WTF/... 路徑，manifest.json 記錄通道、版本與 SHA-256；還原前會建立 rollback 備份。一般插件部署不檢查 Wow.exe／WowT.exe 執行狀態，也不會因程序仍在執行而拒絕覆蓋；Reparse Point、路徑越界與雜湊不符仍維持 fail-closed。
## 可選參數

只驗證、不建立 ZIP：
```powershell
pwsh -NoProfile -File .\Deploy\Build-Package.ps1 -DryRun
pwsh -NoProfile -File .\Deploy\Build-SourcePackage.ps1 -DryRun
```

指定輸出目錄或套件標籤：
```powershell
pwsh -NoProfile -File .\Deploy\Build-Package.ps1 -OutputDirectory <目錄> -PackageLabel <標籤>
```

`-SkipLuaCheck` 與 `-SkipFlowValidation` 只供診斷工具故障；正式發布不得使用。專案 source 包只有 `-OutputDirectory` 與 `-DryRun`。

## 驗證要求

正式插件包預設必須完成：

- TOC 與完整來源樹、必要 Managers、README/changelog 同步、敏感檔案及 Reparse Point 檢查。
- `.AI/Tools/CheckLuaSyntax.ps1`。
- `.AI/Tools/Run-FlowValidation.ps1 -Suite all`。
- `.AI/Tools/Test-ValidationContracts.ps1`。
- ZIP 解壓後 inventory、頂層目錄與 SVG 條目驗證。
- 產生 ZIP、`.sha256` 與 `.inventory.json`。

專案 source 包必須排除 `Dist/`、本機附件、`.AI/patch-temp/`，並以 leaf 規則排除任意深度的 `.git/`、`backup/`、`.trash_*/`、`TestResults/`、快取、log 與既有 ZIP；同時保留 `.vscode/`、`.codex/`、`.AI/skills/` 與 `.AI/docs_html/`。

## HTML 說明檔案轉換

`.AI/Docs/*.md` 或 `.AI/AGENTS.md` 修改後，在專案根執行：
```powershell
$env:EAM_DOCS_OFFLINE='1'
python .\.AI\Tools\batch_convert_docs.py
```

輸出位於 `.AI/docs_html/`。Markdown 原檔仍是 AI 與開發唯一 Facts-of-Truth；HTML 只供人類閱讀。離線模式不得把全文送往外部翻譯服務，也不再建立根目錄 `readme.html`。

## 注意事項

- 資源成功不代表WoW正式服實機驗證完成。
- 若 TOC `## Version` 與當日日期不一致，壓縮工具會停止。
- 發布前仍需依 `.AI/Docs/06_TEST_PLAN_RETAIL.md` 做正式服實機測試。
- 封裝 gate 通過仍只代表離線契約，不能取代 `_ptr_`／`_xptr_` 真人矩陣。

## SVG 素材封裝契約

- 正式副檔名白名單必須包含 .svg；否則本機符號連結可顯示、GitHub Release ZIP 卻會靜默缺素材。
- Alpha 6 封裝至少必須含 Media/SVG/eam-minimap.svg、Media/SVG/eam-svg-probe.svg、Core/ProfileCodec.lua 與 UI/ProfileCodecPanel.lua，並繼續排除 Tests、TestResults、Tools、backup 與本機 deploy。
- Validation Contracts 會斷言 SVG 為自包含靜態素材且無 script／href／data URI；完整來源樹封裝不可漏掉 `.svg`。
- Release ZIP 建立後仍須列出壓縮內容確認 SVG 條目存在；本機 deploy 資料夾不得提交或重複打包。

## GitHub Alpha 手動發布邊界

- `.github/workflows/release.yml` 目前只保留停用殼：`workflow_dispatch` 且 job `if: false`。不得為 Alpha 6 移除 gate，也不得觸發 BigWigs packager。
- 正式流程是在本機執行 `Deploy/Build-Package.ps1` 與 `Deploy/Build-SourcePackage.ps1`，檢查兩份 ZIP 清單與 SHA-256，再以 `gh release create <tag> <addon.zip> <source.zip> --prerelease` 上傳 GitHub Release。
- GitHub Release 不等於 CurseForge／WoWInterface 發布；`-w`、`-p` 外部目標本輪不使用。
- tag 必須指向已通過 gate 且已推送的 commit；ZIP 不提交 Git。插件包只含 `EventAlertMod/`，source 包依排除契約移除本機衍生物。

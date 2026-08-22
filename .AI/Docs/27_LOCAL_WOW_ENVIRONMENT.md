<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EAM 本機 WoW 開發環境基準

## 2026-08-21 新根現行環境快照（current-of-truth）

- WoW 根目錄：`D:\World of Warcraft`。
- Git／專案根：`D:\Project_EventAlertMod`；插件實體來源：`D:\Project_EventAlertMod\EventAlertMod`；AI 治理：`D:\Project_EventAlertMod\.AI`；部署工具：`D:\Project_EventAlertMod\Deploy`；本機產物：`D:\Project_EventAlertMod\Dist`（ignored）。
- 版本與目標（本次 Status 唯讀結果）：Retail `_retail_` `12.1.0.69382`／physical、PTR `_ptr_` `12.1.0.69382`／physical、XPTR `_xptr_` `12.0.7.68887`／physical。這是環境狀態，不代表插件功能或真人流程簽收；目前只有 PTR 含 `EventAlertMod.toc`，Retail/XPTR 尚缺該檔，故 `Test-LocalWoWEnvironment` 為 1/3，不是工具 bug，也不能宣稱三通道 ready。Deploy Status/DryRun 三通道 pass 僅代表安全部署前檢。
- 先前「Retail/XPTR link blocked、PTR physical」是歷史快照；本次三者已為 physical。日後每次部署前仍須重新查 ProductVersion、LinkType、Target、ReparsePoint 與 inventory，不能只依本段快照。
- 部署工具以 Registry 優先、`DeploymentTargets.json` fallback；可由使用者確認或指定 `-WowRoot`。Status 列出三通道版本；PTR/XPTR 的 Retail inclusion 僅在互動確認後加入，noninteractive 不暗加；Reparse Point 一律 fail-closed。

> 本節優先於下方舊日期快照；舊路徑與舊版本均保留作歷史證據，不是現行操作目標。

## 1. 2026-08-14 歷史定位與證據邊界

以下第 1～3 節記錄 2026-08-14 的舊連結基準，僅供追溯；現行操作一律以前方 2026-08-21 current-of-truth 為準。

- WoW 根目錄：`D:\World of Warcraft`
- 當時 EAM 實體專案：`D:\EventAlertMod`（已停用）
- 歷史唯讀盤點：2026-08-14（Asia/Taipei）
- 證據：執行檔 VersionInfo、目錄存在性、`LinkType`、`Target`、`ReparsePoint`
- 尚未代表：角色登入、插件載入、流程面板、taint 或實機測試通過

本機路徑不得成為 EAM Lua 執行期依賴，也不得寫入發布包的執行期設定。

## 2. 2026-08-14 歷史 Retail／PTR 版本矩陣

| 版本資料夾 | 執行檔 | ProductVersion | WTF／AddOns | EAM 用途 |
| --- | --- | --- | --- | --- |
| `_retail_` | `Wow.exe` | 12.1.0.69299 | 皆存在 | 正式服 12.1 Native 實機驗證 |
| `_ptr_` | `WowT.exe` | 12.1.0.69299 | 皆存在 | 12.1 PTR Native 實機驗證 |
| `_xptr_` | `WowT.exe` | 12.0.7.68887 | 皆存在 | 至暗之夜 12.0.7 PTR 驗證 |

Battle.net 更新後 build 可能改變。每次實機測試前必須重讀 VersionInfo，不可只依 `_ptr_`／`_xptr_` 名稱推斷版本。

## 3. 2026-08-14 歷史 EventAlertMod 路徑型態

| 版本資料夾 | `Interface\AddOns\EventAlertMod` 型態 | 目標／狀態 | EAM 支援 |
| --- | --- | --- | --- |
| `_retail_` | `SymbolicLink`／Reparse Point | `D:\EventAlertMod` | 是 |
| `_ptr_` | `SymbolicLink`／Reparse Point | `D:\EventAlertMod` | 是 |
| `_xptr_` | `SymbolicLink`／Reparse Point | `D:\EventAlertMod` | 是 |
| `_classic_` | `SymbolicLink`／Reparse Point | `D:\EventAlertMod` | 否 |
| `_classic_era_` | 實體 `Directory` | 非連結 | 否 |
| `_classic_ptr_` | `SymbolicLink`／Reparse Point | `D:\EventAlertMod` | 否 |
| `_classic_era_ptr_` | 不存在 | 無 | 否 |

此表只描述當時狀態；舊根現已停用。Classic 路徑型態不一致，仍禁止套用批次連結操作。

## 4. 現行 Reparse Point 與部署保護規則

- 所有原始碼、文件與工具修改只可作用於新專案根；唯一插件來源是 `EventAlertMod/`。
- 任一 `_retail_`、`_ptr_`、`_xptr_` 目標若為 Reparse Point、SymbolicLink 或 Junction，部署與清理立即停止；不得跟隨、刪除、覆蓋或重建。
- 實體目標也不得用未驗證的 `robocopy /MIR` 或遞迴清理；只可由 `Deploy/Deploy-EventAlertMod.ps1` 在完整前檢與使用者確認後部署。
- 封裝只可從 `EventAlertMod/` 建立插件 ZIP；不得以 ZIP 解壓覆蓋 Reparse Point。
- 任何連結維護都必須獨立說明完整命令、目標、風險與恢復方式，並取得明確授權。
- 操作 AddOns 前先驗證 `LinkType`、`Target`、`ReparsePoint` 與 `EventAlertMod.toc`；只有完整實體目錄才可作實機簽收。

### 自動斷言工具

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
    -File .\.AI\Tools\Test-LocalWoWEnvironment.ps1
```

預設斷言 Retail `12.1.0`、PTR `12.1.0`、XPTR `12.0.7` 的 patch train，不鎖定 build 尾碼；完整 `ProductVersion`、`FileVersion` 與目標型態會寫入 `.AI/TestResults/EAM_LocalWoWEnvironment_*.json` 及 `.md`。版本不符、Reparse Point、檔案目標、巢狀 Reparse Point或實體目錄缺少 TOC 都回傳 exit code 1，且不執行修復。

Battle.net 切換版本線後可暫時用 `-RetailExpectedPatch`、`-PtrExpectedPatch`、`-XPtrExpectedPatch` 覆寫預期值；確認新基準後仍須同步更新本文件與 `AGENTS.md`。

唯讀驗證範例：

```powershell
$link = Get-Item -LiteralPath 'D:\World of Warcraft\_ptr_\Interface\AddOns\EventAlertMod' -Force
$link | Select-Object FullName, LinkType, Target, Attributes
```

## 5. WTF 路徑推導

```text
<WOW_ROOT>\<VERSION>\WTF
<WOW_ROOT>\<VERSION>\WTF\Account\<ACCOUNT>\SavedVariables\EventAlertMod.lua
```

目前候選：

```text
D:\World of Warcraft\_retail_\WTF\Account\<ACCOUNT>\SavedVariables\EventAlertMod.lua
D:\World of Warcraft\_ptr_\WTF\Account\<ACCOUNT>\SavedVariables\EventAlertMod.lua
D:\World of Warcraft\_xptr_\WTF\Account\<ACCOUNT>\SavedVariables\EventAlertMod.lua
```

不應遞迴列出 `WTF\Account`。需要回灌時，先確認實際測試版本與 build，再由使用者提供明確的 `EventAlertMod.lua` 路徑給 `.AI/Tools/Import-EAMFlowReport.ps1`。

## 6. 隱私與實機證據

- 不把帳號名稱、角色名稱、Battle.net 識別資訊或其他 SavedVariables 寫入 Git、Docs 或測試報告。
- 不在 WoW 正在寫入 SavedVariables 時搬移、覆蓋或修改 WTF；本專案 importer 僅唯讀。
- `_retail_`、`_ptr_`、`_xptr_` 報告不可混用，必須記錄實際 client build 與來源版本樹。
- Classic 目錄或連結存在不代表本專案支援 Classic。
- 目錄可安全部署、插件目標完整、離線 Mock、Retail 實機與 PTR 實機是不同證據層級，不得互相替代。

## 7. 與流程驗證的關係

`.AI/Docs/26_FLOW_VALIDATION_FRAMEWORK.md` 定義測試案例、遊戲內按鈕、SavedVariable 報告與回灌契約；本文件只負責本機版本、WTF 與部署目標安全邊界。

## 8. 2026-08-08 唯讀前檢快照

| 產品目錄 | ProductVersion | 用途 |
| --- | --- | --- |
| `_retail_` | 12.0.7.68974 | 正式服回歸 |
| `_ptr_` | 12.1.0.69189 | PTR8 Native Aura／UnitPower RQA 目標 |
| `_xptr_` | 12.0.7.68887 | Legacy 相容回歸 |

本次證據為 `TestResults/EAM_LocalWoWEnvironment_20260808_194717447.json`，結果 3/3；三個 AddOns 路徑均為 SymbolicLink／Reparse Point 且目標為 `D:\EventAlertMod`。這不是遊戲內流程簽收。

## 9. 2026-07-29 歷史唯讀前檢快照

| 產品目錄 | ProductVersion | 用途 |
| --- | --- | --- |
| `_retail_` | 12.0.7.68887 | 正式服回歸 |
| `_ptr_` | 12.1.0.68914 | Native Aura RQA 目標 |
| `_xptr_` | 12.0.7.68887 | Legacy 相容回歸 |

`_retail_`、`_ptr_`、`_xptr_` 的 `Interface\AddOns\EventAlertMod` 均已唯讀確認為 SymbolicLink，目標是 `D:\EventAlertMod`。證據為 `TestResults/EAM_LocalWoWEnvironment_20260729_135335687.json`，結果 3/3；這不是遊戲內簽收。本輪所有修改只作用於實體專案，未對 link 路徑執行部署、刪除、搬移、覆寫或重建。

## 9. 2026-08-14 唯讀前檢快照

| 產品目錄 | ProductVersion | 用途 |
| --- | --- | --- |
| `_retail_` | 12.1.0.69299 | 正式服 12.1 Native 回歸 |
| `_ptr_` | 12.1.0.69299 | PTR 12.1 Native／API 能力回歸 |
| `_xptr_` | 12.0.7.68887 | Legacy 相容回歸 |

`TestResults/EAM_LocalWoWEnvironment_20260814_104354344.json` 結果 3/3；三個支援客戶端的 AddOns 路徑仍是指向 EAM 實體專案的 SymbolicLink／Reparse Point。此證據只確認版本 train、執行檔與連結，未啟動 WoW，也不是 Aura、Tooltip、Profile 或戰鬥流程簽收。

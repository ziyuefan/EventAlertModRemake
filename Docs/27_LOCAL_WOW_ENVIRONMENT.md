<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EAM 本機 WoW 開發環境基準

## 1. 定位與證據邊界

本文件記錄少年欸目前開發機的 WoW 安裝與連結基準，供後續安裝路徑辨識、WTF 報告回灌及 Retail／PTR 實機測試使用。

- WoW 根目錄：`D:\World of Warcraft`
- EAM 實體專案：`D:\EventAlertMod`
- 最後唯讀盤點：2026-08-08（Asia/Taipei）
- 證據：執行檔 VersionInfo、目錄存在性、`LinkType`、`Target`、`ReparsePoint`
- 尚未代表：角色登入、插件載入、流程面板、taint 或實機測試通過

本機路徑不得成為 EAM Lua 執行期依賴，也不得寫入發布包的執行期設定。

## 2. Retail／PTR 版本矩陣

| 版本資料夾 | 執行檔 | ProductVersion | WTF／AddOns | EAM 用途 |
| --- | --- | --- | --- | --- |
| `_retail_` | `Wow.exe` | 12.0.7.68974 | 皆存在 | 正式服實機驗證 |
| `_ptr_` | `WowT.exe` | 12.1.0.69189 | 皆存在 | 至暗之夜 12.1.0 PTR 驗證 |
| `_xptr_` | `WowT.exe` | 12.0.7.68887 | 皆存在 | 至暗之夜 12.0.7 PTR 驗證 |

Battle.net 更新後 build 可能改變。每次實機測試前必須重讀 VersionInfo，不可只依 `_ptr_`／`_xptr_` 名稱推斷版本。

## 3. EventAlertMod 路徑型態

| 版本資料夾 | `Interface\AddOns\EventAlertMod` 型態 | 目標／狀態 | EAM 支援 |
| --- | --- | --- | --- |
| `_retail_` | `SymbolicLink`／Reparse Point | `D:\EventAlertMod` | 是 |
| `_ptr_` | `SymbolicLink`／Reparse Point | `D:\EventAlertMod` | 是 |
| `_xptr_` | `SymbolicLink`／Reparse Point | `D:\EventAlertMod` | 是 |
| `_classic_` | `SymbolicLink`／Reparse Point | `D:\EventAlertMod` | 否 |
| `_classic_era_` | 實體 `Directory` | 非連結 | 否 |
| `_classic_ptr_` | `SymbolicLink`／Reparse Point | `D:\EventAlertMod` | 否 |
| `_classic_era_ptr_` | 不存在 | 無 | 否 |

Windows 路徑大小寫不影響目標；`D:\EventAlertMod` 與 `d:\EventAlertMod` 視為同一路徑。Classic 路徑型態不一致，禁止套用批次連結操作。

## 4. SymbolicLink 保護規則

- 所有原始碼、文件與工具修改只可作用於實體目錄 `D:\EventAlertMod`。
- 嚴禁對 `_retail_`、`_ptr_`、`_xptr_` 的 `Interface\AddOns\EventAlertMod` 執行刪除、搬移、覆蓋、解壓縮、重新命名或連結重建。
- 嚴禁以 `robocopy /MIR`、遞迴清理或其他可能追蹤 Reparse Point 的工具處理上述連結路徑。
- 封裝工具只可從實體專案建立 zip，不得把輸出解壓回 SymbolicLink 路徑。
- 任何連結維護都必須獨立說明完整命令、目標、風險與恢復方式，並取得明確授權。
- 操作 AddOns 前先驗證 `LinkType`、`Target` 與 `ReparsePoint`；不符合預期立即停止。

### 自動斷言工具

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
    -File .\Tools\Test-LocalWoWEnvironment.ps1
```

預設斷言 Retail `12.0.7`、PTR `12.1.0`、XPTR `12.0.7` 的 patch train，不鎖定 build 尾碼；完整 `ProductVersion`、`FileVersion`、Reparse Point 與 Target 會寫入 `TestResults/EAM_LocalWoWEnvironment_*.json` 及 `.md`。任一版本或連結不符即回傳 exit code 1，且不執行修復。

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

不應遞迴列出 `WTF\Account`。需要回灌時，先確認實際測試版本與 build，再由使用者提供明確的 `EventAlertMod.lua` 路徑給 `Tools/Import-EAMFlowReport.ps1`。

## 6. 隱私與實機證據

- 不把帳號名稱、角色名稱、Battle.net 識別資訊或其他 SavedVariables 寫入 Git、Docs 或測試報告。
- 不在 WoW 正在寫入 SavedVariables 時搬移、覆蓋或修改 WTF；本專案 importer 僅唯讀。
- `_retail_`、`_ptr_`、`_xptr_` 報告不可混用，必須記錄實際 client build 與來源版本樹。
- Classic 目錄或連結存在不代表本專案支援 Classic。
- 目錄存在、SymbolicLink 正確、離線 Mock、Retail 實機與 PTR 實機是不同證據層級，不得互相替代。

## 7. 與流程驗證的關係

`Docs/26_FLOW_VALIDATION_FRAMEWORK.md` 定義測試案例、遊戲內按鈕、SavedVariable 報告與回灌契約；本文件只負責本機版本、WTF 與 SymbolicLink 安全邊界。

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

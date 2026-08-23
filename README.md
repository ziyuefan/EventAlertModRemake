# EventAlertMod Retail 12.1

[![GitHub](https://img.shields.io/badge/source-GitHub-181717)](https://github.com/ziyuefan/EventAlertModRemake)
[![Release](https://img.shields.io/badge/release-Alpha%207.5-orange)](https://github.com/ziyuefan/EventAlertModRemake/releases)
[![Retail](https://img.shields.io/badge/WoW-Retail%2012.1-blue)](https://github.com/ziyuefan/EventAlertModRemake)

EventAlertMod（EAM）是只支援《魔獸世界》正式服 Retail 的輕量提醒插件，專注於自身／目標光環、技能冷卻、物品冷卻、地面效果與玩家職業資源。現行來源版本標記為 EventAlertMod_MN_20260823，發布定位為 Alpha 7.5 prerelease。

> 本文件是 GitHub 專案首頁與目前使用說明。下方歷史內容若與本節衝突，以本節、EventAlertMod.toc 與 .AI/Docs 的最新文件為準。

## 目前支援範圍

- Retail 12.1：Interface 120100，使用 Native Aura capability。
- XPTR／相容通道 12.0.7：保留 Legacy backend；不把 12.1 Native API 當成必備。
- Classic、MoP、TBC、Wrath 不在本專案支援範圍。
- 17 種玩家資源、13 個職業與 40 組職業／專精拓撲由 Player Resource Module 管理；同一專精可同時追蹤多個資源。
- 每項資源可獨立啟用、排序、前景／背景、位置、方向、寬高、圖示大小、間距、透明度、數字文字大小與相對偏移。
- 自身與目標光環、技能冷卻、物品冷卻、地面效果各有獨立設定與模組開關。
- 自身／目標新增光環預設僅玩家施放；跨職業增減益預設不勾選玩家施放條件。
- 12.1 Native Aura 不讀取 UNIT_AURA Secret payload，也不鉤 Blizzard AuraButton／TargetFrame。目標框架光環若沒有安全 Tooltip candidate，不能保證取得法術 ID 或開啟 Ctrl+Alt 視窗；使用 /eam add target 開啟手動加入視窗。

## 玩家職業資源

Player Resource Module 將 Mana、Rage、Energy、Combo Points、Insanity、Runes、Runic Power、Arcane Charges 等視為獨立 resource node，不使用單一 active power 覆蓋其他資源。

- NUMERIC 資源：在 API 能安全讀取時可顯示數字、門檻與高亮。
- SECRET_DISPLAY 資源：只把安全百分比或狀態送入原生 StatusBar sink，不讀回、不比較、不字串化、不保存、不匯出。
- UnitPower、UnitPowerMax、UnitPowerPercent 只在 capability／冷路徑與允許的事件路徑使用；報告不包含 current、max、percent 原值。
- 死亡騎士 Runes 不使用泛用 UnitPower 聚合值：登入／拓樸建立時以六槽 GetRuneCount／GetRuneCooldown 初始化，之後由 RUNE_POWER_UPDATE(index, added) 即時更新 0..6 分段；Runic Power 維持獨立資源條。
- UNIT_DISPLAYPOWER、形態切換與脫戰只更新前景 metadata，不批量清除背景資源；背景資源沒有事件時，才由 demand-driven 共用 sampler 低頻取樣。
- 玩家資源設定在非戰鬥中即時套用；戰鬥中的結構變更延後到離戰合併，避免污染受保護框架。
- /eam unitpower background RESOURCE_KEY 是診斷入口，只標記指定背景資源可能缺少事件，不會輸出原始資源數值。

## 冷卻行為

技能冷卻只在「玩家精確成功施放、且該法術已在冷卻清單」時首次進入監控。戰鬥治療、脫戰、形態切換、refresh 或 regen 事件不得把整份清單批量 render。

三項冷卻行為可使用全域設定，也可在單一技能的齒輪細部設定中覆寫：

1. 冷卻完成時移除圖示。
2. 脫離戰鬥後是否保留圖示。
3. 技能可用時是否顯示高亮。

單技能設定為未指定時繼承全域；明確 false 會保存，不會被預設值覆蓋。充能技能須先觀測到至少一次「已消耗充能」，之後回到最大可用次數才視為完成；環形版面使用封裝 TGA ring grid，能力不符時回退線性條。

## 地面效果

地面效果只在玩家本人成功施放、且安全施放 ID 命中設定清單時建立計時。服務在非戰鬥冷路徑預先編譯設定 ID 的 Base／Override／目前 SpellInfo ID 族群，熱路徑只做安全 O(1) 查表；設定 ID 完全相符時優先，碰撞或 Secret ID 則拒絕猜測。

- 死亡凋零與褻瀆等天賦替換可由同一法術族群對齊，不需要同時硬寫所有 override ID。
- 冰霜之球、反魔法立場等仍以成功施法事件啟動；自動秒數解析失敗時使用該項手動 fallback。
- EAM 目前追蹤的是施放後的時間上限；反魔法立場若因吸收上限提前消失，沒有安全公開事件可證明實際提前結束，圖示可能維持到 fallback 到期。
- 切換天賦／專精會在非戰鬥中重編譯法術族群；戰鬥中只標記待更新，離戰後合併一次。

## 斜線命令

命令不分大小寫；主入口是 /eam，也接受 /eventalertmod。沒有參數時開啟主設定。

### 設定與清單

| 命令 | 用途與時機 |
| --- | --- |
| /eam 或 /eam opt | 開啟主設定視窗；調整模組開關、主題、語系、字型、位置與資源。 |
| /eam help | 顯示目前版本可用命令。遇到版本差異先執行此命令。 |
| /eam list | 列出目前職業 profile 的自身光環、目標光環、技能冷卻、物品冷卻與地面效果。 |
| /eam lookup 名稱 | 在目前職業有限候選資料中做部分名稱查詢並列出 Spell ID。 |
| /eam lookupfull 完整名稱 | 在目前職業候選資料中做完整名稱查詢。/eam l 與 /eam lf 是別名。 |
| /eam profile | 開啟職業 Profile 匯入／匯出視窗。 |
| /eam profile export | 直接開啟可複製的 EAMAP1 JSON／Base64 匯出視窗。匯入仍在同一視窗貼上並預覽後執行。 |

### 新增與移除監控

| 命令 | 用途與時機 |
| --- | --- |
| /eam add SPELL_ID | 將玩家自身光環加入目前職業清單；適合已知 Spell ID。 |
| /eam add target SPELL_ID | 將目標光環加入目標清單；適合已知 Spell ID。 |
| /eam add target | 開啟目標光環手動加入視窗；適合 TargetFrame 無安全 ID 或 Ctrl+Alt 不產生 candidate 時。 |
| /eam add cd SPELL_ID | 將技能加入技能冷卻清單；第一次精確成功施放後才 render。 |
| /eam add item ITEM_ID | 將物品加入物品冷卻清單。 |
| /eam remove SPELL_ID | 移除玩家自身光環。 |
| /eam remove target SPELL_ID | 移除目標光環。 |
| /eam remove cd SPELL_ID | 移除技能冷卻。/eam remove cooldown SPELL_ID 也可用。 |
| /eam remove item ITEM_ID | 移除物品冷卻。 |

### 診斷、流程與探索

| 命令 | 用途與時機 |
| --- | --- |
| /eam doctor 或 /eam validate | 顯示 Retail／PTR API capability、Secret 邊界與 runtime metadata；遇到資源不顯示時先執行。 |
| /eam test | 開啟流程測試面板。 |
| /eam test quick | 快速核心流程。 |
| /eam test core | 核心事件、SavedVariables 與 scheduler。 |
| /eam test boundary | Secret／安全邊界與 API sink。 |
| /eam test aura121 | Retail 12.1 Native Aura 流程。 |
| /eam test all | 執行完整離線流程測試並產生 JSON 報告。 |
| /eam test live 或 /eam test manual | 開啟玩家手動實機簽收面板；插件不會自動操作角色或按鈕。 |
| /eam debug | 開啟精簡開發報告匯出視窗。 |
| /eam debug ground SPELL_ID | 低頻解析指定地面技能 Tooltip 秒數；解析失敗時仍使用設定的 fallback。 |
| /eam rune | 顯示死亡騎士 6 格符文槽位即時秒數與冷卻進度診斷視窗。 |
| /eam export | 開啟精簡 AI debug 狀態匯出。 |
| /eam showcast 或 /eam showc | 開／關本次登入玩家成功施法記錄，並列出安全可讀的 Spell ID。 |
| /eam show、/eam showtarget | 顯示 12.1 光環 ID 的安全限制與建議路徑。 |
| /eam showautoadd、/eam showenvadd | 顯示不自動掃描／寫入監控清單的原因。 |
| /eam unitpower background RESOURCE_KEY | 明確標記背景資源事件缺失，啟用共用 sampler；只在診斷事件缺失時使用。 |

實機報告必須註明 Retail、PTR 或 XPTR、Interface、build、戰鬥狀態與是否剛部署；離線 mock 通過不能冒充遊戲內通過。

## 安全與已知限制

- 不在戰鬥中讀取、比較、字串化、索引、序列化 Secret／Protected UnitPower、Aura 或時間值。
- 不使用 UnitPower 的 OnUpdate 輪詢；不鉤、覆寫或猴子補丁 Blizzard secure/protected frame、TargetFrame、AuraButton、ActionButton。
- Native Aura 的法術 ID、目標光環 owner、剩餘時間與堆疊可能受 Blizzard 安全策略限制；安全取得不到時保留圖示或手動輸入路徑，不猜 ID。
- StatusBar／Cooldown 原生 sink 的接受只代表 API 邊界成立，不代表所有客戶端的視覺結果；仍需玩家在對應通道驗證。
- 修改插件程式後，必須先部署至對應通道的 Interface\AddOns\EventAlertMod，再在遊戲內 /reload；本機 source 變更不會直接改變遊戲中的插件。
- 讀取 WTF 最新報告前，玩家必須先 /reload 或正常登出，否則 SavedVariables 可能仍是舊內容。

## 專案目錄

- EventAlertMod：唯一插件實體來源；打包時完整封裝，包含 Managers。
- Deploy：部署、插件 ZIP 與完整 source ZIP 工具。
- .AI：Docs、Data、Tools、Flow／Contracts、ProjectContinuity、備份與 AI 交接記錄。
- Dist：本機產物，不上傳 GitHub；GitHub Release 才提供下載 ZIP。
- backup：修改前備份與部署 rollback，不納入發布包。

## 離線驗證與報告匯入

在專案根目錄執行：

~~~powershell
pwsh -NoProfile -File .\.AI\Tools\CheckLuaSyntax.ps1 -AddonOnly
pwsh -NoProfile -File .\.AI\Tools\Run-FlowValidation.ps1 -Suite boundary
pwsh -NoProfile -File .\.AI\Tools\Run-FlowValidation.ps1 -Suite all
pwsh -NoProfile -File .\.AI\Tools\Test-ValidationContracts.ps1
pwsh -NoProfile -File .\.AI\Tools\Import-EAMFlowReport.ps1 -Path '<EventAlertMod.lua 或 report.json>' -ReportType Auto
~~~

檢查重點是 Lua syntax、Flow all／boundary、Validation Contracts、JSON schema 與 report importer。成功只代表離線契約；需要 Retail／PTR／XPTR 的戰鬥、專精、形態、視覺與 Tooltip 結果，必須由玩家手動部署與回報。

## 打包與部署

插件包與 source 包都從 canonical root 建立，禁止直接對 WoW 的 SymbolicLink／Junction 操作。

~~~powershell
pwsh -NoProfile -File .\Deploy\Build-Package.ps1
pwsh -NoProfile -File .\Deploy\Build-Package.ps1 -DryRun
pwsh -NoProfile -File .\Deploy\Build-SourcePackage.ps1
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1 -Action Status -WowRoot 'D:\World of Warcraft'
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1 -Action PTR -WowRoot 'D:\World of Warcraft' -DryRun
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1 -Action All -WowRoot 'D:\World of Warcraft' -DryRun
~~~

互動部署直接執行 Deploy-EventAlertMod.ps1。工具先從 Windows Registry 找 WoW 根目錄，顯示來源與 ProductVersion，按 Enter 接受或輸入 C 改路徑；選 PTR／XPTR 時只有輸入 Y 才會一併部署 Retail。實際覆蓋前需輸入 DEPLOY。部署器不檢查 Wow.exe／WowT.exe 是否執行，也不會替使用者關閉遊戲；目標 Reparse Point、來源錯誤、README／changelog 雜湊不同時會 fail-closed 且零寫入。

互動選單：

- 1 Retail、2 PTR、3 XPTR、4 全部通道。
- W 備份選定通道 WTF 中所有路徑含 EventAlertMod 的檔案，保留原始相對路徑與 SHA-256 manifest。
- U 依通道選擇備份並還原；還原前自動建立 rollback。
- B 建立插件 ZIP；S 建立 Project_EventAlertMod source ZIP；R 重新讀取狀態；Q 離開。

WTF 非互動範例：

~~~powershell
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1 -Action Backup -Channel PTR -WowRoot 'D:\World of Warcraft'
pwsh -NoProfile -File .\Deploy\Deploy-EventAlertMod.ps1 -Action Restore -Channel PTR -WowRoot 'D:\World of Warcraft' -WtfBackupPath '.AI\backup\wtf\ptr__<timestamp>'
~~~

Restore 必須指定單一通道與備份目錄；WTF 可能包含帳號／角色資料，不得上傳或貼到公開報告。

## 目前 Alpha 7.4 驗證狀態

- 目前源碼標記：EventAlertMod_MN_20260823。
- Alpha 7.4 累積包含：冷卻 exact-cast gate、充能 spent→full 完成生命週期、五種 current/max StatusBar 版面與 TGA ring grid、玩家資源即時設定、DK 六槽 Runes 事件更新、GroundEffect Base／Override 法術族群與 Target Aura 手動路由。
- 發布前離線 gate：Lua syntax 64/64、Flow all 82/82、Flow boundary 61/61、Validation Contracts 493/493。數字是離線／靜態證據，不等於 Retail、PTR 或 XPTR 真人視覺通過。
- 插件變更尚未自行部署到 WoW/WTF；玩家部署後需 /reload，再依 .AI/Docs/29_LIVE_TEST_STEP_GUIDE.md 的 Alpha 7.4 快速簽收回報通道、build、Interface 與畫面結果。
- GitHub prerelease 由人工 gh release 流程建立，不啟用既有 Release Action，也不發布 CurseForge。

## 開發者注意

- 修改任何檔案前先備份至 .AI/backup/時間戳。
- 修改 Markdown 後使用 EAM_DOCS_OFFLINE=1 執行 .AI/Tools/batch_convert_docs.py；Markdown 原檔是 AI 的唯一事實來源。
- 不要把 Dist、.AI/backup、WTF、TestResults 或本機附件加入發布 ZIP。
- 變更後至少執行 Lua、Flow、Contracts、JSON parse 與 git diff --check。
- 詳細 API、Secret、Aura、測試矩陣與持續性規則見 .AI/Docs/00_AI_CONTEXT.md、02_RETAIL_API_BOUNDARIES.md、06_TEST_PLAN_RETAIL.md、26_FLOW_VALIDATION_FRAMEWORK.md、28_PROJECT_CONTINUITY.md、30_PLAYER_RESOURCE_REFACTOR_REPORT.md。

## 連結

- [GitHub 原始碼](https://github.com/ziyuefan/EventAlertModRemake)
- [GitHub Releases](https://github.com/ziyuefan/EventAlertModRemake/releases)
- [GitHub Pages](https://ziyuefan.github.io/EventAlertModRemake/)
- [Changelog](https://github.com/ziyuefan/EventAlertModRemake/blob/main/changelog.txt)

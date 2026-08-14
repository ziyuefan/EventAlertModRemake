<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# [GitHubPage](https://ziyuefan.github.io/EventAlertModRemake/ "GitHubPage")
# [ChangLog](https://github.com/ziyuefan/EventAlertModRemake/blob/main/changelog.txt "ChangLog")
# [CommandLine](https://github.com/ziyuefan/EventAlertModRemake/blob/main/README.md#命令列 "CommandLine")
# [ScreenShot](https://github.com/ziyuefan/EventAlertModRemake/blob/main/README.md#截圖 "ScreenShot")

---

#### [Retail 12.1 Alpha 6] 2026.08.14
- 正式服與 PTR 12.1 使用 Native Aura capability；XPTR 12.0.7 保留 Legacy backend。自身／目標 Aura 預設僅玩家施放，跨職業增減益預設取消，批次輸入只加入可解析且存在的 ID。
- 修正語系列空白與按鈕固定紅色：Auto Detect 與五個原生語言名稱在未 hover 時可見，十一套主題控制按鈕 normal／highlight／pushed／disabled、文字與四邊 2px 邊框。
- 小地圖固定使用內建 `Trade_Engineering` 齒輪；內層圖示依標準小地圖按鈕幾何縮入金色追蹤圈，不再與 53×53 複合邊框錯位。
- Alpha 6 ZIP 由本機 `Build-CurseForgePackage.ps1` 產生後手動上傳 GitHub prerelease；停用中的 BigWigs／CurseForge／WoWInterface workflow 不啟用，本機 deploy、Tools、Tests、TestResults、backup 與 LegacyReference 不進套件。
- 發布前離線 gate：Lua `56/56`、Flow `68/68`、Validation Contracts `394/394`；Retail／PTR／XPTR 真人視覺、音效與戰鬥簽收仍為 pending。

#### [Retail 12.1 Alpha 5 follow-up] 2026.08.14
- 現行正式服與 PTR 已更新為 12.1，Native Aura capability 以 Interface `120100` 與實際 widget 能力判定；XPTR 12.0.7 保留 Legacy backend。
- Aura 清單新增批次輸入，可用 Enter、半形分號或全形分號分隔；自身與目標新增預設「僅玩家施放」，跨職業增減益預設取消該條件，不存在的 SpellID 不顯示也不寫入。
- 修正下拉選單黑底看不到文字、Profile 長字串捲動與主設定入口；小地圖改用內建 `Trade_Engineering` 齒輪，暫停不可靠的 Texture SVG 圖示路徑。
- `Data/wow_spells_and_auras.json` 僅作 Wowhead 離線候選索引，不接入 TOC、runtime 或預設 seeder；唯一治理工具為 `Tools/Test-WowheadCandidateData.ps1`。
- 本輪離線 gate：Lua `56/56`、Flow `67/67`、Validation Contracts `380/380`、本機環境 `3/3`；Retail／PTR／XPTR 真人簽收仍為 pending。

#### [正式服 12.1.0 PTR8 Alpha 5] 2026.08.14
- Alpha 5 完成 EAMAP1 JSON／Base64 profile 分享：嚴格 schema、checksum、preview、merge／replace、戰鬥拒絕與手動 Ctrl+C，不使用 loadstring。
- 主設定新增字型選擇（STANDARD、ARIALN、MORPHEUS、SKURRI）；字型設定只套用 EAM 自有文字，不修改 Blizzard secure/protected UI。
- 語系切換改為動態刷新 EAM 自有按鈕、下拉選單、條件與專精名稱；Auto Detect 固定英文，切換後不需 /reload，只有更新插件程式才需先 /reload 載入新 Lua。
- Alpha 5 Release ZIP 只由 GitHub Release 提供；本機 deploy、測試資料、工具與備份目錄不納入套件。
- 本版定位為 Alpha 5；離線驗證 Lua 56/56、Flow 66/66、Contracts 360/360，不代表 PTR／XPTR／Retail 實機簽收。

#### [正式服 12.1.0 PTR8 Alpha 4] 2026.08.13
- Alpha 4 整合功能模組開關、職業專用監控清單、模組化匯入／匯出規劃與 12.1 AuraSound 細部設定。
- 延續六套 EAM 主題、俄文語系、SVG 小地圖圖示、Native Aura／UnitPower 安全邊界與 37 案真人測試矩陣。
- 發布套件只由 GitHub Release 提供；本機 deploy、測試資料、工具與備份目錄不納入正式 ZIP。
- 本版定位為 Alpha 4；離線驗證通過不代表 PTR／XPTR／Retail 實機簽收。

#### [正式服 12.1.0 PTR8 Alpha 3 follow-up] 2026.08.13
- Aura 細部設定新增 12.1 AuraSound：可選共用素材，分別啟用光環新增、層數增加與移除；三項皆未選時沿用全域音效。
- 全域音效為 master gate；純音效變更不重建 AuraContainer。註冊採交易式交換，失敗保留舊 registry，移除失敗留待重試。
- 12.0.7 顯示 capability 降級且保留設定，不呼叫 12.1 `AddAuraSound`。Native sound 無 caster／極性欄位，仍需 PTR 觀察 over-fire。
- 真人矩陣升為 `2026-08-13.1` 共 37 案；離線流程通過不代表 PTR／XPTR／Retail 實播簽收。
- 本輪離線 gate：Lua `54/54`、Flow `all 61/61`、Validation Contracts `355/355`；Flow artifact 為 `TestResults/EAM_FlowValidation_all_20260813_013945.json`。

#### [正式服 12.1.0 PTR8 Alpha 2] 2026.08.08
- 12.1 改採 Blizzard Native AuraContainer／AuraButton；12.0.7 保留 Legacy backend，不在 12.1 讀取 `UNIT_AURA` Secret payload。
- GameTooltip 顯示可安全取得的法術、物品與巨集 ID；光環 ID 優先交由 Blizzard CVar 顯示。
- 在非戰鬥中可用精確 `Ctrl+Alt` 開啟 EAM 自製監控選單，依法術／光環／物品／巨集來源路由至既有監控清單。
- timer 與 applications 可各自選擇 21 個框內／框外位置，字級可設 8–32。12.0.7 一般 EAM 圖示可直接重套文字；12.1 Native AuraButton 的文字、swipe 與錨點只在 `initializeFrame` 設定，滑桿提交後於脫戰重建一次容器。單次載入最多建立 18 個 Native 容器，超限時明示需 `/reload`。
- 修正 DurationObject／DurationTextBinding 建構與釋放契約、12.1 物品冷卻事件、地面效果說明秒數與手動 fallback、冷卻 swipe 透明度，以及次要 UnitPower 資源顯示；Secret 主要資源只走原生顯示 sink，不讀回數值。
- 接入 PTR8 AuraButton Pandemic region、Dispel texture options 與停用 AuraContainer 清除契約；Native 設定只在初始化期套用，修改後於非戰鬥手動重建。
- 新增離線流程驗證、遊戲內能力面板、34 案真人簽收工作台、雙倒數診斷、UnitPower 能力報告、嚴格 JSON 匯入與 continuity drift gate；本輪通過 Lua 47 檔、Flow `all` 54/54、Validation Contracts 208/208。報告的 `purpose=offline-contract`、`executionSource/source=offline-mock`、`clientChannel=OFFLINE` 只代表離線契約，不是 PTR／XPTR／Retail 實機簽收。
- 本版定位為 Alpha；離線驗證不等於 PTR 實機簽收，Tooltip 互動、Secret 邊界與戰鬥污染仍需在 12.1 PTR 驗證。

---

## 開發與實機流程驗證

```powershell
pwsh -NoProfile -File .\Tools\CheckLuaSyntax.ps1
pwsh -NoProfile -File .\Tools\Run-FlowValidation.ps1 -Suite all
pwsh -NoProfile -File .\Tools\Test-ValidationContracts.ps1
```

遊戲內能力檢查請用 `/eam test`；PTR／XPTR 真人簽收請用 `/eam test live`，選擇實際客戶端後由玩家手動完成 37 案。EAM 不會自動操作角色、Tooltip、按鈕或 `/reload`。未跨過玩家自行執行的 `/reload`、測試版本身分未知、案例未全數通過或仍有警告時，報告不得完成。備註不可包含帳號、角色、伺服器、WTF 或絕對路徑。面板直接複製的是記憶體內最新 JSON；若要從 WTF 匯入，完成報告後必須由玩家再輸入 `/reload` 或正常登出，SavedVariables 才會寫入最新內容：

UnitPower 能力測試在 `/eam test` 點「UnitPower 能力」，由玩家自行產生／消耗資源、切換專精及進出戰鬥，再對兩個原生顯示標記 pass／fail／blocked。輸出的 `EAM_UNIT_POWER_CAPABILITY_REPORT` 只含能力分類與人工結果，不含 current／max／percent 原值。

```powershell
pwsh -NoProfile -File .\Tools\Import-EAMFlowReport.ps1 -Path '<EventAlertMod.lua 或 report.json>' -ReportType Auto
```

Mock 通過不代表 Retail／PTR 實機通過。完整規格見 [Docs/26_FLOW_VALIDATION_FRAMEWORK.md](https://github.com/ziyuefan/EventAlertModRemake/blob/main/Docs/26_FLOW_VALIDATION_FRAMEWORK.md)。

#### [正式服12.1.0]2026.06.09
- 零分配與事件驅動全模組架構重構（資料完全與視圖解耦）
- 引入AlertManager控制器與節流調度器
- 影子載體實務技術 (Shadow Host) 與 UI 避讓
- 16大全新與高端魔獸事件整合
- 靜態JIT編譯完成優化與故障隔離
- 自動化預算發布工具 (Build-CurseForgePackage.ps1) 取得Bug修改與安全防禦升級
---
#### [正式服12.0.7]2026.06.06
- 專精與職業名稱動態API本地化重構
- 全專案硬編碼字串清掃與五大語系字典補齊
- ClassPower核心資源安全偵查與錯誤加強
- EventRouter/Scheduler 故障隔離
---
#### [正式服DF]2023.03.23
####【經典WOTLKC】2023.03.23
- DF：更新版本號到10.0.7
- 全域將函數與變數從全域空間(_G)移至外掛專屬空間名人(_G.EventAlertMod)，以減少相互幹擾
- 修改一些小bug1.
---
#### [正式服DF]2023.02.24
####【經典WOTLKC】2023.02.24
- DF: 活力提示
- DF:修改鼠標提示無法顯示MACRO的滑鼠ID
---
#### [正式服DF]2023.02.18
####【經典WOTLKC】2023.02.18
- 物品快速取表的建立改以協程方式獲取，深圳市卡頓
- DF：支持喚能師(Evoker)職業、支持龍能(Essence)顯示
---
#### [正式服DF]2022.12.22
####【經典WOTLKC】2022.12.22
- 修復排序
---
#### [正式服DF]2022.11.18
####【經典WOTLKC】2022.11.18
- DF:修復鼠標提示符號ID與物品ID顯示
- DF: 刪除 /eam basefontsize 指令
- DF: 增加 /eam StackFontSize nSize 指令以改變其中層資料大小(不分大小寫,亦/eam sfs nSize 可以代替)
- DF:增加/eam TimerFontSize nSize以改變大小數字大小（不分大小寫，也可以/eam tfs nSize代替）
- DF:增加/eam SNameFontSize nSize以改變武器名稱大小(不分大小寫,也可以/eam nfs nSize代替)
- WOTLKC:測試相容性OK
---
####【經典WOTLKC】2022.10.28
#### [正式服DF]2022.10.28
- DF:異動Button及CheckButton使用範例，保證正常顯示
- DF：刪除XML內未用屬性避免WARNING報錯
- WOTLKC: 相容性測試OK
---
####【經典WOTLKC】2022.10.18
#### [正式服 SL ]2022.10.18
- 冷卻模組暫時不再偵測背包冷卻物品即可偵測（背包的冷卻物品將偵測不到）
---
####【經典WOTLKC】2022.10.01
- 修正相關專精函數導致WLK版本之錯誤，並與SL版本相關
---
####【經典WOTLKC】2022.09.27
- 修復BUFF顯示
---
####【經典WOTLKC】2022.09.26
- 以SL 9.2.5版本之EAM重新作為WOTLKC之基礎版本
- 修復DK符文顯示，符文圖示以目前領域為主
- 修復DK符能顯示
---
####【經典WOTLKC】2022.08.22
- TOC架構更新、版本更新
---
####【經典待定】2021.06.25
- 回覆寵物集中值顯示
- 優化法力顯示
- 修復物品武器冷卻之卡頓
- 物品不再由玩家創建伺服器，改為每次釋放新版本更新伺服器
---
####【經典待定】2021.06.22
- 防止使用專精相關API而導致報錯
---
####【經典待定】2021.05.22
- 移除事件：ACTIVE_GROUP_TALENT
- 加入事件：UNIT_SPELLCAST_SUCCEEDED，並變更為符合版本規定的參數順序
---
####【經典待定】2021.05.21
- 基於SL 2021.04.14進行修改TBC版本，故繼承版本及之前的特性
- 增加顯示法力值,並顯示法力百分比
---
#### [SL] 2021.06.26
- 優化執行，減少卡頓
---
#### [SL] 2021.04.14
- 物品顯示改善冷卻正確性（比對物品優先順序：已裝備物品（庫存）> 背包（包）> 第一個建立的資料庫（EA_SPELL_ITEM））
- 針對工程附魔硝基推進器的ID做特別處理(GetItemSpell取得皆為55004，但使用觸發皆為54861)
- 在項目滑鼠提示內的武器ID增加顯示藥劑名稱
---
#### [SL] 2020.12.26
- 惡魔獵人復仇專精與災虐專精統一使用魔怒(Fury)資源,魔痛(Pain)已不再使用
- 條件技能內請勿再使用魔痛
- 德魯伊時將連擊點數放第一格，能量放第二格，怒氣放第三格
- 德魯伊平衡專精時將星能改放在第一格，連擊分數第四格
- 切換專精時連擊積分修改資源不更新的問題
- ShowAuraValueWhenOver 預設值改為 10
---
#### [SL] 2020.11.17
- 變更細部設定背景，形成不與其他框架影響
- 修改魔法細部設定文字綠色背景問題
- 修改: 啟用ESC關閉提示功能時,ESC關閉框架問題,其他技能提醒無法退出ESC關閉的按鈕,
且ESC將成為顯示開關，按一次關、按一次開，並可戰鬥中開關
---
#### [SL] 2020.11.03
- 修改DK符文報錯
---
#### [SL] 2020.11.01
- 變更DK符文圖案，制定符合版本
- 符文數量會顯示專精，例如：邪邪符文、冰霜符文、血魄符文
- 字體基礎大小值改為自訂，不再跟隨圖示大小縮放可輸入 /eam BaseFontSize nSize
自訂大小和縮放、名稱將以這個基礎值做框外或框內等縮放比例有興趣者可以到
EventAlert_IconOptions.lua 查找函數EventAlert_Icon_Options_Frame_AdjustTimerFontSize
自行修改,首次執行預設值為26
- 斬殺動畫...調整，並且可以/eam play 播放
- 新增及增加小地圖齒輪的滑鼠提示輔助說明
---
#### [SL] 2020.10.26
- 修復連擊點高亮, 並一律以巔峰高亮(依專精天賦可能不同)
- 修復獵人寵物集中值高亮，並預設50高亮，
   可配合手動施放寵物傷害技能時，最大化傷害。
- FontObject(EA_FONT_OBJECT) 維修以"TextStatusBarText"為主，否則以"ChatFontNoramal"為主
- 字體 (EA_Fonts) 拉取系統預設值 STANDARD_TEXT_FONT, 以 /dump STANDARD_TEXT_FONT 可能因語言出現不同的標準字體
- 以上兩個可修改於 EventAlertMod_InitVar.lua 進行
- 將大部分框架體係由HIGH或MEDIUM嘗試減少與其他框架現象的對比
- 圖示大小每次滑動調整值由 51 改為
- 當偵測OmniCC被載入且EAM也啟用倒數陰影功能時，強制關閉EAM的倒數陰影，避免被OmniCC攔截造成顯示幹擾
---
#### [SL] 2020.10.18
- 變更秘法充能圖案
- 修改術士報錯
- DK 增加可用符文數量顯示,若達6個可用符文則高亮
- DK 可透過/eam ShowRunesBar 切換顯示符文列
---
#### [SL] 2020.10.17
- 修復真氣顯示
- 修復坦DH資源顯示(魔痛)
- 暗牧瘋狂值達到標準需求值50高亮
- 狂戰怒氣達到暴怒需求值80高亮
- 武戰怒氣達到斬殺最大傷害需求值40高亮
- 防戰怒氣達到無視苦痛需求值40高亮
- 平衡德魯伊星能達到星術需求值50高亮
- 放大字體（必須調整圖示大小才會跟著調整字體大小）
---
#### [SL] 2020.10.04
- 包裝GetSpellDurationByDesc() 到 Lib_ZYF
---
#### [SL] 2020.08.23
- 修復術士靈魂碎片及碎塊顯示問題
- 修復容量框架內不顯示數字
---
#### [SL] 2020.08.22
- 修改非光環式地面效果的比對PATTERN使之可以在PTR比對到例如:116011(主動力之符文)、342130(被動力之符文)
（註：此類效果需在自身增減益輸入施法ID，而非BUFF ID，須特別注意）
---
#### [SL] 2020.08.16
- 將 TOC 版本號碼更新至 9.0(90001)
- 因應暴雪對背景操作進行異動而進行相關修改使顯示正常
- LibButtonGLow的高亮函數壞掉，改用LibCustomGLow的LibStub("LibCustomGlow-1.0").ButtonGlow_Start(eaf)及
LibStub("LibCustomGlow-1.0").ButtonGlow_Stop(eaf)
- 其他忘記改了啥東西
---
####【博鰲亞洲論壇】2019.06.27
- 將版本號碼更新至 8.2
-修改：由於播放音效API不再支援PATH格式，所以產生的錯誤目前全部都到https://wow.tools/files/找到對應ID代入
---
####【博鰲亞洲論壇】2019.06.07
- 修改:武僧真氣顯示(LIGHTFORCE改為均CHI)
---
####【博鰲亞洲論壇】2018.11.24
- 修改:/eam iconappespelltip 選項功能,設定可以正常開關滑鼠提示,也允許滑鼠點擊倉庫
---
####【博鰲亞洲論壇】2018.11.05
- 群體條件技能提示增加條件滿足時高亮的選項
- 若天賦屬於技能，但未點出，則不會進行判斷與顯示(以第一組子條件的法術ID以及當前專精作為參照)
---
####【博鰲亞洲論壇】2018.10.12
- 修改：自身與目標debuff不顯示紅色與綠色的問題
- 修改：技能冷卻模組圖示引發問題
- 優化：建立專案對應的伺服器表不再嚴重卡頓（但先一點小卡）並會提示建立伺服器圖，
建議等待完成記錄完成。 （為了避免嚴重卡頓而分攤到250秒內，所以會比之前等待時間更久）
- 技能冷卻增加最後秒數紅字提示之設定(請於齒輪內設定)
- 剩餘秒數紅字提示放大10%大小依(依框內或框外之倒數數字放大)
- 非光環式技能持續時間增加了一個比對方式，讓烏鴉獵殺可以被判定到
---
####【博鰲亞洲論壇】2018.10.02
-修改非光環式技能會顯示玩家本身以外的問題
- 修改數字引發問題(可在EventAlert_IconOption.lua內找到
EventAlert_Icon_Options_Frame_AdjustTimerFontSize來修改比例)
---
####【博鰲亞洲論壇】2018.09.29
- PositionFrame(), TarPositionFrame(0, ScdPositionFrame()不再一有事件就更新,
改以每0.1秒定時更新圖標，以求大幅降低cpu使用率，從而避免團戰時大量事件引起的LAG
---
####[博鰲亞洲論壇]2018.09.03
- 加強非光環式持續效果正確性
---
####【博鰲亞洲論壇】2018.08.29
- 支援無光環之技能秒數，請在本職業提示模組中輸入“技能武器ID”，程式會自動抽取技能提示內的持續時間，
若抓取不到，請查閱localization.tw.lua內的EA_XCMD_SPELL_DURATION_PATTERN1,
EA_XCMD_SPELL_DURATION_PATTERN2 的正規表示式例如暴風雪(190356)、鏡像(55342)、
冰霜之球(84714)、力之符文(116011)等等
P.S.116011是符文持續時間,116014是在符文有效範圍內才會出現的BUFF
---
####【博鰲亞洲論壇】2018.08.25
- 新增指令 /eam NewLineByIconCount (2~n)
單一模組，每個圖示自動跳轉至下一列冷卻
- 新增指令 /eam UpdateInterval
控制OnUpdate頻率，超過0.1秒則小數據點顯示會不正常，但較慢不會延遲
- 一些特殊指令會在設定圖示的滑鼠提示中顯示
---
#### [腿] 2017.09.01
- 修改- 修復主選單設定無法儲存問題
- 修改- 修改 7.3 PlaySound函數因引用參數類型改變造成的錯誤
- 術毀滅士的碎片會顯示到小數字點
---
#### [腿] 2017.07.09
- 增加招式圖騰型魔法監控，在自身BUFF內輸入招喚型施法法術ID
例如力之符文、薩滿圖騰、屈心魔等等
- /eam showc 若啟用，增加顯示招喚型法術ID
---
#### [腿] 2017.07.01
- 加入邪DK黑暗犯罪者支持
- 黃色字體改回白色字體
- 修復冷卻計時錯誤
- 修改在技能冷卻結束時提示不消失的狀態下(/eam scdremovewhencooldown 等於 false 時)，對應技能卻在冷卻完成時消失的BUG
---
#### [腿] 2017.06.29
- 修復因加入物品CD功能而導致技能CD失常的現象
---
#### [腿] 2017.06.26
- 重新調整.toc檔內引用UIDropDownMenu相關文件的順序(XML必須比LUA檔更早引用,且LibStub必須更早引用)
- BUFF,DEBUFF 附加數值(value1~3) 若超過1萬則以萬為單位顯示
---
#### [腿] 2017.06.23
- 針對力之符文(116014)做特別處理(SPELL_SUMMON事件記錄開始時間,EventAlert_Buffs_Update函數讀寫持續時間10秒)
- UIDropDownMenu修改呼叫不完全的問題(toc加入另外兩個lua的路徑)
---
#### [腿] 2017.06.21
- 針對污染問題呼叫UIDropDownMenu修改用函式函式庫及新版本的LibButtonGlow1.0函數函式庫來降低污染的產生式
- 技能冷卻增加了冷卻，但是不能輸入物品ID(Item ID)，只能輸入施放的武器ID萊建立，
可以使用/eam showc來查詢，但是物品的CD如果可以「使用型」則可以透過GetSpellBaseCooldown(武器ID)來查詢
,程式會自動判別,但如果特定條件觸發且有內建CD的則需要玩家手動輸入固定值,目前用比較不方便的作法就
是在打印機ID的冷卻輸入格式後面以分號(;)隔開輸入秒數。例如：
賽弗斯的秘密就輸入208052;30
聽力吸收207452;30
輸入後若無法立即作用請/rl或/reload重載UI
若曾經建立過該條碼ID但沒有輸入過秒數或秒數錯誤，請先刪除，再重新建立。之後再時間更正
- 統計文字加上地理
- 包含文字加大並加上陰影
---
#### [腿] 2017.06.19
- 修改冷卻模組產生前置作業存取到空白表格的nil存取錯誤
---
#### [腿] 2017.06.16
- 技能冷卻模組現在可以設定比重排序了(其他4項暫時無效果，建議不要設定)
- 條件式群體技能將連擊點由“連擊點異動類別”移至“能量異動類別”
- 條件式群體技能連擊積分修改故障問題
- 修復條件式群體技能第三個專精無法篩選問題
- 跨職業增減益區由修改項目觸發的增減益無法顯示的錯誤。
- 修改在星界能量轉換為UpdateSinglePower函數處理後原碼引用舊函數UpdateLunarPower所導致的錯誤。
- 星星可以改變一個圖案，看看更多「星星」的感覺。
- 調整職業資源高亮邏輯：狂怒戰士怒氣打暴怒技能，85以上高亮，若天賦有點大屠殺，則70以上高亮
- 調整職業資源高亮邏輯：暗牧瘋狂值，若天賦點了殘遺虛無，則65以上就高亮。
- 調整職業資源高亮邏輯：平衡德星能達到星湧技術40星能需求就高亮
---
#### [腿] 2016.08.27
- EA_Config2 內的變數只會成為首次安裝的預設值，之後的所有變更將存入 EA_Config 檔案並作為下次載入之來源。簡單來說，每次更新版本時，都會保留屬於玩家自己的設定。遊戲輸入可以 EA_Config.變數名稱=指定內容的格式來變更並儲存。
- 設定圖示顯示增加了控制變數OPTION_ICON，在/eam小地圖切換的同時也更改了該變數作為後續參考。
- 增加參數 /eam showeaconfig, /eam showeaposition 來顯示玩家設定內容
- 修正簡體版、英文版本化文件內容錯誤導致星能量界無法顯示
- 獵人寵物集中值到圖形介面內做修改式切換，並刪除HUNTER_ShowPetFocus變數
-即使修改點擊只顯示玩家施放之選項仍然會顯示別人增減益的錯誤(自身變數未正確儲存) (有問題的BUFF/DEBUFF ID必須刪除重建)
-value Display,value,value3的功能以下一個設備EA_Config.ShowAuraValueWhenOver來決定是否顯示。目前預設下一個設備為1000
- *[未完成]*:自身/目標的BUFF/DEBUFF倒數N高亮提示秒
- *[未完成]*：嘗試將特殊資源與自身BUFF分開
- *[未完成]*:能源框架脫戰後消失
---
#### [腿] 2016.08.22
- 設定圖示可用/小地圖切換啟用/關閉
- 設定圖示可以右鍵移動（拖曳後的新位置將會被暴雪自動儲存到各角色下的版本面-local.txt，上線時會自動還原到最後位置）
- 新增：輸入 /eam scdremovewhencooldown 直接 SwitchEA_Config2.SCD_RemoveWhenCooldown 變數控製冷卻行為框架
（true表示單一技能冷卻完成即消失，false表示完成即使也不消失）
(不會存檔，下次登入時仍會繼續Addons\EventAlertMod\EventAlertMod.lua內的設定)
- 新增：輸入/eam scdnocombatstillkeep直接EA_Config2.SCD_NocombatStillKeep變數來控製冷卻框架行為（true表示分割戰鬥仍然保持框架，false表示分割戰鬥框架消失）（不會存檔指標，後續登入切換時仍會進行基礎上的加值掃描設定。
- 若計時器若在框外(0.65倍框體大小)，則可提供數字大小調大(0.45倍框體大小)；計時器若在框外(0.5倍框體大小)，則可提供數字大小調小(0.3倍框體大小)
- 在增減益下方顯示value1,value2,value3(若有的話),期能顯示吸收值
- 修改:當技能額外提示輸入了非職業之技能ID時，使自身增減益的模組的一些BUFF產生錯誤，包含了不顯示時間或不正確的時間。
-：條件式團體技能的存檔未納入新的特殊能量代碼，導致無法正確回應玩家的設定。 （加入薩滿元能MAELSTROM、秘法充能ARCANE_CHARGES、惡魔獵人的魔怒FURY、魔痛PAIN）
---
#### [腿] 2016.08.16
- 惡魔獵人增加PAIN能量(坦克)
- 調整框架文字比例（隨圖示大小比例調整）
- 在小地圖附近增加一個齒輪圖示可點選開啟主設定視窗，並在鼠標懸停時顯示提示說明
---
#### [腿] 2016.08.11
- :更新符文函數內的一行修改程式碼在DK登入遊戲時會造成報錯
- 修改:充能型技能在SCD_RemoveWhenCooldown啟用時，只消耗一次會隱藏框架的問題。
- 條件式群體技能內的天賦改為專精，增加為4個，並顯示專精名稱。依最大專精數量顯示
- 增加惡魔獵人相關計畫碼
---
#### [腿] 2016.08.09
- 調整：DK符文框架脫戰後消失
- 調整：DK符文框架附掛在自身BUFF的上方，並與BUFF同方向增長
- 調整：DK符文冷卻倒數數字比例調小
- 調整：刪除EventAlertMod.lua內DK_ShowRunes變數，改為在圖形介面上啟用關閉
- 新增：寵物BUFF/DEBUFF支持，以自身BUFF/DEBUFF模組顯示
- 補充說明：寵物技能冷卻支持，以技能模組冷卻顯示(已前期增加，但未加入說明)
- 修改特殊職業資源取消勾選現在能立即生效
- : 修改預設魔法ID因應版本刪除過去的魔法ID並加入大量7.0魔法ID（可能無法滿足較差）
---
#### [腿] 2016.08.01
- 調整DK符文顯示大小，解決卡頓問題
- BUFF與DEBUFF的滑鼠提示不再只是技能說明，而是當前的狀態數值，冷卻的框架則維持技能說明
- 突出計數避免小於2皆不顯示計數值，出現1的情況。
- 連擊點數若為6則以6為高亮值，連擊點數若為8或5則以5做為高亮值
-若職業為盜賊則將能量的OFFSET由-2-1
- 將尺寸調整改為整數
---
#### [腿] 2016.07.27
- 群體條件技能提示可以正常指定顯示模式了，並加入新的特殊能量支持
- 新增法術時，預設僅顯示為玩家本人施放的BUFF/DEBUFF(點法術後的齒輪可以可見此選項)
- 啟用倒數N秒後顯示修改小數時使特殊屬性也出現小數點的問題(以timeLeft~=floor(timeLeft)來錯開)
- 修改EA_Config2.IsKeepGlowSCD無法相容的問題
- 增加鼠標提示。
並以EA_Config2.ICON_APPEND_SPELL_TIP變數位作為開關
- 初始預設關閉所有職業能量特殊
- 初始預設關閉斬殺提示(星芒閃光)
- 「圖示位置選項」按鈕更名為：「圖示位置與職業能量特殊」（簡體：「圖示位置與特殊能量」）
為了讓大家知道去哪邊啟用關閉這些特殊電源。
- EA_Config2變數更名：
-- 脫離戰鬥後是否保持技能冷卻框架
SCD_NocombatStillKeep=真，
-- 當冷卻框架之技能達到可施放條件時高亮SCD_GlowWhenUsable = true ,
-- 單一完成技能冷卻即移除(true:要移除/false:不移除)SCD_RemoveWhenCooldown= true,
-- 剩餘顯示多少秒開始使用小數點型號(使用0則完全不會有小數點)UseFloatSec= 1,
-- 是否顯示死騎符文(true:/false:不顯示)DK_ShowRunes = false,
-- 是否顯示獵人寵物集中值HUNTER_ShowPetFocus= true,
-- 獵人寵物集中值高亮條件值(0表示不高亮)HUNTER_GlowPetFocus = 50,
---
#### [腿] 2016.07.26
- 新增秘法充能資源(頂高亮)
- 新增薩滿元能資源(頂部高亮)
---
#### [腿] 2016.07.25
- 戰士/熊因怒氣歸零時不會觸發UNIT_POWER，導致怒氣框架歸零後無法消失，所以增加UNIT_FRUQUENT事件來刷新怒氣框架。
- 死騎符文顯示6的問題。由於CreateFrames_SpecialFrames_Show內判定錯誤導致沒有刷新。已修改。符文顏色隨專精轉換。
- 在EventAlertMod.lua內的EA_Config2增加一個變數:DK_ShowRunes來決定是否顯示符文。 (true:顯示/false:不顯示)
- 對應武僧目前花生只有能量，風行有能量/真氣，織霧只有法力沒有能量真氣做對應的調整。
- 增加獵人寵物集中是否顯示的變化數，由EA_Config2.HUNTER_ShowPetFocus來決定
- 增加獵人寵物集中值高亮條件值, 0表示不顯示高亮,預設值50。 (寵物基本攻擊50集中以上有增傷)
- 暗牧瘋狂值達到上限會高亮
- 小數點變數變更為UseFloatSec，表示低於此秒數將使用小數點同時顯示若0則表示完全不會顯示
- 鳥D日月能移除，極限下星能。
# [ChangLog](https://github.com/ziyuefan/EventAlertModRemake/blob/main/changelog.txt "ChangLog")
# [ScreenShot](https://github.com/ziyuefan/EventAlertModRemake/blob/main/README.md#截圖 "ScreenShot")

##命令列

## 以下指令說明不分大小寫：

**/eam SCDRemoveWhenCooldown**

*開關型完成指令，技能冷卻圖示在冷卻後移除(true表示要移除;false表示不移除)*

**/eam SCDNocombatStillKeep**

*開關型指令，技能冷卻圖示在脫離戰鬥後是否仍顯示(true保持顯示;false脫戰不顯示)*

**/eam SCDGlowWhenUsable**
*開關型指令，技能冷卻是否在可用時高亮(true表示可用時高亮，false則否)
該指令特別說明其使用IsUsableSpell()判斷，如果該指令因為資源或
有減益導致無法施放但無法滿足其技能條件，則不會高亮距離不在此限*

**/eam MiniMap [重設]**

*開關型指令，用於顯示設定齒輪顯示與否，加上重設強制定位定位到小地圖左下角*
**/eam UpdateInterval n**

*設定更新頻率，越小越快，若有團戰無法疲勞狀況請加大此數值，預設0.1S（0.1 ~ 1秒）*

**/eam IconAppenSpellTip**

*開關形指令、圖示是否在滑鼠移開時顯示指令指令*

**/eam ShowRunesBar**

*開關型指令，用於決定是否顯示死騎符文列(2020/10/18新增)*

**/eam StackFontSize nSize**

*指令以改變上層資料大小(不分大小寫,也可以/eam sfs nSize代替)*

**/eam TimerFontSize nSize**
* 以改變數字大小（不分大小寫，也可以/eam tfs nSize代替）*

**/eam SNameFontSize nSize**

* 以改變作用名稱大小(不分大小寫,也可以/eam nfs nSize代替)*

# [ChangLog](https://github.com/ziyuefan/EventAlertModRemake/blob/main/changelog.txt "ChangLog")

## 截圖

![EAM 主](https://truth.bahamut.com.tw/s01/202008/1982fcd16ac80aaddfeb299f57a71e94.JPG)
![EAM 選項](https://truth.bahamut.com.tw/s01/202008/cc3c05665af5fe7e3dae3dd5caa5acb5.JPG)
![EAM 自己](https://truth.bahamut.com.tw/s01/202008/226588adaa20b9640c7cc00e8d8b6561.JPG)
![EAM 目標](https://truth.bahamut.com.tw/s01/202008/0b6c52fcdf6fa73ac1d84c5a0198557f.JPG)
![EAM其他](https://truth.bahamut.com.tw/s01/202008/83af52716595ce311f7142f6085a1945.JPG)
![EAM 詳細選項](https://truth.bahamut.com.tw/s01/202008/21cfb5148289c4480beca22cbf5e3c4a.JPG)
![EAM SCD](https://truth.bahamut.com.tw/s01/202008/1dd0d978d4daa6d4b5aab7b6308671d8.JPG)
![EAM組](https://truth.bahamut.com.tw/s01/202008/198e63977a8ace11423675524c90f1d3.JPG)
![EAM群組詳細資料](https://truth.bahamut.com.tw/s01/202008/07c24ff7bc0d14fe9381b96f50905f52.JPG)
![EAM小地圖](https://truth.bahamut.com.tw/s01/202008/154db1c0ef239cd20035d3b91c2a140f.JPG)
![EAM小地圖提示](https://truth.bahamut.com.tw/s01/202008/f1ee8bd0327ecd95f6d2ffea2f06d7ae.JPG)

# [ChangLog](https://github.com/ziyuefan/EventAlertModRemake/blob/main/changelog.txt "ChangLog")
# [CommandLine](https://github.com/ziyuefan/EventAlertModRemake/blob/main/README.md#命令列 "CommandLine")
# [ScreenShot](https://github.com/ziyuefan/EventAlertModRemake/blob/main/README.md#截圖 "ScreenShot")
## Retail 12.1 AuraContainer 狀態（2026-07-26）

- TOC 同時宣告 `120007, 120100`，支援共享實體專案的 12.0.7 Legacy 與 12.1 Native 分流。
- 12.1 使用 Blizzard `AuraContainer`／`AuraButton` 追蹤與顯示 Aura；EAM 不解析 `UNIT_AURA` Secret payload，也不建立 Native AuraState。
- 設定頁會顯示目前 Aura backend、戰鬥 pending 狀態與手動重建按鈕；流程面板提供「12.1 Aura」suite。
- 離線 mock 通過不等於 PTR 實機通過。完整架構、限制與簽收項目見 `Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`。

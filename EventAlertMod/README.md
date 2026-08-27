# EventAlertMod Retail 12.1 (EAM)

[![GitHub](https://img.shields.io/badge/source-GitHub-181717)](https://github.com/ziyuefan/EventAlertModRemake)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blueviolet)](https://ziyuefan.github.io/EventAlertModRemake/)
[![Release](https://img.shields.io/badge/release-Alpha%208.2-orange)](https://github.com/ziyuefan/EventAlertModRemake/releases)
[![Retail](https://img.shields.io/badge/WoW-Retail%2012.1-blue)](https://github.com/ziyuefan/EventAlertModRemake)
[![Interface](https://img.shields.io/badge/Interface-120007%20%7C%20120100-brightgreen)](https://github.com/ziyuefan/EventAlertModRemake)

> 🚀 **專為《魔獸世界：正式服 (Retail 12.1 / 12.0+)》打造的超輕量、零污染、純事件驅動法術監控與戰鬥告警插件！**
>
> 🌐 **官方線上說明文件與導航中心**：[https://ziyuefan.github.io/EventAlertModRemake/](https://ziyuefan.github.io/EventAlertModRemake/)

---

## 🌟 為什麼選擇現代版 EventAlertMod (EAM)？（四大差異化核心優勢）

| 傳統法術監控 / 複雜大型插件 | 現代重構版 EventAlertMod (EAM) |
| :--- | :--- |
| ⚠️ **沉重且佔用資源**：大量背景 OnUpdate 輪詢、吃記憶體、引發戰鬥掉幀。 | ⚡ **極致輕量與零負擔**：純事件驅動架構，全面引入物件池技術（State Pools），消滅 GC 記憶體垃圾。 |
| ❌ **容易受污染報錯**：12.0+ 暴雪引入 Secret Values 後，常常在戰鬥中報錯噴黃字或引發 UI 異常。 | 🛡️ **暴雪 12.0+ 終極安全防護**：獨家採用原生 C-Level `StatusBar:SetValue` 直通渲染技術，絕不觸發 Taint 污染。 |
| 🔄 **設定繁瑣、需匯入字串**：需手動到網站翻找 WA 字串或手寫 Lua 條件判斷。 | 🎯 **直覺易用、秒加監控**：滑鼠停在任何技能、光環或物品上按 **`Ctrl + Alt`** 一秒加入，無需查 ID。 |
| 🐢 **速度顯示不準確**：傳統插件無法偵測 10.0+ / 11.0+ / 12.0+ 飛龍騎術的真實衝刺速度。 | 🏃 **業界唯一：四合一速度淬鍊**：專屬對接 `C_PlayerInfo.GetGlidingInfo()`，完美支援 **830%~1400%** 動態極速！ |

---

## ✨ 八大獨立告警模組 (8 Independent Alert Modules)

EAM 擁有 8 個完全解耦、獨立排版、自由拖曳的專業監控模組：

1. 🔮 **自身光環 (Player Buff / Debuff)**：監控自身增益與減益，支援堆疊層數與高精度倒數。
2. 🎯 **目標光環 (Target Buff / Debuff)**：精確監控當前目標之光環、控制與 Debuff 狀態。
3. ⚔️ **跨職業光環 (Cross-Class / Target Cast)**：監控敵方關鍵爆發或隊友重要增益。
4. ⏳ **技能冷卻 (Spell Cooldown)**：精確監控技能冷卻與充能層數；支援圓形環狀進度條 (`Radial Mode`) 與框外線性條 (`TOP/BOTTOM/LEFT/RIGHT`)。
5. 🎒 **物品冷卻 (Item Cooldown)**：飾品、主動使用裝備與消耗品冷卻監控。
6. 🌋 **地面效果 (Ground Effect)**：監控玩家施放的無光環地面範圍技能（如死亡凋零、褻瀆、冰霜之球、反魔法立場），支援天賦法術族群智能對齊。
7. ⚡ **玩家職業資源 (Player Resource)**：支援全 13 職業、40 組專精、17 種資源獨立節點（法力、怒氣、能量、連擊點、真氣、狂亂、符能、奧術充能、靈魂裂片、神聖能量、精華等）。
8. 📊 **角色屬性與吸收量 (Player Stats & Absorbs)**：全方位即時監控 18 種角色數值（主屬性、副屬性、四合一速度、護甲值、總吸收盾量與治療吸收量）。

---

## 🎨 現代化視覺與極致操作體驗

- 🐮 **經典奶牛頭位置預覽**：排版模式下以經典奶牛頭圖示 (`Spell_Nature_Polymorph_Cow`) 清楚標記 8 大告警框架定位。
- 🖼️ **全模組自訂替代圖示 (Custom Icon Override)**：所有模組均可輸入官方 FileID（例如 `132307`）或材質路徑，自訂取代預設圖示，並附即時動態預覽方塊與 Wago.tools 查詢指引。
- 💀 **死亡騎士符文儀表板**：依專精動態切換專屬圖示，內建 6 格微型充能冷卻條（0%..100% 平滑動畫）與 `/eam rune` 槽位診斷視窗。
- ⚡ **60fps 全方位即時熱預覽**：調整尺寸、間距、透明度、轉圈動畫、文字大小等，畫面上即時動態響應，非戰鬥不需 `/reload`。
- 💬 **全介面控制項懸停提示 (Hover Tooltips)**：所有按鈕、核取方塊、滑桿、編輯框與選單均附帶直觀指引，使用門檻為零。
- 🎨 **11 套精美主題風格**：魔獸經典 (預設)、Borland 亮藍黃字、DOS CRT 復古黑綠、曜石黑、賽博龐克等風格自由切換。
- 🚨 **進入戰鬥紅框閃爍**：提供全螢幕戰鬥進入警示動畫與即時測試按鈕。
- 📦 **Profile 設定檔跨角色分享**：支援 8 大分類自選項目匯出／匯入（EAMAP1 JSON / Base64 編碼），附防禦性白名單校驗。
- 🌐 **完整多國語系支援**：繁體中文 (zhTW - 嚴格對齊台灣官方術語：致命、加速、臨機應變)、簡體中文 (zhCN)、英文 (enUS)、韓文 (koKR)、俄文 (ruRU)。

---

## 📸 介面圖文導覽與功能展示 (Feature & UI Showcase)

### 1. 主設定與系統選單 (Main Options & System Preferences)

| 主設定面板 (Main Options) | 功能模組開關 (Module Options) | 關於插件資訊 (About Panel) |
| :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/01_%E4%B8%BB%E8%A8%AD%E5%AE%9A%E9%9D%A2%E6%9D%BF_MainOptions.jpg" width="100%" alt="EAM 主設定面板" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/02_%E5%8A%9F%E8%83%BD%E6%A8%A1%E7%B5%84%E9%96%8B%E9%97%9C_ModuleOptions.jpg" width="100%" alt="功能模組開關" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/03_%E9%97%9C%E6%96%BC%E6%8F%92%E4%BB%B6%E8%B3%87%E8%A8%8A_AboutPanel.jpg" width="100%" alt="關於插件資訊" /> |
| 整合主題/音效/語系選單、光環後端切換與全域開關 | 8 大功能模組獨立事件監聽與資源開關 | 插件版本、作者資訊、API 基準 (12.1.0 PTR) 與專案連結 |

| 11 套主題樣式 (Theme Dropdown) | 12 種經典音效 (Sound Dropdown) | 6 大多國語系 (Locale Dropdown) |
| :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/04_%E4%B8%BB%E9%A1%8C%E6%A8%A3%E5%BC%8F%E4%B8%8B%E6%8B%89%E9%81%B8%E5%96%AE_ThemeDropdown.jpg" width="100%" alt="主題樣式下拉選單" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/05_%E6%8F%90%E7%A4%BA%E9%9F%B3%E6%95%88%E4%B8%8B%E6%8B%89%E9%81%B8%E5%96%AE_SoundDropdown.jpg" width="100%" alt="提示音效下拉選單" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/06_%E5%A4%9A%E5%9C%8B%E8%AA%9E%E7%B3%BB%E4%B8%8B%E6%8B%89%E9%81%B8%E5%96%AE_LocaleDropdown.jpg" width="100%" alt="多國語系下拉選單" /> |
| 內建魔獸經典、FF7、WinXP、Borland 等 11 套風格 | 內建 ShayBell、Netherwind、PolyMorphCow 等音效 | 自動偵測、繁體中文 (台灣官方術語)、簡中、英文、韓文、俄文 |

---

### 2. 法術清單、細部條件與階層吸附 (Alert Lists, Conditions & Docking)

| 自身光環與奶牛頭預覽 (Self Aura & Preview) | 技能冷卻與行為覆寫 (Spell Cooldown Overrides) |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/07_%E8%87%AA%E8%BA%AB%E5%85%89%E7%92%B0%E6%B8%85%E5%96%AE%E8%88%87%E7%B4%B0%E9%83%A8%E6%A2%9D%E4%BB%B6%E8%A8%AD%E5%AE%9A_SelfAuraConditions.jpg" width="100%" alt="自身光環清單與細部條件設定" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/08_%E6%8A%80%E8%83%BD%E5%86%B7%E5%8D%BB%E7%9B%A3%E6%8E%A7%E8%88%87%E8%A1%8C%E7%82%BA%E8%A6%86%E5%AF%AB%E8%A8%AD%E5%AE%9A_SpellCooldownOptions.jpg" width="100%" alt="技能冷卻監控與行為覆寫設定" /> |
| 自身法術清單、奶牛頭排版預覽、層數/高亮/紅字限制、12.1 光環事件音效與自訂圖示 | 技能冷卻清單、完成後移除/非戰鬥顯示/可用時高亮三態覆寫與自訂替代圖示 |

| 物品冷卻設定 (Item Cooldown) | 三級階層吸附與地面效果 (Ground Effect Docking) |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/09_%E7%89%A9%E5%93%81%E5%86%B7%E5%8D%BB%E7%9B%A3%E6%8E%A7%E8%88%87%E7%B4%B0%E9%83%A8%E6%A2%9D%E4%BB%B6%E8%A8%AD%E5%AE%9A_ItemCooldownOptions.jpg" width="100%" alt="物品冷卻監控設定" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/10_%E5%9C%B0%E9%9D%A2%E6%95%88%E6%9E%9C%E7%93%A3%E6%8E%A7%E8%88%87%E4%B8%89%E7%B4%9A%E9%9A%8E%E5%B1%A4%E5%90%B8%E9%99%84_GroundEffectDocking.jpg" width="100%" alt="地面效果監控與三級階層吸附" /> |
| 裝備與飾品冷卻清單、層數閾值、優先級與自訂圖示 | 主選單 ➔ 清單 ➔ 細部條件無縫平滑貼合 (APPEND Docking) 與動態 Tooltip 擷取 |

---

### 3. 職業資源、角色屬性與排版設定 (Resources, Stats & Layout)

| 玩家職業資源設定 (Player Resource Panel) | 角色屬性與吸收量監控 (Player Stats & Absorbs) |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/11_%E7%8E%A9%E5%AE%B6%E8%81%B7%E6%A5%AD%E8%B3%87%E6%BA%90%E8%A8%AD%E5%AE%9A%E9%9D%A2%E6%9D%BF_PlayerResourcePanel.jpg" width="100%" alt="玩家職業資源設定面板" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/12_%E8%A7%92%E8%89%B2%E5%B1%AC%E6%80%A7%E8%88%87%E5%90%B8%E6%94%B6%E9%87%8F%E7%9B%A3%E6%8E%A7%E9%9D%A2%E6%9D%BF_PlayerStatsPanel.jpg" width="100%" alt="角色屬性與吸收量監控面板" /> |
| 符文/符能與各專精能量條、顯示模式、錨點定位、16 項細部滑桿與 Secret 原生保護 | 18 項核心屬性取值、跑速/泳速/飛速/飛龍速度、圖示/進度條開關與警戒值設定 |

| 告警框架排版與懸停提示 (Layout & Tooltips) | 職業 Profile 分享與匯入匯出 (Profile Codec) |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/13_%E5%91%8A%E8%AD%A6%E6%A1%86%E6%9E%B6%E4%BD%8D%E7%BD%AE%E6%8E%92%E7%89%88%E8%88%87%E6%87%B8%E5%81%9C%E6%8F%90%E7%A4%BA_LayoutPositionOptions.jpg" width="100%" alt="告警框架位置排版與懸停提示" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/14_%E8%81%B7%E6%A5%ADProfile%E5%88%86%E4%BA%AB%E8%88%87%E5%8C%AF%E5%85%A5%E5%8C%AF%E5%87%BA%E9%9D%A2%E6%9D%BF_ProfileCodecPanel.jpg" width="100%" alt="職業Profile分享與匯入匯出面板" /> |
| 尺寸/間距/字型/透明度滑桿、7 大框架成長方向、充能列設定與控制項懸停 Tooltip 指引 | 8 大自選項勾選、快捷按鈕與 EAMAP1 Base64 字串匯出/預覽/合併套用/取代套用 |

---

## ⌨️ 命令列與斜線指令 (Command Line Reference)

EAM 提供豐富完整的斜線命令，主入口為 `/eam` 或 `/eventalertmod`（不分大小寫）：

| 指令 | 縮寫 / 別名 | 說明 |
| :--- | :--- | :--- |
| `/eam` 或 `/eam opt` | `/eam option`, `/eam options` | 開啟 EAM 主設定選單 |
| `/eam reset` | `/eam resetpos`, `/eam center` | **將 EAM 主視窗重置回螢幕正中央**（解決視窗被拖出畫面找不到的問題） |
| `/eam list` | 無 | 顯示目前職業已啟用的監控清單（自身、目標、冷卻、物品、地面效果） |
| `/eam add <spellID>` | `/eam add player <spellID>` | 新增指定法術 ID 至「自身光環」監控清單 |
| `/eam add target [spellID]` | 無 | 新增「目標光環」監控；若不輸入 ID 則開啟手動輸入與候選視窗 |
| `/eam add cd <spellID>` | `/eam add cooldown <spellID>` | 新增指定法術 ID 至「技能冷卻」監控清單 |
| `/eam add item <itemID>` | `/eam add itemcooldown <itemID>` | 新增指定物品 ID 至「物品冷卻」監控清單 |
| `/eam remove <spellID>` | `/eam remove <player\|target\|cd\|item> <ID>` | 從指定監控類別中移除指定法術或物品 ID |
| `/eam lookup <名稱>` | `/eam l <名稱>` | 依關鍵字模糊查詢目前職業可用法術候選與 Spell ID |
| `/eam lookupfull <全名>` | `/eam lf <全名>` | 依完整名稱精確查詢目前職業可用法術候選與 Spell ID |
| `/eam showcast` | `/eam showc` | 開始或停止記錄本次登入成功施放的法術（方便查詢自己剛放的技能 ID） |
| `/eam profile` | `/eam profile export`, `/eam profile import` | 開啟 Profile 設定檔匯出／匯入與字串分享面板 |
| `/eam rune` | `/eam runes`, `/eam probe rune` | 開啟死亡騎士 6 格符文槽位即時狀態、充能秒數與診斷 JSON 視窗 |
| `/eam unitpower background <KEY>` | 無 | 標記指定背景資源缺少事件，啟動 0.5s demand-driven 共用取樣器 |
| `/eam doctor` | `/eam validate` | 執行客戶端 API 邊界與運行環境診斷報告 |
| `/eam test [suite]` | `/eam test live` | 開啟遊戲內流程測試面板，或執行指定測試套件 (`quick/core/boundary/aura121/all/live`) |
| `/eam debug` | `/eam export` | 開啟系統狀態與精簡 AI 除錯報告輸出視窗 |
| `/eam debug ground <spellID>` | 無 | 測試並除錯特定地面技能之 Tooltip 持續時間解析 |
| `/eam show` / `/eam showtarget` | `/eam shows`, `/eam showt` | 顯示 Retail 12.1 安全加入光環之操作指引（滑鼠懸停按 Ctrl+Alt） |
| `/eam help` | `/eam ?` | 列出所有可用斜線命令說明 |

---

## 🖱️ 快速操作指引：滑鼠懸停加入監控 (Ctrl+Alt Quick Add)

在遊戲中，您可以完全不需手動查詢法術 ID：
1. 將滑鼠懸停於自身頭像、目標頭像的光環圖示，或快捷列上的技能/巨集/物品上。
2. 同時按下鍵盤上的 **`Ctrl + Alt`** 組合鍵。
3. 畫面即刻彈出 EAM 專屬加入視窗，一鍵將其指派至自身光環、目標光環、技能冷卻或物品冷卻監控清單中！

---

## 📦 安裝說明 (Installation)

1. 前往 [GitHub Releases](https://github.com/ziyuefan/EventAlertModRemake/releases) 下載最新版本之 `EventAlertMod_MN_*.zip`。
2. 解壓縮後將 `EventAlertMod` 資料夾放置於魔獸世界安裝目錄：
   - 正式服路徑：`World of Warcraft\_retail_\Interface\AddOns\EventAlertMod`
3. 啟動遊戲，在角色選擇畫面確認「插件」清單中已勾選啟用 `EventAlertMod`。

---

## 📜 版本更新歷史 (Beautified CHANGELOG.TXT)

<details open markdown="1">
<summary><b>🔥 Retail 12.1.0 重構與 Alpha 系列更新紀錄 (點擊展開/收合)</b></summary>

### 🌟 [Retail 12.1.0 Alpha 8.2] - 2026.08.27
- **LibSharedMedia-3.0 (SharedMedia) 素材庫全面整合與動態探測 (Full LSM Integration & Dynamic Discovery)**：
  - 全面接入社群廣泛使用的 LibSharedMedia-3.0 素材生態，完整支援所有第三方 SharedMedia 音效包、字型包與材質包。
  - 實作 `MediaService.ensureLSM()` 動態探測機制與 `PLAYER_LOGIN` 延遲同步刷新，徹底解決 EAM 早於其他 SharedMedia 擴充插件載入時音效清單被凍結在初始 12 種內建音效的問題。
  - 同時查詢 `lsm:List("sound")` 與 `lsm:HashTable("sound")` 雙軌資料來源並自動去重，保證 100% 完整抓取所有第三方 SharedMedia 註冊音效。
  - 支援安全雙軌音效播放 (`MediaService.playSound`)：無縫相容數字 `FileDataID`、原生 `SoundKitID` 與自訂字串 `FilePath` (.ogg / .mp3) 檔案。
  - 12.1 Native Aura 原生光環規則編譯器 (`AuraRuleCompiler`) 接入 `MediaService`，光環觸發時亦可播放 LSM 自訂音效。
- **全域字型熱套用與存檔修復（免 /reload 即時生效）(Zero-Delay Font Application & SavedVariables Whitelist)**：
  - 解除字型存檔白名單限制：`SavedVariables.lua` 放行所有通過 LSM 註冊的自訂字型名稱，防止重登、重載或切換專精後被強制還原為預設字型。
  - 畫面預覽圖示即時聯動：更換字型時，畫面上的奶牛頭與位置預覽圖示 (Preview Icons) 立即同步重繪新字型。
  - 12.1 Native Aura 規則指紋補齊：將 `fontFamily` 納入 Native 佈局指紋 (`buildLayoutFingerprint`)，修復過去因指紋相同而略過原生容器重建的問題。
  - 全子系統文字廣播聯動：透過 `EAM_FONT_FAMILY_CHANGED` 事件，同步即時刷新一般告警圖示 (`Renderer`)、能量條文字 (`PowerRenderer` / `PlayerResourceService`) 與人物屬性文字 (`PlayerStatService`)，選取字型後畫面上所有文字零延遲即時套用。
  - 職業資源文字面板 (`PlayerResourcePanel`) 之字型切換按鈕全面支援循環切換所有 SharedMedia 字型。
- **UI 下拉選單長清單自適應捲動容器 (Scrollable Dropdown Menus with MouseWheel)**：
  - 實作通用自適應捲動選單 `buildScrollableDropdownMenu`：當 SharedMedia 包含數十或數百種字型／音效時，選單自動限制高度為 10 筆並啟用 `UIPanelScrollFrameTemplate` 捲軸與滑鼠滾輪支援，版面整潔不破圖。
  - 展開音效與字型選單時自動以 `forceRefresh` 模式向 LSM 抓取最新註冊素材清單。

### 📌 [Retail 12.1.0 Alpha 8.1] - 2026.08.26
- **技能冷卻純透明度（Alpha=0）隱藏模式與全監控冷卻預先錨定 (Persistent Pre-anchoring & Zero-Alpha Cooldown Mode)**：
  - 徹底解決技能冷卻在戰鬥中首次施放無法建立框架或延遲至脫戰後才出現的架構問題。
  - 進入世界、切換天賦或載入設定時，非戰鬥狀態下自動預先建立所有已監控之技能冷卻與物品冷卻 Frame，並完成精確座標計算。
  - 冷卻完成時透過 `SetAlpha(0)` 隱藏圖示，保留 Frame 結構與座標常駐，避免戰鬥中動態釋放與排版重算；冷卻觸發時瞬間恢復 `SetAlpha(targetAlpha)`，實現 0.00ms 零 GC 零排版延遲且 100% 免疫戰鬥鎖定。
- **角色屬性與副屬性戰鬥中防歸零修復 (Combat Stat Cache & Multi-Tier API Fallback)**：
  - 解決 Retail 12.0+/12.1+ 進入戰鬥後呼叫原生 Unit / Stat API 受限回傳 Secret Number 導致力量、敏捷、智力、耐力、致命、加速、精通、臨機應變等數值歸零問題。
  - 建立全 18 項屬性 `lastKnownStats` 記憶體快取表，並在登入、切換專精、更換裝備及脫離戰鬥時自動執行預熱 (`prewarmStats`)，戰鬥中若遇受限環境自動無縫回退至最後有效真實數值。
  - 副屬性全面補齊系別 API (`GetCritChance` / `GetSpellCritChance` 等) 與等級評級轉換公式容錯。
- **角色屬性依職業獨立設定 (Per-Class Player Stat Profiles)**：
  - 角色屬性監控全面升級為「依職業獨立配置設定」：每種職業（例如聖騎士、法師、戰士、牧師等）擁有專屬獨立的屬性監控項目開關、圖示大小、字型、閾值與獨立位置座標。
  - 切換不同職業角色時自動無縫載入該職業設定，設定面板標題即時標註當前職業名稱（例如「★ 角色屬性與吸收量監控 [聖騎士]」）。
- **吸收盾與治療吸收量雙軌偵測強化 (Dual-Channel Shield & Heal Absorb Detection)**：
  - 強化總吸收盾量 (`totalAbsorb`) 與治療吸收量 (`healAbsorb`) 取值核心：支援原生 Unit API 與 `C_UnitAuras` 增益/減益點數 (`aura.points`) 雙軌即時累加運算，徹底解決吸收盾無法顯示問題。
  - 補齊 `UNIT_HEAL_ABSORB_AMOUNT_CHANGED`、`UNIT_HEALTH`、`UNIT_MAXHEALTH` 與 `PLAYER_SPECIALIZATION_CHANGED` 事件監聽。
- **光環模組支援護盾吸收量即時顯示 (Aura Shield Absorb Amount Display)**：
  - 光環監控核心 (`AuraService`) 自動從 `C_UnitAuras` 提取護盾類光環（如真言術:盾、冰甲護盾、靈魂汲取等）的即時剩餘吸收盾數值 (`state.absorbAmount`)。
  - 渲染器 (`Renderer`) 於光環圖示右下角疊加層精確格式化顯示剩餘吸收盾量（如 45.2k、1.2M），若同時具備多層數則自動並列顯示（如 3(45k)）。
- **圖示物件池 (IconPool) 擴容與安全放行**：
  - 預熱池容量由 16 擴增至 64，並在池耗盡時直接安全呼叫 `createIcon` 建立，杜絕戰鬥中回傳 nil。

### 📌 [Retail 12.1.0 Alpha 8.0] - 2026.08.25
- **角色屬性與吸收量監控升級 (Independent Positioning & Grow Direction)**：
  - 新增「整體排列方向」下拉選單（向右、向左、向上、向下），支援整組屬性即時方向重構。
  - 支援各單項「獨立自訂位置與獨立拖曳」：每項屬性可勾選啟用獨立位置，具備專屬 X/Y 軸像素滑桿，並提供「移動此單項」與「移動所有屬性」按鈕，在畫面上直接以滑鼠拖曳定位並即時雙向同步座標。
  - 取消圖示純文字自適應排版與指定位置 (Iconless Adaptive Layout & Positioning)：即使取消顯示圖示，純文字標籤與數值依然完整支援指定「獨立自訂位置」或依設定「整體方向」自動延伸排版。
  - 支援無圖示排版方位自訂：在關閉圖示時可選擇數值相對於名稱之「上方/下方/左側/右側」佈局。
  - 移動模式保護機制：開啟拖曳錨點時自動顯示高亮外框與拖曳提示，防止高頻計時器重設位置。
  - 修復飛龍模式飛速圖示黑框問題：改用數值型 FileDataID 4667307 與動態 API 獲取原生圖示。
  - 重構左右列表與細部表單雙向同步，增加選中條目金框高亮，新增「全選監控」與「全部停用」批次按鈕。
- **主選單排版精確對齊與控制項優化**：
  - 修復「測試閃爍」按鈕覆蓋文字問題，獨立配置於專屬按鈕列。
  - 將「啟用 12.1 原生圓形光環倒數光圈」完整回歸主設定選單核心控制區。

### 🌟 [Retail 12.1.0 Alpha 7.9] - 2026.08.24
- **全介面控制項懸停提示 (Comprehensive UI Hover Tooltips)**：
  - 在全部按鈕、核取方塊、滑桿、下拉選單、輸入編輯框與清單操作列加入直觀的懸停說明提示 (Hover Tooltips)，清晰標註控制項用途、設定範圍與操作指引。
  - 實作通用工具函式 `EAM.UI.setTooltip`，支援純文字、多語系字串與表格綁定，徹底消除介面操作門檻。
  - 覆蓋主設定面板、告警框架排版、法術清單、細部條件、批次輸入、角色屬性、職業資源、功能模組、Profile 分享與除錯中心共 10 大視窗。
- **主視窗螢幕邊界鎖定與一鍵居中重置 (ClampedToScreen & Center Reset Command)**：
  - 主視窗增加 `SetClampedToScreen` 螢幕邊界鎖定，防止拖出畫面無法找回。
  - 新增 `/eam reset` (或 `/eam center` / `resetpos`) 斜線命令、小地圖按鈕中鍵點擊與 Shift+點擊，一鍵將主視窗拉回螢幕正中央。
  - 修正關閉主視窗時在 `closeAllSidePanels` 缺少 `close()` 引發的 nil call 錯誤，實作防禦性 `safeClosePanel` 機制。
- **官方 README 圖文導覽與 GitHub 直連展示 (Visual Showcase)**：
  - 整理 14 張全功能高畫質介面截圖，分類涵蓋系統選單、法術條件與階層吸附、職業資源與屬性排版。

### 📌 [Retail 12.1.0 Alpha 7.8] - 2026.08.24
- **「★ 角色屬性與吸收量監控」全新模組**：
  - 支援 18 種核心屬性取值監控（主屬性：力量、敏捷、耐力、智力；副屬性：致命、加速、精通、臨機應變；輔助與生存：閃避、汲取、速度屬性評級、跑速、泳速、飛速、飛龍模式飛速、總吸收盾量、治療吸收量、護甲值）。
  - 速度類別全面淬鍊：跑速 (`GetUnitSpeed` 地面即時與上限跑速)、泳速 (水下速度)、飛速 (穩定飛行 310%~420%)、飛龍模式飛速 (調用 `C_PlayerInfo.GetGlidingInfo` 專屬 API 取得 830%~1400% 動能滑翔速度)，並以 0.1s 高頻計時器平滑刷新。
  - 繁體中文術語嚴格對齊台灣官方用語（致命、加速、臨機應變）。
  - 獨立二級設定面板：無縫依附主視窗右側並支援同步平滑拖曳；支援個別自訂開關、是否顯示圖示、替代圖示路徑/代碼、圖示大小、數值字型大小、代表名稱字型大小、名稱替代文字、小數位數 (0~2)、大數值簡寫 (k/M)、警戒值上下限紅框警示、進度條開關與獨立框架定位排版。
- **Secret Value 防護與原生 StatusBar Sink 整合**：
  - 針對 Retail 12.0+ / 12.1+ 部分 Unit API 在戰鬥/受污染環境下回傳受保護之 Secret Number，全面加入安全數值檢查，防止 Lua 層運算或格式化報錯。
  - 為屬性框架預建原生 C-Level `StatusBar`，遭遇 Secret 數值時直接將原始數值單向傳入 `StatusBar:SetValue` 展現視覺進度比例。
  - 支援依屬性類別專屬著色（吸收盾天藍、治療吸收紫紅、移速青綠、副屬性金黃、主屬性橙紅、護甲鋼藍）。
- **全模組自訂替代圖示支援 (Custom Icon Override)**：
  - 在自身光環、目標光環、技能冷卻、物品冷卻、地面效果等所有模組細部設定中，新增「自訂替代圖示（代碼或材質路徑）」輸入框、即時動態預覽方塊與 Wago.tools 查詢網址框。
  - 服務層發布告警狀態時優先採用自訂圖示覆蓋原生預設圖示。
- **經典奶牛頭位置預覽 (Classic Cow Head Anchor Preview)**：
  - 拖曳排版位置時改用經典奶牛頭圖示 (`Spell_Nature_Polymorph_Cow`) 作為畫面預覽，並支援 8 大告警框架即時標籤名稱與紅/綠框高亮區分。
- **全方位即時熱預覽 (Live Real-time Config Preview)**：
  - 調整圖示尺寸、水平/垂直間距、透明度、扇形倒數轉圈動畫、轉圈透明度、自身/目標減益色度、法術/倒數/堆疊字型大小、成長方向時，畫面上告警框架與圖示即時 60fps 熱更新響應，無需重啟。
- **進入戰鬥全螢幕紅框閃爍 (In-Combat Fullscreen Red Edge Flash)**：
  - 實作 `UI/CombatFlash.lua` 全螢幕低血/戰鬥紅框閃爍動畫，監聽 `PLAYER_REGEN_DISABLED` 事件觸發戰鬥進入警示，並在主選單提供即時測試按鈕。
- **主題樣式與預設回歸**：
  - EAM 預設主題改回經典魔獸紅色選單按鈕與仿石框邊緣。

### 📌 [Retail 12.1.0 Alpha 7.7] - 2026.08.24
- **子視窗聯動移動錨點**：點擊各類別監控子視窗時，自動在畫面上亮起該模組專屬半透明移動錨點框（標記按住左鍵拖曳），方便玩家直觀拖曳調整在畫面上的定位。
- **排版位置全開模式**：開啟「告警框架位置與排版」視窗時自動亮起全部 7 大框架移動錨點，關閉子視窗或主選單時自動隱藏所有錨點並套用最新座標排版。
- **全二級附屬側窗互斥**：開啟職業資源、除錯中心、Profile 匯入/匯出、功能模組、關於或清單子視窗時，自動關閉其他側邊面板，徹底消除多個側窗堆疊重疊問題。
- **除錯中心與診斷匯出修復**：修正流程測試分頁運行非同步回傳布林值導致的 index error，補全格式化輸出；修正系統診斷報告匯出按鈕調用。

### 📌 [Retail 12.1.0 Alpha 7.5] - 2026.08.23
- **介面佈局重構**：主選單第 7 項目提升為「★ 玩家職業資源設定」，排版位置微調為第 8 項目，除錯類功能統整至 4-Tab「除錯與測試診斷中心」。
- **全視窗快速關閉**：所有視窗右上角加入原生 `[X]` 快速關閉按鈕。
- **階層式無縫吸附 (APPEND Docking)**：主選單 ➔ 清單/排版/資源 ➔ 細部條件/批次輸入 視窗依序向右緊密貼合，並支援多視窗同步平滑拖曳。
- **Profile 分享功能升級**：支援 8 大自選項目匯出／匯入（自身/目標光環、技能/物品冷卻、地面效果、框架排版位置、職業資源設定、一般偏好設定），並提供快捷選取按鈕與預覽區塊分析。
- **職業資源設定即時生效**：設定滑桿與下拉選單數值變更時即時驅動原生渲染器更新，非戰鬥不需 `/reload`。
- **死亡騎士符文強化**：圖示依血魄 (250)、冰霜 (251)、穢邪 (252) 專精動態切換專屬圖示；下方增設 6 格微型充能冷卻條，由排程器平滑驅動；提供 `/eam rune` 槽位診斷與複製視窗。

### 📌 [Retail 12.1.0 Alpha 7.4] - 2026.08.23
- 充能環形版面改用封裝的透明 TGA ring grid；冷卻完成必須先觀測到已消耗充能，再於 `currentCharges` 回到 `maxCharges` 時成立。
- 死亡騎士符文改由 `GetRuneCount`／`GetRuneCooldown` 六槽初始化與 `RUNE_POWER_UPDATE(index, added)` 即時驅動；消耗／恢復更新 0..6 分段，符能仍為獨立資源。
- 地面效果設定會在非戰鬥中編譯 Base／Override／目前 SpellInfo 法術族群；死亡凋零／褻瀆等替換 ID 可命中同一監控項，設定 ID 完全相符時優先。

### 📌 [Retail 12.1.0 Alpha 7.3] - 2026.08.23
- 充能 StatusBar 改以目前可用次數／最大次數顯示，不再讓段數跟著單層恢復時間前進；Secret `currentCharges` 只直送 Blizzard C-level `SetValue` sink。
- 新增框外 TOP／BOTTOM／LEFT／RIGHT 與環形 RING 版面；預設長度／環直徑為圖示 150%、厚度 8px，並依安全 `maxCharges` 顯示分隔線。
- 12.1 環形使用 StatusBar Radial render mode；能力或材質不可用時回退 BOTTOM 線性條。

### 📌 [Retail 12.1.0 Alpha 7.2] - 2026.08.23
- 充能技能仍只在玩家首次成功施放後進入監控，並可對齊儲存 base ID 與目前 override ID。
- `SpellChargeInfo` 改採欄位級 Secret 判讀；安全 current/max 顯示文字，Secret `currentCharges` 則以圖示同寬 StatusBar 接收官方 DurationObject。
- 冷卻技能細部設定隱藏 Aura 專用「僅監控自己施放」，三項冷卻行為按鈕不再重疊。

### 📌 [Retail 12.1.0 Alpha 7.1] - 2026.08.23
- 充能型技能在安全取得充能資料時顯示 current/max，並保留原生 DurationObject 冷卻倒數。
- 無計時時清除並隱藏 CooldownFrame 的 edge／bling，避免技能圖示留下白色空框。
- Glow Border 支援內嵌 `LibButtonGlow-1.0`；自訂顏色、戰鬥首次建框或 library 不可用時回退 EAM 動畫邊框。
- 玩家資源設定面板開關後即時重套用視覺狀態，非戰鬥不需 `/reload`。

### 📌 [Retail 12.1 Alpha 7] - 2026.08.23
- 玩家職業資源改為 17 資源、13 職業／40 組專精候選拓撲；`UNIT_DISPLAYPOWER` 只更新前景，不再因形態切換拆除背景追蹤。
- 補強德魯伊 Bear／Cat／Caster／Moonkin／回 Bear、Energy→ComboPoints renderer ownership、PAIN 專用 legacy key 與模組停用清理。
- 每項資源新增／補齊字型、數字文字大小與位置、方向、尺寸、透明度、排序、前景／背景與數值能力設定；非戰鬥變更即時套用。

### 📌 [Retail 12.1 Alpha 6] - 2026.08.23
- 技能冷卻監控改為只在玩家精確成功施放清單技能後首次 render；新增 `cooldownRemoveAura`、`showSCDOutsideCombat`、`glowSCDWhenUsable` 三項 per-spell 覆寫。
- Target Aura 提供匿名 diagnostics 與明確 `/eam add target` 手動 popup route；不保存 Secret、AuraData、Frame 或猜測 ID。

### 📌 [Retail 12.1 Alpha 5] - 2026.08.14
- 新增 EAMAP1 JSON／Base64 profile codec，含白名單欄位、大小／深度／節點限制、Adler-32 checksum、preview、merge／replace 與 combat guard。
- 新增 STANDARD、ARIALN、MORPHEUS、SKURRI 字型選擇；十一套主題統一控制按鈕底色與邊框。

### 📌 [Retail 12.1 Alpha 4 ~ Alpha 1] - 2026.07 ~ 2026.08
- 12.1 現代化重構首版發布，全面接入原生 AuraContainer 與 Tooltip Ctrl+Alt 快捷監控通道。
- 引入 VectorGraphics / Texture SVG A/B 能力探針與完整流程測試。
- 徹底重構解耦 AuraService、CooldownService、ItemCooldownService、GroundEffectService 五大數據服務。
- 數據服務引入零分配狀態緩衝池（如 AuraStatePool 等），完全消滅運行期 GC 記憶體垃圾。
- 引入 AlertManager 中介控制器與 Scheduler 節流，消除 Layout Churn 與高頻重複計算。
</details>

<details markdown="1">
<summary><b>📜 歷史經典版本摘要 (TWW / DF / SL / Classic) (點擊展開/收合)</b></summary>

- **[Retail 12.0.7] 2026.06**：專精名稱動態本地化重構、五大語系字典補齊；重構地面效果多國語言 Tooltip Scraping；拆分 7 大獨立告警框架。
- **[Classic MOP / Retail TWW] 2025.11**：新增俄語支援；微調顯示秒數小數點進位方式；光環數值依語系支援萬/K/M簡寫。
- **[Retail TWW] 2025.07**：定時更新改由 C_Timer 驅動；PositionFrame 更新頻率優化，大幅降低 CPU 佔用。
- **[Retail DF] 2023.02**：支援喚能師 (Evoker) 職業與龍能 (Essence) 顯示；支援飛龍騎術活力 (Vigor) 提示。
- **[Retail SL] 2020.10**：支援全職業核心能量高亮（真氣、聖能、碎片、狂亂、暴怒怒氣）；支援 DK 符文列切換。
</details>

---

## 📌 相容性與支援邊界 (Compatibility)

- **支援環境**：
  - 《魔獸世界：正式服》World of Warcraft: Retail 12.1.0+ (Interface 120100)
  - 相容通道 Retail 12.0.7+ (Interface 120007)
- **不支援環境**：
  - 經典懷舊服全系列（Classic Era、MoP Classic、TBC Classic、Wrath 等不在本專案支援範圍）。

---

## 🌐 說明文件與相關連結 (Documentation & Links)

- 📖 **GitHub Pages 說明文件導航中心**：[https://ziyuefan.github.io/EventAlertModRemake/](https://ziyuefan.github.io/EventAlertModRemake/)
- 📦 **GitHub 專案原始碼與 Release 發布**：[https://github.com/ziyuefan/EventAlertModRemake](https://github.com/ziyuefan/EventAlertModRemake)
- 📜 **CurseForge 專案發布頁面**：[https://www.curseforge.com/wow/addons/eventalertmod](https://www.curseforge.com/wow/addons/eventalertmod)
- 💬 **WoWInterface 專案發布頁面**：[https://www.wowinterface.com/downloads/info26550-EventAlertMod.html](https://www.wowinterface.com/downloads/info26550-EventAlertMod.html)

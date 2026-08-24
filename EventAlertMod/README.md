# EventAlertMod Retail 12.1 (EAM)

[![GitHub](https://img.shields.io/badge/source-GitHub-181717)](https://github.com/ziyuefan/EventAlertModRemake)
[![Release](https://img.shields.io/badge/release-Alpha%207.8-orange)](https://github.com/ziyuefan/EventAlertModRemake/releases)
[![Retail](https://img.shields.io/badge/WoW-Retail%2012.1-blue)](https://github.com/ziyuefan/EventAlertModRemake)
[![Interface](https://img.shields.io/badge/Interface-120007%20%7C%20120100-brightgreen)](https://github.com/ziyuefan/EventAlertModRemake)

**EventAlertMod (EAM)** 是專為《魔獸世界》正式服（World of Warcraft: Retail 12.1 / 12.0+）全面重構的現代化、極致效能、零污染與純事件驅動法術監控告警插件。

本插件專注於玩家自身與目標光環（BUFF/DEBUFF）、技能冷卻、物品冷卻、地面法術效果、17 種玩家職業資源、18 種角色屬性與吸收量監控，並具備四合一速度淬鍊與全模組自訂替代圖示等豐富功能。現行來源版本標記為 `EventAlertMod_MN_20260824`，發布定位為 **Alpha 7.8 prerelease**。

---

## ✨ 核心特色與架構優勢 (Features)

### 1. 🛡️ Retail 12.0+ / 12.1+ 零污染與 Secret Values 終極防護
- **原生 C-Level StatusBar Sink**：針對 12.0+ / 12.1+ 在戰鬥或受保護環境下可能回傳的 `Secret Number`（受保護數值），EAM 嚴格遵循暴雪安全規範，絕不在 Lua 層進行直接比較、算術運算、字串化或讀回。
- **直通渲染技術**：數值直接單向輸送至暴雪原生底層 `StatusBar:SetValue` 展現視覺進度，徹底杜絕 UI 污染、報錯與戰鬥中斷。
- **分類專屬著色**：支援依屬性類別專屬著色（吸收盾天藍、治療吸收紫紅、移速青綠、副屬性金黃、主屬性橙紅、護甲鋼藍）。

### 2. 🧩 八大獨立告警框架 (8 Independent Alert Modules)
EAM 具備 8 個完全解耦、獨立排版、自由定位的監控模組：
1. **自身光環 (Player Buff / Debuff)**：監控自身觸發之增益與減益，支援堆疊層數與高精度倒數。
2. **目標光環 (Target Buff / Debuff)**：監控當前目標之光環與狀態。
3. **跨職業光環 (Cross-Class / Target Cast)**：監控跨職業、敵方或隊友施放的關鍵光環。
4. **技能冷卻 (Spell Cooldown)**：精確監控技能冷卻與充能層數；支援圓形環狀進度條 (`Radial Mode`) 與框外線性條 (`TOP/BOTTOM/LEFT/RIGHT`)。
5. **物品冷卻 (Item Cooldown)**：飾品、主動使用裝備與消耗品冷卻監控。
6. **地面效果 (Ground Effect)**：監控玩家施放的無光環地面範圍技能（如死亡凋零、褻瀆、冰霜之球、反魔法立場），支援天賦法術族群智能對齊。
7. **玩家職業資源 (Player Resource)**：支援全 13 職業、40 組專精、17 種資源獨立節點（法力、怒氣、能量、連擊點、真氣、狂亂、符能、奧術充能、靈魂裂片、神聖能量、精華等）。
8. **角色屬性與吸收量 (Player Stats & Absorbs)**：全方位監控 18 種角色數值。

### 3. 🏃 四合一速度即時淬鍊 (Refined 4-in-1 Speed System)
精準對接暴雪最新物理狀態 API，徹底解決飛龍騎術無法被傳統 API 捕捉的痛點：
- **跑速 (Run Speed)**：調用 `GetUnitSpeed("player")` 提取 `runSpeed` 與地面即時 `currentSpeed`（100%~220%）。
- **泳速 (Swim Speed)**：調用 `GetUnitSpeed("player")` 提取 `swimSpeed`，水下為 67%~100%+。
- **飛速 (Flight Speed)**：傳統懸浮穩定飛行 `flightSpeed`（310%~420%）。
- **飛龍模式飛速 (Skyriding Speed)**：專屬調用 **`C_PlayerInfo.GetGlidingInfo()`** 提取 `forwardSpeed` 換算 **830%~1400%** 即時滑翔衝刺速度！
- **0.1 秒高頻計時器**：起跑、跳水、起飛或俯衝加速時，數值與底層進度條均以 0.1s 高頻即時流暢響應。

### 4. 🎨 全模組自訂替代圖示 (Custom Icon Override)
- 在所有 8 大模組的細部設定中，均提供「自訂替代圖示（代碼或材質路徑）」輸入框。
- 支援輸入任何官方 FileID（例如 `132307`）或自訂材質路徑，並附即時動態預覽方塊與 Wago.tools 查詢指引，可隨心自訂專屬視覺風格。

### 5. 💀 死亡騎士專用符文引擎 (DK Runes Engine)
- 依血魄 (250)、冰霜 (251)、穢邪 (252) 專精動態切換專屬圖示。
- 內建 6 格微型充能冷卻條（0%..100% 平滑動畫），由排程器平滑驅動。
- 提供 `/eam rune` 槽位即時狀態與診斷 JSON 視窗。

### 6. 🖥️ 經典排版預覽與極致 UI 體驗 (Modern UI & Live Preview)
- **階層式無縫吸附 (APPEND Docking)**：主選單 ➔ 清單/排版/資源/屬性 ➔ 細部條件/批次輸入 視窗向右緊密貼合，並支援多視窗同步平滑拖曳。
- **全二級側窗互斥**：開啟新側窗時自動收合其他側窗，徹底消除介面重疊。
- **經典奶牛頭位置預覽**：排版模式下以經典奶牛頭圖示 (`Spell_Nature_Polymorph_Cow`) 清楚標記 8 大告警框架定位。
- **60fps 全方位即時熱預覽**：調整圖示大小、水平/垂直間距、透明度、扇形倒數轉圈、字型大小等，畫面上告警框架與圖示即時動態響應，非戰鬥不需 `/reload`。
- **11 套精美主題風格**：魔獸經典 (預設)、Borland 亮藍黃字、DOS CRT 復古黑綠、曜石黑、賽博龐克等風格自由切換。
- **進入戰鬥紅框閃爍**：提供全螢幕戰鬥進入警示動畫與即時測試。

### 7. 💾 Profile 設定檔分享 (EAMAP1 Codec)
- 支援 8 大自選項目匯出／匯入（自身光環、目標光環、技能CD、物品CD、地面效果、框架排版、職業資源、一般偏好）。
- 採用防禦性白名單驗證與 Adler-32 Checksum 校驗，支援 JSON / Base64 編碼，安全分享配置。

### 8. 🌐 完整多國語系 (Localization)
- 完整支援 **繁體中文 (zhTW - 嚴格對齊台灣官方術語：致命、加速、臨機應變)**、**簡體中文 (zhCN)**、**英文 (enUS)**、**韓文 (koKR)**、**俄文 (ruRU)**。

---

## ⌨️ 命令列與斜線指令 (Command Line Reference)

EAM 提供豐富的斜線命令，主入口為 `/eam` 或 `/eventalertmod`（不分大小寫）：

| 指令 | 縮寫 / 別名 | 說明 |
| :--- | :--- | :--- |
| `/eam` 或 `/eam opt` | `/eam option`, `/eam options` | 開啟 EAM 主設定選單 |
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

## 📌 相容性與支援邊界 (Compatibility)

- **支援環境**：
  - 《魔獸世界：正式服》World of Warcraft: Retail 12.1.0+ (Interface 120100)
  - 相容通道 Retail 12.0.7+ (Interface 120007)
- **不支援環境**：
  - 經典懷舊服全系列（Classic Era、MoP Classic、TBC Classic、Wrath 等不在本專案支援範圍）。

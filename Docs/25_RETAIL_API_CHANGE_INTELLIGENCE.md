<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# Retail API Change Intelligence：12.0.0 起始基線

## 1. 文件目的與狀態

本文件是 EventAlertMod 正式服 AddOn API 變更情報的版本基準。目標不是抄錄完整 changelog，而是把 API 新增、移除、棄用、Secret／Forbidden 規則與 Widget 行為變化，轉成可執行的架構預警、遷移窗口與驗證工作。

- 專案範圍：僅 WoW Retail。
- 起始基線：12.0.0。
- 活動專案 TOC：`120007`。
- 12.1 狀態：PTR／持續修訂；不得宣稱正式相容。
- 最後查證：2026-06-21。
- Wiki revision time 均為頁面修訂時間，不是遊戲 patch 發布時間。

## 2. APICHG 專家章程

`EAM_API_Change_Intelligence_Expert`（`APICHG`）負責：

1. 維護版本、TOC、build 狀態、來源 URL、revision ID 與 revision time。
2. 區分 API 事實、EAM 工程推論與 PTR／Retail 實機結果。
3. 將變更分成 `P0 阻斷`、`P1 遷移`、`P2 觀察`、`無直接影響`。
4. 為 adapter、capability gate、降級路徑與舊路徑退場條件提供提前量。
5. 在新 PTR、RC、正式版或來源 revision 變動時，觸發影響掃描與文件更新。

責任邊界：

- `APICHG` 不取代 `SEC` 的 Secret／taint 安全終審。
- `APICHG` 不取代 `AURA121` 的 AuraContainer／AuraButton 遷移實作。
- `APICHG` 不取代 `RQA` 的 PTR／Retail 客戶端證據。
- `DOC` 管來源與狀態一致性，不自行裁決 API 技術真偽。

## 3. 證據優先序

1. Blizzard 官方公告、PTR／RC development notes。
2. Blizzard UI 原始碼或可追溯的版本 diff。
3. Warcraft Wiki `API_change_summaries` 與各 patch API changes 頁，且必須記錄 revision。
4. 專案 Markdown、活動 TOC 與實際 Lua 命中。
5. 搜尋摘要只作線索，不得單獨成為架構結論。

## 4. 12.0.0 至 12.1.0 版本演進

| 版本 | TOC | Wiki revision（UTC） | 與 EAM 直接相關的變更 | 策略判讀 |
| --- | ---: | --- | --- | --- |
| API change summaries | — | `6747807`，2026-06-19 05:45:08 | 提供版本索引與跨版定位入口 | revision 變更即觸發差異複核，不把索引頁當唯一事實 |
| 12.0.0 | `120000` | `6747189`，2026-06-18 08:59:26 | 引入 Secret Values 世代、predicate 與大量 API 移除／棄用 | Secret-safe adapter 必須成為服務層基礎，不可把舊數值模型直接搬入 12.x |
| 12.0.1 | `120001` | `6747895`，2026-06-19 08:48:51 | 封堵字串與 StatusBar 等 secret laundering；Secret 冷卻改走 `SetCooldownFromDurationObject`；部分 Private Aura 呼叫戰鬥中受限 | 顯示通道與可讀資料必須分離，`pcall` 或 UI 中繼不能當繞過 |
| 12.0.5 | `120005` | `6747894`，2026-06-19 08:48:14 | Formatter、DurationObject 零區間行為、Aura 布林值秘密性調整、`table.freeze`／predicate 變更；預告 Aura overhaul | Capability gate 必須檢查能力而非散落 patch 字串；先保留穩定路徑 |
| 12.0.7 | `120007` | `6747893`，2026-06-19 08:46:57 | `C_DurationUtil.CreateDurationTextBinding`；受限 unit token 改回傳 nil／預設；`debugstack`／`debuglocals` 秘密傳播；Aura refactor 指向 12.1 | 目前活動基線；錯誤與除錯輸出也可能攜帶秘密性，Aura 抽取架構需準備退場 |
| 12.1.0 | `120100` | `6749767`，2026-06-20 05:57:01 | AuraContainer／AuraButton、Private Script Objects、Forbidden Partition／Aspects；受限 UnitAura 資料可能全為 secret 或 nil | 既有逐 AuraData／spellID 抽取模型屬 P0 相容性風險；PTR 內容仍需持續追 revision 與實機 |

## 5. 變更脈絡

12.x 的核心不是單一 API 改名，而是資料權限模型逐步收緊：

1. 12.0.0 建立 Secret Values 與 predicate 基礎。
2. 12.0.1 封閉透過字串、StatusBar 或其他 UI 物件洗出秘密資料的路徑。
3. 12.0.5 把安全顯示導向 Formatter／DurationObject，並預告 Aura 架構重整。
4. 12.0.7 提供 DurationTextBinding，擴大秘密傳播到除錯輸出，明示 12.1 Aura refactor。
5. 12.1.0 將 Aura 顯示轉向受控 Container／Button 與 Forbidden 邊界，限制 AddOn 直接抽取敏感 Aura 事實。

因此 EAM 的長期布局必須從「讀值後自行計算與渲染」轉成「服務層辨識能力、保留合法事實、UI 使用 Blizzard 支援的原生顯示物件」。

## 6. EAM 架構策略

- API 邊界集中於 service／adapter，不把版本判斷散落在 Renderer。
- 優先 feature detection 與 capability gate；只有在功能語意確定一致時才使用 TOC 判斷。
- PTR 新路徑與現行穩定路徑並存，直到官方契約、UI source 與 RQA 證據符合退場條件。
- Secret／Forbidden 資料不得做算術、比較、字串化、序列化或自訂表 key。
- 時間顯示優先 DurationObject、DurationTextBinding 與 Blizzard 支援的 formatter。
- Tooltip scraping 僅能低頻、非戰鬥、明確標記來源，不能覆寫 API 安全事實。
- 每次版本變更同時檢查 SavedVariables schema、事件 payload、Frame／Widget 行為、TOC 與封裝設定。
- 版本文件不等於實機相容；靜態、Mock、PTR、Retail 四種證據分開簽收。

## 7. 監控觸發條件

遇到下列任一情況，啟動 `eam-retail-api-change-intelligence` 流程：

- `API_change_summaries` 新增 patch 頁或 revision 改變。
- Blizzard 發布 PTR／RC／正式版 AddOn、Aura 或 UI 限制公告。
- UI source diff 出現新增、移除、棄用、predicate 或 mixin／widget 介面變化。
- TOC／Interface 版本發布或專案目標版本調整。
- Secret、Forbidden、Duration、Aura、Tooltip、FrameXML、事件 payload 行為有新證據。
- EAM 活動 Lua 命中已移除 API、舊全域 API 或不再合法的資料流。

## 8. 影響輸出格式

每次查證至少產出：

1. 目標版本、前一穩定版、TOC、build 狀態與來源 revision。
2. 新增／移除／棄用／行為變更清單。
3. EAM 命中檔案與行號。
4. `P0／P1／P2／無直接影響` 分級。
5. 立即、PTR 期間、正式版前或後續觀察的處置窗口。
6. adapter／capability gate／降級／退場條件。
7. 已執行與未執行驗證，以及需由 `SEC/AURA121/RQA/DOC` 簽收的事項。

## 9. 目前 EAM 判讀

- 目前活動 TOC `120007` 對應 12.0.7 基線。
- 12.1 AuraContainer／AuraButton 尚未落地，既有 AuraService 仍依賴逐筆 AuraData 與 UnitAura 路徑，列為 P0 相容性阻斷。
- Secret 時間資料、戰鬥中框架建立、Scheduler 去重與 deferred state 生命週期另有 P0／P1 技術債；詳見 `Docs/24_EXPERT_COUNCIL_REVIEW_20260621.md`。
- 本文件與 SKILL 的建立沒有修改 Lua，也不能視為 12.1 相容完成。

## 10. 來源

- [Warcraft Wiki API change summaries](https://warcraft.wiki.gg/wiki/API_change_summaries)
- [Patch 12.0.0 API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes?oldid=6747189)
- [Patch 12.0.1 API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.1/API_changes?oldid=6747895)
- [Patch 12.0.5 API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.5/API_changes?oldid=6747894)
- [Patch 12.0.7 API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.7/API_changes?oldid=6747893)
- [Patch 12.1.0 API changes](https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes?oldid=6749767)
- [Blizzard：Addons and Auras in Curse of Ula’tek](https://us.forums.blizzard.com/en/wow/t/addons-and-auras-in-curse-of-ula%E2%80%99tek/2317456)

## 2026-07-26：12.1.0.68914 固定證據

- 本機 `_ptr_`：12.1.0.68914；對照 Gethe/wow-ui-source commit `d3915c78aba77a7a9be76acbfa35c674bbb6abe9`。
- 本機 `_xptr_`：12.0.7.68887；對照 commit `4383ced30106d51b27e3e86d1987f1552f0d259d`。
- AuraContainer sorting 使用 FrameXML 全域 `AuraContainerSortMethod`／`AuraContainerSortDirection`；68914 Generated Documentation 沒有登錄這兩表。
- `UnitAuraSortRule` 是 Aura getter 的另一組型別，不可傳入 AuraContainer options。
- EAM 實作與 API 限制矩陣見 `Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`。

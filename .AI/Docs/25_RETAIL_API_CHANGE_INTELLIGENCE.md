<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# Retail API Change Intelligence：12.0.0 起始基線

## 1. 文件目的與狀態

本文件是 EventAlertMod 正式服 AddOn API 變更情報的版本基準。目標不是抄錄完整 changelog，而是把 API 新增、移除、棄用、Secret／Forbidden 規則與 Widget 行為變化，轉成可執行的架構預警、遷移窗口與驗證工作。

- 專案範圍：僅 WoW Retail。
- 起始基線：12.0.0。
- 活動專案 TOC：`120007, 120100`，同一套程式以 capability gate 區分 12.0.7 與 12.1。
- 12.1 狀態：PTR／持續修訂；不得宣稱正式相容。
- 最後查證：2026-08-13。
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
2. Blizzard UI 原始碼或可追溯的版本 diff：
   - [Ketho/wow-ui-source-midnight-ptr](https://github.com/Ketho/wow-ui-source-midnight-ptr)（暴雪 Midnight / 12.x PTR 官方 UI 原始碼鏡像）
   - [Ketho/WowDoc](https://github.com/Ketho/WowDoc)（社群最完整 WoW API / FrameXML 文檔與簽名庫）
   - [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources)（暴雪 UI 素材、Atlas、Texture 與音效清單）
3. Warcraft Wiki `API_change_summaries` 與各 patch API changes 頁，且必須記錄 revision。
4. 專案 Markdown、活動 TOC 與實際 Lua 命中。
5. 搜尋摘要只作線索，不得單獨成為架構結論。

## 4. 12.0.0 至 12.1.5 版本演進

| 版本 | TOC | Wiki revision（UTC） | 與 EAM 直接相關的變更 | 策略判讀 |
| --- | ---: | --- | --- | --- |
| API change summaries | — | `6747807`，2026-06-19 05:45:08 | 提供版本索引與跨版定位入口 | revision 變更即觸發差異複核，不把索引頁當唯一事實 |
| 12.0.0 | `120000` | `6747189`，2026-06-18 08:59:26 | 引入 Secret Values 世代、predicate 與大量 API 移除／棄用 | Secret-safe adapter 必須成為服務層基礎，不可把舊數值模型直接搬入 12.x |
| 12.0.1 | `120001` | `6747895`，2026-06-19 08:48:51 | 封堵字串與 StatusBar 等 secret laundering；Secret 冷卻改走 `SetCooldownFromDurationObject`；部分 Private Aura 呼叫戰鬥中受限 | 顯示通道與可讀資料必須分離，`pcall` 或 UI 中繼不能當繞過 |
| 12.0.5 | `120005` | `6747894`，2026-06-19 08:48:14 | Formatter、DurationObject 零區間行為、Aura 布林值秘密性調整、`table.freeze`／predicate 變更；預告 Aura overhaul | Capability gate 必須檢查能力而非散落 patch 字串；先保留穩定路徑 |
| 12.0.7 | `120007` | `6747893`，2026-06-19 08:46:57 | `C_DurationUtil.CreateDurationTextBinding`；受限 unit token 改回傳 nil／預設；`debugstack`／`debuglocals` 秘密傳播；Aura refactor 指向 12.1 | 目前活動基線；錯誤與除錯輸出也可能攜帶秘密性，Aura 抽取架構需準備退場 |
| 12.1.0 | `120100` | `6749767`，2026-06-20 05:57:01 | AuraContainer／AuraButton、Private Script Objects、Forbidden Partition／Aspects；受限 UnitAura 資料可能全為 secret 或 nil | 既有逐 AuraData／spellID 抽取模型屬 P0 相容性風險；PTR 內容仍需持續追 revision 與實機 |
| 12.1.5 | `120105` | `6912957` / `6905828`，2026-10-09 19:28:37 | C_Timer.NewTimedSignalMap、C_UnitAuras.GetRefreshCarryOverDuration、AddPandemicActive/Enter/LeaveAnimation、AddAuraSound (限長5s且throttle<=5s)、C_Intl、C_Weather、C++ math/table/string 加速、CreateFrameWithOptions、SetRoundLayoutToNearestPixel；移除 10 大舊時代相容模組 (Blizzard_Deprecated) | 實裝 TimedSignalMap 原生排程、精準 Pandemic 窗口、C++ 工具 polyfills，全面移除 deprecated 依賴，並嚴格遵循 5s 音效節流限制 |

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

- 12.0.7 保留 readable Legacy Aura 路徑；12.1 已具 AuraContainer／AuraButton Native backend，並在離線 strict mock 驗證初始化期設定與零 Legacy Aura pipeline。
- Native backend 已落地不等於 PTR 簽收。圖示、單一倒數、applications、target transition、Forbidden Aspect、戰鬥限制與 taint 仍需 `_ptr_` 真人證據。
- 冷卻顯示集中經 `Core/DurationAdapter.lua`：`CreateDuration()` 與 `CreateDurationTextBinding()` 都先無參數建立，再以公開 setter 設定；不再假設建構參數或 `Unbind()`。
- 12.1 `SPELL_UPDATE_COOLDOWN` payload 可提供 `spellID`、`baseSpellID` 與 `itemID`。EAM 以安全 ID 做目標刷新，缺值時才回到合併刷新。
- UnitPower 採雙通道：predicate 判定可讀的次要資源可輸出安全 numeric state；可能為 Secret 的主要資源只把 `UnitPowerPercent()` 直接送入 Blizzard 支援的 StatusBar／radial sink，不讀回、不比較、不匯出原始值。
- `AuraContainerUtil.AddDispelTypeTexture` 只視為驅散類型外觀能力，不取代任意 proc／Pandemic Glow。
- 本輪離線流程與能力分類測試不能視為 12.1 PTR 或 12.0.7 實機相容完成。

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

## 2026-08-01：Duration、冷卻、Aura 外觀與 UnitPower 佈局

### API 事實

- Duration factory 與 DurationTextBinding factory 均為無參數建立，再透過 ScriptObject setter 配置；EAM 以單一 adapter 管生命週期。
- `SPELL_UPDATE_COOLDOWN` 在 12.1 可攜帶 `itemID`，物品冷卻不應只等待 `BAG_UPDATE_COOLDOWN`。
- `UnitPowerPercent(unitToken, powerType, unmodified, curve)` 可產生適合原生顯示 sink 的百分比；`C_Secrets.ShouldUnitPowerBeSecret`、`ShouldUnitPowerMaxBeSecret` 與 `GetPowerTypeSecrecy` 用於先分類能力。
- StatusBar／radial sink 能接受 Secret 輸入，不代表 AddOn 可從 widget 讀回普通數字；該路徑只能顯示，不得成為 EAM 自訂判斷、序列化或觸發條件。
- 68914 CustomAuraButton 的 dispel texture 是特定 Aura 外觀能力，不能推論成任意 border／Glow API。

### 實作與驗證狀態

- `ClassPowerService` 已修正事件參數與資源選擇，優先處理 Holy Power、Combo Points、Soul Shards、Chi、Arcane Charges 等次要資源；安全值 `1` 不再被 Renderer 當成「無層數」隱藏。
- `UnitPowerCapabilityProbe` 只能由玩家按鈕啟動，輸出能力分類與人工 pass／fail／blocked；`rawValuesCollected` 固定為 `false`。
- 離線 mock 已證明安全 numeric 次要資源與 Secret 原生 sink 資料流可達；實際職業、專精、戰鬥限制與視覺更新仍需 `_ptr_` 12.1 與 `_xptr_` 12.0.7 玩家實測。

固定來源：

- [68914 Unit API documentation source](https://github.com/Gethe/wow-ui-source/blob/d3915c78aba77a7a9be76acbfa35c674bbb6abe9/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [68914 Secret predicate documentation source](https://github.com/Gethe/wow-ui-source/blob/d3915c78aba77a7a9be76acbfa35c674bbb6abe9/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua)
- [68914 AuraContainer frame provider](https://github.com/Gethe/wow-ui-source/blob/d3915c78aba77a7a9be76acbfa35c674bbb6abe9/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua)
- [68914 CustomAuraButton implementation](https://github.com/Gethe/wow-ui-source/blob/d3915c78aba77a7a9be76acbfa35c674bbb6abe9/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua)


## 2026-08-08：PTR8 與 UnitPower 公開 API 固定證據

### PTR8 API 事實

- 固定來源為 Gethe/wow-ui-source PTR commit `a520b6c27bb897e6be2333b6cc2be36d52c7c11b`，版本 `12.1.0.69189`。
- `AuraButton:AddPandemicRegion(region)`、`RemovePandemicRegion(index)`、`ClearPandemicRegions()` 是 Pandemic Region 合約；EAM 只在規則明確要求時建立 texture 並於 `initializeFrame` 綁定，不讀 `Enum.SecretAspect.Shown`，不建立自己的 OnUpdate。
- `AuraButton:AddDispelTypeTexture(texture, options)` 使用 `showAlways`、Harmful/Helpful 與 `Enum.CustomAuraButtonDispelTypeStealableFilter`；`showAlways=true` 時不輸出無作用的 `stealableFilter`。新程式不依賴 AuraBorder deprecated alias。
- 停用 `AuraContainer` 時由 Blizzard 清除 AuraButton 與 ItemEnchantment 顯示資料；框架仍可存在。此行為已加入 strict mock，PTR 實機仍待簽收。
- PTR8 的 tooltip 200ms throttle、duration 0 bug fix 與 OnSizeChanged exploit fix 是 Blizzard 行為，不由 EAM 自製輪詢或 exploit。

### UnitPower API 事實與否定結論

- 同一 PTR commit 的 `SimpleStatusBarAPIDocumentation.lua`、`UnitDocumentation.lua` 與 `SecretPredicateAPIDocumentation.lua` 未證實 `StatusBar:SetUnit`、`SetPowerTextFontString`、`SetOnUpdateMode`；不得將使用者提供的三個方法當成公開 API 或硬依賴。
- 可確認的 Secret 顯示路徑是 `UnitPowerPercent()` 取得分類結果後單向送入 `StatusBar:SetValue()` 或 `Texture:SetRadialProgressBarPercent()`；禁止讀回 widget、比較、字串化或序列化 Secret 值。
- `ClassPowerService` 只有在 `C_Secrets.ShouldUnitPowerBeSecret`／`ShouldUnitPowerMaxBeSecret` 明確可用且回傳 `false` 時才讀取普通數字；戰鬥中所有 UnitPower/Max 讀取延後至 `PLAYER_REGEN_ENABLED`。
- `UnitPowerCapabilityProbe` 的 `statusBarSecretSink` 僅保留初始化相容欄位，實際通過仍須 case `accepted` 加玩家視覺 pass；文件或離線 mock 不升格為 PTR 實機證據。

固定來源：

- [SimpleStatusBar API 12.1.0.69189](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua)
- [SimpleTextureBase API 12.1.0.69189](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua)
- [Unit API 12.1.0.69189](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Secret predicate API 12.1.0.69189](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua)
## 2026-08-09：PTR 通道旗標與 Alpha 2 Native Aura gate

### 已確認的回歸鏈

- 玩家實機觀察為 Alpha 1 可顯示 Aura、Alpha 2 完全不顯示。Alpha 2 新增的 Native runtime gate 要求 `IsPublicTestClient()==true` 且 `IsTestBuild()==true`。
- PTR `12.1.0.69189` 的實機報告卻是 `isPublicTestClient=true`、`isTestBuild=false`、`isBetaBuild=false`，所以舊 AND 條件必然關閉 Native backend；這不是 AuraContainer API 被 PTR8 移除。
- 修正後只把三個 raw flags 視為測試通道的替代證據：Interface `>=120100` 且 public-test、test-build、beta 任一為真。每個 flag 都以 `pcall` 取得安全布林值；AuraContainer、Slot、Group、Layout 方法仍各自做 capability gate。
- PTR 69189 固定 FrameXML 仍有 `AuraContainerMixin:SetEnabled`、`SetUnit` 與 Custom container 的 `AddAuraSlot`、`AddAuraGroup`、`SetAuraGroupLayout`。因此目前修正聚焦通道判定，不放寬缺方法時的 fail-closed。
- 離線 mock 已改為 public-test=true、test-build=false、beta=false，專門覆蓋本次真實旗標組合。遊戲客戶端上的 strict-mock-only Flow 案例改為 `skip`，不再把 mock 缺席冒充功能失敗。

固定來源：

- [AuraContainer 12.1.0.69189](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainer.lua)
- [CustomAuraContainer 12.1.0.69189](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua)

### UnitPower 實機報告界線

- 同一 PTR build 的回報顯示：primary 為 `secret`，StatusBar 與 radial 呼叫均為 `accepted`，但 `visualObservation=pending`；selected 為 `safe-number`，兩個 sink 亦為 `accepted`，但視覺狀態為 `blocked`。
- `rawValuesCollected=false` 符合安全契約。這份報告可確認 API 呼叫沒有被拒絕，不能確認畫面會隨資源正確增減，也不能升格為 UnitPower PTR pass。

## 2026-08-09：PTR8 AuraButton border 與 EAM 分類邊框分流

- PTR8 的 `AuraButton:AddDispelTypeTexture(texture, options)` 用於 Blizzard Aura 驅散／stealable／showAlways 契約；EAM 的七色分類邊框只表示監控來源類型，兩者不得互相冒充。
- 12.1 Native 路徑只可在 `initializeFrame` 建立 EAM 自有 Texture 並套用靜態 `unit + filterString` 顏色；不得在初始化後新增 Region、追蹤 `OnSizeChanged` 或藉尺寸變化推算 Aura 數量。
- TargetFrame 與 BuffFrame 的 Aura Tooltip 可能由非 `GameTooltip` 的 Blizzard tooltip object 顯示。EAM 只接收 `SetUnitAura` post-call 作匿名短期 hover 心跳，不讀 callback payload、不保存 frame、不推導 spellID；玩家按 Ctrl+Alt 後仍在 EAM Popup 手動確認 ID 與 player／target 路由。
- Macro action ID 以 `GetActionInfo` 的安全 resolved subtype／ID 為第一來源，再降級 `GetMacroSpell`／`GetMacroItem`；不依賴 TooltipData 中可能只代表 macro index 的 `id`。

## 2026-08-09：PTR8 SVG API 固定證據

固定查證快照為 Gethe/wow-ui-source commit a520b6c27bb897e6be2333b6cc2be36d52c7c11b，version 12.1.0.69189：

- Frame:CreateVectorGraphics() 回傳 SimpleVectorGraphics；生成文件將其 SecretArguments 標為 NotAllowed。
- SimpleVectorGraphics 提供 SetSVG、ClearSVG、HasSVG、GetSVGFileID；VectorGraphics:SetSVG 的 SecretArguments 為 AllowedWhenUntainted。
- SimpleTextureBase 提供 Texture:SetSVG 與 ClearSVG，但固定生成文件沒有 Texture:HasSVG 或 Texture:GetSVGFileID；Texture:SetSVG 的 SecretArguments 為 AllowedWhenTainted。這只描述 Secret argument policy，不等於允許戰鬥中建立或重排 region。
- VectorGraphics 只有 Region 能力，沒有 Texture 的 rotation、mask、texcoord 與 blend 契約；EAM 以 A/B 探針分開驗證，不做能力等同推論。
- PTR 69189 Alpha 3 實機報告確認兩條 SetSVG 路徑 accepted 且人工圖樣觀察均 pass。VectorGraphics 為 HasSVG=true、GetSVGFileID 分類 zero、clear/reload pass；Texture introspection unavailable 是預期契約，舊探針因錯誤要求 HasSVG 才沒有執行 Texture clear/reload。
- `GetSVGFileID() == 0` 只在固定的 addon-local 封裝素材、HasSVG=true、生命週期與人工目視均通過時視為非阻擋診斷；不能泛化成任意 SVG 路徑都有效。

固定版本來源：

- [SimpleFrame API 12.1.0.69189](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua)
- [SimpleVectorGraphics API 12.1.0.69189](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleVectorGraphicsAPIDocumentation.lua)
- [SimpleTextureBase API 12.1.0.69189](https://github.com/Gethe/wow-ui-source/blob/a520b6c27bb897e6be2333b6cc2be36d52c7c11b/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua)

持續更新知識庫：

- [Warcraft Wiki：UIOBJECT_VectorGraphics](https://warcraft.wiki.gg/wiki/UIOBJECT_VectorGraphics) 用於追蹤方法、繼承與後續 Patch 變更；頁面可能隨 Wiki 更新，不能取代上述固定 commit 的 build 證據。
- [Warcraft Wiki：Patch 12.1.0/API changes](https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes) 用於追蹤 PTR 批次變更與官方說明脈絡。

適用評估：Pandemic 靜態提示 Region 是最高價值候選；Dispel CustomAsset／PreserveAsset 需先完成 asset map／預載；Legacy Glow 可評估 12.1 SVG 與 12.0.7 原材質雙軌。動態 spell/item/aura 主圖示、UnitPower radial、Tooltip Popup 目前不改。

## 2026-08-13：PTR 69273 AuraSound 情報

| 項目 | 69273 事實 | EAM 策略 |
| --- | --- | --- |
| Trigger | Added／ApplicationsIncreased／Removed | per-alert 三開關與三筆 registration |
| Sound info | unitToken、spellID、file name／FileDataID、channel | 只由普通 SavedVariables 建構 |
| 篩選能力 | 無 caster／auraFilter | 標記 limitation，PTR 觀察 over-fire |
| 生命週期 | Add 回 registration ID、Remove 依 ID | session registry、交易式交換、移除失敗重試 |
| 12.0.7 | 僅 private aura applied 舊 API | 一般 Aura 三 trigger 顯示 unsupported |

P0 邊界：不得從 AuraData 讀取／推導 sound trigger，不得保存 registration ID，不得把 Secret 值做比較、字串化、table key 或 JSON。`RemoveAuraSound` 只證明取消後續註冊，不能推論已播放音效會停止。

固定證據：

- [12.1.0.69273 UnitAura API](https://github.com/Gethe/wow-ui-source/blob/6e348870ed8f93d95f0cd16d299b51dbce500296/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
- [12.1.0.69273 Trigger enum](https://github.com/Gethe/wow-ui-source/blob/6e348870ed8f93d95f0cd16d299b51dbce500296/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraConstantsDocumentation.lua)
- [12.1.0.69273 UnitAuraSoundInfo](https://github.com/Gethe/wow-ui-source/blob/6e348870ed8f93d95f0cd16d299b51dbce500296/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitConstantsDocumentation.lua)

## 2026-09-19 / 2026-10-09：12.1.5 全面解鎖實作與 PTR 1 ~ PTR 4 官方變更與注意事項沉澱

### 1. 開發邊界與發布準則（Alpha 8.8 升級）

- **開發環境解鎖**：已全面解鎖 Retail 12.1.5（TOC: 120105）環境之代碼實作，不僅限於研究備存。
- **主力實機測試與發布目標**：雖 10/15 正式服才會全面上線 12.1.5，但當前開發以 **12.1.5 PTR 為主力實機測試環境**。
- **漸進增強與跨版本防禦相容**：凡引入 12.1.5 專屬 API（如 `C_Timer.NewTimedSignalMap`、`AddPandemicActiveAnimation`、`C_UnitAuras.GetRefreshCarryOverDuration`、`math.clamp`、`table.isempty` 等），必須封裝安全能力檢定閘門（Capability Gate）與高效率 Lua 降級實作（Fallback Polyfills），確保代碼在 Retail 12.1.5、Retail 12.1.0（120100）與 XPTR 12.0.7（120007）客戶端中 100% 平穩運行、零報錯。
- **每輪需求必訪 Wiki 協議**：主代理與所有分派之 Subagent，每輪任務均必須主動探訪 `https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes` 與 `https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes/notes`，追蹤最新 PTR Build 演進。

### 2. 12.1.5 PTR 1 / PTR 2 / PTR 3 / PTR 4 最新情報深入解析

依據 `https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes`（Revision `6912957`）與 `https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes/notes`（Revision `6905828`）：

#### 📅 PTR 1 (2026-09-03, Build 69594)
- **原生 Pandemic 動畫管線 (`CustomAuraButton`)**：
  - `AddPandemicEnterAnimation(animGroup)`：進入補 DoT 窗口單次觸發（適合單次閃爍/進場動畫）。
  - `AddPandemicActiveAnimation(animGroup)`：窗口內持續播放發光/脈動動畫（適合循環動畫）。
  - `AddPandemicLeaveAnimation(animGroup)`：脫離窗口平滑停止。
  - **Forbidden Aspects 擴充**：新增 `QueryAnimationProgress`（禁止查詢動畫進度與運行狀態）與 `AddAnimations`（禁止動態掛載/改綁 Parent）。動畫本身具備 `ChangeAnimationTarget` 切面限制。
- **Region 參考傳參與破壞性變更**：
  - `AddPandemicRegion(region)` 與 `AddDispelTypeTexture(texture, options)` 不再返回 index，重複加入同一物件會拋出 Fatal Error。
  - `RemovePandemicRegion(region)` 與 `RemoveDispelTypeTexture(texture)` 必須傳遞 Region 物件參考本身。
  - `CustomAuraButton:SetCasterName(fontString)`：原生字串綁定施法者名稱。
  - CVar `tooltipShowAuraCasterNames`：支援在光環浮動提示顯示施法者，並依陣營/職業上色。
  - `CustomAuraContainer` 控制：支援 `SetAuraGroupEnabled`、`SetAuraSlotEnabled`、`SetItemEnchantmentEnabled`、`SetEditModePreviewEnabled` 及 `minApplications`。
- **AddOn 安全性防禦**：
  - 受保護的 Cooldown 框架（Protected Cooldown Frame）禁止由 Tainted 程式碼調用 `SetCooldown` 與 `Clear`。
  - Castbar ID 改為依 unit token 大小寫唯一化（例如 `"PLAYER"` 與 `"player"` 回傳不同 ID），事件統一使用小寫 token。
- **C++ 排程器革命 (`TimedSignalMap`)**：
  - `C_Timer.NewTimedSignalMap(callback)`：單一回呼支援數千 key 註冊，支援 `SignalAt(key, time)` 原位重設且無須取消操作，零閉包分配、零 GC 壓力。
  - `TimerUtil.CreateTimedSignalCallbackMap()`：官方 FrameXML 便捷封裝。
- **底層原生 C++ 加速與佈局**：
  - `CreateFrameWithOptions({ frameType = "Frame", hidden = true })` 杜絕建立即顯示閃爍。
  - `ScriptRegion:SetRoundLayoutToNearestPixel(true)` 原生硬體像素對齊，取代 Lua `PixelUtil`。
  - 暴雪底層 C++ 函式庫：`math.clamp`、`math.saturate`、`math.round`、`math.lerp`、`math.normalize`、`math.sign`、`math.remap`、`math.wrap`、`math.isfinite`、`math.isnan`、`math.isinf`；`string.contains`、`string.ltrim`、`string.rtrim`、`string.startswith`、`string.endswith`；`table.isempty`、`table.contains`、`table.indexof`、`table.removeunordered`、`table.removevalue`、`table.keys`、`table.values`。
- **拔除 10 大相容庫**：`Blizzard_DeprecatedItemScript`、`Blizzard_DeprecatedSoundScript`、`Blizzard_DeprecatedCurrencyScript` 等徹底移除，EAM 維持 100% `C_Item.*` 與現代 API。
- **新命名空間**：`C_Weather` (`GetCurrentWeather`, 事件 `WEATHER_CHANGED`) 與 `C_Intl`（Unicode / 國際化支援庫）。

#### 📅 PTR 2 (2026-09-16, Build 69848)
- **`CustomAuraButton` 完整生命週期動畫**：
  - 新增 `AddAuraShownAnimation(animGroup)` 與 `AddAuraAssignedAnimation(animGroup)`，原生處理光環初次顯示與 slot 指派動畫。
- **Secret Aspects 擴展**：
  - `Enum.SecretAspect.VertexColor` 與 `Enum.SecretAspect.TexCoords` 納入受限切面，避免透過頂點著色或 UV 貼圖逆向刺探戰鬥秘密。
- **音效節流保護**：
  - `C_UnitAuras.AddAuraSound` 支援選填 `throttleSeconds`（如 0.3s），由 C++ 引擎自動節流高頻刷新音效。
- **單位框架工具庫 (`UnitFrameUtil`) 引入**：
  - 官方提供安全的 `UnitFrameUtil.UpdateUnitPvPIndicator` 等渲染通道，解決單位框架存取秘密屬性之 Taint 阻斷。
  - `C_Intl` 支援 Tainted 秘密字串（但禁止 `Null`/`Remove` 轉譯），索引修正為 1-based。
  - Enemy Nameplate 獲得額外 1 幀命中框調整窗口 (`UNIT_CLASSIFICATION_CHANGED`)。
- **雜項優化**：
  - Chat tab 移除 `UIFrameFlash` 降低全域 Taint。
  - `C_ClassColor.GetClassColor` 支援可選 tint。
  - 恢復 3 個 CVars：`nameplateMotionSpeed`、`nameplateBottomInset`、`nameplateTopInset`。

#### 📅 PTR 3 (2026-09-22, Build 69952)
- **競技場敵方專精 Secret 屬性化**：
  - `GetArenaOpponentSpec` 正式回傳 Secret，一般插件不得直接讀取；必須透過 `UnitFrameUtil.GetArenaOpponentSpecDisplayInfo`、`UpdateArenaOpponentSpecDisplay` 與 `UpdateArenaOpponentSpecDisplayName` 進行原生安全顯示。
- **角色職責圖示安全通道**：
  - `UnitFrameUtil.GetUnitRoleIconDisplayInfo` 與 `UpdateUnitFrameRoleIcon`（支援 `textureMap` 參數）。
- **`C_UnitAuras.GetRefreshCarryOverDuration` 精準結餘**：
  - 暴雪官方提供精準 Pandemic 結餘計算（如德魯伊生命之花等具備超額 Carry-Over 的技能），解決自製 30% 臨界值計算偏差問題。

#### 📅 PTR 4 (2026-09-29, Build 70077, 官方最終 PTR 基準)
- **`C_UnitAuras.AddAuraSound` 安全防禦限縮**：
  - 播放的音效檔案長度強制限制最長 5 秒。
  - `throttleSeconds` 參數若大於 5 秒將直接拒絕（Reject）。EAM 預設傳入 `0.3s`，完全處於合規安全區。
- **`C_Intl.GetSortKey` 容錯加固**：
  - 修復傳入空字串與 `Enum.CollationStrength.Primary` 時回傳 `nil` 之異常。

### 3. 12.1.5 INTRINSIC_AuraButton 與架構 R&D 藍圖

- **固有類型**：`CreateFrame("AuraButton", nil, UIParent, "CustomAuraButtonTemplate")`（Button 繼承 Intrinsic Frame）。
- **獨立一級公民**：脫離 12.1.0 `AuraContainer` 寄生限制，允許以 Button 獨立建立單顆光環。
- **原生單向 Sinks 與解綁方法群**：
  - Sinks: `SetDurationBar`、`SetDurationCooldown`、`SetDurationText`、`SetApplicationCount`、`SetSpellName`、`SetCasterName`、`SetIcon`。
  - 解綁: `ClearDurationText()`、`ClearApplicationCount()`、`ClearSpellName()`、`ClearDurationBar()`、`ClearDurationCooldown()`、`ClearIcon()`。
- **解除「18 次重建必須 /reload」限制**：12.1.5 單元化獨立後，可改為單顆按鈕建立/釋放，徹底告別 Container 18 次配額死鎖。
- **字型大小即時熱套用**：利用 `ClearDurationText()` 先解綁文字 Sink，重新 `SetFont` 後再 `SetDurationText()`，實現字型大小、樣式調整的 100% 平滑即時熱套用。

### 4. 12.1.5 Consolidated Changes 總清冊與各系統分類 (Build 69594 ~ 70077)

#### (1) 全域 API (Global APIs)
- **新增 (82)**：
  - **光環與冷卻相關**：`C_UnitAuras.GetRefreshCarryOverDuration`、`C_UnitAuras.GetAuraCasterGUID`、`C_AuraContainerUtil.ProcessCustomAuraButtonCasterNameOptions`、`C_Timer.NewTimedSignalMap`、`CreateFrameWithOptions`、`GetScriptBucketThrottleLimits`、`GetTextureMetatable`。
  - **動作列與巨集**：`C_ActionBar.IsMacroActionWithShowTooltip`。
  - **環境與 PvP**：`C_Weather.GetCurrentWeather`、`C_LFGInfo.GetActiveLFGDungeonName`、`C_PvP.GetRandomTrainingGroundArenaRewards`、`C_PvP.GetRandomTrainingGroundBGRewards`、`C_PvP.HasRandomTrainingGroundArenaWinToday`、`C_PvP.HasRandomTrainingGroundBGWinToday`、`C_PvP.IsTrainingGroundsArena`、`C_PvP.IsTrainingGroundsBG`、`C_PvP.JoinRandomTrainingGroundBG`。
  - **C++ 原生加速庫 (Math/String/Table)**：`math.clamp`、`math.saturate`、`math.round`、`math.lerp`、`math.normalize`、`math.sign`、`math.remap`、`math.wrap`、`math.isfinite`、`math.isnan`、`math.isinf`；`string.contains`、`string.ltrim`、`string.rtrim`、`string.startswith`、`string.endswith`；`table.isempty`、`table.contains`、`table.indexof`、`table.removeunordered`、`table.removevalue`、`table.keys`、`table.values`、`table.getcountinfo`。
  - **C++ 相容別名導出**：`Clamp`、`CountTable`、`GetKeysArray`、`GetValuesArray`、`Lerp`、`Round`、`RoundToSignificantDigits`、`Saturate`、`Sign`、`TableIsEmpty`、`tContains`、`tDeleteItem`、`tIndexOf`、`tUnorderedRemove`。
  - **國際化庫 (`C_Intl`) (24)**：`CompareStrings`、`CreateLocaleContext`、`FindBreaks`、`FindStringMatches`、`FoldCase`、`FormatCurrency`、`FormatDate`、`FormatDateTime`、`FormatNumber`、`FormatTime`、`GetCharacterProperties`、`GetCurrencyFractionDigits`、`GetCurrencyName`、`GetCurrentLocale`、`GetDisplayName`、`GetSortKey`、`IsNormalized`、`Length`、`Normalize`、`ParseCurrency`、`ParseNumber`、`SelectPlural`、`ToLower`、`ToTitle`、`ToUpper`、`TransformLocale`、`Transliterate`。
- **移除 (4)**：`C_PvP.GetRandomTrainingGroundRewards`、`C_PvP.HasRandomTrainingGroundWinToday`、`C_PvP.JoinRandomTrainingGroundBattleground`、`C_TableUtil.FindIndexedMismatch`。

#### (2) FrameXML 工具函數
- **新增 (29)**：
  - `ChatFrameUtil`: `GetTabAlphas`、`IsTabAlerting`、`SetTabAlerting`、`SetTabAlphas`、`StartFlash`、`StartSyncedFlash`、`StopFlash`。
  - `UnitFrameUtil`: `GetArenaOpponentSpecDisplayInfo`、`GetUnitPvPIndicatorDisplayInfo`、`GetUnitRoleIconDisplayInfo`、`UpdateArenaOpponentSpecDisplayName`、`UpdateArenaOpponentSpecDisplay`、`UpdateUnitFrameRoleIcon`、`UpdateUnitPvPIndicator`。
  - `TimerUtil`: `CreateTimedSignalCallbackMap`。
  - `PixelUtil`: `SetRoundLayoutToNearestPixelRecursively`。
  - `CombatAudioAlertUtil`: `EnumeratePulseHealthPercentInfo`、`GetCurrentPulseHealthPercentInfo`、`GetPulseHealthPercentInfo`、`GetPulseHealthSoundKit`、`SetPulseHealthSoundKit`。
  - 其他：`MarchingAnts_Create`、`MarchingAnts_CreateAsChildOf`、`MarchingAnts_CreateForTarget`、`CompactUnitFrame_GetOptionDispelIndicatorAnimatedBorder`、`GenericTraitUtil.GetKnownTreeIDs`、`GetTimeSinceLastQuestProgress`、`HousingFramesUtil.MoveLayoutCameraFloor`、`QuestMapLog_GetStoryTooltip`。
- **移除 (15)**：舊時代全域 Lua 實現（`Clamp`、`CountTable`、`GetKeysArray`、`GetValuesArray`、`Lerp`、`Round`、`RoundToSignificantDigits`、`Saturate`、`Sign`、`StringContains`、`TableIsEmpty`、`tContains`、`tDeleteItem`、`tIndexOf`、`tUnorderedRemove` 全部移入 C++）。

#### (3) ScriptObjects 方法群
- **新增 (30)**：
  - `TimedSignalMap` (8)：`CancelAllSignals`、`CancelSignal`、`GetNextSignal`、`GetSignalCount`、`GetSignalTime`、`HasSignal`、`SignalAfter`、`SignalAt`。
  - `LocaleContext` (22)：`CompareStrings`、`FindBreaks`、`FindStringMatches`、`FoldCase`、`FormatCurrency`、`FormatDate`、`FormatDateTime`、`FormatNumber`、`FormatTime`、`GetCurrencyName`、`GetDisplayName`、`GetLocale`、`GetSortKey`、`Length`、`ParseCurrency`、`ParseNumber`、`SelectPlural`、`SetLocale`、`ToLower`、`ToTitle`、`ToUpper`、`TransformLocale`。

#### (4) Widgets 與 Events
- **Widget 新增 (2)**：`ScriptRegion:GetRoundLayoutToNearestPixel()`、`ScriptRegion:SetRoundLayoutToNearestPixel(enabled)`。
- **Events 新增 (1)**：`WEATHER_CHANGED`。

#### (5) 控制台變數 (CVars) (12)
- `tooltipShowAuraCasterNames` (預設 0, Account)：光環浮動提示顯示施法者。
- `tooltipShowAuraSpellIDs` (預設 0, Game)：修正本地化與著色問題。
- `minimapShowPlayerCoords` (預設 1, Account)：小地圖顯示玩家座標。
- `coordsByTenths` (預設 1, Account)：座標顯示至十分位數。
- `CAAPulsePlayerHealthPercent` (預設 0, Account)：低血量循環脈衝警示音。
- `CAAPulsePlayerHealthVolume` (預設 100, Account)：低血量警示音量。
- `nameplateMotionSpeed` (預設 0.025, Game)：名條移動平滑速率。
- `nameplateBottomInset` (預設 0.100, Game) / `nameplateTopInset` (預設 0.080, Game)：名條螢幕上下邊距。
- `raidFramesDispelIndicatorAnimatedBorder` (預設 0, Character)：驅散指示器動畫邊框。
- `dumpSmallAlloc` (Game 命令)：小型分配偵錯。
- `maximumConnectionAttempts` (預設 2, Net)：QUIC 連線重試上限。
- `winePlatformTTS` (預設 0, Game)：Wine 平臺 TTS 開關。

#### (6) 徹底移除的 10 大 Deprecated 套件
- `Blizzard_DeprecatedCurrencyScript`、`Blizzard_DeprecatedGlue`、`Blizzard_DeprecatedItemScript`、`Blizzard_DeprecatedItemSocketInfo`、`Blizzard_DeprecatedLFG`、`Blizzard_DeprecatedPetInfo`、`Blizzard_DeprecatedPvpScript`、`Blizzard_DeprecatedSoundScript`、`Blizzard_DeprecatedTradeInfo`、`Blizzard_DeprecatedWorldElapsedTimerTypes`。

### 5. EAM 核心模組對齊與防禦策略矩陣

| EAM 模組 | 涉及 12.1.5 API / 行為 | 防禦策略與落地架構 | 當前狀態 |
| --- | --- | --- | --- |
| `Core/Scheduler.lua` | `C_Timer.NewTimedSignalMap`、`TimedSignalMap:SignalAt` | 封裝能力檢定閘門，優先調用 C++ 原位重設排程器；降級至基底 OnUpdate / Timer 鏈；uint32 floor 與 pcall 隔離防護 | ✅ 已落地 |
| `UI/NativeAuraRenderer.lua` | `AddPandemicActive/Enter/LeaveAnimation`、`AddDispelTypeTexture`、`AddPandemicRegion` | 嚴格依 Region 物件參考傳參；以 `hasPandemicAnimation` 探針安全掛載；禁止查詢動畫進度 (Forbidden Aspect) | ✅ 已落地 |
| `Services/CooldownService.lua` | Cooldown 框架 Taint 限制、法術覆蓋與先驗冷卻 | 獨立 Frame 創建杜絕暴雪保護框架污染；施法優先級重啟；引導技能 0ms 先驗冷卻；60ms 自適應突發 CDR 採樣器 | ✅ 已落地 |
| `Services/AuraService.lua` | `C_UnitAuras.AddAuraSound` | 嚴格防禦性限制：音效播放長度 $\le 5$ 秒，`throttleSeconds` 傳入 `0.3s`（保證 $< 5.0\text{s}$），杜絕高頻音效轟炸與 API 拋錯 | ✅ 已落地 |
| `Core/Util.lua` | 原生 C++ `math.*`、`table.*`、`string.*` | 建立安全封裝層（`Util.clamp`、`Util.lerp`、`Util.tableIsEmpty` 等），優先調用底層 C++ 加速，提供零除零與 NaN 防禦降級 | ✅ 已落地 |
| `UI/Renderer.lua` | `SetRoundLayoutToNearestPixel`、`CreateFrameWithOptions` | 建立框架時若支援 `CreateFrameWithOptions` 採用 `hidden=true`；對 Alert 圖示啟用像素四捨五入對齊消除模糊抖動 | ✅ 已落地 |
| 全專案依賴 | 拔除 10 大 Deprecated 套件 | 全面清查並確認 100% 使用 `C_Item.*`、`C_Sound.*`、`C_CurrencyInfo.*`，零舊版相容庫依賴 | ✅ 100% 合規 |

固定來源：
- [Warcraft Wiki：Patch 12.1.5/API changes](https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes)（Revision `6912957`，2026-10-14 01:55:36 UTC，Build `69952 ~ 70077`）
- [Warcraft Wiki：Patch 12.1.5/API changes/notes](https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes/notes)（Revision `6905828`，2026-10-09 19:28:37 UTC）
- [Warcraft Wiki：INTRINSIC_AuraButton](https://warcraft.wiki.gg/wiki/INTRINSIC_AuraButton)（Revision `6878724`，2026-09-19 00:19:09 UTC）


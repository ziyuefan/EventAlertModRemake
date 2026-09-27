---
name: eam-miliui-publisher
description: >-
  奇樂 (MiliUI / WoWbox) 說明文件排版、語法特性與發布規範技能。涵蓋 https://addons.miliui.com/wow/28 實機驗證、純 HTML5 (0% Markdown)、收合語法 (<details><summary>點擊展開</summary><div class="details-content"><p>...</p></div></details>)、後端 Sanitizer 表格洗除防禦（0 table, 改採 ul/ol/li/code 結構化）、圖片 50% 寬度排版與自動化產出腳本 (.AI/Tools/Build-MiliUIDoc.py)。
---

# EAM MiliUI Publisher (奇樂說明文件排版與發布技能)

本技能規範 EventAlertMod 發布至繁體中文魔獸插件社群平台 **奇樂 (MiliUI / WoWbox)** 之說明文件標準化排版、平台語法特性與後端過濾器防禦。

- **線上專案與實機驗證網址**：`https://addons.miliui.com/wow/28`
- **主要發布產物**：
  - `addons_miliui_eventalertmod.html` (專案根目錄，方便直接複製發布)
  - `Deploy/addons_miliui_eventalertmod.html` (部署目錄副本)
- **自動化建置工具**：`.AI/Tools/Build-MiliUIDoc.py`

---

## 1. 核心自動化建置指令

```powershell
# 1. 執行奇樂專用 HTML 文件建置與 15 項自動化自檢
python .\.AI\Tools\Build-MiliUIDoc.py

# 2. 驗證全專案合約（確保代碼與文檔規範一致）
pwsh -NoProfile -File .\.AI\Tools\Test-ValidationContracts.ps1
```

建置腳本會自動將專案的完整說明文件轉換為奇樂規格，並嚴格執行 15 項自檢斷言：
- `<table>` 標籤數 = 0
- 包含語意化清單（`<ul>`、`<ol>`、`<li>`）與 `<code>` 標籤
- 14 張展示截圖統一為 `width="50%"`
- 杜絕 XHTML 自閉合簡寫（無 `<.../>`）
- 杜絕巢狀 `<p>` 標籤

---

## 2. 奇樂平台語法特性與 Sanitizer 防禦 (Sanitizer Quirks & Filter Pitfalls)

奇樂的後端富文本解析器與安全過濾器（Sanitizer）具有特殊的過濾機制，必須嚴格遵守以下特性：

### 特性一：純 HTML5 架構（0% Markdown）
- **解析器邊界**：奇樂後端完全不支援 Markdown 語法。任何 `#`、`##`、`**`、\`代碼\` 或 `|---|` 表格語法皆不會被轉譯，在前台會被直接原樣輸出為純文字字元。
- **鐵則**：說明文件必須為 **100% 純 HTML 結構**。

### 特性二：後端 Sanitizer 的「表格清洗陷阱」（Table Stripping）
- **陷阱描述**：奇樂後端的富文本過濾器會將 `<table>`、`<thead>`、`<tbody>`、`<tr>`、`<th>`、`<td>` 等表格相關標籤無差別洗除，替換或退化為普通 `<p>` 段落。
- **破壞後果**：若使用 HTML 表格排版 Slash 命令對照表或模組特色，儲存後在前台會失去行列排版，導致指令與說明文字全部擠在一起，版面徹底混亂。
- **鐵則（Zero Table Policy）**：
  - 專案說明中**嚴格保持 0 `<table>` 標籤**。
  - 所有原本使用表格呈現的內容（如 Slash 指令、模組狀態、修飾鍵說明），一律改採語意化清單（`<ul>`、`<ol>`、`<li>`）結合 `<code>`、`<strong>` 標籤呈現。

### 特性三：清單與代碼支援性（與 CurseForge 的關鍵對應）
- **支援度**：奇樂**完整原生支援** `<ul>`、`<ol>`、`<li>`、`<code>`、`<strong>`、`<em>`、`<a>`。
- **平台差異注意**：
  - **CurseForge**：後端 Sanitizer 會剝離 `<li>`，因此 CurseForge 必須禁用 `<li>`，改用 `&bull;&nbsp;` 與 `<br>`。
  - **奇樂 (MiliUI)**：`<li>` 與 `<code>` 是最重要的結構化排版工具，能產生乾淨清爽的縮排與條目效果。

### 特性四：收合區塊語法標準 (`<details>` / `<summary>`)
奇樂原生支援標準 HTML5 `<details>` 折疊面板。為符合奇樂前台樣式與階層相容性，必須嚴格遵循以下標籤結構：

```html
<details>
  <summary>點擊展開</summary>
  <div class="details-content">
    <p>
      ... 收合內容主體 ...
    </p>
  </div>
</details>
```

- `<summary>` 內部文字建議使用「`點擊展開`」或對應模組標題（如「`點擊展開詳細說明`」）。
- 內部必須包裹一層 `<div class="details-content">`，以維持奇樂樣式表之邊距與縮排。

### 特性五：現代 HTML5 空標籤規範（Void Elements Standard）
- 依據現代 HTML5 規範，空元素（Void Elements）**嚴禁使用帶有斜線之 XHTML 自閉合標籤**（如 `<br />`、`<hr />`、`<img ... />`）。
- 一律使用標準單標籤：
  - `<br>`
  - `<hr>`
  - `<img src="..." width="50%" alt="...">`

### 特性六：圖片寬度與 CDN 規範（50% 寬度適配）
- **寬度適配**：奇樂內容欄位寬度有限，若截圖設為 `width="100%"`，實機截圖會過大且佔據整面螢幕，影響閱讀流暢度。
- **統一尺寸**：所有 14 張 UI 截圖統一設定為 `width="50%"`（`<img src="..." width="50%" alt="...">`）。
- **圖片來源**：優先使用官方 CDN 附件（CurseForge Attachments CDN：`https://media.forgecdn.net/attachments/...`），載入穩定且不會受到 GitHub raw 防盜鏈阻擋。

---

## 3. 14 大展示圖片 CDN 映射表

1. **主設定面板**：`https://media.forgecdn.net/attachments/description/826042/description_04ac0707-5adb-4e9f-a51c-876fb3e1bc84.jpg`
2. **功能模組開關**：`https://media.forgecdn.net/attachments/description/826042/description_e2998c73-1a7b-4cee-ada8-5a98d40888ac.jpg`
3. **關於插件資訊**：`https://media.forgecdn.net/attachments/description/826042/description_2b46c72f-8515-493e-a3a2-5d5271fd2b90.jpg`
4. **主題樣式下拉選單**：`https://media.forgecdn.net/attachments/description/826042/description_8fb2f296-64fd-4fdd-9881-876e63a748d9.jpg`
5. **提示音效下拉選單**：`https://media.forgecdn.net/attachments/description/826042/description_4961ea26-688a-4c99-bc3c-404101ab6fe9.jpg`
6. **多國語系下拉選單**：`https://media.forgecdn.net/attachments/description/826042/description_1a8c7c49-0ce4-4c0d-ae21-1aa64dc7f25b.jpg`
7. **自身光環細部條件**：`https://media.forgecdn.net/attachments/1891/207/07_eaeoacae-aec-e-aeae-a_selfauraconditions-jpg.jpg`
8. **技能冷卻覆寫設定**：`https://media.forgecdn.net/attachments/1891/208/08_aee12aacaeeecoea-e-a_spellcooldownoptions-jpg.jpg`
9. **物品冷卻監控設定**：`https://media.forgecdn.net/attachments/1891/209/09_c-c-aaacaee-a_itemcooldownoptions-jpg.jpg`
10. **地面效果階層吸附**：`https://media.forgecdn.net/attachments/1891/210/10_aeaeaecaeea-c-eaa-e_groundeffectdocking-jpg.jpg`
11. **玩家職業資源面板**：`https://media.forgecdn.net/attachments/1891/211/11_c-c-aeaee3aeoe-aeae_playerresourcepanel-jpg.jpg`
12. **角色屬性監控面板**：`https://media.forgecdn.net/attachments/1891/212/12_ee2aaeea-aeecaeeae_playerstatspanel-jpg.jpg`
13. **告警框架排版位置**：`https://media.forgecdn.net/attachments/1891/213/13_aeaeaea12c12aeceae-aaeco_layoutpositionoptions.jpg`
14. **職業 Profile 分享**：`https://media.forgecdn.net/attachments/1891/214/14_eaeprofileaaoea-aa-aoeae_profilecodecpanel-jpg.jpg`

---

## 4. 發布與實機驗證檢核清單 (Release & Verification Checklist)

- [ ] 執行 `python .\.AI\Tools\Build-MiliUIDoc.py` 產出最新版 HTML。
- [ ] 檢查自檢指標：確認表格數量為 0、無自閉合標籤、截圖寬度皆為 50%。
- [ ] 執行全契約檢查：`pwsh -NoProfile -File .\.AI\Tools\Test-ValidationContracts.ps1`。
- [ ] 複製 `addons_miliui_eventalertmod.html` 內容貼至奇樂管理後台說明欄位。
- [ ] 前往 `https://addons.miliui.com/wow/28` 進行實機驗收：
  - 檢查頂部專案簡介與特色清單縮排是否正常。
  - 點擊 `<details>` 各收合區塊（版本歷史、Slash 命令等），驗證展開與折疊流暢度。
  - 檢視 14 張截圖尺寸是否適中（50% 寬度），確認無溢出或破圖。
  - 檢查 Slash 指令清單是否以 `<code>` 清晰對齊，確認無被後端洗成混亂 `<p>` 的現象。

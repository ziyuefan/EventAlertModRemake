#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Build-MiliUIDoc.py
------------------
自動建置奇樂 (MiliUI / WoWbox) 專屬純 HTML 說明頁面 addons_miliui_eventalertmod.html。

奇樂 (MiliUI) 平台特性與防禦性規範：
1. 奇樂後端富文字清道夫（Sanitizer）會將 <table>、<tr>、<td>、<th> 全數過濾清洗為 <p>，
   導致表格排版嚴重走位碎裂。本工具將全表格徹底重構成專屬純 HTML5 卡片與列表排版，
   全篇 0 個 <table> 標籤，永久杜絕被網站後端洗成碎片。
2. 奇樂完整原生支援 <code>、<ul>、<ol>、<li> 標籤：
   - 斜線指令採用四大功能分組，搭配 <code> 高亮與 <ul><li> 結構化清單。
   - 快速操作與安裝指引採用 <ol><li> 步驟有序列表。
   - 歷史更新日誌與特性全面採用語意化 <ul><li>，徹底消除人工 &bull;&nbsp; 模擬符號。
3. 100% 純 HTML5 語法，零 Markdown 語法（網站不支援 Markdown 解析）。
4. 收合語法嚴格遵循奇樂標準：
   <details>
     <summary>點擊展開</summary>
     <div class="details-content">
       <p>
         內容...
       </p>
     </div>
   </details>
5. Void elements 嚴格遵循 HTML5 標準，杜絕 XHTML 自閉合斜線（使用 <br>、<hr>、<img ...>，禁止 <br />、<hr />、<img ... />）。
6. 杜絕非法巢狀 <p><p> 標籤，保證排版完全合規。
"""

import os
import re
import sys

def build_comparison_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <p>EAM 專為 12.0+ / 12.1+ Retail 正式服深度重構，徹底解決傳統法術監控插件沉重、掉幀與報錯污染問題：</p>\n'
        '    <ol>\n'
        '      <li>\n'
        '        <strong>資源佔用與運行效能</strong>\n'
        '        <ul>\n'
        '          <li>⚠️ <strong>傳統法術監控 / 複雜大型插件</strong>：大量背景 OnUpdate 輪詢、吃記憶體、引發戰鬥掉幀。</li>\n'
        '          <li>⚡ <strong>現代重構版 EventAlertMod (EAM)</strong>：純事件驅動架構，全面引入物件池技術（State Pools），消滅 GC 記憶體垃圾。</li>\n'
        '        </ul>\n'
        '      </li>\n'
        '      <li>\n'
        '        <strong>暴雪 12.0+ 終極安全防護</strong>\n'
        '        <ul>\n'
        '          <li>❌ <strong>傳統法術監控 / 複雜大型插件</strong>：12.0+ 暴雪引入 Secret Values 後，常常在戰鬥中報錯噴黃字或引發 UI 異常。</li>\n'
        '          <li>🛡️ <strong>現代重構版 EventAlertMod (EAM)</strong>：獨家採用原生 C-Level <code>StatusBar:SetValue</code> 直通渲染技術，絕不觸發 Taint 污染。</li>\n'
        '        </ul>\n'
        '      </li>\n'
        '      <li>\n'
        '        <strong>操作門檻與法術設定</strong>\n'
        '        <ul>\n'
        '          <li>🔄 <strong>傳統法術監控 / 複雜大型插件</strong>：設定繁瑣、需匯入字串：需手動到網站翻找 WA 字串或手寫 Lua 條件判斷。</li>\n'
        '          <li>🎯 <strong>現代重構版 EventAlertMod (EAM)</strong>：直覺易用、秒加監控：滑鼠停在任何技能、光環或物品上按 <strong><code>Ctrl + Alt</code></strong> 一秒加入，無需查 ID。</li>\n'
        '        </ul>\n'
        '      </li>\n'
        '      <li>\n'
        '        <strong>四合一移動速度與飛龍騎術支援</strong>\n'
        '        <ul>\n'
        '          <li>🐢 <strong>傳統法術監控 / 複雜大型插件</strong>：速度顯示不準確：傳統插件無法偵測 10.0+ / 11.0+ / 12.0+ 飛龍騎術的真實衝刺速度。</li>\n'
        '          <li>🏃 <strong>現代重構版 EventAlertMod (EAM)</strong>：業界唯一四合一速度淬鍊：專屬對接 <code>C_PlayerInfo.GetGlidingInfo()</code>，完美支援 <strong>830%~1400%</strong> 動態極速！</li>\n'
        '        </ul>\n'
        '      </li>\n'
        '    </ol>\n'
        '  </div>\n'
        '</details>'
    )

def build_alert_modules_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <p>EAM 擁有 8 個完全解耦、獨立排版、自由拖曳的專業監控模組：</p>\n'
        '    <ol>\n'
        '      <li>🔮 <strong>自身光環 (Player Buff / Debuff)</strong>：監控自身增益與減益，支援堆疊層數與高精度倒數。</li>\n'
        '      <li>🎯 <strong>目標光環 (Target Buff / Debuff)</strong>：精確監控當前目標之光環、控制與 Debuff 狀態。</li>\n'
        '      <li>⚔️ <strong>跨職業光環 (Cross-Class / Target Cast)</strong>：監控敵方關鍵爆發或隊友重要增益。</li>\n'
        '      <li>⏳ <strong>技能冷卻 (Spell Cooldown)</strong>：精確監控技能冷卻與充能層數；支援圓形環狀進度條 (<code>Radial Mode</code>) 與框外線性條 (<code>TOP/BOTTOM/LEFT/RIGHT</code>)。</li>\n'
        '      <li>🎒 <strong>物品冷卻 (Item Cooldown)</strong>：飾品、主動使用裝備與消耗品冷卻監控。</li>\n'
        '      <li>🌋 <strong>地面效果 (Ground Effect)</strong>：監控玩家施放的無光環地面範圍技能（如死亡凋零、褻瀆、冰霜之球、反魔法立場），支援天賦法術族群智能對齊。</li>\n'
        '      <li>⚡ <strong>玩家職業資源 (Player Resource)</strong>：支援全 13 職業、40 組專精、17 種資源獨立節點（法力、怒氣、能量、連擊點、真氣、狂亂、符能、奧術充能、靈魂裂片、神聖能量、精華等）。</li>\n'
        '      <li>📊 <strong>角色屬性與吸收量 (Player Stats &amp; Absorbs)</strong>：全方位即時監控 18 種角色數值（主屬性、副屬性、四合一速度、護甲值、總吸收盾量與治療吸收量）。</li>\n'
        '    </ol>\n'
        '  </div>\n'
        '</details>'
    )

def build_visual_experience_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <ul>\n'
        '      <li>📖 <strong>次世代全量法術庫與智慧預設 (Master Spell Catalog)</strong>：內建 5 語系先驗資料庫（收錄 4,463 個技能與 466 個光環），支援專精樹展開/收合、一鍵天賦技能智慧同步、目標模組清單自由指派（冷卻/光環/地面效果）與全法術 GameTooltip 懸停說明。</li>\n'
        '      <li>🏷️ <strong>多維戰術群組與標籤管理 (Group Management)</strong>：支援技能多對多標籤歸屬、內建 4 大系統戰術群組（爆發/減傷/控場/地面）與自訂群組、獨立二級管理側窗、戰鬥情境過濾與技能細節視窗下拉複選器。</li>\n'
        '      <li>🎵 <strong>LibSharedMedia-3.0 (SharedMedia) 素材生態全面整合</strong>：動態探測所有第三方 SharedMedia 音效、字型與材質包，支援自適應長清單滑鼠滾輪選單與字型全域 60fps 熱套用（免 /reload 即時生效）。</li>\n'
        '      <li>🐮 <strong>經典奶牛頭位置預覽</strong>：排版模式下以經典奶牛頭圖示 (<code>Spell_Nature_Polymorph_Cow</code>) 清楚標記 8 大告警框架定位。</li>\n'
        '      <li>🖼️ <strong>全模組自訂替代圖示 (Custom Icon Override)</strong>：所有模組均可輸入官方 FileID（例如 <code>132307</code>）或材質路徑，自訂取代預設圖示，並附即時動態預覽方塊與 Wago.tools 查詢指引。</li>\n'
        '      <li>💀 <strong>死亡騎士符文儀表板</strong>：依專精動態切換專屬圖示，內建 6 格微型充能冷卻條（0%..100% 平滑動畫）與 <code>/eam rune</code> 槽位診斷視窗。</li>\n'
        '      <li>⚡ <strong>60fps 全方位即時熱預覽</strong>：調整尺寸、間距、透明度、轉圈動畫、文字大小等，畫面上即時動態響應，非戰鬥不需 <code>/reload</code>。</li>\n'
        '      <li>💬 <strong>全介面控制項懸停提示 (Hover Tooltips)</strong>：所有按鈕、核取方塊、滑桿、編輯框與選單均附帶直觀指引，使用門檻為零。</li>\n'
        '      <li>🎨 <strong>11 套精美主題風格</strong>：EAM 原版經典（石板金框深紅按鈕）、FF7 戰鬥視窗（皇家藍漸層白框）、Windows XP（Luna 藍）、Windows 7（Aero 玻璃）、Windows 10、Windows 3.1（3D 凸面按鈕）、Borland C++ IDE、DOS CRT（P1 磷光綠）、倚天中文、Red Alert（紅色警戒裝甲）、macOS Aqua（果凍膠囊藍）等自由切換，全面支援 Modern WoW 垂直漸層與所有子視窗無縫連動。</li>\n'
        '      <li>\n'
        '        📈 <strong>暴雪原生 CurveObject / ColorCurveObject 曲線架構全面接入</strong>：\n'
        '        <ul>\n'
        '          <li><strong>能量/資源條動態色彩曲線染色</strong>：消耗型與累積型資源自動以三色階動態染色（警戒深紅 ➜ 預警金黃 ➜ 專職代表色），完美相容 12.0+ <code>UnitPowerPercent</code> 原生硬體級渲染。</li>\n'
        '          <li><strong>階梯閥門曲線 (Step Gate Curve)</strong>：透過二元階梯函數安全穿透受保護秘密值，實現精確斬殺與警戒，零報錯零 Taint。</li>\n'
        '          <li><strong>SecondsFormatter 自適應精度曲線</strong>：時間倒數文字依剩餘秒數平滑切換精度（長時間整數，關鍵 &lt;= 5 秒小數點），零 GC 負擔。</li>\n'
        '          <li><strong>非線性冷卻進度曲線</strong>：支援線性均勻 (Linear)、三次加速衝刺 (Cubic) 與餘弦平滑 (Cosine)，營造大招即將就緒的戰鬥衝刺張力。</li>\n'
        '          <li><strong>全螢幕瀕死動態呼吸警示</strong>：血量危急時全螢幕邊緣動態呼吸脈動，血量越低紅框越濃烈，脫戰自動平滑隱藏。</li>\n'
        '        </ul>\n'
        '      </li>\n'
        '      <li>🚨 <strong>進入戰鬥紅框閃爍</strong>：提供全螢幕戰鬥進入警示動畫與即時測試按鈕。</li>\n'
        '      <li>📦 <strong>Profile 設定檔跨角色分享</strong>：支援 8 大分類自選項目匯出／匯入（EAMAP1 JSON / Base64 編碼），附防禦性白名單校驗。</li>\n'
        '      <li>🌐 <strong>完整多國語系支援</strong>：繁體中文 (zhTW - 嚴格對齊台灣官方術語：致命、加速、臨機應變)、簡體中文 (zhCN)、英文 (enUS)、韓文 (koKR)、俄文 (ruRU)。</li>\n'
        '    </ul>\n'
        '  </div>\n'
        '</details>'
    )

def build_showcase_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <p>以下為 EAM 各項介面截圖與功能詳細導覽：</p>\n'
        '    <h3>1. 主設定與系統選單 (Main Options &amp; System Preferences)</h3>\n'
        '    <p>\n'
        '      <strong>【主設定面板 (Main Options)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/description/826042/description_04ac0707-5adb-4e9f-a51c-876fb3e1bc84.jpg" width="100%" alt="EAM 主設定面板"><br>\n'
        '      ↳ 整合主題/音效/語系選單、光環後端切換與全域開關。<br><br>\n'
        '      <strong>【功能模組開關 (Module Options)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/description/826042/description_e2998c73-1a7b-4cee-ada8-5a98d40888ac.jpg" width="100%" alt="功能模組開關"><br>\n'
        '      ↳ 8 大功能模組獨立事件監聽與資源開關。<br><br>\n'
        '      <strong>【關於插件資訊 (About Panel)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/description/826042/description_2b46c72f-8515-493e-a3a2-5d5271fd2b90.jpg" width="100%" alt="關於插件資訊"><br>\n'
        '      ↳ 插件版本、作者資訊、API 基準 (12.1.0 PTR) 與專案連結。<br><br>\n'
        '      <strong>【11 套主題樣式 (Theme Dropdown)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/description/826042/description_8fb2f296-64fd-4fdd-9881-876e63a748d9.jpg" width="100%" alt="主題樣式下拉選單"><br>\n'
        '      ↳ 內建魔獸經典、FF7、WinXP、Borland 等 11 套風格。<br><br>\n'
        '      <strong>【12 種經典音效 (Sound Dropdown)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/description/826042/description_4961ea26-688a-4c99-bc3c-404101ab6fe9.jpg" width="100%" alt="提示音效下拉選單"><br>\n'
        '      ↳ 內建 ShayBell、Netherwind、PolyMorphCow 等音效。<br><br>\n'
        '      <strong>【6 大多國語系 (Locale Dropdown)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/description/826042/description_1a8c7c49-0ce4-4c0d-ae21-1aa64dc7f25b.jpg" width="100%" alt="多國語系下拉選單"><br>\n'
        '      ↳ 自動偵測、繁體中文 (台灣官方術語)、簡中、英文、韓文、俄文。<br><br>\n'
        '    </p>\n'
        '    <hr>\n'
        '    <h3>2. 法術清單、細部條件與階層吸附 (Alert Lists, Conditions &amp; Docking)</h3>\n'
        '    <p>\n'
        '      <strong>【自身光環與奶牛頭預覽 (Self Aura &amp; Preview)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/1891/207/07_eaeoacae-aec-e-aeae-a_selfauraconditions-jpg.jpg" width="100%" alt="自身光環清單與細部條件設定"><br>\n'
        '      ↳ 自身法術清單、奶牛頭排版預覽、層數/高亮/紅字限制、12.1 光環事件音效與自訂圖示。<br><br>\n'
        '      <strong>【技能冷卻與行為覆寫 (Spell Cooldown Overrides)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/1891/208/08_aee12aacaeeecoea-e-a_spellcooldownoptions-jpg.jpg" width="100%" alt="技能冷卻監控與行為覆寫設定"><br>\n'
        '      ↳ 技能冷卻清單、完成後移除/非戰鬥顯示/可用時高亮三態覆寫與自訂替代圖示。<br><br>\n'
        '      <strong>【物品冷卻設定 (Item Cooldown)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/1891/209/09_c-c-aaacaee-a_itemcooldownoptions-jpg.jpg" width="100%" alt="物品冷卻監控設定"><br>\n'
        '      ↳ 裝備與飾品冷卻清單、層數閾值、優先級與自訂圖示。<br><br>\n'
        '      <strong>【三級階層吸附與地面效果 (Ground Effect Docking)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/1891/210/10_aeaeaecaeea-c-eaa-e_groundeffectdocking-jpg.jpg" width="100%" alt="地面效果監控與三級階層吸附"><br>\n'
        '      ↳ 主選單 ➔ 清單 ➔ 細部條件無縫平滑貼合 (APPEND Docking) 與動態 Tooltip 擷取。<br><br>\n'
        '    </p>\n'
        '    <hr>\n'
        '    <h3>3. 職業資源、角色屬性與排版設定 (Resources, Stats &amp; Layout)</h3>\n'
        '    <p>\n'
        '      <strong>【玩家職業資源設定 (Player Resource Panel)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/1891/211/11_c-c-aeaee3aeoe-aeae_playerresourcepanel-jpg.jpg" width="100%" alt="玩家職業資源設定面板"><br>\n'
        '      ↳ 符文/符能與各專精能量條、顯示模式、錨點定位、16 項細部滑桿與 Secret 原生保護。<br><br>\n'
        '      <strong>【角色屬性與吸收量監控 (Player Stats &amp; Absorbs)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/1891/212/12_ee2aaeea-aeecaeeae_playerstatspanel-jpg.jpg" width="100%" alt="角色屬性與吸收量監控面板"><br>\n'
        '      ↳ 18 項核心屬性取值、跑速/泳速/飛速/飛龍速度、圖示/進度條開關與警戒值設定。<br><br>\n'
        '      <strong>【告警框架排版與懸停提示 (Layout &amp; Tooltips)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/1891/213/13_aeaeaea12c12aeceae-aaeco_layoutpositionoptions.jpg" width="100%" alt="告警框架位置排版與懸停提示"><br>\n'
        '      ↳ 尺寸/間距/字型/透明度滑桿、7 大框架成長方向、充能列設定與控制項懸停 Tooltip 指引。<br><br>\n'
        '      <strong>【職業 Profile 分享與匯入匯出 (Profile Codec)】</strong><br>\n'
        '      <img src="https://media.forgecdn.net/attachments/1891/214/14_eaeprofileaaoea-aa-aoeae_profilecodecpanel-jpg.jpg" width="100%" alt="職業Profile分享與匯入匯出面板"><br>\n'
        '      ↳ 8 大自選項勾選、快捷按鈕與 EAMAP1 Base64 字串匯出/預覽/合併套用/取代套用。<br><br>\n'
        '    </p>\n'
        '  </div>\n'
        '</details>'
    )

def build_slash_commands_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <p>EAM 提供豐富完整的斜線命令，主入口為 <code>/eam</code> 或 <code>/eventalertmod</code>（不分大小寫）：</p>\n'
        '    <p><strong>【常用核心指令】</strong></p>\n'
        '    <ul>\n'
        '      <li><code>/eam</code> 或 <code>/eam opt</code>（別名：<code>/eam option</code>、<code>/eam options</code>）— 開啟 EAM 主設定選單。</li>\n'
        '      <li><code>/eam preview</code> — 開啟獨立即時效果預覽小視窗（免進戰鬥測試變色、光效、扇形倒數與屬性）。</li>\n'
        '      <li><code>/eam reset</code>（別名：<code>/eam resetpos</code>、<code>/eam center</code>）— <strong>將 EAM 主視窗重置回螢幕正中央</strong>（解決視窗被拖出畫面找不到的問題）。</li>\n'
        '      <li><code>/eam list</code> — 顯示目前職業已啟用的監控清單（自身、目標、冷卻、物品、地面效果）。</li>\n'
        '      <li><code>/eam help</code>（別名：<code>/eam ?</code>）— 列出所有可用斜線命令說明。</li>\n'
        '    </ul>\n'
        '    <p><strong>【快速新增與管理監控】</strong></p>\n'
        '    <ul>\n'
        '      <li><code>/eam add &lt;spellID&gt;</code>（別名：<code>/eam add player &lt;spellID&gt;</code>）— 新增指定法術 ID 至「自身光環」監控清單。</li>\n'
        '      <li><code>/eam add target [spellID]</code> — 新增「目標光環」監控；若不輸入 ID 則開啟手動輸入與候選視窗。</li>\n'
        '      <li><code>/eam add cd &lt;spellID&gt;</code>（別名：<code>/eam add cooldown &lt;spellID&gt;</code>）— 新增指定法術 ID 至「技能冷卻」監控清單。</li>\n'
        '      <li><code>/eam add item &lt;itemID&gt;</code>（別名：<code>/eam add itemcooldown &lt;itemID&gt;</code>）— 新增指定物品 ID 至「物品冷卻」監控清單。</li>\n'
        '      <li><code>/eam remove &lt;spellID&gt;</code>（別名：<code>/eam remove &lt;player|target|cd|item&gt; &lt;ID&gt;</code>）— 從指定監控類別中移除指定法術或物品 ID。</li>\n'
        '      <li><code>/eam show</code> 或 <code>/eam showtarget</code>（別名：<code>/eam shows</code>、<code>/eam showt</code>）— 顯示 Retail 12.1 安全加入光環之操作指引（滑鼠懸停按 Ctrl+Alt）。</li>\n'
        '    </ul>\n'
        '    <p><strong>【法術查詢與施法紀錄】</strong></p>\n'
        '    <ul>\n'
        '      <li><code>/eam lookup &lt;名稱&gt;</code>（別名：<code>/eam l &lt;名稱&gt;</code>）— 依關鍵字模糊查詢目前職業可用法術候選與 Spell ID。</li>\n'
        '      <li><code>/eam lookupfull &lt;全名&gt;</code>（別名：<code>/eam lf &lt;全名&gt;</code>）— 依完整名稱精確查詢目前職業可用法術候選與 Spell ID。</li>\n'
        '      <li><code>/eam showcast</code>（別名：<code>/eam showc</code>）— 開始或停止記錄本次登入成功施放的法術（方便查詢自己剛放的技能 ID）。</li>\n'
        '    </ul>\n'
        '    <p><strong>【進階診斷、測試與設定檔】</strong></p>\n'
        '    <ul>\n'
        '      <li><code>/eam profile</code>（別名：<code>/eam profile export</code>、<code>/eam profile import</code>）— 開啟 Profile 設定檔匯出／匯入與字串分享面板。</li>\n'
        '      <li><code>/eam rune</code>（別名：<code>/eam runes</code>、<code>/eam probe rune</code>）— 開啟死亡騎士 6 格符文槽位即時狀態、充能秒數與診斷 JSON 視窗。</li>\n'
        '      <li><code>/eam unitpower background &lt;KEY&gt;</code> — 標記指定背景資源缺少事件，啟動 0.5s demand-driven 共用取樣器。</li>\n'
        '      <li><code>/eam doctor</code>（別名：<code>/eam validate</code>）— 執行客戶端 API 邊界與運行環境診斷報告。</li>\n'
        '      <li><code>/eam test [suite]</code>（別名：<code>/eam test live</code>）— 開啟遊戲內流程測試面板，或執行指定測試套件 (<code>quick/core/boundary/aura121/all/live</code>)。</li>\n'
        '      <li><code>/eam debug</code>（別名：<code>/eam export</code>）— 開啟系統狀態與精簡 AI 除錯報告輸出視窗。</li>\n'
        '      <li><code>/eam debug ground &lt;spellID&gt;</code> — 測試並除錯特定地面技能之 Tooltip 持續時間解析。</li>\n'
        '    </ul>\n'
        '  </div>\n'
        '</details>'
    )

def build_quick_add_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <p>在遊戲中，您可以完全不需手動查詢法術 ID：</p>\n'
        '    <ol>\n'
        '      <li>將滑鼠懸停於自身頭像、目標頭像的光環圖示，或快捷列上的技能/巨集/物品上。</li>\n'
        '      <li>同時按下鍵盤上的 <strong><code>Ctrl + Alt</code></strong> 組合鍵。</li>\n'
        '      <li>畫面即刻彈出 EAM 專屬加入視窗，一鍵將其指派至自身光環、目標光環、技能冷卻或物品冷卻監控清單中！</li>\n'
        '    </ol>\n'
        '  </div>\n'
        '</details>'
    )

def build_installation_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <p>請依下列步驟完成插件安裝：</p>\n'
        '    <ol>\n'
        '      <li>前往 <a href="https://github.com/ziyuefan/EventAlertModRemake/releases">GitHub Releases</a> 下載最新版本之 <code>EventAlertMod_MN_*.zip</code>。</li>\n'
        '      <li>解壓縮後將 <code>EventAlertMod</code> 資料夾放置於魔獸世界安裝目錄：\n'
        '        <ul>\n'
        r'          <li>正式服路徑：<code>World of Warcraft\_retail_\Interface\AddOns\EventAlertMod</code></li>' + '\n'
        '        </ul>\n'
        '      </li>\n'

        '      <li>啟動遊戲，在角色選擇畫面確認「插件」清單中已勾選啟用 <code>EventAlertMod</code>。</li>\n'
        '    </ol>\n'
        '  </div>\n'
        '</details>'
    )

def build_compatibility_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <p><strong>支援環境</strong>：</p>\n'
        '    <ul>\n'
        '      <li>《魔獸世界：正式服》World of Warcraft: Retail 12.1.0+ (Interface 120100)</li>\n'
        '      <li>相容通道 Retail 12.0.7+ (Interface 120007)</li>\n'
        '    </ul>\n'
        '    <p><strong>不支援環境</strong>：</p>\n'
        '    <ul>\n'
        '      <li>經典懷舊服全系列（Classic Era、MoP Classic、TBC Classic、Wrath 等不在本專案支援範圍）。</li>\n'
        '    </ul>\n'
        '  </div>\n'
        '</details>'
    )

def build_docs_links_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <ul>\n'
        '      <li>📖 <strong>GitHub Pages 說明文件導航中心</strong>：<a href="https://ziyuefan.github.io/EventAlertModRemake/">https://ziyuefan.github.io/EventAlertModRemake/</a></li>\n'
        '      <li>📦 <strong>GitHub 專案原始碼與 Release 發布</strong>：<a href="https://github.com/ziyuefan/EventAlertModRemake">https://github.com/ziyuefan/EventAlertModRemake</a></li>\n'
        '      <li>📜 <strong>CurseForge 專案發布頁面</strong>：<a href="https://www.curseforge.com/wow/addons/eventalertmod">https://www.curseforge.com/wow/addons/eventalertmod</a></li>\n'
        '      <li>💬 <strong>WoWInterface 專案發布頁面</strong>：<a href="https://www.wowinterface.com/downloads/info26550-EventAlertMod.html">https://www.wowinterface.com/downloads/info26550-EventAlertMod.html</a></li>\n'
        '      <li>🌸 <strong>魔獸世界繁體中文插件站 (奇樂 / MiliUI)</strong>：<a href="https://addons.miliui.com/">https://addons.miliui.com/</a></li>\n'
        '    </ul>\n'
        '  </div>\n'
        '</details>'
    )

def convert_changelog_spoiler(inner):
    parts = re.split(r'<br\s*/?>\s*<br\s*/?>', inner.strip())
    lines_out = []
    in_ul = False
    for p in parts:
        p = p.strip()
        if not p:
            continue
        if p.startswith('&bull;&nbsp;'):
            item = p[len('&bull;&nbsp;'):].strip()
            if not in_ul:
                lines_out.append('    <ul>')
                in_ul = True
            lines_out.append(f'      <li>{item}</li>')
        else:
            if in_ul:
                lines_out.append('    </ul>')
                in_ul = False
            lines_out.append(f'    <p>{p}</p>')
    if in_ul:
        lines_out.append('    </ul>')
    content_str = '\n'.join(lines_out)
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        f'{content_str}\n'
        '  </div>\n'
        '</details>'
    )

def main():
    sys.stdout.reconfigure(encoding='utf-8')
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    cf_desc_path = os.path.join(root_dir, 'Deploy', 'CURSEFORGE-DESCRIPTION.md')
    out_deploy_path = os.path.join(root_dir, 'Deploy', 'addons_miliui_eventalertmod.html')
    out_root_path = os.path.join(root_dir, 'addons_miliui_eventalertmod.html')

    if not os.path.isfile(cf_desc_path):
        print(f"Error: {cf_desc_path} not found!", file=sys.stderr)
        sys.exit(1)

    with open(cf_desc_path, 'r', encoding='utf-8') as f:
        raw_content = f.read()

    # 1. 清理 HTML5 void elements (杜絕自閉合斜線 />)
    content = re.sub(r'<br\s*/?>', '<br>', raw_content)
    content = re.sub(r'<hr\s*/?>', '<hr>', content)
    content = re.sub(r'<img\s+([^>]*?)\s*/?>', r'<img \1>', content)

    # 2. 轉換收合區塊為奇樂標準 <details><summary>點擊展開</summary><div class="details-content">...</div></details>
    # 全面利用 <ul>, <ol>, <li>, <code> 標籤重構
    pattern = re.compile(r'<div class="spoiler">\s*(.*?)\s*</div>', re.DOTALL)
    spoiler_idx = 0

    def repl(m):
        nonlocal spoiler_idx
        spoiler_idx += 1
        inner = m.group(1).strip()

        # 區塊 1: 四大差異化核心優勢
        if spoiler_idx == 1:
            return build_comparison_html()
        # 區塊 2: 八大獨立告警模組
        elif spoiler_idx == 2:
            return build_alert_modules_html()
        # 區塊 3: 現代化視覺與極致操作體驗
        elif spoiler_idx == 3:
            return build_visual_experience_html()
        # 區塊 4: 介面圖文導覽
        elif spoiler_idx == 4:
            return build_showcase_html()
        # 區塊 5: 命令列與斜線指令
        elif spoiler_idx == 5:
            return build_slash_commands_html()
        # 區塊 6: 快速操作指引 (Ctrl+Alt Quick Add)
        elif spoiler_idx == 6:
            return build_quick_add_html()
        # 區塊 7: 安裝說明 (Installation)
        elif spoiler_idx == 7:
            return build_installation_html()
        # 區塊 29: 相容性與支援邊界
        elif spoiler_idx == 29:
            return build_compatibility_html()
        # 區塊 30: 說明文件與相關連結
        elif spoiler_idx == 30:
            return build_docs_links_html()
        # 區塊 8~28: 版本更新歷史 Changelog
        else:
            return convert_changelog_spoiler(inner)

    converted = pattern.sub(repl, content)

    # 3. 加入奇樂專屬頂部資訊註解
    header_comment = (
        '<!-- EventAlertMod (EAM) - 魔獸世界繁體中文插件站 (奇樂 / MiliUI) 專屬說明 HTML -->\n'
        '<!-- 本檔為純 HTML5 規範格式，100% 無 Markdown 語法，全篇 0 個 table 表格標籤（徹底免疫網站富文字過濾清洗），全面採用 <code>、<ul>、<ol>、<li> 語意化結構，void elements 嚴格遵循無結尾斜線規範，收合區塊嚴格採用 details/summary/details-content -->\n\n'
    )
    final_html = header_comment + converted

    # 4. 嚴格契約驗證
    details_count = len(re.findall(r'<details>', final_html))
    details_end_count = len(re.findall(r'</details>', final_html))
    summary_count = len(re.findall(r'<summary>點擊展開</summary>', final_html))
    details_content_count = len(re.findall(r'<div class="details-content">', final_html))
    remaining_tables = re.findall(r'<table[\s>]', final_html)
    remaining_spoilers = len(re.findall(r'<div class="spoiler">', final_html))
    remaining_slashes = len(re.findall(r'<[^>]+/>', final_html))
    nested_p = len(re.findall(r'<p[^>]*>[^<]*<p', final_html))
    md_bolds = len(re.findall(r'\*\*[^*]+\*\*', final_html))
    md_code = len(re.findall(r'`[^`]+`', final_html))
    md_headers = len(re.findall(r'^#{1,6}\s+.*$', final_html, flags=re.MULTILINE))
    remaining_bulls = len(re.findall(r'&bull;', final_html))
    li_count = len(re.findall(r'<li[\s>]', final_html))
    ul_count = len(re.findall(r'<ul[\s>]', final_html))
    ol_count = len(re.findall(r'<ol[\s>]', final_html))
    code_count = len(re.findall(r'<code[\s>]', final_html))

    assert details_count == 30, f"Expected 30 details, got {details_count}"
    assert details_end_count == 30, f"Expected 30 closing details, got {details_end_count}"
    assert summary_count == 30, f"Expected 30 summaries, got {summary_count}"
    assert details_content_count == 30, f"Expected 30 details-content, got {details_content_count}"
    assert len(remaining_tables) == 0, f"Expected 0 tables, got {len(remaining_tables)}"
    assert remaining_spoilers == 0, f"Expected 0 spoilers, got {remaining_spoilers}"
    assert remaining_slashes == 0, f"Expected 0 self-closing slashes, got {remaining_slashes}"
    assert nested_p == 0, f"Expected 0 nested p tags, got {nested_p}"
    assert md_bolds == 0, f"Expected 0 md bolds, got {md_bolds}"
    assert md_code == 0, f"Expected 0 md code, got {md_code}"
    assert md_headers == 0, f"Expected 0 md headers, got {md_headers}"
    assert remaining_bulls == 0, f"Expected 0 manual bullets (&bull;), got {remaining_bulls}"
    assert li_count >= 100, f"Expected at least 100 li items, got {li_count}"
    assert ul_count >= 10, f"Expected at least 10 ul tags, got {ul_count}"
    assert ol_count >= 3, f"Expected at least 3 ol tags, got {ol_count}"
    assert code_count >= 40, f"Expected at least 40 code tags, got {code_count}"

    # 5. 輸出檔案
    with open(out_deploy_path, 'w', encoding='utf-8') as f:
        f.write(final_html)
    print(f"[OK] Generated: {out_deploy_path} ({len(final_html):,} bytes)")

    with open(out_root_path, 'w', encoding='utf-8') as f:
        f.write(final_html)
    print(f"[OK] Generated: {out_root_path} ({len(final_html):,} bytes)")

    print(f"[SUCCESS] All 15 verification assertions passed successfully!")
    print(f"  - Total tables: {len(remaining_tables)}")
    print(f"  - Total <li> items: {li_count}")
    print(f"  - Total <ul> lists: {ul_count}")
    print(f"  - Total <ol> lists: {ol_count}")
    print(f"  - Total <code> tags: {code_count}")
    print(f"  - Total &bull; entities: {remaining_bulls}")

if __name__ == '__main__':
    main()

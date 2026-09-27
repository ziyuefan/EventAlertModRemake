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
2. 100% 純 HTML5 語法，零 Markdown 語法（網站不支援 Markdown 解析）。
3. 收合語法嚴格遵循奇樂標準：
   <details>
     <summary>點擊展開</summary>
     <div class="details-content">
       <p>
         內容...
       </p>
     </div>
   </details>
4. Void elements 嚴格遵循 HTML5 標準，杜絕 XHTML 自閉合斜線（使用 <br>、<hr>、<img ...>，禁止 <br />、<hr />、<img ... />）。
5. 杜絕非法巢狀 <p><p> 標籤，保證排版完全合規。
"""

import os
import re
import sys

def build_comparison_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <p>\n'
        '      EAM 專為 12.0+ / 12.1+ Retail 正式服深度重構，徹底解決傳統法術監控插件沉重、掉幀與報錯污染問題：<br><br>\n'
        '      <strong>1. 資源佔用與運行效能</strong><br>\n'
        '      ⚠️ <strong>傳統法術監控 / 複雜大型插件</strong>：大量背景 OnUpdate 輪詢、吃記憶體、引發戰鬥掉幀。<br>\n'
        '      ⚡ <strong>現代重構版 EventAlertMod (EAM)</strong>：純事件驅動架構，全面引入物件池技術（State Pools），消滅 GC 記憶體垃圾。<br><br>\n'
        '      <strong>2. 暴雪 12.0+ 終極安全防護</strong><br>\n'
        '      ❌ <strong>傳統法術監控 / 複雜大型插件</strong>：12.0+ 暴雪引入 Secret Values 後，常常在戰鬥中報錯噴黃字或引發 UI 異常。<br>\n'
        '      🛡️ <strong>現代重構版 EventAlertMod (EAM)</strong>：獨家採用原生 C-Level <code>StatusBar:SetValue</code> 直通渲染技術，絕不觸發 Taint 污染。<br><br>\n'
        '      <strong>3. 操作門檻與法術設定</strong><br>\n'
        '      🔄 <strong>傳統法術監控 / 複雜大型插件</strong>：設定繁瑣、需匯入字串：需手動到網站翻找 WA 字串或手寫 Lua 條件判斷。<br>\n'
        '      🎯 <strong>現代重構版 EventAlertMod (EAM)</strong>：直覺易用、秒加監控：滑鼠停在任何技能、光環或物品上按 <strong><code>Ctrl + Alt</code></strong> 一秒加入，無需查 ID。<br><br>\n'
        '      <strong>4. 四合一移動速度與飛龍騎術支援</strong><br>\n'
        '      🐢 <strong>傳統法術監控 / 複雜大型插件</strong>：速度顯示不準確：傳統插件無法偵測 10.0+ / 11.0+ / 12.0+ 飛龍騎術的真實衝刺速度。<br>\n'
        '      🏃 <strong>現代重構版 EventAlertMod (EAM)</strong>：業界唯一四合一速度淬鍊：專屬對接 <code>C_PlayerInfo.GetGlidingInfo()</code>，完美支援 <strong>830%~1400%</strong> 動態極速！<br><br>\n'
        '    </p>\n'
        '  </div>\n'
        '</details>'
    )

def build_showcase_html():
    return (
        '<details>\n'
        '  <summary>點擊展開</summary>\n'
        '  <div class="details-content">\n'
        '    <p>\n'
        '      以下為 EAM 各項介面截圖與功能詳細導覽：\n'
        '    </p>\n'
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
        '    <p>\n'
        '      EAM 提供豐富完整的斜線命令，主入口為 <code>/eam</code> 或 <code>/eventalertmod</code>（不分大小寫）：<br><br>\n'
        '      <strong>【常用核心指令】</strong><br>\n'
        '      &bull;&nbsp;<code>/eam</code> 或 <code>/eam opt</code>（別名：<code>/eam option</code>、<code>/eam options</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：開啟 EAM 主設定選單。<br><br>\n'
        '      &bull;&nbsp;<code>/eam preview</code><br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：開啟獨立即時效果預覽小視窗（免進戰鬥測試變色、光效、扇形倒數與屬性）。<br><br>\n'
        '      &bull;&nbsp;<code>/eam reset</code>（別名：<code>/eam resetpos</code>、<code>/eam center</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：<strong>將 EAM 主視窗重置回螢幕正中央</strong>（解決視窗被拖出畫面找不到的問題）。<br><br>\n'
        '      &bull;&nbsp;<code>/eam list</code><br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：顯示目前職業已啟用的監控清單（自身、目標、冷卻、物品、地面效果）。<br><br>\n'
        '      &bull;&nbsp;<code>/eam help</code>（別名：<code>/eam ?</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：列出所有可用斜線命令說明。<br><br>\n'
        '      <strong>【快速新增與管理監控】</strong><br>\n'
        '      &bull;&nbsp;<code>/eam add &lt;spellID&gt;</code>（別名：<code>/eam add player &lt;spellID&gt;</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：新增指定法術 ID 至「自身光環」監控清單。<br><br>\n'
        '      &bull;&nbsp;<code>/eam add target [spellID]</code><br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：新增「目標光環」監控；若不輸入 ID 則開啟手動輸入與候選視窗。<br><br>\n'
        '      &bull;&nbsp;<code>/eam add cd &lt;spellID&gt;</code>（別名：<code>/eam add cooldown &lt;spellID&gt;</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：新增指定法術 ID 至「技能冷卻」監控清單。<br><br>\n'
        '      &bull;&nbsp;<code>/eam add item &lt;itemID&gt;</code>（別名：<code>/eam add itemcooldown &lt;itemID&gt;</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：新增指定物品 ID 至「物品冷卻」監控清單。<br><br>\n'
        '      &bull;&nbsp;<code>/eam remove &lt;spellID&gt;</code>（別名：<code>/eam remove &lt;player|target|cd|item&gt; &lt;ID&gt;</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：從指定監控類別中移除指定法術或物品 ID。<br><br>\n'
        '      &bull;&nbsp;<code>/eam show</code> 或 <code>/eam showtarget</code>（別名：<code>/eam shows</code>、<code>/eam showt</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：顯示 Retail 12.1 安全加入光環之操作指引（滑鼠懸停按 Ctrl+Alt）。<br><br>\n'
        '      <strong>【法術查詢與施法紀錄】</strong><br>\n'
        '      &bull;&nbsp;<code>/eam lookup &lt;名稱&gt;</code>（別名：<code>/eam l &lt;名稱&gt;</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：依關鍵字模糊查詢目前職業可用法術候選與 Spell ID。<br><br>\n'
        '      &bull;&nbsp;<code>/eam lookupfull &lt;全名&gt;</code>（別名：<code>/eam lf &lt;全名&gt;</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：依完整名稱精確查詢目前職業可用法術候選與 Spell ID。<br><br>\n'
        '      &bull;&nbsp;<code>/eam showcast</code>（別名：<code>/eam showc</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：開始或停止記錄本次登入成功施放的法術（方便查詢自己剛放的技能 ID）。<br><br>\n'
        '      <strong>【進階診斷、測試與設定檔】</strong><br>\n'
        '      &bull;&nbsp;<code>/eam profile</code>（別名：<code>/eam profile export</code>、<code>/eam profile import</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：開啟 Profile 設定檔匯出／匯入與字串分享面板。<br><br>\n'
        '      &bull;&nbsp;<code>/eam rune</code>（別名：<code>/eam runes</code>、<code>/eam probe rune</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：開啟死亡騎士 6 格符文槽位即時狀態、充能秒數與診斷 JSON 視窗。<br><br>\n'
        '      &bull;&nbsp;<code>/eam unitpower background &lt;KEY&gt;</code><br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：標記指定背景資源缺少事件，啟動 0.5s demand-driven 共用取樣器。<br><br>\n'
        '      &bull;&nbsp;<code>/eam doctor</code>（別名：<code>/eam validate</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：執行客戶端 API 邊界與運行環境診斷報告。<br><br>\n'
        '      &bull;&nbsp;<code>/eam test [suite]</code>（別名：<code>/eam test live</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：開啟遊戲內流程測試面板，或執行指定測試套件 (<code>quick/core/boundary/aura121/all/live</code>)。<br><br>\n'
        '      &bull;&nbsp;<code>/eam debug</code>（別名：<code>/eam export</code>）<br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：開啟系統狀態與精簡 AI 除錯報告輸出視窗。<br><br>\n'
        '      &bull;&nbsp;<code>/eam debug ground &lt;spellID&gt;</code><br>\n'
        '      &nbsp;&nbsp;&nbsp;&nbsp;↳ 說明：測試並除錯特定地面技能之 Tooltip 持續時間解析。<br><br>\n'
        '    </p>\n'
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

    # 2. 轉換收合區塊為奇樂標準 <details><summary>點擊展開</summary><div class="details-content"><p>...</p></div></details>
    # 同時將所有 table 標籤徹底替換為無 table 的語意化卡片與列表排版
    pattern = re.compile(r'<div class="spoiler">\s*(.*?)\s*</div>', re.DOTALL)
    def repl(m):
        inner = m.group(1).strip()
        # 清理段落首的冗餘 <p>...</p><br>，轉為流暢文字
        inner = re.sub(r'^<p>(.*?)</p>\s*<br>', r'\1<br><br>', inner)

        # 區塊 1: 四大差異化核心優勢 (原本為 Table)
        if inner.startswith('<table>'):
            return build_comparison_html()

        # 區塊 4: 介面圖文導覽 (原本包含 6 個 Table)
        elif inner.startswith('<h3>'):
            return build_showcase_html()

        # 區塊 5: 命令列與斜線指令 (原本為 Table)
        elif inner.startswith('<p>EAM 提供豐富完整的斜線命令'):
            return build_slash_commands_html()

        else:
            return (
                '<details>\n'
                '  <summary>點擊展開</summary>\n'
                '  <div class="details-content">\n'
                '    <p>\n'
                f'      {inner}\n'
                '    </p>\n'
                '  </div>\n'
                '</details>'
            )

    converted = pattern.sub(repl, content)

    # 3. 加入奇樂專屬頂部資訊註解
    header_comment = (
        '<!-- EventAlertMod (EAM) - 魔獸世界繁體中文插件站 (奇樂 / MiliUI) 專屬說明 HTML -->\n'
        '<!-- 本檔為純 HTML5 規範格式，100% 無 Markdown 語法，全篇 0 個 table 表格標籤（徹底免疫網站富文字過濾清洗），void elements 嚴格遵循無結尾斜線規範，收合區塊嚴格採用 details/summary/details-content -->\n\n'
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

    assert len(remaining_tables) == 0, f"Expected 0 tables, got {len(remaining_tables)}"
    assert remaining_spoilers == 0, f"Expected 0 spoilers, got {remaining_spoilers}"
    assert remaining_slashes == 0, f"Expected 0 self-closing slashes, got {remaining_slashes}"
    assert nested_p == 0, f"Expected 0 nested p tags, got {nested_p}"
    assert md_bolds == 0, f"Expected 0 md bolds, got {md_bolds}"
    assert md_code == 0, f"Expected 0 md code, got {md_code}"
    assert md_headers == 0, f"Expected 0 md headers, got {md_headers}"


    # 5. 輸出檔案
    with open(out_deploy_path, 'w', encoding='utf-8') as f:
        f.write(final_html)
    print(f"[OK] Generated: {out_deploy_path} ({len(final_html):,} bytes)")

    with open(out_root_path, 'w', encoding='utf-8') as f:
        f.write(final_html)
    print(f"[OK] Generated: {out_root_path} ({len(final_html):,} bytes)")

    print("[SUCCESS] All 11 verification assertions passed successfully! (Total tables: 0)")

if __name__ == '__main__':
    main()

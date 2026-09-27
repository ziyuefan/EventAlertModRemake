#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Build-MiliUIDoc.py
------------------
自動建置奇樂 (MiliUI / WoWbox) 專屬純 HTML 說明頁面 addons_miliui_eventalertmod.html。

規範要求：
1. 100% 純 HTML5 語法，零 Markdown 語法（網站不支援 Markdown 解析）。
2. 收合語法嚴格遵循奇樂標準：
   <details>
     <summary>點擊展開</summary>
     <div class="details-content">
       <p>
         內容...
       </p>
     </div>
   </details>
3. Void elements 嚴格遵循 HTML5 標準，杜絕 XHTML 自閉合斜線（使用 <br>、<hr>、<img ...>，禁止 <br />、<hr />、<img ... />）。
4. 杜絕非法巢狀 <p><p> 標籤，保證排版完全合規。
"""

import os
import re
import sys

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
    pattern = re.compile(r'<div class="spoiler">\s*(.*?)\s*</div>', re.DOTALL)
    def repl(m):
        inner = m.group(1).strip()
        # 清理段落首的冗餘 <p>...</p><br>，轉為流暢文字
        inner = re.sub(r'^<p>(.*?)</p>\s*<br>', r'\1<br><br>', inner)

        # 針對包含 Table 或 H3 的特殊區塊進行語意化排版
        if inner.startswith('<table>'):
            return (
                '<details>\n'
                '  <summary>點擊展開</summary>\n'
                '  <div class="details-content">\n'
                '    <p>\n'
                '      EAM 專為 12.0+ / 12.1+ Retail 正式服深度重構，徹底解決傳統法術監控插件沉重、掉幀與報錯污染問題：\n'
                '    </p>\n'
                f'    {inner}\n'
                '  </div>\n'
                '</details>'
            )
        elif inner.startswith('<h3>'):
            return (
                '<details>\n'
                '  <summary>點擊展開</summary>\n'
                '  <div class="details-content">\n'
                '    <p>\n'
                '      以下為 EAM 各項介面截圖與功能詳細導覽：\n'
                '    </p>\n'
                f'    {inner}\n'
                '  </div>\n'
                '</details>'
            )
        elif inner.startswith('<p>EAM 提供豐富完整的斜線命令'):
            return (
                '<details>\n'
                '  <summary>點擊展開</summary>\n'
                '  <div class="details-content">\n'
                f'    {inner}\n'
                '  </div>\n'
                '</details>'
            )
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
        '<!-- 本檔為純 HTML5 規範格式，100% 無 Markdown 語法，void elements 嚴格遵循無結尾斜線規範，收合區塊嚴格採用 details/summary/details-content -->\n\n'
    )
    final_html = header_comment + converted

    # 4. 嚴格契約驗證
    details_count = len(re.findall(r'<details>', final_html))
    details_end_count = len(re.findall(r'</details>', final_html))
    summary_count = len(re.findall(r'<summary>點擊展開</summary>', final_html))
    details_content_count = len(re.findall(r'<div class="details-content">', final_html))
    remaining_spoilers = len(re.findall(r'<div class="spoiler">', final_html))
    remaining_slashes = len(re.findall(r'<[^>]+/>', final_html))
    nested_p = len(re.findall(r'<p[^>]*>[^<]*<p', final_html))
    md_bolds = len(re.findall(r'\*\*[^*]+\*\*', final_html))
    md_code = len(re.findall(r'`[^`]+`', final_html))
    md_headers = len(re.findall(r'^#{1,6}\s+.*$', final_html, flags=re.MULTILINE))

    assert details_count == 30, f"Expected 30 details, got {details_count}"
    assert details_end_count == 30, f"Expected 30 closing details, got {details_end_count}"
    assert summary_count == 30, f"Expected 30 summaries, got {summary_count}"
    assert details_content_count == 30, f"Expected 30 details-content, got {details_content_count}"
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

    print("[SUCCESS] All 10 verification assertions passed successfully!")

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generate_changelog_html.py
--------------------------
自動將 EventAlertMod 專案根目錄之 changelog.txt 解析並生成高質感、支援收合展開 (<details><summary>)、
版本分類標籤與即時關鍵字過濾的現代化 changelog.html。
"""

import os
import sys
import re
import html

def escape(text):
    return html.escape(text.strip())

def parse_changelog(txt_path):
    with open(txt_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    versions = []
    current_version = None

    header_pattern = re.compile(r'^--\s*(\[.+?\](?:\s*\[.+?\])*)(.*)')
    date_pattern = re.compile(r'(\d{4}[.\-/]\d{1,2}[.\-/]\d{1,2})')
    category_pattern = re.compile(r'^\s*--\s*(【.+?】)\s*[:：]?(.*)')

    for raw_line in lines:
        line_stripped = raw_line.strip()
        
        # 忽略單純分隔線
        if re.match(r'^-{3,}$', line_stripped):
            continue

        header_match = header_pattern.match(line_stripped)
        if header_match:
            # 儲存前一個版本
            if current_version:
                versions.append(current_version)

            raw_brackets = header_match.group(1)
            raw_rest = header_match.group(2).strip()

            # 解析括號內容
            brackets = re.findall(r'\[([^\]]+)\]', raw_brackets)
            badges = []
            subtitle = ""

            for b in brackets:
                b_clean = b.strip()
                # 若為簡稱標記或版本標籤
                if len(b_clean) <= 15 or b_clean.startswith("Alpha") or b_clean.startswith("Beta"):
                    badges.append(b_clean)
                else:
                    subtitle = b_clean

            # 解析日期
            date_match = date_pattern.search(raw_rest)
            date_str = date_match.group(1) if date_match else ""

            current_version = {
                "raw_header": line_stripped,
                "badges": badges,
                "subtitle": subtitle,
                "date": date_str,
                "items": []
            }
            continue

        if current_version is not None:
            if not line_stripped:
                continue

            # 計算縮排
            indent = len(raw_line) - len(raw_line.lstrip())
            # 去除開頭的 --
            content = re.sub(r'^\s*--\s*', '', raw_line).strip()
            if not content:
                continue

            # 檢查是否為大分類（如 【✨ 新增功能 (Features)】）
            cat_match = category_pattern.match(raw_line)
            if cat_match:
                cat_name = cat_match.group(1)
                extra_text = cat_match.group(2).strip()
                current_version["items"].append({
                    "type": "category",
                    "name": cat_name,
                    "extra": extra_text,
                    "indent": indent
                })
            else:
                # 判定為主題標題或細項子條目
                # 如果以 : 或 ： 結尾，或者縮排較淺（indent <= 8），通常為小標題
                is_title = (indent <= 7 or content.endswith(":") or content.endswith("：")) and len(content) < 120
                current_version["items"].append({
                    "type": "item",
                    "text": content,
                    "indent": indent,
                    "is_title": is_title
                })

    if current_version:
        versions.append(current_version)

    return versions

def render_html(versions):
    total_versions = len(versions)
    latest_version = versions[0] if versions else None
    latest_ver_title = " ".join(latest_version["badges"]) if latest_version else "Unknown"
    latest_date = latest_version["date"] if latest_version else "Unknown"

    cards_html = []

    for idx, ver in enumerate(versions):
        is_first = (idx == 0)
        open_attr = ' open' if is_first else ''
        
        # 徽章 HTML
        badges_html = []
        for b in ver["badges"]:
            b_class = "badge-generic"
            if "Retail" in b:
                b_class = "badge-retail"
            elif "MN" in b:
                b_class = "badge-mn"
            elif "Alpha" in b:
                b_class = "badge-alpha"
            elif "Beta" in b:
                b_class = "badge-beta"
            elif "Classic" in b:
                b_class = "badge-classic"
            elif "LEG" in b:
                b_class = "badge-leg"
            badges_html.append(f'<span class="badge {b_class}">{escape(b)}</span>')

        badges_rendered = "".join(badges_html)
        subtitle_rendered = f'<span class="version-subtitle">{escape(ver["subtitle"])}</span>' if ver["subtitle"] else ""
        date_rendered = f'<span class="version-date">📅 {escape(ver["date"])}</span>' if ver["date"] else ""

        # 內容列表 HTML 構建
        body_parts = []
        in_list = False
        in_sub_list = False
        current_cat_div = False

        for item in ver["items"]:
            if item["type"] == "category":
                # 關閉之前的清單
                if in_sub_list:
                    body_parts.append('</ul>')
                    in_sub_list = False
                if in_list:
                    body_parts.append('</ul>')
                    in_list = False
                if current_cat_div:
                    body_parts.append('</div>')
                    current_cat_div = False

                cat_name = item["name"]
                cat_class = "cat-generic"
                if "新增" in cat_name or "Features" in cat_name:
                    cat_class = "cat-feature"
                elif "優化" in cat_name or "Improvements" in cat_name:
                    cat_class = "cat-improvement"
                elif "修復" in cat_name or "Bug Fixes" in cat_name:
                    cat_class = "cat-fix"
                elif "在地化" in cat_name or "Localization" in cat_name:
                    cat_class = "cat-locale"

                body_parts.append(f'<div class="category-block {cat_class}">')
                body_parts.append(f'<div class="category-title">{escape(cat_name)}</div>')
                current_cat_div = True
                continue

            # 普通條目
            text = item["text"]
            # 語法高亮一些常用指令與代碼標籤
            highlighted_text = escape(text)
            highlighted_text = re.sub(r'(/eam\s+[\w\s]+)', r'<code>\1</code>', highlighted_text)
            highlighted_text = re.sub(r'(/reload)', r'<code>\1</code>', highlighted_text)
            highlighted_text = re.sub(r'(CTRL\+ALT|Ctrl\+Alt)', r'<kbd>\1</kbd>', highlighted_text)

            indent = item["indent"]
            if indent >= 8:
                if not in_sub_list:
                    if not in_list:
                        body_parts.append('<ul class="changelog-list">')
                        in_list = True
                    body_parts.append('<ul class="changelog-sublist">')
                    in_sub_list = True
                body_parts.append(f'<li>{highlighted_text}</li>')
            else:
                if in_sub_list:
                    body_parts.append('</ul>')
                    in_sub_list = False
                if not in_list:
                    body_parts.append('<ul class="changelog-list">')
                    in_list = True
                
                if item["is_title"]:
                    body_parts.append(f'<li class="item-title"><strong>{highlighted_text}</strong></li>')
                else:
                    body_parts.append(f'<li>{highlighted_text}</li>')

        if in_sub_list:
            body_parts.append('</ul>')
        if in_list:
            body_parts.append('</ul>')
        if current_cat_div:
            body_parts.append('</div>')

        content_html = "\n".join(body_parts)

        card = f"""
        <details class="version-card"{open_attr} id="ver-{idx}">
            <summary class="version-summary">
                <div class="summary-left">
                    <span class="chevron">▶</span>
                    <div class="badge-group">{badges_rendered}</div>
                    {subtitle_rendered}
                </div>
                <div class="summary-right">
                    {date_rendered}
                </div>
            </summary>
            <div class="version-body">
                {content_html}
            </div>
        </details>
        """
        cards_html.append(card)

    cards_rendered = "\n".join(cards_html)

    html_template = f"""<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EventAlertMod (EAM) 完整更新日誌 (Changelog)</title>
    <style>
        :root {{
            --bg-color: #0d1117;
            --panel-bg: #161b22;
            --card-bg: #1c2128;
            --border-color: #30363d;
            --text-main: #e6edf3;
            --text-sub: #8b949e;
            --accent-gold: #f8b700;
            --accent-gold-dark: #d29922;
            --code-bg: #21262d;
            --link-color: #58a6ff;
            --font-stack: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", "PingFang TC", "Microsoft JhengHei", sans-serif;
            --radius-md: 8px;
            --radius-lg: 12px;
        }}

        @media (prefers-color-scheme: light) {{
            :root {{
                --bg-color: #f6f8fa;
                --panel-bg: #ffffff;
                --card-bg: #f9fafb;
                --border-color: #d0d7de;
                --text-main: #1f2328;
                --text-sub: #656d76;
                --accent-gold: #b08800;
                --accent-gold-dark: #8c6d00;
                --code-bg: #eaeef2;
                --link-color: #0969da;
            }}
        }}

        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}

        body {{
            background-color: var(--bg-color);
            color: var(--text-main);
            font-family: var(--font-stack);
            line-height: 1.6;
            padding: 24px 16px 80px;
        }}

        .container {{
            max-width: 1080px;
            margin: 0 auto;
        }}

        /* Header */
        header.page-header {{
            background: linear-gradient(135deg, rgba(248, 183, 0, 0.08) 0%, rgba(22, 27, 34, 0.95) 100%);
            border: 1px solid var(--border-color);
            border-top: 4px solid var(--accent-gold);
            border-radius: var(--radius-lg);
            padding: 28px 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25);
        }}

        h1.title {{
            font-size: 1.85rem;
            font-weight: 800;
            color: var(--text-main);
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 10px;
            letter-spacing: -0.5px;
        }}

        h1.title .gold {{
            color: var(--accent-gold);
        }}

        .header-meta {{
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            gap: 16px;
            font-size: 0.92rem;
            color: var(--text-sub);
        }}

        .meta-pill {{
            background-color: var(--card-bg);
            border: 1px solid var(--border-color);
            padding: 4px 12px;
            border-radius: 20px;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }}

        /* Sticky Control Bar */
        .control-bar {{
            position: sticky;
            top: 12px;
            z-index: 100;
            background-color: var(--panel-bg);
            border: 1px solid var(--border-color);
            border-radius: var(--radius-md);
            padding: 12px 18px;
            margin-bottom: 24px;
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
            backdrop-filter: blur(8px);
        }}

        .btn-group {{
            display: flex;
            gap: 8px;
            flex-wrap: wrap;
        }}

        button.btn {{
            background-color: var(--card-bg);
            color: var(--text-main);
            border: 1px solid var(--border-color);
            padding: 6px 14px;
            border-radius: 6px;
            font-size: 0.88rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.15s ease-in-out;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }}

        button.btn:hover {{
            background-color: var(--border-color);
            border-color: var(--accent-gold);
            color: var(--accent-gold);
        }}

        .search-box {{
            flex: 1;
            min-width: 240px;
            max-width: 380px;
            position: relative;
        }}

        .search-box input {{
            width: 100%;
            background-color: var(--bg-color);
            border: 1px solid var(--border-color);
            border-radius: 6px;
            color: var(--text-main);
            padding: 6px 12px 6px 32px;
            font-size: 0.9rem;
            outline: none;
            transition: border-color 0.15s;
        }}

        .search-box input:focus {{
            border-color: var(--accent-gold);
        }}

        .search-icon {{
            position: absolute;
            left: 10px;
            top: 50%;
            transform: translateY(-50%);
            color: var(--text-sub);
            pointer-events: none;
            font-size: 0.85rem;
        }}

        /* Version Card (<details>) */
        details.version-card {{
            background-color: var(--panel-bg);
            border: 1px solid var(--border-color);
            border-radius: var(--radius-lg);
            margin-bottom: 16px;
            overflow: hidden;
            transition: border-color 0.2s, box-shadow 0.2s;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12);
        }}

        details.version-card:hover {{
            border-color: rgba(248, 183, 0, 0.5);
        }}

        details.version-card[open] {{
            border-color: var(--border-color);
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
        }}

        summary.version-summary {{
            list-style: none;
            cursor: pointer;
            padding: 16px 20px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 16px;
            background-color: var(--card-bg);
            border-bottom: 1px solid transparent;
            user-select: none;
            transition: background-color 0.15s;
        }}

        summary.version-summary::-webkit-details-marker {{
            display: none;
        }}

        summary.version-summary:hover {{
            background-color: rgba(248, 183, 0, 0.04);
        }}

        details[open] summary.version-summary {{
            border-bottom: 1px solid var(--border-color);
            background-color: rgba(248, 183, 0, 0.05);
        }}

        .summary-left {{
            display: flex;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
            flex: 1;
        }}

        .chevron {{
            font-size: 0.8rem;
            color: var(--text-sub);
            transition: transform 0.2s ease;
            width: 16px;
            display: inline-block;
            text-align: center;
        }}

        details[open] .chevron {{
            transform: rotate(90deg);
            color: var(--accent-gold);
        }}

        .badge-group {{
            display: inline-flex;
            gap: 6px;
            flex-wrap: wrap;
            align-items: center;
        }}

        /* Badges */
        .badge {{
            display: inline-block;
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 0.78rem;
            font-weight: 700;
            letter-spacing: 0.3px;
            line-height: 1.2;
        }}

        .badge-retail {{
            background-color: #0369a1;
            color: #f0f9ff;
        }}

        .badge-mn {{
            background-color: #6366f1;
            color: #ffffff;
        }}

        .badge-alpha {{
            background-color: #854d0e;
            color: #fef08a;
            border: 1px solid #ca8a04;
        }}

        .badge-beta {{
            background-color: #1e3a8a;
            color: #bfdbfe;
        }}

        .badge-classic {{
            background-color: #713f12;
            color: #fef3c7;
        }}

        .badge-leg {{
            background-color: #166534;
            color: #dcfce7;
        }}

        .badge-generic {{
            background-color: #374151;
            color: #f3f4f6;
        }}

        .version-subtitle {{
            font-weight: 600;
            font-size: 1.02rem;
            color: var(--text-main);
        }}

        .version-date {{
            font-size: 0.85rem;
            color: var(--text-sub);
            white-space: nowrap;
            font-variant-numeric: tabular-nums;
        }}

        /* Version Body */
        .version-body {{
            padding: 20px 24px;
        }}

        /* Category Blocks */
        .category-block {{
            margin-bottom: 20px;
            padding: 14px 18px;
            border-radius: var(--radius-md);
            border: 1px solid var(--border-color);
            background-color: var(--card-bg);
        }}

        .cat-feature {{
            border-left: 4px solid #10b981;
        }}

        .cat-improvement {{
            border-left: 4px solid #0ea5e9;
        }}

        .cat-fix {{
            border-left: 4px solid #f59e0b;
        }}

        .cat-locale {{
            border-left: 4px solid #8b5cf6;
        }}

        .category-title {{
            font-weight: 700;
            font-size: 1.05rem;
            margin-bottom: 12px;
            color: var(--text-main);
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        /* Changelog Lists */
        ul.changelog-list {{
            list-style: disc;
            padding-left: 20px;
            margin-bottom: 10px;
        }}

        ul.changelog-list > li {{
            margin-bottom: 8px;
            color: var(--text-main);
            font-size: 0.94rem;
            line-height: 1.6;
        }}

        ul.changelog-list > li.item-title {{
            list-style: square;
            color: var(--accent-gold);
            margin-top: 10px;
            font-size: 0.97rem;
        }}

        ul.changelog-sublist {{
            list-style: circle;
            padding-left: 20px;
            margin-top: 6px;
            margin-bottom: 8px;
        }}

        ul.changelog-sublist > li {{
            margin-bottom: 6px;
            color: var(--text-sub);
            font-size: 0.91rem;
            line-height: 1.55;
        }}

        code {{
            background-color: var(--code-bg);
            color: #ec4899;
            padding: 2px 6px;
            border-radius: 4px;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 0.88em;
            border: 1px solid rgba(255, 255, 255, 0.08);
        }}

        kbd {{
            background-color: var(--code-bg);
            border: 1px solid var(--border-color);
            border-bottom-width: 2px;
            color: var(--text-main);
            padding: 1px 5px;
            border-radius: 4px;
            font-family: inherit;
            font-size: 0.85em;
            box-shadow: 0 1px 1px rgba(0,0,0,0.2);
        }}

        /* Footer */
        footer.page-footer {{
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid var(--border-color);
            color: var(--text-sub);
            font-size: 0.85rem;
        }}

        /* Back to top */
        #backToTop {{
            position: fixed;
            bottom: 24px;
            right: 24px;
            background-color: var(--accent-gold);
            color: #000;
            border: none;
            width: 44px;
            height: 44px;
            border-radius: 50%;
            font-size: 1.2rem;
            cursor: pointer;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
            display: none;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
            z-index: 999;
        }}

        #backToTop:hover {{
            transform: scale(1.1);
            background-color: #ffd043;
        }}
    </style>
</head>
<body>
    <div class="container">
        <header class="page-header">
            <h1 class="title">
                <span>📜</span>
                <span>EventAlertMod (EAM) <span class="gold">更新日誌</span></span>
            </h1>
            <div class="header-meta">
                <div class="meta-pill">
                    <span>🔥 最新版本:</span>
                    <strong>{escape(latest_ver_title)}</strong>
                </div>
                <div class="meta-pill">
                    <span>📅 發布日期:</span>
                    <strong>{escape(latest_date)}</strong>
                </div>
                <div class="meta-pill">
                    <span>📦 歷史版本數:</span>
                    <strong>{total_versions} 個版本記錄</strong>
                </div>
            </div>
        </header>

        <!-- 控制工具列 -->
        <div class="control-bar">
            <div class="btn-group">
                <button class="btn" onclick="expandAll()">
                    <span>➕</span> 展開全部
                </button>
                <button class="btn" onclick="collapseAll()">
                    <span>➖</span> 收合全部
                </button>
                <button class="btn" onclick="latestOnly()">
                    <span>⭐</span> 僅看最新
                </button>
            </div>
            <div class="search-box">
                <span class="search-icon">🔍</span>
                <input type="text" id="searchInput" placeholder="搜尋版本號、功能或修復內容..." oninput="handleSearch()">
            </div>
        </div>

        <!-- 版本卡片列表 -->
        <main id="versionContainer">
            {cards_rendered}
        </main>

        <footer class="page-footer">
            <p>EventAlertMod (EAM) for World of Warcraft &copy; 2026. All rights reserved.</p>
            <p>本文件由 <code>.AI/Tools/generate_changelog_html.py</code> 自動同步自 <code>changelog.txt</code> 生成。</p>
        </footer>
    </div>

    <button id="backToTop" onclick="window.scrollTo({{top: 0, behavior: 'smooth'}})" title="返回頂部">▲</button>

    <script>
        function expandAll() {{
            document.querySelectorAll('details.version-card').forEach(d => d.open = true);
        }}

        function collapseAll() {{
            document.querySelectorAll('details.version-card').forEach(d => d.open = false);
        }}

        function latestOnly() {{
            document.querySelectorAll('details.version-card').forEach((d, idx) => {{
                d.open = (idx === 0);
            }});
        }}

        function handleSearch() {{
            const query = document.getElementById('searchInput').value.trim().toLowerCase();
            const cards = document.querySelectorAll('details.version-card');

            cards.forEach(card => {{
                if (!query) {{
                    card.style.display = '';
                    return;
                }}
                const text = card.textContent.toLowerCase();
                if (text.includes(query)) {{
                    card.style.display = '';
                    card.open = true; // 搜尋時自動展開吻合的版本卡片
                }} else {{
                    card.style.display = 'none';
                }}
            }});
        }}

        window.addEventListener('scroll', () => {{
            const btn = document.getElementById('backToTop');
            if (window.scrollY > 400) {{
                btn.style.display = 'flex';
            }} else {{
                btn.style.display = 'none';
            }}
        }});
    </script>
</body>
</html>
"""
    return html_template

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, "..", ".."))

    changelog_txt = os.path.join(project_root, "changelog.txt")
    if not os.path.exists(changelog_txt):
        print(f"錯誤：找不到 {changelog_txt}")
        sys.exit(1)

    print(f"[*] 讀取並解析：{changelog_txt}")
    versions = parse_changelog(changelog_txt)
    print(f"[+] 成功解析 {len(versions)} 個版本！")

    html_content = render_html(versions)

    # 輸出至根目錄與 EventAlertMod 插件目錄
    targets = [
        os.path.join(project_root, "changelog.html"),
        os.path.join(project_root, "EventAlertMod", "changelog.html")
    ]

    for target in targets:
        with open(target, 'w', encoding='utf-8') as f:
            f.write(html_content)
        size_kb = os.path.getsize(target) / 1024
        print(f"[OK] 已生成：{target} ({size_kb:.2f} KB)")

if __name__ == "__main__":
    main()

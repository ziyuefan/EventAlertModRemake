# -*- coding: utf-8 -*-
import os
import re
import glob
import sys
import subprocess
import shutil

# 設定 EAM_DOCS_OFFLINE=1 時，翻譯函式會在任何外部請求前回傳原文。
# Ensure markdown library is installed
try:
    import markdown
except ImportError:
    print("Installing markdown module...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "markdown"])
    import markdown

import urllib.request
import urllib.parse
import json
import time

import hashlib
import random

CACHE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".translation_cache.json")
TRANSLATION_CACHE = {}
OFFLINE_MODE = os.environ.get("EAM_DOCS_OFFLINE") == "1"

def post_process_translation(text, src_lang, dest_lang):
    if dest_lang == "zh-TW":
        # 1. 替換零售與正式服相關
        text = re.sub(r'零售業?', '正式服', text)
        text = re.sub(r'零售版', '正式版', text)
        text = re.sub(r'魔獸世界零售', '魔獸世界正式服', text)
        text = re.sub(r'主線/零售', '主線/正式服', text)
        text = re.sub(r'零售和遺留', '正式服與舊版', text)
        
        # 2. 替換 spell / 拼寫 / 咒語
        text = re.sub(r'咒語', '法術', text)
        text = re.sub(r'拼寫', '法術', text)
        text = re.sub(r'拼字', '法術', text)
        
        # 3. 替換 ticker / 股票
        text = re.sub(r'股票', '計時器', text)
        text = re.sub(r'股票代號', '定時器', text)
        text = re.sub(r'時間小組', '定時器', text)
        text = re.sub(r'自動更新器', '計時器', text)
        text = re.sub(r'定時處理', '定時器處理', text)
        
        # 4. 修正一些常見專有名詞的硬翻
        text = re.sub(r'奧術費用', '奧術充能', text)
        text = re.sub(r'遞歸', '遞迴', text)
        text = re.sub(r'調試', '除錯', text)
        text = re.sub(r'副資源', '特殊能量', text)
        text = re.sub(r'項目冷卻', '物品冷卻', text)
        text = re.sub(r'項目ID', '物品ID', text)
        text = re.sub(r'項目 ID', '物品 ID', text)
        text = re.sub(r'項目範圍', '物品範圍', text)
        text = re.sub(r'大型項目', '大型物品', text)
        text = re.sub(r'突變', '狀態變更', text)
        text = re.sub(r'回調', '回呼', text)
        text = re.sub(r'回調函數', '回呼函式', text)
        text = re.sub(r'回調函式', '回呼函式', text)
        text = re.sub(r'內存', '記憶體', text)
        text = re.sub(r'線程', '執行緒', text)
        text = re.sub(r'充電', '充能', text)
        text = re.sub(r'卡塔經典', '浩劫與重生經典服', text)
        text = re.sub(r'卡塔經典賽', '浩劫與重生經典服', text)
        text = re.sub(r'憤怒經典', '巫妖王之怒經典服', text)
        text = re.sub(r'憤怒經典賽', '巫妖王之怒經典服', text)
        text = re.sub(r'霧經典', '熊貓人之謎經典服', text)
        text = re.sub(r'霧經典賽', '熊貓人之謎經典服', text)
        text = re.sub(r'TBC經典賽', '燃燒的遠征經典服', text)
        text = re.sub(r'TBC經典', '燃燒的遠征經典服', text)
        text = re.sub(r'戰鬥時間框架', '戰鬥中框架', text)
        text = re.sub(r'專案範圍掃描', '物品範圍掃描', text)
        text = re.sub(r'專案首頁', '首頁', text)
        text = re.sub(r'本文件通行證', '本文件', text)
        text = re.sub(r'這個文件通行證', '本文件', text)
        text = re.sub(r'這份文件通行證', '本文件', text)
        
        # 5. 強制還原一些被硬翻的專案路徑與資料夾片段
        text = re.sub(r'\b主/EventAlert', 'Main/EventAlert', text)
        text = re.sub(r'\b主線/Main', 'Mainline/Main', text)
        text = re.sub(r'圖像/、音樂/', 'Images/、Sounds/', text)
        text = re.sub(r'圖像/ 和 音樂/', 'Images/ 和 Sounds/', text)
        text = re.sub(r'\b主/', 'Main/', text)
        text = re.sub(r'\b圖像/', 'Images/', text)
        text = re.sub(r'\b音樂/', 'Sounds/', text)
        
        # 6. 強制還原暴雪 XML 範本和字體物件的錯翻
        text = re.sub(r'選項滑桿模板', 'OptionsSliderTemplate', text)
        text = re.sub(r'輸入框模板', 'InputBoxTemplate', text)
        text = re.sub(r'背景模板', 'BackdropTemplate', text)
        text = re.sub(r'遊戲字體正常', 'GameFontNormal', text)
        text = re.sub(r'遊戲字體突出顯示', 'GameFontHighlight', text)
        
        # 7. 強制還原常數、性能、選項這幾個在清單對照中被錯翻的檔案名稱
        text = re.sub(r'\b常數\s*[：:]', 'Constants: ', text)
        text = re.sub(r'\b性能\s*[：:]', 'Performance: ', text)
        text = re.sub(r'\b選項\s*[：:]', 'Options: ', text)
    elif dest_lang == "en":
        # 1. 修正中翻英時正式服的硬翻
        text = re.sub(r'\b(?:formal|official|retail)\s+server\b', 'Retail server', text, flags=re.IGNORECASE)
        text = re.sub(r'\b(?:formal|official|retail)\s+servers\b', 'Retail servers', text, flags=re.IGNORECASE)
        text = re.sub(r'\bretail\s+edition\b', 'Retail edition', text, flags=re.IGNORECASE)
        text = re.sub(r'\bretail\s+version\b', 'Retail version', text, flags=re.IGNORECASE)
        text = re.sub(r'\bretail\s+client\b', 'Retail client', text, flags=re.IGNORECASE)
        text = re.sub(r'\b(?:formal|official|retail)\s+branch\b', 'Retail branch', text, flags=re.IGNORECASE)
        # 確保 Retail 是大寫
        text = re.sub(r'\bretail\b', 'Retail', text)
        
        # 2. 修正中翻英時經典服的翻譯
        text = re.sub(r'\bclassic\s+server\b', 'Classic server', text, flags=re.IGNORECASE)
        text = re.sub(r'\bclassic\s+servers\b', 'Classic servers', text, flags=re.IGNORECASE)
        text = re.sub(r'\bclassic\b', 'Classic', text)
        text = re.sub(r'\b(?:Cataclysm|Cata)\s+Classic\b', 'Cataclysm Classic', text, flags=re.IGNORECASE)
        text = re.sub(r'\bWrath\s+Classic\b', 'Wrath of the Lich King Classic', text, flags=re.IGNORECASE)
        text = re.sub(r'\bTBC\s+Classic\b', 'The Burning Crusade Classic', text, flags=re.IGNORECASE)
        text = re.sub(r'\bMists\s+of\s+Pandaria\s+Classic\b', 'Mists of Pandaria Classic', text, flags=re.IGNORECASE)
        
        # 3. 修正中翻英時魔獸專用詞彙與程式代碼
        text = re.sub(r'\b(?:charms?|conjurations?|spellings?)\b', 'Spell', text, flags=re.IGNORECASE)
        text = re.sub(r'\b(?:stocks?|stock\s+tickers?)\b', 'Ticker', text, flags=re.IGNORECASE)
        text = re.sub(r'\b(?:tainted?|dye|coloration)\b', 'Taint', text, flags=re.IGNORECASE)
        text = re.sub(r'\bcombat\s+(?:locking|locked)\b', 'Combat Lockdown', text, flags=re.IGNORECASE)
        text = re.sub(r'\bshadow\s+carrier\b', 'Shadow Host', text, flags=re.IGNORECASE)
        text = re.sub(r'\bzero\s+distribution\b', 'zero-allocation', text, flags=re.IGNORECASE)
        text = re.sub(r'\b(?:object\s+pool|entity\s+pool)\b', 'Object Pool', text, flags=re.IGNORECASE)
        text = re.sub(r'\bcooldown\s+manager\b', 'CooldownViewer', text, flags=re.IGNORECASE)
        text = re.sub(r'\badd-ons?\b', 'AddOn', text, flags=re.IGNORECASE)
        text = re.sub(r'\baddons?\b', 'AddOn', text, flags=re.IGNORECASE)
        text = re.sub(r'\bauras?\b', 'Aura', text, flags=re.IGNORECASE)
    return text

def protect_symbols(text):
    placeholders = []
    
    # 匹配魔獸 API、檔案路徑、小駝峰/大駝峰、大寫底線、括號函數呼叫等
    pattern = re.compile(
        r'('
        r'`[^`]+`' # 反單引號包裹的程式碼（必須在最前面，優先匹配，防止被拆開）
        r'|\b[\w/\\]+\.(?:lua|toc|xml|md|html|txt|json|yml|yaml|png|jpg|gif|blp)\b' # 有副檔名的路徑，如 Main/EventAlert_Options.xml
        r'|\b(?i:Main|Images|Sounds|Classic|TBC|Wrath|libs|locale|DevDocument|Core|Services|UI|Data|Managers|Debug|Tools|Music|Image)/[a-zA-Z0-9_/-]*' # 帶斜線的目錄路徑，不分大小寫，如 Main/、Images/、libs/、image/、music/ 等
        r'|\bC_[a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_]+)*\b' # C_ 開頭 API
        r'|/[a-zA-Z0-9_-]+\b' # Slash commands 如 /run, /dump, /eventtrace, /eam
        r'|\b[a-zA-Z0-9_]*Template\b' # 以 Template 結尾的 XML 模板名稱，如 UIPanelButtonTemplate, BackdropTemplate
        r'|\bGameFont[a-zA-Z0-9_]*\b' # 暴雪字體範本，如 GameFontNormal, GameFontHighlight
        r'|\b[A-Z_][A-Z0-9_]{2,}\b' # 全大寫單字或事件，如 UNIT_AURA, COMBAT_LOG_EVENT_UNFILTERED, API, GC
        r'|\b[a-zA-Z0-9_]+_[a-zA-Z0-9_]+\b' # 底線變數/事件如 UNIT_AURA, EventAlertMod
        r'|\bEAM(?:\.[a-zA-Z0-9_]+)*\b' # EAM.API, EAM.L 命名空間
        r'|\b[a-z]+[A-Z][a-zA-Z0-9]*\b'  # 小駝峰如 classID, specIndex, timerTokenPool
        r'|\b[A-Z][a-z]+[A-Z][a-zA-Z0-9]*\b' # 大駝峰如 GetSpellCooldown, InCombatLockdown, CooldownFrame
        r'|\b[a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_]+)*\(\)\b' # 函數呼叫如 IsZero()
        r'|[\'"][a-zA-Z0-9_.-]+[\'"]' # 引號包裹的代碼字串，例如 'spellId', "timerTokenPool"
        r')'
    )
    
    def replace_match(match):
        val = match.group(1)
        for idx, pval in enumerate(placeholders):
            if pval == val:
                return f"__EAMCODE_{idx}__"
        idx = len(placeholders)
        placeholders.append(val)
        return f"__EAMCODE_{idx}__"
        
    protected_text = pattern.sub(replace_match, text)
    return protected_text, placeholders

def restore_symbols(text, placeholders):
    if not placeholders:
        return text
    def replace_placeholder(match):
        idx = int(match.group(1))
        if idx < len(placeholders):
            return placeholders[idx]
        return match.group(0)
    # 用寬鬆的正則匹配以防 Google 翻譯在底線前後加上空格
    restored = re.sub(r'__\s*EAMCODE\s*_\s*(\d+)\s*__', replace_placeholder, text)
    return restored

def load_cache():
    global TRANSLATION_CACHE
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                TRANSLATION_CACHE = json.load(f)
            
            # 清洗快取中的所有中文 value
            dirty = False
            for lang_key, entries in TRANSLATION_CACHE.items():
                if not isinstance(entries, dict):
                    continue
                if lang_key == "en_to_zh-TW" or lang_key == "zh-TW_to_en":
                    dest_lang = "zh-TW" if lang_key == "en_to_zh-TW" else "en"
                    for text_hash, translated in list(entries.items()):
                        cleaned = post_process_translation(translated, "en" if dest_lang == "zh-TW" else "zh-TW", dest_lang)
                        if cleaned != translated:
                            entries[text_hash] = cleaned
                            dirty = True
            
            if dirty:
                print("[Cache] Detected uncleaned translation terms in cache. Cleaned and saving back...")
                save_cache()
                
            total_entries = sum(len(v) for v in TRANSLATION_CACHE.values() if isinstance(v, dict))
            print(f"[Cache] Loaded {total_entries} entries from {CACHE_FILE}")
        except Exception as e:
            print(f"[Cache Warning] Failed to load cache: {e}")
            TRANSLATION_CACHE = {}
    else:
        TRANSLATION_CACHE = {}

def save_cache():
    try:
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(TRANSLATION_CACHE, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"[Cache Error] Failed to save cache: {e}")

def get_cached_translation(text, src_lang, dest_lang):
    key = f"{src_lang}_to_{dest_lang}"
    if key not in TRANSLATION_CACHE:
        return None
    text_hash = hashlib.md5(text.encode('utf-8')).hexdigest()
    return TRANSLATION_CACHE[key].get(text_hash)

def set_cached_translation(text, translated, src_lang, dest_lang):
    key = f"{src_lang}_to_{dest_lang}"
    if key not in TRANSLATION_CACHE:
        TRANSLATION_CACHE[key] = {}
    text_hash = hashlib.md5(text.encode('utf-8')).hexdigest()
    TRANSLATION_CACHE[key][text_hash] = translated
    save_cache()

def is_chinese_text(text):
    # Detects if the text contains Chinese characters
    return bool(re.search(r'[\u4e00-\u9fff]', text))

def translate_chunk(chunk_text, src_lang="zh-TW", dest_lang="en"):
    if not chunk_text.strip():
        return chunk_text
    if OFFLINE_MODE:
        return chunk_text
        
    # Check cache first
    cached = get_cached_translation(chunk_text, src_lang, dest_lang)
    if cached:
        return cached

    # Protect code symbols before translation
    protected_text, placeholders = protect_symbols(chunk_text)

    # Rate limit delay: sleep random 1.2s to 2.8s before every API call to prevent being blocked
    time.sleep(random.uniform(1.2, 2.8))
    
    max_retries = 5
    timeout_val = 8.0
    clients = ["gtx", "dict-chrome-ex", "t"]
    
    for attempt in range(max_retries):
        client = clients[attempt % len(clients)]
        try:
            query = urllib.parse.quote(protected_text)
            url = f"https://translate.googleapis.com/translate_a/single?client={client}&sl={src_lang}&tl={dest_lang}&dt=t&q={query}"
            
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=timeout_val) as response:
                result = json.loads(response.read().decode('utf-8'))
                
            translated_part = "".join([part[0] for part in result[0] if part[0]])
            if translated_part:
                # Restore protected symbols
                restored_text = restore_symbols(translated_part, placeholders)
                # Apply glossary corrections
                final_translated = post_process_translation(restored_text, src_lang, dest_lang)
                
                set_cached_translation(chunk_text, final_translated, src_lang, dest_lang)
                return final_translated
        except Exception as e:
            wait_time = (2 ** attempt) * 3.0 + random.uniform(0.5, 1.5)
            print(f"  [Chunk Warning] Translate chunk failed (client={client}): {e}. Retrying in {wait_time:.1f}s... (Attempt {attempt+1}/{max_retries})")
            time.sleep(wait_time)
            
    print(f"  [Chunk Error] All {max_retries} attempts failed. Fallback to original text (Not Cached).")
    return chunk_text

def translate_via_google_api(text, src_lang="zh-TW", dest_lang="en"):
    if not text.strip():
        return ""
    try:
        text = text.replace('\r\n', '\n')
        
        # 1. Parse text into segments (code blocks vs plain text) using state machine
        segments = []
        lines = text.split('\n')
        in_code_block = False
        current_block = []
        
        for line in lines:
            if line.strip().startswith("```"):
                if in_code_block:
                    # Closing code block
                    current_block.append(line)
                    segments.append(("\n".join(current_block), True))
                    current_block = []
                    in_code_block = False
                else:
                    # Starting code block
                    if current_block:
                        segments.append(("\n".join(current_block), False))
                    current_block = [line]
                    in_code_block = True
            else:
                current_block.append(line)
                
        if current_block:
            segments.append(("\n".join(current_block), in_code_block))
            
        # 2. Process segments and translate plain text
        translated_segments = []
        for content, is_code in segments:
            if is_code or not content.strip():
                translated_segments.append(content)
                continue
                
            # For plain text, split into smaller chunks (max 1200 characters encoded)
            sub_lines = content.split('\n')
            current_sub_chunk = []
            current_sub_len = 0
            
            for sub_line in sub_lines:
                sub_line_encoded = urllib.parse.quote(sub_line)
                encoded_len = len(sub_line_encoded)
                
                # If single line is too long, we translate it alone
                if encoded_len > 1200:
                    if current_sub_chunk:
                        translated_segments.append(translate_chunk("\n".join(current_sub_chunk), src_lang, dest_lang))
                        current_sub_chunk = []
                        current_sub_len = 0
                    translated_segments.append(translate_chunk(sub_line, src_lang, dest_lang))
                elif current_sub_len + encoded_len > 1200:
                    translated_segments.append(translate_chunk("\n".join(current_sub_chunk), src_lang, dest_lang))
                    current_sub_chunk = [sub_line]
                    current_sub_len = encoded_len
                else:
                    current_sub_chunk.append(sub_line)
                    current_sub_len += encoded_len + 3 # %0A for \n
                    
            if current_sub_chunk:
                translated_segments.append(translate_chunk("\n".join(current_sub_chunk), src_lang, dest_lang))
                
        return "\n".join(translated_segments)
    except Exception as e:
        print(f"[Warning] Translation failed: {e}")
        return None



COMMON_CSS_VARIABLES = """
    :root {
        --base-font-size: 16px;
        --bg-color: #0f172a;
        --text-color: #cbd5e1;
        --heading-color: #f8fafc;
        --accent-color: #38bdf8;
        --panel-bg: #1e293b;
        --border-color: #334155;
        --code-color: #f1f5f9;
    }
"""

CONTROL_PANEL_HTML = """
    <div class="top-nav-bar">
        <div class="nav-container">
            <a href="AGENTS.md.html" class="nav-logo">EventAlertMod Docs</a>
            <div class="nav-controls">
                <!-- 語言 -->
                <div class="nav-control-group">
                    <span class="nav-label">語言 / Lang:</span>
                    <div class="control-options">
                        <button onclick="translatePage('zh-TW')" class="nav-btn lang-btn active" id="lang-zh">繁中</button>
                        <button onclick="translatePage('en')" class="nav-btn lang-btn" id="lang-en">EN</button>
                    </div>
                </div>
                <!-- 字級 -->
                <div class="nav-control-group">
                    <span class="nav-label">字級 / Font:</span>
                    <div class="control-options">
                        <button onclick="setFontSize('14px')" class="nav-btn size-btn">小</button>
                        <button onclick="setFontSize('16px')" class="nav-btn size-btn active">中</button>
                        <button onclick="setFontSize('18px')" class="nav-btn size-btn">大</button>
                    </div>
                </div>
                <!-- 主題 -->
                <div class="nav-control-group">
                    <span class="nav-label">主題 / Theme:</span>
                    <div class="nav-theme-dots">
                        <span class="theme-dot dot-blue active" onclick="setTheme('blue')" title="Blue"></span>
                        <span class="theme-dot dot-red" onclick="setTheme('red')" title="Red"></span>
                        <span class="theme-dot dot-green" onclick="setTheme('green')" title="Green"></span>
                        <span class="theme-dot dot-black" onclick="setTheme('black')" title="Black"></span>
                        <span class="theme-dot dot-gray" onclick="setTheme('gray')" title="Gray"></span>
                        <span class="theme-dot dot-white" onclick="setTheme('white')" title="White"></span>
                    </div>
                </div>
            </div>
        </div>
    </div>
"""

CONTROL_PANEL_CSS = """
    /* Top Nav Bar Styles */
    .top-nav-bar {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 60px;
        background: rgba(30, 41, 59, 0.9);
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
        border-bottom: 1px solid var(--border-color);
        z-index: 10000;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
        transition: background-color 0.3s ease, border-color 0.3s ease;
    }
    
    .nav-container {
        max-width: 1000px;
        height: 100%;
        margin: 0 auto;
        padding: 0 20px;
        display: flex;
        align-items: center;
        justify-content: space-between;
    }
    
    .nav-logo {
        font-family: 'Outfit', sans-serif;
        font-size: 1.2rem;
        font-weight: 700;
        color: var(--accent-color);
        text-decoration: none;
        letter-spacing: 0.5px;
        transition: color 0.3s ease;
    }
    
    .nav-logo:hover {
        color: var(--heading-color);
        text-decoration: none;
        opacity: 0.9;
    }
    
    .nav-controls {
        display: flex;
        align-items: center;
        gap: 20px;
    }
    
    .nav-control-group {
        display: flex;
        align-items: center;
        gap: 8px;
    }
    
    .nav-label {
        font-size: 0.8rem;
        color: var(--text-color);
        font-weight: 500;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    
    .control-options {
        display: flex;
        gap: 4px;
    }
    
    .nav-btn {
        background: var(--bg-color);
        border: 1px solid var(--border-color);
        color: var(--text-color);
        padding: 4px 10px;
        border-radius: 6px;
        cursor: pointer;
        font-size: 0.8rem;
        transition: all 0.2s ease;
        outline: none;
    }
    
    .nav-btn:hover {
        border-color: var(--accent-color);
        color: var(--heading-color);
    }
    
    .nav-btn.active {
        background: var(--accent-color);
        color: var(--bg-color);
        border-color: var(--accent-color);
        font-weight: 600;
    }
    
    .nav-theme-dots {
        display: flex;
        gap: 6px;
    }
    
    .theme-dot {
        width: 18px;
        height: 18px;
        border-radius: 50%;
        cursor: pointer;
        border: 2px solid transparent;
        transition: transform 0.1s ease, border-color 0.2s ease;
    }
    
    .theme-dot:hover {
        transform: scale(1.2);
    }
    
    .theme-dot.active {
        border-color: #ffffff;
        box-shadow: 0 0 0 2px var(--accent-color);
    }
    
    .dot-blue { background-color: #38bdf8; }
    .dot-red { background-color: #ef4444; }
    .dot-green { background-color: #22c55e; }
    .dot-black { background-color: #000000; border: 1px solid #334155; }
    .dot-gray { background-color: #71717a; }
    .dot-white { background-color: #ffffff; border: 1px solid #cbd5e1; }
    
    /* Responsive adjustment */
    @media (max-width: 768px) {
        .top-nav-bar {
            height: auto;
            padding: 10px 0;
        }
        .nav-container {
            flex-direction: column;
            gap: 10px;
            align-items: center;
        }
        .nav-controls {
            flex-wrap: wrap;
            justify-content: center;
        }
    }
"""

CONTROL_PANEL_JS = """
    <script>
        function translatePage(lang) {
            document.querySelectorAll('.lang-content').forEach(el => {
                el.classList.remove('active');
            });
            document.querySelectorAll('.lang-btn').forEach(btn => {
                btn.classList.remove('active');
            });
            
            if (lang === 'zh-TW') {
                const zhContent = document.getElementById('doc-content-zh');
                if (zhContent) zhContent.classList.add('active');
                const zhBtn = document.getElementById('lang-zh');
                if (zhBtn) zhBtn.classList.add('active');
                const logo = document.querySelector('.nav-logo');
                if (logo) logo.innerText = 'EventAlertMod 說明文件';
            } else {
                const enContent = document.getElementById('doc-content-en');
                if (enContent) enContent.classList.add('active');
                const enBtn = document.getElementById('lang-en');
                if (enBtn) enBtn.classList.add('active');
                const logo = document.querySelector('.nav-logo');
                if (logo) logo.innerText = 'EventAlertMod Docs';
            }
        }

        function setFontSize(size) {
            document.documentElement.style.setProperty('--base-font-size', size);
            document.querySelectorAll('.size-btn').forEach(btn => {
                btn.classList.remove('active');
                if ((size === '14px' && btn.innerText === '小') ||
                    (size === '16px' && btn.innerText === '中') ||
                    (size === '18px' && btn.innerText === '大')) {
                    btn.classList.add('active');
                }
            });
        }

        const themes = {
            blue: {
                '--bg-color': '#0f172a',
                '--panel-bg': '#1e293b',
                '--text-color': '#cbd5e1',
                '--heading-color': '#f8fafc',
                '--accent-color': '#38bdf8',
                '--border-color': '#334155',
                '--code-color': '#f1f5f9'
            },
            red: {
                '--bg-color': '#1a0f0f',
                '--panel-bg': '#2d1a1a',
                '--text-color': '#fca5a5',
                '--heading-color': '#fee2e2',
                '--accent-color': '#ef4444',
                '--border-color': '#451a1a',
                '--code-color': '#fee2e2'
            },
            green: {
                '--bg-color': '#06140e',
                '--panel-bg': '#0d281c',
                '--text-color': '#86efac',
                '--heading-color': '#dcfce7',
                '--accent-color': '#22c55e',
                '--border-color': '#14422b',
                '--code-color': '#dcfce7'
            },
            black: {
                '--bg-color': '#050505',
                '--panel-bg': '#121212',
                '--text-color': '#e5e5e5',
                '--heading-color': '#ffffff',
                '--accent-color': '#a3a3a3',
                '--border-color': '#262626',
                '--code-color': '#ffffff'
            },
            gray: {
                '--bg-color': '#27272a',
                '--panel-bg': '#3f3f46',
                '--text-color': '#e4e4e7',
                '--heading-color': '#fafafa',
                '--accent-color': '#cbd5e1',
                '--border-color': '#52525b',
                '--code-color': '#fafafa'
            },
            white: {
                '--bg-color': '#f8fafc',
                '--panel-bg': '#ffffff',
                '--text-color': '#334155',
                '--heading-color': '#0f172a',
                '--accent-color': '#0284c7',
                '--border-color': '#e2e8f0',
                '--code-color': '#0f172a'
            }
        };

        function setTheme(name) {
            const theme = themes[name];
            if (theme) {
                for (const [key, value] of Object.entries(theme)) {
                    document.documentElement.style.setProperty(key, value);
                }
                // Toggle active class on dots
                document.querySelectorAll('.theme-dot').forEach(dot => {
                    dot.classList.remove('active');
                    if (dot.classList.contains('dot-' + name)) {
                        dot.classList.add('active');
                    }
                });
            }
        }
    </script>
"""

def should_convert(content):
    # Detect Mermaid codeblocks
    has_mermaid = "```mermaid" in content
    
    # Detect images: ![alt](url) or <img
    has_image = bool(re.search(r'!\[.*?\]\(.*?\)', content)) or "src=" in content.lower()
    
    # Detect Markdown tables: lines containing | and separator lines containing ---
    has_table = False
    lines = content.split('\n')
    for line in lines:
        if "|" in line and re.search(r'[-:|]{3,}', line):
            # Check if there is a separator line around
            has_table = True
            break
        # Alternate table detection: just checking if there are multiple | in a line
        if line.count('|') >= 2:
            # Check if there's a nearby table separator line
            has_table = True
            break
            
    has_flowchart = "心智圖" in content or "流程圖" in content or "flowchart" in content.lower()
    return has_mermaid or has_image or has_table or has_flowchart

def write_html_file(dest_path, full_html):
    # 來源文件可能保留歷史行尾空白；產出頁面統一正規化，避免每次重建產生髒補丁。
    normalized_html = re.sub(r"[ \t]+(?=\r?$)", "", full_html, flags=re.MULTILINE)
    with open(dest_path, "w", encoding="utf-8") as f:
        f.write(normalized_html)

def convert_to_html(md_path, dest_dir, force_convert=False):
    filename = os.path.basename(md_path)
    # Output file matches: full filename suffix with .html (e.g. filename.md.html)
    out_filename = filename + ".html"
    dest_path = os.path.join(dest_dir, out_filename)
    
    with open(md_path, "r", encoding="utf-8") as f:
        file_content = f.read()
        
    if not force_convert and not should_convert(file_content):
        print(f"[Skip] {filename} does not contain mindmaps, tables, flowcharts, or images.")
        return False

    print(f"[Process] Converting {filename} -> {out_filename}")
    
    # Language direction detection
    is_zh = is_chinese_text(file_content)
    
    if is_zh:
        content_zh = file_content
        content_en = None
        
        # Look for local English version
        base, ext = os.path.splitext(md_path)
        en_md_path = base + "_en" + ext
        if os.path.exists(en_md_path):
            print(f"  [Local EN] Found local English file: {os.path.basename(en_md_path)}")
            with open(en_md_path, "r", encoding="utf-8") as f:
                content_en = f.read()
        else:
            print("  [Auto EN] Translating content to English...")
            content_en = translate_via_google_api(content_zh, src_lang="zh-TW", dest_lang="en")
    else:
        # Original file is English
        content_en = file_content
        content_zh = None
        
        # Look for local Chinese version (e.g. filename_zh.md)
        base, ext = os.path.splitext(md_path)
        zh_md_path = base + "_zh" + ext
        if os.path.exists(zh_md_path):
            print(f"  [Local ZH] Found local Chinese file: {os.path.basename(zh_md_path)}")
            with open(zh_md_path, "r", encoding="utf-8") as f:
                content_zh = f.read()
        else:
            print("  [Auto ZH] Translating content to Traditional Chinese...")
            content_zh = translate_via_google_api(content_en, src_lang="en", dest_lang="zh-TW")

    pattern = re.compile(r'```mermaid\s*\n(.*?)\n```', re.DOTALL)
    
    if content_zh:
        processed_content_zh = pattern.sub(r'\n<div class="mermaid">\n\1\n</div>\n', content_zh)
        html_content_zh = markdown.markdown(processed_content_zh, extensions=['extra', 'codehilite', 'toc'])
        html_content_zh = re.sub(r'href="Docs/([^"]+?)\.md"', r'href="\1.md.html"', html_content_zh)
        html_content_zh = re.sub(r'href="([^"]+?)\.md"', r'href="\1.md.html"', html_content_zh)
        html_content_zh = re.sub(r'href="\.\./Docs/([^"]+?)\.md"', r'href="\1.md.html"', html_content_zh)
    else:
        html_content_zh = """
        <div class="translation-fallback">
            <h3>繁體中文版本載入失敗 / Translation Unavailable</h3>
            <p>無法動態生成此文件的繁體中文翻譯。請嘗試使用瀏覽器內置的「翻譯成繁體中文」功能。</p>
        </div>
        """

    if content_en:
        processed_content_en = pattern.sub(r'\n<div class="mermaid">\n\1\n</div>\n', content_en)
        html_content_en = markdown.markdown(processed_content_en, extensions=['extra', 'codehilite', 'toc'])
        html_content_en = re.sub(r'href="Docs/([^"]+?)\.md"', r'href="\1.md.html"', html_content_en)
        html_content_en = re.sub(r'href="([^"]+?)\.md"', r'href="\1.md.html"', html_content_en)
        html_content_en = re.sub(r'href="\.\./Docs/([^"]+?)\.md"', r'href="\1.md.html"', html_content_en)
    else:
        html_content_en = """
        <div class="translation-fallback">
            <h3>English Version Offline / Translation Unavailable</h3>
            <p>The English translation for this document could not be dynamically generated. This usually happens when:</p>
            <ul>
                <li>You are executing the build script in an offline environment.</li>
                <li>The dynamically accessed Google Translate API is temporarily blocked or timed out.</li>
            </ul>
            <p><strong>Recommended Solution:</strong> Directly use your browser's built-in <em>"Translate to English"</em> function by right-clicking on the page.</p>
        </div>
        """
        
    html_content_zh = f'<a href="AGENTS.md.html" class="back-btn">← 返回 AI 入口指導檔 (AGENTS)</a>\n' + html_content_zh
    html_content_en = f'<a href="AGENTS.md.html" class="back-btn">← Back to AI Entrance (AGENTS)</a>\n' + html_content_en

    # Premium CSS design
    css_style = """
    html, body {
        overflow-x: hidden;
    }
    body {
        font-family: 'Outfit', 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background-color: var(--bg-color);
        color: var(--text-color);
        font-size: var(--base-font-size);
        line-height: 1.6;
        max-width: 1000px;
        margin: 0 auto;
        padding: 80px 20px 40px 20px;
        transition: background-color 0.3s ease, color 0.3s ease;
    }
    
    h1, h2, h3, h4, h5, h6 {
        color: var(--heading-color);
        margin-top: 1.5em;
        margin-bottom: 0.5em;
        font-weight: 600;
    }
    
    h1 {
        font-size: 2.2rem;
        border-bottom: 2px solid var(--border-color);
        padding-bottom: 10px;
        color: var(--accent-color);
    }
    
    h2 {
        font-size: 1.7rem;
        border-bottom: 1px solid var(--border-color);
        padding-bottom: 8px;
        color: var(--heading-color);
    }
    
    h3 {
        font-size: 1.35rem;
        color: var(--heading-color);
    }
    
    h4 {
        font-size: 1.15rem;
        color: var(--accent-color);
        background-color: var(--panel-bg);
        padding: 6px 12px;
        border-radius: 6px;
        display: inline-block;
    }
    
    a {
        color: var(--accent-color);
        text-decoration: none;
        transition: color 0.2s ease;
    }
    
    a:hover {
        color: var(--accent-color);
        text-decoration: underline;
        opacity: 0.8;
    }
    
    ul, ol {
        padding-left: 24px;
        margin-bottom: 20px;
    }
    
    li {
        margin-bottom: 6px;
    }
    
    hr {
        border: 0;
        height: 1px;
        background: var(--border-color);
        margin: 30px 0;
    }
    
    code {
        font-family: 'Fira Code', 'Courier New', Courier, monospace;
        background-color: var(--panel-bg);
        padding: 2px 6px;
        border-radius: 4px;
        color: var(--code-color);
        font-size: 0.9em;
    }
    
    pre {
        background-color: var(--panel-bg);
        padding: 16px;
        border-radius: 8px;
        overflow-x: auto;
        border: 1px solid var(--border-color);
        margin: 20px 0;
    }
    
    pre code {
        background-color: transparent;
        padding: 0;
        border-radius: 0;
        color: var(--text-color);
    }
    
    blockquote {
        border-left: 4px solid var(--accent-color);
        padding: 10px 20px;
        margin: 20px 0;
        background-color: var(--panel-bg);
        border-radius: 0 8px 8px 0;
        color: var(--text-color);
        opacity: 0.85;
    }
    
    img {
        max-width: 100%;
        height: auto;
        border-radius: 8px;
        border: 1px solid var(--border-color);
        margin: 20px 0;
        box-shadow: 0 10px 15px -3px rgb(0 0 0 / 0.3);
    }
    
    table {
        border-collapse: collapse;
        width: 100%;
        margin: 25px 0;
        background-color: var(--panel-bg);
        border-radius: 8px;
        overflow: hidden;
        box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
        border: 1px solid var(--border-color);
    }
    
    th, td {
        padding: 12px 16px;
        text-align: left;
        border-bottom: 1px solid var(--border-color);
    }
    
    th {
        background-color: var(--bg-color);
        color: var(--accent-color);
        font-weight: 600;
        border-bottom: 2px solid var(--border-color);
    }
    
    tr:last-child td {
        border-bottom: none;
    }
    
    tr:hover {
        background-color: var(--panel-bg);
        opacity: 0.95;
    }
    
    /* Mermaid Graph Center Alignment */
    .mermaid {
        display: flex;
        justify-content: center;
        background-color: var(--panel-bg);
        padding: 20px;
        border-radius: 8px;
        border: 1px solid var(--border-color);
        margin: 25px 0;
    }
    
    /* Back Button */
    .back-btn {
        display: inline-flex;
        align-items: center;
        margin-bottom: 20px;
        background-color: var(--panel-bg);
        color: var(--heading-color);
        padding: 8px 16px;
        border-radius: 6px;
        font-size: 0.9em;
        border: 1px solid var(--border-color);
        transition: all 0.2s ease;
    }
    
    .back-btn:hover {
        background-color: var(--border-color);
        color: var(--accent-color);
        text-decoration: none;
    }
    
    @media (max-width: 600px) {
        body {
            padding: 20px 10px;
        }
        h1 {
            font-size: 1.8rem;
        }
    }
    """

    full_html = f"""<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{filename} - EventAlertMod Docs</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Outfit:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        {COMMON_CSS_VARIABLES}
        {css_style}
        {CONTROL_PANEL_CSS}
        .lang-content {{
            display: none;
        }}
        .lang-content.active {{
            display: block;
        }}
        .translation-fallback {{
            background-color: var(--panel-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }}
        .translation-fallback h3 {{
            color: #ef4444;
            margin-top: 0;
        }}
    </style>
</head>
<body>
    {CONTROL_PANEL_HTML}
    <div id="doc-content-zh" class="lang-content active">
        {html_content_zh}
    </div>
    <div id="doc-content-en" class="lang-content">
        {html_content_en}
    </div>
    
    <!-- Mermaid Dynamic Render Script -->
    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
    <script>
        mermaid.initialize({{
            startOnLoad: true,
            theme: 'dark',
            securityLevel: 'loose',
            themeVariables: {{
                background: '#1e293b',
                primaryColor: '#0f172a',
                primaryTextColor: '#f8fafc',
                lineColor: '#38bdf8'
            }}
        }});
    </script>
    {CONTROL_PANEL_JS}
</body>
</html>
"""

    write_html_file(dest_path, full_html)
    return True

def convert_txt_to_html(txt_path, dest_dir):
    filename = os.path.basename(txt_path)
    out_filename = filename + ".html"
    dest_path = os.path.join(dest_dir, out_filename)
    
    with open(txt_path, "r", encoding="utf-8") as f:
        content_zh = f.read()
        
    print(f"[Process] Converting txt {filename} -> {out_filename}")
    
    # Translate to English
    print("  [Auto EN] Translating text to English...")
    content_en = translate_via_google_api(content_zh)
    
    import html
    escaped_zh = html.escape(content_zh)
    
    if content_en:
        escaped_en = html.escape(content_en)
    else:
        escaped_en = """[English Translation Offline / Unavailable]
The English translation for this document could not be dynamically generated. 
This usually happens when:
- You are executing the build script in an offline environment.
- The dynamically accessed Google Translate API is temporarily blocked or timed out.

Recommended Solution: Directly use your browser's built-in "Translate to English" function by right-clicking on the page."""

    css_style = """
    html, body {
        overflow-x: hidden;
    }
    body {
        font-family: 'Outfit', 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background-color: var(--bg-color);
        color: var(--text-color);
        font-size: var(--base-font-size);
        line-height: 1.6;
        max-width: 900px;
        margin: 0 auto;
        padding: 80px 20px 40px 20px;
        transition: background-color 0.3s ease, color 0.3s ease;
    }
    h1 {
        font-size: 2.2rem;
        border-bottom: 2px solid var(--border-color);
        padding-bottom: 10px;
        color: var(--accent-color);
    }
    pre {
        background-color: var(--panel-bg);
        padding: 16px;
        border-radius: 8px;
        overflow-x: auto;
        border: 1px solid var(--border-color);
        margin: 20px 0;
    }
    code {
        font-family: 'Fira Code', 'Courier New', Courier, monospace;
        color: var(--text-color);
        font-size: 0.95em;
        line-height: 1.5;
    }
    .back-btn {
        display: inline-flex;
        align-items: center;
        margin-bottom: 20px;
        background-color: var(--panel-bg);
        color: var(--heading-color);
        padding: 8px 16px;
        border-radius: 6px;
        font-size: 0.9em;
        border: 1px solid var(--border-color);
        transition: all 0.2s ease;
    }
    .back-btn:hover {
        background-color: var(--border-color);
        color: var(--accent-color);
        text-decoration: none;
    }
    """
    
    full_html = f"""<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{filename} - EventAlertMod 說明文件</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Outfit:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        {COMMON_CSS_VARIABLES}
        {css_style}
        {CONTROL_PANEL_CSS}
        .lang-content {{
            display: none;
        }}
        .lang-content.active {{
            display: block;
        }}
        .translation-fallback {{
            background-color: var(--panel-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }}
        .translation-fallback h3 {{
            color: #ef4444;
            margin-top: 0;
        }}
    </style>
</head>
<body>
    {CONTROL_PANEL_HTML}
    <div id="doc-content-zh" class="lang-content active">
        <a href="AGENTS.md.html" class="back-btn">← 返回 AI 入口指導檔 (AGENTS)</a>
        <h1>{filename}</h1>
        <pre><code>{escaped_zh}</code></pre>
    </div>
    <div id="doc-content-en" class="lang-content">
        <a href="AGENTS.md.html" class="back-btn">← Back to AI Entrance (AGENTS)</a>
        <h1>{filename}</h1>
        <pre><code>{escaped_en}</code></pre>
    </div>
    {CONTROL_PANEL_JS}
</body>
</html>
"""
    write_html_file(dest_path, full_html)
    return True

def main():
    load_cache()
    workspace = "d:/EventAlertMod"
    docs_dir = os.path.join(workspace, "Docs")
    dest_dir = os.path.join(workspace, "docs_html")
    
    # Create target directory
    if not os.path.exists(dest_dir):
        os.makedirs(dest_dir)
        print(f"Created directory: {dest_dir}")
        
    # Gather target md files in Docs/
    md_files = glob.glob(os.path.join(docs_dir, "*.md"))
    # Filter out bilingual suffix files to prevent redundant html generation
    md_files = [f for f in md_files if not f.endswith("_en.md") and not f.endswith("_zh.md")]
    
    converted_count = 0
    # Convert Docs/ md files
    for md_path in md_files:
        if convert_to_html(md_path, dest_dir, force_convert=True):
            converted_count += 1
            
    # Force convert key markdown files in root
    root_mds = ["AGENTS.md", "README.md"]
    for filename in root_mds:
        md_path = os.path.join(workspace, filename)
        if os.path.exists(md_path):
            if convert_to_html(md_path, dest_dir, force_convert=True):
                converted_count += 1

    # Release ZIP 收錄根 readme.html；永遠由 Pages 的 README 產物同步，避免雙份 HTML 漂移。
    readme_html_source = os.path.join(dest_dir, "README.md.html")
    readme_html_path = os.path.join(workspace, "readme.html")
    if os.path.exists(readme_html_source):
        shutil.copyfile(readme_html_source, readme_html_path)
        print("Synchronized root readme.html from docs_html/README.md.html")
                
    # Convert changelog.txt
    changelog_txt = os.path.join(workspace, "changelog.txt")
    if os.path.exists(changelog_txt):
        if convert_txt_to_html(changelog_txt, dest_dir):
            converted_count += 1
            
    # Generate index.html by copying 00_INDEX.md.html for GitHub Pages root rendering
    index_src_path = os.path.join(dest_dir, "00_INDEX.md.html")
    index_html_path = os.path.join(dest_dir, "index.html")
    if os.path.exists(index_src_path):
        shutil.copyfile(index_src_path, index_html_path)
        print("Generated index.html from 00_INDEX.md.html")
            
    print(f"--------------------------------------------------")
    print(f"Batch conversion completed. Converted {converted_count} files.")
    print(f"Output files stored in {dest_dir}")
    print(f"--------------------------------------------------")

if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
import os
import json
import re

WORKSPACE = "d:/EventAlertMod"
CACHE_FILE = os.path.join(WORKSPACE, "Tools/.translation_cache.json")

if not os.path.exists(CACHE_FILE):
    print("Cache file not found!")
    exit(1)

with open(CACHE_FILE, "r", encoding="utf-8") as f:
    cache = json.load(f)

# Dirty patterns to search for in translated text
dirty_regexes = [
    r'核心/[a-zA-Z0-9_]+',
    r'服務/[a-zA-Z0-9_]+',
    r'使用者介面/[a-zA-Z0-9_]+',
    r'調試/[a-zA-Z0-9_]+',
    r'工具/[a-zA-Z0-9_]+',
    r'主/EventAlert',
    r'主線/Main',
    r'常數\.lua',
    r'性能\.lua',
    r'選項\.lua',
    r'調度程序\.lua',
    r'事件路由器\.lua',
    r'背景模板',
    r'輸入框模板',
    r'選項滑桿模板',
    r'遊戲字體',
    r'更新時',
    r'位置框架',
    r'更新ScdFrame',
    r'單元光環',
    r'時間小組',
    r'自動更新器',
    r'定時處理',
    r'股票代號',
    r'圖像/、音樂/',
    r'圖像/ 和 音樂/',
    r'主/',
    r'圖像/',
    r'音樂/'
]

compiled_regexes = [re.compile(p) for p in dirty_regexes]

removed_count = 0
for lang_key, entries in list(cache.items()):
    if not isinstance(entries, dict):
        continue
    for text_hash, translated in list(entries.items()):
        has_dirty = False
        for rx in compiled_regexes:
            if rx.search(translated):
                has_dirty = True
                break
        if has_dirty:
            del entries[text_hash]
            removed_count += 1

with open(CACHE_FILE, "w", encoding="utf-8") as f:
    json.dump(cache, f, ensure_ascii=False, indent=2)

print(f"Super Purge: Removed {removed_count} dirty entries from cache.")

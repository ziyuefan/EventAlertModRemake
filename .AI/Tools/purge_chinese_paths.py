# -*- coding: utf-8 -*-
import os
import json
import re

WORKSPACE = "d:/EventAlertMod"
CACHE_FILE = os.path.join(WORKSPACE, "Tools/.translation_cache.json")

if not os.path.exists(CACHE_FILE):
    print("Cache file not found!")
    exit(1)

with open(CACHE_FILE, "r", encoding="utf-8-sig") as f:
    cache = json.load(f)

# Regex to find any Chinese path translation in values
chinese_path_patterns = [
    r'使用者介面/[^ \n\t`\'"]+',
    r'服務/[^ \n\t`\'"]+',
    r'核心/[^ \n\t`\'"]+',
    r'調試/[^ \n\t`\'"]+',
    r'工具/[^ \n\t`\'"]+',
    r'主/[^ \n\t`\'"]+'
]

compiled = [re.compile(p) for p in chinese_path_patterns]

removed_count = 0
for lang_key, entries in list(cache.items()):
    if not isinstance(entries, dict):
        continue
    for text_hash, translated in list(entries.items()):
        has_dirty = False
        for rx in compiled:
            if rx.search(translated):
                has_dirty = True
                break
        if has_dirty:
            print(f"Purging Hash: {text_hash} | Value: {repr(translated[:120])}")
            del entries[text_hash]
            removed_count += 1

with open(CACHE_FILE, "w", encoding="utf-8") as f:
    json.dump(cache, f, ensure_ascii=False, indent=2)

print(f"Purged {removed_count} entries containing Chinese paths.")

# -*- coding: utf-8 -*-
import os
import json

WORKSPACE = "d:/EventAlertMod"
CACHE_FILE = os.path.join(WORKSPACE, "Tools/.translation_cache.json")

if not os.path.exists(CACHE_FILE):
    print("Cache file not found!")
    exit(1)

with open(CACHE_FILE, "r", encoding="utf-8-sig") as f:
    cache = json.load(f)

with open(os.path.join(WORKSPACE, "Tools/search_results.txt"), "w", encoding="utf-8") as out:
    out.write("--- Searching for '模板', '範本', '事件', '更新時', '更新ScdFrame', '位置框架' ---\n")
    for lang_key, entries in cache.items():
        if not isinstance(entries, dict):
            continue
        for text_hash, translated in entries.items():
            found = []
            for term in ["模板", "範本", "事件", "更新時", "更新ScdFrame", "位置框架"]:
                if term in translated:
                    found.append(term)
            if found:
                preview = translated.replace('\n', '\\n')[:120]
                out.write(f"[{lang_key}] Hash: {text_hash} | Found: {found} | Preview: {preview}\n")


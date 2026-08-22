# -*- coding: utf-8 -*-
import os
import json
import hashlib

WORKSPACE = "d:/EventAlertMod"
CACHE_FILE = os.path.join(WORKSPACE, "Tools/.translation_cache.json")

with open(CACHE_FILE, "r", encoding="utf-8-sig") as f:
    cache = json.load(f)

# Let's read 00_AI_CONTEXT.md in its original English (from git)
# Wait, currently 00_AI_CONTEXT.md on disk is translated. Let's see if we can find the hash in cache that contains "核心/Env.lua"
found = False
for lang_key, entries in cache.items():
    if not isinstance(entries, dict):
        continue
    for text_hash, translated in entries.items():
        if "核心/Env.lua" in translated:
            print(f"Found hash: {text_hash} | Value:\n{translated}\n")
            found = True

if not found:
    print("No entry found containing '核心/Env.lua'")

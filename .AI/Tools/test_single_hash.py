# -*- coding: utf-8 -*-
import os
import json
import re

WORKSPACE = "d:/EventAlertMod"
CACHE_FILE = os.path.join(WORKSPACE, "Tools/.translation_cache.json")

with open(CACHE_FILE, "r", encoding="utf-8-sig") as f:
    cache = json.load(f)

val = cache["en_to_zh-TW"].get("dcbfd6a02428d6a022aa814b4318229b")
if val:
    print("Value found!")
    # Test regex
    rx = re.compile(r'核心/[^ \n\t`\'"]+')
    match = rx.search(val)
    print("Match:", match)
    if match:
        print("Matched text:", repr(match.group(0)))
else:
    print("Value not found in cache")

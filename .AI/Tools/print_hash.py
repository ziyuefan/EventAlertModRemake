# -*- coding: utf-8 -*-
import os
import json

WORKSPACE = "d:/EventAlertMod"
CACHE_FILE = os.path.join(WORKSPACE, "Tools/.translation_cache.json")

with open(CACHE_FILE, "r", encoding="utf-8-sig") as f:
    cache = json.load(f)

val = cache["en_to_zh-TW"].get("7591b49097c4669fba7521638e542933")
if val:
    with open(os.path.join(WORKSPACE, "Tools/hash_value.txt"), "w", encoding="utf-8") as out:
        out.write(val)
    print("Saved to Tools/hash_value.txt")
else:
    print("Not found")

# -*- coding: utf-8 -*-
import os
import glob
import re

WORKSPACE = "d:/EventAlertMod"
docs_dir = os.path.join(WORKSPACE, "Docs")
md_files = glob.glob(os.path.join(docs_dir, "*.md"))
md_files = [f for f in md_files if not f.endswith("_en.md") and not f.endswith("_zh.md")]

def is_chinese_text(text):
    return bool(re.search(r'[\u4e00-\u9fff]', text))

print("--- Markdown Files Language Check ---")
for f in md_files:
    with open(f, "r", encoding="utf-8") as file:
        content = file.read()
    is_zh = is_chinese_text(content)
    print(f"File: {os.path.basename(f)} | Detected as Chinese? {is_zh}")

# Check root md files
for filename in ["AGENTS.md", "README.md"]:
    md_path = os.path.join(WORKSPACE, filename)
    if os.path.exists(md_path):
        with open(md_path, "r", encoding="utf-8") as file:
            content = file.read()
        is_zh = is_chinese_text(content)
        print(f"File: {filename} | Detected as Chinese? {is_zh}")

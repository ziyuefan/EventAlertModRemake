# -*- coding: utf-8 -*-
import os
import json
import re
import glob
import hashlib
import sys

WORKSPACE = "d:/EventAlertMod"
TOOLS_DIR = os.path.join(WORKSPACE, "Tools")
CACHE_FILE = os.path.join(TOOLS_DIR, ".translation_cache.json")

if TOOLS_DIR not in sys.path:
    sys.path.append(TOOLS_DIR)

from batch_convert_docs import protect_symbols

# Load translation cache
if not os.path.exists(CACHE_FILE):
    print("Cache file not found!")
    exit(1)

with open(CACHE_FILE, "r", encoding="utf-8-sig") as f:
    cache = json.load(f)

# Helper to get MD5
def get_md5(text):
    return hashlib.md5(text.encode('utf-8')).hexdigest()

# 1. Collect all original English text from markdown files
original_texts = {}

def collect_chunks_from_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Segment state machine matching convert_mds_to_zh.py
    segments = []
    lines = content.split('\n')
    in_code_block = False
    current_block = []
    
    for line in lines:
        if line.strip().startswith("```"):
            if in_code_block:
                current_block.append(line)
                segments.append(("\n".join(current_block), True))
                current_block = []
                in_code_block = False
            else:
                if current_block:
                    segments.append(("\n".join(current_block), False))
                current_block = [line]
                in_code_block = True
        else:
            current_block.append(line)
            
    if current_block:
        segments.append(("\n".join(current_block), in_code_block))
        
    for chunk, is_code in segments:
        if is_code or not chunk.strip():
            continue
            
        # Split plain text into sub-chunks
        import urllib.parse
        sub_lines = chunk.split('\n')
        current_sub_chunk = []
        current_sub_len = 0
        
        for sub_line in sub_lines:
            sub_line_encoded = urllib.parse.quote(sub_line)
            encoded_len = len(sub_line_encoded)
            
            if encoded_len > 1200:
                if current_sub_chunk:
                    text_val = "\n".join(current_sub_chunk)
                    original_texts[get_md5(text_val)] = text_val
                    current_sub_chunk = []
                    current_sub_len = 0
                original_texts[get_md5(sub_line)] = sub_line
            elif current_sub_len + encoded_len > 1200:
                text_val = "\n".join(current_sub_chunk)
                original_texts[get_md5(text_val)] = text_val
                current_sub_chunk = [sub_line]
                current_sub_len = encoded_len
            else:
                current_sub_chunk.append(sub_line)
                current_sub_len += encoded_len + 3
                
        if current_sub_chunk:
            text_val = "\n".join(current_sub_chunk)
            original_texts[get_md5(text_val)] = text_val

# Collect from Docs/*.md
docs_dir = os.path.join(WORKSPACE, "Docs")
md_files = glob.glob(os.path.join(docs_dir, "*.md"))
md_files = [f for f in md_files if not f.endswith("_en.md") and not f.endswith("_zh.md")]

for md_path in md_files:
    collect_chunks_from_file(md_path)

# Collect from root markdown files
root_mds = ["AGENTS.md", "README.md"]
for filename in root_mds:
    md_path = os.path.join(WORKSPACE, filename)
    if os.path.exists(md_path):
        collect_chunks_from_file(md_path)

print(f"Collected {len(original_texts)} unique English chunks from source files.")

# 2. Smart purge contaminated entries
removed_count = 0
entries = cache.get("en_to_zh-TW", {})

for h, translated in list(entries.items()):
    if h not in original_texts:
        continue
        
    original = original_texts[h]
    
    # Run protect_symbols on original to extract all protected code terms
    _, placeholders = protect_symbols(original)
    
    # Check if any protected code term from original is missing in translated
    missing_terms = []
    for term in placeholders:
        # Strip backticks, quotes, or trailing empty parentheses for comparison if needed,
        # but actually, if the term is restored, it should be in the translated text exactly.
        # However, to be safe, if the term is backtick-wrapped e.g. `OnUpdate`, is it in translated?
        # In translated text, it should be restored exactly as `OnUpdate`.
        # Let's check for exact substring containment.
        if term not in translated:
            # Also check if it's restored but with spaces, e.g. due to translation.
            # But the restore_symbols function cleans spaces.
            missing_terms.append(term)
            
    if missing_terms:
        # Print using errors='replace' to avoid windows terminal encoding crashes
        orig_preview = original[:100].encode(sys.stdout.encoding, errors='replace').decode(sys.stdout.encoding)
        trans_preview = translated[:100].encode(sys.stdout.encoding, errors='replace').decode(sys.stdout.encoding)
        print(f"Purging Hash: {h}")
        print(f"  Original:   {repr(orig_preview)}")
        print(f"  Translated: {repr(trans_preview)}")
        print(f"  Missing terms: {missing_terms}")
        del entries[h]
        removed_count += 1

# Save cache back
with open(CACHE_FILE, "w", encoding="utf-8") as f:
    json.dump(cache, f, ensure_ascii=False, indent=2)

print(f"Smart Purge Completed! Removed {removed_count} contaminated entries.")

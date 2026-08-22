# -*- coding: utf-8 -*-
import os
import re
import glob
import sys
import shutil
from datetime import datetime

WORKSPACE = "d:/EventAlertMod"
TOOLS_DIR = os.path.join(WORKSPACE, "Tools")
BACKUP_DIR = os.path.join(WORKSPACE, "backup")

# Add Tools to path to import batch_convert_docs modules
if TOOLS_DIR not in sys.path:
    sys.path.append(TOOLS_DIR)

from batch_convert_docs import translate_chunk, load_cache, save_cache

def backup_file(filepath):
    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    filename = os.path.basename(filepath)
    backup_path = os.path.join(BACKUP_DIR, f"{filename}__{timestamp}")
    shutil.copyfile(filepath, backup_path)
    print(f"  [Backup] Backed up {filename} -> {os.path.basename(backup_path)}")

def convert_md_to_zh(md_path):
    filename = os.path.basename(md_path)
    with open(md_path, "r", encoding="utf-8") as f:
        file_content = f.read()
        
    print(f"[Process] Converting English sections in MD to Traditional Chinese: {filename}")
    
    # Split using the same segment state machine as batch_convert_docs.py
    segments = []
    lines = file_content.split('\n')
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
        
    translated_segments = []
    for content, is_code in segments:
        if is_code or not content.strip():
            translated_segments.append(content)
            continue
            
        # Split plain text into sub-chunks
        sub_lines = content.split('\n')
        current_sub_chunk = []
        current_sub_len = 0
        
        for sub_line in sub_lines:
            import urllib.parse
            sub_line_encoded = urllib.parse.quote(sub_line)
            encoded_len = len(sub_line_encoded)
            
            if encoded_len > 1200:
                if current_sub_chunk:
                    chunk_text = "\n".join(current_sub_chunk)
                    translated = translate_chunk(chunk_text, src_lang="en", dest_lang="zh-TW")
                    translated_segments.append(translated if translated else chunk_text)
                    current_sub_chunk = []
                    current_sub_len = 0
                translated = translate_chunk(sub_line, src_lang="en", dest_lang="zh-TW")
                translated_segments.append(translated if translated else sub_line)
            elif current_sub_len + encoded_len > 1200:
                chunk_text = "\n".join(current_sub_chunk)
                translated = translate_chunk(chunk_text, src_lang="en", dest_lang="zh-TW")
                translated_segments.append(translated if translated else chunk_text)
                current_sub_chunk = [sub_line]
                current_sub_len = encoded_len
            else:
                current_sub_chunk.append(sub_line)
                current_sub_len += encoded_len + 3
                
        if current_sub_chunk:
            chunk_text = "\n".join(current_sub_chunk)
            translated = translate_chunk(chunk_text, src_lang="en", dest_lang="zh-TW")
            translated_segments.append(translated if translated else chunk_text)
            
    final_content = "\n".join(translated_segments)
    
    # Strip any potential leading/trailing whitespace mismatches from split join
    if final_content.strip() == file_content.strip():
        print(f"  [Info] Translation output is identical to original for {filename}. No changes needed.")
        return False
        
    # Backup before writing
    backup_file(md_path)
    
    # Write back
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(final_content)
        
    print(f"  [Success] Saved Traditional Chinese version to {filename}")
    return True

def main():
    # Load cache via imported module
    load_cache()
        
    docs_dir = os.path.join(WORKSPACE, "Docs")
    md_files = glob.glob(os.path.join(docs_dir, "*.md"))
    # Filter out bilingual suffix files
    md_files = [f for f in md_files if not f.endswith("_en.md") and not f.endswith("_zh.md")]
    
    converted = 0
    for md_path in md_files:
        if convert_md_to_zh(md_path):
            converted += 1
            
    # Also convert root MD files
    root_mds = ["AGENTS.md", "README.md"]
    for filename in root_mds:
        md_path = os.path.join(WORKSPACE, filename)
        if os.path.exists(md_path):
            if convert_md_to_zh(md_path):
                converted += 1
                
    print(f"Completed! Converted {converted} markdown files to Traditional Chinese.")

if __name__ == "__main__":
    main()

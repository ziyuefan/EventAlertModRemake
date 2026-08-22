# -*- coding: utf-8 -*-
import os
import sys

WORKSPACE = "d:/EventAlertMod"
TOOLS_DIR = os.path.join(WORKSPACE, "Tools")

if TOOLS_DIR not in sys.path:
    sys.path.append(TOOLS_DIR)

from convert_mds_to_zh import convert_md_to_zh, load_cache

def main():
    load_cache()
    
    target_files = [
        "Docs/02_RETAIL_API_BOUNDARIES.md",
        "Docs/03_STATE_SCHEMA.md",
        "Docs/04_MODULE_CONTRACTS.md",
        "Docs/05_PERFORMANCE_GUIDE.md",
        "Docs/06_TEST_PLAN_RETAIL.md",
        "Docs/09_KNOWN_LIMITATIONS.md"
    ]
    
    converted = 0
    for rel_path in target_files:
        abs_path = os.path.join(WORKSPACE, rel_path)
        if os.path.exists(abs_path):
            if convert_md_to_zh(abs_path):
                converted += 1
                
    print(f"Select translation completed: converted {converted} files.")

if __name__ == "__main__":
    main()

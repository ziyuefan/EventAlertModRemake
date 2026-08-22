# -*- coding: utf-8 -*-
import re

text = """相同的運行時表面。重寫應保留有用的資料並面向用戶
語義，同時用顯式模組取代內部結構。

所需的目標模組：

- `核心/Env.lua`
- `核心/Util.lua`
- `核心/常數.lua`
"""

chinese_path_patterns = [
    r'核心/[^ \n\t`\'"]+'
]

compiled = [re.compile(p) for p in chinese_path_patterns]

for rx in compiled:
    match = rx.search(text)
    print("Regex:", rx.pattern)
    print("Match:", match)
    if match:
        print("Matched value:", repr(match.group(0)))

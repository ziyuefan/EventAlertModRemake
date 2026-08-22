# -*- coding: utf-8 -*-
import re
from batch_convert_docs import protect_symbols

text = "- `Core/Env.lua`"
protected, placeholders = protect_symbols(text)
print("Text:", repr(text))
print("Protected:", repr(protected))
print("Placeholders:", placeholders)

# -*- coding: utf-8 -*-
"""
EAM Spell Heuristics & Presets Extractor
Parses .AI/Data/wow_spells_and_auras.json to extract:
1. Curated Class/Spec Core Presets
2. Hero Talent Tree Mappings
3. Ground Effect Catalog (no-aura area spells)
4. Heuristic Meta (maxStacks, baseDuration, statType, charges, absorb)
Outputs: EventAlertMod/Data/SpellHeuristics.lua (compact, <80KB)
"""

import os
import sys
import json
import re

if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JSON_PATH = os.path.join(PROJECT_ROOT, ".AI", "Data", "wow_spells_and_auras.json")
OUTPUT_LUA_PATH = os.path.join(PROJECT_ROOT, "EventAlertMod", "Data", "SpellHeuristics.lua")

# Tactical keywords for classification
BURST_KEYWORDS = [
    r"魯莽", r"天神下凡", r"冰霜之柱", r"燃燒", r"狂暴", r"嗜血", r"超凡之盟", r"符文武器", r"升騰",
    r"冰冷之血", r"影刃", r"死神印記", r"巨像重擊", r"虛空爆發", r"黑暗靈魂", r"復仇之怒", r"狂熱",
    r"巨龍之怒", r"支配", r"奧丁之怒", r"爆發", r"狂心", r"狂亂", r"雷霆咆哮", r"復仇之魂",
    r"Recklessness", r"Avatar", r"Pillar of Frost", r"Combustion", r"Berserk", r"Bloodlust",
    r"Incarnation", r"Empower Rune Weapon", r"Ascendance", r"Icy Veins", r"Shadow Blades",
    r"Colossus Smash", r"Void Eruption", r"Dark Soul", r"Avenging Wrath", r"Dragonrage"
]

DEFENSIVE_KEYWORDS = [
    r"盾牆", r"狂暴恢復", r"劍下亡魂", r"聖盾術", r"寒冰屏障", r"反魔法護罩", r"冰錮堅韌",
    r"痛苦壓制", r"消散", r"樹皮術", r"求生本能", r"惡魔變形", r"黑暗", r"佯攻", r"閃避", r"暗影斗篷",
    r"聖佑術", r"守護之魂", r"救贖之魂", r"守護者之光", r"熾熱防禦者", r"遠古諸王守護者",
    r"吸血鬼之血", r"天災契約", r"法術反彈", r"勝利在望", r"乘勝追擊", r"集結吶喊", r"盾牌格擋",
    r"Shield Wall", r"Enraged Regeneration", r"Die by the Sword", r"Divine Shield", r"Ice Block",
    r"Anti-Magic Shell", r"Icebound Fortitude", r"Pain Suppression", r"Dispersion", r"Barkskin",
    r"Survival Instincts", r"Metamorphosis", r"Darkness", r"Feint", r"Evasion", r"Cloak of Shadows",
    r"Divine Protection", r"Guardian Spirit", r"Vampiric Blood", r"Spell Reflection"
]

CC_KEYWORDS = [
    r"拳擊", r"制裁之錘", r"致盲", r"悶棍", r"變形術", r"恐懼", r"心靈震擊", r"腳踢", r"迎頭痛擊",
    r"壓制", r"斷法", r"沉默", r"太陽光束", r"震盪波", r"風暴之錘", r"吹風", r"旋風", r"束縛射擊",
    r"冰凍陷阱", r"癱瘓", r"掃堂腿", r"窒息", r"絞殺", r"妖術", r"心靈尖嘯", r"懺悔", r"盲目之光",
    r"Pummel", r"Hammer of Justice", r"Blind", r"Sap", r"Polymorph", r"Fear", r"Mind Blast",
    r"Kick", r"Skull Bash", r"Counterspell", r"Silence", r"Solar Beam", r"Shockwave", r"Storm Bolt",
    r"Freezing Trap", r"Paralysis", r"Leg Sweep", r"Asphyxiate", r"Strangulate", r"Hex", r"Psychic Scream"
]

GROUND_KEYWORDS = [
    r"死亡凋零", r"褻瀆", r"奉獻", r"反魔法力場", r"冰霜之球", r"暴風雪", r"火焰咒符",
    r"治療之雨", r"地震術", r"百花齊放", r"破壞者", r"平心之環", r"光明之泉", r"野性蘑菇",
    r"暗影裂隙", r"極效狂暴", r"烈焰風暴", r"信標", r"共鳴箭", r"衰變領域",
    r"Death and Decay", r"Defile", r"Consecration", r"Anti-Magic Zone", r"Frozen Orb",
    r"Blizzard", r"Sigil of Flame", r"Healing Rain", r"Earthquake", r"Efflorescence",
    r"Ravager", r"Ring of Peace", r"Wild Mushroom", r"Flamestrike"
]

def clean_lua_string(s):
    if not s:
        return ""
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ')

def extract_meta(spell):
    s_id = spell['spell_id']
    name = spell.get('name', '')
    desc_dict = spell.get('descriptions') or {}
    aura_dict = spell.get('aura_texts') or {}
    desc = desc_dict.get('tw', '') or desc_dict.get('en', '')
    aura_text = aura_dict.get('tw', '') or aura_dict.get('en', '')
    full_text = f"{desc} {aura_text}"

    # 1. Max Stacks
    max_stacks = None
    stack_match = re.search(r'(?:最多|最高)(?:可)?堆疊\s*(\d+)\s*層', full_text)
    if not stack_match:
        stack_match = re.search(r'stacks?\s*up\s*to\s*(\d+)\s*times?', full_text, re.IGNORECASE)
    if stack_match:
        try:
            max_stacks = int(stack_match.group(1))
            if max_stacks > 100 or max_stacks <= 1:
                max_stacks = None
        except:
            pass

    # 2. Base Duration
    base_duration = None
    dur_match = re.search(r'持續\s*(\d+(?:\.\d+)?)\s*秒', full_text)
    if not dur_match:
        dur_match = re.search(r'lasts?\s*(?:for\s*)?(\d+(?:\.\d+)?)\s*sec', full_text, re.IGNORECASE)
    if dur_match:
        try:
            val = float(dur_match.group(1))
            if 0 < val <= 3600:
                base_duration = val
        except:
            pass

    # 3. Stat Bonus
    stat_type = None
    stat_val = None
    for st_name, st_key in [('致命', 'crit'), ('加速', 'haste'), ('精通', 'mastery'), ('臨機應變', 'versatility'),
                            ('力量', 'strength'), ('敏捷', 'agility'), ('智力', 'intellect'), ('護甲', 'armor')]:
        m = re.search(rf'{st_name}[^\d]{{0,10}}(?:提高|增加|提升)\s*(\d+(?:\.\d+)?)\s*%', full_text)
        if m:
            stat_type = st_key
            try:
                stat_val = float(m.group(1))
            except:
                pass
            break

    # 4. Charges
    charges = None
    charge_match = re.search(r'(\d+)\s*次充能', full_text)
    if not charge_match:
        charge_match = re.search(r'(\d+)\s*charges?', full_text, re.IGNORECASE)
    if charge_match:
        try:
            c = int(charge_match.group(1))
            if 1 < c <= 10:
                charges = c
        except:
            pass

    # 5. Tactical Tag determination
    tactical_tags = []
    for kw in BURST_KEYWORDS:
        if re.search(kw, name, re.IGNORECASE) or (re.search(kw, desc, re.IGNORECASE) and '冷卻時間' in desc):
            tactical_tags.append("burst")
            break

    for kw in DEFENSIVE_KEYWORDS:
        if re.search(kw, name, re.IGNORECASE) or re.search(kw, aura_text, re.IGNORECASE):
            tactical_tags.append("defensive")
            break

    for kw in CC_KEYWORDS:
        if re.search(kw, name, re.IGNORECASE):
            tactical_tags.append("cc")
            break

    is_ground = False
    for kw in GROUND_KEYWORDS:
        if re.search(kw, name, re.IGNORECASE):
            tactical_tags.append("ground_effect")
            is_ground = True
            break
    if not is_ground and ('在目標區域' in desc or '在地面' in desc or 'target area' in desc.lower()) and base_duration:
        tactical_tags.append("ground_effect")
        is_ground = True

    return {
        'spell_id': s_id,
        'max_stacks': max_stacks,
        'base_duration': base_duration,
        'stat_type': stat_type,
        'stat_val': stat_val,
        'charges': charges,
        'is_ground': is_ground,
        'tactical_tags': list(set(tactical_tags))
    }

def main():
    print(f"Reading Wowhead database from {JSON_PATH}...")
    with open(JSON_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    spells = data.get('spells', [])
    print(f"Loaded {len(spells)} spells. Extracting heuristics and building presets...")

    # Index by Class & Spec
    spec_presets = {}      # [class_id][spec_id] = [spell_ids]
    hero_presets = {}      # [hero_tree_name] = [spell_ids]
    ground_effects = {}    # [spell_id] = { duration, name }
    spell_metadata = {}    # [spell_id] = { maxStacks, baseDuration, statType, statVal, charges, tags }

    for sp in spells:
        s_id = sp['spell_id']
        c_id = sp.get('class_id')
        name = sp.get('name_zh') or sp.get('name') or f"Spell {s_id}"
        meta = extract_meta(sp)

        # Record metadata if meaningful
        meta_entry = {}
        if meta['max_stacks']: meta_entry['maxStacks'] = meta['max_stacks']
        if meta['base_duration']: meta_entry['baseDuration'] = meta['base_duration']
        if meta['stat_type']: meta_entry['statType'] = meta['stat_type']
        if meta['stat_val']: meta_entry['statVal'] = meta['stat_val']
        if meta['charges']: meta_entry['charges'] = meta['charges']
        if meta['tactical_tags']: meta_entry['tags'] = meta['tactical_tags']

        if meta_entry:
            spell_metadata[s_id] = meta_entry

        if meta['is_ground']:
            ground_effects[s_id] = {
                'duration': meta['base_duration'] or 10.0,
                'name': name
            }

        # Index into spec presets
        if c_id:
            if c_id not in spec_presets:
                spec_presets[c_id] = {}
            for spec_info in sp.get('specs', []):
                spec_id = spec_info.get('spec_id')
                if spec_id:
                    if spec_id not in spec_presets[c_id]:
                        spec_presets[c_id][spec_id] = []
                    # Add if tactical or aura or talent
                    if meta['tactical_tags'] or sp.get('has_aura') or 'spec_ability' in sp.get('categories', []):
                        if s_id not in spec_presets[c_id][spec_id]:
                            spec_presets[c_id][spec_id].append(s_id)

        # Index into hero presets
        for ht in sp.get('hero_trees', {}).get('tw', []):
            if ht:
                if ht not in hero_presets:
                    hero_presets[ht] = []
                if s_id not in hero_presets[ht]:
                    hero_presets[ht].append(s_id)

    # Trim spec presets to high-value top 15 spells per spec
    trimmed_spec_presets = {}
    for cid, specs in spec_presets.items():
        trimmed_spec_presets[cid] = {}
        for sid, s_list in specs.items():
            # Sort: bursts & defensives first, then ground, then auras
            def sort_key(spell_id):
                m = spell_metadata.get(spell_id, {})
                tags = m.get('tags', [])
                score = 0
                if 'burst' in tags: score += 100
                if 'defensive' in tags: score += 80
                if 'ground_effect' in tags: score += 60
                if 'cc' in tags: score += 40
                if m.get('maxStacks'): score += 20
                return -score
            sorted_spells = sorted(s_list, key=sort_key)
            trimmed_spec_presets[cid][sid] = sorted_spells[:16]

    print(f"Generated presets for {len(trimmed_spec_presets)} classes, {len(ground_effects)} ground effects, {len(spell_metadata)} metadata entries.")

    # Format Lua Output
    lua_lines = [
        "--[[ EAM_FILE_COMMENTARY",
        "EventAlertMod Retail Rewrite",
        "Module: Data/SpellHeuristics",
        "檔案: Data\\SpellHeuristics.lua",
        "理念: 離線提煉之全職業核心預設、啟發式特徵字典與無光環地面效果名冊。",
        "責任: 為戰鬥鎖定環境提供先驗數值推導（0-API 呼叫）與開箱即用的一鍵預設。",
        "邊界: 唯讀靜態元資料，不保存運行時狀態，不觸發 Taint。",
        "--]]",
        "local _, EAM = ...",
        "",
        "EAM.Data = EAM.Data or {}",
        "local SpellHeuristics = {",
        "    -- 1. 內建戰術群組定義",
        "    TACTICAL_GROUPS = {",
        '        { id = "burst", nameKey = "GROUP_BURST", icon = 132349, color = "FFFFD100" },',
        '        { id = "defensive", nameKey = "GROUP_DEFENSIVE", icon = 132294, color = "FF00BFFF" },',
        '        { id = "cc", nameKey = "GROUP_CC", icon = 132307, color = "FFFF6347" },',
        '        { id = "ground_effect", nameKey = "GROUP_GROUND", icon = 136035, color = "FF32CD32" },',
        "    },",
        "",
        "    -- 2. 無光環地面範圍技能名冊 (Ground Target Spells without UnitAura)",
        "    GROUND_EFFECTS = {"
    ]

    for s_id, g_info in sorted(ground_effects.items()):
        clean_n = clean_lua_string(g_info['name'])
        lua_lines.append(f'        [{s_id}] = {{ duration = {g_info["duration"]}, name = "{clean_n}" }},')

    lua_lines.append("    },")
    lua_lines.append("")
    lua_lines.append("    -- 3. 全職業專精核心推薦預設 (Curated Presets per Spec)")
    lua_lines.append("    SPEC_PRESETS = {")

    for cid, specs in sorted(trimmed_spec_presets.items()):
        lua_lines.append(f"        [{cid}] = {{")
        for sid, s_list in sorted(specs.items()):
            ids_str = ", ".join(map(str, s_list))
            lua_lines.append(f"            [{sid}] = {{ {ids_str} }},")
        lua_lines.append("        },")

    lua_lines.append("    },")
    lua_lines.append("")
    lua_lines.append("    -- 4. 英雄天賦樹關聯預設 (Hero Talent Presets)")
    lua_lines.append("    HERO_PRESETS = {")

    for ht_name, s_list in sorted(hero_presets.items()):
        clean_ht = clean_lua_string(ht_name)
        ids_str = ", ".join(map(str, s_list[:10]))
        lua_lines.append(f'        ["{clean_ht}"] = {{ {ids_str} }},')

    lua_lines.append("    },")
    lua_lines.append("")
    lua_lines.append("    -- 5. 啟發式先驗特徵字典 (Heuristic Metadata: MaxStacks, Duration, StatType)")
    lua_lines.append("    SPELL_META = {")

    for s_id, meta in sorted(spell_metadata.items()):
        parts = []
        if 'maxStacks' in meta: parts.append(f"maxStacks = {meta['maxStacks']}")
        if 'baseDuration' in meta: parts.append(f"baseDuration = {meta['baseDuration']}")
        if 'statType' in meta: parts.append(f'statType = "{meta["statType"]}"')
        if 'statVal' in meta: parts.append(f"statVal = {meta['statVal']}")
        if 'charges' in meta: parts.append(f"charges = {meta['charges']}")
        if 'tags' in meta:
            tags_str = ", ".join([f'"{t}"' for t in meta['tags']])
            parts.append(f"tags = {{ {tags_str} }}")
        lua_lines.append(f"        [{s_id}] = {{ {', '.join(parts)} }},")

    lua_lines.append("    },")
    lua_lines.append("}")
    lua_lines.append("")
    lua_lines.append("EAM.Data.SpellHeuristics = SpellHeuristics")
    lua_lines.append("")

    os.makedirs(os.path.dirname(OUTPUT_LUA_PATH), exist_ok=True)
    with open(OUTPUT_LUA_PATH, 'w', encoding='utf-8') as f:
        f.write("\n".join(lua_lines))

    file_size_kb = os.path.getsize(OUTPUT_LUA_PATH) / 1024
    print(f"\n🎉 Successfully generated {OUTPUT_LUA_PATH} ({file_size_kb:.2f} KB)!")

if __name__ == '__main__':
    main()

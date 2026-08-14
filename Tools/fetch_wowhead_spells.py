import urllib.request
import urllib.parse
import re
import json
import time
import os
import sys
from concurrent.futures import ThreadPoolExecutor

CLASSES_MAP = {
    1: {"name_en": "Warrior", "name_zh": "戰士", "slug": "warrior"},
    2: {"name_en": "Paladin", "name_zh": "聖騎士", "slug": "paladin"},
    3: {"name_en": "Hunter", "name_zh": "獵人", "slug": "hunter"},
    4: {"name_en": "Rogue", "name_zh": "盜賊", "slug": "rogue"},
    5: {"name_en": "Priest", "name_zh": "牧師", "slug": "priest"},
    6: {"name_en": "Death Knight", "name_zh": "死亡騎士", "slug": "death-knight"},
    7: {"name_en": "Shaman", "name_zh": "薩滿", "slug": "shaman"},
    8: {"name_en": "Mage", "name_zh": "法師", "slug": "mage"},
    9: {"name_en": "Warlock", "name_zh": "術士", "slug": "warlock"},
    10: {"name_en": "Monk", "name_zh": "武僧", "slug": "monk"},
    11: {"name_en": "Druid", "name_zh": "德魯伊", "slug": "druid"},
    12: {"name_en": "Demon Hunter", "name_zh": "惡魔獵人", "slug": "demon-hunter"},
    13: {"name_en": "Evoker", "name_zh": "喚能師", "slug": "evoker"}
}

SPECS_MAP = {
    71: {"name_en": "Arms", "name_zh": "武器", "class_id": 1},
    72: {"name_en": "Fury", "name_zh": "狂怒", "class_id": 1},
    73: {"name_en": "Protection", "name_zh": "防護", "class_id": 1},
    65: {"name_en": "Holy", "name_zh": "神聖", "class_id": 2},
    66: {"name_en": "Protection", "name_zh": "防護", "class_id": 2},
    70: {"name_en": "Retribution", "name_zh": "懲戒", "class_id": 2},
    253: {"name_en": "Beast Mastery", "name_zh": "野獸控制", "class_id": 3},
    254: {"name_en": "Marksmanship", "name_zh": "射擊", "class_id": 3},
    255: {"name_en": "Survival", "name_zh": "生存", "class_id": 3},
    259: {"name_en": "Assassination", "name_zh": "刺殺", "class_id": 4},
    260: {"name_en": "Outlaw", "name_zh": "狂徒", "class_id": 4},
    261: {"name_en": "Subtlety", "name_zh": "敏銳", "class_id": 4},
    256: {"name_en": "Discipline", "name_zh": "戒律", "class_id": 5},
    257: {"name_en": "Holy", "name_zh": "神聖", "class_id": 5},
    258: {"name_en": "Shadow", "name_zh": "暗影", "class_id": 5},
    250: {"name_en": "Blood", "name_zh": "鮮血", "class_id": 6},
    251: {"name_en": "Frost", "name_zh": "冰霜", "class_id": 6},
    252: {"name_en": "Unholy", "name_zh": "邪惡", "class_id": 6},
    262: {"name_en": "Elemental", "name_zh": "元素", "class_id": 7},
    263: {"name_en": "Enhancement", "name_zh": "增強", "class_id": 7},
    264: {"name_en": "Restoration", "name_zh": "恢復", "class_id": 7},
    62: {"name_en": "Arcane", "name_zh": "奧術", "class_id": 8},
    63: {"name_en": "Fire", "name_zh": "火焰", "class_id": 8},
    64: {"name_en": "Frost", "name_zh": "冰霜", "class_id": 8},
    265: {"name_en": "Affliction", "name_zh": "痛苦", "class_id": 9},
    266: {"name_en": "Demonology", "name_zh": "惡魔學識", "class_id": 9},
    267: {"name_en": "Destruction", "name_zh": "毀滅", "class_id": 9},
    268: {"name_en": "Brewmaster", "name_zh": "酒仙", "class_id": 10},
    270: {"name_en": "Mistweaver", "name_zh": "織霧", "class_id": 10},
    269: {"name_en": "Windwalker", "name_zh": "踏風", "class_id": 10},
    102: {"name_en": "Balance", "name_zh": "平衡", "class_id": 11},
    103: {"name_en": "Feral", "name_zh": "野性", "class_id": 11},
    104: {"name_en": "Guardian", "name_zh": "守護者", "class_id": 11},
    105: {"name_en": "Restoration", "name_zh": "恢復", "class_id": 11},
    577: {"name_en": "Havoc", "name_zh": "浩劫", "class_id": 12},
    581: {"name_en": "Vengeance", "name_zh": "復仇", "class_id": 12},
    1480: {"name_en": "Devourer", "name_zh": "噬滅", "class_id": 12},
    1467: {"name_en": "Devastation", "name_zh": "湮滅", "class_id": 13},
    1468: {"name_en": "Preservation", "name_zh": "儲存", "class_id": 13},
    1473: {"name_en": "Augmentation", "name_zh": "增幅", "class_id": 13}
}

def clean_html(html_str):
    if not html_str:
        return ""
    text = re.sub(r'<br\s*/?>', '\n', html_str)
    text = re.sub(r'</p>', '\n', text)
    text = re.sub(r'</td>', ' ', text)
    text = re.sub(r'</tr>', '\n', text)
    text = re.sub(r'<[^>]+>', '', text)
    text = text.replace('&nbsp;', ' ').replace('&lt;', '<').replace('&gt;', '>').replace('&amp;', '&')
    lines = [l.strip() for l in text.split('\n') if l.strip()]
    return '\n'.join(lines)

def fetch_class_urls():
    print("Resolving class URLs 1 to 14 from Wowhead TW...")
    class_urls = []

    def resolve_url(cid):
        url = f"https://www.wowhead.com/tw/class={cid}"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
        try:
            with urllib.request.urlopen(req, timeout=8) as resp:
                final_url = urllib.parse.unquote(resp.geturl())
                return cid, final_url, True
        except Exception as e:
            return cid, f"https://www.wowhead.com/tw/class={cid} (無此職業/或超時: {e})", False

    with ThreadPoolExecutor(max_workers=14) as ex:
        results = list(ex.map(resolve_url, range(1, 15)))

    for cid, url, valid in sorted(results):
        class_urls.append({'class_id': cid, 'url': url, 'valid': valid})
    return class_urls

def fetch_talents_data():
    url = "https://nether.wowhead.com/data/talents-dragonflight?locale=10&dv=41&db=1786626888"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    print(f"Fetching Wowhead TW talent database from {url}...")
    with urllib.request.urlopen(req, timeout=15) as resp:
        content = resp.read().decode('utf-8')

    matches = re.findall(r'WH\.setPageData\("([^"]+)",\s*(.*?)\);(?=\s*WH\.setPageData|\s*$)', content, re.DOTALL)
    page_data = {}
    for key, val_str in matches:
        try:
            page_data[key] = json.loads(val_str)
        except Exception as e:
            print(f"Warning: Error parsing page data {key}: {e}")
    return page_data

def process_spells(page_data):
    trees = page_data.get('wow.talentCalcDragonflight.live.trees', [])
    abilities = page_data.get('wow.talentCalcDragonflight.live.abilities', [])
    pvp = page_data.get('wow.talentCalcDragonflight.live.pvp', [])

    spells_dict = {}

    def get_or_create(s_id, name, icon, c_id=None):
        if s_id not in spells_dict:
            spells_dict[s_id] = {
                'spell_id': s_id,
                'name': name or f"Spell {s_id}",
                'icon': icon or "",
                'class_id': c_id,
                'class_name': CLASSES_MAP[c_id]['name_zh'] if c_id in CLASSES_MAP else None,
                'class_name_en': CLASSES_MAP[c_id]['name_en'] if c_id in CLASSES_MAP else None,
                'categories': set(),
                'specs': set(),
                'hero_trees': set()
            }
        elif c_id and not spells_dict[s_id]['class_id']:
            spells_dict[s_id]['class_id'] = c_id
            spells_dict[s_id]['class_name'] = CLASSES_MAP[c_id]['name_zh'] if c_id in CLASSES_MAP else None
            spells_dict[s_id]['class_name_en'] = CLASSES_MAP[c_id]['name_en'] if c_id in CLASSES_MAP else None
        return spells_dict[s_id]

    # 1. Process abilities
    for a in abilities:
        c_id = a.get('playerClass')
        s_id = a.get('id')
        if s_id and c_id in CLASSES_MAP:
            sp = get_or_create(s_id, a.get('name'), a.get('icon'), c_id)
            spec_id = a.get('spec')
            if spec_id:
                sp['categories'].add('spec_ability')
                sp['specs'].add(spec_id)
            else:
                sp['categories'].add('class_ability')

    # 2. Process PvP talents
    for p in pvp:
        s_id = p.get('id')
        if s_id:
            specs_list = p.get('specs', [])
            c_id = SPECS_MAP[specs_list[0]]['class_id'] if specs_list and specs_list[0] in SPECS_MAP else None
            sp = get_or_create(s_id, p.get('name'), p.get('icon'), c_id)
            sp['categories'].add('pvp_talent')
            for spec_id in specs_list:
                sp['specs'].add(spec_id)

    # 3. Process Trees
    for t in trees:
        t_id = t.get('id')
        t_name = t.get('name')
        t_type = t.get('type') # 1: Class Talent, 2: Spec Talent, 3: Hero Talent
        c_id = t.get('playerClass')

        cat_label = "class_talent" if t_type == 1 else ("spec_talent" if t_type == 2 else "hero_talent")

        talents = t.get('talents', {})
        for cell_key, node_list in talents.items():
            if isinstance(node_list, list):
                for n in node_list:
                    shown_specs = n.get('shownForSpecs', [])
                    spells = n.get('spells', [])
                    for node_spell in spells:
                        s_id = node_spell.get('spell')
                        if s_id:
                            sp = get_or_create(s_id, node_spell.get('name'), node_spell.get('icon'), c_id)
                            sp['categories'].add(cat_label)
                            if t_type == 3 and t_name:
                                sp['hero_trees'].add(t_name)
                            for spec_id in shown_specs:
                                sp['specs'].add(spec_id)
                            if t_type == 2 and t_id in SPECS_MAP:
                                sp['specs'].add(t_id)

    # 4. Crawl class & spec ability listviews
    print("Crawling class ability listviews for extra spells...")
    for cid, cinfo in CLASSES_MAP.items():
        slug = cinfo['slug']
        for page_type in ['abilities', 'specialization']:
            url = f'https://www.wowhead.com/tw/spells/{page_type}/{slug}'
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
            try:
                with urllib.request.urlopen(req, timeout=10) as resp:
                    content = resp.read().decode('utf-8')
                    pos = content.find('var listviewspells = ')
                    if pos != -1:
                        end_pos = content.find(';\n', pos)
                        if end_pos == -1: end_pos = content.find('];', pos) + 1
                        js_text = content[pos + len('var listviewspells = '):end_pos].strip()
                        if js_text.endswith(';'): js_text = js_text[:-1]
                        json_text = re.sub(r'([{,])\s*([a-zA-Z_0-9]+)\s*:', r'\1"\2":', js_text)
                        json_text = re.sub(r',\s*([}\]])', r'\1', json_text)
                        spells_arr = json.loads(json_text)
                        for sp_item in spells_arr:
                            s_id = sp_item.get('id')
                            if s_id:
                                sp = get_or_create(s_id, sp_item.get('name'), sp_item.get('icon'), cid)
                                cat_name = 'spec_ability' if page_type == 'specialization' else 'class_ability'
                                sp['categories'].add(cat_name)
                                for ts in sp_item.get('talentspec', []):
                                    if ts in SPECS_MAP:
                                        sp['specs'].add(ts)
            except Exception as e:
                pass

    return spells_dict

def fetch_single_tooltip(s_id):
    url = f"https://nether.wowhead.com/tooltip/spell/{s_id}?locale=10"
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    })
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            buff_raw = data.get('buff', '')
            tooltip_raw = data.get('tooltip', '')
            has_aura = bool(buff_raw and buff_raw.strip())

            clean_buff = clean_html(buff_raw) if has_aura else ""
            clean_desc = clean_html(tooltip_raw)

            return s_id, {
                'has_aura': has_aura,
                'buff_html': buff_raw if has_aura else None,
                'buff_text': clean_buff if has_aura else None,
                'description': clean_desc,
                'name_override': data.get('name'),
                'icon_override': data.get('icon')
            }
    except Exception as e:
        return s_id, {
            'has_aura': False,
            'buff_html': None,
            'buff_text': None,
            'description': "",
            'error': str(e)
        }

def main():
    start_time = time.time()

    # Resolve Class 1 to 14 URLs
    class_urls = fetch_class_urls()
    for item in class_urls:
        print(f"  Class {item['class_id']}: {item['url']}")

    page_data = fetch_talents_data()
    spells_dict = process_spells(page_data)

    total_spells = len(spells_dict)
    print(f"\nCollected total {total_spells} unique spells across all classes and specs. Fetching tooltips...")

    spell_ids = list(spells_dict.keys())
    tooltips_results = {}

    fetched_count = 0
    with ThreadPoolExecutor(max_workers=25) as executor:
        futures = [executor.submit(fetch_single_tooltip, s_id) for s_id in spell_ids]
        for f in futures:
            s_id, t_info = f.result()
            tooltips_results[s_id] = t_info
            fetched_count += 1
            if fetched_count % 500 == 0 or fetched_count == total_spells:
                elapsed = time.time() - start_time
                print(f"Fetched {fetched_count}/{total_spells} TW tooltips... ({elapsed:.1f}s)")

    output_spells = []
    aura_count = 0

    for s_id, sp in spells_dict.items():
        t_info = tooltips_results.get(s_id, {})
        has_aura = t_info.get('has_aura', False)

        cats = list(sp['categories'])
        if has_aura:
            cats.append('aura')
            aura_count += 1

        specs_list = []
        for spec_id in sorted(list(sp['specs'])):
            if spec_id in SPECS_MAP:
                specs_list.append({
                    'spec_id': spec_id,
                    'spec_name_zh': SPECS_MAP[spec_id]['name_zh'],
                    'spec_name_en': SPECS_MAP[spec_id]['name_en']
                })
            else:
                specs_list.append({'spec_id': spec_id, 'spec_name_zh': f"專精 {spec_id}", 'spec_name_en': f"Spec {spec_id}"})

        output_spells.append({
            'spell_id': s_id,
            'name': t_info.get('name_override') or sp['name'],
            'icon': t_info.get('icon_override') or sp['icon'],
            'class_id': sp['class_id'],
            'class_name': sp['class_name'],
            'class_name_en': sp['class_name_en'],
            'categories': sorted(cats),
            'specs': specs_list,
            'hero_trees': sorted(list(sp['hero_trees'])),
            'has_aura': has_aura,
            'aura_info': {
                'raw_html': t_info.get('buff_html'),
                'clean_text': t_info.get('buff_text')
            } if has_aura else None,
            'description': t_info.get('description', '')
        })

    output_spells.sort(key=lambda x: (x['class_id'] or 99, x['spell_id']))

    final_output = {
        'source': 'https://www.wowhead.com/tw/spells',
        'generated_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'class_urls_traversed': class_urls,
        'total_spells': len(output_spells),
        'total_auras': aura_count,
        'classes': [
            {'id': c_id, 'name_zh': c_info['name_zh'], 'name_en': c_info['name_en'], 'slug': c_info['slug']}
            for c_id, c_info in sorted(CLASSES_MAP.items())
        ],
        'spells': output_spells
    }

    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    data_dir = os.path.join(project_root, 'Data')
    os.makedirs(data_dir, exist_ok=True)
    out_file = os.path.join(data_dir, 'wow_spells_and_auras.json')
    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    elapsed_total = time.time() - start_time
    file_size_mb = os.path.getsize(out_file) / (1024 * 1024)
    print(f"\nSuccessfully generated full TW dataset: {out_file}!")
    print(f"Total Spells: {len(output_spells)}")
    print(f"Total Auras: {aura_count}")
    print(f"File Size: {file_size_mb:.2f} MB")
    print(f"Total Execution Time: {elapsed_total:.2f}s")

if __name__ == '__main__':
    main()

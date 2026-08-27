import urllib.request
import urllib.parse
import re
import json
import time
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

LOCALES = {
    'en': {'id': 0, 'prefix': '', 'name': 'English'},
    'tw': {'id': 10, 'prefix': 'tw', 'name': '繁體中文'},
    'cn': {'id': 7, 'prefix': 'cn', 'name': '简体中文'},
    'kr': {'id': 8, 'prefix': 'ko', 'name': '한국어'},
    'ru': {'id': 6, 'prefix': 'ru', 'name': 'Русский'}
}

CLASSES_MAP = {
    1: {"names": {"en": "Warrior", "tw": "戰士", "cn": "战士", "kr": "전사", "ru": "Воин"}, "slug": "warrior"},
    2: {"names": {"en": "Paladin", "tw": "聖騎士", "cn": "圣骑士", "kr": "성기사", "ru": "Паладин"}, "slug": "paladin"},
    3: {"names": {"en": "Hunter", "tw": "獵人", "cn": "猎人", "kr": "사냥꾼", "ru": "Охотник"}, "slug": "hunter"},
    4: {"names": {"en": "Rogue", "tw": "盜賊", "cn": "潜行者", "kr": "도적", "ru": "Разбойник"}, "slug": "rogue"},
    5: {"names": {"en": "Priest", "tw": "牧師", "cn": "牧师", "kr": "사제", "ru": "Жрец"}, "slug": "priest"},
    6: {"names": {"en": "Death Knight", "tw": "死亡騎士", "cn": "死亡骑士", "kr": "죽음의 기사", "ru": "Рыцарь смерти"}, "slug": "death-knight"},
    7: {"names": {"en": "Shaman", "tw": "薩滿", "cn": "萨满祭司", "kr": "주술사", "ru": "Шаман"}, "slug": "shaman"},
    8: {"names": {"en": "Mage", "tw": "法師", "cn": "法师", "kr": "마법사", "ru": "Маг"}, "slug": "mage"},
    9: {"names": {"en": "Warlock", "tw": "術士", "cn": "术士", "kr": "흑마법사", "ru": "Чернокнижник"}, "slug": "warlock"},
    10: {"names": {"en": "Monk", "tw": "武僧", "cn": "武僧", "kr": "수도사", "ru": "Монах"}, "slug": "monk"},
    11: {"names": {"en": "Druid", "tw": "德魯伊", "cn": "德鲁伊", "kr": "드루이드", "ru": "Друид"}, "slug": "druid"},
    12: {"names": {"en": "Demon Hunter", "tw": "惡魔獵人", "cn": "恶魔猎手", "kr": "악마사냥꾼", "ru": "Охотник на демонов"}, "slug": "demon-hunter"},
    13: {"names": {"en": "Evoker", "tw": "喚能師", "cn": "唤魔师", "kr": "기원사", "ru": "Пробудитель"}, "slug": "evoker"}
}

SPECS_MAP = {
    71: {"names": {"en": "Arms", "tw": "武器", "cn": "武器", "kr": "무기", "ru": "Оружие"}, "class_id": 1},
    72: {"names": {"en": "Fury", "tw": "狂怒", "cn": "狂怒", "kr": "분노", "ru": "Неистовство"}, "class_id": 1},
    73: {"names": {"en": "Protection", "tw": "防護", "cn": "防护", "kr": "방어", "ru": "Защита"}, "class_id": 1},
    65: {"names": {"en": "Holy", "tw": "神聖", "cn": "神圣", "kr": "신성", "ru": "Свет"}, "class_id": 2},
    66: {"names": {"en": "Protection", "tw": "防護", "cn": "防护", "kr": "보호", "ru": "Защита"}, "class_id": 2},
    70: {"names": {"en": "Retribution", "tw": "懲戒", "cn": "惩戒", "kr": "징벌", "ru": "Воздаяние"}, "class_id": 2},
    253: {"names": {"en": "Beast Mastery", "tw": "野獸控制", "cn": "野兽控制", "kr": "야수", "ru": "Повелитель зверей"}, "class_id": 3},
    254: {"names": {"en": "Marksmanship", "tw": "射擊", "cn": "射击", "kr": "사격", "ru": "Стрельба"}, "class_id": 3},
    255: {"names": {"en": "Survival", "tw": "生存", "cn": "生存", "kr": "생존", "ru": "Выживание"}, "class_id": 3},
    259: {"names": {"en": "Assassination", "tw": "刺殺", "cn": "奇袭", "kr": "암살", "ru": "Ликвидация"}, "class_id": 4},
    260: {"names": {"en": "Outlaw", "tw": "狂徒", "cn": "狂徒", "kr": "무법", "ru": "Головорез"}, "class_id": 4},
    261: {"names": {"en": "Subtlety", "tw": "敏銳", "cn": "敏锐", "kr": "잠행", "ru": "Скрытность"}, "class_id": 4},
    256: {"names": {"en": "Discipline", "tw": "戒律", "cn": "戒律", "kr": "수양", "ru": "Послушание"}, "class_id": 5},
    257: {"names": {"en": "Holy", "tw": "神聖", "cn": "神圣", "kr": "신성", "ru": "Священность"}, "class_id": 5},
    258: {"names": {"en": "Shadow", "tw": "暗影", "cn": "暗影", "kr": "암흑", "ru": "Тьма"}, "class_id": 5},
    250: {"names": {"en": "Blood", "tw": "鮮血", "cn": "鲜血", "kr": "혈기", "ru": "Кровь"}, "class_id": 6},
    251: {"names": {"en": "Frost", "tw": "冰霜", "cn": "冰霜", "kr": "냉기", "ru": "Лед"}, "class_id": 6},
    252: {"names": {"en": "Unholy", "tw": "邪惡", "cn": "邪恶", "kr": "부정", "ru": "Нечестивость"}, "class_id": 6},
    262: {"names": {"en": "Elemental", "tw": "元素", "cn": "元素", "kr": "원소", "ru": "Стихии"}, "class_id": 7},
    263: {"names": {"en": "Enhancement", "tw": "增強", "cn": "增强", "kr": "고양", "ru": "Совершенствование"}, "class_id": 7},
    264: {"names": {"en": "Restoration", "tw": "恢復", "cn": "恢复", "kr": "복원", "ru": "Исцеление"}, "class_id": 7},
    62: {"names": {"en": "Arcane", "tw": "奧術", "cn": "奥术", "kr": "비전", "ru": "Тайная магия"}, "class_id": 8},
    63: {"names": {"en": "Fire", "tw": "火焰", "cn": "火焰", "kr": "화염", "ru": "Огонь"}, "class_id": 8},
    64: {"names": {"en": "Frost", "tw": "冰霜", "cn": "冰霜", "kr": "冰霜", "kr": "냉기", "ru": "Лед"}, "class_id": 8},
    265: {"names": {"en": "Affliction", "tw": "痛苦", "cn": "痛苦", "kr": "고통", "ru": "Колдовство"}, "class_id": 9},
    266: {"names": {"en": "Demonology", "tw": "惡魔學識", "cn": "恶魔学识", "kr": "악마", "ru": "Демонология"}, "class_id": 9},
    267: {"names": {"en": "Destruction", "tw": "毀滅", "cn": "毁灭", "kr": "파괴", "ru": "Разрушение"}, "class_id": 9},
    268: {"names": {"en": "Brewmaster", "tw": "酒仙", "cn": "酒仙", "kr": "양조", "ru": "Хмелевар"}, "class_id": 10},
    270: {"names": {"en": "Mistweaver", "tw": "織霧", "cn": "织雾", "kr": "운무", "ru": "Ткач туманов"}, "class_id": 10},
    269: {"names": {"en": "Windwalker", "tw": "踏風", "cn": "踏风", "kr": "풍운", "ru": "Танцующий с ветром"}, "class_id": 10},
    102: {"names": {"en": "Balance", "tw": "平衡", "cn": "平衡", "kr": "조화", "ru": "Баланс"}, "class_id": 11},
    103: {"names": {"en": "Feral", "tw": "野性", "cn": "野性", "kr": "야성", "ru": "Сила зверя"}, "class_id": 11},
    104: {"names": {"en": "Guardian", "tw": "守護者", "cn": "守护", "kr": "수호", "ru": "Страж"}, "class_id": 11},
    105: {"names": {"en": "Restoration", "tw": "恢復", "cn": "恢复", "kr": "회복", "ru": "Исцеление"}, "class_id": 11},
    577: {"names": {"en": "Havoc", "tw": "浩劫", "cn": "浩劫", "kr": "파멸", "ru": "Истребление"}, "class_id": 12},
    581: {"names": {"en": "Vengeance", "tw": "復仇", "cn": "复仇", "kr": "복수", "ru": "Месть"}, "class_id": 12},
    1480: {"names": {"en": "Devourer", "tw": "噬滅", "cn": "噬灭", "kr": "삼키는 자", "ru": "Пожиратель"}, "class_id": 12},
    1467: {"names": {"en": "Devastation", "tw": "湮滅", "cn": "湮灭", "kr": "황폐", "ru": "Опустошитель"}, "class_id": 13},
    1468: {"names": {"en": "Preservation", "tw": "儲存", "cn": "恩赐", "kr": "보존", "ru": "Хранитель"}, "class_id": 13},
    1473: {"names": {"en": "Augmentation", "tw": "增幅", "cn": "湮灭", "kr": "증강", "ru": "Насыщатель"}, "class_id": 13}
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
    print("[1/5] Traversing class URLs 1 to 14 from Wowhead across locales...")
    class_urls = []

    def resolve_url(cid):
        url = f"https://www.wowhead.com/tw/class={cid}"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                final_url = urllib.parse.unquote(resp.geturl())
                return cid, final_url, True
        except Exception as e:
            return cid, f"https://www.wowhead.com/tw/class={cid} (無此職業/或超時: {e})", False

    with ThreadPoolExecutor(max_workers=14) as ex:
        results = list(ex.map(resolve_url, range(1, 15)))

    for cid, url, valid in sorted(results):
        class_urls.append({'class_id': cid, 'url': url, 'valid': valid})
    return class_urls

def fetch_talents_payload(loc_key, loc_info):
    url = f"https://nether.wowhead.com/data/talents-dragonflight?locale={loc_info['id']}&dv=41"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    print(f"  Fetching talent database for {loc_key.upper()} ({loc_info['name']}) from {url}...")
    with urllib.request.urlopen(req, timeout=20) as resp:
        content = resp.read().decode('utf-8')

    matches = re.findall(r'WH\.setPageData\("([^"]+)",\s*(.*?)\);(?=\s*WH\.setPageData|\s*$)', content, re.DOTALL)
    page_data = {}
    for key, val_str in matches:
        try:
            page_data[key] = json.loads(val_str)
        except Exception as e:
            print(f"Warning: Error parsing page data {key} for {loc_key}: {e}")
    return loc_key, page_data

def process_all_locales_talents(all_page_data):
    print("\n[2/5] Processing spells, talents, abilities, and PvP across all 5 locales...")
    spells_dict = {}

    def get_or_create(s_id, c_id=None):
        if s_id not in spells_dict:
            spells_dict[s_id] = {
                'spell_id': s_id,
                'names': {},
                'icon': '',
                'class_id': c_id,
                'categories': set(),
                'specs': set(),
                'hero_trees': {loc: set() for loc in LOCALES}
            }
        elif c_id and not spells_dict[s_id]['class_id']:
            spells_dict[s_id]['class_id'] = c_id
        return spells_dict[s_id]

    for loc_key, page_data in all_page_data.items():
        trees = page_data.get('wow.talentCalcDragonflight.live.trees', [])
        abilities = page_data.get('wow.talentCalcDragonflight.live.abilities', [])
        pvp = page_data.get('wow.talentCalcDragonflight.live.pvp', [])

        # 1. Process abilities
        for a in abilities:
            c_id = a.get('playerClass')
            s_id = a.get('id')
            if s_id and c_id in CLASSES_MAP:
                sp = get_or_create(s_id, c_id)
                name = a.get('name')
                if name: sp['names'][loc_key] = name
                if a.get('icon'): sp['icon'] = a.get('icon')
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
                sp = get_or_create(s_id, c_id)
                name = p.get('name')
                if name: sp['names'][loc_key] = name
                if p.get('icon'): sp['icon'] = p.get('icon')
                sp['categories'].add('pvp_talent')
                for spec_id in specs_list:
                    sp['specs'].add(spec_id)

        # 3. Process Trees
        for t in trees:
            t_id = t.get('id')
            t_name = t.get('name')
            t_type = t.get('type') # 1: Class, 2: Spec, 3: Hero
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
                                sp = get_or_create(s_id, c_id)
                                name = node_spell.get('name')
                                if name: sp['names'][loc_key] = name
                                if node_spell.get('icon'): sp['icon'] = node_spell.get('icon')
                                sp['categories'].add(cat_label)
                                if t_type == 3 and t_name:
                                    sp['hero_trees'][loc_key].add(t_name)
                                for spec_id in shown_specs:
                                    sp['specs'].add(spec_id)
                                if t_type == 2 and t_id in SPECS_MAP:
                                    sp['specs'].add(t_id)

    print(f"Total unique spells extracted from trees & abilities: {len(spells_dict)}")
    return spells_dict

def fetch_single_spell_multilingual_tooltip(s_id):
    results = {}
    for loc_key, loc_info in LOCALES.items():
        lid = loc_info['id']
        url = f"https://nether.wowhead.com/tooltip/spell/{s_id}?locale={lid}"
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

                results[loc_key] = {
                    'name': data.get('name', ''),
                    'icon': data.get('icon', ''),
                    'has_aura': has_aura,
                    'buff_text': clean_buff if has_aura else "",
                    'description': clean_desc
                }
        except Exception as e:
            results[loc_key] = {
                'name': '',
                'icon': '',
                'has_aura': False,
                'buff_text': '',
                'description': '',
                'error': str(e)
            }
    return s_id, results

def main():
    start_time = time.time()
    print("==================================================================")
    print("EventAlertMod Wowhead Multi-Lingual (5 Locales) Spell Extractor")
    print("Locales: EN, TW, CN, KR, RU | Classes: 1 to 13 (and 14 traversed)")
    print("==================================================================")

    # 1. Resolve Class URLs
    class_urls = fetch_class_urls()

    # 2. Fetch talent payloads for all 5 locales in parallel
    print("\nFetching talent payloads for 5 locales in parallel...")
    all_page_data = {}
    with ThreadPoolExecutor(max_workers=5) as ex:
        futures = [ex.submit(fetch_talents_payload, loc_key, loc_info) for loc_key, loc_info in LOCALES.items()]
        for f in as_completed(futures):
            loc_key, page_data = f.result()
            all_page_data[loc_key] = page_data

    # 3. Process spells
    spells_dict = process_all_locales_talents(all_page_data)
    total_spells = len(spells_dict)
    spell_ids = sorted(list(spells_dict.keys()))

    # 4. Fetch 5-locale tooltips concurrently
    print(f"\n[3/5] Fetching 5-locale tooltips & auras for {total_spells} spells...")
    tooltips_map = {}
    fetched_count = 0
    with ThreadPoolExecutor(max_workers=30) as executor:
        future_to_id = {executor.submit(fetch_single_spell_multilingual_tooltip, s_id): s_id for s_id in spell_ids}
        for future in as_completed(future_to_id):
            s_id, t_info_by_loc = future.result()
            tooltips_map[s_id] = t_info_by_loc
            fetched_count += 1
            if fetched_count % 300 == 0 or fetched_count == total_spells:
                elapsed = time.time() - start_time
                print(f"  Progress: {fetched_count}/{total_spells} spells (5 locales each) ... [{elapsed:.1f}s]")

    # 5. Format output
    print("\n[4/5] Formatting multi-lingual records...")
    output_spells = []
    total_auras = 0

    for s_id in spell_ids:
        sp = spells_dict[s_id]
        t_loc = tooltips_map.get(s_id, {})

        # Determine has_aura (if any locale returns has_aura = true)
        has_aura = any(t_loc.get(loc, {}).get('has_aura', False) for loc in LOCALES)
        if has_aura:
            total_auras += 1

        # Determine primary name & icon (prefer TW/EN)
        name_tw = t_loc.get('tw', {}).get('name') or sp['names'].get('tw')
        name_en = t_loc.get('en', {}).get('name') or sp['names'].get('en')
        primary_name = name_tw or name_en or f"Spell {s_id}"

        icon_val = ""
        for loc in ['tw', 'en', 'cn', 'kr', 'ru']:
            if t_loc.get(loc, {}).get('icon'):
                icon_val = t_loc[loc]['icon']
                break
        if not icon_val:
            icon_val = sp.get('icon', '')

        # Localized names
        names_dict = {}
        for loc in LOCALES:
            names_dict[loc] = t_loc.get(loc, {}).get('name') or sp['names'].get(loc) or primary_name

        # Localized descriptions
        desc_dict = {}
        for loc in LOCALES:
            desc_dict[loc] = t_loc.get(loc, {}).get('description', '')

        # Localized aura texts
        aura_dict = {}
        if has_aura:
            for loc in LOCALES:
                aura_dict[loc] = t_loc.get(loc, {}).get('buff_text', '')

        cats = list(sp['categories'])
        if has_aura:
            cats.append('aura')

        c_id = sp['class_id']
        class_names = CLASSES_MAP[c_id]['names'] if c_id in CLASSES_MAP else None

        specs_list = []
        for spec_id in sorted(list(sp['specs'])):
            if spec_id in SPECS_MAP:
                specs_list.append({
                    'spec_id': spec_id,
                    'names': SPECS_MAP[spec_id]['names'],
                    'name_zh': SPECS_MAP[spec_id]['names']['tw'],
                    'name_en': SPECS_MAP[spec_id]['names']['en']
                })
            else:
                specs_list.append({
                    'spec_id': spec_id,
                    'names': {loc: f"Spec {spec_id}" for loc in LOCALES},
                    'name_zh': f"專精 {spec_id}",
                    'name_en': f"Spec {spec_id}"
                })

        hero_trees_dict = {}
        for loc in LOCALES:
            hero_trees_dict[loc] = sorted(list(sp['hero_trees'][loc]))

        record = {
            'spell_id': s_id,
            'name': primary_name,
            'name_zh': names_dict['tw'],
            'name_en': names_dict['en'],
            'names': names_dict,
            'icon': icon_val,
            'class_id': c_id,
            'class_names': class_names,
            'class_name': class_names['tw'] if class_names else None,
            'class_name_en': class_names['en'] if class_names else None,
            'categories': sorted(cats),
            'specs': specs_list,
            'hero_trees': hero_trees_dict,
            'has_aura': has_aura,
            'aura_texts': aura_dict if has_aura else None,
            'descriptions': desc_dict
        }
        output_spells.append(record)

    output_spells.sort(key=lambda x: (x['class_id'] or 99, x['spell_id']))

    final_output = {
        'source': 'https://www.wowhead.com/spells/live-only:on',
        'generated_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'locales': list(LOCALES.keys()),
        'class_urls_traversed': class_urls,
        'total_spells': len(output_spells),
        'total_auras': total_auras,
        'classes': [
            {
                'id': cid,
                'slug': cinfo['slug'],
                'names': cinfo['names'],
                'name_zh': cinfo['names']['tw'],
                'name_en': cinfo['names']['en']
            }
            for cid, cinfo in sorted(CLASSES_MAP.items())
        ],
        'spells': output_spells
    }

    governance_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    data_dir = os.path.join(governance_root, 'Data')
    os.makedirs(data_dir, exist_ok=True)
    out_file = os.path.join(data_dir, 'wow_spells_and_auras.json')

    print(f"\n[5/5] Writing canonical dataset to {out_file}...")
    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    elapsed_total = time.time() - start_time
    file_size_mb = os.path.getsize(out_file) / (1024 * 1024)
    print("\n==================================================================")
    print("🎉 Wowhead 5-Locale Dataset Extraction Completed Successfully!")
    print(f"Target Output: {out_file}")
    print(f"Locales: {', '.join([k.upper() for k in LOCALES.keys()])}")
    print(f"Total Spells Extracted: {len(output_spells)}")
    print(f"Total Auras Identified: {total_auras}")
    print(f"Final File Size: {file_size_mb:.2f} MB")
    print(f"Total Execution Time: {elapsed_total:.2f}s")
    print("==================================================================")

if __name__ == '__main__':
    main()

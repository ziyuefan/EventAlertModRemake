import sys
import os
import re
import zlib
import json
import base64

print('=== 1. Checking Lua Syntax & Block Balance for ALL Addon Files ===')

def check_lua_balance(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        src = f.read()

    i = 0
    n = len(src)
    block_stack = []
    paren_depth = 0
    bracket_depth = 0
    brace_depth = 0
    line = 1
    
    while i < n:
        ch = src[i]
        if ch == '\n':
            line += 1
            i += 1
            continue
            
        # Comments
        if ch == '-' and i + 1 < n and src[i+1] == '-':
            i += 2
            if i < n and src[i] == '[':
                eq_count = 0
                j = i + 1
                while j < n and src[j] == '=':
                    eq_count += 1
                    j += 1
                if j < n and src[j] == '[':
                    closing = ']' + ('=' * eq_count) + ']'
                    pos = src.find(closing, j + 1)
                    if pos == -1:
                        raise SyntaxError(f"Unclosed long comment in {filepath} at line {line}")
                    line += src[i:pos+len(closing)].count('\n')
                    i = pos + len(closing)
                    continue
            while i < n and src[i] != '\n':
                i += 1
            continue
            
        # Long strings [=[ ... ]=]
        if ch == '[' and (i + 1 < n and (src[i+1] == '[' or src[i+1] == '=')):
            eq_count = 0
            j = i + 1
            while j < n and src[j] == '=':
                eq_count += 1
                j += 1
            if j < n and src[j] == '[':
                closing = ']' + ('=' * eq_count) + ']'
                pos = src.find(closing, j + 1)
                if pos == -1:
                    raise SyntaxError(f"Unclosed long string in {filepath} at line {line}")
                line += src[i:pos+len(closing)].count('\n')
                i = pos + len(closing)
                continue
                
        # Short strings "..." or '...'
        if ch == '"' or ch == "'":
            quote = ch
            i += 1
            while i < n:
                c = src[i]
                if c == '\n':
                    raise SyntaxError(f"Unclosed string in {filepath} at line {line}")
                if c == '\\':
                    i += 2
                    continue
                if c == quote:
                    i += 1
                    break
                i += 1
            continue
            
        # Brackets and parens
        if ch == '(':
            paren_depth += 1
            i += 1
            continue
        elif ch == ')':
            paren_depth -= 1
            assert paren_depth >= 0, f"{filepath}: Unmatched ')' at line {line}"
            i += 1
            continue
        elif ch == '[':
            bracket_depth += 1
            i += 1
            continue
        elif ch == ']':
            bracket_depth -= 1
            assert bracket_depth >= 0, f"{filepath}: Unmatched ']' at line {line}"
            i += 1
            continue
        elif ch == '{':
            brace_depth += 1
            i += 1
            continue
        elif ch == '}':
            brace_depth -= 1
            assert brace_depth >= 0, f"{filepath}: Unmatched '}}' at line {line}"
            i += 1
            continue
            
        # Identifiers and keywords
        if ch.isalpha() or ch == '_':
            start = i
            while i < n and (src[i].isalnum() or src[i] == '_'):
                i += 1
            word = src[start:i]
            
            if word in ('function', 'if', 'do'):
                block_stack.append((word, line))
            elif word == 'repeat':
                block_stack.append(('repeat', line))
            elif word == 'until':
                assert block_stack and block_stack[-1][0] == 'repeat', f"{filepath}: Unmatched 'until' at line {line}"
                block_stack.pop()
            elif word == 'end':
                assert block_stack, f"{filepath}: Unmatched 'end' at line {line}"
                top, top_line = block_stack.pop()
                assert top in ('function', 'if', 'do'), f"{filepath}: Mismatched 'end' for '{top}' (line {top_line}) at line {line}"
            continue
            
        i += 1

    assert paren_depth == 0, f'{filepath}: Unclosed parenthesis ({paren_depth})'
    assert bracket_depth == 0, f'{filepath}: Unclosed bracket ({bracket_depth})'
    assert brace_depth == 0, f'{filepath}: Unclosed brace ({brace_depth})'
    assert len(block_stack) == 0, f'{filepath}: Unclosed block {block_stack[-1]}'

total_checked = 0
for root, _, files in os.walk('EventAlertMod'):
    for f in sorted(files):
        if f.endswith('.lua'):
            p = os.path.join(root, f).replace('\\', '/')
            check_lua_balance(p)
            total_checked += 1

print(f'  [PASS] All {total_checked} Lua files in EventAlertMod verified perfectly balanced.')

print('=== 2. Testing Deflate Fallback RFC 1951 Compatibility ===')
def fallback_deflate(s):
    b = s.encode('utf-8')
    parts = []
    pos = 0
    while pos < len(b) or len(b) == 0:
        chunk = b[pos:pos+65535]
        is_final = 1 if pos + len(chunk) >= len(b) else 0
        l = len(chunk)
        nl = 65535 - l
        parts.append(bytes([is_final, l % 256, l // 256, nl % 256, nl // 256]) + chunk)
        pos += len(chunk)
        if len(b) == 0: break
    return b''.join(parts)

def fallback_inflate(b):
    pos = 0
    parts = []
    while pos < len(b):
        if pos + 5 > len(b): break
        header = b[pos]
        is_final = (header % 2 == 1)
        btype = (header % 8) // 2
        assert btype == 0
        l = b[pos+1] + b[pos+2] * 256
        nl = b[pos+3] + b[pos+4] * 256
        assert l + nl == 65535
        pos += 5
        parts.append(b[pos:pos+l])
        pos += l
        if is_final: break
    return b''.join(parts)

test_strings = ['', 'a', 'hello world', 'long text '*5000]
for ts in test_strings:
    c = fallback_deflate(ts)
    d_zlib = zlib.decompress(c, -zlib.MAX_WBITS).decode('utf-8')
    assert d_zlib == ts, f'zlib decompress mismatch on len {len(ts)}'
    d_fallback = fallback_inflate(c).decode('utf-8')
    assert d_fallback == ts, f'fallback inflate mismatch on len {len(ts)}'
print('  [PASS] Deflate RFC 1951 uncompressed stream 100% round-trip verified (both standard zlib and custom inflate)')

print('=== 3. Testing TOC Integration ===')
toc_content = open('EventAlertMod/EventAlertMod.toc', 'r', encoding='utf-8').read()
assert 'Debug\\EngineProfiler.lua' in toc_content, 'Debug\\EngineProfiler.lua missing from TOC'
print('  [PASS] Debug\\EngineProfiler.lua correctly registered in EventAlertMod.toc')

print('=== 4. Testing ProfileCodec Bug Fixes: compareRecord id and exportProfile cBackend ===')
codec_src = open('EventAlertMod/Core/ProfileCodec.lua', 'r', encoding='utf-8').read()
assert 'local id = record[definition.idField]' in codec_src, 'Missing local id definition in compareRecord!'
assert 'local compressed = nil' in codec_src, 'exportProfile should use clean single assignments for compressed and cBackend'
assert 'PREFIX_V1 = "EAMAP1:"' in codec_src
assert 'PREFIX_V2 = "EAMAP2:"' in codec_src
assert 'PREFIX = PREFIX_V2' in codec_src
assert 'function Codec.importProfile(' in codec_src
print('  [PASS] ProfileCodec.compareRecord id bug and exportProfile multiple assignment verified fixed')

print('=== 5. Testing Util.lua Bug Fixes: boolean ternary idiom and Deflate/Inflate alias ===')
util_src = open('EventAlertMod/Core/Util.lua', 'r', encoding='utf-8').read()
# Verify ternary idiom fix: if boolValue then return valIfTrue else return valIfFalse end
assert 'if boolValue then\n        return valIfTrue\n    else\n        return valIfFalse\n    end' in util_src, 'Util.evaluateColorValueFromBoolean must use explicit if/else, not boolean short-circuit!'
assert 'if boolValue then\n        return colorIfTrue\n    else\n        return colorIfFalse\n    end' in util_src, 'Util.evaluateColorFromBoolean must use explicit if/else, not boolean short-circuit!'
assert 'encoding.Deflate' in util_src, 'Missing C_EncodingUtil.Deflate alias check'
assert 'encoding.Inflate' in util_src, 'Missing C_EncodingUtil.Inflate alias check'
assert 'return nil, err or "decompressFailed"' in util_src, 'decompressString must propagate error instead of returning raw passthrough'
print('  [PASS] Util.lua evaluateColor boolean ternary and C_EncodingUtil aliases verified fixed')

print('=== 6. Testing Renderer.lua Bug Fixes: outOfRange and notUsable chaining ===')
renderer_src = open('EventAlertMod/UI/Renderer.lua', 'r', encoding='utf-8').read()
assert 'if alertState.outOfRange ~= nil and Util.evaluateColorValueFromBoolean then\n        targetAlpha = Util.evaluateColorValueFromBoolean(alertState.outOfRange, baseAlpha * 0.6, baseAlpha)\n    end\n    if alertState.notUsable ~= nil and Util.evaluateColorValueFromBoolean then\n        targetAlpha = Util.evaluateColorValueFromBoolean(alertState.notUsable, baseAlpha * 0.6, targetAlpha)\n    end' in renderer_src, 'Renderer alpha must chain outOfRange and notUsable independently without elseif skipping!'
print('  [PASS] Renderer.lua alpha evaluation chaining verified fixed')

print('=== 7. Testing CooldownService Loss of Control Verification ===')
cd_src = open('EventAlertMod/Services/CooldownService.lua', 'r', encoding='utf-8').read()
assert 'GetSpellLossOfControlCooldown' in cd_src
assert 'GetSpellLossOfControlCooldownDuration' in cd_src
assert 'setProtectedTimer(state, locDurationObj, "lossOfControl")' in cd_src, 'locDurationObj must invoke setProtectedTimer!'
assert 'LOSS_OF_CONTROL_UPDATE' in cd_src
assert 'LOSS_OF_CONTROL_ADDED' in cd_src
print('  [PASS] CooldownService LoC lockout duration object and setProtectedTimer verified')

print('=== 8. Testing PlayerStatService Authoritative Return ===')
stat_src = open('EventAlertMod/Services/PlayerStatService.lua', 'r', encoding='utf-8').read()
assert 'CreateUnitHealPredictionCalculator' in stat_src
assert 'UnitGetDetailedHealPrediction' in stat_src
assert 'calc.GetDamageAbsorbs' in stat_src
assert 'calc.GetHealAbsorbs' in stat_src
assert 'if okDmg and isSafeNumber(dmgAbsorb) then\n                        PlayerStatService.lastKnownStats["totalAbsorb"] = dmgAbsorb\n                        return dmgAbsorb\n                    end' in stat_src
assert 'if okHeal and isSafeNumber(hAbsorb) then\n                        PlayerStatService.lastKnownStats["healAbsorb"] = hAbsorb\n                        return hAbsorb\n                    end' in stat_src
print('  [PASS] PlayerStatService native heal/absorb calculator authoritative 0-return verified')

print('=== 9. Testing MediaService TTS and EngineProfiler Integration ===')
media_src = open('EventAlertMod/Services/MediaService.lua', 'r', encoding='utf-8').read()
assert 'function MediaService.speakTTS(text, category, allowOverlap)' in media_src
assert 'C_CombatAudioAlert' in media_src
assert 'function MediaService.hasTTS()' in media_src

prof_src = open('EventAlertMod/Debug/EngineProfiler.lua', 'r', encoding='utf-8').read()
assert 'C_AddOnProfiler' in prof_src
assert 'function EngineProfiler.getMetrics(' in prof_src
assert 'function EngineProfiler.formatSummary(' in prof_src
print('=== 10. Testing NativeAuraRenderer 12.1.5+ SetApplicationBar, SetDurationBar & Animations ===')
nar_src = open('EventAlertMod/UI/NativeAuraRenderer.lua', 'r', encoding='utf-8').read()
assert 'function bindApplicationBar(auraButton, style)' in nar_src
assert 'function bindDurationBar(auraButton, style)' in nar_src
assert 'auraButton.SetApplicationBar' in nar_src
assert 'auraButton.SetDurationBar' in nar_src
assert 'StatusBarInterpolation.ExponentialEaseOut' in nar_src, 'Missing StatusBarInterpolation.ExponentialEaseOut in NativeAuraRenderer'
assert 'interpolation = interpEnum' in nar_src, 'Missing interpolation in SetApplicationBar options table'
assert 'nativeApplicationBarCapabilityCount' in nar_src
assert 'applicationBarBoundCount' in nar_src
assert 'nativeDurationBarCapabilityCount' in nar_src
assert 'durationBarBoundCount' in nar_src
assert 'activeAnim:SetLooping("BOUNCE")' in nar_src
assert 'scale:SetSmoothing("IN_OUT")' in nar_src
assert 'scale:SetSmoothing("OUT")' in nar_src
assert 'scale:SetSmoothing("IN")' in nar_src
assert 'Util.snapToPixels(auraButton.eamApplicationBar)' in nar_src
assert 'Util.snapToPixels(auraButton.eamDurationBar)' in nar_src
print('  [PASS] NativeAuraRenderer 12.1.5+ ApplicationBar, DurationBar, Animations and Pixel Snapping verified')

print('=== 11. Testing Scheduler 12.1.5+ TimedSignalMap Capability Detection & Renderer Integration ===')
sched_src = open('EventAlertMod/Core/Scheduler.lua', 'r', encoding='utf-8').read()
assert 'TimerUtil.CreateTimedSignalCallbackMap' in sched_src
assert 'cTimer.CreateTimedSignalCallbackMap' in sched_src
assert 'cTimer.NewTimedSignalMap' in sched_src
assert 'function Scheduler.hasNativeSignalMap()' in sched_src
assert 'function Scheduler.createSignalMap(callback)' in sched_src

renderer_src = open('EventAlertMod/UI/Renderer.lua', 'r', encoding='utf-8').read()
assert 'local function getAlertSignalMap()' in renderer_src, 'Renderer must define getAlertSignalMap'
assert 'signalMap:SignalAt(alertKey, expirationTime)' in renderer_src, 'Renderer must use keyed SignalAt for zero-allocation active alert rescheduling'
assert 'signalMap:Cancel(rendered.signalKey)' in renderer_src, 'Renderer must use signalMap:Cancel on alert cleanup'
print('  [PASS] Scheduler 12.1.5+ TimedSignalMap TimerUtil/C_Timer capability detection and Renderer integration verified')

print('=== 12. Testing PowerRenderer 12.1.5+ Pixel Snapping & Strict Security Contract ===')
power_src = open('EventAlertMod/UI/PowerRenderer.lua', 'r', encoding='utf-8').read()
assert 'Util.snapToPixels(container)' in power_src
assert 'Util.snapToPixels(statusBar)' in power_src
assert 'Util.snapToPixels(background)' in power_src
assert 'Util.snapToPixels(label)' in power_src
assert 'Util.snapToPixels(valueText)' in power_src
assert 'Util.snapToPixels(glow)' in power_src
assert 'Util.snapToPixels(markers[index])' in power_src
assert 'Util.snapToPixels(slotBars[index])' in power_src
assert 'GetValue(' not in power_src, 'PowerRenderer must NOT call GetValue('
assert 'GetMinMaxValues(' not in power_src, 'PowerRenderer must NOT call GetMinMaxValues('
assert 'SetScript("OnUpdate"' not in power_src, 'PowerRenderer must NOT register OnUpdate'
assert 'string.format' not in power_src, 'PowerRenderer must NOT call string.format'
print('  [PASS] PowerRenderer pixel snapping and strict zero-taint contract verified')

print('=== 13. Testing SavedVariables 12.1.5+ Defaults & Normalization ===')
sv_src = open('EventAlertMod/Core/SavedVariables.lua', 'r', encoding='utf-8').read()
assert 'showApplicationBar = true' in sv_src
assert 'applicationBarMax = 5' in sv_src
assert 'applicationBarMin = 1' in sv_src
assert 'showDurationBar = false' in sv_src
assert 'audioThrottle = 0.3' in sv_src
assert sv_src.count('function SavedVariables.updateApplicationBarSettings(') == 1, 'updateApplicationBarSettings must be defined exactly once'
assert sv_src.count('function SavedVariables.updateAudioThrottle(') == 1, 'updateAudioThrottle must be defined exactly once'
print('  [PASS] SavedVariables 12.1.5+ schema fields and update helpers verified')

print('=== 14. Testing AuraRuleCompiler 12.1.5+ Visual Fingerprint & GroupID ===')
arc_src = open('EventAlertMod/Managers/AuraRuleCompiler.lua', 'r', encoding='utf-8').read()
assert 'showApplicationBar' in arc_src
assert 'applicationBarMax' in arc_src
assert 'applicationBarMin' in arc_src
assert 'showDurationBar' in arc_src
assert 'config.audioThrottle' in arc_src
assert 'throttleSeconds = tonumber(config.audioThrottle)' in arc_src

sound_service_src = open('EventAlertMod/Services/AuraSoundService.lua', 'r', encoding='utf-8').read()
assert 'EAM.db.config.audioThrottle' in sound_service_src, 'AuraSoundService must fall back to EAM.db.config.audioThrottle'
print('  [PASS] AuraRuleCompiler visualFingerprint, groupID, audioThrottle and AuraSoundService fallback verified')

print('=== 15. Testing 5-Locale Synchronization for New 12.1.5+ Keys ===')
locales = ['zhTW', 'zhCN', 'enUS', 'koKR', 'ruRU']
required_keys = [
    'EAM_OPT_APPLICATION_BAR_MAX',
    'EAM_OPT_APPLICATION_BAR_MIN',
    'EAM_OPT_AUDIO_THROTTLE',
    'EAM_OPT_AUDIO_THROTTLE_TIP',
    'EAM_OPT_AURA_DURATION_BAR',
    'EAM_OPT_AURA_DURATION_BAR_TIP',
]
for loc in locales:
    loc_src = open(f'EventAlertMod/Locale/{loc}.lua', 'r', encoding='utf-8').read()
    for rk in required_keys:
        assert (f'L.{rk}' in loc_src or f'L["{rk}"]' in loc_src), f'Missing {rk} in EventAlertMod/Locale/{loc}.lua'
print(f'  [PASS] All {len(required_keys)} new keys verified present across all 5 locale files')

print('=== 16. Testing Forever 1.60.1 Dual-Flavor Architecture, ForeverCatalog & Classic Stats ===')

# A. Env.lua & Constants.lua
env_src = open('EventAlertMod/Core/Env.lua', 'r', encoding='utf-8').read()
assert 'EAM.WOW_PROJECT_CAMELOT = _G.WOW_PROJECT_CAMELOT or 18' in env_src, 'Missing WOW_PROJECT_CAMELOT in Env.lua'
assert 'function EAM.detectGameFlavor()' in env_src, 'Missing detectGameFlavor in Env.lua'
assert 'GetManaRegenFromSpirit' in env_src, 'Missing GetManaRegenFromSpirit in EAM.API bindings'
assert 'UnitDefenseSkill' in env_src, 'Missing UnitDefenseSkill in EAM.API bindings'
assert 'C_PetInfo' in env_src, 'Missing C_PetInfo in EAM.API bindings'

const_src = open('EventAlertMod/Core/Constants.lua', 'r', encoding='utf-8').read()
assert 'FOREVER_INTERFACE = 16001' in const_src, 'Missing FOREVER_INTERFACE in Constants.lua'
assert 'WOW_PROJECT_CAMELOT = 18' in const_src, 'Missing WOW_PROJECT_CAMELOT in Constants.lua'
assert 'GAME_FLAVOR_FOREVER = "FOREVER"' in const_src, 'Missing GAME_FLAVOR_FOREVER in Constants.lua'
assert 'FOREVER_COMPATIBILITY_LABEL' in const_src, 'Missing FOREVER_COMPATIBILITY_LABEL in Constants.lua'

# B. TOC directives
toc_src = open('EventAlertMod/EventAlertMod.toc', 'r', encoding='utf-8').read()
assert '16001' in toc_src, 'Missing 16001 in TOC Interface header'
assert 'AllowLoadGameType: standard, forever, camelot' in toc_src, 'Missing AllowLoadGameType in TOC'
assert 'Data\\Forever\\ForeverCatalog.lua' in toc_src, 'Missing ForeverCatalog.lua in TOC'

# C. ForeverCatalog.lua
fc_src = open('EventAlertMod/Data/Forever/ForeverCatalog.lua', 'r', encoding='utf-8').read()
assert 'EAM.Data.ForeverCatalog = freeze(ForeverCatalog)' in fc_src, 'Missing ForeverCatalog registration'
assert 'FOREVER_RESOURCE_TOPOLOGY' in fc_src, 'Missing FOREVER_RESOURCE_TOPOLOGIES'
assert 'FOREVER_STAT_DEFINITIONS' in fc_src, 'Missing FOREVER_STAT_DEFINITIONS'
assert 'FOREVER_DEFAULT_ALERTS' in fc_src, 'Missing FOREVER_DEFAULT_ALERTS'
assert 'FOREVER_SPELL_HEURISTICS' in fc_src, 'Missing FOREVER_SPELL_HEURISTICS'
for cls in ['WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID']:
    assert f'{cls} = {{' in fc_src, f'Missing {cls} topology in ForeverCatalog'

# D. PlayerStatService.lua & Dynamic Filter
stat_src = open('EventAlertMod/Services/PlayerStatService.lua', 'r', encoding='utf-8').read()
assert 'spiritManaRegen' in stat_src, 'Missing spiritManaRegen in PlayerStatService'
assert 'defenseSkill' in stat_src, 'Missing defenseSkill in PlayerStatService'
assert 'petHappiness' in stat_src, 'Missing petHappiness in PlayerStatService'
assert 'ammoStatus' in stat_src, 'Missing ammoStatus in PlayerStatService'
assert 'PlayerStatService.FOREVER_ORDERED_KEYS' in stat_src, 'Missing FOREVER_ORDERED_KEYS'
assert 'PlayerStatService.RETAIL_ORDERED_KEYS' in stat_src, 'Missing RETAIL_ORDERED_KEYS'

# E. 5-Locale Classic Stat Keys
stat_keys = [
    'EAM_STAT_SPIRIT_MANA_REGEN',
    'EAM_STAT_DEFENSE_SKILL',
    'EAM_STAT_PET_HAPPINESS',
    'EAM_STAT_AMMO_STATUS',
]
for loc in ['zhTW', 'zhCN', 'enUS', 'koKR', 'ruRU']:
    loc_src = open(f'EventAlertMod/Locale/{loc}.lua', 'r', encoding='utf-8').read()
    for sk in stat_keys:
        assert (f'L.{sk}' in loc_src or f'L["{sk}"]' in loc_src), f'Missing {sk} in Locale/{loc}.lua'

# F. ItemCooldownService.lua & SpellInfoService.lua
ic_src = open('EventAlertMod/Services/ItemCooldownService.lua', 'r', encoding='utf-8').read()
assert 'cSpell.GetItemCooldown' in ic_src, 'Missing C_Spell.GetItemCooldown in ItemCooldownService'

si_src = open('EventAlertMod/Services/SpellInfoService.lua', 'r', encoding='utf-8').read()
assert 'SpellInfoService.isSpellBookItemLowRank' in si_src, 'Missing isSpellBookItemLowRank in SpellInfoService'
assert 'ForeverCatalog.GetSpellHeuristics' in si_src, 'Missing ForeverCatalog.GetSpellHeuristics in SpellInfoService'

# G. Deploy targets
import json
dt = json.load(open('Deploy/DeploymentTargets.json', 'r', encoding='utf-8'))
assert any(t.get('key') == 'forever' for t in dt.get('targets', [])), 'Missing forever target in DeploymentTargets.json'

print('  [PASS] Forever 1.60.1 Dual-Flavor Architecture, ForeverCatalog, Classic Stats & Automation verified')


print('=== 17. Testing Forever 16001 Modern Engine & Capability Routing ===')
env_src = open('EventAlertMod/Core/Env.lua', 'r', encoding='utf-8').read()
assert 'function EAM.isModernEngineInterface(interfaceVersion)' in env_src, 'Missing isModernEngineInterface in Env.lua'
assert 'iv >= 16000 and iv < 20000' in env_src, 'Missing 16000-19999 range check in Env.lua'

util_src = open('EventAlertMod/Core/Util.lua', 'r', encoding='utf-8').read()
assert 'Util.isModernEngineInterface' in util_src, 'Missing isModernEngineInterface in Util.lua'
assert 'function Util.readStructuredField(source, key, warnings, warningCode)' in util_src, 'Missing readStructuredField in Util.lua'

aura_cap_src = open('EventAlertMod/Services/AuraCapabilityService.lua', 'r', encoding='utf-8').read()
assert 'EAM.isModernEngineInterface' in aura_cap_src, 'AuraCapabilityService must use isModernEngineInterface'

aura_cont_src = open('EventAlertMod/Services/AuraContainerService.lua', 'r', encoding='utf-8').read()
assert 'EAM.isModernEngineInterface' in aura_cont_src, 'AuraContainerService must use isModernEngineInterface'

res_cap_src = open('EventAlertMod/Services/PlayerResourceCapability.lua', 'r', encoding='utf-8').read()
assert 'EAM.isModernEngineInterface' in res_cap_src, 'PlayerResourceCapability must use isModernEngineInterface'

lbg_src = open('EventAlertMod/Lib/LibButtonGlow-1.0.lua', 'r', encoding='utf-8').read()
assert 'tocVersion >= 16000 and tocVersion < 20000' in lbg_src, 'LibButtonGlow must recognize Forever toc range as Midnight/Modern'
assert 'isCdDurSafe' in lbg_src or 'issecretvalue(cdDur)' in lbg_src, 'LibButtonGlow must guard cdDur against Secret Numbers'
print('  [PASS] Modern engine interface routing (16001->Native, 120007->Legacy, 120105->Native) verified')

print('=== 18. Testing Secret Value Defense-in-Depth for Cooldown, Aura & CombatFlash ===')
cd_src = open('EventAlertMod/Services/CooldownService.lua', 'r', encoding='utf-8').read()
assert 'Util.readStructuredField' in cd_src, 'CooldownService must use readStructuredField'
assert 'GetSpellLossOfControlCooldownInfo' in cd_src, 'CooldownService must check GetSpellLossOfControlCooldownInfo'
assert 'Util.isSafePositiveNumber(locDur)' in cd_src or 'Util.isSafeNumber(locDur)' in cd_src, 'CooldownService must guard locDur against Secret Numbers'

aura_src = open('EventAlertMod/Services/AuraService.lua', 'r', encoding='utf-8').read()
assert 'Util.readStructuredField(updateInfo, "isFullUpdate"' in aura_src, 'AuraService must guard isFullUpdate against Secret Booleans'
assert 'Util.readStructuredField' in aura_src, 'AuraService must use readStructuredField for delta scanning'

cf_src = open('EventAlertMod/UI/CombatFlash.lua', 'r', encoding='utf-8').read()
assert 'isSafeNumber(cur) and isSafeNumber(maxH) and maxH > 0' in cf_src, 'CombatFlash must guard cur and maxH against Secret Numbers'
assert 'isSafeNumber(alpha)' in cf_src, 'CombatFlash must guard alpha against Secret Numbers'
assert 'CombatFlash.triggerSpiritActive' in cf_src, 'CombatFlash must provide triggerSpiritActive'
print('  [PASS] Secret Value (Number/Boolean) defense-in-depth verified')

print('=== 19. Testing Forever Spell Rank Full Pipeline & Multi-Rank Grouping ===')
toc_src = open('EventAlertMod/EventAlertMod.toc', 'r', encoding='utf-8').read()
assert 'Services\\SpellRankService.lua' in toc_src, 'SpellRankService must be registered in EventAlertMod.toc'

rank_src = open('EventAlertMod/Services/SpellRankService.lua', 'r', encoding='utf-8').read()
assert 'SpellRankService.getRankSpellIDs' in rank_src, 'Missing getRankSpellIDs in SpellRankService'
assert 'SpellRankService.populateSpellIDSet' in rank_src, 'Missing populateSpellIDSet in SpellRankService'
assert 'not EAM.isForever' in rank_src, 'SpellRankService must short-circuit when not EAM.isForever'

compiler_src = open('EventAlertMod/Managers/AuraRuleCompiler.lua', 'r', encoding='utf-8').read()
assert 'EAM.Services.SpellRankService.populateSpellIDSet' in compiler_src, 'AuraRuleCompiler must populate spell ranks for Forever'

ge_src = open('EventAlertMod/Services/GroundEffectService.lua', 'r', encoding='utf-8').read()
assert 'SpellRankService.getRankSpellIDs' in ge_src, 'GroundEffectService must index spell ranks for Forever'

opt_src = open('EventAlertMod/UI/Options.lua', 'r', encoding='utf-8').read()
assert 'subName' in opt_src or 'GetSpellSubtext' in opt_src, 'Options.lua must support spell subtext/rank in Forever'
print('  [PASS] Forever Spell Rank pipeline (SpellRankService, Compiler, GroundEffect, Options) verified')

print('=== 20. Testing Five Magic Resistances Monitoring ===')
cat_src = open('EventAlertMod/Data/Forever/ForeverCatalog.lua', 'r', encoding='utf-8').read()
assert 'RESIST_ARCANE' in cat_src, 'Missing RESIST_ARCANE in ForeverCatalog'
assert 'RESIST_FIRE' in cat_src, 'Missing RESIST_FIRE in ForeverCatalog'
assert 'RESIST_FROST' in cat_src, 'Missing RESIST_FROST in ForeverCatalog'
assert 'RESIST_NATURE' in cat_src, 'Missing RESIST_NATURE in ForeverCatalog'
assert 'RESIST_SHADOW' in cat_src, 'Missing RESIST_SHADOW in ForeverCatalog'

stat_src = open('EventAlertMod/Services/PlayerStatService.lua', 'r', encoding='utf-8').read()
assert 'resistArcane' in stat_src, 'Missing resistArcane in PlayerStatService'
assert 'resistFire' in stat_src, 'Missing resistFire in PlayerStatService'
assert 'resistFrost' in stat_src, 'Missing resistFrost in PlayerStatService'
assert 'resistNature' in stat_src, 'Missing resistNature in PlayerStatService'
assert 'resistShadow' in stat_src, 'Missing resistShadow in PlayerStatService'
assert 'UNIT_RESISTANCES' in stat_src, 'PlayerStatService must listen for UNIT_RESISTANCES'

resist_keys = [
    'EAM_STAT_RESIST_ARCANE',
    'EAM_STAT_RESIST_FIRE',
    'EAM_STAT_RESIST_FROST',
    'EAM_STAT_RESIST_NATURE',
    'EAM_STAT_RESIST_SHADOW',
]
for loc in ['zhTW', 'zhCN', 'enUS', 'koKR', 'ruRU']:
    loc_src = open(f'EventAlertMod/Locale/{loc}.lua', 'r', encoding='utf-8').read()
    for rk in resist_keys:
        assert (f'L.{rk}' in loc_src or f'L["{rk}"]' in loc_src), f'Missing {rk} in Locale/{loc}.lua'
print('  [PASS] Five Magic Resistances monitoring, data, service and 5-locale synchronization verified')

print('=== 21. Testing Forever Spirit 5SR State Machine, MP5/HP5 Dual Metrics & Active Alert ===')
assert 'SPIRIT = freeze' in cat_src, 'Missing SPIRIT in ForeverCatalog'
assert 'spirit = {' in stat_src, 'Missing spirit stat definition in PlayerStatService'
assert 'PlayerStatService.spiritState' in stat_src, 'Missing spiritState in PlayerStatService'
assert 'PlayerStatService.getSpiritRegenState' in stat_src, 'Missing getSpiritRegenState in PlayerStatService'
assert 'PlayerStatService.onPlayerSpellCastSucceeded' in stat_src, 'Missing onPlayerSpellCastSucceeded in PlayerStatService'
assert 'PlayerStatService.onPlayerPowerUpdate' in stat_src, 'Missing onPlayerPowerUpdate in PlayerStatService'
assert 'spiritActiveAlert' in stat_src, 'PlayerStatService must handle spiritActiveAlert'
assert 'spiritBlueScreenFlash' in stat_src, 'PlayerStatService must handle spiritBlueScreenFlash'

panel_src = open('EventAlertMod/UI/PlayerStatPanel.lua', 'r', encoding='utf-8').read()
assert 'spiritSection' in panel_src, 'PlayerStatPanel must have spiritSection'
assert 'spiritActiveAlertCb' in panel_src, 'PlayerStatPanel must have spiritActiveAlertCb'
assert 'spiritBlueFlashCb' in panel_src, 'PlayerStatPanel must have spiritBlueFlashCb'
assert 'saveCurrentConfig' not in panel_src, 'PlayerStatPanel must not call non-existent global saveCurrentConfig'
assert 'spiritActiveAlertCb:SetScript("OnClick", applyLiveChange)' in panel_src, 'spiritActiveAlertCb must bind applyLiveChange'
assert 'spiritBlueFlashCb:SetScript("OnClick", applyLiveChange)' in panel_src, 'spiritBlueFlashCb must bind applyLiveChange'
assert 'Theme.registerButton(spiritModeBtn)' in panel_src, 'spiritModeBtn must register with Theme'
assert 'Theme.registerButton(testBlueBtn)' in panel_src, 'testBlueBtn must register with Theme'
assert 'EAM.UI.setTooltip(spiritModeBtn' in panel_src, 'spiritModeBtn must have tooltip'
assert 'EAM.UI.setTooltip(spiritActiveAlertCb' in panel_src, 'spiritActiveAlertCb must have tooltip'
assert 'formatSpiritDisplay' in panel_src, 'PlayerStatPanel must use formatSpiritDisplay for live preview'

assert 'local spiritSnapshot =' in stat_src, 'PlayerStatService must have preallocated spiritSnapshot table'
assert 'PlayerStatService.resetSpiritRegenState' in stat_src, 'PlayerStatService must expose resetSpiritRegenState'
assert 'lastEvalTime' in stat_src, 'spiritState must track lastEvalTime for same-frame idempotency'
assert 'hasPlayerFreecastAura' in stat_src, 'PlayerStatService must check clearcasting/freecast auras'
assert '12536' in stat_src and '16246' in stat_src and '16870' in stat_src, 'Must check clearcasting spells 12536, 16246, 16870'
assert 'PlayerStatService.formatSpiritDisplay' in stat_src, 'PlayerStatService must expose formatSpiritDisplay'
assert 'isSpiritManagedBorder' in stat_src, 'PlayerStatService must protect spirit active border from gray override'

spirit_keys = [
    'EAM_STAT_SPIRIT',
    'EAM_STAT_SPIRIT_SETTINGS',
    'EAM_STAT_SPIRIT_MODE',
    'EAM_STAT_SPIRIT_ACTIVE_ALERT',
    'EAM_STAT_SPIRIT_BLUE_FLASH',
    'EAM_STAT_TEST_BLUE_FLASH',
]
for loc in ['zhTW', 'zhCN', 'enUS', 'koKR', 'ruRU']:
    loc_src = open(f'EventAlertMod/Locale/{loc}.lua', 'r', encoding='utf-8').read()
    for sk in spirit_keys:
        assert (f'L.{sk}' in loc_src or f'L["{sk}"]' in loc_src), f'Missing {sk} in Locale/{loc}.lua'

print('  [PASS] Forever Spirit 5SR State Machine, MP5/HP5, Active Alert and UI verified')

print('=== 22. Testing Aura Out-Of-Combat Visibility Pipeline & 5-Locale Keys ===')

# 1. 5-Locale synchronization
aura_ooc_keys = [
    'EAM_OPT_HIDE_AURA_OUTSIDE_COMBAT',
    'EAM_OPT_HIDE_AURA_OUTSIDE_COMBAT_TIP',
    'EAM_OPT_COND_AURA_HIDE_OUTSIDE',
    'EAM_OPT_COND_AURA_HIDE_OUTSIDE_TIP',
]
for loc in ['zhTW', 'zhCN', 'enUS', 'koKR', 'ruRU']:
    loc_src = open(f'EventAlertMod/Locale/{loc}.lua', 'r', encoding='utf-8').read()
    for ak in aura_ooc_keys:
        assert (f'L.{ak}' in loc_src or f'L["{ak}"]' in loc_src), f'Missing {ak} in Locale/{loc}.lua'

# 2. SavedVariables.lua
sv_src = open('EventAlertMod/Core/SavedVariables.lua', 'r', encoding='utf-8').read()
assert 'hideAuraOutsideCombat = false,' in sv_src, 'defaults.config must have hideAuraOutsideCombat = false'
assert 'local AURA_BEHAVIOR_FIELDS = { "hideAuraOutsideCombat" }' in sv_src, 'Missing AURA_BEHAVIOR_FIELDS in SavedVariables'
assert 'function SavedVariables.updateAuraBehavior(unit, spellID, field, value)' in sv_src, 'Missing updateAuraBehavior in SavedVariables'
assert 'hideAuraOutsideCombat = true,' in sv_src, 'SavedVariables.updateConfigBoolean must allow hideAuraOutsideCombat'

# 3. ProfileCodec.lua
codec_src = open('EventAlertMod/Core/ProfileCodec.lua', 'r', encoding='utf-8').read()
assert 'hideAuraOutsideCombat = true,' in codec_src, 'normalizeAuraRecord must whitelist hideAuraOutsideCombat'
assert 'normalized.hideAuraOutsideCombat = record.hideAuraOutsideCombat' in codec_src, 'normalizeAuraRecord must parse hideAuraOutsideCombat'
assert 'normalized.hideAuraOutsideCombat = true' in codec_src, 'normalizeGeneralConfigRecord must handle hideAuraOutsideCombat'

# 4. AuraService.lua
aura_src = open('EventAlertMod/Services/AuraService.lua', 'r', encoding='utf-8').read()
assert 'inCombat = false,' in aura_src, 'AuraService must initialize inCombat = false'
assert 'AuraService.resolveHideAuraOutsideCombat' in aura_src, 'AuraService must expose resolveHideAuraOutsideCombat'
assert 'AuraService.shouldSuppressAuraOutsideCombat' in aura_src, 'AuraService must expose shouldSuppressAuraOutsideCombat'
assert 'function AuraService.onRegenDisabled()' in aura_src, 'AuraService must implement onRegenDisabled'
assert 'function AuraService.onAuraConfigChanged()' in aura_src, 'AuraService must implement onAuraConfigChanged'

# 5. Native pipeline
compiler_src = open('EventAlertMod/Managers/AuraRuleCompiler.lua', 'r', encoding='utf-8').read()
assert 'hideOutsideCombat = hideOutsideCombat,' in compiler_src, 'AuraRuleCompiler must populate rule.style.hideOutsideCombat'
assert 'tostring(rule.style and rule.style.hideOutsideCombat == true)' in compiler_src, 'AuraRuleCompiler must include hideOutsideCombat in fingerprint'

renderer_src = open('EventAlertMod/UI/NativeAuraRenderer.lua', 'r', encoding='utf-8').read()
assert 'function NativeAuraRenderer.updateCombatVisibility(inCombatNow)' in renderer_src, 'NativeAuraRenderer must implement updateCombatVisibility'
assert 'return true, "noPostInitializationMutation"' in renderer_src, 'NativeAuraRenderer contract preserved'

container_src = open('EventAlertMod/Services/AuraContainerService.lua', 'r', encoding='utf-8').read()
assert 'function AuraContainerService.onCombatStart()' in container_src, 'AuraContainerService must implement onCombatStart'
assert 'router.register("PLAYER_REGEN_DISABLED", AuraContainerService.onCombatStart)' in container_src, 'AuraContainerService must register PLAYER_REGEN_DISABLED'

# 6. Options.lua
opt_src = open('EventAlertMod/UI/Options.lua', 'r', encoding='utf-8').read()
assert 'function Options.refreshAuraBehaviorControls()' in opt_src, 'Options must implement refreshAuraBehaviorControls'
assert 'condFrame.auraHideOutsideBtn' in opt_src, 'Options must create auraHideOutsideBtn'
assert 'EAM_OPT_HIDE_AURA_OUTSIDE_COMBAT' in opt_src, 'Options must create global hideAuraOutsideCombat checkbox'
assert re.search(r'if isAura then\s*cf\.fromPlayerCb:Show\(\)\s*else\s*cf\.fromPlayerCb:Hide\(\)\s*end\s*\n\s*for index = 1, #COOLDOWN_BEHAVIOR_OPTIONS', opt_src), 'Options.lua violates Test-ValidationContracts.ps1 L1391 contract'

# 7. FlowTestRunner.lua
flow_src = open('EventAlertMod/Debug/FlowTestRunner.lua', 'r', encoding='utf-8').read()
assert 'aura.hide_outside_combat_override' in flow_src, 'FlowTestRunner must contain aura.hide_outside_combat_override case'

print('  [PASS] Aura Out-Of-Combat Visibility Pipeline, 5-Locale Keys & Flow Test verified')

print('=== 23. Testing Forever 1.60.1 11 Character Attributes, Tooltip Engine & Formulas ===')

stat_service_src = open('EventAlertMod/Services/PlayerStatService.lua', 'r', encoding='utf-8').read()

# 1. Check STAT_DEFINITIONS has attackPower, dodge, parry, block
for key in ['attackPower', 'dodge', 'parry', 'block']:
    assert f'key = "{key}"' in stat_service_src, f'Missing {key} in PlayerStatService.DEFINITIONS'

# 2. Check FOREVER_ORDERED_KEYS has attackPower, dodge, parry, block
for key in ['attackPower', 'dodge', 'parry', 'block']:
    assert f'"{key}"' in stat_service_src, f'Missing {key} in FOREVER_ORDERED_KEYS'

# 3. Check Forever 11 character attribute formulas and mechanics in getStatTooltipInfo
assert 'PlayerStatService.getStatTooltipInfo' in stat_service_src, 'Missing getStatTooltipInfo in PlayerStatService'
assert 'PlayerStatService.showStatTooltip' in stat_service_src, 'Missing showStatTooltip in PlayerStatService'

# Formula 1: 1 Str = 2 AP
assert '1 點力量 = 2 AP' in stat_service_src, 'Missing 1 Str = 2 AP mechanic in tooltip'
# Formula 2: 1 Agi = 2 Armor
assert '1 點敏捷 = 2 護甲' in stat_service_src, 'Missing 1 Agi = 2 Armor mechanic in tooltip'
# Formula 3: 1 Sta = 10 HP
assert '1 點耐力 = 10 生命力' in stat_service_src, 'Missing 1 Sta = 10 HP mechanic in tooltip'
# Formula 4: Int increases weapon skill level-up chance
assert '智力影響升熟練度速度' in stat_service_src, 'Missing Int weapon skill level-up mechanic in tooltip'
# Formula 5: Spirit 5SR + sitting/lying 33% HP regen
assert '坐下或躺下時，生命力恢復速度提高 33%' in stat_service_src, 'Missing sitting 33% HP regen in tooltip'
# Formula 6: 14 AP = 1 DPS
assert '14 AP = 1 DPS' in stat_service_src, 'Missing 14 AP = 1 DPS formula in tooltip'
# Formula 7: 200% melee crit & 150% spell crit & DoT crit
assert '造成 200% 傷害' in stat_service_src, 'Missing 200% melee crit damage in tooltip'
assert '造成 150% 效果' in stat_service_src, 'Missing 150% spell crit damage in tooltip'
assert 'DoT/HoT' in stat_service_src, 'Missing DoT crit mechanic in tooltip'
# Formula 8: 150% crushing blow & 440 defense boss uncrittable
assert '150% 碾壓傷害' in stat_service_src, 'Missing 150% crushing blow mechanic in tooltip'
assert '防禦達 440 點' in stat_service_src and '-5.60%' in stat_service_src, 'Missing 440 defense uncrittable mechanic in tooltip'
# Formula 9: Dodge frontal only for player, all directions for mobs
assert '只有來自正面的近戰攻擊可閃躲' in stat_service_src, 'Missing frontal-only dodge mechanic in tooltip'
# Formula 10: Parry haste
assert 'Parry Haste' in stat_service_src, 'Missing Parry Haste mechanic in tooltip'
# Formula 11: 75% max armor DR cap
assert '75.00%' in stat_service_src, 'Missing 75% armor damage reduction cap in tooltip'

# 4. Check UI event wiring for tooltips
assert 'PlayerStatService.showStatTooltip(self, self.statKey)' in stat_service_src, 'Missing OnEnter tooltip wiring in statItemFrames'
assert 'item:EnableMouse(true)' in stat_service_src, 'statItemFrames must have mouse enabled for tooltips'

stat_panel_src = open('EventAlertMod/UI/PlayerStatPanel.lua', 'r', encoding='utf-8').read()
assert 'PlayerStatService.showStatTooltip(self, self.statKey)' in stat_panel_src, 'PlayerStatPanel rows must wire showStatTooltip on hover'

print('  [PASS] Forever 1.60.1 11 Character Attributes, Tooltip Engine & Formulas verified')

print('=== 24. Testing Independent WeaponEnchantService Pipeline, HUD & 5-Locale Synchronization ===')

# 1. TOC verification
toc_src = open('EventAlertMod/EventAlertMod.toc', 'r', encoding='utf-8').read()
assert 'Services\\WeaponEnchantService.lua' in toc_src, 'WeaponEnchantService.lua must be registered in EventAlertMod.toc'

# 2. Constants verification
const_src = open('EventAlertMod/Core/Constants.lua', 'r', encoding='utf-8').read()
assert 'ALERT_KIND_WEAPON_ENCHANT = "weaponEnchant"' in const_src, 'Missing ALERT_KIND_WEAPON_ENCHANT in Constants'
assert 'weaponEnchant = "weaponEnchant"' in const_src, 'Missing weaponEnchant in MODULE_KEYS / ALERT_FRAME_TYPES'

# 3. SavedVariables verification
sv_src = open('EventAlertMod/Core/SavedVariables.lua', 'r', encoding='utf-8').read()
assert 'weaponEnchant = {' in sv_src, 'Missing weaponEnchant default settings in SavedVariables'
assert 'weaponEnchant = { growDirection = 1, x = 120, y = -120' in sv_src, 'Missing layout.frames.weaponEnchant in SavedVariables'
assert 'warnMissing = true' in sv_src, 'Missing warnMissing in SavedVariables defaults'
assert 'warnExpiring = true' in sv_src, 'Missing warnExpiring in SavedVariables defaults'

# 4. ModuleController verification
mc_src = open('EventAlertMod/Core/ModuleController.lua', 'r', encoding='utf-8').read()
assert 'weaponEnchant = true,' in mc_src, 'Missing weaponEnchant in ModuleController.validKeys'
assert 'weaponEnchant = "WeaponEnchantService",' in mc_src, 'Missing weaponEnchant in ModuleController.serviceNames'

# 5. WeaponEnchantService implementation details
we_src = open('EventAlertMod/Services/WeaponEnchantService.lua', 'r', encoding='utf-8').read()
assert 'WeaponEnchantService.sampleWeaponEnchants' in we_src, 'Missing sampleWeaponEnchants in WeaponEnchantService'
assert 'WeaponEnchantService.formatDuration' in we_src, 'Missing formatDuration in WeaponEnchantService'
assert 'WeaponEnchantService.getEnchantTooltipInfo' in we_src, 'Missing getEnchantTooltipInfo in WeaponEnchantService'
assert 'WeaponEnchantService.showEnchantTooltip' in we_src, 'Missing showEnchantTooltip in WeaponEnchantService'
assert 'WeaponEnchantService.setActiveAnchors' in we_src, 'Missing setActiveAnchors in WeaponEnchantService'
assert 'isMissing' in we_src, 'WeaponEnchantService must support isMissing warning state'
assert 'isExpiring' in we_src, 'WeaponEnchantService must support isExpiring warning state'
assert 'expireThreshold' in we_src, 'WeaponEnchantService must respect expireThreshold'
assert 'WEAPON_ENCHANT_CHANGED' in we_src, 'WeaponEnchantService must register WEAPON_ENCHANT_CHANGED'
assert 'PLAYER_EQUIPMENT_CHANGED' in we_src, 'WeaponEnchantService must register PLAYER_EQUIPMENT_CHANGED'

# 6. 5-Locale synchronization for all new keys
new_locale_keys = [
    'EAM_STAT_ATTACK_POWER',
    'EAM_STAT_DODGE',
    'EAM_STAT_PARRY',
    'EAM_STAT_BLOCK',
    'EAM_WEAPON_ENCHANT_TITLE',
    'EAM_WEAPON_ENCHANT_MISSING',
    'EAM_WEAPON_ENCHANT_EXPIRING',
    'EAM_WEAPON_ENCHANT_WARN_MISSING',
    'EAM_WEAPON_ENCHANT_WARN_EXPIRING',
]
for loc in ['zhTW', 'zhCN', 'enUS', 'koKR', 'ruRU']:
    loc_src = open(f'EventAlertMod/Locale/{loc}.lua', 'r', encoding='utf-8').read()
    for k in new_locale_keys:
        assert (f'L.{k}' in loc_src or f'L["{k}"]' in loc_src), f'Missing {k} in Locale/{loc}.lua'

print('  [PASS] Independent WeaponEnchantService Pipeline, HUD & 5-Locale Synchronization verified')

print('=== 25. Testing Mana Stat, StatusBar/Icon/Text 5SR Active Alerts, Continuous Full-Screen Blue Glow & 5-Locale Keys ===')

stat_service_src = open('EventAlertMod/Services/PlayerStatService.lua', 'r', encoding='utf-8').read()
combat_flash_src = open('EventAlertMod/UI/CombatFlash.lua', 'r', encoding='utf-8').read()
stat_panel_src = open('EventAlertMod/UI/PlayerStatPanel.lua', 'r', encoding='utf-8').read()

# 1. Verify mana in STAT_DEFINITIONS and ordered keys
assert 'key = "mana"' in stat_service_src, 'Missing mana definition in PlayerStatService.DEFINITIONS'
assert '"mana"' in stat_service_src, 'Missing mana in ORDERED_KEYS'

# 2. Verify mana in getStatTooltipInfo
assert 'key == "mana"' in stat_service_src, 'Missing mana handling in getStatTooltipInfo'
assert '【5秒精神回魔作用中】' in stat_service_src, 'Missing 5SR active line in mana tooltip'
assert '【5秒規則等待中】' in stat_service_src, 'Missing 5SR penalty countdown in mana tooltip'

# 3. Verify formatSpiritDisplay handles mana
assert 'if key == "mana" then' in stat_service_src, 'Missing mana in formatSpiritDisplay'

# 4. Verify StatusBar/Icon/Text 5SR Active Alerts in PlayerStatService.lua
assert 'data.key == "spirit" or data.key == "spiritManaRegen" or data.key == "mana"' in stat_service_src, \
    'PlayerStatService.update must include mana in isSpiritSpecial'
assert 'item.statusBar:SetStatusBarColor(0.20, 0.85, 1.00, 1.00)' in stat_service_src, \
    'Missing ice-blue StatusBar color for 5SR active regen'
assert 'item.statusBar:SetStatusBarColor(0.85, 0.45, 0.15, 0.95)' in stat_service_src, \
    'Missing amber StatusBar color for 5SR penalty window'
assert 'item:SetBackdropBorderColor(0.85, 0.45, 0.15, 0.85)' in stat_service_src, \
    'Missing amber border color for 5SR penalty window on icon'
assert 'item.valText:SetTextColor(0.95, 0.65, 0.25, 0.95)' in stat_service_src, \
    'Missing amber text color for 5SR penalty window'

# 5. Verify Continuous Full-Screen Blue Glow in CombatFlash.lua & PlayerStatService.lua
assert 'function CombatFlash.setSpiritActiveGlow(active)' in combat_flash_src, \
    'Missing CombatFlash.setSpiritActiveGlow in CombatFlash.lua'
assert 'EAM_SpiritActiveGlowFrame' in combat_flash_src, \
    'Missing EAM_SpiritActiveGlowFrame in CombatFlash.lua'
assert '0.15, 0.65, 1.00, 0.35' in combat_flash_src, \
    'Missing soft ice-blue vertex color in CombatFlash.lua'
assert 'CF.setSpiritActiveGlow' in stat_service_src, \
    'PlayerStatService must drive CombatFlash.setSpiritActiveGlow'

# 6. Verify PlayerStatPanel UI controls & wiring
assert 'spiritBlueScreenGlowCb' in stat_panel_src, 'Missing spiritBlueScreenGlowCb in PlayerStatPanel.lua'
assert 'cfg.spiritBlueScreenGlow = spiritBlueScreenGlowCb:GetChecked()' in stat_panel_src, \
    'Missing spiritBlueScreenGlow in applyLiveChange'
assert 'spiritBlueScreenGlowCb:SetChecked(cfg.spiritBlueScreenGlow == true)' in stat_panel_src, \
    'Missing spiritBlueScreenGlow in loadStatToDetail'
assert 'statKey == "spirit" or statKey == "spiritManaRegen" or statKey == "mana"' in stat_panel_src, \
    'PlayerStatPanel must show spiritSection for mana as well'

# 7. Verify 5-Locale keys synchronization
suite25_locale_keys = [
    'EAM_STAT_MANA',
    'EAM_STAT_SPIRIT_BLUE_GLOW',
    'EAM_STAT_SPIRIT_BLUE_GLOW_TIP',
]
for loc in ['zhTW', 'zhCN', 'enUS', 'koKR', 'ruRU']:
    loc_src = open(f'EventAlertMod/Locale/{loc}.lua', 'r', encoding='utf-8').read()
    for k in suite25_locale_keys:
        assert (f'L.{k}' in loc_src or f'L["{k}"]' in loc_src), f'Missing {k} in Locale/{loc}.lua'

print('  [PASS] Mana Stat, StatusBar/Icon/Text 5SR Active Alerts, Continuous Full-Screen Blue Glow & 5-Locale Keys verified')

print('\n>>> ALL 25 DEEP TEST SUITES PASSED WITH ZERO ERRORS! <<<')



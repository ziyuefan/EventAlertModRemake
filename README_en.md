# EventAlertMod Retail 12.1 (EAM)

[![GitHub](https://img.shields.io/badge/source-GitHub-181717)](https://github.com/ziyuefan/EventAlertModRemake)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blueviolet)](https://ziyuefan.github.io/EventAlertModRemake/)
[![Release](https://img.shields.io/badge/release-Alpha%208.4-orange)](https://github.com/ziyuefan/EventAlertModRemake/releases)
[![Retail](https://img.shields.io/badge/WoW-Retail%2012.1-blue)](https://github.com/ziyuefan/EventAlertModRemake)
[![Interface](https://img.shields.io/badge/Interface-120007%20%7C%20120100-brightgreen)](https://github.com/ziyuefan/EventAlertModRemake)

> 🚀 **Ultra-lightweight, zero-taint, pure event-driven spell monitoring and combat alert AddOn built specifically for World of Warcraft: Retail (12.1.0 / 12.0+)!**
>
> 🌐 **Official Online Documentation & Navigation Hub**: [https://ziyuefan.github.io/EventAlertModRemake/](https://ziyuefan.github.io/EventAlertModRemake/)

---

## 🌟 Why Choose Modern EventAlertMod (EAM)? (Four Core Architectural Advantages)

| Traditional Spell Alerts / Heavy AddOns | Modern Remake EventAlertMod (EAM) |
| :--- | :--- |
| ⚠️ **Heavy resource drain**: Massive background OnUpdate polling, high memory consumption, combat frame drops. | ⚡ **Ultra-lightweight & zero burden**: Pure event-driven architecture with zero-allocation State Pools, eliminating GC memory spikes. |
| ❌ **Vulnerable to combat taint**: 12.0+ Secret Values frequently cause yellow Lua errors or broken frames in combat. | 🛡️ **Blizzard 12.0+ Secret Protection**: Direct native C-Level `StatusBar:SetValue` throughput, 100% immune to Lua taint. |
| 🔄 **Tedious setup & string imports**: Requires searching online for WeakAura strings or complex custom scripting. | 🎯 **Intuitive one-second monitor**: Hover over any spell, aura, or item and press **`Ctrl + Alt`** to instantly add to monitor. |
| 🐢 **Inaccurate flight speed**: Traditional addons fail to read 10.0+ / 11.0+ / 12.0+ Dragonriding dynamic gliding velocity. | 🏃 **Industry-first 4-in-1 Velocity**: Dedicated integration with `C_PlayerInfo.GetGlidingInfo()` supporting **830%~1400%** dynamic speed! |

---

## ✨ 8 Independent Alert Modules

EAM features 8 completely decoupled, independently positioned, and freely draggable alert modules:

1. 🔮 **Player Buff / Debuff**: Self buffs & debuffs with stack counts, remaining shield absorb amount, and high-precision timers.
2. 🎯 **Target Buff / Debuff**: Precise tracking of target auras, CC, and debuff states.
3. ⚔️ **Cross-Class / Target Cast**: Key enemy burst cooldowns and crucial friendly buffs.
4. ⏳ **Spell Cooldown**: Zero-Alpha (Alpha=0) persistent pre-anchored mode with 0.00ms layout latency; supports Radial Ring Mode & outer linear bars (`TOP/BOTTOM/LEFT/RIGHT`), custom reordering (drag & drop, up/down), and desaturated placeholder masks.
5. 🎒 **Item Cooldown**: Trinkets, on-use equipment, and consumables monitoring.
6. 🌋 **Ground Effect**: Aura-less ground AoE spells (Death and Decay, Defile, Frozen Orb, Anti-Magic Zone) with Base/Override talent family matching.
7. ⚡ **Player Resource**: All 13 classes, 40 specs, and 17 resource types (Mana, Rage, Energy, Combo Points, Chi, Insanity, Runic Power, Arcane Charges, Soul Shards, Holy Power, Essence, etc.).
8. 📊 **Player Stats & Absorbs**: Per-class customizable profiles with 18 core stats (Primary, Secondary, 4-in-1 Speeds, Armor, Total Shield Absorbs, and Heal Absorbs).

---

## 🎨 Modern Visuals & Streamlined Experience

- 📖 **Next-Gen Master Spell Catalog & Intelligent Presets**: Built-in 5-language offline database (4,463 core spells & 466 auras) with collapsible spec trees, one-click talent book auto-sync, target module redirection (cooldowns/auras/ground), and native GameTooltip hovering.
- 🏷️ **Multi-dimensional Tactical Groups & Tag Management**: Many-to-many tag associations, 4 built-in tactical groups (Burst, Mitigation, CC/Interrupt, Ground AoE) + custom groups, secondary docking manager panel, combat-only filters, and multi-select group dropdown in spell conditions.
- 🎵 **Full LibSharedMedia-3.0 (SharedMedia) Ecosystem Integration**: Dynamic runtime discovery of third-party sounds, fonts, and borders (`ensureLSM`), adaptive scrollable dropdowns with mouse wheel support, and zero-delay global font hot-swapping (no `/reload` needed).
- 🐮 **Classic Cow Head Anchor Preview**: Displays classic cow head icons (`Spell_Nature_Polymorph_Cow`) to preview all 8 alert frame positions during layout configuration.
- 🖼️ **Custom Icon Override Across All Modules**: Enter any official FileDataID (e.g. `132307`) or texture path to override default icons, with live texture preview box and Wago.tools lookup reference.
- 💀 **Death Knight Runes Dashboard**: Dynamic spec-specific rune textures with 6 micro charge bars (0%..100% smooth animation) and `/eam rune` slot diagnostics.
- ⚡ **60fps Real-Time Live Preview**: Adjust sizes, spacing, opacity, cooldown swipes, text sizes, and positions with immediate 60fps dynamic UI response out of combat.
- 💬 **Comprehensive Hover Tooltips**: Intuitive, clear tooltips on all buttons, checkboxes, sliders, edit boxes, and menus.
- 🎨 **11 Themed Visual Styles**: Warcraft Classic (default), Borland Blue/Yellow, DOS CRT Retro Green, Obsidian Black, Cyberpunk, and more.
- 🚨 **In-Combat Fullscreen Red Edge Flash**: Fullscreen combat entry and low-health warning flash animations with instant preview button.
- 📦 **Cross-Character Profile Sharing**: Export and import settings across 8 selective categories using standard EAMAP1 Base64/JSON strings with strict whitelist validation.
- 🌐 **Comprehensive Multi-Language Support**: Traditional Chinese (`zhTW`), Simplified Chinese (`zhCN`), English (`enUS`), Korean (`koKR`), and Russian (`ruRU`).

---

## 📸 Feature & UI Showcase

### 1. Main Options & System Preferences

| Main Options Panel | Module Toggles | About Panel |
| :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/01_%E4%B8%BB%E8%A8%AD%E5%AE%9A%E9%9D%A2%E6%9D%BF_MainOptions.jpg" width="100%" alt="EAM Main Options" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/02_%E5%8A%9F%E8%83%BD%E6%A8%A1%E7%B5%84%E9%96%8B%E9%97%9C_ModuleOptions.jpg" width="100%" alt="Module Toggles" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/03_%E9%97%9C%E6%96%BC%E6%8F%92%E4%BB%B6%E8%B3%87%E8%A8%8A_AboutPanel.jpg" width="100%" alt="About Panel" /> |
| Theme/Sound/Locale menus, Aura backend switch & global options | Independent event listener toggles for 8 modules | Version info, author, API baseline (12.1.0 PTR), and project links |

| 11 Theme Styles | 12 Classic Sound Effects | 5 Locales (Auto Detect) |
| :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/04_%E4%B8%BB%E9%A1%8C%E6%A8%A3%E5%BC%8F%E4%B8%8B%E6%8B%89%E9%81%B8%E5%96%AE_ThemeDropdown.jpg" width="100%" alt="Theme Dropdown" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/05_%E6%8F%90%E7%A4%BA%E9%9F%B3%E6%95%88%E4%B8%8B%E6%8B%89%E9%81%B8%E5%96%AE_SoundDropdown.jpg" width="100%" alt="Sound Dropdown" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/06_%E5%A4%9A%E5%9C%8B%E8%AA%9E%E7%B3%BB%E4%B8%8B%E6%8B%89%E9%81%B8%E5%96%AE_LocaleDropdown.jpg" width="100%" alt="Locale Dropdown" /> |
| Classic, FF7, WinXP, Borland, Dark, Cyberpunk styles | ShayBell, Netherwind, PolyMorphCow, and SharedMedia audio | Auto Detect, Traditional Chinese, Simplified Chinese, English, Korean, Russian |

---

### 2. Alert Lists, Conditions & Docking

| Self Aura & Cow Head Preview | Spell Cooldown & Behavior Overrides |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/07_%E8%87%AA%E8%BA%AB%E5%85%89%E7%92%B0%E6%B8%85%E5%96%AE%E8%88%87%E7%B4%B0%E9%83%A8%E6%A2%9D%E4%BB%B6%E8%A8%AD%E5%AE%9A_SelfAuraConditions.jpg" width="100%" alt="Self Aura Conditions" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/08_%E6%8A%80%E8%83%BD%E5%86%B7%E5%8D%BB%E7%9B%A3%E6%8E%A7%E8%88%87%E8%A1%8C%E7%82%BA%E8%A6%86%E5%AF%AB%E8%A8%AD%E5%AE%9A_SpellCooldownOptions.jpg" width="100%" alt="Spell Cooldown Options" /> |
| Spell list, Cow Head layout preview, stack/glow/timer limits, 12.1 sound triggers | Cooldown list, remove-on-complete, out-of-combat display, usable glow overrides |

| Item Cooldown Settings | 3-Level Docking & Ground Effects |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/09_%E7%89%A9%E5%93%81%E5%86%B7%E5%8D%BB%E7%9B%A3%E6%8E%A7%E8%88%87%E7%B4%B0%E9%83%A8%E6%A2%9D%E4%BB%B6%E8%A8%AD%E5%AE%9A_ItemCooldownOptions.jpg" width="100%" alt="Item Cooldown Settings" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/10_%E5%9C%B0%E9%9D%A2%E6%95%88%E6%9E%9C%E7%93%A3%E6%8E%A7%E8%88%87%E4%B8%89%E7%B4%9A%E9%9A%8E%E5%B1%A4%E5%90%B8%E9%99%84_GroundEffectDocking.jpg" width="100%" alt="Ground Effect & 3-Level Docking" /> |
| Equipment & trinket cooldown list, stack thresholds, priorities & custom icons | Main Options ➔ List ➔ Conditions seamless APPEND Docking & dynamic Tooltip probe |

---

### 3. Resources, Stats & Layout

| Player Resource Panel | Player Stats & Absorbs Monitor |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/11_%E7%8E%A9%E5%AE%B6%E8%81%B7%E6%A5%AD%E8%B3%87%E6%BA%90%E8%A8%AD%E5%AE%9A%E9%9D%A2%E6%9D%BF_PlayerResourcePanel.jpg" width="100%" alt="Player Resource Panel" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/12_%E8%A7%92%E8%89%B2%E5%B1%AC%E6%80%A7%E8%88%87%E5%90%B8%E6%94%B6%E9%87%8F%E7%9B%A3%E6%8E%A7%E9%9D%A2%E6%9D%BF_PlayerStatsPanel.jpg" width="100%" alt="Player Stats Panel" /> |
| Runes, Power Bars, display modes, anchor positioning, sliders & Secret protection | 18 core stats, run/swim/fly/gliding speed, icon/bar toggles & threshold warnings |

| Layout Positioning & Tooltips | Profile Sharing & Import/Export |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/13_%E5%91%8A%E8%AD%A6%E6%A1%86%E6%9E%B6%E4%BD%8D%E7%BD%AE%E6%8E%92%E7%89%88%E8%88%87%E6%87%B8%E5%81%9C%E6%8F%90%E7%A4%BA_LayoutPositionOptions.jpg" width="100%" alt="Layout Options & Tooltips" /> | <img src="https://raw.githubusercontent.com/ziyuefan/EventAlertModRemake/main/.AI/ScreenShot/14_%E8%81%B7%E6%A5%ADProfile%E5%88%86%E4%BA%AB%E8%88%87%E5%8C%AF%E5%85%A5%E5%8C%AF%E5%87%BA%E9%9D%A2%E6%9D%BF_ProfileCodecPanel.jpg" width="100%" alt="Profile Codec Panel" /> |
| Size/spacing/font/alpha sliders, 7 frame growth directions, tooltips on all controls | 8 selective categories, one-click export/preview/merge/replace via EAMAP1 Base64 |

---

## ⌨️ Command Line Reference

EAM provides a rich suite of slash commands via `/eam` or `/eventalertmod` (case-insensitive):

| Command | Aliases | Description |
| :--- | :--- | :--- |
| `/eam` or `/eam opt` | `/eam option`, `/eam options` | Open EAM Main Options menu |
| `/eam reset` | `/eam resetpos`, `/eam center` | **Reset main window to the center of the screen** (fixes windows dragged offscreen) |
| `/eam list` | None | Print monitored alerts for current class (Self, Target, Cooldown, Item, Ground) |
| `/eam add <spellID>` | `/eam add player <spellID>` | Add specified Spell ID to "Player Buff/Debuff" monitor list |
| `/eam add target [spellID]` | None | Add to "Target Buff/Debuff" monitor; opens manual entry if ID omitted |
| `/eam add cd <spellID>` | `/eam add cooldown <spellID>` | Add specified Spell ID to "Spell Cooldown" monitor list |
| `/eam add item <itemID>` | `/eam add itemcooldown <itemID>` | Add specified Item ID to "Item Cooldown" monitor list |
| `/eam remove <spellID>` | `/eam remove <player\|target\|cd\|item> <ID>` | Remove spell or item ID from specified monitor category |
| `/eam lookup <name>` | `/eam l <name>` | Fuzzy search candidate spells and Spell IDs for current class |
| `/eam lookupfull <fullName>` | `/eam lf <fullName>` | Exact search candidate spells and Spell IDs for current class |
| `/eam showcast` | `/eam showc` | Start/stop logging spells cast successfully during current session |
| `/eam profile` | `/eam profile export`, `/eam profile import` | Open Profile Export/Import and string sharing panel |
| `/eam rune` | `/eam runes`, `/eam probe rune` | Open Death Knight 6-slot rune dashboard, charge status & diagnostic JSON |
| `/eam unitpower background <KEY>` | None | Mark background resource missing event, triggering 0.5s demand-driven sampler |
| `/eam doctor` | `/eam validate` | Run client API boundary and environment diagnostic report |
| `/eam test [suite]` | `/eam test live` | Open in-game flow test panel or run specified suite (`quick/core/boundary/aura121/all/live`) |
| `/eam debug` | `/eam export` | Open system status and compact AI debug report export window |
| `/eam debug ground <spellID>` | None | Test and debug ground effect tooltip duration parsing for a spell |
| `/eam show` / `/eam showtarget` | `/eam shows`, `/eam showt` | Display Retail 12.1 safe aura monitoring guide (hover + Ctrl+Alt) |
| `/eam help` | `/eam ?` | Print all available slash commands |

---

## 🖱️ Quick Add via Mouse Hover (`Ctrl + Alt`)

In-game, you never need to manually look up Spell IDs:
1. Hover your mouse over any aura icon on player/target unit frames, or action bar buttons/macros/items.
2. Press **`Ctrl + Alt`** simultaneously.
3. The EAM Quick Add dialog pops up immediately, letting you add it to Player Buff, Target Buff, Spell Cooldown, or Item Cooldown with a single click!

---

## 📦 Installation

1. Visit [GitHub Releases](https://github.com/ziyuefan/EventAlertModRemake/releases) and download the latest `EventAlertMod_MN_*.zip`.
2. Extract the archive and place the `EventAlertMod` folder into your World of Warcraft directory:
   - Retail Path: `World of Warcraft\_retail_\Interface\AddOns\EventAlertMod`
3. Launch World of Warcraft. On the Character Selection screen, verify that `EventAlertMod` is checked in the "AddOns" menu.

---

## 📜 Version History (CHANGELOG.TXT)

<details open markdown="1">
<summary><b>🔥 Retail 12.1.0 Redux & Alpha Series Highlights (Click to Expand/Collapse)</b></summary>

### 🌟 [Retail 12.1.0 Alpha 8.3] - 2026.08.30
- **Cooldown Location Order, Strict Inactive Guard & Per-Spell Pre-render Placeholders**:
  - **Cooldown Location Order**: Each row features a dedicated Location Order numeric input box displaying its unique natural number slot (1..N). Supports `▲`/`▼` shifting, drag-and-drop reordering, and direct numeric jump with automatic normalization.
  - **Strict Guard for Disabled Spells**: Spells that are disabled (`enabled == false`) strictly never create pre-render frames or placeholders, taking zero layout slots or memory.
  - **Per-Spell Independent Pre-render Toggle**: Replaced global setting with independent per-spell condition overrides (desaturated placeholder when inactive, full color on cooldown), default false.
  - **Smooth Scroll Tracking & Selection Highlight**: Reordering or clicking items smoothly scrolls the ScrollBox to follow the target spell and maintains a persistent blue selection highlight.
- **Player Stats In-Combat Live Updates & C-Level Zero-GC Rendering**:
  - Full adoption of native `FontString:SetFormattedText` for all 18 stats, achieving zero Lua GC string allocations in OnUpdate timer loops.
  - Implemented `getRawValue` routing across all 18 attributes, respecting Retail 12.x / Midnight `AllowedWhenTainted` and `Enum.SecretAspect.Text` contracts.

### 🌟 [Retail 12.1.0 Alpha 8.2] - 2026.08.27
- **Full LibSharedMedia-3.0 (SharedMedia) Ecosystem Integration**:
  - Dynamic discovery (`MediaService.ensureLSM()`), `PLAYER_LOGIN` deferred sync, third-party sound/font package support, dual-channel safe playback (`MediaService.playSound`), and 12.1 Native Aura sound routing.
- **Zero-Delay Live Font Application (No `/reload` Needed)**:
  - SavedVariables whitelist unlock, live refresh of preview icons, general alert icons, player resources, and player stats text.
- **Scrollable Dropdown Menus**:
  - Adaptive `UIPanelScrollFrameTemplate` with smooth mouse wheel scrolling for long lists of media assets.

### 📌 [Retail 12.1.0 Alpha 8.1] - 2026.08.26
- **Persistent Pre-anchoring & Zero-Alpha Cooldown Mode**:
  - Pre-created frame structures and pre-calculated layout coordinates; `SetAlpha(0)` hiding on cooldown completion for 0.00ms latency and 100% combat lockdown immunity.
- **Combat Stat Memory Cache & Multi-Tier Fallback**:
  - Memory cache table (`lastKnownStats`) across 18 stats for seamless non-zero combat displays under restricted APIs.
- **Dual-Channel Shield & Heal Absorb Detection**:
  - Native Unit APIs + `C_UnitAuras.points` accumulation.
- **Aura Shield Absorb Amount Display**:
  - Overlay formatted shield amounts (e.g. `45.2k`, `1.2M`, `3(45k)`).

### 📌 [Retail 12.1.0 Alpha 8.0] - 2026.08.25
- **Per-Class Player Stat Profiles**:
  - Completely isolated stat monitoring profiles, thresholds, and positions per class.
- **Iconless Adaptive Layout**:
  - Perfect equal spacing and zero text overlapping when icons are hidden.

### 🌟 [Retail 12.1.0 Alpha 7.9] - 2026.08.24
- **10 Full UI Windows Comprehensive Hover Tooltips**.
- **ClampedToScreen & `/eam reset` Window Center Reset Command**.
- **Official Visual Showcase with 14 High-Res Screenshots**.

### 📌 [Retail 12.1.0 Alpha 7.8] - 2026.08.24
- **Player Stats & Absorbs Module**: 18 stats & 4-in-1 velocities (gliding 830%~1400%).
- **Custom Icon Override Across All Modules**.
</details>

---

## 📌 Compatibility

- **Supported Client Environments**:
  - World of Warcraft: Retail 12.1.0+ (Interface `120100`)
  - Retail Compatibility Channel 12.0.7+ (Interface `120007`)
- **Unsupported Environments**:
  - Classic Era, MoP Classic, TBC Classic, Wrath Classic (Out of scope for this Retail remake project).

---

## 🌐 Documentation & Links

- 📖 **GitHub Pages Documentation Hub**: [https://ziyuefan.github.io/EventAlertModRemake/](https://ziyuefan.github.io/EventAlertModRemake/)
- 📦 **GitHub Repository & Releases**: [https://github.com/ziyuefan/EventAlertModRemake](https://github.com/ziyuefan/EventAlertModRemake)
- 📜 **CurseForge Addon Page**: [https://www.curseforge.com/wow/addons/eventalertmod](https://www.curseforge.com/wow/addons/eventalertmod)
- 💬 **WoWInterface Addon Page**: [https://www.wowinterface.com/downloads/info26550-EventAlertMod.html](https://www.wowinterface.com/downloads/info26550-EventAlertMod.html)

# EventAlertMod Remake Documentation Hub

[![GitHub](https://img.shields.io/badge/source-GitHub-181717)](https://github.com/ziyuefan/EventAlertModRemake)
[![Release](https://img.shields.io/badge/release-Alpha%208.5-orange)](https://github.com/ziyuefan/EventAlertModRemake/releases)
[![Retail](https://img.shields.io/badge/WoW-Retail%2012.1-blue)](https://github.com/ziyuefan/EventAlertModRemake)
[![Interface](https://img.shields.io/badge/Interface-120007%20%7C%20120100-brightgreen)](https://github.com/ziyuefan/EventAlertModRemake)

> 🚀 **Ultra-lightweight, zero-taint, pure event-driven spell monitoring and combat alert AddOn built specifically for World of Warcraft: Retail (12.1.0 / 12.0+)!**

Welcome to the EventAlertMod (EAM) Retail Rewrite Documentation Hub. This portal provides tailored navigation and architectural references for both **AddOn users/players** and **AI/Human developers**.

---

## 🌟 Four Core Architectural Advantages of Modern EAM

| Traditional Spell Alerts / Heavy AddOns | Modern Remake EventAlertMod (EAM) |
| :--- | :--- |
| ⚠️ **Heavy resource drain**: Massive background OnUpdate polling, high memory consumption, combat frame drops. | ⚡ **Ultra-lightweight & zero burden**: Pure event-driven architecture with zero-allocation State Pools, eliminating GC memory spikes. |
| ❌ **Vulnerable to combat taint**: 12.0+ Secret Values frequently cause yellow Lua errors or broken frames in combat. | 🛡️ **Blizzard 12.0+ Secret Protection**: Direct native C-Level `StatusBar:SetValue` throughput & C-Level curve pipelines (`CurveObject` / `ColorCurveObject`), utilizing binary step gate curves to pierce Secret Values without Lua taint. |
| 🔄 **Tedious setup & string imports**: Requires searching online for WeakAura strings or complex custom scripting. | 🎯 **Intuitive one-second monitor**: Hover over any spell, aura, or item and press **`Ctrl + Alt`** to instantly add to monitor; built-in Master Spell Catalog covering 4,463 spells with intelligent preset syncing. |
| 🐢 **Inaccurate flight speed**: Traditional addons fail to read 10.0+ / 11.0+ / 12.0+ Dragonriding dynamic gliding velocity. | 🏃 **Industry-first 4-in-1 Velocity**: Dedicated integration with `C_PlayerInfo.GetGlidingInfo()` supporting **830%~1400%** dynamic speed, featuring a dedicated "Gliding Only" display mode and in-combat cache fallbacks! |

---

## ✨ 8 Independent Alert Modules

EAM features 8 decoupled, independently positioned and freely draggable alert modules:

1. 🔮 **Player Buff / Debuff**: Self buffs & debuffs with stack counts, real-time shield absorb amounts (e.g. `45.2k`, `1.2M`, `3(45k)`), and high-precision countdown timers.
2. 🎯 **Target Buff / Debuff**: Precise tracking of target auras, CC, and debuff states with anonymous Tooltip probes and zero-taint sampling.
3. ⚔️ **Cross-Class / Target Cast**: Key enemy burst cooldowns and crucial friendly buffs, featuring interactive confirmation dialogs for non-class spells.
4. ⏳ **Spell Cooldown**: Zero-Alpha (Alpha=0) persistent pre-anchored mode with 0.00ms layout latency; supports 2D Grid Layout with customizable columns per row, Radial Ring Mode, outer linear bars (`TOP/BOTTOM/LEFT/RIGHT`), cooldown swipe color/alpha customization, and non-linear cooldown curves.
5. 🎒 **Item Cooldown**: Trinkets, on-use equipment, and consumables monitoring with 2D Grid Layout support.
6. 🌋 **Ground Effect**: Aura-less ground AoE spells (Death and Decay, Defile, Frozen Orb, AMZ) with Base/Override talent family matching and 2D Grid Layout support.
7. ⚡ **Player Resource**: All 13 classes, 40 specs, and 17 resource types, supporting smooth dynamic color curves and bidirectional (horizontal/vertical) bar growth; includes a dedicated 6-slot Death Knight Runes dashboard with `/eam rune` diagnostics.
8. 📊 **Player Stats & Absorbs**: Per-class customizable profiles with 18 core stats (Primary, Secondary, 4-in-1 Speeds, Armor, Total Shield Absorbs, and Heal Absorbs), powered by a modular 4-Tab settings layout and per-stat draggable positioning.

---

## 🔥 Recent Release Milestones

- 🌟 **[Retail 12.1.0 Alpha 8.5] - 2026.09.08 ~ 2026.09.12**
    - **Skyriding Speed Gliding-Only Display Option**: Added a dedicated "Glide Only" display option for skyriding speed, presenting velocity only during active gliding (`C_PlayerInfo.GetGlidingInfo().isGliding == true`) and hiding when stationary to keep UI clean.
    - **Cooldown Swipe Color & Alpha Customization**: Cooldown swipe on alert icons and preview panels now supports custom color and transparency (defaults to classic dark `(0, 0, 0, 0.8)`), eliminating glare from solid white swipes.
    - **Non-Class Spell Add Interactive Confirmation**: Entering a non-class spell ID prompts a theme-aligned interactive confirmation dialog instead of silently redirecting to cross-class lists.
    - **11 Classic & Modern Themes Deep Visual Overhaul**: Fully revitalized 11 themes (EAM Classic, FF7 Battle, Windows XP/7/10, DOS CRT green screen, ETen, Red Alert), fixed Modern WoW vertical gradient pipelines, and unified subwindow theme registration.
    - **Zero-Alpha Suppression on ESC Key**: Hiding icons via the ESC key now uses zero-alpha suppression (`SetAlpha(0)`), preserving frame trees, 2D matrix layouts, and background cooldown animations.
    - **Player Stats 4-Tab Modular Layout**: Expanded to 720x540 and restructured into 4 separate tabs ("Display & Icons", "Font & Format", "Thresholds", "Position & Anchors"), eliminating slider label collisions.
    - **Vertical Resource StatusBar Growth Fix**: Fixed vertical resource bars failing to grow upward with proper dimension transposition and tick dividers.
    - **Independent Live Preview Panel**: Free-floating preview panel supporting "Alert Icons", "Player Resources", and "Player Stats" tabs, allowing instant testing of countdown curves, Proc gold glows, and Pandemic borders out of combat.
    - **Blizzard Native CurveObject & ColorCurveObject Pipeline**: Aligned with Patch 12.0.0 C-Level curve architecture, enabling smooth power bar transitions and binary step gate curves to pierce protected Secret Values for 20%/35% execute thresholds.
    - **Adaptive SecondsFormatter Curves & Dynamic Health Pulse**: High-precision fractional seconds for final critical window, non-linear cooldown sprint tension, and full-screen pulsating low-health warnings.
- 🌟 **[Retail 12.1.0 Alpha 8.4] - 2026.09.04**
    - **2D Grid Layout Engine & Columns per Row Configuration**: Self auras, target auras, spell cooldowns, item cooldowns, and ground effects upgraded to 2D grid matrix layout with 1~20 columns per row slider.
    - **Pre-rendered Cooldown Combat Visibility & Zero-Alpha Toggle**: Out-of-combat pre-rendered cooldown icons smoothly hide via `SetAlpha(0)` and reappear instantly upon combat entry without frame recreation or layout shifts.
    - **Combat Speed Restriction Guard & True Cache Fallback**: Fixed Retail 12.x bug where `GetUnitSpeed` returned locked 1.0 causing 14.3% display, seamlessly falling back to cached real velocity.
    - **Cooldown Location Order & Per-Spell Pre-render Placeholders**: Added Location Order numeric inputs with ▲/▼ order swapping and per-spell pre-rendered placeholder toggles.
    - **In-Combat Stat Updates via FontString:SetFormattedText**: Zero-GC string formatting with C-level updates, eliminating frozen stat labels in combat.
- 🌟 **[Retail 12.1.0 Alpha 8.3] - 2026.08.28**
    - **Next-Gen Master Spell Catalog & Intelligent Presets**: 5-locale offline catalog with 4,463 core spells and 466 auras across 13 classes, 40 specs, and 39 hero talent trees with one-click talent book syncing.
    - **Multidimensional Group Management Module**: 4 built-in tactical groups (Major Burst, Major Defensive, CC/Interrupt, Ground AoE) with custom tags, global toggles, and multi-select dropdowns.
    - **Hardening & Deprecated API Elimination**: Full migration from legacy APIs to modern `C_Spell` / `C_Item`, with duplicate alert ID prevention in Profile Codec.
- 🌟 **[Retail 12.1.0 Alpha 8.2] - 2026.08.27**
    - **Full LibSharedMedia-3.0 (SharedMedia) Ecosystem Integration**: `ensureLSM` dynamic discovery, `PLAYER_LOGIN` deferred sync, third-party sound/font package support, dual-channel safe playback (`MediaService.playSound`), and 12.1 Native Aura sound routing.
    - **Zero-Delay Live Font Application (No `/reload` Needed)**: SavedVariables whitelist unlock, live refresh of preview icons, general alert icons, player resources, and player stats text.
    - **Scrollable Dropdown Menus**: Adaptive `UIPanelScrollFrameTemplate` with smooth mouse wheel scrolling for long lists of media assets.
- 🌟 **[Retail 12.1.0 Alpha 8.1] - 2026.08.26**
    - **Persistent Pre-anchoring & Zero-Alpha Cooldown Mode**: Pre-created frame structures and pre-calculated layout coordinates; `SetAlpha(0)` hiding on cooldown completion for 0.00ms latency and 100% combat lockdown immunity.
    - **Combat Stat Memory Cache & Multi-Tier Fallback**: Memory cache table (`lastKnownStats`) across 18 stats for seamless non-zero combat displays under restricted APIs.
- 🌟 **[Retail 12.1.0 Alpha 8.0] - 2026.08.25**
    - **Per-Class Player Stat Profiles**: Completely isolated stat monitoring profiles, thresholds, and positions per class.
    - **Dual-Channel Shield & Heal Absorb Detection**: Native Unit APIs + `C_UnitAuras.points` accumulation.
    - **Iconless Adaptive Layout**: Perfect equal spacing and zero text overlapping when icons are hidden.
    - **Aura Shield Absorb Amount Display**: Overlay formatted shield amounts (e.g. `45.2k`, `1.2M`, `3(45k)`).
- 🌟 **[Retail 12.1.0 Alpha 7.8 ~ 7.9] - 2026.08.24**
    - **Player Stats & Absorbs Module**: 18 stats & 4-in-1 velocities (gliding 830%~1400%).
    - **10 Full UI Windows Comprehensive Hover Tooltips** and ClampedToScreen window center reset (`/eam reset`).
    - **Custom Icon Override Across All Modules** and Classic Cow Head Anchor Preview.
- 🌟 **[Retail 12.1.0 Alpha 7.1 ~ 7.7] - 2026.08.23**
    - Sub-window Multi-Anchor Positioning Mode, APPEND Window Docking, Profile Export/Import (EAMAP1), and Death Knight Runes Dashboard.
    - Spell Charge Info Secret Boundary, Radial Ring Mode, and Ground Effect Base/Override Families.
- 🌟 **[Retail 12.1.0 Alpha 5 ~ 7.0] - 2026.08.14 ~ 2026.08.23**
    - 17 Player Resources, 11 Themes, and 5 Locales (zhTW, zhCN, enUS, koKR, ruRU).
- 🌟 **[Retail 12.1.0 Alpha 1 ~ 4] - 2026.07 ~ 2026.08**
    - Retail 12.1 Native Aura (`CustomAuraContainer`) initial rewrite, Zero-Allocation state pools, and Tooltip `Ctrl+Alt` shortcut.

---

## 🎮 Players & Users Portal

*   📖 **[Quick Start Guide (README)](README.md.html)**
    *   Installation guide, slash commands, screenshot showcase, custom icons, and 8 module feature details.
*   📜 **[Changelog (Updates)](changelog.txt.html)**
    *   Full release history and technical change details for all Alpha releases.

---

## 🤖 AI & Human Developers Portal

### 🛠️ Core Guidelines
*   🔑 **[AI Entrance & Hard Constraints (AGENTS)](AGENTS.md.html)**
    *   **The absolute Fact-of-Truth guide for developers**. Includes combat Secret check protocols, Taint control rules, OnUpdate scheduler limits, and package building scripts.
*   🔄 **[Subagent Workflows (Collab)](17_SUBAGENT_WORKFLOW.md.html)**
    *   Multi-agent collaboration procedures, RACI expert matrix, and QA root cause analysis guidelines.
*   🧭 **[Expert RACI Matrix](21_RACI_EXPERTS_MATRIX.md.html)**
    *   24 canonical expert roles, single point of accountability, evidence grading, and task signoff protocols.
*   🔎 **[2026-06-21 Expert Council Review](24_EXPERT_COUNCIL_REVIEW_20260621.md.html)**
    *   Graded review of Retail 12.1 Aura readiness, Secret/Taint protection, performance, and documentation governance.
*   🚀 **[Antigravity Takeover Baseline Assessment](31_TAKEOVER_UNDERSTANDING_BASELINE_20260823_200615.md.html)**
    *   Authoritative baseline assessment of AI governance, WoW Retail 12.x API boundaries, zero-GC performance architecture, player resources, and deployment workflow.
*   🧠 **[21 Core SKILLs Ecosystem & Agentic AI Philosophy](32_EAM_SKILL_ECOSYSTEM_AND_PHILOSOPHY.md.html)**
    *   **Everything-as-a-Skill Operational Runbook**. Covers all 21 standardized skills across 5 domains, progressive disclosure, deterministic execution, and anti-regression governance.
*   📜 **[AI Agent Structured XML Governance Directive](33_AI_GOVERNANCE_DIRECTIVE.md.html)**
    *   **Structured XML directive for LLMs & Subagents**. Defines when to establish/ingest XML directives, 5 absolute iron rules, Retail 12.x Secret sentinel firewalls, architecture layer contracts, and zero cold-start memory anchoring. Physical XML stored at `AI_GOVERNANCE_DIRECTIVE.xml`.

### 🏗️ Architecture & APIs
*   📐 **[System Architecture (Decoupled Design)](01_ARCHITECTURE.md.html)**
    *   Complete decoupling between data layers and the Renderer, EventRouter dispatching, and AlertManager batch throttle mechanism.
*   🛡️ **[Retail 12.x API Boundaries](02_RETAIL_API_BOUNDARIES.md.html)**
    *   The 4 core Secret/Protected value checking functions, secure table indexing guards, and C++ DurationObject rendering pipelines.
*   📡 **[Retail API Change Intelligence](25_RETAIL_API_CHANGE_INTELLIGENCE.md.html)**
    *   APICHG version intelligence, TOC/revision matrix, 12.0.0~12.1.0 evolution, and EAM migration window.
*   🧩 **[Retail 12.1 AuraContainer Native Backend](23_AURA_CONTAINER_IMPLEMENTATION.md.html)**
    *   Build 68914 contracts, Native/Legacy routing, Slot/Group, Aura Sound, schema v4, and PTR RQA acceptance.
*   ⚡ **[Player Resource Refactor Report](30_PLAYER_RESOURCE_REFACTOR_REPORT.md.html)**
    *   17 resources, 13 classes / 40 spec topologies, Druid form switching, DK 6-slot runes, and Secret write-only sinks.
*   📚 **[Class & Specialization Database](18_RETAIL_12X_CLASS_SPECIALIZATION_HERO_TALENT_DATABASE.md.html)**
    *   Offline database covering core class spells, burst auras, and hero talents across all 40 specs.
*   💾 **[Data State Schema](03_STATE_SCHEMA.md.html)**
    *   Data structures of the zero-allocation cache pool (AuraStatePool), countdown states, and memory recycling strategies.
*   📜 **[Module Contracts](04_MODULE_CONTRACTS.md.html)**
    *   API contract interfaces between the 5 core data services and the Renderer/AlertManager.

### ⚡ Performance & Quality
*   🏎️ **[JIT Optimization & Performance Guide](05_PERFORMANCE_GUIDE.md.html)**
    *   Heap garbage prevention in hot paths (avoiding anonymous closures), pcall crash isolation, and JIT compiler friendly StatePool practices.
*   🔍 **[Performance & Taint Audit Report](23_PERFORMANCE_TAINT_AUDIT_REPORT.md.html)**
    *   In-depth static analysis and live stress-test verification demonstrating zero memory leaks and complete immunity from combat taint.
*   📋 **[Retail Smoke Test Plan](06_TEST_PLAN_RETAIL.md.html)**
    *   Smoke test scenarios, in-combat taint checks, and local development package verification.
*   🧪 **[Flow Validation and Developer Feedback](26_FLOW_VALIDATION_FRAMEWORK.md.html)**
    *   Shared offline/live cases, in-game controls, JSON/Markdown reports, and WTF feedback import.
*   🔬 **[QC Root Cause Analysis Guide](22_QC_ROOT_CAUSE_ANALYSIS_GUIDE.md.html)**
    *   Standard engineering methodology for defect attribution, boundary condition testing, and regression prevention.
*   🖥️ **[Local WoW Development Environment](27_LOCAL_WOW_ENVIRONMENT.md.html)**
    *   Local 12.0.7/12.1.0 version mapping under `D:\World of Warcraft`, WTF path derivation, and fail-closed protection for symbolic links.
*   📓 **[Development Issue Log](15_DEVELOPMENT_ISSUE_LOG.md.html)**
    *   A comprehensive log of resolved JIT Aborts, Blizzard protected frame restrictions, and frame clipsChildren issues.
*   🔄 **[Project Continuity & Timeline](28_PROJECT_CONTINUITY.md.html)**
    *   First human-readable continuity point after context compression or subagent handover.
*   🎮 **[Live In-Game Test Step Guide](29_LIVE_TEST_STEP_GUIDE.md.html)**
    *   Execution steps and signoff manual for 37 real client verification test cases.


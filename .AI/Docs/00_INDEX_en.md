# EventAlertMod Remake Documentation Hub

[![GitHub](https://img.shields.io/badge/source-GitHub-181717)](https://github.com/ziyuefan/EventAlertModRemake)
[![Release](https://img.shields.io/badge/release-Alpha%208.2-orange)](https://github.com/ziyuefan/EventAlertModRemake/releases)
[![Retail](https://img.shields.io/badge/WoW-Retail%2012.1-blue)](https://github.com/ziyuefan/EventAlertModRemake)
[![Interface](https://img.shields.io/badge/Interface-120007%20%7C%20120100-brightgreen)](https://github.com/ziyuefan/EventAlertModRemake)

> 🚀 **Ultra-lightweight, zero-taint, pure event-driven spell monitoring and combat alert AddOn built specifically for World of Warcraft: Retail (12.1.0 / 12.0+)!**

Welcome to the EventAlertMod (EAM) Retail Rewrite Documentation Hub. This portal provides tailored navigation and architectural references for both **AddOn users/players** and **AI/Human developers**.

---

## 🌟 Four Core Architectural Advantages of Modern EAM

| Traditional Spell Alerts / Heavy AddOns | Modern Remake EventAlertMod (EAM) |
| :--- | :--- |
| ⚠️ **Heavy resource drain**: Massive background OnUpdate polling, high memory consumption, combat frame drops. | ⚡ **Ultra-lightweight & zero burden**: Pure event-driven architecture with zero-allocation State Pools, eliminating GC memory spikes. |
| ❌ **Vulnerable to combat taint**: 12.0+ Secret Values frequently cause yellow Lua errors or broken frames in combat. | 🛡️ **Blizzard 12.0+ Secret Protection**: Direct native C-Level `StatusBar:SetValue` throughput, 100% immune to Lua taint. |
| 🔄 **Tedious setup & string imports**: Requires searching online for WeakAura strings or complex custom scripting. | 🎯 **Intuitive one-second monitor**: Hover over any spell, aura, or item and press **`Ctrl + Alt`** to instantly add to monitor. |
| 🐢 **Inaccurate flight speed**: Traditional addons fail to read 10.0+ / 11.0+ / 12.0+ Dragonriding dynamic gliding velocity. | 🏃 **Industry-first 4-in-1 Velocity**: Dedicated integration with `C_PlayerInfo.GetGlidingInfo()` supporting **830%~1400%** dynamic speed! |

---

## ✨ 8 Independent Alert Modules

EAM features 8 decoupled, independently positioned and freely draggable alert modules:

1. 🔮 **Player Buff / Debuff**: Self buffs & debuffs with stack counts, remaining shield absorb amount, and high-precision timers.
2. 🎯 **Target Buff / Debuff**: Precise tracking of target auras, CC, and debuff states.
3. ⚔️ **Cross-Class / Target Cast**: Key enemy burst cooldowns and crucial friendly buffs.
4. ⏳ **Spell Cooldown**: Zero-Alpha (Alpha=0) persistent pre-anchored mode with 0.00ms layout latency; supports Radial Ring Mode & outer linear bars (`TOP/BOTTOM/LEFT/RIGHT`).
5. 🎒 **Item Cooldown**: Trinkets, on-use equipment, and consumables monitoring.
6. 🌋 **Ground Effect**: Aura-less ground AoE spells (Death and Decay, Defile, Frozen Orb, AMZ) with Base/Override talent family matching.
7. ⚡ **Player Resource**: All 13 classes, 40 specs, and 17 resource types (Mana, Rage, Energy, Combo Points, Chi, Insanity, Runic Power, Arcane Charges, Soul Shards, Holy Power, Essence, etc.).
8. 📊 **Player Stats & Absorbs**: Per-class customizable profiles with 18 core stats (Primary, Secondary, 4-in-1 Speeds, Armor, Total Shield Absorbs, and Heal Absorbs).

---

## 🔥 Recent Release Milestones

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
- 🌟 **[Retail 12.1.0 Alpha 7.9] - 2026.08.24**
  - **10 Full UI Windows Comprehensive Hover Tooltips**: Intuitive guidance on all buttons, checkboxes, sliders, and menus.
  - **ClampedToScreen & `/eam reset` Window Center Reset Command**.
  - **Official Visual Showcase with 14 High-Res Screenshots**.
- 🌟 **[Retail 12.1.0 Alpha 7.8] - 2026.08.24**
  - **Player Stats & Absorbs Module**: 18 stats & 4-in-1 velocities (gliding 830%~1400%).
  - **Custom Icon Override Across All Modules**: Custom FileDataIDs or texture paths.
  - **Classic Cow Head Anchor Preview**.
- 🌟 **[Retail 12.1.0 Alpha 7.5 ~ 7.7] - 2026.08.23**
  - Sub-window Multi-Anchor Positioning Mode, APPEND Window Docking, Profile Export/Import (EAMAP1), and Death Knight Runes Dashboard.
- 🌟 **[Retail 12.1.0 Alpha 7.1 ~ 7.4] - 2026.08.23**
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
*   💾 **[Data State Schema](03_STATE_SCHEMA.md.html)**
    *   Data structures of the zero-allocation cache pool (AuraStatePool), countdown states, and memory recycling strategies.
*   📜 **[Module Contracts](04_MODULE_CONTRACTS.md.html)**
    *   API contract interfaces between the 5 core data services and the Renderer/AlertManager.

### ⚡ Performance & Quality
*   🏎️ **[JIT Optimization & Performance Guide](05_PERFORMANCE_GUIDE.md.html)**
    *   Heap garbage prevention in hot paths (avoiding anonymous closures), pcall crash isolation, and JIT compiler friendly StatePool practices.
*   📋 **[Retail Smoke Test Plan](06_TEST_PLAN_RETAIL.md.html)**
    *   Smoke test scenarios, in-combat taint checks, and local development package verification.
*   🧪 **[Flow Validation and Developer Feedback](26_FLOW_VALIDATION_FRAMEWORK.md.html)**
    *   Shared offline/live cases, in-game controls, JSON/Markdown reports, and WTF feedback import.
*   🖥️ **[Local WoW Development Environment](27_LOCAL_WOW_ENVIRONMENT.md.html)**
    *   Local 12.0.7/12.1.0 version mapping under `D:\World of Warcraft`, WTF path derivation, and protection rules for Windows symbolic links targeting `D:\EventAlertMod`.
*   📓 **[Development Issue Log](15_DEVELOPMENT_ISSUE_LOG.md.html)**
    *   A comprehensive log of resolved JIT Aborts, Blizzard protected frame restrictions, and frame clipsChildren issues.
*   🔄 **[Project Continuity & Timeline](28_PROJECT_CONTINUITY.md.html)**
    *   First human-readable continuity point after context compression or subagent handover.
*   🎮 **[Live In-Game Test Step Guide](29_LIVE_TEST_STEP_GUIDE.md.html)**
    *   Execution steps and signoff manual for 37 real client verification test cases.

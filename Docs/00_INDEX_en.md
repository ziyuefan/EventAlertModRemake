# EventAlertMod Remake Documentation Hub

Welcome to the EventAlertMod (EAM) Retail Rewrite Documentation Hub. This center provides tailored entry portals for both **AddOn users/players** and **AI/Human developers**.

---

## 🎮 Players & Users Portal

If you are a player using this AddOn, please visit the following documents to learn about installation, usage, and recent update logs:

*   📖 **[Quick Start Guide (README)](README.md.html)**
    *   AddOn installation, slash commands, frame adjustments, and feature highlights (Pandemic glow, hero talent support).
*   📜 **[Changelog (Updates)](changelog.txt.html)**
    *   Full details of rewrite updates in 12.0.7 and 12.1.0, including zero-allocation JIT optimizations and shadow host CDM bypass rendering history.

---

## 🤖 AI & Human Developers Portal

If you are an AI coding agent or a human developer contributing to this project, please read the system architecture and development guidelines carefully:

### 🛠️ Core Guidelines
*   🔑 **[AI Entrance & Hard Constraints (AGENTS)](AGENTS.md.html)**
    *   **The absolute Fact-of-Truth guide for developers**. Includes combat Secret check protocols, Taint control rules, OnUpdate scheduler limits, and package building scripts.
*   🔄 **[Subagent Workflows (Collab)](17_SUBAGENT_WORKFLOW.md.html)**
    *   Multi-agent collaboration procedures, RACI expert matrix, and QA root cause analysis guidelines.

### 🏗️ Architecture & APIs
*   📐 **[System Architecture (Decoupled Design)](01_ARCHITECTURE.md.html)**
    *   Complete decoupling between data layers and the Renderer, EventRouter dispatching, and AlertManager batch throttle mechanism.
*   🛡️ **[Retail 12.x API Boundaries](02_RETAIL_API_BOUNDARIES.md.html)**
    *   The 4 core Secret/Protected value checking functions, secure table indexing guards, and C++ DurationObject rendering pipelines.
*   🧩 **[Retail 12.1 AuraContainer Native Backend](23_AURA_CONTAINER_IMPLEMENTATION.md.html)**
    *   Build 68914 contracts, Native/Legacy routing, Slot/Group, Aura Sound, schema v2, and pending PTR RQA acceptance.
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

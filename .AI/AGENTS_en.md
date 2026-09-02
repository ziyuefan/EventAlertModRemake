<!-- EAM_DOCUMENTATION_SOURCE: enUS -->
# EventAlertMod AI Agent Entry & Governance Guide

This document governs the development, maintenance, and architectural standards for the modern World of Warcraft (WoW) Retail rewrite of EventAlertMod (EAM). Legacy codebase files serve only as behavioral references; legacy architecture must never be used as the foundation for modern development.

---

## Communication & Documentation Principles

- Default project language: Traditional Chinese (Taiwan conventions) for user dialogue, English for code, API bindings, and international docs.
- User reference: "少年欸" (Master/Boss).
- Responses must directly address the task with clear technical depth and structured rationale.
- WoW AddOn tasks must verify Retail vs. Classic boundaries first; **this project exclusively targets Retail**.
- For 12.x APIs, Secret Values, `C_*` namespaces, or Widget behavior, always prioritize `Docs/` and latest Warcraft Wiki / Blizzard API intelligence.
- Never claim in-game verification unless loaded and tested within a live WoW Retail client.
- When code is modified, documentation under `.AI/Docs/` must be proactively kept in sync without waiting for user prompting.
- **Markdown & HTML Conversion Rules**:
  - The absolute Fact-of-Truth for development and AI collaboration is `.AI/AGENTS.md` and related `.md` files under `.AI/Docs/`.
  - The HTML site under `.AI/docs_html/` is strictly for human browser reading; AI tools and agents must always read original `.md` files.
  - When `.AI/Docs/*.md` or `AGENTS.md` are updated with Mermaid charts, tables, or images, run `python .AI/Tools/batch_convert_docs.py` to regenerate the HTML documentation.

---

## Required Reading List
Before modifying production code, agents must review:

- `.AI/PROJECT_MEMORY.md`
- `.AI/Docs/00_AI_CONTEXT.md`
- `.AI/Docs/01_ARCHITECTURE.md`
- `.AI/Docs/02_RETAIL_API_BOUNDARIES.md`
- `.AI/Docs/03_STATE_SCHEMA.md`
- `.AI/Docs/04_MODULE_CONTRACTS.md`
- `.AI/Docs/05_PERFORMANCE_GUIDE.md`
- `.AI/Docs/06_TEST_PLAN_RETAIL.md`
- `.AI/Docs/07_MIGRATION_NOTES.md`
- `.AI/Docs/08_AI_PROMPT_EXPORT_SCHEMA.md`
- `.AI/Docs/09_KNOWN_LIMITATIONS.md`
- `.AI/Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md`
- `.AI/Docs/11_WARCRAFT_WIKI_MAIN_MENU_TREE.md`
- `.AI/Docs/12_CODE_COMMENTARY_GUIDE.md`
- `.AI/Docs/14_PACKAGING_GUIDE.md`
- `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`
- `.AI/Docs/16_RETAIL_ADDON_OPTIMIZATION_ROADMAP.md`
- `.AI/Docs/17_SUBAGENT_WORKFLOW.md`
- `.AI/Docs/18_RETAIL_12X_CLASS_SPECIALIZATION_HERO_TALENT_DATABASE.md`
- `.AI/Docs/19_AURA_1210_REDUX_BLUEPRINT.md`
- `.AI/Docs/20_CDM_BYPASS_FEASIBILITY_STUDY.md`
- `.AI/Docs/21_RACI_EXPERTS_MATRIX.md`
- `.AI/Docs/22_QC_ROOT_CAUSE_ANALYSIS_GUIDE.md`
- `.AI/Docs/23_AURA_CONTAINER_IMPLEMENTATION.md`
- `.AI/Docs/24_EXPERT_COUNCIL_REVIEW_20260621.md`
- `.AI/Docs/25_RETAIL_API_CHANGE_INTELLIGENCE.md`
- `.AI/Docs/26_FLOW_VALIDATION_FRAMEWORK.md`
- `.AI/Docs/27_LOCAL_WOW_ENVIRONMENT.md`
- `.AI/Docs/28_PROJECT_CONTINUITY.md`
- `.AI/Docs/29_LIVE_TEST_STEP_GUIDE.md`
- `.AI/Data/ProjectContinuity.json`

---

## Project Objectives

- **Target Client**: World of Warcraft: Retail only (12.x / Midnight era).
- **Architecture**: Pure event-driven, zero-allocation StatePools, decoupled services, zero combat taint.
- **User Positioning**: Maintain EAM's core identity: simpler, lighter, and more focused on auras, cooldowns, and resources than WeakAuras.

---

## Hard Architectural Constraints & Safety Rules

### 1. Secret / Protected Values Defense (Retail 12.x / Midnight)
Retail 12.x may mark auras, cooldowns, timers, points, or unit values as Secret / Protected. To prevent fatal Lua errors or Taint crashes in combat:
- **Four Core Verification APIs**:
  - `issecretvalue(value)`: Checks if a value is a protected Secret Value.
  - `canaccessvalue(value)`: Checks if current execution context has permission to read the value.
  - `canaccesstable(table)`: Checks if a table structure can be safely accessed.
  - `issecrettable(table)` / `hasanysecretvalues(table)`: Checks if table contains secret properties.
- **Table Indexing Protection (CRITICAL)**:
  - NEVER use a Secret Value (e.g. protected `spellID` or `text`) as a key to index any non-secret Lua table:
    `attempted to index a table that cannot be indexed with Key Secrets`.
  - Always verify `not issecretvalue(key)` before indexing.
- **Never Arithmetic or Concatenate Secrets**:
  - Do NOT perform arithmetic (`+`, `-`, `*`), string concatenation (`..`), or comparisons (`<`, `>`) on Secret Numbers.
  - Route secret numbers directly to native C-Level sinks:
    - `FontString:SetFormattedText("%d", secretNum)` (AllowedWhenTainted = true, SecretAspect.Text).
    - `StatusBar:SetValue(secretNum)` (Write-only sink).
    - `DurationObject` pointer passing for CooldownFrame widgets.

### 2. Combat Lockdown Protection (`InCombatLockdown`)
- Any frame creation (`CreateFrame`), `SetParent`, or layout mutation (`SetPoint`, `ClearAllPoints`) during `InCombatLockdown() == true` is strictly prohibited or must be deferred to `PLAYER_REGEN_ENABLED`.
- Pre-anchor and pre-create all frames out of combat; use `SetAlpha(0)` or `isPlaceholder` desaturated masks to toggle combat display without layout churn.

### 3. Zero-Allocation (0-GC) State Pool Contract
- Never instantiate anonymous closures or ephemeral tables inside `OnUpdate` scripts or high-frequency event handlers.
- Use `StatePool.acquire()` and `StatePool.release()` to recycle state objects, completely eliminating LuaJIT garbage collection stutter.

---

## Deployment & Verification Commands

- **Build Package**: `pwsh -NoProfile -File .\Deploy\Build-Package.ps1`
- **Build Dev Package**: `pwsh -NoProfile -File .\Deploy\Build-Package.ps1 -PackageLabel DEV`
- **CurseForge Upload**: `pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1`
- **DryRun Upload**: `pwsh -NoProfile -File .\Deploy\Upload-CurseForge.ps1 -DryRun`
- **Run Syntax Check**: `pwsh -NoProfile -File .\.AI\Tools\CheckLuaSyntax.ps1`
- **Run Flow Validation**: `pwsh -NoProfile -File .\.AI\Tools\Run-FlowValidation.ps1`
- **Run Contract Validation**: `pwsh -NoProfile -File .\.AI\Tools\Test-ValidationContracts.ps1`
- **Sync Documentation Site**: `python .\.AI\Tools\batch_convert_docs.py`

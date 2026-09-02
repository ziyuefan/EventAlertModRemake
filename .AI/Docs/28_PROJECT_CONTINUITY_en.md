<!-- EAM_DOCUMENTATION_SOURCE: enUS -->
# Project Continuity & Knowledge Handoff Snapshot

## 1. Purpose & Authority

This document serves as the authoritative primary human-readable continuity point following context compression, subagent handover, or extended development interruptions.
- Machine-readable status is maintained in `Data/ProjectContinuity.json`.
- Chronological engineering trial details are logged in `Docs/15_DEVELOPMENT_ISSUE_LOG.md`.
- Live client verification matrices are maintained in `Data/LiveValidationMatrix.json`.

---

## 2. Current State Snapshot: Alpha 8.3 (Active Baseline)

- **Current Status**: Project is in active Alpha 8.3 release development.
- **Cooldown Reordering & Pre-render Placeholders**:
  - Full Drag-and-Drop and Up/Down (`▲`/`▼`) slot reordering in cooldown options.
  - Pre-render Placeholder Mode (`cooldownPreRender`) displays a desaturated grayscale mask out of combat, dynamically transitioning to full color upon spell cast with zero combat `CreateFrame` overhead.
- **Player Stats In-Combat Live Updates**:
  - Direct adoption of native `FontString:SetFormattedText` for all 18 attributes, achieving zero Lua GC string allocations in OnUpdate timer loops.
  - Implemented `getRawValue` routing across all 18 attributes, respecting Retail 12.x / Midnight `AllowedWhenTainted` and `Enum.SecretAspect.Text` contracts.
- **LibSharedMedia-3.0 (SharedMedia) Ecosystem Integration**:
  - Dynamic discovery (`MediaService.ensureLSM()`), `PLAYER_LOGIN` deferred synchronization, third-party sound/font package support, dual-channel safe playback (`MediaService.playSound`), and 12.1 Native Aura sound routing.
- **Zero-Delay Live Font Application (No `/reload` Needed)**:
  - SavedVariables whitelist unlock, live refresh of preview icons, general alert icons, player resources, and player stats text.
- **Scrollable Dropdown Menus**:
  - Adaptive `UIPanelScrollFrameTemplate` with smooth mouse wheel scrolling for long lists of media assets.
- **Validation Baseline**:
  - Lua Syntax Check: **76/76 PASSED**.
  - Flow Validation Harness: **84/84 PASSED**.
  - Validation Contracts: **496/496 PASSED**.

---

## 3. Fixed Project Boundaries

- **Git Project Root**: `D:\Project_EventAlertMod`
- **AddOn Runtime Tree**: `D:\Project_EventAlertMod\EventAlertMod`
- **AI Governance & Tools**: `D:\Project_EventAlertMod\.AI`
- **Packaging & Deployment**: `D:\Project_EventAlertMod\Deploy`
- **Build Output**: `D:\Project_EventAlertMod\Dist` (Git ignored)
- **Deprecated Directory**: `D:\EventAlertMod` is obsolete; agents must never read, write, or fall back to it.
- **Symbolic Link Protection**: Any Reparse Point, Junction, or Symlink targeting AddOns must fail-closed.

---

## 4. Subsystem Responsibilities

1. **`Core/`**: Environment initialization, central event bus, frame-budgeted scheduler, and SavedVariables schema migration.
2. **`Services/`**: Runtime facts extraction (Auras, Cooldowns, Resources, Stats, Ground Spells) with strict Secret Value gating.
3. **`UI/`**: Pooled visual widgets, 60fps live configuration preview, 3-level APPEND docking, hover tooltips, and 11 visual themes.
4. **`Debug/`**: Flow test runners, runtime probes, live test session checkpoints, and compact AI diagnostic reporting.

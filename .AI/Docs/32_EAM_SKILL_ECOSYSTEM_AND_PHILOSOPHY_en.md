<!-- EAM_DOCUMENTATION_SOURCE: enUS -->
# EAM Skill Ecosystem & Agentic AI Governance Philosophy

> 🚀 **Skill-Driven, Progressive Disclosure, Deterministic Execution: A Modern Agentic AI Collaboration Architecture for World of Warcraft AddOn Development**

---

## 🧭 1. Core Architecture Philosophy

In traditional large-scale software engineering with AI agents, teams frequently encounter critical bottlenecks: **Context Window Explosion, Lost in the Middle, Context Truncation, and Architecture Drift across different agents**.

To decisively eliminate these bottlenecks, EventAlertMod (EAM) implements an industry-leading **"Everything as a Skill"** architecture:

```
                           EAM Agentic AI Governance Architecture
  ┌────────────────────────────────────────────────────────────────────────┐
  │                   User Declarative Intent (User Prompt)                │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │
                                      ▼
  ┌────────────────────────────────────────────────────────────────────────┐
  │        Antigravity / Master Agent (Central Intent & Task Router)       │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │ (Dynamic Progressive Disclosure)
                                      ▼
  ┌────────────────────────────────────────────────────────────────────────┐
  │                 21 Standardized SKILL Systems (SOP Protocols)          │
  │  ┌──────────────────┐ ┌──────────────────┐ ┌─────────────────────────┐  │
  │  │ Core Engine &    │ │ Game Services &  │ │ Interactivity &         │  │
  │  │ 12.x API Defense │ │ Resource Systems │ │ Visual Systems (UI/UX)  │  │
  │  └──────────────────┘ └──────────────────┘ └─────────────────────────┘  │
  │  ┌──────────────────┐ ┌──────────────────────────────────────────────┐  │
  │  │ Validation & QA  │ │ DevOps, Continuous Packaging & Local Sec     │  │
  │  │ Gates (QC Engine)│ │ (Release Automation & Secret Vault)          │  │
  │  └──────────────────┘ └──────────────────────────────────────────────┘  │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │ (Deterministic Execution)
                                      ▼
  ┌────────────────────────────────────────────────────────────────────────┐
  │  Subagents Cluster / Toolchain / 496+ AST Validation / 84+ Flow Sandbox │
  └────────────────────────────────────────────────────────────────────────┘
```

### 💡 Five Core Transformation Benefits:

1. **Progressive Disclosure & Maximum Token Conservation**:
   - Technical documentation across 30+ files is never dumped into the prompt simultaneously.
   - The agent retains lightweight metadata (Name + Description) for the 21 skills in working memory.
   - When a specific task is triggered, the system dynamically injects only the corresponding `SKILL.md` into context.
2. **Zero Cold-Start Continuity across Sessions & Models**:
   - Chat trajectories are ephemeral, but persisted skills are permanent.
   - New conversations or alternate models (e.g. Gemini Flash / Pro / Claude) consult the designated skill and instantly align with authoritative project standards.
3. **Anti-Regression Safeguards**:
   - Months of hard-earned engineering solutions (e.g. 12.x Secret Value table key protections, Cloudflare WAF bypass, LSM dual-source deduplication, JIT abort prevention) are codified as strict "Violations" and "Best Practices".
4. **Capability Equalization**:
   - Clear step-by-step SOPs allow lightweight subagents to execute specialized refactoring with identical quality to flagship models.
5. **Agent-Ready Smart Repository**:
   - The repository pairs production code with self-maintaining, self-repairing, automated validation tooling.

---

## 🏛️ 2. The 21 SKILLs Catalog Across 5 Domains

### Domain 1: Core Engine & WoW 12.x API Defense
1. **`eam-secret-taint-sentinel`**: Four-point `issecretvalue` verification, table indexing defense, write-only sinks (`StatusBar:SetValue`, `DurationObject`), and zero readback.
2. **`eam-zero-alloc-statepool`**: Zero-allocation state object pools, elimination of OnUpdate closures, and throttled batch updates (`AlertManager`).
3. **`eam-native-aura-compiler`**: Retail 12.1 Native Aura container compilation, layout fingerprints (`buildLayoutFingerprint`), slot/group separation, and deferred in-combat application.
4. **`eam-cdm-shadow-host`**: CooldownViewer (CDM) shadow host parasitic hooks, `ClipsChildren` text protection, and FrameLevel elevation.
5. **`eam-api-change-intel`**: Multi-client API diff tracking (Retail 12.1 / PTR 12.1 / XPTR 12.0.7), Wago.tools intelligence, and fallback wrappers.

### Domain 2: Game Services & Cooldown Tracking
6. **`eam-player-resource-catalog`**: 17 resources across 40 spec topologies, Druid 5-form switching, DK 6-slot rune dashboard, and demand-driven samplers.
7. **`eam-cooldown-activation-guard`**: Exact player cast verification (`UNIT_SPELLCAST_SUCCEEDED`), spell override state machines, and tri-state condition overrides.
8. **`eam-target-aura-anonymous-probe`**: Anonymous target aura inspection, `Ctrl+Alt` quick-add gating, and zero-taint tooltip callbacks.
9. **`eam-player-stat-monitor`**: 18 core stats, 4-in-1 velocities (ground, swim, flight, gliding 830%~1400%), and zero-GC `FontString:SetFormattedText`.

### Domain 3: UI & Visual Systems
10. **`eam-ui-interactive-suite`**: Seamless 3-level APPEND docking, synchronized multi-window dragging, mutual side panel exclusion, and comprehensive hover tooltips (`EAM.UI.setTooltip`).
11. **`eam-glow-pandemic-visuals`**: Action bar overlay glow sync, dual-layer glow fallbacks, Pandemic DoT threshold highlights, and fullscreen combat red edge flash.
12. **`eam-sharedmedia-integration`**: LibSharedMedia-3.0 (SharedMedia) dynamic asset discovery, zero-delay live font hot-swapping, and adaptive scrollable dropdowns.
13. **`eam-profile-codec-manager`**: Selective 8-category profile sharing, EAMAP1 Base64/JSON encoding, Adler-32 checksums, and safe merge/replace.

### Domain 4: QA, Verification & Diagnostic Gates
14. **`eam-flow-validation-harness`**: 84+ automated behavioral test cases, combat transitions, and structured JSON/Markdown reports.
15. **`eam-validation-contracts`**: 496+ AST code assertions, TOC file ordering, and 5-locale terminology alignment.
16. **`eam-live-matrix-inspector`**: PTR / XPTR / Retail live verification matrix (`LiveValidationMatrix.json`) and `/reload` boot token checkpoints.

### Domain 5: DevOps, Packaging & Governance
17. **`eam-secret-vault-manager`**: Windows DPAPI double-encryption (`API_TOKEN.SEC`), git exclusion, and secure memory isolation.
18. **`eam-curseforge-publisher`**: Automated CurseForge uploads, Cloudflare WAF bypass, MIME payload validation, and DryRun simulation.
19. **`eam-local-wow-deployer`**: Windows Registry root discovery, Reparse Point / Symlink fail-closed guards, and WTF backups.
20. **`eam-docs-site-builder`**: Automated HTML documentation site generator (`batch_convert_docs.py`), navbar injection, and bilingual content switching.
21. **`eam-project-continuity-governor`**: Single source of truth governance, `ProjectContinuity.json`, and context compression handoff.

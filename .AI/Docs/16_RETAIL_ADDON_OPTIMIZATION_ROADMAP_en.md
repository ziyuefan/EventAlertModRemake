<!-- EAM_DOCUMENTATION_SOURCE: enUS -->
# Retail AddOn Optimization Roadmap

This document outlines the strategic optimization roadmap for the modern Retail rewrite of EventAlertMod (EAM), reflecting research across Warcraft Wiki, Blizzard UI forums, WoWInterface, CurseForge, and Reddit AddOn communities.

---

## Strategic Design Philosophy

1. **Retain EAM's Core Identity**: Lightweight, simple, spellID-oriented, and substantially easier to configure than WeakAuras.
2. **Strict Data Separation**: Clean separation between Safe Facts, Derived Estimates, Display-Only states, and Boundary Warnings.
3. **Widget & DurationObject First**: Let Blizzard native widgets and DurationObjects handle visual time progress; eliminate Lua-side manual string concatenation in timer loops.
4. **Item-Level Secret Value Defense**: Perform granular `issecretvalue()` and `canaccessvalue()` checks instead of relying on broad context flags.
5. **Zero Taint Exposure**: Never attach secure action attributes, modify protected unit frames, or hook Blizzard combat execution chains.
6. **On-Demand Diagnostics**: All debugging, profiling, and export routines must remain strictly on-demand, never polluting hot paths.

---

## Roadmap Milestones & Priorities

### Priority P0: Security & Compatibility Baseline
- Centralized Secret-safe adapters across `AuraService`, `CooldownService`, and `ItemCooldownService`.
- Strictly prohibit table lookups with unverified Secret keys.
- Prohibit unsanitized string matching on tooltip text.
- Defer all layout and structural mutations during `InCombatLockdown()`.

### Priority P1: Core Services Stabilization
- **Player Auras**: Support self buffs/debuffs; fall back to protected timer or icon-only displays when values are restricted.
- **Target Auras**: Strictly track `target` unit; avoid untrusted nameplate lookups.
- **Spell Cooldowns**: Structured `C_Spell` integration; prioritize native `DurationObject`; support `ignoreGCD`.
- **Item Cooldowns**: Direct `itemID` monitoring; avoid massive bag scans.

### Priority P2: Zero-GC & High Frame Rates
- State object and scheduler task pooling to eliminate garbage collection stutter.
- Delta-first aura scans to prevent redundant full-unit iterations.
- Value-gated updates on `SetText`, `SetTexture`, `SetCooldown`, and `SetPoint` to minimize layout redraws.

### Priority P3: User Experience
- Keep simple slash commands: `/eam add <spellID>`, `/eam remove <spellID>`, `/eam reset`.
- Visual clarity with intuitive hover tooltips, 11 themes, and 3-level docking.
- Provide clear "Data Protected" indicators instead of throwing raw Lua errors to players.

---

## Out-of-Scope Boundaries (Will NOT Implement)

- No combat automation, rotation bots, or one-button macros.
- No complex WeakAuras-style arbitrary Lua scripting sandbox.
- No clickable enemy unit frames or protected nameplate interactions.
- No attempts to reverse-engineer Secret Values via combat log sniffing.
- No support for Classic Era, MoP Classic, TBC Classic, or Wrath Classic.

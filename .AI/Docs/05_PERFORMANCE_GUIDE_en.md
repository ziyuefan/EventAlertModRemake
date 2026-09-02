<!-- EAM_DOCUMENTATION_SOURCE: enUS -->
# Performance & LuaJIT Optimization Guide

## Core Performance Principles

1. **Zero Garbage Collection Allocation in Hot Paths**:
   Eliminate transient table allocations, anonymous closure instantiations, and string concatenations inside `OnUpdate` loops or high-frequency event handlers (`UNIT_AURA`, `SPELL_UPDATE_COOLDOWN`).
2. **Centralized Scheduling**:
   Replace scattered `C_Timer.After` closures and per-icon `OnUpdate` scripts with a single central `Scheduler` frame budget.
3. **Recycled State Objects (StatePool)**:
   All state records (`AuraState`, `CooldownState`, `TimerToken`) are managed through reusable object pools (`acquire` / `release`).

---

## Memory Allocation Policies

### Allowed Pre-Allocations:
- Bounded alert arrays and dirty queues pre-allocated with `table.create(narr, nrec)`.
- Icon frame objects prewarmed during non-combat loading.
- Reusable timer token tables indexed by alert ID.

### Strictly Prohibited in Hot Paths:
- **Anonymous Closures**: Avoid `C_Timer.After(delay, function() ... end)`. Use parameterized handlers or static callback pointers.
- **`table.insert` in Loops**: Use direct integer indexing (`arr[#arr + 1] = item` or pre-indexed assignment).
- **Dynamic String Concatenation**: Avoid `text:SetText(str1 .. " " .. str2)`. Use `FontString:SetFormattedText(format, ...)` which formats directly in Blizzard's C-engine without allocating Lua string objects.
- **Unbounded `pairs` Traversal**: Use numeric `for index = 1, count do` arrays wherever deterministic order is feasible.

---

## Table Freezing Policy (`table.freeze`)

To facilitate LuaJIT trace compilation and enforce read-only immutability, apply `table.freeze` strictly to:
- Static constants and enumerations (`Constants.lua`).
- Theme definitions and color palettes.
- Text placement schemas (`TextPlacementContract.json`).
- Static layout offset vectors (`LAYOUT_OFFSETS`).

**Never Freeze**:
- Runtime state caches (`AuraState`, `CooldownState`).
- Active object pools (`IconPool`, `StatePool`).
- `SavedVariables` tables (`EAM_DB`).
- Registered text binding dictionaries (`Locale.lua`).

---

## Combat Lockdown Optimization

- **Pre-Anchored Widgets**: Pre-create and calculate static positions for all active cooldown and aura slots during non-combat states.
- **Zero Layout Churn**: During combat, toggling icon display state is achieved via `SetAlpha(0)` or desaturated masks (`SetDesaturated(true)`), 100% avoiding `icon:SetPoint` calls while `InCombatLockdown() == true`.
